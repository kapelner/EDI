"""Rd audit: the package's help pages (R/EDI/man/*.Rd).

Plan: R/package_metadata/new_feature_plans/v1_0_6/audit_jobs_framework.md, Part 2, plus two owner
additions (2026-11-17): failing examples are fixed, not only reported, and examples are run under
several seeds and checked against the published reference pages.

Mechanical stage (needs R and the installed EDI; the R side is rd_check.R):
  - tools::checkRd on every Rd file; topic links (tools' xref check, and links into packages EDI does
    not declare); tools::codoc / codocClasses / codocData;
  - every \\examples block, extracted with tools::Rd2ex and run in its own Rscript: the part outside
    \\donttest once (60 s limit; over 5 s is CRAN's timing NOTE), and the whole block (300 s limit)
    under set.seed(k) for k = 1..N_SEEDS, fresh session each, so a data-dependent failure that only
    some draws hit is caught; the repeats are skipped for an example whose first run took > 30 s;
  - "#> Error" / "#> Warning" lines in the Examples section of the published pkgdown reference pages
    (the output of the run that built the site);
  - spelling with R/EDI/inst/WORDLIST (seeded on the first run; EDI's own identifiers are added
    automatically later). URLs are not checked here: scripts/check_doc_links.py does that nightly.
Claude stage: changed pages, a 1/8 rotation, and every page whose example fails (always, while it
fails). Apply: one-sentence spelling/grammar fixes in the roxygen source, and replacement @examples
blocks that run clean under every seed; then roxygen runs once. Everything else is "Needs a human".
"""
import concurrent.futures as cf
import html
import json
import os
import re
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path

import audit_common as ac
from audits import _doc_audit_shared as sh

SPEC = {
    "name": "rd",
    "title": "Rd audit",
    "report": "pr",
    "claude": True,
    "model": ac.SONNET,
    "batch_size": 8,
    "cycle_weeks": 8,
    # First full pass is 370 pages = 47 batches (plan, Part 2); a normal week is about 7.
    "max_batches": 48,
    "tools": "Read,Glob,Grep",
    "max_turns": 80,
}

SCRIPT = Path(__file__).with_name("rd_check.R")
CRAN_LIMIT = 60          # s, the part outside \donttest
FULL_LIMIT = 300         # s, the whole block with \donttest
CRAN_SECONDS = 5         # CRAN's limit on the default part (CPU and elapsed)
VERIFY_SECONDS = 4       # stricter limit for a proposed block: CI is faster than CRAN's slowest machines
TARGET_SECONDS = 2.5     # what the prompt asks for
CPU_RATIO = 2.5          # CRAN: CPU more than 2.5 x elapsed means more than 2 threads
CPU_RATIO_FLOOR = 1.0    # s of CPU below which the ratio is not judged
DONTTEST_SECONDS = 60    # report a \donttest part slower than this
DONTRUN_REASONS = {"credentials", "network", "interactive", "non-cran-software", "shows-error"}
LOAD_GRACE = 60          # s on top of a limit for starting R and loading EDI
N_SEEDS = int(os.environ.get("AUDIT_RD_SEEDS", "5"))
REPEAT_MAX_SECONDS = 30  # no seed repeats for an example whose first run took longer
WORKERS = max(1, min(4, os.cpu_count() or 2))
SLOWER_FACTOR, SLOWER_MIN = 2.0, {"cran": 5.0, "full": 30.0}
REFERENCE_URL = "https://kapelner.github.io/EDI/reference/"
USER_AGENT = "EDI-doc-audit/1.0 (scheduled CI job; python-urllib)"
PAGE_DELAY = 0.5         # s between reference pages
TEXT_KINDS = {"spelling", "grammar"}
EXAMPLE_KIND = "example-fix"


# ---------------------------------------------------------------- R runners (tests replace these)

def run_static(ctx, no_codoc=False):
    out = ctx.workdir / "rd_static.json"
    args = [str(SCRIPT), "static", str(ctx.path(sh.PKG)), str(out), str(ctx.workdir / "rd_examples")]
    if no_codoc:
        args.append("--no-codoc")
    code, so, se = sh.run_r(args, timeout=3600, cwd=ctx.repo)
    data = sh.read_json(out)
    if data is None:
        tail = "\n".join((se or so or "").strip().splitlines()[-5:])
        return None, f"rd_check.R static failed (exit {code}): {tail}"
    return data, ""


def run_example(path, limit, seed=None):
    """Run one example file in a fresh Rscript. Returns the R record plus `timed_out`."""
    out = Path(str(path) + (f".seed{seed}" if seed is not None else "") + ".json")
    args = [str(SCRIPT), "example", str(path), str(out)] + (["--seed", str(seed)] if seed is not None else [])
    code, so, se = sh.run_r(args, timeout=limit + LOAD_GRACE)
    res = sh.read_json(out, {}) or {}
    res["timed_out"] = code is None or (res.get("loaded") and res.get("elapsed") is None)
    if code not in (0, None) and not res:
        res["error"] = "Rscript failed: " + "\n".join((se or "").strip().splitlines()[-3:])
    if res.get("elapsed") is not None and res["elapsed"] > limit:
        res["timed_out"] = True
    return res


