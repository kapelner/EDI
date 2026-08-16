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
    double ssq_b_j;

    RobustModelResult() : XtX_inv_diag_j(std::numeric_limits<double>::quiet_NaN()), scale(std::numeric_limits<double>::quiet_NaN()), num_iter(0), converged(false), ssq_b_j(std::numeric_limits<double>::quiet_NaN()) {}
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
    int n = X.rows();
    int p = X.cols();
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
    
    // 2. Scale estimation (MAD of residuals)
    if (scale_est < 0) {
        std::vector<double> abs_r(n);
        for (int i = 0; i < n; ++i) abs_r[i] = std::abs(r[i]);
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
        res.scale = median_abs_r / 0.6745;
    } else {
        res.scale = scale_est;
    }

    if (res.scale < 1e-10) res.scale = 1e-10;

    // 3. IRLS loop
    res.w = Eigen::VectorXd::Ones(n);
    Eigen::VectorXd b_old = b_free;
    
    for (int iter = 1; iter <= maxit; ++iter) {
        edi_check_R_user_interrupt_every(iter);
        res.num_iter = iter;
        
        // Update weights
        if (iter == 1 && warm_start_weights.has_value()) {
            const Eigen::VectorXd& ww = *warm_start_weights;
            if (ww.size() != n) throw std::invalid_argument("warm_start_weights must have length equal to nrow(X)");
            res.w = ww;
        } else {
            const Eigen::ArrayXd u = r.array() / res.scale;
            if (method == "M") {
                const Eigen::ArrayXd abs_u = u.abs();
                res.w = (abs_u <= c).select(1.0, c / abs_u).matrix();
            } else {
                const Eigen::ArrayXd abs_u = u.abs();
                const Eigen::ArrayXd tmp = 1.0 - (u / c_bisquare).square();
                res.w = (abs_u <= c_bisquare).select(tmp.square(), 0.0).matrix();
            }
        }

        // Solve Weighted Least Squares
        Eigen::MatrixXd XtWX;
        if (iter == 1 && warm_start_fisher_info.has_value()) {
            const Eigen::MatrixXd& info_full = *warm_start_fisher_info;
            if (info_full.rows() != p || info_full.cols() != p) throw std::invalid_argument("warm_start_fisher_info must be a p x p matrix");
            XtWX = subset_matrix(info_full, fixed_spec.free_idx, fixed_spec.free_idx);
        } else {
            XtWX = weighted_crossprod(X_free, res.w);
        }
        Eigen::VectorXd XtWy = weighted_crossprod_rhs(X_free, res.w, y_adj);
        
        Eigen::LDLT<Eigen::MatrixXd> ldlt(XtWX);
        if (ldlt.info() != Eigen::Success) break; // Numerical failure
        
        b_free = ldlt.solve(XtWy);
        for (int j = 0; j < p_free; ++j) res.b[fixed_spec.free_idx[j]] = b_free[j];
        r = y - X * res.b;

        // Check convergence
        if ((b_free - b_old).norm() / (b_free.norm() + 1e-10) < tol) {
            res.converged = true;
            if (!estimate_only) res.XtWX = expand_free_covariance(p, fixed_spec, XtWX, false);
            break;
        }
        b_old = b_free;
    }

    return res;
}

