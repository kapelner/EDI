#!/usr/bin/env bash
#
# Build EDI in each of three modes (portable, native, native+LTO), each into
# its own throwaway library, and time a randomization-CI workload
# (R/scripts/benchmark_randomization_ci_ordinal_ppo.R) at num_cores = 3
# against each build.
#
# Usage:
#   bash R/scripts/benchmark_randomization_ci_build_modes.sh
#   EDI_BUILD_MODES="native native+lto" bash R/scripts/benchmark_randomization_ci_build_modes.sh
#
# Environment:
#   R_BIN             R executable (default: R)
#   EDI_BUILD_MODES   space-separated subset of: portable native native+lto
#   EDI_NUM_CORES     cores for the workload (default: 3)
#   EDI_R             randomization vectors per test (default: 201)
#   EDI_REPS          timed repetitions per build (default: 3)
#   EDI_INFERENCE_CLASS, EDI_NONPARALLEL, EDI_FORCE_MIRAI
#                     passed through to the workload script
#   EDI_KEEP_BUILDS   1 to keep the throwaway libraries
#
# WARNING: three full installs of R/EDI (100+ .cpp files each) — several
# minutes per build with the CPU fully loaded. Do not run alongside another
# build of the package; run on an otherwise idle machine.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
pkg_dir="$repo_root/R/EDI"
bench_r="$repo_root/R/scripts/benchmark_randomization_ci_ordinal_ppo.R"
r_bin="${R_BIN:-R}"
modes="${EDI_BUILD_MODES:-portable native native+lto}"
keep_builds="${EDI_KEEP_BUILDS:-0}"

if [ ! -f "$pkg_dir/DESCRIPTION" ]; then
  echo "error: $pkg_dir does not look like the EDI package directory" >&2
  exit 1
fi
if [ ! -f "$bench_r" ]; then
  echo "error: workload script not found: $bench_r" >&2
  exit 1
fi

work_root="$(mktemp -d "${TMPDIR:-/tmp}/edi-ci-modes.XXXXXX")"
cleanup() {
  if [ "$keep_builds" = "1" ]; then
    echo
    echo "Keeping throwaway libraries under: $work_root"
  else
    rm -rf "$work_root"
  fi
}
trap cleanup EXIT

run_mode() {
  local label="$1"
  shift

  local lib_dir build_start build_end bench_start bench_end
  lib_dir="$work_root/lib.${label//[^A-Za-z0-9_-]/_}"
  mkdir -p "$lib_dir"

  printf '\n================ %s ================\n' "$label"
  printf 'env: %s\n' "${*:-(configure defaults)}"

  build_start="$(date +%s)"
  env "$@" "$r_bin" CMD INSTALL --preclean --no-multiarch --no-docs \
    -l "$lib_dir" "$pkg_dir" > "$lib_dir/install.log" 2>&1 \
    || { echo "install failed; see $lib_dir/install.log" >&2; return 1; }
  build_end="$(date +%s)"
  printf 'install time: %ss\n' "$((build_end - build_start))"

  bench_start="$(date +%s)"
  EDI_LIB="$lib_dir" \
  EDI_LABEL="$label" \
  EDI_NUM_CORES="${EDI_NUM_CORES:-3}" \
  EDI_R="${EDI_R:-201}" \
  EDI_REPS="${EDI_REPS:-3}" \
  "$r_bin" --vanilla --quiet --file="$bench_r" | grep -v '^>'
  bench_end="$(date +%s)"
  printf 'benchmark wall time: %ss\n' "$((bench_end - bench_start))"
}

for mode in $modes; do
  case "$mode" in
    portable)   run_mode "portable"   EDI_PORTABLE=1 ;;
    native)     run_mode "native" ;;
    native+lto) run_mode "native+lto" EDI_NATIVE_LTO=1 ;;
    *) echo "unknown build mode: $mode (expected portable, native, native+lto)" >&2; exit 1 ;;
  esac
done
