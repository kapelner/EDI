"""CI self-check (weekly, issue, no Claude).

Plan: R/package_metadata/new_feature_plans/v1_0_6/audit_jobs_framework.md (Part 4, "CI
self-check"; audit_jobs_framework.md TODO-12).

Checks, through the GitHub REST API (`gh api`, authenticated by the GH_TOKEN the prepare job
sets):

1. actions used in .github/workflows/*.yml|yaml whose pinned major version is behind the major
   of the action's latest release (SHA pins and local actions are skipped);
2. workflows GitHub disabled for inactivity (state `disabled_inactivity`, after 60 days with
   no repository activity);
3. per workflow: the latest successful run's duration against the median of the successful
   runs before it in the last 8 weeks; flagged when more than 50% over (and at least
   MIN_SLOWDOWN_S longer, so a 40 s job taking 70 s is not noise in the issue). Only earlier runs
   of at least BASELINE_MIN_S count: many workflows usually stop early in a gate, and those
   runs would make one real run look hundreds of times slower;
4. open bot PRs, and open PRs or branches named audit/* or algorithm-research/*, older than
   4 weeks (a branch counts by the date of its last commit, and only if no open PR uses it).

Reports ONE issue (label `ci-self-check`), closed when clean. A failed API call is a
finding, never clean. Stdlib only.
"""
import datetime as dt
import json
import os
import re
import statistics
import subprocess
from pathlib import Path

import audit_common as ac

SPEC = {
    "name": "ci-self-check",
    "title": "CI self-check",
    "report": "issue",
    "label": "ci-self-check",       # the plan's label (Part 4)
    "claude": False,
}

WINDOW_WEEKS = 8
SLOW_FACTOR = 1.5
MIN_SLOWDOWN_S = 120
MIN_PRIOR_RUNS = 3
BASELINE_MIN_S = 120          # earlier runs shorter than this stopped early (a gate or path filter)
STALE_DAYS = 28
BOT_PREFIXES = ("audit/", "algorithm-research/")


class ApiError(RuntimeError):
    pass


def gh_api(path):
    """GET a REST path with `gh api --paginate`; returns parsed JSON (pages of lists merged)."""
    r = subprocess.run(["gh", "api", "--paginate", "-H", "Accept: application/vnd.github+json", path],
                       capture_output=True, text=True, timeout=300)
    if r.returncode:
        raise ApiError(f"gh api {path}: {r.stderr.strip()[:300]}")
    text = r.stdout.strip()
    if not text:
        return None
    try:
        return json.loads(text)
    except ValueError:
        # --paginate concatenates pages: "[...][...]" or "{...}{...}".
        dec, i, parts = json.JSONDecoder(), 0, []
        while i < len(text):
            obj, i = dec.raw_decode(text, i)
            parts.append(obj)
            while i < len(text) and text[i].isspace():
                i += 1
        if all(isinstance(p, list) for p in parts):
            return [x for p in parts for x in p]
        merged = {}
        for p in parts:
            for k, v in p.items():
                if isinstance(v, list):
                    merged.setdefault(k, []).extend(v)
                else:
                    merged[k] = v
        return merged


def repo_name(ctx):
    name = os.environ.get("GITHUB_REPOSITORY")
    if name:
        return name
    url = subprocess.run(["git", "remote", "get-url", "origin"], cwd=ctx.repo, capture_output=True,
                         text=True).stdout.strip()
    m = re.search(r"github\.com[:/](.+?)(\.git)?$", url)
    return m.group(1) if m else ""


def _time(s):
    return ac.parse_time((s or "").replace("Z", "+00:00"))


# ---------------------------------------------------------------- 1. action versions

USES = re.compile(r"""^\s*(?:-\s*)?uses:\s*["']?([^"'\s#]+)""", re.M)


def workflow_files(repo):
    d = Path(repo) / ".github" / "workflows"
    return sorted(p for p in d.glob("*") if p.suffix in (".yml", ".yaml"))


def action_pins(repo):
    """{(owner/repo, pinned major): [workflow file names]}; skips local, docker and SHA pins."""
    pins = {}
    for wf in workflow_files(repo):
        for ref in USES.findall(wf.read_text(errors="replace")):
            if ref.startswith(("./", "docker://")) or "@" not in ref:
                continue
            action, version = ref.rsplit("@", 1)
            if re.fullmatch(r"[0-9a-f]{40}", version):
                continue
            m = re.search(r"v?(\d+)", version)
            if not m:
                continue
            repo_part = "/".join(action.split("/")[:2])
            pins.setdefault((repo_part, int(m.group(1))), set()).add(wf.name)
    return {k: sorted(v) for k, v in pins.items()}


def latest_major(api, action_repo):
    try:
        rel = api(f"repos/{action_repo}/releases/latest")
        tag = (rel or {}).get("tag_name", "")
    except ApiError:
        tag = ""
    if not tag:
        tags = api(f"repos/{action_repo}/tags?per_page=100") or []
        majors = [int(m.group(1)) for t in tags for m in [re.match(r"v?(\d+)(\.|$)", t.get("name", ""))] if m]
        return max(majors) if majors else None
    m = re.search(r"v?(\d+)", tag)
    return int(m.group(1)) if m else None


def check_actions(api, repo):
    out, latest = [], {}
    for (action, major), files in sorted(action_pins(repo).items()):
        if action not in latest:
            try:
                latest[action] = latest_major(api, action)
            except ApiError as e:
                latest[action] = None
                out.append({"unit": f"action:{action}", "kind": "api-error",
                            "text": f"Could not read the releases of `{action}`: {e}"})
        new = latest[action]
        if new is not None and new > major:
            out.append({"unit": f"action:{action}@v{major}", "kind": "action-behind",
                        "text": f"`{action}@v{major}` is behind its latest major v{new} "
                                f"(used in {', '.join(files)})."})
    return out


