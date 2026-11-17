"""Python binding defaults must match their R twins' defaults.

v1.0.6-TODO-72 (GitHub issue #33): `fast_coxph_regression` and
`fast_stratified_coxph_regression` defaulted to `maxit = 20` in
python/cpp/bindings_survival.cpp after R raised its Cox kernels to
`maxit = 100` in v1.0.5, so Python could stop early on fits R finishes.

This is a pure-text test: it parses the pybind11 sources, the type stub and
R/EDI/R/RcppExports.R, and does not import the compiled `edi_kernels`
extension. For every `m.def("name", ...)` whose R twin `name_cpp` exists in
RcppExports.R, each `py::arg("x") = d` must equal the R default of the
same-named argument (arguments R does not default, or R does not have, are
not compared). This mirrors the mechanical check of the rpy-parity audit
(.github/scripts/audits/rpy_parity.py) so a mismatch fails here before the
monthly audit finds it.
"""
import re
from pathlib import Path

import pytest

PY_DIR = Path(__file__).resolve().parents[1]
REPO = PY_DIR.parent
BIND_DIR = PY_DIR / "cpp"
STUB = PY_DIR / "src" / "edi_kernels" / "_core.pyi"
RCPP_EXPORTS = REPO / "R" / "EDI" / "R" / "RcppExports.R"

PYARG = re.compile(r'py::arg\("(\w+)"\)(?:\s*=\s*(py::none\(\)|"(?:[^"\\]|\\.)*"|[^,)\s]+))?')
MDEF = re.compile(r'\bm\.def\(\s*"(\w+)"')
RFUN = re.compile(r"^(\w+) <- function\((.*)\) \{$", re.M)

pytestmark = pytest.mark.skipif(
    not (BIND_DIR.is_dir() and RCPP_EXPORTS.is_file()),
    reason="needs the repository checkout (python/cpp and R/EDI/R/RcppExports.R)",
)


def _split_top(s):
    """Split on commas outside (), [], {} and string literals."""
    out, depth, cur, quote = [], 0, [], None
    for ch in s:
        if quote:
            cur.append(ch)
            if ch == quote:
                quote = None
            continue
        if ch in "\"'":
            quote = ch
        elif ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        elif ch == "," and depth == 0:
            out.append("".join(cur).strip())
            cur = []
            continue
        cur.append(ch)
    if "".join(cur).strip():
        out.append("".join(cur).strip())
    return out


def _norm(v):
    """Map a C++ or R default literal to a comparable Python value (None = not comparable)."""
    v = v.strip()
    if v in ("py::none()", "NULL"):
        return ("none",)
    if v in ("true", "TRUE"):
        return True
    if v in ("false", "FALSE"):
        return False
    if len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'":
        return v[1:-1]
    num = re.fullmatch(r"(-?[0-9.]+(?:[eE][-+]?[0-9]+)?)[LlFf]?", v)
    if num:
        return float(num.group(1))
    return None


def _python_bindings():
    """{name: [(arg, default-or-None), ...]} for every m.def in python/cpp/bindings_*.cpp."""
    out = {}
    for path in sorted(BIND_DIR.glob("bindings_*.cpp")):
        text = path.read_text(encoding="utf-8")
        starts = [(m.start(), m.group(1)) for m in MDEF.finditer(text)]
        for i, (pos, name) in enumerate(starts):
            end = starts[i + 1][0] if i + 1 < len(starts) else len(text)
            block = text[pos:end]
            out.setdefault(name, []).extend(PYARG.findall(block))
    return out


def _r_exports():
    """{name: {arg: default}} for every function in RcppExports.R (defaulted args only)."""
    out = {}
    for m in RFUN.finditer(RCPP_EXPORTS.read_text(encoding="utf-8")):
        params = {}
        for p in _split_top(m.group(2)):
            if "=" in p:
                k, d = p.split("=", 1)
                params[k.strip()] = d.strip()
        out[m.group(1)] = params
    return out


def _mismatches():
    r = _r_exports()
    bad = []
    for name, args in _python_bindings().items():
        twin = r.get(name + "_cpp")
        if twin is None:
            continue
        for arg, d in args:
            if not d or arg not in twin:
                continue
            pv, rv = _norm(d), _norm(twin[arg])
            if pv is None or rv is None or pv == rv:
                continue
            bad.append(f"{name}({arg} = {d}) vs {name}_cpp({arg} = {twin[arg]})")
    return bad


def test_every_binding_default_matches_its_r_twin():
    assert _mismatches() == []


def test_parser_sees_the_bindings_and_twins():
    # Guard against the test passing vacuously because a parser stopped matching.
    py, r = _python_bindings(), _r_exports()
    paired = [n for n in py if n + "_cpp" in r]
    assert len(paired) >= 30, paired
    assert r["fast_coxph_regression_cpp"]["maxit"] == "100L"


@pytest.mark.parametrize("name", ["fast_coxph_regression", "fast_stratified_coxph_regression"])
def test_cox_maxit_default_is_100_in_binding_stub_and_r(name):
    args = dict(_python_bindings()[name])
    assert args["maxit"] == "100"
    assert _r_exports()[name + "_cpp"]["maxit"] == "100L"

    stub = STUB.read_text(encoding="utf-8")
    sig = re.search(r"^def " + name + r"\((.*)\) -> ", stub, re.M)
    assert sig is not None
    assert re.search(r"\bmaxit: [^=]+= 100,", sig.group(1))
    # The numpydoc block of the stub states the same default.
    doc = stub[sig.end():].split("\ndef ", 1)[0]
    assert "maxit : int, default 100" in doc
