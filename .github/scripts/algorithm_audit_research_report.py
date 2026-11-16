#!/usr/bin/env python3
"""Merge the monthly algorithm-research agents' JSON into one markdown report (stdlib only).

One research task per **problem** (a `problem_id` of algorithm_taxonomy.json; owner,
2026-11-16), plus `inventory` for the currency check. Each leaves either `<dir>/<task>.json`
(the agent's structured output) or `<dir>/<task>.notrun` (why it did not run); `<dir>/<task>
.searches.json` is what its transcript shows it actually searched. A task with no output, or
unparseable JSON, is reported as NOT RUN. Nothing is treated as clean by default.

Checks per problem: every method accounted for (reviewed or not_reviewed, never silently
skipped); findings and conclusions agree; the search plan covered every term class the
taxonomy lists for the problem and each method, and the four venues; the searches the agent
reports are backed by its transcript.

Usage: algorithm_audit_research_report.py --dir research --tasks <problem_id>,...,inventory
       [--batches tasks.json] [--taxonomy algorithm_taxonomy.json] --out report.md
First line of the output is `FLAGGED` or `CLEAN`, like algorithm_audit_drift.py.
"""
import argparse
import datetime
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from algorithm_audit_drift import canonical_cran_url  # noqa: E402

VENUES = ("arxiv", "cran-task-views", "jss", "r-journal")
METHOD_CLASSES = (("synonyms", "synonym"), ("broader", "broader"), ("narrower", "narrower"),
                  ("software", "software"))
ACCESS_WHY = {"blocked": "publisher page blocks automated access",
              "closed": "publisher version is paywalled",
              "lookup_failed": "publisher blocked and the OpenAlex lookup failed: check manually"}


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


def coverage_gaps(data, problem_id, methods, taxonomy):
    """Term classes and venues the agent's reported searches did not cover."""
    gaps = []
    searches = data.get("searches", [])
    covered = set()  # (class, method_id or "")
    for s in searches:
        for c in s.get("term_classes", []):
            covered.add((c, ""))
            for m in s.get("method_ids", []):
                covered.add((c, m))
    prob = taxonomy.get("problems", {}).get(problem_id, {})
    if prob.get("search_terms") and ("problem", "") not in covered:
        gaps.append("no problem-level search")
    for m in methods:
        entry = taxonomy.get("methods", {}).get(m, {})
        if entry.get("trivial"):  # owner, 2026-11-16: reviewed in one line, no per-term searches
            continue
        if entry.get("researched_in") and entry["researched_in"] != problem_id:
            continue  # researched once in its collecting problem (e.g. dense-linear-algebra)
        for key, cls in METHOD_CLASSES:
            if entry.get(key) and (cls, m) not in covered:
                gaps.append(f"`{m}`: no {cls} search")
    wheres = {s.get("where") for s in searches}
    gaps += [f"venue not checked: {v}" for v in VENUES if v not in wheres]
    return gaps


def transcript_gap(data, dirpath, task):
    """Reported searches the transcript does not back, or None when no transcript exists."""
    f = dirpath / f"{task}.searches.json"
    if not f.is_file():
        return None
    rec = json.loads(f.read_text())
    actual = rec.get("searches", [])
    reported = len(data.get("searches", []))
    problems = []
    if reported > len(actual):
        problems.append(f"reports {reported} searches but its transcript shows {len(actual)} "
                        "(WebSearch + WebFetch)")
    denied = {t: n for t, n in rec.get("tool_counts", {}).items()
              if t in ("Bash", "Edit", "Write", "NotebookEdit")}
    if denied:  # tool policy: these are denied; a call means the deny did not hold
        problems.append("called denied tools: " + ", ".join(f"{t} x{n}" for t, n in sorted(denied.items())))
    return "; ".join(problems)


def finding_ids(task, findings, run_id, prev_ids):
    """Ids the PR job will give these findings in research_log.json (same rule as the log)."""
    return [f.get("previous_finding_id") if f.get("previous_finding_id") in prev_ids
            else f"{task}#{run_id}.{k}" for k, f in enumerate(findings, start=1)]


