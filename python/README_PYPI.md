# edi_kernels

Python bindings for EDI's C++ model-fitting kernels, via pybind11. **The point
of this package is speed:** the same C++ solvers used by the `EDI` R package,
called directly from Python with no R/Rcpp dependency, running one to three
orders of magnitude faster than the pure-Python canonical fit for the same
model.

**Source, issue tracker, and full documentation:**
[github.com/kapelner/EDI](https://github.com/kapelner/EDI)
— this package's own subdirectory is
[github.com/kapelner/EDI/tree/main/python](https://github.com/kapelner/EDI/tree/main/python).
This repo hosts two related packages: the `EDI` R package (not yet on CRAN)
and this Python package, sharing one C++ kernel implementation.

This package has **no R or Rcpp dependency**. It compiles the same
`R/EDI/src/*.cpp` model-fitting kernels the R package uses, built under an
`EDI_CORE_ONLY` preprocessor guard that swaps out `RcppEigen`/`Rmath` for a
vanilla `Eigen` + `LBFGSpp`, both fetched directly from their own upstream
repositories. Nothing under `python/` is a copy of a `R/EDI/src/*.cpp` or
`*.h` file — the compiled extension `#include`s them directly from the R
package's own source tree.

See the full design spec
([`python_bindings_package_spec.md`](https://github.com/kapelner/EDI/blob/main/R/package_metadata/finished_features/python_bindings_package_spec.md))
for kernel-by-kernel scope and baseline-benchmarking methodology.

## Install

```bash
pip install edi_kernels
```

## Speed gains

Point-estimate timings (median of 30 cold runs) for every bound kernel that
has a canonical Python baseline to compare against, grouped by response type
and sorted by speedup, descending, within each group. Every row here is
significant at p < 0.001 (Welch's t-test, EDI vs. canonical replicate
distributions). Kernels with **no** Python canonical baseline to compare
against are omitted from this table — see
[Kernels with no Python canonical baseline](#kernels-with-no-python-canonical-baseline)
below for those instead.

| Speed<br>Up | Response<br>type | Function | Canonical package<br>and function | EDI<br>(ms) | Canonical<br>(ms) |
|---:|---|---|---|---:|---:|
| **77.8x** | continuous | `fast_robust_regression` | statsmodels `RLM` | 0.100 | 8.13 |
| **4.44x** | continuous | `fast_ols` | numpy `linalg.lstsq` | 0.0200 | 0.0800 |
| **4.00x** | continuous | `wilcox_hl_point_estimate` | numpy `median(HL pairwise diff)` | 0.150 | 0.610 |
| **48.1x** | incidence | `fast_identity_binomial_regression` | statsmodels `GLM(Binomial, identity link)` | 0.120 | 5.83 |
| **14.4x** | incidence | `fast_probit_regression` | statsmodels `GLM(Binomial, probit link)` | 0.360 | 5.23 |
| **13.7x** | incidence | `fast_logistic_regression` | statsmodels `GLM(Binomial)` | 0.180 | 2.52 |
| **11.8x** | incidence | `fast_log_binomial_regression` | statsmodels `GLM(Binomial, log link)` | 0.890 | 10.5 |
| **1600x** | survival | `get_survival_stat_diff` (restricted_mean) | lifelines `utils.restricted_mean_survival_time` | 0.0100 | 17.6 |
| **1370x** | survival | `get_survival_stat_diff` (median) | lifelines `KaplanMeierFitter(median)` | 0.0100 | 14.8 |
| **1170x** | survival | `fast_weibull_regression_general` | lifelines `WeibullAFTFitter.fit()` (right-censored only) | 0.120 | 136 |
| **519x** | survival | `fast_weibull_regression_general` (interval-censored) | lifelines `WeibullAFTFitter.fit_interval_censoring()` | 0.370 | 193 |
| **433x** | survival | `fast_stratified_coxph_regression` | lifelines `CoxPHFitter(strata=)` | 0.350 | 153 |
| **209x** | survival | `fast_logrank_stats` | lifelines `statistics.logrank_test` | 0.0800 | 16.2 |
| **90.4x** | survival | `fast_coxph_regression` | scikit-survival `CoxPHSurvivalAnalysis` | 0.380 | 34.8 |
| **56.3x** | count | `fast_hurdle_negbin` | statsmodels `HurdleCountModel(negbin)` | 1.59 | 89.6 |
| **28.2x** | count | `fast_zero_augmented_poisson` (is_hurdle=True) | statsmodels `HurdleCountModel(poisson)` | 0.980 | 27.7 |
| **24.7x** | count | `fast_poisson_regression` | statsmodels `GLM(Poisson)` | 0.110 | 2.67 |
| **23.1x** | count | `fast_zinb` | statsmodels `ZeroInflatedNegativeBinomialP` | 9.45 | 218 |
| **18.9x** | count | `fast_neg_bin` | statsmodels `NegativeBinomial` | 0.640 | 12.0 |
| **5.00x** | count | `fast_zero_augmented_poisson` (is_hurdle=False) | statsmodels `ZeroInflatedPoisson` | 7.93 | 39.6 |
| **10.7x** | proportion | `fast_beta_regression` | statsmodels `BetaModel` | 1.06 | 11.4 |
| **111x** | ordinal | `fast_ordinal_regression` | statsmodels `OrderedModel(logit)` | 0.700 | 77.9 |
| **109x** | ordinal | `fast_ordinal_probit_regression` | statsmodels `OrderedModel(probit)` | 0.570 | 62.3 |

Three additional response-family rows in the underlying benchmark
(`InferenceIncidGCompRiskDiff`/`RiskRatio`, `InferencePropGCompMeanDiff`,
`InferenceOrdinalGCompMeanDiff`) time a G-computation post-processing step
layered on top of `fast_logistic_regression`/`fast_ordinal_regression` —
that post-processing utility isn't itself a separately exposed
`edi_kernels` function, so those rows are left out of the table above
rather than misattributing their timing to a single bindable kernel.

Full results, including the Wald/full-inference table (standard errors
and p-values), the utility/math-kernel table, dataset spec, and methodology
notes: [`benchmark_model_fits_python.html`](https://rawcdn.githack.com/kapelner/EDI/main/python/benchmark/benchmark_model_fits_python.html). 
Same table shape as the R package's own
[`benchmark_model_fits_R.html`](https://rawcdn.githack.com/kapelner/EDI/main/R/benchmark/benchmark_model_fits_R.html).

### Utility (math kernel) speed gains

The `fast_math` scalar functions underneath several of the model-fitting
kernels above (`fast_digamma`/`fast_trigamma`/etc., used internally by the
NegBin/Beta/ZINB/Hurdle likelihoods and probit cold-start heuristics) are
also directly exposed and independently benchmarked, vectorized, against
scipy/numpy's own vectorized equivalents over a length-5000 array. Same
methodology and columns as the table above; all 14 have a canonical
baseline, so there's no separate "no baseline" table for this group.

| Speed<br>Up | Function | Canonical package<br>and function | EDI<br>(ms) | Canonical<br>(ms) |
|---:|---|---|---:|---:|
| **75.0x** | `fast_log_dnorm` | scipy `stats.norm.logpdf` | 0.00179 | 0.130 |
| **69.2x** | `fast_trigamma` | scipy `special.polygamma(1,.)` | 0.0200 | 1.33 |
| **8.60x** | `fast_qnorm` | scipy `stats.norm.ppf` | 0.0300 | 0.220 |
| **4.60x** | `dnorm_fast` | scipy `stats.norm.pdf` | 0.0300 | 0.150 |
| **2.85x** | `pnorm_fast` | scipy `stats.norm.cdf` | 0.0700 | 0.200 |
| **2.44x** | `fast_atan` | numpy `arctan` | 0.0200 | 0.0600 |
| **2.30x** | `fast_log_pnorm` | scipy `stats.norm.logcdf` | 0.120 | 0.270 |
| **2.29x** | `fast_lbeta` | scipy `special.betaln` | 0.220 | 0.510 |
| **1.63x** | `fast_log1pexp` | numpy `logaddexp(0,.)` | 0.0600 | 0.100 |
| **1.52x** | `fast_digamma` | scipy `special.digamma` | 0.0600 | 0.0900 |
| **1.42x** | `fast_pchisq_upper` | scipy `stats.chi2.sf` | 0.550 | 0.770 |
| **1.27x** | `fast_lgamma` | scipy `special.gammaln` | 0.0700 | 0.0900 |
| **1.21x** | `fast_erfc` | scipy `special.erfc` | 0.0800 | 0.0900 |
| **1.15x** | `fast_dnbinom_mu` | scipy `stats.nbinom.logpmf` | 0.400 | 0.470 |

## Kernels with no Python canonical baseline

Seventeen bound kernels have no clean, actively-maintained Python package to
benchmark against (an absent comparison is more honest than a mismatched
substitute baseline). They're bound in `edi_kernels` regardless — EDI is
still the only fast way to fit them in Python — they just have no speedup
number to show:

| Function | What it fits | Why there's no Python baseline |
|---|---|---|
| `fast_gaussian_lmm` | Gaussian LMM, random intercept, fit via MLE | statsmodels' `MixedLM` uses REML/a different estimation path by default — not a like-for-like comparison |
| `fast_poisson_glmm` | Poisson GLMM, random intercept, adaptive Gauss-Hermite quadrature + MLE | no pure-Python package offers ML (not variational/Bayesian) GLMM fitting |
| `fast_logistic_glmm` | Logistic GLMM, random intercept, adaptive Gauss-Hermite quadrature + MLE | same — no pure-Python ML GLMM fitter |
| `fast_hurdle_poisson_glmm` | Hurdle-Poisson GLMM, random intercept | no pure-Python package combines a hurdle count model with adaptive-quadrature GLMM fitting |
| `fast_cpoisson_combined` | KK combined (matched-pair + reservoir) joint-likelihood Poisson estimator | no canonical analog in either R or Python |
| `fast_clogit_plus_glmm` | KK combined (matched-pair + reservoir) joint-likelihood conditional-logit/GLMM estimator | no canonical analog in either R or Python |
| `fast_adjacent_category_logit` | Adjacent-category logit ordinal regression | no identified Python package implements this link |
| `fast_ordinal_cauchit_regression` | Ordinal regression, cauchit link | statsmodels' `OrderedModel(distr=)` only documents `'probit'`/`'logit'` |
| `fast_ordinal_cloglog_regression` | Ordinal regression, complementary log-log link | same — `distr=` doesn't officially support cloglog |
| `fast_continuation_ratio_regression` | Continuation-ratio ordinal regression | no identified Python package implements this link |
| `fast_ordinal_clmm` | Ordinal cumulative-link mixed model (logit/probit/cauchit/cloglog), random intercept | no pure-Python package offers ML ordinal-GLMM fitting with adaptive quadrature |
| `fast_ordinal_glmm` | Proportional-odds ordinal GLMM, random intercept | same — no pure-Python ML ordinal-GLMM fitter |
| `fast_stereotype_logit` | Stereotype logit ordinal regression | no Python package implements this link |
| `fast_zero_one_inflated_beta` | Zero-one-inflated beta regression (proportions) | no canonical package in either R or Python |
| `fast_weibull_frailty` | Weibull AFT with shared log-normal frailty | no clean Python package (even the R side only has a partial/PH-parameterized `frailtypack` analog) |
| `fast_clayton_weibull_aft_optim` | KK combined (matched-pair + reservoir) Clayton-copula-dependent-censoring Weibull AFT estimator | no canonical analog in either R or Python |
| `fast_dep_cens_transform_optim` | Dependent-censoring transformation-model regression | no canonical analog in either R or Python |

## Usage

Every bound kernel returns a `dict` mirroring the R package's own
`edi::ResultMap` -> list conversion field for field. Most kernels take an
`estimate_only` flag: `True` skips the variance/vcov computation for the
fastest possible point estimate, `False` (the default on most kernels)
additionally returns standard errors/vcov for Wald inference. A few
families (the zero-inflated/hurdle count models, the constrained-binomial
log/identity links) instead split this into two separate functions — a
point-estimate-only kernel and a `*_with_var` sibling — rather than an
`estimate_only` flag; those are shown as separate calls below.

Full per-argument documentation for every function is available via
`help(edi_kernels.<function>)` — every kernel has a real docstring with a
`Parameters` section, and the package ships a `py.typed` marker + type stub
for IDE autocomplete.

### Continuous

```python
import numpy as np
from edi_kernels import fast_ols, fast_robust_regression, fast_gaussian_lmm

rng = np.random.default_rng(0)
n = 200
X = np.column_stack([np.ones(n), rng.binomial(1, 0.5, n), rng.normal(size=n)])
y = X @ [1.0, 0.5, -0.3] + rng.normal(size=n)

# continuous -- OLS: point estimate only
fit = fast_ols(X, y, estimate_only=True)
# continuous -- OLS: point estimate + model-based variance (SEs/p-values)
fit = fast_ols(X, y, estimate_only=False)

# continuous -- robust (M-estimator) regression: point estimate only
fit = fast_robust_regression(X, y, estimate_only=True)
# continuous -- robust (M-estimator) regression: point estimate + variance
fit = fast_robust_regression(X, y, estimate_only=False)

# group_id must partition rows into groups of size EXACTLY 1 or 2 (matched pairs / singletons) --
# a larger group silently corrupts memory for this whole GLMM/CLMM/LMM kernel family.
group_id = np.repeat(np.arange(n // 2), 2).astype(np.int32) + 1
b_re = rng.normal(scale=0.4, size=n // 2).repeat(2)
y_clustered = X @ [1.0, 0.5, -0.3] + b_re + rng.normal(scale=0.5, size=n)

# continuous -- Gaussian LMM (random intercept): point estimate only
fit = fast_gaussian_lmm(X, y_clustered, group_id, estimate_only=True)
# continuous -- Gaussian LMM: point estimate + variance
fit = fast_gaussian_lmm(X, y_clustered, group_id, estimate_only=False)
```

### Incidence

```python
import numpy as np
from edi_kernels import (
    fast_logistic_regression, fast_probit_regression,
    fast_log_binomial_regression, fast_log_binomial_regression_with_var,
    fast_identity_binomial_regression, fast_identity_binomial_regression_with_var,
    fast_logistic_glmm, fast_clogit_plus_glmm, gee_pairs_singletons,
)

rng = np.random.default_rng(1)
n = 200
X = np.column_stack([np.ones(n), rng.binomial(1, 0.5, n), rng.normal(size=n)])
p = 1 / (1 + np.exp(-(X @ [0.2, 0.8, -0.5])))
y_bin = rng.binomial(1, p).astype(float)

# incidence -- logistic regression: point estimate only
fit = fast_logistic_regression(X, y_bin, estimate_only=True)
# incidence -- logistic regression: point estimate + variance
fit = fast_logistic_regression(X, y_bin, estimate_only=False)

# incidence -- probit regression: point estimate only
fit = fast_probit_regression(X, y_bin, estimate_only=True)
# incidence -- probit regression: point estimate + variance
fit = fast_probit_regression(X, y_bin, estimate_only=False)

y_lowrisk = rng.binomial(1, 0.15 + 0.05 * X[:, 1]).astype(float)

# incidence -- log-binomial regression (risk ratio): point estimate only
fit = fast_log_binomial_regression(X, y_lowrisk, estimate_only=True)
# incidence -- log-binomial regression: point estimate + variance for coefficient j=1 (risk-ratio SE)
fit = fast_log_binomial_regression_with_var(X, y_lowrisk, j=1)

# incidence -- identity-binomial regression (risk difference): point estimate only
fit = fast_identity_binomial_regression(X, y_lowrisk, estimate_only=True)
# incidence -- identity-binomial regression: point estimate + variance for coefficient j=1 (risk-difference SE)
fit = fast_identity_binomial_regression_with_var(X, y_lowrisk, j=1)

# group_id must be groups of size EXACTLY 1 or 2 (same GLMM/CLMM/LMM-family constraint as above).
group_id = np.repeat(np.arange(n // 2), 2).astype(np.int32) + 1
b_re = rng.normal(scale=0.4, size=n // 2).repeat(2)
y_bin_clustered = rng.binomial(1, 1 / (1 + np.exp(-(X @ [0.2, 0.8, -0.5] + b_re)))).astype(float)

# incidence -- logistic GLMM (random intercept), j_T = 0-based treatment column: point estimate only
fit = fast_logistic_glmm(X, y_bin_clustered, group_id, j_T=1, estimate_only=True)
# incidence -- logistic GLMM: point estimate + variance
fit = fast_logistic_glmm(X, y_bin_clustered, group_id, j_T=1, estimate_only=False)

# matched pairs estimator: discordant pairs -> conditional logit, concordant pairs -> random-intercept GLMM.
n_disc = 80
X_disc = rng.normal(size=(n_disc, 2))
y_disc = rng.binomial(1, 1 / (1 + np.exp(-(X_disc @ [0.6, -0.4])))).astype(float)
n_conc = 80
X_conc = rng.normal(size=(n_conc, 2))
group_conc = np.repeat(np.arange(n_conc // 2), 2).astype(np.int32) + 1  # concordant pairs, size EXACTLY 2
b_conc = rng.normal(scale=0.5, size=n_conc // 2).repeat(2)
y_conc = rng.binomial(1, 1 / (1 + np.exp(-(X_conc @ [0.6, -0.4] + b_conc)))).astype(float)

# incidence -- matched pairs conditional-logit + random-intercept-GLMM estimator: point estimate only
fit = fast_clogit_plus_glmm(X_disc, y_disc, X_conc, y_conc, group_conc, True, True, estimate_only=True)
# incidence -- matched pairs conditional-logit + GLMM estimator: point estimate + variance
fit = fast_clogit_plus_glmm(X_disc, y_disc, X_conc, y_conc, group_conc, True, True, estimate_only=False)

# incidence -- matched-pair/singleton GEE (family can be "gaussian"/"binomial"/"poisson"; always returns vcov)
fit = gee_pairs_singletons(X, y_bin_clustered, group_id, "binomial")
```

### Survival

```python
import numpy as np
from edi_kernels import (
    fast_coxph_regression, fast_stratified_coxph_regression,
    fast_weibull_regression_general, fast_weibull_frailty,
    fast_clayton_weibull_aft_optim, fast_dep_cens_transform_optim,
)

rng = np.random.default_rng(2)
n = 150
# survival kernels take X with NO intercept column -- the baseline hazard/log-scale absorbs it.
X = np.column_stack([rng.binomial(1, 0.5, n).astype(float), rng.normal(size=n)])
eta = X @ [0.5, -0.3]
event_time = rng.exponential(np.exp(-eta))
censor_time = rng.exponential(3.0, n)
dead = (event_time <= censor_time).astype(float)
y = np.minimum(event_time, censor_time)
y_exact = np.where(dead != 0, y, np.nan)
y_L = np.where(dead == 0, y, np.nan)
y_R = np.where(dead == 0, np.inf, np.nan)

# survival -- Cox proportional-hazards regression (unstratified): point estimate only
fit = fast_coxph_regression(X, y, dead, estimate_only=True)
# survival -- Cox PH regression: point estimate + variance
fit = fast_coxph_regression(X, y, dead, estimate_only=False)

strata = rng.integers(0, 3, n).astype(np.int32)
# survival -- stratified Cox PH regression (shared beta, per-stratum baseline hazard): point estimate only
fit = fast_stratified_coxph_regression(X, y, dead, strata, estimate_only=True)
# survival -- stratified Cox PH regression: point estimate + variance
fit = fast_stratified_coxph_regression(X, y, dead, strata, estimate_only=False)

# survival -- Weibull AFT regression: point estimate only
fit = fast_weibull_regression_general(X, y_exact, y_L, y_R, estimate_only=True)
# survival -- Weibull AFT regression: point estimate + variance
fit = fast_weibull_regression_general(X, y_exact, y_L, y_R, estimate_only=False)

# survival -- Weibull AFT under left-/interval-/right-censoring (periodic-inspection design, e.g. a
# clinical trial assessed only at scheduled visits -- the event time itself is never observed
# directly, only which inspection interval it fell in).
true_event_time = rng.exponential(np.exp(-eta))
inspection_times = np.array([0.1, 0.3, 0.6, 1.0, 1.5, 2.2])  # scheduled visits
last_inspection = inspection_times[-1]

y_ic = np.full(n, np.nan)  # exact times are never observed under this design
y_L_ic = np.empty(n)
y_R_ic = np.empty(n)
for i in range(n):
    t = true_event_time[i]
    if t > last_inspection:
        y_L_ic[i], y_R_ic[i] = last_inspection, np.inf                              # right-censored
    else:
        idx = np.searchsorted(inspection_times, t)
        if idx == 0:
            y_L_ic[i], y_R_ic[i] = 0.0, inspection_times[0]                          # left-censored
        else:
            y_L_ic[i], y_R_ic[i] = inspection_times[idx - 1], inspection_times[idx]  # interval-censored

# survival -- Weibull AFT under general left-/interval-/right-censoring: point estimate only
fit = fast_weibull_regression_general(X, y_ic, y_L_ic, y_R_ic, estimate_only=True)
# survival -- Weibull AFT under general left-/interval-/right-censoring: point estimate + variance
fit = fast_weibull_regression_general(X, y_ic, y_L_ic, y_R_ic, estimate_only=False)

# group_id: shared-frailty clusters (any size; uses adaptive Gauss-Hermite quadrature, not the fixed-2 shortcut).
group_id = np.repeat(np.arange(n // 2), 2).astype(np.int32) + 1
# survival -- Weibull AFT with shared gamma frailty (random intercept): point estimate only
fit = fast_weibull_frailty(X, y, dead, group_id, estimate_only=True)
# survival -- Weibull AFT with shared frailty: point estimate + variance
fit = fast_weibull_frailty(X, y, dead, group_id, estimate_only=False)

# KK combined estimator: matched valid pairs (Clayton-copula dependent censoring) + independent singletons.
n_pairs, n_single = 30, 20
n_tot = 2 * n_pairs + n_single
Xk = rng.normal(size=(n_tot, 1))
yk = np.exp(0.5 + Xk[:, 0] * 0.3 + rng.gumbel(size=n_tot) * 0.7)
deadk = rng.binomial(1, 0.85, n_tot).astype(float)
pair_idx = np.column_stack([np.arange(0, 2 * n_pairs, 2), np.arange(1, 2 * n_pairs, 2)]).astype(np.int32)
singleton_rows = np.arange(2 * n_pairs, n_tot).astype(np.int32)
warm_start_params = np.zeros(Xk.shape[1] + 2)  # beta, log_sigma, log_theta

# survival -- KK combined Clayton-copula Weibull AFT (matched pairs, dependent censoring): point estimate only
fit = fast_clayton_weibull_aft_optim(Xk, yk, deadk, pair_idx, singleton_rows, warm_start_params, estimate_only=True)
# survival -- KK combined Clayton-copula Weibull AFT: point estimate + variance
fit = fast_clayton_weibull_aft_optim(Xk, yk, deadk, pair_idx, singleton_rows, warm_start_params, estimate_only=False)

# survival -- dependent-censoring transformation-model AFT fit: point estimate only
fit = fast_dep_cens_transform_optim(X, y, dead, estimate_only=True)
# survival -- dependent-censoring transformation-model AFT fit: point estimate + variance
fit = fast_dep_cens_transform_optim(X, y, dead, estimate_only=False)
```

### Count

```python
import numpy as np
from edi_kernels import (
    fast_poisson_regression, fast_neg_bin,
    fast_zinb, fast_zinb_with_var,
    fast_zero_augmented_poisson, fast_zero_augmented_poisson_with_var,
    fast_hurdle_negbin, fast_truncated_negbin_count, fast_cpoisson_combined,
    fast_poisson_glmm, fast_hurdle_poisson_glmm,
)

rng = np.random.default_rng(3)
n = 200
X = np.column_stack([np.ones(n), rng.binomial(1, 0.5, n), rng.normal(size=n)])
mu = np.exp(0.3 + 0.4 * X[:, 1] + 0.2 * X[:, 2])
y_pois = rng.poisson(mu).astype(float)

# count -- Poisson regression: point estimate only
fit = fast_poisson_regression(X, y_pois, estimate_only=True)
# count -- Poisson regression: point estimate + variance
fit = fast_poisson_regression(X, y_pois, estimate_only=False)

r = 4.0
y_nb = rng.negative_binomial(r, r / (r + mu)).astype(float)

# count -- negative binomial regression (dispersion jointly MLE'd): point estimate only
fit = fast_neg_bin(X, y_nb, estimate_only=True)
# count -- negative binomial regression: point estimate + variance
fit = fast_neg_bin(X, y_nb, estimate_only=False)

# count -- zero-inflated negative binomial (Xc: count part, Xz: zero-inflation part): point estimate only
fit = fast_zinb(X, X, y_nb)
# count -- zero-inflated negative binomial: point estimate + full vcov
fit = fast_zinb_with_var(X, X, y_nb)

# count -- zero-inflated Poisson (is_hurdle=False) / hurdle Poisson (is_hurdle=True): point estimate only
fit = fast_zero_augmented_poisson(X, y_pois, X, is_hurdle=False)
# count -- zero-inflated Poisson: point estimate + full vcov
fit = fast_zero_augmented_poisson_with_var(X, y_pois, X, is_hurdle=False)

# count -- hurdle negative binomial (independent logistic hurdle + truncated-NegBin count part): point estimate only
fit = fast_hurdle_negbin(X, y_nb, X, estimate_only=True)
# count -- hurdle negative binomial: point estimate + variance
fit = fast_hurdle_negbin(X, y_nb, X, estimate_only=False)

y_trunc = y_nb.copy()
y_trunc[y_trunc == 0] = 1.0  # zero-truncated NegBin requires y >= 1

# count -- zero-truncated negative binomial regression: point estimate only
fit = fast_truncated_negbin_count(X, y_trunc, estimate_only=True)
# count -- zero-truncated negative binomial regression: point estimate + variance
fit = fast_truncated_negbin_count(X, y_trunc, estimate_only=False)

# KK combined estimator: conditional-Poisson matched valid pairs (binomial(n_k, p)) + Poisson reservoir singletons.
nd, nR = 40, 50
X_diff_v = rng.normal(size=(nd, 1)) * 0.5
n_k_v = rng.integers(4, 15, nd).astype(float)
yT_v = rng.binomial(n_k_v.astype(int), 1 / (1 + np.exp(-(X_diff_v @ [0.4])))).astype(float)
X_r = rng.normal(size=(nR, 1)) * 0.5
w_r = rng.binomial(1, 0.5, nR).astype(float)
y_r = rng.poisson(np.exp(0.3 + 0.4 * w_r + 0.4 * X_r[:, 0])).astype(float)

# count -- KK combined conditional-Poisson (matched pairs) + Poisson (reservoir singletons): point estimate only
fit = fast_cpoisson_combined(yT_v, n_k_v, X_diff_v, y_r, w_r, X_r, estimate_only=True)
# count -- KK combined conditional-Poisson + Poisson: point estimate + variance
fit = fast_cpoisson_combined(yT_v, n_k_v, X_diff_v, y_r, w_r, X_r, estimate_only=False)

# group_id must be groups of size EXACTLY 1 or 2 (GLMM/CLMM/LMM-family constraint).
group_id = np.repeat(np.arange(n // 2), 2).astype(np.int32) + 1
b_re = rng.normal(scale=0.3, size=n // 2).repeat(2)
y_pois_clustered = rng.poisson(np.exp(X @ [0.5, 0.3, -0.2] + b_re)).astype(float)

# count -- Poisson GLMM (random intercept), j_T = 0-based treatment column: point estimate only
fit = fast_poisson_glmm(X, y_pois_clustered, group_id, j_T=1, estimate_only=True)
# count -- Poisson GLMM: point estimate + variance
fit = fast_poisson_glmm(X, y_pois_clustered, group_id, j_T=1, estimate_only=False)

# count -- hurdle-Poisson GLMM (random intercept): point estimate only
fit = fast_hurdle_poisson_glmm(X, y_pois_clustered, group_id, j_T=1, estimate_only=True)
# count -- hurdle-Poisson GLMM: point estimate + variance
fit = fast_hurdle_poisson_glmm(X, y_pois_clustered, group_id, j_T=1, estimate_only=False)
```

### Proportion

```python
import numpy as np
from edi_kernels import fast_beta_regression, fast_zero_one_inflated_beta, gee_pairs_singletons

rng = np.random.default_rng(4)
n = 300
X = np.column_stack([np.ones(n), rng.binomial(1, 0.5, n).astype(float), rng.normal(size=n)])
mu = 1 / (1 + np.exp(-(0.3 + 0.4 * X[:, 1] - 0.3 * X[:, 2])))
phi = 8.0
y_beta = rng.beta(mu * phi, (1 - mu) * phi)  # in the OPEN interval (0, 1)

# proportion -- beta regression: point estimate only
fit = fast_beta_regression(X, y_beta, estimate_only=True)
# proportion -- beta regression: point estimate + variance
fit = fast_beta_regression(X, y_beta, estimate_only=False)

# zero-one-inflated beta: y may include exact 0s/1s; X_zero_one is the inflation-part design matrix.
p0 = 1 / (1 + np.exp(-(-1.0 + 0.3 * X[:, 1])))
p1 = 1 / (1 + np.exp(-(-1.2 - 0.2 * X[:, 1])))
u = rng.uniform(size=n)
y01 = y_beta.copy()
y01[u < p0] = 0.0
y01[(u >= p0) & (u < p0 + p1)] = 1.0

# proportion -- zero-one-inflated beta regression (single-mode kernel; no estimate_only/with_var split)
fit = fast_zero_one_inflated_beta(X, X, y01)

# proportion -- matched-pair/singleton GEE on a (0, 1)-valued response: the same gee_pairs_singletons
# kernel as the Incidence section above (there is no separate "proportion" GEE family -- the binomial
# working variance/logit link applies to any response in [0, 1], not just strictly-binary data), and
# the kernel that backs R's KK-design InferencePropKKGEE.
group_id = np.repeat(np.arange(n // 2), 2).astype(np.int32) + 1
fit = gee_pairs_singletons(X, y_beta, group_id, "binomial")
```

### Ordinal

```python
import numpy as np
from edi_kernels import (
    fast_adjacent_category_logit, fast_continuation_ratio_regression,
    fast_ordinal_regression, fast_ordinal_probit_regression,
    fast_ordinal_cauchit_regression, fast_ordinal_cloglog_regression,
    fast_stereotype_logit, fast_ordinal_clmm, fast_ordinal_glmm,
)

rng = np.random.default_rng(5)
n = 300
K = 4
# ordinal kernels take X with NO intercept -- the K-1 alpha thresholds serve that role --
# and y is 1-INDEXED (values in {1, ..., K}), not 0-indexed.
X = np.column_stack([rng.binomial(1, 0.5, n).astype(float), rng.normal(size=n)])
alpha_true = np.array([-1.0, 0.2, 1.3])
eta = X @ [0.6, -0.4]
y = np.zeros(n)
for i in range(n):
    cum = 1 / (1 + np.exp(-(alpha_true - eta[i])))
    y[i] = 1 + np.sum(rng.uniform() > cum)
y = y.astype(np.int32)

# ordinal -- adjacent-category logit regression (single-mode kernel; always returns full inference)
fit = fast_adjacent_category_logit(X, y)
# ordinal -- continuation-ratio regression (single-mode kernel; always returns full inference)
fit = fast_continuation_ratio_regression(X, y)

# ordinal -- proportional-odds (logit link) regression: point estimate only
fit = fast_ordinal_regression(X, y, estimate_only=True)
# ordinal -- proportional-odds regression: point estimate + variance
fit = fast_ordinal_regression(X, y, estimate_only=False)

# ordinal -- ordered-probit regression: point estimate only
fit = fast_ordinal_probit_regression(X, y, estimate_only=True)
# ordinal -- ordered-probit regression: point estimate + variance
fit = fast_ordinal_probit_regression(X, y, estimate_only=False)

# ordinal -- ordinal regression, cauchit link: point estimate only
fit = fast_ordinal_cauchit_regression(X, y, estimate_only=True)
# ordinal -- ordinal regression, cauchit link: point estimate + variance
fit = fast_ordinal_cauchit_regression(X, y, estimate_only=False)

# ordinal -- ordinal regression, complementary log-log link: point estimate only
fit = fast_ordinal_cloglog_regression(X, y, estimate_only=True)
# ordinal -- ordinal regression, cloglog link: point estimate + variance
fit = fast_ordinal_cloglog_regression(X, y, estimate_only=False)

# stereotype logit's "score" parameterization needs better-conditioned data than the generic
# proportional-odds recipe above to converge cleanly -- a separate, smaller-K synthetic dataset.
n_st, K_st = 400, 3
X_st = np.column_stack([rng.binomial(1, 0.5, n_st).astype(float), rng.normal(size=n_st)])
alpha_st, beta_st = np.array([-1.0, 1.0]), np.array([0.6, -0.4])
eta_st = X_st @ beta_st
y_st = np.zeros(n_st)
for i in range(n_st):
    cum = 1 / (1 + np.exp(-(alpha_st - eta_st[i])))
    y_st[i] = 1 + np.sum(rng.uniform() > cum)
y_st = y_st.astype(np.int32)

# ordinal -- stereotype logit regression: point estimate only
fit = fast_stereotype_logit(X_st, y_st, estimate_only=True)
# ordinal -- stereotype logit regression: point estimate + variance
fit = fast_stereotype_logit(X_st, y_st, estimate_only=False)

# group_id must be groups of size EXACTLY 1 or 2 (GLMM/CLMM/LMM-family constraint).
group_id = np.repeat(np.arange(n // 2), 2).astype(np.int32) + 1
b_re = np.repeat(rng.normal(scale=0.4, size=n // 2), 2)
eta_clustered = X @ [0.6, -0.4] + b_re
y_clustered = np.zeros(n)
for i in range(n):
    cum = 1 / (1 + np.exp(-(np.array([-1.0, 0.5]) - eta_clustered[i])))
    y_clustered[i] = 1 + np.sum(rng.uniform() > cum)
y_clustered = y_clustered.astype(np.int32)

# ordinal -- cumulative-link mixed model (link: "logit"/"probit"/"cauchit"/"cloglog"), K=3 categories: point estimate only
fit = fast_ordinal_clmm(X, y_clustered, group_id, K=3, j_T=0, link="logit", estimate_only=True)
# ordinal -- cumulative-link mixed model: point estimate + variance
fit = fast_ordinal_clmm(X, y_clustered, group_id, K=3, j_T=0, link="logit", estimate_only=False)

# ordinal -- proportional-odds ordinal GLMM (logit link only), random intercept: point estimate only
fit = fast_ordinal_glmm(X, y_clustered, group_id, K=3, j_T=0, estimate_only=True)
# ordinal -- proportional-odds ordinal GLMM: point estimate + variance
fit = fast_ordinal_glmm(X, y_clustered, group_id, K=3, j_T=0, estimate_only=False)
```

### Utilities

The functions below don't fit a parametric model -- they're nonparametric
test statistics, closed-form CIs/p-values on count data, a post-fit
robust-SE adjustment, and one pure math function. Grouped here rather than
under a response type since none of them takes an `estimate_only` flag or
has a "with variance" counterpart -- each is already a single, complete
call.

```python
import numpy as np
from edi_kernels import (
    ols_hc2_post_fit, wilcox_hl_point_estimate,
    mn_ci, mn_pvalue, newcombe_independent_ci,
    fast_gehan_wilcox_stats, fast_logrank_stats, get_survival_stat_diff,
    fast_ridit_analysis,
    fast_pchisq_upper, fast_digamma, fast_trigamma, fast_lgamma, fast_lbeta,
    fast_dnbinom_mu, fast_qnorm, fast_log_pnorm, fast_log_dnorm, fast_erfc,
    pnorm_fast, dnorm_fast, fast_atan, fast_log1pexp,
)

rng = np.random.default_rng(6)
n = 150
X = np.column_stack([np.ones(n), rng.binomial(1, 0.5, n), rng.normal(size=n)])
y = X @ [1.0, 0.5, -0.3] + rng.normal(size=n)

# continuous -- heteroskedasticity-robust (HC2) SE, computed post-fit (on an OLS coefficient
# vector fit however you like -- see fast_ols above) for coefficient j_treat=1
b_hat, *_ = np.linalg.lstsq(X, y, rcond=None)
robust = ols_hc2_post_fit(X, y, b_hat, j_treat=1)

# continuous -- Wilcoxon/Hodges-Lehmann pairwise-difference point estimate (nonparametric two-group contrast)
hl = wilcox_hl_point_estimate(y, X[:, 1].astype(np.int32))

# incidence -- Miettinen-Nurminen score CI for a two-arm risk difference (30/100 treated, 18/95 control)
lower, upper = mn_ci(30.0, 100.0, 18.0, 95.0, 30.0 / 100.0, 18.0 / 95.0)
# incidence -- Miettinen-Nurminen score p-value for the same two-arm comparison, testing delta=0
pval = mn_pvalue(30.0, 100.0, 18.0, 95.0, 0.0, 30.0 / 100.0, 18.0 / 95.0)
# incidence -- Newcombe (Wilson-score-based) CI for the difference of two independent proportions
lower, upper = newcombe_independent_ci(30.0, 100.0, 18.0, 95.0)

# survival kernels take X with no intercept; dead/w are 0/1 event/treatment indicators.
Xs = np.column_stack([rng.binomial(1, 0.5, n).astype(float), rng.normal(size=n)])
event_time = rng.exponential(np.exp(-(Xs @ [0.5, -0.3])))
censor_time = rng.exponential(3.0, n)
dead = (event_time <= censor_time).astype(np.int32)
ys = np.minimum(event_time, censor_time)
w = rng.binomial(1, 0.5, n).astype(np.int32)

# survival -- Gehan-Wilcoxon two-sample test statistic (nonparametric)
stats = fast_gehan_wilcox_stats(ys, dead, w)
# survival -- (rho=0) log-rank two-sample test statistic (nonparametric)
stats = fast_logrank_stats(ys, dead, w)
# survival -- treatment-minus-control Kaplan-Meier median survival-time difference (nonparametric)
diff = get_survival_stat_diff(ys, dead, w, "median")

# ordinal -- Ridit analysis (nonparametric Mann-Whitney-style group contrast); y is 1-indexed {1,...,K}
w_ridit = rng.binomial(1, 0.5, n).astype(np.int32)
y_ridit = rng.integers(1, 5, n).astype(np.int32)
ridit = fast_ridit_analysis(w_ridit, y_ridit, "control")

# not tied to any response type -- upper-tail (survival function) p-value for a chi-squared statistic
pval = fast_pchisq_upper(3.84, df=1)

# utility -- vectorized scalar math kernels (each also used internally by the model-fitting
# kernels above); all take/return a plain 1-D ndarray, elementwise.
z = rng.normal(size=8)             # unrestricted reals, for the normal-distribution family below
p = rng.uniform(0.01, 0.99, 8)     # in (0, 1), for fast_qnorm
x_pos = rng.uniform(0.5, 5.0, 8)   # positive reals, for the gamma-function family below
counts = rng.integers(0, 20, 8).astype(np.float64)  # non-negative, for fast_dnbinom_mu

# utility -- standard normal PDF/CDFs/quantile and their logs (elementwise)
dens = dnorm_fast(z)
cum = pnorm_fast(z)
erfc_vals = fast_erfc(z)
log_dens = fast_log_dnorm(z)
log_cum = fast_log_pnorm(z)
quant = fast_qnorm(p)

# utility -- digamma/trigamma/log-gamma (elementwise)
dig = fast_digamma(x_pos)
trig = fast_trigamma(x_pos)
lgam = fast_lgamma(x_pos)
# utility -- log-beta (elementwise, two equal-length arrays)
lbet = fast_lbeta(x_pos, x_pos[::-1])

# utility -- mean-parameterized negative-binomial log-density (elementwise x; scalar size/mu)
nb_logpmf = fast_dnbinom_mu(counts, size=4.0, mu=6.0, return_log=True)

# utility -- arctangent, softplus (elementwise)
atan_vals = fast_atan(z)
softplus_vals = fast_log1pexp(z)
```

## Citation

If you use `edi_kernels` in published work, please cite it. Citation
metadata is maintained in
[`CITATION.cff`](https://github.com/kapelner/EDI/blob/main/python/CITATION.cff)
(Citation File Format), which GitHub renders as a "Cite this repository"
button and which tools like
[cffconvert](https://github.com/citation-file-format/cffconvert) can turn
into other formats (APA, BibTeX, EndNote, ...). As BibTeX:

```bibtex
@software{kapelner_edi_kernels,
  author  = {Kapelner, Adam},
  title   = {{edi\_kernels}: {P}ython bindings for {EDI}'s {C}++ model-fitting kernels},
  year    = {2026},
  version = {1.0.0.post3},
  url     = {https://pypi.org/project/edi_kernels/},
  note    = {Part of the EDI project, \url{https://github.com/kapelner/EDI}}
}
```

## License

GPL-3.0-only, matching the `EDI` R package this compiles against (see
[`LICENSE`](https://github.com/kapelner/EDI/blob/main/python/LICENSE)).
