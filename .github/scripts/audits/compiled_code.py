"""Compiled-code audit (monthly, 4th Saturday, PR, Opus; at most 3 proposals a run).

Plan: R/package_metadata/new_feature_plans/v1_0_6/audit_jobs_framework.md (Part 5;
audit_jobs_framework.md TODO-14 and TODO-15). It asks "is this algorithm compiled well?" for the
few functions that take the time.

Stage 1, hot functions (mechanical, prepare job). EDI is built from this commit with CRAN-like
flags: `-g -O2`, portable (EDI_PORTABLE=1) and EDI_UNITY=0, so each function keeps its own symbol
and each source file its own object. The build goes to a temp library outside the checkout (the
reusable workflow's install_edi step builds the unity default, so this module builds its own;
the caller sets only setup_r). A short set of the nightly benchmark sections
(R/benchmark/benchmark_model_fits.R --sections / --families / --shard, see PROFILE_RUNS) runs
under `perf record`, single-threaded, each with a time limit. The functions that make up the top
90% of the samples inside EDI.so (at most MAX_HOT) are the hot functions. Template code from
Eigen, std or Rcpp is counted but not audited (its source is not EDI's).

Stage 2, detectors (mechanical). For each hot function: its source file is recompiled alone with
the same command plus `-fopt-info-vec-missed` / `-fopt-info-inline-missed` (Clang:
`-Rpass-missed=...`) into a temp object, and the messages inside the function's line range are
kept; its disassembly from EDI.so (`objdump -d --disassemble=<symbol>`) gives the loops (backward
branches) and the calls inside them: allocation, R API / interrupt checks, assert failures, libm
calls, indirect calls.

Stage 3, Claude (Opus, one agent per flagged function, at most max_batches a run). Unit: one hot
function with a detector finding. Context: source location, profile share, detector output and
the loop part of the disassembly. Hash: the normalised disassembly (addresses and offsets
stripped), so a source edit that leaves the assembly alone is not re-read, and a compiler upgrade
re-audits the function. The agent proposes one source change (file, exact old code, new code,
which detector finding it removes).

Stage 4, verification (no Claude; .github/scripts/compiled_code_verify.py, the verify-* jobs of
the caller workflow). apply() puts every proposal whose old code occurs exactly once into the work
tree, so the framework opens a draft PR (spec `pr_draft`), and writes followup/proposals.json
(uploaded as the `audit-compiled-code-followup` artifact). The verify jobs then build the run's
commit and, separately, the commit plus each proposal; run the tests related to the changed file
on each proposal's build; check that the proposal's bench code (written by the agent) gives the
same results under the D2 closed-form tier; and time it in ABBA blocks against the unchanged
build. Proposals that fail, change results, or are not clearly faster are dropped; the PR branch
is rebuilt with the kept ones and marked ready, or the PR is closed when none is kept (the next
run's harvest then records them as rejected, so they are not proposed again). Detector findings
are listed once and again only when they change.
"""
import concurrent.futures as cf
import glob
import json
import os
import re
import shlex
import shutil
import subprocess
import tempfile
from pathlib import Path

import audit_common as ac
from audits import _rotation as rot

SPEC = {
    "name": "compiled-code",
    "title": "Compiled-code audit",
    "report": "pr",
    "claude": True,
    "model": ac.OPUS,
    "batch_size": 1,          # each agent needs one function's source, disassembly and detector output
    "max_batches": 3,         # at most 3 proposals a run (plan Part 5)
    "period": "month",
    "cycle_weeks": 1,         # unused: every unit carries NEVER (no rotation; see units())
    "max_turns": 50,
    "tools": "Read,Glob,Grep",
    "pr_draft": True,         # the verify jobs mark the PR ready after the benchmark check
}

# Short runs of the nightly benchmark sections (benchmark_sections.R): one shard of each response
# family of the models section, and the procedures section. (section, families, shard, seconds)
PROFILE_RUNS = [
    ("models", "continuous", "1/2", 480),
    ("models", "incidence", "1/3", 480),
    ("models", "count", "1/4", 480),
    ("models", "proportion", "1/3", 480),
    ("models", "ordinal", "1/4", 480),
    ("models", "survival", "1/4", 480),
    ("procedures", None, None, 600),
]
HOT_SHARE = 0.90
MAX_HOT = 20
MIN_SAMPLES = 20
LIBRARY_PREFIXES = ("Eigen::", "std::", "Rcpp::", "__gnu_cxx::", "tinyformat::", "boost::")
WORK_SUB = "compiled_code"

