#ifdef EDI_CORE_ONLY
#include "_helper_functions_core.h"
#else
#include "_helper_functions.h"
#include "result_map_rcpp.h"
#include <RcppEigen.h>
#endif
#include <cmath>
#include <algorithm>
#include <stdexcept>
#include <limits>
#ifdef _OPENMP
#include <omp.h>
#endif

#ifndef EDI_CORE_ONLY
using namespace Rcpp;
#endif

// --- Weight Functions ---

// Huber weight function
double huber_w(double r, double c) {
    double abs_r = std::abs(r);
    if (abs_r <= c) return 1.0;
    return c / abs_r;
}

// Tukey's Bisquare (Biweight) weight function
double bisquare_w(double r, double c) {
    double abs_r = std::abs(r);
    if (abs_r <= c) {
        double tmp = 1.0 - (r / c) * (r / c);
        return tmp * tmp;
    }
    return 0.0;
}

// --- Internal IRLS Logic ---

struct RobustModelResult {
    Eigen::VectorXd b;
    Eigen::VectorXd w;
    Eigen::MatrixXd XtWX;
    Eigen::MatrixXd X_free;
    double XtX_inv_diag_j;
    double scale;
    int num_iter;
    bool converged;
    bool hit_iteration_cap;
    double ssq_b_j;
    // Fallback-path-only (optimizer_diagnostics_report.md TODO-1): minimum
    // eigenvalue of the weighted-crossprod information at the returned b,
    // computed only when !converged. NaN when not computed.
    double min_eigenvalue_information;

    RobustModelResult() : XtX_inv_diag_j(std::numeric_limits<double>::quiet_NaN()), scale(std::numeric_limits<double>::quiet_NaN()), num_iter(0), converged(false), hit_iteration_cap(false), ssq_b_j(std::numeric_limits<double>::quiet_NaN()), min_eigenvalue_information(std::numeric_limits<double>::quiet_NaN()) {}
};

