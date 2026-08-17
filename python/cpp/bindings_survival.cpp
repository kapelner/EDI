// Binds survival-outcome model-fitting kernels (Cox PH, Weibull AFT).

#include <pybind11/pybind11.h>
#include <pybind11/eigen.h>
#include <pybind11/stl.h>
#include "result_map_pybind.h"
#include "_helper_functions_core.h"
#include <limits>
#include <optional>
#include <string>
#include <vector>

namespace py = pybind11;

ModelResult fast_gehan_wilcox_result(
    const Eigen::Ref<const Eigen::VectorXd>& time,
    const std::vector<int>& dead,
    const std::vector<int>& w
);

ModelResult fast_logrank_result(
    const Eigen::Ref<const Eigen::VectorXd>& time,
    const std::vector<int>& dead,
    const std::vector<int>& w
);

double get_survival_stat_diff_result(
    const Eigen::Ref<const Eigen::VectorXd>& y,
    const Eigen::Ref<const Eigen::VectorXi>& dead,
    const Eigen::Ref<const Eigen::VectorXi>& w,
    const std::string& requested_stat
);

edi::ResultMap fast_coxph_regression_internal(
    const Eigen::Ref<const Eigen::MatrixXd>& X,
    const Eigen::Ref<const Eigen::VectorXd>& y,
    const Eigen::Ref<const Eigen::VectorXd>& dead,
    std::optional<Eigen::VectorXd> warm_start_beta,
    bool smart_cold_start,
    bool estimate_only,
    int maxit,
    double tol,
    std::optional<Eigen::VectorXi> fixed_idx,
    std::optional<Eigen::VectorXd> fixed_values,
    std::string optimization_alg,
    std::optional<Eigen::MatrixXd> warm_start_fisher_info
);

edi::ResultMap fast_stratified_coxph_regression_internal(
    const Eigen::Ref<const Eigen::MatrixXd>& X,
    const Eigen::Ref<const Eigen::VectorXd>& y,
    const Eigen::Ref<const Eigen::VectorXd>& dead,
    const Eigen::Ref<const Eigen::VectorXi>& strata,
    std::optional<Eigen::VectorXd> warm_start_beta,
    bool smart_cold_start,
    bool estimate_only,
    int maxit,
    double tol,
    std::optional<Eigen::VectorXi> fixed_idx,
    std::optional<Eigen::VectorXd> fixed_values,
    std::string optimization_alg,
    std::optional<Eigen::MatrixXd> warm_start_fisher_info
);

edi::ResultMap fast_weibull_frailty_internal(
    const Eigen::Ref<const Eigen::MatrixXd>& X,
    const Eigen::Ref<const Eigen::VectorXd>& y,
    const Eigen::Ref<const Eigen::VectorXd>& dead,
    const Eigen::Ref<const Eigen::VectorXi>& group_id,
    std::optional<Eigen::VectorXd> warm_start_params,
    std::optional<Eigen::VectorXd> warm_start_beta,
    bool estimate_only,
    int n_gh,
    double max_abs_log_sigma,
    int maxit,
    double eps_g,
    std::optional<Eigen::VectorXi> fixed_idx,
    std::optional<Eigen::VectorXd> fixed_values,
    std::string optimization_alg,
    std::optional<Eigen::MatrixXd> warm_start_fisher_info
);

edi::ResultMap fast_clayton_weibull_aft_optim_internal(
    const Eigen::Ref<const Eigen::MatrixXd>& X,
    const Eigen::Ref<const Eigen::VectorXd>& y,
    const Eigen::Ref<const Eigen::VectorXd>& dead,
    const Eigen::Ref<const Eigen::MatrixXi>& pair_idx,
    const Eigen::Ref<const Eigen::VectorXi>& singleton_rows,
    const Eigen::Ref<const Eigen::VectorXd>& warm_start_params,
    bool estimate_only,
    int maxit,
    double reltol,
    std::optional<Eigen::VectorXi> fixed_idx,
    std::optional<Eigen::VectorXd> fixed_values,
    std::string optimization_alg,
    std::optional<Eigen::MatrixXd> warm_start_fisher_info
);