# ---------------------------------------------------------------- parsers (unit tested)

PERF_LINE = re.compile(r"^\s*([\d.]+)%\s+(\d+)\s+(\S+)\s+\[([.k])\]\s+(.+?)\s*$")


def parse_perf_report(text):
    """`perf report --stdio --no-children --sort dso,sym -n` -> [(dso, symbol, samples)]."""
    out = []
    for line in (text or "").splitlines():
        if line.startswith("#"):
            continue
        m = PERF_LINE.match(line)
        if m:
            out.append((m.group(3), m.group(5), int(m.group(2))))
    return out


def edi_samples(rows, dso="EDI.so"):
    """{symbol: samples} for rows of the given DSO (summed over runs)."""
    tot = {}
    for d, sym, n in rows:
        if os.path.basename(d) == dso and not sym.startswith("0x") and not sym.endswith("@plt"):
            tot[sym] = tot.get(sym, 0) + n
    return tot


def hot_set(samples, share=HOT_SHARE, max_n=MAX_HOT):
    """Symbols that make up the top `share` of the samples (at most max_n), with their share."""
    total = sum(samples.values())
    if not total:
        return []
    out, cum = [], 0
    for sym, n in sorted(samples.items(), key=lambda kv: (-kv[1], kv[0])):
        if cum >= share * total or len(out) >= max_n:
            break
        out.append({"symbol": sym, "samples": n, "share": round(100.0 * n / total, 2)})
        cum += n
    return out


NM_LINE = re.compile(r"^([0-9a-f]+)\s+([TtWw])\s+(\S+)(?:\s+(\S+):(\d+))?\s*$")


def parse_nm(text):
    """`nm -l --defined-only foo.o` -> {symbol: (type, file or None, line or None)} (text symbols)."""
    out = {}
    for line in (text or "").splitlines():
        m = NM_LINE.match(line.strip().replace("\t", " "))
        if m:
            out[m.group(3)] = (m.group(2), m.group(4), int(m.group(5)) if m.group(5) else None)
    return out


INSN = re.compile(r"^\s*([0-9a-f]+):\s+(.*)$")
TARGET = re.compile(r"\b([0-9a-f]+)\s+<([^>]+)>")
COMMENT_SYM = re.compile(r"#\s*[0-9a-f]+\s+<([^>]+)>")


def parse_objdump(text):
    """objdump -d (no raw bytes) of one function -> [{addr, text, mnemonic, target, target_sym}]."""
    out = []
    for line in (text or "").splitlines():
        m = INSN.match(line)
        if not m:
            continue
        body = m.group(2).strip()
        if not body or body.startswith("(bad)"):
            continue
        mnem = body.split()[0]
        tgt = TARGET.search(body.split("#")[0])
        csym = COMMENT_SYM.search(body)
        out.append({"addr": int(m.group(1), 16), "text": body, "mnemonic": mnem,
                    "target": int(tgt.group(1), 16) if tgt else None,
                    "target_sym": (tgt.group(2) if tgt else (csym.group(1) if csym else None))})
    return out


def loops(insns):
    """Address ranges [target, branch] of backward branches inside the function."""
    if not insns:
        return []
    lo, hi = insns[0]["addr"], insns[-1]["addr"]
    out = []
    for i in insns:
        if i["mnemonic"].startswith("j") and i["target"] is not None and lo <= i["target"] <= i["addr"] <= hi:
            out.append((i["target"], i["addr"]))
    return sorted(set(out))


def in_loop(addr, ranges):
    return any(a <= addr <= b for a, b in ranges)


ALLOC = re.compile(r"^(_Znwm|_Znam|_ZnwmSt11align_val_t|_ZnamSt11align_val_t|malloc|calloc|realloc|"
                   r"posix_memalign|aligned_alloc|R_alloc|Rf_allocVector\w*)(@plt)?$")
