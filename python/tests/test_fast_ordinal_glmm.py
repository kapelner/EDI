"""Parity test for edi_kernels.fast_ordinal_glmm against an R-generated fixture.

This does NOT re-verify the statistical correctness of the ordinal GLMM fit
itself -- that's the same fast_ordinal_glmm_internal object code the R
package's own test suite already exercises via fast_ordinal_glmm_cpp. What
this test covers, which nothing on the R side can: the pybind11 binding
layer itself (argument marshaling, defaults, edi::to_py_dict field
conversion) and the EDI_CORE_ONLY compiled path (this extension links
fetched Eigen + LBFGSpp, not the R build's RcppEigen/RcppNumerical).

X has NO intercept column (per the comment on fast_ordinal_glmm_cpp's X
parameter in R/EDI/src/fast_ordinal_glmm.cpp -- the K-1 alpha thresholds
serve that role); y is 1-indexed (values in {1,...,K}); j_T is the 0-based
treatment column index.

*** group_id must partition observations into groups of size EXACTLY 1 or
2 *** -- see test_fast_logistic_glmm.py's docstring for why (shared
GLMM/CLMM/LMM-family constraint).

The expected values below were computed once via:
    EDI:::fast_ordinal_glmm_cpp(X, y, group_id, K = 3L, j_T = 0L)
in R, on the exact same synthetic dataset generated below with
numpy.random.default_rng(31). Do not regenerate this fixture casually -- if
it needs updating, regenerate from R and update the comment with the
date/EDI version.
"""
import numpy as np
import pytest

from edi_kernels import fast_ordinal_glmm

ATOL = 1e-9
RTOL = 1e-9


def _synthetic_data():
    rng = np.random.default_rng(31)
    n = 300
    X = np.column_stack([
        rng.binomial(1, 0.5, n).astype(float),
        rng.normal(size=n),
    ])
    group_id = (np.repeat(np.arange(n // 2), 2) + 1).astype(np.int32)
    alpha_true = np.array([-1.0, 0.5])  # K=3
    beta_true = np.array([0.5, -0.3])
    b_re = np.repeat(rng.normal(scale=0.4, size=n // 2), 2)
    eta = X @ beta_true + b_re
    y = np.zeros(n)
    for i in range(n):
        cum = 1.0 / (1.0 + np.exp(-(alpha_true - eta[i])))
        u = rng.uniform()
        y[i] = 1 + np.sum(u > cum)
    return X, y.astype(np.int32), group_id


def test_returns_converged_finite_fit():
    X, y, group_id = _synthetic_data()
    res = fast_ordinal_glmm(X, y, group_id, K=3, j_T=0)

    assert res["converged"] is True
    assert np.all(np.isfinite(res["b"]))
    assert np.all(np.isfinite(res["alpha"]))
    assert np.isfinite(res["log_sigma"])
    assert np.isfinite(res["neg_loglik"])
    assert np.isfinite(res["gradient_norm"])
    assert res["gradient_norm"] <= 1e-5


def test_group_membership_is_invariant_to_row_order():
    X, y, group_id = _synthetic_data()
    rng = np.random.default_rng(20260825)
    order = rng.permutation(len(y))
    original = fast_ordinal_glmm(X, y, group_id, K=3, j_T=0)
    shuffled = fast_ordinal_glmm(
        np.asfortranarray(X[order]), y[order], group_id[order], K=3, j_T=0
    )

    assert shuffled["neg_loglik"] == pytest.approx(original["neg_loglik"], abs=ATOL, rel=RTOL)
    assert shuffled["b"] == pytest.approx(original["b"], abs=ATOL, rel=RTOL)
    assert shuffled["log_sigma"] == pytest.approx(original["log_sigma"], abs=ATOL, rel=RTOL)


def test_result_shape_and_types():
    X, y, group_id = _synthetic_data()
    res = fast_ordinal_glmm(X, y, group_id, K=3, j_T=0)

    p = X.shape[1]
    assert res["b"].shape == (p,)
    assert res["alpha"].shape == (2,)
    assert isinstance(res["converged"], bool)
    assert isinstance(res["neg_loglik"], float)
