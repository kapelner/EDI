// Binds binary-outcome model-fitting kernels (logistic, probit).

#include <pybind11/pybind11.h>
#include <pybind11/eigen.h>
#include <pybind11/stl.h>
#include "_helper_functions_core.h"
#include "result_map_pybind.h"
#include <optional>
#include <string>

namespace py = pybind11;

enum class BinomialConstrainedLink {
  kLog = 0,
  kIdentity = 1
};

edi::ResultMap fit_constrained_binomial_cpp_impl(
    const Eigen::Ref<const Eigen::MatrixXd>& X,
    const Eigen::Ref<const Eigen::VectorXd>& y,
    BinomialConstrainedLink link_type,
    int maxit,
    double tol,
    std::optional<Eigen::VectorXi> fixed_idx,
    std::optional<Eigen::VectorXd> fixed_values,
    std::optional<Eigen::VectorXd> warm_start_beta,
    bool smart_cold_start,
    std::optional<Eigen::VectorXd> warm_start_weights,
    std::optional<Eigen::MatrixXd> warm_start_fisher_info,
    bool estimate_only
);

edi::ResultMap fit_constrained_binomial_weighted_cpp_impl(
    const Eigen::Ref<const Eigen::MatrixXd>& X,
    const Eigen::Ref<const Eigen::VectorXd>& y,
    const Eigen::VectorXd& obs_weights,
    BinomialConstrainedLink link_type,
    int maxit,
    double tol,
    std::optional<Eigen::VectorXi> fixed_idx,
    std::optional<Eigen::VectorXd> fixed_values,
    std::optional<Eigen::VectorXd> warm_start_beta,
    bool smart_cold_start,
    std::optional<Eigen::VectorXd> warm_start_weights,
    std::optional<Eigen::MatrixXd> warm_start_fisher_info,
    bool estimate_only
);

edi::ResultMap fit_constrained_binomial_with_var_cpp_impl(
    const Eigen::Ref<const Eigen::MatrixXd>& X,
    const Eigen::Ref<const Eigen::VectorXd>& y,
    BinomialConstrainedLink link_type,
    int j,
    int maxit,
    double tol,
    std::optional<Eigen::VectorXi> fixed_idx,
    std::optional<Eigen::VectorXd> fixed_values,
    std::optional<Eigen::VectorXd> warm_start_beta,
    bool smart_cold_start,
    std::optional<Eigen::VectorXd> warm_start_weights,
    std::optional<Eigen::MatrixXd> warm_start_fisher_info
);