RAPI = re.compile(r"^(Rf_\w+|R_CheckUserInterrupt|R_\w+|Rcpp\w*|_ZN4Rcpp\w*)(@plt)?$")
ASSERT = re.compile(r"^(__assert_fail|__assert_perror_fail|_ZN5Eigen\w*assert\w*)(@plt)?$")
LIBM = re.compile(r"^(__)?(exp|exp2|expm1|log|log2|log10|log1p|pow|sqrt|cbrt|lgamma|tgamma|lgamma_r|erf|erfc|"
                  r"sin|cos|tan|atan|atan2|tanh|sinh|cosh|asin|acos|fmod|hypot)(f|l)?(_finite)?(@plt)?(@GLIBC\S*)?$")


def _sym(s):
    return re.sub(r"@GLIBC\S*$", "", (s or "").split("+")[0])


def detect(insns):
    """Calls inside loop bodies: {detector: {target: count}}. Detectors: allocation_in_loop,
    r_api_in_loop, assert_reachable_in_loop, libm_in_loop, indirect_call_in_loop."""
    rng = loops(insns)
    out = {}

    def hit(kind, what):
        out.setdefault(kind, {})
        out[kind][what] = out[kind].get(what, 0) + 1

    by_addr = {i["addr"]: k for k, i in enumerate(insns)}
    for k, i in enumerate(insns):
        if not in_loop(i["addr"], rng):
            continue
        m = i["mnemonic"]
        if m.startswith("call"):
            s = _sym(i["target_sym"])
            if "*" in i["text"].split("#")[0] and not i["target_sym"]:
                hit("indirect_call_in_loop", re.sub(r"\s+", " ", i["text"].split("#")[0].strip()))
                continue
            if ALLOC.match(s):
                hit("allocation_in_loop", s)
            elif ASSERT.match(s):
                hit("assert_reachable_in_loop", s)
            elif LIBM.match(s):
                hit("libm_in_loop", s)
            elif RAPI.match(s):
                hit("r_api_in_loop", s)
        elif m.startswith("j") and i["target"] is not None and i["target"] in by_addr:
            # a branch out of the loop to a block that calls __assert_fail within a few instructions
            j = by_addr[i["target"]]
            for x in insns[j:j + 8]:
                if x["mnemonic"].startswith("call") and ASSERT.match(_sym(x["target_sym"])):
                    hit("assert_reachable_in_loop", _sym(x["target_sym"]))
                    break
    return out


def normalise(insns):
    """The function's instructions with addresses, offsets and absolute targets stripped."""
    if not insns:
        return []
    base = insns[0]["addr"]
    out = []
    for i in insns:
        t = i["text"].split("#")[0].strip()
        if i["target"] is not None and i["target_sym"] is not None:
            sym = re.sub(r"\+0x[0-9a-f]+$", "", i["target_sym"])
            rel = i["target"] - base if i["mnemonic"].startswith("j") else None
            t = TARGET.sub(f"<{sym}{'' if rel is None else '+' + str(rel)}>", t)
        csym = COMMENT_SYM.search(i["text"])
        if csym:
            t += f" #<{re.sub(r'[+]0x[0-9a-f]+$', '', csym.group(1))}>"
        t = re.sub(r"-?0x[0-9a-f]+\(%rip\)", "X(%rip)", t)
        out.append(re.sub(r"\s+", " ", t))
    return out


OPT_INFO = re.compile(r"^(?P<file>[^:\s]+):(?P<line>\d+):(?:\d+:)?\s*(?:remark:\s*|note:\s*)?(?P<msg>.*)$")


def parse_opt_info(text, source_name, start, end, limit=30):
    """Compiler optimisation remarks for lines start..end of `source_name` (deduplicated)."""
    seen, out = set(), []
    for line in (text or "").splitlines():
        m = OPT_INFO.match(line.strip())
        if not m or os.path.basename(m.group("file")) != source_name:
            continue
        n = int(m.group("line"))
        if not (start <= n <= end):
            continue
        msg = re.sub(r"\s+", " ", m.group("msg")).strip()
        key = (n, msg)
        if key in seen:
            continue
        seen.add(key)
        out.append(f"{source_name}:{n}: {msg}")
        if len(out) >= limit:
            break
    return out


