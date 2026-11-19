"""Variance outputs of the OLS / logistic / probit / Poisson / NB kernels (v1.0.6-TODO-87).

Python had none of R's *_with_var_cpp twins: fast_ols(estimate_only=False)
returned only b and XtWX, and fast_logistic_regression / fast_probit_regression
returned ssq_b_j, ssq_b_2, dispersion and sigma2_hat fields that the C++ never
fills (always nan). The wrappers now compute the twins' numbers from the
returned information matrix (edi_kernels._variance) and drop the dead keys.

R references, computed 2026-11-19 with the installed EDI 1.0.4 on the data
built by _data() (written to CSV), via
    X = cbind(1, d$w, d$x)
    EDI:::fast_ols_with_var_cpp(X, d$yc)                         # and j = 3; fixed_idx = 3L, fixed_values = -0.3
    EDI:::fast_logistic_regression_with_var_cpp(X, d$yb)          # and j = 3; fixed_idx = 3L, fixed_values = 0.4
    EDI:::fast_probit_regression_with_var_cpp(X, d$yb)            # and j = 1
    EDI:::fast_poisson_regression_with_var_cpp(X, d$yp)           # and j = 3
    diag(EDI:::fast_neg_bin_with_var_cpp(X, d$yn)$vcov)
"""
import numpy as np
import pytest

import edi_kernels as ek

RTOL = 1e-8

R_OLS_SIGMA2 = 0.571388204977042
R_OLS_SSQ2 = 0.0190571715622132
R_OLS_SSQ3 = 0.00462023698403732
R_OLS_FIXED_SIGMA2 = 0.566555984511067
R_OLS_FIXED_SSQ2 = 0.0188904468300439
R_LOGIT_SSQ2 = 0.140443231435037
R_LOGIT_SSQ3 = 0.0377295696578074
R_LOGIT_FIXED_SSQ2 = 0.138811540640593
R_PROBIT_SSQ2 = 0.0540228517125502
R_PROBIT_SSQ1 = 0.0275260095285673
R_POIS_SSQ2 = 0.0238379665449047
R_POIS_SSQ3 = 0.0048733685481519
R_NB_VCOV_DIAG = np.array([0.0184796329467559, 0.0354860069164316, 0.00817169275945058, 0.129498340376565])

FIX3 = np.array([3], dtype=np.int32)


def _data():
    rng = np.random.default_rng(87)
    n = 120
    w = rng.binomial(1, 0.5, n).astype(float)
    x = rng.normal(size=n)
    eta = -0.2 + 0.6 * w + 0.4 * x
    yc = 1 + 0.5 * w - 0.3 * x + rng.normal(scale=0.7, size=n)
    yb = (rng.random(n) < 1 / (1 + np.exp(-eta))).astype(float)
    yp = rng.poisson(np.exp(0.3 + 0.4 * w + 0.2 * x)).astype(float)
    yn = rng.negative_binomial(2, 2 / (2 + np.exp(0.3 + 0.4 * w + 0.2 * x))).astype(float)
    X = np.asfortranarray(np.column_stack([np.ones(n), w, x]))
    return X, yc, yb, yp, yn


def test_ols_matches_r_with_var():
    X, yc, *_ = _data()
    res = ek.fast_ols(X, yc, estimate_only=False)
    assert res["sigma2_hat"] == pytest.approx(R_OLS_SIGMA2, rel=RTOL)
    assert res["ssq_b_2"] == pytest.approx(R_OLS_SSQ2, rel=RTOL)
    assert res["vcov"][2, 2] == pytest.approx(R_OLS_SSQ3, rel=RTOL)
    assert np.allclose(res["vcov"], res["vcov"].T)


def test_ols_fixed_coefficient_has_nan_variance():
    X, yc, *_ = _data()
    res = ek.fast_ols(X, yc, fixed_idx=FIX3, fixed_values=np.array([-0.3]), estimate_only=False)
    assert res["sigma2_hat"] == pytest.approx(R_OLS_FIXED_SIGMA2, rel=RTOL)
    assert res["ssq_b_2"] == pytest.approx(R_OLS_FIXED_SSQ2, rel=RTOL)
    assert np.all(np.isnan(res["vcov"][2])) and np.all(np.isnan(res["vcov"][:, 2]))


def test_ols_estimate_only_adds_nothing():
    X, yc, *_ = _data()
    assert set(ek.fast_ols(X, yc)) == {"b", "XtWX"}


@pytest.mark.parametrize("kernel, y_idx, ssq2, other_j, other_ssq", [
    ("fast_logistic_regression", 2, R_LOGIT_SSQ2, 3, R_LOGIT_SSQ3),
    ("fast_probit_regression", 2, R_PROBIT_SSQ2, 1, R_PROBIT_SSQ1),
    ("fast_poisson_regression", 3, R_POIS_SSQ2, 3, R_POIS_SSQ3),
])
def test_glm_matches_r_with_var(kernel, y_idx, ssq2, other_j, other_ssq):
    data = _data()
    X, y = data[0], data[y_idx]
    res = getattr(ek, kernel)(X, y)
    assert res["ssq_b_2"] == pytest.approx(ssq2, rel=RTOL)
    assert res["vcov"][other_j - 1, other_j - 1] == pytest.approx(other_ssq, rel=RTOL)


@pytest.mark.parametrize("kernel, y_idx", [
    ("fast_logistic_regression", 2), ("fast_probit_regression", 2), ("fast_poisson_regression", 3),
    ("fast_neg_bin", 4),
])
@pytest.mark.parametrize("estimate_only", [False, True])
def test_no_always_nan_variance_fields(kernel, y_idx, estimate_only):
    data = _data()
    res = getattr(ek, kernel)(data[0], data[y_idx], estimate_only=estimate_only)
    for key in ("ssq_b_j", "sigma2_hat"):
        assert key not in res
    if kernel != "fast_neg_bin":  # NB's dispersion is theta, a real value
        assert "dispersion" not in res
    if estimate_only:
        assert "vcov" not in res and "ssq_b_2" not in res
    else:
        assert np.isfinite(res["ssq_b_2"]) and res["ssq_b_2"] > 0


def test_logistic_fixed_coefficient():
    X, _, yb, *_ = _data()
    res = ek.fast_logistic_regression(X, yb, fixed_idx=FIX3, fixed_values=np.array([0.4]))
    assert res["ssq_b_2"] == pytest.approx(R_LOGIT_FIXED_SSQ2, rel=RTOL)
    assert np.all(np.isnan(res["vcov"][2]))


def test_neg_bin_matches_r_with_var():
    X, *_, yn = _data()
    res = ek.fast_neg_bin(X, yn)
    assert res["dispersion_at_poisson_boundary"] is False
    assert res["vcov"].shape == (4, 4)
    assert np.diag(res["vcov"]) == pytest.approx(R_NB_VCOV_DIAG, rel=1e-6)
    assert res["ssq_b_2"] == pytest.approx(R_NB_VCOV_DIAG[1], rel=1e-6)


def test_singular_information_gives_nan_vcov_not_an_error():
    X, yc, *_ = _data()
    X_dup = np.asfortranarray(np.column_stack([X, X[:, 1]]))  # duplicated treatment column
    res = ek.fast_ols(X_dup, yc, estimate_only=False)
    assert np.all(np.isnan(res["vcov"]))
    assert np.isnan(res["ssq_b_2"])


def test_positional_arguments_are_bound_by_name():
    X, yc, *_ = _data()
    res = ek.fast_ols(X, yc, None, None, False)
    assert res["ssq_b_2"] == pytest.approx(R_OLS_SSQ2, rel=RTOL)
