#!/usr/bin/env python3
"""Algorithm-audit drift check (stdlib only; read-only; never builds EDI).

Three checks, one markdown report:
  1. comparator versions  -- CRAN version vs R/package_metadata/audits/comparator_versions.json
  2. kernel drift         -- git log per audit row since the row's `reviewed` date
  3. plan-state hygiene   -- every audit TODO's "scheduled in release_vX.md -> TODO-N" target exists

Usage:
  algorithm_audit_drift.py [--out report.md] [--offline]   # run the checks
  algorithm_audit_drift.py --release-gate                  # pre-release: exit 1 if the gate fails
  algorithm_audit_drift.py --snapshot                      # rewrite comparator_versions.json from CRAN now

Exit code is always 0 on a completed run; the report's first line is
`FLAGGED` or `CLEAN` so the workflow can branch on it. See
R/package_metadata/new_feature_plans/algorithm_audit_runbook.md.
"""
import argparse
import datetime
import fnmatch
import json
import re
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
META = ROOT / "R" / "package_metadata"
AUDIT = META / "new_feature_plans" / "algorithm_choice_audit.md"
RELEASES = META / "future_release_plans"
ROW_MAP = META / "audits" / "algorithm_audit_row_map.json"
PINS = META / "audits" / "comparator_versions.json"
DESCRIPTION = ROOT / "R" / "EDI" / "DESCRIPTION"

# Comparators the audit's verdicts lean on, whether or not DESCRIPTION lists them.
EXTRA_COMPARATORS = ["survival", "clinfun", "coin", "betareg", "aftgee", "icenReg",
                     "robustbase", "coxme", "lme4", "glmmTMB"]
BASE_PKGS = {"R", "base", "methods", "stats", "utils", "parallel", "tools", "graphics",
             "grDevices", "datasets", "grid", "splines", "stats4", "compiler", "tcltk"}
NEWS_KEYWORDS = re.compile(
    r"default|algorithm|\btie|quadrature|convergen|optimi[sz]|starting value|"
    r"deprecat|breaking|incompatible|behaviou?r|numerical|accuracy|bug", re.I)
MAX_NEWS_LINES = 8
MAX_COMMITS = 8
MAX_FETCH_ERRORS = 3  # more network failures than this and check 1 is not trustworthy


