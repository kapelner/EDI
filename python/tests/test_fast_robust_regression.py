"""Parity test for edi_kernels.fast_robust_regression against an R-generated
fixture.

This does NOT re-verify the statistical correctness of the robust (MM-
estimation) fit itself -- that's the same fast_robust_regression_internal
object code the R package's own test suite already exercises via
fast_robust_regression_cpp. What this test covers, which nothing on the R
side can: the pybind11 binding layer itself (argument marshaling, defaults,
dict field conversion) and the EDI_CORE_ONLY compiled path (this extension
links fetched Eigen + LBFGSpp, not the R build's RcppEigen/RcppNumerical).

The expected values below were computed once via:
    EDI:::fast_robust_regression_cpp(X, y)
in R (default method="MM"), on the exact same synthetic dataset (with a
handful of injected outliers) generated below with
numpy.random.default_rng(102).
"""
import numpy as np
import pytest

from edi_kernels import fast_robust_regression

ATOL = 1e-9
RTOL = 1e-9


def _synthetic_data():
    rng = np.random.default_rng(102)
    n = 150
    X = np.column_stack([
        np.ones(n),
        rng.binomial(1, 0.5, n),
        rng.normal(size=n),
    ])
    beta_true = np.array([1.0, 0.5, -0.3])
    y = X @ beta_true + rng.normal(scale=0.5, size=n)
    outlier_idx = rng.choice(n, 5, replace=False)
    y[outlier_idx] += rng.normal(scale=8, size=5)
    return X, y


# R reference, EDI 1.0.0, computed 2026-08-04 via:
#   EDI:::fast_robust_regression_cpp(X, y)
R_COEFFICIENTS = np.array(
    [0.95890410926024, 0.533261327370603, -0.309509629741258]
)
R_SCALE = 0.490313028232971
R_NUM_ITER = 11


def test_matches_r_fixture():
    X, y = _synthetic_data()
    res = fast_robust_regression(X, y)

    # converged/num_iter values are unaffected by the optimizer_diagnostics_
    # report.md TODO-4 rework -- this fitter's convergence criterion
    # (coefficient-relative-change, not gradient-norm) was deliberately left
    # untouched (see fast_robust_regression.cpp for why); only the field
    # name (num_iter) and the new hit_iteration_cap field are new.
    assert res["converged"] is True
    assert res["coefficients"] == pytest.approx(R_COEFFICIENTS, abs=ATOL, rel=RTOL)
    assert res["scale"] == pytest.approx(R_SCALE, abs=ATOL, rel=RTOL)
    assert res["num_iter"] == R_NUM_ITER
    assert res["hit_iteration_cap"] is False


def test_result_shape_and_types():
    X, y = _synthetic_data()
    res = fast_robust_regression(X, y)

    p = X.shape[1]
    assert res["coefficients"].shape == (p,)
    assert isinstance(res["converged"], bool)
    assert isinstance(res["scale"], float)


def test_returns_r_variance_fields():
    """ssq_b_j, fisher_information and min_eigenvalue_information, as R's
    fast_robust_regression_cpp returns them (audit decision rpy-parity-dd699435e)."""
    X, y = _synthetic_data()
    p = X.shape[1]
    res = fast_robust_regression(X, y)

    assert "min_eigenvalue_information" in res
    assert isinstance(res["ssq_b_j"], float)
    assert np.isfinite(res["ssq_b_j"]) and res["ssq_b_j"] > 0
    info = res["fisher_information"]
    assert info.shape == (p, p)
    assert np.all(np.isfinite(info))
    assert info == pytest.approx(info.T, abs=1e-10)


def test_ssq_b_j_follows_j_and_is_nan_for_a_fixed_coefficient():
    X, y = _synthetic_data()
    v2 = fast_robust_regression(X, y, j=2)["ssq_b_j"]
    v3 = fast_robust_regression(X, y, j=3)["ssq_b_j"]
    assert np.isfinite(v2) and np.isfinite(v3) and v2 != v3

    fixed = fast_robust_regression(X, y, j=2, fixed_idx=np.array([2], dtype=np.int32),
                                   fixed_values=np.array([0.5]))
    assert np.isnan(fixed["ssq_b_j"])  # R returns NA here


def test_estimate_only_omits_variance_fields():
    X, y = _synthetic_data()
    res = fast_robust_regression(X, y, estimate_only=True)
    assert "ssq_b_j" not in res
    assert "fisher_information" not in res
    assert "coefficients" in res and "min_eigenvalue_information" in res
