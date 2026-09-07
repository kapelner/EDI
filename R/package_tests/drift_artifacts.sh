#!/usr/bin/env bash
# Single source of truth for the package_tests/ "drift artifacts": the CSVs
# that are derived from live introspection of EDI's current source and must
# therefore be regenerated and committed whenever the source changes.
#
# Three places used to carry their own private copy of BOTH the generator
# sequence and the CSV list -- .githooks/pre-push, gitpush_with_hooks_safe.sh
# and .github/workflows/test-coverage-R-advanced.yml -- and they drifted
# apart (2026-09-07: the local copies lacked public_argument_contract_registry.R
# and comprehensive_suite_internal_surfaces.R entirely, and ran the registry
# before the audit it reads), so the local loop "converged" on output CI's own
# regeneration disagreed with, and pushes failed CI anyway. All three now call
# this script. Add a generator or an artifact HERE and nowhere else.
#
# Usage (from any directory):
#   drift_artifacts.sh regenerate   run every generator, in dependency order
#   drift_artifacts.sh list         print the artifact paths, relative to R/
#   drift_artifacts.sh check        git diff --exit-code on those artifacts
#                                   (non-zero + the diff on stdout if stale)
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # .../R/package_tests
r_dir="$(dirname "$here")"                              # .../R

# Dependency order (each line's inputs are produced by the lines above it):
#   public_api_inventory            -> (load_all of current source) inventory CSV
#   extract_checkmate_argument_contracts -> contracts CSV
#   public_argument_contract_registry    -> registry CSV, read by analyze +
#                                           quality gates: a stale committed
#                                           registry silently changes every
#                                           downstream count and row order
#   generate / run / analyze / integration / quality gates
#                                        -> the argument-combination family,
#                                           incl. coverage CSV
#   audit_comprehensive_suite_baseline   -> baseline audit (reads coverage)
#   comprehensive_suite_registry         -> reads the baseline audit, so it
#                                           MUST come after the audit
#   comprehensive_suite_internal_surfaces -> reads audit + registry + inventory
generators=(
	"public_api_inventory.R"
	"extract_checkmate_argument_contracts.R"
	"public_argument_contract_registry.R"
	"generate_public_argument_combinations.R"
	"run_public_argument_combinations.R"
	"analyze_public_argument_combinations.R"
	"public_argument_combination_integration.R"
	"check_public_argument_combination_quality_gates.R report"
	"audit_comprehensive_suite_baseline.R"
	"comprehensive_suite_registry.R"
	"comprehensive_suite_internal_surfaces.R"
)

# Everything the generators above write that is meant to be committed.
# comprehensive_suite_exemptions.csv is deliberately NOT here:
# audit_comprehensive_suite_baseline.R stamps it with created_date = Sys.Date()
# on every run, so it would always "drift", and its reason/owner/expiry
# columns are scaffolding for later human review, not something to gate on.
artifacts=(
	package_tests/public_api_inventory.csv
	package_tests/public_argument_baseline_gap_report.csv
	package_tests/checkmate_argument_contracts.csv
	package_tests/public_argument_contract_registry.csv
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
	package_tests/comprehensive_suite_baseline_audit.csv
	package_tests/comprehensive_suite_registry.csv
	package_tests/comprehensive_suite_internal_surfaces.csv
)

case "${1:-}" in
	regenerate)
		cd "$r_dir"
		for g in "${generators[@]}"; do
			echo ">>> Rscript package_tests/$g"
			# shellcheck disable=SC2086  # intentional word-splitting: "<script> <arg>"
			Rscript package_tests/$g
		done
		;;
	list)
		printf '%s\n' "${artifacts[@]}"
		;;
	check)
		cd "$r_dir"
		git diff --exit-code -- "${artifacts[@]}"
		;;
	*)
		sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' >&2
		exit 2
		;;
esac
