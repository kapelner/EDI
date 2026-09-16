#!/usr/bin/env python3
"""Refresh inventory and optionally import CSV timing artifacts from CI."""
import argparse
import csv
from plan_shards import ROOT, MANIFEST

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--timings", nargs="*", default=[])
args = parser.parse_args()
existing = {}
if MANIFEST.exists():
    with MANIFEST.open() as stream:
        existing = {(r["runtime_tier"], r["test_file"]): r for r in csv.DictReader(stream)}
measurements = {}
for path in args.timings:
    with open(path) as stream:
        for row in csv.DictReader(stream):
            if row["status"] != "complete":
                continue
            key = row["runtime_tier"], row["test_file"]
            measurements[key] = max(measurements.get(key, 0), float(row["elapsed_seconds"]))
rows = []
for directory in ("R/EDI/tests/testthat", "R/package_tests/testthat_bulk"):
    for path in sorted((ROOT / directory).glob("test-*.R")):
        name = str(path.relative_to(ROOT))
        for tier in ("correctness", "coverage"):
            if tier == "correctness" and "testthat_bulk" not in directory:
                continue
            key = tier, name
            # Conservative starting estimates, explicitly labelled as unmeasured.
            expensive_case = "run-all-inference-case-" in name and int(path.stem.rsplit("-", 1)[1]) <= 18
            seconds = 900 if expensive_case else 120
            if "testthat_bulk" not in directory:
                seconds = 15  # These files were previously measured at <=3s without instrumentation.
            if tier == "coverage":
                seconds *= 2
            row = existing.get(key, dict(test_file=name, runtime_tier=tier,
                                        estimated_seconds=seconds, estimate_source="bootstrap"))
            if key in measurements:
                row["estimated_seconds"] = max(1, round(measurements[key] * 1.3, 1))
                row["estimate_source"] = "measured_with_30_percent_headroom"
            rows.append(row)
with MANIFEST.open("w", newline="") as stream:
    writer = csv.DictWriter(stream, fieldnames=["test_file", "runtime_tier", "estimated_seconds", "estimate_source"])
    writer.writeheader()
    writer.writerows(sorted(rows, key=lambda r: (r["runtime_tier"], r["test_file"])))
