#!/usr/bin/env python3
"""Turn a research run's agent output into repo changes for one pull request (stdlib only).

- Inventory task: new functions that implement an algorithm become rows of
  R/package_metadata/audits/algorithm_inventory.csv, but only with reference URLs this script
  has itself verified (Wikipedia API / doi.org handle API / Crossref for titles); a stale-details
  correction is applied only when it maps to exactly one inventory row. Verdicts are never
  changed. Anything that cannot be applied mechanically is listed for a human instead.
- Everything (findings, not-run tasks, applied and unapplied inventory changes) goes into
  R/package_metadata/audits/research_findings/<date>.md, one file per run.

Usage:
  algorithm_audit_research_apply.py --dir research --tasks A.1,...,inventory \
      [--batches batches.json] [--date YYYY-MM-DD] [--offline] --pr-body pr_body.md
Prints CHANGES if it wrote anything, NONE otherwise. Never commits or pushes.
"""
import argparse
import csv
import datetime
import json
import sys
import urllib.error
import urllib.parse
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import algorithm_audit_drift as drift  # noqa: E402
import algorithm_audit_research_report as report  # noqa: E402

FINDINGS_DIR = drift.META / "audits" / "research_findings"


def ref_title(url, offline):
    """Verified title for a reference URL, or None if it does not resolve / is not allowed."""
    if offline:
        return None
    if url.startswith("https://en.wikipedia.org/wiki/"):
        dead, errors = drift.check_reference_urls([url])
        if dead or errors:
            return None
        return urllib.parse.unquote(url.rsplit("/wiki/", 1)[1]).replace("_", " ")
    if url.startswith("https://doi.org/"):
        doi = url[len("https://doi.org/"):]
        try:
            m = json.loads(drift.http_get(
                f"https://api.crossref.org/works/{urllib.parse.quote(doi, safe='/')}"))["message"]
            author = (m.get("author") or [{}])[0].get("family", "")
            year = (m.get("issued", {}).get("date-parts") or [[""]])[0][0]
            return f"{author} {year}, {(m.get('title') or [''])[0]}".strip()
        except (urllib.error.URLError, OSError, KeyError, ValueError, IndexError):
            return None
    if url.startswith(drift.CRAN + "/"):
        try:
            drift.http_get(url)
        except (urllib.error.URLError, OSError):
            return None
        tail = urllib.parse.urlsplit(url)
        return "CRAN: " + (tail.path.strip("/").replace("web/packages/", "") or tail.query)
    return None  # only Wikipedia, DOI and cran.r-project.org references are accepted


def apply(dirpath, tasks, today, offline):
    inv = drift.load_inventory()
    cols = list(inv[0])
    refs = {r["url"]: r for r in drift.load_references()}
    applied, held, skipped = [], [], 0
    data, _ = report.load(dirpath, "inventory") if "inventory" in tasks else (None, None)
    for s in (data or {}).get("new_symbols", []):
        if not s.get("is_algorithm"):
            continue
        p, where = s.get("proposed") or {}, f"`{s.get('file')}` `{s.get('symbol')}`"
        path = drift.ROOT / str(s.get("file", ""))
        if not (path.is_file() and s.get("symbol") and s["symbol"] in path.read_text(errors="replace")):
            held.append(f"{where}: file or symbol not found; not added")
            continue
        if any(e["file"] == s["file"] and e["symbol"] == s["symbol"] for e in inv):
            skipped += 1  # already inventoried (e.g. added by hand since the agent ran)
            continue
        rows = [r.strip() for r in str(p.get("audit_row", "")).split("+") if r.strip()]
        if not rows or any(r not in json.loads(drift.ROW_MAP.read_text())["rows"] for r in rows):
            held.append(f"{where}: unknown audit row `{p.get('audit_row')}`; not added")
            continue
        good = []
        for u in (drift.canonical_cran_url(x) for x in p.get("refs", [])):
            if u in refs:
                good.append(u)
            else:
                t = ref_title(u, offline)
                if t:
                    kind = "wikipedia" if "wikipedia" in u else "doi" if "doi.org" in u else "cran"
                    refs[u] = {"url": u, "kind": kind, "title": t}
                    good.append(u)
        if not good:
            held.append(f"{where}: none of its references could be verified "
                        f"({' '.join(p.get('refs', [])) or 'none given'}); not added. Proposed: "
                        f"{p.get('algorithm', '?')} (row {p.get('audit_row', '?')}): {p.get('details', '')}")
            continue
        watch = sorted({w for e in inv if e["file"] == s["file"] for w in e["watch"].split()},
                       key=lambda x: (len(x), x))
        inv.append({"file": s["file"], "symbol": s["symbol"], "problem": p.get("problem", ""),
                    "algorithm": p.get("algorithm", ""), "details": p.get("details", ""),
                    "complexity": p.get("complexity", ""), "audit_row": " + ".join(rows),
                    "verdict": f"Not yet audited (added {today})", "refs": " ".join(good),
                    "watch": " ".join(watch), "source": f"{today} research run"})
        applied.append(f"Added {where}: {p.get('algorithm', '?')} (row {' + '.join(rows)})")
    for c in (data or {}).get("changed_entries", []):
        if not c.get("stale"):
            continue
        where = f"`{c.get('file')}` `{c.get('symbol')}`"
        hits = [e for e in inv if e["file"] == c.get("file") and e["symbol"] == c.get("symbol")]
        if c.get("algorithm"):
            hits = [e for e in hits if e["algorithm"] == c["algorithm"]]
        flag = " **(may affect the verdict: re-review the row)**" if c.get("may_affect_verdict") else ""
        if len(hits) == 1 and c.get("suggested_details"):
            hits[0]["details"] = c["suggested_details"]
            applied.append(f"Updated `details` of {where}{flag}: {c.get('issue', '')}")
        else:
            why = ("no suggested text" if not c.get("suggested_details") else
                   f"matches {len(hits)} inventory rows")
            held.append(f"{where}{flag}: {c.get('issue', '')} Not applied ({why}). "
                        f"Suggested `details`: {c.get('suggested_details', '')}")
    if applied:
        inv.sort(key=lambda r: (r["file"], r["symbol"], r["problem"]))
        with drift.INVENTORY.open("w", newline="") as fh:
            w = csv.DictWriter(fh, fieldnames=cols, lineterminator="\n")
            w.writeheader()
            w.writerows(inv)
        used = {u for e in inv for u in e["refs"].split()}
        with drift.REFERENCES.open("w", newline="") as fh:
            w = csv.writer(fh, lineterminator="\n")
            w.writerow(["url", "kind", "title"])
            for u in sorted(used):
                w.writerow([u, refs[u]["kind"], refs[u]["title"]])
    return applied, held, skipped


