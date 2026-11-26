"""Input-validation gate for the Python kernels (edi_kernels._checks).

v1.0.6-TODO-59: every exported kernel is a thin wrapper that checks its inputs
before calling the pybind11 function. This file also closes v1.0.6-TODO-47: with
y = [1, 2, 3.5, 4, 2.2, 3.1], every death observed and a 1/2- or -1/1-coded `w`,
wilcox_hl_point_estimate, get_survival_stat_diff and fast_ridit_analysis
silently returned nan and fast_logrank_stats flipped the sign of beta_hat. Now
every treatment-vector kernel raises ValueError naming `w`, whether or not the
optional checks are on.

Parts:
1. the checkmate-named helpers;
2. the rules table: it covers exactly the exported kernels, its parameter names
   match the type stub, each R twin exists in RcppExports.R, and each rule that
   names an R checkmate contract agrees with
   R/package_tests/checkmate_argument_contracts.csv (pure text; no R needed);
3. generic per-rule tests (NaN, wrong length, bad choice) driven by the table
   through check_call(), so no compiled call is needed for them;
4. end-to-end tests through the real kernels: TODO-86's repro for all
   treatment-vector kernels under 1/2 and -1/1 coding, wrong lengths, NaN.
"""
import csv
import math
import pickle
import re
from pathlib import Path

import numpy as np
import pytest

import edi_kernels
from edi_kernels import _checks, _core
from edi_kernels._checks import (
    KERNELS,
    assert_binary,
    assert_choice,
    assert_count,
    assert_integerish,
    assert_matrix,
    assert_numeric,
    assert_same_length,
    check_call,
)

PY_DIR = Path(__file__).resolve().parents[1]
REPO = PY_DIR.parent
STUB = PY_DIR / "src" / "edi_kernels" / "_core.pyi"
RCPP_EXPORTS = REPO / "R" / "EDI" / "R" / "RcppExports.R"
CONTRACTS = REPO / "R" / "package_tests" / "checkmate_argument_contracts.csv"


@pytest.fixture(autouse=True)
def _checks_on():
    """Every test starts with the optional checks on and leaves them as found."""
    prev = edi_kernels.set_checks(True)
    yield
    edi_kernels.set_checks(prev)


# --------------------------------------------------------------- 1. helpers


def test_assert_numeric():
    assert_numeric([1.0, 2.0], n=2, name="y")
    with pytest.raises(ValueError, match="'y' must be finite"):
        assert_numeric([1.0, np.nan], name="y")
    with pytest.raises(ValueError, match="'y' must be finite"):
        assert_numeric([1.0, np.inf], name="y")
    assert_numeric([1.0, np.nan], finite=False, name="y")
    with pytest.raises(ValueError, match="'y' must have length 3"):
        assert_numeric([1.0, 2.0], n=3, name="y")
    with pytest.raises(ValueError, match="'y' must be numeric"):
        assert_numeric(["a", "b"], name="y")
    with pytest.raises(ValueError, match="'a' must be >= 0"):
        assert_numeric(-1.0, name="a", lower=0.0)
    with pytest.raises(ValueError, match="'a' must be <= 1"):
        assert_numeric(1.5, name="a", upper=1.0)
    # A ragged list makes np.asarray itself raise; the helper turns that into
    # the same "must be numeric" ValueError naming the argument.
    with pytest.raises(ValueError, match="'y' must be numeric: "):
        assert_numeric([[1.0, 2.0], [3.0]], name="y")


def test_wrap_kernel_refuses_a_kernel_without_rules():
    def not_a_kernel():
        pass

    with pytest.raises(KeyError, match="not_a_kernel has no entry"):
        _checks.wrap_kernel(not_a_kernel)


def test_assert_matrix():
    assert_matrix(np.ones((3, 2)), name="X")
    assert_matrix(np.ones(3), name="X")  # one column, as pybind11 accepts
    with pytest.raises(ValueError, match="'X' must be a 2-D"):
        assert_matrix(np.ones((2, 2, 2)), name="X")
    with pytest.raises(ValueError, match="'X' must be finite"):
        assert_matrix(np.array([[1.0, np.nan]]), name="X")


@pytest.mark.parametrize("w", [[0, 1, 1, 0], [True, False], np.array([0.0, 1.0])])
def test_assert_binary_accepts_0_1(w):
    assert_binary(w, name="w")


