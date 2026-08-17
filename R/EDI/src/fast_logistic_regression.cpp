#ifdef EDI_CORE_ONLY
#include "_helper_functions_core.h"
#else
#include "_helper_functions.h"
#include "result_map_rcpp.h"
#include <RcppEigen.h>
#endif
#include "internal_fn_decls.h"
#ifdef _OPENMP
#include <omp.h>
#endif

#ifndef EDI_CORE_ONLY
using namespace Rcpp;
#endif

namespace {

inline double plogis_manual(double x) {
    if (x > 20.0) return 1.0;
    if (x < -20.0) return 0.0;
    return 1.0 / (1.0 + std::exp(-x));
}

inline double log1pexp_stable(double x) {
    return (x > 0.0) ? x + std::log1p(std::exp(-x)) : std::log1p(std::exp(x));
}

// score_weighted_crossprod_colwise_assign is now the canonical version in
// _helper_functions_core.h (already in this file's include chain) -- see
// its comment for why.

class LogisticLbfgsObjective {
private:
    const Eigen::Ref<const Eigen::MatrixXd> m_X;
    const Eigen::Ref<const Eigen::VectorXd> m_y;
    const Eigen::Ref<const Eigen::VectorXd> m_weights;
    const Eigen::Ref<const Eigen::VectorXd> m_eta_fixed;
    bool m_use_weights;
    int m_n;

public:
    LogisticLbfgsObjective(const Eigen::Ref<const Eigen::MatrixXd>& X, const Eigen::Ref<const Eigen::VectorXd>& y,
                           const Eigen::Ref<const Eigen::VectorXd>& weights, const Eigen::Ref<const Eigen::VectorXd>& eta_fixed,
                           bool use_weights)
        : m_X(X), m_y(y), m_weights(weights), m_eta_fixed(eta_fixed),
          m_use_weights(use_weights), m_n(X.rows()) {}

    double operator()(const Eigen::VectorXd& beta, Eigen::VectorXd& grad) {
        Eigen::VectorXd eta = m_eta_fixed + m_X * beta;
        double neg_ll = 0.0;
        Eigen::VectorXd diff(m_n);

        for (int i = 0; i < m_n; ++i) {
            double ei = eta[i];
            double prob = plogis_manual(ei);
            double wi = m_use_weights ? m_weights[i] : 1.0;
            neg_ll += wi * (log1pexp_stable(ei) - m_y[i] * ei);
            diff[i] = wi * (prob - m_y[i]);
        }
        grad.noalias() = m_X.transpose() * diff;
        return neg_ll;
    }
};

} // namespace

