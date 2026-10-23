#!/usr/bin/env bash
# Local ASAN/UBSAN and valgrind evidence for the EDI native kernels
# (release_v1_0_5.md TODO-38 and TODO-63; TODO-66's bulk contract can be run too).
#
# Everything happens under $EDI_SAN_DIR (default /tmp/edi-san): rsync copies of
# R/EDI, private R libraries, copied tests, R's TMPDIR and all logs. The repo is
# only read. Run from ANY directory; the repo root is found from this script's path.
#
# THIS SCRIPT DOES A FULL COMPILE of R/EDI (build-asan, build-vg). It is for the
# user to run; agents must not run it (see CLAUDE.md).
#
# WHAT THIS DOES AND DOES NOT CLOSE. The plan's gate G5 for TODO-38/63/66 is the
# project's CI jobs (R-CMD-check-sanitizers / -valgrind / test-bulk-non-cran) green
# at a COMMITTED SHA, and TODO-38 also needs G4 (comprehensive-CSV reconciliation).
# This script produces the local, attested equivalent: a build manifest (SHA, dirty-
# tree hash, compiler, flags, DLL hash), per-test-block results as CSV, and a
# validity check that rejects banner-only Valgrind logs. Whether local evidence may
# stand in for G5 is the owner's decision; the CI run remains the literal gate.
#
# Usage: scripts/sanitizer_valgrind_check.sh <step> [more steps...]
#   prepare      rsync source + tests into $EDI_SAN_DIR, record SHA + dirty-tree hash
#   build-asan   install an ASAN+UBSAN build into $EDI_SAN_DIR/lib-asan
#   test-asan    run the kernel tests against it (system R + LD_PRELOAD)
#   build-vg     install a plain -O1 -g build into $EDI_SAN_DIR/lib-vg
#   test-vg      run the kernel tests under valgrind, one process per file
#   manifest     write logs/manifest.txt (SHA, flags, compiler, DLL hashes, R version)
#   report       per-test-block CSVs + pass/fail validity verdict (exit 1 if invalid)
#   clean        delete $EDI_SAN_DIR (only that directory)
# Example: scripts/sanitizer_valgrind_check.sh prepare build-asan test-asan build-vg test-vg manifest report
#
# Env overrides: EDI_SAN_DIR, EDI_SAN_JOBS (default 4), EDI_SAN_TESTS (space-
# separated test file names; default below), EDI_SAN_BULK_TESTS (extra bulk-suite
# files run in the ASAN pass only, e.g. the TODO-66 file; default: none).
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
W="${EDI_SAN_DIR:-/tmp/edi-san}"
JOBS="${EDI_SAN_JOBS:-4}"
# Default = the files TODO-38 / TODO-63 name: malformed-warm-start contract,
# ZOIB length guards, mixed-kernel shape guards, and the lme4 GLMM equivalence.
TESTS="${EDI_SAN_TESTS:-test-kernel-warm-start-length-contracts.R test-zoib-kernel-input-length-validation.R test-mixed-kernel-warm-start-shape-guards-reference.R test-glmm-cpp-equivalence.R}"
BULK_TESTS="${EDI_SAN_BULK_TESTS:-}"
BULK_TEST_DIR="$REPO/R/package_tests/testthat_bulk"
WARN="-Wno-ignored-attributes"