static void bind_constrained_binomial(py::module_& m, const char* name,
                                       const char* name_with_var,
                                       BinomialConstrainedLink link_type,
                                       const char* doc, const char* doc_with_var) {
    // No R-side roxygen documents either raw kernel directly
    // (fast_log_binomial_regression.cpp has none); parameters follow the same
    // conventions used throughout this module. Built as named locals (not
    // temporaries in the m.def() argument list below) so their lifetime
    // unambiguously covers both m.def() calls regardless of exactly when
    // pybind11 copies the C string (it does so immediately via strdup, but
    // this removes any doubt).
    const std::string full_doc = std::string(doc) +
        "\n\n"
        "Parameters\n"
        "----------\n"
        "X : ndarray\n"
        "    Numeric matrix of predictors (including intercept column).\n"
        "y : ndarray\n"
        "    Numeric vector of binary (0/1) responses.\n"
        "weights : ndarray, optional\n"
        "    Optional nonnegative row weights; if provided, routes to the weighted\n"
        "    fit backend.\n"
        "maxit : int, default 100\n"
        "    Maximum number of iterations.\n"
        "tol : float, default 1e-6\n"
        "    Convergence tolerance.\n"
        "fixed_idx : ndarray of int, optional\n"
        "    Optional indices of coefficients to hold fixed at fixed_values rather\n"
        "    than estimate.\n"
        "fixed_values : ndarray, optional\n"
        "    Optional values for the fixed_idx coefficients.\n"
        "warm_start_beta : ndarray, optional\n"
        "    Optional starting values for coefficients. If provided,\n"
        "    smart_cold_start is ignored.\n"
        "smart_cold_start : bool, default True\n"
        "    If True, use an initial OLS-based guess when starting from scratch.\n"
        "    Ignored if a warm start is provided.\n"
        "warm_start_weights : ndarray, optional\n"
        "    Optional initial working weights for the first iteration.\n"
        "warm_start_fisher_info : ndarray, optional\n"
        "    Optional initial Fisher information matrix for the first iteration.\n"
        "estimate_only : bool, default False\n"
        "    If True, skip variance-component calculations and return only the\n"
        "    point estimate.";
    const std::string full_doc_with_var = std::string(doc_with_var) +
        "\n\n"
        "Parameters\n"
        "----------\n"
        "X : ndarray\n"
        "    Numeric matrix of predictors (including intercept column).\n"
        "y : ndarray\n"
        "    Numeric vector of binary (0/1) responses.\n"
        "j : int, default 2\n"
        "    1-based index of the coefficient whose individual variance (ssq_b_j)\n"
        "    is returned.\n"
        "maxit : int, default 100\n"
        "    Maximum number of iterations.\n"
        "tol : float, default 1e-6\n"
        "    Convergence tolerance.\n"
        "fixed_idx : ndarray of int, optional\n"
        "    Optional indices of coefficients to hold fixed at fixed_values rather\n"
        "    than estimate.\n"
        "fixed_values : ndarray, optional\n"
        "    Optional values for the fixed_idx coefficients.\n"
        "warm_start_beta : ndarray, optional\n"
        "    Optional starting values for coefficients. If provided,\n"
        "    smart_cold_start is ignored.\n"
        "smart_cold_start : bool, default True\n"
        "    If True, use an initial OLS-based guess when starting from scratch.\n"
        "    Ignored if a warm start is provided.\n"
        "warm_start_weights : ndarray, optional\n"
        "    Optional initial working weights for the first iteration.\n"
        "warm_start_fisher_info : ndarray, optional\n"
        "    Optional initial Fisher information matrix for the first iteration.";

    m.def(name, [link_type](const Eigen::Ref<const Eigen::MatrixXd>& X,
                             const Eigen::Ref<const Eigen::VectorXd>& y,
                             std::optional<Eigen::VectorXd> weights,
                             int maxit,
                             double tol,
                             std::optional<Eigen::VectorXi> fixed_idx,
                             std::optional<Eigen::VectorXd> fixed_values,
                             std::optional<Eigen::VectorXd> warm_start_beta,
                             bool smart_cold_start,
                             std::optional<Eigen::VectorXd> warm_start_weights,
                             std::optional<Eigen::MatrixXd> warm_start_fisher_info,
                             bool estimate_only) {
        edi::ResultMap res = weights.has_value()
            ? fit_constrained_binomial_weighted_cpp_impl(
                  X, y, *weights, link_type, maxit, tol, fixed_idx, fixed_values,
                  warm_start_beta, smart_cold_start, warm_start_weights, warm_start_fisher_info,
                  estimate_only)
            : fit_constrained_binomial_cpp_impl(
                  X, y, link_type, maxit, tol, fixed_idx, fixed_values,
                  warm_start_beta, smart_cold_start, warm_start_weights, warm_start_fisher_info,
                  estimate_only);
        return edi::to_py_dict(res);
    },
    py::arg("X"), py::arg("y"),
    py::arg("weights") = py::none(),
    py::arg("maxit") = 100,
    py::arg("tol") = 1e-6,
    py::arg("fixed_idx") = py::none(),
    py::arg("fixed_values") = py::none(),
    py::arg("warm_start_beta") = py::none(),
    py::arg("smart_cold_start") = true,
    py::arg("warm_start_weights") = py::none(),
    py::arg("warm_start_fisher_info") = py::none(),
    py::arg("estimate_only") = false,
    full_doc.c_str());

    m.def(name_with_var, [link_type](const Eigen::Ref<const Eigen::MatrixXd>& X,
                                      const Eigen::Ref<const Eigen::VectorXd>& y,
                                      int j,
                                      int maxit,
                                      double tol,
                                      std::optional<Eigen::VectorXi> fixed_idx,
                                      std::optional<Eigen::VectorXd> fixed_values,
                                      std::optional<Eigen::VectorXd> warm_start_beta,
                                      bool smart_cold_start,
                                      std::optional<Eigen::VectorXd> warm_start_weights,
                                      std::optional<Eigen::MatrixXd> warm_start_fisher_info) {
        edi::ResultMap res = fit_constrained_binomial_with_var_cpp_impl(
            X, y, link_type, j, maxit, tol, fixed_idx, fixed_values,
            warm_start_beta, smart_cold_start, warm_start_weights, warm_start_fisher_info);
        return edi::to_py_dict(res);
    },
    py::arg("X"), py::arg("y"),
    py::arg("j") = 2,
    py::arg("maxit") = 100,
    py::arg("tol") = 1e-6,
    py::arg("fixed_idx") = py::none(),
    py::arg("fixed_values") = py::none(),
    py::arg("warm_start_beta") = py::none(),
    py::arg("smart_cold_start") = true,
    py::arg("warm_start_weights") = py::none(),
    py::arg("warm_start_fisher_info") = py::none(),
    full_doc_with_var.c_str());
}