def compile_command(log, cpp_name):
    """The compiler command R CMD INSTALL printed for `cpp_name` (a list), or None."""
    for line in (log or "").splitlines():
        if re.search(r"(^|\s)-c\s+" + re.escape(cpp_name) + r"(\s|$)", line):
            try:
                return shlex.split(line.strip())
            except ValueError:
                return None
    return None


def with_opt_info(cmd, out_obj, info_file, clang=False):
    """The compile command with its -o replaced and missed-optimisation remarks requested. GCC
    takes one -fopt-info file per compile (a second one is ignored with a warning), so the vec and
    inline groups share one file; split_opt_info() separates them."""
    cmd = list(cmd)
    if "-o" in cmd:
        k = cmd.index("-o")
        cmd[k + 1] = str(out_obj)
    else:
        cmd += ["-o", str(out_obj)]
    if clang:
        cmd += ["-Rpass-missed=loop-vectorize", "-Rpass-analysis=loop-vectorize", "-Rpass-missed=inline"]
    else:
        cmd += [f"-fopt-info-vec-inline-missed={info_file}"]
    return cmd


def split_opt_info(lines):
    """(vectorizer remarks, inliner remarks). The early inliner's "will not early inline" notes
    are routine and dropped."""
    vec, inl = [], []
    for l in lines:
        if "will not early inline" in l:
            continue
        (inl if ("inlin" in l) else vec).append(l)
    return vec, inl


def brace_end(lines, start_line, limit=3000):
    """1-based line of the brace that closes the function starting at start_line."""
    depth, opened = 0, False
    for n in range(start_line - 1, min(len(lines), start_line - 1 + limit)):
        code = re.sub(r'"(?:[^"\\]|\\.)*"|//.*$', "", lines[n])
        for c in code:
            if c == "{":
                depth += 1
                opened = True
            elif c == "}":
                depth -= 1
                if opened and depth == 0:
                    return n + 1
    return min(len(lines), start_line + 200)


def demangle(names):
    if not names:
        return {}
    try:
        r = subprocess.run(["c++filt"], input="\n".join(names), capture_output=True, text=True, timeout=60)
        dm = r.stdout.splitlines()
        if len(dm) == len(names):
            return dict(zip(names, dm))
    except (OSError, subprocess.TimeoutExpired):
        pass
    return {n: n for n in names}


def short_name(demangled):
    """`ret ns::f(args) const` -> `ns::f`; keeps templates' outer name."""
    s = demangled
    depth, cut = 0, None
    for k, c in enumerate(s):
        if c == "<":
            depth += 1
        elif c == ">":
            depth -= 1
        elif c == "(" and depth == 0:
            cut = k
            break
    head = s[:cut] if cut is not None else s
    return head.strip()


def unit_id(source_rel, demangled):
    name = short_name(demangled)
    uid = f"{source_rel}::{name}"
    if len(uid) > 160:
        uid = uid[:140] + "~" + ac.text_hash(uid)[:8]
    return uid


# ---------------------------------------------------------------- stage 1 and 2 (prepare)

def _run(cmd, **kw):
    kw.setdefault("capture_output", True)
    kw.setdefault("text", True)
    try:
        return subprocess.run(cmd, **kw)
    except (OSError, subprocess.TimeoutExpired) as e:
        return subprocess.CompletedProcess(cmd, 127, "", f"{e.__class__.__name__}: {e}")


def find_perf():
    cands = [shutil.which("perf")] + sorted(glob.glob("/usr/lib/linux-tools*/*/perf"), reverse=True)
    for c in cands:
        if c and _run([c, "--version"], timeout=30).returncode == 0:
            return c
    return None


def build_dir():
    return Path(os.environ.get("RUNNER_TEMP") or tempfile.gettempdir()) / "compiled_code_build"


