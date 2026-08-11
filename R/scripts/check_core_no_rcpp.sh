#!/usr/bin/env bash
# Fails if any EDI_CORE_ONLY-migrated core in R/EDI/src still references
# Rcpp/SEXP. See check_core_no_rcpp.py for what "core" means and why this
# check exists (TODO-3 in package_metadata/new_feature_plans/
# sexp_removal_rcppeigen_conversion_spec.md).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="${SCRIPT_DIR}/../EDI/src"

exec python3 "${SCRIPT_DIR}/check_core_no_rcpp.py" "${SRC_DIR}"
