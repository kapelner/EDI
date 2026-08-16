#ifdef EDI_CORE_ONLY
#include "_helper_functions_core.h"
#else
#include "_helper_functions.h"
#include "result_map_rcpp.h"
#include <RcppEigen.h>
#endif
#include <stdexcept>

#ifndef EDI_CORE_ONLY
using namespace Rcpp;
#endif

namespace {

// Log-scale pnorm: falls back to fast_log_pnorm's wider-range series for |x| > 6
// where direct log(erfc) loses precision.
inline double log_pnorm_lower(double x) {
    if (x > -6.0 && x < 6.0) return std::log(0.5 * fast_erfc(-x * kSqrt1_2));
    return fast_log_pnorm(x);
}
inline double log_pnorm_upper(double x) {
    if (x > -6.0 && x < 6.0) return std::log(0.5 * fast_erfc(x * kSqrt1_2));
    return fast_log_pnorm(-x);
}

// Generalized residual for Probit: y*phi/Phi - (1-y)*phi/(1-Phi)
inline double probit_gen_residual_optimized(double y, double phi, double Phi, double Phi_inv) {
    if (y > 0.5) {
        return phi / Phi;
    } else {
        return -phi / Phi_inv;
    }
}

// score_weighted_crossprod_colwise_assign is now the canonical version in
// _helper_functions_core.h (already in this file's include chain) -- see
// its comment for why.

class ProbitLbfgsObjective {
private:
    const Eigen::Ref<const RowMajorMatrixXd> m_X;
    const Eigen::Ref<const Eigen::VectorXd> m_y;
    const Eigen::Ref<const Eigen::VectorXd> m_weights;
    const Eigen::Ref<const Eigen::VectorXd> m_eta_fixed;
    bool m_use_weights;
    int m_n;

public:
    ProbitLbfgsObjective(const Eigen::Ref<const RowMajorMatrixXd>& X,
                         const Eigen::Ref<const Eigen::VectorXd>& y,
                         const Eigen::Ref<const Eigen::VectorXd>& weights,
                         const Eigen::Ref<const Eigen::VectorXd>& eta_fixed,
                         bool use_weights) :
        m_X(X), m_y(y), m_weights(weights), m_eta_fixed(eta_fixed),
        m_use_weights(use_weights), m_n(X.rows()) {}

    double operator()(const Eigen::VectorXd& beta, Eigen::VectorXd& grad) {
        const Eigen::VectorXd eta = m_X * beta + m_eta_fixed;
        Eigen::VectorXd gen_res(m_n);
        double f = 0.0;

        for (int i = 0; i < m_n; ++i) {
            const double ei = eta[i];
            const double wi = m_use_weights ? m_weights[i] : 1.0;
            
            const double lp = log_pnorm_lower(ei);
            const double lq = log_pnorm_upper(ei);
            f -= wi * (m_y[i] * lp + (1.0 - m_y[i]) * lq);
            
            const double phi = dnorm_fast(ei);
            const double Phi = pnorm_fast(ei);
            const double Phi_inv = 1.0 - Phi;
            gen_res[i] = wi * probit_gen_residual_optimized(m_y[i], phi, Phi, Phi_inv);
        }

        grad.noalias() = -m_X.transpose() * gen_res;
        return f;
    }
};

} // namespace

