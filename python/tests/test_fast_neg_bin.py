"""Parity test for edi_kernels.fast_neg_bin against an R-generated fixture.

This does NOT re-verify the statistical correctness of the negative-
binomial fit itself -- that's the same fast_neg_bin_internal object code
the R package's own test suite already exercises via fast_neg_bin_cpp.
What this test covers, which nothing on the R side can: the pybind11
binding layer itself (argument marshaling, defaults, dict field conversion)
and the EDI_CORE_ONLY compiled path (this extension links fetched Eigen +
LBFGSpp, not the R build's RcppEigen/RcppNumerical).

HISTORICAL NOTE: an earlier pass through this file found a real default
mismatch -- R's fast_neg_bin_cpp defaults to smart_cold_start = FALSE
(confirmed: R/EDI/src/fast_negbin_regression.cpp's three R-facing entry
points, fast_neg_bin_cpp/_with_var_cpp/_weighted_cpp, all explicitly
declare smart_cold_start = false; the shared fast_neg_bin_internal core
they call into defaults to true, but every R wrapper overrides that), while
the Python binding defaulted to True (python/cpp/bindings_count.cpp).
FIXED 2026-08-05: the Python binding's default was changed to False to
match R. R_B/R_DISPERSION/R_ITERATIONS below still pin
smart_cold_start=True explicitly (preserving the original, still-valid
fixture); test_matches_r_fixture_default_smart_cold_start below is the new
test that checks Python's now-fixed default against a fresh R fixture
computed with smart_cold_start omitted (i.e. R's own default, FALSE).

res["neg_loglik"] and res["mu"]: until v1.0.6-TODO-188 the binding returned
res.neg_ll, which fast_neg_bin_internal never sets (it keeps the
log-likelihood in res.sigma2_hat, which R returns as $logLik), so
neg_loglik was NaN and mu had shape (0,). The binding now returns
neg_loglik = -$logLik and mu = exp(X b) (R returns no fitted means; the
R-side equivalent is exp(X %*% b)). PATCHED, needs owner wheel rebuild: the
tests in the TODO-188 block below fail against a wheel built before the fix.
res["dispersion"] carries R's $theta_hat.

The expected values below were computed once via:
    EDI:::fast_neg_bin_cpp(X, as.integer(y), estimate_only = FALSE, smart_cold_start = TRUE)
in R, on the exact same synthetic dataset generated below with
numpy.random.default_rng(108).
"""
import numpy as np
import pytest

from edi_kernels import fast_neg_bin

ATOL = 1e-9
RTOL = 1e-9


def _synthetic_data():
    rng = np.random.default_rng(108)
    n = 200
    X = np.column_stack([
        np.ones(n),
        rng.binomial(1, 0.5, n),
        rng.normal(size=n),
    ])
    beta_true = np.array([0.5, 0.3, -0.2])
    mu = np.exp(X @ beta_true)
    theta = 3.0
    p_nb = theta / (theta + mu)
    y = rng.negative_binomial(theta, p_nb).astype(np.int32)
    return X, y


# R reference, EDI 1.0.0, computed 2026-08-04 via:
#   EDI:::fast_neg_bin_cpp(X, as.integer(y), estimate_only = FALSE, smart_cold_start = TRUE)
R_B = np.array([0.362440207398258, 0.376465607321876, -0.0794374115758531])
R_DISPERSION = 6.44141227855442  # R's $theta_hat
R_NUM_ITER = 18

# R reference, EDI 1.0.0, computed 2026-08-05 via (smart_cold_start omitted
# -- exercises R's own default, FALSE, on the exact same fixture data):
#   EDI:::fast_neg_bin_cpp(X, as.integer(y), estimate_only = FALSE)
R_B_DEFAULT_COLD_START = np.array([0.36241919053302, 0.376530201068749, -0.0794330300265768])
R_DISPERSION_DEFAULT_COLD_START = 6.44090879821874
R_NUM_ITER_DEFAULT_COLD_START = 12

# NOTE (2026-08-17): num_iter (renamed from "iterations") should be unchanged
# by the optimizer_diagnostics_report.md TODO-4 convergence-field rework --
# that only changes how `converged`/`hit_iteration_cap` classify a given
# exit, not which iteration the optimizer actually exits on. This fitter
# defaults to "lbfgs", whose own stopping check also fires on a relative
# function-value-decrease criterion, not gradient norm alone -- re-verify
# `converged=True` still holds for both fixtures against a fresh R run after
# the C++ change is compiled.


def test_matches_r_fixture():
    X, y = _synthetic_data()
    res = fast_neg_bin(X, y, estimate_only=False, smart_cold_start=True)

    assert res["converged"] is True
    assert res["b"] == pytest.approx(R_B, abs=ATOL, rel=RTOL)
    assert res["dispersion"] == pytest.approx(R_DISPERSION, abs=ATOL, rel=RTOL)
    assert res["num_iter"] == R_NUM_ITER
    assert res["hit_iteration_cap"] is False


