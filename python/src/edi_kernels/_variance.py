"""Variance outputs for the GLM kernels, computed from what ``_core`` already returns (private).

v1.0.6-TODO-48. The R package has ``*_with_var_cpp`` twins of the OLS, logistic,
probit, Poisson and negative-binomial kernels that also return coefficient
variances. The Python bindings expose only the plain kernels, and
``fast_logistic_regression`` / ``fast_probit_regression`` returned
``ssq_b_j``, ``ssq_b_2``, ``dispersion`` and ``sigma2_hat`` fields that the
C++ never fills (always ``nan``). Every number the ``_with_var`` twins compute
is a function of the returned information matrix (``XtWX``), ``b``, ``X`` and
``y``, so this module fills them in after the call instead of adding bindings:

* ``fast_ols`` (``estimate_only=False``): ``sigma2_hat`` (residual sum of
  squares / (n - number of free coefficients)), ``vcov`` (``sigma2_hat`` times
  the inverse of X^T X over the free coefficients) and ``ssq_b_2``, as in
  ``fast_ols_with_var_cpp``.
* ``fast_logistic_regression``, ``fast_probit_regression``,
  ``fast_poisson_regression`` (``estimate_only=False``): ``vcov`` (inverse of
  the Fisher information ``XtWX`` over the free coefficients) and ``ssq_b_2``,
  as in the ``_with_var_cpp`` twins. The always-``nan`` keys are removed
  (``ssq_b_j``, ``dispersion`` and ``sigma2_hat`` for logistic/probit,
  ``dispersion`` for Poisson; ``ssq_b_2`` too when ``estimate_only=True``):
  read ``vcov[j - 1, j - 1]`` for R's ``ssq_b_j``.
* ``fast_neg_bin`` (``estimate_only=False``): ``vcov`` over
  ``[beta, log(theta)]`` and ``ssq_b_2``, as in ``fast_neg_bin_with_var_cpp``
  (the ``log(theta)`` row and column are ``nan`` when the fit sits at the
  Poisson boundary, ``dispersion_at_poisson_boundary=True``).

Fixed coefficients (``fixed_idx``, 1-based) have ``nan`` rows and columns in
``vcov``, and ``ssq_b_2`` is ``nan`` when coefficient 2 is fixed or absent,
matching R's ``NA``. A singular or non-finite information block gives an
all-``nan`` ``vcov`` rather than an error.
"""
from __future__ import annotations

from typing import Any, Callable, Mapping, Optional

import numpy as np

__all__ = ["POST"]


def _free_idx(n_params: int, fixed_idx: Any) -> np.ndarray:
    """0-based indices of the free parameters, given 1-based ``fixed_idx`` (or None)."""
    if fixed_idx is None:
        return np.arange(n_params)
    fixed = {int(i) - 1 for i in np.asarray(fixed_idx).ravel()}
    return np.array([i for i in range(n_params) if i not in fixed], dtype=int)


def _inverse_on_free(info: np.ndarray, free: np.ndarray, n_params: int) -> np.ndarray:
    """``n_params`` x ``n_params`` covariance: inverse of ``info[free, free]``, ``nan`` elsewhere.

    Mirrors ``invert_free_information`` + ``expand_free_covariance(..., fixed_as_na = true)``.
    """
    vcov = np.full((n_params, n_params), np.nan)
    if free.size == 0:
        return vcov
    block = info[np.ix_(free, free)]
    if not np.all(np.isfinite(block)) or np.linalg.matrix_rank(block) < free.size:
        return vcov
    try:
        vcov[np.ix_(free, free)] = np.linalg.inv(block)
    except np.linalg.LinAlgError:
        pass
    return vcov


def _ssq_b_2(vcov: np.ndarray, p: int) -> float:
    return float(vcov[1, 1]) if p >= 2 else float("nan")


def _info(res: Mapping[str, Any], n_params: int) -> Optional[np.ndarray]:
    """The returned ``XtWX`` when it is a usable ``n_params`` x ``n_params`` matrix, else None."""
    info = res.get("XtWX")
    if info is None:
        return None
    info = np.asarray(info, dtype=float)
    return info if info.shape == (n_params, n_params) else None


def _ols(res: dict, a: Mapping[str, Any]) -> dict:
    if a.get("estimate_only", True):
        return res
    X = np.asarray(a["X"], dtype=float)
    p = X.shape[1]
    info = _info(res, p)
    if info is None:
        return res
    b = np.asarray(res["b"], dtype=float)
    free = _free_idx(p, a.get("fixed_idx"))
    df = X.shape[0] - free.size
    resid = np.asarray(a["y"], dtype=float).ravel() - X @ b
    sigma2_hat = float(resid @ resid / df) if df > 0 and np.all(np.isfinite(b)) else float("nan")
    vcov = sigma2_hat * _inverse_on_free(info, free, p)
    res["sigma2_hat"] = sigma2_hat
    res["vcov"] = vcov
    res["ssq_b_2"] = _ssq_b_2(vcov, p)
    return res


def _glm(drop: tuple) -> Callable[[dict, Mapping[str, Any]], dict]:
    def post(res: dict, a: Mapping[str, Any]) -> dict:
        for key in drop + ("ssq_b_2",):  # ssq_b_2 comes back nan from C++; refilled below
            res.pop(key, None)
        if a.get("estimate_only", False):
            return res
        p = np.asarray(a["X"]).shape[1]
        info = _info(res, p)
        if info is None:
            return res
        vcov = _inverse_on_free(info, _free_idx(p, a.get("fixed_idx")), p)
        res["vcov"] = vcov
        res["ssq_b_2"] = _ssq_b_2(vcov, p)
        return res
    return post


def _neg_bin(res: dict, a: Mapping[str, Any]) -> dict:
    if a.get("estimate_only", False):
        return res
    p = np.asarray(a["X"]).shape[1]
    info = _info(res, p + 1)
    if info is None:
        return res
    free = _free_idx(p + 1, a.get("fixed_idx"))
    if res.get("dispersion_at_poisson_boundary", False):
        free = free[free != p]  # negbin_information_spec(): drop log(theta) at the boundary
    vcov = _inverse_on_free(info, free, p + 1)
    res["vcov"] = vcov
    res["ssq_b_2"] = _ssq_b_2(vcov, p)
    return res


_BINARY_DEAD = ("ssq_b_j", "dispersion", "sigma2_hat")

#: kernel name -> post(result_dict, bound_arguments) -> result_dict
POST: Mapping[str, Callable[[dict, Mapping[str, Any]], dict]] = {
    "fast_ols": _ols,
    "fast_logistic_regression": _glm(_BINARY_DEAD),
    "fast_probit_regression": _glm(_BINARY_DEAD),
    "fast_poisson_regression": _glm(("dispersion",)),
    "fast_neg_bin": _neg_bin,
}
