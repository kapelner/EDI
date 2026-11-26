"""Input checks for the edi_kernels wrappers (private; numpy only).

v1.0.6-TODO-59. The pybind11 bindings in ``_core`` convert argument types but
check nothing else, so a 1/2-coded treatment vector, a NaN in ``y`` or arrays of
different lengths went straight into the C++ solvers (v1.0.6-TODO-47: silent
``nan`` results and a sign-flipped log-rank estimate). The R package never hits
this because checkmate runs first. This module is the Python counterpart:

* checkmate-named helpers (``assert_numeric``, ``assert_binary``, ...), each
  raising ``ValueError`` that names the offending argument;
* ``KERNELS``, the one declarative table of every exported kernel's ordered
  parameter names, argument rules, equal-length groups and R twin;
* ``set_checks()`` / ``get_checks()``, mirroring R's ``should_run_asserts()``.
  Turning checks off skips only the convenience rules (finite values, ranges,
  choices, counts). The rules that guard correctness, a 0/1 treatment or event
  vector and matching lengths, always run (the rule v1.0.6-TODO-58 sets for R);
* ``wrap_kernel()``, which ``__init__.py`` uses to put a thin checking wrapper
  around every ``_core`` function.
"""
from __future__ import annotations

import functools
from typing import Any, Callable, Mapping, NamedTuple, Optional, Sequence, TypeVar

import numpy as np

__all__ = [
    "assert_numeric", "assert_matrix", "assert_binary", "assert_integerish",
    "assert_count", "assert_choice", "assert_same_length",
    "set_checks", "get_checks", "Rule", "KernelSpec", "KERNELS", "check_call", "wrap_kernel",
]

_RUN_CHECKS = True
_DBL_MIN = float(np.finfo(float).tiny)  # R's .Machine$double.xmin


def set_checks(enabled: bool) -> bool:
    """Turn the optional input checks on or off; returns the previous setting.

    Mirrors R's ``should_run_asserts()``. With checks off, only the checks that
    guard correctness still run: a 0/1 treatment or event vector, and arguments
    that must have matching lengths. Finite-value, range, choice and count checks
    are skipped, saving their (small) cost in tight loops.
    """
    global _RUN_CHECKS
    if not isinstance(enabled, (bool, np.bool_)):
        raise ValueError(f"argument 'enabled' must be True or False, not {enabled!r}")
    previous, _RUN_CHECKS = _RUN_CHECKS, bool(enabled)
    return previous


def get_checks() -> bool:
    """Return whether the optional input checks are on (see ``set_checks``)."""
    return _RUN_CHECKS


# ------------------------------------------------------------------ helpers


def _arr(x: Any, name: str) -> np.ndarray:
    try:
        a = np.asarray(x)
    except Exception as exc:  # ragged lists and the like
        raise ValueError(f"argument '{name}' must be numeric: {exc}") from None
    if a.dtype.kind not in "biuf":
        raise ValueError(f"argument '{name}' must be numeric, not dtype {a.dtype}")
    return a


def _length(x: Any) -> int:
    shape = np.shape(x)
    return int(shape[0]) if shape else 1


def _show(values: np.ndarray, k: int = 5) -> str:
    vals = np.unique(values)
    shown = ", ".join(repr(v.item()) for v in vals[:k])
    return shown + (", ..." if vals.size > k else "")


def assert_numeric(x: Any, n: Optional[int] = None, finite: bool = True, *, name: str = "x",
                   lower: Optional[float] = None, upper: Optional[float] = None) -> Any:
    """checkmate::assertNumeric: numeric, optionally all finite, length ``n``, in [lower, upper]."""
    a = _arr(x, name)
    if n is not None and a.size != n:
        raise ValueError(f"argument '{name}' must have length {n}, not {a.size}")
    if finite and not np.isfinite(a).all():
        raise ValueError(f"argument '{name}' must be finite (no NaN or inf); "
                         f"found {int((~np.isfinite(a)).sum())} non-finite value(s)")
    if lower is not None and (a < lower).any():
        raise ValueError(f"argument '{name}' must be >= {lower}; found {_show(a[a < lower])}")
    if upper is not None and (a > upper).any():
        raise ValueError(f"argument '{name}' must be <= {upper}; found {_show(a[a > upper])}")
    return x


