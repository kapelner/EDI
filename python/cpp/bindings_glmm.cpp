// Binds GLMM-family model-fitting kernels. fast_poisson_glmm_internal is
// *defined* in R/EDI/src/fast_poisson_glmm.cpp, which is compiled as its own
// source in this same CMake target (see ../CMakeLists.txt) -- it is
// declared, not redefined, here. Nothing under python/ is a copy of
// anything in R/EDI/src.

#include <pybind11/pybind11.h>
#include <pybind11/eigen.h>
#include <pybind11/stl.h>
#include "result_map_pybind.h"
#include <Eigen/Dense>
#include <optional>
#include <string>

namespace py = pybind11;

edi::ResultMap fast_poisson_glmm_internal(
    const Eigen::Ref<const Eigen::MatrixXd>& X,
    const Eigen::Ref<const Eigen::VectorXd>& y,
    const Eigen::Ref<const Eigen::VectorXi>& group_id,
    int j_T,
    std::optional<Eigen::VectorXd> warm_start_params,
    bool smart_cold_start,
    bool estimate_only,
    int n_gh,
    int maxit,
    double eps_g,
    std::optional<Eigen::VectorXi> fixed_idx,
    std::optional<Eigen::VectorXd> fixed_values,
    std::string optimization_alg,
    std::optional<Eigen::MatrixXd> warm_start_fisher_info,
    std::optional<Eigen::VectorXd> row_weights
);

edi::ResultMap fast_gaussian_lmm_internal(
    const Eigen::Ref<const Eigen::MatrixXd>& X,
    const Eigen::Ref<const Eigen::VectorXd>& y,
    const Eigen::Ref<const Eigen::VectorXi>& group_id,
    std::optional<Eigen::VectorXd> warm_start_params,
    std::optional<Eigen::VectorXd> warm_start_beta,
    bool estimate_only,
    int maxit,
    double eps_g,
    std::optional<Eigen::VectorXi> fixed_idx,
    std::optional<Eigen::VectorXd> fixed_values,
    std::string optimization_alg,
    std::optional<Eigen::MatrixXd> warm_start_fisher_info,
    std::optional<Eigen::VectorXd> weights
);

edi::ResultMap fast_hurdle_poisson_glmm_internal(
    const Eigen::Ref<const Eigen::MatrixXd>& X,
    const Eigen::Ref<const Eigen::VectorXd>& y,
    const Eigen::Ref<const Eigen::VectorXi>& group_id,
    int j_T,
    std::optional<Eigen::VectorXd> warm_start_params,
    bool smart_cold_start,
    bool estimate_only,
    int n_gh,
    int maxit,
    double eps_g,
    std::string optimization_alg,
    std::optional<Eigen::VectorXi> fixed_idx,
    std::optional<Eigen::VectorXd> fixed_values,
    std::optional<Eigen::MatrixXd> warm_start_fisher_info
);

edi::ResultMap fast_clogit_plus_glmm_internal(
    const Eigen::Ref<const Eigen::MatrixXd>& X_disc,
    const Eigen::Ref<const Eigen::VectorXd>& y_disc,
    const Eigen::Ref<const Eigen::MatrixXd>& X_conc,
    const Eigen::Ref<const Eigen::VectorXd>& y_conc,
    const Eigen::Ref<const Eigen::VectorXi>& group_conc,
    bool has_discordant,
    bool has_concordant,
    std::optional<Eigen::VectorXd> warm_start_params,
    std::optional<Eigen::VectorXd> warm_start_beta,
    bool estimate_only,
    double max_abs_log_sigma,
    int maxit,
    double eps_g,
    std::optional<Eigen::VectorXi> fixed_idx,
    std::optional<Eigen::VectorXd> fixed_values,
    std::string optimization_alg,
    std::optional<Eigen::MatrixXd> warm_start_fisher_info,
    int n_gh
);