RobustModelResult fast_robust_regression_internal(
    const Eigen::Ref<const Eigen::MatrixXd>& X,
    const Eigen::Ref<const Eigen::VectorXd>& y,
    std::optional<Eigen::VectorXd> warm_start_beta = std::nullopt,
    bool smart_cold_start = true,
    std::string method = "MM",
    double c = 1.345, // Huber constant
    double c_bisquare = 4.685, // Bisquare constant
    int maxit = 50,
    double tol = 1e-7,
    double scale_est = -1.0, // If negative, compute MAD
    std::optional<Eigen::VectorXi> fixed_idx = std::nullopt,
    std::optional<Eigen::VectorXd> fixed_values = std::nullopt,
    std::optional<Eigen::VectorXd> warm_start_weights = std::nullopt,
    std::optional<Eigen::MatrixXd> warm_start_fisher_info = std::nullopt,
    bool estimate_only = false,
    int variance_j = 0
) {
    if (method != "M" && method != "MM") {
        throw std::invalid_argument("method must be \"M\" (Huber) or \"MM\", got \"" + method + "\"");
    }
    int n = X.rows();
    int p = X.cols();
    // Non-finite input used to flow through the IRLS (Eigen QR / MAD / weights)
    // and come back as a 0 coefficient, which R callers could not tell from a
    // genuine estimate (release_v1_0_5.md TODO-131: NA KK pair differences gave
    // an all-zero BRT null). Refuse it instead. Callers inside OpenMP regions
    // (compute_robust_rand_bootstrap_parallel_cpp) must pre-check and skip, since
    // an exception escaping a parallel region terminates the process.
    if (!X.allFinite() || !y.allFinite()) {
        throw std::invalid_argument("fast_robust_regression: X and y must be finite (non-finite input is nonestimable)");
    }
    require_length(warm_start_beta, p, "warm_start_beta");
    require_length(warm_start_weights, n, "warm_start_weights");
    require_square_matrix(warm_start_fisher_info, p, "warm_start_fisher_info");
    FixedParamSpec fixed_spec = make_fixed_param_spec(p, fixed_idx, fixed_values);
    const int p_free = fixed_spec.free_idx.size();
    Eigen::MatrixXd X_free(n, p_free);
    for (int j = 0; j < p_free; ++j) X_free.col(j) = X.col(fixed_spec.free_idx[j]);
    Eigen::VectorXd y_adj = y;
    for (int j = 0; j < fixed_spec.fixed_idx.size(); ++j) {
        y_adj.noalias() -= X.col(fixed_spec.fixed_idx[j]) * fixed_spec.fixed_values[j];
    }
    RobustModelResult res;
    res.X_free = X_free;
    int free_variance_j = -1;
    if (variance_j > 0) {
        const int variance_j0 = variance_j - 1;
        for (int jj = 0; jj < fixed_spec.free_idx.size(); ++jj) {
            if (fixed_spec.free_idx[jj] == variance_j0) {
                free_variance_j = jj;
                break;
            }
        }
    }

    // 1. Initial estimate
    Eigen::VectorXd b_free;
    if (warm_start_beta.has_value()) {
        Eigen::VectorXd b_start = apply_fixed_values(*warm_start_beta, fixed_spec);
        b_free = subset_vector(b_start, fixed_spec.free_idx);
    } else if (smart_cold_start) {
        Eigen::ColPivHouseholderQR<Eigen::MatrixXd> qr(X_free);
        b_free = qr.solve(y_adj);
        if (!estimate_only && free_variance_j >= 0) {
            Eigen::MatrixXd R = Eigen::MatrixXd::Zero(p_free, p_free);
            R.triangularView<Eigen::Upper>() =
                qr.matrixR().topLeftCorner(p_free, p_free).template triangularView<Eigen::Upper>();
            Eigen::MatrixXd RtR = R.transpose() * R;
            Eigen::VectorXd e_orig = Eigen::VectorXd::Unit(p_free, free_variance_j);
            Eigen::VectorXd e_piv = qr.colsPermutation().transpose() * e_orig;
            Eigen::LDLT<Eigen::MatrixXd> ldlt(RtR);
            if (ldlt.info() == Eigen::Success) {
                Eigen::VectorXd z = ldlt.solve(e_piv);
                if (z.allFinite()) {
                    res.XtX_inv_diag_j = e_piv.dot(z);
                }
            }
        }
    } else {
        b_free = Eigen::VectorXd::Zero(p_free);
    }
    res.b = Eigen::VectorXd::Zero(p);
    for (int j = 0; j < p_free; ++j) res.b[fixed_spec.free_idx[j]] = b_free[j];
    for (int j = 0; j < fixed_spec.fixed_idx.size(); ++j) res.b[fixed_spec.fixed_idx[j]] = fixed_spec.fixed_values[j];

    Eigen::VectorXd r = y - X * res.b;
    
    // 2. Scale estimation (MAD of residuals, median(|r|) / 0.6745, as MASS::rlm).
    // "M" re-estimates it from the current residuals at the top of every IRLS
    // iteration, exactly like MASS::rlm(method = "M", scale.est = "MAD"); "MM"
    // keeps it fixed at the start value (v1.0.6-TODO-15).
    auto mad_scale = [n](const Eigen::VectorXd& resid) {
        std::vector<double> abs_r(n);
        for (int i = 0; i < n; ++i) abs_r[i] = std::abs(resid[i]);
        double median_abs_r;
        if (n < 512) {
            // Full sorting is faster for small vectors because selection has higher fixed overhead.
            std::sort(abs_r.begin(), abs_r.end());
            median_abs_r = (n % 2 == 0) ? (abs_r[n / 2 - 1] + abs_r[n / 2]) / 2.0 : abs_r[n / 2];
        } else {
            const auto upper_mid = abs_r.begin() + n / 2;
            std::nth_element(abs_r.begin(), upper_mid, abs_r.end());
            median_abs_r = *upper_mid;
            if (n % 2 == 0) {
                const double lower_mid = *std::max_element(abs_r.begin(), upper_mid);
                median_abs_r = (lower_mid + median_abs_r) / 2.0;
            }
        }
        return median_abs_r / 0.6745;
    };
    const bool update_scale_each_iter = (method == "M") && (scale_est < 0);
    if (scale_est < 0) {
        res.scale = mad_scale(r);
    } else {
        res.scale = scale_est;
    }

    // "MM" (fixed scale) floors the scale so the weights never divide by zero.
    // "M" leaves the start scale unclamped so the exact-fit stop at the top of
    // iteration 1 can fire: with a start whose MAD is 0, MASS::rlm returns the
    // start and reports convergence, and so must this loop (v1.0.6-TODO-172).
    // A tiny positive MAD is used as is, as rlm does and as later iterations do.
    if (!update_scale_each_iter && res.scale < 1e-10) res.scale = 1e-10;

    // 3. IRLS loop
    res.w = Eigen::VectorXd::Ones(n);
    Eigen::VectorXd b_old = b_free;
    bool numerical_failure = false;
    // Hoisted out of the loop (was loop-local) so the last iteration's value
    // survives to the fallback-eigenvalue diagnostic after the loop
    // (optimizer_diagnostics_report.md TODO-1).
    Eigen::MatrixXd XtWX;

    for (int iter = 1; iter <= maxit; ++iter) {
        edi_check_R_user_interrupt_every(iter);
        res.num_iter = iter;
        if (update_scale_each_iter && iter > 1) {
            res.scale = mad_scale(r);
        }
        if (update_scale_each_iter && res.scale <= 0.0) {
            // Exact fit (MAD 0): MASS::rlm stops here, returns the current
            // coefficients and reports convergence. At iteration 1 no WLS step
            // has run yet, so the information matrix is built from the current
            // weights (all 1, as rlm's returned w) (v1.0.6-TODO-172).
            res.scale = 1e-10;
            res.converged = true;
            if (!estimate_only) {
                if (XtWX.rows() == 0) XtWX = weighted_crossprod(X_free, res.w);
                res.XtWX = expand_free_covariance(p, fixed_spec, XtWX, false);
            }
            break;
        }
        
        // Update weights
        if (iter == 1 && warm_start_weights.has_value()) {
            const Eigen::VectorXd& ww = *warm_start_weights;
            if (ww.size() != n) throw std::invalid_argument("warm_start_weights must have length equal to nrow(X)");
            res.w = ww;
        } else {
            // Fused, allocation-free weight update (same per-element arithmetic
            // as the former u / abs_u / tmp array temporaries).
            const double scale_i = res.scale;
            const double* rp = r.data();
            double* wp = res.w.data();
            if (method == "M") {
                for (int i = 0; i < n; ++i) {
                    const double abs_u = std::abs(rp[i] / scale_i);
                    wp[i] = (abs_u <= c) ? 1.0 : c / abs_u;
                }
            } else {
                for (int i = 0; i < n; ++i) {
                    const double u = rp[i] / scale_i;
                    const double us = u / c_bisquare;
                    const double t = 1.0 - us * us;
                    wp[i] = (std::abs(u) <= c_bisquare) ? t * t : 0.0;
                }
            }
        }

        // Solve Weighted Least Squares
        if (iter == 1 && warm_start_fisher_info.has_value()) {
            const Eigen::MatrixXd& info_full = *warm_start_fisher_info;
            if (info_full.rows() != p || info_full.cols() != p) throw std::invalid_argument("warm_start_fisher_info must be a p x p matrix");
            XtWX = subset_matrix(info_full, fixed_spec.free_idx, fixed_spec.free_idx);
        } else {
            XtWX = weighted_crossprod(X_free, res.w);
        }
        Eigen::VectorXd XtWy = weighted_crossprod_rhs(X_free, res.w, y_adj);
        
        Eigen::LDLT<Eigen::MatrixXd> ldlt(XtWX);
        if (ldlt.info() != Eigen::Success) { numerical_failure = true; break; } // Numerical failure

        b_free = ldlt.solve(XtWy);
        for (int j = 0; j < p_free; ++j) res.b[fixed_spec.free_idx[j]] = b_free[j];
        Eigen::VectorXd r_old;
        if (update_scale_each_iter) r_old = r;
        r = y - X * res.b;

        // Check convergence. "M" uses MASS::rlm's test.vec = "resid" criterion
        // (relative change in the residual vector <= tol, rlm's `acc`), so that
        // with the same start, scale update and tolerance it stops on the same
        // iteration as rlm (v1.0.6-TODO-15); "MM" keeps the relative
        // coefficient-change criterion.
        const bool conv_now = update_scale_each_iter
            ? std::sqrt((r_old - r).squaredNorm() / std::max(1e-20, r_old.squaredNorm())) <= tol
            : (b_free - b_old).norm() / (b_free.norm() + 1e-10) < tol;
        if (conv_now) {
            res.converged = true;
            if (!estimate_only) res.XtWX = expand_free_covariance(p, fixed_spec, XtWX, false);
            break;
        }
        b_old = b_free;
    }

    // NOT redefined to gradient-norm-based (optimizer_diagnostics_report.md
    // TODO-4): this IRLS loop is a fixed-point iteration on reweighted least
    // squares, not a gradient-based optimizer. Its stopping rules are "M": the
    // exact-fit stop (MAD scale 0) or MASS::rlm's relative residual-vector
    // change <= tol; "MM": relative coefficient change < tol. There is no
    // already-computed M-estimator score/gradient here to reuse "for free"
    // (TODO-1's threading principle), and fabricating one would be new
    // computation, not a diagnostics-layer exposure. `hit_iteration_cap` is
    // still meaningful without touching `converged`'s definition: TRUE iff the
    // loop ran out of `maxit` iterations without either converging (by any
    // rule above) or hitting the numerical-failure exit above.
    res.hit_iteration_cap = !res.converged && !numerical_failure;
    // Reuses XtWX (free-parameter-space, last iteration's value) -- no new
    // computation. Independent of the convergence-criterion decision above:
    // this diagnostic only needs a curvature/information matrix, which XtWX
    // legitimately is regardless of what stopping rule produced it
    // (optimizer_diagnostics_report.md TODO-1).

    return res;
}