def extract_examples(rd_path, ex_dir):
    """Rd2ex one Rd file (rd_check.R extract). Returns {"cran": path, "full": path|None, ...}."""
    code, so, se = sh.run_r([str(SCRIPT), "extract", str(rd_path), str(ex_dir)], timeout=120)
    try:
        return json.loads(so.strip() or "{}")
    except ValueError:
        return {}


def edi_loads():
    code, so, se = sh.run_r(["-e", "suppressPackageStartupMessages(library(EDI))"], timeout=180)
    return code == 0, (se or "").strip()


# ---------------------------------------------------------------- example runs

def timing_problems(elapsed, cpu, limit=CRAN_SECONDS):
    """CRAN's timing rules for the part of an example that runs by default (outside \\donttest and
    \\dontrun): over `limit` s of CPU or elapsed time, or CPU more than 2.5 times elapsed (more
    than two threads in use; checked once CPU reaches CPU_RATIO_FLOOR s, below which the ratio is
    noise)."""
    out = []
    elapsed, cpu = elapsed or 0.0, cpu or 0.0
    if elapsed > limit or cpu > limit:
        out.append({"kind": "example-cran-time",
                    "text": f"the part CRAN runs by default took {elapsed:.1f} s elapsed, {cpu:.1f} s CPU "
                            f"(limit {limit:g} s)"})
    if cpu >= CPU_RATIO_FLOOR and elapsed > 0 and cpu > CPU_RATIO * elapsed:
        out.append({"kind": "example-cpu-ratio",
                    "text": f"the part CRAN runs by default used {cpu / elapsed:.1f} times as much CPU as "
                            f"elapsed time ({cpu:.1f} s / {elapsed:.1f} s; CRAN flags more than {CPU_RATIO:g}, "
                            f"i.e. more than 2 threads)"})
    return out


def check_example(cran, full, run=None, seeds=None, limit=CRAN_SECONDS, dontrun=None):
    """Run one page's example the audit's way and classify the result.

    cran: the file without \\donttest code; full: the file with it (None when the page has no
    \\donttest); dontrun: the file with \\dontrun code uncommented (None when it has none).
    The default part runs once (seed 1) for CRAN's timing rules (`limit` s, CPU/elapsed 2.5); the
    complete block runs under set.seed(1..N), each in a fresh session, so a failure only some
    draws hit is caught (repeats are skipped after a first run over REPEAT_MAX_SECONDS s). The
    \\donttest part's time is the complete block's minus the default part's; over
    DONTTEST_SECONDS s is reported. A \\dontrun file that runs clean is reported: CRAN wants
    \\dontrun only for code that cannot run in a check.
    Returns {"cran", "runs", "dontrun", "repeats_skipped", "donttest_seconds", "problems"}.
    """
    run = run or run_example
    seeds = list(seeds or range(1, N_SEEDS + 1))
    problems = []
    rec = {"cran": None, "runs": [], "repeats_skipped": False, "dontrun": None, "donttest_seconds": None}
    if cran:
        r = run(cran, CRAN_LIMIT, seed=seeds[0])
        rec["cran"] = r
        if r.get("timed_out"):
            problems.append({"kind": "example-time-limit", "part": "cran", "seeds": [seeds[0]],
                             "text": f"the part CRAN runs by default hit the {CRAN_LIMIT} s limit"})
        elif r.get("error"):
            problems.append({"kind": "example-error", "part": "cran", "seeds": [seeds[0]],
                             "text": f"error outside \\donttest: {r['error']}"})
        else:
            if r.get("warnings"):
                problems.append({"kind": "example-warning", "part": "cran", "seeds": [seeds[0]],
                                 "text": "warning outside \\donttest: " + " | ".join(r["warnings"])})
            for p in timing_problems(r.get("elapsed"), r.get("cpu"), limit):
                problems.append({**p, "part": "cran", "seeds": [seeds[0]]})
    target, tlimit, part = (full, FULL_LIMIT, "full") if full else (cran, CRAN_LIMIT, "cran")
    if target:
        by_msg = {}
        for i, k in enumerate(seeds):
            if full is None and i == 0 and rec["cran"] is not None:
                r = rec["cran"]   # no \\donttest: the default-part run is the seed-1 run
            else:
                r = run(target, tlimit, seed=k)
            rec["runs"].append({**r, "seed": k})
            if r.get("timed_out"):
                by_msg.setdefault(("example-time-limit", f"hit the {tlimit} s limit"), []).append(k)
            elif r.get("error"):
                by_msg.setdefault(("example-error", f"error: {r['error']}"), []).append(k)
            elif r.get("warnings"):
                by_msg.setdefault(("example-warning", "warning: " + " | ".join(r["warnings"])), []).append(k)
            if r.get("timed_out") or (i == 0 and (r.get("elapsed") or 0) > REPEAT_MAX_SECONDS):
                rec["repeats_skipped"] = i == 0 and len(seeds) > 1 and not r.get("timed_out")
                break
        if full and rec["runs"] and rec["runs"][0].get("elapsed") is not None:
            base = (rec["cran"] or {}).get("elapsed") or 0.0
            rec["donttest_seconds"] = max(0.0, rec["runs"][0]["elapsed"] - base)
            if rec["donttest_seconds"] > DONTTEST_SECONDS:
                problems.append({"kind": "example-donttest-time", "part": "full", "seeds": [seeds[0]],
                                 "text": f"the \\donttest part took about {rec['donttest_seconds']:.0f} s "
                                         f"(reported over {DONTTEST_SECONDS} s; R CMD check --as-cran runs it)"})
        where = "with \\donttest" if full else "(no \\donttest)"
        cran_msgs = {p["text"].split(": ", 1)[-1] for p in problems if p["part"] == "cran"}
        for (kind, msg), ks in by_msg.items():
            if part == "cran" and ks == [seeds[0]] and msg.split(": ", 1)[-1] in cran_msgs:
                continue   # the seed-1 default run, already reported above
            if part == "cran" and kind == "example-time-limit" and ks == [seeds[0]]:
                continue
            problems.append({"kind": kind, "part": part, "seeds": ks,
                             "text": f"{where}, seed{'s' if len(ks) > 1 else ''} {', '.join(map(str, ks))} "
                                     f"of {len(rec['runs'])}: {msg}"})
        if rec["repeats_skipped"]:
            rec["note"] = f"first run took over {REPEAT_MAX_SECONDS} s, so it ran under one seed only"
    if dontrun:
        r = run(dontrun, FULL_LIMIT, seed=seeds[0])
        rec["dontrun"] = r
        if not r.get("timed_out") and not r.get("error") and not r.get("warnings"):
            dest = "\\donttest" if (r.get("elapsed") or 0) > CRAN_SECONDS else "plain code"
            problems.append({"kind": "example-dontrun-runs", "part": "dontrun", "seeds": [seeds[0]],
                             "text": f"the \\dontrun code runs clean ({r.get('elapsed') or 0:.1f} s): CRAN allows "
                                     f"\\dontrun only for code that cannot run in a check; move it to {dest}"})
    rec["problems"] = problems
    return rec


