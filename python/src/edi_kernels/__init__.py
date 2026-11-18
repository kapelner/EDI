"""edi_kernels: Python bindings for the C++ model-fitting kernels of EDI.

EDI (Experimental Design and Inference) is an R and Python software project
for fixed and sequential randomized experimental designs with inference
(exact, asymptotic, and randomization-based) matched to each design and
response type. This package exposes the same C++ solvers used by the EDI R
package (GLM, GLMM, survival, count, ordinal, and proportion models) through
pybind11, with no R or Rcpp dependency. Project home:
https://github.com/kapelner/EDI

Every kernel is a thin Python wrapper around the compiled function of the same
name in ``edi_kernels._core``: it checks its inputs (finite numeric data, 0/1
treatment and event vectors, matching lengths, valid choices; see
``edi_kernels._checks``) and raises ``ValueError`` naming the bad argument, then
calls the kernel unchanged. ``set_checks(False)`` skips the optional checks for
speed; the 0/1 and matching-length checks always run (v1.0.6-TODO-101).
"""

from . import _core
from ._checks import get_checks, set_checks, wrap_kernel as _wrap

fast_pchisq_upper = _wrap(_core.fast_pchisq_upper)
# continuous
fast_ols = _wrap(_core.fast_ols)
fast_robust_regression = _wrap(_core.fast_robust_regression)
wilcox_hl_point_estimate = _wrap(_core.wilcox_hl_point_estimate)
ols_hc2_post_fit = _wrap(_core.ols_hc2_post_fit)
# binary
fast_logistic_regression = _wrap(_core.fast_logistic_regression)
fast_probit_regression = _wrap(_core.fast_probit_regression)
fast_log_binomial_regression = _wrap(_core.fast_log_binomial_regression)
fast_log_binomial_regression_with_var = _wrap(_core.fast_log_binomial_regression_with_var)
fast_identity_binomial_regression = _wrap(_core.fast_identity_binomial_regression)
fast_identity_binomial_regression_with_var = _wrap(_core.fast_identity_binomial_regression_with_var)
# count
fast_poisson_regression = _wrap(_core.fast_poisson_regression)
fast_neg_bin = _wrap(_core.fast_neg_bin)
fast_zinb = _wrap(_core.fast_zinb)
fast_zinb_with_var = _wrap(_core.fast_zinb_with_var)
fast_zero_augmented_poisson = _wrap(_core.fast_zero_augmented_poisson)
fast_zero_augmented_poisson_with_var = _wrap(_core.fast_zero_augmented_poisson_with_var)
fast_hurdle_negbin = _wrap(_core.fast_hurdle_negbin)
fast_truncated_negbin_count = _wrap(_core.fast_truncated_negbin_count)
fast_cpoisson_combined = _wrap(_core.fast_cpoisson_combined)
# proportion
fast_beta_regression = _wrap(_core.fast_beta_regression)
fast_zero_one_inflated_beta = _wrap(_core.fast_zero_one_inflated_beta)
# ordinal
fast_adjacent_category_logit = _wrap(_core.fast_adjacent_category_logit)
fast_continuation_ratio_regression = _wrap(_core.fast_continuation_ratio_regression)
fast_ordinal_regression = _wrap(_core.fast_ordinal_regression)
fast_ordinal_probit_regression = _wrap(_core.fast_ordinal_probit_regression)
fast_ordinal_cauchit_regression = _wrap(_core.fast_ordinal_cauchit_regression)
fast_ordinal_cloglog_regression = _wrap(_core.fast_ordinal_cloglog_regression)
fast_ordinal_clmm = _wrap(_core.fast_ordinal_clmm)
fast_ordinal_glmm = _wrap(_core.fast_ordinal_glmm)
fast_stereotype_logit = _wrap(_core.fast_stereotype_logit)
fast_ridit_analysis = _wrap(_core.fast_ridit_analysis)
# incidence / GEE / nonparametric
gee_pairs_singletons = _wrap(_core.gee_pairs_singletons)
mn_ci = _wrap(_core.mn_ci)
mn_pvalue = _wrap(_core.mn_pvalue)
newcombe_independent_ci = _wrap(_core.newcombe_independent_ci)
# survival
fast_coxph_regression = _wrap(_core.fast_coxph_regression)
fast_stratified_coxph_regression = _wrap(_core.fast_stratified_coxph_regression)
fast_weibull_regression_general = _wrap(_core.fast_weibull_regression_general)
fast_weibull_frailty = _wrap(_core.fast_weibull_frailty)
fast_clayton_weibull_aft_optim = _wrap(_core.fast_clayton_weibull_aft_optim)
fast_dep_cens_transform_optim = _wrap(_core.fast_dep_cens_transform_optim)
fast_gehan_wilcox_stats = _wrap(_core.fast_gehan_wilcox_stats)
fast_logrank_stats = _wrap(_core.fast_logrank_stats)
get_survival_stat_diff = _wrap(_core.get_survival_stat_diff)
# GLMM
fast_poisson_glmm = _wrap(_core.fast_poisson_glmm)
fast_gaussian_lmm = _wrap(_core.fast_gaussian_lmm)
fast_logistic_glmm = _wrap(_core.fast_logistic_glmm)
fast_hurdle_poisson_glmm = _wrap(_core.fast_hurdle_poisson_glmm)
fast_clogit_plus_glmm = _wrap(_core.fast_clogit_plus_glmm)
# fast_math (utility scalar kernels) -- fast_pchisq_upper above was the
# only one of these 14 actually re-exported here; the other 13 were
# compiled into _core same as always but never surfaced through the
# public edi_kernels namespace, an oversight caught 2026-08-12 by
# trying to run python/README_PYPI.md's own new Utilities example
# against the real published 1.0.0.post1 package.
fast_digamma = _wrap(_core.fast_digamma)
fast_trigamma = _wrap(_core.fast_trigamma)
fast_lgamma = _wrap(_core.fast_lgamma)
fast_lbeta = _wrap(_core.fast_lbeta)
fast_dnbinom_mu = _wrap(_core.fast_dnbinom_mu)
fast_qnorm = _wrap(_core.fast_qnorm)
fast_log_pnorm = _wrap(_core.fast_log_pnorm)
fast_log_dnorm = _wrap(_core.fast_log_dnorm)
fast_erfc = _wrap(_core.fast_erfc)
pnorm_fast = _wrap(_core.pnorm_fast)
dnorm_fast = _wrap(_core.dnorm_fast)
fast_atan = _wrap(_core.fast_atan)
fast_log1pexp = _wrap(_core.fast_log1pexp)

