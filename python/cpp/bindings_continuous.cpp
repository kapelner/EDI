// Binds continuous-outcome model-fitting kernels (OLS, robust regression).
// Each *_internal function is defined in its own R/EDI/src/fast_*.cpp file,
// compiled as its own source in this same CMake target (see
// ../CMakeLists.txt) -- declared, not redefined, here.

#include <pybind11/pybind11.h>
#include <pybind11/eigen.h>
#include <pybind11/stl.h>
#include "_helper_functions_core.h"
#include <optional>

namespace py = pybind11;

ModelResult fast_ols_internal(
    const Eigen::Ref<const Eigen::MatrixXd>& X,
    const Eigen::Ref<const Eigen::VectorXd>& y,
    std::optional<Eigen::VectorXi> fixed_idx,
    std::optional<Eigen::VectorXd> fixed_values,
    bool estimate_only
);

// Matches R/EDI/src/fast_robust_regression.cpp's file-local RobustModelResult
// exactly (no shared header exists for it) -- keep in sync if that struct's
// field list ever changes.
struct RobustModelResult {
    Eigen::VectorXd b;
    Eigen::VectorXd w;
    Eigen::MatrixXd XtWX;
    Eigen::MatrixXd X_free;
    double XtX_inv_diag_j;
    double scale;
    int iterations;
    bool converged;
    double ssq_b_j;
};

RobustModelResult fast_robust_regression_internal(
    const Eigen::Ref<const Eigen::MatrixXd>& X,
    const Eigen::Ref<const Eigen::VectorXd>& y,
    std::optional<Eigen::VectorXd> warm_start_beta,
    bool smart_cold_start,
    std::string method,
    double c,
    double c_bisquare,
    int maxit,
    double tol,
    double scale_est,
    std::optional<Eigen::VectorXi> fixed_idx,
    std::optional<Eigen::VectorXd> fixed_values,
    std::optional<Eigen::VectorXd> warm_start_weights,
    std::optional<Eigen::MatrixXd> warm_start_fisher_info,
    bool estimate_only,
    int variance_j
);

double wilcox_hl_point_estimate_result(
    const Eigen::Ref<const Eigen::VectorXd>& y,
    const Eigen::Ref<const Eigen::VectorXi>& w
);

struct SummarizeWithVcovResult {
    double beta_hat;
    double ssq_hat;
    double se;
    Eigen::MatrixXd vcov;
    Eigen::VectorXd std_err;
    Eigen::VectorXd z_vals;
};

SummarizeWithVcovResult ols_hc2_post_fit_result(
    const Eigen::Ref<const Eigen::MatrixXd>& X_fit,
    const Eigen::Ref<const Eigen::VectorXd>& y,
    const Eigen::Ref<const Eigen::VectorXd>& coef_hat,
    int j_treat
);