def build_edi(ctx, bdir, log_path):
    """Install EDI from this commit (EDI_UNITY=0, portable, -g -O2) into bdir/lib, building in a
    copy of R/EDI so the objects stay next to their sources. Returns (lib, src copy, log text)."""
    src = bdir / "EDI"
    lib = bdir / "lib"
    if src.exists():
        shutil.rmtree(src)
    shutil.copytree(ctx.path("R/EDI"), src, ignore=shutil.ignore_patterns("*.o", "*.so", "*.dll", "unity_*"))
    lib.mkdir(parents=True, exist_ok=True)
    mk = bdir / "Makevars"
    mk.write_text("CXXFLAGS = -g -O2\nCXX11FLAGS = -g -O2\nCXX14FLAGS = -g -O2\nCXX17FLAGS = -g -O2\n"
                  "CXX20FLAGS = -g -O2\nCFLAGS = -g -O2\n")
    env = {**os.environ, "EDI_UNITY": "0", "EDI_PORTABLE": "1", "R_MAKEVARS_USER": str(mk),
           "MAKEFLAGS": f"-j{os.cpu_count() or 2}"}
    r = _run(["R", "CMD", "INSTALL", "--no-test-load", f"--library={lib}", str(src)], env=env, timeout=5400)
    log = (r.stdout or "") + "\n" + (r.stderr or "")
    Path(log_path).write_text(log[-200000:])
    if r.returncode:
        raise RuntimeError(f"R CMD INSTALL failed (exit {r.returncode}); the log tail is in the work artifact")
    return lib, src / "src", log


def profile(ctx, perf, lib, wdir):
    """Run PROFILE_RUNS under perf; returns ({symbol: samples}, [run notes])."""
    _run(["sudo", "-n", "sysctl", "-w", "kernel.perf_event_paranoid=1"], timeout=30)
    _run(["sudo", "-n", "sysctl", "-w", "kernel.kptr_restrict=0"], timeout=30)
    env = {**os.environ, "R_LIBS": f"{lib}:{os.environ.get('R_LIBS', '')}".rstrip(":"),
           "OMP_NUM_THREADS": "1", "OPENBLAS_NUM_THREADS": "1", "MKL_NUM_THREADS": "1"}
    total, notes = {}, []
    for k, (section, fams, shard, limit) in enumerate(PROFILE_RUNS, 1):
        data = wdir / f"perf-{k}.data"
        args = ["Rscript", "benchmark/benchmark_model_fits.R", f"--sections={section}"]
        if fams:
            args.append(f"--families={fams}")
        if shard:
            args.append(f"--shard={shard}")
        cmd = ["timeout", "-s", "INT", "-k", "60", str(limit), perf, "record", "-F", "499", "-q",
               "-o", str(data), "--"] + args
        r = _run(cmd, cwd=ctx.path("R"), env=env, timeout=limit + 180)
        label = " ".join(args[2:])
        if not data.exists():
            notes.append(f"{label}: no profile ({(r.stderr or '').strip().splitlines()[-1:] or ['no message']})")
            continue
        rep = _run([perf, "report", "-i", str(data), "--stdio", "--no-children", "--sort", "dso,sym", "-n",
                    "--no-demangle"], timeout=600)
        got = edi_samples(parse_perf_report(rep.stdout))
        for s, n in got.items():
            total[s] = total.get(s, 0) + n
        notes.append(f"{label}: {sum(got.values())} EDI.so samples"
                     + ("" if r.returncode == 0 else f" (stopped at the {limit} s limit or exit {r.returncode})"))
        data.unlink(missing_ok=True)
    return total, notes


def symbol_objects(obj_dir, wanted):
    """{symbol: (object file, nm type, source file, line)} for the wanted symbols; a strong
    definition wins over a weak one. Line numbers (nm -l, slow) only for the objects needed."""
    out = {}
    for o in sorted(Path(obj_dir).glob("*.o")):
        r = _run(["nm", "--defined-only", str(o)], timeout=300)
        for sym, (typ, _f, _l) in parse_nm(r.stdout).items():
            if sym not in wanted:
                continue
            prev = out.get(sym)
            if prev is None or (prev[1] in "Ww" and typ in "Tt"):
                out[sym] = (o, typ, None, None)
    for o in sorted({v[0] for v in out.values()}):
        r = _run(["nm", "-l", "--defined-only", str(o)], timeout=600)
        for sym, (typ, f, line) in parse_nm(r.stdout).items():
            if sym in out and out[sym][0] == o:
                out[sym] = (o, out[sym][1], f, line)
    return out


