#!/usr/bin/env python3
"""Research-finding triage helpers (stdlib only; owner, 2026-11-16).

Every faster-algorithm finding gets one decision in R/package_metadata/audits/research_triage.csv:
reject / defer / investigate / adopt, with status proposed (a draft) or approved (the owner's
decision). An approved investigate / adopt names its release TODO (v<version>-TODO-<n>, e.g. v1.1.0-TODO-196).

  algorithm_audit_triage.py annotate   # write each decision under its finding in research_findings/*.md
  algorithm_audit_triage.py summary    # counts by decision / status, and what still needs a decision

The inventory check (algorithm_audit_drift.py, check 4) validates the CSV.
"""
import argparse
import re
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import algorithm_audit_drift as drift  # noqa: E402

FINDINGS = drift.META / "audits" / "research_findings"
TRIAGE_LINE = re.compile(r"^- \*\*Triage:\*\* .*\n", re.M)


def triage_line(t):
    bits = [f"{t['decision']} ({t['status']})"]
    if t.get("todo"):
        bits.append(t["todo"])
    if t.get("revisit"):
        bits.append(f"revisit {t['revisit']}")
    when = f", {t['decided']}" if t.get("decided") else ""
    return f"- **Triage:** {', '.join(bits)}{when}. {t.get('reason', '').strip()}\n"


def annotate(triage=None, folder=FINDINGS):
    """Insert or replace the Triage line under each triaged finding's heading. Returns the
    number of findings annotated; ids found in no findings file are returned as missing."""
    triage = {t["finding_id"]: t for t in (triage if triage is not None else drift.load_triage())}
    done, seen = 0, set()
    for f in sorted(folder.glob("*.md")):
        if f.name.endswith("-searches.md") or f.name == "README.md":
            continue
        text = f.read_text()
        out, changed = [], False
        lines = text.splitlines(keepends=True)
        i = 0
        while i < len(lines):
            line = lines[i]
            out.append(line)
            m = re.match(r"^### .*`([^`]+#[^`]+)`\s*$", line)
            if m and m.group(1) in triage:
                fid = m.group(1)
                seen.add(fid)
                new = triage_line(triage[fid])
                if i + 1 < len(lines) and TRIAGE_LINE.match(lines[i + 1]):
                    if lines[i + 1] != new:
                        changed = True
                    i += 1  # replace the old line
                else:
                    changed = True
                out.append(new)
                done += 1
            i += 1
        if changed:
            f.write_text("".join(out))
    return done, sorted(set(triage) - seen)


def summary(triage=None):
    rows = triage if triage is not None else drift.load_triage()
    by = Counter((t["decision"], t["status"]) for t in rows)
    log_ids = [f["id"] for p in drift.load_research_log().values() for f in p.get("findings", [])]
    untriaged = [i for i in log_ids if i not in {t["finding_id"] for t in rows}]
    lines = [f"{len(rows)} triaged findings:"]
    lines += [f"  {d:<11} {s:<8} {n}" for (d, s), n in sorted(by.items())]
    lines.append(f"{len(untriaged)} findings in research_log.json without a decision")
    return "\n".join(lines)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["annotate", "summary"])
    a = ap.parse_args()
    if a.cmd == "annotate":
        n, missing = annotate()
        print(f"annotated {n} findings" + (f"; ids in no findings file: {missing}" if missing else ""))
    else:
        print(summary())


if __name__ == "__main__":
    main()