# Problems that make a page a fix-step unit; the slow \\donttest note alone does not.
FIX_KINDS = {"example-error", "example-warning", "example-time-limit", "example-cran-time",
             "example-cpu-ratio", "example-dontrun-runs", "published-example-output"}


def clean(rec):
    """No error, warning, time-out or CRAN timing problem (a slow \\donttest part is allowed)."""
    return not [p for p in rec.get("problems", []) if p["kind"] != "example-donttest-time"]


# ---------------------------------------------------------------- published reference pages

def fetch(url, timeout=30):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read().decode("utf-8", "replace")


def reference_pages(index_html):
    """Page names (without .html) linked from the pkgdown reference index."""
    names = re.findall(r'href="([A-Za-z0-9_.-]+)\.html"', index_html)
    return sorted({n for n in names if n != "index"})


def example_output_problems(page_html):
    """The `#> Error` / `#> Warning` lines in a pkgdown page's Examples section."""
    m = re.search(r'id="ref-examples"', page_html)
    if not m:
        return []
    sec = page_html[m.end():]
    end = re.search(r"</main>|<h2[ >]", sec)
    sec = sec[:end.start()] if end else sec
    out = []
    for raw in re.findall(r'<span class="r-(?:err|wrn)[^"]*">(.*?)</span>\s*(?:\n|$)', sec, re.S):
        text = html.unescape(re.sub(r"<[^>]+>", "", raw)).strip()
        if re.match(r"#>\s*(Error|Warning)", text):
            out.append(re.sub(r"\s+", " ", text))
    # pkgdown also prints a multi-line message one `#>` span per line; catch stray error lines
    if not out:
        for line in html.unescape(re.sub(r"<[^>]+>", "", sec)).splitlines():
            if re.match(r"\s*#>\s*(Error|Warning)", line):
                out.append(re.sub(r"\s+", " ", line.strip()))
    return out


def rd_lookup(repo):
    """Map a page name / topic / alias to the Rd file (repo-relative)."""
    look = {}
    for p in sorted(Path(repo, sh.MAN_DIR).glob("*.Rd")):
        rel = p.relative_to(repo).as_posix()
        look.setdefault(p.stem, rel)
        t = p.read_text(encoding="utf-8", errors="replace")
        nm = sh.rd_name(t)
        if nm:
            look.setdefault(nm, rel)
        for a in re.findall(r"^\\alias\{([^}]*)\}", t, re.M):
            look.setdefault(a, rel)
    return look