#ifndef EDI_CORE_ONLY
//' Fast Robust (M/MM-Estimator) Linear Regression (C++)
//'
//' Fits a robust linear regression by iteratively reweighted least squares (IRLS),
//' minimizing \eqn{\sum_i \rho(r_i / \hat\sigma)} for residuals \eqn{r_i = y_i -
//' x_i^\top\beta} and a fixed robustness scale \eqn{\hat\sigma}, rather than
//' ordinary least squares' \eqn{\sum_i r_i^2}. \code{method = "M"} uses \strong{Huber's}
//' weight function \eqn{w(u) = 1} for \eqn{|u| \le c} and \eqn{w(u) = c/|u|}
//' otherwise (\code{c}, default 1.345, tuned for 95\% efficiency under normality);
//' any other value of \code{method} (including the default, \code{"MM"}) uses
//' \strong{Tukey's bisquare} weight \eqn{w(u) = (1 - (u/c_b)^2)^2} for \eqn{|u| \le c_b}
//' and \eqn{0} otherwise, with \eqn{c_b = 4.685} hardcoded (not settable through
//' this exported wrapper, though the internal fitter accepts it). The scale
//' \eqn{\hat\sigma} is fixed once at the start as the normalized median absolute
//' deviation of the OLS residuals, \eqn{\hat\sigma = \mathrm{median}(|r_i|) /
//' 0.6745} (the internal fitter also accepts a caller-supplied fixed scale, but
//' this wrapper always estimates it). Each IRLS iteration re-weights and re-solves
//' the weighted normal equations \eqn{X^\top W X\, \beta = X^\top W y} via
//' \code{Eigen::LDLT}; convergence is declared when the relative change in
//' \eqn{\beta} falls below \code{tol}. Column 1 of a real design typically holds
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
//'   is supplied, use an OLS (QR) initial guess; see Details.
//' @param method Robust estimation method: \code{"M"} for Huber weighting, anything else
//'   (default \code{"MM"}) for Tukey bisquare weighting; see Details.
//' @param j 1-based index of the coefficient whose asymptotic variance to return in \code{ssq_b_j}.
//' @param c Huber tuning constant (default 1.345; only used when \code{method = "M"}).
//' @param maxit Maximum number of IRLS iterations.
//' @param tol Relative parameter-change convergence tolerance.
//' @param fixed_idx Optional indices of fixed parameters.
//' @param fixed_values Optional values for fixed parameters.
//' @param warm_start_weights Optional initial working weights for the first IRLS iteration.
//' @param warm_start_fisher_info Optional initial curvature (\eqn{X^\top W X}) matrix for the first IRLS iteration.
//' @param estimate_only If \code{TRUE}, skip the post-fit asymptotic-variance computation
//'   and return only \code{coefficients}, \code{scale}, \code{converged}, and \code{iterations}.
//'
//' @return If \code{estimate_only = TRUE}: a list with \code{coefficients}, \code{scale}
//'   (the fixed MAD-based robustness scale \eqn{\hat\sigma}), \code{converged}, \code{iterations}.
//'   Otherwise, additionally: \code{ssq_b_j} and \code{fisher_information} (the final IRLS
//'   \eqn{X^\top W X} curvature matrix). \code{ssq_b_j} is computed only if the fit converged
//'   or ran the full \code{maxit} iterations, as the standard M-estimator asymptotic variance
//'   \eqn{\widehat{\mathrm{Var}}(\hat\beta_j) = \left(\frac{n}{n-p}\right) \frac{\sum_i
//'   \psi(r_i)^2}{n\,\bar\psi'^2} \, [(X^\top X)^{-1}]_{jj}}, where \eqn{\psi} is the
//'   derivative of \eqn{\rho} (i.e. \eqn{\psi(r) = w(r/\hat\sigma)\,r}) and \eqn{\bar\psi'} is
//'   the mean of \eqn{\psi'} across observations, matching the classical Huber (1981)
//'   sandwich-free M-estimator variance formula; \code{NA} if \code{j} indexes a fixed
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
            .set("iterations", res.num_iter));
    }

    if (!res.converged && res.XtWX.rows() == 0) {
        Eigen::MatrixXd XtWX_free = weighted_crossprod(res.X_free, res.w);
        res.XtWX = expand_free_covariance(X.cols(), fixed_spec, XtWX_free, false);
    }

    int n = X.rows();
    int p = X.cols();
    Eigen::VectorXd r = y_vec - X * res.b;
    
    double ssq_j = NA_REAL;
    if (res.converged || res.num_iter == maxit) {
        Eigen::VectorXd psi_r(n);
        double sum_psi_prime = 0;
        const Eigen::ArrayXd u = r.array() / res.scale;
        if (method == "M") {
            const Eigen::ArrayXd abs_u = u.abs();
            const Eigen::ArrayXd sign_u = (u > 0.0).select(
                Eigen::ArrayXd::Ones(n),
                -Eigen::ArrayXd::Ones(n)
            );
            psi_r = (abs_u <= c).select(r.array(), c * res.scale * sign_u).matrix();
            sum_psi_prime = (abs_u <= c).template cast<double>().sum();
        } else {
            const double c_b = 4.685;
            const Eigen::ArrayXd abs_u = u.abs();
            const Eigen::ArrayXd u_scaled_sq = (u / c_b).square();
            const Eigen::ArrayXd tmp = 1.0 - u_scaled_sq;
            psi_r = (abs_u <= c_b).select(r.array() * tmp.square(), 0.0).matrix();
            sum_psi_prime = (abs_u <= c_b).select(tmp * (1.0 - 5.0 * u_scaled_sq), 0.0).sum();
        }
        
        double m = sum_psi_prime / n;
        double sum_psi_sq = psi_r.squaredNorm();
        double factor = (n / (double(n - fixed_spec.free_idx.size()))) * sum_psi_sq / (n * m * m);

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
                if (!R_finite(inv_diag)) {
                    Eigen::MatrixXd XtX = symmetric_crossprod(res.X_free);
                    inv_diag = compute_diagonal_inverse_entry(XtX, free_j + 1);
                }
                if (R_finite(inv_diag)) {
                    ssq_j = factor * inv_diag;
                }
            }
        }
    }

    return edi::to_rcpp_list(edi::ResultMap()
        .set("coefficients", res.b)
        .set("scale", res.scale)
        .set("converged", res.converged)
        .set("iterations", res.num_iter)
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

    const bool has_noise = noise_mat.isNotNull();
    NumericMatrix noise_m;
    const double* noise_ptr = nullptr;
    if (has_noise) {
        noise_m = NumericMatrix(noise_mat);
        noise_ptr = noise_m.begin();
    }

#ifdef _OPENMP
    if (num_cores > 1) omp_set_num_threads(num_cores);
#endif

#pragma omp parallel if(num_cores > 1)
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
