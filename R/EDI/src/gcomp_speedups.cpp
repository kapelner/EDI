// [[Rcpp::depends(RcppEigen)]]
#include "_helper_functions.h"
#include <unordered_map>
#include <utility>

using namespace Rcpp;

namespace {

inline double plogis_stable(double x) {
  if (x >= 0.0) {
    const double z = std::exp(-x);
    return 1.0 / (1.0 + z);
  }
  const double z = std::exp(x);
  return z / (1.0 + z);
}

// plogis_array is now the canonical version in _helper_functions_core.h
// (already in this file's include chain via _helper_functions.h) -- see
// its comment for why.

// Named cluster_meat_gcomp (not cluster_meat) because
// robust_post_fit_speedups.cpp's same-named function computes the same
// result via a different implementation strategy (lookup-table + vector of
// accumulators instead of a map keyed directly by cluster id) -- not
// unified, since picking one strategy for both call sites is a separate,
// out-of-scope performance decision. See unity_build_collision_audit.md.
Eigen::MatrixXd cluster_meat_gcomp(const Eigen::MatrixXd& X_fit,
                             const Eigen::VectorXd& resid,
                             const IntegerVector& cluster_id) {
  const int n = X_fit.rows();
  const int p = X_fit.cols();
  if (cluster_id.size() != n) {
    stop("dimension mismatch in cluster_meat");
  }

  Eigen::MatrixXd meat = Eigen::MatrixXd::Zero(p, p);
  std::unordered_map<int, Eigen::VectorXd> cluster_scores;
  cluster_scores.reserve(static_cast<std::size_t>(n));
  for (int i = 0; i < n; ++i) {
    const int id = cluster_id[i];
    auto it = cluster_scores.find(id);
    if (it == cluster_scores.end()) {
      it = cluster_scores.emplace(id, Eigen::VectorXd::Zero(p)).first;
    }
    it->second.noalias() += X_fit.row(i).transpose() * resid[i];
  }
  for (const auto& entry : cluster_scores) {
    const auto& score_g = entry.second;
    meat.noalias() += score_g * score_g.transpose();
  }
  return meat;
}

}  // namespace

//' Fast G-Computation (Standardization) Point Estimate for a Logit-Link Model (C++)
//'
//' Computes the \strong{G-computation} (regression standardization) point estimate
//' of the marginal treatment effect under a fitted logit-link model — logistic
//' regression for a binary outcome, or the algebraically identical fractional
//' logit / quasi-binomial model for a proportion outcome in \eqn{[0, 1]}, since
//' the standardization formula depends only on the fitted linear predictor and
//' link function, not the response's distributional assumptions. For each
//' subject \eqn{i} in the fitted sample, the fitted linear predictor is
//' decomposed into its treatment-free baseline \eqn{\eta_{\mathrm{base},i} =
//' x_i^\top\hat\beta - \hat\beta_{j_{\mathrm{treat}}}\, x_{i,j_{\mathrm{treat}}}}
//' and the two \strong{counterfactual} predictions
//' \eqn{\widehat{\Pr}(Y_i = 1 \mid \mathrm{do}(T=1)) = \mathrm{logit}^{-1}(\eta_{\mathrm{base},i}
//' + \hat\beta_{j_{\mathrm{treat}}})} and \eqn{\widehat{\Pr}(Y_i = 1 \mid \mathrm{do}(T=0)) =
//' \mathrm{logit}^{-1}(\eta_{\mathrm{base},i})} are computed by setting every
//' subject's treatment column to 1 (respectively 0) while leaving all other
//' covariates at their observed values — this is standard G-computation /
//' standardization: average the model-implied outcome over the empirical
//' covariate distribution under each counterfactual treatment assignment. The
//' two averages (\code{mean1}, \code{mean0}) and their difference (\code{md}, the
//' standardized average treatment effect on the risk-difference scale) are
//' returned.
//'
//' @param X_fit Numeric matrix of predictors used to fit the model, including an
//'   intercept column if the model has one.
//' @param coef_hat Numeric vector of fitted model coefficients \eqn{\hat\beta},
//'   same length and column order as \code{X_fit}.
//' @param j_treat 1-based column index of the treatment indicator in \code{X_fit}.
//' @return A list with elements \code{mean1} (standardized mean outcome under
//'   \eqn{T=1} for everyone), \code{mean0} (standardized mean outcome under \eqn{T=0}
//'   for everyone), and \code{md} (\code{mean1 - mean0}, the standardized risk
//'   difference).
//' @seealso \code{\link{gcomp_logistic_point_estimate_cpp}}, which computes the
//'   identical quantity (it delegates directly to this function) under the
//'   "logistic regression" framing.
//' @export
//' @keywords internal
// [[Rcpp::export]]
List gcomp_fractional_logit_point_estimate_cpp( const Eigen::Map<Eigen::MatrixXd>& X_fit,
		const Eigen::Map<Eigen::VectorXd>& coef_hat,
		int j_treat) {

  

  
  const int n = X_fit.rows();
  const int p = X_fit.cols();
  const int j_treat0 = j_treat - 1;

  if (j_treat0 < 0 || j_treat0 >= p) {
    stop("treatment column index is out of bounds");
  }

  Eigen::VectorXd eta = X_fit * coef_hat;
  Eigen::VectorXd eta_base = eta - coef_hat[j_treat0] * X_fit.col(j_treat0);

  Eigen::ArrayXd risk1_arr = plogis_array_safe((eta_base.array() + coef_hat[j_treat0]));
  Eigen::ArrayXd risk0_arr = plogis_array_safe(eta_base.array());

  double mean1 = risk1_arr.mean();
  double mean0 = risk0_arr.mean();

  return List::create(
    _["mean1"] = mean1,
    _["mean0"] = mean0,
    _["md"] = mean1 - mean0
  );
}

