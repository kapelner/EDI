"""The GLMM kernels take X WITH an intercept column (v1.0.6-TODO-85).

The fast_gaussian_lmm docstring said X has "no intercept column", but the C++
model is X beta + u_i with beta_0 the intercept, and the R class
InferenceContinKKGLMM passes columns (intercept, w, covariates). The same wrong
claim was on fast_poisson_glmm, fast_logistic_glmm and fast_hurdle_poisson_glmm
(their R callers, InferenceCountKKGLMM and InferenceCountKKHurdlePoissonOneLik,
also pass an intercept). The ordinal kernels (thresholds play the intercept's
role) and the Cox kernels (partial likelihood) really do take X without one;
their docstrings were checked and left as they are.

The fixture below is the R class's own estimate on the same data:

    d = <the data built by _matched_pairs_data(), written to CSV>
    des = DesignFixedBinaryMatch$new(response_type = "continuous", n = 40,
        m = d$m, design_formula = ~ x1, verbose = FALSE)
    des$add_all_subjects_to_experiment(data.frame(x1 = d$x1))
    des$assign_w_to_all_subjects(d$w); des$add_all_subject_responses(d$y)
    InferenceContinKKGLMM$new(des, verbose = FALSE)$compute_estimate()

computed 2026-11-19 with the installed EDI 1.0.4.
"""
import re
from pathlib import Path

import numpy as np
import pytest

from edi_kernels import fast_gaussian_lmm

STUB = Path(__file__).resolve().parents[1] / "src" / "edi_kernels" / "_core.pyi"

R_CLASS_ESTIMATE = 1.03901849258417  # InferenceContinKKGLMM, EDI 1.0.4
GLMM_WITH_INTERCEPT = ("fast_gaussian_lmm", "fast_poisson_glmm", "fast_logistic_glmm", "fast_hurdle_poisson_glmm")
NO_INTERCEPT = ("fast_continuation_ratio_regression", "fast_coxph_regression", "fast_stratified_coxph_regression",
                "fast_ordinal_clmm", "fast_ordinal_glmm")


def _matched_pairs_data():
    rng = np.random.default_rng(85)
    n = 40
    x1 = rng.normal(size=n)
    w = np.concatenate([rng.permutation([0.0, 1.0]) for _ in range(n // 2)])
    m = np.repeat(np.arange(1, n // 2 + 1), 2).astype(np.int32)
    g = np.repeat(rng.normal(scale=0.3, size=n // 2), 2)
    y = 1.5 + 0.4 * w - 0.3 * x1 + g + rng.normal(size=n)
    return y, w, m, x1


def test_documented_layout_reproduces_the_r_class_estimate():
    y, w, m, x1 = _matched_pairs_data()
    X = np.asfortranarray(np.column_stack([np.ones_like(w), w, x1]))
    res = fast_gaussian_lmm(X, y, m)
    assert res["b"][1] == pytest.approx(R_CLASS_ESTIMATE, rel=1e-6)


def test_dropping_the_intercept_fits_a_different_model():
    y, w, m, x1 = _matched_pairs_data()
    X = np.asfortranarray(np.column_stack([w, x1]))
    res = fast_gaussian_lmm(X, y, m)
    assert abs(res["b"][0] - R_CLASS_ESTIMATE) > 0.1


def _stub_doc_x(name):
    text = STUB.read_text()
    body = re.search(rf'^def {name}\(.*?"""(.*?)"""', text, re.S | re.M).group(1)
    return re.search(r"^    X : ndarray\n(.*?)^    \w+ :", body, re.S | re.M).group(1)


@pytest.mark.parametrize("name", GLMM_WITH_INTERCEPT)
def test_glmm_stub_says_x_includes_an_intercept(name):
    doc = _stub_doc_x(name)
    assert "including an intercept column" in doc
    assert "no intercept" not in doc


@pytest.mark.parametrize("name", NO_INTERCEPT)
def test_ordinal_and_cox_stubs_still_say_no_intercept(name):
    assert "no intercept" in _stub_doc_x(name)
