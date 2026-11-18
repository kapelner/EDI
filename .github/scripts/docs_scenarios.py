#!/usr/bin/env python3
"""Driver for the weekly docs-only scenario job (.github/workflows/audit-docs-scenarios.yml).

v1.0.6-TODO-98 (owner decision 2026-11-18). Runbook:
R/package_metadata/new_feature_plans/v1_0_6/docs_only_scenario_runbook.md (section 7 describes this job).

    docs_scenarios.py plan    --repo R --notes N --work W [--requested changed|all|id,id]
        -> which areas are due, one kit per due area under W/kits/<id>/, W/plan.json
    docs_scenarios.py render  --kit K --lib L --run-dir D [--venv V]
        -> D/prompt.md and D/context/ for one area (runs on the agent runner, which has no checkout)
    docs_scenarios.py collect --kit K --run-dir D --out O [--outcome S] [--redact-env A,B]
        -> O/result.json plus the agent's files, secrets redacted
    docs_scenarios.py report  --repo R --notes N --plan P --results DIR --run-id I --findings-dir F
        -> updates the state in N, writes F/<date>-run<id>.md when there are new findings, report.md

Stdlib only. Areas come from .github/prompts/docs_scenario_areas.json, the prompt from
.github/prompts/docs_scenario.md, the agent's rules from section 4 of the runbook (pasted verbatim, so the
rules have one source).

State (the `audit-notes` branch, folder docs-scenarios/, saved with `audit_run.py save-notes`):

    docs-scenarios/state.json             {"areas": {id: {last_run_sha, last_run_at, last_run_id, last_outcome,
                                                          last_attempt_at, last_attempt_id, runs}}}
    docs-scenarios/learnings/<id>.md      what earlier runs learned; each run's agent reads it first, and
                                          the run's learnings_update.md is appended under a dated heading
    docs-scenarios/findings.jsonl         every finding ever reported: id, area, title, kind, run, date,
                                          status (open | filed | closed | dismissed), todo
    docs-scenarios/runs/<date>-run<id>/<area>/   that run's summary.md, findings.md, learnings_update.md

A finding's status is re-derived on every run from the repo: `filed` when an unticked TODO in
R/package_metadata/future_release_plans/*.md cites its id (`closed` when that TODO is ticked), `dismissed`
when R/package_metadata/audits/dismissed_decisions.md lists it. The coordinator files TODOs by hand
(runbook section 6); this job never writes to a release file.

Skip rule. An area runs when one of its paths changed between its last successful run and HEAD, after
scripts/significant_changes.py drops R, C++ and Python files whose only edits are comments or whitespace
(owner ruling 2026-11-17). For this job docs changes must count too, since the agent learns EDI only from
the docs. They do, with no extra rule: significant_changes.py counts every non-source file whenever git
says it changed, so man/*.Rd, vignettes/*.Rmd, articles, README_PYPI.md and the .pyi stub always count; a
roxygen-only edit to R/*.R is dropped as a comment there but reaches the area through the man/*.Rd file it
regenerates (the pre-push roxygen check keeps them in step); and a Python docstring is a string token, so
it counts as code. An area with no successful run yet, or whose last-run commit is no longer in history,
is due.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
CONFIG = ".github/prompts/docs_scenario_areas.json"
PROMPT = ".github/prompts/docs_scenario.md"
RUNBOOK = "R/package_metadata/new_feature_plans/v1_0_6/docs_only_scenario_runbook.md"
RELEASE_GLOB = "R/package_metadata/future_release_plans/release_v*.md"
DISMISSED = "R/package_metadata/audits/dismissed_decisions.md"
PY_CMAKE = "python/CMakeLists.txt"
PY_README = "python/README_PYPI.md"
ARTICLES = "R/EDI/vignettes/articles"
NOTES_DIR = "docs-scenarios"
KINDS = ("silent NA", "documented option fails", "false message", "useless message", "false docs",
         "insufficient docs", "accepted bad input", "silent change of your input", "reference mismatch",
         "inconsistency")
SECRET_PATTERNS = [re.compile(p) for p in (r"sk-ant-[A-Za-z0-9_\-]{10,}", r"gh[pousr]_[A-Za-z0-9]{20,}",
                                           r"github_pat_[A-Za-z0-9_]{20,}")]


# ---------------------------------------------------------------- config and state

def load_config(repo):
    cfg = json.loads((Path(repo) / CONFIG).read_text())
    d = cfg.get("defaults", {})
    ids = [a["id"] for a in cfg["areas"]]
    if len(ids) != len(set(ids)):
        raise SystemExit(f"duplicate area ids in {CONFIG}")
    for a in cfg["areas"]:
        if not re.fullmatch(r"[a-z0-9]+(-[a-z0-9]+)*", a["id"]):
            raise SystemExit(f"area id {a['id']!r} must be kebab-case")
        for k in ("model", "effort", "max_turns", "max_budget_usd", "minutes"):
            a.setdefault(k, d.get(k))
        a.setdefault("articles", [])
        a.setdefault("python", False)
    return cfg


class State:
    """docs-scenarios/ on the audit-notes clone."""

    def __init__(self, notes_root):
        self.dir = Path(notes_root) / NOTES_DIR
        (self.dir / "learnings").mkdir(parents=True, exist_ok=True)

    def load(self):
        p = self.dir / "state.json"
        return json.loads(p.read_text()) if p.exists() else {"areas": {}}

    def save(self, st):
        (self.dir / "state.json").write_text(json.dumps(st, indent=1, sort_keys=True) + "\n")

    def findings(self):
        p = self.dir / "findings.jsonl"
        if not p.exists():
            return []
        return [json.loads(x) for x in p.read_text().splitlines() if x.strip()]

    def save_findings(self, rows):
        (self.dir / "findings.jsonl").write_text("".join(json.dumps(r, sort_keys=True) + "\n" for r in rows))

    def learnings(self, area):
        p = self.dir / "learnings" / f"{area}.md"
        return p.read_text() if p.exists() else ""

    def append_learnings(self, area, heading, text):
        p = self.dir / "learnings" / f"{area}.md"
        old = p.read_text() if p.exists() else f"# Learnings: {area}\n\nAppended by each weekly docs-only scenario run.\n"
        p.write_text(old.rstrip("\n") + f"\n\n## {heading}\n\n{text.strip()}\n")


# ---------------------------------------------------------------- git and paths

def git(repo, *args, check=True):
    r = subprocess.run(["git", "-C", str(repo), *args], capture_output=True, text=True)
    if check and r.returncode:
        raise RuntimeError(f"git {' '.join(args)}: {r.stderr.strip()}")
    return r


def commit_exists(repo, sha):
    return bool(sha) and git(repo, "cat-file", "-e", f"{sha}^{{commit}}", check=False).returncode == 0


def python_kernel_sources(repo):
    p = Path(repo) / PY_CMAKE
    text = p.read_text() if p.exists() else ""
    return sorted(set(re.findall(r"\$\{EDI_SRC_DIR\}/([A-Za-z0-9_]+\.(?:cpp|h|hpp))", text)))


def area_paths(area, cfg, repo):
    """Repo-relative globs for an area, '@python_kernels' expanded, common paths added."""
    out = []
    for p in list(area["paths"]) + list(cfg.get("common_paths", [])):
        if p == "@python_kernels":
            out += [f"R/EDI/src/{f}" for f in python_kernel_sources(repo)]
        else:
            out.append(p)
    return list(dict.fromkeys(out))


def pathspecs(paths):
    return [f":(glob){p}" for p in paths]


def significant(repo, base, head, paths):
    sys.path.insert(0, str(Path(repo).resolve() / "scripts"))
    import significant_changes as sc  # noqa: E402  (scripts/, shared with every other change gate)
    return sc.significant_changes(str(repo), base, head, pathspecs(paths))


def due_reason(repo, area, cfg, rec, head):
    """(due, reason, changed_paths) for one area."""
    last = (rec or {}).get("last_run_sha")
    if not last:
        return True, "first run (no successful run recorded)", []
    if not commit_exists(repo, last):
        return True, f"last-run commit {last[:8]} is not in history", []
    if last == head:
        return False, f"already run at {head[:8]}", []
    changed = significant(repo, last, head, area_paths(area, cfg, repo))
    if changed:
        more = f" (+{len(changed) - 3} more)" if len(changed) > 3 else ""
        return True, f"{len(changed)} path(s) changed since {last[:8]}: " + ", ".join(changed[:3]) + more, changed
    return False, f"nothing relevant changed since {last[:8]}", []


def choose(cfg, state, due, requested):
    """Order due areas (never run first, then longest since last run) and cap a 'changed' run."""
    areas = {a["id"]: a for a in cfg["areas"]}
    if requested == "all":
        ids = list(areas)
    elif requested in ("changed", "", None):
        ids = [i for i in areas if due[i][0]]
    else:
        ids = [x.strip() for x in requested.split(",") if x.strip()]
        bad = [x for x in ids if x not in areas]
        if bad:
            raise SystemExit(f"unknown area(s) {bad}; known: {', '.join(areas)}")
    recs = state.get("areas", {})
    order = {x: k for k, x in enumerate(areas)}  # ties (e.g. never run) keep the config's order
    ids.sort(key=lambda i: (bool(recs.get(i, {}).get("last_run_at")), recs.get(i, {}).get("last_run_at") or "",
                            order[i]))
    deferred = []
    cap = cfg.get("defaults", {}).get("max_areas_per_run")
    if requested in ("changed", "", None) and cap and len(ids) > cap:
        ids, deferred = ids[:cap], ids[cap:]
    return ids, deferred


# ---------------------------------------------------------------- finding status from the repo

def release_citations(repo):
    """{finding id: (status, 'v1.0.6-TODO-30')} from the release files' TODO entries."""
    out = {}
    for f in sorted(Path(repo).glob(RELEASE_GLOB)):
        m = re.match(r"release_v(\d+)_(\d+)_(\d+)\.md$", f.name)
        ver = ".".join(m.groups()) if m else f.stem
        todo, ticked = None, False
        for line in f.read_text(errors="replace").splitlines():
            t = re.match(r"\s*- \[( |x|X)\] TODO-(\d+)", line)
            if t:
                todo, ticked = f"v{ver}-TODO-{t.group(2)}", t.group(1) != " "
            for fid in re.findall(r"\bds-[a-z0-9-]+-\d+-f\d+\b", line):
                if todo:
                    out[fid] = ("closed" if ticked else "filed", todo)
    return out