edi::ResultMap fast_logistic_glmm_internal(
    const Eigen::Ref<const Eigen::MatrixXd>& X,
    const Eigen::Ref<const Eigen::VectorXd>& y,
    const Eigen::Ref<const Eigen::VectorXi>& group_id,
    int j_T,
    std::optional<Eigen::VectorXd> warm_start_params,
    bool smart_cold_start,
    bool estimate_only,
    int n_gh,
    int maxit,
    double eps_g,
    std::string optimization_alg,
    std::optional<Eigen::VectorXi> fixed_idx,
    std::optional<Eigen::VectorXd> fixed_values,
    std::optional<Eigen::MatrixXd> warm_start_fisher_info
);

void bind_glmm(py::module_& m) {
    m.def("fast_poisson_glmm", [](const Eigen::Ref<const Eigen::MatrixXd>& X,
                                   const Eigen::Ref<const Eigen::VectorXd>& y,
                                   const Eigen::Ref<const Eigen::VectorXi>& group_id,
                                   int j_T,
                                   std::optional<Eigen::VectorXd> warm_start_params,
                                   bool smart_cold_start,
                                   bool estimate_only,
                                   int n_gh,
                                   int maxit,
                                   double eps_g,
                                   std::optional<Eigen::VectorXi> fixed_idx,
                                   std::optional<Eigen::VectorXd> fixed_values,
                                   std::string optimization_alg,
                                   std::optional<Eigen::MatrixXd> warm_start_fisher_info,
                                   std::optional<Eigen::VectorXd> row_weights) {
        return edi::to_py_dict(fast_poisson_glmm_internal(
            X, y, group_id, j_T, warm_start_params, smart_cold_start,
            estimate_only, n_gh, maxit, eps_g, fixed_idx, fixed_values,
            optimization_alg, warm_start_fisher_info, row_weights));
    },
    py::arg("X"), py::arg("y"), py::arg("group_id"), py::arg("j_T"),
    py::arg("warm_start_params") = py::none(),
    py::arg("smart_cold_start") = true,
    py::arg("estimate_only") = false,
    py::arg("n_gh") = 20,
    py::arg("maxit") = 300,
    py::arg("eps_g") = 1e-6,
    py::arg("fixed_idx") = py::none(),
    py::arg("fixed_values") = py::none(),
    py::arg("optimization_alg") = "lbfgs",
    py::arg("warm_start_fisher_info") = py::none(),
    py::arg("row_weights") = py::none(),
    "Fit a Poisson GLMM with a random intercept via Gauss-Hermite quadrature + "
    "L-BFGS. No R-side roxygen documents this raw kernel directly "
    "(fast_poisson_glmm.cpp has none); shared adaptive-quadrature parameter "
    "meanings (group_id/j_T/n_gh/etc.) are grounded in R/EDI/man/ documentation "
    "for the sibling fast_ordinal_glmm_cpp, which uses the same GLMM engine.\n\n"
    "Parameters\n"
    "----------\n"
    "X : ndarray\n"
    "    Numeric matrix of predictors (no intercept column).\n"
    "y : ndarray\n"
    "    Numeric vector of count responses.\n"
    "group_id : ndarray of int\n"
    "    Group (random-intercept cluster) identifiers, one per row of X/y.\n"
    "j_T : int\n"
    "    0-based index of the treatment effect in the beta vector.\n"
    "warm_start_params : ndarray, optional\n"
    "    Optional starting values for all parameters [beta, log_sigma]. If\n"
    "    provided, smart_cold_start is ignored.\n"
    "smart_cold_start : bool, default True\n"
    "    If True, use an initial OLS-based guess when starting from scratch. Ignored\n"
    "    if a warm start is provided.\n"
    "estimate_only : bool, default False\n"
    "    If True, skip variance-component calculations.\n"
    "n_gh : int, default 20\n"
    "    Number of Gauss-Hermite quadrature nodes used to integrate out the random\n"
    "    intercept.\n"
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
    "    Optional initial Fisher information matrix for the first iteration.\n"
    "row_weights : ndarray, optional\n"
    "    Optional nonnegative row weights for a weighted fit.");

    m.def("fast_gaussian_lmm", [](const Eigen::Ref<const Eigen::MatrixXd>& X,
                                   const Eigen::Ref<const Eigen::VectorXd>& y,
                                   const Eigen::Ref<const Eigen::VectorXi>& group_id,
                                   std::optional<Eigen::VectorXd> warm_start_params,
                                   std::optional<Eigen::VectorXd> warm_start_beta,
                                   bool estimate_only,
                                   int maxit,
                                   double eps_g,
                                   std::optional<Eigen::VectorXi> fixed_idx,
                                   std::optional<Eigen::VectorXd> fixed_values,
                                   std::string optimization_alg,
                                   std::optional<Eigen::MatrixXd> warm_start_fisher_info,
                                   std::optional<Eigen::VectorXd> weights) {
        edi::ResultMap res = fast_gaussian_lmm_internal(
            X, y, group_id, warm_start_params, warm_start_beta, estimate_only,
            maxit, eps_g, fixed_idx, fixed_values, optimization_alg, warm_start_fisher_info, weights);
        return edi::to_py_dict(res);
    },
    py::arg("X"), py::arg("y"), py::arg("group_id"),
    py::arg("warm_start_params") = py::none(),
    py::arg("warm_start_beta") = py::none(),
    py::arg("estimate_only") = false,
    py::arg("maxit") = 300,
    py::arg("eps_g") = 1e-6,
    py::arg("fixed_idx") = py::none(),
    py::arg("fixed_values") = py::none(),
    py::arg("optimization_alg") = "lbfgs",
    py::arg("warm_start_fisher_info") = py::none(),
    py::arg("weights") = py::none(),
    "Fit a Gaussian LMM with a random intercept via L-BFGS. Returned 'b' is "
    "[beta, log_sigma_e, log_sigma_b] (plain array, not R's named vector). No "
    "R-side roxygen documents this raw kernel directly (fast_gaussian_lmm.cpp has "
    "none); shared parameter meanings are grounded in R/EDI/man/ documentation for "
    "the sibling fast_ordinal_glmm_cpp.\n\n"
    "Parameters\n"
    "----------\n"
    "X : ndarray\n"
    "    Numeric matrix of predictors (no intercept column).\n"
    "y : ndarray\n"
    "    Numeric vector of continuous responses.\n"
    "group_id : ndarray of int\n"
    "    Group (random-intercept cluster) identifiers, one per row of X/y.\n"
    "warm_start_params : ndarray, optional\n"
    "    Optional starting values for all parameters [beta, log_sigma_e,\n"
    "    log_sigma_b].\n"
    "warm_start_beta : ndarray, optional\n"
    "    Optional starting values for the fixed-effect coefficients only.\n"
    "estimate_only : bool, default False\n"
    "    If True, skip variance-component calculations.\n"
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
    "    Optional initial Fisher information matrix for the first iteration.\n"
    "weights : ndarray, optional\n"
    "    Optional nonnegative row weights for a weighted fit.");

    m.def("fast_logistic_glmm", [](const Eigen::Ref<const Eigen::MatrixXd>& X,
                                    const Eigen::Ref<const Eigen::VectorXd>& y,
                                    const Eigen::Ref<const Eigen::VectorXi>& group_id,
                                    int j_T,
                                    std::optional<Eigen::VectorXd> warm_start_params,
                                    bool smart_cold_start,
                                    bool estimate_only,
                                    int n_gh,
                                    int maxit,
                                    double eps_g,
                                    std::string optimization_alg,
                                    std::optional<Eigen::VectorXi> fixed_idx,
                                    std::optional<Eigen::VectorXd> fixed_values,
                                    std::optional<Eigen::MatrixXd> warm_start_fisher_info) {
        edi::ResultMap res = fast_logistic_glmm_internal(
            X, y, group_id, j_T, warm_start_params, smart_cold_start, estimate_only,
            n_gh, maxit, eps_g, optimization_alg, fixed_idx, fixed_values, warm_start_fisher_info);
        return edi::to_py_dict(res);
    },
    py::arg("X"), py::arg("y"), py::arg("group_id"), py::arg("j_T"),
    py::arg("warm_start_params") = py::none(),
    py::arg("smart_cold_start") = true,
    py::arg("estimate_only") = false,
    py::arg("n_gh") = 20,
    py::arg("maxit") = 300,
    py::arg("eps_g") = 1e-6,
    py::arg("optimization_alg") = "lbfgs",
    py::arg("fixed_idx") = py::none(),
    py::arg("fixed_values") = py::none(),
    py::arg("warm_start_fisher_info") = py::none(),
    "Fit a Logistic GLMM with a random intercept via Gauss-Hermite quadrature + "
    "L-BFGS. No R-side roxygen documents this raw kernel directly "
    "(fast_logistic_glmm.cpp has none) -- and unlike every other kernel in this "
    "module, this one currently has no R6 consumer class in R/EDI/R either (bound "
    "and working, but nothing in the R package calls it yet); parameter meanings "
    "are grounded in R/EDI/man/ documentation for the sibling fast_ordinal_glmm_cpp, "
    "which uses the same GLMM engine.\n\n"
    "Parameters\n"
    "----------\n"
    "X : ndarray\n"
    "    Numeric matrix of predictors (no intercept column).\n"
    "y : ndarray\n"
    "    Numeric vector of binary (0/1) responses.\n"
    "group_id : ndarray of int\n"
    "    Group (random-intercept cluster) identifiers, one per row of X/y.\n"
    "j_T : int\n"
    "    0-based index of the treatment effect in the beta vector.\n"
    "warm_start_params : ndarray, optional\n"
    "    Optional starting values for all parameters [beta, log_sigma]. If\n"
    "    provided, smart_cold_start is ignored.\n"
    "smart_cold_start : bool, default True\n"
    "    If True, use an initial OLS-based guess when starting from scratch. Ignored\n"
    "    if a warm start is provided.\n"
    "estimate_only : bool, default False\n"
    "    If True, skip variance-component calculations.\n"
    "n_gh : int, default 20\n"
    "    Number of Gauss-Hermite quadrature nodes used to integrate out the random\n"
    "    intercept.\n"
    "maxit : int, default 300\n"
    "    Maximum number of iterations.\n"
    "eps_g : float, default 1e-6\n"
    "    Convergence tolerance for the gradient.\n"
    "optimization_alg : str, default \"lbfgs\"\n"
    "    Optimization algorithm.\n"
    "fixed_idx : ndarray of int, optional\n"
    "    Optional indices of fixed parameters.\n"
    "fixed_values : ndarray, optional\n"
    "    Optional values for fixed parameters.\n"
    "warm_start_fisher_info : ndarray, optional\n"
    "    Optional initial Fisher information matrix for the first iteration.");

    m.def("fast_hurdle_poisson_glmm", [](const Eigen::Ref<const Eigen::MatrixXd>& X,
                                          const Eigen::Ref<const Eigen::VectorXd>& y,
                                          const Eigen::Ref<const Eigen::VectorXi>& group_id,
                                          int j_T,
                                          std::optional<Eigen::VectorXd> warm_start_params,
                                          bool smart_cold_start,
                                          bool estimate_only,
                                          int n_gh,
                                          int maxit,
                                          double eps_g,
                                          std::string optimization_alg,
                                          std::optional<Eigen::VectorXi> fixed_idx,
                                          std::optional<Eigen::VectorXd> fixed_values,
                                          std::optional<Eigen::MatrixXd> warm_start_fisher_info) {
        edi::ResultMap res = fast_hurdle_poisson_glmm_internal(
            X, y, group_id, j_T, warm_start_params, smart_cold_start, estimate_only,
            n_gh, maxit, eps_g, optimization_alg, fixed_idx, fixed_values, warm_start_fisher_info);
        return edi::to_py_dict(res);
    },
    py::arg("X"), py::arg("y"), py::arg("group_id"), py::arg("j_T"),
    py::arg("warm_start_params") = py::none(),
    py::arg("smart_cold_start") = true,
    py::arg("estimate_only") = false,
    py::arg("n_gh") = 7,
    py::arg("maxit") = 300,
    py::arg("eps_g") = 1e-6,
    py::arg("optimization_alg") = "lbfgs",
    py::arg("fixed_idx") = py::none(),
    py::arg("fixed_values") = py::none(),
    py::arg("warm_start_fisher_info") = py::none(),
    "Fit a Hurdle-Poisson GLMM with a random intercept via Gauss-Hermite "
    "quadrature + L-BFGS. No R-side roxygen documents this raw kernel directly "
    "(fast_hurdle_poisson_glmm.cpp has none); parameter meanings are grounded in "
    "R/EDI/man/ documentation for the sibling fast_ordinal_glmm_cpp, which uses the "
    "same GLMM engine.\n\n"
    "Parameters\n"
    "----------\n"
    "X : ndarray\n"
    "    Numeric matrix of predictors (no intercept column).\n"
    "y : ndarray\n"
    "    Numeric vector of count responses.\n"
    "group_id : ndarray of int\n"
    "    Group (random-intercept cluster) identifiers, one per row of X/y.\n"
    "j_T : int\n"
    "    0-based index of the treatment effect in the beta vector.\n"
    "warm_start_params : ndarray, optional\n"
    "    Optional starting values for all parameters. If provided,\n"
    "    smart_cold_start is ignored.\n"
    "smart_cold_start : bool, default True\n"
    "    If True, use an initial OLS-based guess when starting from scratch. Ignored\n"
    "    if a warm start is provided.\n"
    "estimate_only : bool, default False\n"
    "    If True, skip variance-component calculations.\n"
    "n_gh : int, default 7\n"
    "    Number of Gauss-Hermite quadrature nodes used to integrate out the random\n"
    "    intercept.\n"
    "maxit : int, default 300\n"
    "    Maximum number of iterations.\n"
    "eps_g : float, default 1e-6\n"
    "    Convergence tolerance for the gradient.\n"
    "optimization_alg : str, default \"lbfgs\"\n"
    "    Optimization algorithm.\n"
    "fixed_idx : ndarray of int, optional\n"
    "    Optional indices of fixed parameters.\n"
    "fixed_values : ndarray, optional\n"
    "    Optional values for fixed parameters.\n"
    "warm_start_fisher_info : ndarray, optional\n"
    "    Optional initial Fisher information matrix for the first iteration.");

    m.def("fast_clogit_plus_glmm", [](const Eigen::Ref<const Eigen::MatrixXd>& X_disc,
                                       const Eigen::Ref<const Eigen::VectorXd>& y_disc,
                                       const Eigen::Ref<const Eigen::MatrixXd>& X_conc,
                                       const Eigen::Ref<const Eigen::VectorXd>& y_conc,
                                       const Eigen::Ref<const Eigen::VectorXi>& group_conc,
                                       bool has_discordant,
                                       bool has_concordant,
                                       std::optional<Eigen::VectorXd> warm_start_params,
                                       std::optional<Eigen::VectorXd> warm_start_beta,
                                       bool estimate_only,
                                       double max_abs_log_sigma,
                                       int maxit,
                                       double eps_g,
                                       std::optional<Eigen::VectorXi> fixed_idx,
                                       std::optional<Eigen::VectorXd> fixed_values,
                                       std::string optimization_alg,
                                       std::optional<Eigen::MatrixXd> warm_start_fisher_info,
                                       int n_gh) {
        edi::ResultMap res = fast_clogit_plus_glmm_internal(
            X_disc, y_disc, X_conc, y_conc, group_conc, has_discordant, has_concordant,
            warm_start_params, warm_start_beta, estimate_only, max_abs_log_sigma, maxit, eps_g,
            fixed_idx, fixed_values, optimization_alg, warm_start_fisher_info, n_gh);
        return edi::to_py_dict(res);
    },
    py::arg("X_disc"), py::arg("y_disc"), py::arg("X_conc"), py::arg("y_conc"), py::arg("group_conc"),
    py::arg("has_discordant"), py::arg("has_concordant"),
    py::arg("warm_start_params") = py::none(),
    py::arg("warm_start_beta") = py::none(),
    py::arg("estimate_only") = false,
    py::arg("max_abs_log_sigma") = 8.0,
    py::arg("maxit") = 200,
    py::arg("eps_g") = 1e-5,
    py::arg("fixed_idx") = py::none(),
    py::arg("fixed_values") = py::none(),
    py::arg("optimization_alg") = "lbfgs",
    py::arg("warm_start_fisher_info") = py::none(),
    py::arg("n_gh") = 20,
    "Fit a combined conditional-logit (discordant pairs) + random-intercept-GLMM "
    "(concordant pairs) model via Gauss-Hermite quadrature + L-BFGS, for KK "
    "matched-pair-plus-reservoir designs. No R-side roxygen documents this raw "
    "kernel directly (fast_clogit_plus_glmm.cpp has none); shared parameter "
    "meanings are grounded in R/EDI/man/ documentation for the sibling "
    "fast_ordinal_glmm_cpp.\n\n"
    "Parameters\n"
    "----------\n"
    "X_disc : ndarray\n"
    "    Predictor matrix for the discordant (matched-pair) subjects.\n"
    "y_disc : ndarray\n"
    "    Response vector for the discordant subjects.\n"
    "X_conc : ndarray\n"
    "    Predictor matrix for the concordant (reservoir) subjects.\n"
    "y_conc : ndarray\n"
    "    Response vector for the concordant subjects.\n"
    "group_conc : ndarray of int\n"
    "    Group (random-intercept cluster) identifiers for the concordant subjects.\n"
    "has_discordant : bool\n"
    "    Whether any discordant pairs are present (enables the conditional-logit\n"
    "    component).\n"
    "has_concordant : bool\n"
    "    Whether any concordant/reservoir subjects are present (enables the\n"
    "    random-intercept-GLMM component).\n"
    "warm_start_params : ndarray, optional\n"
    "    Optional starting values for all parameters. If provided,\n"
    "    smart_cold_start is ignored.\n"
    "warm_start_beta : ndarray, optional\n"
    "    Optional starting values for the coefficients only.\n"
    "estimate_only : bool, default False\n"
    "    If True, skip variance-component calculations.\n"
    "max_abs_log_sigma : float, default 8.0\n"
    "    Maximum allowed value for log(sigma) (the random-intercept SD), bounding\n"
    "    the optimizer away from a degenerate/unbounded variance-component\n"
    "    estimate.\n"
    "maxit : int, default 200\n"
    "    Maximum number of iterations.\n"
    "eps_g : float, default 1e-5\n"
    "    Convergence tolerance for the gradient.\n"
    "fixed_idx : ndarray of int, optional\n"
    "    Optional indices of fixed parameters.\n"
    "fixed_values : ndarray, optional\n"
    "    Optional values for fixed parameters.\n"
    "optimization_alg : str, default \"lbfgs\"\n"
    "    Optimization algorithm.\n"
    "warm_start_fisher_info : ndarray, optional\n"
    "    Optional initial Fisher information matrix for the first iteration.\n"
    "n_gh : int, default 20\n"
    "    Number of Gauss-Hermite quadrature nodes used to integrate out the random\n"
    "    intercept.");
}
