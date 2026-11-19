"""Dead-code audit (monthly, 2nd Monday; Claude checks the candidates).

Plan: R/package_metadata/new_feature_plans/v1_0_6/audit_jobs_framework.md (Part 4, "Dead code").

Mechanical stage: a symbol cross-reference built with regular expressions over the sources (no
compile, no R):

- R: every NAMESPACE export with no reference outside its own definition in R/EDI/R, the tests
  (R/EDI/tests, R/package_tests), R/benchmark, the vignettes, or an Rd \\examples section;
- C++: every function exported with an Rcpp attribute whose R wrapper nothing calls, and every
  free function defined at file scope in R/EDI/src with no reference in R/EDI/src, python/cpp or R/benchmark
  other than its definition and its declarations.

- Regions: code regions the untested-code audit (untested_code.py) could not reach through the public
  API, read from `untested-code/unreachable.json` on the audit-notes branch (unit `region:unt-<hex>`).
  The agent checks each one like any candidate: a path that reaches it makes it a false positive.

Claude stage: one unit per candidate. The agent rules out false positives (R6 methods called by
name, .Call targets, names built with paste() and called through do.call() or get(), Python
bindings under python/cpp, macros) and confirms the rest.

The PR rewrites CANDIDATES_FILE with the confirmed candidates. It removes no code. Deleting a line
of that file on the PR branch rejects the candidate, so it is not raised again.
"""
import json
import os
import re

import audit_common as ac

SPEC = {
    "period": "month",   # monthly job: the rotation cycle counts its monthly runs
    "name": "dead-code",
    "title": "Dead code",
    "report": "pr",
    "claude": True,
    "model": ac.SONNET,
    "batch_size": 8,
    "cycle_weeks": 26,     # a candidate found to be a false positive is looked at again about twice a year
    "max_batches": 8,
    "tools": "Read,Glob,Grep",
    "max_turns": 60,
}

CANDIDATES_FILE = "R/package_metadata/audits/dead_code_candidates.md"
R_SOURCE = "R/EDI/R"
R_USE_DIRS = ("R/EDI/R", "R/EDI/tests", "R/package_tests", "R/benchmark", "R/EDI/vignettes")
CPP_DIRS = ("R/EDI/src", "python/cpp", "R/benchmark")
RCPP_CPP = "R/EDI/src/RcppExports.cpp"
RCPP_R = "R/EDI/R/RcppExports.R"
CPP_EXT = (".cpp", ".cc", ".c", ".h", ".hpp")
R_EXT = (".R", ".r", ".Rmd", ".qmd")
NOT_FUNCTIONS = {"if", "for", "while", "switch", "return", "sizeof", "catch", "defined", "main",
                 "decltype", "static_assert", "alignof", "operator"}


# ---------------------------------------------------------------- reading the sources

def read_files(ctx, dirs, exts):
    out = {}
    for f in ac.tracked_files(*dirs, cwd=ctx.repo):
        if f.endswith(exts):
            text = ctx.read(f)
            if text is not None:
                out[f] = text
    return out


def strip_r_comment(line):
    """The code part of an R line: drops a # comment that is not inside a string."""
    q = None
    i = 0
    while i < len(line):
        c = line[i]
        if q:
            if c == "\\":
                i += 1
            elif c == q:
                q = None
        elif c in "\"'`":
            q = c
        elif c == "#":
            return line[:i]
        i += 1
    return line


def strip_cpp_comments(text):
    """Comments replaced by spaces (newlines kept, so line numbers stay right). Strings are kept."""
    out, i, n = [], 0, len(text)
    while i < n:
        c = text[i]
        if c == '"' or c == "'":
            j = i + 1
            while j < n and text[j] != c and text[j] != "\n":
                j += 2 if text[j] == "\\" else 1
            out.append(text[i:j + 1])
            i = j + 1
        elif text.startswith("//", i):
            j = text.find("\n", i)
            j = n if j < 0 else j
            out.append(" " * (j - i))
            i = j
        elif text.startswith("/*", i):
            j = text.find("*/", i + 2)
            j = n if j < 0 else j + 2
            out.append(re.sub(r"[^\n]", " ", text[i:j]))
            i = j
        else:
            out.append(c)
            i += 1
    return "".join(out)


