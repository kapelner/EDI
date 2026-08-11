// Binds ordinal-outcome model-fitting kernels (adjacent-category logit,
// continuation-ratio, proportional-odds logit/probit/cauchit/cloglog, the
// GLMM-random-intercept proportional-odds variant, and stereotype logit).

#include <pybind11/pybind11.h>
#include <pybind11/eigen.h>
#include <pybind11/stl.h>
#include "_helper_functions_core.h"
#include "result_map_pybind.h"
#include <optional>
#include <string>
#include <vector>

namespace py = pybind11;

// External linkage in R/EDI/src/fast_adjacent_category_logit.cpp (moved out of
// that file's anonymous namespace specifically so this binding can call them).
std::vector<double> get_levels(const Eigen::Ref<const Eigen::VectorXd>& y);
std::vector<int> map_y_to_1K(const Eigen::Ref<const Eigen::VectorXd>& y, const std::vector<double>& levels);

struct RiditAnalysisResult {
    double mean_ridit_t;
    double mean_ridit_c;
    double estimate;
    double se;
    std::vector<double> scores;
    std::vector<int> levels;
    std::vector<double> ref_p;
};

RiditAnalysisResult fast_ridit_analysis_result(
    const Eigen::Ref<const Eigen::VectorXi>& w,
    const Eigen::Ref<const Eigen::VectorXi>& y,
    const std::string& reference
);

LikelihoodFitResult fast_adjacent_category_logit_internal(
    const Eigen::Ref<const Eigen::MatrixXd>& X,
    const std::vector<int>& y_mapped,
    int K,
    int maxit,
    double tol,
    bool smart_cold_start,
    std::optional<Eigen::VectorXi> fixed_idx,
    std::optional<Eigen::VectorXd> fixed_values,
    std::string optimization_alg,
    std::optional<Eigen::MatrixXd> warm_start_fisher_info,
    std::optional<Eigen::VectorXd> warm_start_params,
    std::optional<Eigen::VectorXd> warm_start_beta
);

struct ContinuationRatioFit {
    LikelihoodFitResult fit;
    Eigen::MatrixXd X_aug;
    Eigen::VectorXd z;
    int n_alpha;
    int p;
};

ContinuationRatioFit fast_continuation_ratio_internal(
    const Eigen::Ref<const Eigen::MatrixXd>& X,
    const Eigen::Ref<const Eigen::VectorXd>& y,
    int maxit,
    double tol,
    std::optional<Eigen::VectorXd> warm_start_beta,
    bool smart_cold_start,
    std::optional<Eigen::VectorXi> fixed_idx,
    std::optional<Eigen::VectorXd> fixed_values,
    std::string optimization_alg,
    std::optional<Eigen::MatrixXd> warm_start_fisher_info
);

edi::ResultMap fast_ordinal_regression_internal(
    const Eigen::Ref<const Eigen::MatrixXd>& X,
    const Eigen::Ref<const Eigen::VectorXd>& y,
    std::optional<Eigen::VectorXd> weights,
    std::optional<Eigen::VectorXd> warm_start_params,
    bool smart_cold_start,
    int maxit,
    double tol,
    std::optional<Eigen::VectorXi> fixed_idx,
    std::optional<Eigen::VectorXd> fixed_values,
    std::string optimization_alg,
    std::optional<Eigen::MatrixXd> warm_start_fisher_info,
    bool estimate_only
);

edi::ResultMap fast_ordinal_probit_regression_internal(
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
);

edi::ResultMap fast_ordinal_cauchit_regression_internal(
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
);

edi::ResultMap fast_ordinal_cloglog_regression_internal(
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
);

edi::ResultMap fast_ordinal_clmm_internal(
    const Eigen::Ref<const Eigen::MatrixXd>& X,
    const Eigen::Ref<const Eigen::VectorXi>& y,
    const Eigen::Ref<const Eigen::VectorXi>& group_id,
    int K,
    int j_T,
    std::string link,
    bool estimate_only,
    int n_gh,
    double max_abs_log_sigma,
    int maxit,
    double eps_g,
    std::optional<Eigen::VectorXd> warm_start_params,
    std::string optimization_alg,
    std::optional<Eigen::VectorXi> fixed_idx,
    std::optional<Eigen::VectorXd> fixed_values,
    std::optional<Eigen::MatrixXd> warm_start_fisher_info
);