def disassemble(so, sym):
    r = _run(["objdump", "-d", "--no-show-raw-insn", f"--disassemble={sym}", str(so)], timeout=300)
    return r.stdout if r.returncode == 0 else ""


def stage12(ctx):
    """Stages 1-2. Returns {"hot": [...], "notes": [...], "errors": [...]} and writes it to the work dir."""
    wdir = Path(ctx.workdir) / WORK_SUB
    wdir.mkdir(parents=True, exist_ok=True)
    res = {"hot": [], "notes": [], "errors": [], "library_share": 0.0}
    perf = find_perf()
    if not perf:
        res["errors"].append("perf is not available (the caller installs linux-tools via apt_packages)")
        return res
    if not shutil.which("R"):
        res["errors"].append("R is not available (the caller sets setup_r: true)")
        return res
    bdir = build_dir()
    bdir.mkdir(parents=True, exist_ok=True)
    try:
        lib, objdir, log = build_edi(ctx, bdir, wdir / "install.log")
    except RuntimeError as e:
        res["errors"].append(str(e))
        return res
    so = lib / "EDI" / "libs" / "EDI.so"
    samples, notes = profile(ctx, perf, lib, bdir)
    res["notes"] += notes
    if sum(samples.values()) < MIN_SAMPLES:
        res["errors"].append(f"the profile has only {sum(samples.values())} samples in EDI.so")
        return res
    names = demangle(list(samples))
    total = sum(samples.values())
    lib_n = sum(n for s, n in samples.items() if names.get(s, s).startswith(LIBRARY_PREFIXES))
    res["library_share"] = round(100.0 * lib_n / total, 1)
    own = {s: n for s, n in samples.items() if not names.get(s, s).startswith(LIBRARY_PREFIXES)}
    hot = hot_set(own)       # the top 90% of the samples in EDI's own functions
    for h in hot:            # shares reported relative to all EDI.so samples
        h["share"] = round(100.0 * h["samples"] / total, 2)
    syms = symbol_objects(objdir, {h["symbol"] for h in hot})
    clang = "clang" in (_run(["R", "CMD", "config", "CXX"], timeout=60).stdout or "")
    compiler = (_run([("clang++" if clang else "g++"), "--version"], timeout=60).stdout or "").splitlines()[:1]

    def one(h):
        sym = h["symbol"]
        dm = names.get(sym, sym)
        o, _typ, f, line = syms.get(sym, (None, None, None, None))
        if o is None:
            return {**h, "function": dm, "skip": "no object file defines this symbol"}
        cpp = o.with_suffix(".cpp")
        source_rel = f"R/EDI/src/{cpp.name}"
        if f and Path(f).name != cpp.name and Path(f).suffix in (".h", ".hpp"):
            source_rel = f"R/EDI/src/{Path(f).name}"
        src_lines = (ctx.read(source_rel) or "").splitlines()
        start = line or 1
        if not line:
            m = re.search(r"\b" + re.escape(short_name(dm).split("::")[-1]) + r"\s*\(", "\n".join(src_lines))
            start = "\n".join(src_lines)[:m.start()].count("\n") + 1 if m else 1
        end = brace_end(src_lines, start)
        insns = parse_objdump(disassemble(so, sym))
        det = detect(insns)
        vec, inl = [], []
        cmd = compile_command(log, cpp.name)
        if cmd:
            tmp = Path(tempfile.mkdtemp(dir=bdir))
            info = tmp / "opt-info.txt"
            r = _run(with_opt_info(cmd, tmp / "x.o", info, clang), cwd=objdir, timeout=1800)
            text = (info.read_text() if info.exists() else "") + ("\n" + (r.stderr or "") if clang else "")
            vec, inl = split_opt_info(parse_opt_info(text, Path(source_rel).name, start, end, limit=80))
            vec, inl = vec[:30], inl[:30]
        if vec:
            det["loop_not_vectorized"] = {"compiler remarks": len(vec)}
        if inl:
            det["call_not_inlined"] = {"compiler remarks": len(inl)}
        rng = loops(insns)
        excerpt = [f"{i['addr']:x}: {i['text']}" for i in insns if in_loop(i["addr"], rng)][:250]
        dmap = demangle(sorted({x for x in excerpt for x in re.findall(r"<(_Z[^>+@]+)", x)}))
        excerpt = [re.sub(r"<(_Z[^>+@]+)", lambda m: "<" + dmap.get(m.group(1), m.group(1)), x) for x in excerpt]
        return {**h, "function": dm, "source_file": source_rel, "start_line": start, "end_line": end,
                "object": o.name, "n_instructions": len(insns), "n_loops": len(rng),
                "asm_hash": ac.text_hash(normalise(insns)) if insns else None,
                "detectors": det, "vec_missed": vec, "inline_missed": inl, "loop_disassembly": excerpt,
                "compiler": compiler[0] if compiler else ""}

    with cf.ThreadPoolExecutor(max_workers=max(1, min(4, os.cpu_count() or 1))) as pool:
        res["hot"] = list(pool.map(one, hot))
    (wdir / "hot.json").write_text(json.dumps(res, indent=1))
    return res