def assert_matrix(x: Any, finite: bool = True, *, name: str = "X") -> Any:
    """checkmate::assertMatrix (numeric): a 1-D (one column) or 2-D numeric array."""
    a = _arr(x, name)
    if a.ndim not in (1, 2):
        raise ValueError(f"argument '{name}' must be a 2-D numeric array, not {a.ndim}-D")
    return assert_numeric(x, finite=finite, name=name)


def assert_binary(x: Any, *, name: str = "w") -> Any:
    """A 0/1 vector (treatment or event indicator). Always runs: other codings give wrong answers."""
    a = _arr(x, name)
    ok = (a == 0) | (a == 1)
    if not ok.all():
        bad = a[~ok]
        raise ValueError(
            f"argument '{name}' must contain only 0 and 1; found {_show(bad)}. "
            "Recode it to 0/1 first (e.g. 1/2 coding: w - 1; -1/1 coding: (w + 1) // 2).")
    return x


def assert_integerish(x: Any, *, name: str = "x", lower: Optional[float] = None) -> Any:
    """checkmate::assertIntegerish: finite whole numbers, optionally >= ``lower``."""
    a = _arr(x, name)
    assert_numeric(a, finite=True, name=name, lower=lower)
    if a.dtype.kind == "f" and (a != np.round(a)).any():
        raise ValueError(f"argument '{name}' must contain whole numbers; found {_show(a[a != np.round(a)])}")
    return x


def assert_count(k: Any, positive: bool = False, *, name: str = "k") -> Any:
    """checkmate::assertCount: one whole number >= 0 (>= 1 if ``positive``)."""
    if isinstance(k, (bool, np.bool_)) or np.ndim(k) != 0:
        raise ValueError(f"argument '{name}' must be a single whole number, not {k!r}")
    assert_integerish(k, name=name, lower=1 if positive else 0)
    return k


def assert_choice(s: Any, choices: Sequence[str], *, name: str = "s") -> Any:
    """checkmate::assertChoice: one of ``choices``."""
    if not isinstance(s, str) or s not in choices:
        raise ValueError(f"argument '{name}' must be one of {', '.join(map(repr, choices))}; not {s!r}")
    return s


def assert_same_length(**named: Any) -> None:
    """All arguments have the same length (rows for a matrix). Always runs.

    A key written ``ncol__X`` stands for the number of columns of ``X``.
    """
    lens = {}
    for key, value in named.items():
        if key.startswith("ncol__"):
            shape = np.shape(value)
            lens[f"ncol({key[6:]})"] = int(shape[1]) if len(shape) == 2 else 1
        else:
            lens[key] = _length(value)
    if len(set(lens.values())) > 1:
        desc = ", ".join(f"{k} = {v}" for k, v in lens.items())
        raise ValueError(f"arguments {', '.join(repr(k) for k in lens)} must have the same length; got {desc}")


# --------------------------------------------------------------- rule table


class Rule(NamedTuple):
    """One argument rule. ``kind`` picks the helper:

    numeric | matrix | binary | integerish | count | choice.
    ``r_contract`` = (class, method, arg) of the R checkmate row in
    R/package_tests/checkmate_argument_contracts.csv that states the same rule
    (compared by python/tests/test_input_checks.py), or None if R has none.
    """
    arg: str
    kind: str
    finite: bool = True
    lower: Optional[float] = None
    upper: Optional[float] = None
    n: Optional[int] = None
    positive: bool = False
    choices: tuple = ()
    r_contract: Optional[tuple] = None

    @property
    def always(self) -> bool:
        """Correctness rules (0/1 vectors) run even with set_checks(False)."""
        return self.kind == "binary"


class KernelSpec(NamedTuple):
    params: tuple                 # ordered parameter names, as in _core.pyi
    rules: tuple = ()             # Rule objects
    same_length: tuple = ()       # tuples of argument names (always checked)
    r_twin: Optional[str] = None  # R export reaching the same C++ kernel; None = no R export