def published_example_problems(repo, fetcher=fetch, delay=PAGE_DELAY):
    """{rd rel path: [problem lines]} from the published reference pages, plus a status note."""
    try:
        index = fetcher(REFERENCE_URL)
    except (urllib.error.URLError, OSError, ValueError) as e:
        return {}, f"published reference pages NOT CHECKED: could not read {REFERENCE_URL} ({e})"
    look = rd_lookup(repo)
    found, failed = {}, 0
    for i, page in enumerate(reference_pages(index)):
        if i and delay:
            time.sleep(delay)
        try:
            body = fetcher(REFERENCE_URL + page + ".html")
        except (urllib.error.URLError, OSError, ValueError):
            failed += 1
            continue
        hits = example_output_problems(body)
        if hits:
            rd = look.get(page) or f"{sh.MAN_DIR}/{page}.Rd"
            found.setdefault(rd, []).extend(hits)
    note = f"published reference pages checked ({len(reference_pages(index))})"
    if failed:
        note += f"; {failed} could not be read"
    return found, note


# ---------------------------------------------------------------- spelling helpers

def identifiers(repo):
    """Names EDI itself defines or uses in code: exports, Rd aliases, code tokens of R/EDI/R/*.R."""
    ids = set()
    for p in Path(repo, sh.R_DIR).glob("*.R"):
        for line in p.read_text(encoding="utf-8", errors="replace").splitlines():
            if re.match(r"^\s*#", line):
                continue
            code = re.sub(r"#.*$", "", line)
            ids.update(re.findall(r"[A-Za-z][A-Za-z0-9_.]*", code))
    ns = Path(repo, sh.PKG, "NAMESPACE")
    if ns.exists():
        ids.update(re.findall(r"export\(([^)]+)\)", ns.read_text()))
    for p in Path(repo, sh.MAN_DIR).glob("*.Rd"):
        ids.update(re.findall(r"^\\alias\{([^}]*)\}", p.read_text(encoding="utf-8", errors="replace"), re.M))
    return ids


def split_spelling(words, ids, seeding):
    """(words to add to the WORDLIST, words to report).

    Identifiers are always added. When the WORDLIST does not exist yet (seeding), every other word
    is added too, except likely typos: lower case, found once, not an identifier. The owner reviews
    the seeded list in the PR."""
    add, report = [], []
    for w in words:
        word, found = w["word"], w.get("found") or []
        base = re.sub(r"'s$", "", word)
        if word in ids or base in ids:
            add.append(word)
        elif seeding and not (word.islower() and len(found) <= 1):
            add.append(word)
        else:
            report.append(w)
    return add, report


def merge_wordlist(existing_text, words):
    have = [l.strip() for l in (existing_text or "").splitlines() if l.strip()]
    allw = sorted(set(have) | set(words), key=lambda s: (s.lower(), s))
    return "\n".join(allw) + "\n", [w for w in sorted(set(words)) if w not in set(have)]


# ---------------------------------------------------------------- mechanical

