# EDI (development version)

## Bug fixes

* `compute_rand_bootstrap_confidence_interval(type = "smoothed")` and
  `compute_rand_bootstrap_two_sided_pval(type = "smoothed")` added
  raw-scale Gaussian kernel noise to count responses, so a resampled zero
  could become a slightly negative non-integer. Under the CI inversion's
  multiplicative count shift that became a large negative integer, the
  Rcpp Poisson-GLMM fit gave up, and the glmmTMB fallback rejected every
  such draw (`GLMM FIT ERROR: negative values not allowed for the 'Poisson'
  family`), corrupting the null distribution and yielding a degenerate
  conservative bound (e.g. `InferenceCountKKGLMM`). With `use_rcpp = FALSE`
  every draw failed and the p-value was `NA`. Kernel noise on count
  responses is now rounded and floored at zero so the resampled draw stays
  on the non-negative integer support (the same convention the count shift
  already uses); other response types are unchanged.

# EDI 1.0.1

## Breaking changes

* `set_custom_randomization_statistic_function()` and
  `set_custom_randomization_statistic_cpp()` are removed from every concrete
  estimator class. They let a bare R closure read `private$des_obj_priv_int`
  through a hand-built environment proxy — an undocumented, fragile
  mechanism that also forced every concrete estimator's own fast/vectorized
  randomization-test paths to carry a guard for a feature that had nothing
  to do with that estimator. Use the new `InferenceRandCustom` class
  instead: `InferenceRandCustom$new(des_obj, custom_randomization_statistic_function
  = function(y, w, dead) ...)` (or `custom_randomization_statistic_cpp =`
  for the same C++ source/compiled-function/`RcppXPtrUtils::cppXPtr()`
  options as before), then call `compute_rand_two_sided_pval()` or
  `compute_rand_confidence_interval()` on it. The statistic function's
  calling convention is now explicit arguments — `function(y, w, dead)` —
  not implicit access to private state; existing custom statistic functions
  need this small rewrite. `InferenceRandCustom` has its own dedicated fast
  kernel, so performance is unchanged or better than before, uniformly
  across every dataset and design (previously, speed depended on which
  concrete class the statistic happened to be attached to).

## New features

* `InferenceIncidGCompRiskRatio` and `InferenceIncidKKGCompRiskRatio` gain
  subsampling and m-out-of-n bootstrap confidence intervals and two-sided
  p-values (previously only available for the risk-difference gcomp
  classes). The risk-ratio pivot is computed on the log scale (null at
  `log(delta)`, centered on `log(estimate)`), matching the convention
  already used by their percentile/BCa bootstrap CIs, since the raw-scale
  pivot correct for a difference is not correct for a ratio whose null is
  1 and which is right-skewed at reduced effective sample size.
* `get_local_EDI_optimization()`'s hardware fingerprint now detects
  CPU/RAM on Windows and macOS as well as Linux.

## Bug fixes

* The randomization confidence interval's bisection search picked the
  wrong "conservative" fallback endpoint when it had no reliable sign
  change to bracket: it always fell back to the lower endpoint `l`
  whenever the lower p-value was non-significant, which is correct when
  searching for a *lower* bound (`l` is the outer/conservative end there)
  but wrong when searching for an *upper* bound, where `l` is the point
  estimate itself and is essentially always non-significant. Every such
  "conservative" upper bound silently collapsed to the point estimate,
  producing badly-too-narrow intervals — confirmed by simulation at
  roughly 51-61% empirical coverage instead of the nominal 95% for
  `InferenceContinLin`, `InferenceContinOLS`, `InferenceContinQuantileRegr`,
  and the KK one-likelihood classes. The fallback now keys on which bound
  is being computed rather than which p-value was non-significant.
* `SurvivalDepCensTransformSource` (the dependent-censoring AFT residual
  transform) protected only the treatment column from the hardened QR
  column-dropping fallback, not the intercept — dropping the intercept
  left a severe bias under the null (mean `beta_hat` around 0.71 instead
  of about 0.005, coverage around 13% instead of 95%). Both columns are
  now protected, the same pattern already used for the Weibull-frailty
  design matrix below.
