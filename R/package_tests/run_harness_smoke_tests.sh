#!/usr/bin/env bash
# Runs the package_tests harness's own unit tests (R/package_tests/smoke_test_*.R) and
# fails if any does. Called by scripts/pre-push (comprehensive block, after the drift
# check converges, so the committed CSVs these read are settled).
#
# These went unrun from about 2026-10 to 2026-11-15 and rotted while the harness drifted
# from EDI (lazy-component stubs hid most argument contracts; release_v1_0_7.md TODO-18).
#
# Skipped by default, because the hook already runs the comprehensive suite's smoke tier
# and they take ~200 s each: smoke_test_run_comprehensive_suite.R and
# smoke_test_analyze_comprehensive_suite.R. EDI_HARNESS_SMOKE_ALL=1 runs them too.
# Tests run 4 at a time; together about 35 s.
#
# Usage (from any directory): run_harness_smoke_tests.sh
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$here/.." || exit 2   # R/, where every smoke test expects to start
log_dir="$(mktemp -d "${TMPDIR:-/tmp}/edi_harness_smoke.XXXXXX")"
trap 'rm -rf "$log_dir"' EXIT

skip_re='smoke_test_(run_comprehensive_suite|analyze_comprehensive_suite)\.R$'
tests=()
for f in package_tests/smoke_test_*.R; do
	if [ "${EDI_HARNESS_SMOKE_ALL:-0}" != "1" ] && [[ "$f" =~ $skip_re ]]; then continue; fi
	tests+=("$f")
done

run_one() {
	local f="$1" log="$log_dir/$(basename "$1").log"
	if Rscript "$f" > "$log" 2>&1; then echo "ok   $f"; else echo "FAIL $f"; fi
}
export -f run_one
export log_dir

results="$(printf '%s\n' "${tests[@]}" | xargs -P 4 -I{} bash -c 'run_one "$@"' _ {})"
echo "$results" | sort
failed="$(echo "$results" | grep '^FAIL' | awk '{print $2}')"
if [ -n "$failed" ]; then
	for f in $failed; do
		echo "---- $f" >&2
		grep -v "saved tuning\|system scope bus\|deduce timezone" "$log_dir/$(basename "$f").log" | tail -15 >&2
	done
	echo "harness smoke tests: $(echo "$failed" | wc -l) of ${#tests[@]} FAILED" >&2
	exit 1
fi
echo "harness smoke tests: all ${#tests[@]} passed"