//' Fast G-Computation (Standardization) Point Estimate for Logistic Regression (C++)
//'
//' Computes the standardized (G-computation) marginal risk difference under a
//' fitted logistic regression model. This is a thin alias: it delegates directly
//' to \code{\link{gcomp_fractional_logit_point_estimate_cpp}} (see that page for
//' the full standardization formula and counterfactual-averaging methodology,
//' which is identical for logistic and fractional-logit/quasi-binomial models),
//' passing its arguments through unchanged.
//'
//' @param X_fit Numeric matrix of predictors used to fit the model, including an
//'   intercept column if the model has one.
//' @param coef_hat Numeric vector of fitted logistic regression coefficients
//'   \eqn{\hat\beta}, same length and column order as \code{X_fit}.
//' @param j_treat 1-based column index of the treatment indicator in \code{X_fit}.
//' @return A list with elements \code{mean1} (standardized mean risk under
//'   \eqn{T=1} for everyone), \code{mean0} (standardized mean risk under \eqn{T=0}
//'   for everyone), and \code{md} (\code{mean1 - mean0}, the standardized risk
//'   difference).
//' @seealso \code{\link{gcomp_fractional_logit_point_estimate_cpp}} for the full
//'   documentation of the underlying computation.
//' @export
//' @keywords internal
// [[Rcpp::export]]
List gcomp_logistic_point_estimate_cpp( const Eigen::Map<Eigen::MatrixXd>& X_fit,
		const Eigen::Map<Eigen::VectorXd>& coef_hat,
		int j_treat) {

  

  
  return gcomp_fractional_logit_point_estimate_cpp(X_fit, coef_hat, j_treat);
}

