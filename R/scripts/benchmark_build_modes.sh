#!/usr/bin/env bash
#
# Build EDI three ways -- portable, native, native+LTO -- each into its own
# throwaway library, then run the same kernel microbenchmark against each so
# the three builds can be compared back-to-back on this machine.
#
# Build modes (see R/EDI/configure and the README "Local performance builds"
# table):
#   portable     EDI_PORTABLE=1                       no -march=native, no -O3
#   native       (configure defaults)                 -march=native -mtune=native -O3
#   native+lto   EDI_NATIVE_LTO=1                     native flags + -flto
#
# Usage:
#   bash R/scripts/benchmark_build_modes.sh                # all three modes
#   EDI_BUILD_MODES="native native+lto" bash R/scripts/benchmark_build_modes.sh
#   EDI_BENCH_SCRIPT=path/to/bench.R bash R/scripts/benchmark_build_modes.sh
#
# Environment:
#   R_BIN             R executable (default: R)
#   EDI_BUILD_MODES   space-separated subset of: portable native native+lto
#   EDI_BENCH_SCRIPT  an R script to run under each build instead of the
#                     built-in microbenchmark. It is run with R_LIBS_USER set
#                     to the throwaway library, so a plain library(EDI) picks
#                     up that build.
#   EDI_BENCH_REPS    replicates per kernel for the built-in benchmark
#                     (default: 200)
#   EDI_BENCH_N       sample size for the built-in benchmark (default: 1000)
#   EDI_BENCH_P       number of covariates for the built-in benchmark
#                     (default: 10)
#   EDI_KEEP_BUILDS   1 to keep the throwaway libraries (paths are printed)
#
# WARNING: this performs three full installs of R/EDI (100+ .cpp files each).
# Expect several minutes per build and a fully loaded CPU throughout. Do not
# run it alongside another build of the package. Run it on an otherwise idle
# machine or the timings are meaningless.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
pkg_dir="$repo_root/R/EDI"
r_bin="${R_BIN:-R}"
modes="${EDI_BUILD_MODES:-portable native native+lto}"
bench_script="${EDI_BENCH_SCRIPT:-}"
reps="${EDI_BENCH_REPS:-200}"
bench_n="${EDI_BENCH_N:-1000}"
bench_p="${EDI_BENCH_P:-10}"
keep_builds="${EDI_KEEP_BUILDS:-0}"

if [ ! -f "$pkg_dir/DESCRIPTION" ]; then
  echo "error: $pkg_dir does not look like the EDI package directory" >&2
  exit 1
fi

work_root="$(mktemp -d "${TMPDIR:-/tmp}/edi-build-modes.XXXXXX")"
cleanup() {
  if [ "$keep_builds" = "1" ]; then
    echo
    echo "Keeping throwaway libraries under: $work_root"
  else
    rm -rf "$work_root"
  fi
}
trap cleanup EXIT

# Built-in benchmark: a few hot kernels every replicate loop hits, timed with
# median wall time over $reps calls. Prints one tab-separated line per kernel:
#   <kernel>\t<median_us>\t<q1_us>\t<q3_us>
builtin_bench="$work_root/bench.R"
cat > "$builtin_bench" <<'RSCRIPT'
suppressPackageStartupMessages(library(EDI))
reps = as.integer(Sys.getenv("EDI_BENCH_REPS", "200"))
n    = as.integer(Sys.getenv("EDI_BENCH_N", "1000"))
p    = as.integer(Sys.getenv("EDI_BENCH_P", "10"))
set.seed(42)
X = cbind(1, matrix(rnorm(n * (p - 1)), n, p - 1))
beta = rnorm(p, sd = 0.3)
y_gauss = as.numeric(X %*% beta + rnorm(n))
y_bin   = as.numeric(rbinom(n, 1, plogis(X %*% beta)))
y_pois  = as.numeric(rpois(n, exp(X %*% beta)))

time_one = function(f) {
  f() # warm up
  t = numeric(reps)
  for (i in seq_len(reps)) {
    t0 = proc.time()[["elapsed"]]
    f()
    t[i] = proc.time()[["elapsed"]] - t0
  }
  stats::quantile(t * 1e6, c(0.5, 0.25, 0.75), names = FALSE)
}

kernels = list(
  fast_ols_cpp                 = function() fast_ols_cpp(X, y_gauss),
  fast_logistic_regression_cpp = function() fast_logistic_regression_cpp(X, y_bin),
  fast_poisson_regression_cpp  = function() fast_poisson_regression_cpp(X, y_pois)
)

cat(sprintf("n = %d, p = %d, reps = %d\n", n, p, reps))
cat(sprintf("%-32s %12s %12s %12s\n", "kernel", "median_us", "q1_us", "q3_us"))
for (nm in names(kernels)) {
  q = time_one(kernels[[nm]])
  cat(sprintf("%-32s %12.1f %12.1f %12.1f\n", nm, q[1], q[2], q[3]))
}
RSCRIPT

if [ -z "$bench_script" ]; then
  bench_script="$builtin_bench"
fi

run_mode() {
  local label="$1"
  shift

  local lib_dir start end elapsed
  lib_dir="$work_root/lib.${label//[^A-Za-z0-9_-]/_}"
  mkdir -p "$lib_dir"

  printf '\n================ %s ================\n' "$label"
  printf 'env: %s\n' "${*:-(configure defaults)}"

  start="$(date +%s)"
  env "$@" "$r_bin" CMD INSTALL --preclean --no-multiarch --no-docs \
    -l "$lib_dir" "$pkg_dir" > "$lib_dir/install.log" 2>&1 \
    || { echo "install failed; see $lib_dir/install.log" >&2; return 1; }
  end="$(date +%s)"
  elapsed=$((end - start))
  printf 'build time: %ss\n' "$elapsed"

  # Confirm the build carries the flags we asked for.
  R_LIBS_USER="$lib_dir" "$r_bin" --quiet --no-save -e \
    'suppressPackageStartupMessages(library(EDI)); bi = EDI:::edi_build_info_cpp(); keep = grep("^(env_edi_|pkg_cxxflags|cxxflags)", names(bi), value = TRUE); cat("build info:", paste(keep, unlist(bi[keep]), sep = "=", collapse = "  "), "\n")' \
    2>/dev/null | grep -v '^>' || true

  printf -- '--- benchmark ---\n'
  R_LIBS_USER="$lib_dir" \
    EDI_BENCH_REPS="$reps" EDI_BENCH_N="$bench_n" EDI_BENCH_P="$bench_p" \
    "$r_bin" --quiet --no-save --file="$bench_script" 2>&1 | grep -v '^>'
}

for mode in $modes; do
  case "$mode" in
    portable)   run_mode "portable"   EDI_PORTABLE=1 ;;
    native)     run_mode "native" ;;
    native+lto) run_mode "native+lto" EDI_NATIVE_LTO=1 ;;
    *) echo "unknown build mode: $mode (expected portable, native, native+lto)" >&2; exit 1 ;;
  esac
done
