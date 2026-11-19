"""Allowlist and baseline hygiene: accepted rows and allowlist entries whose TODO is closed.

Plan: R/package_metadata/new_feature_plans/v1_0_6/audit_jobs_framework.md (Part 4, "Allowlist and
baseline hygiene"). No Claude.

Every entry that excuses a gate failure must cite an open TODO. This audit reads the TODO state
from the release and plan files (with the TODO-status audit's parser, imported, not copied) and:

- removes entries whose cited TODO is ticked or does not exist, from the files where an entry is one
  CSV line and deleting it is the documented way to retire it (`REMOVABLE` below);
- reports entries whose TODO moved (a struck pointer), entries in files whose own rules say not to
  delete them (`stale_ok_row_rules.csv`: reclassify `todo:` to `commit:` instead), TODO citations
  next to the known-failure lists embedded in R test code, and entries that can be seen not to
  trigger any more without running R (their class or design no longer exists, or their class
  pattern matches no class).
"""
import csv
import io
import os
import re
from pathlib import Path

import audit_common as ac
from audits import todo_status as ts

SPEC = {
    "name": "allowlist-hygiene",
    "title": "Allowlist and baseline hygiene",
    "report": "pr",
    "claude": False,
}

PT = "R/package_tests"
# file -> how its entries cite a TODO and name what they match.
#   cite: "reason-lead" (a leading `v1.1 TODO-173:` in `reason`) or "tracked_in" (a column)
#   key:  the columns that identify an entry in the report
REMOVABLE = {
    f"{PT}/calibration/calibration_study_accepted.csv": {
        "cite": "reason-lead", "class": "inf_class", "design": "design",
        "key": ("response_type", "design", "prob_T", "inf_class", "inf_procedure", "formula", "n", "metric")},
    f"{PT}/calibration/calibration_fast_tier_accepted.csv": {
        "cite": "reason-lead", "class": "inference_class", "design": "design",
        "key": ("response_type", "design", "prob_T", "inference_class", "method", "formula", "n", "metric")},
    f"{PT}/path_audits_regression_allowlist.csv": {
        "cite": "tracked_in", "class_regex": "class_regex", "key": ("id",)},
    # Untested-code audit (audits/untested_code.py): regions left uncovered on purpose.
    "R/package_metadata/audits/untested_code_allowlist.csv": {"cite": "reason-lead", "key": ("match",)},
}
# Entries are reported, never removed: the file's header says to reclassify a `todo:` rule to
# `commit:` when its TODO lands, and delete it only once nothing is left to prune.
REPORT_ONLY = {
    f"{PT}/stale_ok_row_rules.csv": {
        "cite": "tracked_in", "class": "class", "strip_prefix": True,
        "key": ("response_type", "class", "function_run", "before_timestamp")},
}
# Files with no per-entry TODO citation: listed in the summary so a reader knows they were not checked.
NO_CITATION = (f"{PT}/comprehensive_results_audit_baseline.csv",)
# Known-failure lists embedded in R test code (not line-safe to edit): report TODO citations near them.
EMBEDDED_DIRS = ("R/EDI/tests", f"{PT}")
EMBEDDED_LIST = re.compile(r"^\s*([A-Za-z_.][\w.]*(?:known_failures|KNOWN_FAILURES|allowlist|ALLOWLIST)\w*)\s*(?:=|<-)",
                           re.M)
EMBEDDED_WINDOW = 12

LEAD_CITE = re.compile(r"^\s*v(\d+(?:\.\d+){0,2})[- ]TODO-(" + ts.TODO_NUM + r")(?![\w])")
TRACKED_CITE = re.compile(r"(?:todo:)?(?:[\w./-]*/)?([\w-]+\.md):(?:TODO-)?(" + ts.TODO_NUM + r")$")
ANY_CITE = re.compile(r"\bv(\d+\.\d+(?:\.\d+)?)[- ]TODO-(" + ts.TODO_NUM + r")(?![\w])"
                      r"|\b([\w-]+\.md)(?:\s*(?:→|->))?\s+TODO-(" + ts.TODO_NUM + r")(?![\w])")


def release_file(version):
    parts = [int(x) for x in version.split(".")]
    parts += [0] * (3 - len(parts))
    return "release_v{}_{}_{}.md".format(*parts[:3])