def mechanical(ctx):
    ctx.workdir.mkdir(parents=True, exist_ok=True)
    status, findings = [], []
    rel = lambda f: f"{sh.MAN_DIR}/{f}" if f and not f.startswith("R/") else f

    if not sh.have_r():
        status.append("R is not available in this job: checkRd, links, codoc, examples and spelling were NOT RUN")
        static = None
    else:
        static, err = run_static(ctx)
        if static is None:
            status.append(err)
    if static:
        status += [str(n) for n in static.get("notes", [])]
        for f, msgs in sorted((static.get("checkrd") or {}).items()):
            for m in msgs:
                findings.append({"unit": rel(f), "kind": "checkrd", "text": f"`{f}`: {m}"})
        for x in static.get("xrefs") or []:
            findings.append({"unit": rel(x["rd"]), "kind": "link",
                             "text": f"`{x['rd']}`: {x['kind']}: " + ", ".join(f"`{t}`" for t in x["targets"])})
        seen = set()
        for x in static.get("undeclared_link_packages") or []:
            key = (x["rd"], x["package"], x["target"])
            if key in seen:
                continue
            seen.add(key)
            findings.append({"unit": rel(x["rd"]), "kind": "link",
                             "text": f"`{x['rd']}`: links to `{x['target']}` in package `{x['package']}`, which "
                                     f"EDI does not declare (is the link written `\\link[pkg]{{topic}}` by mistake?)"})
        for c in static.get("codoc") or []:
            findings.append({"unit": rel(c.get("rd") or "codoc"), "kind": "codoc",
                             "text": f"{c['check']}: " + c["text"].replace("\n", " / ")})

    # examples
    examples = {}
    if static and static.get("examples"):
        ok, why = edi_loads()
        if not ok:
            status.append("examples NOT RUN: library(EDI) fails in this job: " + why.splitlines()[-1] if why
                          else "examples NOT RUN: library(EDI) fails in this job")
        else:
            with cf.ThreadPoolExecutor(max_workers=WORKERS) as pool:
                futs = {pool.submit(check_example, e.get("cran"), e.get("full"), dontrun=e.get("dontrun_file")): e
                        for e in static["examples"]}
                for fut in cf.as_completed(futs):
                    e = futs[fut]
                    try:
                        rec = fut.result()
                    except Exception as ex:  # noqa: BLE001 - one page must not stop the rest
                        rec = {"problems": [{"kind": "example-error", "part": "?", "seeds": [],
                                             "text": f"could not run: {ex}"}], "runs": []}
                    rec.update({"rd": e["rd"], "cran_file": e.get("cran"), "full_file": e.get("full"),
                                "dontrun_file": e.get("dontrun_file"), "donttest": e.get("donttest")})
                    examples[rel(e["rd"])] = rec
            examples = dict(sorted(examples.items()))
            status.append(f"examples run: {len(examples)} pages, the complete block under up to {N_SEEDS} seeds "
                          f"(repeats skipped for {sum(1 for r in examples.values() if r.get('repeats_skipped'))} "
                          f"slow pages, run once)")
    # timing history, kept in the manifest on the notes branch: report an example that got much slower
    m = ctx.notes.manifest()
    old_t = m.get("example_timings") or {}
    new_t = {}
    for rd, rec in examples.items():
        t = {}
        if rec.get("cran") and rec["cran"].get("elapsed") is not None:
            t["cran"] = rec["cran"]["elapsed"]
            t["cran_cpu"] = rec["cran"].get("cpu")
        if rec.get("donttest_seconds") is not None:
            t["full"] = rec["donttest_seconds"]
        new_t[rd] = t
        for part, v in t.items():
            if part not in SLOWER_MIN or v is None:
                continue
            prev = (old_t.get(rd) or {}).get(part)
            if prev and v > SLOWER_FACTOR * prev and v - prev > SLOWER_MIN[part]:
                rec.setdefault("problems_info", []).append(part)
                findings.append({"unit": rd, "kind": "example-slower",
                                 "text": f"`{Path(rd).name}`: example ({'outside' if part == 'cran' else 'with'} "
                                         f"\\donttest) took {v:.1f} s, was {prev:.1f} s"})
    if new_t:
        m["example_timings"] = {**old_t, **new_t}
        ctx.notes.save_manifest(m)
        ctx.manifest["example_timings"] = m["example_timings"]

    # published reference pages
    published, note = published_example_problems(ctx.repo)
    status.append(note)
    for rd, lines in sorted(published.items()):
        for line in lines:
            findings.append({"unit": rd, "kind": "published-example-output",
                             "text": f"`{Path(rd).name}`: the published reference page shows `{line}`"})

    for rd, rec in examples.items():
        for p in rec.get("problems", []):
            findings.append({"unit": rd, "kind": p["kind"], "text": f"`{Path(rd).name}`: {p['text']}"})

    # spelling
    words = {"seed": False, "add": []}
    if static and static.get("spelling_engine") not in (None, "none"):
        seeding = not static.get("wordlist_exists")
        add, report = split_spelling(static.get("spelling") or [], identifiers(ctx.repo), seeding)
        words = {"seed": seeding, "add": sorted(set(add)), "engine": static.get("spelling_engine")}
        for w in report:
            locs = w.get("found") or []
            findings.append({"unit": f"{sh.MAN_DIR}/{locs[0].split(':')[0]}" if locs else "spelling",
                             "kind": "spelling",
                             "text": f"unknown word `{w['word']}`: " + ", ".join(locs[:6]) +
                                     (f" and {len(locs) - 6} more" if len(locs) > 6 else "")})

    failing = {rd: {"problems": [p["text"] for p in rec.get("problems", [])],
                    "parts": sorted({p["part"] for p in rec.get("problems", []) if p["kind"] in FIX_KINDS})}
               for rd, rec in examples.items()
               if any(p["kind"] in FIX_KINDS for p in rec.get("problems", []))}
    for rd, lines in published.items():
        failing.setdefault(rd, {"problems": []})["published"] = lines
    sh.write_json(ctx.workdir / "rd_examples.json", examples)
    sh.write_json(ctx.workdir / "rd_failing.json", failing)
    sh.write_json(ctx.workdir / "rd_wordlist.json", words)
    sh.write_json(ctx.workdir / "rd_status.json", status)
    return findings


# ---------------------------------------------------------------- units

def _signature(text, block, n=3):
    lines = text.split("\n")
    return "\n".join(lines[block.end:block.end + n])


def _workdir_rel(ctx, p):
    """A path in ctx.workdir as the agent sees it (.audit-work/...)."""
    try:
        return ".audit-work/" + Path(p).resolve().relative_to(ctx.workdir.resolve()).as_posix()
    except (ValueError, OSError, TypeError):
        return None