def test_matches_r_fixture_default_smart_cold_start():
    """smart_cold_start omitted on both sides -- proves the Python
    binding's default (fixed 2026-08-05 to match R's FALSE) actually
    produces the same fit R's own default produces, not just that both
    defaults have the same *value* in isolation."""
    X, y = _synthetic_data()
    res = fast_neg_bin(X, y, estimate_only=False)

    assert res["converged"] is True
    assert res["b"] == pytest.approx(R_B_DEFAULT_COLD_START, abs=ATOL, rel=RTOL)
    assert res["dispersion"] == pytest.approx(R_DISPERSION_DEFAULT_COLD_START, abs=ATOL, rel=RTOL)
    assert res["num_iter"] == R_NUM_ITER_DEFAULT_COLD_START
    assert res["hit_iteration_cap"] is False


def test_result_shape_and_types():
    X, y = _synthetic_data()
    res = fast_neg_bin(X, y, estimate_only=False, smart_cold_start=True)

    p = X.shape[1]
    assert res["b"].shape == (p,)
    assert isinstance(res["converged"], bool)
    assert isinstance(res["dispersion"], float)
    assert isinstance(res["dispersion_at_poisson_boundary"], bool)


def test_estimate_only_true_still_returns_b():
    X, y = _synthetic_data()
    res = fast_neg_bin(X, y, estimate_only=True, smart_cold_start=True)

    assert res["b"] == pytest.approx(R_B, abs=1e-6, rel=1e-6)


# v1.0.6-TODO-188: neg_loglik and mu. R reference, EDI 1.0.5 source loaded with
# pkgload::load_all("R/EDI", compile = FALSE), computed 2026-11-20 on the same
# fixture via
#   r <- EDI:::fast_neg_bin_with_var_cpp(X, y)            # default start
#   r$logLik; exp(X %*% r$b)[1:5]; sum(exp(X %*% r$b))
# r$logLik equals sum(dnbinom(y, size = r$theta_hat, mu = exp(X %*% r$b), log = TRUE))
# to all printed digits, so it is the full log-likelihood (constants included).
R_LOGLIK_DEFAULT = -339.948271823945
R_MU_HEAD_DEFAULT = np.array([2.07190750063714, 2.07913574568202, 1.29193228869451,
                              1.23692392086066, 1.32599092972169])
R_MU_SUM_DEFAULT = 351.919480436027
#   EDI:::fast_neg_bin_cpp(X, y, smart_cold_start = TRUE, estimate_only = FALSE)$logLik
R_LOGLIK_SMART = -339.948271787222
#   w <- the weights from _weights() below
#   EDI:::fast_neg_bin_weighted_cpp(X, y, weights = w)
R_LOGLIK_WEIGHTED = -341.369117036619
R_B_WEIGHTED = np.array([0.3701083211288, 0.411451369397426, -0.0997686733118449])
R_MU_SUM_WEIGHTED = 362.316309172961


def _weights(n):
    return np.random.default_rng(188).uniform(0.5, 1.5, n)


def test_neg_loglik_and_mu_match_r():
    X, y = _synthetic_data()
    res = fast_neg_bin(X, y, estimate_only=False)

    assert np.isfinite(res["neg_loglik"])
    assert res["neg_loglik"] == pytest.approx(-R_LOGLIK_DEFAULT, abs=1e-8, rel=1e-10)
    assert res["mu"].shape == (X.shape[0],)
    assert res["mu"][:5] == pytest.approx(R_MU_HEAD_DEFAULT, rel=1e-8)
    assert res["mu"].sum() == pytest.approx(R_MU_SUM_DEFAULT, rel=1e-8)
    assert res["mu"] == pytest.approx(np.exp(X @ res["b"]), rel=1e-12)


def test_neg_loglik_smart_cold_start_and_estimate_only():
    X, y = _synthetic_data()
    res = fast_neg_bin(X, y, estimate_only=False, smart_cold_start=True)
    assert res["neg_loglik"] == pytest.approx(-R_LOGLIK_SMART, abs=1e-8, rel=1e-10)

    # estimate_only skips the Hessian only; R returns the same $logLik either way.
    res_eo = fast_neg_bin(X, y, estimate_only=True)
    assert res_eo["neg_loglik"] == pytest.approx(-R_LOGLIK_DEFAULT, abs=1e-8, rel=1e-10)
    assert res_eo["mu"].shape == (X.shape[0],)


def test_neg_loglik_and_mu_weighted_match_r():
    X, y = _synthetic_data()
    res = fast_neg_bin(X, y, weights=_weights(X.shape[0]))

    assert res["b"] == pytest.approx(R_B_WEIGHTED, abs=1e-7, rel=1e-7)
    assert res["neg_loglik"] == pytest.approx(-R_LOGLIK_WEIGHTED, abs=1e-7, rel=1e-9)
    assert res["mu"].sum() == pytest.approx(R_MU_SUM_WEIGHTED, rel=1e-7)
