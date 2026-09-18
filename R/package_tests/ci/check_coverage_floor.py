#!/usr/bin/env python3
"""Coverage-floor gate (TODO-9, R/package_metadata/new_feature_plans/
full_test_coverage.md): exits non-zero if aggregate coverage drops below the
best-ever figure recorded in coverage_baseline.json. On a new high, prints
instructions to bump the baseline by hand -- mirrors check_coverage_floor.R
and check_coverage_registry.R's existing measure-then-human-commits pattern;
this script never writes the baseline file itself.

Used both by test-coverage-python.yml (CI, hard gate) and .githooks/pre-push
(local -- like every other pre-push check, still skippable with
`git push --no-verify`). Stdlib only: the pre-push hook calls this with the
system python3, not the project's test venv.
"""
import datetime
import json
import os
import sys
import xml.etree.ElementTree as ET

EPSILON = 0.05  # percentage points; avoids failing on float noise between otherwise-identical runs


def main(argv):
	if len(argv) != 4:
		print("Usage: check_coverage_floor.py COVERAGE_XML BASELINE_JSON LANGUAGE_KEY", file=sys.stderr)
		return 2
	coverage_xml, baseline_path, language_key = argv[1], argv[2], argv[3]

	root = ET.parse(coverage_xml).getroot()
	fresh_pct = float(root.attrib["line-rate"]) * 100

	with open(baseline_path) as f:
		baseline = json.load(f)
	best_pct = (baseline.get(language_key) or {}).get("coverage_pct")

	best_str = f"{best_pct:.2f}%" if best_pct is not None else "none recorded yet"
	print(f"Coverage floor check ({language_key}): fresh = {fresh_pct:.2f}%, best-ever = {best_str}")

	summary_path = os.environ.get("GITHUB_STEP_SUMMARY")

	def write_summary(line):
		if summary_path:
			with open(summary_path, "a") as f:
				f.write(line + "\n")

	if best_pct is not None and fresh_pct < best_pct - EPSILON:
		msg = (f"Coverage regressed: {fresh_pct:.2f}% is below the best-ever figure of "
			f"{best_pct:.2f}% (dropped {best_pct - fresh_pct:.2f} points). "
			"See R/package_tests/ci/coverage_baseline.json.")
		write_summary(f"**{msg}**")
		print(msg, file=sys.stderr)
		return 1

	if best_pct is None or fresh_pct > best_pct + EPSILON:
		prev = "none" if best_pct is None else f"{best_pct:.2f}%"
		msg = (f"New best-ever {language_key} coverage: {fresh_pct:.2f}% (previous: {prev}). "
			f'Update the "{language_key}" entry in R/package_tests/ci/coverage_baseline.json '
			"and commit it to raise the floor.")
		print(msg)
		write_summary(msg)

	return 0


if __name__ == "__main__":
	sys.exit(main(sys.argv))