def dismissed_ids(repo):
    p = Path(repo) / DISMISSED
    return set(re.findall(r"\bds-[a-z0-9-]+-\d+-f\d+\b", p.read_text())) if p.exists() else set()


def refresh_statuses(repo, rows):
    cited, dismissed = release_citations(repo), dismissed_ids(repo)
    for r in rows:
        if r["id"] in dismissed:
            r["status"], r["todo"] = "dismissed", None
        elif r["id"] in cited:
            r["status"], r["todo"] = cited[r["id"]]
        else:
            r["status"], r["todo"] = "open", None
    return rows


def known_findings_md(area, rows):
    mine = [r for r in rows if r["area"] == area]
    if not mine:
        return f"# Known findings: {area}\n\nNone yet: this is the first run that reports findings for this area.\n"
    lines = [f"# Known findings: {area}", "",
             "Status: open = reported, not yet triaged; filed = an open TODO cites it; closed = that TODO is done "
             "(re-check it: a regression is a new finding); dismissed = the owner judged it not a bug.", "",
             "| Id | Status | TODO | First seen | Kind | Finding |", "|---|---|---|---|---|---|"]
    for r in sorted(mine, key=lambda r: (r["date"], r["id"])):
        title = r["title"].replace("|", "\\|")
        lines.append(f"| `{r['id']}` | {r['status']} | {r.get('todo') or ''} | {r['date']} | {r.get('kind') or ''} | {title} |")
    return "\n".join(lines) + "\n"


