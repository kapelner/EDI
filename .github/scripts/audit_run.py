#!/usr/bin/env python3
"""Driver for the scheduled audit jobs (.github/workflows/audit.yml).

    audit_run.py gate      --audit NAME --nth N --event E          -> run=true|false
    audit_run.py prepare   --audit NAME --notes DIR --work DIR     -> mechanical findings, batches
    audit_run.py finish    --audit NAME --notes DIR --work DIR --results DIR
    audit_run.py publish   --audit NAME --notes DIR --work DIR     -> PR or issue (needs gh)
    audit_run.py save-notes --notes DIR --message M                -> commit + push audit-notes

Plan: R/package_metadata/new_feature_plans/v1_0_6/audit_jobs_framework.md (Part 1).
"""
import argparse
import json
import os
import random
import subprocess
import time
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import audit_common as ac  # noqa: E402

BOT_NAME = "github-actions[bot]"
BOT_EMAIL = "41898282+github-actions[bot]@users.noreply.github.com"


def out(github_output, **kv):
    if not github_output:
        for k, v in kv.items():
            print(f"{k}={v}")
        return
    with open(github_output, "a") as f:
        for k, v in kv.items():
            f.write(f"{k}={v}\n")


def run_url():
    s, r, i = (os.environ.get(k, "") for k in ("GITHUB_SERVER_URL", "GITHUB_REPOSITORY", "GITHUB_RUN_ID"))
    return f"{s}/{r}/actions/runs/{i}" if r else "(local run)"


def gh(*args, check=True, input=None):
    r = subprocess.run(["gh", *args], capture_output=True, text=True, input=input)
    if check and r.returncode:
        raise RuntimeError(f"gh {' '.join(args)}: {r.stderr.strip()}")
    return r.stdout.strip()


def context(a, module=None):
    module = module or ac.load_audit(a.audit)
    spec = ac.spec_of(module)
    notes = ac.Notes(a.notes, spec["name"])
    return module, spec, notes, ac.Context(spec, a.repo, notes, a.work, scope=getattr(a, "scope", "auto"),
                                           sha=os.environ.get("GITHUB_SHA", ""),
                                           event=os.environ.get("GITHUB_EVENT_NAME", "schedule"),
                                           run_url=run_url())


# ---------------------------------------------------------------- gate

def cmd_gate(a):
    due = ac.due_today(a.nth, ac.now_utc(), a.event)
    out(a.github_output, run="true" if due else "false")
    print("due today" if due else f"not the week of the month this job runs (nth={a.nth})")
    return 0


# ---------------------------------------------------------------- harvest closed PRs

def harvest(spec, notes):
    """Settle the findings of the audit's last PR if it was merged or closed since."""
    m = notes.manifest()
    pr = m.get("open_pr")
    if not pr:
        return []
    try:
        state = gh("pr", "view", str(pr), "--json", "state", "--jq", ".state")
    except (RuntimeError, FileNotFoundError) as e:
        print(f"could not read PR #{pr}: {e}")
        return []
    if state == "OPEN":
        return []

    def read_main(path):
        r = subprocess.run(["git", "show", f"origin/HEAD:{path}"], capture_output=True, text=True)
        if r.returncode:
            r = subprocess.run(["git", "show", f"HEAD:{path}"], capture_output=True, text=True)
        return r.stdout if not r.returncode else None

    hist, lines = ac.harvest_pr(notes.findings(), state, pr, read_main)
    notes.save_findings(hist)
    notes.add_decisions(lines)
    m["open_pr"] = None
    notes.save_manifest(m)
    print(f"PR #{pr} is {state}: {len(lines)} finding(s) recorded as rejected")
    return lines


# ---------------------------------------------------------------- prepare

