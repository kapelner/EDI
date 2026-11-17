#!/usr/bin/env python3
"""Package size and time budgets for the push checks (R-CMD-check.yaml).

collect  runs at the end of each CRAN-platform check leg. It reads that leg's check
         directory and writes one JSON record: source tarball size, installed size,
         the install / examples / tests times R CMD check logged, and the whole check
         step's wall time.
report   runs once after all legs. It appends the records to a JSON-lines history,
         compares each figure with its limit and with its median over the last
         8 weeks on the same leg, and writes a Markdown report plus `breach=` to
         GITHUB_OUTPUT.
slowest  runs after the bulk test shards (test-bulk-non-cran.yml), which already time
         every test file. It lists the slowest files and the files that took longer
         than their estimate in R/package_tests/ci/test_runtimes.csv (the shard
         planner's figure, measured time plus 30% headroom), so a test that grew is
         caught and the planner's estimate is known to be stale.

Stdlib only, so it runs on every runner without installs.
"""
import argparse
import datetime as dt
import glob
import json
import os
import re
import csv
import statistics
import sys

MB = 1024 * 1024
# CRAN's policy: the source tarball should be under 5 MB. The warning limit leaves room
# to react before a submission is refused.
TARBALL_HARD = 5 * MB
TARBALL_WARN = 4 * MB
JUMP = 0.20           # a rise of more than 20% over the median
WINDOW_DAYS = 56      # 8 weeks
MIN_POINTS = 5        # fewer earlier points than this: report the figure, judge no jump
# Absolute floors so noise on small figures is not called a jump.
FLOORS = {"tarball_bytes": 100 * 1024, "installed_kb": 1024, "install_s": 60,
          "examples_s": 60, "tests_s": 120, "check_s": 180}
METRICS = ["tarball_bytes", "installed_kb", "install_s", "examples_s", "tests_s", "check_s"]

STEP_RE = {
    "install_s": r"checking whether package .* can be installed \.\.\.(.*)$",
    "examples_s": r"checking examples \.\.\.(.*)$",
    "tests_s": r"checking tests \.\.\.(.*)$",
}
# R CMD check prints " [cpu/elapsed]" (" [elapsed]" on Windows), in s, or in m above 600 s.
TIME_RE = re.compile(r"\[(?:(\d+)([sm])/)?(\d+)([sm])\]")


def parse_elapsed(text):
    m = TIME_RE.search(text)
    if not m:
        return None
    value, unit = int(m.group(3)), m.group(4)
    return value * 60 if unit == "m" else value


def parse_check_log(text):
    out = {}
    lines = text.splitlines()
    for key, pat in STEP_RE.items():
        rx = re.compile(pat)
        for i, line in enumerate(lines):
            m = rx.search(line)
            if not m:
                continue
            t = parse_elapsed(m.group(1))
            # "checking tests ..." prints its time on the "Running 'testthat.R'" line below.
            j = i + 1
            while t is None and j < len(lines) and lines[j].startswith("  "):
                t = parse_elapsed(lines[j]); j += 1
            if t is not None:
                out[key] = t
            break
    return out


def dir_kb(path):
    total = 0
    for root, _, files in os.walk(path):
        for f in files:
            try:
                total += os.path.getsize(os.path.join(root, f))
            except OSError:
                pass
    return total // 1024