# ---------------------------------------------------------------- prompt

def runbook_rules(repo):
    """Section 4 of the runbook, verbatim, minus its first line (an instruction to the coordinator)."""
    text = (Path(repo) / RUNBOOK).read_text()
    m = re.search(r"^## 4\. [^\n]*\n(.*?)^## 5\. ", text, re.S | re.M)
    if not m:
        raise SystemExit(f"could not find section 4 in {RUNBOOK}")
    body = m.group(1).strip()
    body = re.sub(r"^Give these to the agent verbatim[^\n]*\n+", "", body)
    return body.strip()


def fill(template, values):
    out = template
    for k, v in values.items():
        out = out.replace("{{" + k + "}}", v)
    return out


# ---------------------------------------------------------------- plan

def cmd_plan(a):
    repo, work = Path(a.repo), Path(a.work)
    cfg = load_config(repo)
    st = State(a.notes)
    state = st.load()
    head = git(repo, "rev-parse", a.head).stdout.strip()
    due = {}
    for area in cfg["areas"]:
        due[area["id"]] = due_reason(repo, area, cfg, state["areas"].get(area["id"]), head)
    ids, deferred = choose(cfg, state, due, a.requested)
    rows = refresh_statuses(repo, st.findings())
    template = (repo / PROMPT).read_text()
    rules = runbook_rules(repo)
    by_id = {x["id"]: x for x in cfg["areas"]}
    matrix = []
    for i in ids:
        area = by_id[i]
        kit = work / "kits" / i
        (kit / "context" / "articles").mkdir(parents=True, exist_ok=True)
        (kit / "pkg").mkdir(exist_ok=True)
        (kit / "tool").mkdir(exist_ok=True)
        prompt = fill(template, {"AREA": area["title"], "TASK": area["task"], "RULES": rules,
                                 "MINUTES": str(area["minutes"])})
        (kit / "prompt_template.md").write_text(prompt)
        (kit / "area.json").write_text(json.dumps({**area, "head": head, "reason": due[i][1]}, indent=1))
        learn = st.learnings(i) or (f"# Learnings: {i}\n\nNo earlier run has recorded learnings for this area yet.\n")
        (kit / "context" / "learnings.md").write_text(learn)
        (kit / "context" / "known_findings.md").write_text(known_findings_md(i, rows))
        changed = due[i][2]
        ch = [f"# Changes since the last run: {i}", "", f"Why this area runs: {due[i][1]}.", ""]
        ch += [f"- `{p}`" for p in changed[:200]] or ["(no list: first run, or a run requested by hand)"]
        (kit / "context" / "changes.md").write_text("\n".join(ch) + "\n")
        for art in area["articles"]:
            src = repo / ARTICLES / art
            if src.exists():
                shutil.copy(src, kit / "context" / "articles" / art)
        if area["python"] and (repo / PY_README).exists():
            (kit / "context" / "python").mkdir(exist_ok=True)
            shutil.copy(repo / PY_README, kit / "context" / "python" / "README_PYPI.md")
        # DESCRIPTION only: setup-r-dependencies installs EDI's dependencies from it. No other package file.
        shutil.copy(repo / "R/EDI/DESCRIPTION", kit / "pkg" / "DESCRIPTION")
        shutil.copy(Path(__file__), kit / "tool" / "docs_scenarios.py")
        matrix.append({"area": i, "python": bool(area["python"]), "job_minutes": int(area["minutes"]) + 30})
    plan = {"head": head, "requested": a.requested, "areas": ids, "deferred": deferred,
            "due": {k: {"due": v[0], "reason": v[1]} for k, v in due.items()}}
    work.mkdir(parents=True, exist_ok=True)
    (work / "plan.json").write_text(json.dumps(plan, indent=1))
    lines = [f"# Docs-only scenarios: plan at {head[:8]}", "", "| Area | Runs | Why |", "|---|---|---|"]
    for area in cfg["areas"]:
        i = area["id"]
        runs = "yes" if i in ids else ("deferred (cap)" if i in deferred else "no")
        lines.append(f"| `{i}` | {runs} | {due[i][1]} |")
    (work / "plan.md").write_text("\n".join(lines) + "\n")
    print("\n".join(lines), file=sys.stderr)
    out(a.github_output, has="true" if ids else "false", matrix=json.dumps(matrix),
        python="true" if any(m["python"] for m in matrix) else "false")
    return 0


