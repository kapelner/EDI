#!/usr/bin/env bash
# Single source of truth for the package_tests/ "drift artifacts": the CSVs
# that are derived from live introspection of EDI's current source and must
# therefore be regenerated and committed whenever the source changes.
#
# Three places used to carry their own private copy of BOTH the generator
# sequence and the CSV list -- scripts/pre-push, gitpush_with_hooks_safe.sh
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
	"capability_matrix.R"
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
	package_tests/capability_matrix.csv
	package_tests/design_matrix.csv
	package_tests/capability_matrix.json
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

# Generator outputs that are written on every run but are not gated artifacts:
# the exemptions CSV is date-stamped (see above) and the HTML report is a view of
# the combination results. They are left out of the fingerprint below, or it
# would never match from one day to the next.
untracked_outputs=(
	package_tests/comprehensive_suite_exemptions.csv
	package_tests/public_argument_combination_report.html
)

# Skip-if-unchanged cache (local only). The generators are deterministic, so if
# nothing they read or write has changed since the last successful regenerate,
# running them again reproduces the same files. That happens on every push via
# gitpush_with_hooks_safe.sh (it regenerates, then git push runs pre-push, which
# regenerates again) and on pre-push's confirming pass after it auto-commits
# drifted CSVs. The fingerprint hashes, relative to R/:
#   - every tracked or untracked-but-not-ignored file under EDI/ and
#     package_tests/ (sources, tests, the generators, the tracked results CSVs
#     and the artifacts themselves, since some generators read earlier outputs),
#     except package_tests/{calibration,ci}/ (no generator reads them) and the
#     untracked_outputs above;
#   - the installed EDI's DESCRIPTION (its Built: stamp changes on reinstall) and
#     the R version, since EDI is loaded from source but R and its library are not.
# It lives in the git dir, so it is never committed. CI (CI=true) never uses it
# and always regenerates; EDI_DRIFT_NO_CACHE=1 forces a run locally. A missed
# change can at worst skip a local regenerate: CI's own regenerate still gates.
fingerprint_file() {
	echo "$(cd "$(git -C "$r_dir" rev-parse --git-dir)" && pwd)/edi-drift-fingerprint"
}

# $1 = "all" (inputs and artifacts) or "inputs" (artifacts excluded).
drift_fingerprint() {
	local mode="$1" excluded
	excluded="$(printf '%s\n' "${untracked_outputs[@]}")"
	if [ "$mode" = inputs ]; then excluded="$excluded"$'\n'"$(printf '%s\n' "${artifacts[@]}")"; fi
	(
		set +o pipefail
		cd "$r_dir"
		git ls-files -co --exclude-standard -- EDI package_tests \
			| grep -vE '^package_tests/(calibration|ci)/' \
			| grep -vxF -f <(printf '%s\n' "$excluded") \
			| while IFS= read -r f; do [ -f "$f" ] && printf '%s\n' "$f"; done \
			| sort > "$fp_list"
		# --stdin-paths resolves paths from the repo root, not the cwd: pass them absolute.
		sed "s|^|$r_dir/|" "$fp_list" | git hash-object --no-filters --stdin-paths | paste -d' ' - "$fp_list"
		printf 'installed-EDI %s\n' "$installed_edi"
		R --version | head -1
	) | git hash-object --stdin
}

case "${1:-}" in
	regenerate)
		cd "$r_dir"
		# Generators read only git-tracked inputs, so a local regenerate matches
		# CI's clean checkout (see read_comprehensive_results() in
		# audit_comprehensive_suite_baseline.R).
		export EDI_DRIFT_TRACKED_INPUTS_ONLY=1
		# Skip the saved-tuning import (and its "fastest at N cores" startup
		# notice in every generator). scripts/pre-push exports this too, but
		# gitpush_with_hooks_safe.sh runs this regenerate before git push.
		export EDI_SKIP_LOCAL_TUNING=1

		use_cache=1
		if [ "${CI:-}" = "true" ] || [ "${EDI_DRIFT_NO_CACHE:-0}" = "1" ]; then use_cache=0; fi
		if [ "$use_cache" = 1 ]; then
			fp_list="$(mktemp)"
			trap 'rm -f "$fp_list"' EXIT
			installed_edi="$(Rscript -e 'f = system.file("DESCRIPTION", package = "EDI"); cat(if (nzchar(f)) tools::md5sum(f) else "none")' 2>/dev/null || echo unknown)"
			fp_file="$(fingerprint_file)"
			if [ -f "$fp_file" ] && [ "$(cat "$fp_file")" = "$(drift_fingerprint all)" ]; then
				echo "drift_artifacts: nothing the generators read or write has changed since the last regenerate; skipping (EDI_DRIFT_NO_CACHE=1 forces a run)."
				exit 0
			fi
			rm -f "$fp_file"
			inputs_before="$(drift_fingerprint inputs)"
		fi

		# One R process for all generators (EDI loaded from source once; see
		# run_drift_generators.R). EDI_DRIFT_SEPARATE_PROCESSES=1 runs each in its
		# own Rscript, as before 2026-11-13.
		if [ "${EDI_DRIFT_SEPARATE_PROCESSES:-0}" = "1" ]; then
			for g in "${generators[@]}"; do
				echo ">>> Rscript package_tests/$g"
				# shellcheck disable=SC2086  # intentional word-splitting: "<script> <arg>"
				Rscript package_tests/$g
			done
		else
			Rscript package_tests/run_drift_generators.R "${generators[@]}"
		fi

		if [ "$use_cache" = 1 ]; then
			# Record only if no input changed while the generators ran (another
			# session editing the tree); otherwise these outputs may not match.
			if [ "$(drift_fingerprint inputs)" = "$inputs_before" ]; then
				drift_fingerprint all > "$fp_file"
			else
				echo "drift_artifacts: sources changed during this regenerate; not recording a fingerprint." >&2
			fi
		fi
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
