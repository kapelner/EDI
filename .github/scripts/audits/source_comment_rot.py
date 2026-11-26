"""Source comment rot audit (monthly, 4th Sunday; Claude on changed files + rotation).

Plan: R/package_metadata/new_feature_plans/v1_0_6/audit_jobs_framework.md (Part 4, "Source comment rot").

Unit: one source file in R/EDI/R or R/EDI/src (hash: its content; no dependencies). The generated
RcppExports files are left out.

Mechanical stage: TODO / FIXME / XXX notes (a comment that starts with one of the words; a citation
such as `v1.0.7-TODO-34` is not a note) that no release TODO cites. A note is cited when it, or the
comment lines right after it, names a TODO (`v<version>-TODO-<n>`, `TODO-<n>`), or when a release or
plan file names the source file together with the note's line number or its text.

Claude stage: comments that contradict the code beside them (a stated default, tolerance, formula,
or always/never claim the code does not do). The agent returns the exact old comment line and the
corrected one.

Apply: a comment line is replaced only when the old line occurs exactly once in the file and the
file with its comments removed is the same before and after the change (so only the comment
changed). A contradiction where the code may be the wrong side goes to "Needs a human".
"""
import re

import audit_common as ac
from audits import _doc_audit_shared as sh

SPEC = {
    "period": "month",   # monthly job: the rotation cycle counts its monthly runs
    "name": "source-comment-rot",
    "title": "Source comment rot",
    "report": "pr",
    "claude": True,
    "model": ac.SONNET,
    "batch_size": 5,       # source files are long; five per agent leaves turns to read them
    "cycle_weeks": 8,
    "max_batches": 12,
    "tools": "Read,Glob,Grep",
    "max_turns": 80,
}

SOURCE_DIRS = ("R/EDI/R", "R/EDI/src")
SOURCE_EXT = (".R", ".cpp", ".cc", ".c", ".h", ".hpp")
GENERATED = {"R/EDI/R/RcppExports.R", "R/EDI/src/RcppExports.cpp"}
PLAN_GLOBS = ("R/package_metadata/future_release_plans/release_v*.md",
              "R/package_metadata/new_feature_plans/**/*.md",
              "R/package_metadata/bug_fix_plans/**/*.md")
NOTE_RE = re.compile(r"(?:#'?|//+|/\*+|^\s*\*)\s*(TODO|FIXME|XXX)\b(?!-\d)")
CITATION_RE = re.compile(r"\bTODO-\d+\b")


def is_r(path):
    return path.endswith(".R")


# ---------------------------------------------------------------- comments

def strip_r_comments(text):
    """Each line's # comment (outside a string) replaced by nothing; lines kept."""
    out = []
    for line in text.split("\n"):
        q, i, cut = None, 0, len(line)
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
                cut = i
                break
            i += 1
        out.append(line[:cut])
    return "\n".join(out)


def strip_cpp_comments(text):
    """// and /* */ comments replaced by spaces; strings and newlines kept."""
    out, i, n = [], 0, len(text)
    while i < n:
        c = text[i]
        if c in "\"'":
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


def code_only(path, text):
    """The file with its comments removed and trailing blanks dropped: what the compiler or R sees."""
    stripped = strip_r_comments(text) if is_r(path) else strip_cpp_comments(text)
    return "\n".join(l.rstrip() for l in stripped.split("\n"))


def comment_lines(path, text):
    """Number of lines that hold a comment."""
    code = code_only(path, text).split("\n")
    return sum(1 for a, b in zip(text.split("\n"), code) if a.rstrip() != b)


# ---------------------------------------------------------------- notes

def source_files(ctx):
    return [f for f in ac.tracked_files(*SOURCE_DIRS, cwd=ctx.repo)
            if f.endswith(SOURCE_EXT) and f not in GENERATED]


def plan_lines(ctx):
    out = []
    for g in PLAN_GLOBS:
        for p in sorted(ctx.repo.glob(g)):
            if "finished_features" in p.parts:
                continue
            try:
                out += p.read_text(errors="replace").splitlines()
            except OSError:
                pass
    return out


def norm(s):
    return re.sub(r"\s+", " ", s).strip().lower()


def find_notes(path, text):
    """[(line number, note text, the note and up to 3 comment lines after it)]."""
    lines = text.split("\n")
    code = code_only(path, text).split("\n")
    out = []
    for i, line in enumerate(lines):
        m = NOTE_RE.search(line)
        if not m or line.rstrip() == code[i]:        # not inside a comment (e.g. in a string)
            continue
        if code[i].strip() and m.start() < len(code[i].rstrip()):
            continue
        block = [line]
        for j in range(i + 1, min(i + 4, len(lines))):
            if code[j].strip() or lines[j].rstrip() == code[j] or NOTE_RE.search(lines[j]):
                break   # code, a blank line, or the next note ends this note
            block.append(lines[j])
        out.append((i + 1, line[m.start():].strip(), "\n".join(block)))
    return out


