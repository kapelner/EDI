# edi_kernels

Python bindings for EDI's C++ model-fitting kernels, via pybind11. **The point
of this package is speed:** the same C++ solvers used by the R package,
called directly from Python with no R/Rcpp dependency, running one to three
orders of magnitude faster than the pure-Python canonical fit for the same
model.

This package has **no R or Rcpp dependency**. It compiles the same
`R/EDI/src/*.cpp` model-fitting kernels the R package
[`EDI`](../R/README.md)
(not yet on CRAN) uses, built under an `EDI_CORE_ONLY` preprocessor guard
that swaps out `RcppEigen`/`Rmath` for a vanilla `Eigen` + `LBFGSpp`, both
fetched directly from their own upstream repositories (see
`CMakeLists.txt`). Nothing under `python/` is a copy of a `R/EDI/src/*.cpp`
or `*.h` file — the compiled extension `#include`s them directly from the
R package's own source tree.

See [`../R/package_metadata/new_feature_plans/python_bindings_package_spec.md`](../R/package_metadata/new_feature_plans/python_bindings_package_spec.md)
for the full design spec, kernel-by-kernel scope, and baseline-benchmarking
methodology.

## Speed gains

Point-estimate timings (median of 30 cold runs) for every bound kernel that
has a canonical Python baseline to compare against, sorted by speedup,
descending. `Timing Pval` for every row here is significant at
p < 0.001 (Welch's t-test, EDI vs. canonical replicate distributions).
Rows with **no** canonical Python implementation are omitted from this table
— see [Models with no Python canonical baseline](#models-with-no-python-canonical-baseline)
below for those.

| Class | Response | EDI (ms) | Canonical | Canonical (ms) | Speedup |
|---|---|---:|---|---:|---:|
| `InferenceSurvivalWeibullRegr` | survival | 0.08 | lifelines `WeibullAFTFitter` | 192.55 | **2423.43x** |
| `InferenceSurvivalKMDiff` | survival | 0.02 | lifelines `KaplanMeierFitter(median)` | 26.52 | **1647.81x** |
| `InferenceSurvivalRestrictedMeanDiff` | survival | 0.01 | lifelines `utils.restricted_mean_survival_time` | 19.30 | **1460.28x** |
| `InferenceSurvivalStratCoxPHRegr` | survival | 0.47 | lifelines `CoxPHFitter(strata=)` | 273.61 | **583.92x** |
| `InferenceSurvivalLogRank` | survival | 0.12 | lifelines `statistics.logrank_test` | 26.28 | **212.34x** |
| `InferenceIncidBinomialIdentityRiskDiff` | incidence | 0.10 | statsmodels `GLM(Binomial, identity link)` | 15.49 | **149.00x** |
| `InferenceOrdinalPropOddsRegr` | ordinal | 0.91 | statsmodels `OrderedModel(logit)` | 117.69 | **129.83x** |
| `InferenceOrdinalOrderedProbitRegr` | ordinal | 0.80 | statsmodels `OrderedModel(probit)` | 86.01 | **106.95x** |
| `InferenceOrdinalGCompMeanDiff` | ordinal | 1.09 | statsmodels `OrderedModel(logit)+gcomp` | 113.58 | **104.52x** |
| `InferenceSurvivalCoxPHRegr` | survival | 0.50 | scikit-survival `CoxPHSurvivalAnalysis` | 51.62 | **102.32x** |
| `InferenceContinRobustRegr` | continuous | 0.17 | statsmodels `RLM` | 11.92 | **69.49x** |
| `InferenceCountHurdleNegBin` | count | 2.33 | statsmodels `HurdleCountModel(negbin)` | 135.15 | **57.90x** |
| `InferenceCountHurdlePoisson` | count | 1.43 | statsmodels `HurdleCountModel(poisson)` | 41.83 | **29.33x** |
| `InferenceCountQuasiPoisson` | count | 0.14 | statsmodels `GLM(Poisson)` | 3.85 | **26.88x** |
| `InferenceCountZeroInflatedNegBin` | count | 13.96 | statsmodels `ZeroInflatedNegativeBinomialP` | 356.91 | **25.56x** |
| `InferenceIncidModifiedPoisson` | incidence | 0.16 | statsmodels `GLM(Poisson)` | 3.90 | **24.25x** |
| `InferenceCountRobustPoisson` | count | 0.16 | statsmodels `GLM(Poisson)` | 3.80 | **23.84x** |
| `InferenceCountPoisson` | count | 0.18 | statsmodels `GLM(Poisson)` | 3.94 | **22.54x** |
| `InferenceCountNegBin` | count | 0.81 | statsmodels `NegativeBinomial` | 17.87 | **22.13x** |
| `InferenceIncidProbitRegr` | incidence | 0.44 | statsmodels `GLM(Binomial, probit link)` | 9.38 | **21.34x** |
| `InferencePropFractionalLogit` | proportion | 0.15 | statsmodels `GLM(Binomial, fractional y)` | 3.08 | **20.00x** |
| `InferenceIncidLogRegr` | incidence | 0.24 | statsmodels `GLM(Binomial)` | 4.03 | **17.04x** |
| `InferencePropGCompMeanDiff` | proportion | 0.26 | statsmodels `GLM(Binomial)+gcomp` | 4.04 | **15.60x** |
| `InferenceIncidGCompRiskDiff` | incidence | 0.36 | statsmodels `GLM(Binomial)+gcomp(RD)` | 4.78 | **13.16x** |
| `InferenceIncidGCompRiskRatio` | incidence | 0.30 | statsmodels `GLM(Binomial)+gcomp(RR)` | 3.69 | **12.21x** |
| `InferencePropBetaRegr` | proportion | 1.40 | statsmodels `BetaModel` | 16.81 | **11.99x** |
| `InferenceCountZeroInflatedPoisson` | count | 11.91 | statsmodels `ZeroInflatedPoisson` | 59.04 | **4.96x** |
| `InferenceAllSimpleWilcox` | continuous | 0.25 | numpy `median(HL pairwise diff)` | 1.12 | **4.57x** |
| `InferenceIncidRiskDiff` | incidence | 0.03 | numpy `linalg.lstsq (LPM)` | 0.11 | **4.12x** |
| `InferenceContinOLS` | continuous | 0.03 | numpy `linalg.lstsq` | 0.11 | **3.25x** |
| `InferenceIncidLogBinomial` | incidence | 1.63 | statsmodels `GLM(Binomial, log link)` | 5.13 | **3.15x** |

**→ [Full results (`benchmark_model_fits_python.html`)](benchmark/benchmark_model_fits_python.html)**
— includes the Wald/full-inference table (standard errors + p-values, not just
the point estimate), the utility/math-kernel table, dataset spec, and
methodology notes. Same table shape as the R package's own
[`benchmark_model_fits_R.html`](../R/benchmark/benchmark_model_fits_R.html).

## Models with no Python canonical baseline

Fourteen EDI estimators have no clean, actively-maintained Python package to
benchmark against (an absent comparison is more honest than a mismatched
substitute baseline). They're bound in `edi_kernels` regardless — EDI is
still the only fast way to fit them in Python — they just don't appear in the
speed-gains table above since there's nothing to compare to:

| EDI class | What it fits | Why there's no Python baseline |
|---|---|---|
| `InferenceContinGLMM (pairs)` | Gaussian LMM, random intercept, fit via MLE | statsmodels' `MixedLM` uses REML/a different estimation path by default — not a like-for-like comparison |
| `InferenceCountGLMM (pairs)` | Poisson GLMM, random intercept, adaptive Gauss-Hermite quadrature + MLE | no pure-Python package offers ML (not variational/Bayesian) GLMM fitting |
| `InferenceCountHurdlePoisson (pairs)` | Hurdle-Poisson GLMM, random intercept | no pure-Python package combines a hurdle count model with adaptive-quadrature GLMM fitting |
| `InferenceCountKKCondPoissonOneLik` | KK combined (matched-pair + reservoir) joint-likelihood Poisson estimator | no canonical analog in either R or Python |
| `InferenceIncidKKCondLogitGLMMOneLik` | KK combined (matched-pair + reservoir) joint-likelihood conditional-logit/GLMM estimator | no canonical analog in either R or Python |
| `InferenceOrdinalAdjCatLogitRegr` | Adjacent-category logit ordinal regression | no identified Python package implements this link (R uses `VGAM::vglm(acat())`) |
| `InferenceOrdinalCauchitRegr` | Ordinal regression, cauchit link | statsmodels' `OrderedModel(distr=)` only documents `'probit'`/`'logit'` |
| `InferenceOrdinalCloglogRegr` | Ordinal regression, complementary log-log link | same — `distr=` doesn't officially support cloglog |
| `InferenceOrdinalContRatioRegr` | Continuation-ratio ordinal regression | no identified Python package implements this link (R uses `VGAM::vglm(cratio())`) |
| `InferenceOrdinalCLMM (pairs)` | Ordinal cumulative-link mixed model (logit/probit/cauchit/cloglog), random intercept | no pure-Python package offers ML ordinal-GLMM fitting with adaptive quadrature |
| `InferenceOrdinalGLMM (pairs)` | Proportional-odds ordinal GLMM, random intercept | same — no pure-Python ML ordinal-GLMM fitter |
| `InferenceOrdinalStereotypeLogitRegr` | Stereotype logit ordinal regression | R uses `VGAM::vglm(multinomial(...))`-style fitting; no Python package implements this link |
| `InferencePropZeroOneInflatedBetaRegr` | Zero-one-inflated beta regression (proportions) | no canonical package in either R or Python |
| `InferenceSurvivalKKWeibullFrailtyOneLik` | Weibull AFT with shared log-normal frailty | no clean Python package (even the R side only has a partial/PH-parameterized `frailtypack` analog) |

## Install

```bash
pip install .
```

## Usage

```python
import numpy as np
from edi_kernels import fast_ols

X = np.column_stack([np.ones(100), np.random.default_rng(0).normal(size=100)])
y = X @ [1.0, 0.5] + np.random.default_rng(1).normal(size=100)
result = fast_ols(X, y)
print(result["b"])
```

Every bound kernel returns a `dict` (see `python/cpp/result_map_pybind.h`)
mirroring the R package's own `edi::ResultMap` -> list conversion field for
field.
