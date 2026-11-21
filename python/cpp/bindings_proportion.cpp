// Binds proportion-outcome model-fitting kernels (beta regression, zero-one-inflated beta).

#include <pybind11/pybind11.h>
#include <pybind11/eigen.h>
#include <pybind11/stl.h>
#include "_helper_functions_core.h"
#include "result_map_pybind.h"
#include <optional>
#include <limits>
#include <string>

namespace py = pybind11;

ModelResult fast_beta_regression_internal(
    const Eigen::Ref<const Eigen::MatrixXd>& X,
    const Eigen::Ref<const Eigen::VectorXd>& y,
    const Eigen::VectorXd* weights,
    const Eigen::VectorXd* warm_start_beta,
    bool smart_cold_start,
    double start_phi,
    std::optional<Eigen::VectorXi> fixed_idx,
    std::optional<Eigen::VectorXd> fixed_values,
    std::string optimization_alg,
    std::optional<Eigen::MatrixXd> warm_start_fisher_info,
    bool estimate_only
);

LikelihoodFitResult fast_zero_one_inflated_beta_internal(
    const Eigen::Ref<const Eigen::MatrixXd>& X,
    const Eigen::Ref<const Eigen::MatrixXd>& X_zero_one,
    const Eigen::Ref<const Eigen::VectorXd>& y_eigen,
    std::optional<Eigen::VectorXd> warm_start_params,
    bool smart_cold_start,
    std::optional<Eigen::VectorXi> fixed_idx,
    std::optional<Eigen::VectorXd> fixed_values,
    std::string optimization_alg,
    std::optional<Eigen::MatrixXd> warm_start_fisher_info
);

// Defined in R/EDI/src/fast_zero_one_inflated_beta.cpp and shared with the R
// export fast_zero_one_inflated_beta_cpp, so both return the same fields
// (audit decision rpy-parity-d1f65c8c0).
edi::ResultMap fast_zero_one_inflated_beta_result_internal(
    const Eigen::Ref<const Eigen::MatrixXd>& X,
    const Eigen::Ref<const Eigen::MatrixXd>& X_zero_one,
    const Eigen::Ref<const Eigen::VectorXd>& y_eigen,
    std::optional<Eigen::VectorXd> warm_start_params,
    bool smart_cold_start,
    std::optional<Eigen::VectorXi> fixed_idx,
    std::optional<Eigen::VectorXd> fixed_values,
    std::string optimization_alg,
    std::optional<Eigen::MatrixXd> warm_start_fisher_info,
    bool estimate_only,
    double vcov_missing
);