def out(github_output, **kv):
    text = "".join(f"{k}={v}\n" for k, v in kv.items())
    if github_output:
        with open(github_output, "a") as fh:
            fh.write(text)
    else:
        print(text, end="")


# ---------------------------------------------------------------- render (agent runner)

def cmd_render(a):
    kit, run = Path(a.kit), Path(a.run_dir)
    area = json.loads((kit / "area.json").read_text())
    run.mkdir(parents=True, exist_ok=True)
    ctx = run / "context"
    if ctx.exists():
        shutil.rmtree(ctx)
    shutil.copytree(kit / "context", ctx)
    py = area.get("python") and a.venv
    values = {"LIB": a.lib, "RUN_DIR": str(run), "CONTEXT_DIR": str(ctx),
              "PYTHON_LINE": (f"\nThe Python package edi_kernels is installed in the virtual environment {a.venv}; run "
                              f"Python as `{a.venv}/bin/python`. numpy, scipy, pandas, statsmodels and lifelines are "
                              "installed there for cross-checks.\n") if py else "",
              "PYTHON_DOCS_LINE": (f"\n- `{ctx}/python/README_PYPI.md`: the package's PyPI README.") if py else "",
              "PYTHON_PATH_NOTE": f", {a.venv}" if py else ""}
    text = fill((kit / "prompt_template.md").read_text(), values)
    left = sorted(set(re.findall(r"\{\{[A-Z_]+\}\}", text)))
    if left:
        raise SystemExit(f"unfilled placeholders in the prompt: {left}")
    (run / "prompt.md").write_text(text)
    out(a.github_output, model=area["model"], max_turns=str(area["max_turns"]),
        budget=str(area["max_budget_usd"]), effort=(f"--effort {area['effort']}" if area.get("effort") else ""),
        minutes=str(area["minutes"]))
    return 0