namespace {

struct LogisticPostFitResult {
  Eigen::MatrixXd vcov;
  Eigen::VectorXd std_err;
  Eigen::VectorXd z_vals;
  double risk1;
  double risk0;
  double rd;
  double se_rd;
  double log_rr;
  double rr;
  double se_log_rr;
};

LogisticPostFitResult compute_gcomp_logistic_post_fit(const Eigen::Map<Eigen::MatrixXd>& X_fit,
                                                       const Eigen::Map<Eigen::VectorXd>& y,
                                                       const Eigen::Map<Eigen::VectorXd>& coef_hat,
                                                       const Eigen::Map<Eigen::VectorXd>& mu_hat,
                                                       int j_treat) {
  const int n = X_fit.rows();
  const int p = X_fit.cols();
  const int j_treat0 = j_treat - 1;

  if (j_treat0 < 0 || j_treat0 >= p) {
    stop("treatment column index is out of bounds");
  }
  if (y.size() != n || coef_hat.size() != p || mu_hat.size() != n) {
    stop("dimension mismatch in gcomp_logistic_post_fit_cpp");
  }

  for (int i = 0; i < n; ++i) {
    const double mu_i = mu_hat[i];
    if (!R_finite(mu_i) || mu_i <= 0.0 || mu_i >= 1.0) {
      stop("non-finite or boundary fitted values");
    }
  }
  const Eigen::VectorXd W = (mu_hat.array() * (1.0 - mu_hat.array())).matrix();

  const Eigen::MatrixXd XtWX = weighted_crossprod(X_fit, W);
  Eigen::LDLT<Eigen::MatrixXd> ldlt(XtWX);
  if (ldlt.info() != Eigen::Success) {
    stop("failed to factorize X'WX");
  }

  const Eigen::MatrixXd bread = ldlt.solve(Eigen::MatrixXd::Identity(p, p));
  if (ldlt.info() != Eigen::Success) {
    stop("failed to invert X'WX");
  }

  const Eigen::VectorXd score_resid = y - mu_hat;
  const Eigen::VectorXd resid_sq = score_resid.array().square().matrix();
  Eigen::MatrixXd meat = weighted_crossprod(X_fit, resid_sq);
  Eigen::MatrixXd vcov_robust = bread * meat * bread;
  vcov_robust = 0.5 * (vcov_robust + vcov_robust.transpose());

  for (int j = 0; j < p; ++j) {
    for (int k = 0; k < p; ++k) {
      if (!R_finite(vcov_robust(j, k))) {
        stop("non-finite robust covariance");
      }
    }
  }

  const double ssq_treat = vcov_robust(j_treat0, j_treat0);
  if (!R_finite(ssq_treat) || ssq_treat <= 0.0) {
    stop("non-positive treatment variance");
  }

  const Eigen::VectorXd eta = X_fit * coef_hat;
  const Eigen::VectorXd eta_base = eta - coef_hat[j_treat0] * X_fit.col(j_treat0);

  const Eigen::ArrayXd risk1_arr = plogis_array(eta_base.array() + coef_hat[j_treat0]);
  const Eigen::ArrayXd risk0_arr = plogis_array(eta_base.array());
  const Eigen::VectorXd risk1_i = risk1_arr.matrix();
  const Eigen::VectorXd risk0_i = risk0_arr.matrix();

  const double risk1 = risk1_i.mean();
  const double risk0 = risk0_i.mean();

  const double inv_n = 1.0 / static_cast<double>(n);
  const Eigen::VectorXd wt1 = (risk1_arr * (1.0 - risk1_arr) * inv_n).matrix();
  const Eigen::VectorXd wt0 = (risk0_arr * (1.0 - risk0_arr) * inv_n).matrix();
  Eigen::VectorXd grad1 = X_fit.transpose() * wt1;
  Eigen::VectorXd grad0 = X_fit.transpose() * wt0;
  grad1[j_treat0] = wt1.sum();
  grad0[j_treat0] = 0.0;

  const double rd = risk1 - risk0;
  const Eigen::VectorXd grad_rd = grad1 - grad0;
  const Eigen::VectorXd bread_grad_rd = ldlt.solve(grad_rd);
  const double var_rd = (bread_grad_rd.transpose() * meat * bread_grad_rd)(0, 0);
  const double se_rd = (R_finite(var_rd) && var_rd >= 0.0) ? std::sqrt(var_rd) : NA_REAL;

  double log_rr = NA_REAL;
  double rr = NA_REAL;
  double se_log_rr = NA_REAL;
  if (risk1 > 0.0 && risk0 > 0.0) {
    log_rr = std::log(risk1) - std::log(risk0);
    rr = std::exp(log_rr);
    const Eigen::VectorXd grad_log_rr = grad1 / risk1 - grad0 / risk0;
    const Eigen::VectorXd bread_grad_log_rr = ldlt.solve(grad_log_rr);
    const double var_log_rr = (bread_grad_log_rr.transpose() * meat * bread_grad_log_rr)(0, 0);
    if (R_finite(var_log_rr) && var_log_rr >= 0.0) {
      se_log_rr = std::sqrt(var_log_rr);
    }
  }

  Eigen::VectorXd std_err(p);
  Eigen::VectorXd z_vals(p);
  for (int j = 0; j < p; ++j) {
    const double var_j = vcov_robust(j, j);
    std_err[j] = (R_finite(var_j) && var_j >= 0.0) ? std::sqrt(var_j) : NA_REAL;
    z_vals[j] = (R_finite(std_err[j]) && std_err[j] > 0.0) ? coef_hat[j] / std_err[j] : NA_REAL;
  }

  return {
    std::move(vcov_robust),
    std::move(std_err),
    std::move(z_vals),
    risk1,
    risk0,
    rd,
    se_rd,
    log_rr,
    rr,
    se_log_rr
  };
}

}  // namespace