void bind_proportion(py::module_& m) {
    m.def("fast_beta_regression", [](const Eigen::Ref<const Eigen::MatrixXd>& X,
                                      const Eigen::Ref<const Eigen::VectorXd>& y,
                                      std::optional<Eigen::VectorXd> weights,
                                      std::optional<Eigen::VectorXd> warm_start_beta,
                                      bool smart_cold_start,
                                      double start_phi,
                                      std::optional<Eigen::VectorXi> fixed_idx,
                                      std::optional<Eigen::VectorXd> fixed_values,
                                      std::string optimization_alg,
                                      std::optional<Eigen::MatrixXd> warm_start_fisher_info,
                                      bool estimate_only) {
        ModelResult res = fast_beta_regression_internal(
            X, y,
            weights.has_value() ? &(*weights) : nullptr,
            warm_start_beta.has_value() ? &(*warm_start_beta) : nullptr,
            smart_cold_start, start_phi,
            fixed_idx, fixed_values, optimization_alg, warm_start_fisher_info, estimate_only);
        py::dict out;
        out["b"] = res.b;
        out["mu"] = res.mu;
        out["XtWX"] = res.XtWX;
        out["converged"] = res.converged;
        out["neg_loglik"] = res.neg_ll;
        out["dispersion"] = res.dispersion;
        out["num_iter"] = res.num_iter;
        out["hit_iteration_cap"] = res.hit_iteration_cap;
        out["gradient_norm"] = res.gradient_norm;
        return out;
    },
    py::arg("X"), py::arg("y"),
    py::arg("weights") = py::none(),
    py::arg("warm_start_beta") = py::none(),
    py::arg("smart_cold_start") = true,
    py::arg("start_phi") = 10.0,
    py::arg("fixed_idx") = py::none(),
    py::arg("fixed_values") = py::none(),
    py::arg("optimization_alg") = "lbfgs",
    py::arg("warm_start_fisher_info") = py::none(),
    py::arg("estimate_only") = false,
    "Fits Ferrari and Cribari-Neto's (2004) beta regression by maximum\n"
    "likelihood via L-BFGS, for a continuous proportion response strictly in\n"
    "(0, 1): Y_i ~ Beta(mu_i*phi, (1-mu_i)*phi) in the mean/precision\n"
    "parameterization (mean E[Y_i]=mu_i, Var(Y_i)=mu_i*(1-mu_i)/(1+phi)),\n"
    "with logit(mu_i) = x_i^T beta and a single scalar precision phi shared\n"
    "across all observations (not modeled as a function of covariates).\n"
    "Returned 'b' is beta only (phi is returned as 'dispersion', optimized on the log scale for\n"
    "positivity). Parameters sourced from R/EDI/man/ documentation for\n"
    "fast_beta_regression_cpp/fast_beta_regression_weighted_cpp. Analogous to\n"
    "statsmodels' BetaModel (link=logit) or R's betareg::betareg; see\n"
    "https://www.statsmodels.org/stable/generated/statsmodels.othermod.betareg.BetaModel.html.\n\n"
    "Parameters\n"
    "----------\n"
    "X : ndarray\n"
    "    A numeric matrix of predictors.\n"
    "y : ndarray\n"
    "    A numeric vector of responses (in (0, 1)).\n"
    "weights : ndarray, optional\n"
    "    Optional nonnegative row weights; if provided, routes to the weighted\n"
    "    fit backend.\n"
    "warm_start_beta : ndarray, optional\n"
    "    Optional starting values for coefficients. If provided,\n"
    "    smart_cold_start is ignored.\n"
    "smart_cold_start : bool, default True\n"
    "    If True, use an initial OLS-based guess when starting from scratch (a\n"
    "    \"cold start\") with no prior knowledge. Ignored if a warm start is\n"
    "    provided.\n"
    "start_phi : float, default 10.0\n"
    "    Optional starting value for the precision parameter phi.\n"
    "fixed_idx : ndarray of int, optional\n"
    "    Optional 1-based indices of fixed parameters.\n"
    "fixed_values : ndarray, optional\n"
    "    Optional values for fixed parameters.\n"
    "optimization_alg : str, default \"lbfgs\"\n"
    "    Optimization algorithm.\n"
    "warm_start_fisher_info : ndarray, optional\n"
    "    Optional initial Fisher information matrix.\n"
    "estimate_only : bool, default False\n"
    "    If True, skip Fisher information / variance calculation.");

    m.def("fast_zero_one_inflated_beta", [](const Eigen::Ref<const Eigen::MatrixXd>& X,
                                             const Eigen::Ref<const Eigen::MatrixXd>& X_zero_one,
                                             const Eigen::Ref<const Eigen::VectorXd>& y,
                                             std::optional<Eigen::VectorXd> warm_start_params,
                                             bool smart_cold_start,
                                             std::optional<Eigen::VectorXi> fixed_idx,
                                             std::optional<Eigen::VectorXd> fixed_values,
                                             std::string optimization_alg,
                                             std::optional<Eigen::MatrixXd> warm_start_fisher_info,
                                             bool estimate_only) {
        return edi::to_py_dict(fast_zero_one_inflated_beta_result_internal(
            X, X_zero_one, y, warm_start_params, smart_cold_start,
            fixed_idx, fixed_values, optimization_alg, warm_start_fisher_info,
            estimate_only, std::numeric_limits<double>::quiet_NaN()));
    },
    py::arg("X"), py::arg("X_zero_one"), py::arg("y"),
    py::arg("warm_start_params") = py::none(),
    py::arg("smart_cold_start") = true,
    py::arg("fixed_idx") = py::none(),
    py::arg("fixed_values") = py::none(),
    py::arg("optimization_alg") = "lbfgs",
    py::arg("warm_start_fisher_info") = py::none(),
    py::arg("estimate_only") = false,
    "Fits a zero-one-inflated beta regression by maximum likelihood via\n"
    "L-BFGS, for a proportion response on the closed interval [0, 1]\n"
    "(observable exact 0s and 1s, unlike plain beta regression which requires\n"
    "y strictly in (0,1)): a three-part mixture with P(Y_i=0) = pi0_i,\n"
    "P(Y_i=1) = pi1_i, and P(Y_i in (0,1)) = 1 - pi0_i - pi1_i times a\n"
    "Beta(mu_i*phi, (1-mu_i)*phi) density on that continuous part (same\n"
    "mean/precision beta parameterization as fast_beta_regression, with\n"
    "logit(mu_i) = x_i^T beta). The zero/one-inflation probabilities pi0_i,\n"
    "pi1_i are themselves modeled via a link function of X_zero_one\n"
    "(typically a multinomial/logistic sub-model over {zero, one,\n"
    "continuous}). Returned 'params' packs [beta, log_phi,\n"
    "zero_one_inflation_params]; see R/EDI/src/fast_zero_one_inflated_beta.cpp\n"
    "for the exact parameter block layout. Parameters sourced from\n"
    "R/EDI/man/ documentation for fast_zero_one_inflated_beta_cpp. Analogous\n"
    "to R's gamlss (family=BEINF) for zero-one-inflated beta regression (no\n"
    "widely-used single-call Python equivalent).\n\n"
    "Parameters\n"
    "----------\n"
    "X : ndarray\n"
    "    Matrix of predictors for the beta component.\n"
    "X_zero_one : ndarray\n"
    "    Matrix of predictors for the zero- and one-inflation components.\n"
    "y : ndarray\n"
    "    Vector of responses in [0, 1].\n"
    "warm_start_params : ndarray, optional\n"
    "    Optional starting values for all parameters. If provided,\n"
    "    smart_cold_start is ignored.\n"
    "smart_cold_start : bool, default True\n"
    "    If True, use an initial OLS-based guess when starting from scratch (a\n"
    "    \"cold start\") with no prior knowledge. Ignored if a warm start is\n"
    "    provided.\n"
    "fixed_idx : ndarray of int, optional\n"
    "    Optional 1-based indices into params of parameters to hold fixed (as in\n"
    "    R). 0 or an out-of-range index raises.\n"
    "fixed_values : ndarray, optional\n"
    "    Optional values for fixed parameters.\n"
    "optimization_alg : str, default \"lbfgs\"\n"
    "    Optimization algorithm.\n"
    "warm_start_fisher_info : ndarray, optional\n"
    "    Optional initial Fisher information matrix for the first iteration.\n"
    "estimate_only : bool, default False\n"
    "    If True, skip the post-fit observed-information / vcov computation.\n\n"
    "The solver's iteration cap and tolerance are fixed (1500 iterations,\n"
    "gradient-norm tolerance 1e-6) and are not arguments, as in R.\n\n"
    "Returns\n"
    "-------\n"
    "dict with the same fields as R's fast_zero_one_inflated_beta_cpp: b (beta),\n"
    "log_phi, zero_one_b0 / zero_one_b1 (the zero- and one-inflation\n"
    "coefficients), params (the full joint vector [b, log_phi, zero_one_b0,\n"
    "zero_one_b1]), neg_loglik, converged, num_iter, hit_iteration_cap,\n"
    "gradient_norm and min_eigenvalue_information; unless estimate_only=True,\n"
    "also vcov (joint variance-covariance matrix of params; all nan where R\n"
    "returns all NA, i.e. when the observed information is non-finite or its\n"
    "free block is singular), observed_information, fisher_information and\n"
    "information (three names for the same observed-information matrix),\n"
    "information_type ('observed') and hessian (minus that matrix).");
}