# ---------------------------------------------------------------- collect (agent runner)

def redact(text, secrets):
    for s in secrets:
        if s and len(s) >= 8:
            text = text.replace(s, "[REDACTED]")
    for p in SECRET_PATTERNS:
        text = p.sub("[REDACTED]", text)
    return text


def parse_findings(text):
    """[{n, title, kind, body, has_repro}] from findings.md (### F<n>: headings)."""
    parts = re.split(r"^### F(\d+):[ \t]*(.*)$", text, flags=re.M)
    found = []
    for k in range(1, len(parts) - 1, 3):
        n, title, body = int(parts[k]), parts[k + 1].strip(), parts[k + 2].strip()
        km = re.search(r"^- Kind:[ \t]*(.+)$", body, re.M)
        kind = km.group(1).strip() if km else ""
        kind = next((x for x in KINDS if x.lower() == kind.lower().strip("` ")), kind)
        rm = re.search(r"^- Repro:.*?```[a-zA-Z]*\n(.*?)```", body, re.S | re.M)
        found.append({"n": n, "title": title, "kind": kind, "body": body,
                      "has_repro": bool(rm and rm.group(1).strip())})
    return found


def cmd_collect(a):
    kit, run, dest = Path(a.kit), Path(a.run_dir), Path(a.out)
    area = json.loads((kit / "area.json").read_text())
    dest.mkdir(parents=True, exist_ok=True)
    secrets = [os.environ.get(n, "") for n in (a.redact_env or "").split(",") if n]
    files = {}
    for name in ("findings.md", "summary.md", "learnings_update.md", "analysis.R", "analysis.py"):
        p = run / name
        if p.is_file():
            files[name] = redact(p.read_text(errors="replace"), secrets)[:400_000]
            (dest / name).write_text(files[name])
    if a.notrun:
        status, note = "notrun", a.notrun
    elif files.get("summary.md", "").strip():
        status, note = "ok", f"agent step outcome: {a.outcome or 'unknown'}"
    elif files.get("findings.md", "").strip():
        status, note = "partial", f"no summary.md (agent step outcome: {a.outcome or 'unknown'}); findings kept, area re-runs next week"
    else:
        status, note = "notrun", f"agent left no summary.md or findings.md (step outcome: {a.outcome or 'unknown'})"
    findings = parse_findings(files.get("findings.md", ""))
    result = {"area": area["id"], "head": area["head"], "status": status, "note": note, "findings": findings,
              "reason": area.get("reason", "")}
    (dest / "result.json").write_text(json.dumps(result, indent=1))
    for t in a.transcripts or []:
        p = Path(t)
        if p.is_file():
            p.write_text(redact(p.read_text(errors="replace"), secrets))
    print(f"{area['id']}: {status} ({len(findings)} finding(s)); {note}")
    return 0