def _num(arg, **kw): return Rule(arg, "numeric", **kw)
def _mat(arg, **kw): return Rule(arg, "matrix", **kw)
def _bin(arg): return Rule(arg, "binary")
def _int(arg, **kw): return Rule(arg, "integerish", **kw)
def _cnt(arg, **kw): return Rule(arg, "count", positive=True, **kw)
def _pos(arg): return Rule(arg, "numeric", n=1, lower=0.0)
def _chc(arg, choices, **kw): return Rule(arg, "choice", choices=tuple(choices), **kw)


X, Y = _mat("X"), _num("y")
MAXIT, TOL, EPS_G, RELTOL, N_GH = _cnt("maxit"), _pos("tol"), _pos("eps_g"), _pos("reltol"), _cnt("n_gh")
WEIGHTS = _num("weights", lower=0.0)
GROUP = _int("group_id")
J_T = Rule("j_T", "count")  # 0-based index of the treatment coefficient
MAX_LOG_SIGMA = _pos("max_abs_log_sigma")
XY = (("X", "y"),)
XY_W = (("X", "y", "weights"),)
# A scalar math kernel: numeric, but NaN/inf propagate elementwise by design.
MATH = KernelSpec(("x",), (_num("x", finite=False),))
P_TAIL = dict(lower=_DBL_MIN, upper=1.0)  # R: lower = .Machine$double.xmin, upper = 1 - double.xmin (== 1)

_GLM_W = ("X", "y", "weights", "warm_start_beta", "smart_cold_start", "maxit", "tol", "fixed_idx",
          "fixed_values", "optimization_alg", "warm_start_weights", "warm_start_fisher_info", "estimate_only")
_BINOM = ("X", "y", "weights", "maxit", "tol", "fixed_idx", "fixed_values", "warm_start_beta",
          "smart_cold_start", "warm_start_weights", "warm_start_fisher_info", "estimate_only")
_BINOM_VAR = ("X", "y", "j", "maxit", "tol", "fixed_idx", "fixed_values", "warm_start_beta",
              "smart_cold_start", "warm_start_weights", "warm_start_fisher_info")
_ORD = ("X", "y", "warm_start_params", "smart_cold_start", "maxit", "tol", "optimization_alg", "fixed_idx",
        "fixed_values", "warm_start_fisher_info", "estimate_only")
_ORD_LOGIT = ("X", "y", "maxit", "tol", "smart_cold_start", "fixed_idx", "fixed_values", "optimization_alg",
              "warm_start_fisher_info", "warm_start_params", "warm_start_beta")
_ZAP = ("X", "y", "Xzi", "is_hurdle", "warm_start_params", "smart_cold_start", "maxit", "tol", "fixed_idx",
        "fixed_values", "optimization_alg", "warm_start_fisher_info")
_ZINB = ("Xc", "Xz", "y", "warm_start_params", "maxit", "tol", "fixed_idx", "fixed_values", "optimization_alg",
         "smart_cold_start", "warm_start_fisher_info")
_GLMM = ("X", "y", "group_id", "j_T", "warm_start_params", "smart_cold_start", "estimate_only", "n_gh",
         "maxit", "eps_g")
_ORD_Y = _int("y")
_ORD_RULES = (X, _ORD_Y, MAXIT, TOL)
_WTEST = ("time", "dead", "w")