# ---------------------------------------------------------------- 2-3. workflows and run times

def check_workflows(api, repo_full, now):
    out = []
    data = api(f"repos/{repo_full}/actions/workflows?per_page=100") or {}
    workflows = data.get("workflows", []) if isinstance(data, dict) else data
    since = (now - dt.timedelta(weeks=WINDOW_WEEKS)).date().isoformat()
    for w in sorted(workflows, key=lambda w: w.get("path", "")):
        path = w.get("path", "") or w.get("name", "")
        if w.get("state") == "disabled_inactivity":
            out.append({"unit": f"workflow:{path}", "kind": "disabled",
                        "text": f"`{path}` was disabled by GitHub for repository inactivity; re-enable it "
                                f"(Actions > {w.get('name', path)} > Enable workflow)."})
            continue
        if w.get("state") != "active":
            continue
        runs = api(f"repos/{repo_full}/actions/workflows/{w['id']}/runs?status=success&per_page=100"
                   f"&created=%3E%3D{since}") or {}
        runs = runs.get("workflow_runs", []) if isinstance(runs, dict) else runs
        f = slow_run(path, runs)
        if f:
            out.append(f)
    return out


def run_seconds(run):
    a, b = _time(run.get("run_started_at") or run.get("created_at")), _time(run.get("updated_at"))
    return (b - a).total_seconds() if a and b and b >= a else None


def slow_run(path, runs):
    timed = sorted(((_time(r.get("created_at")), run_seconds(r), r) for r in runs
                    if _time(r.get("created_at")) and run_seconds(r) is not None), key=lambda x: x[0])
    if len(timed) < MIN_PRIOR_RUNS + 1:
        return None
    latest_s, latest = timed[-1][1], timed[-1][2]
    prior = [s for _, s, _ in timed[:-1]]
    if latest_s >= BASELINE_MIN_S:
        prior = [s for s in prior if s >= BASELINE_MIN_S]
    if len(prior) < MIN_PRIOR_RUNS:
        return None
    median = statistics.median(prior)
    if median > 0 and latest_s > SLOW_FACTOR * median and latest_s - median >= MIN_SLOWDOWN_S:
        return {"unit": f"runtime:{path}", "kind": "slow-run",
                "text": f"`{path}`: latest successful run took {latest_s / 60:.0f} min against an "
                        f"{WINDOW_WEEKS}-week median of {median / 60:.0f} min "
                        f"({latest_s / median:.1f}x; {len(prior)} earlier runs; "
                        f"{latest.get('html_url', '')})."}
    return None


# ---------------------------------------------------------------- 4. stale bot PRs and branches

def is_bot(user):
    user = user or {}
    return user.get("type") == "Bot" or str(user.get("login", "")).endswith("[bot]")


def check_stale(api, repo_full, now):
    out = []
    cutoff = now - dt.timedelta(days=STALE_DAYS)
    prs = api(f"repos/{repo_full}/pulls?state=open&per_page=100") or []
    heads = set()
    for pr in sorted(prs, key=lambda p: p.get("number", 0)):
        ref = (pr.get("head") or {}).get("ref", "")
        heads.add(ref)
        created = _time(pr.get("created_at"))
        if not created or created > cutoff:
            continue
        if is_bot(pr.get("user")) or ref.startswith(BOT_PREFIXES):
            out.append({"unit": f"pr:{pr.get('number')}", "kind": "stale-pr",
                        "text": f"PR #{pr.get('number')} ({ref}, by {(pr.get('user') or {}).get('login', '?')}) "
                                f"has been open since {created.date()}, more than {STALE_DAYS // 7} weeks: merge or close it."})
    branches = api(f"repos/{repo_full}/branches?per_page=100") or []
    for b in sorted(branches, key=lambda b: b.get("name", "")):
        name = b.get("name", "")
        if not name.startswith(BOT_PREFIXES) or name in heads:
            continue
        sha = (b.get("commit") or {}).get("sha")
        c = api(f"repos/{repo_full}/commits/{sha}") if sha else None
        when = _time(((c or {}).get("commit") or {}).get("committer", {}).get("date"))
        if when and when <= cutoff:
            out.append({"unit": f"branch:{name}", "kind": "stale-branch",
                        "text": f"Branch `{name}` has no open PR and no commit since {when.date()}: "
                                "delete it if its work is settled."})
    return out


# ---------------------------------------------------------------- stages

def mechanical(ctx, api=None):
    api = api or gh_api
    repo_full = repo_name(ctx)
    out = []
    for label, fn in (("action versions", lambda: check_actions(api, ctx.repo)),
                      ("workflow states and run times", lambda: check_workflows(api, repo_full, ctx.now)),
                      ("stale bot PRs and branches", lambda: check_stale(api, repo_full, ctx.now))):
        try:
            out += fn()
        except (ApiError, OSError, subprocess.TimeoutExpired, KeyError, TypeError, ValueError) as e:
            hint = (" (the prepare job's token may need `actions: read`)"
                    if "403" in str(e) or "not accessible" in str(e) else "")
            out.append({"unit": f"check:{label}", "kind": "not-run",
                        "text": f"The {label} check did not run: {e}{hint}"})
    return out


def apply(ctx, results, mech):
    groups = {}
    for f in mech:
        groups.setdefault(f["kind"], []).append(f)
    summary = ", ".join(f"{len(v)} {k}" for k, v in sorted(groups.items())) if mech else ""
    return {"summary": summary and f"Findings: {summary}.", "mechanical": [f["text"] for f in mech]}