# ---------------------------------------------------------------- report (publish runner)

def finding_id(area, run_id, n):
    return f"ds-{area}-{run_id}-f{n}"


def cmd_report(a):
    repo = Path(a.repo)
    st = State(a.notes)
    state = st.load()
    plan = json.loads(Path(a.plan).read_text())
    date = a.date or dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%d")
    now = dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds")
    rows = refresh_statuses(repo, st.findings())
    known_ids = {r["id"] for r in rows}
    results = {}
    for area in plan["areas"]:
        p = Path(a.results) / area / "result.json"
        results[area] = (json.loads(p.read_text()) if p.exists()
                         else {"area": area, "status": "notrun", "note": "no result (job failed or was cancelled)",
                               "findings": []})
    new_rows, sections, incomplete_total = [], [], 0
    run_dir = st.dir / "runs" / f"{date}-run{a.run_id}"
    for area, res in results.items():
        rec = state["areas"].setdefault(area, {"runs": 0})
        rec["last_attempt_at"], rec["last_attempt_id"] = now, str(a.run_id)
        rec["last_outcome"] = res["status"]
        src = Path(a.results) / area
        if res["status"] in ("ok", "partial"):
            rec["runs"] = rec.get("runs", 0) + 1
            (run_dir / area).mkdir(parents=True, exist_ok=True)
            for name in ("summary.md", "findings.md", "learnings_update.md"):
                if (src / name).exists():
                    shutil.copy(src / name, run_dir / area / name)
            upd = (src / "learnings_update.md").read_text() if (src / "learnings_update.md").exists() else ""
            if upd.strip():
                st.append_learnings(area, f"Run {date} (run {a.run_id}, {plan['head'][:8]}, {res['status']})", upd)
        if res["status"] == "ok":
            rec.update(last_run_sha=plan["head"], last_run_at=now, last_run_id=str(a.run_id))
        good, bad = [], []
        for f in res["findings"]:
            fid = finding_id(area, a.run_id, f["n"])
            (good if f["has_repro"] else bad).append((fid, f))
        incomplete_total += len(bad)
        for fid, f in good:
            if fid not in known_ids:
                new_rows.append({"id": fid, "area": area, "title": f["title"], "kind": f["kind"],
                                 "run": str(a.run_id), "date": date, "status": "open", "todo": None})
        sections.append((area, res, good, bad))
    st.save(state)
    st.save_findings(rows + new_rows)

    run_url = a.run_url or ""
    head = plan["head"]
    lines = [f"# Docs-only scenario findings {date} (run {a.run_id})", "",
             f"Commit `{head[:8]}`" + (f", [run]({run_url})" if run_url else "") + ". Workflow "
             "`.github/workflows/audit-docs-scenarios.yml` (v1.0.6-TODO-98); procedure in "
             f"`{RUNBOOK}` section 6.", "",
             "Each finding is an unverified report by a docs-only agent. Verify it against the source, then file it "
             "as a release-prefixed TODO that cites its id (that marks it `filed` for later runs), or list the id in "
             f"`{DISMISSED}` with a reason (that marks it `dismissed`). This job never writes to a release file.", "",
             "| Area | Result | New findings | Why it ran |", "|---|---|---|---|"]
    for area, res, good, bad in sections:
        extra = f" (+{len(bad)} without a repro)" if bad else ""
        lines.append(f"| `{area}` | {res['status']} | {len(good)}{extra} | {res.get('reason') or plan['due'].get(area, {}).get('reason', '')} |")
    if plan.get("deferred"):
        lines += ["", "Deferred to a later run by the per-run cap: " + ", ".join(f"`{x}`" for x in plan["deferred"]) + "."]
    for area, res, good, bad in sections:
        lines += ["", f"## `{area}`", "", f"Result: {res['status']}. {res['note']}"]
        for fid, f in good:
            lines += ["", f"### `{fid}`: {f['title']}", "", f["body"]]
        if bad:
            lines += ["", "Reported without a runnable repro (not registered; the agent was told to drop these):", ""]
            lines += [f"- F{f['n']}: {f['title']}" for _, f in bad]
        summ = Path(a.results) / area / "summary.md"
        if summ.exists():
            lines += ["", "<details><summary>Agent's summary</summary>", "", summ.read_text().strip(), "", "</details>"]
    report = "\n".join(lines) + "\n"
    Path(a.report).write_text(report)
    status = "FINDINGS" if new_rows else "NONE"
    if new_rows:
        fdir = repo / a.findings_dir
        fdir.mkdir(parents=True, exist_ok=True)
        (fdir / f"{date}-run{a.run_id}.md").write_text(report)
    out(a.github_output, status=status, date=date, new=str(len(new_rows)))
    print(f"{status}: {len(new_rows)} new finding(s), {incomplete_total} without a repro")
    return 0