// Internal pure C++ logic. Defaults are declared once in internal_fn_decls.h
// (included above) -- repeating them here would be an error.
ModelResult fast_logistic_regression_internal(const Eigen::Ref<const Eigen::MatrixXd>& X,
                                              const Eigen::Ref<const Eigen::VectorXd>& y,
                                              const Eigen::Ref<const Eigen::VectorXd>& weights,
                                              std::optional<Eigen::VectorXd> warm_start_beta,
                                              bool smart_cold_start,
                                              int maxit,
                                              double tol,
                                              std::optional<Eigen::VectorXi> fixed_idx,
                                              std::optional<Eigen::VectorXd> fixed_values,
                                              std::string optimization_alg,
                                              std::optional<Eigen::VectorXd> warm_start_weights,
                                              std::optional<Eigen::MatrixXd> warm_start_fisher_info,
                                              bool estimate_only) {
    const int n = X.rows();
    const int p = X.cols();
    const bool use_weights = (weights.size() == n);
    FixedParamSpec fixed_spec = make_fixed_param_spec(p, fixed_idx, fixed_values);

    const int p_free = fixed_spec.free_idx.size();
    Eigen::VectorXd beta = Eigen::VectorXd::Zero(p);
    if (warm_start_beta.has_value()) {
        beta = *warm_start_beta;
    } else if (smart_cold_start) {
        beta = edi_opt::logistic_smart_cold_start(X, y);
    }
    beta = apply_fixed_values(beta, fixed_spec);
    
    Eigen::VectorXd beta_free = subset_vector(beta, fixed_spec.free_idx);
    Eigen::VectorXd eta_fixed = Eigen::VectorXd::Zero(n);
    for(size_t k=0; k<fixed_spec.fixed_idx.size(); k++) {
        eta_fixed.noalias() += X.col(fixed_spec.fixed_idx[k]) * fixed_spec.fixed_values[k];
    }

    if (optimization_alg == "lbfgs") {
        Eigen::MatrixXd X_free(n, p_free);
        for (int j = 0; j < p_free; ++j) X_free.col(j) = X.col(fixed_spec.free_idx[j]);

        // Diagnostic fields below are uniform across the LBFGS/IRLS paths of
        // this fitter (optimizer_diagnostics_report.md TODO-4): `converged`
        // is purely last-gradient-norm-vs-tol, recomputed here rather than
        // trusted from the optimizer's own (partly function-value-based)
        // stopping check, and `hit_iteration_cap` separately reports whether
        // the iteration budget, not the gradient, is why the fitter stopped.
        // p_free == 0 (no free parameters) is a degenerate case with nothing
        // to optimize -- trivially converged, no iterations run.
        bool converged = true;
        bool hit_iteration_cap = false;
        double fopt = std::numeric_limits<double>::quiet_NaN();
        double grad_norm = std::numeric_limits<double>::quiet_NaN();
        int niter = 0;
        if (p_free > 0) {
            LogisticLbfgsObjective nll(X_free, y, weights, eta_fixed, use_weights);
            // Same solver/parameter setup as RcppNumerical's optim_lbfgs
            // (epsilon=epsilon_rel=tol, past=1, delta=tol, max_linesearch=100,
            // backtracking strong-Wolfe line search) -- swapped in because
            // optim_lbfgs's own failure path calls Rcpp::warning(), a real R
            // dependency baked into RcppNumerical's vendored wrapper.h that
            // can't be satisfied under EDI_CORE_ONLY.
            LikelihoodFitResult fit = optimize_likelihood_lbfgs(nll, beta_free, maxit, tol);
            beta_free = fit.params;
            fopt = fit.value;
            grad_norm = fit.gradient_norm;
            niter = fit.niter;
            // fit.converged (optimizer_diagnostics_report.md TODO-4, revised
            // 2026-08-17): gradient_norm < tol OR LBFGSpp's own criterion --
            // a pure gradient-norm-only rule made ordinary, correctly-fit
            // LBFGS models routinely report converged=FALSE, since the
            // objective plateaus (satisfying LBFGSpp's relative-function-
            // decrease criterion) before the gradient norm actually clears a
            // tight tol. See optimize_likelihood_lbfgs's own comment.
            const bool finite_result = beta_free.allFinite();
            converged = fit.converged && finite_result;
            // A non-finite result is a distinct failure, not "ran out of
            // iterations" -- consistent with how numerical failures are
            // classified elsewhere in this codebase.
            hit_iteration_cap = fit.hit_iteration_cap && finite_result;
        }

        ModelResult res;
        res.b = expand_free_params(beta_free, beta, fixed_spec);
        res.neg_ll = fopt;
        res.gradient_norm = grad_norm;
        res.num_iter = niter;
        res.converged = converged;
        res.hit_iteration_cap = hit_iteration_cap;
        if (!estimate_only) {
            Eigen::VectorXd eta = X * res.b;
            res.mu = plogis_array_safe(eta.array()).matrix();
            Eigen::VectorXd w_diag = res.mu.array() * (1.0 - res.mu.array());
            if (use_weights) w_diag.array() *= weights.array();
            w_diag.array() = w_diag.array().max(1e-10);
            Eigen::MatrixXd XtWX_free = weighted_crossprod(X_free, w_diag);
            res.XtWX = expand_free_covariance(p, fixed_spec, XtWX_free, false);
            // Reuses XtWX_free (free-parameter-space only -- expand_free_
            // covariance above zero-pads fixed parameters, which would
            // falsely read as rank-deficient/near-zero-eigenvalue whenever
            // fixed_idx is used, so the expanded res.XtWX must not be used
            // here) rather than requiring LogisticLbfgsObjective to
            // implement .hessian() (optimizer_diagnostics_report.md TODO-1).
            // res.converged is already set above, so the fallback-only gate
            // sees the real value.
            set_min_eigenvalue_if_suspect(XtWX_free, res);
        }
        return res;
    }

    // IRLS Path
    Eigen::MatrixXd X_free(n, p_free);
    for (int j = 0; j < p_free; ++j) X_free.col(j) = X.col(fixed_spec.free_idx[j]);

    Eigen::VectorXd mu(n);
    Eigen::VectorXd w(n);
    Eigen::VectorXd eta(n);
    Eigen::MatrixXd XtWX(p_free, p_free);
    Eigen::VectorXd score_free(p_free);
    Eigen::VectorXd diff(n);
    int iterations = 0;
    double last_grad_norm = std::numeric_limits<double>::quiet_NaN();

    for (int iter = 0; iter < maxit; iter++) {
        edi_check_R_user_interrupt_every(iter);
        iterations++;
        eta.noalias() = eta_fixed;
        eta.noalias() += X_free * beta_free;

        // Fast vectorized plogis
        mu.array() = 1.0 / (1.0 + (-eta.array()).exp());

        if (iter == 0 && warm_start_weights.has_value()) {
            const Eigen::VectorXd& ww = *warm_start_weights;
            if (ww.size() == n) w = ww;
            else w.array() = mu.array() * (1.0 - mu.array());
        } else {
            w.array() = mu.array() * (1.0 - mu.array());
        }
        if (use_weights) w.array() *= weights.array();
        w.array() = w.array().max(1e-10);
        diff.array() = y.array() - mu.array();
        if (use_weights) diff.array() *= weights.array();

        const bool use_warm_xtwx = (iter == 0) &&
            (warm_start_fisher_info.has_value() || (smart_cold_start && !warm_start_beta.has_value()));
        if (!use_warm_xtwx) {
            score_weighted_crossprod_colwise_assign(X_free, diff, w, score_free, XtWX);
        } else {
            score_free.noalias() = X_free.transpose() * diff;
            if (warm_start_fisher_info.has_value()) {
                XtWX = subset_matrix(*warm_start_fisher_info, fixed_spec.free_idx, fixed_spec.free_idx);
            } else {
                XtWX = subset_matrix(edi_opt::logistic_smart_hessian(X, beta), fixed_spec.free_idx, fixed_spec.free_idx);
            }
        }

        last_grad_norm = score_free.norm();
        if (last_grad_norm < tol) break;

        Eigen::LDLT<Eigen::MatrixXd> ldlt(XtWX);
        if (ldlt.info() != Eigen::Success) break;
        Eigen::VectorXd delta = ldlt.solve(score_free);
        if (!delta.allFinite()) break;

        beta_free += delta;
        if (delta.norm() < tol) {
            // Step-size convergence: recompute the gradient norm at the
            // post-step point so the uniform `converged = grad_norm < tol`
            // rule below classifies this exit by its actual gradient, not by
            // this (different) stopping criterion having fired.
            eta.noalias() = eta_fixed;
            eta.noalias() += X_free * beta_free;
            mu.array() = 1.0 / (1.0 + (-eta.array()).exp());
            Eigen::VectorXd w_final(n);
            w_final.array() = mu.array() * (1.0 - mu.array());
            if (use_weights) w_final.array() *= weights.array();
            Eigen::VectorXd diff_final(n);
            diff_final.array() = y.array() - mu.array();
            if (use_weights) diff_final.array() *= weights.array();
            last_grad_norm = (X_free.transpose() * diff_final).norm();
            break;
        }
    }

    // Uniform gradient-norm-based convergence (optimizer_diagnostics_report.md
    // TODO-4): `converged` no longer also fires on the step-size (delta.norm())
    // criterion above. `hit_iteration_cap` is TRUE iff the loop ran to `maxit`
    // without any of the above break conditions firing; every other exit
    // (singular Hessian, non-finite step) already implies `last_grad_norm >=
    // tol` -- the gradient-tol break above would have fired first otherwise --
    // so the blanket rule classifies those as `converged = false,
    // hit_iteration_cap = false` correctly with no special-casing needed.
    bool converged = (last_grad_norm < tol);
    bool hit_iteration_cap = (iterations >= maxit) && !converged;

    ModelResult res;
    res.b = expand_free_params(beta_free, beta, fixed_spec);
    if (!estimate_only) {
        res.mu = mu;
        res.XtWX = expand_free_covariance(p, fixed_spec, XtWX, false);
        double nl = 0.0;
        Eigen::VectorXd final_eta = eta_fixed + X_free * beta_free;
        for (int i = 0; i < n; ++i) {
            double wi = use_weights ? weights[i] : 1.0;
            nl += wi * (log1pexp_stable(final_eta[i]) - y[i] * final_eta[i]);
        }
        res.neg_ll = nl;
        Eigen::VectorXd final_diff = y - mu;
        if (use_weights) final_diff.array() *= weights.array();
        res.score = X.transpose() * final_diff;
    }
    res.num_iter = iterations;
    res.converged = converged;
    res.hit_iteration_cap = hit_iteration_cap;
    res.gradient_norm = last_grad_norm;
    // Reuses XtWX, already built above (the last iteration's Fisher
    // information in free-parameter space) -- no new computation
    // (optimizer_diagnostics_report.md TODO-1). Not meaningful for the
    // p_free == 0 case above (returns early); IRLS path only.
    set_min_eigenvalue_if_suspect(XtWX, res);
    return res;
}