@pytest.mark.parametrize("w", [[1, 2, 1, 2], [-1, 1, -1, 1], [0, 1, np.nan], [0.5, 1]])
def test_assert_binary_rejects_other_codings(w):
    with pytest.raises(ValueError, match="'w' must contain only 0 and 1"):
        assert_binary(w, name="w")


def test_assert_integerish_count_choice_same_length():
    assert_integerish([1, 2, 3.0], name="g")
    with pytest.raises(ValueError, match="'g' must contain whole numbers"):
        assert_integerish([1, 2.5], name="g")
    assert_count(0, name="k")
    with pytest.raises(ValueError, match="'k' must be >= 1"):
        assert_count(0, positive=True, name="k")
    for bad in (True, [1, 2], 1.5):
        with pytest.raises(ValueError, match="'k'"):
            assert_count(bad, name="k")
    assert_choice("MM", ("M", "MM"), name="method")
    with pytest.raises(ValueError, match="'method' must be one of 'M', 'MM'"):
        assert_choice("mm", ("M", "MM"), name="method")
    assert_same_length(a=[1, 2], b=np.ones((2, 3)))
    with pytest.raises(ValueError, match="'a', 'b' must have the same length; got a = 2, b = 3"):
        assert_same_length(a=[1, 2], b=[1, 2, 3])
    with pytest.raises(ValueError, match=r"ncol\(X\) = 3"):
        assert_same_length(ncol__X=np.ones((2, 3)), b=[1, 2])


def test_set_checks_switch():
    assert edi_kernels.get_checks() is True
    assert edi_kernels.set_checks(False) is True
    assert edi_kernels.get_checks() is False
    assert edi_kernels.set_checks(True) is False
    with pytest.raises(ValueError, match="'enabled'"):
        edi_kernels.set_checks("no")


# ------------------------------------------------------------ 2. the table

KERNEL_NAMES = sorted(set(edi_kernels.__all__) - {"set_checks", "get_checks"})


def test_table_covers_exactly_the_exported_kernels():
    assert sorted(KERNELS) == KERNEL_NAMES
    assert sorted(n for n in dir(_core) if not n.startswith("_")) == KERNEL_NAMES


@pytest.mark.parametrize("name", KERNEL_NAMES)
def test_every_export_is_a_checking_wrapper(name):
    fn = getattr(edi_kernels, name)
    assert fn is not getattr(_core, name)
    assert fn.__wrapped__ is getattr(_core, name)
    assert fn.__name__ == name and fn.__doc__ == getattr(_core, name).__doc__
    assert pickle.loads(pickle.dumps(fn)) is fn


def _stub_params():
    """{name: [param, ...]} from _core.pyi (first overload for overloaded names)."""
    out = {}
    text = STUB.read_text()
    for m in re.finditer(r"^def (\w+)\((.*?)\) ->", text, re.S | re.M):
        params = re.findall(r"(?:^|,)\s*(\w+):", re.sub(r"\[[^\[\]]*\]", "", re.sub(r"\[[^\[\]]*\]", "", m.group(2))))
        out.setdefault(m.group(1), params)
    return out


@pytest.mark.parametrize("name", KERNEL_NAMES)
def test_table_params_match_the_stub(name):
    """params is a prefix of the stub's parameter list and holds every checked argument."""
    spec = KERNELS[name]
    stub = _stub_params()[name]
    assert list(spec.params) == stub[: len(spec.params)], (spec.params, stub)
    named = {r.arg for r in spec.rules}
    named |= {k[6:] if k.startswith("ncol__") else k for g in spec.same_length for k in g}
    assert named <= set(spec.params), named - set(spec.params)


@pytest.mark.skipif(not RCPP_EXPORTS.is_file(), reason="needs R/EDI/R/RcppExports.R (repository checkout)")
def test_r_twins_exist():
    exports = set(re.findall(r"^(\w+) <- function\(", RCPP_EXPORTS.read_text(), re.M))
    missing = {k: s.r_twin for k, s in KERNELS.items() if s.r_twin and s.r_twin not in exports}
    assert not missing
    # Only the fast_math utilities have no R export (they are inline C++ helpers in R/EDI/src).
    no_twin = {k for k, s in KERNELS.items() if s.r_twin is None}
    assert no_twin == {"fast_pchisq_upper", "fast_digamma", "fast_trigamma", "fast_lgamma", "fast_lbeta",
                       "fast_dnbinom_mu", "fast_qnorm", "fast_log_pnorm", "fast_log_dnorm", "fast_erfc",
                       "pnorm_fast", "dnorm_fast", "fast_atan", "fast_log1pexp"}