// Internal probit fitting core.
ModelResult fast_probit_regression_internal(
        const Eigen::Ref<const Eigen::MatrixXd>& X_eigen,
        const Eigen::Ref<const Eigen::VectorXd>& y_eigen,
        const Eigen::Ref<const Eigen::VectorXd>& weights_eigen,
        std::optional<Eigen::VectorXd> warm_start_beta = std::nullopt,
        bool smart_cold_start = true,
        int maxit = 100,
        double tol = 1e-8,
        std::optional<Eigen::VectorXi> fixed_idx = std::nullopt,
        std::optional<Eigen::VectorXd> fixed_values = std::nullopt,
        std::string optimization_alg = "irls",
        std::optional<Eigen::VectorXd> warm_start_weights = std::nullopt,
        std::optional<Eigen::MatrixXd> warm_start_fisher_info = std::nullopt,
        bool estimate_only = false) {

    const int n = X_eigen.rows();
    const int p = X_eigen.cols();
    const bool use_weights = (weights_eigen.size() == n);
    FixedParamSpec fixed_spec = make_fixed_param_spec(p, fixed_idx, fixed_values);
    const int p_free = static_cast<int>(fixed_spec.free_idx.size());

    Eigen::VectorXd beta_start = Eigen::VectorXd::Zero(p);
    if (warm_start_beta.has_value()) {
        beta_start = *warm_start_beta;
        if (static_cast<int>(beta_start.size()) != p)
            throw std::invalid_argument("warm_start_beta must have length equal to ncol(X)");
    } else if (smart_cold_start) {
        beta_start = ols_smart_cold_start_beta(X_eigen, y_eigen.array().unaryExpr([](double v){
            return fast_qnorm((v + 0.5) / 2.0);
        }));
    }
    beta_start = apply_fixed_values(beta_start, fixed_spec);

    Eigen::VectorXd eta_fixed = Eigen::VectorXd::Zero(n);
    for (int k = 0; k < static_cast<int>(fixed_spec.fixed_idx.size()); ++k) {
        eta_fixed += X_eigen.col(fixed_spec.fixed_idx[k]) * fixed_spec.fixed_values[k];
    }

    Eigen::MatrixXd X_free(n, p_free);
    for (int j = 0; j < p_free; ++j) X_free.col(j) = X_eigen.col(fixed_spec.free_idx[j]);

    Eigen::VectorXd beta_free = subset_vector(beta_start, fixed_spec.free_idx);

    ModelResult res;
    res.num_iter = 0;
    res.converged = false;

    if (optimization_alg == "lbfgs") {
        // Same solver/parameter setup as RcppNumerical's optim_lbfgs
        // (epsilon=epsilon_rel=tol, past=1, delta=tol, max_linesearch=100,
        // backtracking strong-Wolfe line search) -- swapped in because
        // optim_lbfgs's own failure path calls Rcpp::warning(), a real R
        // dependency baked into RcppNumerical's vendored wrapper.h that
        // can't be satisfied under EDI_CORE_ONLY.
        ProbitLbfgsObjective obj(X_free, y_eigen, weights_eigen, eta_fixed, use_weights);
        LikelihoodFitResult fit = optimize_likelihood_lbfgs(obj, beta_free, maxit, tol);
        beta_free = fit.params;
        res.converged = fit.converged;
        res.num_iter = std::numeric_limits<int>::min();
        res.neg_ll = fit.value;
    } else {
        Eigen::VectorXd mu(n);
        Eigen::VectorXd w(n);
        Eigen::VectorXd gen_res(n);
        Eigen::MatrixXd XtWX(p_free, p_free);
        Eigen::VectorXd score_free(p_free);

        for (int iter = 0; iter < maxit; ++iter) {
            res.num_iter++;
            const Eigen::VectorXd eta = X_free * beta_free + eta_fixed;

            for (int i = 0; i < n; ++i) {
                const double ei = eta[i];
                const double wi = use_weights ? weights_eigen[i] : 1.0;
                
                const double phi = dnorm_fast(ei);
                const double Phi = pnorm_fast(ei);
                const double Phi_inv = 1.0 - Phi;
                const double vm = std::max(1e-15, Phi * Phi_inv);
                
                mu[i] = Phi;
                w[i] = wi * (phi * phi / vm);
                gen_res[i] = wi * probit_gen_residual_optimized(y_eigen[i], phi, Phi, Phi_inv);
            }

            const bool use_warm_xtwx = (iter == 0) && warm_start_fisher_info.has_value();
            if (!use_warm_xtwx) {
                score_weighted_crossprod_colwise_assign(X_free, gen_res, w, score_free, XtWX);
            } else {
                score_free.noalias() = X_free.transpose() * gen_res;
                XtWX = subset_matrix(*warm_start_fisher_info, fixed_spec.free_idx, fixed_spec.free_idx);
            }
            if (score_free.norm() < tol) { res.converged = true; break; }

            Eigen::LDLT<Eigen::MatrixXd> ldlt(XtWX);
            if (ldlt.info() != Eigen::Success) break;
            const Eigen::VectorXd delta = ldlt.solve(score_free);
            if (!delta.allFinite()) break;

            beta_free += delta;
            if (delta.norm() < tol) { res.converged = true; break; }
        }
        res.mu = mu;
        res.XtWX = expand_free_covariance(p, fixed_spec, XtWX, false);
        res.score = expand_free_params(score_free, Eigen::VectorXd::Zero(p), fixed_spec);
        
        // Reuse mu[] from last IRLS iteration — avoids 1 GEMV + n erfc calls
        double nl = 0.0;
        for (int i = 0; i < n; ++i) {
            const double wi = use_weights ? weights_eigen[i] : 1.0;
            nl -= wi * (y_eigen[i] > 0.5 ? std::log(mu[i]) : std::log1p(-mu[i]));
        }
        res.neg_ll = nl;
    }

    res.b = expand_free_params(beta_free, beta_start, fixed_spec);
    
    if (!estimate_only) {
        const Eigen::VectorXd eta = X_eigen * res.b;
        if (res.mu.size() == 0) {
            res.mu = eta.array().unaryExpr([](double e){ return pnorm_fast(e); }).matrix();
        }
        if (res.XtWX.size() == 0) {
            Eigen::VectorXd weights_vec(n);
            for (int i = 0; i < n; ++i) {
                const double wi = use_weights ? weights_eigen[i] : 1.0;
                const double ei = eta[i];
                const double phi = dnorm_fast(ei);
                const double Phi = pnorm_fast(ei);
                const double vm = std::max(1e-15, Phi * (1.0 - Phi));
                weights_vec[i] = wi * (phi * phi / vm);
            }
            res.XtWX = X_eigen.transpose() * weights_vec.asDiagonal() * X_eigen;
        }
        if (res.score.size() == 0) {
            Eigen::VectorXd full_gen_res(n);
            for (int i = 0; i < n; ++i) {
                const double wi = use_weights ? weights_eigen[i] : 1.0;
                const double ei = eta[i];
                const double phi = dnorm_fast(ei);
                const double Phi = pnorm_fast(ei);
                full_gen_res[i] = wi * probit_gen_residual_optimized(y_eigen[i], phi, Phi, 1.0 - Phi);
            }
            res.score = X_eigen.transpose() * full_gen_res;
        }
    }
    
    return res;
}