def units(ctx):
    idx = sh.RoxygenIndex(ctx.repo)
    failing = sh.read_json(ctx.workdir / "rd_failing.json", {}) or {}
    examples = sh.read_json(ctx.workdir / "rd_examples.json", {}) or {}
    texts = {}
    out = {}
    for p in sorted(ctx.path(sh.MAN_DIR).glob("*.Rd")):
        rel = p.relative_to(ctx.repo).as_posix()
        rd_text = p.read_text(encoding="utf-8", errors="replace")
        blocks = idx.blocks_for_rd(rel, rd_text)
        deps_parts = []
        for b in blocks:
            t = texts.setdefault(b.path, ctx.read(b.path) or "")
            deps_parts += [b.text(), _signature(t, b)]
        srcs = sh.rd_sources(rd_text)
        context = {
            "rd_file": rel,
            "sources": srcs,
            "roxygen_blocks": sh.blocks_context(blocks),
            "editable": bool(blocks) and not (set(srcs) & sh.GENERATED_R),
        }
        rec = examples.get(rel)
        if rec:
            context["example_run"] = {"clean": not rec.get("problems"),
                                      "elapsed_outside_donttest": (rec.get("cran") or {}).get("elapsed"),
                                      "seeds_run": len(rec.get("runs") or [])}
        h = ac.text_hash(rd_text)
        if rel in failing:
            f = failing[rel]
            ex_blocks = [b for b in blocks if "examples" in b.tags]
            context["failing_example"] = {
                "problems": f.get("problems", []),
                "published_page_output": f.get("published", []),
                "examples_source": [{"file": b.path, "lines": "%d-%d" % sh.tag_range(texts[b.path], b, "examples")}
                                    for b in ex_blocks if sh.tag_range(texts[b.path], b, "examples")],
                "extracted_code": {k: _workdir_rel(ctx, (rec or {}).get(k)) for k in ("cran_file", "full_file")
                                   if (rec or {}).get(k)},
                "has_dontrun": bool((rec or {}).get("dontrun") is not None),
                "cpu_outside_donttest": ((rec or {}).get("cran") or {}).get("cpu"),
                "donttest_seconds": (rec or {}).get("donttest_seconds"),
                "failing_part": {"cran": "outside \\donttest (CRAN runs it by default)",
                                 "full": "inside \\donttest", "dontrun": "inside \\dontrun"}.get(
                    (f.get("parts") or ["?"])[0], "see published_page_output") if len(f.get("parts") or []) <= 1
                    else "several parts: " + ", ".join(f["parts"]),
                "elapsed": {"outside_donttest": ((rec or {}).get("cran") or {}).get("elapsed"),
                            "complete_block_by_seed": {str(r.get("seed")): r.get("elapsed")
                                                       for r in (rec or {}).get("runs", [])}},
                "usage": sh.rd_section(rd_text, "usage", 3000),
                "arguments": sh.rd_section(rd_text, "arguments", 4000),
            }
            # A failing page is re-read every run while it fails: its hash carries the run date.
            h = ac.text_hash(rd_text, "example fails", f, ctx.now.isoformat())
        out[rel] = {"hash": h, "deps": ac.text_hash(*deps_parts), "context": context}
    return out


# ---------------------------------------------------------------- apply

def _rejected_ids(ctx):
    return {h["id"] for h in ctx.notes.findings() if h.get("status") == "rejected"}


def text_fix_id(unit, kind, old, new):
    return ac.finding_id("rd", unit, kind, f"replace “{sh.norm_ws(old)}” with “{sh.norm_ws(new)}”")


def example_fix_text(rd, block):
    return f"new @examples block for {rd} ({ac.text_hash(sh.norm_ws(block))})"


def _blocks_in(text, path, rd_rel, idx):
    """The Rd's blocks in `path`, re-parsed from the current `text` (line numbers move after edits)."""
    stems = {Path(rd_rel).stem}
    nm = sh.rd_name(idx.rd_text(rd_rel)) if hasattr(idx, "rd_text") else None
    if nm:
        stems.add(sh.nice_name(nm))
    return [b for b in sh.parse_blocks(text, path) if b.topic and sh.nice_name(b.topic) in stems]


class _Idx:
    def __init__(self, repo):
        self.repo = repo

    def rd_text(self, rel):
        try:
            return (self.repo / rel).read_text(encoding="utf-8", errors="replace")
        except OSError:
            return ""


def escape_examples(body):
    """What roxygen does to @examples text on its way into \\examples{}: escape a bare %."""
    return re.sub(r"(?<!\\)%", r"\\%", body)