def cmd_prepare(a):
    module, spec, notes, ctx = context(a)
    work = Path(a.work)
    (work / "batches").mkdir(parents=True, exist_ok=True)
    if not a.no_harvest:
        harvest(spec, notes)
        ctx.manifest = notes.manifest()
    history = notes.findings()

    mech = []
    if hasattr(module, "mechanical"):
        raw = module.mechanical(ctx) or []
        mech = ac.drop_rejected([ac.normalise_finding(spec["name"], f, "mechanical") for f in raw], history)
    (work / "mechanical.json").write_text(json.dumps(mech, indent=1))

    units = module.units(ctx) if (spec["claude"] and hasattr(module, "units")) else {}
    max_units = spec["max_batches"] * spec["batch_size"]
    chosen, reasons, rolled = ac.select_units(units, ctx.manifest, ctx.scope, spec["cycle_weeks"], ctx.now,
                                              max_units, spec["period"])
    batches = ac.make_batches(chosen, units, spec)
    decisions = notes.decisions()
    for b in batches:
        payload = {"audit": spec["name"], "batch": b["id"], "model": b["model"],
                   "units": [{"id": u, "reason": reasons[u], **(units[u].get("context") or {})}
                             for u in b["units"]]}
        (work / "batches" / f"{b['id']}.json").write_text(json.dumps(payload, indent=1))
    (work / "decisions.md").write_text(decisions or "(no settled decisions yet)\n")
    plan = {"units": {u: {k: units[u].get(k) for k in ("hash", "deps")} for u in units},
            "chosen": chosen, "reasons": reasons, "rolled": rolled,
            "batches": [{"id": b["id"], "model": b["model"], "units": b["units"]} for b in batches]}
    (work / "plan.json").write_text(json.dumps(plan, indent=1))
    matrix = [{"id": b["id"], "model": b["model"]} for b in batches]
    out(a.github_output, batches=json.dumps(matrix), claude="true" if matrix else "false")
    print(f"{len(mech)} mechanical finding(s); {len(units)} unit(s), {len(chosen)} chosen in "
          f"{len(batches)} batch(es), {len(rolled)} rolled to the next run")
    return 0


# ---------------------------------------------------------------- finish

def load_results(results_dir, plan):
    """Agent outputs: results/<batch>.json (structured output) or <batch>.notrun."""
    results, notrun = [], []
    rd = Path(results_dir) if results_dir else None
    for b in plan.get("batches", []):
        p = rd / f"{b['id']}.json" if rd else None
        if p and p.exists():
            try:
                r = json.loads(p.read_text())
                r["_batch"] = b["id"]
                r["_units"] = b["units"]
                results.append(r)
                continue
            except ValueError:
                pass
        reason = ""
        if rd and (rd / f"{b['id']}.notrun").exists():
            reason = (rd / f"{b['id']}.notrun").read_text().strip()
        notrun.append({"batch": b["id"], "units": b["units"], "reason": reason or "no output"})
    return results, notrun


def cmd_finish(a):
    module, spec, notes, ctx = context(a)
    work = Path(a.work)
    plan = json.loads((work / "plan.json").read_text())
    mech = json.loads((work / "mechanical.json").read_text())
    results, notrun = load_results(a.results, plan)
    history = notes.findings()

    parts = module.apply(ctx, results, mech) if hasattr(module, "apply") else {}
    parts = parts or {}
    if not hasattr(module, "apply"):
        parts = {"mechanical": [f.get("text", "") for f in mech]}

    # Findings this run proposes or reports: keep for the history.
    proposed = [ac.normalise_finding(spec["name"], f, f.get("source", "claude"))
                for f in parts.pop("proposed", [])]
    proposed = ac.drop_rejected(proposed, history)
    known = {h["id"] for h in history}
    stamp = ac.now_utc().isoformat(timespec="seconds")
    for f in proposed + mech:
        if f["id"] not in known:
            history.append({**{k: v for k, v in f.items() if not k.startswith("_")},
                            "status": "proposed" if f.get("applied_file") else "reported",
                            "first_seen": stamp, "run": os.environ.get("GITHUB_RUN_ID", "")})
            known.add(f["id"])
    notes.save_findings(history)

    # Units an agent actually covered get their new hashes; the rest stay due.
    covered = set()
    for r in results:
        covered.update(r.get("units_checked") or r["_units"])
    open_by_unit = {}
    for f in proposed:
        open_by_unit[f["unit"]] = open_by_unit.get(f["unit"], 0) + 1
    m = notes.manifest()
    for u in covered:
        if u not in plan["units"]:
            continue
        m["units"][u] = {**plan["units"][u], "audited_at": stamp, "run": os.environ.get("GITHUB_RUN_ID", ""),
                         "open_findings": open_by_unit.get(u, 0)}
    for u in list(m["units"]):
        if u not in plan["units"] and plan["units"]:
            del m["units"][u]   # the unit no longer exists
    m["last_run"] = stamp
    notes.save_manifest(m)

    coverage = {
        "units in scope": len(plan["units"]),
        "re-read this run": f"{len(covered)} of {len(plan['chosen'])} chosen "
                            f"({', '.join(f'{v} {k}' for k, v in _count(plan['reasons'], covered).items()) or 'none'})",
        "rolled to the next run": len(plan["rolled"]),
        "batches NOT RUN": ", ".join(f"{n['batch']} ({n['reason']})" for n in notrun) or "none",
        "mechanical findings": len(mech),
    }
    report = ac.render_report(spec, parts, coverage, ctx.run_url)
    (work / "report.md").write_text(report)
    (work / "proposed.json").write_text(json.dumps([f["id"] for f in proposed if f.get("applied_file")]))
    changed = subprocess.run(["git", "status", "--porcelain"], capture_output=True, text=True,
                             cwd=a.repo).stdout.strip() != ""
    findings = ac.has_findings(parts)
    out(a.github_output, changed="true" if changed else "false", findings="true" if findings else "false")
    print(report)
    return 0