def render(dirpath, tasks, batches=None, taxonomy=None, inventory_ctx=None, run_id="local",
           log=None, triage=None):
    """batches: problem_id -> method_ids it was given (any not accounted for is a silent skip);
    taxonomy: algorithm_taxonomy.json, for the search-plan coverage check."""
    batches, taxonomy, inventory_ctx = batches or {}, taxonomy or {}, inventory_ctx or {}
    log, triage = log or {}, {t["finding_id"]: t for t in (triage or [])}
    today = datetime.date.today().isoformat()
    rereported, unjustified = [], []
    notrun, incomplete, findings, reviewed, skipped, mismatched = [], [], [], [], [], []
    gaps, unbacked, proposed, impls = [], [], [], []
    new_algos, plumbing, stale, unchecked = [], 0, [], 0
    for task in tasks:
        data, why = load(dirpath, task)
        if data is None:
            notrun.append((task, why))
            continue
        if task == "inventory" or task.startswith("inventory."):
            for s in data.get("new_symbols", []):
                if s.get("symbol") == "*":
                    plumbing += 1  # a whole file reported as plumbing
                    continue
                if s.get("is_algorithm"):
                    new_algos.append(s)
                else:
                    plumbing += 1
            for c in data.get("changed_entries", []):
                if c.get("stale"):
                    stale.append(c)
                else:
                    unchecked += 1
            # every item the shard was given must come back (shards 12, 14, 15 of run
            # 43957548346 returned only their stale entries)
            ctx = inventory_ctx.get(task, {})
            for kind, label in (("new_symbols", "new function"), ("changed_entries", "changed entry")):
                got = {(x.get("file"), x.get("symbol")) for x in data.get(kind, [])}
                whole = {x.get("file") for x in data.get(kind, []) if x.get("symbol") == "*"
                         and kind == "new_symbols" and x.get("is_algorithm") is False}
                skipped += [(task, f"{label} `{x['file']}` `{x['symbol']}`") for x in ctx.get(kind, [])
                            if (x["file"], x["symbol"]) not in got and x["file"] not in whole]
            continue
        prev_ids = {x.get("id") for x in log.get(task, {}).get("findings", [])}
        for f, fid in zip(data.get("findings", []), finding_ids(task, data.get("findings", []), run_id, prev_ids)):
            f = dict(f, _id=fid)
            t = triage.get(fid) if fid == f.get("previous_finding_id") else None
            if t:
                rereported.append((task, f, t))
                blocked = t["decision"] == "reject" or (t["decision"] == "defer" and t.get("revisit", "") > today)
                if blocked and not f.get("new_evidence"):
                    unjustified.append((task, fid, t["decision"]))
            else:
                findings.append((task, f))
        for a in data.get("methods_reviewed", []):
            reviewed.append((task, a))
        for a in data.get("not_reviewed", []):
            incomplete.append((task, a))
        proposed += [(task, p) for p in data.get("proposed_terms", [])]
        impls += [(task, i) for i in data.get("implementations", [])]
        named = {a.get("method_id") for a in data.get("methods_reviewed", [])
                 + data.get("not_reviewed", [])}
        skipped += [(task, m) for m in batches.get(task, []) if m not in named]
        conclusion = {a.get("method_id"): a.get("conclusion")
                      for a in data.get("methods_reviewed", [])}
        found = {m for f in data.get("findings", []) for m in f.get("methods", [])}
        for m in sorted(found, key=str):
            c = conclusion.get(m)
            if c != "faster_option_found":
                mismatched.append((task, m, "has a finding but is "
                                   + (f"marked `{c}`" if c else "not in methods_reviewed")))
        for m, c in conclusion.items():
            if c == "faster_option_found" and m not in found:
                mismatched.append((task, m, "marked `faster_option_found` but has no finding"))
        if taxonomy:
            g = coverage_gaps(data, task, batches.get(task, list(conclusion)), taxonomy)
            if g:
                gaps.append((task, g))
        t = transcript_gap(data, dirpath, task)
        if t:
            unbacked.append((task, t))

    flagged = bool(notrun or incomplete or skipped or mismatched or gaps or unbacked
                   or findings or new_algos or stale or unjustified)
    today = datetime.date.today().isoformat()
    L = ["FLAGGED" if flagged else "CLEAN", "",
         f"# Algorithm research report ({today})", "",
         "Output of the monthly research agents in `.github/workflows/algorithm-audit-drift.yml`: "
         "one agent per problem of `R/package_metadata/audits/algorithm_taxonomy.json` (task "
         "prompts in `.github/prompts/`, method in `.github/prompts/research_agent_CLAUDE.md`). "
         "Everything here is **unverified**: web claims, not measurements. A finding means "
         "*re-look*, not *wrong*. What each agent actually searched is in the companion "
         "`-searches.md` file. Procedure: "
         "`R/package_metadata/new_feature_plans/v1_0_5/algorithm_audit_runbook.md`.", ""]

    if notrun:
        L.append("## Tasks that did not run")
        L += [f"- **{t}**: {why}" for t, why in notrun]
        L.append("")

    vs = {}
    for _, a in reviewed:
        vs[a.get("vs_previous", "unrecorded")] = vs.get(a.get("vs_previous", "unrecorded"), 0) + 1
    if vs:
        L += ["Compared with the previous results (`research_log.json`): "
              + ", ".join(f"{n} {k}" for k, n in sorted(vs.items())) + ".", ""]

    def finding_block(task, f, triaged=None):
        L.append(f"### {task}: {', '.join(f.get('methods', [])) or '?'} → {f.get('candidate', '?')} "
                 f"`{f['_id']}`")
        if triaged:
            L.append(f"- **Previously triaged:** {triaged['decision']} ({triaged.get('status', '')})"
                     + (f", {triaged['todo']}" if triaged.get("todo") else "")
                     + (f", revisit {triaged['revisit']}" if triaged.get("revisit") else "")
                     + f". {triaged.get('reason', '')}")
            if f.get("new_evidence"):
                L.append(f"- **New evidence:** {f['new_evidence']}")
        L.append(f"- **Current:** {f.get('current', '')}")
        L.append(f"- **Claimed speedup:** {f.get('claimed_speedup', '')} "
                 f"(applies at EDI's sizes: {f.get('applies_at_edi_sizes', '?')}; "
                 f"keeps the estimator: {f.get('keeps_estimator', '?')}; "
                 f"confidence: {f.get('confidence', '?')})")
        L.append(f"- **Trade-offs:** {f.get('tradeoffs', '')}")
        L.append(f"- **Suggested action:** {f.get('suggested_action', '')}")
        L.append("- **Affects:** " + ", ".join(f"`{e}`" for e in f.get("entries", [])))
        L.append("- **Sources:** " + " ".join(canonical_cran_url(u) for u in f.get("sources", [])))
        for doi, status in sorted(f.get("source_access", {}).items()):
            if status == "lookup_failed":
                L.append(f"- **Open-copy lookup failed** for doi:{doi} ({ACCESS_WHY[status]})")
            elif not f.get("open_copies"):
                L.append(f"- **No open copy found** for doi:{doi} ({ACCESS_WHY.get(status, status)})")
        if f.get("open_copies"):
            reasons = sorted({ACCESS_WHY.get(v, v) for v in f.get("source_access", {}).values()})
            L.append(f"- **Open copies** ({'; '.join(reasons) or 'publisher not usable'}): "
                     + " ".join(f["open_copies"]))
        L.append("")

    L.append("## 1. Faster-algorithm findings (new; each needs a triage decision)")
    if not findings:
        L.append("_None._")
    for task, f in findings:
        finding_block(task, f)
    if rereported:
        L.append("## 1b. Previously triaged findings, re-reported")
        for task, f, t in rereported:
            finding_block(task, f, t)
    if unjustified:
        L.append("## 8. Re-reported despite a reject / defer decision, with no new evidence")
        L += [f"- {t}: `{fid}` (decision: {dec})" for t, fid, dec in unjustified]
        L.append("")

    L.append("## 2. Inventory currency")
    if new_algos:
        L.append("### New functions that implement an algorithm (add to `algorithm_inventory.csv`)")
        for s in new_algos:
            p = s.get("proposed") or {}
            L.append(f"- `{s.get('file')}` `{s.get('symbol')}`: {p.get('algorithm', '?')} "
                     f"(problem `{p.get('problem_id', '?')}`, method `{p.get('method_id', '?')}`, "
                     f"row {p.get('audit_row', '?')}; {p.get('problem', '')}). "
                     f"{p.get('details', '')} Complexity: {p.get('complexity', '')}. "
                     "Refs: " + " ".join(canonical_cran_url(u) for u in p.get("refs", [])))
    if stale:
        L.append("### Inventory rows that no longer describe the code")
        for c in stale:
            mark = " **(may affect the verdict)**" if c.get("may_affect_verdict") else ""
            L.append(f"- `{c.get('file')}` `{c.get('symbol')}`{mark}: {c.get('issue', '')}")
            if c.get("suggested_details"):
                L.append(f"  - Suggested `details`: {c['suggested_details']}")
    inv_tasks = [t for t in tasks if t == "inventory" or t.startswith("inventory.")]
    if inv_tasks and not any(t in inv_tasks for t, _ in notrun):
        L.append(f"_{plumbing} new functions judged plumbing; {unchecked} changed entries "
                 "still accurate._")
    L.append("")

    if incomplete or skipped:
        L.append("## 3. Methods and inventory items not reviewed this run")
        L += [f"- {t}: `{a.get('method_id', '?')}` ({a.get('reason', '')})" for t, a in incomplete]
        L += [f"- {t}: {m if m.startswith(('new function', 'changed entry')) else f'`{m}`'} "
              "(**silently skipped**: given to the agent but not in its output)" for t, m in skipped]
        L.append("")

    if mismatched:
        L.append("## 4. Inconsistent agent output (check the finding before acting on it)")
        L += [f"- {t}: `{m}`: {why}" for t, m, why in mismatched]
        L.append("")

    if gaps or unbacked:
        L.append("## 5. Search-plan gaps (see the companion `-searches.md`)")
        for t, g in gaps:
            L.append(f"- {t}: " + "; ".join(g))
        L += [f"- {t}: **{msg}**" for t, msg in unbacked]
        L.append("")

    if proposed:
        L.append("## 6. Taxonomy terms proposed by agents")
        L += [f"- {t}: {p.get('target')} `{p.get('id')}` {p.get('term_class')}: "
              f"\"{p.get('term')}\" ({p.get('why', '')})" for t, p in proposed]
        L.append("")

    if impls:
        order = {"yes": 0, "conditional": 1, "unknown": 2, "no": 3}
        L.append("## 7. Open-source implementations found (license as stated by the agent's source)")
        L.append("| GPL-3 compatible | Implementation | License | Problem: methods | Language | Relevance |")
        L.append("|---|---|---|---|---|---|")
        for t, i in sorted(impls, key=lambda ti: (order.get(ti[1].get("gpl3_compatible"), 2),
                                                 ti[0], str(ti[1].get("name", "")).casefold())):
            cell = lambda x: str(x).replace("|", "\\|").replace("\n", " ")
            lic = cell(i.get("license", "?"))  # e.g. "GPL-2 | GPL-3" broke the table (run 43925959437)
            if i.get("license_source"):
                lic = f"[{lic}]({i['license_source']})"
            L.append(f"| {i.get('gpl3_compatible', 'unknown')} | [{cell(i.get('name', '?'))}]"
                     f"({i.get('url', '')}) | {lic} | {t}: {', '.join(i.get('methods', []))} | "
                     f"{cell(i.get('language', ''))} | {cell(i.get('relevance', ''))} |")
        L.append("")

    if reviewed:
        L += ["<details><summary>Methods reviewed with no acceptable faster option "
              f"({sum(1 for _, a in reviewed if a.get('conclusion') != 'faster_option_found')})"
              "</summary>", ""]
        L += [f"- {t}: `{a.get('method_id', '?')}`: {a.get('conclusion', '?')}"
              f" ({a.get('vs_previous', '?')}). {a.get('note', '')}"
              for t, a in reviewed if a.get("conclusion") != "faster_option_found"]
        L += ["", "</details>"]
    return flagged, "\n".join(L) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", required=True)
    ap.add_argument("--tasks", required=True, help="comma-separated: problem ids and/or inventory")
    ap.add_argument("--batches", help="JSON problem_id -> method_ids (algorithm_audit_drift.py --research-batches)")
    ap.add_argument("--taxonomy", help="algorithm_taxonomy.json, for the search-plan coverage check")
    ap.add_argument("--inventory-shards", help="JSON inventory.N -> currency context (--inventory-shards)")
    ap.add_argument("--out", default="-")
    a = ap.parse_args()
    batches = json.loads(Path(a.batches).read_text()) if a.batches else None
    taxonomy = json.loads(Path(a.taxonomy).read_text()) if a.taxonomy else None
    shards = json.loads(Path(a.inventory_shards).read_text()) if a.inventory_shards else None
    _, text = render(Path(a.dir), [t for t in a.tasks.split(",") if t], batches, taxonomy, shards)
    if a.out == "-":
        print(text, end="")
    else:
        Path(a.out).write_text(text)


if __name__ == "__main__":
    main()
