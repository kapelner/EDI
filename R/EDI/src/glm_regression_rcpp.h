#ifndef EDI_GLM_REGRESSION_RCPP_H
#define EDI_GLM_REGRESSION_RCPP_H

#include "_helper_functions.h"
#include "result_map_rcpp.h"

namespace edi_glm {

template <typename Fit>
inline ModelResult fit_unweighted(
    Fit fit, const Eigen::Map<Eigen::MatrixXd>& X, SEXP y,
    const Rcpp::Nullable<Rcpp::NumericVector>& warm_start_beta, bool smart_cold_start,
    int maxit, double tol, const Rcpp::Nullable<Rcpp::IntegerVector>& fixed_idx,
    const Rcpp::Nullable<Rcpp::NumericVector>& fixed_values, const std::string& optimization_alg,
    const Rcpp::Nullable<Rcpp::NumericVector>& warm_start_weights,
    const Rcpp::Nullable<Rcpp::NumericMatrix>& warm_start_fisher_info, bool estimate_only) {
    // NumericVector also coerces integer responses, such as rbinom() draws.
    Rcpp::NumericVector y_numeric(y);
    Eigen::Map<const Eigen::VectorXd> response(y_numeric.begin(), y_numeric.size());
    return fit(X, response, Eigen::VectorXd(), nullable_to_optional<Eigen::VectorXd>(warm_start_beta),
               smart_cold_start, maxit, tol, nullable_to_optional<Eigen::VectorXi>(fixed_idx),
               nullable_to_optional<Eigen::VectorXd>(fixed_values), optimization_alg,
               nullable_to_optional<Eigen::VectorXd>(warm_start_weights),
               nullable_to_optional<Eigen::MatrixXd>(warm_start_fisher_info), estimate_only);
}

inline Rcpp::List estimate_result(const ModelResult& res) {
    return edi::to_rcpp_list(edi::ResultMap()
        .set("b", res.b)
        .set("converged", res.converged)
        .set("num_iter", res.num_iter)
        .set("hit_iteration_cap", res.hit_iteration_cap)
        .set("gradient_norm", res.gradient_norm)
        .set("min_eigenvalue_information", res.min_eigenvalue_information));
}

inline Rcpp::List binary_fit_result(const ModelResult& res, const Eigen::VectorXd& weights) {
    return edi::to_rcpp_list(edi::ResultMap()
        .set("b", res.b)
        .set("w", weights)
        .set("num_iter", res.num_iter)
        .set("hit_iteration_cap", res.hit_iteration_cap)
        .set("fisher_information", res.XtWX)
        .set("score", res.score)
        .set("neg_ll", res.neg_ll)
        .set("converged", res.converged)
        .set("gradient_norm", res.gradient_norm)
        .set("min_eigenvalue_information", res.min_eigenvalue_information));
}

inline Rcpp::List fit_result_with_mean(const ModelResult& res, const int* num_step_halvings = nullptr) {
    edi::ResultMap result;
    result.set("b", res.b)
        .set("mu", res.mu)
        .set("XtWX", res.XtWX)
        .set("fisher_information", res.XtWX)
        .set("score", res.score)
        .set("neg_ll", res.neg_ll)
        .set("converged", res.converged)
        .set("num_iter", res.num_iter)
        .set("hit_iteration_cap", res.hit_iteration_cap)
        .set("gradient_norm", res.gradient_norm)
        .set("min_eigenvalue_information", res.min_eigenvalue_information);
    if (num_step_halvings) result.set("num_step_halvings", *num_step_halvings);
    return edi::to_rcpp_list(result);
}

inline void add_convergence(edi::ResultMap& result, const ModelResult& res) {
    result.set("converged", res.converged)
        .set("num_iter", res.num_iter)
        .set("hit_iteration_cap", res.hit_iteration_cap);
}

inline Rcpp::List variance_result(
    const ModelResult& res, int ncols, int j, const FixedParamSpec& fixed_spec, bool include_mean) {
    const Eigen::MatrixXd info_free = subset_matrix(res.XtWX, fixed_spec.free_idx, fixed_spec.free_idx);
    const auto coefficient_variance = [&](int column) {
        if (column > 0 && column <= ncols) {
            for (int k = 0; k < static_cast<int>(fixed_spec.free_idx.size()); ++k) {
                if (fixed_spec.free_idx[k] == column - 1) {
                    return compute_diagonal_inverse_entry(info_free, k + 1);
                }
            }
        }
        return NA_REAL;
    };

    edi::ResultMap result;
    result.set("b", res.b)
        .set("params", res.b)
        .set("ssq_b_j", coefficient_variance(j))
        .set("ssq_b_2", coefficient_variance(2));
    // The Poisson result includes the fitted mean and places diagnostics before score.
    if (include_mean) {
        result.set("mu", res.mu);
        add_convergence(result, res);
    }
    const Eigen::MatrixXd neg_information = -res.XtWX;
    result.set("score", res.score)
        .set("observed_information", res.XtWX)
        .set("fisher_information", res.XtWX)
        .set("information", res.XtWX)
        .set("information_type", std::string("fisher"))
        .set("hessian", neg_information)
        .set("neg_loglik", res.neg_ll)
        .set("neg_ll", res.neg_ll)
        .set("loglik", R_finite(res.neg_ll) ? -res.neg_ll : NA_REAL);
    if (!include_mean) add_convergence(result, res);
    result.set("gradient_norm", res.gradient_norm)
        .set("min_eigenvalue_information", res.min_eigenvalue_information);
    return edi::to_rcpp_list(result);
}

} // namespace edi_glm

#endif
