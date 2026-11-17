#!/usr/bin/env python3
"""Shared machinery for the scheduled audit jobs.

Plan: R/package_metadata/new_feature_plans/v1_0_6/audit_jobs_framework.md (Part 1).

Every audit is a module `.github/scripts/audits/<name>.py` with:

    SPEC = {...}                      # see DEFAULT_SPEC for the keys
    def mechanical(ctx) -> list[dict] # findings without Claude (optional)
    def units(ctx) -> dict[str, dict] # unit id -> {"hash", "deps", "model"?, "context"?}  (optional)
    def apply(ctx, results, mech) -> dict   # edits the work tree, returns the report parts

`audit_run.py` drives the stages (prepare, Claude batches, finish, publish); this module
holds what they share: the notes cache on the `audit-notes` branch, unit selection with
rotation, batching, finding ids and the history of findings, and report rendering.
Stdlib only.
"""
import datetime as dt
import hashlib
import importlib
import json
import os
import re
import subprocess
from pathlib import Path

NOTES_BRANCH = "audit-notes"
SONNET = "claude-sonnet-5-5"
OPUS = "claude-opus-5-5"

DEFAULT_SPEC = {
    "name": None,              # folder on audit-notes, label suffix, branch suffix
    "title": None,             # human name, used in PR / issue titles
    "report": "pr",            # "pr" or "issue"
    "claude": False,           # has a Claude stage
    "model": SONNET,           # default model for a batch (units may override with "model")
    "effort": None,            # e.g. "medium"; None = the model's default
    "batch_size": 8,           # units per agent (algorithm audit: one agent for 120 items finished 2)
    "cycle_weeks": 8,          # rotation: each unchanged unit re-read once per cycle of this many runs
    "period": "week",          # the rotation clock: "week" (weekly jobs) or "month" (monthly jobs), so
                               # a cycle of N means N of the job's own runs either way
    "max_batches": 20,         # hard cap per run; the rest rolls to the next run, oldest first
    "tools": "Read,Glob,Grep", # agent tools; Bash is always denied
    "max_turns": 60,
    "timeout_minutes": 20,     # per agent
    "pr_draft": False,         # open the PR as a draft (a follow-up job marks it ready)
}


def spec_of(module):
    s = dict(DEFAULT_SPEC)
    s.update(getattr(module, "SPEC", {}))
    if not s["name"]:
        raise ValueError(f"{module.__name__}: SPEC needs a name")
    s.setdefault("label", f"audit-{s['name']}")
    if not s.get("label"):
        s["label"] = f"audit-{s['name']}"
    s["title"] = s["title"] or s["name"]
    return s


def load_audit(name):
    """Import .github/scripts/audits/<name>.py (dashes in the job name become underscores)."""
    return importlib.import_module(f"audits.{name.replace('-', '_')}")


# ---------------------------------------------------------------- hashing and time

def text_hash(*parts):
    h = hashlib.sha256()
    for p in parts:
        if isinstance(p, (dict, list)):
            p = json.dumps(p, sort_keys=True)
        h.update(str(p).encode("utf-8", "replace"))
        h.update(b"\0")
    return h.hexdigest()[:16]


def file_hash(path):
    try:
        return text_hash(Path(path).read_bytes().decode("utf-8", "replace"))
    except OSError:
        return "missing"


def now_utc():
    return dt.datetime.now(dt.timezone.utc)


def parse_time(s):
    try:
        t = dt.datetime.fromisoformat(s)
    except (TypeError, ValueError):
        return None
    return t if t.tzinfo else t.replace(tzinfo=dt.timezone.utc)


def week_index(now):
    """Weeks since 2026-01-05 (a Monday): the rotation clock."""
    return (now.date() - dt.date(2026, 1, 5)).days // 7


def month_index(now):
    return now.year * 12 + now.month - 1


def in_rotation(unit_id, cycle_weeks, now, period="week"):
    """True on the one run of each cycle that belongs to this unit (stable per unit). The clock
    counts the job's own runs: weeks for weekly jobs, months for monthly ones (a weekly clock
    read once a month would visit the slots unevenly)."""
    if cycle_weeks <= 1:
        return True
    slot = int(hashlib.sha256(unit_id.encode()).hexdigest(), 16) % cycle_weeks
    clock = month_index(now) if period == "month" else week_index(now)
    return clock % cycle_weeks == slot


def nth_weekday_of_month(day):
    """1 for days 1-7, 2 for 8-14, 3 for 15-21, 4 for 22-28, 5 after."""
    return (day - 1) // 7 + 1


def due_today(nth, now, event):
    """Monthly jobs run on one weekly cron and keep only the nth such weekday of the month.
    nth = 0 means weekly or daily (always due). Manual dispatch is always due."""
    if not nth or event != "schedule":
        return True
    return nth_weekday_of_month(now.day) == nth


# ---------------------------------------------------------------- notes cache

