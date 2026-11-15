#!/usr/bin/env bash
# Safe wrapper around `git push`: pre-regenerates and commits every
# generated file the pre-push hook (scripts/pre-push) itself knows how to
# auto-fix (the package_tests/ drift CSVs), plus the roxygen-generated docs and
# exports the hook only checks (R/EDI/man, NAMESPACE, RcppExports.*), BEFORE
# invoking the real `git push`, instead of letting the hook discover the drift
# mid-push.
# (README.md's lines-of-code badge used to be handled here too, but it's now
# a static badge fed by a Gist that .github/workflows/loc-badge.yml updates
# server-side -- README.md itself never needs a commit for it anymore.)
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

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

# Same manifest refresh scripts/pre-push runs, but pre-committed here --
# unlike the hook, this wrapper runs BEFORE the real `git push` resolves what
# to send, so a fix committed here is naturally included (see this file's
# own header comment on why the hook itself can't do that).
echo "gitpush_with_hooks_safe: refreshing the CI test-runtime manifest ..."
if ! python3 R/package_tests/ci/refresh_manifest.py; then
	echo "gitpush_with_hooks_safe: refresh_manifest.py FAILED (see output above) -- not pushing." >&2
	exit 1
fi
if ! git diff --exit-code -- R/package_tests/ci/test_runtimes.csv >/dev/null 2>&1; then
	echo "gitpush_with_hooks_safe: test_runtimes.csv drifted -- committing the fix ..."
	git add -- R/package_tests/ci/test_runtimes.csv
	git commit --quiet -m "pre-push: refresh CI test-runtime manifest" -- R/package_tests/ci/test_runtimes.csv
fi

# Roxygen-generated docs and exports. scripts/pre-push runs fast_roxygenize.R
# when the push changes roxygen comments or [[Rcpp::export]] tags, and aborts if
# the regenerated files differ from HEAD (it deliberately never commits them).
# Here, run by choice before the push, they are regenerated and committed so the
# push carries them (owner request 2026-11-15). Runs before the drift CSVs below,
# since the public API inventory reads NAMESPACE.
# Same trigger as the hook: roxygen/export lines changed in the commits being
# pushed (vs the upstream branch, else origin/main).
generated_paths=(R/EDI/man R/EDI/NAMESPACE R/EDI/R/RcppExports.R R/EDI/src/RcppExports.cpp)
push_base="$(git rev-parse --verify --quiet '@{upstream}' || git rev-parse --verify --quiet origin/main || true)"
roxy_lines=0
if [ -n "$push_base" ]; then
	roxy_lines="$(git diff -U0 "$push_base" HEAD -- 'R/EDI/R/*.R' 'R/EDI/src/*.cpp' 2>/dev/null \
		| grep -cE "^[+-]#'|^[+-].*\[\[Rcpp::export" || true)"
fi
if [ "${roxy_lines:-0}" -gt 0 ]; then
	# The generated files must describe the committed sources. With uncommitted
	# edits to R/EDI/R or R/EDI/src they would describe the working tree instead,
	# so leave them to the hook's check.
	if ! git diff --quiet HEAD -- 'R/EDI/R/*.R' 'R/EDI/src/*.cpp' ':!R/EDI/R/RcppExports.R' ':!R/EDI/src/RcppExports.cpp'; then
		echo "gitpush_with_hooks_safe: R/EDI/R or R/EDI/src has uncommitted changes -- not regenerating docs (the pre-push hook will check them)."
	else
		echo "gitpush_with_hooks_safe: roxygen comments / [[Rcpp::export]] tags changed -- running fast_roxygenize.R ..."
		roxy_out="$(mktemp)"
		roxy_status=0
		(cd R && Rscript fast_roxygenize.R) > "$roxy_out" 2>&1 || roxy_status=$?
		cat "$roxy_out"
		if [ "$roxy_status" != 0 ] || grep -qE "^Warning" "$roxy_out"; then
			rm -f "$roxy_out"
			echo "gitpush_with_hooks_safe: fast_roxygenize.R failed or reported a documentation warning (see above) -- not pushing." >&2
			exit 1
		fi
		rm -f "$roxy_out"
		if [ -n "$(git status --porcelain -- "${generated_paths[@]}")" ]; then
			echo "gitpush_with_hooks_safe: regenerated docs/exports differ from HEAD -- committing them ..."
			git add -A -- "${generated_paths[@]}"
			git commit --quiet -m "pre-push: regenerate roxygen docs and Rcpp exports" -- "${generated_paths[@]}"
		else
			echo "gitpush_with_hooks_safe: roxygen docs/exports already match HEAD."
		fi
	fi
fi

echo "gitpush_with_hooks_safe: regenerating package_tests/ drift CSVs (this runs the full generator suite -- can take a few minutes) ..."

# Generator sequence + artifact list come from R/package_tests/drift_artifacts.sh,
# the single copy shared with scripts/pre-push and test-coverage-R-advanced.yml.
mapfile -t drift_csvs < <(bash R/package_tests/drift_artifacts.sh list)

max_drift_attempts=5
attempt=1
while [ "$attempt" -le "$max_drift_attempts" ]; do
	if ! bash R/package_tests/drift_artifacts.sh regenerate; then
		echo "gitpush_with_hooks_safe: a package_tests/ generator FAILED (see output above) -- not pushing." >&2
		exit 1
	fi

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
