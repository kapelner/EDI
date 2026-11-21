# EDI (development version)

## Changes that alter results

* `InferenceContinKKGLMM`'s parametric bootstrap (`compute_param_bootstrap_*()`
  and the likelihood-ratio bootstrap) simulated each dataset with the residual
  and pair standard deviations swapped, so when the pair SD was near 0 the
  simulated data had almost no within-pair noise: the bootstrap CI came out
  about 40-70 times narrower than the Wald CI and the p-value sat at its floor
  (a 5% test rejected a true null 75% of the time in a small simulation; 10%
  after the fix, the likelihood-ratio bootstrap 6.7% before and 8.3% after).
  The simulator now reads the variance components in the kernel's order
  (v1.0.6-TODO-291, v1.0.6-TODO-56).

* `InferenceOrdinalPartialProportionalOddsRegr`: when a nonparallel covariate
  makes it fit through `VGAM::vglm`, the Wald standard error, CI and p-value now
  use the observed information at VGAM's estimate rather than VGAM's expected
  (Fisher-scoring) information, matching the fast solver and the `ordinal::clm`
  fallback. Estimates are unchanged; on simulated data the SE moved by a median
  of 0.1-0.8% at n = 40-300 (at most about 6%). If the observed information is
  not positive definite, the class falls back to `ordinal::clm`
  (v1.0.6-TODO-215).

* The C++ robust M fit (`method = "M"`, used by the KK robust-regression classes
  with `use_rcpp = TRUE`) now stops at once when its OLS start is an exact fit
  (median absolute residual 0), returning the start as converged, as
  `MASS::rlm` does. It used to floor the start scale at 1e-10 first, so it took
  one more weighted step; when the zero-residual points did not pin down every
  coefficient, that step moved the estimate away from `rlm`'s. Fits whose start
  has a nonzero MAD are unchanged (v1.0.6-TODO-273).
* The Bayesian-bootstrap replicates of the Cox classes now use Breslow ties,
  like their point estimates. The weighted refit behind each replicate called
  `survival::coxph()` with its default Efron ties, while every EDI Cox
  estimate uses Breslow, so on tied event times the replicates fit a different
  partial likelihood from the estimate. This affects
  `InferenceSurvivalCoxPHRegr`, `InferenceSurvivalStratCoxPHRegr`,
  `InferenceSurvivalKKStratCoxPHIVWC`, `InferenceSurvivalKKStratCoxPHOneLik`,
  `InferenceSurvivalKKLWACoxPHIVWC` and `InferenceSurvivalKKLWACoxPHOneLik`.
  Bayesian-bootstrap draws, intervals and p-values change on tied data; data
  without ties give the same results. The weighted Cox surrogate of
  `InferenceSurvivalDepCensTransformRegr` keeps Efron ties, since its estimate
  is not a Cox fit (v1.0.6-TODO-271).

* `InferenceIncidKKGEE` and `InferencePropKKGEE` no longer return NA for the
  asymptotic p-value and confidence interval, with a separation warning, just
  because one subject's fitted probability is within 1e-8 of 0 or 1. A single
  high-leverage subject can do that in a fit whose solution exists (estimate
  0.67, p NA before, p 0.45 now). That screen is now confirmed by an exact
  check that the data are (quasi-)completely separated, and results are NA
  only then. Separated fits still warn once and return NA (v1.0.6-TODO-274).

* `DesignFixedRerandomization` with `prop_acceptable` and
  `objective = "abs_sum_diff"` now filters draws when the model matrix has a
  constant column, e.g. from a `design_formula` term such as `I(x^0)`. The
  objective divided that column by its zero SD, so every draw scored `NaN` and
  the design kept the first draws unfiltered (complete randomization). A
  zero-variance column is now left unscaled and adds nothing, as on the
  `obj_val_cutoff` paths. The default `~ .` formula drops constant columns, so
  it was not affected. Other `abs_sum_diff` values can differ in the last
  digits, since the SD is now computed from centered sums (v1.0.6-TODO-276).

* Count, probit and other likelihood fits no longer report convergence too
  early, or a correct fit as unconverged, when the design is ill-conditioned or a
  covariate has a large scale or offset. The L-BFGS wrapper, Newton and the
  Poisson and probit IRLS kernels share a scale-aware Newton-decrement rule
  (glm's relative deviance tolerance); an L-BFGS stop that fails it is finished
  with damped Newton steps. Example: `InferenceCountNegBin` on `colon` gave
  -0.248 (reported converged) where `MASS::glm.nb` gives -0.211; it now gives
  -0.211. Fits that already met the gradient test are unchanged
  (v1.0.6-TODO-169, v1.0.6-TODO-170).

* `compute_wald_confidence_interval()`, `compute_wald_two_sided_pval()`,
  `get_standard_error()`, `InferenceSuite`'s `se` column and CI-inversion seeds of
  `InferenceIncidBinomialIdentityRiskDiff`, `InferenceIncidLogBinomial`,
  `InferenceContinKKGLMM` and `InferenceCountKKGLMM` now use the same standard
  error as `compute_asymp_confidence_interval()`; before, they used a different
  information matrix (or, for the Count KK GLMM, skipped the jackknife
  inflation), 1% to 26% apart (v1.0.6-TODO-220).

* `compute_rand_bootstrap_two_sided_pval()` with sequential Monte Carlo early
  stopping now applies `min_fraction_usable_samples` when `na.rm = TRUE`: it no
  longer stops on a prefix below the cap, and returns NA with reason
  `rand_bootstrap_too_few_valid_replicates_fraction` when all B draws fall below
  it (v1.0.6-TODO-219).

* On `DesignSeqOneByOneSPBR` and `DesignSeqOneByOneRandomBlockSize`, when any
  stratum holds fewer than 10 permuted blocks, the automatic jackknife unit is
  now one subject within its stratum (`"observation_within_block"`, the
  stratified delete-1 jackknife of Wolter 2007, Sec. 4.5) instead of the
  permuted block. With 2-9 blocks in the smallest stratum the permuted-block
  jackknife-Wald test was too liberal (InferenceCountPoisson, prob_T 0.2,
  n = 200, `~ 1`: size about 0.06 on both designs at a nominal 0.05, against
  0.050-0.055 deleting single subjects).
  This changes the automatic jackknife of every class on these designs;
  `unit = "permuted_block"` still deletes permuted blocks (v1.0.6-TODO-270).
* Jackknife-Wald tests and intervals on the stratified deletion units
  (`"permuted_block"`, `"observation_within_block"`: SPBR, RandomBlockSize,
  FixedBlocking and few-block `ObservationalDesignBlocks`), including the
  g-computation risk-ratio log-scale jackknife, use the t distribution with
  sum_h(n_h - 1) degrees of freedom instead of the normal. SPBR incidence
  coverage at beta 0 rises from about 0.93 to 0.95. Unstratified units are
  unchanged (v1.0.6-TODO-231).

* Subsampling and m-out-of-n p-values for ratio estimands
  (`InferenceIncidGCompRiskRatio`, `InferenceIncidKKGCompRiskRatio`,
  `InferenceIncidLogRegr`, `InferenceIncidKKGEE`, `InferenceIncidModifiedPoisson`,
  `InferenceIncidLogBinomial`, `InferenceCountPoisson`) are now symmetric: the
  share of pivot draws with |T*| >= |t|, not twice the smaller tail. At small
  subsample sizes the log-ratio draws are skewed toward the observed effect, and
  the equal-tailed rule doubled that tail, so these tests rarely rejected. Null
  size at n = 80 rose from 0.040 to 0.055 (g-computation RR subsampling) and
  from 0.015 to 0.045 (KK). Confidence intervals are unchanged (equal-tailed)
  (v1.0.6-TODO-230).

* `InferenceIncidExactZhang`'s exact confidence interval is now the convex hull
  of every effect value the combined exact test accepts (Blaker 2000; Fay 2010).
  The combined p-value is not monotone, and the interval used to be only the
  accepted piece around the search start, too narrow in about 1-2% of
  matching-design cases. An endpoint on one of the p-value's jumps is now
  reported at the jump itself (e.g. exactly 0 instead of -1e-7); other
  endpoints move by at most 1e-6. The interval takes 1.7-2.8x as long
  (v1.0.6-TODO-233).

* The g-computation risk-ratio subsampling and m-out-of-n methods now default to
  `min_fraction_usable_samples = 0.8` (was 0.95). Degenerate draws pile up in
  datasets with an extreme log RR-hat, so at 0.95, 9% (subsampling) and 29%
  (m-out-of-n) of small null datasets returned NA, including most of those
  where the Wald test rejects. At 0.8 none did, and null size was 0.040 / 0.030
  (v1.0.6-TODO-230).

* Subsampling and m-out-of-n for `InferenceIncidLogRegr`, `InferenceIncidKKGEE`,
  `InferenceIncidModifiedPoisson`, `InferenceIncidLogBinomial` and
  `InferenceCountPoisson` drop degenerate draws: a treatment arm with no events
  (logit scale: or only events; counts: a zero total), or a separated logistic
  fit. Below 80% usable draws the p-value or interval is NA with a recorded
  reason and one `edi_procedure_na_warning`. Intervals that used to be NA from
  the extreme-interval cap (up to 54% of small null datasets) are now finite
  (v1.0.6-TODO-230).

* `DesignFixediBCRD` now sets the treated count with R's `round(n * prob_T)` (a
  .5 tie goes to even), matching `DesignSeqOneByOneiBCRD`: n = 21 at
  `prob_T = 0.5` now treats 10, not 11. `DesignFixedRerandomization` with
  `prop_acceptable` at `prob_T = 0.5` and odd n now treats `round(n / 2)`, as
  its other paths and its documentation do: n = 23 now treats 12, not 11.
  Realized allocations and randomization redraws change only in these tie cases
  (v1.0.6-TODO-234).

* `InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC` no longer offers the
  Bayesian bootstrap: its replicates came from a marginal Weibull fit, not the
  class's Clayton-copula inverse-variance-weighted estimator. It now refuses,
  as the Normal IVWC class does (v1.0.6-TODO-235).

* `InferenceContinKKQuantileRegrIVWC` and `InferencePropKKQuantileRegrIVWC`
  support the Bayesian bootstrap again: each replicate refits both halves by
  weighted `quantreg::rq()` under the Dirichlet weights and pools them by
  inverse variance (v1.0.6-TODO-235).

* KK IVWC Bayesian bootstrap: replicates are now weighted refits of each class's
  own inverse-variance-weighted estimator (stratified Cox, LWA Cox, OLS,
  conditional logit, mean difference, Newcombe, rank regression). They used to
  be a raw mean difference, all zero for `InferenceSurvivalKKStratCoxPHIVWC`.
  The Bai KK14/KK21, quantile IVWC, robust IVWC, Weibull frailty Normal IVWC and
  Loggamma OneLik classes no longer offer the Bayesian bootstrap. Also fixed:
  the Weibull frailty IVWC randomization statistic (wrong fixed parameter in the
  reservoir refit, state-dependent pooling, dropped Loggamma covariates), the
  Wilcox IVWC worker returning the W statistic to m-out-of-n, subsampling and
  jackknife on fixed matched designs, and the rank-regression ISMB seed
  depending on row names (v1.0.6-TODO-217).

* The jackknife on `DesignSeqOneByOneSPBR` and `DesignFixedBlocking` no longer
  deletes whole strata (2-4 replicates; jackknife-Wald coverage about 0.84).
  SPBR now deletes one permuted block at a time (a trailing partial block is
  merged into the previous block) and `DesignFixedBlocking` deletes one subject
  at a time; both use the stratified jackknife (Wolter 2007, Sec. 4.5), so
  jackknife SEs, p-values, CIs and BCa intervals change on these designs.
  Coverage at beta = 0 is now about 0.92-0.97. Other designs are unchanged
  (v1.0.6-TODO-4).

* `InferenceIncidGCompRiskRatio` and `InferenceIncidKKGCompRiskRatio`:
  subsampling and m-out-of-n p-values and intervals now drop degenerate draws (an
  arm with no or only events, or a non-converged or separated logistic fit;
  these draws are now `NaN` in the subsampling and m-out-of-n distributions).
  They return `NA` with a recorded reason and a warning when fewer than
  `min_fraction_usable_samples` (new, default 0.95) of the draws are usable.
  These tests previously almost never rejected under the null (size 0.005 /
  0.000 at n = 80) (v1.0.6-TODO-191).

* Saved `tune_EDI_for_this_machine()` policies from earlier versions are
  ignored (tuning schema version 2), because their continuous, proportion and
  survival timings were measured on synthetic fixtures whose covariates were
  dropped as perfect predictors; run the tuner again (v1.0.6-TODO-212).

* `InferenceIncidGCompRiskRatio` and `InferenceIncidKKGCompRiskRatio`: the
  subsampling and m-out-of-n p-values and intervals now drop degenerate draws (an
  arm with no events or only events, or a non-converged or separated logistic
  fit). Kept, these draws gave log risk ratios near +/-20 and made the tests
  almost never reject (null size 0.005 and 0.000 at n = 80). When fewer than
  `min_fraction_usable_samples` (new argument, default 0.95) of the draws are
  usable, the result is `NA` with reason
  `subsampling_too_few_usable_draws_fraction` or
  `m_out_of_n_too_few_usable_draws_fraction` and one `edi_procedure_na_warning`.
  On small samples this is common: at n = 80 under the null, 9% (subsampling)
  and 29% (m-out-of-n) of data sets return `NA`. The 0.95 default is under
  review. For the risk ratio the ordinary bootstrap is the recommended
  resampling method (v1.0.6-TODO-191).

* `InferenceCountZeroInflatedNegBin` no longer accepts a fit that is not the
  maximum-likelihood fit. Its default Newton-Raphson fitter, started from a warm
  start, could stop at the zero-inflation-off negative binomial fit or on a
  separation ridge even when a fit with a higher likelihood existed. This
  happened most often on the permuted data of the randomization test (13-14% of
  draws at n = 50), which then rejected a true null about 8% of the time instead
  of 5%. A fit that looks suspect (not converged, at the zero-inflation boundary,
  a zero-inflation coefficient beyond 10 in absolute value, or a gradient norm
  above 1e-5) is now refit with L-BFGS from a cold start and from the warm
  start, and the fit with the highest likelihood is kept. This applies to every
  fit the class makes: the estimate, the tests and CIs, and the randomization
  and bootstrap draws. Point estimates can change where the old fit was not the
  maximum (they now agree with `pscl::zeroinfl()`), randomization p-values
  change, and small samples run more slowly because about half the fits at
  n = 50 need the extra refits (v1.0.6-TODO-222).

* Wald standard errors, p-values and CIs of likelihood-backed classes now always
  use the observed information; `set_information_preference()` affects only
  score tests and score CIs ("fisher" stays the default there). The only visible
  change is for the cumulative-link ordinal classes under the default "fisher"
  preference: `InferenceSuite`'s `se` column, the Wald fallback used when the fit
  has no SE, and CI-inversion step sizes now use the observed SE, so score CI
  endpoints move within the root finder's tolerance (v1.0.6-TODO-215).