def collect(args):
    rec = {"leg": args.leg, "commit": args.commit, "run_id": args.run_id,
           "at": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds")}
    tars = sorted(glob.glob(os.path.join(args.check_dir, "*.tar.gz")))
    if tars:
        rec["tarball_bytes"] = os.path.getsize(tars[-1])
    rcheck = glob.glob(os.path.join(args.check_dir, "*.Rcheck"))
    if rcheck:
        pkg_dir = os.path.join(rcheck[0], args.package)
        if os.path.isdir(pkg_dir):
            rec["installed_kb"] = dir_kb(pkg_dir)
        log = os.path.join(rcheck[0], "00check.log")
        if os.path.exists(log):
            rec.update(parse_check_log(open(log, encoding="utf-8", errors="replace").read()))
    if args.check_seconds is not None:
        rec["check_s"] = args.check_seconds
    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    with open(args.out, "w") as f:
        json.dump(rec, f, indent=2)
    print(json.dumps(rec, indent=2))
    return 0


def fmt(metric, v):
    if v is None:
        return "—"
    if metric == "tarball_bytes":
        return f"{v / MB:.2f} MB"
    if metric == "installed_kb":
        return f"{v / 1024:.1f} MB"
    return f"{v / 60:.1f} min" if v >= 600 else f"{v:.0f} s"


def judge(records, history, now):
    """Return (rows, breaches). rows: one per leg x metric with value, median, verdict."""
    rows, breaches = [], []
    cutoff = now - dt.timedelta(days=WINDOW_DAYS)
    for rec in sorted(records, key=lambda r: r["leg"]):
        past = [h for h in history if h.get("leg") == rec["leg"]
                and h.get("commit") != rec.get("commit")
                and dt.datetime.fromisoformat(h["at"]) >= cutoff]
        for m in METRICS:
            v = rec.get(m)
            if v is None:
                continue
            prev = [h[m] for h in past if h.get(m) is not None]
            med = statistics.median(prev) if len(prev) >= MIN_POINTS else None
            verdict = "ok"
            if m == "tarball_bytes" and v >= TARBALL_HARD:
                verdict = "over CRAN's 5 MB limit"
            elif m == "tarball_bytes" and v >= TARBALL_WARN:
                verdict = "over the 4 MB warning limit"
            elif med is not None and v > med * (1 + JUMP) and v - med > FLOORS[m]:
                verdict = f"+{(v / med - 1) * 100:.0f}% over the 8-week median"
            row = {"leg": rec["leg"], "metric": m, "value": v, "median": med, "verdict": verdict}
            rows.append(row)
            if verdict != "ok":
                breaches.append(row)
    return rows, breaches


def report(args):
    records = []
    for p in sorted(glob.glob(os.path.join(args.records, "**", "*.json"), recursive=True)):
        try:
            records.append(json.load(open(p)))
        except (OSError, ValueError):
            print(f"skipping unreadable record {p}", file=sys.stderr)
    history = []
    if os.path.exists(args.history):
        for line in open(args.history):
            line = line.strip()
            if line:
                try:
                    history.append(json.loads(line))
                except ValueError:
                    pass
    now = dt.datetime.fromisoformat(args.now) if args.now else dt.datetime.now(dt.timezone.utc)
    rows, breaches = judge(records, history, now)

    md = ["## Package size and time budgets", ""]
    if not records:
        md.append("No leg wrote a budget record (every CRAN-platform leg was skipped or failed early).")
    else:
        md += [f"Commit `{records[0].get('commit', '')[:8]}`. Limits: source tarball under 5 MB (CRAN), "
               f"warning at 4 MB; any figure more than {int(JUMP * 100)}% over its median on the same leg "
               f"over the last {WINDOW_DAYS // 7} weeks (needs {MIN_POINTS} earlier runs).", "",
               "| Leg | Figure | This run | 8-week median | Verdict |", "|---|---|---|---|---|"]
        for r in rows:
            mark = "" if r["verdict"] == "ok" else "**"
            md.append(f"| {r['leg']} | {r['metric']} | {fmt(r['metric'], r['value'])} | "
                      f"{fmt(r['metric'], r['median'])} | {mark}{r['verdict']}{mark} |")
        md += ["", "The slowest test files are listed by the bulk test run (test-bulk-non-cran.yml), "
               "which times every file."]
    text = "\n".join(md) + "\n"
    with open(args.out, "w") as f:
        f.write(text)
    if args.append_history:
        os.makedirs(os.path.dirname(os.path.abspath(args.history)), exist_ok=True)
        with open(args.history, "a") as f:
            for r in records:
                f.write(json.dumps(r) + "\n")
    if args.github_output:
        with open(args.github_output, "a") as f:
            f.write(f"breach={'true' if breaches else 'false'}\n")
            f.write(f"records={len(records)}\n")
    print(text)
    return 0


OVER_FLOOR_S = 10  # a file over its estimate by less than this is noise


def read_timings(folder):
    """Every shard's timings.csv: test_file -> elapsed seconds (finished rows only)."""
    out = {}
    for p in glob.glob(os.path.join(folder, "**", "timings.csv"), recursive=True):
        with open(p, newline="") as f:
            for row in csv.DictReader(f):
                try:
                    t = float(row.get("elapsed_seconds") or "nan")
                except ValueError:
                    continue
                if t == t:  # not NaN: the row finished
                    out[row["test_file"]] = out.get(row["test_file"], 0.0) + t
    return out


def read_estimates(path):
    out = {}
    if path and os.path.exists(path):
        with open(path, newline="") as f:
            for row in csv.DictReader(f):
                try:
                    out[row["test_file"]] = float(row["estimated_seconds"])
                except (KeyError, ValueError):
                    pass
    return out


def slowest(args):
    times = read_timings(args.timings)
    est = read_estimates(args.estimates)
    top = sorted(times.items(), key=lambda kv: -kv[1])[:args.top]
    over = sorted(((f, t, est[f]) for f, t in times.items()
                   if f in est and t > est[f] and t - est[f] >= OVER_FLOOR_S),
                  key=lambda x: -(x[1] - x[2]))
    md = ["## Test file times", ""]
    if not times:
        md.append("No shard wrote a timings file.")
    else:
        total = sum(times.values())
        md += [f"{len(times)} test files, {total / 60:.0f} min in all.", "",
               f"### Slowest {len(top)}", "", "| File | Time | Estimate |", "|---|---|---|"]
        md += [f"| `{os.path.basename(f)}` | {t:.0f} s | {est[f]:.0f} s |" if f in est
               else f"| `{os.path.basename(f)}` | {t:.0f} s | — |" for f, t in top]
        md += ["", f"### Over their estimate ({len(over)})", ""]
        if over:
            md += ["Estimates are the shard planner's (`R/package_tests/ci/test_runtimes.csv`: measured time "
                   "plus 30% headroom), so these files grew by more than that, or the estimate is stale. "
                   "`R/package_tests/ci/refresh_manifest.py` refreshes the estimates.", "",
                   "| File | Time | Estimate |", "|---|---|---|"]
            md += [f"| `{os.path.basename(f)}` | {t:.0f} s | {e:.0f} s |" for f, t, e in over]
        else:
            md.append("None.")
    text = "\n".join(md) + "\n"
    with open(args.out, "w") as f:
        f.write(text)
    if args.github_output:
        with open(args.github_output, "a") as f:
            f.write(f"over={len(over) if times else 0}\n")
    print(text)
    return 0


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    c = sub.add_parser("collect")
    c.add_argument("--check-dir", required=True)
    c.add_argument("--package", default="EDI")
    c.add_argument("--leg", required=True)
    c.add_argument("--commit", default=os.environ.get("GITHUB_SHA", ""))
    c.add_argument("--run-id", default=os.environ.get("GITHUB_RUN_ID", ""))
    c.add_argument("--check-seconds", type=int)
    c.add_argument("--out", required=True)
    r = sub.add_parser("report")
    r.add_argument("--records", required=True, help="folder holding the legs' JSON records")
    r.add_argument("--history", required=True, help="JSON-lines history file")
    r.add_argument("--append-history", action="store_true")
    r.add_argument("--now")
    r.add_argument("--out", required=True)
    r.add_argument("--github-output")
    t = sub.add_parser("slowest")
    t.add_argument("--timings", required=True, help="folder holding the shards' timings.csv files")
    t.add_argument("--estimates", default="R/package_tests/ci/test_runtimes.csv")
    t.add_argument("--top", type=int, default=20)
    t.add_argument("--out", required=True)
    t.add_argument("--github-output")
    a = ap.parse_args(argv)
    return {"collect": collect, "report": report, "slowest": slowest}[a.cmd](a)


if __name__ == "__main__":
    sys.exit(main())
