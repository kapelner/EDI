"""Parity tests for the general-censoring Weibull AFT Python binding."""

import numpy as np
import pytest

from edi_kernels import fast_weibull_regression_general


ATOL = 1e-9
RTOL = 1e-9


def _synthetic_data():
    rng = np.random.default_rng(123)
    n = 150
    X = np.column_stack([
        rng.binomial(1, 0.5, n).astype(float),
        rng.normal(size=n),
    ])
    beta_true = np.array([0.5, -0.3])
    eta = X @ beta_true
    event_time = rng.exponential(np.exp(-eta))
    censor_time = rng.exponential(3.0, n)
    dead = (event_time <= censor_time).astype(float)
    y_obs = np.minimum(event_time, censor_time)
    return X, y_obs, dead


def _general_response(y_obs, dead):
    y = np.where(dead != 0, y_obs, np.nan)
    y_L = np.where(dead == 0, y_obs, np.nan)
    y_R = np.where(dead == 0, np.inf, np.nan)
    return y, y_L, y_R


# R reference, EDI 1.0.0, computed 2026-08-04 with the same general response.
R_PARAMS = np.array([-0.580572508466287, 0.35362562665742, 0.115502572892534])
R_NEG_LOGLIK = 100.088153200844
R_VCOV_DIAG = np.array([0.0210927071459095, 0.0105260329864121, 0.00435393717820719])


def test_matches_r_fixture():
    X, y_obs, dead = _synthetic_data()
    y, y_L, y_R = _general_response(y_obs, dead)
    res = fast_weibull_regression_general(X, y, y_L, y_R)

    assert res["converged"] is True
    assert res["params"] == pytest.approx(R_PARAMS, abs=ATOL, rel=RTOL)
    assert res["neg_loglik"] == pytest.approx(R_NEG_LOGLIK, abs=ATOL, rel=RTOL)
    assert np.diag(res["vcov"]) == pytest.approx(R_VCOV_DIAG, abs=ATOL, rel=RTOL)


def test_result_shape_and_types():
    X, y_obs, dead = _synthetic_data()
    y, y_L, y_R = _general_response(y_obs, dead)
    res = fast_weibull_regression_general(X, y, y_L, y_R)

    total = X.shape[1] + 1
    assert res["params"].shape == (total,)
    assert res["vcov"].shape == (total, total)
    assert isinstance(res["converged"], bool)
    assert isinstance(res["neg_loglik"], float)


def test_estimate_only_still_fits_params():
    X, y_obs, dead = _synthetic_data()
    y, y_L, y_R = _general_response(y_obs, dead)
    res = fast_weibull_regression_general(X, y, y_L, y_R, estimate_only=True)

    assert "vcov" not in res
    assert "params" not in res
    p = X.shape[1]
    assert res["b"] == pytest.approx(R_PARAMS[:p], abs=1e-6, rel=1e-6)
    assert res["log_sigma"] == pytest.approx(R_PARAMS[p], abs=1e-6, rel=1e-6)