#ifndef EDI_CORE_ONLY
// [[Rcpp::export]]
Eigen::VectorXd get_probit_regression_score_cpp(const Eigen::Map<Eigen::MatrixXd>& X, SEXP y, const Eigen::Map<Eigen::VectorXd>& beta) {
	NumericVector y_r_coerced(y); Eigen::Map<const Eigen::VectorXd> y_vec_coerced(y_r_coerced.begin(), y_r_coerced.size());


    

    

    

    const Eigen::VectorXd eta = X * beta;
    const int n = X.rows();
    Eigen::VectorXd gen_res(n);
    for (int i = 0; i < n; ++i) {
        const double ei = eta[i];
        gen_res[i] = probit_gen_residual_optimized(y_vec_coerced[i], dnorm_fast(ei), pnorm_fast(ei), pnorm_fast(-ei));
    }
    return X.transpose() * gen_res;
}

// [[Rcpp::export]]
Eigen::MatrixXd get_probit_regression_hessian_cpp( const Eigen::Map<Eigen::MatrixXd>& X,
		const Eigen::Map<Eigen::VectorXd>& beta) {

    

    

    const Eigen::VectorXd eta = X * beta;
    const int n = X.rows();
    Eigen::VectorXd w(n);
    for (int i = 0; i < n; ++i) {
        const double ei = eta[i];
        const double phi = dnorm_fast(ei);
        const double Phi = pnorm_fast(ei);
        const double vm = std::max(1e-15, Phi * (1.0 - Phi));
        w[i] = phi * phi / vm;
    }
    return -weighted_crossprod(X, w);
}

