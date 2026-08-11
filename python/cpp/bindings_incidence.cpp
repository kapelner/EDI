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

struct GEEResult {
    Eigen::VectorXd beta;
    double alpha;
    Eigen::MatrixXd vcov;
    double quasi_loglik;
    Eigen::VectorXd score;
    Eigen::MatrixXd bread;
    bool converged;
    int niter;
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
        return out;
    },
    py::arg("X"), py::arg("y"), py::arg("group_id"), py::arg("family"),
    py::arg("warm_start_beta") = py::none(),
    py::arg("warm_start_fisher_info") = py::none(),
    py::arg("maxit") = 100,
    py::arg("tol") = 1e-8,
    "Fast GEE (singleton/pair clusters only) via Fisher scoring. "
    "family is one of 'gaussian', 'binomial', 'poisson'. No R-side roxygen "
    "documents this raw kernel directly (fast_gee.cpp has none); parameters "
    "follow the same conventions used throughout this module.\n\n"
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
    "Miettinen-Nurminen score confidence interval for a risk difference "
    "(inverts the constrained score test via bisection). Returns (lower, upper). "
    "Shared x_t/n_t/x_c/n_c/p_t_obs/p_c_obs argument meanings sourced from "
    "R/EDI/man/ documentation for the sibling mn_pvalue_cpp/mn_z_statistic_cpp "
    "(same file); alpha/pval_epsilon are this CI-inversion wrapper's own "
    "arguments, undocumented on the R side.\n\n"
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
    "Miettinen-Nurminen two-sided score p-value for testing risk difference = "
    "delta. Parameters sourced from R/EDI/man/ documentation for mn_pvalue_cpp.\n\n"
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
    "Newcombe hybrid score confidence interval for independent proportions "
    "(Method 10). Returns (lower, upper). R/EDI/src/newcombe_speedups.cpp's "
    "roxygen for this exact function has only an (untagged) title, no @param "
    "entries; argument meanings below follow directly from the two-independent-"
    "proportions parameterization the title names, and match the sibling "
    "newcombe_paired_ci_cpp's x/n naming in the same file.\n\n"
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