def note_findings(ctx, files=None, plans=None):
    plans = plans if plans is not None else plan_lines(ctx)
    out = []
    for path in files if files is not None else source_files(ctx):
        text = ctx.read(path) or ""
        base = path.rsplit("/", 1)[-1]
        mentions = [norm(l) for l in plans if base in l]
        for line_no, note, block in find_notes(path, text):
            if CITATION_RE.search(block):
                continue
            body = norm(re.sub(r"^(?:#'?|//+|/\*+|\*)\s*", "", note))[:40]
            if any(f"{base.lower()}:{line_no}" in m or (len(body) >= 12 and body in m) for m in mentions):
                continue
            out.append({"unit": path, "kind": "uncited-note", "line": line_no,
                        "text": f"`{note[:160]}` has no release TODO citing it"})
    return out


# ---------------------------------------------------------------- stages

def mechanical(ctx):
    return note_findings(ctx)


def units(ctx):
    notes_by_file = {}
    for f in note_findings(ctx):
        notes_by_file.setdefault(f["unit"], []).append(f"line {f['line']}: {f['text']}")
    out = {}
    for path in source_files(ctx):
        text = ctx.read(path) or ""
        out[path] = {"hash": ac.text_hash(text), "context": {
            "file": path, "language": "R" if is_r(path) else "C++",
            "lines": text.count("\n") + 1, "comment_lines": comment_lines(path, text),
            "uncited_notes": notes_by_file.get(path, [])}}
    return out


def try_replace(ctx, path, old, new):
    """Replace one comment line. Returns None when applied, else why not."""
    if "\n" in old or "\n" in new:
        return "old and new must each be one line"
    if old.rstrip() == new.rstrip():
        return "the new line is the same as the old one"
    text = ctx.read(path)
    if text is None:
        return "the file does not exist"
    lines = text.split("\n")
    hits = [i for i, l in enumerate(lines) if l.rstrip() == old.rstrip()]
    if len(hits) != 1:
        return f"the old line occurs {len(hits)} times in the file, not exactly once"
    i = hits[0]
    if lines[i].rstrip() == code_only(path, text).split("\n")[i]:
        return "the old line holds no comment"
    changed = lines[:i] + [new.rstrip()] + lines[i + 1:]
    new_text = "\n".join(changed)
    if code_only(path, text) != code_only(path, new_text):
        return "the change touches code, not only the comment"
    ctx.path(path).write_text(new_text)
    return None


RCPP_EXPORTS_R = "R/EDI/R/RcppExports.R"


def roxygen_sources(path, old, new):
    """The roxygen sources a one-line edit changes, for run_roxygen_once: an R file for a `#'` line;
    for a `//'` line in C++, RcppExports.R too, since compileAttributes copies it there and the Rd
    header names RcppExports.R."""
    lines = (old.lstrip(), new.lstrip())
    if path.endswith(".R") and any(x.startswith("#'") for x in lines):
        return {path}
    if not path.endswith(".R") and any(x.startswith("//'") for x in lines):
        return {path, RCPP_EXPORTS_R}
    return set()


def apply(ctx, results, mech, roxygen=None):
    known = set(source_files(ctx))
    applied, human, proposed, edited = [], [], [], set()
    for r in results:
        for f in r.get("findings") or []:
            path, old, new = f.get("unit", ""), f.get("old", ""), f.get("new", "")
            why = re.sub(r"\s+", " ", f.get("text", "")).strip()
            where = f"`{path}:{f.get('line', '?')}`"
            if path not in known:
                human.append(ac.decision(f"{where}: {why} (not a source file this audit covers; not applied)", unit=f.get("unit"), key="contradiction"))
                continue
            if f.get("kind") != "contradiction":
                human.append(ac.decision(f"{where}: the code may be the wrong side: {why} Comment: `{old.strip()}`"
                             + (f"; suggested: `{new.strip()}`" if new.strip() else ""), unit=f.get("unit"), key="contradiction"))
                continue
            err = try_replace(ctx, path, old, new)
            if err:
                human.append(ac.decision(f"{where}: {why} Not applied: {err}. Suggested: `{old.strip()}` -> `{new.strip()}`", unit=f.get("unit"), key="contradiction"))
                continue
            edited |= roxygen_sources(path, old, new)
            applied.append(f"{where}: `{old.strip()}` -> `{new.strip()}` ({why})")
            proposed.append({"unit": path, "kind": "contradiction", "text": f"{old.strip()} -> {new.strip()}",
                             "reason": why, "applied_file": path, "applied_text": new.strip()})
    # A corrected roxygen line changes its Rd page: regenerate it here so this PR carries both, as the
    # rd audit does, instead of leaving the page for the generated-drift audit to propose later.
    rox = (roxygen or sh.run_roxygen_once)(ctx.repo, sorted(edited))
    rd_pages = [x for x in rox.get("kept", []) if x.endswith(".Rd")]
    applied += [f"`{x}`: regenerated from the corrected roxygen" for x in rd_pages]
    mechanical = [f"`{f['unit']}:{f['line']}`: {f['text']}" for f in mech]
    files = sum(len(r.get("units_checked") or r.get("_units") or []) for r in results)
    summary = (f"Agents read {files} source file(s): {len(applied)} comment line(s) corrected, "
               f"{len(human)} left for a human. {len(mech)} TODO/FIXME/XXX note(s) with no release TODO citing "
               "them (mechanical).")
    if edited:
        summary += " " + rox["note"] + "."
    return {"summary": summary, "applied": applied, "mechanical": mechanical, "human": human,
            "proposed": proposed}
