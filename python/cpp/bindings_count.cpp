// Binds count-outcome model-fitting kernels (Poisson, NegBin, ZINB, ZAP/hurdle-Poisson).

#include <pybind11/pybind11.h>
#include <pybind11/eigen.h>
#include <pybind11/stl.h>
#include "_helper_functions_core.h"
#include "result_map_pybind.h"
#include <optional>
#include <string>

namespace py = pybind11;

ModelResult fast_poisson_regression_internal(
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

ModelResult fast_neg_bin_internal(
    const Eigen::Ref<const Eigen::MatrixXd>& X,
    const Eigen::Ref<const Eigen::VectorXi>& y,
    std::optional<Eigen::VectorXd> warm_start_params,
    bool smart_cold_start,
    int maxit,
    double eps_g,
    std::optional<Eigen::VectorXi> fixed_idx,
    std::optional<Eigen::VectorXd> fixed_values,
    std::string optimization_alg,
    std::optional<Eigen::MatrixXd> warm_start_fisher_info,
    bool estimate_only,
    const Eigen::VectorXd* weights
);

LikelihoodFitResult fast_zinb_internal(
    const Eigen::Ref<const Eigen::MatrixXd>& Xc,
    const Eigen::Ref<const Eigen::MatrixXd>& Xz,
    const Eigen::Ref<const Eigen::VectorXd>& y_vec,
    std::optional<Eigen::VectorXd> warm_start_params,
    int maxit, double tol,
    std::optional<Eigen::VectorXi> fixed_idx,
    std::optional<Eigen::VectorXd> fixed_values,
    std::string optimization_alg,
    bool smart_cold_start,
    std::optional<Eigen::MatrixXd> warm_start_fisher_info
);

LikelihoodFitResult fast_zap_internal(
    const Eigen::Ref<const Eigen::MatrixXd>& X,
    const Eigen::Ref<const Eigen::VectorXd>& y,
    const Eigen::Ref<const Eigen::MatrixXd>& Xzi,
    bool is_hurdle,
    std::optional<Eigen::VectorXd> warm_start_params,
    bool smart_cold_start,
    int maxit,
    double tol,
    std::optional<Eigen::VectorXi> fixed_idx,
    std::optional<Eigen::VectorXd> fixed_values,
    std::string optimization_alg,
    std::optional<Eigen::MatrixXd> warm_start_fisher_info
);

edi::ResultMap fast_zap_with_var_internal(
    const Eigen::Ref<const Eigen::MatrixXd>& X,
    const Eigen::Ref<const Eigen::VectorXd>& y,
    const Eigen::Ref<const Eigen::MatrixXd>& Xzi,
    bool is_hurdle,
    std::optional<Eigen::VectorXd> warm_start_params,
    bool smart_cold_start,
    int maxit,
    double tol,
    std::optional<Eigen::VectorXi> fixed_idx,
    std::optional<Eigen::VectorXd> fixed_values,
    std::string optimization_alg,
    std::optional<Eigen::MatrixXd> warm_start_fisher_info
);

edi::ResultMap fast_zinb_with_var_internal(
    const Eigen::Ref<const Eigen::MatrixXd>& Xc,
    const Eigen::Ref<const Eigen::MatrixXd>& Xz,
    const Eigen::Ref<const Eigen::VectorXd>& y_vec,
    std::optional<Eigen::VectorXd> warm_start_params,
    int maxit, double tol,
    std::optional<Eigen::VectorXi> fixed_idx,
    std::optional<Eigen::VectorXd> fixed_values,
    std::string optimization_alg,
    bool smart_cold_start,
    std::optional<Eigen::MatrixXd> warm_start_fisher_info
);

edi::ResultMap fast_hurdle_negbin_internal(
    const Eigen::Ref<const Eigen::MatrixXd>& X,
    const Eigen::Ref<const Eigen::VectorXd>& y,
    const Eigen::Ref<const Eigen::MatrixXd>& X_hurdle,
    std::optional<Eigen::VectorXd> warm_start_params,
    bool smart_cold_start,
    int maxit,
    double tol,
    std::optional<Eigen::VectorXi> fixed_idx,
    std::optional<Eigen::VectorXd> fixed_values,
    std::string optimization_alg,
    std::optional<Eigen::MatrixXd> warm_start_fisher_info,
    std::optional<Eigen::MatrixXd> warm_start_hurdle_fisher_info,
    bool estimate_only,
    int j
);

edi::ResultMap fast_truncated_negbin_count_internal(
    const Eigen::Ref<const Eigen::MatrixXd>& X,
    const Eigen::Ref<const Eigen::VectorXd>& y,
    std::optional<Eigen::VectorXd> warm_start_params,
    bool smart_cold_start,
    bool estimate_only,
    int maxit,
    double tol,
    std::optional<Eigen::VectorXi> fixed_idx,
    std::optional<Eigen::VectorXd> fixed_values,
    std::string optimization_alg,
    std::optional<Eigen::MatrixXd> warm_start_fisher_info
);

edi::ResultMap fast_cpoisson_combined_internal(
    const Eigen::Ref<const Eigen::VectorXd>& yT_v,
    const Eigen::Ref<const Eigen::VectorXd>& n_k_v,
    const Eigen::Ref<const Eigen::MatrixXd>& X_diff_v,
    const Eigen::Ref<const Eigen::VectorXd>& y_r,
    const Eigen::Ref<const Eigen::VectorXd>& w_r,
    const Eigen::Ref<const Eigen::MatrixXd>& X_r,
    int maxit,
    double tol,
    std::optional<Eigen::VectorXi> fixed_idx,
    std::optional<Eigen::VectorXd> fixed_values,
    std::optional<Eigen::MatrixXd> warm_start_fisher_info,
    std::optional<Eigen::VectorXd> warm_start_params,
    std::optional<Eigen::VectorXd> warm_start_beta,
    bool estimate_only
);

static py::dict likelihood_fit_result_to_dict(const LikelihoodFitResult& fit) {
    py::dict out;
    out["params"] = fit.params;
    out["neg_loglik"] = fit.value;
    out["iterations"] = fit.niter;
    out["converged"] = fit.converged;
    out["gradient_norm"] = fit.gradient_norm;
    return out;
}

void bind_count(py::module_& m) {
    m.def("fast_poisson_regression", [](const Eigen::Ref<const Eigen::MatrixXd>& X,
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
        ModelResult res = fast_poisson_regression_internal(
            X, y, weights.value_or(Eigen::VectorXd()), warm_start_beta, smart_cold_start, maxit, tol,
            fixed_idx, fixed_values, optimization_alg, warm_start_weights, warm_start_fisher_info, estimate_only);
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
    py::arg("smart_cold_start") = false,
    py::arg("maxit") = 100,
    py::arg("tol") = 1e-8,
    py::arg("fixed_idx") = py::none(),
    py::arg("fixed_values") = py::none(),
    py::arg("optimization_alg") = "irls",
    py::arg("warm_start_weights") = py::none(),
    py::arg("warm_start_fisher_info") = py::none(),
    py::arg("estimate_only") = false,
    "Fits Poisson log-linear regression, Y_i ~ Poisson(mu_i),\n"
    "log(mu_i) = eta_i = x_i^T beta, by maximum likelihood. By default\n"
    "(optimization_alg=\"irls\"), fitting uses iteratively reweighted least\n"
    "squares with the canonical-link (Fisher-scoring) working weights\n"
    "w_i = mu_i and working response z_i = eta_i + (y_i - mu_i)/mu_i: each\n"
    "iteration solves the weighted normal equations X^T W X delta = X^T W z.\n"
    "Any optimization_alg other than \"lbfgs\" runs this IRLS path;\n"
    "optimization_alg=\"lbfgs\" instead minimizes the exact negative\n"
    "log-likelihood directly via L-BFGS. No R-side roxygen documents this raw\n"
    "kernel directly (fast_poisson_regression.cpp has none); parameters\n"
    "follow the same fixed_idx/fixed_values/warm-start conventions used\n"
    "throughout this module (see e.g. fast_logistic_regression's docstring\n"
    "for the shared IRLS/L-BFGS machinery pattern). Analogous to statsmodels'\n"
    "Poisson/GLM(family=Poisson()); see\n"
    "https://www.statsmodels.org/stable/discretemod.html.\n\n"
    "Parameters\n"
    "----------\n"
    "X : ndarray\n"
    "    Numeric matrix of predictors (including intercept column where wanted).\n"
    "y : ndarray\n"
    "    Numeric vector of non-negative integer count responses.\n"
    "weights : ndarray, optional\n"
    "    Optional nonnegative row weights for a weighted fit.\n"
    "warm_start_beta : ndarray, optional\n"
    "    Optional starting values for coefficients. If provided, smart_cold_start\n"
    "    is ignored.\n"
    "smart_cold_start : bool, default False\n"
    "    If True, use an initial OLS-based guess when starting from scratch. Ignored\n"
    "    if a warm start is provided.\n"
    "maxit : int, default 100\n"
    "    Maximum number of iterations.\n"
    "tol : float, default 1e-8\n"
    "    Convergence tolerance.\n"
    "fixed_idx : ndarray of int, optional\n"
    "    Optional indices of coefficients to hold fixed at fixed_values rather than\n"
    "    estimate.\n"
    "fixed_values : ndarray, optional\n"
    "    Optional values for the fixed_idx coefficients.\n"
    "optimization_alg : str, default \"irls\"\n"
    "    Optimization algorithm (\"irls\" or \"lbfgs\").\n"
    "warm_start_weights : ndarray, optional\n"
    "    Optional initial IRLS working weights for the first iteration.\n"
    "warm_start_fisher_info : ndarray, optional\n"
    "    Optional initial Fisher information matrix for the first iteration.\n"
    "estimate_only : bool, default False\n"
    "    If True, skip variance-component calculations and return only the point\n"
    "    estimate.");

    m.def("fast_neg_bin", [](const Eigen::Ref<const Eigen::MatrixXd>& X,
                              const Eigen::Ref<const Eigen::VectorXi>& y,
                              std::optional<Eigen::VectorXd> warm_start_params,
                              bool smart_cold_start,
                              int maxit,
                              double eps_g,
                              std::optional<Eigen::VectorXi> fixed_idx,
                              std::optional<Eigen::VectorXd> fixed_values,
                              std::string optimization_alg,
                              std::optional<Eigen::MatrixXd> warm_start_fisher_info,
                              bool estimate_only,
                              std::optional<Eigen::VectorXd> weights) {
        ModelResult res = fast_neg_bin_internal(
            X, y, warm_start_params, smart_cold_start, maxit, eps_g,
            fixed_idx, fixed_values, optimization_alg, warm_start_fisher_info, estimate_only,
            weights.has_value() ? &(*weights) : nullptr);
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
    py::arg("warm_start_params") = py::none(),
    py::arg("smart_cold_start") = false,
    py::arg("maxit") = 1000,
    py::arg("eps_g") = 1e-6,
    py::arg("fixed_idx") = py::none(),
    py::arg("fixed_values") = py::none(),
    py::arg("optimization_alg") = "lbfgs",
    py::arg("warm_start_fisher_info") = py::none(),
    py::arg("estimate_only") = false,
    py::arg("weights") = py::none(),
    "Fits negative-binomial (NB2) log-linear regression, Y_i ~ NB(mu_i, theta),\n"
    "log(mu_i) = x_i^T beta, with Var(Y_i) = mu_i + mu_i^2/theta (theta the\n"
    "dispersion/shape parameter; smaller theta means more overdispersion\n"
    "relative to Poisson), by direct maximum likelihood over the joint\n"
    "parameter vector [beta, log(theta)] (theta optimized on the log scale\n"
    "for positivity) via L-BFGS, using fast_digamma/fast_trigamma internally\n"
    "for the theta-derivative terms of the gradient/Hessian. When\n"
    "smart_cold_start=True and no warm_start_params is given, beta is seeded\n"
    "from an OLS fit and theta from the method-of-moments Pearson-residual\n"
    "estimate alpha_hat = mean(((y-mu)^2 - mu)/mu^2), theta0 = 1/alpha_hat\n"
    "(falling back to a fixed legacy start if that estimate is non-finite or\n"
    "non-positive). Parameters sourced from R/EDI/man/ documentation for\n"
    "fast_neg_bin_cpp / fast_neg_bin_with_var_cpp (R/EDI/src/fast_negbin_regression.cpp).\n"
    "Analogous to statsmodels' NegativeBinomial (NB2 parameterization); see\n"
    "https://www.statsmodels.org/stable/discretemod.html.\n\n"
    "Parameters\n"
    "----------\n"
    "X : ndarray\n"
    "    Numeric matrix of predictors.\n"
    "y : ndarray of int\n"
    "    Numeric vector of non-negative integer count responses.\n"
    "warm_start_params : ndarray, optional\n"
    "    Optional starting values for coefficients and dispersion (log_theta). If\n"
    "    provided, smart_cold_start is ignored.\n"
    "smart_cold_start : bool, default False\n"
    "    If True, use an initial OLS-based guess when starting from scratch (a\n"
    "    \"cold start\") with no prior knowledge. Ignored if a warm start is\n"
    "    provided.\n"
    "maxit : int, default 1000\n"
    "    Maximum number of iterations.\n"
    "eps_g : float, default 1e-6\n"
    "    Convergence tolerance for the gradient.\n"
    "fixed_idx : ndarray of int, optional\n"
    "    Optional indices of fixed parameters.\n"
    "fixed_values : ndarray, optional\n"
    "    Optional values for fixed parameters.\n"
    "optimization_alg : str, default \"lbfgs\"\n"
    "    Optimization algorithm.\n"
    "warm_start_fisher_info : ndarray, optional\n"
    "    Optional initial Fisher information matrix for the first iteration.\n"
    "estimate_only : bool, default False\n"
    "    If True, skip variance computation and return only coefficients.\n"
    "weights : ndarray, optional\n"
    "    Optional nonnegative row weights for a weighted fit (routes to the\n"
    "    R-side fast_neg_bin_weighted_cpp backend when provided).");

    m.def("fast_zinb", [](const Eigen::Ref<const Eigen::MatrixXd>& Xc,
                           const Eigen::Ref<const Eigen::MatrixXd>& Xz,
                           const Eigen::Ref<const Eigen::VectorXd>& y,
                           std::optional<Eigen::VectorXd> warm_start_params,
                           int maxit,
                           double tol,
                           std::optional<Eigen::VectorXi> fixed_idx,
                           std::optional<Eigen::VectorXd> fixed_values,
                           std::string optimization_alg,
                           bool smart_cold_start,
                           std::optional<Eigen::MatrixXd> warm_start_fisher_info) {
        LikelihoodFitResult fit = fast_zinb_internal(
            Xc, Xz, y, warm_start_params, maxit, tol, fixed_idx, fixed_values,
            optimization_alg, smart_cold_start, warm_start_fisher_info);
        return likelihood_fit_result_to_dict(fit);
    },
    py::arg("Xc"), py::arg("Xz"), py::arg("y"),
    py::arg("warm_start_params") = py::none(),
    py::arg("maxit") = 1000,
    py::arg("tol") = 1e-8,
    py::arg("fixed_idx") = py::none(),
    py::arg("fixed_values") = py::none(),
    py::arg("optimization_alg") = "lbfgs",
    py::arg("smart_cold_start") = true,
    py::arg("warm_start_fisher_info") = py::none(),
    "Fits a zero-inflated negative-binomial model by direct maximum\n"
    "likelihood via L-BFGS: a NB2 log-link count component\n"
    "(mu_i = exp(x_i^T beta_cond), Xc) mixed with a logit-link always-zero\n"
    "latent class (pi_i = expit(x_zi_i^T beta_zi), Xz), so\n"
    "P(Y_i=0) = pi_i + (1-pi_i)*NB(0; mu_i, theta) and\n"
    "P(Y_i=y | y>0) = (1-pi_i)*NB(y; mu_i, theta) -- the negative-binomial\n"
    "analogue of fast_zero_augmented_poisson's zero-inflated-Poisson branch\n"
    "(is_hurdle=False there), but with an NB2 count component and its own\n"
    "dispersion parameter theta instead of Poisson. Returns 'params' =\n"
    "[beta_cond, beta_zi, log_theta]; split into components on the Python\n"
    "side. Parameters sourced from R/EDI/man/ documentation for fast_zinb_cpp\n"
    "(Xc/Xz here correspond to that function's X/Xzi). Analogous to\n"
    "statsmodels' ZeroInflatedNegativeBinomialP; see\n"
    "https://www.statsmodels.org/stable/discretemod.html.\n\n"
    "Parameters\n"
    "----------\n"
    "Xc : ndarray\n"
    "    Numeric matrix of predictors for the count component (including\n"
    "    intercept).\n"
    "Xz : ndarray\n"
    "    Numeric matrix of predictors for the zero-inflation component (including\n"
    "    intercept).\n"
    "y : ndarray\n"
    "    Numeric vector of non-negative integer count responses.\n"
    "warm_start_params : ndarray, optional\n"
    "    Optional starting values for all parameters ([beta_cond, beta_zi,\n"
    "    log_theta]).\n"
    "maxit : int, default 1000\n"
    "    Maximum number of iterations.\n"
    "tol : float, default 1e-8\n"
    "    Convergence tolerance.\n"
    "fixed_idx : ndarray of int, optional\n"
    "    Optional indices of fixed parameters.\n"
    "fixed_values : ndarray, optional\n"
    "    Optional values for fixed parameters.\n"
    "optimization_alg : str, default \"lbfgs\"\n"
    "    Optimization algorithm.\n"
    "smart_cold_start : bool, default True\n"
    "    If True, use a heuristic initial guess when no warm start is provided.\n"
    "warm_start_fisher_info : ndarray, optional\n"
    "    Optional initial Fisher information matrix.");

    m.def("fast_zinb_with_var", [](const Eigen::Ref<const Eigen::MatrixXd>& Xc,
                                    const Eigen::Ref<const Eigen::MatrixXd>& Xz,
                                    const Eigen::Ref<const Eigen::VectorXd>& y,
                                    std::optional<Eigen::VectorXd> warm_start_params,
                                    int maxit,
                                    double tol,
                                    std::optional<Eigen::VectorXi> fixed_idx,
                                    std::optional<Eigen::VectorXd> fixed_values,
                                    std::string optimization_alg,
                                    bool smart_cold_start,
                                    std::optional<Eigen::MatrixXd> warm_start_fisher_info) {
        edi::ResultMap res = fast_zinb_with_var_internal(
            Xc, Xz, y, warm_start_params, maxit, tol, fixed_idx, fixed_values,
            optimization_alg, smart_cold_start, warm_start_fisher_info);
        return edi::to_py_dict(res);
    },
    py::arg("Xc"), py::arg("Xz"), py::arg("y"),
    py::arg("warm_start_params") = py::none(),
    py::arg("maxit") = 1000,
    py::arg("tol") = 1e-8,
    py::arg("fixed_idx") = py::none(),
    py::arg("fixed_values") = py::none(),
    py::arg("optimization_alg") = "lbfgs",
    py::arg("smart_cold_start") = true,
    py::arg("warm_start_fisher_info") = py::none(),
    "Same zero-inflated negative-binomial model as fast_zinb (see its\n"
    "docstring for the full P(Y_i=0)/P(Y_i=y|y>0) mixture formula and\n"
    "parameterization) with full vcov (params order:\n"
    "[beta_cond, beta_zi, log_theta]). Always computes the variance --\n"
    "fast_zinb is the dedicated point-estimate-only backend. Same argument\n"
    "meanings as fast_zinb; Xc/Xz correspond to R/EDI/man/'s fast_zinb_cpp\n"
    "X/Xzi.\n\n"
    "Parameters\n"
    "----------\n"
    "Xc : ndarray\n"
    "    Numeric matrix of predictors for the count component (including\n"
    "    intercept).\n"
    "Xz : ndarray\n"
    "    Numeric matrix of predictors for the zero-inflation component (including\n"
    "    intercept).\n"
    "y : ndarray\n"
    "    Numeric vector of non-negative integer count responses.\n"
    "warm_start_params : ndarray, optional\n"
    "    Optional starting values for all parameters ([beta_cond, beta_zi,\n"
    "    log_theta]).\n"
    "maxit : int, default 1000\n"
    "    Maximum number of iterations.\n"
    "tol : float, default 1e-8\n"
    "    Convergence tolerance.\n"
    "fixed_idx : ndarray of int, optional\n"
    "    Optional indices of fixed parameters.\n"
    "fixed_values : ndarray, optional\n"
    "    Optional values for fixed parameters.\n"
    "optimization_alg : str, default \"lbfgs\"\n"
    "    Optimization algorithm.\n"
    "smart_cold_start : bool, default True\n"
    "    If True, use a heuristic initial guess when no warm start is provided.\n"
    "warm_start_fisher_info : ndarray, optional\n"
    "    Optional initial Fisher information matrix.");

    m.def("fast_zero_augmented_poisson", [](const Eigen::Ref<const Eigen::MatrixXd>& X,
                                             const Eigen::Ref<const Eigen::VectorXd>& y,
                                             const Eigen::Ref<const Eigen::MatrixXd>& Xzi,
                                             bool is_hurdle,
                                             std::optional<Eigen::VectorXd> warm_start_params,
                                             bool smart_cold_start,
                                             int maxit,
                                             double tol,
                                             std::optional<Eigen::VectorXi> fixed_idx,
                                             std::optional<Eigen::VectorXd> fixed_values,
                                             std::string optimization_alg,
                                             std::optional<Eigen::MatrixXd> warm_start_fisher_info) {
        LikelihoodFitResult fit = fast_zap_internal(
            X, y, Xzi, is_hurdle, warm_start_params, smart_cold_start, maxit, tol,
            fixed_idx, fixed_values, optimization_alg, warm_start_fisher_info);
        return likelihood_fit_result_to_dict(fit);
    },
    py::arg("X"), py::arg("y"), py::arg("Xzi"), py::arg("is_hurdle"),
    py::arg("warm_start_params") = py::none(),
    py::arg("smart_cold_start") = true,
    py::arg("maxit") = 1000,
    py::arg("tol") = 1e-8,
    py::arg("fixed_idx") = py::none(),
    py::arg("fixed_values") = py::none(),
    py::arg("optimization_alg") = "lbfgs",
    py::arg("warm_start_fisher_info") = py::none(),
    "Fits, by direct maximum likelihood via L-BFGS, a two-component count\n"
    "model with a Poisson log-link count component\n"
    "(lambda_i = exp(x_i^T beta_cond), X) and a logit-link binary component\n"
    "(pi_i = expit(x_zi_i^T beta_zi), Xzi). The two models differ in how\n"
    "pi_i enters the likelihood:\n"
    "  * Zero-inflated Poisson (is_hurdle=False): pi_i is the probability of\n"
    "    an always-zero latent class, mixed with a Poisson count that can\n"
    "    itself produce zeros: P(Y_i=0) = pi_i + (1-pi_i)*exp(-lambda_i) and\n"
    "    P(Y_i=y | y>0) = (1-pi_i)*Poisson(y; lambda_i).\n"
    "  * Hurdle Poisson (is_hurdle=True): pi_i = P(Y_i=0) directly, via a\n"
    "    simple binary (zero vs. positive) logistic sub-model, and positive\n"
    "    counts follow a zero-truncated Poisson,\n"
    "    P(Y_i=y | y>0) = (1-pi_i)*lambda_i^y*exp(-lambda_i) / (y!*(1-exp(-lambda_i))).\n"
    "Both branches share one likelihood/gradient/Hessian implementation,\n"
    "switched per observation by is_hurdle, jointly optimizing\n"
    "[beta_cond, beta_zi]. If the optimizer throws an exception internally,\n"
    "this does not propagate a Python error: it returns\n"
    "{\"converged\": False, \"gradient_norm\": nan} with no other fields.\n"
    "smart_cold_start=True (default, no warm_start_params) uses a\n"
    "model-specific heuristic start; otherwise all parameters start at zero\n"
    "except the first conditional-model coefficient, initialized to\n"
    "log(mean(y)) when mean(y) > 0. Returns 'params' = [beta_cond, beta_zi];\n"
    "split into components on the Python side. Parameters sourced from\n"
    "R/EDI/man/ documentation for fast_zero_augmented_poisson_cpp. Analogous\n"
    "to statsmodels' ZeroInflatedPoisson; see\n"
    "https://www.statsmodels.org/stable/discretemod.html.\n\n"
    "Parameters\n"
    "----------\n"
    "X : ndarray\n"
    "    Matrix of predictors for the conditional (count) component.\n"
    "y : ndarray\n"
    "    Vector of count responses.\n"
    "Xzi : ndarray\n"
    "    Matrix of predictors for the zero-inflation/hurdle component.\n"
    "is_hurdle : bool\n"
    "    If True, fit a hurdle model; if False, fit a zero-inflated model.\n"
    "warm_start_params : ndarray, optional\n"
    "    Optional starting values for all parameters. If provided,\n"
    "    smart_cold_start is ignored.\n"
    "smart_cold_start : bool, default True\n"
    "    If True, use an initial OLS-based guess when starting from scratch (a\n"
    "    \"cold start\") with no prior knowledge. Ignored if a warm start is\n"
    "    provided.\n"
    "maxit : int, default 1000\n"
    "    Maximum number of iterations.\n"
    "tol : float, default 1e-8\n"
    "    Convergence tolerance.\n"
    "fixed_idx : ndarray of int, optional\n"
    "    Optional indices of fixed parameters.\n"
    "fixed_values : ndarray, optional\n"
    "    Optional values for fixed parameters.\n"
    "optimization_alg : str, default \"lbfgs\"\n"
    "    Optimization algorithm.\n"
    "warm_start_fisher_info : ndarray, optional\n"
    "    Optional initial Fisher information matrix for the first iteration.");

    m.def("fast_zero_augmented_poisson_with_var", [](const Eigen::Ref<const Eigen::MatrixXd>& X,
                                                       const Eigen::Ref<const Eigen::VectorXd>& y,
                                                       const Eigen::Ref<const Eigen::MatrixXd>& Xzi,
                                                       bool is_hurdle,
                                                       std::optional<Eigen::VectorXd> warm_start_params,
                                                       bool smart_cold_start,
                                                       int maxit,
                                                       double tol,
                                                       std::optional<Eigen::VectorXi> fixed_idx,
                                                       std::optional<Eigen::VectorXd> fixed_values,
                                                       std::string optimization_alg,
                                                       std::optional<Eigen::MatrixXd> warm_start_fisher_info) {
        edi::ResultMap res = fast_zap_with_var_internal(
            X, y, Xzi, is_hurdle, warm_start_params, smart_cold_start, maxit, tol,
            fixed_idx, fixed_values, optimization_alg, warm_start_fisher_info);
        return edi::to_py_dict(res);
    },
    py::arg("X"), py::arg("y"), py::arg("Xzi"), py::arg("is_hurdle"),
    py::arg("warm_start_params") = py::none(),
    py::arg("smart_cold_start") = true,
    py::arg("maxit") = 1000,
    py::arg("tol") = 1e-8,
    py::arg("fixed_idx") = py::none(),
    py::arg("fixed_values") = py::none(),
    py::arg("optimization_alg") = "lbfgs",
    py::arg("warm_start_fisher_info") = py::none(),
    "Same zero-inflated/hurdle Poisson model as fast_zero_augmented_poisson\n"
    "(see its docstring for the full P(Y_i=0)/P(Y_i=y|y>0) formulas for both\n"
    "branches) with full vcov (params order: [beta_cond, beta_zi]). Always\n"
    "computes the variance -- fast_zero_augmented_poisson is the dedicated\n"
    "point-estimate-only backend. Returns additionally the joint covariance\n"
    "matrix (vcov), the observed-information matrix (fisher_information /\n"
    "observed_information / information, all aliases), its negation\n"
    "(hessian), and coefficients as a {\"cond\": ..., \"zi\": ...} split.\n"
    "Same argument meanings as fast_zero_augmented_poisson (see its\n"
    "docstring).\n\n"
    "Parameters\n"
    "----------\n"
    "X : ndarray\n"
    "    Matrix of predictors for the conditional (count) component.\n"
    "y : ndarray\n"
    "    Vector of count responses.\n"
    "Xzi : ndarray\n"
    "    Matrix of predictors for the zero-inflation/hurdle component.\n"
    "is_hurdle : bool\n"
    "    If True, fit a hurdle model; if False, fit a zero-inflated model.\n"
    "warm_start_params : ndarray, optional\n"
    "    Optional starting values for all parameters. If provided,\n"
    "    smart_cold_start is ignored.\n"
    "smart_cold_start : bool, default True\n"
    "    If True, use an initial OLS-based guess when starting from scratch. Ignored\n"
    "    if a warm start is provided.\n"
    "maxit : int, default 1000\n"
    "    Maximum number of iterations.\n"
    "tol : float, default 1e-8\n"
    "    Convergence tolerance.\n"
    "fixed_idx : ndarray of int, optional\n"
    "    Optional indices of fixed parameters.\n"
    "fixed_values : ndarray, optional\n"
    "    Optional values for fixed parameters.\n"
    "optimization_alg : str, default \"lbfgs\"\n"
    "    Optimization algorithm.\n"
    "warm_start_fisher_info : ndarray, optional\n"
    "    Optional initial Fisher information matrix for the first iteration.");

    m.def("fast_hurdle_negbin", [](const Eigen::Ref<const Eigen::MatrixXd>& X,
                                    const Eigen::Ref<const Eigen::VectorXd>& y,
                                    const Eigen::Ref<const Eigen::MatrixXd>& X_hurdle,
                                    std::optional<Eigen::VectorXd> warm_start_params,
                                    bool smart_cold_start,
                                    int maxit,
                                    double tol,
                                    std::optional<Eigen::VectorXi> fixed_idx,
                                    std::optional<Eigen::VectorXd> fixed_values,
                                    std::string optimization_alg,
                                    std::optional<Eigen::MatrixXd> warm_start_fisher_info,
                                    std::optional<Eigen::MatrixXd> warm_start_hurdle_fisher_info,
                                    bool estimate_only,
                                    int j) {
        edi::ResultMap res = fast_hurdle_negbin_internal(
            X, y, X_hurdle, warm_start_params, smart_cold_start, maxit, tol,
            fixed_idx, fixed_values, optimization_alg, warm_start_fisher_info,
            warm_start_hurdle_fisher_info, estimate_only, j);
        return edi::to_py_dict(res);
    },
    py::arg("X"), py::arg("y"), py::arg("X_hurdle"),
    py::arg("warm_start_params") = py::none(),
    py::arg("smart_cold_start") = true,
    py::arg("maxit") = 1000,
    py::arg("tol") = 1e-8,
    py::arg("fixed_idx") = py::none(),
    py::arg("fixed_values") = py::none(),
    py::arg("optimization_alg") = "lbfgs",
    py::arg("warm_start_fisher_info") = py::none(),
    py::arg("warm_start_hurdle_fisher_info") = py::none(),
    py::arg("estimate_only") = false,
    py::arg("j") = 2,
    "Fits a two-part hurdle negative-binomial model for count data with\n"
    "excess zeros: (1) a hurdle part -- logistic regression of the binary\n"
    "indicator I(Y_i > 0) on X_hurdle -- models whether the hurdle is\n"
    "crossed at all, and (2) a count part -- a zero-truncated\n"
    "negative-binomial regression fit only on the subset of subjects with\n"
    "Y_i > 0, using X -- models the count given the hurdle is crossed.\n"
    "Unlike a zero-inflated model (which mixes a point mass at zero with an\n"
    "untruncated count distribution that can itself also produce zeros), the\n"
    "hurdle model's two parts are a clean partition: every zero comes from\n"
    "the hurdle part, and every positive count's distribution is exactly the\n"
    "negative-binomial conditional on being positive (left-truncated at 1).\n"
    "The count part's parameter vector is [beta, log(theta)]\n"
    "(theta the NB dispersion, optimized on the log scale, reported back as\n"
    "theta_hat=exp(...)); if the positive-count subset has too few\n"
    "observations to identify the coefficients, the count part returns b as\n"
    "all NaN and converged=False with an explanatory failure_message, while\n"
    "the hurdle part (independent of that subset) still fits normally.\n"
    "Unifies the R-side plain-fit and with-variance exports: the joint\n"
    "vcov/ssq_b_j (for count-model parameter index j) and\n"
    "hurdle_ssq_b_j/hurdle_ssq_b_2 (hurdle-model coefficient variances) are\n"
    "always computed when not estimate_only. Parameters sourced from\n"
    "R/EDI/man/ documentation for fast_hurdle_negbin_with_var_cpp\n"
    "(X_r/y_r/X_hurdle_r there correspond to X/y/X_hurdle here). Analogous\n"
    "to statsmodels' HurdleCountModel with a negative-binomial count\n"
    "distribution; see https://www.statsmodels.org/stable/discretemod.html.\n\n"
    "Parameters\n"
    "----------\n"
    "X : ndarray\n"
    "    Matrix of predictors for the count component.\n"
    "y : ndarray\n"
    "    Vector of count responses.\n"
    "X_hurdle : ndarray\n"
    "    Matrix of predictors for the hurdle (zero/positive) component.\n"
    "warm_start_params : ndarray, optional\n"
    "    Optional starting values for count parameters. If provided,\n"
    "    smart_cold_start is ignored.\n"
    "smart_cold_start : bool, default True\n"
    "    If True, use an initial OLS-based guess when starting from scratch (a\n"
    "    \"cold start\") with no prior knowledge. Ignored if a warm start is\n"
    "    provided.\n"
    "maxit : int, default 1000\n"
    "    Maximum number of iterations.\n"
    "tol : float, default 1e-8\n"
    "    Convergence tolerance.\n"
    "fixed_idx : ndarray of int, optional\n"
    "    Optional indices of fixed parameters.\n"
    "fixed_values : ndarray, optional\n"
    "    Optional values for fixed parameters.\n"
    "optimization_alg : str, default \"lbfgs\"\n"
    "    Optimization algorithm.\n"
    "warm_start_fisher_info : ndarray, optional\n"
    "    Optional initial Fisher information matrix for the count component's first\n"
    "    iteration.\n"
    "warm_start_hurdle_fisher_info : ndarray, optional\n"
    "    Optional initial Fisher information matrix for the hurdle component's\n"
    "    first iteration.\n"
    "estimate_only : bool, default False\n"
    "    If True, skip variance-covariance computation and return only\n"
    "    coefficients.\n"
    "j : int, default 2\n"
    "    1-based index of the count-component coefficient whose individual\n"
    "    variance (ssq_b_j) is returned.");

    m.def("fast_truncated_negbin_count", [](const Eigen::Ref<const Eigen::MatrixXd>& X,
                                             const Eigen::Ref<const Eigen::VectorXd>& y,
                                             std::optional<Eigen::VectorXd> warm_start_params,
                                             bool smart_cold_start,
                                             bool estimate_only,
                                             int maxit,
                                             double tol,
                                             std::optional<Eigen::VectorXi> fixed_idx,
                                             std::optional<Eigen::VectorXd> fixed_values,
                                             std::string optimization_alg,
                                             std::optional<Eigen::MatrixXd> warm_start_fisher_info) {
        edi::ResultMap res = fast_truncated_negbin_count_internal(
            X, y, warm_start_params, smart_cold_start, estimate_only, maxit, tol,
            fixed_idx, fixed_values, optimization_alg, warm_start_fisher_info);
        return edi::to_py_dict(res);
    },
    py::arg("X"), py::arg("y"),
    py::arg("warm_start_params") = py::none(),
    py::arg("smart_cold_start") = true,
    py::arg("estimate_only") = false,
    py::arg("maxit") = 1000,
    py::arg("tol") = 1e-8,
    py::arg("fixed_idx") = py::none(),
    py::arg("fixed_values") = py::none(),
    py::arg("optimization_alg") = "lbfgs",
    py::arg("warm_start_fisher_info") = py::none(),
    "Fits a zero-truncated negative-binomial regression by direct maximum\n"
    "likelihood via L-BFGS on strictly positive counts: mean-parameterized\n"
    "NB2 with mean mu_i = exp(x_i^T beta) and dispersion theta, conditioned\n"
    "on Y_i > 0 (the density divided by 1 - NB(0; mu_i, theta)). This is the\n"
    "count-component fit used internally inside fast_hurdle_negbin's count\n"
    "part (see that function's docstring for how it combines with a hurdle\n"
    "logistic part), also exposed standalone here. The joint parameter\n"
    "vector is [beta, log(theta)] (theta optimized on the log scale for\n"
    "positivity, reported back as theta_hat=exp(...)); several candidate\n"
    "starting points (OLS-based beta plus a method-of-moments and a\n"
    "model-specific theta heuristic) are tried with fallback if the primary\n"
    "start fails to converge. No R-side roxygen documents this raw kernel\n"
    "directly (fast_hurdle_negbin.cpp's roxygen documents the hurdle export,\n"
    "not this truncated-count-only one); parameters follow the same\n"
    "conventions used throughout this module. Analogous to statsmodels'\n"
    "TruncatedLFNegativeBinomialP; see\n"
    "https://www.statsmodels.org/stable/discretemod.html.\n\n"
    "Parameters\n"
    "----------\n"
    "X : ndarray\n"
    "    Matrix of predictors.\n"
    "y : ndarray\n"
    "    Vector of positive (zero-truncated) count responses.\n"
    "warm_start_params : ndarray, optional\n"
    "    Optional starting values for coefficients and dispersion. If provided,\n"
    "    smart_cold_start is ignored.\n"
    "smart_cold_start : bool, default True\n"
    "    If True, use an initial OLS-based guess when starting from scratch. Ignored\n"
    "    if a warm start is provided.\n"
    "estimate_only : bool, default False\n"
    "    If True, skip variance-covariance computation and return only\n"
    "    coefficients.\n"
    "maxit : int, default 1000\n"
    "    Maximum number of iterations.\n"
    "tol : float, default 1e-8\n"
    "    Convergence tolerance.\n"
    "fixed_idx : ndarray of int, optional\n"
    "    Optional indices of fixed parameters.\n"
    "fixed_values : ndarray, optional\n"
    "    Optional values for fixed parameters.\n"
    "optimization_alg : str, default \"lbfgs\"\n"
    "    Optimization algorithm.\n"
    "warm_start_fisher_info : ndarray, optional\n"
    "    Optional initial Fisher information matrix for the first iteration.");

    m.def("fast_cpoisson_combined", [](const Eigen::Ref<const Eigen::VectorXd>& yT_v,
                                        const Eigen::Ref<const Eigen::VectorXd>& n_k_v,
                                        const Eigen::Ref<const Eigen::MatrixXd>& X_diff_v,
                                        const Eigen::Ref<const Eigen::VectorXd>& y_r,
                                        const Eigen::Ref<const Eigen::VectorXd>& w_r,
                                        const Eigen::Ref<const Eigen::MatrixXd>& X_r,
                                        int maxit,
                                        double tol,
                                        std::optional<Eigen::VectorXi> fixed_idx,
                                        std::optional<Eigen::VectorXd> fixed_values,
                                        std::optional<Eigen::MatrixXd> warm_start_fisher_info,
                                        std::optional<Eigen::VectorXd> warm_start_params,
                                        std::optional<Eigen::VectorXd> warm_start_beta,
                                        bool estimate_only) {
        edi::ResultMap res = fast_cpoisson_combined_internal(
            yT_v, n_k_v, X_diff_v, y_r, w_r, X_r, maxit, tol,
            fixed_idx, fixed_values, warm_start_fisher_info, warm_start_params,
            warm_start_beta, estimate_only);
        return edi::to_py_dict(res);
    },
    py::arg("yT_v"), py::arg("n_k_v"), py::arg("X_diff_v"),
    py::arg("y_r"), py::arg("w_r"), py::arg("X_r"),
    py::arg("maxit") = 100,
    py::arg("tol") = 1e-8,
    py::arg("fixed_idx") = py::none(),
    py::arg("fixed_values") = py::none(),
    py::arg("warm_start_fisher_info") = py::none(),
    py::arg("warm_start_params") = py::none(),
    py::arg("warm_start_beta") = py::none(),
    py::arg("estimate_only") = false,
    "Jointly fits a single treatment-effect coefficient beta_T (and shared\n"
    "covariate effects beta_xs) across two structurally different count\n"
    "likelihoods at once -- the matched-pair (conditional Poisson) component\n"
    "from subjects paired on-the-fly by a KK matching design, and the\n"
    "marginal Poisson component from unmatched \"reservoir\" subjects --\n"
    "rather than fitting the two subsets separately and combining estimates\n"
    "afterward.\n\n"
    "Matched-pair component (conditional Poisson): for pair k with total\n"
    "count n_k (sum of both members' counts) and treated-member count\n"
    "y_T_k, conditioning on n_k (the sufficient statistic that eliminates\n"
    "the pair's nuisance baseline rate) reduces the joint Poisson likelihood\n"
    "of the pair to a Binomial: y_T_k | n_k ~ Binomial(n_k, p_k),\n"
    "p_k = expit(beta_T + x_diff_k^T beta_xs), where x_diff_k is the pair's\n"
    "covariate difference (treated minus control). This is the count-\n"
    "response analog of conditional logistic regression for matched pairs --\n"
    "no per-pair intercept is estimated (conditioned out entirely).\n\n"
    "Reservoir component (marginal Poisson): unmatched reservoir subjects\n"
    "contribute an ordinary Poisson log-linear likelihood,\n"
    "y_i ~ Poisson(mu_i), log(mu_i) = beta_0 + w_i*beta_T + x_i^T beta_xs,\n"
    "sharing the same beta_T and beta_xs as the pair component but\n"
    "additionally estimating an intercept beta_0.\n\n"
    "The total log-likelihood is the sum of the pair and reservoir\n"
    "log-likelihoods, jointly maximized over [beta_0, beta_T, beta_xs] via\n"
    "Newton's method using the analytic Fisher information as the Hessian.\n"
    "ssq_b_j is the variance of beta_T specifically. No R-side roxygen\n"
    "documents this raw fit kernel's Python-facing name directly, but\n"
    "R/EDI/man/ fully documents the equivalent R export (see\n"
    "fast_cpoisson_combined.cpp's roxygen for\n"
    "fast_cpoisson_combined_with_var_cpp), whose argument names/meanings\n"
    "match the ones below. Analogous to statsmodels' ConditionalPoisson for\n"
    "the matched-pair component alone (not the combined pair+reservoir\n"
    "model implemented here); see\n"
    "https://www.statsmodels.org/dev/generated/statsmodels.discrete.conditional_models.ConditionalPoisson.html.\n\n"
    "Parameters\n"
    "----------\n"
    "yT_v : ndarray\n"
    "    Treated-subject counts, one per matched pair.\n"
    "n_k_v : ndarray\n"
    "    Total (treated + control) counts, one per matched pair.\n"
    "X_diff_v : ndarray\n"
    "    Matrix of covariate differences between the treated and control member of\n"
    "    each matched pair.\n"
    "y_r : ndarray\n"
    "    Outcome counts for the unmatched reservoir subjects.\n"
    "w_r : ndarray\n"
    "    0/1 treatment indicators for the reservoir subjects.\n"
    "X_r : ndarray\n"
    "    Covariate matrix for the reservoir subjects.\n"
    "maxit : int, default 100\n"
    "    Maximum number of Newton iterations.\n"
    "tol : float, default 1e-8\n"
    "    Convergence tolerance.\n"
    "fixed_idx : ndarray of int, optional\n"
    "    Optional indices of fixed parameters.\n"
    "fixed_values : ndarray, optional\n"
    "    Optional values for fixed parameters.\n"
    "warm_start_fisher_info : ndarray, optional\n"
    "    Optional initial Fisher information matrix for the first iteration.\n"
    "warm_start_params : ndarray, optional\n"
    "    Optional starting values for all parameters.\n"
    "warm_start_beta : ndarray, optional\n"
    "    Optional starting values for coefficients only.\n"
    "estimate_only : bool, default False\n"
    "    If True, skip variance-covariance computation and return only\n"
    "    coefficients.");
}