#ifndef EDI_CORE_ONLY
// [[Rcpp::export]]
Eigen::VectorXd get_logistic_regression_score_cpp(const Eigen::Map<Eigen::MatrixXd>& X, SEXP y, const Eigen::Map<Eigen::VectorXd>& beta) {
	NumericVector y_r_coerced(y); Eigen::Map<const Eigen::VectorXd> y_vec_coerced(y_r_coerced.begin(), y_r_coerced.size());


    

    

    

    const int n = X.rows();
    Eigen::VectorXd eta = X * beta;
    Eigen::VectorXd mu(n);
    mu.array() = 1.0 / (1.0 + (-eta.array()).exp());
    return X.transpose() * (y_vec_coerced - mu);
}

// [[Rcpp::export]]
Eigen::MatrixXd get_logistic_regression_hessian_cpp( const Eigen::Map<Eigen::MatrixXd>& X,
		const Eigen::Map<Eigen::VectorXd>& beta) {

    

    

    const int n = X.rows();
    Eigen::VectorXd eta = X * beta;
    Eigen::VectorXd w(n);
    w.array() = 1.0 / (1.0 + (-eta.array()).exp()); // mu
    w.array() = w.array() * (1.0 - w.array());
    return -weighted_crossprod(X, w);
}

// [[Rcpp::export]]
Eigen::VectorXd get_logistic_regression_weighted_score_cpp(const Eigen::Map<Eigen::MatrixXd>& X, SEXP y, SEXP weights, const Eigen::Map<Eigen::VectorXd>& beta) {
	NumericVector weights_r_coerced(weights); Eigen::Map<const Eigen::VectorXd> weights_vec_coerced(weights_r_coerced.begin(), weights_r_coerced.size());
	NumericVector y_r_coerced(y); Eigen::Map<const Eigen::VectorXd> y_vec_coerced(y_r_coerced.begin(), y_r_coerced.size());


    

    

    

    

    const int n = X.rows();
    Eigen::VectorXd eta = X * beta;
    Eigen::VectorXd mu(n);
    mu.array() = 1.0 / (1.0 + (-eta.array()).exp());
    Eigen::VectorXd diff = y_vec_coerced - mu;
    diff.array() *= weights_vec_coerced.array();
    return X.transpose() * diff;
}