R_RULES = [(k, r) for k, s in sorted(KERNELS.items()) for r in s.rules if r.r_contract]


def _num_or_none(s):
    return float(s) if s not in ("", "NA") else None


@pytest.mark.skipif(not CONTRACTS.is_file(), reason="needs R/package_tests/checkmate_argument_contracts.csv")
@pytest.mark.parametrize("kernel,rule", R_RULES, ids=[f"{k}.{r.arg}" for k, r in R_RULES])
def test_rule_matches_r_checkmate_contract(kernel, rule):
    """The Python rule states the same constraint as R's checkmate assertion for that argument.

    The CSV holds R6 public-method contracts only (no *_cpp rows), so a rule is
    compared with the R class argument that feeds the same kernel argument.
    """
    cls, method, arg = rule.r_contract
    with CONTRACTS.open(newline="") as fh:
        rows = [r for r in csv.DictReader(fh)
                if r["class_name"] == cls and r["method_name"] == method and r["arg"] == arg]
    assert rows, f"no R contract row for {rule.r_contract}"
    row = rows[0]
    expected_kind = {"choice": "assertChoice", "count": "assertCount", "numeric": "assertNumeric"}[rule.kind]
    assert row["assertion"] == expected_kind
    if rule.kind == "choice":
        assert set(rule.choices) == set(row["choices"].split(";"))
    elif rule.kind == "count":
        assert rule.positive == (row["positive"] == "TRUE")
    else:
        for py, r in ((rule.lower, _num_or_none(row["lower"])), (rule.upper, _num_or_none(row["upper"]))):
            assert (py is None) == (r is None) and (py is None or math.isclose(py, r, rel_tol=1e-12))
        if row["len"]:  # R fixes the length; Python must too (a scalar kernel argument is n = 1 anyway)
            assert rule.n == int(row["len"])


def test_r_contract_coverage_is_what_we_expect():
    """Arguments R checks with checkmate before calling the kernel; the rest have no R twin rule
    (R builds them internally from the design, e.g. w, y, X, family, requested_stat)."""
    assert {(k, r.arg) for k, r in R_RULES} == {
        ("fast_ridit_analysis", "reference"), ("fast_robust_regression", "method"),
        ("fast_robust_regression", "maxit"), ("mn_ci", "alpha"), ("mn_ci", "pval_epsilon"),
        ("mn_pvalue", "delta"), ("newcombe_independent_ci", "alpha")}


# ------------------------------------------------- 3. generic, table-driven

N = 6