// Post-fit pieces of the R export fast_robust_regression_cpp that are not
// estimate_only: fills res.XtWX when the IRLS loop stopped before building it,
// and returns the sandwich variance of coefficient j (1-based), or nullopt
// (R: NA) when j indexes a fixed coefficient or the fit neither converged nor
// exhausted maxit. Shared with the Python binding
// (python/cpp/bindings_continuous.cpp) so both return the same ssq_b_j and
// fisher_information (audit decision rpy-parity-dd699435e).
std::optional<double> fast_robust_regression_ssq_b_j_internal(
    RobustModelResult& res,
    const Eigen::Ref<const Eigen::MatrixXd>& X,
    const Eigen::Ref<const Eigen::VectorXd>& y_vec,
    const std::string& method,
    double c,
    int j,
    int maxit,
    const FixedParamSpec& fixed_spec
) {
    if (!res.converged && res.XtWX.rows() == 0) {
        Eigen::MatrixXd XtWX_free = weighted_crossprod(res.X_free, res.w);
        res.XtWX = expand_free_covariance(X.cols(), fixed_spec, XtWX_free, false);
    }

    int n = X.rows();
    int p = X.cols();
    Eigen::VectorXd r = y_vec - X * res.b;
    
    std::optional<double> ssq_j;
    if (res.converged || res.num_iter == maxit) {
        Eigen::VectorXd psi_r(n);
        Eigen::ArrayXd psi_prime(n);
        const Eigen::ArrayXd u = r.array() / res.scale;
        if (method == "M") {
            const Eigen::ArrayXd abs_u = u.abs();
            const Eigen::ArrayXd sign_u = (u > 0.0).select(
                Eigen::ArrayXd::Ones(n),
                -Eigen::ArrayXd::Ones(n)
            );
            psi_r = (abs_u <= c).select(r.array(), c * res.scale * sign_u).matrix();
            psi_prime = (abs_u <= c).template cast<double>();
        } else {
            const double c_b = 4.685;
            const Eigen::ArrayXd abs_u = u.abs();
            const Eigen::ArrayXd u_scaled_sq = (u / c_b).square();
            const Eigen::ArrayXd tmp = 1.0 - u_scaled_sq;
            psi_r = (abs_u <= c_b).select(r.array() * tmp.square(), 0.0).matrix();
            psi_prime = (abs_u <= c_b).select(tmp * (1.0 - 5.0 * u_scaled_sq), 0.0);
        }
        
        double m = psi_prime.sum() / n;
        // Huber's (1981) small-sample correction kappa = 1 + p Var(psi') / (n mean(psi')^2),
        // as MASS:::summary.rlm applies it (Var with denominator n - 1). Without it the
        // SE was low by the factor 1 / kappa and the KK IVWC inverse-variance weights
        // disagreed with the MASS::rlm path (v1.0.6-TODO-15).
        const double p_free_d = double(fixed_spec.free_idx.size());
        const double var_psi_prime = (n > 1) ? (psi_prime - m).square().sum() / double(n - 1) : 0.0;
        const double kappa = 1.0 + p_free_d * var_psi_prime / (double(n) * m * m);
        double sum_psi_sq = psi_r.squaredNorm();
        double factor = (n / (double(n - fixed_spec.free_idx.size()))) * sum_psi_sq / (n * m * m) * kappa * kappa;

        if (j > 0 && j <= p) {
            const int j0 = j - 1;
            int free_j = -1;
            for (int jj = 0; jj < fixed_spec.free_idx.size(); ++jj) {
                if (fixed_spec.free_idx[jj] == j0) {
                    free_j = jj;
                    break;
                }
            }
            if (free_j >= 0) {
                double inv_diag = res.XtX_inv_diag_j;
                if (!std::isfinite(inv_diag)) {
                    Eigen::MatrixXd XtX = symmetric_crossprod(res.X_free);
                    inv_diag = compute_diagonal_inverse_entry(XtX, free_j + 1);
                }
                if (std::isfinite(inv_diag)) {
                    ssq_j = factor * inv_diag;
                }
            }
        }
    }

    return ssq_j;
}

