#!/usr/bin/env python3
"""Pure regression checks for check_coverage_floor.py: stdlib only, no
edi_kernels build/install. Mirrors test_check_coverage_floor.R's cases."""
import subprocess
import sys
import tempfile
from pathlib import Path

SCRIPT = Path(__file__).parent / "check_coverage_floor.py"


def write_coverage_xml(path, line_rate):
	path.write_text(f'<?xml version="1.0"?><coverage line-rate="{line_rate}"></coverage>')


def write_baseline(path, r_pct, py_pct):
	fmt = lambda x: "null" if x is None else str(x)
	path.write_text(
		'{"r": {"coverage_pct": %s, "commit": "prev", "measured_at": "prev-time"}, '
		'"python": {"coverage_pct": %s, "commit": null, "measured_at": null}}'
		% (fmt(r_pct), fmt(py_pct))
	)


def run(coverage_xml, baseline, key, env=None):
	result = subprocess.run(
		[sys.executable, str(SCRIPT), str(coverage_xml), str(baseline), key],
		capture_output=True, text=True, env=env,
	)
	return result.returncode, result.stdout + result.stderr


def main():
	with tempfile.TemporaryDirectory(prefix="coverage-floor-tests-") as work:
		work = Path(work)
		baseline = work / "baseline.json"
		write_baseline(baseline, 60, None)

		# Regression: 40% fresh vs. 60% baseline must fail loudly.
		regressed_xml = work / "regressed.xml"
		write_coverage_xml(regressed_xml, 0.40)
		status, output = run(regressed_xml, baseline, "r")
		assert status != 0, output
		assert "regressed" in output.lower(), output

		# Improvement: 80% fresh vs. 60% baseline must pass and announce a new high.
		improved_xml = work / "improved.xml"
		write_coverage_xml(improved_xml, 0.80)
		status, output = run(improved_xml, baseline, "r")
		assert status == 0, output
		assert "New best-ever" in output, output

		# No prior baseline (python still null): any measurement passes and is
		# reported as a new high, never a regression.
		status, output = run(improved_xml, baseline, "python")
		assert status == 0, output
		assert "New best-ever" in output, output
		assert "regressed" not in output.lower(), output

		# Within epsilon of the baseline: neither a regression nor a new high.
		baseline_tight = work / "baseline-tight.json"
		write_baseline(baseline_tight, 80, None)
		status, output = run(improved_xml, baseline_tight, "r")
		assert status == 0, output
		assert "regressed" not in output.lower() and "New best-ever" not in output, output

		# GITHUB_STEP_SUMMARY receives the same message.
		import os
		summary = work / "summary.md"
		env = dict(os.environ, GITHUB_STEP_SUMMARY=str(summary))
		status, output = run(regressed_xml, baseline, "r", env=env)
		assert status != 0, output
		assert "regressed" in summary.read_text().lower()

	print("Coverage floor check regression checks passed.")


if __name__ == "__main__":
	main()