def rd_examples(text):
    """The \\examples{...} sections of an Rd file (brace matched)."""
    out = []
    for m in re.finditer(r"\\examples\s*\{", text):
        depth, i = 1, m.end()
        while i < len(text) and depth:
            if text[i] == "\\" and i + 1 < len(text):
                i += 2
                continue
            depth += {"{": 1, "}": -1}.get(text[i], 0)
            i += 1
        out.append(text[m.end():i - 1])
    return "\n".join(out)


R_WORD = r"[A-Za-z_.][A-Za-z0-9_.]*"
CPP_WORD = r"[A-Za-z_][A-Za-z0-9_]*"


def word_index(texts, word=R_WORD):
    """{word: [(file, line_no, line)]} for every identifier-like word in the given texts."""
    idx = {}
    for f, text in texts.items():
        for no, line in enumerate(text.splitlines(), 1):
            for w in set(re.findall(word, line)):
                idx.setdefault(w, []).append((f, no, line))
    return idx


# ---------------------------------------------------------------- R exports

def namespace_exports(text):
    out = []
    for m in re.finditer(r"^export\(([^)]*)\)", text or "", re.M):
        for name in m.group(1).split(","):
            name = name.strip().strip("\"'`")
            if name:
                out.append(name)
    return out


def r_definitions(r_files):
    """{name: (file, line, kind)} for top-level assignments in R/EDI/R."""
    defs = {}
    pat = re.compile(r"^`?([A-Za-z.][A-Za-z0-9_.]*)`?\s*(?:=|<-)\s*(.*)$")
    for f, text in r_files.items():
        lines = text.splitlines()
        for no, line in enumerate(lines, 1):
            m = pat.match(line)
            if not m or m.group(1) in defs:
                continue
            rest = m.group(2) + " " + " ".join(lines[no:no + 2])
            if re.match(r"\s*(?:R6::)?R6Class\b|\s*define_inference_class\b|\s*(?:\w+::)?setRefClass\b", rest):
                kind = "class"
            elif re.match(r"\s*function\b", rest):
                kind = "function"
            else:
                kind = "object"
            defs[m.group(1)] = (f, no, kind)
    return defs


def r_uses(ctx):
    """Texts in which an R reference counts: code with comments removed, plus Rd \\examples."""
    texts = {}
    for f, text in read_files(ctx, R_USE_DIRS, R_EXT).items():
        if f == RCPP_R:
            continue
        if f.endswith((".Rmd", ".qmd")):
            texts[f] = text
        else:
            texts[f] = "\n".join(strip_r_comment(l) for l in text.splitlines())
    for f in ac.tracked_files("R/EDI/man", cwd=ctx.repo):
        if f.endswith(".Rd"):
            ex = rd_examples(ctx.read(f) or "")
            if ex:
                texts[f + " (examples)"] = ex
    return texts


def r_candidates(ctx, idx=None):
    r_files = read_files(ctx, (R_SOURCE,), (".R",))
    defs = r_definitions(r_files)
    idx = idx if idx is not None else word_index(r_uses(ctx))
    out = {}
    for name in namespace_exports(ctx.read("R/EDI/NAMESPACE")):
        where = defs.get(name)
        hits = [h for h in idx.get(name, []) if not (where and h[0] == where[0] and h[1] == where[1])]
        if hits:
            continue
        f, line, kind = where if where else ("", 0, "unknown")
        out[f"R:{name}"] = {"lang": "R", "name": name, "kind": f"exported R {kind}", "file": f, "line": line}
    return out


# ---------------------------------------------------------------- C++