case "$W" in
  "$REPO"|"$REPO"/*) echo "EDI_SAN_DIR must be outside the repo: $W" >&2; exit 2;;
esac

# R helper: run test files, print one line per test block, write a CSV.
# Args: out.csv file1 file2 ...   (test blocks = testthat results, so each
# wrapper's expect_error block shows up by name)
write_runner() {
  cat > "$W/run_tests.R" <<'EOF'
args <- commandArgs(TRUE)
out <- args[1]; files <- args[-1]
suppressPackageStartupMessages({library(EDI); library(testthat)})
rows <- list()
for (f in files) {
  res <- as.data.frame(testthat::test_file(f, reporter = "silent", stop_on_failure = FALSE))
  res$file <- f
  rows[[length(rows) + 1L]] <- res[, c("file", "test", "nb", "failed", "skipped", "error", "warning")]
}
all <- do.call(rbind, rows)
utils::write.csv(all, out, row.names = FALSE)
cat(sprintf("RUNNER_SUMMARY blocks=%d expectations=%d failed=%d errors=%d skipped=%d\n",
  nrow(all), sum(all$nb), sum(all$failed), sum(all$error), sum(all$skipped)))
EOF
}

prepare() {
  mkdir -p "$W/lib-asan" "$W/lib-vg" "$W/tmp" "$W/logs" "$W/results"
  for d in src-asan src-vg; do
    rsync -a --delete --exclude='*.o' --exclude='*.so' --exclude='*.dll' --exclude='.git' \
      "$REPO/R/EDI/" "$W/$d/"
  done
  rsync -a --delete "$REPO/R/EDI/tests/testthat/" "$W/tests/testthat/"
  for t in $TESTS $BULK_TESTS; do
    if [ ! -f "$W/tests/testthat/$t" ] && [ -f "$BULK_TEST_DIR/$t" ]; then
      cp "$BULK_TEST_DIR/$t" "$W/tests/testthat/"
    fi
    [ -f "$W/tests/testthat/$t" ] || { echo "test file not found: $t" >&2; exit 2; }
  done
  # Preflight: warn if a selected test (or the helpers/setup files testthat loads
  # with it) reads files by relative path; those would fail in this /tmp copy.
  local hits
  hits="$( cd "$W/tests/testthat" && grep -nE 'test_path|system\.file|\.\./|readRDS|read\.csv|fread|source\(|getwd|list\.files|file\.exists|load_all' \
      $TESTS $BULK_TESTS helper-*.R setup-*.R 2>/dev/null | grep -vE ':[0-9]+:[[:space:]]*#' || true )"
  if [ -n "$hits" ]; then
    echo "WARNING: possible repo-relative file access (add the fixture to prepare if a test fails):" >&2
    echo "$hits" >&2
  fi
  git -C "$REPO" rev-parse HEAD | tee "$W/logs/checkout_sha.txt"
  # Dirty-tree fingerprint: the plan requires the tested tree to be identifiable.
  { git -C "$REPO" status --porcelain; git -C "$REPO" diff HEAD -- R/EDI; } | sha256sum | cut -d' ' -f1 \
    | tee "$W/logs/dirty_tree_sha256.txt"
  write_runner
}

write_makevars() {  # $1 = path, $2 = flags
  cat > "$1" <<EOF
CXXFLAGS   = $2
CXX17FLAGS = $2
CXX20FLAGS = $2
MAKEFLAGS  = -j$JOBS
EOF
}

build_asan() {
  local flags="-O1 -g -fno-omit-frame-pointer -fsanitize=address,undefined -fno-sanitize-recover=undefined $WARN"
  write_makevars "$W/Makevars.asan" "$flags"
  echo "SHLIB_LIBADD = -fsanitize=address,undefined" >> "$W/Makevars.asan"
  ( cd "$W" && R_MAKEVARS_USER="$W/Makevars.asan" EDI_UNITY=0 EDI_PORTABLE=1 TMPDIR="$W/tmp" \
      R CMD INSTALL --no-test-load --library="$W/lib-asan" "$W/src-asan" ) 2>&1 | tee "$W/logs/build-asan.log"
}

test_asan() {
  local pre
  pre="$(gcc -print-file-name=libasan.so):$(gcc -print-file-name=libubsan.so)"
  # LD_PRELOAD is scoped to the Rscript process only.
  ( cd "$W/tests/testthat" && env LD_PRELOAD="$pre" \
      ASAN_OPTIONS=detect_leaks=0:abort_on_error=0:halt_on_error=1 \
      UBSAN_OPTIONS=print_stacktrace=1:halt_on_error=1 \
      NOT_CRAN=true R_LIBS="$W/lib-asan" TMPDIR="$W/tmp" \
      Rscript "$W/run_tests.R" "$W/results/asan.csv" $TESTS $BULK_TESTS ) 2>&1 | tee "$W/logs/test-asan.log"
}

build_vg() {
  write_makevars "$W/Makevars.vg" "-O1 -g $WARN"
  ( cd "$W" && R_MAKEVARS_USER="$W/Makevars.vg" EDI_UNITY=0 EDI_PORTABLE=1 TMPDIR="$W/tmp" \
      R CMD INSTALL --library="$W/lib-vg" "$W/src-vg" ) 2>&1 | tee "$W/logs/build-vg.log"
}

test_vg() {
  local t
  for t in $TESTS; do
    ( cd "$W/tests/testthat" && NOT_CRAN=true R_LIBS="$W/lib-vg" TMPDIR="$W/tmp" \
        R -d "valgrind --tool=memcheck --leak-check=no --error-exitcode=1 --track-origins=yes" \
        --vanilla --no-echo -f "$W/run_tests.R" --args "$W/results/vg-${t%.R}.csv" "$t" ) 2>&1 \
      | tee "$W/logs/valgrind-${t%.R}.log" || true
  done
}

manifest() {
  {
    echo "date: $(date -u +%FT%TZ)"
    echo "checkout SHA: $(cat "$W/logs/checkout_sha.txt" 2>/dev/null || echo unknown)"
    echo "dirty-tree sha256: $(cat "$W/logs/dirty_tree_sha256.txt" 2>/dev/null || echo unknown)"
    echo "R: $(R --version | head -1)"
    echo "gcc: $(gcc --version | head -1)"
    echo "EDI version (src): $(grep '^Version:' "$REPO/R/EDI/DESCRIPTION")"
    echo "build env: EDI_UNITY=0 EDI_PORTABLE=1 MAKEFLAGS=-j$JOBS"
    for v in asan vg; do
      echo "--- Makevars.$v"; cat "$W/Makevars.$v" 2>/dev/null || echo "(not built)"
    done
    echo "--- DLL SHA-256"
    sha256sum "$W"/lib-asan/EDI/libs/EDI.so "$W"/lib-vg/EDI/libs/EDI.so 2>&1 || true
    echo "--- ASAN actually linked into lib-asan EDI.so?"
    ( ldd "$W/lib-asan/EDI/libs/EDI.so" 2>/dev/null | grep -E "asan|ubsan" ) || echo "NOT FOUND (build is not instrumented)"
    echo "--- per-file object evidence (EDI_UNITY=0 => one .o per .cpp)"
    echo "asan .o count: $(find "$W/src-asan/src" -name '*.o' 2>/dev/null | wc -l)  unity_*.o: $(find "$W/src-asan/src" -name 'unity_*.o' 2>/dev/null | wc -l)"
    echo "vg   .o count: $(find "$W/src-vg/src"   -name '*.o' 2>/dev/null | wc -l)  unity_*.o: $(find "$W/src-vg/src"   -name 'unity_*.o' 2>/dev/null | wc -l)"
  } | tee "$W/logs/manifest.txt"
}

# Validity rules (so a banner-only or skipped run can never look green):
#  ASAN:  runner printed RUNNER_SUMMARY with expectations>0, failed=0, errors=0,
#         and no "ERROR: AddressSanitizer" / "runtime error:" in the log.
#  VG:    per file, RUNNER_SUMMARY with expectations>0, failed=0, errors=0, AND
#         valgrind printed "ERROR SUMMARY: 0 errors" (a banner alone is invalid).
report() {
  local rc=0 f log
  echo "== ASAN/UBSAN =="
  if [ -f "$W/logs/test-asan.log" ]; then
    grep -E "RUNNER_SUMMARY" "$W/logs/test-asan.log" || { echo "INVALID: no RUNNER_SUMMARY"; rc=1; }
    if grep -qE "ERROR: AddressSanitizer|runtime error:" "$W/logs/test-asan.log"; then
      echo "FAIL: sanitizer report found"; rc=1; fi
    if grep -E "RUNNER_SUMMARY" "$W/logs/test-asan.log" | grep -qE "expectations=0 |failed=[1-9]|errors=[1-9]"; then
      echo "FAIL/INVALID: zero expectations or failures"; rc=1; fi
    [ -f "$W/results/asan.csv" ] && echo "per-block results: $W/results/asan.csv"
  else echo "not run"; rc=1; fi
  echo "== Valgrind =="
  for t in $TESTS; do
    log="$W/logs/valgrind-${t%.R}.log"
    if [ ! -f "$log" ]; then echo "$t: not run"; rc=1; continue; fi
    if ! grep -q "ERROR SUMMARY: 0 errors" "$log"; then echo "$t: INVALID/FAIL (no 'ERROR SUMMARY: 0 errors')"; rc=1; continue; fi
    if ! grep "RUNNER_SUMMARY" "$log" | grep -qvE "expectations=0 |failed=[1-9]|errors=[1-9]"; then
      echo "$t: INVALID/FAIL (tests did not run clean)"; rc=1; continue; fi
    echo "$t: OK  $(grep RUNNER_SUMMARY "$log")"
  done
  echo "== verdict =="
  if [ "$rc" -eq 0 ]; then echo "local evidence VALID (see manifest.txt for SHA/DLL/flags)"; else echo "local evidence NOT valid"; fi
  return "$rc"
}

clean() { rm -rf -- "$W"; echo "removed $W"; }

[ "$#" -ge 1 ] || { sed -n '2,36p' "${BASH_SOURCE[0]}"; exit 2; }
for step in "$@"; do
  echo "=== $step ($(date +%H:%M:%S)) ==="
  case "$step" in
    prepare)    prepare;;
    build-asan) build_asan;;
    test-asan)  test_asan;;
    build-vg)   build_vg;;
    test-vg)    test_vg;;
    manifest)   manifest;;
    report)     report;;
    clean)      clean;;
    *) echo "unknown step: $step" >&2; exit 2;;
  esac
done
