#ifndef EDI_ORDINAL_SCALE_GUARD_H
#define EDI_ORDINAL_SCALE_GUARD_H

// TODO-107: scale-aware convergence for the ordinal kernels (logit, cauchit,
// cloglog, probit, adjacent-category, continuation-ratio).
//
// The optimizers' stopping rules are not invariant to the scale/location of
// the covariates: on uncentred covariates (e.g. mean 1e3) they can report
// converged = TRUE while the treatment coefficient is still off by many
// standard errors. The Newton decrement g' H^{-1} g is invariant to any
// affine reparameterisation, so it is a scale-free certificate of
// convergence. It is evaluated ONLY when the covariates look badly scaled
// (same rule as R's ordinal_center_scale_plan(): some |mean| > sd, or some sd
// outside [0.25, 4]), so well-scaled fits are bit-identical and pay nothing.
// A converged fit that fails the certificate is downgraded to
// converged = FALSE; params are never modified here.

#ifdef EDI_CORE_ONLY
#include "_helper_functions_core.h"
#endif
#include <Eigen/Dense>
#include <algorithm>
#include <cmath>

// Columns [col0, X.cols()) are inspected (callers pass col0 = 0 for designs
// that hold only covariates; the continuation-ratio augmented design passes
// n_alpha so the threshold-indicator columns are skipped).
template <typename Derived>
inline bool ordinal_covariates_badly_scaled(const Eigen::MatrixBase<Derived>& X, int col0 = 0) {
    const double n = static_cast<double>(X.rows());
    if (n < 2.0) return false;
    for (int j = col0; j < X.cols(); ++j) {
        const double m = X.col(j).mean();
        const double ss = (X.col(j).array() - m).square().sum();
        const double sd = std::sqrt(ss / (n - 1.0));
        if (!std::isfinite(m) || !std::isfinite(sd)) return true;
        if (sd <= 0.0) continue; // constant column: not a scaling problem
        // G1 post-build 2026-10-23: a 0/1 column (the treatment, a dummy) is never a
        // scaling problem, but with more than half ones its mean exceeds its sd, so
        // the |mean| > sd rule fired on ordinary designs (52% treated: 92/100
        // well-scaled PO fits, 68-91/100 probit/cloglog/cauchit, downgraded to
        // converged = FALSE; ~35% NA estimates at class level). R's
        // ordinal_center_scale_plan() never looks at the treatment column.
        bool zero_one = true;
        for (int i = 0; i < X.rows() && zero_one; ++i) {
            const double v = X(i, j);
            zero_one = (v == 0.0 || v == 1.0);
        }
        if (zero_one) continue;
        if (std::fabs(m) > sd || sd < 0.25 || sd > 4.0) return true;
    }
    return false;
}

// FullFunctor must expose operator()(params, grad) -> negative log-likelihood
// with grad = its gradient, and hessian(params) -> Hessian of the NEGATIVE
// log-likelihood (all six ordinal functors do).
// Returns TRUE if the fit passes (or the check cannot be evaluated, in which
// case the optimizer's own verdict stands).
template <typename FullFunctor>
inline bool ordinal_newton_decrement_ok(FullFunctor& fun,
                                        const Eigen::VectorXd& params,
                                        const FixedParamSpec& fixed_spec,
                                        double tol) {
    if (!params.allFinite()) return true;
    Eigen::VectorXd grad(params.size());
    Eigen::VectorXd p = params;
    fun(p, grad);
    Eigen::MatrixXd H = fun.hessian(p);
    Eigen::VectorXd g_free = subset_vector(grad, fixed_spec.free_idx);
    Eigen::MatrixXd H_free = subset_matrix(H, fixed_spec.free_idx, fixed_spec.free_idx);
    if (g_free.size() == 0 || !g_free.allFinite() || !H_free.allFinite()) return true;
    Eigen::LDLT<Eigen::MatrixXd> ldlt(H_free);
    if (ldlt.info() != Eigen::Success || !ldlt.isPositive()) return true;
    const Eigen::VectorXd step = ldlt.solve(g_free);
    const double decrement = g_free.dot(step);
    if (!std::isfinite(decrement)) return true;
    return decrement <= std::max(1e-6, tol);
}

#endif
