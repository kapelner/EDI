#ifdef EDI_CORE_ONLY
#include "_helper_functions_core.h"
#include "result_map.h"
#include "na_real_core.h"
#else
#include "_helper_functions.h"
#include "result_map_rcpp.h"
#include <RcppEigen.h>
#endif
#include "survival_rank_test.h"
#include <algorithm>
#include <cmath>
#include <vector>

#ifndef EDI_CORE_ONLY
using namespace Rcpp;
#endif

namespace {

ModelResult fast_gehan_wilcox_internal(const Eigen::Ref<const Eigen::VectorXd>& time,
                                const std::vector<int>& dead,
                                const std::vector<int>& w) {
  return edi_survival::rank_test<true>(time, dead, w);
}

} // namespace

// Portable (EDI_CORE_ONLY-safe) sibling of fast_gehan_wilcox_stats_cpp
// below: fast_gehan_wilcox_internal above is already fully portable (plain
// Eigen::VectorXd/std::vector<int>, returns the shared, already-portable
// ModelResult struct) but has internal linkage (anonymous namespace), so it
// can't be called from a separate Python binding translation unit directly.
// This wrapper -- external linkage, same TU, so it CAN see the anonymous-
// namespace function -- just re-exposes it under a stable name.
ModelResult fast_gehan_wilcox_result(const Eigen::Ref<const Eigen::VectorXd>& time,
                                      const std::vector<int>& dead,
                                      const std::vector<int>& w) {
  return fast_gehan_wilcox_internal(time, dead, w);
}

#ifndef EDI_CORE_ONLY
// [[Rcpp::export]]
List fast_gehan_wilcox_stats_cpp(const IntegerVector& w,
                            const NumericVector& y_r,
                            const IntegerVector& dead) {
  Eigen::Map<const Eigen::VectorXd> y(y_r.begin(), y_r.size());
  int n = y.size();
  std::vector<int> dead_std(n), w_std(n);
  for(int i=0; i<n; ++i) { dead_std[i] = dead[i]; w_std[i] = w[i]; }

  ModelResult res = fast_gehan_wilcox_internal(y, dead_std, w_std);
  int n_treat = 0;
  for(int val : w_std) if (val == 1) n_treat++;

  return edi::to_rcpp_list(edi::ResultMap()
    .set("score", res.dispersion)
    .set("var_score", (res.sigma2_hat > 0.0) ? res.sigma2_hat : NA_REAL)
    .set("beta_hat", res.b[0])
    .set("se_beta_hat", res.ssq_b_2)
    .set("n_treat", n_treat)
    .set("n_control", n - n_treat));
}
#endif // EDI_CORE_ONLY
