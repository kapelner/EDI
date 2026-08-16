#ifdef EDI_CORE_ONLY
#include "_helper_functions_core.h"
#include <stdexcept>
#else
// [[Rcpp::depends(RcppEigen)]]
#include "_helper_functions.h"
#include "result_map_rcpp.h"
#endif
#include <limits>
#include <unordered_map>

#ifndef EDI_CORE_ONLY
using namespace Rcpp;
#endif

// all_finite_mat/all_finite_vec are now the canonical versions in
// _helper_functions_core.h (already in this file's include chain) -- see
// their comment for why.

struct SummarizeWithVcovResult {
  double beta_hat;
  double ssq_hat;
  double se;
  Eigen::MatrixXd vcov;
  Eigen::VectorXd std_err;
  Eigen::VectorXd z_vals;
};

// Portable (EDI_CORE_ONLY-safe) core shared by ols_hc2_post_fit_cpp,
// glm_sandwich_post_fit_cpp, and glm_cluster_sandwich_post_fit_cpp below:
// identical logic to the original summarize_with_vcov, just throwing
// std::invalid_argument instead of Rcpp::stop() and returning a plain
// struct instead of Rcpp::List.
SummarizeWithVcovResult summarize_with_vcov_result(const Eigen::VectorXd& coef_hat,
                                                    const Eigen::MatrixXd& vcov,
                                                    int j_treat) {
  const int p = static_cast<int>(coef_hat.size());
  const int j_treat0 = j_treat - 1;
  if (j_treat0 < 0 || j_treat0 >= p) {
    throw std::invalid_argument("treatment column index is out of bounds");
  }
  if (!all_finite_mat(vcov)) {
    throw std::invalid_argument("non-finite covariance matrix");
  }

  Eigen::VectorXd std_err(p);
  Eigen::VectorXd z_vals(p);
  for (int j = 0; j < p; ++j) {
    const double var_j = vcov(j, j);
    std_err[j] = (std::isfinite(var_j) && var_j >= 0.0) ? std::sqrt(var_j) : std::numeric_limits<double>::quiet_NaN();
    z_vals[j] = (std::isfinite(std_err[j]) && std_err[j] > 0.0) ? coef_hat[j] / std_err[j] : std::numeric_limits<double>::quiet_NaN();
  }

  const double ssq_hat = vcov(j_treat0, j_treat0);
  const double beta_hat = coef_hat[j_treat0];

  return SummarizeWithVcovResult{
    beta_hat, ssq_hat,
    (std::isfinite(ssq_hat) && ssq_hat >= 0.0) ? std::sqrt(ssq_hat) : std::numeric_limits<double>::quiet_NaN(),
    vcov, std_err, z_vals
  };
}

// Portable (EDI_CORE_ONLY-safe) sibling of ols_hc2_setup_cpp +
// ols_hc2_post_fit_precomputed_cpp + ols_hc2_post_fit_cpp below: identical
// HC2 sandwich-SE logic (bread = (X'X)^-1, hat = leverage, omega =
// resid^2/(1-hat), meat = X' diag(omega) X, vcov = bread*meat*bread), fused
// into one call on plain Eigen types so a separate Python binding
// translation unit can call it without ols_hc2_post_fit_cpp's internal
// SEXP round-trip through ols_hc2_setup_cpp.
SummarizeWithVcovResult ols_hc2_post_fit_result(const Eigen::Ref<const Eigen::MatrixXd>& X_fit,
                                                const Eigen::Ref<const Eigen::VectorXd>& y,
                                                const Eigen::Ref<const Eigen::VectorXd>& coef_hat,
                                                int j_treat) {
  const int n = static_cast<int>(X_fit.rows());
  const int p = static_cast<int>(X_fit.cols());
  if (!all_finite_mat(X_fit)) {
    throw std::invalid_argument("non-finite design matrix");
  }
  if (static_cast<int>(y.size()) != n || static_cast<int>(coef_hat.size()) != p) {
    throw std::invalid_argument("dimension mismatch in ols_hc2_post_fit_result");
  }
  if (!all_finite_vec(coef_hat)) {
    throw std::invalid_argument("non-finite inputs");
  }

  const Eigen::MatrixXd XtX = X_fit.transpose() * X_fit;
  Eigen::LDLT<Eigen::MatrixXd> ldlt(XtX);
  if (ldlt.info() != Eigen::Success) {
    throw std::runtime_error("failed to factorize X'X");
  }
  const Eigen::MatrixXd bread = ldlt.solve(Eigen::MatrixXd::Identity(p, p));
  if (ldlt.info() != Eigen::Success || !all_finite_mat(bread)) {
    throw std::runtime_error("failed to invert X'X");
  }

  const Eigen::VectorXd hat = (X_fit * bread).cwiseProduct(X_fit).rowwise().sum();

  const Eigen::VectorXd resid = y - X_fit * coef_hat;
  if (!all_finite_vec(resid)) {
    throw std::invalid_argument("non-finite residuals");
  }

  Eigen::VectorXd omega(n);
  for (int i = 0; i < n; ++i) {
    omega[i] = resid[i] * resid[i] / std::max(1.0 - hat[i], std::numeric_limits<double>::epsilon());
  }

  Eigen::MatrixXd meat = weighted_crossprod(X_fit, omega);
  Eigen::MatrixXd vcov = bread * meat * bread;
  vcov = 0.5 * (vcov + vcov.transpose());
  return summarize_with_vcov_result(coef_hat, vcov, j_treat);
}

