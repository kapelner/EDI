#!/usr/bin/env python3
"""Extract what a research agent actually did from its Claude Code transcript (stdlib only).

The claude-code-action `execution_file` is the session's JSON transcript. This walks it for
tool calls without depending on its exact layout (any object with "type": "tool_use" and a
"name"), and writes a compact record: every WebSearch query and WebFetch URL, in order, plus
counts per tool and the session's turns and cost when present. The research-pr job merges
these into research_findings/<date>-run<id>-searches.md so the queries can be critiqued (owner,
2026-11-16).

Usage:
  algorithm_audit_search_log.py extract --task A.3 --transcript exec.json --out A.3.searches.json
  algorithm_audit_search_log.py render --dir research --tasks A.1,...,inventory --out searches.md
"""
import argparse
import datetime
import json
from collections import Counter
from pathlib import Path


def _load_transcript(path):
    """A JSON document, or JSON lines (stream-json), as one list of objects."""
    text = Path(path).read_text()
    try:
        data = json.loads(text)
        return data if isinstance(data, list) else [data]
    except ValueError:
        out = []
        for line in text.splitlines():
            line = line.strip()
            if line:
                try:
                    out.append(json.loads(line))
                except ValueError:
                    continue
        return out


def _walk(node):
    if isinstance(node, dict):
        yield node
        for v in node.values():
            yield from _walk(v)
    elif isinstance(node, list):
        for v in node:
            yield from _walk(v)


def extract(transcript):
    """Compact record of the session's tool use."""
    calls, seen, result = [], set(), {}
    for obj in _walk(transcript):
        if obj.get("type") == "tool_use" and obj.get("name"):
            key = obj.get("id") or json.dumps(obj, sort_keys=True)
            if key in seen:  # the same call can appear in more than one envelope
                continue
            seen.add(key)
            calls.append((obj["name"], obj.get("input") or {}))
        if obj.get("type") == "result":
            result = {k: obj.get(k) for k in ("num_turns", "total_cost_usd", "duration_ms",
                                              "is_error") if k in obj}
    searches = []
    for name, inp in calls:
        if name == "WebSearch":
            searches.append({"tool": "WebSearch", "query": inp.get("query", "")})
        elif name == "WebFetch":
            searches.append({"tool": "WebFetch", "url": inp.get("url", ""),
                             "asked": (inp.get("prompt") or "")[:200]})
    return {"tool_counts": dict(Counter(n for n, _ in calls)), "searches": searches, **result}


def render(dirpath, tasks):
    """Markdown search log for a run, one section per task."""
    L = [f"# Research search log ({datetime.date.today().isoformat()})", "",
         "What each research agent actually searched and fetched, extracted from its transcript "
         "by `.github/scripts/algorithm_audit_search_log.py`, for critiquing the research method "
         "(and `.github/prompts/research_agent_CLAUDE.md`). Full transcripts are the run's "
         "`transcript-<task>` artifacts (kept 90 days).", ""]
    totals = Counter()
    for task in tasks:
        f = Path(dirpath) / f"{task}.searches.json"
        L.append(f"## {task}")
        if not f.is_file():
            L += ["_No search log (agent did not run, or its transcript was not available)._", ""]
            continue
        rec = json.loads(f.read_text())
        q = [s for s in rec.get("searches", []) if s["tool"] == "WebSearch"]
        u = [s for s in rec.get("searches", []) if s["tool"] == "WebFetch"]
        totals.update({"searches": len(q), "fetches": len(u), "tasks": 1})
        meta = ", ".join(f"{k} {rec[k]}" for k in ("num_turns", "total_cost_usd") if k in rec)
        tools = ", ".join(f"{k} {v}" for k, v in sorted(rec.get("tool_counts", {}).items()))
        L.append(f"{len(q)} searches, {len(u)} fetches" + (f"; {meta}" if meta else "")
                 + (f". Tools: {tools}" if tools else ""))
        L += [f"- search: `{s['query']}`" for s in q]
        L += [f"- fetch: {s['url']}" + (f" ({s['asked']})" if s.get("asked") else "") for s in u]
        L.append("")
    L.insert(4, f"Totals: {totals['searches']} searches and {totals['fetches']} fetches across "
                f"{totals['tasks']} agents.\n")
    return "\n".join(L) + "\n"


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    e = sub.add_parser("extract")
    e.add_argument("--task", required=True)
    e.add_argument("--transcript", required=True)
    e.add_argument("--out", required=True)
    r = sub.add_parser("render")
    r.add_argument("--dir", required=True)
    r.add_argument("--tasks", required=True)
    r.add_argument("--out", required=True)
    a = ap.parse_args()
    if a.cmd == "extract":
        rec = dict(task=a.task, **extract(_load_transcript(a.transcript)))
        Path(a.out).write_text(json.dumps(rec, indent=1, ensure_ascii=False) + "\n")
    else:
        Path(a.out).write_text(render(a.dir, [t for t in a.tasks.split(",") if t]))


if __name__ == "__main__":
    main()