edi::ResultMap fast_dep_cens_transform_optim_internal(
    const Eigen::Ref<const Eigen::MatrixXd>& X,
    const Eigen::Ref<const Eigen::VectorXd>& y,
    const Eigen::Ref<const Eigen::VectorXd>& dead,
    std::optional<Eigen::VectorXd> warm_start_params,
    bool smart_cold_start,
    bool estimate_only,
    int maxit,
    double reltol,
    std::optional<Eigen::VectorXi> fixed_idx,
    std::optional<Eigen::VectorXd> fixed_values,
    std::string optimization_alg,
    std::optional<Eigen::MatrixXd> warm_start_fisher_info
);

// Renamed from fast_weibull_regression_general_internal (TODO-28: the fast
// exact/right-censored-only kernel was restored under its own name,
// fast_weibull_regression_internal -- not yet bound in Python; see that
// TODO for the follow-up to add it here too).
edi::ResultMap fast_weibull_regression_left_interval_censoring_internal(
    const Eigen::Ref<const Eigen::MatrixXd>& X,
    const Eigen::Ref<const Eigen::VectorXd>& y,
    const Eigen::Ref<const Eigen::VectorXd>& y_L,
    const Eigen::Ref<const Eigen::VectorXd>& y_R,
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

void bind_survival(py::module_& m) {
    m.def("fast_coxph_regression", [](const Eigen::Ref<const Eigen::MatrixXd>& X,
                                       const Eigen::Ref<const Eigen::VectorXd>& y,
                                       const Eigen::Ref<const Eigen::VectorXd>& dead,
                                       std::optional<Eigen::VectorXd> warm_start_beta,
                                       bool smart_cold_start,
                                       bool estimate_only,
                                       int maxit,
                                       double tol,
                                       std::optional<Eigen::VectorXi> fixed_idx,
                                       std::optional<Eigen::VectorXd> fixed_values,
                                       std::string optimization_alg,
                                       std::optional<Eigen::MatrixXd> warm_start_fisher_info) {
        edi::ResultMap res = fast_coxph_regression_internal(
            X, y, dead, warm_start_beta, smart_cold_start, estimate_only, maxit, tol,
            fixed_idx, fixed_values, optimization_alg, warm_start_fisher_info);
        return edi::to_py_dict(res);
    },
    py::arg("X"), py::arg("y"), py::arg("dead"),
    py::arg("warm_start_beta") = py::none(),
    py::arg("smart_cold_start") = true,
    py::arg("estimate_only") = false,
    py::arg("maxit") = 20,
    py::arg("tol") = 1e-9,
    py::arg("fixed_idx") = py::none(),
    py::arg("fixed_values") = py::none(),
    py::arg("optimization_alg") = "newton_raphson",
    py::arg("warm_start_fisher_info") = py::none(),
    "Fits the Cox proportional-hazards model, hazard(t | x_i) =\n"
    "h0(t)*exp(x_i^T beta) with an unspecified baseline hazard h0(t), by\n"
    "maximizing the Cox partial likelihood with Breslow's method for tied\n"
    "event times: PL(beta) = prod_{i: dead_i=1} exp(x_i^T beta) /\n"
    "(sum_{j in R(t_i)} exp(x_j^T beta))^{d_i}, where R(t_i) is the risk set\n"
    "at event time t_i (all subjects still under observation) and d_i is the\n"
    "number of tied events at t_i. Fit via Newton-Raphson on the log partial\n"
    "likelihood's score and (observed) information; unstratified, no\n"
    "cluster-robust sandwich vcov (the plain inverse-information covariance is\n"
    "returned). No R-side roxygen documents this raw kernel directly\n"
    "(fast_coxph_regression.cpp's roxygen documents a bootstrap helper, not\n"
    "this fit function); parameters follow the same conventions used\n"
    "throughout this module. Analogous to lifelines' CoxPHFitter; see\n"
    "https://lifelines.readthedocs.io/en/latest/fitters/regression/CoxPHFitter.html.\n\n"
    "Parameters\n"
    "----------\n"
    "X : ndarray\n"
    "    Numeric matrix of predictors (no intercept column -- Cox regression is\n"
    "    fit on the partial likelihood, which has none).\n"
    "y : ndarray\n"
    "    Numeric vector of survival/censoring times.\n"
    "dead : ndarray\n"
    "    0/1 event indicator (1 = event, 0 = censored), same length as y.\n"
    "warm_start_beta : ndarray, optional\n"
    "    Optional starting values for coefficients. If provided,\n"
    "    smart_cold_start is ignored.\n"
    "smart_cold_start : bool, default True\n"
    "    If True, use an initial OLS-based guess when starting from scratch. Ignored\n"
    "    if a warm start is provided.\n"
    "estimate_only : bool, default False\n"
    "    If True, skip variance-covariance computation and return only\n"
    "    coefficients.\n"
    "maxit : int, default 20\n"
    "    Maximum number of Newton-Raphson iterations.\n"
    "tol : float, default 1e-9\n"
    "    Convergence tolerance.\n"
    "fixed_idx : ndarray of int, optional\n"
    "    Optional indices of fixed parameters.\n"
    "fixed_values : ndarray, optional\n"
    "    Optional values for fixed parameters.\n"
    "optimization_alg : str, default \"newton_raphson\"\n"
    "    Optimization algorithm.\n"
    "warm_start_fisher_info : ndarray, optional\n"
    "    Optional initial Fisher information matrix for the first iteration.");

    m.def("fast_stratified_coxph_regression", [](const Eigen::Ref<const Eigen::MatrixXd>& X,
                                                  const Eigen::Ref<const Eigen::VectorXd>& y,
                                                  const Eigen::Ref<const Eigen::VectorXd>& dead,
                                                  const Eigen::Ref<const Eigen::VectorXi>& strata,
                                                  std::optional<Eigen::VectorXd> warm_start_beta,
                                                  bool smart_cold_start,
                                                  bool estimate_only,
                                                  int maxit,
                                                  double tol,
                                                  std::optional<Eigen::VectorXi> fixed_idx,
                                                  std::optional<Eigen::VectorXd> fixed_values,
                                                  std::string optimization_alg,
                                                  std::optional<Eigen::MatrixXd> warm_start_fisher_info) {
        edi::ResultMap res = fast_stratified_coxph_regression_internal(
            X, y, dead, strata, warm_start_beta, smart_cold_start, estimate_only, maxit, tol,
            fixed_idx, fixed_values, optimization_alg, warm_start_fisher_info);
        return edi::to_py_dict(res);
    },
    py::arg("X"), py::arg("y"), py::arg("dead"), py::arg("strata"),
    py::arg("warm_start_beta") = py::none(),
    py::arg("smart_cold_start") = true,
    py::arg("estimate_only") = false,
    py::arg("maxit") = 20,
    py::arg("tol") = 1e-9,
    py::arg("fixed_idx") = py::none(),
    py::arg("fixed_values") = py::none(),
    py::arg("optimization_alg") = "newton_raphson",
    py::arg("warm_start_fisher_info") = py::none(),
    "Fits a stratified Cox proportional-hazards model: hazard(t | x_i, s_i) =\n"
    "h0s_i(t)*exp(x_i^T beta), one baseline hazard h0s(t) per stratum s but a\n"
    "single shared beta across all strata. The partial likelihood is the\n"
    "product of each stratum's own Breslow-tie partial likelihood (see\n"
    "fast_coxph_regression's docstring for that formula), so risk sets never\n"
    "cross stratum boundaries -- this is how a covariate that violates the\n"
    "proportional-hazards assumption on its own can be \"stratified out\" (its\n"
    "effect absorbed into the per-stratum baseline) while beta is still\n"
    "estimated jointly for the covariates of interest. strata: integer group\n"
    "labels, any values (grouped internally, not required to be\n"
    "0-based/contiguous). Fit via Newton-Raphson, same as\n"
    "fast_coxph_regression. No R-side roxygen documents this raw kernel\n"
    "directly (fast_coxph_regression.cpp's roxygen documents a bootstrap\n"
    "helper, not this fit function); other parameters follow\n"
    "fast_coxph_regression's conventions (see its docstring). Analogous to\n"
    "lifelines' CoxPHFitter(strata=...); see\n"
    "https://lifelines.readthedocs.io/en/latest/fitters/regression/CoxPHFitter.html.\n\n"
    "Parameters\n"
    "----------\n"
    "X : ndarray\n"
    "    Numeric matrix of predictors (no intercept column).\n"
    "y : ndarray\n"
    "    Numeric vector of survival/censoring times.\n"
    "dead : ndarray\n"
    "    0/1 event indicator (1 = event, 0 = censored), same length as y.\n"
    "strata : ndarray of int\n"
    "    Stratum label for each subject; each stratum gets its own baseline\n"
    "    hazard while sharing one beta across all strata.\n"
    "warm_start_beta : ndarray, optional\n"
    "    Optional starting values for coefficients. If provided,\n"
    "    smart_cold_start is ignored.\n"
    "smart_cold_start : bool, default True\n"
    "    If True, use an initial OLS-based guess when starting from scratch. Ignored\n"
    "    if a warm start is provided.\n"
    "estimate_only : bool, default False\n"
    "    If True, skip variance-covariance computation and return only\n"
    "    coefficients.\n"
    "maxit : int, default 20\n"
    "    Maximum number of Newton-Raphson iterations.\n"
    "tol : float, default 1e-9\n"
    "    Convergence tolerance.\n"
    "fixed_idx : ndarray of int, optional\n"
    "    Optional indices of fixed parameters.\n"
    "fixed_values : ndarray, optional\n"
    "    Optional values for fixed parameters.\n"
    "optimization_alg : str, default \"newton_raphson\"\n"
    "    Optimization algorithm.\n"
    "warm_start_fisher_info : ndarray, optional\n"
    "    Optional initial Fisher information matrix for the first iteration.");

    m.def("fast_weibull_regression_general", [](const Eigen::Ref<const Eigen::MatrixXd>& X,
                                        const Eigen::Ref<const Eigen::VectorXd>& y,
                                        const Eigen::Ref<const Eigen::VectorXd>& y_L,
                                        const Eigen::Ref<const Eigen::VectorXd>& y_R,
                                        std::optional<Eigen::VectorXd> warm_start_params,
                                        bool smart_cold_start,
                                        bool estimate_only,
                                        int maxit,
                                        double tol,
                                        std::optional<Eigen::VectorXi> fixed_idx,
                                        std::optional<Eigen::VectorXd> fixed_values,
                                        std::string optimization_alg,
                                        std::optional<Eigen::MatrixXd> warm_start_fisher_info) {
        edi::ResultMap res = fast_weibull_regression_left_interval_censoring_internal(
            X, y, y_L, y_R, warm_start_params, smart_cold_start, estimate_only, maxit, tol,
            fixed_idx, fixed_values, optimization_alg, warm_start_fisher_info);
        return edi::to_py_dict(res);
    },
    py::arg("X"), py::arg("y"), py::arg("y_L"), py::arg("y_R"),
    py::arg("warm_start_params") = py::none(),
    py::arg("smart_cold_start") = true,
    py::arg("estimate_only") = false,
    py::arg("maxit") = 100,
    py::arg("tol") = 1e-8,
    py::arg("fixed_idx") = py::none(),
    py::arg("fixed_values") = py::none(),
    py::arg("optimization_alg") = "lbfgs",
    py::arg("warm_start_fisher_info") = py::none(),
    "Fits a Weibull accelerated-failure-time (AFT) regression by direct\n"
    "maximum likelihood via L-BFGS: log(T_i) = x_i^T beta + sigma*eps_i, with\n"
    "eps_i following a standard (extreme-value/Gumbel-minimum) distribution --\n"
    "equivalently, T_i ~ Weibull with scale exp(x_i^T beta) and shape 1/sigma,\n"
    "the same parameterization as R's survival::survreg(dist=\"weibull\").\n"
    "Exact observations are supplied in y; left-, interval-, and right-censored\n"
    "observations are supplied by their y_L/y_R bounds. sigma is optimized on the\n"
    "log scale for positivity. Returned 'params' = [beta, log_sigma].\n"
    "Parameters sourced from R/EDI/man/ documentation for\n"
    "fast_weibull_regression_general_cpp. Analogous to lifelines'\n"
    "WeibullAFTFitter or statsmodels' PHReg with a Weibull baseline; see\n"
    "https://lifelines.readthedocs.io/en/latest/fitters/regression/WeibullAFTFitter.html.\n\n"
    "Parameters\n"
    "----------\n"
    "X : ndarray\n"
    "    A numeric matrix of predictors.\n"
    "y : ndarray\n"
    "    Exact survival times; NaN for censored observations.\n"
    "y_L : ndarray\n"
    "    Lower censoring bounds; NaN for exact observations and 0 for left censoring.\n"
    "y_R : ndarray\n"
    "    Upper censoring bounds; NaN for exact observations and inf for right censoring.\n"
    "warm_start_params : ndarray, optional\n"
    "    Optional starting values for coefficients.\n"
    "smart_cold_start : bool, default True\n"
    "    If True, use an initial OLS-based guess.\n"
    "estimate_only : bool, default False\n"
    "    If True, do not compute the variance-covariance matrix.\n"
    "maxit : int, default 100\n"
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
    "    Optional initial Fisher information matrix.");

    m.def("fast_weibull_frailty", [](const Eigen::Ref<const Eigen::MatrixXd>& X,
                                      const Eigen::Ref<const Eigen::VectorXd>& y,
                                      const Eigen::Ref<const Eigen::VectorXd>& dead,
                                      const Eigen::Ref<const Eigen::VectorXi>& group_id,
                                      std::optional<Eigen::VectorXd> warm_start_params,
                                      std::optional<Eigen::VectorXd> warm_start_beta,
                                      bool estimate_only,
                                      int n_gh,
                                      double max_abs_log_sigma,
                                      int maxit,
                                      double eps_g,
                                      std::optional<Eigen::VectorXi> fixed_idx,
                                      std::optional<Eigen::VectorXd> fixed_values,
                                      std::string optimization_alg,
                                      std::optional<Eigen::MatrixXd> warm_start_fisher_info) {
        edi::ResultMap res = fast_weibull_frailty_internal(
            X, y, dead, group_id, warm_start_params, warm_start_beta, estimate_only,
            n_gh, max_abs_log_sigma, maxit, eps_g, fixed_idx, fixed_values,
            optimization_alg, warm_start_fisher_info);
        return edi::to_py_dict(res);
    },
    py::arg("X"), py::arg("y"), py::arg("dead"), py::arg("group_id"),
    py::arg("warm_start_params") = py::none(),
    py::arg("warm_start_beta") = py::none(),
    py::arg("estimate_only") = false,
    py::arg("n_gh") = 20,
    py::arg("max_abs_log_sigma") = 8.0,
    py::arg("maxit") = 300,
    py::arg("eps_g") = 1e-6,
    py::arg("fixed_idx") = py::none(),
    py::arg("fixed_values") = py::none(),
    py::arg("optimization_alg") = "lbfgs",
    py::arg("warm_start_fisher_info") = py::none(),
    "Fits a Weibull AFT model (see fast_weibull_regression_general's docstring for the\n"
    "base log(T_i) = x_i^T beta + sigma*eps_i parameterization) extended with\n"
    "a shared log-scale random intercept (frailty) per group: log(T_i) =\n"
    "x_i^T beta + b_{group_id_i} + sigma*eps_i, b_g ~ Normal(0,\n"
    "sigma_frailty^2) i.i.d. across groups. The random effect is integrated\n"
    "out of the marginal likelihood via fixed-node Gauss-Hermite quadrature\n"
    "(n_gh nodes) rather than a closed-form expression (unlike a true\n"
    "gamma-frailty Cox model, this Gaussian-on-the-log-time-scale frailty has\n"
    "no closed form), and the resulting marginal log-likelihood is maximized\n"
    "via L-BFGS over [beta, log_sigma_shape, log_sigma_frailty]. Both\n"
    "log-scale parameters are clamped to +/- max_abs_log_sigma to keep the\n"
    "quadrature well-behaved. No R-side roxygen documents this raw kernel\n"
    "directly (fast_weibull_frailty.cpp has none); shared adaptive-quadrature\n"
    "parameter meanings (n_gh/max_abs_log_sigma/etc.) are grounded in\n"
    "R/EDI/man/ documentation for the GLMM-engine sibling\n"
    "fast_ordinal_glmm_cpp. Analogous to R's frailtypack or coxme for\n"
    "shared-frailty survival models (no direct scikit-survival/lifelines\n"
    "equivalent for a Weibull AFT frailty model).\n\n"
    "Parameters\n"
    "----------\n"
    "X : ndarray\n"
    "    A numeric matrix of predictors.\n"
    "y : ndarray\n"
    "    A numeric vector of survival times.\n"
    "dead : ndarray\n"
    "    0/1 event indicator (1 = event, 0 = censored).\n"
    "group_id : ndarray of int\n"
    "    Group (shared-frailty cluster) identifiers, one per row of X/y.\n"
    "warm_start_params : ndarray, optional\n"
    "    Optional starting values for all parameters [beta, log_sigma_shape,\n"
    "    log_sigma_frailty].\n"
    "warm_start_beta : ndarray, optional\n"
    "    Optional starting values for the coefficients only.\n"
    "estimate_only : bool, default False\n"
    "    If True, skip variance-component calculations.\n"
    "n_gh : int, default 20\n"
    "    Number of Gauss-Hermite quadrature nodes used to integrate out the\n"
    "    shared frailty term.\n"
    "max_abs_log_sigma : float, default 8.0\n"
    "    Maximum allowed value for log(sigma) (the frailty SD).\n"
    "maxit : int, default 300\n"
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
    "    Optional initial Fisher information matrix for the first iteration.");

    m.def("fast_clayton_weibull_aft_optim", [](const Eigen::Ref<const Eigen::MatrixXd>& X,
                                                const Eigen::Ref<const Eigen::VectorXd>& y,
                                                const Eigen::Ref<const Eigen::VectorXd>& dead,
                                                const Eigen::Ref<const Eigen::MatrixXi>& pair_idx,
                                                const Eigen::Ref<const Eigen::VectorXi>& singleton_rows,
                                                const Eigen::Ref<const Eigen::VectorXd>& warm_start_params,
                                                bool estimate_only,
                                                int maxit,
                                                double reltol,
                                                std::optional<Eigen::VectorXi> fixed_idx,
                                                std::optional<Eigen::VectorXd> fixed_values,
                                                std::string optimization_alg,
                                                std::optional<Eigen::MatrixXd> warm_start_fisher_info) {
        edi::ResultMap res = fast_clayton_weibull_aft_optim_internal(
            X, y, dead, pair_idx, singleton_rows, warm_start_params, estimate_only,
            maxit, reltol, fixed_idx, fixed_values, optimization_alg, warm_start_fisher_info);
        return edi::to_py_dict(res);
    },
    py::arg("X"), py::arg("y"), py::arg("dead"), py::arg("pair_idx"), py::arg("singleton_rows"),
    py::arg("warm_start_params"),
    py::arg("estimate_only") = false,
    py::arg("maxit") = 2000,
    py::arg("reltol") = 1e-9,
    py::arg("fixed_idx") = py::none(),
    py::arg("fixed_values") = py::none(),
    py::arg("optimization_alg") = "lbfgs",
    py::arg("warm_start_fisher_info") = py::none(),
    "Fast Clayton-copula Weibull AFT regression (matched pairs + singleton reservoir "
    "design) via L-BFGS. pair_idx: 0-based (n_pairs x 2) row indices into X/y/dead; "
    "singleton_rows: 0-based row indices of reservoir singletons. warm_start_params "
    "is required (no default cold start). No R-side roxygen documents this raw "
    "kernel directly (fast_survival_models_optim.cpp has none).\n\n"
    "Parameters\n"
    "----------\n"
    "X : ndarray\n"
    "    A numeric matrix of predictors.\n"
    "y : ndarray\n"
    "    A numeric vector of survival/censoring times.\n"
    "dead : ndarray\n"
    "    0/1 event indicator (1 = event, 0 = censored).\n"
    "pair_idx : ndarray of int\n"
    "    0-based (n_pairs, 2) matrix of row indices into X/y/dead identifying\n"
    "    each Clayton-copula-dependent matched pair.\n"
    "singleton_rows : ndarray of int\n"
    "    0-based row indices of reservoir subjects not in any pair (treated as\n"
    "    independent).\n"
    "warm_start_params : ndarray\n"
    "    Required starting values for all parameters (no default cold start is\n"
    "    implemented for this kernel).\n"
    "estimate_only : bool, default False\n"
    "    If True, skip variance-covariance computation and return only\n"
    "    coefficients.\n"
    "maxit : int, default 2000\n"
    "    Maximum number of iterations.\n"
    "reltol : float, default 1e-9\n"
    "    Relative convergence tolerance.\n"
    "fixed_idx : ndarray of int, optional\n"
    "    Optional indices of fixed parameters.\n"
    "fixed_values : ndarray, optional\n"
    "    Optional values for fixed parameters.\n"
    "optimization_alg : str, default \"lbfgs\"\n"
    "    Optimization algorithm.\n"
    "warm_start_fisher_info : ndarray, optional\n"
    "    Optional initial Fisher information matrix for the first iteration.");

    m.def("fast_dep_cens_transform_optim", [](const Eigen::Ref<const Eigen::MatrixXd>& X,
                                               const Eigen::Ref<const Eigen::VectorXd>& y,
                                               const Eigen::Ref<const Eigen::VectorXd>& dead,
                                               std::optional<Eigen::VectorXd> warm_start_params,
                                               bool smart_cold_start,
                                               bool estimate_only,
                                               int maxit,
                                               double reltol,
                                               std::optional<Eigen::VectorXi> fixed_idx,
                                               std::optional<Eigen::VectorXd> fixed_values,
                                               std::string optimization_alg,
                                               std::optional<Eigen::MatrixXd> warm_start_fisher_info) {
        edi::ResultMap res = fast_dep_cens_transform_optim_internal(
            X, y, dead, warm_start_params, smart_cold_start, estimate_only, maxit, reltol,
            fixed_idx, fixed_values, optimization_alg, warm_start_fisher_info);
        return edi::to_py_dict(res);
    },
    py::arg("X"), py::arg("y"), py::arg("dead"),
    py::arg("warm_start_params") = py::none(),
    py::arg("smart_cold_start") = true,
    py::arg("estimate_only") = false,
    py::arg("maxit") = 2000,
    py::arg("reltol") = 1e-9,
    py::arg("fixed_idx") = py::none(),
    py::arg("fixed_values") = py::none(),
    py::arg("optimization_alg") = "lbfgs",
    py::arg("warm_start_fisher_info") = py::none(),
    "Fast dependent-censoring transformation-model regression via L-BFGS. No "
    "R-side roxygen documents this raw kernel directly "
    "(fast_survival_models_optim.cpp has none); parameters follow the same "
    "conventions used throughout this module.\n\n"
    "Parameters\n"
    "----------\n"
    "X : ndarray\n"
    "    A numeric matrix of predictors.\n"
    "y : ndarray\n"
    "    A numeric vector of survival/censoring times.\n"
    "dead : ndarray\n"
    "    0/1 event indicator (1 = event, 0 = censored).\n"
    "warm_start_params : ndarray, optional\n"
    "    Optional starting values for all parameters. If provided,\n"
    "    smart_cold_start is ignored.\n"
    "smart_cold_start : bool, default True\n"
    "    If True, use an initial OLS-based guess when starting from scratch. Ignored\n"
    "    if a warm start is provided.\n"
    "estimate_only : bool, default False\n"
    "    If True, skip variance-covariance computation and return only\n"
    "    coefficients.\n"
    "maxit : int, default 2000\n"
    "    Maximum number of iterations.\n"
    "reltol : float, default 1e-9\n"
    "    Relative convergence tolerance.\n"
    "fixed_idx : ndarray of int, optional\n"
    "    Optional indices of fixed parameters.\n"
    "fixed_values : ndarray, optional\n"
    "    Optional values for fixed parameters.\n"
    "optimization_alg : str, default \"lbfgs\"\n"
    "    Optimization algorithm.\n"
    "warm_start_fisher_info : ndarray, optional\n"
    "    Optional initial Fisher information matrix for the first iteration.");

    m.def("fast_gehan_wilcox_stats", [](const Eigen::Ref<const Eigen::VectorXd>& time,
                                         const std::vector<int>& dead,
                                         const std::vector<int>& w) {
        ModelResult res = fast_gehan_wilcox_result(time, dead, w);
        int n_treat = 0;
        for (int val : w) if (val == 1) ++n_treat;
        py::dict out;
        out["score"] = res.dispersion;
        out["var_score"] = (res.sigma2_hat > 0.0) ? py::cast(res.sigma2_hat) : py::cast(std::numeric_limits<double>::quiet_NaN());
        out["beta_hat"] = res.b.size() > 0 ? res.b[0] : std::numeric_limits<double>::quiet_NaN();
        out["se_beta_hat"] = res.ssq_b_2;
        out["n_treat"] = n_treat;
        out["n_control"] = static_cast<int>(w.size()) - n_treat;
        return out;
    },
    py::arg("time"), py::arg("dead"), py::arg("w"),
    "Peto-Prentice (Gehan-Wilcoxon, rho=1) two-sample survival test. dead/w are "
    "0/1 vectors (event indicator / treatment indicator). Returns score, "
    "var_score (Peto-Prentice-weighted logrank score/variance), beta_hat "
    "(treatment-minus-control mean of Peto-Prentice-weighted martingale "
    "residuals -- the point estimate), se_beta_hat, n_treat, n_control. No "
    "R-side roxygen documents this raw kernel directly (fast_gehan_wilcox.cpp "
    "has none).\n\n"
    "Parameters\n"
    "----------\n"
    "time : ndarray\n"
    "    Numeric vector of survival/censoring times.\n"
    "dead : list of int\n"
    "    0/1 event indicator (1 = event, 0 = censored), same length as time.\n"
    "w : list of int\n"
    "    0/1 treatment indicator, same length as time.");

    m.def("fast_logrank_stats", [](const Eigen::Ref<const Eigen::VectorXd>& time,
                                    const std::vector<int>& dead,
                                    const std::vector<int>& w) {
        ModelResult res = fast_logrank_result(time, dead, w);
        int n_treat = 0;
        for (int val : w) if (val == 1) ++n_treat;
        py::dict out;
        out["score"] = res.dispersion;
        out["var_score"] = (res.sigma2_hat > 0.0) ? py::cast(res.sigma2_hat) : py::cast(std::numeric_limits<double>::quiet_NaN());
        out["beta_hat"] = res.b.size() > 0 ? res.b[0] : std::numeric_limits<double>::quiet_NaN();
        out["se_beta_hat"] = res.ssq_b_2;
        out["n_treat"] = n_treat;
        out["n_control"] = static_cast<int>(w.size()) - n_treat;
        return out;
    },
    py::arg("time"), py::arg("dead"), py::arg("w"),
    "Standard (rho=0) two-sample log-rank test. dead/w are 0/1 vectors "
    "(event indicator / treatment indicator). Returns score, var_score, "
    "beta_hat (treatment-minus-control mean of martingale residuals -- the "
    "point estimate), se_beta_hat, n_treat, n_control. No R-side roxygen "
    "documents this raw kernel directly (fast_logrank.cpp has none).\n\n"
    "Parameters\n"
    "----------\n"
    "time : ndarray\n"
    "    Numeric vector of survival/censoring times.\n"
    "dead : list of int\n"
    "    0/1 event indicator (1 = event, 0 = censored), same length as time.\n"
    "w : list of int\n"
    "    0/1 treatment indicator, same length as time.");

    m.def("get_survival_stat_diff", &get_survival_stat_diff_result,
    py::arg("y"), py::arg("dead"), py::arg("w"), py::arg("requested_stat") = "median",
    "Difference (treatment minus control) in a per-group Kaplan-Meier "
    "statistic. requested_stat is 'median' (KM median survival time, "
    "matching survival::quantile.survfit's step-function semantics) or "
    "'restricted_mean'. dead/w are 0/1 vectors (event indicator / treatment "
    "indicator). Parameters sourced from R/EDI/man/ documentation for this "
    "same-named function in R/EDI/src/fast_survival_stats.cpp.\n\n"
    "Parameters\n"
    "----------\n"
    "y : ndarray\n"
    "    Numeric vector of survival times.\n"
    "dead : ndarray of int\n"
    "    Event indicator (1=event, 0=censored).\n"
    "w : ndarray of int\n"
    "    Treatment assignment (1=treatment, 0=control).\n"
    "requested_stat : str, default \"median\"\n"
    "    Either \"median\" or \"restricted_mean\".");
}