def _count(reasons, covered):
    c = {}
    for u in covered:
        r = reasons.get(u, "other").split(" (")[0]
        c[r] = c.get(r, 0) + 1
    return c


# ---------------------------------------------------------------- publish

def cmd_publish(a):
    module, spec, notes, ctx = context(a)
    work = Path(a.work)
    report = ac.fit_body((work / "report.md").read_text(), run_url())
    m = notes.manifest()
    label = spec["label"]
    gh("label", "create", label, "--color", "5319E7", "--description", f"{spec['title']} findings",
       check=False)
    if spec["report"] == "issue":
        return publish_issue(spec, notes, m, report, label, a.findings == "true")
    return publish_pr(spec, notes, m, report, label, a.changed == "true", work, a.repo,
                      a.findings == "true")


def publish_issue(spec, notes, m, report, label, findings):
    issue = gh("issue", "list", "--label", label, "--state", "open", "--json", "number",
               "--jq", ".[0].number // empty", check=False)
    body_hash = ac.text_hash(report.split("\nRun: ")[0])
    if findings:
        if issue and m.get("issue_hash") == body_hash:
            print(f"issue #{issue} already says this; not notifying again")
        elif issue:
            gh("issue", "edit", issue, "--body", report)
            gh("issue", "comment", issue, "--body", "The findings changed; the issue body is updated. "
               + report.split("\nRun: ")[-1].strip())
        else:
            gh("issue", "create", "--title", f"{spec['title']}: findings", "--label", label, "--body", report)
        m["issue_hash"] = body_hash
    elif issue:
        gh("issue", "close", issue, "--comment", "Clean on this run. " + report.split("\nRun: ")[-1].strip())
        m["issue_hash"] = None
    notes.save_manifest(m)
    return 0


def publish_pr(spec, notes, m, report, label, changed, work, repo, findings=False):
    branch = f"audit/{spec['name']}"
    existing = gh("pr", "list", "--head", branch, "--state", "open", "--json", "number",
                  "--jq", ".[0].number // empty", check=False)
    if not changed:
        if existing:
            gh("pr", "comment", existing, "--body", report)
            print("no changes to propose; findings added to the open PR")
            return 0
        # Findings but nothing to commit (an audit whose findings all need a human): report
        # them in the audit's issue, which closes itself on a clean run.
        print("no changes to propose; reporting the findings in an issue")
        return publish_issue(spec, notes, m, report, label, findings)
    if existing:
        # Keep commits the owner pushed to the branch: never force over them.
        authors = gh("pr", "view", existing, "--json", "commits",
                     "--jq", "[.commits[].authors[].login] | unique | join(\",\")", check=False)
        humans = [x for x in authors.split(",") if x and x not in ("github-actions", "github-actions[bot]",
                                                                   "app/github-actions")]
        if humans:
            gh("pr", "comment", existing, "--body",
               "This run found changes to propose, but the branch has commits by "
               f"{', '.join(humans)}, so it was left as it is. The changes will be proposed again after "
               "this PR is merged or closed.\n\n" + report)
            subprocess.run(["git", "checkout", "--", "."], cwd=repo)
            return 0
    g = lambda *x: subprocess.run(["git", *x], cwd=repo, check=True, capture_output=True, text=True)
    g("config", "user.name", BOT_NAME)
    g("config", "user.email", BOT_EMAIL)
    g("switch", "-C", branch)
    g("add", "-A")
    g("commit", "-qm", f"{spec['title']}: proposed changes\n\n{run_url()}")
    g("push", "--force", "origin", f"{branch}:{branch}")
    title = f"{spec['title']}: proposed changes"
    draft = ["--draft"] if spec.get("pr_draft") else []
    if existing:
        gh("pr", "edit", existing, "--body", report)
        if draft:
            # New changes go back through the follow-up check before the PR is ready again.
            gh("pr", "ready", existing, "--undo", check=False)
        pr = existing
    else:
        url = gh("pr", "create", "--base", os.environ.get("AUDIT_BASE", "main"), "--head", branch,
                 "--label", label, "--title", title, "--body", report, *draft)
        pr = url.rstrip("/").split("/")[-1]
    m["open_pr"] = int(pr)
    notes.save_manifest(m)
    ids = set(json.loads((work / "proposed.json").read_text()))
    hist = notes.findings()
    for h in hist:
        if h["id"] in ids and h.get("status") == "proposed":
            h["pr"] = int(pr)
    notes.save_findings(hist)
    print(f"PR #{pr}")
    return 0