# ---------------------------------------------------------------- CLI

def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("plan")
    p.add_argument("--repo", default=".")
    p.add_argument("--notes", required=True)
    p.add_argument("--work", required=True)
    p.add_argument("--requested", default="changed")
    p.add_argument("--head", default="HEAD")
    p.add_argument("--github-output", default=os.environ.get("GITHUB_OUTPUT"))
    p = sub.add_parser("render")
    p.add_argument("--kit", required=True)
    p.add_argument("--lib", required=True)
    p.add_argument("--run-dir", required=True)
    p.add_argument("--venv", default="")
    p.add_argument("--github-output", default=os.environ.get("GITHUB_OUTPUT"))
    p = sub.add_parser("collect")
    p.add_argument("--kit", required=True)
    p.add_argument("--run-dir", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--outcome", default="")
    p.add_argument("--notrun", default="")
    p.add_argument("--redact-env", default="")
    p.add_argument("--transcripts", nargs="*")
    p = sub.add_parser("report")
    p.add_argument("--repo", default=".")
    p.add_argument("--notes", required=True)
    p.add_argument("--plan", required=True)
    p.add_argument("--results", required=True)
    p.add_argument("--run-id", required=True)
    p.add_argument("--run-url", default="")
    p.add_argument("--date", default="")
    p.add_argument("--findings-dir", default="R/package_metadata/audits/docs_scenario_findings")
    p.add_argument("--report", required=True)
    p.add_argument("--github-output", default=os.environ.get("GITHUB_OUTPUT"))
    a = ap.parse_args(argv)
    return {"plan": cmd_plan, "render": cmd_render, "collect": cmd_collect, "report": cmd_report}[a.cmd](a)


if __name__ == "__main__":
    sys.exit(main())