* `InferenceCountPoisson`: the design-conservative tests (every asymptotic and
  likelihood test, which report the larger of the model-based and jackknife
  p-values and the union of the two intervals) lost their jackknife half on
  blocking designs whose automatic jackknife unit is the whole block, such as
  `DesignSeqOneByOneRandomBlockSize`. With fewer than 5 blocks that jackknife is
  `NA` (v1.0.6-TODO-135), so the raw Poisson test was reported alone, and it is
  anti-conservative under overdispersion: with `~ 1` on a 4-stratum design it
  rejected a true null 17-19% of the time at a nominal 5%. The class now falls
  back to the stratified delete-1 jackknife, `unit = "observation_within_block"`
  (Wolter 2007, Sec. 4.5), the estimator `DesignFixedBlocking` already uses
  automatically since v1.0.6-TODO-4, which brings the size to about 3-5%. On
  these designs p-values can rise and intervals widen. Other designs and other
  classes are unchanged (v1.1.0-TODO-218).

* `InferenceIncidBinomialIdentityRiskDiff` and `InferenceIncidLogBinomial` no longer silently drop covariates when the default cold start lies outside the mean support (v1.0.6-TODO-142). The least-squares start could give a fitted probability outside [0, 1], so the kernel stopped after one iteration and the class reported a reduced model. The start is now pulled 90% of the way to the support boundary, toward the intercept-only fit; feasible starts are untouched. Estimates, intervals and p-values change on data where the old fit failed, including some bootstrap and jackknife replicates. Bootstrap subset copies made outside an active resampling operation (for example the outer loop of `ci_calibrated_bootstrap()`) now follow the same warm-start policy as copies made inside one, instead of inheriting the parent's warm start.

* Randomization p-values (`compute_rand_two_sided_pval()`, their Monte Carlo bands, the studentized randomization-bootstrap p-values and the closed-form randomization-bootstrap CI) now count a redrawn statistic as a tie in both tails when it is within `sqrt(.Machine$double.eps)` times max(|observed|, largest |redraw|) of the observed one. Before, the tolerance was 1e-8 times |observed|, so an observed statistic of exactly 0 never caught ties at about 1e-17 (an enumerated 12-subject `InferenceOrdinalRidit` test gave p = 0.9935 instead of 1). P-values with such ties can only rise. Also: `InferenceIncidExactZhang$compute_exact_confidence_interval()` (and the `type = "Zhang"` randomization CI for incidence) now starts its endpoint search from a point the combined test accepts, so the interval inverts the test it reports; with every subject matched it used to always contain 0, and on KK designs at large n coverage was 0.85-0.88.

* `InferenceCountZeroInflatedPoisson` / `InferenceCountZeroInflatedNegBin`:
  randomization, bootstrap-randomization and parametric-bootstrap refits are no
  longer warm-started from a full-data fit whose zero-inflation part sits on a
  flat ridge (a fitted zero-inflation logit of 10 or more in absolute value);
  they are cold-started like a fresh fit. On such data every ZIP randomization
  replicate used to differ from a fresh fit (by up to 0.84), and so did half the
  ZINB ones (up to 0.64). The ZIP bootstrap-randomization reusable worker now
  equals the slow path. Results on data with a well-identified zero part are
  unchanged (v1.0.6-TODO-30).
* `InferenceCountZeroInflatedPoisson`: each fit also runs L-BFGS from
  `pscl::zeroinfl()`'s default start and keeps the fit with the lower negative
  log-likelihood. Estimates that sat at an interior local maximum change (e.g.
  1.138 to -0.466, now matching pscl); fits already at the maximum are unchanged.
  When the zero-inflation (or hurdle) part of `InferenceCountZeroInflatedPoisson`,
  `InferenceCountZeroInflatedNegBin` or `InferenceCountHurdlePoisson` has no
  finite maximum likelihood estimate, its coefficients are now reported as `NA`
  and the count-part treatment estimate is kept. If the zero-inflation part is
  only driven toward no inflation (no fitted zero-inflation probability above 5%,
  or ZINB's zero-inflation-off boundary fit), a message of class
  `edi_no_zero_inflation_message` says there is no evidence of zero inflation;
  otherwise (some subject pushed to a structural zero, and always for the hurdle
  part) a warning of class `edi_zero_part_separation_warning` (a subclass of
  `edi_logistic_separation_warning`) is raised (v1.0.6-TODO-152,
  v1.0.6-TODO-218).

* `InferenceSurvivalKKStratCoxPHIVWC`,
  `InferenceSurvivalGLMMWeibullFrailtyNormalIVWC` and
  `InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC`:
  `compute_estimate(estimate_only = TRUE)` now returns the same
  inverse-variance-weighted combination as `compute_estimate()`; it used
  sample-size weights (StratCox) or 50/50 weights (Weibull frailty). Jackknife,
  reusable-worker and slow-path resampling replicates, and the CIs and p-values
  built from them, now resample the reported estimator and change. Results from
  a fresh full call are unchanged. The Weibull frailty classes and
  `InferenceIncidKKCondLogitIVWC` also no longer lose their standard error (`NA`
  Wald CI and p-value) when `estimate_only = TRUE` was called first. Resampling
  is about 20% slower for the Weibull frailty classes (v1.0.6-TODO-132).

* `DesignSeqOneByOneKK21` and `DesignSeqOneByOneKK21stepwise` with
  `proportion_use_speedup = TRUE`: when any proportion response observed so far
  is exactly 0 or 1, every response is now compressed to (y(n - 1) + 0.5)/n
  before the logit (Smithson and Verkuilen 2006), with n the number of responses
  in the weight regression. This replaces the clamp to machine epsilon, which
  made a 0 or 1 a +/-36 logit outlier in the matching-weight t-statistics.
  Allocations change for designs with 0/1 responses and are unchanged when all
  responses are strictly between 0 and 1 (v1.0.6-TODO-60).

* Zero-augmented count models (`InferenceCountHurdlePoisson`,
  `InferenceCountZeroInflatedPoisson`, `InferenceCountZeroInflatedNegBin`,
  `InferenceCountHurdleNegBin`) now drop count-part covariates that are aliased
  on the subjects with a positive count, the same as what `glm` does with aliased
  columns, with one `edi_covariate_dropped_warning`. Previously such fits drifted
  along an unidentified direction (arbitrary ZIP/ZINB estimates, `NA` standard
  errors and CIs) or, with few positive counts, were `NA`; they now give the
  estimate of the model without those columns. Results on full-rank data are
  unchanged (v1.0.6-TODO-195).

* The cumulative-link ordinal classes (`InferenceOrdinalPropOddsRegr`,
  `InferenceOrdinalOrderedProbitRegr`, `InferenceOrdinalCauchitRegr`,
  `InferenceOrdinalCloglogRegr`) now use the expected Fisher information wherever
  "fisher" information is used; before, it was the observed information under a
  "fisher" label. This changes default score-test p-values and score CIs, and
  improves small-sample score-test size for the cauchit and cloglog links
  (n = 40: 0.092 to 0.053 for cauchit). `InferenceOrdinalPropOddsRegr` now
  offers `set_information_preference("fisher")` and uses it by default. Wald and
  likelihood-ratio results are unchanged (v1.0.6-TODO-201).

* Bootstrap, Bayesian-bootstrap and randomization-bootstrap p-values computed
  with `na.rm = TRUE` now return `NA` (reason
  `*_too_few_valid_replicates_fraction`, with one `edi_procedure_na_warning`)
  when fewer than 95% of the replicates are valid, instead of a p-value from the
  surviving replicates. The new argument `min_fraction_usable_samples` (default
  0.95; `0` turns the check off) sets the minimum. This also changes default
  calls where `na.rm = TRUE` is the default: `compute_rand_bootstrap_two_sided_pval()`,
  the KM-difference Bayesian bootstrap and the zero-augmented count classes, and
  the internal bootstrap fallbacks of the log-rank, Gehan-Wilcoxon, RMST, KK
  conditional Poisson and ordinal g-computation classes. `na.rm = FALSE` and the
  bootstrap confidence intervals are unchanged (v1.0.6-TODO-12).

* `InferenceIncidBinomialIdentityRiskDiff`: the randomization p-value is now
  reproducible and the same on the reusable-worker and slow paths.
  Warm-started refits that stalled at their start were counted as null draws
  equal to the observed estimate (about 30% of draws), and the observed
  statistic drifted between calls; a stalled fit now refits cold
  (v1.0.6-TODO-205).

* Under `set_estimand("marginal_mean_diff")` / `"marginal_ratio"`, the
  randomization and bootstrap-randomization tests of `InferencePropBetaRegr`,
  `InferenceCountPoisson`, `InferenceCountQuasiPoisson`,
  `InferenceCountHurdlePoisson`, `InferenceCountZeroInflatedPoisson` and
  `InferenceIncidLogRegr` now use the marginal statistic. Before, the observed
  statistic was the conditional coefficient while the null draws could be
  marginal, so p-values were wrong. `$capabilities()` no longer lists the
  randomization confidence intervals under a marginal estimand, where they are
  refused (v1.0.6-TODO-189).

* `InferenceIncidExactZhang$compute_estimate()` now returns the
  Haldane-Anscombe log odds ratio of the pooled 2x2 table over all subjects, as
  documented. It used only the unmatched (reservoir) subjects, so on matching
  designs it ignored the matched pairs and was always 0 when every subject was
  matched. Bernoulli designs, the exact p-values and the exact confidence
  intervals are unchanged (v1.0.6-TODO-147).

* Weibull AFT fits no longer fail on covariates left on their raw scale
  (v1.0.6-TODO-163). With columns such as age in years or lymph-node counts
  next to the intercept, the likelihood was badly conditioned and the fitter
  (`fast_weibull_regression_cpp()` and its left-/interval-censoring sibling)
  stopped at the iteration limit far from the optimum, so
  `InferenceSurvivalWeibullRegr` dropped covariates with an
  `edi_covariate_dropped_warning` and reported the reduced model. On the colon
  cancer trial of the case-study article it dropped six of eleven covariates.
  The fitter now standardizes badly scaled columns internally and maps the
  coefficients, covariance, information, score and gradient norm back to the
  original scale, so those fits keep every covariate and agree with
  `survival::survreg()`. Fits on well-scaled covariates (every column near unit
  scale) are unchanged; fits on badly scaled covariates change, including the
  Weibull classes built on the same fitter (KK marginal Weibull, GLMM Weibull
  frailty) and the Weibull randomization-bootstrap kernel.

* `InferencePropGCompMeanDiff`'s nonparametric bootstrap (confidence interval,
  p-value and `approximate_bootstrap_distribution_beta_hat_T()`) no longer
  depends on the number of cores (v1.0.6-TODO-22). Each worker chunk drew its
  resamples from its own random-number stream, so the same seed gave a
  different interval at 1, 2 and 4 cores. Every replicate's resample, and the
  seed for any redraw the separation screening asks for, is now drawn before
  the work is split. Seeded multi-core results change; single-core results
  change only for replicates that needed a redraw.

* `DesignSeqOneByOneKK14` now forms matches at the published rate
  (v1.0.6-TODO-45). Its match test compared the full d'S^-1 d with the
  Hotelling cutoff, but the statistic is half of that (the difference of two
  exchangeable subjects has covariance 2 Sigma), as SeqExpMatch computed it. The
  halving was lost in the C++ port, so KK14 was twice as strict as published and
  sent too many subjects to the reservoir. With 4 covariates, the mean number of
  pairs at n = 40 goes from 8.5 to 14.0 of 20, and at n = 100 from 31.5 to 42.0
  of 50, close to KK21. Seeded KK14 allocations change, and so does everything
  computed from them, including KK21 and KK21stepwise before they have enough
  responses to leave their KK14 fallback. To reproduce an old allocation
  approximately, pass `lambda = 0.1 * 2^(-p/2)` for p covariates.
* `InferenceIncidExactFisher` now reports the estimate as nonestimable (reason
  `"exact_fisher_conditional_mle_infinite"`) when the conditional MLE of the
  log odds ratio is infinite, as happens when the table is separated (for
  example, every discordant matched pair favors the same arm). It used to
  return `Inf` or `-Inf`, which `InferenceSuite` listed as an "ok" row. The
  exact p-value and confidence interval are unchanged.
* `InferencePropBetaRegr` bootstrap and jackknife replicates on rank-deficient
  draws (for example, a leave-one-block-out draw on a blocking design whose
  formula names the strata) now fit the right model. A warm start sized for the
  full design was passed to the reduced fit, the fit failed, and the
  column-dropping fallback then dropped a real covariate as well, which moved
  the replicate (by about 1e-3 on the logit scale in the test case). Full-data
  estimates are unchanged.