* `InferenceSurvivalStratCoxPHRegr`'s score-test information closures
  returned the raw Cox partial-likelihood Hessian unnegated. Since that
  Hessian is negative semi-definite (a concave log-likelihood), the
  "information" matrix fed to the score test was itself negative-definite,
  so the shared score-test helper's positivity check always failed —
  `compute_score_two_sided_pval()`/`compute_score_confidence_interval()`
  returned `NA` on every call, regardless of formula. Fixed to negate, as
  the sibling `InferenceSurvivalCoxPHRegr` already did.
* `get_clogit_plus_glmm_hessian_cpp()`'s exported wrapper negated an
  objective that already returns the positive information matrix (not the
  raw log-likelihood Hessian), so `InferencePropKKGLMM` and
  `InferenceIncidKKCondLogitGLMMIVWC`/`OneLik` fed the score test a
  negative-definite matrix — the same failure mode as the StratCoxPH bug
  above, reproducing an approximately 100% `NA` rate for their score test
  regardless of formula. The extra negation is removed.
* Six ordinal-response inference classes — `InferenceOrdinalAdjCatLogitRegr`,
  `InferenceOrdinalCauchitRegr`, `InferenceOrdinalCloglogRegr`,
  `InferenceOrdinalOrderedProbitRegr`, `InferenceOrdinalContRatioRegr`, and
  `InferenceOrdinalPropOddsRegr` — extracted `b[length(b)]` (the last
  covariate's slope) as the treatment coefficient instead of `b[1]`
  (treatment is always the design matrix's first column). The two coincide
  only when the model has no covariates beyond treatment; with covariates
  present, the randomization test and the Bayesian-bootstrap machinery
  silently estimated and tested a different covariate's effect instead of
  treatment's (confirmed via near-total null rejection on
  `design_formula = ~.` paths).
* The log-normal-frailty Weibull AFT model
  (`InferenceSurvivalGLMMWeibullFrailtyNormalIVWC`/`OneLik`) fit its design
  matrix with no intercept column. Without one, the control arm's baseline
  log-time was pinned at 0 and the mean-zero Gaussian frailty could only
  partly absorb it; the leftover bias (plus the Gumbel error's nonzero
  mean) leaked into the treatment estimate, inflating Wald/score/LR/
  bootstrap rejection to roughly 50-70% under the null (nominal 5%).
* The zero-inflated negative binomial kernel (`fast_zinb.cpp`) had two bugs
  in its ZIP-limit reduced fit: a fixed-parameter index was off by one, so
  the reduced fit pinned the parameter *before* the one requested (e.g.
  the intercept instead of the treatment coefficient); and the ZIP-limit
  score vector was one entry shorter than the full parameter vector and
  was not zero-padded, so score-test consumers compared it against a
  differently-sized information matrix.
* `InferenceOrdinalKKGEE` fit its GEE model on the raw, unreduced design
  matrix; rank-deficient fixtures (e.g. `~0+.` model matrices) made the
  `multgee::ordLORgee()` backend refuse the fit outright, silently
  swallowed to `NULL` (74-89% `NA` rates observed on affected data shapes).
  It now retries through the same QR-hardened rank-reduction machinery
  used elsewhere before giving up.
* Five classes' Bayesian-bootstrap machinery discarded an already-computed
  per-replicate SE for the treatment coefficient and always reported `NA`
  instead, starving their studentized/BCa variants of any SE:
  `InferenceOrdinalPropOddsRegr`, `InferenceCountQuasipoisson`,
  `InferenceCountRobustPoisson`, the glmmTMB-based weighted refit path
  shared by the zero-augmented Poisson classes, and
  `InferenceAbstractKKOrdinalCLMM` (the shared base of the KK ordinal
  CLMM classes).
* `InferenceProportionFractionalLogit` was missing quasi-binomial
  dispersion scaling, systematically overstating standard errors — 0
  rejections out of several hundred simulated replicates under the true
  null (near-zero power rather than nominal-level power).
* `InferenceIncidLogBinomial`'s Bayesian bootstrap discarded
  boundary-hitting refit replicates instead of retaining them, shrinking
  the empirical spread of the bootstrap distribution — observed test size
  25-36% instead of nominal 5%, and CI coverage 56-70% instead of 95%.
* `InferenceExtPRWSubsampling` was missing the finite-population
  correction for without-replacement subsampling, observed at roughly
  9.75% Type-I error instead of nominal 5% at a subsample fraction of
  about 0.4.
* `InferenceExtPRWSubsampling` and `InferenceExtMOutOfNBootstrap`'s
  failure gate checked only the absolute count of finite replicates
  (default minimum 5), not the fraction of the requested `B`/`m`. With
  `B` in the hundreds, a high (24%+) convergence-failure rate could still
  pass the gate, producing a falsely-precise, degenerate p-value. The gate
  now also requires a majority of replicates to succeed.
* The zero-augmented Poisson classes' shared information-matrix code now
  neutralizes the zero-inflation coefficient block when the ZI submodel's
  fitted probability collapses to its boundary, preventing inflated
  likelihood-ratio-test Type-I error in that regime.
* The KK-GEE shared mixin's QR-hardened column-dropping fallback read a
  nonexistent `attempt$X_fit` field (the correct field is `attempt$fit`),
  so the fallback candidate was never actually generated for any class
  composing that mixin (continuous/count/incidence/proportion/ordinal-KK
  GEE classes).
* The generic score test (`InferenceExtInformationMatrix`) returned `NA`
  for the large majority of calls from `InferenceContinKKGLMM` and
  `InferenceCountKKGLMM` — their null-constrained refit's
  nuisance-parameter information is positive definite only about 32% of
  the time near a variance-component boundary, which is expected behavior
  of the likelihood surface there, not a sign of a bad fit. This made the
  score test degenerate (0% Type-I error and 0% power together, rather
  than merely miscalibrated). A ridge-regularized fallback now activates
  only when the unregularized path already returned a non-finite p-value.
* `DesignFixedBlocking` silently ignored user-supplied block IDs: the
  randomization draw always re-derived blocks from the raw covariates
  instead of using the `m` a caller passed at construction.
* `InferenceSurvivalGehanWilcox` and `InferenceSurvivalLogRank` fit their
  null Cox model with the default (Efron) tie-handling, inconsistent with
  the Breslow/Nelson-Aalen convention their fast C++ kernels assume — a
  genuinely different martingale residual under tied event times. Both
  now fit with `method = "breslow"` explicitly.
* `InferenceSurvivalRestrictedMeanDiff` (RMST) never populated the
  treatment coefficient's SE on a full (non-`estimate_only`) fit, unlike
  every peer class, so bootstrap callers expecting it for a studentized
  pivot got `NA`.
* `InferenceOrdinalPairedSignTest`: an estimate is no longer `NaN`
  whenever any single pair-difference is `NA` — valid pairs are now used.
  Its bootstrap and jackknife distribution methods, previously disabled
  with an error asserting they violate the matched-pair design
  constraint, are available again.
* Bootstrap-family methods (nonparametric, m-out-of-n, subsampling, BCa)
  now refuse with an explicit error for `DesignSeqOneByOne` and its
  subclasses, except `DesignSeqOneByOneBernoulli` (whose assignments do
  not depend on prior subjects, so row resampling is valid there). These
  methods previously ran without error for sequential designs in general
  and were documented as merely "conservative"; that claim did not hold
  and has been removed along with the methods for the other sequential
  designs.
* An OpenMP worker thread (not the master) calling into R's interrupt or
  time-budget checks could raise an exception across the OpenMP thread
  boundary, crashing the whole R process (`SIGABRT`) instead of cleanly
  interrupting, under `num_cores > 1`. Both checks now no-op on any
  thread but the master.
* `InferenceSurvivalCoxPHRegr`'s internal `coxph.fit` wrapper crashed
  assigning column names to a 0-column design matrix (`length of
  'dimnames' [2] not equal to array extent`) on null-model refits — e.g.
  `compute_lik_ratio_two_sided_pval()`/`compute_score_two_sided_pval()`
  under `model_formula = ~1` — because `paste0("x", seq_len(0))` returns
  `"x"` rather than `character(0)`. The column-naming step is now skipped
  for a 0-column matrix.
* `SimulationFramework`'s `mirai`-based parallelization
  (`set_num_cores(force_mirai = TRUE)`) could hang indefinitely if a
  daemon died before connecting. Daemon launch and every
  daemon-collection call are now bounded by a deadline, with one relaunch
  attempt and a clear error in place of an unbounded wait.
* Randomization confidence intervals are no longer offered for the six
  log-hazard-ratio (Cox-family) survival classes — `InferenceSurvivalCoxPHRegr`,
  `InferenceSurvivalKKLWACoxPHIVWC`/`OneLik`, `InferenceSurvivalKKStratCoxPHIVWC`/`OneLik`,
  and `InferenceSurvivalStratCoxPHRegr` (which already refused). The generic
  randomization CI inverts an accelerated-failure-time sharp null, so its
  `delta` axis is a log *time* ratio; these classes' estimates are log
  *hazard* ratios, and the Cox model has no shape parameter linking the two.
  The search was being seeded on the wrong axis and returned bounds that
  were not a confidence interval for anything (on a Weibull test case:
  estimate −1.70, "CI" `[−1.70, −1.26]`). A direct
  `compute_rand_confidence_interval()` call now stops with an explanation,
  and `InferenceSuite` no longer lists the method for them, as for
  incidence responses. The randomization p-value and the randomization-
  bootstrap CI (a percentile interval on the estimate's own scale) are
  unchanged. AFT-scale survival classes (Weibull, marginal Weibull, Weibull
  frailty, rank regression) are unaffected.

## Documentation

* `compute_rand_confidence_interval()` documents the impute-then-permute
  construction (Rosenbaum 2002; Imbens & Rubin 2015) and, for survival
  responses, the AFT residual construction and its censoring assumptions
  (Tsiatis 1990; Wei, Ying & Lin 1990; Jin, Lin, Wei & Ying 2003).
* `InferenceOrdinalStereotypeLogitRegr`'s likelihood-ratio test
  (`compute_lik_ratio_two_sided_pval()`) now documents that it has
  inflated Type-I error (roughly 18-23% vs. a nominal 5%) for this class
  specifically (a non-regular case in the sense of Davies 1977), and
  recommends the bootstrap (~6-7%) or Bartlett-corrected (~4%) variants
  instead. The flagged method's own behavior is unchanged.
* `InferenceSuite`'s combined-evidence documentation adds a "same-Y does
  not mean same estimand" caveat: rows testing the same outcome under
  different link functions/estimands do not share one coherent null
  hypothesis under the weak (asymptotic) null, only under the
  randomization sharp null — relevant to interpreting
  `combined_evidence$pval`.

# EDI 1.0.0

Initial release of EDI (Experimental Design and Inference): a framework that
pairs randomized experimental designs — fixed-sample and sequential — with
inference procedures matched to each design and response type, so that
estimation and testing always reflect how the data were generated.

## Experimental designs

* Fixed-sample designs (all n subjects assigned at once via
  `assign_w_to_all_subjects()`): `DesignFixedBernoulli`, `DesignFixediBCRD`,
  `DesignFixedFactorial`, `DesignFixedBlocking`, `DesignFixedCluster`,
  `DesignFixedBlockedCluster`, `DesignFixedBinaryMatch`,
  `DesignFixedMatchingGreedyPairSwitching`, `DesignFixedGreedy`,
  `DesignFixedGreedyDOptimal`, `DesignFixedOptimal` and
  `DesignFixedOptimalBlocks` (mixed-integer-programming optimal designs via
  `ompr`/GLPK, with simulated-annealing and greedy alternatives), and
  `DesignFixedRerandomization`.
* Sequential one-by-one designs (each subject assigned on arrival via
  `add_one_subject_to_experiment_and_assign()`, maintaining covariate
  balance): `DesignSeqOneByOneBernoulli`, `DesignSeqOneByOneiBCRD`,
  `DesignSeqOneByOneUrn`, `DesignSeqOneByOneEfron` (biased coin),
  `DesignSeqOneByOneAtkinson`, `DesignSeqOneByOnePocockSimon`
  (minimization), `DesignSeqOneByOneRandomBlockSize`, `DesignSeqOneByOneSPBR`
  (stratified permuted block), and the Kapelner-Krieger matching-on-the-fly
  family that builds matched pairs from the accruing subject stream:
  `DesignSeqOneByOneKK14`, `DesignSeqOneByOneKK21`,
  `DesignSeqOneByOneKK21stepwise`.
* Observational designs (containers for already-observed, non-randomized
  assignments with blocking/matching structure): `ObservationalDesign`,
  `ObservationalDesignBlocks`, `ObservationalDesignMatching`.
* Custom-design extension bases for user-defined assignment rules:
  `DesignFixedCustom`, `DesignCustomSequential`.
* Unequal allocation supported; missing covariate data imputed
  automatically (`missRanger`/`missForest`).

## Response types

Six response types, each with its own matched inference classes: continuous,
incidence (binary), count, proportion (values in [0, 1]), ordinal, and
survival — the survival response supporting exact, left-censored,
right-censored, and interval-censored observations through one `y`/`y_L`/`y_R`
interface.

## Inference

* Continuous: OLS (`InferenceContinOLS`), Lin's covariate-interacted OLS,
  quantile regression, robust (Huber) regression, and for matched (KK)
  designs GLMM (`InferenceContinKKGLMM`), OLS/quantile/robust variants in
  both IVWC (inverse-variance-weighted combination) and combined-likelihood
  pooling, plus the Bai adjusted-t estimators (`InferenceBaiAdjustedTKK14`,
  `InferenceBaiAdjustedTKK21`).
* Incidence: logistic, probit, log-binomial, and identity-link binomial
  regression, Wald and exact binomial tests, Fisher's exact test, CMH,
  Newcombe and Miettinen-Nurminen risk-difference intervals, extended-Robins
  and Zhang (2026) exact test-inversion randomization CIs, g-computation
  marginal effects, modified Poisson, and conditional-logit / GLMM classes
  for matched designs.
* Count: Poisson, quasi-Poisson, robust Poisson, negative binomial,
  zero-inflated and hurdle models, composite likelihood, conditional
  Poisson, and GEE classes for matched designs.
* Proportion: beta regression, fractional logit, zero-one-inflated beta,
  quantile regression, g-computation, and matched-design GEE/quantile
  variants.
* Ordinal: proportional odds, partial proportional odds, adjacent-category
  logit, continuation-ratio, stereotype logit, ordered probit, cauchit and
  complementary-log-log links, g-computation, ridit scoring,
  Jonckheere-Terpstra, paired sign test, and CLMM-based matched-design
  classes; randomization confidence intervals for ordinal GLM effects are
  obtained by inverting the exact permutation test (following the
  Wang-Rosenberger approach).
* Survival: Cox proportional hazards (plain and stratified), Weibull AFT
  (with full censoring support), restricted mean survival time, log-rank and
  Gehan-Wilcoxon tests, Kaplan-Meier survival differences, Weibull frailty
  GLMMs (log-gamma and normal frailties), Clayton-copula and
  dependent-censoring-transform estimators, and LWA/rank-regression classes
  for matched designs.
* Cross-cutting estimators usable across response types:
  `InferenceAllSimpleAverageDiff`, `InferenceAllSimpleMeanDiffPooledVar`,
  `InferenceAllSimpleWilcox`, `InferenceAllKKMeanDiffIVWC`,
  `InferenceAllKKWilcoxIVWC`.
* Every applicable procedure at once: `InferenceSuite` runs all inference
  classes valid for a given design/response combination and reports a single
  Cauchy-combined p-value alongside the individual results.
* Custom-inference extension bases: `InferenceCustomAsymp`,
  `InferenceCustomBoot`, `InferenceCustomRand`.
* Where a specialized engine is best-in-class, estimation delegates to it —
  `glmmTMB` (GLMMs), `fixest` (fast GLMs), `aftgee` (rank-based AFT),
  `Rfit` (R-estimation), `survival` — with EDI's own C++ kernels used
  everywhere else.

## Resampling and randomization machinery

* Non-parametric, parametric, and Bayesian bootstrap; BCa intervals;
  jackknife; m-out-of-n bootstrap and Politis-Romano-Wolf subsampling;
  exchangeable-resampling-unit handling for blocked/matched/cluster
  structures; minimum-volatility CI selection.
* Randomization tests with sequential Monte Carlo p-values, custom
  randomization statistics, quantile randomization CIs, and
  randomization/bootstrap confidence intervals via parallel bisection
  test-inversion.

## Simulation framework

* `SimulationFramework` runs Monte Carlo power, size, and
  operating-characteristic studies across designs, response types, and
  inference procedures, with `coverage_pval`/`size_pval` calibration
  diagnostics; `SimulationFrameworkReport` renders results.
* Helpers `generate_covariate_dataset()` and
  `transform_cont_y_based_on_response_type()`; optional parallelization via
  `mirai` (`set_num_cores()`/`unset_num_cores()`).

## Performance

* All model-fitting and variance kernels implemented in C++ (Rcpp,
  RcppEigen/Eigen, RcppNumerical, LBFGS++, IRLS, OpenMP), exposed as
  documented `fast_*` functions — typically one to three orders of magnitude
  faster than the corresponding pure-R fits (see the shipped benchmark
  comparisons against each canonical R baseline).
* Machine-specific tuning: `tune_EDI_for_this_machine()` benchmarks the
  local machine across four axes and persists tuned performance-policy
  defaults (`get_local_EDI_optimization()`,
  `clear_local_EDI_optimization()`).
* Runtime-tunable dispatch policies for optimizer choice, cold/warm-start
  heuristics, and parallel/serial execution:
  `get_optimization_dispatch_policy()`/`set_optimization_dispatch_policy()`
  and the corresponding `*_cold_start_`, `*_warm_start_`, and
  `*_parallel_dispatch_policy()` pairs, plus
  `get_bootstrap_dispatch_policy()`.
* Install-time build configuration via environment variables
  (`EDI_PORTABLE`, `EDI_NATIVE_SPEED`, `EDI_NATIVE_LTO`, `EDI_UNITY`,
  `EDI_DISABLE_VECTORIZATION`, `EDI_DEBUG_SYMBOLS`): a tuned
  `-march=native` unity build by default locally, and a fully portable,
  warning-free build for CRAN/CI (auto-selected on r-universe builders).
* Runtime argument-checking can be disabled for production speed with
  `toggle_asserts()`.

## Documentation and extensibility

* Five concept vignettes: notation glossary; reproducibility (RNG and seed
  conventions); backend contracts (`fast_*`/C++ kernel conventions);
  validation evidence; and extending EDI with your own design and inference
  classes (backed by the design/inference class registries and the
  `DesignFixedCustom`/`DesignCustomSequential`/`InferenceCustom*` bases).
* Utilities including `create_model_matrix_from_features()`,
  `robust_negbinreg()`, `robust_survreg()`, and
  `robust_survreg_with_surv_object()`.

## Companion Python package

* The same C++ kernels are published separately for Python as
  `edi_kernels` (PyPI; pybind11, no R dependency).