//' Fast Probit Regression, Estimate-Capable (C++)
//'
//' Fits binary probit regression, \eqn{Y_i \sim \mathrm{Bernoulli}(\Phi(\eta_i))},
//' \eqn{\eta_i = x_i^\top\beta}, by maximum likelihood, using a numerically stable
//' log-scale evaluation of \eqn{\Phi} (\code{log_pnorm_lower}/\code{log_pnorm_upper},
//' matching \code{\link[base]{pnorm}}'s \code{log.p = TRUE} for \eqn{|\eta| < 6} via a
//' \code{erfc}-based identity, and falling back to a wider-range series approximation
//' beyond that). By default (\code{optimization_alg = "irls"}), fitting uses
//' iteratively reweighted least squares with working weights \eqn{w_i =
//' \phi(\eta_i)^2 / \max(\Phi(\eta_i)(1-\Phi(\eta_i)), 10^{-15})} (the standard probit
//' Fisher-scoring weight) and generalized residual \eqn{r_i = y_i\,\phi(\eta_i)/\Phi(\eta_i)
//' - (1-y_i)\,\phi(\eta_i)/(1-\Phi(\eta_i))}: each iteration solves \eqn{X^\top W X\,
//' \delta = X^\top r} via \code{Eigen::LDLT} and takes the full Newton step (no
//' step-halving line search), declaring convergence when either the score norm or the
//' step norm falls below \code{tol}. Any \code{optimization_alg} value other than
//' \code{"lbfgs"} runs this IRLS path; \code{optimization_alg = "lbfgs"} instead
//' minimizes the exact negative log-likelihood directly via a bespoke L-BFGS driver
//' with backtracking strong-Wolfe line search (mirroring \pkg{RcppNumerical}'s
//' \code{optim_lbfgs} defaults), bypassing IRLS entirely — in that path,
//' \code{warm_start_fisher_info} is \strong{not consulted}.
//'
//' @section Fixed parameters, warm starts:
//' \code{fixed_idx} and \code{fixed_values} optionally hold a subset of coefficients
//' fixed at caller-supplied constant values (folded into the linear predictor as an
//' offset) rather than estimated. \code{warm_start_beta} supplies starting
//' coefficients directly; otherwise, if \code{smart_cold_start = TRUE} (the default),
//' an OLS fit of the probit-transformed response \eqn{\Phi^{-1}((y+0.5)/2)} on
//' \code{X} seeds the start. \code{warm_start_fisher_info}, if supplied, seeds the
//' curvature matrix used for the IRLS path's very first iteration only (see above for
//' the \code{"lbfgs"} exception). \code{warm_start_weights} is accepted for interface
//' parity with sibling functions but is \strong{not consulted anywhere} in this
//' function's fitting logic.
//'
//' @param X A numeric matrix of predictors (including an intercept column, if desired).
//' @param y A numeric vector of binary responses (0/1).
//' @param warm_start_beta Optional starting values for coefficients \eqn{\beta}. If
//'   provided, \code{smart_cold_start} is ignored.
//' @param smart_cold_start Logical. If \code{TRUE} (the default) and no
//'   \code{warm_start_beta} is supplied, use an OLS-based initial guess (see Details).
//' @param maxit Maximum number of iterations (IRLS path only).
//' @param tol Convergence tolerance.
//' @param fixed_idx Optional indices of fixed parameters.
//' @param fixed_values Optional values for fixed parameters.
//' @param optimization_alg Optimization algorithm: any value other than
//'   \code{"lbfgs"} runs IRLS (default \code{"irls"}); \code{"lbfgs"} runs direct
//'   likelihood minimization.
//' @param warm_start_weights Accepted but unused; see Details.
//' @param warm_start_fisher_info Optional initial curvature matrix for the first
//'   IRLS iteration (IRLS path only).
//' @param estimate_only If \code{TRUE}, skip the post-fit weight/curvature computation
//'   and return only \code{b}, \code{converged}, and \code{iterations}.
//' @return If \code{estimate_only = TRUE}: a list with \code{b}, \code{converged},
//'   \code{iterations}. Otherwise: a list additionally containing \code{w} (the final
//'   probit IRLS working weights, evaluated at the fitted \eqn{\hat\beta} regardless of
//'   which \code{optimization_alg} was used), \code{fisher_information} (\eqn{X^\top W X}
//'   at those weights), \code{score}, and \code{neg_ll} (the negative log-likelihood).
//' @seealso \code{\link{fast_probit_regression_weighted_cpp}} for the observation-weighted
//'   variant; \code{\link{fast_probit_regression_with_var_cpp}} for the variance-computing
//'   variant.
//' @export
//' @keywords internal
// [[Rcpp::export]]
List fast_probit_regression_cpp(const Eigen::Map<Eigen::MatrixXd>& X, SEXP y, Rcpp::Nullable<Rcpp::NumericVector> warm_start_beta = R_NilValue, bool smart_cold_start = true, int maxit = 100, double tol = 1e-8, Rcpp::Nullable<Rcpp::IntegerVector> fixed_idx = R_NilValue, Rcpp::Nullable<Rcpp::NumericVector> fixed_values = R_NilValue, std::string optimization_alg = "irls", Rcpp::Nullable<Rcpp::NumericVector> warm_start_weights = R_NilValue, Rcpp::Nullable<Rcpp::NumericMatrix> warm_start_fisher_info = R_NilValue, bool estimate_only = false) {
	NumericVector y_r_coerced(y); Eigen::Map<const Eigen::VectorXd> y_vec_coerced(y_r_coerced.begin(), y_r_coerced.size());


    

    

    ModelResult res = fast_probit_regression_internal(
        X, y_vec_coerced, Eigen::VectorXd(),
        nullable_to_optional<Eigen::VectorXd>(warm_start_beta),
        smart_cold_start, maxit, tol,
        nullable_to_optional<Eigen::VectorXi>(fixed_idx),
        nullable_to_optional<Eigen::VectorXd>(fixed_values),
        optimization_alg,
        nullable_to_optional<Eigen::VectorXd>(warm_start_weights),
        nullable_to_optional<Eigen::MatrixXd>(warm_start_fisher_info),
        estimate_only);
    if (estimate_only) {
        return edi::to_rcpp_list(edi::ResultMap()
            .set("b", res.b)
            .set("converged", res.converged)
            .set("iterations", res.num_iter));
    }
    const int n = X.rows();
    const Eigen::VectorXd eta = X * res.b;
    Eigen::VectorXd weights_vec(n);
    for (int i = 0; i < n; ++i) {
        const double ei = eta[i];
        const double phi = dnorm_fast(ei);
        const double Phi = pnorm_fast(ei);
        const double vm = std::max(1e-15, Phi * (1.0 - Phi));
        weights_vec[i] = phi * phi / vm;
    }
    return edi::to_rcpp_list(edi::ResultMap()
        .set("b", res.b)
        .set("w", weights_vec)
        .set("iterations", res.num_iter)
        .set("fisher_information", res.XtWX)
        .set("score", res.score)
        .set("neg_ll", res.neg_ll)
        .set("converged", res.converged));
}