#ifndef EDI_CORE_ONLY
namespace {

edi::ResultMap summarize_with_vcov(const Eigen::VectorXd& coef_hat,
                                   const Eigen::MatrixXd& vcov,
                                   int j_treat) {
  SummarizeWithVcovResult res = summarize_with_vcov_result(coef_hat, vcov, j_treat);
  return edi::ResultMap()
    .set("beta_hat", res.beta_hat)
    .set("ssq_hat", res.ssq_hat)
    .set("se", res.se)
    .set("vcov", res.vcov)
    .set("std_err", res.std_err)
    .set("z_vals", res.z_vals);
}

// Named cluster_meat_robust (not cluster_meat) because gcomp_speedups.cpp's
// same-named function computes the same result via a different
// implementation strategy (map keyed directly by cluster id, instead of a
// lookup-table + vector of accumulators) -- not unified, since picking one
// strategy for both call sites is a separate, out-of-scope performance
// decision. See unity_build_collision_audit.md.
Eigen::MatrixXd cluster_meat_robust(const Eigen::MatrixXd& X_fit,
                             const Eigen::VectorXd& resid,
                             const IntegerVector& cluster_id) {
  const int n = X_fit.rows();
  const int p = X_fit.cols();
  if (cluster_id.size() != n) {
    stop("dimension mismatch in cluster_meat");
  }

  std::unordered_map<int, int> cluster_lookup;
  std::vector<Eigen::VectorXd> cluster_scores;
  cluster_scores.reserve(static_cast<std::size_t>(n));

  for (int i = 0; i < n; ++i) {
    const int id = cluster_id[i];
    auto it = cluster_lookup.find(id);
    int pos;
    if (it == cluster_lookup.end()) {
      pos = static_cast<int>(cluster_scores.size());
      cluster_lookup.emplace(id, pos);
      cluster_scores.push_back(Eigen::VectorXd::Zero(p));
    } else {
      pos = it->second;
    }
    cluster_scores[static_cast<std::size_t>(pos)].noalias() += X_fit.row(i).transpose() * resid[i];
  }

  Eigen::MatrixXd meat = Eigen::MatrixXd::Zero(p, p);
  for (const auto& score_g : cluster_scores) {
    meat.noalias() += score_g * score_g.transpose();
  }
  return meat;
}

}  // namespace

// [[Rcpp::export]]
List ols_hc2_setup_cpp( const Eigen::Map<Eigen::MatrixXd>& X_fit) {

  
  const int n = X_fit.rows();
  const int p = X_fit.cols();
  if (!all_finite_mat(X_fit)) {
    stop("non-finite design matrix");
  }

  const Eigen::MatrixXd XtX = X_fit.transpose() * X_fit;
  Eigen::LDLT<Eigen::MatrixXd> ldlt(XtX);
  if (ldlt.info() != Eigen::Success) {
    stop("failed to factorize X'X");
  }
  const Eigen::MatrixXd bread = ldlt.solve(Eigen::MatrixXd::Identity(p, p));
  if (ldlt.info() != Eigen::Success || !all_finite_mat(bread)) {
    stop("failed to invert X'X");
  }

  const Eigen::VectorXd hat = (X_fit * bread).cwiseProduct(X_fit).rowwise().sum();

  return edi::to_rcpp_list(edi::ResultMap()
    .set("bread", bread)
    .set("hat", hat));
}