def _load_stage(ctx):
    p = Path(ctx.workdir) / WORK_SUB / "hot.json"
    try:
        return json.loads(p.read_text())
    except (OSError, ValueError):
        return None


def mechanical(ctx):
    res = stage12(ctx)
    (Path(ctx.workdir) / WORK_SUB).mkdir(parents=True, exist_ok=True)
    (Path(ctx.workdir) / WORK_SUB / "hot.json").write_text(json.dumps(res, indent=1))
    out = [{"unit": "profile", "kind": "stage_failed", "text": f"Stage 1-2 did not complete: {e}"}
           for e in res["errors"]]
    # The manifest keeps only hashes, so the profile history lives in its own notes file.
    prof_path = ctx.notes.dir / "profile.json"
    try:
        prev = json.loads(prof_path.read_text())
    except (OSError, ValueError):
        prev = None
    now = {h.get("function", h["symbol"]): h["share"] for h in res["hot"]}
    if prev and now:
        for fn, share in sorted(now.items(), key=lambda kv: -kv[1]):
            if fn not in prev.get("shares", {}):
                out.append({"unit": fn, "kind": "became_hot",
                            "text": f"`{short_name(fn)}` is newly hot: {share}% of the EDI.so samples."})
    if now:
        prof_path.write_text(json.dumps({"at": ctx.now.isoformat(timespec="seconds"), "sha": ctx.sha,
                                         "shares": now, "library_share": res["library_share"]},
                                        indent=1, sort_keys=True) + "\n")
    return out


def units(ctx):
    res = _load_stage(ctx) or {"hot": []}
    # A function whose proposal is still in a PR (being benchmarked or awaiting the owner) is not
    # re-read: the next run after the PR is merged or closed settles it (fixed or rejected).
    pending = {h.get("unit") for h in ctx.notes.findings() if h.get("status") == "proposed"}
    out = {}
    for h in res["hot"]:
        if h.get("skip") or not h.get("asm_hash") or not h.get("detectors"):
            continue
        uid = unit_id(h["source_file"], h["function"])
        if uid in pending:
            continue
        out[uid] = {
            "hash": h["asm_hash"],
            # No rotation: an unchanged assembly is not re-read (plan Part 5).
            "cycle_weeks": rot.NEVER,
            "context": {k: h[k] for k in ("function", "symbol", "source_file", "start_line", "end_line",
                                           "share", "samples", "n_instructions", "n_loops", "detectors",
                                           "vec_missed", "inline_missed", "loop_disassembly", "compiler")},
        }
    return out


# ---------------------------------------------------------------- apply (finish)

FOLLOWUP_SUB = "followup"


def applied_marker(old, new, original):
    """A line of the new code that was not in the file before (so finding it on main means the
    change was merged); the whole new code if every line already occurs."""
    lines = sorted({l.strip() for l in new.splitlines() if l.strip() and l.strip() not in original},
                   key=len, reverse=True)
    return lines[0] if lines else new.strip()