ModelResult fast_logistic_regression_internal(
    const Eigen::Ref<const Eigen::MatrixXd>& X,
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
    bool estimate_only
);

ModelResult fast_probit_regression_internal(
    const Eigen::Ref<const Eigen::MatrixXd>& X_eigen,
    const Eigen::Ref<const Eigen::VectorXd>& y_eigen,
    const Eigen::Ref<const Eigen::VectorXd>& weights_eigen,
    std::optional<Eigen::VectorXd> warm_start_beta,
    bool smart_cold_start,
    int maxit,
    double tol,
    std::optional<Eigen::VectorXi> fixed_idx,
    std::optional<Eigen::VectorXd> fixed_values,
    std::string optimization_alg,
    std::optional<Eigen::VectorXd> warm_start_weights,
    std::optional<Eigen::MatrixXd> warm_start_fisher_info,
    bool estimate_only
);

static py::dict model_result_to_dict(const ModelResult& res) {
    py::dict out;
    out["b"] = res.b;
    out["mu"] = res.mu;
    out["XtWX"] = res.XtWX;
    out["score"] = res.score;
    out["neg_loglik"] = res.neg_ll;
    out["ssq_b_j"] = res.ssq_b_j;
    out["ssq_b_2"] = res.ssq_b_2;
    out["dispersion"] = res.dispersion;
    out["sigma2_hat"] = res.sigma2_hat;
    out["num_iter"] = res.num_iter;
    out["hit_iteration_cap"] = res.hit_iteration_cap;
    out["converged"] = res.converged;
    out["gradient_norm"] = res.gradient_norm;
    return out;
}