void bind_continuous(py::module_& m) {
    m.def("fast_ols", [](const Eigen::Ref<const Eigen::MatrixXd>& X,
                          const Eigen::Ref<const Eigen::VectorXd>& y,
                          std::optional<Eigen::VectorXi> fixed_idx,
                          std::optional<Eigen::VectorXd> fixed_values,
                          bool estimate_only) {
        ModelResult res = fast_ols_internal(X, y, fixed_idx, fixed_values, estimate_only);
        py::dict out;
        out["b"] = res.b;
        out["XtWX"] = res.XtWX;
        return out;
    },
    py::arg("X"), py::arg("y"),
    py::arg("fixed_idx") = py::none(),
    py::arg("fixed_values") = py::none(),
    py::arg("estimate_only") = true,
    "Fast closed-form ordinary least squares, beta_hat = (X^T X)^-1 X^T y,\n"
    "solved via a Cholesky (LDLT) factorization of X^T X rather than a QR\n"
    "decomposition of X directly -- faster but slightly less numerically\n"
    "stable for near-collinear designs. Returns coefficients only unless\n"
    "estimate_only=False, which also returns XtWX (the X^T X crossproduct\n"
    "needed downstream for standard errors, e.g. via ols_hc2_post_fit). No\n"
    "R-side roxygen documents this raw kernel directly (fast_ols_cpp has\n"
    "none); parameters follow the same fixed_idx/fixed_values convention used\n"
    "throughout this module. Analogous to statsmodels.OLS or numpy.linalg.lstsq.\n\n"
    "Parameters\n"
    "----------\n"
    "X : ndarray\n"
    "    Numeric design matrix of predictors (including an intercept column if one\n"
    "    is wanted -- this kernel does not add one implicitly).\n"
    "y : ndarray\n"
    "    Numeric vector of continuous responses.\n"
    "fixed_idx : ndarray of int, optional\n"
    "    0-based indices of coefficients to hold fixed at fixed_values rather than\n"
    "    estimate, instead of dropping those columns from X entirely. Must be paired\n"
    "    with fixed_values (both or neither).\n"
    "fixed_values : ndarray, optional\n"
    "    Values to hold the fixed_idx coefficients at; y is adjusted for their\n"
    "    contribution before the remaining (free) coefficients are estimated.\n"
    "estimate_only : bool, default True\n"
    "    If True, skip computing XtWX (the crossproduct needed for standard errors)\n"
    "    and return only the coefficient vector -- faster when only a point estimate\n"
    "    is needed.");

    m.def("fast_robust_regression", [](const Eigen::Ref<const Eigen::MatrixXd>& X,
                                        const Eigen::Ref<const Eigen::VectorXd>& y,
                                        std::optional<Eigen::VectorXd> warm_start_beta,
                                        bool smart_cold_start,
                                        std::string method,
                                        int j,
                                        double c,
                                        int maxit,
                                        double tol,
                                        std::optional<Eigen::VectorXi> fixed_idx,
                                        std::optional<Eigen::VectorXd> fixed_values,
                                        std::optional<Eigen::VectorXd> warm_start_weights,
                                        std::optional<Eigen::MatrixXd> warm_start_fisher_info,
                                        bool estimate_only) {
        RobustModelResult res = fast_robust_regression_internal(
            X, y, warm_start_beta, smart_cold_start, method, c, 4.685, maxit, tol, -1.0,
            fixed_idx, fixed_values, warm_start_weights, warm_start_fisher_info,
            estimate_only, j);
        py::dict out;
        out["coefficients"] = res.b;
        out["scale"] = res.scale;
        out["converged"] = res.converged;
        out["iterations"] = res.num_iter;
        return out;
    },
    py::arg("X"), py::arg("y"),
    py::arg("warm_start_beta") = py::none(),
    py::arg("smart_cold_start") = true,
    py::arg("method") = "MM",
    py::arg("j") = 2,
    py::arg("c") = 1.345,
    py::arg("maxit") = 50,
    py::arg("tol") = 1e-7,
    py::arg("fixed_idx") = py::none(),
    py::arg("fixed_values") = py::none(),
    py::arg("warm_start_weights") = py::none(),
    py::arg("warm_start_fisher_info") = py::none(),
    py::arg("estimate_only") = false,
    "Robust regression via IRLS (Huber M or Huber-then-Tukey-bisquare MM-estimation). "
    "Parameters sourced from R/EDI/man/ documentation for fast_robust_regression_cpp.\n\n"
    "Parameters\n"
    "----------\n"
    "X : ndarray\n"
    "    Numeric matrix of predictors.\n"
    "y : ndarray\n"
    "    Numeric vector of responses.\n"
    "warm_start_beta : ndarray, optional\n"
    "    Optional starting values for coefficients. If provided, smart_cold_start is\n"
    "    ignored.\n"
    "smart_cold_start : bool, default True\n"
    "    If True, use an initial OLS-based guess when starting from scratch (a \"cold\n"
    "    start\") with no prior knowledge. Ignored if a warm start is provided.\n"
    "method : str, default \"MM\"\n"
    "    Robust estimation method: \"M\" (single-stage Huber M-estimation) or \"MM\"\n"
    "    (S-then-M two-stage estimation, more resistant to high-leverage outliers).\n"
    "j : int, default 2\n"
    "    1-based index of the coefficient for which to return an individual variance\n"
    "    (ssq_b_j in the result).\n"
    "c : float, default 1.345\n"
    "    Huber tuning constant (used for the M-step; the Tukey bisquare tuning\n"
    "    constant for the MM-step's S-estimator is fixed internally at 4.685).\n"
    "maxit : int, default 50\n"
    "    Maximum number of IRLS iterations.\n"
    "tol : float, default 1e-7\n"
    "    Convergence tolerance.\n"
    "fixed_idx : ndarray of int, optional\n"
    "    Optional 0-based indices of coefficients to hold fixed at fixed_values\n"
    "    rather than estimate.\n"
    "fixed_values : ndarray, optional\n"
    "    Optional values for the fixed_idx coefficients.\n"
    "warm_start_weights : ndarray, optional\n"
    "    Optional initial IRLS working weights for the first iteration.\n"
    "warm_start_fisher_info : ndarray, optional\n"
    "    Optional initial Fisher information matrix for the first IRLS iteration.\n"
    "estimate_only : bool, default False\n"
    "    If True, skip variance-component calculations and return only the point\n"
    "    estimate.");

    m.def("wilcox_hl_point_estimate", &wilcox_hl_point_estimate_result,
    py::arg("y"), py::arg("w"),
    "Hodges-Lehmann point estimate (median of all pairwise treatment-minus-"
    "control differences, exact for small n or via bisection selection for "
    "large n) for the two-sample Wilcoxon rank-sum problem. w is a 0/1 "
    "treatment indicator; non-finite y entries are dropped. No R-side roxygen "
    "documents this exact raw kernel (fast_wilcox_hl.cpp's roxygen documents a "
    "different, permutation-batch export in the same file); parameters are named "
    "for their role in the algorithm above.\n\n"
    "Parameters\n"
    "----------\n"
    "y : ndarray\n"
    "    Numeric response vector.\n"
    "w : ndarray of int\n"
    "    0/1 treatment indicator, same length as y.");

    m.def("ols_hc2_post_fit", [](const Eigen::Ref<const Eigen::MatrixXd>& X_fit,
                                  const Eigen::Ref<const Eigen::VectorXd>& y,
                                  const Eigen::Ref<const Eigen::VectorXd>& coef_hat,
                                  int j_treat) {
        SummarizeWithVcovResult res = ols_hc2_post_fit_result(X_fit, y, coef_hat, j_treat);
        py::dict out;
        out["beta_hat"] = res.beta_hat;
        out["ssq_hat"] = res.ssq_hat;
        out["se"] = res.se;
        out["vcov"] = res.vcov;
        out["std_err"] = res.std_err;
        out["z_vals"] = res.z_vals;
        return out;
    },
    py::arg("X_fit"), py::arg("y"), py::arg("coef_hat"), py::arg("j_treat") = 2,
    "Given an already-fitted OLS model, computes the HC2 heteroskedasticity-\n"
    "consistent sandwich covariance matrix (MacKinnon and White 1985) for the\n"
    "coefficients: Var(beta_hat) = B M B, with \"bread\" B = (X^T X)^-1 and\n"
    "\"meat\" M = X^T diag(omega_i) X, where omega_i = r_i^2 / (1 - h_ii) --\n"
    "the squared OLS residual r_i leverage-corrected by dividing by 1 - h_ii\n"
    "(h_ii the i-th diagonal of the OLS hat matrix X(X^TX)^-1 X^T), unlike the\n"
    "plain HC0 sandwich which does not correct for leverage. HC2 is unbiased\n"
    "under homoskedasticity for balanced designs and generally has better\n"
    "small-sample properties than HC0/HC1 when leverage is uneven. Ported\n"
    "from R/EDI/man/ documentation for ols_hc2_post_fit_cpp. Reference:\n"
    "MacKinnon, J. G. and White, H. (1985), 'Some Heteroskedasticity-\n"
    "Consistent Covariance Matrix Estimators with Improved Finite Sample\n"
    "Properties', Journal of Econometrics, 29(3), 305-325. Analogous to\n"
    "statsmodels' OLS(...).fit(cov_type=\"HC2\"); see\n"
    "https://www.statsmodels.org/stable/generated/statsmodels.regression.linear_model.RegressionResults.html.\n\n"
    "Parameters\n"
    "----------\n"
    "X_fit : ndarray\n"
    "    The fitting design matrix (e.g. Lin's intercept+treatment+centered-\n"
    "    covariates+treatment×covariate design) -- must match the matrix the\n"
    "    supplied coef_hat was actually fit against.\n"
    "y : ndarray\n"
    "    Numeric response vector used in the original fit.\n"
    "coef_hat : ndarray\n"
    "    The already-fitted OLS coefficient vector to compute post-fit HC2\n"
    "    standard errors for.\n"
    "j_treat : int, default 2\n"
    "    1-based column of X_fit/coef_hat whose SE/z-value is highlighted as\n"
    "    beta_hat/se in the result (std_err/z_vals cover every column\n"
    "    regardless).");
}
