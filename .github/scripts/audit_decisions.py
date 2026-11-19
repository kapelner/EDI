#!/usr/bin/env python3
"""One list of every audit's open decisions: the "Decisions for you" items still waiting on the owner.

Workflow: .github/workflows/audit-status.yml (after each audit run, and daily), next to the status
table. The list is the body of one pinned issue labelled `audit-decisions`, edited in place, so its
URL never changes; merging an audit PR does not hide its decisions. Plan:
R/package_metadata/new_feature_plans/v1_0_6/audit_jobs_framework.md.

Source: each audit's `<audit>/decisions_open.json` on the `audit-notes` branch (and, under their own
heading, its open mechanical findings from `<audit>/mechanical_open.json`, owner 2026-11-19), which its finish
stage writes ({id: {text, first_seen, last_seen, unit, key}}). A decision leaves the list when a run
no longer finds it (the audit drops it from that file), when an unticked TODO in a release file
cites its id, or when its id is in R/package_metadata/audits/dismissed_decisions.md. The last two
are re-read here, so citing or dismissing takes effect at the next update, not the next audit run.
"""
import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audit_common as ac  # noqa: E402

LABEL = "audit-decisions"
TITLE = "Open audit decisions"
NOTES_REF = "origin/audit-notes"
MAX_BODY = 60000          # GitHub's issue body limit is 65536 characters
MIN_CAP = 120             # never cut an item shorter than this


def gh(*args, check=True):
    r = subprocess.run(["gh", *args], capture_output=True, text=True)
    if check and r.returncode:
        raise RuntimeError(f"gh {' '.join(args[:4])}: {r.stderr.strip()}")
    return r.stdout


def load_open(repo, ref=NOTES_REF, name="decisions_open.json"):
    """{audit: {id: record}} from every <audit>/<name> on the notes branch (decisions_open.json, or
    mechanical_open.json for the mechanical findings)."""
    ls = subprocess.run(["git", "ls-tree", "-r", "--name-only", ref], cwd=repo, capture_output=True, text=True)
    out = {}
    for path in ls.stdout.split():
        if not path.endswith("/" + name):
            continue
        r = subprocess.run(["git", "show", f"{ref}:{path}"], cwd=repo, capture_output=True, text=True)
        try:
            out[path.split("/")[0]] = json.loads(r.stdout or "{}")
        except json.JSONDecodeError:
            out[path.split("/")[0]] = {}
    return out


def select(by_audit, cited, dismissed):
    """Drop cited and dismissed ids. Returns ({audit: [(id, record)] oldest first}, {"cited", "dismissed"})."""
    out, counts = {}, {"cited": 0, "dismissed": 0}
    for audit, recs in sorted(by_audit.items()):
        keep = []
        for did, rec in recs.items():
            if did in dismissed:
                counts["dismissed"] += 1
            elif did in cited:
                counts["cited"] += 1
            else:
                keep.append((did, rec))
        keep.sort(key=lambda x: (str(x[1].get("first_seen", "")), x[0]))
        if keep:
            out[audit] = keep
    return out, counts


def clip(text, cap):
    if cap is None or len(text) <= cap:
        return text
    return text[:cap].rsplit(" ", 1)[0] + " …"


def render(selected, counts, generated_at, repo="", run_url="", cap=None, mech=None, mcounts=None):
    mech, mcounts = mech or {}, mcounts or {}
    total = sum(len(v) for v in selected.values())
    notes = f"https://github.com/{repo}/blob/audit-notes" if repo else ""
    lines = [f"# {TITLE}", "",
             f"Updated {generated_at.replace('T', ' ')[:16]} UTC by `.github/workflows/audit-status.yml`"
             + (f" ([run]({run_url}))" if run_url else "") + ". Edited in place; do not edit by hand.", "",
             "> [!NOTE]",
             "> **This is a standing list, not a task.** It stays open and pinned; do not close it (the next "
             "update reopens it). Each item is a decision a scheduled audit could not make for you. An item "
             "leaves the list when:",
             "> - the code or docs change so the audit no longer finds it (next run of that audit);",
             "> - an unticked TODO in a release file (`R/package_metadata/future_release_plans/release_v*.md`) "
             "cites its id, e.g. `(audit decision rd-d1234abcd)`;",
             f"> - its id is listed in `{ac.DISMISSED_FILE}` with a reason.", ""]
    extra = []
    if counts.get("cited"):
        extra.append(f"{counts['cited']} cited by an open release TODO")
    if counts.get("dismissed"):
        extra.append(f"{counts['dismissed']} dismissed")
    lines.append(f"**{total} open decision(s)** across {len(selected)} audit(s)"
                 + (f"; not listed: {', '.join(extra)}" if extra else "") + ".")
    if cap is not None:
        lines.append(f"Long items are cut at {cap} characters to fit the issue; the full text is in each "
                     "audit's `decisions_open.json` (linked per audit).")
    if selected:
        lines += ["", "| Audit | Open | Oldest |", "|---|---|---|"]
        for audit, items in selected.items():
            lines.append(f"| [`{audit}`](#{audit}) | {len(items)} | {str(items[0][1].get('first_seen', ''))[:10]} |")
    for audit, items in selected.items():
        lines += ["", f"## {audit}", ""]
        if notes:
            lines += [f"Full records: [`{audit}/decisions_open.json`]({notes}/{audit}/decisions_open.json)", ""]
        lines += ["<details><summary>" + f"{len(items)} decision(s)" + "</summary>", ""]
        for did, rec in items:
            text = clip(str(rec.get("text", "")).strip(), cap)
            first, sep, rest = text.partition("\n")
            lines.append(f"- `{did}` · since {str(rec.get('first_seen', ''))[:10]} · {first}" + sep + rest)
        lines += ["", "</details>"]
    lines += render_mechanical(mech, mcounts, notes, cap)
    return "\n".join(lines) + "\n"