void bind_binary(py::module_& m) {
    m.def("fast_logistic_regression", [](const Eigen::Ref<const Eigen::MatrixXd>& X,
                                          const Eigen::Ref<const Eigen::VectorXd>& y,
                                          std::optional<Eigen::VectorXd> weights,
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
        ModelResult res = fast_logistic_regression_internal(
            X, y, weights.value_or(Eigen::VectorXd()), warm_start_beta, smart_cold_start, maxit, tol,
            fixed_idx, fixed_values, optimization_alg, warm_start_weights, warm_start_fisher_info, estimate_only);
        return model_result_to_dict(res);
    },
    py::arg("X"), py::arg("y"),
    py::arg("weights") = py::none(),
    py::arg("warm_start_beta") = py::none(),
    py::arg("smart_cold_start") = false,
    py::arg("maxit") = 100,
    py::arg("tol") = 1e-8,
    py::arg("fixed_idx") = py::none(),
    py::arg("fixed_values") = py::none(),
    py::arg("optimization_alg") = "irls",
    py::arg("warm_start_weights") = py::none(),
    py::arg("warm_start_fisher_info") = py::none(),
    py::arg("estimate_only") = false,
    "Fits binary logistic regression, Y_i ~ Bernoulli(expit(eta_i)),\n"
    "eta_i = x_i^T beta, by maximum likelihood. By default\n"
    "(optimization_alg=\"irls\"), fitting uses iteratively reweighted least\n"
    "squares with the canonical-link (Fisher-scoring) working weights\n"
    "w_i = mu_i*(1-mu_i) (mu_i = expit(eta_i)) and working response\n"
    "z_i = eta_i + (y_i - mu_i)/w_i: each iteration solves the weighted normal\n"
    "equations X^T W X delta = X^T W z, declaring convergence when either the\n"
    "score norm or the step norm falls below tol. Any optimization_alg other\n"
    "than \"lbfgs\" runs this IRLS path; optimization_alg=\"lbfgs\" instead\n"
    "minimizes the exact negative log-likelihood directly via a bespoke L-BFGS\n"
    "driver with backtracking strong-Wolfe line search, bypassing IRLS\n"
    "entirely (in that path, warm_start_fisher_info is not consulted).\n"
    "fixed_idx/fixed_values optionally hold a subset of coefficients fixed at\n"
    "caller-supplied constants (folded into the linear predictor as an offset)\n"
    "rather than estimated. This is the logistic-link sibling of\n"
    "fast_probit_regression, sharing the same argument list and IRLS/L-BFGS\n"
    "machinery (see that function's docstring, ported from its documented R\n"
    "sibling fast_probit_regression_cpp, for the fully-referenced probit\n"
    "analogue of this model). Analogous to statsmodels' Logit/GLM(family=\n"
    "Binomial()) with the logit link; see\n"
    "https://www.statsmodels.org/stable/glm.html.\n\n"
    "Parameters\n"
    "----------\n"
    "X : ndarray\n"
    "    Numeric matrix of predictors (including intercept column).\n"
    "y : ndarray\n"
    "    Numeric vector of binary (0/1) responses.\n"
    "weights : ndarray, optional\n"
    "    Optional nonnegative row weights for a weighted fit.\n"
    "warm_start_beta : ndarray, optional\n"
    "    Optional starting values for coefficients.\n"
    "smart_cold_start : bool, default False\n"
    "    If True, use an OLS-based initial guess when no warm start is provided.\n"
    "maxit : int, default 100\n"
    "    Maximum number of iterations.\n"
    "tol : float, default 1e-8\n"
    "    Convergence tolerance.\n"
    "fixed_idx : ndarray of int, optional\n"
    "    Optional indices of fixed parameters.\n"
    "fixed_values : ndarray, optional\n"
    "    Optional values for fixed parameters.\n"
    "optimization_alg : str, default \"irls\"\n"
    "    Optimization algorithm (\"irls\" or \"lbfgs\").\n"
    "warm_start_weights : ndarray, optional\n"
    "    Optional initial IRLS working weights.\n"
    "warm_start_fisher_info : ndarray, optional\n"
    "    Optional initial Fisher information matrix.\n"
    "estimate_only : bool, default False\n"
    "    If True, skip variance computation and return only coefficients.");

    m.def("fast_probit_regression", [](const Eigen::Ref<const Eigen::MatrixXd>& X,
                                        const Eigen::Ref<const Eigen::VectorXd>& y,
                                        std::optional<Eigen::VectorXd> weights,
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
        ModelResult res = fast_probit_regression_internal(
            X, y, weights.value_or(Eigen::VectorXd()), warm_start_beta, smart_cold_start, maxit, tol,
            fixed_idx, fixed_values, optimization_alg, warm_start_weights, warm_start_fisher_info, estimate_only);
        return model_result_to_dict(res);
    },
    py::arg("X"), py::arg("y"),
    py::arg("weights") = py::none(),
    py::arg("warm_start_beta") = py::none(),
    py::arg("smart_cold_start") = true,
    py::arg("maxit") = 100,
    py::arg("tol") = 1e-8,
    py::arg("fixed_idx") = py::none(),
    py::arg("fixed_values") = py::none(),
    py::arg("optimization_alg") = "irls",
    py::arg("warm_start_weights") = py::none(),
    py::arg("warm_start_fisher_info") = py::none(),
    py::arg("estimate_only") = false,
    "Fits binary probit regression, Y_i ~ Bernoulli(Phi(eta_i)),\n"
    "eta_i = x_i^T beta, by maximum likelihood, using a numerically stable\n"
    "log-scale evaluation of Phi (matching R's pnorm(log.p=True) via an\n"
    "erfc-based identity for |eta| < 6, falling back to a wider-range series\n"
    "approximation beyond that). By default (optimization_alg=\"irls\"),\n"
    "fitting uses iteratively reweighted least squares with working weights\n"
    "w_i = phi(eta_i)^2 / max(Phi(eta_i)*(1-Phi(eta_i)), 1e-15) (the standard\n"
    "probit Fisher-scoring weight) and generalized residual\n"
    "r_i = y_i*phi(eta_i)/Phi(eta_i) - (1-y_i)*phi(eta_i)/(1-Phi(eta_i)):\n"
    "each iteration solves X^T W X delta = X^T r via an LDLT decomposition and\n"
    "takes the full Newton step (no step-halving line search), declaring\n"
    "convergence when either the score norm or the step norm falls below tol.\n"
    "Any optimization_alg value other than \"lbfgs\" runs this IRLS path;\n"
    "optimization_alg=\"lbfgs\" instead minimizes the exact negative\n"
    "log-likelihood directly via a bespoke L-BFGS driver with backtracking\n"
    "strong-Wolfe line search (mirroring RcppNumerical's optim_lbfgs\n"
    "defaults), bypassing IRLS entirely -- in that path, warm_start_fisher_info\n"
    "is not consulted.\n\n"
    "fixed_idx/fixed_values optionally hold a subset of coefficients fixed at\n"
    "caller-supplied constant values (folded into the linear predictor as an\n"
    "offset) rather than estimated. warm_start_beta supplies starting\n"
    "coefficients directly; otherwise, if smart_cold_start=True (the default),\n"
    "an OLS fit of the probit-transformed response Phi^-1((y+0.5)/2) on X\n"
    "seeds the start. warm_start_fisher_info, if supplied, seeds the curvature\n"
    "matrix used for the IRLS path's very first iteration only (see above for\n"
    "the \"lbfgs\" exception). warm_start_weights is accepted for interface\n"
    "parity with sibling functions (e.g. fast_logistic_regression) but is not\n"
    "consulted anywhere in this function's fitting logic. Ported from the R\n"
    "sibling fast_probit_regression_cpp's documentation. Analogous to\n"
    "statsmodels' Probit/GLM(family=Binomial(link=probit())); see\n"
    "https://www.statsmodels.org/stable/glm.html.\n\n"
    "Parameters\n"
    "----------\n"
    "X : ndarray\n"
    "    A numeric matrix of predictors (including intercept column).\n"
    "y : ndarray\n"
    "    A numeric vector of binary responses (0/1).\n"
    "weights : ndarray, optional\n"
    "    Optional nonnegative row weights for a weighted fit.\n"
    "warm_start_beta : ndarray, optional\n"
    "    Optional starting values for coefficients.\n"
    "smart_cold_start : bool, default True\n"
    "    If True, use an OLS-based initial guess when no warm start is provided.\n"
    "maxit : int, default 100\n"
    "    Maximum number of iterations.\n"
    "tol : float, default 1e-8\n"
    "    Convergence tolerance.\n"
    "fixed_idx : ndarray of int, optional\n"
    "    Optional indices of fixed parameters.\n"
    "fixed_values : ndarray, optional\n"
    "    Optional values for fixed parameters.\n"
    "optimization_alg : str, default \"irls\"\n"
    "    Optimization algorithm (\"irls\" or \"lbfgs\").\n"
    "warm_start_weights : ndarray, optional\n"
    "    Optional initial IRLS working weights.\n"
    "warm_start_fisher_info : ndarray, optional\n"
    "    Optional initial Fisher information matrix.\n"
    "estimate_only : bool, default False\n"
    "    If True, skip variance computation and return only coefficients.");

    bind_constrained_binomial(m, "fast_log_binomial_regression", "fast_log_binomial_regression_with_var",
        BinomialConstrainedLink::kLog,
        "Fast log-binomial (relative-risk) regression via Fisher scoring. Pass "
        "weights to fit the weighted variant.",
        "Fast log-binomial regression with full variance-covariance matrix (ssq_b_j "
        "is the variance of parameter index j).");

    bind_constrained_binomial(m, "fast_identity_binomial_regression", "fast_identity_binomial_regression_with_var",
        BinomialConstrainedLink::kIdentity,
        "Fast identity-link (risk-difference) binomial regression via Fisher "
        "scoring. Pass weights to fit the weighted variant.",
        "Fast identity-link binomial regression with full variance-covariance "
        "matrix (ssq_b_j is the variance of parameter index j).");
}