#ifndef EDI_CORE_ONLY
//' Fast Robust (M/MM-Estimator) Linear Regression (C++)
//'
//' Fits a robust linear regression by iteratively reweighted least squares (IRLS),
//' minimizing \eqn{\sum_i \rho(r_i / \hat\sigma)} for residuals \eqn{r_i = y_i -
//' x_i^\top\beta} and a robustness scale \eqn{\hat\sigma}, rather than
//' ordinary least squares' \eqn{\sum_i r_i^2}. \code{method = "M"} uses \strong{Huber's}
//' weight function \eqn{w(u) = 1} for \eqn{|u| \le c} and \eqn{w(u) = c/|u|}
//' otherwise (\code{c}, default 1.345, tuned for 95\% efficiency under normality);
//' \code{method = "MM"} (the default; any other value is an error) uses
//' \strong{Tukey's bisquare} weight \eqn{w(u) = (1 - (u/c_b)^2)^2} for \eqn{|u| \le c_b}
//' and \eqn{0} otherwise, with \eqn{c_b = 4.685} hardcoded (not settable through
//' this exported wrapper, though the internal fitter accepts it). The scale is the
//' normalized median absolute deviation of the current residuals,
//' \eqn{\hat\sigma = \mathrm{median}(|r_i|) / 0.6745}. For \code{method = "M"} it is
//' re-estimated at the start of every IRLS iteration and convergence is declared when
//' the relative change in the residual vector, \eqn{\|r_{old} - r\| / \|r_{old}\|}, is at
//' most \code{tol}: this is exactly \code{MASS::rlm(method = "M", scale.est = "MAD",
//' test.vec = "resid")}, with \code{tol} playing the role of \code{acc}. For
//' \code{"MM"} the scale is fixed once at the start value and convergence is declared
//' when the relative change in \eqn{\beta} falls below \code{tol}. (The internal
//' fitter also accepts a caller-supplied fixed scale, but this wrapper always
//' estimates it.) Each IRLS iteration re-weights and re-solves the weighted normal
//' equations \eqn{X^\top W X\, \beta = X^\top W y} via \code{Eigen::LDLT}. Column 1 of a real design typically holds
//' the intercept, but no columns are treated specially except via \code{fixed_idx}.
//'
//' @section Fixed parameters, warm starts:
//' \code{fixed_idx} and \code{fixed_values} optionally hold a subset of coefficients
//' fixed at caller-supplied constant values (subtracted out of \code{y} as an
//' offset) rather than estimated. \code{warm_start_beta} supplies a starting
//' coefficient vector directly; otherwise, if \code{smart_cold_start = TRUE} (the
//' default), an ordinary QR least-squares fit seeds the start (and, when variance
//' will later be requested via \code{j}, also caches the QR-based \eqn{[(X^\top
//' X)^{-1}]_{jj}} entry for reuse in the variance formula below). \code{warm_start_weights}
//' seeds the IRLS weights for the first iteration only (skipping that iteration's
//' Huber/bisquare weight computation); \code{warm_start_fisher_info} similarly seeds
//' the first iteration's \eqn{X^\top W X} curvature matrix.
//'
//' @param X A numeric matrix of predictors.
//' @param y A numeric vector of responses.
//' @param warm_start_beta Optional starting values for coefficients. If provided, \code{smart_cold_start} is ignored.
//' @param smart_cold_start Logical. If \code{TRUE} (the default) and no \code{warm_start_beta}
//'   is supplied, use an OLS (QR) initial guess; see the section "Fixed parameters, warm starts".
//' @param method Robust estimation method: \code{"M"} for Huber weighting, \code{"MM"}
//'   (the default) for Tukey bisquare weighting; any other value is an error; see the Description.
//' @param j 1-based index of the coefficient whose asymptotic variance to return in \code{ssq_b_j}.
//' @param c Huber tuning constant (default 1.345; only used when \code{method = "M"}).
//' @param maxit Maximum number of IRLS iterations.
//' @param tol Convergence tolerance: relative residual change for \code{"M"} (as
//'   \code{MASS::rlm}'s \code{acc}), relative coefficient change for \code{"MM"}.
//' @param fixed_idx Optional indices of fixed parameters.
//' @param fixed_values Optional values for fixed parameters.
//' @param warm_start_weights Optional initial working weights for the first IRLS iteration.
//' @param warm_start_fisher_info Optional initial curvature (\eqn{X^\top W X}) matrix for the first IRLS iteration.
//' @param estimate_only If \code{TRUE}, skip the post-fit asymptotic-variance computation
//'   and return only \code{coefficients}, \code{scale}, \code{converged}, and \code{num_iter} (plus diagnostics).
//'
//' @return If \code{estimate_only = TRUE}: a list with \code{coefficients}, \code{scale}
//'   (the MAD-based robustness scale \eqn{\hat\sigma} used in the last iteration), \code{converged}, \code{num_iter}.
//'   Otherwise, additionally: \code{ssq_b_j} and \code{fisher_information} (the final IRLS
//'   \eqn{X^\top W X} curvature matrix). \code{ssq_b_j} is computed only if the fit converged
//'   or ran the full \code{maxit} iterations, as the standard M-estimator asymptotic variance
//'   \eqn{\widehat{\mathrm{Var}}(\hat\beta_j) = \kappa^2 \left(\frac{n}{n-p}\right) \frac{\sum_i
//'   \psi(r_i)^2}{n\,\bar\psi'^2} \, [(X^\top X)^{-1}]_{jj}}, where \eqn{\psi} is the
//'   derivative of \eqn{\rho} (i.e. \eqn{\psi(r) = w(r/\hat\sigma)\,r}), \eqn{\bar\psi'} is
//'   the mean of \eqn{\psi'} across observations and \eqn{\kappa = 1 + p\,\mathrm{Var}(\psi') /
//'   (n\,\bar\psi'^2)} is Huber's (1981) small-sample correction, the same formula as
//'   \code{summary(MASS::rlm(...))} (default \code{method = "XtX"}); \code{NA} if \code{j} indexes a fixed
//'   coefficient or the fit neither converged nor exhausted \code{maxit}.
//' @export
//' @keywords internal
// [[Rcpp::export]]
List fast_robust_regression_cpp(
    const Eigen::Map<Eigen::MatrixXd>& X,
    SEXP y,
    Nullable<NumericVector> warm_start_beta = R_NilValue,
    bool smart_cold_start = true,
    std::string method = "MM",
    int j = 2,
    double c = 1.345,
    int maxit = 50,
    double tol = 1e-7,
    Rcpp::Nullable<Rcpp::IntegerVector> fixed_idx = R_NilValue,
    Rcpp::Nullable<Rcpp::NumericVector> fixed_values = R_NilValue,
    Rcpp::Nullable<Rcpp::NumericVector> warm_start_weights = R_NilValue,
    Rcpp::Nullable<Rcpp::NumericMatrix> warm_start_fisher_info = R_NilValue,
    bool estimate_only = false
) {
    NumericVector y_r(y);
    Eigen::Map<const Eigen::VectorXd> y_vec(y_r.begin(), y_r.size());

    RobustModelResult res = fast_robust_regression_internal(
        X, y_vec,
        nullable_to_optional<Eigen::VectorXd>(warm_start_beta),
        smart_cold_start, method, c, 4.685, maxit, tol, -1.0,
        nullable_to_optional<Eigen::VectorXi>(fixed_idx),
        nullable_to_optional<Eigen::VectorXd>(fixed_values),
        nullable_to_optional<Eigen::VectorXd>(warm_start_weights),
        nullable_to_optional<Eigen::MatrixXd>(warm_start_fisher_info),
        estimate_only, j);
    FixedParamSpec fixed_spec = make_fixed_param_spec(
        X.cols(),
        nullable_to_optional<Eigen::VectorXi>(fixed_idx),
        nullable_to_optional<Eigen::VectorXd>(fixed_values));

    if (estimate_only) {
        return edi::to_rcpp_list(edi::ResultMap()
            .set("coefficients", res.b)
            .set("scale", res.scale)
            .set("converged", res.converged)
            .set("num_iter", res.num_iter)
            .set("hit_iteration_cap", res.hit_iteration_cap)
            .set("min_eigenvalue_information", res.min_eigenvalue_information));
    }

    std::optional<double> ssq_j_opt = fast_robust_regression_ssq_b_j_internal(
        res, X, y_vec, method, c, j, maxit, fixed_spec);
    double ssq_j = ssq_j_opt.has_value() ? *ssq_j_opt : NA_REAL;

    return edi::to_rcpp_list(edi::ResultMap()
        .set("coefficients", res.b)
        .set("scale", res.scale)
        .set("converged", res.converged)
        .set("num_iter", res.num_iter)
        .set("hit_iteration_cap", res.hit_iteration_cap)
        .set("min_eigenvalue_information", res.min_eigenvalue_information)
        .set("ssq_b_j", ssq_j)
        .set("fisher_information", res.XtWX));
}