DEF_RE = re.compile(
    r"^(?:template\s*<[^;{}]*?>\s*)?"
    r"(?:(?:static|inline|extern|constexpr|friend|\[\[[^\]]*\]\])\s+)*"
    r"(?P<ret>[A-Za-z_][\w:<>,\s\*&]*?[\s\*&])"
    r"(?P<name>[A-Za-z_]\w*)\s*\((?P<args>[^;{}]*)\)\s*(?:const\s*)?(?:noexcept\s*)?(?:->\s*[\w:<>\s]+)?\{",
    re.M)


def cpp_definitions(texts):
    """[(file, line, name)] for free functions defined at file scope (definition starts in column 0)."""
    out = []
    for f, text in texts.items():
        if f == RCPP_CPP:
            continue
        for m in DEF_RE.finditer(text):
            name = m.group("name")
            ret = m.group("ret").strip()
            start = m.start("name")
            if name in NOT_FUNCTIONS or text[max(0, start - 2):start] == "::":
                continue
            if re.search(r"\b(?:return|else|new|delete|throw|class|struct|enum|namespace|typedef|using)\b", ret):
                continue
            if "=" in ret or "(" in ret:
                continue
            out.append((f, text.count("\n", 0, start) + 1, name))
    return out


def rcpp_exports(rcpp_cpp):
    """{R name: C++ name} from RcppExports.cpp."""
    out = {}
    for m in re.finditer(r"RcppExport SEXP _EDI_(\w+)\(.*?\n(.*?)END_RCPP", rcpp_cpp or "", re.S):
        body = m.group(2)
        c = re.search(r"Rcpp::wrap\((\w+)\(", body) or re.search(r"^\s+(\w+)\([^\n]*\);\s*$", body, re.M)
        if c:
            out[m.group(1)] = c.group(1)
    return out


def is_declaration(line, name):
    m = re.match(rf"^\s*(?:template\s*<.*>\s*)?(?P<pre>[\w:<>,\s\*&]+?)[\s\*&]{re.escape(name)}\s*\(.*\)\s*(?:const\s*)?(?:noexcept\s*)?;\s*$",
                 line)
    if not m or not re.search(r"[A-Za-z_]", m.group("pre")):
        return False   # `name(x);` on its own line is a call, not a declaration
    return not re.search(r"\b(?:return|else|new|delete|throw|co_return)\b", m.group("pre"))


def cpp_candidates(ctx, r_idx=None):
    raw = read_files(ctx, CPP_DIRS, CPP_EXT)
    texts = {f: strip_cpp_comments(t) for f, t in raw.items()}
    cidx = word_index({f: t for f, t in texts.items() if f != RCPP_CPP}, CPP_WORD)
    r_idx = r_idx if r_idx is not None else word_index(r_uses(ctx))
    exports = rcpp_exports(raw.get(RCPP_CPP))
    exported_cpp = {c: r for r, c in exports.items()}
    defs = cpp_definitions({f: t for f, t in texts.items() if f.startswith("R/EDI/src/")})
    def_sites = {}
    for f, line, name in defs:
        def_sites.setdefault(name, set()).add((f, line))
    out = {}
    for f, line, name in defs:
        cpp_hits = [h for h in cidx.get(name, [])
                    if (h[0], h[1]) not in def_sites[name] and not is_declaration(h[2], name)]
        rname = exported_cpp.get(name)
        if rname:
            r_hits = r_idx.get(rname, [])
            if r_hits:
                continue
            kind = "Rcpp export with no R caller"
            note = (f"its R wrapper `{rname}()` (RcppExports.R) has no caller; "
                    + (f"{len(cpp_hits)} C++ reference(s), so the export may be unneeded rather than the function"
                       if cpp_hits else "no C++ reference either"))
        else:
            if cpp_hits:
                continue
            kind = "C++ function with no call site"
            note = "no reference in R/EDI/src, python/cpp or R/benchmark other than its definition and declarations"
        uid = f"cpp:{f}::{name}"
        if uid not in out:
            out[uid] = {"lang": "C++", "name": name, "kind": kind, "file": f, "line": line, "note": note,
                        "r_name": rname}
    return out