* `missingness_method = "impute"` no longer uses the outcome to impute missing
  covariates (v1.0.6-TODO-44). missRanger/missForest were given the response as
  a predictor. Treated subjects' responses are shifted, so the imputed covariate
  carried part of the treatment effect, and adjusting for it biased the
  estimate toward 0 (in one simulation, a true effect of 1 was estimated as 0.90
  with 91% CI coverage; now 1.00 and 93%). Imputation now uses the covariates
  only, and it is seeded (with the design's `seed`, else 1) without advancing
  the caller's RNG, so the same data always give the same estimate. Imputed
  values and covariate-adjusted estimates change for data with missing
  covariates. Randomization tests under the sharp null were not affected.
* `DesignFixedRerandomization` with `objective = "abs_sum_diff"` now
  standardizes each covariate by its SD on every path (v1.0.6-TODO-70). The C++
  paths always did, but the pure-R path (odd n, or `prob_T` other than 0.5) used
  raw differences, so the same `obj_val_cutoff` accepted different allocations
  depending on n. Draws change only for `abs_sum_diff` at odd n or unequal
  arms. The default `mahal_dist` is unchanged.
* Randomization p-values and intervals (`compute_rand_two_sided_pval()`,
  `compute_rand_confidence_interval()`) for inference classes whose likelihood
  is not concave (registry `likelihood_concave = FALSE`) now start every
  permutation's fit from the full-data MLE instead of chaining each fit's
  solution into the next, so one replicate that lands on a wrong local optimum
  no longer seeds the following ones. Seeded randomization results for those
  classes can change; concave-likelihood classes still chain warm starts and
  are unchanged.

* The default BCa bootstrap p-value (`compute_bootstrap_two_sided_pval()` and
  `compute_bayesian_bootstrap_two_sided_pval()`, `type = "bca"`) now returns the
  2/B floor instead of `NA` when the null value lies outside the bootstrap
  distribution, matching the percentile, symmetric and studentized types
  (v1.0.6-TODO-75, v1.0.6-TODO-114). When the BCa adjustment is on the boundary
  the p-value is still `NA` but now warns `edi_bootstrap_bca_boundary_warning`,
  like the BCa interval, and at B >= 501 that warning no longer recommends
  increasing B (v1.0.6-TODO-92).

* `InferenceSurvivalLogRank` and `InferenceSurvivalGehanWilcox` on left- or
  interval-censored data now always report treatment minus control
  (v1.0.6-TODO-117, v1.0.6-TODO-121). `interval::ictest()` orders the arms by
  which one appears first in the data, so the estimate's sign used to depend on
  whether subject 1 was treated, and bootstrap, jackknife and randomization
  draws had an essentially random sign. That broke percentile and BCa intervals
  and bootstrap p-values. Two-sided asymptotic p-values are unchanged.
* `InferenceIncidKKGEE` and `InferencePropKKGEE` now return `NA` for the
  asymptotic p-value and confidence interval, with
  `edi_logistic_separation_warning`, under (quasi-)complete separation. Before,
  the collapsed sandwich standard error gave p ~ 0. The point estimate is
  unchanged (v1.0.6-TODO-118). `InferenceOrdinalKKGEE` does the same, and the
  KK GEE jackknife methods now return `NA` with a warning (reason
  `jackknife_full_data_separation`) when the full-data fit is separated,
  instead of meaningless finite values (a jackknife estimate of the wrong sign
  was seen). The ordinal KK GEE also no longer returns a silent `NA` fit when a
  standard error is requested after an estimate-only fit on separated data
  (v1.0.6-TODO-122).
* BCa bootstrap and jackknife intervals on `DesignFixedBlocking` with a
  `design_formula` that names the strata column are no longer `NA`: the model
  matrix is now rebuilt correctly when a resample leaves a formula column
  constant (v1.0.6-TODO-108, v1.0.6-TODO-107). `InferenceContinLin` also
  rebuilt its covariates incorrectly on rank-deficient resamples.

* `InferenceSurvivalRestrictedMeanDiff`: with no user `tau`, the default
  horizon (the smaller of the arms' maximum follow-up) is now computed once
  from the observed data and held fixed in every randomization,
  randomization-bootstrap, bootstrap and jackknife draw, instead of being
  recomputed from each draw's arms. Point estimates and Wald results are
  unchanged; randomization p-values and resampling results change. The
  per-draw horizon made the null distribution compare RMSTs over different
  horizons, so the randomization test could have power below alpha at large
  effects (0.03 vs 0.99 in a simulation with n = 40). Prespecifying `tau` is
  still recommended (v1.0.6-TODO-115).
* Bootstrap intervals on left- or interval-censored survival data (RMST, the
  KM median difference, and the asymptotic intervals that fall back to the
  bootstrap) are no longer rejected as "extreme" and returned as `NA`: the
  stability check now measures the outcome's spread from the exact times,
  interval midpoints and censoring times instead of the all-`NA` exact
  response (v1.0.6-TODO-91).

* Bootstrap and jackknife replicates on rank-deficient resamples (for example
  leave-one-block-out with the strata column in `design_formula`) no longer
  fail or silently drop the covariates for about 30 regression classes
  (logistic, probit, modified Poisson, risk difference, quasi-Poisson, beta,
  the ordinal regressions, Weibull, stratified Cox, and the KK OLS, robust,
  GLMM, hurdle and conditional classes). Several of these silently fitted the
  unadjusted model on such draws; each replicate now equals a refit on the
  resampled rows (v1.0.6-TODO-123).

* Zero-inflated and hurdle Poisson/negative-binomial classes: bootstrap and
  jackknife replicates on a resample that makes a covariate constant (for
  example leave-one-block-out with the strata in the formula) are no longer
  `NA`, and the non-reusable-worker bootstrap refit no longer reuses the
  full-data covariate matrices, which R silently recycled against the resampled
  rows whenever `model_formula` is not `~ .` (v1.0.6-TODO-126).

* `InferenceSurvivalKKStratCoxPHIVWC` no longer discards the matched-pair
  stratified Cox fit when a covariate is constant within every pair (for
  example a rare binary covariate whose carriers are all in the reservoir, or a
  bootstrap or jackknife draw that omits them). Such columns are now dropped as
  `survival::coxph(strata = )` drops them, so the estimate and standard error
  combine both halves; before, the estimate came from the reservoir alone or
  was `NA`. An estimate that is still `NA` now warns (v1.0.6-TODO-128).

* Reusable bootstrap workers now redraw randomization-bootstrap assignments on
  the design's own `design_formula` matrix when the inference uses a different
  `model_formula`; covariate-aware designs (greedy, rerandomization, Atkinson,
  KK21stepwise) used to balance on the inference's columns. On rank-deficient
  draws the worker also keeps the inference's `model_formula` columns instead
  of falling back to the design's (v1.0.6-TODO-130).

* The jackknife estimate, bias, standard error, Wald p-value and Wald interval
  are now `NA` with an `edi_procedure_na_warning` (reason
  `jackknife_too_few_deletion_units`) when there are fewer than 5 deletion units
  (for example leave-one-block-out with 2 to 4 blocks). With G units the
  jackknife variance has G - 1 degrees of freedom, and the normal-reference
  Wald interval covers only 70% to 86% at G = 2 to 4. Results with 5 or more
  units are unchanged (v1.0.6-TODO-135).
* BCa bootstrap intervals and p-values (`type = "bca"`, plain and Bayesian) are
  now `NA` with an `edi_procedure_na_warning` (reason
  `bootstrap_bca_jackknife_too_few_deletion_units` /
  `bayesian_bootstrap_bca_jackknife_too_few_deletion_units`) when the jackknife
  behind the BCa acceleration has fewer than 5 deletion units (for example 2 to
  4 blocks or clusters), the same minimum as the jackknife standard error.
  Before, 2 blocks gave a finite interval with an acceleration of exactly 0.
  Results with 5 or more units are unchanged (v1.0.6-TODO-135).

* The bootstrap randomization test (`approximate_rand_bootstrap_distribution_beta_hat_T()`,
  `compute_rand_bootstrap_two_sided_pval()`, `compute_rand_bootstrap_confidence_interval()`)
  with a nonzero `delta` on left- or interval-censored survival data now
  shifts the censoring bounds `y_L`/`y_R` along with the exact times. Before,
  the null distribution ignored `delta` for censored subjects (entirely, when
  every subject was censored), so its p-values and intervals on such data were
  wrong (v1.0.6-TODO-143).

* The smoothed bootstrap randomization test and interval (`type = "smoothed"`)
  now refuse left- or interval-censored survival data with a clear error. The
  noise was added only to exact times, never to censored subjects' bounds, and
  its bandwidth came from the exact times alone. Use `type = "percentile"`
  (v1.0.6-TODO-146).

* `InferencePropGCompMeanDiff`, `InferenceIncidGCompRiskDiff` and
  `InferenceIncidGCompRiskRatio`: studentized (bootstrap-t) nonparametric and
  Bayesian bootstrap intervals and p-values were `NA` on every design (no
  standard error was exposed to the bootstrap, and weighted refits returned
  none); they now use the Wald standard error and a weighted HC0 delta-method
  standard error. Their studentized randomization-bootstrap p-values used to
  fall back to the percentile method without saying so (v1.0.6-TODO-134).

* The bootstrap and Bayesian-bootstrap "extreme interval" check no longer
  rejects wide intervals for log-ratio and link-scale estimands (log odds,
  rate, risk, hazard and time ratios; probit, cloglog, cauchit and stereotype
  effects) just because they are wider than 5 outcome SDs. Such an interval is
  now kept when it is at most 10 robust SDs (MAD) of the bootstrap replicates
  wide and both bounds are within +/-10 on the link scale. Example:
  `InferenceOrdinalPropOddsRegr` on a 10-cluster design now returns its
  bootstrap interval instead of `NA`. Separation-driven intervals are still
  rejected, and intervals that were accepted before are unchanged
  (v1.0.6-TODO-157).

* `InferenceSurvivalWeibullRegr`: when the Weibull fit fails to converge on
  unscaled covariates (for example `survival::colon`), it now refits on
  standardized columns instead of dropping covariates; results match
  `survival::survreg()`. Fits that already converged are unchanged
  (v1.0.6-TODO-161).

* The g-computation risk-ratio jackknife-Wald p-value and interval
  (`InferenceIncidGCompRiskRatio`, `InferenceIncidKKGCompRiskRatio`) now use the
  shared jackknife guards. Fewer than 5 deletion units, failed or zero
  leave-one-unit-out risk ratios, and extreme replicates now give `NA` with an
  `edi_procedure_na_warning` naming the reason, where before the result was a
  finite value (with 3 units, or intervals from 1e-13 to 1e14) or a silent
  `NA`. Results with 5 or more units and no failure are unchanged
  (v1.0.6-TODO-137).

* `InferencePropGCompMeanDiff`: the bootstrap randomization test
  (`compute_rand_bootstrap_two_sided_pval()`,
  `compute_rand_bootstrap_confidence_interval()`) built its null distribution
  from ordinary bootstrap refits on the observed assignment, so it was centred
  at the estimate and its p-values were near 1 even for strong effects. It now
  refits each fresh design assignment under the sharp null (v1.0.6-TODO-150).

* The bootstrap and Bayesian-bootstrap "extreme interval" check now always
  rejects a log-ratio or link-scale interval with a bound beyond +/-10 (a ratio
  of about 22,000), whatever the outcome's SD; large-SD counts used to let
  degenerate log-rate-ratio intervals such as [-25.8, -5.0] through. The
  g-computation risk ratio (`InferenceIncidGCompRiskRatio`,
  `InferenceIncidKKGCompRiskRatio`) is now checked on log(RR) with the same
  rule, so skewed but legitimate intervals such as [0.76, 6.5] are kept and
  degenerate ones reaching about 1e-10 are rejected (v1.0.6-TODO-160).

* Sequential designs (`DesignSeqOneByOne*`) with a non-NULL `seed` now draw
  each subject's assignment from a seed derived from (`seed`, subject index)
  and restore the session's random-number state afterwards. Allocations depend
  only on the seed and the subjects' data; random numbers used between
  assignments no longer change them; a trial saved with `saveRDS()` continues
  exactly after `readRDS()` without saving `.Random.seed`; and constructing or
  assigning no longer resets the session's stream.
  `draw_ws_according_to_design()` on a seeded sequential design is seeded too,
  so repeated calls return the same draws, as on fixed designs. Seeded
  sequential allocations differ from earlier versions; `seed = NULL` is
  unchanged (v1.0.6-TODO-177).

* The studentized and symmetric-percentile-t bootstrap randomization p-values
  of `InferenceIncidGCompRiskRatio` and `InferenceIncidKKGCompRiskRatio` now
  center at the no-effect risk ratio 1. They centered at 0, so under a true
  null the test almost never rejected (rejection rate 0.000 at 0.05, now
  0.055). `compute_rand_bootstrap_two_sided_pval()` now refuses a nonzero
  `delta` on incidence responses, as `compute_rand_two_sided_pval()` already
  did; it used to shift the 0/1 responses and return a meaningless p-value
  (v1.0.6-TODO-151).

* `InferencePropZeroOneInflatedBetaRegr`'s bootstrap randomization test now
  builds its null from the fresh design draw. Its reused-worker fast path had
  fitted the observed treatment column against the sharp-null responses, so
  the null draws were centred at the estimate (p about 0.85 where the
  randomization test gave 0.01). Its bootstrap-randomization p-values and CIs
  change; plain bootstrap results do not (v1.0.6-TODO-167).

* For `InferenceIncidGCompRiskRatio` and `InferenceIncidKKGCompRiskRatio`, the
  bootstrap stability checks now judge the risk ratio on log(RR) everywhere: a
  few replicates with near-zero control risk no longer make the percentile/BCa
  interval NA; subsampling and m-out-of-n intervals reaching a ratio beyond
  e^10 (e.g. [3e-5, 2.8]) are now NA with a warning; and the basic bootstrap
  and basic/Wald Bayesian-bootstrap intervals now run the extreme-interval
  check, so degenerate intervals such as [1.4e-8, 20] are no longer returned
  silently (v1.0.6-TODO-175).

* `InferencePropZeroOneInflatedBetaRegr` under `estimand =
  "marginal_mean_diff"`: the randomization and randomization-bootstrap
  p-values now use the marginal mean difference as their statistic; they used
  the conditional coefficient, and the randomization-bootstrap p-value compared
  it against marginal null draws. Switching estimands with `set_estimand()`
  now discards cached resampling distributions and workers from the previous
  estimand, for every class with a marginal estimand. Randomization and
  randomization-bootstrap confidence intervals are refused under any marginal
  estimand (error class `edi_rand_ci_estimand_scale_mismatch_refused`),
  because they invert a logit or log shift whose bounds are not on the
  estimand's scale (v1.0.6-TODO-184).

* `InferenceOrdinalGCompMeanDiff` and `InferenceOrdinalStereotypeLogitRegr`
  now centre and scale covariates internally like the other ordinal classes,
  so their estimates no longer depend on covariate units or offsets. The
  g-computation mean difference could be badly off (0.26 vs 0.19 on the
  `colon` data), and the stereotype fit could stop at a worse optimum or drop
  every covariate and return NA (v1.0.6-TODO-172).

* Seeded randomization-bootstrap p-values that draw each replicate's
  assignment lazily (`type = "smoothed"`, and the percentile path for classes
  without a fast kernel or reusable worker) no longer depend on
  `set_num_cores()`: each draw now replays its own seed. Results at
  `num_cores = 1` change by Monte Carlo noise on these paths
  (v1.0.6-TODO-53).
* Randomization distributions of iteratively fitted models no longer chain
  warm starts between permutations: every permutation starts from the
  full-data fit, so seeded results no longer depend on `set_num_cores()`.
  `num_cores = 1` values change at the optimizer-tolerance level
  (v1.0.6-TODO-61).
* glmmTMB fits (hurdle negative binomial, the zero-augmented Poisson family,
  the KK GLMM classes) now run TMB on one thread, so their estimates and every
  bootstrap replicate no longer depend on `set_num_cores()`
  (v1.0.6-TODO-62, v1.0.6-TODO-64).

* Hurdle and zero-inflated count models (`InferenceCountHurdlePoisson`,
  `InferenceCountHurdleNegBin`, `InferenceCountZeroInflatedPoisson`,
  `InferenceCountZeroInflatedNegBin`) now report the treatment effect as
  non-estimable when the positive counts do not identify the count-part
  treatment coefficient (e.g. a single positive count). The fit used to return
  its starting values, so the estimate was arbitrary and the randomization
  null distribution collapsed to a constant equal to it (v1.0.6-TODO-186).

## New features

* The generic subsampling and m-out-of-n p-value and CI methods take
  `min_fraction_usable_samples` (default 0.8), the usable-draw cap for ratio
  estimands (LogRegr, KKGEE, ModifiedPoisson, LogBinomial, CountPoisson); other
  classes ignore it (v1.0.6-TODO-269).

* `InferenceSuite$run_all_inference()` gains `r` (draws for the randomization
  and randomization-bootstrap tests and CIs) and `B` (replicates for the
  nonparametric, Bayesian and parametric bootstrap and the parametric-bootstrap
  likelihood-ratio tests and CIs). Both default to `NULL`, which keeps each
  method's own default, and are recorded in the result as `resample_counts`
  (v1.0.6-TODO-210).

* `InferenceIncidGCompRiskRatio` and `InferenceIncidKKGCompRiskRatio` gain
  `type = "symmetric-percentile-t"` in
  `compute_bayesian_bootstrap_confidence_interval()`: a symmetric studentized
  Bayesian-bootstrap interval built on the log risk ratio. It covers better in
  small samples than `type = "studentized"`, which is built on the raw ratio
  scale and undercovers (about 0.89 at n = 60); the class docs now say so
  (v1.0.6-TODO-168).

* The randomization test (`compute_rand_two_sided_pval()` with a nonzero
  `delta`) and the randomization confidence interval now work on left- and
  interval-censored survival data: the null shift rescales the treated
  subjects' censoring bounds `y_L`/`y_R` by exp(delta) as it rescales exact
  times (bounds of 0 and `Inf` stay put). Before, both refused with an error.
  This makes the Weibull randomization interval for the time ratio available
  on interval-censored data (v1.0.6-TODO-143).

## Bug fixes

* `InferenceSuite$run_all_inference()`: the per-estimand summary printed
  `p = NA` for every estimand with a single inference class; it now prints that
  class's own p-value (v1.0.6-TODO-312).

* `InferenceSurvivalKMDiff$compute_asymp_two_sided_pval()` no longer returns
  `NA` when a few bootstrap replicates of its fallback are non-finite while the
  asymptotic CI (which drops them) is finite; both fallbacks now drop them
  (v1.0.6-TODO-309).

* `fast_weibull_regression(use_rcpp = FALSE)` now fits a covariate matrix with
  an empty or duplicated column name (e.g. `cbind(w, d$age)`), or columns named
  `y` / `dead`, instead of stopping with "failed to converge", and reports other
  survreg errors as such (v1.0.6-TODO-307).

* `InferenceIncidExactFisher$compute_estimate()` now warns (class
  `edi_procedure_na_warning`) when it returns `NA` because an arm has no events
  and the conditional MLE is infinite, and names the cause; the exact CI and
  p-value are unchanged (v1.0.6-TODO-306).

* `DesignFixedFactorial` now requires `factors` to be a fully named list of whole
  numbers >= 2. `list(subject = 2.5)` used to run as a two-level factor and an
  unnamed list got the name `Var1` (v1.0.6-TODO-305).

* `assign_w_to_all_subjects(w_precomputed = )` on fixed designs now checks the
  vector: numeric or logical, length n, no `NA`, only 0 and 1, both arms, and on
  cluster designs the same value within every cluster. A 1/2-coded vector used
  to be stored and give `NA` estimates silently (v1.0.6-TODO-300,
  v1.0.6-TODO-301).

* `DesignFixedBlocking`: the unequal-block-size error no longer says
  `B_target` was not given when it was, and no longer advises `B_target` for
  categorical strata, whose categories fix the block sizes (v1.0.6-TODO-73).

* `DesignFixedOptimal(objective = "abs_sum_diff")` with the default
  `solver = "auto"` could run for many minutes with no message (n = 40). The
  exact MILP now gets `solver_args$milp_time_limit` seconds (default 30, GLPK);
  after that the design uses the better of the MILP incumbent and an annealing
  run and says so, with certificate `"annealing_converged"` (v1.0.6-TODO-296).
* `DesignFixedOptimal$get_optimization_diagnostics()$objective_value` is now


  the documented M(w) for `"mahal_dist"` and `"abs_sum_diff"`. It was the
  solver's internal value, M(w) times 4 n_T^2 n_C^2 / n^4 or 2 n_T n_C / n^2 (a
  quarter and a half at prob_T = 0.5). The solver value is kept as
  `objective_value_internal`; allocations are unchanged (v1.0.6-TODO-297).
* `InferenceSuite$run_all_inference()` with `max_secs_per_class` and more than


  one core printed the report and then failed with "arguments imply differing
  number of rows", losing every result, whenever a class timed out: the
  timeout row had no `tau`. Such rows now get `NA` there and the results table
  is always built (v1.0.6-TODO-292).

* `DesignSeqOneByOneKK14`, `DesignSeqOneByOneKK21` and `DesignSeqOneByOneKK21stepwise`
  now reject `lambda` or `t_0_pct` outside [0, 1] (or `NA`) at `$new()`. They used
  to construct and then fail partway through the trial, or never match
  (v1.0.6-TODO-290).

* Sequential designs: when `add_one_subject_to_experiment_and_assign()` fails
  (for example a covariate refused by `missingness_method = "error"`), the
  subject is no longer left enrolled with no assignment. The design is rolled
  back to its state before the call, so a corrected retry continues the trial
  as if the failed call never happened (v1.0.6-TODO-316).

* `approximate_bootstrap_distribution_beta_hat_T(bootstrap_type = ...)` cached
  its draws by `B` alone, so on blocking designs a call with one
  `bootstrap_type` returned the draws of an earlier call with another, and a
  diagnostic call changed a later `compute_bootstrap_confidence_interval()` or
  p-value. The cache (and the randomization-bootstrap one) is now keyed by the
  bootstrap type too (v1.0.6-TODO-299).

* `InferenceAllSimpleMeanDiffPooledVar`: after a randomization p-value or CI,
  the asymptotic p-value and CI came back `NA` with no warning, because the
  randomization path cached the estimate without the per-arm responses the
  pooled t statistic reads. They are now rebuilt from the data, so the result
  no longer depends on which procedure ran first (v1.0.6-TODO-293).

* `InferenceIncidBinomialIdentityRiskDiff` / `InferenceIncidLogBinomial`: the
  constrained binomial fitters switch to observed-information Newton steps after
  20 iterations when Fisher scoring is slow near (not on) a mean bound. A fit that
  used to hit the iteration cap, drop covariates and report a different estimate
  (0.083 vs the MLE 0.167) now reaches the MLE (v1.0.6-TODO-267).

* The cumulative-link ordinal fitters (`fast_ordinal_regression*_cpp`,
  `fast_ordinal_{probit,cauchit,cloglog}_regression*_cpp`) no longer return a
  `fisher_information` field: it held the observed Hessian, not the expected
  information. Use `observed_information` / `information` (v1.0.6-TODO-215).

* `InferenceRandCustom` at a nonzero `delta` now tests a coherent sharp null on
  survival, count and proportion responses, and with `transform_responses = "log"`
  or `"logit"`. Each draw used to re-add `delta` additively although it had been
  removed on the log (survival, count) or logit (proportion) scale, so the
  reference distribution matched no null (proportion draws could leave [0, 1]).
  The draws now re-apply `delta` on the same scale, exactly as the built-in
  classes do. The survival randomization CI now evaluates the statistic on the raw
  times and inverts the class's own p-value, so it is an interval for the log time
  ratio (it used to pass log times to the statistic). Continuous responses under
  the default are unchanged (v1.0.6-TODO-286).

* `ObservationalDesignBlocks` with fewer than 5 blocks now jackknifes one
  subject at a time within blocks (treated as strata) instead of leaving out
  whole blocks, which gave NA (v1.0.6-TODO-231).

* `approximate_subsampling_distribution_beta_hat_T(debug = TRUE)` and the
  m-out-of-n equivalent now mark degenerate ratio draws NaN like the default
  path, and report `num_degenerate` (v1.0.6-TODO-230).

* The identity- and log-binomial regression kernels (and their weighted
  variants) no longer report convergence short of the maximum likelihood
  estimate when a start lies next to a mean bound: convergence now also
  requires the observed-information Newton step to agree, so
  `InferenceIncidBinomialIdentityRiskDiff` and `InferenceIncidLogBinomial`
  randomization and bootstrap draws reach the MLE (v1.0.6-TODO-221).

* `InferenceOrdinalOrderedProbitRegr` returns NA instead of 0 when the response
  has a single level, and its bootstrap no longer counts single-level draws as
  zero estimates. The cauchit, cloglog and probit kernels now agree on these
  edge cases: they validate inputs before the one-level early return and report
  a non-positive treatment variance as NaN (v1.0.6-TODO-203).

* `DesignSeqOneByOneRandomBlockSize`: the jackknife now deletes one permuted
  block at a time (blocks are recorded at assignment; a trailing unfilled block
  is merged into the previous one) and pools within strata. It used to delete
  whole strata, which left 2-4 replicates and an NA jackknife
  (v1.0.6-TODO-231).

* BCa bootstrap intervals and p-values on `DesignFixedBlocking` take their
  acceleration from the within-stratum (stratified) jackknife influence values
  (v1.0.6-TODO-231).

* `InferenceCountZeroInflatedPoisson` also tries an L-BFGS start with a sharpened
  zero part, so small-sample fits that stopped unflagged at an interior local
  maximum below a separated zero-inflation ridge now reach the higher likelihood
  and carry the zero-part separation warning. ZIP fits are about 1.8x slower
  (v1.0.6-TODO-232).

* `set_estimand()` and `get_supported_estimands()` on inference classes that
  cannot switch estimands (e.g. `InferenceCountNegBin`,
  `InferenceCountZeroInflatedNegBin`, `InferenceCountHurdleNegBin`) now stop with
  a clear error of class `edi_estimand_not_supported` instead of "attempt to
  apply non-function"; `get_estimand()` returns `"conditional"` on every class
  (v1.0.6-TODO-208).

* `DesignSeqOneByOneiBCRD`: when `n * prob_T` ends in .5 (e.g. n = 21,
  `prob_T = 0.5`), randomization redraws had one more treated subject than the
  realized trial, because the two rounded the tie differently; redraws now use
  the realized treated count, so randomization p-values and CIs use the correct
  null. Realized assignments are unchanged (v1.0.6-TODO-213).

* `InferenceIncidExactZhang$compute_exact_confidence_interval()` on a matching
  design now returns `NA` bounds with an `edi_procedure_na_warning` (reason
  `exact_ci_empty_acceptance_set`) when the matched-pair and reservoir parts of
  the combined exact test reject every log odds ratio; before, it returned a
  near-zero-width interval at a rejected point. When the search's starting
  points are all rejected, a grid search now finds an accepted region the old
  search missed (v1.0.6-TODO-216).

* Hurdle count models (`InferenceCountHurdlePoisson`, `InferenceCountHurdleNegBin`,
  the KK hurdle-Poisson classes): when every positive count in one arm equals 1,
  the count-part treatment estimate is now `NA` with an
  `edi_hurdle_count_mle_not_finite_warning` (its MLE is infinite) instead of the
  optimizer's stopping point (v1.0.6-TODO-195).
* The KK hurdle-Poisson classes now drop count covariates aliased on the
  positive rows (the same as what `glm` does) and return `NA` when those rows do
  not identify the treatment, instead of an arbitrary estimate
  (v1.0.6-TODO-195).
* The zero-augmented and hurdle count kernels check their inputs; `y =
  numeric(0)` and mismatched input lengths no longer crash R or return a
  converged-looking fit of garbage (v1.0.6-TODO-195).
* `InferenceCountHurdleNegBin` now warns when its hurdle part is separated
  (`edi_zero_part_separation_warning`) (v1.0.6-TODO-218).

* `InferenceSuite$run_all_inference()` is now reproducible after `set.seed()`:
  each task runs from its own seed, drawn once from the caller's stream, with no
  randomization draws carried over from earlier tasks, runs or direct calls on
  the same design, and `num_cores = 2` gives the same results as
  `num_cores = 1`. Seeded suite results differ from earlier versions. A user `B`
  below 5 now errors before fitting when a bootstrap method runs
  (v1.0.6-TODO-219).

* `InferenceIncidLogBinomial`'s randomization statistic is now the cached point
  estimate, so it matches the reusable worker and repeated seeded calls agree.
  The constrained log- and identity-binomial kernels now redo a fit from the
  cold start when a warm Fisher information from other data makes the first
  step fail, instead of returning the warm start unconverged (v1.0.6-TODO-209).

* `compute_rand_bootstrap_two_sided_pval(na.rm = FALSE)` now returns `NA` on
  any invalid null draw on every path. The studentized and sequential Monte
  Carlo paths used to drop such draws silently, and the percentile and smoothed
  paths returned an `NA` without a warning; each case now raises one
  `edi_bootstrap_nonfinite_na_warning` (v1.0.6-TODO-214).

* The logistic regression kernel (`fast_logistic_regression_cpp`,
  `_weighted_cpp`, `_with_var_cpp`) now reruns a non-converging IRLS fit with
  step halving, so a poor warm start (e.g. in the g-computation bootstrap
  refits) converges instead of running to |b| ~ 1e9. When the absolute gradient
  test fails, it also accepts a scale-aware Newton-decrement criterion, so fits
  with large-offset covariates are no longer reported as not converged. Fits
  that converged before are unchanged (v1.0.6-TODO-192, v1.0.6-TODO-170).

* In that step-halving rerun the step taken at the last allowed iteration is
  now checked too. A fit that hit `maxit` could return a log-likelihood far
  below its starting point (e.g. -36768 against -408 from a far warm start at
  `maxit = 1`); it now never returns a worse fit than it started from. A fit
  that stops at `maxit` also reports its fitted probabilities, score, gradient
  norm and Fisher information at the returned coefficients; before, they
  belonged to the iterate one step earlier, even when the fit was declared
  converged. Coefficients of converged fits are unchanged (v1.0.6-TODO-272).

* The parametric-bootstrap likelihood-ratio confidence interval's `NA`
  reasons (`lik_ratio_bootstrap_ci_pval_at_estimate_unavailable`,
  `..._rejects_at_estimate`, `..._bound_not_found`) are now recorded under
  `procedure_failure_reason[["lik_ratio_bootstrap_ci"]]`, keeping the Wald
  estimate and standard error, as other resampling procedures do
  (v1.0.6-TODO-210).

* The g-computation risk-ratio and risk-difference classes
  (`InferenceIncidKKGCompRiskRatio` / `RiskDiff`, `InferenceIncidGCompRiskRatio`
  / `RiskDiff`) no longer reuse a non-converged weighted refit as the starting
  point for the next bootstrap replicate. In the KK classes one such fit made
  every later Bayesian-bootstrap replicate return RR = 1 (RD = 0) with an NA
  standard error, causing undercoverage and non-finite intervals. A failed refit
  is now retried from the full-data fit and then cold, and is never cached
  (v1.0.6-TODO-192).

* The parametric-bootstrap LR p-value and CI, the parametric-bootstrap
  estimate, CI and p-value, and the m-out-of-n and subsampling p-values now
  warn (`edi_procedure_na_warning`) when they return `NA`, instead of returning
  a silent `NA` (for example an LR-bootstrap CI with `B` too small to reach
  alpha). The resampling flag now covers only their replicate loops, so on a
  not-yet-fitted object parametric-bootstrap results can differ at about 1e-10
  and now match the results on an already-fitted object (v1.0.6-TODO-207).

* The Bayesian-bootstrap `type = "wald"` p-value now warns
  (`edi_procedure_na_warning`, reason
  `bayesian_bootstrap_standard_error_unavailable`) instead of returning a silent
  `NA` when the draws have no spread. Resampling methods now restore an outer
  resampling operation on exit instead of clearing it, so nested calls no
  longer turn on warnings that should be silent (v1.0.6-TODO-185).

* When fewer than 10 randomization draws were requested, the randomization
  p-value's NA warning (`randomization_too_few_finite_estimates`) now says to
  increase `r` instead of blaming the estimator (v1.0.6-TODO-202).

* `InferenceIncidGCompRiskDiff`, `InferenceIncidGCompRiskRatio` and `InferencePropGCompMeanDiff` now reject
  `prob_clip_eps = 0.5` (and `prob_clip_strong_eps = 0.5`), as documented: the clamps must be in `[0, 0.5)`.
  At 0.5 every fitted probability was clipped to 0.5.

* `DesignSeqOneByOneKK14`, `DesignSeqOneByOneKK21` and
  `DesignSeqOneByOneKK21stepwise` no longer fail with "object not found" when
  `design_formula` names a covariate that is still constant among the subjects
  enrolled so far, and KK14/KK21 no longer fail when no covariate varies yet
  among earlier subjects (v1.0.6-TODO-107).
* `DesignSeqOneByOneKK21stepwise` no longer errors ("missing values and NaN's
  not allowed" in `quantile()`) when the responses so far are constant or fit
  exactly by the covariates (for example with a single covariate, or all-zero
  counts). The covariate weights fall back to equal weights, as
  `DesignSeqOneByOneKK21` already did (v1.0.6-TODO-120, v1.0.6-TODO-63).
* `InferenceIncidLogRegr`, `InferenceIncidProbitRegr` and the logistic
  g-computation classes (`InferenceIncidGCompRiskDiff`/`RiskRatio`,
  `InferenceIncidKKGCompRiskDiff`/`RiskRatio`) now warn
  (`edi_logistic_separation_warning`, once per object, never inside resampling)
  when fitted probabilities are numerically 0 or 1, i.e. under (quasi-)complete
  separation. Estimates are unchanged (v1.0.6-TODO-109, v1.0.6-TODO-119).
* `InferenceRandCustom` on incidence responses: a C++ statistic now gives the
  randomization p-value at `delta = 0` (it was refused), and an R-function
  statistic now refuses a nonzero `delta` like every other form
  (v1.0.6-TODO-110, v1.0.6-TODO-81).
* `InferenceRandCustom` now warns, naming the statistic argument, when the
  custom statistic (R or C++) is not finite on the observed data, instead of
  silently returning `NA` (v1.0.6-TODO-111).
* `InferenceSurvivalKMDiff` now warns, naming the arm, when a Kaplan-Meier
  median is not reached (all results are `NA`; use
  `InferenceSurvivalRestrictedMeanDiff`), and explains a jackknife-Wald `NA`
  (the jackknife is unreliable for medians; use the bootstrap)
  (v1.0.6-TODO-112).
* `NA` results that EDI recorded on the object without a warning now warn with
  a classed warning carrying `procedure` and `reason` fields
  (`edi_procedure_na_warning`, or `edi_unsupported_procedure` when the
  procedure is unsupported): asymptotic inference for count-likelihood classes
  on blocked-cluster designs, bootstrap intervals rejected as numerically
  extreme, jackknife results that are not estimable, and jackknife or BCa
  results on blocking designs whose deletion unit is unsupported (the warning
  names `unit = "block"`) (v1.0.6-TODO-113, v1.0.6-TODO-108, v1.0.6-TODO-74).
* The BCa bootstrap interval and p-value (plain and Bayesian) now warn once
  per object with `edi_bootstrap_bca_unstable_warning` (suggesting
  `type = "percentile"`) when they are `NA` because the BCa bias correction or
  acceleration is unstable; that `NA` used to be silent (v1.0.6-TODO-116).
* `DesignSeqOneByOneKK14`, `DesignSeqOneByOneKK21` and
  `DesignSeqOneByOneKK21stepwise` now warn when `morrison = TRUE` is passed
  (v1.0.6-TODO-46). The Morrison threshold calibration is not implemented, so
  the argument was silently ignored and the standard `lambda`/`t_0_pct`
  schedule ran; the documentation now says the argument is reserved.
* `get_block_ids()` on a sequential matching design no longer errors with
  "improperly sized" before the trial is full; it returns the match ids of the
  subjects enrolled so far (v1.0.6-TODO-46).

* `DesignFixedRerandomization` now errors at construction on an `objective`
  other than `"mahal_dist"` or `"abs_sum_diff"`. Before, an unknown value
  silently ran as `abs_sum_diff` on the fast path (v1.0.6-TODO-70).
* `DesignSeqOneByOneEfron` now requires `0.5 < weighted_coin_prob <= 1`
  (1 is Efron's deterministic limit). Values above 1 used to give `NA`
  assignments (v1.0.6-TODO-70).
* The C++ robust-regression kernel (`fast_robust_regression_cpp()`, used when
  `use_rcpp = TRUE`, the default) now computes the same estimator as
  `MASS::rlm()`. Results change for `InferenceContinRobustRegr`,
  `InferenceContinKKRobustRegrIVWC`, `InferenceContinKKRobustRegrOneLik` and the
  robust randomization/bootstrap kernel:
  * With `method = "M"`, the estimate changes. The kernel fixed the MAD scale
    once, from the OLS residuals (which outliers pull), where `rlm()`
    re-estimates it every iteration, and it stopped on the change in the
    coefficients rather than in the residuals. The two paths differed by about
    1% (up to 6%); they now agree to rounding error. The default
    `method = "MM"` keeps its fixed scale, so its estimates do not change.
  * With either method, the standard error now includes the small-sample
    factor kappa that `summary.rlm()` applies, so standard errors are slightly
    larger, and the KK IVWC classes' inverse-variance weights change with them.
  * The KK robust classes' default `maxit` is 100 for every number of
    covariates (it was 10 to 20, below what `rlm()` needs once the scale is
    re-estimated). A fit that still does not converge now gives `NA`, as the
    `use_rcpp = FALSE` path already did, instead of the unconverged iterate.

* Bootstrap randomization tests with `DesignSeqOneByOneAtkinson`, or with
  `DesignSeqOneByOneKK21stepwise(condition_on_ws_for_rand_tests = FALSE)`, no
  longer fail (Atkinson) or ignore the covariates (KK21stepwise) on a bootstrap
  resample that leaves a covariate constant: the redraw now rebuilds the
  design's model matrix first (v1.0.6-TODO-129).

* `InferencePropGCompMeanDiff`: the leave-one-block/pair-out jackknife (and
  BCa on blocked designs), subsampling and m-out-of-n bootstrap no longer
  return all-`NA` on blocked or matched designs (and, for subsampling and
  m-out-of-n, on every design); the worker now reads row indices from
  list-shaped resampling draws (v1.0.6-TODO-127).

* `compute_rand_two_sided_pval()` now returns `NA` when fewer than
  `max(10, floor(r/10))` randomization draws are finite on the cached
  affine-reuse path too (it required only one), matching the uncached path and
  the documentation (v1.0.6-TODO-124).

* `InferenceSurvivalRestrictedMeanDiff`: a user `tau` is no longer wrongly
  refused on left- or interval-censored data when an arm's largest time is an
  exact event. Warnings that suggest other procedures (the bootstrap "extreme
  interval" `NA` and `edi_cluster_independence_warning`) now name only
  procedures the class supports (v1.0.6-TODO-125).

* `InferenceSurvivalKKStratCoxPHIVWC`: the reservoir's treatment-only fallback
  Cox fit now passes the same usability check as the other reservoir fits, so
  a separated reservoir (infinite coefficient) is dropped, with
  `edi_kk_strat_cox_ivwc_reservoir_dropped_warning`, instead of entering the
  estimate. A reservoir with an empty arm no longer triggers a hidden error
  and is dropped with the same warning, since it carries no treatment
  contrast (v1.0.6-TODO-133).

* `InferenceSurvivalKMDiff` on interval-censored data: the asymptotic interval
  and p-value (which fall back to the bootstrap there) are now finite (fixed
  with v1.0.6-TODO-91), and `compute_bayesian_bootstrap_two_sided_pval()` now
  stops with a clear error instead of returning a silent `NA`, since the
  interval-censored Turnbull fit takes no weights (v1.0.6-TODO-90).

* The bootstrap and randomization-bootstrap refits that copy the inference
  object for each draw (used when the reusable worker is off) now take the
  draw's rows of the design's `y_L`, `y_R` and `y_original`, and clear every
  other private cache still holding the parent's rows. Randomization-bootstrap
  null draws on interval-censored data were all `NA` for the Weibull and
  log-rank classes and wrong for the KM median difference
  (v1.0.6-TODO-131).

* When a model's fit with all covariates fails (for example a coefficient
  diverges under separation) and the hardened refit drops covariates, EDI now
  warns once per object (`edi_covariate_dropped_warning`, fields `dropped`,
  `reason`, `diverged`), naming the dropped columns; `InferenceIncidProbitRegr`
  and the other GLM, g-computation, ordinal and survival classes used to report
  the reduced model silently. Columns dropped only for collinearity are still
  silent, and no estimates change (v1.0.6-TODO-138).
* The studentized (bootstrap-t) bootstrap and Bayesian-bootstrap p-values now
  warn (`edi_procedure_na_warning`) instead of returning a silent `NA` when
  standard errors are missing or unstable, as the studentized interval already
  did; values are unchanged (v1.0.6-TODO-140).

* The Bayesian bootstrap (interval, p-value and draw distribution) now stops
  with a clear error on left- or interval-censored data for
  `InferenceSurvivalKMDiff`, `InferenceSurvivalRestrictedMeanDiff`,
  `InferenceSurvivalGehanWilcox`, `InferenceSurvivalLogRank` and
  `InferenceSurvivalWeibullRegr`, whose interval-censored fits take no case
  weights, instead of returning `NA` with a misleading reason (or, for the RMST
  p-value, a silent `NA`). Right-censored data are unaffected
  (v1.0.6-TODO-141).

* `DesignFixedBlockedCluster` now accepts blocks with different numbers of
  subjects or clusters; it used to error and suggest an `equal_block_sizes`
  argument it does not have. The unequal-blocks error of the other blocking
  designs now names only arguments the class takes (v1.0.6-TODO-73).
* `InferenceCountZeroInflatedPoisson` and `InferenceCountZeroInflatedNegBin`
  now accept `smart_cold_start_default`, like their hurdle siblings
  (v1.0.6-TODO-153). `InferenceIncidRiskDiff` records a class-specific
  non-estimability reason when one is set (v1.0.6-TODO-156).
* `InferenceSurvivalKMDiff` on left- or interval-censored data now warns
  (`edi_km_median_not_reached_warning`) when an arm's Turnbull median is not
  reached, naming the arm and its lowest survival and suggesting
  `InferenceSurvivalRestrictedMeanDiff`; its jackknife-Wald `NA` now gives the
  median-specific `edi_km_jackknife_na_warning` (v1.0.6-TODO-144).
* The reproducibility vignette and the `Design` documentation now state what a
  design's `seed` guarantees: fixed designs re-seed on every draw, while
  sequential designs seed once at construction, so an exact continuation after
  a restart needs the saved `.Random.seed` (v1.0.6-TODO-79).

* `InferenceRandCustom` now errors when the custom statistic returns other
  than exactly one value, instead of silently keeping the first
  (v1.0.6-TODO-83); its refusal of randomization intervals on count and
  proportion responses no longer points to a randomization-bootstrap interval
  the class does not have (v1.0.6-TODO-84).

* A plain-bootstrap BCa interval that is `NA` because the adjusted tail falls
  on the boundary now warns when some bootstrap draws were non-finite (for
  example a cluster resample with no treated or no control cluster). It was
  silently `NA NA` before, including on `DesignFixedCluster` with 5 or more
  clusters. Finite intervals are unchanged (v1.0.6-TODO-162).

* Randomization, bootstrap and Bayesian-bootstrap p-values that return `NA`
  (too few finite draws or replicates, implausibly extreme replicates, or a BCa
  p-value that cannot be computed) now warn once with the reason
  (`edi_procedure_na_warning`) instead of returning a silent `NA`. Randomization
  interval searches no longer repeat the p-value warning for every `delta` they
  try; the interval warns once if it ends `NA`. Values are unchanged
  (v1.0.6-TODO-136, v1.0.6-TODO-145).

* Inference objects now detect covariates that make the response (on a scale
  suited to its type) an exact linear function of treatment and covariates,
  which in a randomized experiment almost always means leakage. They drop those
  columns from every fit and resampling replicate and raise one
  `edi_perfect_predictor_warning` naming them. Results on data without a
  perfect predictor are unchanged (v1.0.6-TODO-158).

* Sequential designs created with `n = NULL` now work: KK14/KK21/KK21stepwise
  no longer crash once covariates are available (with no planned `n`, matching
  starts once the covariate model matrix exists), such designs can be analyzed
  (including the bootstrap) once every enrolled subject has a response, and
  responses can be added in any order. A response for a subject who has not
  arrived is refused with a clear message (v1.0.6-TODO-76, v1.0.6-TODO-77,
  v1.0.6-TODO-78).

* `InferenceOrdinalGCompMeanDiff`, `InferenceIncidKKGCompRiskDiff` and
  `InferenceIncidKKGCompRiskRatio`: the studentized (bootstrap-t) Bayesian
  bootstrap no longer returns `NA`; weighted refits now supply a weighted
  delta-method standard error (weighted inverse information for the ordinal
  model, a weighted matched-pair cluster sandwich for KK), equal to the usual
  standard error at unit weights. The KK classes' studentized nonparametric
  bootstrap and studentized bootstrap randomization test now also use the real
  standard error (v1.0.6-TODO-149).

* `draw_ws_according_to_design()` on a sequential design that uses the generic
  replay (`DesignSeqOneByOneUrn` and custom sequential designs) no longer
  overwrites the subjects' realized assignments. A redraw, including the one
  inside `InferenceIncidCMH`'s standard error, used to leave a redrawn vector
  in `get_w()`, changing every later inference and the rest of a running
  trial (v1.0.6-TODO-42).

* The randomization-bootstrap confidence interval now warns once
  (`edi_procedure_na_warning`, with the reason) when it returns NA: estimate or
  studentized SE unavailable, too few finite null draws, or a search-bounds,
  bisection or closed-form failure. An unavailable Bayesian-bootstrap BCa
  p-value now warns instead of returning a silent NA (v1.0.6-TODO-165).

* Sequential Monte Carlo randomization and randomization-bootstrap p-values
  (used by the randomization CI searches when r >= 200) no longer return NA
  when an early batch has fewer than 10 finite null draws, including whenever
  `mc_batch_size` < 10; they now draw the next batch. Results are unchanged
  when every draw is finite (v1.0.6-TODO-166, v1.0.6-TODO-55).

* The CR2 cluster-robust standard error used by `InferenceContinOLS` and
  `InferenceContinLin` on cluster designs no longer falls back silently to the
  independent-subjects SE when the response is measured in small units (e.g.
  y * 1e-8): the not-estimable floor is now relative to the scale of the
  response, and the variance matches `clubSandwich::vcovCR(type = "CR2")` at
  every scale (v1.0.6-TODO-58).

* `DesignFixedOptimal` with `objective = "mahal_dist"` no longer silently
  falls back to the `abs_sum_diff` objective when full-rank covariates are on
  very different scales; the singularity check now uses the correlation
  matrix, so it is scale-invariant (v1.0.6-TODO-54).

* `DesignFixedGreedyDOptimal` and `DesignFixedOptimal` (objective `"D"` /
  `"A"`, no `prior_precision`) now build the correct criterion when a
  covariate is collinear with the intercept (e.g. `x2 = x1 + 1`, or indicators
  that sum to 1). The projection matrix used to include an arbitrary extra
  direction, and the A-criterion's interest columns could be misaligned after
  QR pivoting, so the search optimized the wrong objective. Designs where
  `[1, X]` has full rank are unchanged (v1.0.6-TODO-57).

* `InferenceAllSimpleWilcox` now returns the Hodges-Lehmann estimate (the arm
  difference) and the ties-corrected rank-sum p-value when each arm is
  constant, instead of an NA estimate. The rank-test confidence interval does
  not exist there, so it is returned as NA with a classed
  `edi_wilcox_ci_unavailable_warning` (v1.0.6-TODO-59).

* Cox-model parametric-bootstrap and simulation paths no longer understate
  the Breslow baseline hazard when a late risk set holds only subjects with
  very low relative risk: the absolute 1e-10 floor on the rescaled risk-set
  sum is removed, with a log-scale rescale used only on underflow. Results on
  ordinary data are unchanged (v1.0.6-TODO-51).

* Redraws on a sequential design that is still enrolling are now consistent:
  `DesignSeqOneByOnePocockSimon` no longer errors before the last subject
  arrives; Efron and iBCRD redraws return one row per enrolled subject like
  every other sequential design (they returned the planned `n`); and custom
  sequential designs see the subject being replayed during a redraw. Redraws
  on a completed trial are unchanged (v1.0.6-TODO-183).

* `DesignSeqOneByOneKK21` with `response_type = "proportion"` and the default
  `proportion_use_speedup = TRUE` no longer loses all covariate weights
  (silently matching unweighted) when a response is exactly 0 or 1: the logit
  is now clamped as in `DesignSeqOneByOneKK21stepwise`. Designs whose
  responses are all inside (0, 1) are unchanged (v1.0.6-TODO-60).

* PRW subsampling confidence intervals and p-values now respect the CI
  timeout deadline and re-raise timeouts or interrupts that occur while
  computing the original estimate, instead of returning NA; they now share one
  setup routine with the m-out-of-n bootstrap (v1.0.6-TODO-194).

* The g-computation risk-ratio classes now accept a list-valued `b` / `m`
  (minimum-volatility size selection) for subsampling and m-out-of-n intervals
  and p-values; timeouts raised while computing their original estimate, or
  while the resample-size selectors evaluate a candidate, now abort the call
  instead of producing NA or a non-estimable candidate (v1.0.6-TODO-196).

## Breaking changes

* `DesignFixedRerandomization$new()` now requires an acceptance rule, exactly one of `obj_val_cutoff` and `prop_acceptable`, and stops if neither is given. Before, giving neither accepted every candidate draw, so the design was complete randomization with a fixed number treated. Pass e.g. `prop_acceptable = 0.1` (keep the best 10% of draws by Mahalanobis distance); `obj_val_cutoff = Inf` reproduces the old behaviour exactly. `SimulationFramework` supplies `prop_acceptable = 0.1` when the design is given without a rule.

* `DesignSeqOneByOneiBCRD` now requires `n` and errors on `n = NULL`. Its old
  `n = NULL` fallback assigned by Bernoulli coin while its randomization draws
  forced exact balance, so its randomization tests were invalid. Use
  `DesignSeqOneByOneBernoulli` when the sample size is unknown. Designs
  constructed with `n` are unchanged (v1.0.6-TODO-187).

* `compute_lik_ratio_bootstrap_confidence_interval()` now errors up front when
  `B < 2/alpha - 1` (e.g. "B must be at least 39 for alpha = 0.05"): its
  bootstrap p-value can never be below 2/(B+1). Such calls used to run the whole
  search and return a warned `NA`; `InferenceCountPoisson` silently fell back to
  its design-based interval. `InferenceSuite$run_all_inference()` makes the same
  check before any fitting when the `"param_boot"` CI is in the run, and asks for
  a larger `B`. The default `B = 199` covers any `alpha >= 0.01`
  (v1.0.6-TODO-210).

* Argument checks are stricter (v1.0.6-TODO-100, v1.0.6-TODO-106). Calls that
  used to be accepted and gave `NA`, a silently wrong value or a confusing later
  error now stop with a checkmate error naming the argument:
  * `alpha` must be a single number strictly between 0 and 1. The old upper
    bound `1 - .Machine$double.xmin` equals 1 in double precision, so
    `alpha = 1` passed and gave a zero-width interval.
  * `alpha`, `delta`, `pval_epsilon`, `tau`, `prob_T` and similar scalar
    arguments must have length 1 (a vector used to be silently truncated or
    recycled), must not be `NA`, and `delta` must be finite (`delta = Inf`
    used to give p = 0).
  * `Design$new(n = 0)` is rejected, and count arguments such as `B`,
    `max_expansions` and `mc_batch_size` must be whole numbers (2.7 was
    silently truncated to 2).
  * Responses: `add_one_subject_response(y = NA)` and `NA` responses in
    `add_all_subject_responses()` are rejected for non-survival designs with a
    message naming the first such subject, and an exact response must be
    finite (right censoring is still `y_L` with `y_R = Inf`).
  * `strata_cols`, `cluster_col`, `classes`/`exclude_classes` and logical flags
    such as `na.rm`, `show_progress`, `exact_num_blocks` and
    `equal_block_sizes` must not contain `NA`.
  * An `InferenceRandCustom` R statistic must accept `(y, w, dead)` (or `...`);
    it used to fail only at the first draw.
  * The checks that guard correctness (an `NA` response, `prob_T`, Pocock-Simon
    `p_best`/`weights`, and the 0/1 `w` passed to
    `overwrite_all_subject_assignments()`) now run even with assertions turned
    off for speed.

* `overwrite_all_subject_assignments()` now has one implementation for fixed
  and sequential designs and stops with a clear error if called before any
  subjects are added or, for a sequential design with `n`, before all `n`
  subjects have arrived (an overwrite mid-trial fed later sequential assignments
  a `w` the design never drew) (v1.0.6-TODO-154).

## Documentation

* Corrected docs from the 2026-11-21 docs-scenario audit: `?InferenceSuite` no longer points to unexported
  internals and says `methods = NULL` means every sentinel it lists; `?Design` and the reproducibility vignette
  date the per-subject sequential seeding to the first release after 1.0.4 (a development build still reports
  1.0.4); the notation glossary says `SimulationFramework` hooks receive `w` in {0, 1}; `?SimulationFramework`
  says `$run()` returns the framework, not a report, and that errors are read with
  `SimulationFrameworkReport$new(sim)$get_errors()`; `?DesignFixedBlocking` and the existing-experiment article
  say when the unequal-block error fires (at a drawn assignment, or for a supplied `w` at the first redraw,
  bootstrap or randomization call), and the article says the four-site BCa interval is finite;
  `?InferenceIncidWald` and `?InferenceIncidRiskDiff` no longer list other methods' arguments under `$new()`;
  the proportional-odds, cloglog, ordered-probit and cauchit classes document their constructor, which takes no
  `harden` or `seed`; the proportion cookbook says fractional logit fits exact 0s and 1s;
  `?InferencePropBetaRegr` states the Smithson-Verkuilen squeeze it applies to every response when any is 0 or 1;
  and `?InferenceOrdinalJonckheereTerpstraTest` describes its exact algorithm (enumeration of per-category
  treated counts, capped at one million count vectors, not allocations) and its two-sided convention.

* `?DesignFixedGreedy` and `?DesignFixedGreedyDOptimal`: the two classes give
  the same draws at their defaults only when the covariates have no ties; with
  ties their searches can break equal-improvement swaps differently
  (v1.0.6-TODO-295).

* Corrected docs from the 2026-11-18 docs-scenario audit: `?DesignFixedBlockedCluster` says blocks
  may have unequal sizes and which jackknife units return `NA` there, and why;
  `InferenceIncidLogRegr` (`estimand = "marginal_ratio"`, log scale) and `InferenceIncidGCompRiskRatio`
  (ratio scale) state the scale of the same marginal risk ratio; `InferenceSurvivalRestrictedMeanDiff` no
  longer names a nonexistent `DesignFixedBCRD`; the missing-covariates article says the outcome-free
  imputation ships after the 1.0.4 release; `InferenceRandCustom` documents that C++ source must be a
  single function without `// [[Rcpp::export]]`, that a nonzero `delta` and the randomization CI are
  coherent only for continuous responses (on survival the CI is returned but not valid), and the article
  quotes the real two-argument error, the 2/B p-value floor and the one-number check; the randomization
  methods document the allowed `transform_responses` values and the `permutations` list format; the
  Python article now says the kernels check that `w` is 0/1; and the Cox kernels' stubs and README say
  ties use Breslow's approximation.

* `InferenceCountZeroInflatedPoisson` documents that at small n with continuous
  covariates in the zero-inflation formula the ZIP MLE often does not exist (a
  separated zero-part ridge): some fits can stop at a lower interior local
  maximum without a warning, and the count-part estimate is only weakly defined
  on a ridge. A treatment-only zero formula (`model_formula_zero = ~ 1`) is
  recommended there (v1.0.6-TODO-232).

* The jackknife documentation explains why the stratified jackknife rescales
  EDI's subset refits to Wolter's reweighted replicates, and that its bias
  correction then equals the ordinary jackknife bias, which can over-correct
  nonlinear estimators when strata differ strongly (v1.0.6-TODO-231).

* Corrected documentation claims: `SimulationFramework` draws covariates with `cov_draw_method` (default `stats::rnorm`), not Uniform(0, 1); `InferenceSurvivalRestrictedMeanDiff` integrates the Kaplan-Meier curve exactly (a sum of rectangles), not by the trapezoid rule; and `fast_cpoisson_combined_with_var_cpp()` documents its `tol`, `hessian` and estimate-only return accurately.

* Corrected more class documentation that contradicted the code (docs-claims audit): the incidence classes'
  `compute_rand_two_sided_pval()` takes its default p-value from randomization draws and uses the Zhang exact test
  only with `type = "Zhang"`; `InferenceIncidKKNewcombeRiskDiff` uses Wald variances in both components;
  `InferencePropQuantileRegr`'s weighted refit no longer claims to overwrite the cached estimate;
  `InferencePropZeroOneInflatedBetaRegr`'s weighted refit is described as the separate weighted fits it runs;
  `InferenceOrdinalPairedSignTest` supports bootstrap and jackknife; and `InferenceOrdinalStereotypeLogitRegr` lists
  only its Bartlett p-value as excluded from the comprehensive suite. `InferenceCountZeroInflatedNegBin` also loses a
  marginal-estimand branch that could never run.

# EDI 1.0.4

Correctness release. Wrong results found by the algorithm audit and the
comprehensive-test sweeps are fixed, and seeded draws are now identical on
Linux, macOS and Windows at every thread count (checked in CI). No new
methods.

## Breaking changes

* `DesignFixedRerandomization$new()` now requires an acceptance rule, exactly
  one of `obj_val_cutoff` and `prop_acceptable`, and stops if neither is given.
  Before, giving neither accepted every candidate draw, so the design was
  complete randomization with a fixed number treated: no rerandomization at
  all. Pass e.g. `prop_acceptable = 0.1` (keep the best 10% of draws by
  Mahalanobis distance); `obj_val_cutoff = Inf` reproduces the old behaviour
  exactly. `SimulationFramework` supplies `prop_acceptable = 0.1` when the
  design is given without a rule.
* The randomization bootstrap (`compute_rand_bootstrap_two_sided_pval()`,
  `compute_rand_bootstrap_confidence_interval()`,
  `approximate_rand_bootstrap_distribution_beta_hat_T()` and the
  `get_supported_rand_bootstrap_*_types()` helpers) is no longer available on
  `DesignSeqOneByOne` designs other than `DesignSeqOneByOneBernoulli`, matching
  the nonparametric bootstrap. It resamples subjects the same way, and its
  validity on adaptive sequential designs, including the KK designs, is
  unproven. Those methods now stop with "not supported", and `supports()`
  reports `randomization_bootstrap` and `randomization_bootstrap_ci` as
  `FALSE` there. Before, `supports()` reported them available, contradicting
  the capability contract. KK estimators keep the randomization bootstrap on
  `DesignFixedBinaryMatch`.

* `InferenceIncidKKCondLogitGLMMOneLik` and `InferenceIncidKKCondLogitGLMMIVWC`
  fit a new model: conditional logit on the discordant pairs, plus (OneLik
  only) a logistic regression on the reservoir with shared coefficients. The
  old GLMM split most pairs into one-row groups. All results change; class
  names are unchanged and `max_abs_log_sigma` is ignored. OneLik's pooled
  estimand caveat is documented in the class. `InferencePropKKGLMM` keeps its
  GLMM, now grouped correctly.
* GitHub source installs build the portable CRAN configuration by default;
  `EDI_PORTABLE=0` restores the machine-tuned build.
* Randomization p-values (and their Monte Carlo bands, the studentized
  randomization-bootstrap p-values and the closed-form randomization-bootstrap
  CI) count a redrawn statistic as a tie in both tails when it is within
  `sqrt(.Machine$double.eps)` times max(|observed|, largest |redraw|) of the
  observed one. A redraw that reproduces the observed allocation gives the
  observed statistic only up to rounding, so before it could be counted or
  not depending on the build, core count and subject order (seeded 1-core
  and 2-core sessions could differ by 2/r). Scaling by the redraws as well
  covers an observed statistic of exactly 0: an enumerated 12-subject Ridit
  test had half its exact ties at -5.6e-17 and gave a one-sided p of 0.497
  instead of 0.634. P-values with such ties can only rise.
* Seed-pinned draws change once: a portable shuffle replaces
  `std::shuffle`, and greedy, D-optimal, pair-switching and rerandomization
  designs no longer depend on the thread count.
* `DesignSeqOneByOnePocockSimon` no longer rebuilds the model matrix on
  every arrival. When covariates have missing values, that rebuild ran the
  random-forest imputation, which drew from R's random number stream, so
  seeded assignment sequences with missing covariates change once. Sequences
  without missing covariates are unchanged.
* `DesignFixedBlocking`, `DesignFixedOptimalBlocks`, `DesignFixedCluster` and
  `DesignFixedBlockedCluster` draw null assignments in one vectorized pass
  (about 15x faster, no `randomizr` needed, independent of
  `set_num_cores()`), so seeded draws change once. Singleton blocks are
  Bernoulli(`prob_T`).
* Studentized bootstrap statistics are cached per object by `B` and
  `smooth` and use `set_seed()`, so a studentized CI and p-value share
  resamples. Seeded results change once.
* Randomization p-values and intervals use `set_seed()`, else the design
  seed, and the permutation cache is keyed on that seed. Seeded results
  change once; unseeded behaviour is unchanged. New
  `clear_randomization_cache()`.
* The KK matched-pair bootstrap, `InferencePropGCompMeanDiff`'s bootstrap,
  the `"calibrated"`, `"double-bootstrap"` and `"prepivoted"` bootstrap CIs and
  the KK quantile-regression IVWC randomization CI now use the object's seed
  instead of the caller's RNG stream. Seeded results change once.
* `compute_rand_confidence_interval()` errors instead of returning wrong-scale
  bounds for raw-scale mean-difference and rank classes on proportion, count
  and ordinal responses (e.g. `InferenceAllSimpleAverageDiff`,
  `InferenceOrdinalRidit`).
* `capabilities()` / `supports()` no longer advertise `randomization_ci`
  where it is refused, so `InferenceSuite` and `SimulationFramework` skip it.
* On cluster designs `InferenceContinOLS` and `InferenceContinLin` use a CR2
  cluster-robust SE with Satterthwaite degrees of freedom (as
  `clubSandwich`), and `cluster_col` no longer enters `~ .`. Other
  regression classes warn once (`edi_cluster_independence_warning`); use
  randomization, bootstrap or cluster jackknife inference there.
* Randomization intervals invert at `alpha`, not `alpha / 2` (they were too
  wide); the default `pval_epsilon` drops from 0.005 to 1e-6.
* Binary matching minimizes plain distance by default, as `nbpMatching`
  does (about 22% of pairs change); `match_objective = "squared_distance"`
  restores the old pairs.
* KK21 survival weights come from a correct Weibull AFT fit.
* `InferenceSurvivalRestrictedMeanDiff` truncates both arms at one horizon;
  the interval-censored path now uses exact events, and an all-censored
  arm's RMST is the horizon, not `NA`.
* The bootstrap CI width guard is `5 * max(1, sd(y))`, so wide intervals on
  large-scale outcomes are no longer returned as `NA`.
* `get_summary()` works for every class and returns its table invisibly.
* `Design$any_censoring()` is `FALSE` before responses are recorded, so
  `applicable_inference_class_names()` no longer drops classes early.
* `DesignFixedOptimal` bootstrap replays reuse the observed solver.
* Jackknife inference is centred on the jackknife estimate.
* `compute_rand_two_sided_pval()` always uses randomization draws; for
  incidence it no longer silently returns the more conservative Zhang test
  (still available as `type = "Zhang"`).
* Methods that cannot give a valid answer now error: KK modified Poisson is
  Wald-only, smoothed randomization bootstrap is refused for categorical and
  bounded refits, exact tests refuse bootstrap weights, and
  `InferenceOrdinalKKCondAdjCatLogitRegr` drops the Bayesian bootstrap.
* `InferenceSurvivalDepCensTransformRegr`'s bootstrap intervals default to
  `B = 501` like every other bootstrap; pass `B = 1000` for the old ones.
* `DesignFixedBlocking`: `strata_cols` without `B_target` uses all named
  strata (the default cap dropped them silently).
* Blocking designs treat an integer-valued strata column with at most 10
  distinct values as categorical instead of binning it.
* `prob_T` is removed from the constructors of designs that always assign
  1:1 (Efron, Atkinson, Pocock-Simon, the KK sequential designs,
  `DesignFixedBinaryMatch`, `DesignFixedMatchingGreedyPairSwitching`);
  passing it is now an error.
* `InferenceCountZeroInflatedPoisson` and `InferenceCountZeroInflatedNegBin`
  error when the response has no zeros (not identified, as in
  `pscl::zeroinfl()`); resampling replicates with no zeros fall back to the
  non-inflated fit.
* Unequal-arm support is a design registry capability,
  `supports_unequal_allocation`, checked at construction.

## New features

* `DesignSeqOneByOneKK21stepwise`: `condition_on_ws_for_rand_tests = FALSE`
  replays the full allocation in randomization tests.
* KK quantile-regression randomization intervals are re-enabled.
* Studentized Bayesian-bootstrap intervals for the Weibull and
  modified-Poisson classes.
* `na.rm` for the KMDiff Bayesian-bootstrap p-value.
* `InferenceSurvivalRestrictedMeanDiff$new(..., tau = NULL)`: a user-set
  RMST horizon.
* `alternative = c("two.sided", "greater", "less")` on
  `compute_rand_two_sided_pval()`, for non-negative custom statistics.
* `clear_randomization_cache()` on `Inference`.
* `run_all_inference()` results gain four columns after `weight`: `regime`
  (asymptotic or finite-sample), `n_eff` (the effective-sample-size rule for
  the class, design and procedure with its value on your data, e.g.
  `n_pairs = 25`), `size_order` (expected order of the size / coverage error,
  e.g. `O(n_eff^-1)`, `exact`, `O(1)` or `unknown`) and `rate_basis` (theory,
  literature, assumed default or unknown). Existing columns are unchanged.
* `get_inference_procedure_validity(design, inference_class, procedure = NULL)`
  and the inference method `get_procedure_validity(procedure = NULL)` look up,
  without fitting, what the validity registry says about each procedure a class
  supports: regime, expected order of the size error, effective-n rule (with
  its value on the object's data for the method), regularity, basis and
  reference. Measured calibration values are not shipped yet (`measured` is
  `NULL`).

## Bug fixes

* `InferenceIncidExactZhang$compute_exact_confidence_interval()` (and the
  `type = "Zhang"` randomization CI for incidence) now inverts the combined
  test it reports. Its endpoint search started from the log odds ratio of the
  unmatched (reservoir) subjects only. With every subject matched
  (`DesignFixedBinaryMatch`) that is always 0, so the interval held 0 even
  when the test rejected (coverage 1.00 at the null); with a small reservoir
  (KK designs at large n) a start the test rejects gave a wrong endpoint
  (coverage 0.85-0.88 at n = 1000 on `DesignSeqOneByOneKK21`, while the test's
  size was 0.03). The search now starts from a point the combined test
  accepts. Intervals that already started from an accepted point do not change.
* `tune_EDI_for_this_machine()` no longer refuses to run on an idle machine
  with "calibration timings are noisy". Its idle check timed a single ~1 ms
  operation with a 1 ms clock, so the measured spread was mostly the clock's
  rounding. Each calibration sample now times a batch of 50 runs.
* `tune_EDI_for_this_machine()` no longer loses a finished run when it cannot
  write its config file (for example a read-only home directory). It now warns,
  applies the tuning to the current session, and returns the result.
* `tune_EDI_for_this_machine()`'s summary now gives the right number of timing
  wins discarded by the correctness gate. It counted warm-start operations
  instead (5 printed for 19 discards).
* `tune_EDI_for_this_machine()`'s start-up time estimate now matches measured
  runs: about 1 hour for `effort = "quick"` and 3-4 hours for `"standard"` on a
  6-core laptop (it said 2-5 and 15-30 minutes). `"thorough"` is not timed and
  takes many hours.

* `tune_EDI_for_this_machine()` no longer aborts partway through (it stopped
  at cell 57 of 1065 under `effort = "standard"`). Its synthetic count data had
  no zeros, which the zero-inflated classes now reject. Zero-inflated and
  hurdle classes are now benchmarked on counts that include structural zeros.
  A benchmark cell that still errors is skipped with a warning and keeps the
  shipped default; skipped cells are listed in `attr(x, "failed_cells")`.
* `InferenceIncidLogBinomial`'s gradient CI now warns (class
  `edi_lik_ci_lik_ratio_fallback`) and records why when it returns the
  likelihood-ratio interval because gradient inversion failed; this was silent.
* `InferenceSurvivalDepCensTransformRegr` fits from several deterministic
  starts and keeps the best, since the single start could miss the MLE
  (about 1 fit in 7). Fits take about 2x as long.
* `InferenceSurvivalKMDiff`'s Wald CI and p-value keep each arm's asymmetric
  median interval (MOVER); coverage with small arms improves. Results change
  for every dataset.
* Likelihood-ratio CIs no longer return a bracket midpoint when the root
  search hits its iteration limit.
* BCa bootstrap intervals count ties with the estimate as half, so discrete
  bootstrap distributions no longer make them mostly `NA`.
* `InferenceSurvivalKMDiff` and the quantile-regression classes default to
  the percentile bootstrap; `type = "bca"` is still available.
* `InferenceSurvivalRestrictedMeanDiff`'s randomization-bootstrap CI is
  refused: its bounds were on the wrong scale.
* Randomization-bootstrap replays redraw each resample's assignment from the
  resample's own design structure (pairs, optimal blocks, D-optimal and
  rerandomization criteria). Results on these designs change, and replays
  with `DesignFixedOptimalBlocks(method = "ompr")` are very slow.
* `DesignFixedOptimalBlocks(method = "greedy")` no longer fails on some
  resamples with duplicated rows.
* `InferenceSurvivalRestrictedMeanDiff`'s Bayesian-bootstrap studentized
  intervals are no longer always `NA`.
* Robust regression classes return `NA`, not 0, for fits with non-finite
  data.
* `robust_survreg()` restart jitter uses its own seeded stream (new
  `jitter_seed` argument) and leaves the caller's RNG alone.
* `InferenceSurvivalKKRankRegrIVWC` results are now reproducible across calls.
* `InferenceAllKKMeanDiffIVWC`'s bootstrap no longer errors on
  `DesignFixedBinaryMatch`.
* Ridit `reference = "treatment"` always returned 0; interior levels misscored.
* `InferenceOrdinalRidit` uses the DeLong SE; the old one was
  anti-conservative.
* `compute_rand_confidence_interval()` refuses proportions with exact 0 or 1
  for logit-shift classes, and survival responses for raw-scale classes.
* The jackknife block-size guard no longer swallows interrupts and timeouts.
* `InferenceRandCustom` randomization CIs are searched on the effect scale.
* `InferenceOrdinalPartialProportionalOddsRegr` (VGAM) had the wrong
  treatment sign, and `nonparallel` gave degenerate fits.
* Ordinal fast solvers centre and scale covariates, fixing wrong estimates
  for covariates far from zero.
* `InferenceContinLin` no longer reuses another formula's centred covariates.
* `InferenceSurvivalKKStratCoxPHOneLik`'s Bayesian-bootstrap refit uses the
  same reservoir stratum; `InferenceSurvivalStratCoxPHRegr` warns on matched
  designs.
* KK and frailty survival classes work with zero covariate columns.
* Score / LR / gradient tests of the KK OneLik and GLMM classes work when
  `beta_T` is the only parameter, and several classes that silently returned
  Wald results now run the requested test. `InferenceCountKKGLMM`'s score
  test sign is fixed.
* New classed warnings when a likelihood test is unavailable or replaced by
  Wald (`edi_lik_test_unavailable_warning`, `edi_lik_ci_wald_fallback`,
  `edi_lik_test_wald_fallback`, `edi_unsupported_procedure`).
* A failed resampling or likelihood-test procedure returns `NA` for that
  procedure only, without marking the object non-estimable.
* `InferenceIncidLogBinomial` and `InferenceIncidBinomialIdentityRiskDiff`
  warn once (`edi_binomial_mle_boundary_warning`) when the MLE is on the
  boundary.
* `InferenceIncidLogBinomial`'s Wald p-value and CI are now `NA` when the MLE
  is on the boundary (a fitted probability of 1), with a warning (class
  `edi_wald_mle_boundary_unavailable`) pointing to the likelihood-ratio test.
  The Wald standard error is too small there: null size was 0.14 at n = 50
  with five covariates, and is 0.04-0.05 over the fits that remain. With
  several covariates most fits are on the boundary, so Wald is often `NA`.
  The likelihood-ratio interval at such fits no longer falls back to the Wald
  interval when the null refit had no feasible start (526 to 75 of 1000 fits
  at n = 50).
* `InferenceIncidLogBinomial` and `InferenceIncidBinomialIdentityRiskDiff`
  fits no longer stop short of the MLE at a boundary, which also made the
  jackknife depend on call order.
* `InferenceIncidProbitRegr` no longer reports convergence at a saturated
  fit.
* `InferenceIncidBinomialIdentityRiskDiff` no longer cycles until the
  iteration cap on some interior fits.
* `InferenceIncidBinomialIdentityRiskDiff` and `InferenceIncidLogBinomial`:
  one failed null refit no longer makes every later likelihood test on the
  object `NA`. The retry is shared by all likelihood-test classes.
* `InferenceIncidLogBinomial` and `InferenceIncidBinomialIdentityRiskDiff`:
  score and gradient tests at a null MLE with a fitted probability of 0 or 1
  were `NA` or wrong; they now use the profile (Kuhn-Tucker) score, so their
  intervals end at true roots.
* `InferenceIncidBinomialIdentityRiskDiff`'s null refit no longer fails when
  every start has a fitted probability outside [0, 1]; such CI endpoints
  stopped short of the root.
* Likelihood CI inversion no longer returns an isolated low-p point as an
  endpoint.
* `InferenceOrdinalStereotypeLogitRegr`: likelihood-test p-values no longer
  depend on which nulls were tested earlier on the object (now 3-6x slower).
* `InferenceOrdinalStereotypeLogitRegr`: the randomization and bootstrap
  estimator now matches `compute_estimate()`.
* `InferenceCountNegBin` fits now match `MASS::glm.nb`.
* Modified Poisson Wald SE is the robust sandwich.
* Randomization intervals reused a shifted null that is exact only for
  mean-difference and OLS estimators, and refined the wrong endpoint.
* `InferenceAllKKWilcoxIVWC` SEs, bootstrap interval and bootstrap scale;
  other legacy `*IVWC` classes had placeholder variances or dropped pairs.
* Mixed models: logistic GLMM Hessian, multi-start fits, KK GEE correlation,
  bootstrap-weighted refits that fit the wrong model.
* Ordinal: cloglog parametric-bootstrap sign (left open in 1.0.2),
  stereotype and continuation-ratio multi-start; ZOIB softmax means.
* Designs: `RandomBlockSize` redraw stratum and single block size,
  `PocockSimon` `NA` level, `OptimalBlocks` block-size spread.
* Incidence: Newcombe root search, equal-tailed exact-binomial p-value,
  Zhang interval bracket.
* Survival: stratified-Cox bootstrap scaling, DepCens intervals, Clayton
  overflow, KK Weibull no-event `NA`, Breslow ties in Cox fallbacks.
* Stale caches keyed on `w` only (GLM, Cox, log-rank, Gehan);
  `get_X_imp()` aliased the raw covariates.
* `InferenceAllSimpleAverageDiff` bootstrap weights are frequency weights.
* Singular fits return `NA` SEs; Jonckheere-Terpstra exact enumeration is
  capped at 1e6 cells.
* Crashes: GC faults in the KK21 ordinal and match kernels;
  `InferenceRandCustom` compile cache.
* `InferenceOrdinalKKCLMMCloglog`'s `ordinal::clmm()` paths fitted the
  log-log model (a `clmm()` link-name swap); EDI now detects the mapping.
* KK CLMM classes no longer report convergence at non-stationary fits;
  such fits are retried, else `NA`.
* `InferenceBaiAdjustedTKK14` / `KK21`: the asymptotic p-value now tests
  `delta` (it ignored it).
* `InferenceContinKKGLMM`'s score intervals were about 20% too narrow; fixed.
* `InferenceCountZeroInflatedPoisson` / `ZeroInflatedNegBin`: LR and score
  intervals no longer contradict their tests, and the ZINB Wald SE is no
  longer `NA` at a boundary.
* `InferenceAllSimpleWilcox`'s asymptotic p-value at nonzero `delta` tested
  `-delta`; it now matches `wilcox.test(mu = delta)`.
* `InferenceCountKKGLMM` reports the model-based likelihood tests instead of
  the larger of model and Wald p-values.
* `InferenceOrdinalStereotypeLogitRegr` no longer drops covariates in most
  fits. With 3+ categories a treatment-only fit (`~ 1`) is non-estimable:
  the model is saturated there and its tests are not calibrated.
* `InferenceCountHurdleNegBin` and `InferenceSurvivalDepCensTransformRegr`
  likelihood-test p-values no longer depend on call history.

## Known limitations

* `InferenceSurvivalRestrictedMeanDiff`'s SE assumes independent arms, so it
  is conservative on designs other than Bernoulli and complete
  randomization. Design-aware variances are planned for 1.1.0.
* `InferenceSurvivalKKStratCoxPHOneLik` with covariates is biased toward zero
  at small n, so its intervals under-cover; use
  `InferenceSurvivalKKLWACoxPHOneLik`. A fix is planned for 1.1.0.
* Jackknife inference on `DesignSeqOneByOneSPBR` and `DesignFixedBlocking`
  with few strata under-covers (about 0.85); a fix is planned for 1.1.0.
* `InferenceOrdinalCloglogRegr` with covariates at small n: likelihood-based
  tests reject 8-12% at nominal 5%, and the parametric bootstrap is
  conservative. Under review for 1.1.0.
* `InferenceIncidExtendedRobins`'s Wald test is anti-conservative on small
  blocks and matched pairs; use `InferenceIncidCMH` there.
* Some asymptotic tests reject up to 8-14% at nominal 5% at n = 50, or with
  about 10 treated subjects; they are close to nominal by n = 200. Each
  affected class's help page has a "Small samples" note naming the tests
  and a better-calibrated alternative. Under review for 1.1.0.

## Performance

* The tighter KK CLMM tolerance makes full fits about 1.5x and randomization
  refits about 2.8x slower.
* Cached per-permutation slopes, a C++ OLS randomization kernel, batched
  Bayesian-bootstrap weights, lazy model matrices; OpenMP kernels respect the
  package thread maximum.
* Eight unused internal C++ kernels were removed.

## Documentation

* New vignette "Which procedure can I trust at my sample size?"
  (`vignette("procedure-trust")`). It explains the split between
  finite-sample procedures (exact tests and the randomization test) and
  asymptotic ones, the order of the size error and the effective-n rule of each
  procedure, the classes where the rate is unknown and why (boundary,
  variance components, zero inflation, quantile-regression sparsity, design
  mismatch), and how many design x class x procedure cells rest on theory, an
  assumed default, or nothing. Its tables are rendered from the internal
  registry, and a test fails if they drift from it. It links the published
  calibration results.
* Every public inference class's help page has a new "Small-sample behaviour"
  section generated from the same registry: for each procedure the class
  supports it gives the regime (exact or asymptotic), the order of the size
  error, the effective-n rule, the regularity and the references, with
  design-specific differences (unequal allocation, cluster designs, designs
  that make an unadjusted variance conservative). A rate that is only the
  procedure's regular-model default is labelled "assumed default", and an
  unknown rate says so rather than guessing. The new citations are in
  `REFERENCES.md`. The hand-written small-sample paragraphs now quote the first
  calibration campaign: for example the `InferenceContinLin` Wald test at
  `prob_T = 0.2`, n = 50 with covariates rejected 17% of the time, not the
  "about 10.5%" stated before.

## Internal

* Inference components declare only the components they call; shared
  resampling helpers moved into a new internal `ResamplingCore` component.
* New internal registry `inference_procedure_regime.R` classifies each
  `run_all_inference()` procedure as asymptotic or finite-sample (exact and
  randomization); package load fails if a procedure has no entry. The
  published calibration study uses it to hold asymptotic procedures to a
  looser size and coverage tolerance at small n.
* The same file now holds an internal convergence-rate registry: for each
  design, inference class and procedure it records the order of the
  size / coverage error and of the bias, the effective sample size (pairs,
  smaller arm, events, nonzero counts, ...), the regularity of the model, and
  whether the answer comes from theory, the literature, or is only a default
  or unknown. Rates not known are recorded as unknown, never guessed. Nothing
  in the calibration gate reads it yet.

# EDI 1.0.2

This is the first version submitted to CRAN. Versions 1.0.0 and 1.0.1 were
GitHub-only releases; their entries below record what changed in each. Most of
1.0.2 is correctness work found by the extended comprehensive test suite and
by writing unit tests: resampling and randomization results that were silently
wrong in specific classes, a few kernel defects (including one memory-safety
bug), and standard-error and confidence-interval fixes.

## Breaking changes

* `toggle_asserts()`, `set_num_cores()`, and the internal thread-count
  bookkeeping it drives no longer set global `options()` as a side effect
  (CRAN policy: a package must not modify and leave changed the user's
  session options). `toggle_asserts()` now stores its flag in the package's
  own internal state; calling it no longer changes what
  `getOption("edi.run_asserts")` returns (a user's own
  `options(edi.run_asserts = ...)` is still read and honored). Likewise,
  `set_num_cores()`/`set_package_threads()` no longer set
  `options(mc.cores = ...)` (nothing in EDI read it back; downstream code
  relying on this package to set it for `parallel`/`pbmcapply` needs to set
  it itself now) and no longer call `fixest::setFixest_nthreads()` (which
  sets `options(fixest_nthreads)`, the user's own option, not EDI's to
  change). No change to which thread counts are actually used internally —
  only to these previously-observable `options()` side effects.

## New features

* `InferenceCountQuasiPoisson` now composes the marginal-estimand component
  (`MarginalEstimand`), like `InferenceCountPoisson`, so marginal (standardized)
  effect estimands are available for the quasi-Poisson class as well.

## Bug fixes

* Reused-worker resampling reused a stale cached fit across draws for
  classes whose fit is cached under a custom guard key (first found in
  `InferenceOrdinalGCompMeanDiff`, whose `cached_values$md` guard survived
  the loader's narrow reset list). Every draw then returned the same
  number, the resampling distribution collapsed to a point mass, and
  `compute_rand_two_sided_pval()` sat at its floor regardless of the true
  effect (reject rate 1.0 at a true null). The worker loaders for
  randomization, non-parametric bootstrap, m-out-of-n bootstrap and
  randomization-bootstrap draws now reset the cached fit state between
  draws, and a structural regression test asserts that every class exposing
  a reusable-worker method returns a non-degenerate distribution.
* `InferencePropGCompMeanDiff` and
  `InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC` returned `NA` (or a
  stale value) in randomization inference: the first from a
  sample-usability gate applied to the wrong resampling context, the second
  from its estimate-only `w_star` pooling. Both are fixed and no longer
  listed as known-broken.
* The KK survival compound classes `InferenceSurvivalKKLWACoxPHOneLik`,
  `InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik` and
  `InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC` fed real `NA`s into the
  fitter for every censored subject during randomization inference:
  `compute_treatment_estimate_during_randomization_inference()` re-read `y`
  from the design and derived `dead = as.numeric(!is.na(y))`, but since the
  `y`/`y_L`/`y_R` migration the design's `y` uses `NA` to mark a censored
  observation. On simulated data with a strong effect the randomization
  `p`-value was 0.02 with no censoring and 0.97 with about 20% censoring.
  `y`/`dead` are now derived as `Design$get_effective_time()` /
  `$get_effective_dead()` do. A sweep of the other 16 survival classes found
  no further instance.
* `InferenceOrdinalCloglogRegr`'s parametric-bootstrap `p`-value was
  badly over-rejecting (60% at a true null). One cause is fixed: the
  delta-constrained null refit started from a single cold start and could
  stall; it is now multi-start (the same fix `InferenceOrdinalStereotypeLogitRegr`
  received earlier). *A second cause, a sign mismatch in the shared
  bootstrap-data simulator, is root-caused but not fixed here.*
* The Efron biased-coin randomization null draws (`generate_permutations`)
  compared weighted arm counts (`n_T * prob_T` vs `n_C * (1 - prob_T)`)
  instead of the raw arm counts `DesignSeqOneByOneEfron` actually compares,
  so for any `prob_T != 0.5` the randomization null did not follow the
  design's own assignment rule. It now uses the raw counts.
* `fast_probit_regression`'s L-BFGS objective held a dangling
  `Eigen::Ref` to a temporary, giving non-deterministic fits and `NaN`
  negative log-likelihoods. The objective now owns its design matrix.
* `fast_log_binomial_regression`'s weighted log-likelihood let zero-weight
  rows constrain the `[0, 1]` mean support although they are absent from
  the likelihood; zero-weight rows are now skipped, so the identity- and
  log-link binomial fits no longer reject valid data because of them.
* The robust-regression bootstrap kernel accepted any `method` string and
  would throw inside an OpenMP region, terminating R; `method` is now
  validated (`"M"` or `"MM"`) before the parallel region.
* `stable_signature()` (used to key cached randomization state) hashed a
  strided sample of the serialized object, which collided on 0/1 integer
  permutation matrices; it now hashes the full serialization.
* `InferenceCountPoisson`'s covariance falls back to the Fisher information
  when the kernel returns no `X'WX`; `InferenceIncidLogRegr` gained an
  estimand-aware standard error and degrees of freedom.
* Weibull and Cox fits with fixed (held) coefficients now compute the
  covariance from the free-parameter information block only and expand it
  back, so the free coefficients' variances are finite and the fixed
  parameters' rows and columns are `NaN` by convention; the Cox cluster-robust
  sandwich does the same.
* OpenMP's primary thread no longer polls R's interrupt machinery while
  worker threads are active in the Wilcoxon-Hodges-Lehmann kernels.
* `fast_gaussian_lmm_gls_cpp()` (the fixed-variance-component GLS solve used by
  the randomization and non-studentised bootstrap fast paths of
  `InferenceContinKKGLMM`) mixed `X'X` with a cross-term scaled by an extra
  `1/sigma_e^2`, so it returned the wrong coefficient whenever the residual
  standard deviation was not exactly 1 (on a paired-plus-singleton fixture
  with `sigma_e = 0.4` the slope was -0.53 instead of the correct 0.63; at
  `sigma_e = 1` the two agreed). It now matches an explicit GLS to machine
  precision at every `sigma_e`.
* The KK21 stepwise weight selection for ordinal responses read a
  nonexistent field (`ssq_b_2`) from `fast_ordinal_regression_with_var_cpp()`;
  it now reads the returned `ssq_b_j`.
* Native fitting kernels now validate the dimensions of consumed caller-supplied
  warm-start parameter, weight, and Fisher-information inputs, and validate
  fixed-parameter indices before use. Malformed inputs that could previously
  trigger unsafe Eigen indexing or silently discard a supplied start now fail
  at the native boundary with an error.
* `fast_zero_one_inflated_beta_cpp()` did not check the length of a supplied
  `warm_start_params` (or `warm_start_fisher_info`, or the row counts of `X`,
  `X_zero_one` and `y`), so a mis-sized start let the optimizer read and write
  past its parameter buffer (heap corruption, found under valgrind; it aborted
  R with `free(): invalid next size`). It now raises an ordinary error.
  `InferencePropZeroOneInflatedBetaRegr` always passed a correctly sized start
  and was not affected.
* `fast_ordinal_clmm` now errors on mismatched `X`/`y`/`group_id` lengths
  instead of reading out of bounds.
* `InferenceIncidRiskDiff`, `InferenceCountRobustPoisson`, and the
  zero-inflated/hurdle Poisson classes reported a confident (often
  zero-width) confidence interval and `p`-value on a perfectly or
  near-perfectly fit response (e.g. `y` fully separated by `w`, or
  constant), because the Huber-White/model-based standard error collapses
  to a numerically-zero-but-positive value there. Found via a raw
  `comprehensive_tests` results audit's new adversarial-data/fault-injection
  sweep. `robust_sandwich_variance()` and the affected classes' standard-error
  paths now treat a variance below `.Machine$double.eps` as non-estimable
  (`NA`), not as precision.
* `InferenceCountHurdlePoisson`/`InferenceCountZeroInflatedPoisson` reported
  a confident estimate and `p`-value on a hurdle fit that has no MLE by
  construction (every positive count equal to 1, so the zero-truncated
  Poisson likelihood only improves as `lambda -> 0`). Non-estimability is
  now decided from the data alone (not from what the optimizer/glmmTMB
  happens to return), so the result is `NA` on every platform.
* `InferenceRandCustom$compute_rand_confidence_interval()`'s fast path
  ignored the trial `delta` shift during the randomization search, so the
  returned interval was in the custom statistic's own scale (e.g. centred
  on a Welch-t value of ~2-4) rather than the response's scale. The
  `comprehensive_tests` harness's own custom-statistic randomization-CI
  check also fed it a non-translation-equivariant statistic (Welch t),
  which cannot give a meaningful CI under this or any correct
  implementation; it now uses a difference-in-means statistic for that
  check.
* `InferenceAllSimpleWilcox$compute_asymp_confidence_interval(alpha)`
  cached and returned the 95% Wilcoxon interval for every `alpha`, so a
  90% or 99% interval silently came back at the wrong nominal level.
* `InferenceOrdinalAdjCatLogitRegr`'s parametric-bootstrap confidence
  interval could be wildly wrong (e.g. `[-30, -11]` around an estimate of
  `-0.09`) because each simulated replicate's treatment coefficient was
  read from the wrong field of the refit object (`fit$b`, slopes only)
  when the anchor fit's index into its own coefficient vector (`fit$params`,
  thresholds + slopes) pointed somewhere else entirely on `fit$b`. Every
  parametric-bootstrap replicate now reads the same field the anchor fit
  used.
* `InferenceOrdinalContRatioRegr` (and, via the same hardened
  QR-column-dropping helper, 8 other ordinal threshold-model classes)
  could silently fit from a garbage cold start and "converge" after one
  iteration when the design matrix contained columns collinear with the
  model's *implicit* per-stage intercept (e.g. a stratified design's two
  complementary factor dummies) — `qr()` alone, with no intercept column
  to check against, reported the matrix as full rank. The column-dropping
  helper now optionally includes that implicit intercept in its rank
  check.