class Notes:
    """One audit's folder on the audit-notes branch, checked out at `root/<name>`."""

    def __init__(self, root, name):
        self.root = Path(root)
        self.dir = self.root / name
        self.dir.mkdir(parents=True, exist_ok=True)

    # manifest: {"units": {id: {...}}, "last_run": iso, "open_pr": n, "issue_hash": str, ...}
    def manifest(self):
        p = self.dir / "manifest.json"
        try:
            m = json.loads(p.read_text())
            if not isinstance(m, dict):
                raise ValueError
        except (OSError, ValueError):
            m = {}
        m.setdefault("units", {})
        return m

    def save_manifest(self, m):
        (self.dir / "manifest.json").write_text(json.dumps(m, indent=1, sort_keys=True) + "\n")

    def findings(self):
        p = self.dir / "findings.jsonl"
        out = []
        if p.exists():
            for line in p.read_text().splitlines():
                line = line.strip()
                if line:
                    try:
                        out.append(json.loads(line))
                    except ValueError:
                        pass
        return out

    def save_findings(self, rows):
        p = self.dir / "findings.jsonl"
        p.write_text("".join(json.dumps(r, sort_keys=True) + "\n" for r in rows))

    def decisions(self):
        p = self.dir / "decisions.md"
        return p.read_text() if p.exists() else ""

    def add_decisions(self, lines):
        if not lines:
            return
        p = self.dir / "decisions.md"
        head = "" if p.exists() else (
            "# Settled decisions\n\nFindings the owner rejected, and conventions. The audit agents read this "
            "file and must not raise a finding that matches one below. The owner may edit it by hand.\n\n")
        with open(p, "a") as f:
            f.write(head + "".join(l.rstrip() + "\n" for l in lines))

    def history_path(self, name):
        return self.dir / name


# ---------------------------------------------------------------- unit selection

def select_units(units, manifest, scope, cycle_weeks, now, max_units=None, period="week"):
    """Decide which units to (re)read.

    units: id -> {"hash": str, "deps": str (optional), "cycle_weeks": int (optional)}
    Returns (chosen ids in priority order, {id: reason}, rolled-over ids).
    Priority: new or changed, then open findings, then rotation. Inside a class a unit's own
    "priority" (lower first, default 0) decides, then the unit audited longest ago, so a
    capped run never starves a unit and the units that matter most go first.
    """
    seen = manifest.get("units", {})
    reasons, rank = {}, {}
    for uid, u in units.items():
        prev = seen.get(uid)
        cyc = u.get("cycle_weeks", cycle_weeks)
        if scope == "none":
            continue
        if scope == "all":
            reasons[uid], rank[uid] = "full pass", 0
        elif prev is None:
            reasons[uid], rank[uid] = "new", 0
        elif prev.get("hash") != u.get("hash"):
            reasons[uid], rank[uid] = "changed", 0
        elif u.get("deps") is not None and prev.get("deps") != u.get("deps"):
            reasons[uid], rank[uid] = "something it depends on changed", 0
        elif prev.get("open_findings"):
            reasons[uid], rank[uid] = "open finding", 1
        elif in_rotation(uid, cyc, now, period):
            reasons[uid], rank[uid] = f"rotation (1 in {cyc} {period}ly runs)", 2
    def age(uid):
        t = parse_time(seen.get(uid, {}).get("audited_at"))
        return t.timestamp() if t else 0.0
    order = sorted(reasons, key=lambda u: (rank[u], units[u].get("priority", 0), age(u), u))
    if max_units is not None and len(order) > max_units:
        return order[:max_units], {u: reasons[u] for u in order[:max_units]}, order[max_units:]
    return order, reasons, []


def make_batches(chosen, units, spec):
    """Group chosen units into agent batches of spec['batch_size'], one model per batch."""
    by_model = {}
    for uid in chosen:
        by_model.setdefault(units[uid].get("model") or spec["model"], []).append(uid)
    batches = []
    for model in sorted(by_model):
        ids = by_model[model]
        for i in range(0, len(ids), spec["batch_size"]):
            batches.append({"id": f"b{len(batches) + 1:03d}", "model": model,
                            "units": ids[i:i + spec["batch_size"]]})
    return batches


# ---------------------------------------------------------------- findings

def finding_id(audit, unit, kind, text):
    norm = re.sub(r"\s+", " ", str(text)).strip().lower()
    return text_hash(audit, unit, kind, norm)[:12]


def normalise_finding(audit, f, source):
    f = dict(f)
    f.setdefault("unit", f.get("file", ""))
    f.setdefault("kind", "finding")
    f.setdefault("text", "")
    f["source"] = source
    f["id"] = f.get("id") or finding_id(audit, f["unit"], f["kind"], f["text"])
    return f


def drop_rejected(findings, history):
    """Leave out findings whose id was rejected before."""
    rejected = {h["id"] for h in history if h.get("status") == "rejected"}
    return [f for f in findings if f["id"] not in rejected]