# ---------------------------------------------------------------- stages

UNTESTED_UNREACHABLE = "untested-code/unreachable.json"


def untested_candidates(ctx):
    """Regions the untested-code audit judged unreachable from the public API, as candidates."""
    root = getattr(ctx.notes, "root", None)
    if root is None:
        return {}
    try:
        data = json.loads((root / UNTESTED_UNREACHABLE).read_text())
    except (OSError, ValueError):
        return {}
    out = {}
    for rid, v in (data.items() if isinstance(data, dict) else []):
        f = v.get("file") or ""
        if not f or not v.get("first_line"):
            continue
        a, b = v["first_line"], v.get("last_line") or v["first_line"]
        out[f"region:{rid}"] = {
            "lang": "R" if f.endswith(R_EXT) else "C++", "name": f"{v.get('fn') or 'top level'} lines {a}-{b}",
            "kind": "unreachable region (untested-code audit)", "file": f, "line": a,
            "note": (f"The untested-code audit found no public path to lines {a}-{b}: {v.get('text', '')} "
                     f"Evidence: {v.get('evidence', '')}").strip()[:1500]}
    return out


def candidates(ctx):
    if getattr(ctx, "_dead_code_candidates", None) is None:
        r_idx = word_index(r_uses(ctx))
        c = r_candidates(ctx, r_idx)
        c.update(cpp_candidates(ctx, r_idx))
        c.update(untested_candidates(ctx))
        ctx._dead_code_candidates = c
    return ctx._dead_code_candidates


def snippet(ctx, f, line, n=40):
    """The definition: from its first line to the first closing brace in column 0, at most n lines."""
    text = ctx.read(f) if f else None
    if not text:
        return ""
    lines = text.splitlines()[max(0, line - 1):line - 1 + n]
    for i, l in enumerate(lines[1:], 1):
        if l.startswith("}"):
            return "\n".join(lines[:i + 1])
    return "\n".join(lines)


def finding_text(c):
    """The text of a confirmed candidate's finding: stable, so the owner's rejection sticks."""
    return f"{c['kind']}: {c['name']}"


def rejected_units(ctx):
    """Candidates whose confirmed finding the owner rejected (line deleted in the PR, or PR closed)."""
    bad = {h["id"] for h in ctx.notes.findings() if h.get("status") == "rejected"}
    return {u for u, c in candidates(ctx).items()
            if ac.finding_id(SPEC["name"], u, "dead-code", finding_text(c)) in bad}


def mechanical(ctx):
    return []


def units(ctx):
    out = {}
    skip = rejected_units(ctx)
    for uid, c in candidates(ctx).items():
        if uid in skip:
            continue
        snip = snippet(ctx, c["file"], c["line"])
        context = {k: v for k, v in c.items() if v not in (None, "")}
        context["definition"] = snip
        context["searched"] = ("the untested-code audit's agent, reading the code (no test reached these lines)"
                               if uid.startswith("region:") else
                               f"mechanical word search found no reference in: {', '.join(R_USE_DIRS)}, "
                               "R/EDI/man \\examples" if c["lang"] == "R"
                               else f"mechanical word search found no call site in: {', '.join(CPP_DIRS)}"
                               + (f"; and none for its R wrapper in {', '.join(R_USE_DIRS)}" if c.get("r_name") else ""))
        out[uid] = {"hash": ac.text_hash(c["kind"], snip, c.get("note", "")), "context": context}
    return out


LINE_RE = re.compile(r"^- `(?P<unit>[^`]+)`")


def candidate_line(unit, c, text):
    loc = f"{c['file']}:{c['line']}" if c.get("file") else "definition not found"
    return f"- `{unit}` ({c['kind']}, {loc}): {text}"