def apply(ctx, results, mech):
    res = _load_stage(ctx) or {"hot": [], "notes": [], "errors": []}
    human, info, mechanical_lines = [], [], [m.get("text", "") for m in mech]
    notes_dir = ctx.notes.dir
    hot_by_unit = {unit_id(h["source_file"], h["function"]): h for h in res.get("hot", []) if h.get("function") and h.get("source_file")}
    proposals_for = set()
    followup, proposed, applied = [], [], []
    n_prop = 0
    for r in results:
        for f in r.get("findings") or []:
            if not isinstance(f, dict) or f.get("kind") != "proposal":
                continue
            n_prop += 1
            proposals_for.add(f.get("unit"))
            rel = (f.get("file") or "").strip()
            old, new = f.get("old_code") or "", f.get("new_code") or ""
            path = ctx.path(rel) if rel.startswith("R/EDI/src/") and ".." not in rel else None
            text = path.read_text() if path is not None and path.is_file() else None
            if text is None:
                state = "the file is not under R/EDI/src or does not exist"
            else:
                c = text.count(old) if old else 0
                state = None if c == 1 and new != old else (
                    "the new code equals the old code" if c == 1 else f"the old code occurs {c} times (must be once)")
            if state:
                human.append(ac.decision(f"Not applied: `{f.get('unit', '')}`: {f.get('text', '').strip()} ({state}).", unit=f.get("unit"), key="not-applied"))
                continue
            path.write_text(text.replace(old, new, 1))
            pid = f"p{len(followup) + 1}"
            marker = applied_marker(old, new, text)
            h = hot_by_unit.get(f.get("unit"), {})
            followup.append({"id": pid, "unit": f.get("unit"), "function": h.get("function", f.get("unit")),
                             "share": h.get("share"), "file": rel, "old_code": old, "new_code": new,
                             "bench_code": f.get("bench_code", ""),
                             **{k: f.get(k, "") for k in ("text", "removes", "expected_effect", "risk_to_results")}})
            proposed.append({"unit": f.get("unit"), "kind": "proposal", "text": f.get("text", ""),
                             "applied_file": rel, "applied_text": marker})
            applied.append(f"{pid} `{rel}` ({short_name(h.get('function', f.get('unit', '')))}): "
                           f"{f.get('text', '').strip()} Removes: {f.get('removes', 'unspecified')}. "
                           "Benchmark check pending: the verify jobs keep it only if it is clearly faster "
                           "with equal results.")
    if followup:
        fdir = Path(ctx.workdir) / FOLLOWUP_SUB
        fdir.mkdir(parents=True, exist_ok=True)
        (fdir / "proposals.json").write_text(json.dumps(followup, indent=1))
    # Detector findings with no proposal: once, then only when they change.
    rep_path = notes_dir / "reported_detectors.json"
    try:
        reported = json.loads(rep_path.read_text())
    except (OSError, ValueError):
        reported = {}
    for h in res.get("hot", []):
        if h.get("skip") or not h.get("detectors"):
            continue
        uid = unit_id(h["source_file"], h["function"])
        dh = ac.text_hash(h["detectors"], h.get("vec_missed"), h.get("inline_missed"))
        if uid in proposals_for or reported.get(uid) == dh:
            continue
        reported[uid] = dh
        det = "; ".join(f"{k}: " + ", ".join(f"{t} x{n}" for t, n in sorted(v.items())[:6])
                        for k, v in sorted(h["detectors"].items()))
        info.append(f"Detector findings in `{short_name(h['function'])}` (`{h['source_file']}:{h['start_line']}`, "
                     f"{h['share']}% of EDI.so samples), no proposal kept: {det}")
    rep_path.write_text(json.dumps(reported, indent=1, sort_keys=True) + "\n")
    hot = res.get("hot", [])
    summary = (f"{len(hot)} hot function(s) cover {round(sum(h['share'] for h in hot), 1)}% of the EDI.so "
               f"samples ({res.get('library_share', 0)}% more is Eigen/std/Rcpp template code, not audited); "
               f"{sum(1 for h in hot if h.get('detectors'))} have detector findings; {n_prop} proposal(s). "
               f"{len(followup)} applied to this draft PR for the benchmark check, which drops the ones that "
               "are not clearly faster or change results, then marks the PR ready (or closes it).")
    if res.get("notes"):
        summary += " Profile runs: " + "; ".join(res["notes"]) + "."
    return {"summary": summary, "applied": applied, "mechanical": mechanical_lines, "human": human,
            "info": info, "proposed": proposed}