# ---------------------------------------------------------------- save notes

def cmd_save_notes(a):
    root = Path(a.notes)
    g = lambda *x, check=True: subprocess.run(["git", *x], cwd=root, capture_output=True, text=True, check=check)
    if not (root / ".git").exists():
        g("init", "-q", "-b", ac.NOTES_BRANCH)
    repo = os.environ.get("GITHUB_REPOSITORY")
    if repo:
        # The token goes into the remote only here, at push time, never into an uploaded clone.
        url = f"https://x-access-token:{os.environ.get('GH_TOKEN', '')}@github.com/{repo}.git"
        if g("remote", "get-url", "origin", check=False).returncode:
            g("remote", "add", "origin", url)
        else:
            g("remote", "set-url", "origin", url)
    g("config", "user.name", BOT_NAME)
    g("config", "user.email", BOT_EMAIL)
    g("add", "-A")
    if not g("status", "--porcelain").stdout.strip():
        print("notes unchanged")
        return 0
    g("commit", "-qm", a.message)
    # Many audits can finish together (a first run of all of them creates the branch at once),
    # so retry with a random wait; each audit writes only its own folder, so rebases are clean.
    attempts = 10
    for attempt in range(attempts):
        if g("push", "-q", "origin", f"HEAD:{ac.NOTES_BRANCH}", check=False).returncode == 0:
            print("notes saved")
            return 0
        time.sleep(random.uniform(2, 10))
        # Another audit saved its notes meanwhile; each audit writes only its own folder.
        g("fetch", "-q", "origin", ac.NOTES_BRANCH, check=False)
        if g("rebase", "-q", f"origin/{ac.NOTES_BRANCH}", check=False).returncode:
            g("rebase", "--abort", check=False)
            print("::warning::could not rebase the audit notes")
            return 1
    print(f"::warning::could not save the audit notes after {attempts} attempts")
    return 1


def main(argv=None):
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    for name in ("gate", "prepare", "finish", "publish"):
        p = sub.add_parser(name)
        p.add_argument("--audit", required=True)
        p.add_argument("--github-output", default=os.environ.get("GITHUB_OUTPUT"))
        p.add_argument("--repo", default=".")
        if name == "gate":
            p.add_argument("--nth", type=int, default=0)
            p.add_argument("--event", default=os.environ.get("GITHUB_EVENT_NAME", "schedule"))
            continue
        p.add_argument("--notes", required=True)
        p.add_argument("--work", required=True)
        p.add_argument("--scope", default="auto", choices=["auto", "all", "none"])
        if name == "prepare":
            p.add_argument("--no-harvest", action="store_true")
        if name == "finish":
            p.add_argument("--results")
        if name == "publish":
            p.add_argument("--changed", default="false")
            p.add_argument("--findings", default="false")
    p = sub.add_parser("save-notes")
    p.add_argument("--notes", required=True)
    p.add_argument("--message", default="audit notes")
    a = ap.parse_args(argv)
    return {"gate": cmd_gate, "prepare": cmd_prepare, "finish": cmd_finish, "publish": cmd_publish,
            "save-notes": cmd_save_notes}[a.cmd](a)


if __name__ == "__main__":
    sys.exit(main())
