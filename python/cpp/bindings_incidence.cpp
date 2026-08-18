// Binds GEE (correlated-data / incidence family).

#include <pybind11/pybind11.h>
#include <pybind11/eigen.h>
#include <pybind11/stl.h>
#include "_helper_functions_core.h"
#include <algorithm>
#include <optional>
#include <string>
#include <vector>

namespace py = pybind11;

enum class GEEFamily { GAUSSIAN, BINOMIAL, POISSON };

// Matches R/EDI/src/fast_gee.cpp's file-local GEEResult exactly (no shared
// header exists for it) -- keep in sync if that struct's field list ever
// changes. A stale/short mirror here previously caused a real stack-buffer
// overflow: gee_pairs_singletons_cpp_impl (compiled against the real,
// longer struct) writes hit_iteration_cap/gradient_norm past the end of
// the caller's (short-struct-sized) local, corrupting the stack.
struct GEEResult {
    Eigen::VectorXd beta;
    double alpha;
    Eigen::MatrixXd vcov;
    double quasi_loglik;
    Eigen::VectorXd score;
    Eigen::MatrixXd bread;
    bool converged;
    int niter;
    bool hit_iteration_cap;
    double gradient_norm;
};

GEEResult gee_pairs_singletons_cpp_impl(
    const Eigen::Ref<const Eigen::MatrixXd>& X,
    const Eigen::Ref<const Eigen::VectorXd>& y,
    const std::vector<int>& grp_start,
    const std::vector<int>& grp_size,
    GEEFamily family,
    const Eigen::Ref<const Eigen::VectorXd>& weights,
    std::optional<Eigen::VectorXd> warm_start_beta,
    std::optional<Eigen::MatrixXd> warm_start_fisher_info,
    int maxit, double tol
);

struct MNCIBounds { double lower; double upper; };
double mn_pvalue_cpp(double x_t, double n_t, double x_c, double n_c, double delta, double p_t_obs, double p_c_obs);
MNCIBounds mn_ci_internal(double x_t, double n_t, double x_c, double n_c, double p_t_obs, double p_c_obs, double alpha, double pval_epsilon);

struct NewcombeCIBounds { double lower; double upper; };
NewcombeCIBounds newcombe_independent_ci_internal(double x1, double n1, double x2, double n2, double alpha);

