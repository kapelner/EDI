#ifndef EDI_ORDINAL_FIXED_LINK_INTERNAL_H
#define EDI_ORDINAL_FIXED_LINK_INTERNAL_H

// Shared fit + vcov pipeline for the fixed-link cumulative ordinal kernels
// (cauchit, cloglog, probit). v1.0.7-TODO-54 (code-duplication audit
// families dup-5997356561a2 and dup-b84f50f38a71): the three *_internal
// functions and their score / Hessian exports were near-identical copies.
//
// The v1.0.7-TODO-54 merge kept the places where the three copies had
// drifted apart as FixedLinkFitSpec policy flags. v1.0.6-TODO-144 replaced
// them with one behavior for all three links:
//   * inputs (warm_start_fisher_info, fixed_idx / fixed_values,
//     warm_start_params) are validated before any early return (cauchit used
//     to return before validating);
//   * degenerate y (fewer than 2 levels) returns an empty ResultMap (probit
//     had no such early return and fitted a model with no thresholds);
//   * a non-finite or non-positive ssq_b_j is reported as NaN (cauchit and
//     cloglog used to pass it through);
//   * the *_with_var_cpp exports return list(b = NA, ssq_b_2 = NA) for
//     degenerate y (probit returned the empty list); see
//     fixed_link_ordinal_with_var_list().
//
// Lives in its own header (not ordinal_fixed_link_helpers.h) because
// _helper_functions_core.h includes ordinal_fixed_link_helpers.h, while this
// template needs FixedParamSpec, OrdinalStart, optimize_fixed_likelihood and
// edi::ResultMap from the core helpers. Include it after the kernel's own
// _helper_functions / result_map includes.

#ifdef EDI_CORE_ONLY
#include "_helper_functions_core.h"
#include "result_map.h"
#else
#include "_helper_functions.h"
#include "result_map_rcpp.h"
#include <Rcpp.h>
#include <RcppEigen.h>
#endif
#include "ordinal_fixed_link_helpers.h"
#include "ordinal_scale_guard.h"
#include <limits>
#include <optional>
#include <stdexcept>
#include <string>
#include <utility>
#include <variant>

namespace edi_ordinal {

template <Link link>
class UnweightedOrdinalRegression : public FixedOrdinalRegression {
public:
    UnweightedOrdinalRegression(const Eigen::Ref<const Eigen::MatrixXd>& X,
                                const Eigen::Ref<const Eigen::VectorXd>& y) :
        FixedOrdinalRegression(X, y, link, -1.0) {}

