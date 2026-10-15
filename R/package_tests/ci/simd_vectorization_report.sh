#!/usr/bin/env bash
# Reports whether each EDI_SIMD / EDI_SIMD_REDUCTION loop in R/EDI/src is
# actually vectorized by clang (arm_hardware.md TODO-7 / TODO-8). Run from
# the repo root after Rcpp, RcppEigen and RcppNumerical are installed:
#
#   R/package_tests/ci/simd_vectorization_report.sh [report.md]
#
# Compiles the files holding the hints (plus a probe TU that instantiates the
# weighted_crossprod helpers in _helper_functions_core.h) into a temp dir with
# -Rpass=loop-vectorize. The R/EDI/src tree is never written to. Uses R's own
# C++ compiler unless SIMD_REPORT_CXX is set; needs clang (GCC has no -Rpass).
#
# Exit status: 0 when every hinted loop vectorized and the compile emitted no
# warnings; 1 otherwise (a -Wpass-failed warning would also surface in an
# R CMD check install log); 2 when the compiler is not clang. Written for
# macOS's bash 3.2: no associative arrays or mapfile.

set -u

src="R/EDI/src"
report="${1:-/dev/stdout}"
[ -d "$src" ] || { echo "run from the repo root ($src not found)" >&2; exit 2; }

cxx="${SIMD_REPORT_CXX:-$(R CMD config CXX17)}"
if ! $cxx --version 2>/dev/null | grep -qi clang; then
  echo "compiler '$cxx' is not clang; -Rpass remarks need clang" >&2
  exit 2
fi

r_inc() { Rscript -e "cat(system.file('include', package = '$1'))"; }
cppflags="$(R CMD config --cppflags) -I$(r_inc Rcpp) -I$(r_inc RcppEigen) -I$(r_inc RcppNumerical) -I$src"
# Same defines as the package build; OpenMP is whatever R itself enables
# (empty on CRAN's macOS R), so this shows the build users actually get.
# R CMD config rejects SHLIB_OPENMP_CXXFLAGS, so read R's Makeconf, as
# R/EDI/configure does. SIMD_REPORT_OPENMP overrides it (set it empty to
# check the no-OpenMP clang path on a Linux machine).
makeconf="$(R RHOME)/etc${R_ARCH:-}/Makeconf"
openmp="${SIMD_REPORT_OPENMP-$(sed -n 's/^SHLIB_OPENMP_CXXFLAGS[[:space:]]*=[[:space:]]*//p' "$makeconf")}"
flags="-O2 -fPIC -DNDEBUG -DEIGEN_NO_DEBUG $openmp -Rpass=loop-vectorize -Rpass-missed=loop-vectorize"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

cat > "$work/helpers_probe.cpp" <<'EOF'
#include "_helper_functions.h"
typedef Eigen::Map<const Eigen::Matrix<double, Eigen::Dynamic, Eigen::Dynamic, Eigen::RowMajor>> RowMap;
Eigen::MatrixXd p1(const Eigen::MatrixXd& X, const Eigen::VectorXd& w) { return weighted_crossprod(X, w); }
Eigen::MatrixXd p2(const RowMap& X, const Eigen::VectorXd& w) { return weighted_crossprod(X, w); }
Eigen::VectorXd p3(const Eigen::MatrixXd& X, const Eigen::VectorXd& w, const Eigen::VectorXd& y) { return weighted_crossprod_rhs(X, w, y); }
Eigen::VectorXd p4(const RowMap& X, const Eigen::VectorXd& w, const Eigen::VectorXd& y) { return weighted_crossprod_rhs(X, w, y); }
// The generic templates only reach their hinted loops for row-major X.
typedef Eigen::Matrix<double, Eigen::Dynamic, Eigen::Dynamic, Eigen::RowMajor> RowMat;
Eigen::MatrixXd p5(const RowMat& X, const Eigen::VectorXd& w) { return weighted_crossprod(X, w); }
Eigen::VectorXd p6(const RowMat& X, const Eigen::VectorXd& w, const Eigen::VectorXd& y) { return weighted_crossprod_rhs(X, w, y); }
EOF

units="$work/helpers_probe.cpp"
for f in $(grep -l 'EDI_SIMD' "$src"/*.cpp); do units="$units $f"; done

log="$work/remarks.log"
: > "$log"
compile_failed=0
for u in $units; do
  # shellcheck disable=SC2086
  if ! $cxx $cppflags $flags -c "$u" -o "$work/$(basename "$u" .cpp).o" >> "$log" 2>&1; then
    echo "compile failed: $u" >&2
    compile_failed=1
  fi
done

failures=0
{
  echo "### SIMD hint vectorization ($($cxx --version | head -1))"
  echo
  echo "OpenMP flags from R: \`${openmp:-none}\`"
  echo
  echo "| Site | Loop line | Result |"
  echo "|---|---|---|"
  for f in "$src"/_helper_functions_core.h $(grep -l 'EDI_SIMD' "$src"/*.cpp); do
    base="$(basename "$f")"
    for hint in $(grep -n '^[[:space:]]*EDI_SIMD' "$f" | cut -d: -f1); do
      loop="$(awk -v L="$hint" 'NR > L && /for[[:space:]]*\(/ { print NR; exit }' "$f")"
      hits="$(grep -E "(^|/)$base:$loop:[0-9]+: remark: vectorized loop" "$log" | head -1)"
      if [ -n "$hits" ]; then
        result="vectorized ($(echo "$hits" | sed -n 's/.*(\(vectorization width: [0-9]*\).*/\1/p'))"
      else
        why="$(grep -E "(^|/)$base:$loop:[0-9]+: remark: loop not vectorized" "$log" | head -1 | sed 's/.*remark: //; s/ \[-Rpass.*//')"
        result="**NOT vectorized** ${why:-no remark emitted}"
        failures=$((failures + 1))
      fi
      echo "| \`$base:$hint\` | $loop | $result |"
    done
  done
  echo
  warnings="$(grep -E ': warning: ' "$log" | sort -u)"
  if [ -n "$warnings" ]; then
    echo "Compiler warnings (R CMD check would report these):"
    echo
    echo '```'
    echo "$warnings"
    echo '```'
    failures=$((failures + 1))
  else
    echo "No compiler warnings."
  fi
} >> "$report"

[ "$compile_failed" = 0 ] || { grep -E ': error: ' "$log" | head -20 >&2; exit 1; }
[ "$failures" = 0 ] || exit 1
exit 0
