#!/usr/bin/env python3
"""Merge the monthly algorithm-research agents' JSON into one markdown issue body (stdlib only).

Each task (one per research batch such as `A.3`, plus `inventory` for the currency check) leaves either
`<dir>/<task>.json` (the agent's structured output) or `<dir>/<task>.notrun` (why it did not
run). A task with neither, or with unparseable JSON, is reported as NOT RUN. Nothing is ever
treated as clean by default: a missing task makes the report FLAGGED.

Usage: algorithm_audit_research_report.py --dir research --tasks A.1,A.2,...,inventory
       [--batches batches.json] --out report.md
First line of the output is `FLAGGED` or `CLEAN`, like algorithm_audit_drift.py.
"""
import argparse
import datetime
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from algorithm_audit_drift import canonical_cran_url  # noqa: E402


def load(dirpath, task):
    """(data, None) or (None, reason it did not run)."""
    js, nr = dirpath / f"{task}.json", dirpath / f"{task}.notrun"
    if js.is_file():
        try:
            data = json.loads(js.read_text())
        except ValueError as e:
            return None, f"output was not valid JSON ({e})"
        if not isinstance(data, dict):
            return None, "output was not a JSON object"
        return data, None
    if nr.is_file():
        return None, nr.read_text().strip() or "no reason given"
    return None, "no output (job failed, timed out or was cancelled)"