class TodoState:
    """State of a cited TODO: open, ticked, moved (a struck pointer) or missing."""

    def __init__(self, repo):
        self.repo = repo
        self.st = ts.load_todo_state(repo)
        self.look = ts.todo_lookup(self.st)

    def state(self, base, num):
        it, file_found = ts.find_target(self.st, self.look, base, num, self.repo)
        if it is None:
            return ("missing", f"`{base}` has no checkbox TODO-{num}" if file_found else f"no file `{base}`")
        if it.get("pointer"):
            tg = ", ".join(f"{b} → TODO-{n}" for b, n in it.get("targets") or []) or "elsewhere"
            return ("moved", f"`{base} → TODO-{num}` moved to {tg}")
        if it["checked"]:
            return ("ticked", f"`{base} → TODO-{num}` is ticked")
        return ("open", "")


def read_csv_lines(text):
    """[(line index, dict)] for a CSV whose records are one physical line each, or None if a record
    spans lines (then the file is not edited)."""
    lines = text.splitlines(keepends=True)
    if not lines:
        return [], []
    header = next(csv.reader([lines[0]]))
    rows = []
    for i, line in enumerate(lines[1:], start=1):
        if not line.strip():
            continue
        recs = list(csv.reader([line]))
        if len(recs) != 1 or len(recs[0]) != len(header):
            return None, header
        rows.append((i, dict(zip(header, recs[0]))))
    if len(list(csv.DictReader(io.StringIO(text)))) != len(rows):
        return None, header
    return rows, header


def citation_of(row, rule):
    if rule["cite"] == "reason-lead":
        m = LEAD_CITE.match(row.get("reason") or "")
        return (release_file(m.group(1)), m.group(2), f"v{m.group(1)} TODO-{m.group(2)}") if m else None
    v = (row.get("tracked_in") or "").strip()
    m = TRACKED_CITE.search(v)
    if not m or os.path.basename(m.group(1)).lower() == "news.md":
        return None
    return (m.group(1), m.group(2), v)


def known_designs(repo):
    return {c for c in ts.class_files(repo) if c.startswith("Design")}


def class_names(repo):
    return set(ts.class_files(repo))


def _entry_key(row, rule):
    return " / ".join(str(row.get(k, "")) for k in rule["key"])


def _trigger_check(row, rule, classes, designs):
    """Why an entry can be seen to match nothing any more without running R, or None."""
    cls = row.get(rule.get("class", ""), "") if rule.get("class") else ""
    if cls:
        name = cls.split(" ")[0]
        if rule.get("strip_prefix") and not name.startswith("Inference"):
            name = "Inference" + name
        if name not in classes:
            return f"class `{cls}` no longer exists in R/EDI/R"
    d = row.get(rule.get("design", ""), "") if rule.get("design") else ""
    if d and d.startswith("Design") and designs and d not in designs:
        return f"design `{d}` no longer exists in R/EDI/R"
    rx = row.get(rule.get("class_regex", ""), "") if rule.get("class_regex") else ""
    if rx and rx not in ("*", ".*", ".+"):
        try:
            pat = re.compile(rx)
        except re.error:
            return f"class_regex `{rx}` is not a valid regular expression"
        bare = {c[len("Inference"):] for c in classes if c.startswith("Inference")}
        if not any(pat.search(c) for c in bare):
            return f"class_regex `{rx}` matches no class"
    return None