def render_mechanical(mech, mcounts, notes, cap):
    """The "Mechanical findings" section: each audit's open mechanical findings (ids `<audit>-m<hex>`),
    which leave the list the same three ways as decisions."""
    total = sum(len(v) for v in mech.values())
    extra = []
    if mcounts.get("cited"):
        extra.append(f"{mcounts['cited']} cited by an open release TODO")
    if mcounts.get("dismissed"):
        extra.append(f"{mcounts['dismissed']} dismissed")
    lines = ["", "# Mechanical findings", "",
             f"**{total} open mechanical finding(s)** across {len(mech)} audit(s)"
             + (f"; not listed: {', '.join(extra)}" if extra else "") + ". These come from the audits' "
             "checks without Claude (checkRd, spelling, example runs, ...). Each leaves the list when a run "
             "no longer finds it (fixed), when an open release TODO cites its `<audit>-m<hex>` id, or when the "
             f"id is listed in `{ac.DISMISSED_FILE}`."]
    if mech:
        lines += ["", "| Audit | Open | Oldest |", "|---|---|---|"]
        for audit, items in mech.items():
            lines.append(f"| `{audit}` | {len(items)} | {str(items[0][1].get('first_seen', ''))[:10]} |")
    for audit, items in mech.items():
        lines += ["", f"## {audit} (mechanical)", ""]
        if notes:
            lines += [f"Full records: [`{audit}/mechanical_open.json`]({notes}/{audit}/mechanical_open.json)", ""]
        lines += ["<details><summary>" + f"{len(items)} finding(s)" + "</summary>", ""]
        for mid, rec in items:
            text = clip(str(rec.get("text", "")).strip(), cap)
            first, sep, rest = text.partition("\n")
            lines.append(f"- `{mid}` · since {str(rec.get('first_seen', ''))[:10]} · {first}" + sep + rest)
        lines += ["", "</details>"]
    return lines


def render_fitting(selected, counts, generated_at, repo="", run_url="", mech=None, mcounts=None):
    """The full list if it fits; else the largest per-item text cap that does."""
    body = render(selected, counts, generated_at, repo, run_url, mech=mech, mcounts=mcounts)
    if len(body) <= MAX_BODY:
        return body
    every = [r for v in selected.values() for _, r in v] + [r for v in (mech or {}).values() for _, r in v]
    lo, hi = MIN_CAP, max((len(str(r.get("text", ""))) for r in every), default=MIN_CAP)
    best = render(selected, counts, generated_at, repo, run_url, MIN_CAP, mech, mcounts)
    while lo <= hi:
        mid = (lo + hi) // 2
        b = render(selected, counts, generated_at, repo, run_url, mid, mech, mcounts)
        if len(b) <= MAX_BODY:
            best, lo = b, mid + 1
        else:
            hi = mid - 1
    return best if len(best) <= MAX_BODY else ac.fit_body(best, run_url, MAX_BODY)


def publish(repo, body):
    num = gh("issue", "list", "--repo", repo, "--label", LABEL, "--state", "all", "--limit", "1",
             "--json", "number", "--jq", ".[0].number // empty", check=False).strip()
    if num:
        subprocess.run(["gh", "issue", "edit", num, "--repo", repo, "--body-file", "-"], input=body,
                       text=True, check=True, capture_output=True)
        subprocess.run(["gh", "issue", "reopen", num, "--repo", repo], capture_output=True)
        return num
    gh("label", "create", LABEL, "--repo", repo, "--color", "D93F0B", "--description",
       "The audits' open decisions for the owner", check=False)
    r = subprocess.run(["gh", "issue", "create", "--repo", repo, "--title", TITLE, "--label", LABEL,
                        "--body-file", "-"], input=body, text=True, check=True, capture_output=True)
    num = r.stdout.strip().rstrip("/").split("/")[-1]
    subprocess.run(["gh", "issue", "pin", num, "--repo", repo], capture_output=True)
    return num


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--repo", default=os.environ.get("GITHUB_REPOSITORY"))
    ap.add_argument("--checkout", default=str(Path(__file__).resolve().parents[2]),
                    help="checkout holding the release files and the dismissed list, with the notes branch fetched")
    ap.add_argument("--notes-ref", default=NOTES_REF)
    ap.add_argument("--out", required=True)
    ap.add_argument("--publish", action="store_true")
    a = ap.parse_args(argv)
    import datetime
    now = datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds")
    run_url = (f"{os.environ['GITHUB_SERVER_URL']}/{a.repo}/actions/runs/{os.environ['GITHUB_RUN_ID']}"
               if os.environ.get("GITHUB_RUN_ID") else "")
    cited, dismissed = ac.cited_decisions(a.checkout), ac.dismissed_decisions(a.checkout)
    selected, counts = select(load_open(a.checkout, a.notes_ref), cited, dismissed)
    mech, mcounts = select(load_open(a.checkout, a.notes_ref, "mechanical_open.json"), cited, dismissed)
    body = render_fitting(selected, counts, now, a.repo or "", run_url, mech, mcounts)
    Path(a.out).write_text(body)
    if a.publish:
        print(f"issue #{publish(a.repo, body)}")
    else:
        print(body)
    return 0


if __name__ == "__main__":
    sys.exit(main())
