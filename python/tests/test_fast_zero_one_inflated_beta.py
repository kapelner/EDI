"""Parity test for edi_kernels.fast_zero_one_inflated_beta against an
R-generated fixture.

This does NOT re-verify the statistical correctness of the zero-one-
inflated beta fit itself -- that's the same
fast_zero_one_inflated_beta_internal object code the R package's own test
suite already exercises via fast_zero_one_inflated_beta_cpp. What this test
covers, which nothing on the R side can: the pybind11 binding layer itself
(argument marshaling, defaults, edi::to_py_dict field conversion) and the
EDI_CORE_ONLY compiled path (this extension links fetched Eigen + LBFGSpp,
not the R build's RcppEigen/RcppNumerical).

X_zero_one is the design matrix for the zero/one-inflation component; y is
in [0, 1] inclusive (may include exact 0s and 1s, unlike plain beta
regression). Returned 'params' packs [beta, log_phi, zero_one_b0,
zero_one_b1].

Note (updated 2026-08-17): fast_zero_one_inflated_beta_cpp's R-facing return
list previously had no "converged"/"iterations"/"gradient_norm" fields at
all, even though the underlying LikelihoodFitResult the Python binding
surfaces always carried them -- the R wrapper just didn't expose them. Fixed
as part of optimizer_diagnostics_report.md TODO-1/TODO-4 (now exposes
converged/num_iter/hit_iteration_cap/gradient_norm on both the
estimate_only and full-result branches). This test still only cross-checks
params/neg_loglik against the R fixture below (predates the R-side fix) and
asserts converged==True as a Python-side sanity check -- re-verify against a
fresh R run once compiled, since converged is now also gradient-norm-based
per TODO-4.

The expected values below were computed once via:
    EDI:::fast_zero_one_inflated_beta_cpp(X, X_zero_one, y)
in R, on the exact same synthetic dataset generated below with
numpy.random.default_rng(101). Do not regenerate this fixture casually --
if it needs updating, regenerate from R and update the comment with the
date/EDI version.
"""
import numpy as np
import pytest

from edi_kernels import fast_zero_one_inflated_beta

ATOL = 1e-9
RTOL = 1e-9


def _synthetic_data():
    rng = np.random.default_rng(101)
    n = 300
    X = np.column_stack([
        np.ones(n),
        rng.binomial(1, 0.5, n).astype(float),
        rng.normal(size=n),
    ])
    X_zero_one = X.copy()
    mu = 1.0 / (1.0 + np.exp(-(0.3 + 0.4 * X[:, 1] - 0.3 * X[:, 2])))
    phi = 8.0
    y_beta = rng.beta(mu * phi, (1 - mu) * phi)

    p0 = 1.0 / (1.0 + np.exp(-(-1.0 + 0.3 * X_zero_one[:, 1])))
    p1 = 1.0 / (1.0 + np.exp(-(-1.2 - 0.2 * X_zero_one[:, 1])))
    u = rng.uniform(size=n)
    y = y_beta.copy()
    y[u < p0] = 0.0
    y[(u >= p0) & (u < p0 + p1)] = 1.0
    return X, X_zero_one, y


# R reference, EDI 1.0.0, computed 2026-08-04 via:
#   EDI:::fast_zero_one_inflated_beta_cpp(X, X_zero_one, y)
# params = [beta (3), log_phi, zero_one_b0 (3), zero_one_b1 (3)]
R_PARAMS = np.array([
    0.352794130617712, 0.325391374378021, -0.282430219264307,
    1.88727372055993,
    -0.629974194384907, 0.00854523430697365, -0.00755452556415076,
    -0.60718765372455, 0.0122774565246871, -0.058961448979751,
])
R_NEG_LOGLIK = 262.24798255249


def test_matches_r_fixture():
    X, X_zero_one, y = _synthetic_data()
    res = fast_zero_one_inflated_beta(X, X_zero_one, y)

    assert res["params"] == pytest.approx(R_PARAMS, abs=ATOL, rel=RTOL)
    assert res["neg_loglik"] == pytest.approx(R_NEG_LOGLIK, abs=ATOL, rel=RTOL)


def test_result_shape_and_types():
    X, X_zero_one, y = _synthetic_data()
    res = fast_zero_one_inflated_beta(X, X_zero_one, y)

    assert res["params"].shape == (10,)  # 3 + 1 + 3 + 3
    assert isinstance(res["neg_loglik"], float)
    assert res["converged"] is True  # Python-side-only sanity check, see docstring


ZOIB_FULL_KEYS = {"b", "log_phi", "zero_one_b0", "zero_one_b1", "params", "vcov", "neg_loglik",
                  "converged", "num_iter", "hit_iteration_cap", "gradient_norm",
                  "min_eigenvalue_information", "observed_information", "fisher_information",
                  "information", "information_type", "hessian"}


def test_returns_r_fields_with_vcov_and_unpacked_blocks():
    """Same fields as R's fast_zero_one_inflated_beta_cpp (audit decision
    rpy-parity-d1f65c8c0): unpacked blocks, vcov and information matrices."""
    X, X_zero_one, y = _synthetic_data()
    res = fast_zero_one_inflated_beta(X, X_zero_one, y)

    assert ZOIB_FULL_KEYS <= set(res)
    p, q = X.shape[1], X_zero_one.shape[1]
    params = res["params"]
    assert res["b"] == pytest.approx(params[:p])
    assert res["log_phi"] == pytest.approx(params[p])
    assert res["zero_one_b0"] == pytest.approx(params[p + 1:p + 1 + q])
    assert res["zero_one_b1"] == pytest.approx(params[p + 1 + q:])
    k = params.size
    assert res["vcov"].shape == (k, k)
    assert np.all(np.isfinite(res["vcov"]))
    assert np.all(np.diag(res["vcov"]) > 0)
    assert res["vcov"] == pytest.approx(res["vcov"].T, abs=1e-10)
    info = res["observed_information"]
    assert res["fisher_information"] == pytest.approx(info)
    assert res["information"] == pytest.approx(info)
    assert res["hessian"] == pytest.approx(-info)
    assert res["information_type"] == "observed"
    # vcov is the inverse of the observed information (no fixed parameters).
    assert res["vcov"] @ info == pytest.approx(np.eye(k), abs=1e-6)


def test_estimate_only_skips_variance_but_keeps_estimates():
    X, X_zero_one, y = _synthetic_data()
    full = fast_zero_one_inflated_beta(X, X_zero_one, y)
    est = fast_zero_one_inflated_beta(X, X_zero_one, y, estimate_only=True)

    for key in ("vcov", "observed_information", "fisher_information", "information", "hessian"):
        assert key not in est
    for key in ("b", "log_phi", "zero_one_b0", "zero_one_b1", "params", "neg_loglik", "converged"):
        assert key in est
    assert est["params"] == pytest.approx(full["params"], abs=1e-12)
