#!/usr/bin/env python3
"""One table of every scheduled audit: schedule, last run, result, open PR or issue.

Workflow: .github/workflows/audit-status.yml (after each audit run, and daily). The table is the
body of one issue labelled `audit-status`, edited in place, so its URL never changes; it also goes
into the job summary. Plan: R/package_metadata/new_feature_plans/v1_0_6/audit_jobs_framework.md.

The audits are the `.github/workflows/audit-<name>.yml` callers. Their names are
`audit · <daily|weekly|monthly> · <name>`, so the Actions sidebar groups them; this table follows
the same grouping. A monthly audit runs on a weekly cron and its gate keeps one week of the month,
so a scheduled run in another week ends "not due" (every audit job skipped), not "passed".
"""
import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

LABEL = "audit-status"
TITLE = "Audit status"
DAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
ORDINAL = {1: "1st", 2: "2nd", 3: "3rd", 4: "4th"}
FREQ_ORDER = {"daily": 0, "weekly": 1, "monthly": 2}


def gh(*args, check=True):
    r = subprocess.run(["gh", *args], capture_output=True, text=True)
    if check and r.returncode:
        raise RuntimeError(f"gh {' '.join(args[:4])}: {r.stderr.strip()}")
    return r.stdout


def callers(wf_dir):
    """[{file, audit, name, freq, schedule}] from the caller workflows."""
    out = []
    for p in sorted(Path(wf_dir).glob("audit-*.yml")):
        if p.name == "audit-status.yml":
            continue
        s = p.read_text()
        name = re.search(r"^name:\s*(.+)$", s, re.M)
        audit = re.search(r"^[ \t]+audit:[ \t]*([\w-]+)[ \t]*$", s, re.M)
        cron = re.search(r'cron:\s*"([^"]+)"', s)
        nth = re.search(r"^[ \t]+nth:[ \t]*(\d+)", s, re.M)
        out.append({"file": p.name, "audit": audit.group(1) if audit else p.stem[len("audit-"):],
                    "name": name.group(1).strip() if name else p.stem,
                    **describe(cron.group(1) if cron else None, int(nth.group(1)) if nth else 0)})
    return sorted(out, key=lambda c: (FREQ_ORDER.get(c["freq"], 9), c["audit"]))


def describe(cron, nth):
    if not cron:
        return {"freq": "manual", "schedule": "manual only"}
    minute, hour, _dom, _mon, dow = cron.split()[:5]
    at = f"{int(hour):02d}:{int(minute):02d} UTC"
    if dow == "*":
        return {"freq": "daily", "schedule": f"daily {at}"}
    day = DAYS[int(dow) % 7] if dow.isdigit() else dow
    if nth:
        return {"freq": "monthly", "schedule": f"{ORDINAL.get(nth, str(nth) + 'th')} {day} {at}"}
    return {"freq": "weekly", "schedule": f"{day} {at}"}


def result_of(run, jobs):
    """A short result for a run and its jobs (list of {name, conclusion})."""
    if run is None:
        return "never run"
    if run.get("status") != "completed":
        return "running" if run.get("status") == "in_progress" else (run.get("status") or "queued")
    c = run.get("conclusion") or "unknown"
    if c == "success" and jobs:
        audit_jobs = [j for j in jobs if not j["name"].startswith(("verify-", "audit / verify"))]
        ran = [j for j in audit_jobs if j.get("conclusion") not in ("skipped", None)]
        if len(ran) <= 1 and any("prepare" in j["name"] for j in ran) and \
                any(j.get("conclusion") == "skipped" for j in audit_jobs):
            return "not due (gate)"
        return "passed"
    return {"failure": "FAILED", "startup_failure": "FAILED to start", "cancelled": "cancelled",
            "timed_out": "timed out"}.get(c, c)


def when(ts):
    return ts.replace("T", " ")[:16] + " UTC" if ts else ""