def render(dirpath, tasks, batches=None):
    """batches: task -> algorithms it was given; any not accounted for is a silent skip."""
    batches = batches or {}
    notrun, incomplete, findings, reviewed, skipped, mismatched = [], [], [], [], [], []
    new_algos, plumbing, stale, unchecked = [], 0, [], 0
    for task in tasks:
        data, why = load(dirpath, task)
        if data is None:
            notrun.append((task, why))
            continue
        if task == "inventory":
            for s in data.get("new_symbols", []):
                if s.get("is_algorithm"):
                    new_algos.append(s)
                else:
                    plumbing += 1
            for c in data.get("changed_entries", []):
                if c.get("stale"):
                    stale.append(c)
                else:
                    unchecked += 1
            continue
        for f in data.get("findings", []):
            findings.append((task, f))
        for a in data.get("algorithms_reviewed", []):
            reviewed.append((task, a))
        for a in data.get("not_reviewed", []):
            incomplete.append((task, a))
        named = {a.get("algorithm") for a in data.get("algorithms_reviewed", [])
                 + data.get("not_reviewed", [])}
        skipped += [(task, alg) for alg in batches.get(task, []) if alg not in named]
        # A finding and its algorithm's conclusion must agree, in both directions.
        conclusion = {a.get("algorithm"): a.get("conclusion")
                      for a in data.get("algorithms_reviewed", [])}
        found = {f.get("algorithm") for f in data.get("findings", [])}
        for alg in sorted(found, key=str):
            c = conclusion.get(alg)
            if c != "faster_option_found":
                why = (f"marked `{c}`" if c else "not in algorithms_reviewed")
                mismatched.append((task, alg, f"has a finding but is {why}"))
        for alg, c in conclusion.items():
            if c == "faster_option_found" and alg not in found:
                mismatched.append((task, alg, "marked `faster_option_found` but has no finding"))

    flagged = bool(notrun or incomplete or skipped or mismatched or findings or new_algos or stale)
    today = datetime.date.today().isoformat()
    L = ["FLAGGED" if flagged else "CLEAN", "",
         f"# Algorithm research report ({today})", "",
         "Output of the monthly research agents in `.github/workflows/algorithm-audit-drift.yml` "
         "(prompts in `.github/prompts/`). Everything here is **unverified**: web claims, not "
         "measurements. A finding means *re-look*, not *wrong*. Procedure: "
         "`R/package_metadata/new_feature_plans/v1_0_5/algorithm_audit_runbook.md`.", ""]

    if notrun:
        L.append("## Tasks that did not run")
        L += [f"- **{t}**: {why}" for t, why in notrun]
        L.append("")

    L.append("## 1. Faster-algorithm findings")
    if not findings:
        L.append("_None._")
    for task, f in findings:
        L.append(f"### Batch {task}: {f.get('algorithm', '?')} → {f.get('candidate', '?')}")
        L.append(f"- **Current:** {f.get('current', '')}")
        L.append(f"- **Claimed speedup:** {f.get('claimed_speedup', '')} "
                 f"(applies at EDI's sizes: {f.get('applies_at_edi_sizes', '?')}; "
                 f"keeps the estimator: {f.get('keeps_estimator', '?')}; "
                 f"confidence: {f.get('confidence', '?')})")
        L.append(f"- **Trade-offs:** {f.get('tradeoffs', '')}")
        L.append(f"- **Suggested action:** {f.get('suggested_action', '')}")
        L.append("- **Affects:** " + ", ".join(f"`{e}`" for e in f.get("entries", [])))
        L.append("- **Sources:** " + " ".join(canonical_cran_url(u) for u in f.get("sources", [])))
        if f.get("open_copies"):
            L.append("- **Open copies** (preprint / PubMed Central; the publisher page may block "
                     "automated access): " + " ".join(f["open_copies"]))
        L.append("")

    L.append("## 2. Inventory currency")
    if new_algos:
        L.append("### New functions that implement an algorithm (add to `algorithm_inventory.csv`)")
        for s in new_algos:
            p = s.get("proposed") or {}
            L.append(f"- `{s.get('file')}` `{s.get('symbol')}`: {p.get('algorithm', '?')} "
                     f"(row {p.get('audit_row', '?')}; {p.get('problem', '')}). "
                     f"{p.get('details', '')} Complexity: {p.get('complexity', '')}. "
                     "Refs: " + " ".join(canonical_cran_url(u) for u in p.get("refs", [])))
    if stale:
        L.append("### Inventory rows that no longer describe the code")
        for c in stale:
            mark = " **(may affect the verdict)**" if c.get("may_affect_verdict") else ""
            L.append(f"- `{c.get('file')}` `{c.get('symbol')}`{mark}: {c.get('issue', '')}")
            if c.get("suggested_details"):
                L.append(f"  - Suggested `details`: {c['suggested_details']}")
    if "inventory" in tasks and not any(t == "inventory" for t, _ in notrun):
        L.append(f"_{plumbing} new functions judged plumbing; {unchecked} changed entries "
                 "still accurate._")
    L.append("")

    if incomplete or skipped:
        L.append("## 3. Algorithms not reviewed this run")
        L += [f"- Batch {t}: {a.get('algorithm', '?')} ({a.get('reason', '')})" for t, a in incomplete]
        L += [f"- Batch {t}: {alg} (**silently skipped**: in the batch but in neither list)"
              for t, alg in skipped]
        L.append("")

    if mismatched:
        L.append("## 4. Inconsistent agent output (check the finding before acting on it)")
        L += [f"- Batch {t}: {alg}: {why}" for t, alg, why in mismatched]
        L.append("")

    if reviewed:
        L += ["<details><summary>Algorithms reviewed with no acceptable faster option "
              f"({sum(1 for _, a in reviewed if a.get('conclusion') != 'faster_option_found')})"
              "</summary>", ""]
        L += [f"- Batch {t}: {a.get('algorithm', '?')}: {a.get('conclusion', '?')}. {a.get('note', '')}"
              for t, a in reviewed if a.get("conclusion") != "faster_option_found"]
        L += ["", "</details>"]
    return flagged, "\n".join(L) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", required=True)
    ap.add_argument("--tasks", required=True, help="comma-separated: audit rows and/or inventory")
    ap.add_argument("--batches", help="JSON task -> algorithms (algorithm_audit_drift.py --research-batches)")
    ap.add_argument("--out", default="-")
    a = ap.parse_args()
    batches = json.loads(Path(a.batches).read_text()) if a.batches else None
    _, text = render(Path(a.dir), [t for t in a.tasks.split(",") if t], batches)
    if a.out == "-":
        print(text, end="")
    else:
        Path(a.out).write_text(text)


if __name__ == "__main__":
    main()