def harvest_pr(history, pr_state, merged, file_reader):
    """Settle the findings of a closed audit PR.

    pr_state: "MERGED", "CLOSED" or "OPEN". A merged PR's finding is fixed if the text it
    applied (`applied_text` in `applied_file`) is on main, else the owner removed it on the
    branch: rejected. A PR closed without merging rejects all its findings.
    Returns (updated history, decision lines for the rejected).
    """
    lines = []
    for h in history:
        if h.get("status") != "proposed" or h.get("pr") != merged:
            continue
        if pr_state == "OPEN":
            continue
        if pr_state == "MERGED" and h.get("applied_file") and h.get("applied_text") is not None:
            body = file_reader(h["applied_file"]) or ""
            ok = h["applied_text"] in body
        else:
            ok = pr_state == "MERGED" and not h.get("applied_file")
        h["status"] = "fixed" if ok else "rejected"
        h["settled_at"] = now_utc().isoformat(timespec="seconds")
        if not ok:
            lines.append(f"- `{h.get('unit', '')}`: {h.get('text', '')} "
                         f"(rejected in PR #{h.get('pr')}; id {h['id']})")
    return history, lines


def settle_open_counts(manifest, settled):
    """Lower each unit's `open_findings` by its findings just settled (fixed or rejected), so a unit
    whose PR was merged or closed is not re-read as "open finding" on every later run."""
    units = manifest.get("units", {})
    for h in settled:
        u = units.get(h.get("unit"))
        if u and u.get("open_findings"):
            u["open_findings"] = max(0, u["open_findings"] - 1)
    return manifest


# ---------------------------------------------------------------- reports

def render_report(spec, parts, coverage, run_url):
    """parts: {"applied": [str], "mechanical": [str], "human": [str], "summary": str}."""
    md = [f"## {spec['title']}", ""]
    if parts.get("summary"):
        md += [parts["summary"], ""]
    for key, title in (("applied", "Applied changes"), ("mechanical", "Mechanical findings"),
                       ("human", "Needs a human")):
        items = parts.get(key) or []
        if items:
            md += [f"### {title} ({len(items)})", ""] + [f"- {x}" for x in items] + [""]
    md += ["### Coverage", ""]
    md += [f"- {k}: {v}" for k, v in coverage.items()]
    md += ["", f"Run: {run_url}", ""]
    return "\n".join(md)


def issue_note(spec):
    """The note at the top of an audit's issue: it is a standing report, not a task to close."""
    wf = f"audit-{spec['name']}.yml"
    repo = os.environ.get("GITHUB_REPOSITORY", "kapelner/EDI")
    return ("> [!NOTE]\n"
            "> **This is a standing audit report, not a task.** The `" + spec["name"] + "` audit "
            f"([`{wf}`](https://github.com/{repo}/actions/workflows/{wf})) rewrites this issue on every run and closes it "
            "itself when a run finds nothing. Do not close it, assign it or work in it: closing it by hand "
            "only makes the next run open a new one. To act on a finding, fix it in its own PR or open a "
            "release TODO (`v<version>-TODO-<n>`); a finding leaves this report once a run no longer "
            "finds it.\n\n")


BODY_LIMIT = 60000   # GitHub rejects PR and issue bodies and comments over 65,536 characters


def fit_body(report, run_link="", limit=BODY_LIMIT):
    """The report, cut to fit a PR or issue body. Keeps the head and the Coverage section, cuts
    at a line boundary, and says how much was left out and where the full report is."""
    if len(report) <= limit:
        return report
    i = report.rfind("\n### Coverage")
    tail = report[i:] if i >= 0 and len(report) - i < limit // 4 else ""
    head_text = report[:i] if tail else report
    room = limit - len(tail) - 400
    cut = head_text.rfind("\n", 0, room)
    head = head_text[:cut if cut > 0 else room]
    left = head_text[len(head):].count("\n")
    note = (f"\n\n**Report cut to fit GitHub's size limit: {left} more line(s) not shown.** The full report "
            f"is in the run's summary{': ' + run_link if run_link else ''}.\n")
    return head + note + tail


def has_findings(parts):
    return any(parts.get(k) for k in ("applied", "mechanical", "human"))


# ---------------------------------------------------------------- small helpers for audits

def git(*args, cwd=None, check=True):
    return subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True, check=check).stdout


def changed_since(commit, paths, cwd=None):
    """Files under `paths` changed between `commit` and HEAD (all of them if commit is unknown)."""
    if not commit:
        return None
    r = subprocess.run(["git", "diff", "--name-only", f"{commit}..HEAD", "--", *paths],
                       cwd=cwd, capture_output=True, text=True)
    return None if r.returncode else [l for l in r.stdout.splitlines() if l]


def tracked_files(*paths, cwd=None):
    return [l for l in git("ls-files", *paths, cwd=cwd).splitlines() if l]


class Context:
    """What an audit's functions get."""

    def __init__(self, spec, repo, notes, workdir, now=None, scope="auto", sha="", event="schedule",
                 run_url=""):
        self.spec, self.repo, self.notes = spec, Path(repo), notes
        self.workdir = Path(workdir)
        self.now = now or now_utc()
        self.scope, self.sha, self.event, self.run_url = scope, sha, event, run_url
        self.manifest = notes.manifest()

    def path(self, *p):
        return self.repo.joinpath(*p)

    def read(self, rel):
        try:
            return self.path(rel).read_text(encoding="utf-8", errors="replace")
        except OSError:
            return None