def render(rows, generated_at, run_url="", repo=""):
    lines = [f"# {TITLE}", "",
             f"Updated {when(generated_at)} by `.github/workflows/audit-status.yml`"
             + (f" ([run]({run_url}))" if run_url else "") + ". Edited in place; do not edit by hand.", ""]
    bad = [r for r in rows if r["result"].startswith(("FAILED", "timed out"))]
    lines.append(f"{len(rows)} audits; {len(bad)} failed on their last run"
                 + (": " + ", ".join(f"`{r['audit']}`" for r in bad) if bad else "") + ".")
    for freq in ("daily", "weekly", "monthly", "manual"):
        group = [r for r in rows if r["freq"] == freq]
        if not group:
            continue
        lines += ["", f"## {freq.capitalize()}", "",
                  "| Audit | Schedule | Last run | Result | Open PR / issue |", "|---|---|---|---|---|"]
        for r in group:
            last = f"[{when(r['last_at'])}]({r['last_url']}) ({r['last_event']})" if r.get("last_url") else ""
            if r.get("last_real") and r["result"] == "not due (gate)":
                last += f"; last real run [{when(r['last_real']['at'])}]({r['last_real']['url']})"
            openi = ", ".join(f"[{'draft ' if x.get('draft') else ''}{x['kind']} #{x['number']}]({x['url']})"
                              for x in r.get("open", [])) or "none"
            lines.append(f"| [`{r['audit']}`](https://github.com/{repo}/actions/workflows/{r['file']}) | {r['schedule']} | {last or 'never'} "
                         f"| {r['result']} | {openi} |")
    return "\n".join(lines) + "\n"


def collect(repo, wf_dir):
    rows = []
    prs = json.loads(gh("pr", "list", "--repo", repo, "--state", "open", "--limit", "200",
                        "--json", "number,url,labels,isDraft") or "[]")
    issues = json.loads(gh("issue", "list", "--repo", repo, "--state", "open", "--limit", "200",
                           "--json", "number,url,labels") or "[]")
    for c in callers(wf_dir):
        label = f"audit-{c['audit']}"
        runs = json.loads(gh("api", f"repos/{repo}/actions/workflows/{c['file']}/runs?per_page=10",
                             check=False) or "{}").get("workflow_runs", [])
        run = runs[0] if runs else None
        jobs = []
        if run and run.get("status") == "completed" and run.get("conclusion") == "success":
            jobs = json.loads(gh("api", f"repos/{repo}/actions/runs/{run['id']}/jobs?per_page=100",
                                 check=False) or "{}").get("jobs", [])
        res = result_of(run, jobs)
        real = None
        if res == "not due (gate)":
            for r in runs[1:]:
                if r.get("event") != "schedule" and r.get("status") == "completed":
                    real = {"at": r["created_at"], "url": r["html_url"]}
                    break
        opened = [{"kind": "PR", "number": p["number"], "url": p["url"], "draft": p.get("isDraft")}
                  for p in prs if any(l["name"] == label for l in p.get("labels", []))]
        opened += [{"kind": "issue", "number": i["number"], "url": i["url"]}
                   for i in issues if any(l["name"] == label for l in i.get("labels", []))]
        rows.append({**c, "result": res, "open": opened, "last_real": real,
                     "last_at": run and run.get("created_at"), "last_url": run and run.get("html_url"),
                     "last_event": run and run.get("event")})
    return rows


def publish(repo, body):
    num = gh("issue", "list", "--repo", repo, "--label", LABEL, "--state", "all", "--limit", "1",
             "--json", "number", "--jq", ".[0].number // empty", check=False).strip()
    if num:
        subprocess.run(["gh", "issue", "edit", num, "--repo", repo, "--body-file", "-"], input=body,
                       text=True, check=True, capture_output=True)
        subprocess.run(["gh", "issue", "reopen", num, "--repo", repo], capture_output=True)
        return num
    gh("label", "create", LABEL, "--repo", repo, "--color", "0E8A16", "--description",
       "The scheduled audits' status table", check=False)
    r = subprocess.run(["gh", "issue", "create", "--repo", repo, "--title", TITLE, "--label", LABEL,
                        "--body-file", "-"], input=body, text=True, check=True, capture_output=True)
    num = r.stdout.strip().rstrip("/").split("/")[-1]
    subprocess.run(["gh", "issue", "pin", num, "--repo", repo], capture_output=True)
    return num


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--repo", default=os.environ.get("GITHUB_REPOSITORY"))
    ap.add_argument("--workflows", default=str(Path(__file__).resolve().parents[1] / "workflows"))
    ap.add_argument("--out", required=True)
    ap.add_argument("--publish", action="store_true")
    a = ap.parse_args(argv)
    import datetime
    now = datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds")
    run_url = (f"{os.environ['GITHUB_SERVER_URL']}/{a.repo}/actions/runs/{os.environ['GITHUB_RUN_ID']}"
               if os.environ.get("GITHUB_RUN_ID") else "")
    body = render(collect(a.repo, a.workflows), now, run_url, a.repo)
    Path(a.out).write_text(body)
    if a.publish:
        print(f"issue #{publish(a.repo, body)}")
    else:
        print(body)
    return 0


if __name__ == "__main__":
    sys.exit(main())