// [[Rcpp::export]]
NumericVector compute_robust_rand_bootstrap_parallel_cpp(
    const NumericVector& y0,
    const NumericMatrix& Xc,
    const IntegerMatrix& i_mat,
    const IntegerMatrix& w_mat,
    double delta,
    std::string method,
    Rcpp::Nullable<Rcpp::NumericMatrix> noise_mat,
    int num_cores)
{
    // Validated here, before the OpenMP region: an exception thrown inside a parallel region would terminate R.
    if (method != "M" && method != "MM") {
        Rcpp::stop("method must be \"M\" (Huber) or \"MM\", got \"%s\"", method.c_str());
    }
    const int n      = i_mat.nrow();
    const int nsim   = i_mat.ncol();
    const int n_full = y0.size();
    const int p_cov  = Xc.ncol();
    const int p      = 2 + p_cov;  // intercept + treatment + covariates

    const double* y0_ptr = y0.begin();
    const double* xc_ptr = (p_cov > 0) ? Xc.begin() : nullptr;
    const int*    i_ptr  = i_mat.begin();
    const int*    w_ptr  = w_mat.begin();

    std::vector<double> results(nsim, NA_REAL);
    double* res_ptr = results.data();

    // An empty (0-length) matrix, e.g. matrix(0, 0, 0), is Nullable::isNotNull() == TRUE
    // but has no data: treat it as absent so noise_ptr[b * n + i] is never read OOB.
    NumericMatrix noise_m;
    if (noise_mat.isNotNull()) noise_m = NumericMatrix(noise_mat);
    const bool has_noise = noise_m.size() > 0;
    const double* noise_ptr = has_noise ? noise_m.begin() : nullptr;

#pragma omp parallel if(EDI_KERNEL_NUM_THREADS(num_cores) > 1) num_threads(EDI_KERNEL_NUM_THREADS(num_cores))
    {
        Eigen::VectorXd y_b(n);
        Eigen::MatrixXd X_b(n, p);

#pragma omp for schedule(dynamic)
        for (int b = 0; b < nsim; ++b) {
            const int* ic = i_ptr + (size_t)b * n;
            const int* wc = w_ptr + (size_t)b * n;

            int n_t = 0, n_c = 0;
            for (int i = 0; i < n; ++i) {
                const int r  = ic[i] - 1;
                const int wt = (wc[i] == 1) ? 1 : 0;
                X_b(i, 0) = 1.0;
                X_b(i, 1) = static_cast<double>(wt);
                for (int j = 0; j < p_cov; ++j)
                    X_b(i, j + 2) = xc_ptr[(size_t)j * n_full + r];
                double yv = y0_ptr[r];
                if (has_noise) yv += noise_ptr[(size_t)b * n + i];
                y_b(i) = yv + delta * wt;
                n_t += wt;
                n_c += (1 - wt);
            }
            if (n_t < 2 || n_c < 2) continue;
            // Non-finite resampled responses/covariates: the draw is nonestimable
            // (stays NA). Checked here because the IRLS core now throws on them and
            // must not be entered from inside the parallel region (TODO-131).
            if (!y_b.allFinite() || !X_b.allFinite()) continue;

            RobustModelResult res = fast_robust_regression_internal(
                X_b, y_b,
                std::nullopt, true, method,
                1.345, 4.685, 50, 1e-7, -1.0,
                std::nullopt, std::nullopt,
                std::nullopt, std::nullopt,
                true, 0);
            if (res.b.size() > 1 && std::isfinite(res.b[1]))
                res_ptr[b] = res.b[1];
        }
    }
    return wrap(results);
}
#endif // EDI_CORE_ONLY