// [[Rcpp::export]]
List fast_probit_regression_weighted_cpp(const Eigen::Map<Eigen::MatrixXd>& X, SEXP y, SEXP weights, Rcpp::Nullable<Rcpp::NumericVector> warm_start_beta = R_NilValue, bool smart_cold_start = true, int maxit = 100, double tol = 1e-8, Rcpp::Nullable<Rcpp::IntegerVector> fixed_idx = R_NilValue, Rcpp::Nullable<Rcpp::NumericVector> fixed_values = R_NilValue, std::string optimization_alg = "irls", Rcpp::Nullable<Rcpp::NumericVector> warm_start_weights = R_NilValue, Rcpp::Nullable<Rcpp::NumericMatrix> warm_start_fisher_info = R_NilValue) {
	NumericVector weights_r_coerced(weights); Eigen::Map<const Eigen::VectorXd> weights_vec_coerced(weights_r_coerced.begin(), weights_r_coerced.size());
	NumericVector y_r_coerced(y); Eigen::Map<const Eigen::VectorXd> y_vec_coerced(y_r_coerced.begin(), y_r_coerced.size());


    

    

    

    ModelResult res = fast_probit_regression_internal(
        X, y_vec_coerced, weights_vec_coerced,
        nullable_to_optional<Eigen::VectorXd>(warm_start_beta),
        smart_cold_start, maxit, tol,
        nullable_to_optional<Eigen::VectorXi>(fixed_idx),
        nullable_to_optional<Eigen::VectorXd>(fixed_values),
        optimization_alg,
        nullable_to_optional<Eigen::VectorXd>(warm_start_weights),
        nullable_to_optional<Eigen::MatrixXd>(warm_start_fisher_info));
    return edi::to_rcpp_list(edi::ResultMap()
        .set("b", res.b)
        .set("mu", res.mu)
        .set("XtWX", res.XtWX)
        .set("fisher_information", res.XtWX)
        .set("score", res.score)
        .set("neg_ll", res.neg_ll)
        .set("converged", res.converged)
        .set("iterations", res.num_iter));
}