* A likelihood-ratio confidence interval whose Newton/bisection inversion
  converges to within a small tolerance of the point estimate — without
  landing on it exactly — was reported as a zero-width interval instead of
  falling back to the Wald interval (or `NA`), because the "failed
  inversion" sentinel check required bit-identical bounds.
  `InferenceOrdinalStereotypeLogitRegr`'s `compute_lik_ratio_confidence_interval()`
  hit this on ~6% of one audited sample. Its
  `compute_lik_ratio_bootstrap_confidence_interval()` had a related bug: a
  bootstrap `p`-value below `alpha` *at the point estimate itself* (which
  should be ~1, since the LR statistic there is 0) was silently treated as
  a legitimate zero-width interval rather than a failed constrained-fit
  refit; it now reports `NA`.

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
* `InferenceCountHurdlePoisson`/`InferenceCountHurdleNegBin`/
  `InferenceCountZeroInflatedPoisson`/`InferenceCountZeroInflatedNegBin`'s
  standard error could fall through to the generic information-matrix-inverse
  fallback on a hurdle fit with no MLE by construction (every positive count
  equal to 1), and whether that generic inversion happened to return a
  spurious finite value or correctly fail depended on the LAPACK/BLAS
  backend (confirmed via CI to differ between this environment, where it
  correctly returned non-estimable, and Windows). The data-driven
  non-estimability check that already gated the estimate and `p`-value now
  also runs before this generic fallback, so the standard error is `NA` on
  every platform.
* `SimulationFramework`'s internal design/inference-combination builder
  unconditionally disabled package assertions and never restored them; a
  caller running with `turn_off_asserts_for_speed = FALSE` (assertions
  intentionally kept on) had assertions silently disabled for the rest of
  the R session after this method ran once, which could mask unrelated
  argument-validation bugs in later, unrelated code in the same session. It
  now restores whatever assert state was in effect on entry.

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