def verify_example(ctx, rd_rel, body, run=None, extract=None):
    """Run a proposed @examples block the way the mechanical stage ran the original.

    Builds a one-topic Rd file around the block, extracts it with Rd2ex (with and without the
    \\donttest code), and runs it with check_example (time limits, CRAN's 5 s rule, every seed).
    Returns the check_example record (clean when "problems" is empty)."""
    extract = extract or extract_examples
    d = Path(tempfile.mkdtemp(prefix="rdfix_", dir=str(ctx.workdir)))
    stem = Path(rd_rel).stem
    rd = d / f"{stem}.Rd"
    rd.write_text(f"\\name{{{stem}}}\n\\alias{{{stem}}}\n\\title{{proposed example}}\n"
                  f"\\description{{proposed example}}\n\\examples{{\n{escape_examples(body.strip())}\n}}\n",
                  encoding="utf-8")
    e = extract(rd, d / "ex") or {}
    if not e.get("cran") and not e.get("full"):
        return {"problems": [{"kind": "example-error", "part": "?", "seeds": [],
                              "text": "the proposed block could not be extracted with Rd2ex (unbalanced braces?)"}]}
    rec = check_example(e.get("cran"), e.get("full"), run=run, limit=VERIFY_SECONDS)
    if not has_plain_code(e.get("cran"), body):
        rec["no_plain_part"] = True
    return rec


def has_plain_code(cran_file, body):
    """True if the block has code CRAN runs by default (outside \\donttest and \\dontrun)."""
    if cran_file and Path(cran_file).exists():
        lines = Path(cran_file).read_text(encoding="utf-8", errors="replace").splitlines()
        return any(l.strip() and not l.lstrip().startswith("#") for l in lines)
    return not re.match(r"^\s*\\(donttest|dontrun)\{.*\}\s*$", body or "", re.S)


