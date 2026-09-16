#!/usr/bin/env python3
"""Deterministic longest-first packing; no R loading or compilation."""
import argparse
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
MANIFEST = ROOT / "R/package_tests/ci/test_runtimes.csv"


def plan(tier, target, output=None):
    with MANIFEST.open() as stream:
        rows = [row for row in csv.DictReader(stream) if row["runtime_tier"] == tier]
    actual = {str(p.relative_to(ROOT)) for directory in
              ("R/EDI/tests/testthat", "R/package_tests/testthat_bulk")
              for p in (ROOT / directory).glob("test-*.R")
              if tier == "coverage" or "testthat_bulk" in str(p)}
    recorded = [row["test_file"] for row in rows]
    if len(recorded) != len(set(recorded)) or set(recorded) != actual:
        raise ValueError(f"Manifest inventory mismatch: missing={actual - set(recorded)}, "
                         f"obsolete={set(recorded) - actual}; run refresh_manifest.py")
    buckets = []
    for row in sorted(rows, key=lambda r: (-float(r["estimated_seconds"]), r["test_file"])):
        seconds = float(row["estimated_seconds"])
        if not 0 < seconds <= target:
            raise ValueError(f"Split oversized test before CI: {row['test_file']} ({seconds}s)")
        candidates = [b for b in buckets if b["estimated_seconds"] + seconds <= target]
        bucket = min(candidates, key=lambda b: (b["estimated_seconds"], b["shard"])) if candidates else None
        if bucket is None:
            bucket = dict(shard=len(buckets) + 1, estimated_seconds=0, test_files=[])
            buckets.append(bucket)
        bucket["estimated_seconds"] += seconds
        bucket["test_files"].append(row["test_file"])
    if not buckets or len(buckets) > 256:
        raise ValueError("Invalid GitHub matrix size")
    if output is None:
        print(f"{tier}: inventory and runtime budgets valid ({len(rows)} files, {len(buckets)} shards)")
        return
    output.mkdir(parents=True, exist_ok=True)
    for bucket in buckets:
        (output / f"shard-{bucket['shard']}.json").write_text(json.dumps(bucket, indent=2) + "\n")
        print(f"{tier} shard {bucket['shard']}: {len(bucket['test_files'])} files, "
              f"{bucket['estimated_seconds'] / 60:.1f} estimated minutes")
    (output / "matrix.json").write_text(json.dumps({"shard": [b["shard"] for b in buckets]}))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("tier", choices=["correctness", "coverage"])
    parser.add_argument("--target-seconds", type=float, default=2400)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--check-only", action="store_true", help="Validate without writing shard files")
    args = parser.parse_args()
    if not args.check_only and args.output is None:
        parser.error("--output is required unless --check-only is specified")
    try:
        plan(args.tier, args.target_seconds, None if args.check_only else args.output)
    except (ValueError, OSError) as error:
        parser.exit(1, f"Shard check failed: {error}\n")
