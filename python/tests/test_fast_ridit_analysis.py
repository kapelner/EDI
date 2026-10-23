"""Parity test for edi_kernels.fast_ridit_analysis against an R-generated
fixture.

Most tests do not re-verify the statistical correctness of Ridit analysis
itself -- that's the same fast_ridit_scores_from_ref_indices object code
the R package's own test suite exercises via
EDI:::fast_ridit_analysis_cpp (both call the identical algorithm; only
RiditScoreData's internal storage changed from Rcpp::NumericVector to
std::vector<double> so a separate Python binding translation unit could
call it, and fast_ridit_analysis_result was added as a portable sibling of
fast_ridit_analysis_cpp avoiding its SEXP/Rcpp::List boundary). What this
test covers: the pybind11 binding layer itself and the EDI_CORE_ONLY
compiled path.

The missing-interior-level regression below is deliberately duplicated at
the binding boundary because that bug lived in this shared object code and
changed Python results too.

The expected values below were computed once via:
    EDI:::fast_ridit_analysis_cpp(w, y, "control")
in R on a synthetic n=45 dataset generated with set.seed(654).
"""
import math

import numpy as np
import pytest

from edi_kernels import fast_ridit_analysis

ATOL = 1e-9
RTOL = 1e-9

Y = np.array([
    2, 4, 3, 2, 1, 2, 3, 2, 3, 4, 4, 3, 1, 2, 1, 4, 4, 1, 3, 1, 3, 1, 2, 4,
    2, 1, 2, 2, 2, 2, 3, 3, 3, 3, 3, 4, 4, 2, 2, 2, 3, 4, 3, 1, 4,
], dtype=np.int32)
W = np.array([1, 0] * 22 + [1], dtype=np.int32)

# R reference, EDI 1.0.0, computed 2026-08-05 via:
#   EDI:::fast_ridit_analysis_cpp(w, y, "control")
R_MEAN_RIDIT_T = 0.558300395256917
R_MEAN_RIDIT_C = 0.5
R_ESTIMATE = 0.0583003952569171
# TODO-106 / cpp patch 06: `se` is the DeLong (1988) standard error, not sd(arm scores)/sqrt(n).
# Computed 2026-10-22 in R (EDI working tree) with
#   EDI:::ridit_delong_se(as.integer(Y), as.integer(W), reference)
# on this fixture (Y, W as defined above). Pre-patch value was 0.0487241695783548
# (sd of the treated scores / sqrt(n_T)); it is no longer asserted.
R_SE = 0.086836566958365            # reference = "control" (and "treatment": identical)
R_SE_TREATMENT_REF = 0.086836566958365
R_SE_POOLED_REF = 0.0424534327352006  # = R_SE * n_C / N  (n_C = 22, N = 45)
R_LEVELS = [1, 2, 3, 4]


def test_matches_r_fixture():
    res = fast_ridit_analysis(W, Y, "control")
    assert res["mean_ridit_t"] == pytest.approx(R_MEAN_RIDIT_T, abs=ATOL, rel=RTOL)
    assert res["mean_ridit_c"] == pytest.approx(R_MEAN_RIDIT_C, abs=ATOL, rel=RTOL)
    assert res["estimate"] == pytest.approx(R_ESTIMATE, abs=ATOL, rel=RTOL)
    assert res["se"] == pytest.approx(R_SE, abs=ATOL, rel=RTOL)
    assert res["levels"] == R_LEVELS


def test_pooled_reference_se_is_scaled_delong():
    res = fast_ridit_analysis(W, Y, "pooled")
    assert res["se"] == pytest.approx(R_SE_POOLED_REF, abs=ATOL, rel=RTOL)
    n_c = int(np.sum(W == 0))
    assert res["se"] == pytest.approx(R_SE * n_c / W.size, abs=ATOL, rel=RTOL)


def test_default_reference_is_control():
    default = fast_ridit_analysis(W, Y)
    explicit = fast_ridit_analysis(W, Y, "control")
    assert default["estimate"] == pytest.approx(explicit["estimate"], abs=ATOL, rel=RTOL)


def test_reference_group_mean_ridit_is_half_by_construction():
    # A group's mean ridit relative to its OWN empirical distribution is
    # always exactly 0.5 -- true for whichever arm is chosen as reference.
    res_control = fast_ridit_analysis(W, Y, "control")
    assert res_control["mean_ridit_c"] == pytest.approx(0.5, abs=ATOL)

    res_treatment = fast_ridit_analysis(W, Y, "treatment")
    assert res_treatment["mean_ridit_t"] == pytest.approx(0.5, abs=ATOL)


def test_estimate_orientation_depends_on_reference_group_without_degenerating():
    res = fast_ridit_analysis(W, Y, "control")
    assert res["estimate"] == pytest.approx(res["mean_ridit_t"] - 0.5, abs=ATOL, rel=RTOL)

    res_treatment = fast_ridit_analysis(W, Y, "treatment")
    assert res_treatment["estimate"] == pytest.approx(0.5 - res_treatment["mean_ridit_c"], abs=ATOL, rel=RTOL)
    assert res_treatment["estimate"] == pytest.approx(res["estimate"], abs=ATOL, rel=RTOL)
    # TODO-106 / cpp patch 06: DeLong SE (same for control and treatment references);
    # constant computed from EDI:::ridit_delong_se(Y, W, "treatment") in R, see R_SE_TREATMENT_REF.
    assert res_treatment["se"] == pytest.approx(R_SE_TREATMENT_REF, abs=ATOL, rel=RTOL)
    assert res_treatment["se"] == pytest.approx(res["se"], abs=ATOL, rel=RTOL)
    assert abs(res_treatment["estimate"]) > ATOL


def test_missing_interior_reference_level_uses_mass_below():
    # The control arm has mass 1/4 at level 1 and 3/4 at level 3. Therefore
    # treated level 2 must score 1/4, the control mass strictly below it.
    w = np.array([0, 0, 0, 0, 1, 1, 1, 1], dtype=np.int32)
    y = np.array([1, 3, 3, 3, 2, 2, 3, 4], dtype=np.int32)
    expected_scores = np.array([0.125, 0.625, 0.625, 0.625, 0.25, 0.25, 0.625, 1.0])
    treated = y[w == 1][:, None]
    control = y[w == 0]
    pairwise = (treated > control).astype(float)
    pairwise += 0.5 * (treated == control)
    expected_estimate = pairwise.mean() - 0.5

    res = fast_ridit_analysis(w, y, "control")
    assert np.asarray(res["scores"]) == pytest.approx(expected_scores, abs=ATOL, rel=RTOL)
    assert res["estimate"] == pytest.approx(expected_estimate, abs=ATOL, rel=RTOL)


def test_empty_reference_group_returns_nan_fields():
    # Unlike R's fast_ridit_analysis_cpp (which returns an empty list when
    # the reference group is empty), this binding always returns a
    # fully-populated dict -- NaN scalars and empty list fields -- matching
    # the NaN-populated-dict convention this session's other bindings use
    # for degenerate inputs (e.g. mn_ci at n=0), rather than an empty dict.
    w_all_treat = np.ones_like(W)
    res = fast_ridit_analysis(w_all_treat, Y, "control")
    assert math.isnan(res["mean_ridit_t"])
    assert math.isnan(res["mean_ridit_c"])
    assert math.isnan(res["estimate"])
    assert math.isnan(res["se"])
    assert res["scores"] == []
    assert res["levels"] == []
    assert res["ref_p"] == []
