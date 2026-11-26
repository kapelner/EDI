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

ModelResult fast_logrank_internal(const Eigen::Ref<const Eigen::VectorXd>& time,
                                const std::vector<int>& dead,
                                const std::vector<int>& w) {
  return edi_survival::rank_test<false>(time, dead, w);
}

} // namespace

// Portable (EDI_CORE_ONLY-safe) sibling of fast_logrank_stats_cpp below:
// fast_logrank_internal above is already fully portable (plain
// Eigen::VectorXd/std::vector<int>, returns the shared, already-portable
// ModelResult struct) but has internal linkage (anonymous namespace), so it
// can't be called from a separate Python binding translation unit directly.
// This wrapper -- external linkage, same TU, so it CAN see the anonymous-
// namespace function -- just re-exposes it under a stable name.
ModelResult fast_logrank_result(const Eigen::Ref<const Eigen::VectorXd>& time,
                                 const std::vector<int>& dead,
                                 const std::vector<int>& w) {
  return fast_logrank_internal(time, dead, w);
}

#ifndef EDI_CORE_ONLY
// [[Rcpp::export]]
List fast_logrank_stats_cpp(const IntegerVector& w,
                            const NumericVector& y_r,
                            const IntegerVector& dead) {
  Eigen::Map<const Eigen::VectorXd> y(y_r.begin(), y_r.size());
  int n = y.size();
  std::vector<int> dead_std(n), w_std(n);
  for(int i=0; i<n; ++i) { dead_std[i] = dead[i]; w_std[i] = w[i]; }

  ModelResult res = fast_logrank_internal(y, dead_std, w_std);
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

// BRT variant of the log-rank martingale-residual mean difference: each replicate b
// resamples rows i_mat(., b) of the sharp-null survival times y0 (and censoring
// indicators dead) and pairs them with the fresh assignment w_mat(., b); the sharp-null
// shift is multiplicative on the treated times (delta on the log scale).
// [[Rcpp::export]]
NumericVector compute_logrank_rand_bootstrap_parallel_cpp(
    const NumericVector& y0,
    const IntegerVector& dead,
    const IntegerMatrix& i_mat,
    const IntegerMatrix& w_mat,
    double delta,
    Rcpp::Nullable<Rcpp::NumericMatrix> noise_mat,
    int num_cores) {

  const int n = i_mat.nrow();
  const int nsim = i_mat.ncol();
  std::vector<double> results_vec(nsim, NA_REAL);
  const double* y0_ptr = y0.begin();
  const int* dead_ptr = dead.begin();
  const int* i_ptr = i_mat.begin();
  const int* w_ptr = w_mat.begin();
  double* res_ptr = results_vec.data();
  const double mult = std::exp(delta);
  const bool use_parallel = should_parallelize_replicates(nsim, n, num_cores);

  // An empty (0-length) matrix, e.g. matrix(0, 0, 0), is Nullable::isNotNull() == TRUE
  // but has no data: treat it as absent so noise_ptr[b * n + i] is never read OOB.
  NumericMatrix noise_m;
  if (noise_mat.isNotNull()) noise_m = NumericMatrix(noise_mat);
  const bool has_noise = noise_m.size() > 0;
  const double* noise_ptr = has_noise ? noise_m.begin() : nullptr;

#pragma omp parallel if(use_parallel) num_threads(EDI_KERNEL_NUM_THREADS(num_cores))
  {
    Eigen::VectorXd time_b(n);
    std::vector<int> dead_b(n), w_b(n);

#pragma omp for schedule(static)
    for (int b = 0; b < nsim; ++b) {
      const int* i_col = i_ptr + (size_t)b * n;
      const int* w_col = w_ptr + (size_t)b * n;
      for (int i = 0; i < n; ++i) {
        const int row0 = i_col[i] - 1; // i_mat is 1-based
        const int is_t = (w_col[i] == 1);
        double yv = y0_ptr[row0];
        if (has_noise) yv += noise_ptr[(size_t)b * n + i];
        time_b[i] = (is_t && delta != 0.0) ? yv * mult : yv;
        dead_b[i] = dead_ptr[row0];
        w_b[i] = is_t;
      }
      ModelResult r = fast_logrank_internal(time_b, dead_b, w_b);
      res_ptr[b] = (r.b.size() > 0) ? r.b[0] : NA_REAL;
    }
  }

  return wrap(results_vec);
}
#endif // EDI_CORE_ONLY