def render(lines):
    md = ["# Dead-code candidates", "",
          "Written by the dead-code audit (`.github/workflows/audit-dead-code.yml`) and rewritten on each "
          "run: candidates found by a mechanical cross-reference and confirmed by an agent. Nothing has been "
          "removed. To reject a candidate, delete its line in the audit PR: it will not be raised again.", ""]
    md += sorted(lines) if lines else ["No confirmed candidates."]
    return "\n".join(md) + "\n"


def apply(ctx, results, mech):
    cands = candidates(ctx)
    checked, confirmed, unsure, false_pos = set(), {}, [], 0
    for r in results:
        checked.update(r.get("units_checked") or r.get("_units") or [])
        for f in r.get("findings") or []:
            u = f.get("unit")
            if u not in cands:
                continue
            kind = f.get("kind")
            if kind == "confirmed":
                confirmed[u] = f
            elif kind == "unsure":
                unsure.append(f)
            else:
                false_pos += 1
    # Lines confirmed in an earlier run whose candidate was not re-read this time stay in the file.
    old = ctx.read(CANDIDATES_FILE)
    rejected = rejected_units(ctx)
    confirmed = {u: f for u, f in confirmed.items() if u not in rejected}
    kept, listed = {}, {}
    for line in (old or "").splitlines():
        m = LINE_RE.match(line)
        if m and m.group("unit") in cands:
            listed[m.group("unit")] = line
            if m.group("unit") not in checked | rejected:
                kept[m.group("unit")] = line
    lines, proposed, human = dict(kept), [], []
    for u, f in confirmed.items():
        c = cands[u]
        text = re.sub(r"\s+", " ", f.get("text", "")).strip() or "confirmed"
        # A candidate already listed keeps its line: re-wording it would open a PR with no news.
        line = listed.get(u) or candidate_line(u, c, text)
        lines[u] = line
        proposed.append({"unit": u, "kind": "dead-code", "text": finding_text(c),
                         "applied_file": CANDIDATES_FILE, "applied_text": f"- `{u}` ",
                         "merged_status": "listed"})   # merging lists it; nothing is removed
    # Every listed candidate is also a decision for the owner (remove the code, or dismiss the id), so
    # it reaches the audit-decisions issue and can be cited or dismissed. It leaves the list when the
    # code is gone (no longer a candidate) or its line is deleted in an audit PR (rejected).
    for u in sorted(lines):
        c = cands[u]
        loc = f"`{c['file']}:{c['line']}`" if c.get("file") else "definition not found"
        human.append(ac.decision(f"Confirmed dead code, `{c['name']}` ({c['kind']}, {loc}): remove it, or "
                                 "dismiss this id if it must stay.", unit=u, key="confirmed"))
    for f in unsure:
        c = cands[f["unit"]]
        text = re.sub(r"\s+", " ", f.get("text", "")).strip()
        human.append(ac.decision(f"Unsure, `{c['name']}` ({c['kind']}, `{c['file']}:{c['line']}`): {text}", unit=f.get("unit"), key="unsure"))
    applied = []
    new = render(list(lines.values()))
    if (lines or old is not None) and new != old:
        ctx.path(CANDIDATES_FILE).parent.mkdir(parents=True, exist_ok=True)
        ctx.path(CANDIDATES_FILE).write_text(new)
        applied.append(f"`{CANDIDATES_FILE}`: {len(lines)} confirmed candidate(s) listed")
    not_read = len([u for u in cands if u not in checked])
    by_lang = {}
    for c in cands.values():
        by_lang[c["kind"]] = by_lang.get(c["kind"], 0) + 1
    summary = [f"Mechanical candidates: {len(cands)} ("
               + (", ".join(f"{v} {k}" for k, v in sorted(by_lang.items())) or "none") + ").",
               f"Agents confirmed {len(confirmed)}, ruled out {false_pos}, were unsure of {len(unsure)}; "
               f"{not_read} candidate(s) not read this run (rotation, cap, or a batch NOT RUN).",
               "Nothing was removed."]
    return {"summary": "\n".join(summary), "applied": applied, "mechanical": [], "human": human,
            "proposed": proposed}
