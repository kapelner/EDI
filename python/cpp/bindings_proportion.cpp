// Binds proportion-outcome model-fitting kernels (beta regression, zero-one-inflated beta).

#include <pybind11/pybind11.h>
#include <pybind11/eigen.h>
#include <pybind11/stl.h>
#include "_helper_functions_core.h"
#include <optional>
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
        out["iterations"] = res.iterations;
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
    "Returned 'b' is [beta, log_phi] (phi optimized on the log scale for\n"
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
    "    Optional indices of fixed parameters.\n"
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
                                             std::optional<Eigen::MatrixXd> warm_start_fisher_info) {
        LikelihoodFitResult fit = fast_zero_one_inflated_beta_internal(
            X, X_zero_one, y, warm_start_params, smart_cold_start,
            fixed_idx, fixed_values, optimization_alg, warm_start_fisher_info);
        py::dict out;
        out["params"] = fit.params;
        out["neg_loglik"] = fit.value;
        out["iterations"] = fit.niter;
        out["converged"] = fit.converged;
        out["gradient_norm"] = fit.gradient_norm;
        return out;
    },
    py::arg("X"), py::arg("X_zero_one"), py::arg("y"),
    py::arg("warm_start_params") = py::none(),
    py::arg("smart_cold_start") = true,
    py::arg("fixed_idx") = py::none(),
    py::arg("fixed_values") = py::none(),
    py::arg("optimization_alg") = "lbfgs",
    py::arg("warm_start_fisher_info") = py::none(),
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
    "    Optional indices of fixed parameters.\n"
    "fixed_values : ndarray, optional\n"
    "    Optional values for fixed parameters.\n"
    "optimization_alg : str, default \"lbfgs\"\n"
    "    Optimization algorithm.\n"
    "warm_start_fisher_info : ndarray, optional\n"
    "    Optional initial Fisher information matrix for the first iteration.");
}