KERNELS: Mapping[str, KernelSpec] = {
    # ---- continuous
    "fast_ols": KernelSpec(("X", "y", "fixed_idx", "fixed_values", "estimate_only"), (X, Y), XY, "fast_ols_cpp"),
    "fast_robust_regression": KernelSpec(
        ("X", "y", "warm_start_beta", "smart_cold_start", "method", "j", "c", "maxit", "tol", "fixed_idx",
         "fixed_values", "warm_start_weights", "warm_start_fisher_info", "estimate_only"),
        (X, Y, _chc("method", ("M", "MM"), r_contract=("InferenceContinRobustRegr", "initialize", "method")),
         _cnt("j"), _pos("c"),
         _cnt("maxit", r_contract=("InferenceContinKKRobustRegrOneLik", "initialize", "maxit")), TOL),
        XY, "fast_robust_regression_cpp"),
    # y: non-finite entries are dropped by the kernel (documented), so NaN is allowed here.
    "wilcox_hl_point_estimate": KernelSpec(("y", "w"), (_num("y", finite=False), _bin("w")), (("y", "w"),),
                                           "wilcox_hl_point_estimate_cpp"),
    "ols_hc2_post_fit": KernelSpec(("X_fit", "y", "coef_hat", "j_treat"),
                                   (_mat("X_fit"), Y, _num("coef_hat"), _cnt("j_treat")),
                                   (("X_fit", "y"), ("ncol__X_fit", "coef_hat")), "ols_hc2_post_fit_cpp"),
    # ---- binary
    "fast_logistic_regression": KernelSpec(_GLM_W, (X, Y, WEIGHTS, MAXIT, TOL), XY_W, "fast_logistic_regression_cpp"),
    "fast_probit_regression": KernelSpec(_GLM_W, (X, Y, WEIGHTS, MAXIT, TOL), XY_W, "fast_probit_regression_cpp"),
    "fast_log_binomial_regression": KernelSpec(_BINOM, (X, Y, WEIGHTS, MAXIT, TOL), XY_W,
                                               "fast_log_binomial_regression_cpp"),
    "fast_log_binomial_regression_with_var": KernelSpec(_BINOM_VAR, (X, Y, _cnt("j"), MAXIT, TOL), XY,
                                                        "fast_log_binomial_regression_with_var_cpp"),
    "fast_identity_binomial_regression": KernelSpec(_BINOM, (X, Y, WEIGHTS, MAXIT, TOL), XY_W,
                                                    "fast_identity_binomial_regression_cpp"),
    "fast_identity_binomial_regression_with_var": KernelSpec(_BINOM_VAR, (X, Y, _cnt("j"), MAXIT, TOL), XY,
                                                             "fast_identity_binomial_regression_with_var_cpp"),
    # ---- count
    "fast_poisson_regression": KernelSpec(_GLM_W, (X, Y, WEIGHTS, MAXIT, TOL), XY_W, "fast_poisson_regression_cpp"),
    "fast_neg_bin": KernelSpec(
        ("X", "y", "warm_start_params", "smart_cold_start", "maxit", "eps_g", "fixed_idx", "fixed_values",
         "optimization_alg", "warm_start_fisher_info", "estimate_only", "weights"),
        (X, _int("y", lower=0), MAXIT, EPS_G, WEIGHTS), XY_W, "fast_neg_bin_cpp"),
    "fast_zinb": KernelSpec(_ZINB, (_mat("Xc"), _mat("Xz"), Y, MAXIT, TOL), (("Xc", "Xz", "y"),), "fast_zinb_cpp"),
    # No fast_zinb_with_var_cpp in R: fast_zinb_cpp(estimate_only = FALSE) reaches the same kernel.
    "fast_zinb_with_var": KernelSpec(_ZINB, (_mat("Xc"), _mat("Xz"), Y, MAXIT, TOL), (("Xc", "Xz", "y"),),
                                     "fast_zinb_cpp"),
    "fast_zero_augmented_poisson": KernelSpec(_ZAP, (X, Y, _mat("Xzi"), MAXIT, TOL), (("X", "y", "Xzi"),),
                                              "fast_zero_augmented_poisson_cpp"),
    # Likewise reached in R through fast_zero_augmented_poisson_cpp(estimate_only = FALSE).
    "fast_zero_augmented_poisson_with_var": KernelSpec(_ZAP, (X, Y, _mat("Xzi"), MAXIT, TOL), (("X", "y", "Xzi"),),
                                                       "fast_zero_augmented_poisson_cpp"),
    "fast_hurdle_negbin": KernelSpec(
        ("X", "y", "X_hurdle", "warm_start_params", "smart_cold_start", "maxit", "tol", "fixed_idx",
         "fixed_values", "optimization_alg", "warm_start_fisher_info", "warm_start_hurdle_fisher_info",
         "estimate_only", "j"),
        (X, Y, _mat("X_hurdle"), MAXIT, TOL, _cnt("j")), (("X", "y", "X_hurdle"),), "fast_hurdle_negbin_cpp"),
    "fast_truncated_negbin_count": KernelSpec(
        ("X", "y", "warm_start_params", "smart_cold_start", "estimate_only", "maxit", "tol", "fixed_idx",
         "fixed_values", "optimization_alg", "warm_start_fisher_info"),
        (X, Y, MAXIT, TOL), XY, "fast_truncated_negbin_count_cpp"),
    "fast_cpoisson_combined": KernelSpec(
        ("yT_v", "n_k_v", "X_diff_v", "y_r", "w_r", "X_r", "maxit", "tol", "fixed_idx", "fixed_values",
         "warm_start_fisher_info", "warm_start_params", "warm_start_beta", "estimate_only"),
        (_num("yT_v"), _num("n_k_v"), _mat("X_diff_v"), _num("y_r"), _bin("w_r"), _mat("X_r"), MAXIT, TOL),
        (("yT_v", "n_k_v", "X_diff_v"), ("y_r", "w_r", "X_r")), "fast_cpoisson_combined_with_var_cpp"),
    # ---- proportion
    "fast_beta_regression": KernelSpec(
        ("X", "y", "weights", "warm_start_beta", "smart_cold_start", "start_phi", "fixed_idx", "fixed_values",
         "optimization_alg", "warm_start_fisher_info", "estimate_only"),
        (X, Y, WEIGHTS, _pos("start_phi")), XY_W, "fast_beta_regression_cpp"),
    "fast_zero_one_inflated_beta": KernelSpec(
        ("X", "X_zero_one", "y", "warm_start_params", "smart_cold_start", "fixed_idx", "fixed_values",
         "optimization_alg", "warm_start_fisher_info", "estimate_only"),
        (X, _mat("X_zero_one"), Y), (("X", "X_zero_one", "y"),), "fast_zero_one_inflated_beta_cpp"),
    # ---- ordinal
    "fast_adjacent_category_logit": KernelSpec(_ORD_LOGIT, _ORD_RULES, XY, "fast_adjacent_category_logit_cpp"),
    "fast_continuation_ratio_regression": KernelSpec(
        ("X", "y", "maxit", "tol", "warm_start_beta", "smart_cold_start", "fixed_idx", "fixed_values",
         "optimization_alg", "warm_start_fisher_info"),
        _ORD_RULES, XY, "fast_continuation_ratio_regression_cpp"),
    "fast_ordinal_regression": KernelSpec(
        ("X", "y", "weights", "warm_start_params", "smart_cold_start", "maxit", "tol", "fixed_idx",
         "fixed_values", "optimization_alg", "warm_start_fisher_info", "estimate_only"),
        _ORD_RULES + (WEIGHTS,), XY_W, "fast_ordinal_regression_cpp"),
    "fast_ordinal_probit_regression": KernelSpec(_ORD, _ORD_RULES, XY, "fast_ordinal_probit_regression_cpp"),
    "fast_ordinal_cauchit_regression": KernelSpec(_ORD, _ORD_RULES, XY, "fast_ordinal_cauchit_regression_cpp"),
    "fast_ordinal_cloglog_regression": KernelSpec(_ORD, _ORD_RULES, XY, "fast_ordinal_cloglog_regression_cpp"),
    "fast_ordinal_clmm": KernelSpec(
        ("X", "y", "group_id", "K", "j_T", "link", "estimate_only", "n_gh", "max_abs_log_sigma", "maxit", "eps_g"),
        (X, _ORD_Y, GROUP, _cnt("K"), J_T, _chc("link", ("logit", "probit", "cauchit", "cloglog")), N_GH,
         MAX_LOG_SIGMA, MAXIT, EPS_G),
        (("X", "y", "group_id"),), "fast_ordinal_clmm_cpp"),
    "fast_ordinal_glmm": KernelSpec(
        ("X", "y", "group_id", "K", "j_T", "smart_cold_start", "estimate_only", "n_gh", "max_abs_log_sigma",
         "maxit", "eps_g"),
        (X, _ORD_Y, GROUP, _cnt("K"), J_T, N_GH, MAX_LOG_SIGMA, MAXIT, EPS_G),
        (("X", "y", "group_id"),), "fast_ordinal_glmm_cpp"),
    "fast_stereotype_logit": KernelSpec(_ORD_LOGIT, _ORD_RULES, XY, "fast_stereotype_logit_cpp"),
    "fast_ridit_analysis": KernelSpec(
        ("w", "y", "reference"),
        (_bin("w"), _ORD_Y, _chc("reference", ("control", "treatment", "pooled"),
                                 r_contract=("InferenceOrdinalRidit", "initialize", "reference"))),
        (("w", "y"),), "fast_ridit_analysis_cpp"),
    # ---- incidence / GEE / two-proportion
    "gee_pairs_singletons": KernelSpec(
        ("X", "y", "group_id", "family", "warm_start_beta", "warm_start_fisher_info", "maxit", "tol"),
        (X, Y, GROUP, _chc("family", ("gaussian", "binomial", "poisson")), MAXIT, TOL),
        (("X", "y", "group_id"),), "gee_pairs_singletons_cpp"),
    "mn_ci": KernelSpec(
        ("x_t", "n_t", "x_c", "n_c", "p_t_obs", "p_c_obs", "alpha", "pval_epsilon"),
        (_pos("x_t"), _pos("n_t"), _pos("x_c"), _pos("n_c"),
         _num("p_t_obs", n=1, lower=0.0, upper=1.0), _num("p_c_obs", n=1, lower=0.0, upper=1.0),
         _num("alpha", n=1, r_contract=("InferenceIncidMiettinenNurminenRiskDiff",
                                        "compute_asymp_confidence_interval", "alpha"), **P_TAIL),
         _num("pval_epsilon", n=1, r_contract=("InferenceIncidMiettinenNurminenRiskDiff",
                                               "compute_rand_confidence_interval", "pval_epsilon"), **P_TAIL)),
        (), "mn_ci_cpp"),
    "mn_pvalue": KernelSpec(
        ("x_t", "n_t", "x_c", "n_c", "delta", "p_t_obs", "p_c_obs"),
        (_pos("x_t"), _pos("n_t"), _pos("x_c"), _pos("n_c"),
         _num("delta", n=1, r_contract=("InferenceIncidMiettinenNurminenRiskDiff",
                                        "compute_asymp_two_sided_pval", "delta")),
         _num("p_t_obs", n=1, lower=0.0, upper=1.0), _num("p_c_obs", n=1, lower=0.0, upper=1.0)),
        (), "mn_pvalue_cpp"),
    "newcombe_independent_ci": KernelSpec(
        ("x1", "n1", "x2", "n2", "alpha"),
        (_pos("x1"), _pos("n1"), _pos("x2"), _pos("n2"),
         _num("alpha", n=1, r_contract=("InferenceIncidNewcombeRiskDiff",
                                        "compute_asymp_confidence_interval", "alpha"), **P_TAIL)),
        (), "newcombe_independent_ci_cpp"),
    # ---- survival
    "fast_coxph_regression": KernelSpec(
        ("X", "y", "dead", "warm_start_beta", "smart_cold_start", "estimate_only", "maxit", "tol"),
        (X, Y, _bin("dead"), MAXIT, TOL), (("X", "y", "dead"),), "fast_coxph_regression_cpp"),
    "fast_stratified_coxph_regression": KernelSpec(
        ("X", "y", "dead", "strata", "warm_start_beta", "smart_cold_start", "estimate_only", "maxit", "tol"),
        (X, Y, _bin("dead"), _int("strata"), MAXIT, TOL), (("X", "y", "dead", "strata"),),
        "fast_stratified_coxph_regression_cpp"),
    # y / y_L / y_R use NaN (and inf) to encode censoring, so they are not finite-checked.
    "fast_weibull_regression_general": KernelSpec(
        ("X", "y", "y_L", "y_R", "warm_start_params", "smart_cold_start", "estimate_only", "maxit", "tol"),
        (X, _num("y", finite=False), _num("y_L", finite=False), _num("y_R", finite=False), MAXIT, TOL),
        (("X", "y", "y_L", "y_R"),), "fast_weibull_regression_general_cpp"),
    "fast_weibull_frailty": KernelSpec(
        ("X", "y", "dead", "group_id", "warm_start_params", "warm_start_beta", "estimate_only", "n_gh",
         "max_abs_log_sigma", "maxit", "eps_g"),
        (X, Y, _bin("dead"), GROUP, N_GH, MAX_LOG_SIGMA, MAXIT, EPS_G), (("X", "y", "dead", "group_id"),),
        "fast_weibull_frailty_cpp"),
    "fast_clayton_weibull_aft_optim": KernelSpec(
        ("X", "y", "dead", "pair_idx", "singleton_rows", "warm_start_params", "estimate_only", "maxit", "reltol"),
        (X, Y, _bin("dead"), _int("pair_idx"), _int("singleton_rows"), MAXIT, RELTOL),
        (("X", "y", "dead"),), "fast_clayton_weibull_aft_optim_cpp"),
    "fast_dep_cens_transform_optim": KernelSpec(
        ("X", "y", "dead", "warm_start_params", "smart_cold_start", "estimate_only", "maxit", "reltol"),
        (X, Y, _bin("dead"), MAXIT, RELTOL), (("X", "y", "dead"),), "fast_dep_cens_transform_optim_cpp"),
    "fast_gehan_wilcox_stats": KernelSpec(_WTEST, (_num("time"), _bin("dead"), _bin("w")), (_WTEST,),
                                          "fast_gehan_wilcox_stats_cpp"),
    "fast_logrank_stats": KernelSpec(_WTEST, (_num("time"), _bin("dead"), _bin("w")), (_WTEST,),
                                     "fast_logrank_stats_cpp"),
    "get_survival_stat_diff": KernelSpec(
        ("y", "dead", "w", "requested_stat"),
        (Y, _bin("dead"), _bin("w"), _chc("requested_stat", ("median", "restricted_mean"))),
        (("y", "dead", "w"),), "get_survival_stat_diff"),
    # ---- GLMM
    "fast_poisson_glmm": KernelSpec(
        _GLMM + ("fixed_idx", "fixed_values", "optimization_alg", "warm_start_fisher_info", "row_weights"),
        (X, Y, GROUP, J_T, N_GH, MAXIT, EPS_G, _num("row_weights", lower=0.0)),
        (("X", "y", "group_id", "row_weights"),), "fast_poisson_glmm_cpp"),
    "fast_logistic_glmm": KernelSpec(_GLMM, (X, Y, GROUP, J_T, N_GH, MAXIT, EPS_G), (("X", "y", "group_id"),),
                                     "fast_logistic_glmm_cpp"),
    "fast_hurdle_poisson_glmm": KernelSpec(_GLMM, (X, Y, GROUP, J_T, N_GH, MAXIT, EPS_G), (("X", "y", "group_id"),),
                                           "fast_hurdle_poisson_glmm_cpp"),
    "fast_gaussian_lmm": KernelSpec(
        ("X", "y", "group_id", "warm_start_params", "warm_start_beta", "estimate_only", "maxit", "eps_g",
         "fixed_idx", "fixed_values", "optimization_alg", "warm_start_fisher_info", "weights"),
        (X, Y, GROUP, MAXIT, EPS_G, WEIGHTS), (("X", "y", "group_id", "weights"),), "fast_gaussian_lmm_cpp"),
    "fast_clogit_plus_glmm": KernelSpec(
        ("X_disc", "y_disc", "X_conc", "y_conc", "group_conc", "has_discordant", "has_concordant",
         "warm_start_params", "warm_start_beta", "estimate_only", "max_abs_log_sigma", "maxit", "eps_g",
         "fixed_idx", "fixed_values", "optimization_alg", "warm_start_fisher_info", "n_gh",
         "weights_disc", "weights_conc"),
        (_mat("X_disc"), _num("y_disc"), _mat("X_conc"), _num("y_conc"), _int("group_conc"), MAX_LOG_SIGMA,
         MAXIT, EPS_G, N_GH, _num("weights_disc", lower=0.0), _num("weights_conc", lower=0.0)),
        (("X_disc", "y_disc", "weights_disc"), ("X_conc", "y_conc", "group_conc", "weights_conc")),
        "fast_clogit_plus_glmm_cpp"),
    # ---- fast_math utilities: inline C++ helpers in R (no Rcpp export), so no R twin.
    "fast_pchisq_upper": KernelSpec(("statistic", "df"),
                                    (_num("statistic", finite=False), _num("df", finite=False)),
                                    (("statistic", "df"),)),
    "fast_digamma": MATH, "fast_trigamma": MATH, "fast_lgamma": MATH, "fast_erfc": MATH,
    "fast_log_pnorm": MATH, "fast_log_dnorm": MATH, "pnorm_fast": MATH, "dnorm_fast": MATH,
    "fast_atan": MATH, "fast_log1pexp": MATH,
    "fast_qnorm": KernelSpec(("p",), (_num("p", finite=False),)),
    "fast_lbeta": KernelSpec(("a", "b"), (_num("a", finite=False), _num("b", finite=False)), (("a", "b"),)),
    "fast_dnbinom_mu": KernelSpec(("x", "size", "mu", "return_log"),
                                  (_num("x", finite=False), _num("size", n=1, finite=False),
                                   _num("mu", n=1, finite=False))),
}