// [[Rcpp::export]]
Eigen::MatrixXd get_logistic_regression_weighted_hessian_cpp(const Eigen::Map<Eigen::MatrixXd>& X, SEXP weights, const Eigen::Map<Eigen::VectorXd>& beta) {
	NumericVector weights_r_coerced(weights); Eigen::Map<const Eigen::VectorXd> weights_vec_coerced(weights_r_coerced.begin(), weights_r_coerced.size());


    

    

    

    const int n = X.rows();
    Eigen::VectorXd eta = X * beta;
    Eigen::VectorXd w(n);
    w.array() = 1.0 / (1.0 + (-eta.array()).exp()); // mu
    w.array() = w.array() * (1.0 - w.array()) * weights_vec_coerced.array();
    return -weighted_crossprod(X, w);
}

// [[Rcpp::export]]
List fast_logistic_regression_cpp(const Eigen::Map<Eigen::MatrixXd>& X, SEXP y, Rcpp::Nullable<Rcpp::NumericVector> warm_start_beta = R_NilValue, bool smart_cold_start = false, int maxit = 100, double tol = 1e-8, Rcpp::Nullable<Rcpp::IntegerVector> fixed_idx = R_NilValue, Rcpp::Nullable<Rcpp::NumericVector> fixed_values = R_NilValue, std::string optimization_alg = "irls", Rcpp::Nullable<Rcpp::NumericVector> warm_start_weights = R_NilValue, Rcpp::Nullable<Rcpp::NumericMatrix> warm_start_fisher_info = R_NilValue, bool estimate_only = false) {
	NumericVector y_r_coerced(y); Eigen::Map<const Eigen::VectorXd> y_vec_coerced(y_r_coerced.begin(), y_r_coerced.size());


    

    

    ModelResult res = fast_logistic_regression_internal(
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
            .set("num_iter", res.num_iter)
            .set("hit_iteration_cap", res.hit_iteration_cap)
            .set("gradient_norm", res.gradient_norm)
            .set("min_eigenvalue_information", res.min_eigenvalue_information));
    }
    Eigen::VectorXd weights_vec = res.mu.array() * (1.0 - res.mu.array());
    return edi::to_rcpp_list(edi::ResultMap()
        .set("b", res.b)
        .set("w", weights_vec)
        .set("num_iter", res.num_iter)
        .set("hit_iteration_cap", res.hit_iteration_cap)
        .set("fisher_information", res.XtWX)
        .set("score", res.score)
        .set("neg_ll", res.neg_ll)
        .set("converged", res.converged)
        .set("gradient_norm", res.gradient_norm)
        .set("min_eigenvalue_information", res.min_eigenvalue_information));
}