def add_open_copies(dirpath, tasks, offline):
    """For every finding source with a DOI, try the publisher page first; only if it is blocked or
    closed, record open copies (arXiv, bioRxiv/medRxiv, PMC) from OpenAlex in `open_copies`, and
    why in `source_access` ({doi: "blocked" | "closed"}). Rewrites the task JSON in place,
    before the report is rendered."""
    if offline:
        return
    cache = {}
    for task in tasks:
        path = dirpath / f"{task}.json"
        data, _ = report.load(dirpath, task)
        if not data or not data.get("findings"):
            continue
        for f in data["findings"]:
            copies = list(f.get("open_copies", []))
            notes = dict(f.get("source_access", {}))
            for u in f.get("sources", []):
                doi = drift.doi_of(u)
                if not doi:
                    continue
                if doi not in cache:
                    cache[doi] = drift.doi_access(doi)  # publisher first, then OpenAlex
                status, found = cache[doi]
                if status != "publisher":
                    notes[doi] = status
                copies += [c for c in found if c not in copies and c not in f["sources"]]
            if copies:
                f["open_copies"] = copies
            if notes:
                f["source_access"] = notes
        path.write_text(json.dumps(data))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", required=True)
    ap.add_argument("--tasks", required=True)
    ap.add_argument("--batches")
    ap.add_argument("--date", default=datetime.date.today().isoformat())
    ap.add_argument("--offline", action="store_true")
    ap.add_argument("--pr-body", required=True)
    a = ap.parse_args()
    tasks = [t for t in a.tasks.split(",") if t]
    batches = json.loads(Path(a.batches).read_text()) if a.batches else None
    add_open_copies(Path(a.dir), tasks, a.offline)
    flagged, text = report.render(Path(a.dir), tasks, batches)
    applied, held, skipped = apply(Path(a.dir), tasks, a.date, a.offline)
    body = text.split("\n", 2)[2]  # drop the FLAGGED/CLEAN status line
    # the report's inventory section lists proposals; replace it with what actually happened
    head, _, tail = body.partition("## 2. Inventory currency")
    ends = [i for i in (tail.find("\n## "), tail.find("\n<details>")) if i >= 0]
    tail = tail[min(ends):] if ends else ""
    inv_md = ["## 2. Inventory currency", "",
              "### Applied in this pull request (`algorithm_inventory.csv`, `algorithm_references.csv`)"]
    inv_md += [f"- {x}" for x in applied] or ["_Nothing._"]
    if skipped:
        inv_md.append(f"\n_{skipped} proposed new rows were already in the inventory; skipped._")
    inv_md += ["", "### Needs a human (not applied)"]
    inv_md += [f"- {x}" for x in held] or ["_Nothing._"]
    findings = head + "\n".join(inv_md) + "\n" + tail
    if not (flagged or applied or held):
        print("NONE")
        Path(a.pr_body).write_text("")
        return
    FINDINGS_DIR.mkdir(parents=True, exist_ok=True)
    out = FINDINGS_DIR / f"{a.date}.md"
    out.write_text(findings)
    n_find = findings.count("\n### Batch ")
    Path(a.pr_body).write_text(
        f"Research run {a.date}: findings in `{out.relative_to(drift.ROOT)}`.\n\n"
        f"- Faster-algorithm findings: {n_find} (unverified web claims; promote a confirmed one to a "
        "release TODO, then delete or annotate it in the findings file)\n"
        f"- Inventory changes applied here: {len(applied)}; needing a human: {len(held)}\n"
        "- Verdicts are never changed by this workflow. Merging means the findings file is "
        "acknowledged and the inventory changes are accepted.\n\n"
        "Required checks: a PR opened by `github-actions[bot]` creates `pull_request` runs "
        "(R-CMD-check, test-coverage-python) that never start; merge with the admin bypass, and "
        "GitHub then closes those empty runs as \"failure\" (zero jobs; nothing was tested). "
        "If you pushed a fix to this branch, confirm the PR shows it before merging: GitHub can "
        "take a few minutes to register a push.\n\n"
        "Created by `.github/workflows/algorithm-audit-drift.yml` (research). "
        "Runbook: `R/package_metadata/new_feature_plans/v1_0_5/algorithm_audit_runbook.md`.\n")
    print("CHANGES")


if __name__ == "__main__":
    main()