//' Fast G-Computation Post-Fit Inference for Logistic Regression (C++)
//'
//' Given an already-fitted logistic regression, computes a Huber-White/Eicker
//' sandwich (heteroskedasticity-robust, "HC0") coefficient covariance matrix and,
//' by the delta method, standard errors for the G-computed standardized risk
//' difference and log risk ratio (see
//' \code{\link{gcomp_logistic_point_estimate_cpp}} for the standardization point
//' estimates this builds inference around). The sandwich covariance is
//' \eqn{\widehat{\mathrm{Var}}(\hat\beta) = B\,M\,B}, with "bread"
//' \eqn{B = (X^\top W X)^{-1}} (\eqn{W = \mathrm{diag}(\hat\mu_i(1-\hat\mu_i))}, the
//' model-based Fisher information weights) and "meat" \eqn{M = X^\top
//' \mathrm{diag}((y_i - \hat\mu_i)^2) X} (the empirical score outer-product,
//' making this robust to model misspecification, not just relying on the
//' working Bernoulli variance). The risk-difference standard error is obtained
//' by propagating this sandwich covariance through the standardized risks'
//' gradients with respect to \eqn{\beta} (\eqn{\nabla_\beta \bar{\mathrm{risk}}_1 -
//' \nabla_\beta \bar{\mathrm{risk}}_0}, each a population-averaged logistic-derivative
//' weighted design-matrix sum, with the treatment column's gradient entry replaced
//' by the sum of the standardized-risk derivative directly since every subject's
//' treatment indicator is held fixed at 1 or 0 in the counterfactual averages);
//' the log risk ratio's standard error is obtained the same way via the gradient
//' of \eqn{\log(\overline{\mathrm{risk}}_1) - \log(\overline{\mathrm{risk}}_0)}, and is only
//' computed (non-\code{NA}) when both standardized risks are strictly positive.
//' Aborts with an R error (rather than returning \code{NA}s) if \code{mu_hat}
//' contains non-finite or boundary (0 or 1) values, if the weighted design
//' crossproduct \eqn{X^\top W X} is not invertible, if the sandwich covariance
//' comes out non-finite anywhere, or if the treatment coefficient's variance is
//' non-positive.
//'
//' @param X_fit Numeric matrix of predictors used to fit the model, including an
//'   intercept column if the model has one.
//' @param y The observed binary (0/1) response used to fit the model.
//' @param coef_hat Numeric vector of fitted logistic regression coefficients
//'   \eqn{\hat\beta}, same length and column order as \code{X_fit}.
//' @param mu_hat Numeric vector of fitted probabilities \eqn{\hat\mu_i =
//'   \mathrm{logit}^{-1}(x_i^\top\hat\beta)}, one per row of \code{X_fit}.
//' @param j_treat 1-based column index of the treatment indicator in \code{X_fit}.
//' @return A list with components \code{vcov} (the \eqn{p \times p} sandwich
//'   covariance matrix), \code{std_err} and \code{z_vals} (per-coefficient standard
//'   errors and Wald z-statistics, \code{NA} for any coefficient with non-finite or
//'   non-positive variance), \code{risk1}/\code{risk0} (the standardized mean risks
//'   under \eqn{T=1}/\eqn{T=0} for everyone), \code{rd} (\code{risk1 - risk0}) and
//'   \code{se_rd} (its delta-method standard error), and \code{log_rr}/\code{rr}/
//'   \code{se_log_rr} (the log risk ratio, risk ratio, and the log risk ratio's
//'   delta-method standard error — all \code{NA} if either standardized risk is
//'   not strictly positive).
//' @seealso \code{\link{gcomp_logistic_point_estimate_cpp}} for the point-estimate
//'   computation this function's variances are built around;
//'   \code{gcomp_fractional_logit_post_fit_cpp()} for the analogous
//'   fractional-logit/quasi-binomial post-fit inference.
//' @export
//' @keywords internal
// [[Rcpp::export]]
List gcomp_logistic_post_fit_cpp(const Eigen::Map<Eigen::MatrixXd>& X_fit, SEXP y, const Eigen::Map<Eigen::VectorXd>& coef_hat, const Eigen::Map<Eigen::VectorXd>& mu_hat, int j_treat) {
	NumericVector y_r_coerced(y); Eigen::Map<Eigen::VectorXd> y_vec_coerced(y_r_coerced.begin(), y_r_coerced.size());

  LogisticPostFitResult result = compute_gcomp_logistic_post_fit(
    X_fit, y_vec_coerced, coef_hat, mu_hat, j_treat
  );
  return List::create(
    _["vcov"] = result.vcov,
    _["std_err"] = result.std_err,
    _["z_vals"] = result.z_vals,
    _["risk1"] = result.risk1,
    _["risk0"] = result.risk0,
    _["rd"] = result.rd,
    _["se_rd"] = result.se_rd,
    _["log_rr"] = result.log_rr,
    _["rr"] = result.rr,
    _["se_log_rr"] = result.se_log_rr
  );
}