def apply(ctx, results, mech, run=None, extract=None, roxygen=None, checkrd=None):
    status = sh.read_json(ctx.workdir / "rd_status.json", []) or []
    failing = sh.read_json(ctx.workdir / "rd_failing.json", {}) or {}
    words = sh.read_json(ctx.workdir / "rd_wordlist.json", {}) or {}
    rejected = _rejected_ids(ctx)
    idx = _Idx(ctx.repo)
    applied, human, proposed, edited = [], [], [], set()
    skipped_rejected = 0

    # 1. wordlist additions (identifiers; the whole seed on the first run)
    if words.get("add"):
        wl_rel = f"{sh.PKG}/inst/WORDLIST"
        wl = ctx.path(wl_rel)
        text, new = merge_wordlist(ctx.read(wl_rel), words["add"])
        if new:
            wl.parent.mkdir(parents=True, exist_ok=True)
            wl.write_text(text)
            if words.get("seed"):
                applied.append(f"`{wl_rel}`: created and seeded with {len(new)} words the spell check flags "
                               f"today (review the list: a typo in it would be silenced)")
            else:
                applied.append(f"`{wl_rel}`: added EDI's own terms " + ", ".join(f"`{w}`" for w in new[:30]) +
                               (f" and {len(new) - 30} more" if len(new) > 30 else ""))
            for w in (new if not words.get("seed") else new[:1]):
                proposed.append({"unit": wl_rel, "kind": "wordlist",
                                 "text": "seed the WORDLIST" if words.get("seed") else f"add `{w}` to the WORDLIST",
                                 "applied_file": wl_rel, "applied_text": w})

    findings = []
    for r in results:
        for f in r.get("findings") or []:
            findings.append(f)
    # example fixes first: they replace whole sections, the sentence fixes then re-locate their text
    findings.sort(key=lambda f: 0 if f.get("kind") == EXAMPLE_KIND else 1)

    for f in findings:
        unit, kind = f.get("unit", ""), f.get("kind", "")
        rd_name = Path(unit).name
        rd_text = idx.rd_text(unit)
        srcs = [s for s in sh.rd_sources(rd_text) if s not in sh.GENERATED_R]
        if kind == EXAMPLE_KIND:
            body = f.get("example_block") or ""
            cause = f.get("cause") or f.get("text") or ""
            fid = ac.finding_id("rd", unit, kind, example_fix_text(unit, body))
            if fid in rejected:
                skipped_rejected += 1
                continue
            if unit not in failing:
                human.append(ac.decision(f"`{rd_name}`: example fix proposed for a page whose example did not fail: {cause}", unit=unit, key="example"))
                continue
            shown = f"Cause given: {cause}\n\n```r\n{body.strip()}\n```"
            if re.search(r"\b(try|tryCatch|suppressWarnings|suppressMessages)\s*\(", body):
                human.append(ac.decision(f"`{rd_name}`: proposed example NOT applied, it hides the problem "
                             f"(try/tryCatch/suppress*). {shown}", unit=unit, key="example"))
                continue
            reason = (f.get("dontrun_reason") or "none").strip()
            if "\\dontrun" in body and reason not in DONTRUN_REASONS:
                human.append(ac.decision(f"`{rd_name}`: proposed example NOT applied, it uses \\dontrun without one of the "
                             f"allowed reasons ({', '.join(sorted(DONTRUN_REASONS))}). {shown}", unit=unit, key="example"))
                continue
            targets = []
            for s in srcs:
                t = ctx.read(s) or ""
                targets += [(s, t, b) for b in _blocks_in(t, s, unit, idx) if "examples" in b.tags]
            if len(targets) != 1:
                human.append(ac.decision(f"`{rd_name}`: could not find exactly one @examples block for it in "
                             f"{', '.join(srcs) or 'its sources'} ({len(targets)} found). Cause: {cause}\n\n"
                             f"```r\n{body.strip()}\n```", unit=unit, key="example"))
                continue
            rec = verify_example(ctx, unit, body, run=run, extract=extract)
            if not clean(rec):
                human.append(ac.decision(f"`{rd_name}`: proposed example NOT applied, it does not pass the check "
                             f"(default part under {VERIFY_SECONDS} s, CPU/elapsed at most {CPU_RATIO:g}, every seed "
                             f"clean): " + "; ".join(p["text"] for p in rec["problems"]
                                                     if p["kind"] != "example-donttest-time") + f". {shown}", unit=unit, key="example"))
                continue
            if rec.get("no_plain_part") and not (f.get("plain_part_reason") or "").strip():
                human.append(ac.decision(f"`{rd_name}`: proposed example NOT applied, it has no plain code CRAN runs by "
                             f"default and gives no reason why none is possible. {shown}", unit=unit, key="example"))
                continue
            s, t, b = targets[0]
            new_t = sh.replace_tag_lines(t, b, "examples", body)
            ctx.path(s).write_text(new_t)
            edited.add(s)
            applied.append(f"`{s}` (`{rd_name}`): replaced the @examples block, verified clean under "
                           f"{len(rec.get('runs') or [])} seed(s). Cause: {cause}")
            proposed.append({"unit": unit, "kind": kind, "text": example_fix_text(unit, body),
                             "applied_file": s, "applied_text": sh.first_changed_line(t, new_t)})
            continue

        old, new = f.get("old_sentence") or "", f.get("new_sentence") or ""
        src = f.get("source_file") or (srcs[0] if len(srcs) == 1 else "")
        note = f"`{rd_name}` ({kind}): {f.get('text', '')}"
        if old and new:
            note += f"\n  - now: “{sh.norm_ws(old)}”\n  - suggested: “{sh.norm_ws(new)}”"
        if kind not in TEXT_KINDS or f.get("changes_claim") or not (old and new):
            human.append(ac.decision(note, unit=unit, key=kind))
            continue
        fid = text_fix_id(unit, kind, old, new)
        if fid in rejected:
            skipped_rejected += 1
            continue
        ok, why = sh.safe_text_fix(old, new)
        if not ok or src not in srcs:
            human.append(ac.decision(note + f"\n  - not applied automatically: {why or 'its source file is not editable'}", unit=unit, key=kind))
            continue
        t = ctx.read(src) or ""
        blocks = _blocks_in(t, src, unit, idx)
        n = sh.count_in_blocks(t, blocks, old)
        new_t = sh.replace_in_blocks(t, blocks, old, new) if n == 1 else None
        if new_t is None:
            human.append(ac.decision(note + f"\n  - not applied automatically: the sentence occurs {n} times in the "
                                f"roxygen source (needs exactly once)" if n != 1 else
                         note + "\n  - not applied automatically: the changed words straddle a line break", unit=unit, key=kind))
            continue
        ctx.path(src).write_text(new_t)
        edited.add(src)
        applied.append(f"`{src}` (`{rd_name}`, {kind}): “{sh.norm_ws(old)}” → “{sh.norm_ws(new)}”")
        proposed.append({"unit": unit, "kind": kind,
                         "text": f"replace “{sh.norm_ws(old)}” with “{sh.norm_ws(new)}”",
                         "applied_file": src, "applied_text": sh.first_changed_line(t, new_t)})

    # 2. roxygen once, then check the pages it regenerated
    summary = []
    rox = (roxygen or sh.run_roxygen_once)(ctx.repo, sorted(edited))
    if rox.get("ran") or edited:
        summary.append(rox["note"])
    if rox.get("ran") and rox.get("kept"):
        rds = [ctx.path(p) for p in rox["kept"] if p.endswith(".Rd")]
        if rds:
            res = (checkrd or run_checkrd)(ctx, rds)
            if res is None:
                summary.append("checkRd on the regenerated pages could not run")
            elif res:
                summary.append("checkRd on the regenerated pages: " + "; ".join(
                    f"{k}: {' / '.join(v)}" for k, v in sorted(res.items())))
            else:
                summary.append(f"checkRd on the {len(rds)} regenerated page(s): clean")
    if skipped_rejected:
        summary.append(f"{skipped_rejected} proposal(s) left out: the owner rejected them before")
    summary += status
    return {"summary": "\n".join(f"- {s}" for s in summary) if summary else "",
            "applied": applied, "mechanical": [m["text"] for m in mech], "human": human, "proposed": proposed}


def run_checkrd(ctx, rd_paths):
    if not sh.have_r():
        return None
    out = ctx.workdir / "rd_selfcheck.json"
    sh.run_r([str(SCRIPT), "checkrd", str(out), *map(str, rd_paths)], timeout=600)
    d = sh.read_json(out)
    return None if d is None else (d.get("checkrd") or {})