__all__ = [
    "fast_pchisq_upper",
    "fast_ols",
    "fast_robust_regression",
    "wilcox_hl_point_estimate",
    "ols_hc2_post_fit",
    "fast_logistic_regression",
    "fast_probit_regression",
    "fast_log_binomial_regression",
    "fast_log_binomial_regression_with_var",
    "fast_identity_binomial_regression",
    "fast_identity_binomial_regression_with_var",
    "fast_poisson_regression",
    "fast_neg_bin",
    "fast_zinb",
    "fast_zinb_with_var",
    "fast_zero_augmented_poisson",
    "fast_zero_augmented_poisson_with_var",
    "fast_hurdle_negbin",
    "fast_truncated_negbin_count",
    "fast_cpoisson_combined",
    "fast_beta_regression",
    "fast_zero_one_inflated_beta",
    "fast_adjacent_category_logit",
    "fast_continuation_ratio_regression",
    "fast_ordinal_regression",
    "fast_ordinal_probit_regression",
    "fast_ordinal_cauchit_regression",
    "fast_ordinal_cloglog_regression",
    "fast_ordinal_clmm",
    "fast_ordinal_glmm",
    "fast_stereotype_logit",
    "fast_ridit_analysis",
    "gee_pairs_singletons",
    "mn_ci",
    "mn_pvalue",
    "newcombe_independent_ci",
    "fast_coxph_regression",
    "fast_stratified_coxph_regression",
    "fast_weibull_regression_general",
    "fast_weibull_frailty",
    "fast_clayton_weibull_aft_optim",
    "fast_dep_cens_transform_optim",
    "fast_gehan_wilcox_stats",
    "fast_logrank_stats",
    "get_survival_stat_diff",
    "fast_poisson_glmm",
    "fast_gaussian_lmm",
    "fast_logistic_glmm",
    "fast_hurdle_poisson_glmm",
    "fast_clogit_plus_glmm",
    "fast_digamma",
    "fast_trigamma",
    "fast_lgamma",
    "fast_lbeta",
    "fast_dnbinom_mu",
    "fast_qnorm",
    "fast_log_pnorm",
    "fast_log_dnorm",
    "fast_erfc",
    "pnorm_fast",
    "dnorm_fast",
    "fast_atan",
    "fast_log1pexp",
    "set_checks",
    "get_checks",
]