edi::ResultMap fast_ordinal_glmm_internal(
    const Eigen::Ref<const Eigen::MatrixXd>& X,
    const Eigen::Ref<const Eigen::VectorXi>& y,
    const Eigen::Ref<const Eigen::VectorXi>& group_id,
    int K,
    int j_T,
    bool smart_cold_start,
    bool estimate_only,
    int n_gh,
    double max_abs_log_sigma,
    int maxit,
    double eps_g,
    std::optional<Eigen::VectorXd> warm_start_params,
    std::optional<Eigen::VectorXd> warm_start_beta,
    std::string optimization_alg,
    std::optional<Eigen::VectorXi> fixed_idx,
    std::optional<Eigen::VectorXd> fixed_values,
    std::optional<Eigen::MatrixXd> warm_start_fisher_info
);

edi::ResultMap fast_stereotype_logit_full_internal(
    const Eigen::Ref<const Eigen::MatrixXd>& X,
    const Eigen::Ref<const Eigen::VectorXd>& y,
    int maxit,
    double tol,
    bool smart_cold_start,
    std::optional<Eigen::VectorXi> fixed_idx,
    std::optional<Eigen::VectorXd> fixed_values,
    std::string optimization_alg,
    std::optional<Eigen::MatrixXd> warm_start_fisher_info,
    std::optional<Eigen::VectorXd> warm_start_params,
    std::optional<Eigen::VectorXd> warm_start_beta,
    bool estimate_only
);

