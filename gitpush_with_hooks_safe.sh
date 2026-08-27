#!/usr/bin/env bash
# Safe wrapper around `git push`: pre-regenerates and commits every
# generated file the pre-push hook (.githooks/pre-push) itself knows how to
# auto-fix (README.md's cloc table, the package_tests/ drift CSVs) BEFORE
# invoking the real `git push`, instead of letting the hook discover the
# drift mid-push.
#
# Why this exists rather than making the hook self-heal-and-continue: a
# pre-push hook cannot include a commit it creates in the SAME push
# invocation -- git resolves the exact commit SHA to send *before* running
# the hook (confirmed empirically), so a hook-made commit is stuck local-only
# until a second `git push`. Having the hook `git push` itself to work around
# that recurses infinitely, since `git push` from inside a pre-push hook
# re-triggers that same hook (also confirmed empirically, the hard way, in a
# disposable test repo). Doing the regeneration+commit here, as an ordinary
# step *before* `git push` runs at all, sidesteps both problems entirely:
# by the time the real `git push` resolves what to send, these commits
# already exist in history, so they're included naturally -- no hook
# involved, no recursion possible.
#
# Usage: ./gitpush_with_hooks_safe.sh [any normal `git push` arguments]
# Run from the repo root (or anywhere -- it cd's to the repo root itself).

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$repo_root"

echo "gitpush_with_hooks_safe: regenerating README.md lines-of-code table ..."
if bash scripts/update_readme_cloc.sh; then
	if ! git diff --exit-code -- README.md >/dev/null 2>&1; then
		echo "gitpush_with_hooks_safe: README.md was stale -- committing the refreshed table ..."
		git add README.md
		git commit -m "updated README with new lines of code counts"
	else
		echo "gitpush_with_hooks_safe: README.md already up to date."
	fi
else
	echo "gitpush_with_hooks_safe: scripts/update_readme_cloc.sh failed -- leaving README.md as-is (same as the hook's own cloc-not-installed fallback)." >&2
fi

echo
echo "gitpush_with_hooks_safe: regenerating package_tests/ drift CSVs (this runs the full generator suite -- can take a few minutes) ..."

# Same file list .githooks/pre-push checks -- keep these two in sync if
# either changes.
drift_csvs=(
	package_tests/public_api_inventory.csv
	package_tests/public_argument_baseline_gap_report.csv
	package_tests/checkmate_argument_contracts.csv
	package_tests/public_argument_combination_cases.csv
	package_tests/public_argument_combination_rejected_candidates.csv
	package_tests/public_argument_combination_coverage.csv
	package_tests/public_argument_combination_results.csv
	package_tests/public_argument_combination_failures.csv
	package_tests/public_argument_combination_uncovered_apis.csv
	package_tests/public_argument_combination_registry_drift.csv
	package_tests/public_argument_combination_slowest_cases.csv
	package_tests/public_argument_combination_ci_failure_summary.csv
	package_tests/public_argument_combination_cases_integrated.csv
	package_tests/public_argument_combination_results_integrated.csv
	package_tests/public_argument_combination_coverage_integrated.csv
	package_tests/public_argument_combination_quality_gates.csv
	package_tests/public_argument_combination_quality_gate_summary.csv
	package_tests/comprehensive_suite_registry.csv
	package_tests/comprehensive_suite_baseline_audit.csv
)

max_drift_attempts=5
attempt=1
while [ "$attempt" -le "$max_drift_attempts" ]; do
	(
		cd R &&
		Rscript package_tests/public_api_inventory.R &&
		Rscript package_tests/extract_checkmate_argument_contracts.R &&
		Rscript package_tests/generate_public_argument_combinations.R &&
		Rscript package_tests/run_public_argument_combinations.R &&
		Rscript package_tests/analyze_public_argument_combinations.R &&
		Rscript package_tests/public_argument_combination_integration.R &&
		Rscript package_tests/check_public_argument_combination_quality_gates.R report &&
		Rscript package_tests/comprehensive_suite_registry.R &&
		Rscript package_tests/audit_comprehensive_suite_baseline.R
	)

	drift_csvs_prefixed=()
	for f in "${drift_csvs[@]}"; do drift_csvs_prefixed+=("R/$f"); done

	if (cd R && git diff --exit-code -- "${drift_csvs[@]}") >/dev/null 2>&1; then
		echo "gitpush_with_hooks_safe: package_tests/ CSVs already match HEAD (attempt $attempt/$max_drift_attempts)."
		break
	fi

	echo "gitpush_with_hooks_safe: package_tests/ CSVs drifted (attempt $attempt/$max_drift_attempts) -- committing the fix ..."
	(cd R && git add -- "${drift_csvs[@]}")
	git commit --quiet -m "pre-push: auto-regenerate drifted package_tests CSVs" -- "${drift_csvs_prefixed[@]}"
	attempt=$((attempt + 1))
done

if [ "$attempt" -gt "$max_drift_attempts" ]; then
	echo "gitpush_with_hooks_safe: package_tests/ CSVs still drifted after $max_drift_attempts attempts -- either something keeps editing the source tree concurrently, or a generator is non-deterministic. Not pushing; investigate before retrying." >&2
	exit 1
fi

echo
echo "gitpush_with_hooks_safe: drift pre-settled -- running the real 'git push' $*"
exec git push "$@"