//' Fast Probit Regression with Variance Calculation (C++)
//'
//' Fits the same probit model as \code{\link{fast_probit_regression_cpp}} (see that
//' page for the full model and optimizer contract; always with \code{estimate_only =
//' FALSE}, and \code{maxit}/\code{tol} hardcoded to 100/\eqn{10^{-8}} — no override
//' arguments here), and additionally inverts the fitted Fisher information matrix
//' (\code{compute_diagonal_inverse_entry} on the free-coefficient submatrix) to
//' report the variance of two coefficients.
//'
//' @param X A numeric matrix of predictors (including an intercept column, if desired).
//' @param y A numeric vector of binary responses (0/1).
//' @param j The 1-indexed coefficient whose variance to compute in \code{ssq_b_j}. Defaults to 2.
//' @param warm_start_beta Optional starting values for coefficients \eqn{\beta}. If
//'   provided, \code{smart_cold_start} is ignored.
//' @param smart_cold_start Logical. If \code{TRUE} (the default) and no
//'   \code{warm_start_beta} is supplied, use an OLS-based initial guess; see
//'   \code{\link{fast_probit_regression_cpp}} Details.
//' @param fixed_idx Optional indices of fixed parameters.
//' @param fixed_values Optional values for fixed parameters.
//' @param optimization_alg Optimization algorithm: any value other than
//'   \code{"lbfgs"} runs IRLS (default \code{"irls"}); \code{"lbfgs"} runs direct
//'   likelihood minimization; see \code{\link{fast_probit_regression_cpp}} Details.
//' @param warm_start_weights Accepted but unused; see \code{\link{fast_probit_regression_cpp}} Details.
//' @param warm_start_fisher_info Optional initial curvature matrix for the first
//'   IRLS iteration (IRLS path only).
//'
//' @return A list with components \code{b, params} (the fitted coefficients \eqn{\hat\beta},
//'   two aliases of the same vector), \code{ssq_b_j} (the variance of the \eqn{j}-th
//'   coefficient, \code{NA} if \code{j} indexes a fixed coefficient), \code{ssq_b_2} (the
//'   variance of the second coefficient specifically, regardless of \code{j}; \code{NA} if
//'   the second column is fixed), \code{score}, \code{observed_information} /
//'   \code{fisher_information} / \code{information} (three aliases for the same \eqn{X^\top
//'   W X} curvature matrix; \code{information_type} is always \code{"fisher"}),
//'   \code{hessian} (the negative of that same matrix), \code{neg_loglik}/\code{neg_ll}
//'   (two aliases for the negative log-likelihood), \code{loglik} (\code{-neg_ll}, or
//'   \code{NA} if non-finite), \code{converged}, and \code{iterations}.
//' @seealso \code{\link{fast_probit_regression_cpp}} for the estimate-only-capable variant
//'   and full model documentation.
//' @export
//' @keywords internal
// [[Rcpp::export]]
List fast_probit_regression_with_var_cpp( const Eigen::Map<Eigen::MatrixXd>& X,
		SEXP y,
		int j = 2,
		Rcpp::Nullable<Rcpp::NumericVector> warm_start_beta = R_NilValue,
		bool smart_cold_start = true,
		Rcpp::Nullable<Rcpp::IntegerVector> fixed_idx = R_NilValue,
		Rcpp::Nullable<Rcpp::NumericVector> fixed_values = R_NilValue,
		std::string optimization_alg = "irls",
		Rcpp::Nullable<Rcpp::NumericVector> warm_start_weights = R_NilValue,
		Rcpp::Nullable<Rcpp::NumericMatrix> warm_start_fisher_info = R_NilValue) {

    // See fast_logistic_regression_with_var_cpp for why y is coerced here
    // rather than taken as a direct Eigen::Map.
    NumericVector y_r(y);
    Eigen::Map<const Eigen::VectorXd> y_vec(y_r.begin(), y_r.size());
    ModelResult res = fast_probit_regression_internal(
        X, y_vec, Eigen::VectorXd(),
        nullable_to_optional<Eigen::VectorXd>(warm_start_beta),
        smart_cold_start, 100, 1e-8,
        nullable_to_optional<Eigen::VectorXi>(fixed_idx),
        nullable_to_optional<Eigen::VectorXd>(fixed_values),
        optimization_alg,
        nullable_to_optional<Eigen::VectorXd>(warm_start_weights),
        nullable_to_optional<Eigen::MatrixXd>(warm_start_fisher_info),
        false);

    FixedParamSpec fixed_spec = make_fixed_param_spec(
        X.cols(),
        nullable_to_optional<Eigen::VectorXi>(fixed_idx),
        nullable_to_optional<Eigen::VectorXd>(fixed_values));
    Eigen::MatrixXd info_free = subset_matrix(res.XtWX, fixed_spec.free_idx, fixed_spec.free_idx);

    auto free_idx_of = [&](int overall_j) -> int {
        for (int jj = 0; jj < static_cast<int>(fixed_spec.free_idx.size()); ++jj)
            if (fixed_spec.free_idx[jj] == overall_j) return jj + 1; // 1-based
        return -1;
    };

    int free_j = (j > 0 && j <= X.cols()) ? free_idx_of(j - 1) : -1;
    res.ssq_b_j = (free_j > 0) ? compute_diagonal_inverse_entry(info_free, free_j) : NA_REAL;

    int free_2 = (X.cols() >= 2) ? free_idx_of(1) : -1;
    res.ssq_b_2 = (free_2 > 0) ? compute_diagonal_inverse_entry(info_free, free_2) : NA_REAL;

    Eigen::MatrixXd neg_XtWX = -res.XtWX;
    return edi::to_rcpp_list(edi::ResultMap()
        .set("b", res.b)
        .set("params", res.b)
        .set("ssq_b_j", res.ssq_b_j)
        .set("ssq_b_2", res.ssq_b_2)
        .set("score", res.score)
        .set("observed_information", res.XtWX)
        .set("fisher_information", res.XtWX)
        .set("information", res.XtWX)
        .set("information_type", std::string("fisher"))
        .set("hessian", neg_XtWX)
        .set("neg_loglik", res.neg_ll)
        .set("neg_ll", res.neg_ll)
        .set("loglik", R_finite(res.neg_ll) ? -res.neg_ll : NA_REAL)
        .set("converged", res.converged)
        .set("iterations", res.num_iter));
}
#endif // EDI_CORE_ONLY