// [[Rcpp::export]]
List ols_hc2_post_fit_precomputed_cpp(const Eigen::Map<Eigen::MatrixXd>& X_fit, SEXP y, const Eigen::Map<Eigen::VectorXd>& coef_hat, const Eigen::Map<Eigen::MatrixXd>& bread, const Eigen::Map<Eigen::VectorXd>& hat, int j_treat) {
	NumericVector y_r_coerced(y); Eigen::Map<const Eigen::VectorXd> y_vec_coerced(y_r_coerced.begin(), y_r_coerced.size());


  

  

  

  

  
  const int n = X_fit.rows();
  const int p = X_fit.cols();
  if (y_vec_coerced.size() != n || coef_hat.size() != p || bread.rows() != p || bread.cols() != p || hat.size() != n) {
    stop("dimension mismatch in ols_hc2_post_fit_precomputed_cpp");
  }
  if (!all_finite_vec(coef_hat) || !all_finite_mat(bread) || !all_finite_vec(hat)) {
    stop("non-finite inputs");
  }

  const Eigen::VectorXd resid = y_vec_coerced - X_fit * coef_hat;
  if (!all_finite_vec(resid)) {
    stop("non-finite residuals");
  }

  Eigen::VectorXd omega(n);
  for (int i = 0; i < n; ++i) {
    omega[i] = resid[i] * resid[i] / std::max(1.0 - hat[i], std::numeric_limits<double>::epsilon());
  }

  Eigen::MatrixXd meat = weighted_crossprod(X_fit, omega);
  Eigen::MatrixXd vcov = bread * meat * bread;
  vcov = 0.5 * (vcov + vcov.transpose());
  return edi::to_rcpp_list(summarize_with_vcov(coef_hat, vcov, j_treat));
}

//' HC2 Heteroskedasticity-Robust Post-Fit Inference for OLS (C++)
//'
//' Given an already-fitted ordinary least squares model, computes the
//' \strong{HC2} heteroskedasticity-consistent sandwich covariance matrix
//' (MacKinnon-White) for the coefficients: \eqn{\widehat{\mathrm{Var}}(\hat\beta)
//' = B\,M\,B}, with "bread" \eqn{B = (X^\top X)^{-1}} and "meat" \eqn{M =
//' X^\top \mathrm{diag}(\omega_i) X}, where \eqn{\omega_i = r_i^2 / (1 - h_{ii})}
//' — the squared OLS residual \eqn{r_i} \strong{leverage-corrected} by dividing
//' by \eqn{1 - h_{ii}} (\eqn{h_{ii}} the \eqn{i}-th diagonal of the OLS hat
//' matrix \eqn{X(X^\top X)^{-1}X^\top}), unlike the plain HC0 sandwich
//' (\code{\link{gcomp_logistic_post_fit_cpp}}'s logistic analogue, or this
//' function's own uncorrected \eqn{r_i^2} meat) which does not correct for
//' leverage. HC2 is unbiased under homoskedasticity for balanced designs and
//' generally has better small-sample properties than HC0/HC1 when leverage is
//' uneven. Internally, this function first computes the (design-only) "setup"
//' quantities \code{bread}/\code{hat} via \code{ols_hc2_setup_cpp}, then calls
//' \code{ols_hc2_post_fit_precomputed_cpp}; callers who already have those
//' precomputed (e.g. across repeated resampling on the same fixed design) can
//' call the precomputed variant directly instead to skip recomputing the
//' \eqn{(X^\top X)^{-1}} bread and leverage each time.
//'
//' @param X_fit A numeric matrix of predictors, as used to fit the model.
//' @param y A numeric vector of responses.
//' @param coef_hat A numeric vector of fitted OLS coefficients \eqn{\hat\beta},
//'   same length and column order as \code{X_fit}.
//' @param j_treat 1-based column index of the treatment indicator in \code{X_fit}.
//' @return A list with components \code{beta_hat} (\eqn{\hat\beta_{j_{\mathrm{treat}}}}),
//'   \code{ssq_hat} (its HC2 variance), \code{se} (its HC2 standard error),
//'   \code{vcov} (the full \eqn{p \times p} HC2 covariance matrix), \code{std_err}
//'   (per-coefficient HC2 standard errors), and \code{z_vals} (per-coefficient
//'   Wald z-statistics, \eqn{\hat\beta_j / \widehat{\mathrm{SE}}(\hat\beta_j)}).
//' @references MacKinnon, J. G., and White, H. (1985). "Some Heteroskedasticity-Consistent
//'   Covariance Matrix Estimators with Improved Finite Sample Properties."
//'   \emph{Journal of Econometrics}, 29(3), 305-325,
//'   \doi{10.1016/0304-4076(85)90158-7}, for the HC2 estimator used here.
//' @keywords internal
// [[Rcpp::export]]
List ols_hc2_post_fit_cpp(const Eigen::Map<Eigen::MatrixXd>& X_fit, SEXP y, const Eigen::Map<Eigen::VectorXd>& coef_hat, int j_treat) {
	NumericVector y_r_coerced(y); Eigen::Map<const Eigen::VectorXd> y_vec_coerced(y_r_coerced.begin(), y_r_coerced.size());


  

  

  
  List setup = ols_hc2_setup_cpp(X_fit);
  return ols_hc2_post_fit_precomputed_cpp(
    X_fit,
    y,
    coef_hat,
    setup["bread"],
    setup["hat"],
    j_treat
  );
}