def http_get(url, timeout=20):
    req = urllib.request.Request(url, headers={"User-Agent": "EDI-algorithm-audit-drift"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read().decode("utf-8", "replace")


def description_packages():
    text = DESCRIPTION.read_text()
    pkgs = set()
    for field in ("Imports", "Suggests", "Depends", "LinkingTo"):
        m = re.search(rf"^{field}:\s*((?:.+\n?)(?:[ \t]+.+\n?)*)", text, re.M)
        if not m:
            continue
        for item in m.group(1).split(","):
            name = re.split(r"[\s(]", item.strip(), maxsplit=1)[0]
            if name and name not in BASE_PKGS:
                pkgs.add(name)
    return pkgs


def cran_version(pkg):
    """CRAN version, None if the package is not on CRAN (404); raises on any other failure."""
    last = None
    for _ in range(2):  # one retry for transient errors
        try:
            return json.loads(http_get(f"https://crandb.r-pkg.org/{pkg}"))["Version"]
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return None
            last = e
        except (urllib.error.URLError, OSError, KeyError, ValueError) as e:
            last = e
    raise last


def news_since(pkg, pinned):
    """Keyword-matching NEWS lines newer than the pinned version's heading."""
    for name in ("NEWS.md", "NEWS"):
        try:
            text = http_get(f"https://cran.r-project.org/web/packages/{pkg}/{name}")
            break
        except (urllib.error.URLError, OSError):
            text = None
    if text is None:
        return None
    lines = text.splitlines()
    cut = next((i for i, l in enumerate(lines) if pinned in l), min(len(lines), 400))
    hits = [l.strip() for l in lines[:cut] if NEWS_KEYWORDS.search(l)]
    return hits[:MAX_NEWS_LINES]


def check_versions(offline):
    out = {"changed": [], "unpinned": [], "not_on_cran": [], "errors": [], "skipped": offline}
    if offline:
        return out
    pins = json.loads(PINS.read_text()).get("packages", {}) if PINS.exists() else {}
    for pkg in sorted(description_packages() | set(EXTRA_COMPARATORS)):
        try:
            now = cran_version(pkg)
        except (urllib.error.URLError, OSError, KeyError, ValueError):
            out["errors"].append(pkg)  # network/server failure, not "absent"
            continue
        if now is None:
            out["not_on_cran"].append(pkg)
            continue
        pinned = pins.get(pkg)
        if pinned is None:
            out["unpinned"].append((pkg, now))
        elif pinned != now:
            out["changed"].append((pkg, pinned, now, news_since(pkg, pinned)))
    return out


def git(*args):
    return subprocess.run(["git", "-C", str(ROOT), *args], capture_output=True,
                          text=True, check=False).stdout


def check_kernels():
    cfg = json.loads(ROW_MAP.read_text())
    rows = cfg["rows"]
    max_age = cfg.get("max_age_days", 180)
    out = {"drifted": [], "missing": [], "stale": [], "uncovered": [], "unassigned": 0,
           "max_age": max_age}
    today = datetime.date.today()
    for key, row in rows.items():
        age = (today - datetime.date.fromisoformat(row["reviewed"])).days
        if age > max_age:
            out["stale"].append((key, row["title"], row["reviewed"], age))
        files = [f"R/EDI/src/{f}" if f.endswith((".cpp", ".h")) else f"R/EDI/R/{f}"
                 for f in row["files"]]
        for f in files:
            if not (ROOT / f).exists():
                out["missing"].append((key, f))
        existing = [f for f in files if (ROOT / f).exists()]
        if not existing:
            continue
        log = git("log", f"--since={row['reviewed']}", "--format=%h %ad %s",
                  "--date=short", "--", *existing).strip().splitlines()
        if log:
            out["drifted"].append((key, row["title"], row["reviewed"], log))
    # Coverage: every kernel source file must be mapped to a row or explicitly exempt.
    mapped = {f for r in rows.values() for f in r["files"]}
    exempt = cfg.get("exempt", {})
    patterns = [p for group in exempt.values() for p in group]
    src = sorted(p.name for p in (ROOT / "R" / "EDI" / "src").iterdir()
                 if p.suffix in (".cpp", ".h"))
    out["uncovered"] = [f for f in src if f not in mapped
                        and not any(fnmatch.fnmatch(f, pat) for pat in patterns)]
    for pat in patterns:  # an exempt entry matching nothing is a stale entry
        if not any(fnmatch.fnmatch(f, pat) for f in src):
            out["missing"].append(("exempt", pat))
    out["unassigned"] = sum(1 for f in src if any(
        fnmatch.fnmatch(f, pat) for pat in exempt.get("unassigned_kernels", [])))
    return out


TODO_HEAD = re.compile(r"^- \[([ x])\] (?:~~)?TODO-([0-9A-Za-z]+)")
REF = re.compile(r"(release_v\d_\d_\d\.md)\s*→\s*TODO-(\d+[a-z]?)(?:\.\.(\d+))?")


def release_index(fname, cache={}):
    if fname not in cache:
        active, stubs = set(), set()
        path = RELEASES / fname
        for line in (path.read_text().splitlines() if path.exists() else []):
            m = re.match(r"^- \[[ x]\] TODO-(\d+[a-z]?)\b", line)
            if m:
                active.add(m.group(1))
            m = re.match(r"^- \[[ x]\] ~~TODO-(\d+[a-z]?)~~", line)
            if m:
                stubs.add(m.group(1))
        cache[fname] = (path.exists(), active, stubs)
    return cache[fname]


def check_plan_state():
    out = {"dangling": [], "untagged": []}
    for line in AUDIT.read_text().splitlines():
        m = TODO_HEAD.match(line)
        if not m:
            continue
        done, tid = m.group(1) == "x", m.group(2)
        refs = REF.findall(line)
        if not refs and not done and "covered by" not in line:
            out["untagged"].append(tid)
        for fname, lo, hi in refs:
            exists, active, stubs = release_index(fname)
            targets = [lo] if not hi else [str(n) for n in range(int(lo), int(hi) + 1)]
            for t in targets:
                if not exists:
                    out["dangling"].append((tid, f"{fname} does not exist"))
                elif t not in active:
                    why = "is a moved-stub" if t in stubs else "not found"
                    out["dangling"].append((tid, f"{fname} → TODO-{t} {why}"))
    return out


def render(v, k, p):
    broken = len(v["errors"]) > MAX_FETCH_ERRORS
    flagged = bool(broken or v["changed"] or v["unpinned"] or k["drifted"] or k["missing"]
                   or k["stale"] or k["uncovered"] or p["dangling"] or p["untagged"])
    L = ["FLAGGED" if flagged else "CLEAN", "",
         f"# Algorithm-audit drift report ({datetime.date.today().isoformat()})", "",
         "Read-only output of `.github/scripts/algorithm_audit_drift.py`. A flag means "
         "*re-look*, not *wrong*. Procedure: "
         "`R/package_metadata/new_feature_plans/algorithm_audit_runbook.md`.", ""]
    L.append("## 1. Comparator versions")
    if broken:
        L.append(f"- **CHECK UNRELIABLE:** {len(v['errors'])} of the packages could not be "
                 f"fetched from crandb (limit {MAX_FETCH_ERRORS}), so a 'no changes' result "
                 "here means nothing. Failed: " + ", ".join(v["errors"]))
    elif v["errors"]:
        L.append("- Fetch failed (below the limit, ignored this run): " + ", ".join(v["errors"]))
    if v["skipped"]:
        L.append("_Skipped (offline)._")
    for pkg, old, new, news in v["changed"]:
        L.append(f"- **{pkg}**: pinned `{old}` → CRAN `{new}`")
        for n in (news or []):
            L.append(f"  - {n}")
        if news is None:
            L.append("  - (NEWS not found on CRAN)")
    if v["unpinned"]:
        L.append("- Unpinned (run `--snapshot` after review): " +
                 ", ".join(f"{a} `{b}`" for a, b in v["unpinned"]))
    if v["not_on_cran"]:
        L.append("- Not on CRAN (ignored): " + ", ".join(v["not_on_cran"]))
    if not (v["changed"] or v["unpinned"] or v["skipped"] or broken):
        L.append("_No changes._")
    L += ["", "## 2. Kernel drift since each row's `reviewed` date"]
    for key, title, since, log in k["drifted"]:
        L.append(f"- **Row {key}** ({title}), reviewed {since}: {len(log)} commit(s)")
        L += [f"  - `{c}`" for c in log[:MAX_COMMITS]]
        if len(log) > MAX_COMMITS:
            L.append(f"  - … and {len(log) - MAX_COMMITS} more")
    L += [f"- **Map error:** row {r} lists `{f}`, which does not exist" for r, f in k["missing"]]
    if not (k["drifted"] or k["missing"]):
        L.append("_No mapped file changed._")
    L += ["", f"### Rows past the maximum review age ({k['max_age']} days)"]
    L += [f"- **Row {key}** ({title}): last reviewed {d}, {age} days ago"
          for key, title, d, age in k["stale"]] or ["_None._"]
    L += ["", "### Kernel files in `R/EDI/src` that are neither mapped nor exempt"]
    L += [f"- `{f}`" for f in k["uncovered"]] or ["_None._"]
    if k["unassigned"]:
        L.append(f"\n_Info: {k['unassigned']} algorithm kernels sit in the map's "
                 "`unassigned_kernels` exempt list (no audit row yet); not flagged._")
    L += ["", "## 3. Plan-state hygiene"]
    L += [f"- **Audit TODO-{t}**: {why}" for t, why in p["dangling"]]
    L += [f"- **Audit TODO-{t}**: unchecked but carries no release tag" for t in p["untagged"]]
    if not (p["dangling"] or p["untagged"]):
        L.append("_All audit TODOs resolve._")
    return flagged, "\n".join(L) + "\n"


def snapshot():
    pkgs = {}
    for pkg in sorted(description_packages() | set(EXTRA_COMPARATORS)):
        try:
            ver = cran_version(pkg)
        except (urllib.error.URLError, OSError, KeyError, ValueError):
            sys.exit(f"snapshot aborted: fetching {pkg} failed; not writing a partial pin file")
        if ver is None:
            print(f"skip {pkg} (not on CRAN)", file=sys.stderr)
        else:
            pkgs[pkg] = ver
    PINS.write_text(json.dumps({"snapshot_date": datetime.date.today().isoformat(),
                                "packages": pkgs}, indent=2) + "\n")
    print(f"wrote {PINS} ({len(pkgs)} packages)")


def release_gate():
    """Pre-release gate: no open drift/failure issue and no row past its max age.
    Exit 0 pass, 1 fail, 2 could not be determined (gh missing/unauthenticated: not a pass)."""
    problems = []
    for label in ("algorithm-audit-drift", "algorithm-audit-drift-failure"):
        r = subprocess.run(["gh", "issue", "list", "--label", label, "--state", "open",
                            "--json", "number,title"], capture_output=True, text=True, cwd=ROOT)
        if r.returncode != 0:
            print(f"GATE UNDETERMINED: could not list `{label}` issues "
                  f"({r.stderr.strip() or 'gh failed'}). Run `gh auth login` and retry.")
            return 2
        problems += [f"open issue #{i['number']} ({label}): {i['title']}"
                     for i in json.loads(r.stdout)]
    problems += [f"row {key} ({title}) last reviewed {d}, {age} days ago"
                 for key, title, d, age in check_kernels()["stale"]]
    if problems:
        print("RELEASE GATE FAILED:\n" + "\n".join(f"- {x}" for x in problems))
        return 1
    print("RELEASE GATE PASSED: no open algorithm-audit issue, no row past its max age.")
    return 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="-")
    ap.add_argument("--offline", action="store_true")
    ap.add_argument("--snapshot", action="store_true")
    ap.add_argument("--release-gate", action="store_true")
    a = ap.parse_args()
    if a.release_gate:
        sys.exit(release_gate())
    if a.snapshot:
        return snapshot()
    _, text = render(check_versions(a.offline), check_kernels(), check_plan_state())
    if a.out == "-":
        sys.stdout.write(text)
    else:
        Path(a.out).write_text(text)


if __name__ == "__main__":
    main()