void bind_ordinal(py::module_& m) {
    m.def("fast_adjacent_category_logit", [](const Eigen::Ref<const Eigen::MatrixXd>& X,
                                              const Eigen::Ref<const Eigen::VectorXd>& y,
                                              int maxit,
                                              double tol,
                                              bool smart_cold_start,
                                              std::optional<Eigen::VectorXi> fixed_idx,
                                              std::optional<Eigen::VectorXd> fixed_values,
                                              std::string optimization_alg,
                                              std::optional<Eigen::MatrixXd> warm_start_fisher_info,
                                              std::optional<Eigen::VectorXd> warm_start_params,
                                              std::optional<Eigen::VectorXd> warm_start_beta) {
        std::vector<double> levels = get_levels(y);
        int K = static_cast<int>(levels.size());
        if (K < 2) {
            throw std::invalid_argument("Adjacent-category logits require at least two observed outcome categories.");
        }
        std::vector<int> y_mapped = map_y_to_1K(y, levels);

        LikelihoodFitResult fit = fast_adjacent_category_logit_internal(
            X, y_mapped, K, maxit, tol, smart_cold_start,
            fixed_idx, fixed_values, optimization_alg, warm_start_fisher_info, warm_start_params, warm_start_beta);

        py::dict out;
        out["b"] = Eigen::VectorXd(fit.params.tail(X.cols()));
        out["alpha"] = Eigen::VectorXd(fit.params.head(K - 1));
        out["params"] = fit.params;
        out["neg_loglik"] = fit.value;
        out["iterations"] = fit.niter;
        out["converged"] = fit.converged;
        out["gradient_norm"] = fit.gradient_norm;
        return out;
    },
    py::arg("X"), py::arg("y"),
    py::arg("maxit") = 100,
    py::arg("tol") = 1e-8,
    py::arg("smart_cold_start") = true,
    py::arg("fixed_idx") = py::none(),
    py::arg("fixed_values") = py::none(),
    py::arg("optimization_alg") = "lbfgs",
    py::arg("warm_start_fisher_info") = py::none(),
    py::arg("warm_start_params") = py::none(),
    py::arg("warm_start_beta") = py::none(),
    "Fast adjacent-category logit ordinal regression via L-BFGS. Parameters "
    "sourced from R/EDI/man/ documentation for fast_adjacent_category_logit_cpp "
    "(that function's y/K args are replaced here by a raw y this binding maps to "
    "1..K internally).\n\n"
    "Parameters\n"
    "----------\n"
    "X : ndarray\n"
    "    A numeric matrix of predictors.\n"
    "y : ndarray\n"
    "    A numeric vector of responses (categorical, at least 2 distinct observed\n"
    "    levels); mapped to consecutive integers 1..K internally.\n"
    "maxit : int, default 100\n"
    "    Maximum number of iterations.\n"
    "tol : float, default 1e-8\n"
    "    Convergence tolerance.\n"
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
    "    Optional initial Fisher information matrix.\n"
    "warm_start_params : ndarray, optional\n"
    "    Optional starting values for all parameters. If provided,\n"
    "    smart_cold_start is ignored.\n"
    "warm_start_beta : ndarray, optional\n"
    "    Optional starting values for coefficients. If provided,\n"
    "    smart_cold_start is ignored.");

    m.def("fast_continuation_ratio_regression", [](const Eigen::Ref<const Eigen::MatrixXd>& X,
                                                    const Eigen::Ref<const Eigen::VectorXd>& y,
                                                    int maxit,
                                                    double tol,
                                                    std::optional<Eigen::VectorXd> warm_start_beta,
                                                    bool smart_cold_start,
                                                    std::optional<Eigen::VectorXi> fixed_idx,
                                                    std::optional<Eigen::VectorXd> fixed_values,
                                                    std::string optimization_alg,
                                                    std::optional<Eigen::MatrixXd> warm_start_fisher_info) {
        ContinuationRatioFit cr = fast_continuation_ratio_internal(
            X, y, maxit, tol, warm_start_beta, smart_cold_start,
            fixed_idx, fixed_values, optimization_alg, warm_start_fisher_info);
        py::dict out;
        out["b"] = Eigen::VectorXd(cr.fit.params.tail(cr.p));
        out["alpha"] = Eigen::VectorXd(cr.fit.params.head(cr.n_alpha));
        out["params"] = cr.fit.params;
        out["neg_loglik"] = cr.fit.value;
        out["iterations"] = cr.fit.niter;
        out["converged"] = cr.fit.converged;
        out["gradient_norm"] = cr.fit.gradient_norm;
        return out;
    },
    py::arg("X"), py::arg("y"),
    py::arg("maxit") = 100,
    py::arg("tol") = 1e-8,
    py::arg("warm_start_beta") = py::none(),
    py::arg("smart_cold_start") = true,
    py::arg("fixed_idx") = py::none(),
    py::arg("fixed_values") = py::none(),
    py::arg("optimization_alg") = "lbfgs",
    py::arg("warm_start_fisher_info") = py::none(),
    "Fast continuation-ratio ordinal logit regression via L-BFGS. Parameters "
    "sourced from R/EDI/man/ documentation for "
    "fast_continuation_ratio_regression_cpp.\n\n"
    "Parameters\n"
    "----------\n"
    "X : ndarray\n"
    "    A numeric matrix of predictors (no intercept column; threshold\n"
    "    intercepts are estimated internally).\n"
    "y : ndarray\n"
    "    A numeric vector of ordinal responses.\n"
    "maxit : int, default 100\n"
    "    Maximum number of iterations.\n"
    "tol : float, default 1e-8\n"
    "    Convergence tolerance.\n"
    "warm_start_beta : ndarray, optional\n"
    "    Optional starting values for coefficients.\n"
    "smart_cold_start : bool, default True\n"
    "    If True, use an initial OLS-based guess when no warm start is provided.\n"
    "fixed_idx : ndarray of int, optional\n"
    "    Optional indices of fixed parameters.\n"
    "fixed_values : ndarray, optional\n"
    "    Optional values for fixed parameters.\n"
    "optimization_alg : str, default \"lbfgs\"\n"
    "    Optimization algorithm.\n"
    "warm_start_fisher_info : ndarray, optional\n"
    "    Optional initial Fisher information matrix.");

    m.def("fast_ordinal_regression", [](const Eigen::Ref<const Eigen::MatrixXd>& X,
                                         const Eigen::Ref<const Eigen::VectorXd>& y,
                                         std::optional<Eigen::VectorXd> weights,
                                         std::optional<Eigen::VectorXd> warm_start_params,
                                         bool smart_cold_start,
                                         int maxit,
                                         double tol,
                                         std::optional<Eigen::VectorXi> fixed_idx,
                                         std::optional<Eigen::VectorXd> fixed_values,
                                         std::string optimization_alg,
                                         std::optional<Eigen::MatrixXd> warm_start_fisher_info,
                                         bool estimate_only) {
        edi::ResultMap res = fast_ordinal_regression_internal(
            X, y, weights, warm_start_params, smart_cold_start, maxit, tol,
            fixed_idx, fixed_values, optimization_alg, warm_start_fisher_info, estimate_only);
        return edi::to_py_dict(res);
    },
    py::arg("X"), py::arg("y"),
    py::arg("weights") = py::none(),
    py::arg("warm_start_params") = py::none(),
    py::arg("smart_cold_start") = true,
    py::arg("maxit") = 100,
    py::arg("tol") = 1e-6,
    py::arg("fixed_idx") = py::none(),
    py::arg("fixed_values") = py::none(),
    py::arg("optimization_alg") = "lbfgs",
    py::arg("warm_start_fisher_info") = py::none(),
    py::arg("estimate_only") = false,
    "Fast proportional-odds (logit link) ordinal regression via Newton-Raphson/L-BFGS. "
    "Returns vcov/ssq_b_j (variance of the first covariate after the alphas) whenever "
    "the Hessian is invertible and !estimate_only. Parameters sourced from "
    "R/EDI/man/ documentation for fast_ordinal_regression_cpp/"
    "fast_ordinal_regression_weighted_cpp.\n\n"
    "Parameters\n"
    "----------\n"
    "X : ndarray\n"
    "    A numeric matrix of predictors.\n"
    "y : ndarray\n"
    "    A numeric vector of responses (ordinal categories 1, 2, ...).\n"
    "weights : ndarray, optional\n"
    "    Optional nonnegative observation weights; if provided, routes to the\n"
    "    weighted fit backend.\n"
    "warm_start_params : ndarray, optional\n"
    "    Optional starting values for [alpha, beta]. If provided,\n"
    "    smart_cold_start is ignored.\n"
    "smart_cold_start : bool, default True\n"
    "    If True, use an initial OLS-based guess when starting from scratch (a\n"
    "    \"cold start\") with no prior knowledge. Ignored if a warm start is\n"
    "    provided.\n"
    "maxit : int, default 100\n"
    "    Maximum number of iterations.\n"
    "tol : float, default 1e-6\n"
    "    Convergence tolerance.\n"
    "fixed_idx : ndarray of int, optional\n"
    "    Optional indices of fixed parameters.\n"
    "fixed_values : ndarray, optional\n"
    "    Optional values for fixed parameters.\n"
    "optimization_alg : str, default \"lbfgs\"\n"
    "    Optimization algorithm.\n"
    "warm_start_fisher_info : ndarray, optional\n"
    "    Optional initial Fisher information matrix for the first IRLS iteration.\n"
    "estimate_only : bool, default False\n"
    "    If True, skip variance-component calculations.");

    m.def("fast_ordinal_probit_regression", [](const Eigen::Ref<const Eigen::MatrixXd>& X,
                                                const Eigen::Ref<const Eigen::VectorXd>& y,
                                                std::optional<Eigen::VectorXd> warm_start_params,
                                                bool smart_cold_start,
                                                int maxit,
                                                double tol,
                                                std::string optimization_alg,
                                                std::optional<Eigen::VectorXi> fixed_idx,
                                                std::optional<Eigen::VectorXd> fixed_values,
                                                std::optional<Eigen::MatrixXd> warm_start_fisher_info,
                                                bool estimate_only) {
        edi::ResultMap res = fast_ordinal_probit_regression_internal(
            X, y, warm_start_params, smart_cold_start, maxit, tol, optimization_alg,
            fixed_idx, fixed_values, warm_start_fisher_info, estimate_only);
        return edi::to_py_dict(res);
    },
    py::arg("X"), py::arg("y"),
    py::arg("warm_start_params") = py::none(),
    py::arg("smart_cold_start") = true,
    py::arg("maxit") = 100,
    py::arg("tol") = 1e-6,
    py::arg("optimization_alg") = "lbfgs",
    py::arg("fixed_idx") = py::none(),
    py::arg("fixed_values") = py::none(),
    py::arg("warm_start_fisher_info") = py::none(),
    py::arg("estimate_only") = false,
    "Fast proportional-odds (probit link) ordinal regression via Newton-Raphson/L-BFGS. "
    "Parameters sourced from R/EDI/man/ documentation for "
    "fast_ordinal_probit_regression_cpp.\n\n"
    "Parameters\n"
    "----------\n"
    "X : ndarray\n"
    "    A numeric matrix of predictors.\n"
    "y : ndarray\n"
    "    A numeric vector of responses.\n"
    "warm_start_params : ndarray, optional\n"
    "    Optional starting values for [alpha, beta]. If provided,\n"
    "    smart_cold_start is ignored.\n"
    "smart_cold_start : bool, default True\n"
    "    If True, use an initial OLS-based guess when starting from scratch. Ignored\n"
    "    if a warm start is provided.\n"
    "maxit : int, default 100\n"
    "    Maximum number of iterations.\n"
    "tol : float, default 1e-6\n"
    "    Convergence tolerance.\n"
    "optimization_alg : str, default \"lbfgs\"\n"
    "    Optimization algorithm.\n"
    "fixed_idx : ndarray of int, optional\n"
    "    Optional indices of fixed parameters.\n"
    "fixed_values : ndarray, optional\n"
    "    Optional values for fixed parameters.\n"
    "warm_start_fisher_info : ndarray, optional\n"
    "    Optional initial Fisher information matrix for the first IRLS iteration.\n"
    "estimate_only : bool, default False\n"
    "    If True, skip variance-component calculations.");

    m.def("fast_ordinal_cauchit_regression", [](const Eigen::Ref<const Eigen::MatrixXd>& X,
                                                 const Eigen::Ref<const Eigen::VectorXd>& y,
                                                 std::optional<Eigen::VectorXd> warm_start_params,
                                                 bool smart_cold_start,
                                                 int maxit,
                                                 double tol,
                                                 std::string optimization_alg,
                                                 std::optional<Eigen::VectorXi> fixed_idx,
                                                 std::optional<Eigen::VectorXd> fixed_values,
                                                 std::optional<Eigen::MatrixXd> warm_start_fisher_info,
                                                 bool estimate_only) {
        edi::ResultMap res = fast_ordinal_cauchit_regression_internal(
            X, y, warm_start_params, smart_cold_start, maxit, tol, optimization_alg,
            fixed_idx, fixed_values, warm_start_fisher_info, estimate_only);
        return edi::to_py_dict(res);
    },
    py::arg("X"), py::arg("y"),
    py::arg("warm_start_params") = py::none(),
    py::arg("smart_cold_start") = true,
    py::arg("maxit") = 100,
    py::arg("tol") = 1e-6,
    py::arg("optimization_alg") = "lbfgs",
    py::arg("fixed_idx") = py::none(),
    py::arg("fixed_values") = py::none(),
    py::arg("warm_start_fisher_info") = py::none(),
    py::arg("estimate_only") = false,
    "Fast proportional-odds (cauchit link) ordinal regression via Newton-Raphson/L-BFGS. "
    "Returns an empty dict if the outcome has fewer than 2 observed categories. "
    "Parameters sourced from R/EDI/man/ documentation for "
    "fast_ordinal_cauchit_regression_cpp.\n\n"
    "Parameters\n"
    "----------\n"
    "X : ndarray\n"
    "    A numeric matrix of predictors.\n"
    "y : ndarray\n"
    "    A numeric vector of responses.\n"
    "warm_start_params : ndarray, optional\n"
    "    Optional starting values for [alpha, beta]. If provided,\n"
    "    smart_cold_start is ignored.\n"
    "smart_cold_start : bool, default True\n"
    "    If True, use an initial OLS-based guess when starting from scratch. Ignored\n"
    "    if a warm start is provided.\n"
    "maxit : int, default 100\n"
    "    Maximum number of iterations.\n"
    "tol : float, default 1e-6\n"
    "    Convergence tolerance.\n"
    "optimization_alg : str, default \"lbfgs\"\n"
    "    Optimization algorithm.\n"
    "fixed_idx : ndarray of int, optional\n"
    "    Optional indices of fixed parameters.\n"
    "fixed_values : ndarray, optional\n"
    "    Optional values for fixed parameters.\n"
    "warm_start_fisher_info : ndarray, optional\n"
    "    Optional initial Fisher information matrix for the first IRLS iteration.\n"
    "estimate_only : bool, default False\n"
    "    If True, skip variance-component calculations.");

    m.def("fast_ordinal_cloglog_regression", [](const Eigen::Ref<const Eigen::MatrixXd>& X,
                                                 const Eigen::Ref<const Eigen::VectorXd>& y,
                                                 std::optional<Eigen::VectorXd> warm_start_params,
                                                 bool smart_cold_start,
                                                 int maxit,
                                                 double tol,
                                                 std::string optimization_alg,
                                                 std::optional<Eigen::VectorXi> fixed_idx,
                                                 std::optional<Eigen::VectorXd> fixed_values,
                                                 std::optional<Eigen::MatrixXd> warm_start_fisher_info,
                                                 bool estimate_only) {
        edi::ResultMap res = fast_ordinal_cloglog_regression_internal(
            X, y, warm_start_params, smart_cold_start, maxit, tol, optimization_alg,
            fixed_idx, fixed_values, warm_start_fisher_info, estimate_only);
        return edi::to_py_dict(res);
    },
    py::arg("X"), py::arg("y"),
    py::arg("warm_start_params") = py::none(),
    py::arg("smart_cold_start") = true,
    py::arg("maxit") = 100,
    py::arg("tol") = 1e-6,
    py::arg("optimization_alg") = "lbfgs",
    py::arg("fixed_idx") = py::none(),
    py::arg("fixed_values") = py::none(),
    py::arg("warm_start_fisher_info") = py::none(),
    py::arg("estimate_only") = false,
    "Fast proportional-odds (cloglog link) ordinal regression via Newton-Raphson/L-BFGS. "
    "Returns an empty dict if the outcome has fewer than 2 observed categories. "
    "Parameters sourced from R/EDI/man/ documentation for "
    "fast_ordinal_cloglog_regression_cpp.\n\n"
    "Parameters\n"
    "----------\n"
    "X : ndarray\n"
    "    A numeric matrix of predictors.\n"
    "y : ndarray\n"
    "    A numeric vector of responses.\n"
    "warm_start_params : ndarray, optional\n"
    "    Optional starting values for [alpha, beta]. If provided,\n"
    "    smart_cold_start is ignored.\n"
    "smart_cold_start : bool, default True\n"
    "    If True, use an initial OLS-based guess when starting from scratch. Ignored\n"
    "    if a warm start is provided.\n"
    "maxit : int, default 100\n"
    "    Maximum number of iterations.\n"
    "tol : float, default 1e-6\n"
    "    Convergence tolerance.\n"
    "optimization_alg : str, default \"lbfgs\"\n"
    "    Optimization algorithm.\n"
    "fixed_idx : ndarray of int, optional\n"
    "    Optional indices of fixed parameters.\n"
    "fixed_values : ndarray, optional\n"
    "    Optional values for fixed parameters.\n"
    "warm_start_fisher_info : ndarray, optional\n"
    "    Optional initial Fisher information matrix for the first IRLS iteration.\n"
    "estimate_only : bool, default False\n"
    "    If True, skip variance-component calculations.");

    m.def("fast_ordinal_clmm", [](const Eigen::Ref<const Eigen::MatrixXd>& X,
                                   const Eigen::Ref<const Eigen::VectorXi>& y,
                                   const Eigen::Ref<const Eigen::VectorXi>& group_id,
                                   int K,
                                   int j_T,
                                   std::string link,
                                   bool estimate_only,
                                   int n_gh,
                                   double max_abs_log_sigma,
                                   int maxit,
                                   double eps_g,
                                   std::optional<Eigen::VectorXd> warm_start_params,
                                   std::string optimization_alg,
                                   std::optional<Eigen::VectorXi> fixed_idx,
                                   std::optional<Eigen::VectorXd> fixed_values,
                                   std::optional<Eigen::MatrixXd> warm_start_fisher_info) {
        edi::ResultMap res = fast_ordinal_clmm_internal(
            X, y, group_id, K, j_T, link, estimate_only, n_gh, max_abs_log_sigma,
            maxit, eps_g, warm_start_params, optimization_alg, fixed_idx, fixed_values,
            warm_start_fisher_info);
        return edi::to_py_dict(res);
    },
    py::arg("X"), py::arg("y"), py::arg("group_id"), py::arg("K"), py::arg("j_T"),
    py::arg("link") = "logit",
    py::arg("estimate_only") = false,
    py::arg("n_gh") = 20,
    py::arg("max_abs_log_sigma") = 8.0,
    py::arg("maxit") = 300,
    py::arg("eps_g") = 1e-6,
    py::arg("warm_start_params") = py::none(),
    py::arg("optimization_alg") = "lbfgs",
    py::arg("fixed_idx") = py::none(),
    py::arg("fixed_values") = py::none(),
    py::arg("warm_start_fisher_info") = py::none(),
    "Fast proportional-odds ordinal GLMM (random intercept, Gauss-Hermite quadrature) "
    "via L-BFGS. link is one of 'logit', 'probit', 'cauchit', 'cloglog'. No R-side "
    "roxygen documents this raw kernel directly (fast_ordinal_clmm.cpp has none); "
    "shared parameter meanings are grounded in R/EDI/man/ documentation for the "
    "sibling fast_ordinal_glmm_cpp (same engine, fixed to the logit link).\n\n"
    "Parameters\n"
    "----------\n"
    "X : ndarray\n"
    "    A numeric matrix of predictors (no intercept).\n"
    "y : ndarray of int\n"
    "    A numeric vector of ordinal responses (1, 2, ...).\n"
    "group_id : ndarray of int\n"
    "    A numeric vector of group (random-intercept cluster) identifiers.\n"
    "K : int\n"
    "    Number of ordinal levels.\n"
    "j_T : int\n"
    "    0-based index of the treatment effect in the beta vector.\n"
    "link : str, default \"logit\"\n"
    "    Cumulative link function: one of \"logit\", \"probit\", \"cauchit\",\n"
    "    \"cloglog\".\n"
    "estimate_only : bool, default False\n"
    "    If True, skip variance-component calculations.\n"
    "n_gh : int, default 20\n"
    "    Number of Gauss-Hermite quadrature nodes used to integrate out the random\n"
    "    intercept.\n"
    "max_abs_log_sigma : float, default 8.0\n"
    "    Maximum allowed value for log(sigma).\n"
    "maxit : int, default 300\n"
    "    Maximum number of iterations.\n"
    "eps_g : float, default 1e-6\n"
    "    Convergence tolerance for the gradient.\n"
    "warm_start_params : ndarray, optional\n"
    "    Optional starting values for all parameters [alpha, beta, log_sigma]. If\n"
    "    provided, smart_cold_start is ignored.\n"
    "optimization_alg : str, default \"lbfgs\"\n"
    "    Optimization algorithm.\n"
    "fixed_idx : ndarray of int, optional\n"
    "    Optional indices of fixed parameters.\n"
    "fixed_values : ndarray, optional\n"
    "    Optional values for fixed parameters.\n"
    "warm_start_fisher_info : ndarray, optional\n"
    "    Optional initial Fisher information matrix for the first iteration.");

    m.def("fast_stereotype_logit", [](const Eigen::Ref<const Eigen::MatrixXd>& X,
                                       const Eigen::Ref<const Eigen::VectorXd>& y,
                                       int maxit,
                                       double tol,
                                       bool smart_cold_start,
                                       std::optional<Eigen::VectorXi> fixed_idx,
                                       std::optional<Eigen::VectorXd> fixed_values,
                                       std::string optimization_alg,
                                       std::optional<Eigen::MatrixXd> warm_start_fisher_info,
                                       std::optional<Eigen::VectorXd> warm_start_params,
                                       std::optional<Eigen::VectorXd> warm_start_beta,
                                       bool estimate_only) {
        edi::ResultMap res = fast_stereotype_logit_full_internal(
            X, y, maxit, tol, smart_cold_start, fixed_idx, fixed_values, optimization_alg,
            warm_start_fisher_info, warm_start_params, warm_start_beta, estimate_only);
        return edi::to_py_dict(res);
    },
    py::arg("X"), py::arg("y"),
    py::arg("maxit") = 100,
    py::arg("tol") = 1e-8,
    py::arg("smart_cold_start") = true,
    py::arg("fixed_idx") = py::none(),
    py::arg("fixed_values") = py::none(),
    py::arg("optimization_alg") = "newton_raphson",
    py::arg("warm_start_fisher_info") = py::none(),
    py::arg("warm_start_params") = py::none(),
    py::arg("warm_start_beta") = py::none(),
    py::arg("estimate_only") = false,
    "Fast stereotype logit ordinal regression via Newton-Raphson. Returns ssq_b_1/"
    "ssq_b_j (variance of the first beta) via a profile-likelihood fallback when the "
    "Fisher-information diagonal entry isn't directly invertible; vcov is always None "
    "(not computed by this kernel). Parameters sourced from R/EDI/man/ documentation "
    "for fast_stereotype_logit_cpp/fast_stereotype_logit_with_var_cpp (this binding "
    "unifies both R exports).\n\n"
    "Parameters\n"
    "----------\n"
    "X : ndarray\n"
    "    A numeric matrix of predictors.\n"
    "y : ndarray\n"
    "    A numeric vector of responses.\n"
    "maxit : int, default 100\n"
    "    Maximum number of iterations.\n"
    "tol : float, default 1e-8\n"
    "    Convergence tolerance.\n"
    "smart_cold_start : bool, default True\n"
    "    If True, use an initial OLS-based guess when starting from scratch (a\n"
    "    \"cold start\") with no prior knowledge. Ignored if a warm start is\n"
    "    provided.\n"
    "fixed_idx : ndarray of int, optional\n"
    "    Optional indices of fixed parameters.\n"
    "fixed_values : ndarray, optional\n"
    "    Optional values for fixed parameters.\n"
    "optimization_alg : str, default \"newton_raphson\"\n"
    "    Optimization algorithm.\n"
    "warm_start_fisher_info : ndarray, optional\n"
    "    Optional initial Fisher information matrix for the first IRLS iteration.\n"
    "warm_start_params : ndarray, optional\n"
    "    Optional starting values for all parameters. If provided,\n"
    "    smart_cold_start is ignored.\n"
    "warm_start_beta : ndarray, optional\n"
    "    Optional starting values for coefficients. If provided,\n"
    "    smart_cold_start is ignored.\n"
    "estimate_only : bool, default False\n"
    "    If True, skip variance-related computation and return only the point\n"
    "    estimate.");

    m.def("fast_ordinal_glmm", [](const Eigen::Ref<const Eigen::MatrixXd>& X,
                                   const Eigen::Ref<const Eigen::VectorXi>& y,
                                   const Eigen::Ref<const Eigen::VectorXi>& group_id,
                                   int K,
                                   int j_T,
                                   bool smart_cold_start,
                                   bool estimate_only,
                                   int n_gh,
                                   double max_abs_log_sigma,
                                   int maxit,
                                   double eps_g,
                                   std::optional<Eigen::VectorXd> warm_start_params,
                                   std::optional<Eigen::VectorXd> warm_start_beta,
                                   std::string optimization_alg,
                                   std::optional<Eigen::VectorXi> fixed_idx,
                                   std::optional<Eigen::VectorXd> fixed_values,
                                   std::optional<Eigen::MatrixXd> warm_start_fisher_info) {
        edi::ResultMap res = fast_ordinal_glmm_internal(
            X, y, group_id, K, j_T, smart_cold_start, estimate_only, n_gh, max_abs_log_sigma,
            maxit, eps_g, warm_start_params, warm_start_beta, optimization_alg,
            fixed_idx, fixed_values, warm_start_fisher_info);
        return edi::to_py_dict(res);
    },
    py::arg("X"), py::arg("y"), py::arg("group_id"), py::arg("K"), py::arg("j_T"),
    py::arg("smart_cold_start") = true,
    py::arg("estimate_only") = false,
    py::arg("n_gh") = 20,
    py::arg("max_abs_log_sigma") = 8.0,
    py::arg("maxit") = 300,
    py::arg("eps_g") = 1e-6,
    py::arg("warm_start_params") = py::none(),
    py::arg("warm_start_beta") = py::none(),
    py::arg("optimization_alg") = "lbfgs",
    py::arg("fixed_idx") = py::none(),
    py::arg("fixed_values") = py::none(),
    py::arg("warm_start_fisher_info") = py::none(),
    "Fast proportional-odds (logit link) ordinal GLMM with a random intercept via "
    "Gauss-Hermite quadrature + L-BFGS. X must NOT include an intercept column. "
    "Parameters sourced from R/EDI/man/ documentation for fast_ordinal_glmm_cpp.\n\n"
    "Parameters\n"
    "----------\n"
    "X : ndarray\n"
    "    A numeric matrix of predictors (no intercept).\n"
    "y : ndarray of int\n"
    "    A numeric vector of ordinal responses (1, 2, ...).\n"
    "group_id : ndarray of int\n"
    "    A numeric vector of group identifiers.\n"
    "K : int\n"
    "    Number of ordinal levels.\n"
    "j_T : int\n"
    "    0-based index of the treatment effect in the beta vector.\n"
    "smart_cold_start : bool, default True\n"
    "    If True, use an initial OLS-based guess when starting from scratch (a\n"
    "    \"cold start\") with no prior knowledge. Ignored if a warm start is\n"
    "    provided.\n"
    "estimate_only : bool, default False\n"
    "    If True, skip variance-component calculations.\n"
    "n_gh : int, default 20\n"
    "    Number of Gauss-Hermite nodes.\n"
    "max_abs_log_sigma : float, default 8.0\n"
    "    Maximum allowed value for log(sigma).\n"
    "maxit : int, default 300\n"
    "    Maximum number of iterations.\n"
    "eps_g : float, default 1e-6\n"
    "    Convergence tolerance.\n"
    "warm_start_params : ndarray, optional\n"
    "    Optional starting values for all parameters [alpha, beta, log_sigma]. If\n"
    "    provided, smart_cold_start is ignored.\n"
    "warm_start_beta : ndarray, optional\n"
    "    Optional starting values for coefficients. If provided (and\n"
    "    warm_start_params is not), smart_cold_start is ignored.\n"
    "optimization_alg : str, default \"lbfgs\"\n"
    "    Optimization algorithm.\n"
    "fixed_idx : ndarray of int, optional\n"
    "    Optional indices of fixed parameters.\n"
    "fixed_values : ndarray, optional\n"
    "    Optional values for fixed parameters.\n"
    "warm_start_fisher_info : ndarray, optional\n"
    "    Optional initial Fisher information matrix for the first iteration.");

    m.def("fast_ridit_analysis", [](const Eigen::Ref<const Eigen::VectorXi>& w,
                                     const Eigen::Ref<const Eigen::VectorXi>& y,
                                     std::string reference) {
        RiditAnalysisResult res = fast_ridit_analysis_result(w, y, reference);
        py::dict out;
        out["mean_ridit_t"] = res.mean_ridit_t;
        out["mean_ridit_c"] = res.mean_ridit_c;
        out["estimate"] = res.estimate;
        out["se"] = res.se;
        out["scores"] = res.scores;
        out["levels"] = res.levels;
        out["ref_p"] = res.ref_p;
        return out;
    },
    py::arg("w"), py::arg("y"), py::arg("reference") = "control",
    "Ridit analysis (Bross 1958): assigns each subject a ridit score relative "
    "to the empirical distribution of the reference group ('control', "
    "'treatment', or 'pooled'), then compares treatment/control mean ridits. "
    "estimate = mean_ridit_t - 0.5 (centered at 0 under the null); se is the "
    "sample-variance-based SE of the treatment-arm mean ridit. No R-side roxygen "
    "documents this raw kernel directly (fast_ridit_analysis.cpp has none); "
    "parameters are named for their role in the algorithm above.\n\n"
    "Parameters\n"
    "----------\n"
    "w : ndarray of int\n"
    "    0/1 treatment indicator, one per subject.\n"
    "y : ndarray of int\n"
    "    Ordinal category (1, 2, ...) for each subject.\n"
    "reference : str, default \"control\"\n"
    "    Which group's empirical distribution defines the ridit scores: "
    "\"control\", \"treatment\", or \"pooled\".");
}