// [[Rcpp::export]]
List gcomp_fractional_logit_post_fit_cpp(const Eigen::Map<Eigen::MatrixXd>& X_fit, SEXP y, const Eigen::Map<Eigen::VectorXd>& coef_hat, const Eigen::Map<Eigen::VectorXd>& mu_hat, int j_treat) {
	NumericVector y_r_coerced(y); Eigen::Map<Eigen::VectorXd> y_vec_coerced(y_r_coerced.begin(), y_r_coerced.size());

  LogisticPostFitResult result = compute_gcomp_logistic_post_fit(
    X_fit, y_vec_coerced, coef_hat, mu_hat, j_treat
  );
  return List::create(
    _["vcov"] = result.vcov,
    _["std_err"] = result.std_err,
    _["z_vals"] = result.z_vals,
    _["mean1"] = result.risk1,
    _["mean0"] = result.risk0,
    _["md"] = result.rd,
    _["se_md"] = result.se_rd
  );
}

// [[Rcpp::export]]
List gcomp_logistic_cluster_post_fit_cpp(const Eigen::Map<Eigen::MatrixXd>& X_fit, SEXP y, const Eigen::Map<Eigen::VectorXd>& coef_hat, const Eigen::Map<Eigen::VectorXd>& mu_hat, const IntegerVector& cluster_id, int j_treat) {
	NumericVector y_r_coerced(y); Eigen::Map<const Eigen::VectorXd> y_vec_coerced(y_r_coerced.begin(), y_r_coerced.size());


  

  

  

  
  const int n = X_fit.rows();
  const int p = X_fit.cols();
  const int j_treat0 = j_treat - 1;

  if (j_treat0 < 0 || j_treat0 >= p) {
    stop("treatment column index is out of bounds");
  }
  if (y_vec_coerced.size() != n || coef_hat.size() != p || mu_hat.size() != n) {
    stop("dimension mismatch in gcomp_logistic_cluster_post_fit_cpp");
  }

  for (int i = 0; i < n; ++i) {
    const double mu_i = mu_hat[i];
    if (!R_finite(mu_i) || mu_i <= 0.0 || mu_i >= 1.0) {
      stop("non-finite or boundary fitted values");
    }
  }
  const Eigen::VectorXd W = (mu_hat.array() * (1.0 - mu_hat.array())).matrix();

  const Eigen::MatrixXd XtWX = weighted_crossprod(X_fit, W);
  Eigen::LDLT<Eigen::MatrixXd> ldlt(XtWX);
  if (ldlt.info() != Eigen::Success) {
    stop("failed to factorize X'WX");
  }

  const Eigen::MatrixXd bread = ldlt.solve(Eigen::MatrixXd::Identity(p, p));
  if (ldlt.info() != Eigen::Success) {
    stop("failed to invert X'WX");
  }

  const Eigen::VectorXd score_resid = y_vec_coerced - mu_hat;
  Eigen::MatrixXd meat = cluster_meat_gcomp(X_fit, score_resid, cluster_id);
  Eigen::MatrixXd vcov_robust = bread * meat * bread;
  vcov_robust = 0.5 * (vcov_robust + vcov_robust.transpose());

  for (int j = 0; j < p; ++j) {
    for (int k = 0; k < p; ++k) {
      if (!R_finite(vcov_robust(j, k))) {
        stop("non-finite robust covariance");
      }
    }
  }

  const double ssq_treat = vcov_robust(j_treat0, j_treat0);
  if (!R_finite(ssq_treat) || ssq_treat <= 0.0) {
    stop("non-positive treatment variance");
  }

  const Eigen::VectorXd eta = X_fit * coef_hat;
  const Eigen::VectorXd eta_base = eta - coef_hat[j_treat0] * X_fit.col(j_treat0);

  const Eigen::ArrayXd risk1_arr = plogis_array(eta_base.array() + coef_hat[j_treat0]);
  const Eigen::ArrayXd risk0_arr = plogis_array(eta_base.array());
  const Eigen::VectorXd risk1_i = risk1_arr.matrix();
  const Eigen::VectorXd risk0_i = risk0_arr.matrix();

  const double risk1 = risk1_i.mean();
  const double risk0 = risk0_i.mean();

  const double inv_n = 1.0 / static_cast<double>(n);
  const Eigen::VectorXd wt1 = (risk1_arr * (1.0 - risk1_arr) * inv_n).matrix();
  const Eigen::VectorXd wt0 = (risk0_arr * (1.0 - risk0_arr) * inv_n).matrix();
  Eigen::VectorXd grad1 = X_fit.transpose() * wt1;
  Eigen::VectorXd grad0 = X_fit.transpose() * wt0;
  grad1[j_treat0] = wt1.sum();
  grad0[j_treat0] = 0.0;

  const double rd = risk1 - risk0;
  const Eigen::VectorXd grad_rd = grad1 - grad0;
  const Eigen::VectorXd bread_grad_rd = ldlt.solve(grad_rd);
  const double var_rd = (bread_grad_rd.transpose() * meat * bread_grad_rd)(0, 0);
  const double se_rd = (R_finite(var_rd) && var_rd >= 0.0) ? std::sqrt(var_rd) : NA_REAL;

  double log_rr = NA_REAL;
  double rr = NA_REAL;
  double se_log_rr = NA_REAL;
  if (risk1 > 0.0 && risk0 > 0.0) {
    log_rr = std::log(risk1) - std::log(risk0);
    rr = std::exp(log_rr);
    const Eigen::VectorXd grad_log_rr = grad1 / risk1 - grad0 / risk0;
    const Eigen::VectorXd bread_grad_log_rr = ldlt.solve(grad_log_rr);
    const double var_log_rr = (bread_grad_log_rr.transpose() * meat * bread_grad_log_rr)(0, 0);
    if (R_finite(var_log_rr) && var_log_rr >= 0.0) {
      se_log_rr = std::sqrt(var_log_rr);
    }
  }

  Eigen::VectorXd std_err(p);
  Eigen::VectorXd z_vals(p);
  for (int j = 0; j < p; ++j) {
    const double var_j = vcov_robust(j, j);
    std_err[j] = (R_finite(var_j) && var_j >= 0.0) ? std::sqrt(var_j) : NA_REAL;
    z_vals[j] = (R_finite(std_err[j]) && std_err[j] > 0.0) ? coef_hat[j] / std_err[j] : NA_REAL;
  }

  return List::create(
    _["vcov"] = vcov_robust,
    _["std_err"] = std_err,
    _["z_vals"] = z_vals,
    _["risk1"] = risk1,
    _["risk0"] = risk0,
    _["rd"] = rd,
    _["se_rd"] = se_rd,
    _["log_rr"] = log_rr,
    _["rr"] = rr,
    _["se_log_rr"] = se_log_rr
  );
}