def _apply(rule: Rule, value: Any) -> None:
    k, name = rule.kind, rule.arg
    if k == "binary":
        assert_binary(value, name=name)
    elif k == "numeric":
        assert_numeric(value, rule.n, rule.finite, name=name, lower=rule.lower, upper=rule.upper)
    elif k == "matrix":
        assert_matrix(value, rule.finite, name=name)
    elif k == "integerish":
        assert_integerish(value, name=name, lower=rule.lower)
    elif k == "count":
        assert_count(value, rule.positive, name=name)
    elif k == "choice":
        assert_choice(value, rule.choices, name=name)
    else:  # pragma: no cover - table typo
        raise AssertionError(f"unknown rule kind {k!r}")


def check_call(kernel: str, args: tuple, kwargs: Mapping[str, Any]) -> None:
    """Check one call's arguments against ``KERNELS[kernel]``; raise ValueError on the first failure.

    Arguments not supplied (left at their defaults) or passed as None are not checked.
    Unknown names and extra positionals are left for the kernel itself to reject.
    """
    spec = KERNELS[kernel]
    given = dict(zip(spec.params, args))
    given.update(kwargs)
    present = {k: v for k, v in given.items() if v is not None}
    run_all = _RUN_CHECKS
    try:
        for rule in spec.rules:
            if rule.arg in present and (run_all or rule.always):
                _apply(rule, present[rule.arg])
        for group in spec.same_length:
            vals = {}
            for key in group:
                src = key[6:] if key.startswith("ncol__") else key
                if src in present:
                    vals[key] = present[src]
            if len(vals) > 1:
                assert_same_length(**vals)
    except ValueError as exc:
        raise ValueError(f"{kernel}(): {exc}") from None


_F = TypeVar("_F", bound=Callable[..., Any])


def wrap_kernel(fn: _F) -> _F:
    """Return ``fn`` behind a checking wrapper with the same name, docstring and (static) type.

    Kernels listed in ``edi_kernels._variance.POST`` also get their variance outputs filled in
    from the returned information matrix after the call (v1.0.6-TODO-48).
    """
    from ._variance import POST

    name = fn.__name__
    if name not in KERNELS:
        raise KeyError(f"{name} has no entry in edi_kernels._checks.KERNELS")
    post = POST.get(name)

    @functools.wraps(fn)
    def wrapper(*args: Any, **kwargs: Any) -> Any:
        check_call(name, args, kwargs)
        out = fn(*args, **kwargs)
        if post is None:
            return out
        bound = dict(zip(KERNELS[name].params, args))
        bound.update(kwargs)
        return post(out, bound)

    # Pickle and help() look the function up by module + qualname: point them at the wrapper.
    wrapper.__module__ = "edi_kernels"
    wrapper.__qualname__ = name
    return wrapper  # type: ignore[return-value]