def _valid_value(rule, ncols=2):
    if rule.kind == "matrix":
        return np.ones((N, ncols))
    if rule.kind == "binary":
        return np.array([0, 1] * (N // 2))
    if rule.kind == "integerish":
        return np.ones(N)
    if rule.kind == "count":
        return 1
    if rule.kind == "choice":
        return rule.choices[0]
    if rule.n == 1:
        lo, hi = rule.lower, rule.upper
        return 0.5 if (lo is None or lo <= 0.5) and (hi is None or hi >= 0.5) else lo
    return np.full(N, 0.5)


def _valid_kwargs(spec):
    kw = {r.arg: _valid_value(r) for r in spec.rules}
    for group in spec.same_length:  # e.g. coef_hat must have ncol(X_fit) entries
        for key in group:
            if key.startswith("ncol__"):
                others = [k for k in group if k != key]
                for k in others:
                    kw[k] = np.ones(kw[key[6:]].shape[1])
    return kw


@pytest.mark.parametrize("name", KERNEL_NAMES)
def test_synthetic_valid_input_passes(name):
    check_call(name, (), _valid_kwargs(KERNELS[name]))


NAN_CASES = [(k, r) for k, s in sorted(KERNELS.items()) for r in s.rules
             if r.kind in ("numeric", "matrix", "integerish") and r.finite]


@pytest.mark.parametrize("name,rule", NAN_CASES, ids=[f"{k}.{r.arg}" for k, r in NAN_CASES])
def test_nan_rejected_and_skippable(name, rule):
    kw = _valid_kwargs(KERNELS[name])
    bad = np.array(kw[rule.arg], dtype=float)
    bad.flat[0] = np.nan
    kw[rule.arg] = bad if bad.ndim else float(bad)
    with pytest.raises(ValueError, match=rf"^{name}\(\): argument '{rule.arg}' must be finite"):
        check_call(name, (), kw)
    edi_kernels.set_checks(False)
    check_call(name, (), kw)  # optional check: skipped when checks are off


LENGTH_CASES = [(k, g) for k, s in sorted(KERNELS.items()) for g in s.same_length if len(g) > 1]


@pytest.mark.parametrize("checks_on", [True, False])
@pytest.mark.parametrize("name,group", LENGTH_CASES, ids=[f"{k}:{'/'.join(g)}" for k, g in LENGTH_CASES])
def test_wrong_length_always_rejected(name, group, checks_on):
    edi_kernels.set_checks(checks_on)
    spec = KERNELS[name]
    kw = _valid_kwargs(spec)
    for key in group:
        if key.startswith("ncol__"):
            continue
        short = kw.get(key, np.ones(N))
        kw[key] = short[:-1] if np.ndim(short) else np.ones(N - 1)
        break
    with pytest.raises(ValueError, match="must have the same length"):
        check_call(name, (), kw)


BINARY_CASES = [(k, r.arg) for k, s in sorted(KERNELS.items()) for r in s.rules if r.kind == "binary"]


@pytest.mark.parametrize("checks_on", [True, False])
@pytest.mark.parametrize("coding", [(1, 2), (-1, 1)], ids=["1/2", "-1/1"])
@pytest.mark.parametrize("name,arg", BINARY_CASES, ids=[f"{k}.{a}" for k, a in BINARY_CASES])
def test_non_binary_always_rejected(name, arg, coding, checks_on):
    edi_kernels.set_checks(checks_on)
    kw = _valid_kwargs(KERNELS[name])
    kw[arg] = np.array([coding[0], coding[1]] * (N // 2))
    with pytest.raises(ValueError, match=rf"argument '{arg}' must contain only 0 and 1"):
        check_call(name, (), kw)


CHOICE_CASES = [(k, r.arg) for k, s in sorted(KERNELS.items()) for r in s.rules if r.kind == "choice"]


@pytest.mark.parametrize("name,arg", CHOICE_CASES, ids=[f"{k}.{a}" for k, a in CHOICE_CASES])
def test_bad_choice_rejected(name, arg):
    kw = _valid_kwargs(KERNELS[name])
    kw[arg] = "not_a_choice"
    with pytest.raises(ValueError, match=rf"argument '{arg}' must be one of"):
        check_call(name, (), kw)


def test_positional_arguments_are_mapped_by_name():
    with pytest.raises(ValueError, match="argument 'w'"):
        check_call("wilcox_hl_point_estimate", (np.ones(4), [1, 2, 1, 2]), {})
    check_call("wilcox_hl_point_estimate", (np.ones(4), [1, 0, 1, 0]), {})
    check_call("fast_ols", (np.ones((3, 1)), np.ones(3)), {"fixed_idx": None})  # None = not given


# --------------------------------------- 4. end to end: TODO-86 and friends

Y86 = np.array([1, 2, 3.5, 4, 2.2, 3.1])
DEAD86 = np.ones(6, dtype=np.int32)
YORD86 = np.array([1, 2, 3, 3, 2, 1], dtype=np.int32)


def _cpoisson_call(w):
    from test_fast_cpoisson_combined import _synthetic_data
    yT_v, n_k_v, X_diff_v, y_r, w_r, X_r = _synthetic_data()
    w_r = np.resize(np.asarray(w, dtype=float), len(w_r))
    return edi_kernels.fast_cpoisson_combined(yT_v, n_k_v, X_diff_v, y_r, w_r, X_r)


# One call per treatment-vector kernel; w is the treatment vector to use.
TREATMENT_CALLS = {
    "wilcox_hl_point_estimate": lambda w: edi_kernels.wilcox_hl_point_estimate(Y86, np.asarray(w, np.int32)),
    "get_survival_stat_diff": lambda w: edi_kernels.get_survival_stat_diff(Y86, DEAD86, np.asarray(w, np.int32)),
    "fast_ridit_analysis": lambda w: edi_kernels.fast_ridit_analysis(np.asarray(w, np.int32), YORD86),
    "fast_logrank_stats": lambda w: edi_kernels.fast_logrank_stats(Y86, list(DEAD86), list(w)),
    "fast_gehan_wilcox_stats": lambda w: edi_kernels.fast_gehan_wilcox_stats(Y86, list(DEAD86), list(w)),
    "fast_cpoisson_combined": _cpoisson_call,
}


def test_treatment_call_list_covers_every_treatment_kernel():
    assert set(TREATMENT_CALLS) == {k for k, a in BINARY_CASES if a in ("w", "w_r")}


@pytest.mark.parametrize("checks_on", [True, False])
@pytest.mark.parametrize("w", [[1, 2, 1, 2, 1, 2], [-1, 1, -1, 1, -1, 1]], ids=["1/2", "-1/1"])
@pytest.mark.parametrize("name", sorted(TREATMENT_CALLS))
def test_todo86_non_01_treatment_raises(name, w, checks_on):
    edi_kernels.set_checks(checks_on)
    with pytest.raises(ValueError, match=r"argument 'w(_r)?' must contain only 0 and 1"):
        TREATMENT_CALLS[name](w)


@pytest.mark.parametrize("name", sorted(TREATMENT_CALLS))
def test_0_1_treatment_still_runs(name):
    TREATMENT_CALLS[name]([0, 1, 0, 1, 0, 1])


def test_todo86_logrank_sign_is_right_after_recoding():
    """The 1/2-coded call used to return +0.511; recoded to 0/1 it is -0.511 (now the only way in)."""
    w12 = np.array([1, 2, 1, 2, 1, 2])
    assert _core.fast_logrank_stats(Y86, list(DEAD86), list(w12))["beta_hat"] > 0  # the old silent flip
    res = edi_kernels.fast_logrank_stats(Y86, list(DEAD86), list(w12 - 1))
    assert res["beta_hat"] == pytest.approx(-0.5111111111111112, rel=1e-12)


@pytest.mark.parametrize("checks_on", [True, False])
def test_wrong_length_raises_through_real_kernels(checks_on):
    edi_kernels.set_checks(checks_on)
    with pytest.raises(ValueError, match="'time', 'dead', 'w' must have the same length"):
        edi_kernels.fast_logrank_stats(Y86, list(DEAD86), [0, 1, 0, 1, 0])
    with pytest.raises(ValueError, match="'X', 'y' must have the same length"):
        edi_kernels.fast_ols(np.ones((5, 2)), np.ones(4))
    with pytest.raises(ValueError, match="'a', 'b' must have the same length"):
        edi_kernels.fast_lbeta(np.ones(3), np.ones(2))


def test_nan_raises_through_real_kernels_unless_checks_off():
    y = Y86.copy()
    y[2] = np.nan
    with pytest.raises(ValueError, match="get_survival_stat_diff\\(\\): argument 'y' must be finite"):
        edi_kernels.get_survival_stat_diff(y, DEAD86, np.array([0, 1] * 3, np.int32))
    X = np.column_stack([np.ones(6), [0, 1] * 3])
    with pytest.raises(ValueError, match="fast_ols\\(\\): argument 'y' must be finite"):
        edi_kernels.fast_ols(X, y)
    edi_kernels.set_checks(False)
    edi_kernels.fast_ols(X, y)  # reaches the kernel; its result is the caller's responsibility


def test_documented_nan_inputs_still_accepted():
    """wilcox_hl_point_estimate drops non-finite y by design; the math utilities propagate NaN."""
    y = Y86.copy()
    y[0] = np.nan
    assert np.isfinite(edi_kernels.wilcox_hl_point_estimate(y, np.array([0, 1] * 3, np.int32)))
    assert np.isnan(edi_kernels.fast_digamma(np.array([np.nan]))[0])


def test_bad_choice_raises_through_real_kernel():
    with pytest.raises(ValueError, match="'requested_stat' must be one of 'median', 'restricted_mean'"):
        edi_kernels.get_survival_stat_diff(Y86, DEAD86, np.array([0, 1] * 3, np.int32), "mean")
