#!/usr/bin/env bash
#
# Compare three builds of EDI across several hot C++ kernels:
#   current_normal            working tree, configure defaults (vectorized)
#   current_no_vectorization  working tree, EDI_DISABLE_VECTORIZATION=1
#                             (-DEIGEN_DONT_VECTORIZE -fno-tree-vectorize)
#   head_pre_optimization     a `git archive HEAD` snapshot, configure defaults
# so a working-tree change can be measured against both "no SIMD" and "last
# commit". Results land in $OUT_DIR as simd_matrix_raw.csv and
# simd_matrix_summary.csv.
#
# Usage:
#   bash R/scripts/benchmark_simd_matrix.sh
#   REPS=10 OUT_DIR=R/benchmark/simd_matrix bash R/scripts/benchmark_simd_matrix.sh
#   KEEP_BUILDS=1 bash R/scripts/benchmark_simd_matrix.sh
#
# WARNING: three full installs of R/EDI (100+ .cpp files each) — several
# minutes per build with the CPU fully loaded. Do not run alongside another
# build of the package; run on an otherwise idle machine.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPS="${REPS:-5}"
OUT_DIR="${OUT_DIR:-$repo_root/R/benchmark/simd_matrix}"
keep_flag=()
if [ "${KEEP_BUILDS:-0}" = "1" ]; then
  keep_flag=(--keep_builds)
fi

cd "$repo_root"
Rscript R/scripts/benchmark_simd_matrix.R --reps="${REPS}" --out_dir="${OUT_DIR}" "${keep_flag[@]}"
