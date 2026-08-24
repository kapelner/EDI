"""Parity test for edi_kernels.fast_continuation_ratio_regression against an
R-generated fixture.

This does NOT re-verify the statistical correctness of the continuation-
ratio fit itself -- that's the same fast_continuation_ratio_internal object
code the R package's own test suite already exercises via
fast_continuation_ratio_regression_cpp. What this test covers, which
nothing on the R side can: the pybind11 binding layer itself (argument
marshaling, defaults, edi::to_py_dict field conversion) and the
EDI_CORE_ONLY compiled path (this extension links fetched Eigen + LBFGSpp,
not the R build's RcppEigen/RcppNumerical).

X has NO intercept column; y is 1-indexed (values in {1,...,K}).

The expected values below were computed once via:
    EDI:::fast_continuation_ratio_regression_cpp(X, y)
in R, on the exact same synthetic dataset generated below with
numpy.random.default_rng(123) (same recipe as test_fast_ordinal_regression.py).
Do not regenerate this fixture casually -- if it needs updating, regenerate
from R and update the comment with the date/EDI version.
"""
import numpy as np
import pytest

from edi_kernels import fast_continuation_ratio_regression

ATOL = 1e-9
RTOL = 1e-9


def _synthetic_data():
    rng = np.random.default_rng(123)
    n = 300
    X_full = np.column_stack([
        np.ones(n),
        rng.binomial(1, 0.5, n).astype(float),
        rng.normal(size=n),
    ])
    alpha_true = np.array([-1.0, 0.2, 1.3])
    beta_true = np.array([0.6, -0.4])
    eta = X_full[:, 1:] @ beta_true
    y = np.zeros(n)
    for i in range(n):
        cum = 1.0 / (1.0 + np.exp(-(alpha_true - eta[i])))
        u = rng.uniform()
        y[i] = 1 + np.sum(u > cum)
    return X_full[:, 1:], y.astype(float)


# R reference, EDI 1.0.0, computed 2026-08-04 via:
#   EDI:::fast_continuation_ratio_regression_cpp(X, y)
# (2026-08-24): build_continuation_ratio_augmented_data's z now codes
# "continued past this cut" = 1 instead of "stopped at this cut" = 1, so that
# a positive beta means "pushes toward higher categories of y" -- consistent
# with the package's other ordinal estimators. This is an exact elementwise
# sign flip of the original fixture's b/alpha (fitting a logistic regression
# on the complementary binary response negates both parameter blocks exactly;
# neg_loglik is invariant under this reparametrization).
R_B = np.array([0.634847365434558, -0.358801002565834])
R_ALPHA = np.array([1.01767396284275, 0.218042906987751, -0.678418178076508])
R_NEG_LOGLIK = 399.17351526582


def test_matches_r_fixture():
    X, y = _synthetic_data()
    res = fast_continuation_ratio_regression(X, y)

    # NOTE (2026-08-17): converged now derives from the shared LBFGS/Newton
    # machinery's gradient-norm-based redefinition (optimizer_diagnostics_
    # report.md TODO-4) -- re-verify against a fresh R run once compiled.
    assert res["converged"] is True
    assert res["b"] == pytest.approx(R_B, abs=ATOL, rel=RTOL)
    assert res["alpha"] == pytest.approx(R_ALPHA, abs=ATOL, rel=RTOL)
    assert res["neg_loglik"] == pytest.approx(R_NEG_LOGLIK, abs=ATOL, rel=RTOL)


def test_result_shape_and_types():
    X, y = _synthetic_data()
    res = fast_continuation_ratio_regression(X, y)

    p = X.shape[1]
    n_alpha = 3
    assert res["b"].shape == (p,)
    assert res["alpha"].shape == (n_alpha,)
    assert isinstance(res["converged"], bool)
    assert isinstance(res["neg_loglik"], float)