void bind_incidence(py::module_& m) {
    m.def("gee_pairs_singletons", [](const Eigen::Ref<const Eigen::MatrixXd>& X,
                                      const Eigen::Ref<const Eigen::VectorXd>& y,
                                      const Eigen::Ref<const Eigen::VectorXi>& group_id,
                                      std::string family_str,
                                      std::optional<Eigen::VectorXd> warm_start_beta,
                                      std::optional<Eigen::MatrixXd> warm_start_fisher_info,
                                      int maxit,
                                      double tol) {
        GEEFamily family = GEEFamily::GAUSSIAN;
        if (family_str == "binomial") family = GEEFamily::BINOMIAL;
        else if (family_str == "poisson") family = GEEFamily::POISSON;

        const int n = static_cast<int>(y.size());
        std::vector<int> ord(n);
        for (int i = 0; i < n; ++i) ord[i] = i;
        std::sort(ord.begin(), ord.end(), [&](int a, int b) { return group_id[a] < group_id[b]; });

        Eigen::MatrixXd X_s(n, X.cols());
        Eigen::VectorXd y_s(n);
        for (int i = 0; i < n; ++i) {
            X_s.row(i) = X.row(ord[i]);
            y_s[i] = y[ord[i]];
        }
        std::vector<int> grp_start, grp_size;
        int prev = -1;
        for (int i = 0; i < n; ++i) {
            int g = group_id[ord[i]];
            if (g != prev) { grp_start.push_back(i); grp_size.push_back(1); prev = g; }
            else grp_size.back()++;
        }

        GEEResult res = gee_pairs_singletons_cpp_impl(
            X_s, y_s, grp_start, grp_size, family, Eigen::VectorXd(),
            warm_start_beta, warm_start_fisher_info, maxit, tol);

        py::dict out;
        out["beta"] = res.beta;
        out["alpha"] = res.alpha;
        out["vcov"] = res.vcov;
        out["quasi_loglik"] = res.quasi_loglik;
        out["score"] = res.score;
        out["fisher_information"] = res.bread;
        out["converged"] = res.converged;
        out["niter"] = res.niter;
        out["hit_iteration_cap"] = res.hit_iteration_cap;
        out["gradient_norm"] = res.gradient_norm;
        return out;
    },
    py::arg("X"), py::arg("y"), py::arg("group_id"), py::arg("family"),
    py::arg("warm_start_beta") = py::none(),
    py::arg("warm_start_fisher_info") = py::none(),
    py::arg("maxit") = 100,
    py::arg("tol") = 1e-8,
    "Fits a Generalized Estimating Equations (GEE) model with an exchangeable\n"
    "working correlation structure, specialized to clusters that are all\n"
    "singletons (size 1) or pairs (size 2) -- the matched-pair/reservoir\n"
    "cluster structure produced by this package's KK-family matched designs --\n"
    "via Fisher scoring on the GEE estimating equations rather than a general\n"
    "iterative-proportional-fitting GEE solver. family selects the working\n"
    "variance/link: \"gaussian\" (identity link, constant variance),\n"
    "\"binomial\" (logit link, variance mu*(1-mu)), or \"poisson\" (log link,\n"
    "variance mu). The single exchangeable correlation parameter alpha is\n"
    "estimated from the Pearson residuals of paired clusters (singletons\n"
    "contribute no correlation information). The returned vcov is the\n"
    "sandwich (robust) covariance of beta, consistent even if the working\n"
    "correlation structure is misspecified -- the defining robustness property\n"
    "of GEE (Liang and Zeger 1986). No R-side roxygen documents this raw\n"
    "kernel directly (fast_gee.cpp has none); parameters follow the same\n"
    "conventions used throughout this module. Analogous to statsmodels'\n"
    "GEE with an Exchangeable working correlation structure; see\n"
    "https://www.statsmodels.org/stable/gee.html.\n\n"
    "Parameters\n"
    "----------\n"
    "X : ndarray\n"
    "    Numeric matrix of predictors (including intercept column where wanted).\n"
    "y : ndarray\n"
    "    Numeric vector of responses, matching family's distribution.\n"
    "group_id : ndarray of int\n"
    "    Cluster identifiers, one per row of X/y; every cluster here must be a\n"
    "    singleton (size 1) or a pair (size 2) -- this is the specialized\n"
    "    fast path, not a general GEE solver.\n"
    "family : str\n"
    "    One of \"gaussian\", \"binomial\", \"poisson\" -- the GEE working\n"
    "    variance/link family.\n"
    "warm_start_beta : ndarray, optional\n"
    "    Optional starting values for coefficients.\n"
    "warm_start_fisher_info : ndarray, optional\n"
    "    Optional initial Fisher information matrix for the first iteration.\n"
    "maxit : int, default 100\n"
    "    Maximum number of Fisher-scoring iterations.\n"
    "tol : float, default 1e-8\n"
    "    Convergence tolerance.");

    m.def("mn_ci", [](double x_t, double n_t, double x_c, double n_c, double p_t_obs, double p_c_obs,
                       double alpha, double pval_epsilon) {
        MNCIBounds r = mn_ci_internal(x_t, n_t, x_c, n_c, p_t_obs, p_c_obs, alpha, pval_epsilon);
        py::tuple out(2);
        out[0] = r.lower;
        out[1] = r.upper;
        return out;
    },
    py::arg("x_t"), py::arg("n_t"), py::arg("x_c"), py::arg("n_c"),
    py::arg("p_t_obs"), py::arg("p_c_obs"),
    py::arg("alpha") = 0.05,
    py::arg("pval_epsilon") = 1e-7,
    "Miettinen-Nurminen confidence interval for the risk difference p_T - p_C\n"
    "in two independent binomial samples, obtained by inverting the\n"
    "restricted-maximum-likelihood score test (see mn_pvalue's docstring for\n"
    "the full test definition) via bisection: for each candidate null\n"
    "difference delta, the two-sided p-value from mn_pvalue is compared to\n"
    "alpha, and the lower/upper bounds are the deltas where that p-value\n"
    "equals alpha, searched for independently below and above the observed\n"
    "difference p_t_obs - p_c_obs. Returns (lower, upper). Shared\n"
    "x_t/n_t/x_c/n_c/p_t_obs/p_c_obs argument meanings sourced from R/EDI/man/\n"
    "documentation for the sibling mn_pvalue_cpp/mn_ci_cpp (same file);\n"
    "pval_epsilon is this CI-inversion wrapper's own argument, undocumented on\n"
    "the R side. Reference: Miettinen, O. and Nurminen, M. (1985), 'Comparative\n"
    "analysis of two rates', Statistics in Medicine, 4(2), 213-226.\n\n"
    "Parameters\n"
    "----------\n"
    "x_t : float\n"
    "    Number of events in the treatment arm.\n"
    "n_t : float\n"
    "    Number of subjects in the treatment arm.\n"
    "x_c : float\n"
    "    Number of events in the control arm.\n"
    "n_c : float\n"
    "    Number of subjects in the control arm.\n"
    "p_t_obs : float\n"
    "    Observed treatment-arm risk (typically x_t / n_t).\n"
    "p_c_obs : float\n"
    "    Observed control-arm risk (typically x_c / n_c).\n"
    "alpha : float, default 0.05\n"
    "    Significance level; the returned interval has nominal coverage\n"
    "    1 - alpha.\n"
    "pval_epsilon : float, default 1e-7\n"
    "    Numerical tolerance for the bisection search that inverts the score\n"
    "    test to find each bound.");

    m.def("mn_pvalue", &mn_pvalue_cpp,
    py::arg("x_t"), py::arg("n_t"), py::arg("x_c"), py::arg("n_c"),
    py::arg("delta"), py::arg("p_t_obs"), py::arg("p_c_obs"),
    "Miettinen-Nurminen restricted-maximum-likelihood score test p-value for\n"
    "H0: p_T - p_C = delta in two independent binomial samples. Computes the\n"
    "constrained MLEs p_C~ (found by bisecting the constrained score equation\n"
    "to zero) and p_T~ = p_C~ + delta in place of the unconstrained sample\n"
    "proportions in the variance formula, with a small-sample correction\n"
    "factor (n_T+n_C)/(n_T+n_C-1) applied to the naive binomial variance, then\n"
    "forms the score z statistic z = ((p_t_obs-p_c_obs) - delta) / sqrt(var~)\n"
    "and returns the two-sided normal-tail p-value 2*Phi(-|z|). Returns NaN if\n"
    "either arm is empty, delta is outside (-1, 1), or the resulting z is not\n"
    "finite (e.g. the constrained variance estimate is non-positive).\n"
    "Parameters sourced from R/EDI/man/ documentation for mn_pvalue_cpp.\n"
    "Reference: Miettinen, O. and Nurminen, M. (1985), 'Comparative analysis of\n"
    "two rates', Statistics in Medicine, 4(2), 213-226.\n\n"
    "Parameters\n"
    "----------\n"
    "x_t : float\n"
    "    Number of events in the treatment arm.\n"
    "n_t : float\n"
    "    Number of subjects in the treatment arm.\n"
    "x_c : float\n"
    "    Number of events in the control arm.\n"
    "n_c : float\n"
    "    Number of subjects in the control arm.\n"
    "delta : float\n"
    "    Null risk difference to test against.\n"
    "p_t_obs : float\n"
    "    Observed treatment-arm risk (typically x_t / n_t).\n"
    "p_c_obs : float\n"
    "    Observed control-arm risk (typically x_c / n_c).");

    m.def("newcombe_independent_ci", [](double x1, double n1, double x2, double n2, double alpha) {
        NewcombeCIBounds r = newcombe_independent_ci_internal(x1, n1, x2, n2, alpha);
        py::tuple out(2);
        out[0] = r.lower;
        out[1] = r.upper;
        return out;
    },
    py::arg("x1"), py::arg("n1"), py::arg("x2"), py::arg("n2"),
    py::arg("alpha") = 0.05,
    "Newcombe's 'Method 10' hybrid confidence interval for the difference\n"
    "between two independent proportions p1 - p2. Separate Wilson score\n"
    "intervals [l1, u1] and [l2, u2] are computed for each proportion\n"
    "individually, then combined as\n"
    "  lower = (p1-p2) - sqrt((p1-l1)^2 + (u2-p2)^2)\n"
    "  upper = (p1-p2) + sqrt((u1-p1)^2 + (p2-l2)^2)\n"
    "clamped to [-1, 1]. This avoids the boundary/coverage problems of the\n"
    "naive normal-approximation (Wald) interval on a risk difference while\n"
    "remaining closed-form (no iterative score-test inversion, unlike mn_ci).\n"
    "Returns (nan, nan) if either sample size is non-positive. Parameters\n"
    "sourced from R/EDI/man/ documentation for newcombe_independent_ci_cpp.\n"
    "Reference: Newcombe, R. G. (1998), 'Interval Estimation for the\n"
    "Difference Between Independent Proportions: Comparison of Eleven\n"
    "Methods', Statistics in Medicine, 17(8), 873-890.\n\n"
    "Parameters\n"
    "----------\n"
    "x1 : float\n"
    "    Number of events in group 1.\n"
    "n1 : float\n"
    "    Number of subjects in group 1.\n"
    "x2 : float\n"
    "    Number of events in group 2.\n"
    "n2 : float\n"
    "    Number of subjects in group 2.\n"
    "alpha : float, default 0.05\n"
    "    Significance level; the returned interval has nominal coverage\n"
    "    1 - alpha.");
}