//' Fast G-Computation (Standardization) Point Estimate for a Proportional-Odds Ordinal Model (C++)
//'
//' Computes the standardized (G-computation) marginal difference in
//' \strong{expected ordinal category score} under a fitted proportional-odds
//' (cumulative logit) model for a \eqn{K}-category ordinal outcome coded
//' \eqn{1, \ldots, K}: \eqn{\mathrm{logit}\,\Pr(Y_i \le k \mid x_i) = \alpha_k -
//' x_i^\top\beta}, \eqn{k = 1, \ldots, K-1}. For each subject \eqn{i}, the fitted
//' linear predictor is decomposed into its treatment-free baseline
//' \eqn{\eta_{\mathrm{base},i} = x_i^\top\hat\beta - \hat\beta_{j_{\mathrm{treat}}}\,
//' x_{i,j_{\mathrm{treat}}}} and the counterfactual predictors \eqn{\eta_{1,i} =
//' \eta_{\mathrm{base},i} + \hat\beta_{j_{\mathrm{treat}}}} (treatment column set
//' to 1 for everyone) and \eqn{\eta_{0,i} = \eta_{\mathrm{base},i}} (set to 0 for
//' everyone). The subject-level expected category score under each counterfactual
//' is recovered from the fitted cumulative probabilities via the identity
//' \eqn{E[Y_i] = \sum_{k=1}^K k\,\Pr(Y_i=k) = 1 + \sum_{k=1}^{K-1} \Pr(Y_i > k) = 1 +
//' \sum_{k=1}^{K-1} \left(1 - \mathrm{logit}^{-1}(\hat\alpha_k - \eta_i)\right)},
//' and the two population-averaged expected scores (\code{mean1}, \code{mean0})
//' and their difference (\code{md}) are returned — the ordinal analogue of
//' \code{\link{gcomp_logistic_point_estimate_cpp}}'s risk difference. Unlike
//' \code{\link{gcomp_logistic_post_fit_cpp}}, this function computes
//' \strong{point estimates only}; no sandwich covariance, standard errors, or
//' inferential quantities are returned despite the \verb{_post_fit} name.
//'
//' @param X_fit Numeric matrix of predictors used to fit the model, including an
//'   intercept column if the model has one (conventionally absorbed into the
//'   thresholds \code{alpha_hat} rather than \code{X_fit} for a proportional-odds
//'   model, but this function does not enforce that).
//' @param coef_hat Numeric vector of fitted proportional-odds regression coefficients
//'   \eqn{\hat\beta}, same length and column order as \code{X_fit}.
//' @param alpha_hat Numeric vector of the \eqn{K-1} fitted, increasing category
//'   thresholds \eqn{\hat\alpha_1, \ldots, \hat\alpha_{K-1}}.
//' @param j_treat 1-based column index of the treatment indicator in \code{X_fit}.
//' @return A list with elements \code{mean1} (standardized expected category score
//'   under \eqn{T=1} for everyone), \code{mean0} (standardized expected category score
//'   under \eqn{T=0} for everyone), and \code{md} (\code{mean1 - mean0}).
//' @seealso \code{\link{gcomp_logistic_point_estimate_cpp}} for the binary-outcome
//'   analogue; \code{\link{gcomp_logistic_post_fit_cpp}} for an example of the
//'   sandwich-variance inference this function does \strong{not} provide.
//' @export
//' @keywords internal
// [[Rcpp::export]]
List gcomp_ordinal_proportional_odds_post_fit_cpp( const Eigen::Map<Eigen::MatrixXd>& X_fit,
		const Eigen::Map<Eigen::VectorXd>& coef_hat,
		const Eigen::Map<Eigen::VectorXd>& alpha_hat,
		int j_treat) {

  

  

  
  const int n = X_fit.rows();
  const int K_minus_1 = alpha_hat.size();
  const int j_treat0 = j_treat - 1;

  Eigen::VectorXd eta_base = X_fit * coef_hat - coef_hat[j_treat0] * X_fit.col(j_treat0);
  Eigen::VectorXd eta1 = eta_base.array() + coef_hat[j_treat0];
  Eigen::VectorXd eta0 = eta_base;

  auto compute_mean = [&](const Eigen::VectorXd& eta_vec) {
    double sum = 0.0;
    for (int i = 0; i < n; ++i) {
      double m = 1.0;
      for (int k = 0; k < K_minus_1; ++k) {
        m += 1.0 - plogis_stable(alpha_hat[k] - eta_vec[i]);
      }
      sum += m;
    }
    return sum / n;
  };

  double mean1 = compute_mean(eta1);
  double mean0 = compute_mean(eta0);

  return List::create(
    _["mean1"] = mean1,
    _["mean0"] = mean0,
    _["md"] = mean1 - mean0
  );
}