// [[Rcpp::export]]
List glm_sandwich_post_fit_cpp(const Eigen::Map<Eigen::MatrixXd>& X_fit, SEXP y, const Eigen::Map<Eigen::VectorXd>& coef_hat, const Eigen::Map<Eigen::VectorXd>& mu_hat, const Eigen::Map<Eigen::VectorXd>& working_weights, int j_treat) {
	NumericVector y_r_coerced(y); Eigen::Map<const Eigen::VectorXd> y_vec_coerced(y_r_coerced.begin(), y_r_coerced.size());


  

  

  

  

  
  const int n = X_fit.rows();
  const int p = X_fit.cols();
  if (y_vec_coerced.size() != n || coef_hat.size() != p || mu_hat.size() != n || working_weights.size() != n) {
    stop("dimension mismatch in glm_sandwich_post_fit_cpp");
  }
  if (!all_finite_vec(coef_hat) || !all_finite_vec(mu_hat) || !all_finite_vec(working_weights)) {
    stop("non-finite inputs");
  }

  for (int i = 0; i < n; ++i) {
    if (working_weights[i] <= 0.0) {
      stop("non-positive working weights");
    }
  }

  const Eigen::MatrixXd XtWX = weighted_crossprod(X_fit, working_weights);
  Eigen::LDLT<Eigen::MatrixXd> ldlt(XtWX);
  if (ldlt.info() != Eigen::Success) {
    stop("failed to factorize X'WX");
  }
  const Eigen::MatrixXd bread = ldlt.solve(Eigen::MatrixXd::Identity(p, p));
  if (ldlt.info() != Eigen::Success || !all_finite_mat(bread)) {
    stop("failed to invert X'WX");
  }

  const Eigen::VectorXd resid = y_vec_coerced - mu_hat;
  const Eigen::VectorXd resid_sq = resid.array().square().matrix();
  Eigen::MatrixXd meat = weighted_crossprod(X_fit, resid_sq);
  Eigen::MatrixXd vcov = bread * meat * bread;
  vcov = 0.5 * (vcov + vcov.transpose());
  return edi::to_rcpp_list(summarize_with_vcov(coef_hat, vcov, j_treat));
}

// [[Rcpp::export]]
List glm_cluster_sandwich_post_fit_cpp(const Eigen::Map<Eigen::MatrixXd>& X_fit, SEXP y, const Eigen::Map<Eigen::VectorXd>& coef_hat, const Eigen::Map<Eigen::VectorXd>& mu_hat, const Eigen::Map<Eigen::VectorXd>& working_weights, const IntegerVector& cluster_id, int j_treat) {
	NumericVector y_r_coerced(y); Eigen::Map<const Eigen::VectorXd> y_vec_coerced(y_r_coerced.begin(), y_r_coerced.size());


  

  

  

  

  
  const int n = X_fit.rows();
  const int p = X_fit.cols();
  if (y_vec_coerced.size() != n || coef_hat.size() != p || mu_hat.size() != n || working_weights.size() != n) {
    stop("dimension mismatch in glm_cluster_sandwich_post_fit_cpp");
  }
  if (!all_finite_vec(coef_hat) || !all_finite_vec(mu_hat) || !all_finite_vec(working_weights)) {
    stop("non-finite inputs");
  }

  for (int i = 0; i < n; ++i) {
    if (working_weights[i] <= 0.0) {
      stop("non-positive working weights");
    }
  }

  const Eigen::MatrixXd XtWX = weighted_crossprod(X_fit, working_weights);
  Eigen::LDLT<Eigen::MatrixXd> ldlt(XtWX);
  if (ldlt.info() != Eigen::Success) {
    stop("failed to factorize X'WX");
  }
  const Eigen::MatrixXd bread = ldlt.solve(Eigen::MatrixXd::Identity(p, p));
  if (ldlt.info() != Eigen::Success || !all_finite_mat(bread)) {
    stop("failed to invert X'WX");
  }

  const Eigen::VectorXd resid = y_vec_coerced - mu_hat;
  Eigen::MatrixXd meat = cluster_meat_robust(X_fit, resid, cluster_id);
  Eigen::MatrixXd vcov = bread * meat * bread;
  vcov = 0.5 * (vcov + vcov.transpose());
  return edi::to_rcpp_list(summarize_with_vcov(coef_hat, vcov, j_treat));
}
#endif // EDI_CORE_ONLY