// [[Rcpp::export]]
List fast_logistic_regression_weighted_cpp(const Eigen::Map<Eigen::MatrixXd>& X, SEXP y, SEXP weights, Rcpp::Nullable<Rcpp::NumericVector> warm_start_beta = R_NilValue, bool smart_cold_start = false, int maxit = 100, double tol = 1e-8, Rcpp::Nullable<Rcpp::IntegerVector> fixed_idx = R_NilValue, Rcpp::Nullable<Rcpp::NumericVector> fixed_values = R_NilValue, std::string optimization_alg = "irls", Rcpp::Nullable<Rcpp::NumericVector> warm_start_weights = R_NilValue, Rcpp::Nullable<Rcpp::NumericMatrix> warm_start_fisher_info = R_NilValue) {
	NumericVector weights_r_coerced(weights); Eigen::Map<const Eigen::VectorXd> weights_vec_coerced(weights_r_coerced.begin(), weights_r_coerced.size());
	NumericVector y_r_coerced(y); Eigen::Map<const Eigen::VectorXd> y_vec_coerced(y_r_coerced.begin(), y_r_coerced.size());


    

    

    
    ModelResult res = fast_logistic_regression_internal(
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
        .set("num_iter", res.num_iter)
        .set("hit_iteration_cap", res.hit_iteration_cap)
        .set("gradient_norm", res.gradient_norm)
        .set("min_eigenvalue_information", res.min_eigenvalue_information));
}

// [[Rcpp::export]]
List fast_logistic_regression_with_var_cpp( const Eigen::Map<Eigen::MatrixXd>& X,
		SEXP y,
		int j = 2,
		Rcpp::Nullable<Rcpp::NumericVector> warm_start_beta = R_NilValue,
		bool smart_cold_start = false,
		Rcpp::Nullable<Rcpp::IntegerVector> fixed_idx = R_NilValue,
		Rcpp::Nullable<Rcpp::NumericVector> fixed_values = R_NilValue,
		std::string optimization_alg = "irls",
		Rcpp::Nullable<Rcpp::NumericVector> warm_start_weights = R_NilValue,
		Rcpp::Nullable<Rcpp::NumericMatrix> warm_start_fisher_info = R_NilValue) {

    // Coerce y explicitly: unlike the other Eigen::Map params here, y commonly
    // arrives int-typed (e.g. rbinom()) -- Eigen::Map<VectorXd> has no
    // coercion path, so this restores the NumericVector(SEXP) auto-coercion
    // the pre-zero-copy version of this function relied on.
    NumericVector y_r(y);
    Eigen::Map<const Eigen::VectorXd> y_vec(y_r.begin(), y_r.size());
    ModelResult res = fast_logistic_regression_internal(
        X, y_vec, Eigen::VectorXd(),
        nullable_to_optional<Eigen::VectorXd>(warm_start_beta),
        smart_cold_start, 100, 1e-8,
        nullable_to_optional<Eigen::VectorXi>(fixed_idx),
        nullable_to_optional<Eigen::VectorXd>(fixed_values),
        optimization_alg,
        nullable_to_optional<Eigen::VectorXd>(warm_start_weights),
        nullable_to_optional<Eigen::MatrixXd>(warm_start_fisher_info));
    FixedParamSpec fixed_spec = make_fixed_param_spec(
        X.cols(),
        nullable_to_optional<Eigen::VectorXi>(fixed_idx),
        nullable_to_optional<Eigen::VectorXd>(fixed_values));

    Eigen::MatrixXd info_free = subset_matrix(res.XtWX, fixed_spec.free_idx, fixed_spec.free_idx);

    auto free_idx_of = [&](int overall_j) -> int {
        for (int jj = 0; jj < (int)fixed_spec.free_idx.size(); ++jj)
            if (fixed_spec.free_idx[jj] == overall_j) return jj + 1; // 1-based for compute_diagonal_inverse_entry
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
        .set("num_iter", res.num_iter)
        .set("hit_iteration_cap", res.hit_iteration_cap)
        .set("gradient_norm", res.gradient_norm)
        .set("min_eigenvalue_information", res.min_eigenvalue_information));
}
#endif // EDI_CORE_ONLY