    static std::vector<double> init_levels(const Eigen::Ref<const Eigen::VectorXd>& y) {
        return edi_ordinal::init_levels(y);
    }
};


struct FixedLinkFitSpec {
    Link link;
    // Legacy cold-start threshold k (0-based) out of K levels.
    double (*legacy_alpha)(int k, int K);
};

template <class Model>
edi::ResultMap fixed_link_ordinal_internal(
    const FixedLinkFitSpec& spec,
    const Eigen::Ref<const Eigen::MatrixXd>& X,
    const Eigen::Ref<const Eigen::VectorXd>& y,
    std::optional<Eigen::VectorXd> warm_start_params,
    bool smart_cold_start,
    int maxit,
    double tol,
    std::string optimization_alg,
    std::optional<Eigen::VectorXi> fixed_idx,
    std::optional<Eigen::VectorXd> fixed_values,
    std::optional<Eigen::MatrixXd> warm_start_fisher_info,
    bool estimate_only
) {
    using Eigen::MatrixXd;
    using Eigen::VectorXd;

    Model model(X, y);
    const int p = (int)X.cols();
    const int K = (int)init_levels(y).size();
    const int n_alpha = K > 1 ? K - 1 : 0;
    const int n_params = n_alpha + p;

    // v1.0.6-TODO-144: validate every input first, then the K < 2 early return.
    require_square_matrix(warm_start_fisher_info, n_params, "warm_start_fisher_info");
    FixedParamSpec fixed_spec = make_fixed_param_spec(n_params, fixed_idx, fixed_values);
    if (warm_start_params.has_value() && warm_start_params->size() != n_params)
        throw std::invalid_argument("warm_start_params must have length equal to the number of model parameters");
    if (K < 2) return edi::ResultMap();

    VectorXd params(n_params);
    if (warm_start_params.has_value()) {
        params = *warm_start_params;
    } else {
        OrdinalStart legacy_start;
        legacy_start.alpha = VectorXd(n_alpha);
        for (int k = 0; k < n_alpha; ++k) {
            legacy_start.alpha[k] = spec.legacy_alpha(k, K);
        }
        legacy_start.beta = VectorXd::Zero(p);
        params = ordinal_start_to_params(
            smart_cold_start ? ordinal_smart_cold_start_or_legacy(X, y, spec.link, legacy_start, fixed_spec)
                        : legacy_start
        );
    }

    params = apply_fixed_values(params, fixed_spec);

    MatrixXd info_start;
    const MatrixXd* info_start_ptr = nullptr;
    if (warm_start_fisher_info.has_value()) {
        info_start = *warm_start_fisher_info;
        info_start_ptr = &info_start;
    }

    LikelihoodFitResult fit = optimize_fixed_likelihood(model, params, fixed_spec, maxit, tol, optimization_alg, "lbfgs", 0, info_start_ptr);
    params = fit.params;
    if (fit.converged && ordinal_covariates_badly_scaled(X) &&
        !ordinal_newton_decrement_ok(model, fit.params, fixed_spec, tol)) fit.converged = false;

    if (estimate_only) {
        return edi::ResultMap()
            .set("b", params.tail(p))
            .set("alpha", params.head(n_alpha))
            .set("n_params", n_params)
            .set("params", params)
            .set("converged", fit.converged)
            .set("num_iter", fit.niter)
            .set("hit_iteration_cap", fit.hit_iteration_cap)
            .set("gradient_norm", fit.gradient_norm)
            .set("min_eigenvalue_information", fit.min_eigenvalue_information);
    }

    MatrixXd H_full = model.hessian(params);

    double ssq_b_2 = std::numeric_limits<double>::quiet_NaN();
    MatrixXd vcov;
    bool have_vcov = false;
    if (fit.converged) {
        FixedParameterFunctor<Model> fixed_obj(model, fixed_spec, params);
        VectorXd params_free = subset_vector(params, fixed_spec.free_idx);
        MatrixXd H_free = fixed_obj.hessian(params_free);
        const int n_alpha2 = n_params - p;
        int free_j = -1;
        for (int jj = 0; jj < (int)fixed_spec.free_idx.size(); ++jj)
            if (fixed_spec.free_idx[jj] == n_alpha2) { free_j = jj + 1; break; }
        if (p >= 1 && free_j > 0) {
            ssq_b_2 = compute_diagonal_inverse_entry(H_free, free_j);
            if (!std::isfinite(ssq_b_2) || ssq_b_2 <= 0)
                ssq_b_2 = std::numeric_limits<double>::quiet_NaN();
        }
        MatrixXd cov_free = covariance_from_information(H_free);
        vcov = expand_free_covariance(n_params, fixed_spec, cov_free, true);
        have_vcov = true;
    }

    edi::ResultMap rm = edi::ResultMap()
        .set("b", params.tail(p))
        .set("alpha", params.head(n_alpha))
        .set("n_params", n_params)
        .set("params", params)
        .set("neg_loglik", fit.value)
        .set("converged", fit.converged)
        .set("num_iter", fit.niter)
        .set("hit_iteration_cap", fit.hit_iteration_cap)
        .set("gradient_norm", fit.gradient_norm)
        .set("min_eigenvalue_information", fit.min_eigenvalue_information)
        .set("ssq_b_j", ssq_b_2)
        .set("observed_information", H_full)
        .set("information", H_full)
        .set("information_type", std::string("observed"));
    if (have_vcov) {
        rm.set("vcov", vcov);
    } else {
        rm.set("vcov", std::monostate{});
    }
    return rm;
}

#ifndef EDI_CORE_ONLY
// The *_with_var_cpp exports' result: degenerate y (the fit is an empty
// ResultMap) gives list(b = NA, ssq_b_2 = NA) for all three links
// (v1.0.6-TODO-144).
inline Rcpp::List fixed_link_ordinal_with_var_list(const edi::ResultMap& res) {
    if (res.entries().empty())
        return edi::to_rcpp_list(edi::ResultMap().set("b", NA_REAL).set("ssq_b_2", NA_REAL));
    return edi::to_rcpp_list(res);
}

// Score (gradient of the log-likelihood) at params, with any fixed entries
// overwritten by fixed_values first. Shared by the three *_score_cpp exports.
template <class Model>
Eigen::VectorXd fixed_link_ordinal_score(const Rcpp::NumericMatrix& X,
                                         const Rcpp::NumericVector& y,
                                         const Rcpp::NumericVector& params,
                                         Rcpp::Nullable<Rcpp::IntegerVector> fixed_idx,
                                         Rcpp::Nullable<Rcpp::NumericVector> fixed_values) {
    Eigen::Map<const Eigen::MatrixXd> map_X(X.begin(), X.rows(), X.cols());
    Eigen::Map<const Eigen::VectorXd> map_y(y.begin(), y.size());
    Eigen::Map<const Eigen::VectorXd> map_params(params.begin(), params.size());

    Model model(map_X, map_y);
    FixedParamSpec fixed_spec = make_fixed_param_spec(
        map_params.size(),
        nullable_to_optional<Eigen::VectorXi>(fixed_idx),
        nullable_to_optional<Eigen::VectorXd>(fixed_values));
    Eigen::VectorXd par = apply_fixed_values(map_params, fixed_spec);
    Eigen::VectorXd grad(par.size());
    model(par, grad);
    return -grad;
}

// Hessian of the log-likelihood (negative observed information) at params.
// Shared by the three *_hessian_cpp exports.
template <class Model>
Eigen::MatrixXd fixed_link_ordinal_hessian(const Rcpp::NumericMatrix& X,
                                           const Rcpp::NumericVector& y,
                                           const Rcpp::NumericVector& params,
                                           Rcpp::Nullable<Rcpp::IntegerVector> fixed_idx,
                                           Rcpp::Nullable<Rcpp::NumericVector> fixed_values) {
    Eigen::Map<const Eigen::MatrixXd> map_X(X.begin(), X.rows(), X.cols());
    Eigen::Map<const Eigen::VectorXd> map_y(y.begin(), y.size());
    Eigen::Map<const Eigen::VectorXd> map_params(params.begin(), params.size());

    Model model(map_X, map_y);
    FixedParamSpec fixed_spec = make_fixed_param_spec(
        map_params.size(),
        nullable_to_optional<Eigen::VectorXi>(fixed_idx),
        nullable_to_optional<Eigen::VectorXd>(fixed_values));
    Eigen::VectorXd par = apply_fixed_values(map_params, fixed_spec);
    return -model.hessian(par);
}
#endif // EDI_CORE_ONLY

}  // namespace edi_ordinal

#endif // EDI_ORDINAL_FIXED_LINK_INTERNAL_H