def mechanical(ctx):
    repo = ctx.repo
    todos = TodoState(repo)
    classes = class_names(repo)
    designs = known_designs(repo)
    out = []
    for rel, rule in list(REMOVABLE.items()) + list(REPORT_ONLY.items()):
        text = ctx.read(rel)
        if text is None:
            out.append({"unit": rel, "kind": "file-missing", "text": f"`{rel}` is not in the repository; "
                        "update the allowlist-hygiene audit's file list."})
            continue
        rows, header = read_csv_lines(text)
        removable = rel in REMOVABLE
        if rows is None:
            out.append({"unit": rel, "kind": "not-line-safe", "text": f"`{rel}` has a record that spans lines "
                        "or a short row; it was checked but not edited."})
            removable = False
            rows = [(None, r) for r in csv.DictReader(io.StringIO(text))]
        for line_no, row in rows:
            key = _entry_key(row, rule)
            unit = f"{rel}::{key}"
            cite = citation_of(row, rule)
            if rule["cite"] == "reason-lead" and cite is None:
                out.append({"unit": unit, "kind": "no-citation",
                            "text": f"`{rel}`: `{key}` cites no TODO at the start of its reason."})
            if cite:
                state, why = todos.state(cite[0], cite[1])
                if state in ("ticked", "missing"):
                    f = {"unit": unit, "kind": f"todo-{state}", "file": rel, "line_index": line_no,
                         "line": text.splitlines(keepends=True)[line_no] if line_no is not None else None,
                         "cite": cite[2]}
                    if removable:
                        f["action"] = "remove"
                        f["text"] = f"`{rel}`: removed `{key}`: its TODO `{cite[2]}` is {state} ({why})."
                    elif rel in REPORT_ONLY:
                        f["text"] = (f"`{rel}`: `{key}` cites `{cite[2]}`, which is {state} ({why}). "
                                     "Per the file's header, reclassify the rule to `commit:<sha>` (or delete "
                                     "it once nothing is left to prune).")
                    else:
                        f["text"] = f"`{rel}`: `{key}` cites `{cite[2]}`, which is {state} ({why})."
                    out.append(f)
                elif state == "moved":
                    out.append({"unit": unit, "kind": "todo-moved",
                                "text": f"`{rel}`: `{key}` cites `{cite[2]}`: {why}; cite the new TODO."})
            dead = _trigger_check(row, rule, classes, designs)
            if dead:
                out.append({"unit": unit, "kind": "no-longer-triggers",
                            "text": f"`{rel}`: `{key}`: {dead}, so the entry matches nothing (not removed: "
                                    "check and delete it by hand)."})
    out += embedded(ctx, todos)
    return out


def embedded(ctx, todos):
    """TODO citations within a few lines of a known-failure list in R test code."""
    out = []
    for rel in ts.tracked(ctx.repo, *EMBEDDED_DIRS):
        if not rel.endswith((".R", ".r")):
            continue
        text = ctx.read(rel) or ""
        if not EMBEDDED_LIST.search(text):
            continue
        lines = text.splitlines()
        for m in EMBEDDED_LIST.finditer(text):
            at = text.count("\n", 0, m.start())
            window = "\n".join(lines[max(0, at - EMBEDDED_WINDOW):at + EMBEDDED_WINDOW])
            seen = set()
            for c in ANY_CITE.finditer(window):
                base, num = ((release_file(c.group(1)), c.group(2)) if c.group(1) else (c.group(3), c.group(4)))
                if (base, num) in seen:
                    continue
                seen.add((base, num))
                state, why = todos.state(base, num)
                if state != "open":
                    out.append({"unit": f"{rel}::{m.group(1)}", "kind": f"embedded-todo-{state}",
                                "text": f"`{rel}` line {at + 1}: `{m.group(1)}` is tracked by `{c.group(0)}`, "
                                        f"which is {state} ({why}); remove its entries or cite an open TODO."})
    return out


def apply(ctx, results, mech):
    removals = {}
    for f in mech:
        if f.get("action") == "remove" and f.get("line_index") is not None:
            removals.setdefault(f["file"], []).append(f)
    applied, proposed = [], []
    for rel, fs in sorted(removals.items()):
        path = ctx.path(rel)
        lines = path.read_text().splitlines(keepends=True)
        drop = set()
        for f in fs:
            i = f["line_index"]
            if i < len(lines) and lines[i] == f["line"]:
                drop.add(i)
                applied.append(f["text"])
                proposed.append({**f, "applied_file": rel, "applied_text": ""})
        path.write_text("".join(l for i, l in enumerate(lines) if i not in drop))
    rest = [f["text"] for f in mech if f.get("action") != "remove"]
    summary = (f"{len(applied)} entr{'y' if len(applied) == 1 else 'ies'} removed because the TODO they cite is "
               f"ticked or missing; {len(rest)} other finding(s) reported. Not checked (no per-entry TODO "
               f"column): {', '.join('`' + p + '`' for p in NO_CITATION)}.")
    return {"summary": summary, "applied": applied, "mechanical": rest, "human": [], "proposed": proposed}
