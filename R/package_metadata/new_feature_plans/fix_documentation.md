# Fix Documentation TODOs

> **Depends on:** R-side TODOs: none. Python TODOs #758-#816: the corresponding R function's expanded documentation (they copy from it). Snapshot regeneration depends on `fix_inference_hierarchy.md`/`fix_design_hierarchy.md` completing (see header note). (Global ordering: see `_master.md`.)

Generated from the current `EDI/man/*.Rd` public API surface. This file is a work plan, not user documentation.

- Public Rd topics found: `255` (includes `ObservationalDesign`, `ObservationalDesignBlocks`, `ObservationalDesignMatching`, added after the original snapshot)
- Public R6 methods found: `504` (excludes the 128 auto-generated `$clone()` methods, which use R6's standard boilerplate and are out of scope for individualized documentation)
- Total API entries listed: `754`
- Snapshot-staleness note (2026-08-13): the completed `fix_inference_hierarchy.md`/`fix_design_hierarchy.md` migrations shrink this surface — `supports_*` hook methods, the dead design characterization flags (`is_a_fixed()`, `is_an_observational_design()`, `supports_batch_w_pregeneration()`, etc.), and the algorithmic base classes' Rd pages (`InferenceRand`, `InferenceAsymp`, `InferenceNonParamBootstrap`, `DesignBlocking`, `DesignMatching`, …) are deleted. Individual TODOs for deleted methods are marked obsolete inline; regenerate this snapshot after the migrations before starting any new documentation batch, rather than working from these counts.

## General Instructions

These instructions apply to every numbered TODO in the thin-description list below.

### Documentation Standard

For every public API entry below, replace short or generic prose with documentation that answers:

- What estimand, parameter, contrast, or design quantity is being computed.
- What model, estimating equation, randomization distribution, bootstrap law, or likelihood is used.
- The mathematical form of the key statistic, loss, likelihood, score, variance estimator, or CI inversion when relevant.
- What assumptions are required for validity, including design, response type, censoring, matching, blocking, clustering, or asymptotics.
- What input conventions the method assumes. Document required dimensions, types, ordering, treatment coding, factor levels, matching or block identifiers, weights, offsets, censoring indicators, tie handling, missing-value behavior, zero-count behavior, and boundary cases.
- How function arguments map to mathematical symbols and model parameters. State distribution parameterizations explicitly, including link functions, baseline or reference categories, nuisance parameters, treatment-coefficient indices, and whether parameters are on the natural, log, logit, hazard, odds, probability, time, or transformed scale.
- How hypothesis tests and intervals are defined. State the null and alternative hypotheses, one-sided or two-sided tail conventions, confidence level convention, whether intervals are obtained by Wald formulas, test inversion, profile likelihood, bootstrap quantiles, or randomization inversion, and how exact, asymptotic, bootstrap, jackknife, Bayesian-bootstrap, and randomization paths differ.
- What happens when the quantity is not estimable or when the class does not support the requested inference path.
- Whether the method mutates R6 object state. Document cached fields, call-order requirements, stale-cache invalidation, cloning behavior, reproducibility state, and whether repeated calls are deterministic for fixed inputs and seeds.
- Numerical implementation details that affect reproducibility, accuracy, or interpretation. Document optimizers, starting values, constraints, tolerances, gradients, Hessians, convergence criteria, line-search or trust-region behavior, stabilization tricks, fallbacks, and warnings.
- Randomness and reproducibility behavior. Document which RNG source is used, how seeds are consumed, whether parallel execution changes draw order, how Monte Carlo error is reported or should be assessed, and whether randomization or bootstrap draws can be reused.
- Computational complexity and practical limits when relevant. State the dominant scaling in subjects, pairs, blocks, clusters, covariates, bootstrap replicates, randomization draws, or outcome levels, and identify known memory or runtime bottlenecks.
- Contracts for `fast_*` and C++ backend functions. Document indexing conventions, memory layout, unchecked assumptions, domain restrictions, overflow and underflow behavior, NA/NaN handling, convergence flags, and the relationship between low-level backends and safer R wrappers.
- Links to related parent methods instead of repeating shared bootstrap, randomization, jackknife, exact, or asymptotic contracts.
- Do not repeat yourself: place shared documentation at the highest possible level, then have subclasses link to that shared documentation and document only class-specific behavior. (Updated 2026-08-13: under the shallow component hierarchy "highest possible level" means the component's owning/documenting class page — see `fix_roxygenize_lazy_component_srcrefs.md` — not a deep inheritance ancestor; the algorithmic base classes that used to host shared docs are deleted.)
- References with stable identifiers, preferably DOI, arXiv, or package/manual citations.
- References and links for specialized numerical or statistical ingredients, including approximations, optimizers, quadrature rules, transforms, corrections, and named algorithms. For example, document and cite Lanczos approximation, Stirling approximation, saddlepoint approximations, Gauss-Hermite quadrature, Cholesky decompositions, log-sum-exp stabilization, Bartlett corrections, and other esoteric implementation details when they affect formulas, accuracy, or interpretation.
- HTML links to analogous Python package documentation when it helps users compare APIs or verify model conventions.
- HTML links to Wikipedia pages only as secondary orientation aids; do not use Wikipedia as the primary source for statistical validity, formulas, or implementation details.
- Interpretation guidance and misuse warnings where needed. State causal, design-based, model-based, exchangeability, positivity, independent-censoring, proportional-hazards, proportional-odds, or large-sample assumptions clearly enough that users can tell when a result should not be used.
- Lifecycle status for APIs that are experimental, internal-but-exported, superseded, deprecated, or thin wrappers around lower-level routines.

### First-Rate Documentation Workstreams

These are cross-cutting documentation improvements that should be completed alongside the numbered API TODOs.

- Create theory vignettes by method family: `theory-incidence.Rmd`, `theory-count.Rmd`, `theory-survival.Rmd`, `theory-ordinal.Rmd`, `theory-bootstrap-randomization.Rmd`, and any additional family needed for continuous/proportion methods. Individual roxygen entries should link into these vignettes rather than repeating long derivations.
- [x] Create a notation glossary defining package-wide symbols and conventions, including `W`, `Y`, `X`, `delta`, `beta_T`, matched pairs, reservoir subjects, blocks, clusters, censoring indicators, bootstrap weights, Bayesian-bootstrap weights, randomization permutations, treatment-effect scales, and transformed outcomes. Done: `vignettes/notation-glossary.Rmd` (added `knitr`/`rmarkdown` to `Suggests` and `VignetteBuilder: knitr` to `DESCRIPTION` since no vignette infrastructure existed yet); test-rendered clean via `rmarkdown::render()`.
- Create support tables for all inference classes. Each row should include response type, allowed design types, estimand, effect scale, exact/asymptotic/bootstrap/Bayesian-bootstrap/jackknife/randomization support, likelihood-test support, required packages, and known fallback or unsupported behavior.
- Document return object schemas for every public method or `fast_*` backend that returns a list or structured object. Include field names, dimensions, parameter order, treatment-coefficient index, convergence fields, variance fields, and when fields may be `NA`, `NULL`, or omitted.
- Add explicit "scale of effect" notes throughout the inference docs. State whether the returned estimate is a mean difference, risk difference, log risk ratio, odds ratio, log odds ratio, log hazard ratio, log-time ratio, RMST difference, quantile shift, rank statistic, or other scale.
- Create a centralized validation and failure-semantics page. Cover `is_nonestimable()`, `get_nonestimable_reason()`, `get_nonestimable_stage()`, hardening, convergence failure, model separation, insufficient data, non-finite bootstrap draws, missing standard errors, unsupported exact/asymptotic/bootstrap/randomization methods, and how these states appear in return values.
- Create a method-selection guide. Include decision tables that help users choose an inference class from the design, outcome type, estimand, treatment-effect scale, sample size, censoring structure, clustering/blocking structure, and desired inference mode.
- Create an input-conventions page. Define package-wide conventions for `W`, `Y`, covariate matrices, model matrices, treatment coding, factor ordering, block and cluster identifiers, matched-pair order, weights, offsets, missingness, censoring indicators, ties, and boundary values.
- Create an R6 behavior page. Document which public methods are pure computations, which mutate object state, which cache results, which require a prior call to another method, how cloning behaves, and how users should reason about repeated calls.
- [x] Create a reproducibility page. Document RNG usage for simulation, bootstrap, Bayesian-bootstrap, and randomization methods; explain seed handling, parallel execution, draw reuse, Monte Carlo error, and how to reproduce published examples. Done: `vignettes/reproducibility.Rmd` — covers `Design$seed`/`maybe_set_seed()`, the portable one-draw-seeded `edi_rng::RRng` pattern vs. `pocock_simon_redraw_w_cpp`'s live-`.Random.seed`-continuation exception, the two non-reproducible designs (`DesignFixedAOptimal`/`DesignFixedDOptimal`, `std::random_device`) vs. `DesignFixedGreedy`'s seed-reproducible-despite-OpenMP pattern, randomization inference's reuse of the design's own draw mechanism (plus permutation caching), non-parametric/Bayesian bootstrap RNG sources, `SimulationFramework`'s per-replication/per-cache-job seed derivation (`seed + i`, `seed + 1000003L + job_idx`) and why that makes parallel runs reproducible regardless of `num_cores`/backend, Monte Carlo error rules of thumb, and a reproduce-a-published-example checklist. Test-rendered clean via `rmarkdown::render()`.
- [x] Create a backend-contracts page for `fast_*` and C++ utilities. Document low-level assumptions that are intentionally not checked, argument dimensions and storage order, numeric domains, overflow/underflow safeguards, convergence flags, and wrapper-to-backend equivalence. Done: `vignettes/backend-contracts.Rmd` — covers the R6-validates/backend-trusts boundary (with `fixed_idx`/`fixed_values`'s `make_fixed_param_spec()` validation as the one documented exception), column-major/zero-copy `Eigen::Map` storage vs. NumPy's row-major default, the 1-based-R/0-based-Python indexing split, numeric overflow/underflow safeguards (`fast_log1pexp`, `pnorm_fast`/`fast_log_pnorm` clamps, `logit`/`inv_logit` clamps, `EDI_SEPARATION_THRESHOLD`, `fast_erfc`'s Cephes/libm split), the package-wide `converged`/`iterations`/`gradient_norm`/`neg_loglik`-`neg_ll`-`loglik`/`vcov`-`std_err`-`z_vals`/`fisher_information`-`observed_information`-`information` return-field conventions, the `EDI_CORE_ONLY` shared-header and `*_internal()` shared-core patterns that make the R and Python bindings provably the same compiled code, and `NA`/`NaN` handling. Test-rendered clean via `rmarkdown::render()`.
- Add cross-language analog links for each model family. Use statsmodels, lifelines, scipy, scikit-survival, or other official package documentation where useful, and label these links as analogous APIs or implementation references rather than EDI dependencies.
- [x] Add stable citation keys and a reference map. Prefer `\doi{...}`, arXiv links, package manuals, or canonical book references. Maintain a central `REFERENCES.md` or package citation map from method family/class to references. Done: `R/EDI/REFERENCES.md` — extracted and deduplicated every `@references`/`\doi{}` roxygen entry across `R/EDI/R/*.R` and `R/EDI/src/*.cpp` (verified complete via a `\doi{}`-file cross-check), organized by family (design randomization/matching theory, cross-cutting inference methods, GEE, incidence, ordinal, survival, proportion, backend numerical utilities, simulation framework) with a stable `[Author+Year]` key and a "used by" class/function list per entry. Includes an honest "cited by author-year only" section for two works (Kapelner & Krieger 2021, Morrison & Owen 2025) whose source citations lack a full bibliographic record rather than fabricating one. Follow-up pass: added real `@references` blocks (Kaplan & Meier 1958, Brookmeyer & Crowley 1982, Turnbull 1976, Royston & Parmar 2013, Gehan 1965, Peto & Peto 1972, Mantel 1966, Sun 1996, McCullagh 1980, Peterson & Harrell 1990, Pinheiro & Bates 1995) to `InferenceSurvivalKMDiff`, `InferenceSurvivalRestrictedMeanDiff`, `InferenceSurvivalGehanWilcox`, `InferenceSurvivalLogRank`, `InferenceOrdinalPropOddsRegr`, `InferenceOrdinalPartialProportionalOddsRegr`, and `fast_ordinal_glmm_cpp` (all confirmed safe: not gated by `fix_inference_hierarchy.md`), closing most of the original coverage-gap list. The remaining gap — adjacent-category/continuation-ratio/stereotype ordinal logit and zero-inflated/hurdle count (7 classes) — is confirmed genuinely blocked (still `R6::R6Class` old-ladder, not `define_inference_class`), with the correct citations pre-identified in `REFERENCES.md`'s "Coverage gaps" section for whoever migrates those classes. Added `R/package_tests/check_references_sync.R` (a coverage/staleness checker, not a citation-text diff — verifies every `@references`-bearing file is indexed in `REFERENCES.md` and every `REFERENCES.md` "Used by:" name still exists in the codebase) and wired it into `.githooks/pre-push`, running before `fast_roxygenize.R`; it caught and helped fix 3 real pre-existing `REFERENCES.md` bugs (a wrong class name, a missing R-side function-name alias, and the stale `DesignFixedAOptimal`/`DesignFixedDOptimal` names left over from their merge into `DesignFixedGreedyDOptimal`).
- [x] Add validation-evidence references. For important methods, link examples, tests, or vignettes to published numerical examples, simulation checks, package-to-package comparisons, or closed-form special cases that demonstrate the implementation matches the documented formulas. Done: `vignettes/validation-evidence.Rmd` — surveyed the `R/EDI/tests/testthat/` suite (verified all 32 cited test files actually exist and their claims match real `test_that()` titles, not inferred) and organized by family (continuous, incidence, count, ordinal, survival, proportion, GEE/GLMM, numerical utilities) into tables mapping each `fast_*`/`Inference*` implementation to the specific test file(s) proving it against a reference R package (`stats::glm`, `survival::coxph`/`survreg`, `MASS::glm.nb`/`rlm`, `betareg`, `VGAM`, `ordinal::clm`, `lme4`, `glmmTMB`, `pscl`, `geepack`/`multgee`, `copula`, `gamlss.dist`), a closed-form/limiting-case reduction, or a `numDeriv`-style analytic-vs-numerical gradient/Hessian check. Documents `SimulationFrameworkReport`'s built-in `coverage_pval`/`size_pval` exact-binomial calibration mechanism as the package's simulation-check category (no pre-computed calibration report is checked into the repo). Includes an honest coverage note for custom combined-kernel estimators (`fast_cpoisson_combined_with_var_cpp`, `fast_clogit_plus_glmm_cpp`) that have no single-package analogue to compare against directly.
- Improve examples for public classes. Each exported class should have one tiny runnable example, one realistic `\donttest{}` example where appropriate, and one example or note showing the returned estimand scale.
- Improve pkgdown organization. Group APIs by design family, outcome family, inference mode, and backend utility; add search-friendly aliases for common statistical terms; ensure equations render correctly; and verify that reference pages link to the relevant theory vignettes, support tables, and external references.
- Add documentation tests. The test should parse generated Rd files and fail on placeholder descriptions such as "TODO", "Compute pval", "Initialize object", missing references for theoretical methods, broken links, repeated boilerplate that should live in a parent, public methods without argument/return documentation, undocumented defaults, unresolved mathematical symbols, malformed equations, misspellings, and exported objects missing from the reference index.

### External HTML Link Policy

Use three classes of links in the roxygen pass:

- Primary statistical references: papers, arXiv pages, DOI landing pages, books, package vignettes, or package manuals that define the method.
- Analogous software documentation: official Python/R/SAS documentation showing a comparable model API, parameterization, likelihood, optimizer, or returned object.
- Orientation links: Wikipedia pages for common concepts such as likelihood functions, score tests, Cox models, bootstrap, or special functions. These are useful for readers but should not replace primary references.

When adding analogous Python links, explicitly say they are analogs rather than dependencies. For example, a `fast_poisson_regression_cpp()` doc can link to statsmodels' Poisson/GLM documentation as a comparable Python API while still documenting EDI's own parameterization and C++ return fields.

### Analogous Python Documentation Links

Use these links as a starter map while fixing TODOs:

- Generalized linear models and exponential-family conventions: [statsmodels GLM](https://www.statsmodels.org/stable/glm.html).
- Discrete, binary, count, hurdle, zero-inflated, conditional-logit, and conditional-Poisson models: [statsmodels discrete models](https://www.statsmodels.org/stable/discretemod.html).
- Conditional Poisson likelihood with grouped intercepts conditioned out: [statsmodels ConditionalPoisson](https://www.statsmodels.org/dev/generated/statsmodels.discrete.conditional_models.ConditionalPoisson.html).
- Cox proportional-hazards models and survival APIs: [lifelines CoxPHFitter](https://lifelines.readthedocs.io/en/latest/fitters/regression/CoxPHFitter.html), [statsmodels duration models](https://www.statsmodels.org/dev/duration.html), and [scikit-survival documentation](https://scikit-survival.readthedocs.io/).
- Survival weighting and robust/sandwich examples: [lifelines examples](https://lifelines.readthedocs.io/en/latest/Examples.html).
- Special functions used by `fast_*` math utilities: [SciPy special functions](https://scipy.github.io/devdocs/reference/special.html) and [SciPy digamma](https://docs.scipy.org/doc/scipy/reference/generated/scipy.special.digamma.html).
- Distribution functions and density parameterizations used by fast likelihood code: [SciPy stats beta](https://docs.scipy.org/doc/scipy/reference/generated/scipy.stats.beta.html), [SciPy stats distributions index](https://docs.scipy.org/doc/scipy/reference/stats.html).

### Wikipedia Orientation Links

Use these sparingly as "See also" orientation links, paired with primary references:

- [Likelihood function](https://en.wikipedia.org/wiki/Likelihood_function)
- [Maximum likelihood estimation](https://en.wikipedia.org/wiki/Maximum_likelihood_estimation)
- [Score test](https://en.wikipedia.org/wiki/Score_test)
- [Likelihood-ratio test](https://en.wikipedia.org/wiki/Likelihood-ratio_test)
- [Wald test](https://en.wikipedia.org/wiki/Wald_test)
- [Bootstrap](https://en.wikipedia.org/wiki/Bootstrapping_%28statistics%29)
- [Randomization test](https://en.wikipedia.org/wiki/Randomization_test)
- [Generalized linear model](https://en.wikipedia.org/wiki/Generalized_linear_model)
- [Logistic regression](https://en.wikipedia.org/wiki/Logistic_regression)
- [Poisson regression](https://en.wikipedia.org/wiki/Poisson_regression)
- [Negative binomial distribution](https://en.wikipedia.org/wiki/Negative_binomial_distribution)
- [Beta distribution](https://en.wikipedia.org/wiki/Beta_distribution)
- [Ordinal regression](https://en.wikipedia.org/wiki/Ordinal_regression)
- [Quantile regression](https://en.wikipedia.org/wiki/Quantile_regression)
- [Cox proportional hazards model](https://en.wikipedia.org/wiki/Proportional_hazards_model)
- [Kaplan-Meier estimator](https://en.wikipedia.org/wiki/Kaplan%E2%80%93Meier_estimator)
- [Log-rank test](https://en.wikipedia.org/wiki/Logrank_test)
- [Gamma function](https://en.wikipedia.org/wiki/Gamma_function)
- [Digamma function](https://en.wikipedia.org/wiki/Digamma_function)
- [Lanczos approximation](https://en.wikipedia.org/wiki/Lanczos_approximation)
- [Stirling's approximation](https://en.wikipedia.org/wiki/Stirling%27s_approximation)
- [Gauss-Hermite quadrature](https://en.wikipedia.org/wiki/Gauss%E2%80%93Hermite_quadrature)
- [LogSumExp](https://en.wikipedia.org/wiki/LogSumExp)

### Reference Backlog

Add exact citations while editing the method docs. At minimum, verify and cite the following where relevant:

- Zhang exact/randomization incidence inference paper on arXiv.
- Azriel et al. paper on CMH / covariate-adaptive incidence inference on arXiv.
- Bai adjusted t-test / matched-pair plus reservoir estimator references.
- Lin (2013) covariate-adjusted estimator reference.
- Kaplan-Meier, log-rank, Gehan-Wilcoxon, RMST, Cox PH, stratified Cox, Weibull AFT, frailty, and Clayton-copula survival references.
- GLM and likelihood references for Wald, score, likelihood-ratio, gradient, Bartlett correction, quasi-likelihood, GEE, GLMM, CLMM, conditional logit, hurdle, zero-inflated, negative-binomial, beta, fractional-logit, and quantile-regression models.
- Bootstrap references for percentile/basic, bootstrap-t/studentized, BCa, Bayesian bootstrap, m-out-of-n bootstrap, PRW subsampling, double bootstrap, prepivoting, and calibrated/smoothed variants.
- Randomization-inference references for sharp-null permutation tests, custom statistics, and confidence-interval inversion.

### Primary Reference Hierarchy

Use the strongest primary reference available for each method:

1. Method-defining papers for package-specific or named procedures. Use these for Zhang exact/randomization incidence methods, Azriel CMH/covariate-adaptive incidence methods, Bai adjusted-t methods, Lin covariate adjustment, Newcombe intervals, Miettinen-Nurminen intervals, Bartlett corrections, BCa bootstrap, PRW subsampling, and any KK matching-on-the-fly estimators.
2. Journal papers or arXiv preprints for recent methods that do not yet have canonical textbook treatment. Prefer the published journal version when available; cite arXiv when it is the only stable public version or when the implementation follows the preprint exactly.
3. Textbooks and monographs for standard model families and asymptotic theory. Use these for GLMs, likelihood theory, Wald/score/LR tests, survival analysis, categorical/ordinal models, count regression, randomization inference, bootstrap theory, and estimating equations.
4. Software manuals only for implementation analogs, API comparisons, parameterization checks, and returned-object conventions. Do not cite software manuals as the sole justification for the statistical method unless the documented object is itself a software algorithm.
5. Wikipedia only as a "See also" orientation link, never as the primary statistical reference.

Good textbook or monograph candidates to map into TODOs:

- GLM and likelihood theory: McCullagh and Nelder, *Generalized Linear Models*; Casella and Berger, *Statistical Inference*; Pawitan, *In All Likelihood*.
- Count regression: Cameron and Trivedi, *Regression Analysis of Count Data*.
- Categorical and ordinal data: Agresti, *Categorical Data Analysis* and *Analysis of Ordinal Categorical Data*.
- Survival analysis: Cox and Oakes, *Analysis of Survival Data*; Kalbfleisch and Prentice, *The Statistical Analysis of Failure Time Data*; Klein and Moeschberger, *Survival Analysis*.
- Bootstrap and resampling: Efron and Tibshirani, *An Introduction to the Bootstrap*; Davison and Hinkley, *Bootstrap Methods and Their Application*.
- Randomization and causal inference: Fisher, *The Design of Experiments*; Rosenbaum, *Observational Studies*; Imbens and Rubin, *Causal Inference*.
- Quantile regression: Koenker, *Quantile Regression*.
- GEE and mixed models: Liang and Zeger papers for GEE; standard GLMM references for mixed-model likelihood and quadrature.

## Prerequisite: Fix the `roxygenize()` Lazy-Component-Stub Blocker

`Rscript R/fast_roxygenize.R` currently aborts the entire package-wide `roxygenize()`
run with `Error: ! R6 class <InferenceAllKKWilcoxIVWC> lacks source references.` This
is a systemic issue (39 of ~41 registered inference mixin components use a
`load_policy = "lazy"` stub-method mechanism that strips R's `srcref` attribute; 26
`define_inference_class(...)` call sites across 24 files are potentially affected, not
just this one class) that blocks regenerating **any** `man/*.Rd` file from source, and
therefore blocks verifying the numbered TODOs below against the real generator rather
than by hand. See `package_metadata/new_feature_plans/fix_roxygenize_lazy_component_srcrefs.md`
for the full root-cause analysis and proposed fix. These three items are prerequisites
for reliably finishing the rest of this document and must be done first.

- [x] TODO #001: Implement the srcref fix for `lazy_component_public_stub()` /
  `lazy_component_private_stub()` in `R/mixin_contracts.R` (primary approach: copy the
  real srcref from each component's actual method implementation onto its lazy stub;
  fallback: patch `fast_roxygenize.R`'s R6 method-extraction to tolerate tagged
  srcref-less stubs) — see the plan document's "Proposed fix" section.
- [x] TODO #002: Run `Rscript R/fast_roxygenize.R` end-to-end and confirm it completes
  without the `lacks source references` abort or any new error; spot-check generated
  `.Rd` files for `InferenceAllKKWilcoxIVWC` and at least 2-3 other classes drawn from
  the 26 `define_inference_class(...)` call sites to confirm lazy-component methods
  get sensible source attribution (not silently wrong) — see the plan document's
  "Verification plan" section.
- [x] TODO #003: Re-run `fast_roxygenize.R` against every roxygen-source edit already
  made under the "Thinly Described API TODOs" section below during the period this
  blocker was open, and reconcile any drift between the hand-verified `.Rd` output
  (via `tools::parse_Rd()`/`Rd2txt()`) and what the real generator now produces.

## Thinly Described API TODOs

Each numbered item below is an API entry whose generated description is thin or needs review. Edit the roxygen source, apply the General Instructions above, then regenerate Rd. The current description length is included as a triage signal; consult the generated Rd or source file for the existing wording. The `TODO #NNN` identifiers are stable range targets for instructions such as "do 41-50".


### `build_cox_data_cache_cpp.Rd`

- [x] TODO #004: Topic `build_cox_data_cache_cpp` (current description `95` chars).

### `build_stratified_cox_data_cache_cpp.Rd`

- [x] TODO #005: Topic `build_stratified_cox_data_cache_cpp` (current description `117` chars).

### `check_package_installed.Rd`

- [x] TODO #006: Topic `check_package_installed` (current description `105` chars).

### `compute_coxph_rand_bootstrap_cpp.Rd`

- [x] TODO #007: Topic `compute_coxph_rand_bootstrap_cpp` (current description `392` chars).

### `create_model_matrix_from_features.Rd`

- [x] TODO #008: Topic `create_model_matrix_from_features` (current description `203` chars).

### `DesignFixedAOptimal.Rd`

(Superseded 2026-08-16: class merged into `DesignFixedGreedyDOptimal`, Rd page
deleted; the expanded documentation content was carried into the merged
class's roxygen.)

- [x] TODO #009: Method `DesignFixedAOptimal$new()` (current description `56` chars).
- [x] TODO #010: Topic `DesignFixedAOptimal` (current description `302` chars).

### `DesignFixedBernoulli.Rd`

- [x] TODO #011: Method `DesignFixedBernoulli$is_a_bernoulli_capable()` (current description `56` chars).
- [x] TODO #012: Method `DesignFixedBernoulli$new()` (current description `48` chars).
- [x] TODO #013: Topic `DesignFixedBernoulli` (current description `144` chars).

### `DesignFixedBinaryMatch.Rd`

- [x] TODO #014: Method `DesignFixedBinaryMatch$assign_w_to_all_subjects()` (current description `72` chars).
- [x] TODO #015: Method `DesignFixedBinaryMatch$is_a_kk_matching_capable()` (current description `66` chars).
- [x] TODO #016: Method `DesignFixedBinaryMatch$new()` (current description `51` chars).
- [x] TODO #017: Method `DesignFixedBinaryMatch$supports_batch_w_pregeneration()` (current description `57` chars).
- [x] TODO #018: Topic `DesignFixedBinaryMatch` (current description `281` chars).

### `DesignFixedBlockedCluster.Rd`

- [x] TODO #019: Method `DesignFixedBlockedCluster$is_a_cluster_capable()` (current description `54` chars).
- [x] TODO #020: Method `DesignFixedBlockedCluster$new()` (current description `69` chars).
- [x] TODO #021: Topic `DesignFixedBlockedCluster` (current description `247` chars).

### `DesignFixedBlocking.Rd`

- [x] TODO #022: Method `DesignFixedBlocking$new()` (current description `58` chars).
- [x] TODO #023: Topic `DesignFixedBlocking` (current description `140` chars).

### `DesignFixedCluster.Rd`

- [x] TODO #024: Method `DesignFixedCluster$is_a_cluster_capable()` (current description `54` chars).
- [x] TODO #025: Method `DesignFixedCluster$new()` (current description `57` chars).
- [x] TODO #026: Topic `DesignFixedCluster` (current description `236` chars).

### `DesignFixedDOptimal.Rd`

(Superseded 2026-08-16: class merged into `DesignFixedGreedyDOptimal`, Rd page
deleted; the expanded documentation content was carried into the merged
class's roxygen. The `reproducibility.Rmd` vignette entry above was updated
for the merge and the now-seed-reproducible kernels.)

- [x] TODO #027: Method `DesignFixedDOptimal$new()` (current description `55` chars).
- [x] TODO #028: Topic `DesignFixedDOptimal` (current description `291` chars).

### `DesignFixedFactorial.Rd`

- [x] TODO #029: Method `DesignFixedFactorial$get_w_factorial()` (current description `58` chars).
- [x] TODO #030: Method `DesignFixedFactorial$new()` (current description `48` chars).
- [x] TODO #031: Topic `DesignFixedFactorial` (current description `224` chars).

### `DesignFixedGreedy.Rd`

- [x] TODO #032: Method `DesignFixedGreedy$new()` (current description `52` chars).
- [x] TODO #033: Method `DesignFixedGreedy$supports_batch_w_pregeneration()` (current description `70` chars).
- [x] TODO #034: Topic `DesignFixedGreedy` (current description `196` chars).

### `DesignFixediBCRD.Rd`

- [x] TODO #035: Method `DesignFixediBCRD$new()` (current description `69` chars).
- [x] TODO #036: Topic `DesignFixediBCRD` (current description `162` chars).

### `DesignFixedMatchingGreedyPairSwitching.Rd`

- [x] TODO #037: Method `DesignFixedMatchingGreedyPairSwitching$new()` (current description `90` chars).
- [x] TODO #038: Method `DesignFixedMatchingGreedyPairSwitching$supports_batch_w_pregeneration()` (current description `70` chars).
- [x] TODO #039: Topic `DesignFixedMatchingGreedyPairSwitching` (current description `254` chars).

### `DesignFixedOptimalBlocks.Rd`

- [x] TODO #040: Method `DesignFixedOptimalBlocks$new()` (current description `41` chars).
- [x] TODO #041: Method `DesignFixedOptimalBlocks$supports_batch_w_pregeneration()` (current description `57` chars).
- [x] TODO #042: Topic `DesignFixedOptimalBlocks` (current description `395` chars).

### `DesignFixedRerandomization.Rd`

- [x] TODO #043: Method `DesignFixedRerandomization$new()` (current description `54` chars).
- [x] TODO #044: Topic `DesignFixedRerandomization` (current description `327` chars).

### `DesignSeqOneByOneAtkinson.Rd`

- [x] TODO #045: Method `DesignSeqOneByOneAtkinson$assign_wt()` (current description `52` chars).
- [x] TODO #046: Method `DesignSeqOneByOneAtkinson$new()` (current description `53` chars).
- [x] TODO #047: Topic `DesignSeqOneByOneAtkinson` (current description `230` chars).

### `DesignSeqOneByOneBernoulli.Rd`

- [x] TODO #048: Method `DesignSeqOneByOneBernoulli$assign_wt()` (current description `52` chars).
- [x] TODO #049: Method `DesignSeqOneByOneBernoulli$is_a_bernoulli_capable()` (current description `56` chars).
- [x] TODO #050: Method `DesignSeqOneByOneBernoulli$new()` (current description `53` chars).
- [x] TODO #051: Topic `DesignSeqOneByOneBernoulli` (current description `144` chars).

### `DesignSeqOneByOneEfron.Rd`

- [x] TODO #052: Method `DesignSeqOneByOneEfron$assign_wt()` (current description `52` chars).
- [x] TODO #053: Method `DesignSeqOneByOneEfron$new()` (current description `62` chars).
- [x] TODO #054: Topic `DesignSeqOneByOneEfron` (current description `153` chars).

### `DesignSeqOneByOneiBCRD.Rd`

- [x] TODO #055: Method `DesignSeqOneByOneiBCRD$add_one_subject_to_experiment_and_assign()` (current description `37` chars).
- [x] TODO #056: Method `DesignSeqOneByOneiBCRD$assign_wt()` (current description `52` chars).
- [x] TODO #057: Method `DesignSeqOneByOneiBCRD$new()` (current description `52` chars).
- [x] TODO #058: Topic `DesignSeqOneByOneiBCRD` (current description `228` chars).

### `DesignSeqOneByOneKK14.Rd`

- [x] TODO #059: Method `DesignSeqOneByOneKK14$assign_wt()` (current description `52` chars).
- [x] TODO #060: Method `DesignSeqOneByOneKK14$is_a_kk_matching_capable()` (current description `66` chars).
- [x] TODO #061: Method `DesignSeqOneByOneKK14$new()` (current description `48` chars).
- [x] TODO #062: Topic `DesignSeqOneByOneKK14` (current description `282` chars).

### `DesignSeqOneByOneKK21.Rd`

- [x] TODO #063: Method `DesignSeqOneByOneKK21$assign_wt()` (current description `70` chars).
- [x] TODO #064: Method `DesignSeqOneByOneKK21$get_covariate_weights()` (current description `62` chars).
- [x] TODO #065: Method `DesignSeqOneByOneKK21$get_iteration_weights()` (current description `49` chars).
- [x] TODO #066: Method `DesignSeqOneByOneKK21$new()` (current description `119` chars).
- [x] TODO #067: Topic `DesignSeqOneByOneKK21` (current description `282` chars).

### `DesignSeqOneByOneKK21stepwise.Rd`

- [x] TODO #068: Method `DesignSeqOneByOneKK21stepwise$new()` (current description `198` chars).
- [x] TODO #069: Topic `DesignSeqOneByOneKK21stepwise` (current description `282` chars).

### `DesignSeqOneByOnePocockSimon.Rd`

- [x] TODO #070: Method `DesignSeqOneByOnePocockSimon$assign_wt()` (current description `64` chars).
- [x] TODO #071: Method `DesignSeqOneByOnePocockSimon$new()` (current description `58` chars).
- [x] TODO #072: Topic `DesignSeqOneByOnePocockSimon` (current description `232` chars).

### `DesignSeqOneByOneRandomBlockSize.Rd`

- [x] TODO #073: Method `DesignSeqOneByOneRandomBlockSize$assign_wt()` (current description `52` chars).
- [x] TODO #074: Method `DesignSeqOneByOneRandomBlockSize$new()` (current description `61` chars).
- [x] TODO #075: Topic `DesignSeqOneByOneRandomBlockSize` (current description `339` chars).

### `DesignSeqOneByOneSPBR.Rd`

- [x] TODO #076: Method `DesignSeqOneByOneSPBR$assign_wt()` (current description `52` chars).
- [x] TODO #077: Method `DesignSeqOneByOneSPBR$new()` (current description `69` chars).
- [x] TODO #078: Topic `DesignSeqOneByOneSPBR` (current description `251` chars).

### `DesignSeqOneByOneUrn.Rd`

- [x] TODO #079: Method `DesignSeqOneByOneUrn$assign_wt()` (current description `52` chars).
- [x] TODO #080: Method `DesignSeqOneByOneUrn$new()` (current description `48` chars).
- [x] TODO #081: Topic `DesignSeqOneByOneUrn` (current description `273` chars).

### `dot-normalize_optimizer_algorithm.Rd`

- [x] TODO #082: Topic `.normalize_optimizer_algorithm` (current description `156` chars).

### `edi_build_info_cpp.Rd`

- [x] TODO #083: Topic `edi_build_info_cpp` (current description `247` chars).

### `exact_jonckheere_terpstra_pval_cpp.Rd`

- [x] TODO #084: Topic `exact_jonckheere_terpstra_pval_cpp` (current description `115` chars).

### `expand_adjacent_category_data_cpp.Rd`

- [x] TODO #085: Topic `expand_adjacent_category_data_cpp` (current description `106` chars).

### `expand_continuation_ratio_data_cpp.Rd`

- [x] TODO #086: Topic `expand_continuation_ratio_data_cpp` (current description `102` chars).

### `fast_adjacent_category_logit_cpp.Rd`

- [x] TODO #087: Topic `fast_adjacent_category_logit_cpp` (current description `90` chars).

### `fast_adjacent_category_logit_with_var_cpp.Rd`

- [x] TODO #088: Topic `fast_adjacent_category_logit_with_var_cpp` (current description `124` chars).

### `fast_beta_regression_cpp.Rd`

- [x] TODO #089: Topic `fast_beta_regression_cpp` (current description `107` chars).

### `fast_beta_regression_weighted_cpp.Rd`

- [x] TODO #090: Topic `fast_beta_regression_weighted_cpp` (current description `106` chars).

### `fast_beta_regression_with_var_cpp.Rd`

- [x] TODO #091: Topic `fast_beta_regression_with_var_cpp` (current description `144` chars).

### `fast_beta_regression_with_var.Rd`

- [x] TODO #092: Topic `fast_beta_regression_with_var` (current description `369` chars).

### `fast_beta_regression.Rd`

- [x] TODO #093: Topic `fast_beta_regression` (current description `277` chars).

### `fast_continuation_ratio_regression_cpp.Rd`

- [x] TODO #094: Topic `fast_continuation_ratio_regression_cpp` (current description `97` chars).

### `fast_continuation_ratio_regression_with_var_cpp.Rd`

- [x] TODO #095: Topic `fast_continuation_ratio_regression_with_var_cpp` (current description `141` chars).

### `fast_coxph_regression_cpp.Rd`

- [x] TODO #096: Topic `fast_coxph_regression_cpp` (current description `109` chars).

### `fast_coxph_regression_prebuilt_cpp.Rd`

- [x] TODO #097: Topic `fast_coxph_regression_prebuilt_cpp` (current description `115` chars).

### `fast_coxph_regression.Rd`

- [x] TODO #098: Topic `fast_coxph_regression` (current description `264` chars).

### `fast_cpoisson_combined_with_var_cpp.Rd`

- [x] TODO #099: Topic `fast_cpoisson_combined_with_var_cpp` (current description `183` chars).

### `fast_digamma_vec_cpp.Rd`

- [x] TODO #100: Topic `fast_digamma_vec_cpp` (current description `144` chars).

### `fast_dnbinom_mu_vec_cpp.Rd`

- [x] TODO #101: Topic `fast_dnbinom_mu_vec_cpp` (current description `295` chars).

### `fast_hurdle_negbin_with_var_cpp.Rd`

- [x] TODO #102: Topic `fast_hurdle_negbin_with_var_cpp` (current description `119` chars).

### `fast_identity_binomial_regression_cpp.Rd`

- [x] TODO #103: Topic `fast_identity_binomial_regression_cpp` (current description `117` chars).

### `fast_identity_binomial_regression_weighted_cpp.Rd`

- [x] TODO #104: Topic `fast_identity_binomial_regression_weighted_cpp` (current description `135` chars).

### `fast_identity_binomial_regression_with_var_cpp.Rd`

- [x] TODO #105: Topic `fast_identity_binomial_regression_with_var_cpp` (current description `151` chars).

### `fast_lbeta_vec_cpp.Rd`

- [x] TODO #106: Topic `fast_lbeta_vec_cpp` (current description `153` chars).

### `fast_lgamma_vec_cpp.Rd`

- [x] TODO #107: Topic `fast_lgamma_vec_cpp` (current description `128` chars).

### `fast_log_binomial_regression_cpp.Rd`

- [x] TODO #108: Topic `fast_log_binomial_regression_cpp` (current description `105` chars).

### `fast_log_binomial_regression_weighted_cpp.Rd`

- [x] TODO #109: Topic `fast_log_binomial_regression_weighted_cpp` (current description `123` chars).

### `fast_log_binomial_regression_with_var_cpp.Rd`

- [x] TODO #110: Topic `fast_log_binomial_regression_with_var_cpp` (current description `125` chars).

### `fast_log_dnorm_vec_cpp.Rd`

- [x] TODO #111: Topic `fast_log_dnorm_vec_cpp` (current description `123` chars).

### `fast_log_pnorm_vec_cpp.Rd`

- [x] TODO #112: Topic `fast_log_pnorm_vec_cpp` (current description `162` chars).

### `fast_logistic_regression_cpp.Rd`

- [x] TODO #113: Topic `fast_logistic_regression_cpp` (current description `77` chars).

### `fast_logistic_regression_weighted_cpp.Rd`

- [x] TODO #114: Topic `fast_logistic_regression_weighted_cpp` (current description `95` chars).

### `fast_logistic_regression_with_var_cpp.Rd`

- [x] TODO #115: Topic `fast_logistic_regression_with_var_cpp` (current description `121` chars).

### `fast_logistic_regression_with_var.Rd`

- [x] TODO #116: Topic `fast_logistic_regression_with_var` (current description `315` chars).

### `fast_logistic_regression.Rd`

- [x] TODO #117: Topic `fast_logistic_regression` (current description `262` chars).

### `fast_neg_bin_cpp.Rd`

- [x] TODO #118: Topic `fast_neg_bin_cpp` (current description `102` chars).

### `fast_neg_bin_weighted_cpp.Rd`

- [x] TODO #119: Topic `fast_neg_bin_weighted_cpp` (current description `132` chars).

### `fast_neg_bin_with_var_cpp.Rd`

- [x] TODO #120: Topic `fast_neg_bin_with_var_cpp` (current description `148` chars).

### `fast_negbin_regression_with_var.Rd`

- [x] TODO #121: Topic `fast_negbin_regression_with_var` (current description `406` chars).

### `fast_negbin_regression.Rd`

- [x] TODO #122: Topic `fast_negbin_regression` (current description `302` chars).

### `fast_ols_cpp.Rd`

- [x] TODO #123: Topic `fast_ols_cpp` (current description `369` chars).

### `fast_ols_with_var_cpp.Rd`

- [x] TODO #124: Topic `fast_ols_with_var_cpp` (current description `282` chars).

### `fast_ordinal_cauchit_regression_cpp.Rd`

- [x] TODO #125: Topic `fast_ordinal_cauchit_regression_cpp` (current description `111` chars).

### `fast_ordinal_cauchit_regression_with_var_cpp.Rd`

- [x] TODO #126: Topic `fast_ordinal_cauchit_regression_with_var_cpp` (current description `124` chars).

### `fast_ordinal_cloglog_regression_cpp.Rd`

- [x] TODO #127: Topic `fast_ordinal_cloglog_regression_cpp` (current description `111` chars).

### `fast_ordinal_cloglog_regression_with_var_cpp.Rd`

- [x] TODO #128: Topic `fast_ordinal_cloglog_regression_with_var_cpp` (current description `124` chars).

### `fast_ordinal_glmm_cpp.Rd`

- [x] TODO #129: Topic `fast_ordinal_glmm_cpp` (current description `121` chars).

### `fast_ordinal_probit_regression_cpp.Rd`

- [x] TODO #130: Topic `fast_ordinal_probit_regression_cpp` (current description `109` chars).

### `fast_ordinal_probit_regression_with_var_cpp.Rd`

- [x] TODO #131: Topic `fast_ordinal_probit_regression_with_var_cpp` (current description `122` chars).

### `fast_ordinal_regression_cpp.Rd`

- [x] TODO #132: Topic `fast_ordinal_regression_cpp` (current description `95` chars).

### `fast_ordinal_regression_weighted_cpp.Rd`

- [x] TODO #133: Topic `fast_ordinal_regression_weighted_cpp` (current description `113` chars).

### `fast_ordinal_regression_with_var_cpp.Rd`

- [x] TODO #134: Topic `fast_ordinal_regression_with_var_cpp` (current description `108` chars).

### `fast_poisson_regression_cpp.Rd`

- [x] TODO #135: Topic `fast_poisson_regression_cpp` (current description `208` chars).

### `fast_poisson_regression_weighted_cpp.Rd`

- [x] TODO #136: Topic `fast_poisson_regression_weighted_cpp` (current description `93` chars).

### `fast_poisson_regression_with_var_cpp.Rd`

- [x] TODO #137: Topic `fast_poisson_regression_with_var_cpp` (current description `127` chars).

### `fast_probit_regression_cpp.Rd`

- [x] TODO #138: Topic `fast_probit_regression_cpp` (current description `84` chars).

### `fast_probit_regression_with_var_cpp.Rd`

- [x] TODO #139: Topic `fast_probit_regression_with_var_cpp` (current description `117` chars).

### `fast_qnorm_vec_cpp.Rd`

- [x] TODO #140: Topic `fast_qnorm_vec_cpp` (current description `200` chars).

### `fast_quasipoisson_regression_with_var_cpp.Rd`

- [x] TODO #141: Topic `fast_quasipoisson_regression_with_var_cpp` (current description `139` chars).

### `fast_robust_regression_cpp.Rd`

- [x] TODO #142: Topic `fast_robust_regression_cpp` (current description `83` chars).

### `fast_stereotype_logit_cpp.Rd`

- [x] TODO #143: Topic `fast_stereotype_logit_cpp` (current description `113` chars).

### `fast_stereotype_logit_with_var_cpp.Rd`

- [x] TODO #144: Topic `fast_stereotype_logit_with_var_cpp` (current description `126` chars).

### `fast_stereotype_profile_loglik_cpp.Rd`

- [x] TODO #145: Topic `fast_stereotype_profile_loglik_cpp` (current description `131` chars).

### `fast_trigamma_vec_cpp.Rd`

- [x] TODO #146: Topic `fast_trigamma_vec_cpp` (current description `148` chars).

### `fast_weibull_regression_cpp.Rd`

- [x] TODO #147: Topic `fast_weibull_regression_cpp` (current description `85` chars).

### `fast_weibull_regression.Rd`

- [x] TODO #148: Topic `fast_weibull_regression` (current description `167` chars).

### `fast_zero_augmented_poisson_cpp.Rd`

- [x] TODO #149: Topic `fast_zero_augmented_poisson_cpp` (current description `134` chars).

### `fast_zero_one_inflated_beta_cpp.Rd`

- [x] TODO #150: Topic `fast_zero_one_inflated_beta_cpp` (current description `135` chars).

### `gcomp_fractional_logit_point_estimate_cpp.Rd`

- [x] TODO #151: Topic `gcomp_fractional_logit_point_estimate_cpp` (current description `165` chars).

### `gcomp_logistic_point_estimate_cpp.Rd`

- [x] TODO #152: Topic `gcomp_logistic_point_estimate_cpp` (current description `158` chars).

### `gcomp_logistic_post_fit_cpp.Rd`

- [x] TODO #153: Topic `gcomp_logistic_post_fit_cpp` (current description `101` chars).

### `gcomp_ordinal_proportional_odds_post_fit_cpp.Rd`

- [x] TODO #154: Topic `gcomp_ordinal_proportional_odds_post_fit_cpp` (current description `135` chars).

### `generate_covariate_dataset.Rd`

- [x] TODO #155: Topic `generate_covariate_dataset` (current description `330` chars).

### `get_beta_regression_hessian_cpp.Rd`

- [x] TODO #156: Topic `get_beta_regression_hessian_cpp` (current description `133` chars).

### `get_bootstrap_dispatch_policy.Rd`

- [x] TODO #157: Topic `get_bootstrap_dispatch_policy` (current description `205` chars).

### `get_cold_start_dispatch_policy.Rd`

- [x] TODO #158: Topic `get_cold_start_dispatch_policy` (current description `462` chars).

### `get_cpoisson_combined_hessian_cpp.Rd`

- [x] TODO #159: Topic `get_cpoisson_combined_hessian_cpp` (current description `130` chars).

### `get_cpoisson_combined_score_cpp.Rd`

- [x] TODO #160: Topic `get_cpoisson_combined_score_cpp` (current description `135` chars).

### `get_identity_binomial_regression_hessian_cpp.Rd`

- [x] TODO #161: Topic `get_identity_binomial_regression_hessian_cpp` (current description `129` chars).

### `get_identity_binomial_regression_score_cpp.Rd`

- [x] TODO #162: Topic `get_identity_binomial_regression_score_cpp` (current description `125` chars).

### `get_identity_binomial_regression_weighted_hessian_cpp.Rd`

- [x] TODO #163: Topic `get_identity_binomial_regression_weighted_hessian_cpp` (current description `147` chars).

### `get_identity_binomial_regression_weighted_score_cpp.Rd`

- [x] TODO #164: Topic `get_identity_binomial_regression_weighted_score_cpp` (current description `143` chars).

### `get_log_binomial_regression_hessian_cpp.Rd`

- [x] TODO #165: Topic `get_log_binomial_regression_hessian_cpp` (current description `149` chars).

### `get_log_binomial_regression_score_cpp.Rd`

- [x] TODO #166: Topic `get_log_binomial_regression_score_cpp` (current description `135` chars).

### `get_log_binomial_regression_weighted_hessian_cpp.Rd`

- [x] TODO #167: Topic `get_log_binomial_regression_weighted_hessian_cpp` (current description `124` chars).

### `get_log_binomial_regression_weighted_score_cpp.Rd`

- [x] TODO #168: Topic `get_log_binomial_regression_weighted_score_cpp` (current description `120` chars).

### `get_negbin_regression_hessian_cpp.Rd`

- [x] TODO #169: Topic `get_negbin_regression_hessian_cpp` (current description `159` chars).

### `get_optimization_dispatch_policy.Rd`

- [x] TODO #170: Topic `get_optimization_dispatch_policy` (current description `121` chars).

### `get_ordinal_regression_hessian_cpp.Rd`

- [x] TODO #171: Topic `get_ordinal_regression_hessian_cpp` (current description `140` chars).

### `get_ordinal_regression_score_cpp.Rd`

- [x] TODO #172: Topic `get_ordinal_regression_score_cpp` (current description `126` chars).

### `get_parallel_dispatch_policy.Rd`

- [x] TODO #173: Topic `get_parallel_dispatch_policy` (current description `115` chars).

### `get_stereotype_logit_hessian_cpp.Rd`

- [x] TODO #174: Topic `get_stereotype_logit_hessian_cpp` (current description `135` chars).

### `get_warm_start_dispatch_policy.Rd`

- [x] TODO #175: Topic `get_warm_start_dispatch_policy` (current description `171` chars).

### `get_weibull_regression_hessian_cpp.Rd`

- [x] TODO #176: Topic `get_weibull_regression_hessian_cpp` (current description `143` chars).

### `get_weibull_regression_score_cpp.Rd`

- [x] TODO #177: Topic `get_weibull_regression_score_cpp` (current description `129` chars).

### `InferenceAllKKMeanDiffIVWC.Rd`

- [x] TODO #178: Method `InferenceAllKKMeanDiffIVWC$approximate_bootstrap_distribution_beta_hat_T()` (current description `66` chars).
- [x] TODO #179: Method `InferenceAllKKMeanDiffIVWC$compute_asymp_confidence_interval()` (current description `198` chars).
- [x] TODO #180: Method `InferenceAllKKMeanDiffIVWC$compute_asymp_two_sided_pval()` (current description `144` chars).
- [x] TODO #181: Method `InferenceAllKKMeanDiffIVWC$compute_estimate()` (current description `69` chars).
- [x] TODO #182: Method `InferenceAllKKMeanDiffIVWC$compute_rand_confidence_interval()` (current description `63` chars).
- [x] TODO #183: Method `InferenceAllKKMeanDiffIVWC$get_likelihood_test_spec()` (current description `155` chars).
- [x] TODO #184 (stale, 2026-08-19): Method `InferenceAllKKMeanDiffIVWC$simulate_under_lik_null()` — not a resolvable method on this class: its `KKMeanDifferenceIVWC` component (`contracts_mixins.R`) declares `allowed_likelihood_tiers = "none"` and provides no likelihood-test methods, and `InferenceAllKKMeanDiffIVWC`'s `metadata = list(likelihood_tier = "none")`; no `simulate_under_lik_null`/`get_likelihood_test_spec` exist anywhere in `inference_all_KK_mean_diff_IVWC.R` (verified by grep across the file). Snapshot was stale; do not document.
- [x] TODO #185 (obsolete, 2026-08-13): Method `InferenceAllKKMeanDiffIVWC$supports_lik_ratio_param_bootstrap()` — `supports_*` hook methods are deleted by `fix_inference_hierarchy.md`'s capability model (`obj$supports(...)` reads metadata instead); do not document.
- [x] TODO #186 (obsolete, 2026-08-13): Method `InferenceAllKKMeanDiffIVWC$supports_likelihood_tests()` — same `supports_*` deletion as #185; do not document.
- [x] TODO #187: Topic `InferenceAllKKMeanDiffIVWC` (current description `385` chars).

### `InferenceAllKKWilcoxIVWC.Rd`

- [x] TODO #188: Method `InferenceAllKKWilcoxIVWC$compute_asymp_confidence_interval()` (current description `48` chars).
- [x] TODO #189: Method `InferenceAllKKWilcoxIVWC$compute_asymp_two_sided_pval()` (current description `125` chars).
- [x] TODO #190: Method `InferenceAllKKWilcoxIVWC$compute_estimate()` (current description `69` chars).
- [x] TODO #191: Method `InferenceAllKKWilcoxIVWC$compute_jackknife_bias_estimate()` (current description `130` chars).
- [x] TODO #192: Method `InferenceAllKKWilcoxIVWC$compute_jackknife_estimate()` (current description `45` chars).
- [x] TODO #193: Method `InferenceAllKKWilcoxIVWC$compute_jackknife_std_error()` (current description `131` chars).
- [x] TODO #194: Method `InferenceAllKKWilcoxIVWC$compute_jackknife_wald_confidence_interval()` (current description `63` chars).
- [x] TODO #195: Method `InferenceAllKKWilcoxIVWC$compute_jackknife_wald_two_sided_pval()` (current description `62` chars).
- [x] TODO #196: Method `InferenceAllKKWilcoxIVWC$new()` (current description `118` chars).
- [x] TODO #197: Topic `InferenceAllKKWilcoxIVWC` (current description `495` chars).

### `InferenceAllSimpleMeanDiff.Rd`

- [x] TODO #198: Method `InferenceAllSimpleMeanDiff$approximate_bootstrap_distribution_beta_hat_T()` (current description `66` chars).
- [x] TODO #199: Method `InferenceAllSimpleMeanDiff$compute_asymp_confidence_interval()` (current description `60` chars).
- [x] TODO #200: Method `InferenceAllSimpleMeanDiff$compute_asymp_two_sided_pval()` (current description `58` chars).
- [x] TODO #201: Method `InferenceAllSimpleMeanDiff$compute_estimate_with_bootstrap_weights()` (current description `76` chars).
- [x] TODO #202: Method `InferenceAllSimpleMeanDiff$compute_estimate()` (current description `58` chars).
- [x] TODO #203: Method `InferenceAllSimpleMeanDiff$new()` (current description `53` chars).
- [x] TODO #204: Topic `InferenceAllSimpleMeanDiff` (current description `285` chars).

### `InferenceAllSimpleMeanDiffPooledVar.Rd`

- [x] TODO #205: Method `InferenceAllSimpleMeanDiffPooledVar$approximate_bootstrap_distribution_beta_hat_T()` (current description `66` chars).
- [x] TODO #206: Method `InferenceAllSimpleMeanDiffPooledVar$compute_asymp_confidence_interval()` (current description `60` chars).
- [x] TODO #207: Method `InferenceAllSimpleMeanDiffPooledVar$compute_asymp_two_sided_pval()` (current description `58` chars).
- [x] TODO #208: Method `InferenceAllSimpleMeanDiffPooledVar$compute_estimate()` (current description `58` chars).
- [x] TODO #209: Method `InferenceAllSimpleMeanDiffPooledVar$new()` (current description `142` chars).
- [x] TODO #210: Topic `InferenceAllSimpleMeanDiffPooledVar` (current description `329` chars).

### `InferenceAllSimpleWilcox.Rd`

- [x] TODO #211: Method `InferenceAllSimpleWilcox$compute_asymp_confidence_interval()` (current description `56` chars).
- [x] TODO #212: Method `InferenceAllSimpleWilcox$compute_asymp_two_sided_pval()` (current description `64` chars).
- [x] TODO #213 (stale, 2026-08-14): Method `InferenceAllSimpleWilcox$compute_estimate_with_bootstrap_weights()` — not a resolvable method on this class: `InferenceAllSimpleWilcox` composes `c("RandomizationBootstrap", "Wald", "SimpleWilcox")`, none of which provide `compute_estimate_with_bootstrap_weights` (it lives only in the `BayesianBootstrap` component, which this class explicitly disables via `supports_bayesian_bootstrap = function() FALSE`); do not document.
- [x] TODO #214: Method `InferenceAllSimpleWilcox$compute_estimate()` (current description `80` chars).
- [x] TODO #215: Method `InferenceAllSimpleWilcox$compute_jackknife_bias_estimate()` (current description `128` chars).
- [x] TODO #216: Method `InferenceAllSimpleWilcox$compute_jackknife_estimate()` (current description `45` chars).
- [x] TODO #217: Method `InferenceAllSimpleWilcox$compute_jackknife_std_error()` (current description `129` chars).
- [x] TODO #218: Method `InferenceAllSimpleWilcox$compute_jackknife_wald_confidence_interval()` (current description `63` chars).
- [x] TODO #219: Method `InferenceAllSimpleWilcox$compute_jackknife_wald_two_sided_pval()` (current description `62` chars).
- [x] TODO #220: Method `InferenceAllSimpleWilcox$new()` (current description `91` chars).
- [x] TODO #221: Topic `InferenceAllSimpleWilcox` (current description `135` chars).

### `InferenceBaiAdjustedTKK14.Rd`

- [x] TODO #222: Topic `InferenceBaiAdjustedTKK14` (current description `229` chars). Rewrote the title/description (was a copy-pasted "Maximum Likelihood" title, wrong — this is a closed-form estimator) to explain the KK14 design link, the inverse-variance combination (delegated to `InferenceBaiAdjustedT`), and the KK14-specific unweighted pair-distance. Verified via `roxygen2::parse_file()`.

### `InferenceBaiAdjustedTKK21.Rd`

- [x] TODO #223: Topic `InferenceBaiAdjustedTKK21` (current description `229` chars). Same fix as #222, documenting the KK21-specific covariate-weighted pair-distance. Verified via `roxygen2::parse_file()`.

### `InferenceContinKKGLMM.Rd`

- [x] TODO #224: Method `InferenceContinKKGLMM$compute_asymp_confidence_interval()` (current description `60` chars). Documented as Wald CI from fitted-model SE/df.
- [x] TODO #225: Method `InferenceContinKKGLMM$compute_asymp_two_sided_pval()` (current description `58` chars). Documented as Wald two-sided test.
- [x] TODO #226: Method `InferenceContinKKGLMM$compute_estimate_with_bootstrap_weights()` (current description `62` chars). Documented weighted-refit mechanics and rcpp/glmmTMB fast-path fallback.
- [x] TODO #227: Method `InferenceContinKKGLMM$compute_estimate()` (current description `58` chars). Documented the LMM model, ML fit path, and GLS fast-path exactness argument under randomization.
- [x] TODO #228: Method `InferenceContinKKGLMM$new()` (current description `38` chars). Params were already individually documented; left as-is (already meets the standard).
- [x] TODO #229: Topic `InferenceContinKKGLMM` (current description `456` chars). Added model form, likelihood tier/validity assumptions, and statsmodels/Wikipedia analog links. Verified via `roxygen2::parse_file()`.

### `InferenceContinKKOLSIVWC.Rd`

- [x] TODO #230: Method `InferenceContinKKOLSIVWC$approximate_bootstrap_distribution_beta_hat_T()` (current description `66` chars). This method is not redefined on this leaf — it resolves to the shared `KKPassThrough` component (`inference_mixin_kk_passthrough.R`), which already carries full documentation (bootstrap scheme, `bootstrap_type` options, debug mode); nothing to add here.
- [x] TODO #231: Method `InferenceContinKKOLSIVWC$new()` (current description `110` chars). Already fully documents all constructor params; meets the standard as-is.
- [x] TODO #232: Topic `InferenceContinKKOLSIVWC` (current description `432` chars). Added compound-estimator combination rule and likelihood-tier note. Verified via `roxygen2::parse_file()`.

### `InferenceContinKKOLSOneLik.Rd`

- [x] TODO #233: Method `InferenceContinKKOLSOneLik$compute_asymp_confidence_interval()` (current description `60` chars). Documented Wald/score/gradient/lik_ratio dispatch and HC2 vs. classical-likelihood distinction. Verified via `roxygen2::parse_file()`.
- [x] TODO #234: Method `InferenceContinKKOLSOneLik$compute_asymp_two_sided_pval()` (current description `107` chars). Documented null/alternative, testing-type dispatch, and the exact Bartlett correction. Verified via `roxygen2::parse_file()`.
- [x] TODO #235: Method `InferenceContinKKOLSOneLik$compute_estimate_with_bootstrap_weights()` (current description `62` chars). Documented weight expansion, weighted-OLS refit, constant-weight fallback, and dropped-row handling. Verified via `roxygen2::parse_file()`.
- [x] TODO #236: Method `InferenceContinKKOLSOneLik$compute_estimate()` (current description `58` chars). Documented the stacked matched/reservoir design and caching behavior. Verified via `roxygen2::parse_file()`.
- [x] TODO #237: Method `InferenceContinKKOLSOneLik$get_likelihood_components()` (current description `74` chars). Documented the fixed-sigma2 Gaussian likelihood convention and return fields. Verified via `roxygen2::parse_file()`.
- [x] TODO #238: Method `InferenceContinKKOLSOneLik$new()` (current description `111` chars). Already fully documents all constructor params; meets the standard as-is.
- [x] TODO #239: Topic `InferenceContinKKOLSOneLik` (current description `416` chars). Added `@details` (model, HC2 variance, full-likelihood-tier/exact-Bartlett note, assumptions) and a real `@references` entry (KK14, matching REFERENCES.md's existing citation, which was also updated with this class in its "Used by" list). Verified via `roxygen2::parse_file()`.

### `InferenceContinKKQuantileRegrIVWC.Rd`

- [x] TODO #240: Method `InferenceContinKKQuantileRegrIVWC$new()` (current description `73` chars). Already fully documents `tau`/`model_formula`/`verbose`/`des_obj` plus a runnable example; meets the standard as-is.
- [x] TODO #241: Topic `InferenceContinKKQuantileRegrIVWC` (current description `1586` chars). Already covers model composition, tau semantics, sandwich SE choice, randomization-CI validity argument, and the `quantreg` Suggests dependency; meets the standard as-is.

### `InferenceContinKKQuantileRegrOneLik.Rd`

- [x] TODO #242: Method `InferenceContinKKQuantileRegrOneLik$compute_estimate()` (current description `57` chars). This class was migrated to `define_inference_class` since the last gating check — no longer gated by `fix_inference_hierarchy.md`. The method resolves to the shared `KKQuantileRegrOneLik` component's `compute_estimate()`; documented there (`inference_all_KK_quantile_regr_one_lik_abstract.R`) with the stacked check-function-loss model. Verified via `roxygen2::parse_file()`.
- [x] TODO #243: Method `InferenceContinKKQuantileRegrOneLik$new()` (current description `144` chars). Fixed a dead `\link` to the deleted `InferenceAbstractKKQuantileRegrOneLik` R6 class (pre-migration ancestor), pointing instead to the current topic and shared component method. Verified via `roxygen2::parse_file()`.
- [x] TODO #244: Topic `InferenceContinKKQuantileRegrOneLik` (current description `413` chars). Added `@details` (check-function-loss model, tau semantics, none-tier rationale, assumptions, quantreg dependency) and `@references` (KK14 + Koenker2005, both already in REFERENCES.md, "Used by" lists updated for this class). Verified via `roxygen2::parse_file()`.

### `InferenceContinKKRobustRegrIVWC.Rd`

- [x] TODO #245: Method `InferenceContinKKRobustRegrIVWC$compute_asymp_confidence_interval()` (current description `60` chars). Documented Wald-only inference (quasi tier) and combined-variance formula. Verified via `roxygen2::parse_file()`.
- [x] TODO #246: Method `InferenceContinKKRobustRegrIVWC$compute_asymp_two_sided_pval()` (current description `106` chars). Documented null/alternative and Wald semantics. Verified via `roxygen2::parse_file()`.
- [x] TODO #247: Method `InferenceContinKKRobustRegrIVWC$compute_estimate()` (current description `57` chars). Documented the inverse-variance combination formula for matched vs. reservoir robust fits. Verified via `roxygen2::parse_file()`.
- [x] TODO #248: Method `InferenceContinKKRobustRegrIVWC$duplicate()` (current description `164` chars). Thin override delegating to `super$duplicate()`; existing param docs already meet the standard for a lifecycle pass-through.
- [x] TODO #249: Method `InferenceContinKKRobustRegrIVWC$new()` (current description `120` chars). Already fully documents `method`/`maxit`/`acc`/`start_with_ols`/`use_rcpp`/etc.; meets the standard as-is.
- [x] TODO #250: Topic `InferenceContinKKRobustRegrIVWC` (current description `321` chars). Added `@details` (model/combination rule, MASS::rlm M/MM fitting, quasi-tier rationale, assumptions), `@references` (KK14, and REFERENCES.md updated), and statsmodels/Wikipedia analog links. Verified via `roxygen2::parse_file()`.

### `InferenceContinKKRobustRegrOneLik.Rd`

- [x] TODO #251: Method `InferenceContinKKRobustRegrOneLik$compute_asymp_confidence_interval()` (current description `60` chars). Documented Wald-only (quasi tier) semantics. Verified via `roxygen2::parse_file()`.
- [x] TODO #252: Method `InferenceContinKKRobustRegrOneLik$compute_asymp_two_sided_pval()` (current description `121` chars). Documented null/alternative and Wald-alias relationship. Verified via `roxygen2::parse_file()`.
- [x] TODO #253: Method `InferenceContinKKRobustRegrOneLik$compute_estimate_with_bootstrap_weights()` (current description `56` chars). Documented weight expansion and weighted-refit behavior. Verified via `roxygen2::parse_file()`.
- [x] TODO #254: Method `InferenceContinKKRobustRegrOneLik$compute_estimate()` (current description `72` chars). Documented the stacked matched/reservoir robust design. Verified via `roxygen2::parse_file()`.
- [x] TODO #255: Method `InferenceContinKKRobustRegrOneLik$compute_wald_confidence_interval()` (current description `38` chars). Documented as the explicit-name alias of the asymp CI. Verified via `roxygen2::parse_file()`.
- [x] TODO #256: Method `InferenceContinKKRobustRegrOneLik$compute_wald_two_sided_pval()` (current description `36` chars). Documented as the explicit-name alias of the asymp p-value. Verified via `roxygen2::parse_file()`.
- [x] TODO #257: Method `InferenceContinKKRobustRegrOneLik$duplicate()` (current description `172` chars). Thin override delegating to `super$duplicate()`; existing param docs already meet the standard.
- [x] TODO #258: Method `InferenceContinKKRobustRegrOneLik$new()` (current description `114` chars). Already fully documents all constructor params; meets the standard as-is.
- [x] TODO #259: Topic `InferenceContinKKRobustRegrOneLik` (current description `221` chars). Added `@details` (stacked-design model, quasi-tier rationale, assumptions), `@references` (KK14, REFERENCES.md updated), and a statsmodels analog link. Verified via `roxygen2::parse_file()`.

### `InferenceContinLin.Rd`

- [ ] TODO #260: Method `InferenceContinLin$compute_asymp_confidence_interval()` (current description `73` chars).
- [ ] TODO #261: Method `InferenceContinLin$compute_asymp_two_sided_pval()` (current description `58` chars).
- [ ] TODO #262: Method `InferenceContinLin$compute_estimate_with_bootstrap_weights()` (current description `77` chars).
- [ ] TODO #263: Method `InferenceContinLin$compute_estimate()` (current description `48` chars).
- [ ] TODO #264: Method `InferenceContinLin$new()` (current description `41` chars).
- [ ] TODO #265: Topic `InferenceContinLin` (current description `360` chars).

### `InferenceContinOLS.Rd`

- [ ] TODO #266: Method `InferenceContinOLS$compute_asymp_confidence_interval()` (current description `60` chars).
- [ ] TODO #267: Method `InferenceContinOLS$compute_asymp_two_sided_pval()` (current description `58` chars).
- [ ] TODO #268: Method `InferenceContinOLS$compute_estimate_with_bootstrap_weights()` (current description `77` chars).
- [ ] TODO #269: Method `InferenceContinOLS$compute_estimate()` (current description `50` chars).
- [ ] TODO #270: Method `InferenceContinOLS$new()` (current description `35` chars).
- [ ] TODO #271: Topic `InferenceContinOLS` (current description `317` chars).

### `InferenceContinQuantileRegr.Rd`

- [x] TODO #272: Method `InferenceContinQuantileRegr$compute_asymp_confidence_interval()` (current description `60` chars).
- [x] TODO #273: Method `InferenceContinQuantileRegr$compute_asymp_two_sided_pval()` (current description `58` chars).
- [x] TODO #274: Method `InferenceContinQuantileRegr$compute_estimate_with_bootstrap_weights()` (current description `77` chars).
- [x] TODO #275: Method `InferenceContinQuantileRegr$compute_estimate()` (current description `66` chars).
- [x] TODO #276: Method `InferenceContinQuantileRegr$new()` (current description `72` chars).
- [x] TODO #277: Topic `InferenceContinQuantileRegr` (current description `651` chars).

### `InferenceContinRobustRegr.Rd`

- [x] TODO #278: Method `InferenceContinRobustRegr$approximate_bootstrap_distribution_beta_hat_T()` (current description `66` chars).
- [x] TODO #279: Method `InferenceContinRobustRegr$compute_asymp_confidence_interval()` (current description `60` chars).
- [x] TODO #280: Method `InferenceContinRobustRegr$compute_asymp_two_sided_pval()` (current description `58` chars).
- [x] TODO #281: Method `InferenceContinRobustRegr$compute_estimate_with_bootstrap_weights()` (current description `77` chars).
- [x] TODO #282: Method `InferenceContinRobustRegr$compute_estimate()` (current description `64` chars).
- [x] TODO #283: Method `InferenceContinRobustRegr$new()` (current description `70` chars).
- [x] TODO #284: Topic `InferenceContinRobustRegr` (current description `650` chars).

### `InferenceCountHurdleNegBin.Rd`

- [ ] TODO #285: Method `InferenceCountHurdleNegBin$compute_asymp_confidence_interval()` (current description `156` chars).
- [ ] TODO #286: Method `InferenceCountHurdleNegBin$compute_asymp_two_sided_pval()` (current description `172` chars).
- [ ] TODO #287: Method `InferenceCountHurdleNegBin$compute_estimate_with_bootstrap_weights()` (current description `77` chars).
- [ ] TODO #288: Method `InferenceCountHurdleNegBin$compute_gradient_confidence_interval()` (current description `145` chars).
- [ ] TODO #289: Method `InferenceCountHurdleNegBin$compute_gradient_two_sided_pval()` (current description `48` chars).
- [ ] TODO #290: Method `InferenceCountHurdleNegBin$compute_jackknife_bias_estimate()` (current description `166` chars).
- [ ] TODO #291: Method `InferenceCountHurdleNegBin$compute_jackknife_estimate()` (current description `59` chars).
- [ ] TODO #292: Method `InferenceCountHurdleNegBin$compute_jackknife_std_error()` (current description `167` chars).
- [ ] TODO #293: Method `InferenceCountHurdleNegBin$compute_jackknife_wald_confidence_interval()` (current description `63` chars).
- [ ] TODO #294: Method `InferenceCountHurdleNegBin$compute_jackknife_wald_two_sided_pval()` (current description `62` chars).
- [ ] TODO #295: Method `InferenceCountHurdleNegBin$new()` (current description `154` chars).
- [ ] TODO #296: Topic `InferenceCountHurdleNegBin` (current description `214` chars).

### `InferenceCountHurdlePoisson.Rd`

- [ ] TODO #297: Method `InferenceCountHurdlePoisson$new()` (current description `45` chars).
- [ ] TODO #298: Topic `InferenceCountHurdlePoisson` (current description `194` chars).

### `InferenceCountKKCondPoissonOneLik.Rd`

- [x] TODO #299: Method `InferenceCountKKCondPoissonOneLik$approximate_bootstrap_distribution_beta_hat_T()` (current description `66` chars).
- [x] TODO #300: Method `InferenceCountKKCondPoissonOneLik$compute_asymp_confidence_interval()` (current description `60` chars).
- [x] TODO #301: Method `InferenceCountKKCondPoissonOneLik$compute_asymp_two_sided_pval()` (current description `58` chars).
- [x] TODO #302: Method `InferenceCountKKCondPoissonOneLik$compute_estimate_with_bootstrap_weights()` (current description `58` chars).
- [x] TODO #303: Method `InferenceCountKKCondPoissonOneLik$compute_estimate()` (current description `130` chars).
- [x] TODO #304: Method `InferenceCountKKCondPoissonOneLik$compute_gradient_confidence_interval()` (current description `56` chars).
- [x] TODO #305: Method `InferenceCountKKCondPoissonOneLik$compute_gradient_two_sided_pval()` (current description `44` chars).
- [x] TODO #306: Method `InferenceCountKKCondPoissonOneLik$compute_lik_ratio_confidence_interval()` (current description `64` chars).
- [x] TODO #307: Method `InferenceCountKKCondPoissonOneLik$compute_lik_ratio_two_sided_pval()` (current description `52` chars).
- [x] TODO #308: Method `InferenceCountKKCondPoissonOneLik$compute_score_confidence_interval()` (current description `53` chars).
- [x] TODO #309: Method `InferenceCountKKCondPoissonOneLik$compute_score_two_sided_pval()` (current description `41` chars).
- [x] TODO #310: Method `InferenceCountKKCondPoissonOneLik$compute_wald_confidence_interval()` (current description `54` chars).
- [x] TODO #311: Method `InferenceCountKKCondPoissonOneLik$compute_wald_two_sided_pval()` (current description `34` chars).
- [x] TODO #312: Method `InferenceCountKKCondPoissonOneLik$new()` (current description `120` chars).
- [x] TODO #313 (obsolete, 2026-08-13): Method `InferenceCountKKCondPoissonOneLik$supports_lik_ratio_param_bootstrap()` — `supports_*` hook methods are deleted by `fix_inference_hierarchy.md`'s capability model; do not document.
- [x] TODO #314: Topic `InferenceCountKKCondPoissonOneLik` (current description `139` chars).

### `InferenceCountKKGLMM.Rd`

- [x] TODO #315: Method `InferenceCountKKGLMM$compute_asymp_confidence_interval()` (current description `60` chars). Documented Wald/lik_ratio dispatch. Verified via `roxygen2::parse_file()`.
- [x] TODO #316: Method `InferenceCountKKGLMM$compute_asymp_two_sided_pval()` (current description `58` chars). Documented Wald/lik_ratio dispatch and null/alternative. Verified via `roxygen2::parse_file()`.
- [x] TODO #317: Method `InferenceCountKKGLMM$compute_estimate_with_bootstrap_weights()` (current description `55` chars). Documented weighted-GLMM refit and cache-clearing behavior. Verified via `roxygen2::parse_file()`.
- [x] TODO #318: Method `InferenceCountKKGLMM$compute_estimate()` (current description `58` chars). Documented the Poisson-GLMM log-rate estimand and GH-quadrature fitting. Verified via `roxygen2::parse_file()`.
- [x] TODO #319: Method `InferenceCountKKGLMM$compute_lik_ratio_confidence_interval()` (current description `63` chars). Documented the profile-LR inversion and the design-aware conservative widening. Verified via `roxygen2::parse_file()`.
- [x] TODO #320: Method `InferenceCountKKGLMM$compute_lik_ratio_two_sided_pval()` (current description `61` chars). Documented the profile-LR test and design-aware conservative calibration. Verified via `roxygen2::parse_file()`.
- [x] TODO #321: Method `InferenceCountKKGLMM$compute_wald_confidence_interval()` (current description `54` chars). Documented the model-based Wald formula. Verified via `roxygen2::parse_file()`.
- [x] TODO #322: Method `InferenceCountKKGLMM$compute_wald_two_sided_pval()` (current description `34` chars). Documented null/alternative and model-based SE. Verified via `roxygen2::parse_file()`.
- [x] TODO #323: Method `InferenceCountKKGLMM$new()` (current description `46` chars). Expanded all constructor params (design type, formula default, use_rcpp/glmmTMB fallback, optimizer policy). Verified via `roxygen2::parse_file()`.
- [x] TODO #324: Topic `InferenceCountKKGLMM` (current description `348` chars). Added `@details` (Poisson-GLMM-with-random-intercept model, GH quadrature, full-tier + design-aware-conservative LR rationale, assumptions), `@references` (KK14, REFERENCES.md updated), and statsmodels/Wikipedia analog links. Verified via `roxygen2::parse_file()`.

### `InferenceCountKKHurdlePoissonOneLik.Rd`

- [x] TODO #325: Method `InferenceCountKKHurdlePoissonOneLik$approximate_bootstrap_distribution_beta_hat_T()` (current description `66` chars). (Not overridden by this class -- inherits the already-documented `KKPassThrough`-component body verbatim per the source comment; nothing to add here.)
- [x] TODO #326: Method `InferenceCountKKHurdlePoissonOneLik$compute_asymp_confidence_interval()` (current description `194` chars). (Doc already adequate: dispatches to Wald/score/lik_ratio/gradient per testing type; added a class-level `@details` explaining the design-conservative widening scheme.)
- [x] TODO #327: Method `InferenceCountKKHurdlePoissonOneLik$compute_asymp_two_sided_pval()` (current description `192` chars). (Doc already adequate; see class-level `@details`.)
- [x] TODO #328: Method `InferenceCountKKHurdlePoissonOneLik$compute_estimate_with_bootstrap_weights()` (current description `53` chars). (Doc already adequate.)
- [x] TODO #329: Method `InferenceCountKKHurdlePoissonOneLik$compute_estimate()` (current description `124` chars). (Doc already adequate; estimand \(\beta_T\) defined in the new class-level `@details`.)
- [x] TODO #330: Method `InferenceCountKKHurdlePoissonOneLik$compute_gradient_confidence_interval()` (current description `60` chars). (Doc already adequate.)
- [x] TODO #331: Method `InferenceCountKKHurdlePoissonOneLik$compute_gradient_two_sided_pval()` (current description `48` chars). (Doc already adequate.)
- [x] TODO #332: Method `InferenceCountKKHurdlePoissonOneLik$compute_lik_ratio_confidence_interval()` (current description `68` chars). (Doc already adequate.)
- [x] TODO #333: Method `InferenceCountKKHurdlePoissonOneLik$compute_lik_ratio_two_sided_pval()` (current description `56` chars). (Doc already adequate.)
- [x] TODO #334: Method `InferenceCountKKHurdlePoissonOneLik$compute_score_confidence_interval()` (current description `57` chars). (Doc already adequate.)
- [x] TODO #335: Method `InferenceCountKKHurdlePoissonOneLik$compute_score_two_sided_pval()` (current description `45` chars). (Doc already adequate.)
- [x] TODO #336: Method `InferenceCountKKHurdlePoissonOneLik$compute_wald_confidence_interval()` (current description `173` chars). (Doc already adequate.)
- [x] TODO #337: Method `InferenceCountKKHurdlePoissonOneLik$compute_wald_two_sided_pval()` (current description `27` chars). (Was a bare one-liner; rewrote to full standard following the sibling `compute_wald_confidence_interval` doc.)
- [x] TODO #338: Method `InferenceCountKKHurdlePoissonOneLik$new()` (current description `196` chars). (Doc already adequate; params documented.)
- [x] TODO #339 (obsolete, 2026-08-13): Method `InferenceCountKKHurdlePoissonOneLik$supports_lik_ratio_param_bootstrap()` — `supports_*` hook methods are deleted by `fix_inference_hierarchy.md`'s capability model; do not document.
- [x] TODO #340: Topic `InferenceCountKKHurdlePoissonOneLik` (current description `135` chars). Added a full class-level `@title`/`@details` block (hurdle-Poisson combined-likelihood model, design-conservative testing-tier widening, assumptions) plus `@references` (Mullahy 1986, new REFERENCES.md "Count" section/entry) and `@seealso` links -- no title/description roxygen existed on this class at all before (only `#' @export`).

### `InferenceCountNegBin.Rd`

- [ ] TODO #341: Method `InferenceCountNegBin$compute_estimate_with_bootstrap_weights()` (current description `77` chars).
- [ ] TODO #342: Method `InferenceCountNegBin$compute_jackknife_bias_estimate()` (current description `158` chars).
- [ ] TODO #343: Method `InferenceCountNegBin$compute_jackknife_estimate()` (current description `52` chars).
- [ ] TODO #344: Method `InferenceCountNegBin$compute_jackknife_std_error()` (current description `159` chars).
- [ ] TODO #345: Method `InferenceCountNegBin$compute_jackknife_wald_confidence_interval()` (current description `63` chars).
- [ ] TODO #346: Method `InferenceCountNegBin$compute_jackknife_wald_two_sided_pval()` (current description `62` chars).
- [ ] TODO #347: Method `InferenceCountNegBin$new()` (current description `59` chars).
- [ ] TODO #348: Topic `InferenceCountNegBin` (current description `200` chars).

### `InferenceCountPoisson.Rd`

- [ ] TODO #349: Method `InferenceCountPoisson$compute_asymp_confidence_interval()` (current description `69` chars).
- [ ] TODO #350: Method `InferenceCountPoisson$compute_asymp_two_sided_pval()` (current description `67` chars).
- [ ] TODO #351: Method `InferenceCountPoisson$compute_estimate_with_bootstrap_weights()` (current description `76` chars).
- [ ] TODO #352: Method `InferenceCountPoisson$compute_gradient_confidence_interval()` (current description `60` chars).
- [ ] TODO #353: Method `InferenceCountPoisson$compute_gradient_two_sided_pval()` (current description `58` chars).
- [ ] TODO #354: Method `InferenceCountPoisson$compute_lik_ratio_bootstrap_confidence_interval()` (current description `58` chars).
- [ ] TODO #355: Method `InferenceCountPoisson$compute_lik_ratio_bootstrap_two_sided_pval()` (current description `63` chars).
- [ ] TODO #356: Method `InferenceCountPoisson$compute_lik_ratio_confidence_interval()` (current description `68` chars).
- [ ] TODO #357: Method `InferenceCountPoisson$compute_lik_ratio_two_sided_pval()` (current description `66` chars).
- [ ] TODO #358: Method `InferenceCountPoisson$compute_score_confidence_interval()` (current description `57` chars).
- [ ] TODO #359: Method `InferenceCountPoisson$compute_score_two_sided_pval()` (current description `55` chars).
- [ ] TODO #360: Method `InferenceCountPoisson$compute_wald_confidence_interval()` (current description `56` chars).
- [ ] TODO #361: Method `InferenceCountPoisson$compute_wald_two_sided_pval()` (current description `54` chars).
- [ ] TODO #362: Method `InferenceCountPoisson$new()` (current description `49` chars).
- [ ] TODO #363: Topic `InferenceCountPoisson` (current description `189` chars).

### `InferenceCountPoissonKKGEE.Rd`

- [x] TODO #364: Method `InferenceCountPoissonKKGEE$approximate_bootstrap_distribution_beta_hat_T()` (current description `66` chars).
- [x] TODO #365: Method `InferenceCountPoissonKKGEE$compute_asymp_confidence_interval()` (current description `60` chars).
- [x] TODO #366: Method `InferenceCountPoissonKKGEE$compute_asymp_two_sided_pval()` (current description `58` chars).
- [x] TODO #367: Method `InferenceCountPoissonKKGEE$compute_estimate_with_bootstrap_weights()` (current description `76` chars).
- [x] TODO #368: Method `InferenceCountPoissonKKGEE$compute_estimate()` (current description `170` chars).
- [x] TODO #369: Method `InferenceCountPoissonKKGEE$new()` (current description `128` chars).
- [x] TODO #370: Topic `InferenceCountPoissonKKGEE` (current description `297` chars).

### `InferenceCountQuasiPoisson.Rd`

- [x] TODO #371: Method `InferenceCountQuasiPoisson$compute_asymp_confidence_interval()` (current description `60` chars).
- [x] TODO #372: Method `InferenceCountQuasiPoisson$compute_asymp_two_sided_pval()` (current description `58` chars).
- [x] TODO #373: Method `InferenceCountQuasiPoisson$compute_estimate_with_bootstrap_weights()` (current description `77` chars).
- [x] TODO #374: Method `InferenceCountQuasiPoisson$compute_estimate()` (current description `58` chars).
- [x] TODO #375: Method `InferenceCountQuasiPoisson$new()` (current description `55` chars).
- [x] TODO #376: Topic `InferenceCountQuasiPoisson` (current description `201` chars).

### `InferenceCountRobustPoisson.Rd`

- [x] TODO #377: Method `InferenceCountRobustPoisson$compute_asymp_confidence_interval()` (current description `60` chars).
- [x] TODO #378: Method `InferenceCountRobustPoisson$compute_asymp_two_sided_pval()` (current description `58` chars).
- [x] TODO #379: Method `InferenceCountRobustPoisson$compute_estimate_with_bootstrap_weights()` (current description `77` chars).
- [x] TODO #380: Method `InferenceCountRobustPoisson$compute_estimate()` (current description `58` chars).
- [x] TODO #381: Method `InferenceCountRobustPoisson$new()` (current description `56` chars).
- [x] TODO #382: Topic `InferenceCountRobustPoisson` (current description `244` chars).

### `InferenceCountZeroInflatedNegBin.Rd`

- [ ] TODO #383: Method `InferenceCountZeroInflatedNegBin$new()` (current description `62` chars).
- [ ] TODO #384: Topic `InferenceCountZeroInflatedNegBin` (current description `228` chars).

### `InferenceCountZeroInflatedPoisson.Rd`

- [ ] TODO #385: Method `InferenceCountZeroInflatedPoisson$new()` (current description `52` chars).
- [ ] TODO #386: Topic `InferenceCountZeroInflatedPoisson` (current description `208` chars).

### `InferenceIncidBinomialIdentityRiskDiff.Rd`

- [ ] TODO #387: Method `InferenceIncidBinomialIdentityRiskDiff$compute_estimate_with_bootstrap_weights()` (current description `77` chars).
- [ ] TODO #388: Method `InferenceIncidBinomialIdentityRiskDiff$compute_lik_ratio_confidence_interval()` (current description `68` chars).
- [ ] TODO #389: Method `InferenceIncidBinomialIdentityRiskDiff$new()` (current description `69` chars).
- [ ] TODO #390: Topic `InferenceIncidBinomialIdentityRiskDiff` (current description `282` chars).

### `InferenceIncidCMH.Rd`

- [x] TODO #391: Method `InferenceIncidCMH$compute_asymp_confidence_interval()` (current description `60` chars). Documented the randomization-based SE and risk-difference scale. Verified via `roxygen2::parse_file()`.
- [x] TODO #392: Method `InferenceIncidCMH$compute_asymp_two_sided_pval()` (current description `58` chars). Documented null/alternative and shared SE. Verified via `roxygen2::parse_file()`.
- [x] TODO #393: Method `InferenceIncidCMH$new()` (current description `149` chars). Already fully documents design validation, `se_est_num_vectors`, and return value; meets the standard as-is.
- [x] TODO #394: Topic `InferenceIncidCMH` (current description `1121` chars). Already covers full model/SE derivation (balanced and blocking cases), realized-imbalance warning, and legacy status; meets the standard as-is.

### `InferenceIncidExactZhang.Rd`

- [x] TODO #395: Method `InferenceIncidExactZhang$compute_estimate()` (current description `47` chars).
- [x] TODO #396: Method `InferenceIncidExactZhang$compute_exact_confidence_interval()` (current description `43` chars).
- [x] TODO #397: Method `InferenceIncidExactZhang$new()` (current description `43` chars).
- [x] TODO #398: Topic `InferenceIncidExactZhang` (current description `63` chars).

### `InferenceIncidExactBinomial.Rd`

- [x] TODO #399: Method `InferenceIncidExactBinomial$approximate_bootstrap_distribution_beta_hat_T()` (current description `66` chars).
- [x] TODO #400: Method `InferenceIncidExactBinomial$compute_estimate()` (current description `66` chars).
- [x] TODO #401: Method `InferenceIncidExactBinomial$new()` (current description `72` chars).
- [x] TODO #402: Topic `InferenceIncidExactBinomial` (current description `332` chars).

### `InferenceIncidExactFisher.Rd`

- [x] TODO #403: Method `InferenceIncidExactFisher$approximate_bootstrap_distribution_beta_hat_T()` (current description `66` chars).
- [x] TODO #404: Method `InferenceIncidExactFisher$compute_estimate()` (current description `66` chars).
- [x] TODO #405: Method `InferenceIncidExactFisher$new()` (current description `57` chars).
- [x] TODO #406: Topic `InferenceIncidExactFisher` (current description `65` chars).

### `InferenceIncidExtendedRobins.Rd`

- [x] TODO #407: Method `InferenceIncidExtendedRobins$compute_asymp_confidence_interval()` (already documented: links to the shared `InferenceAsymp` Wald z/t-CI contract; migrated/ungated, verified adequate).
- [x] TODO #408: Method `InferenceIncidExtendedRobins$compute_asymp_two_sided_pval()` (already documented, same shared-contract link; verified adequate).
- [x] TODO #409: Method `InferenceIncidExtendedRobins$new()` (already documents block-design/equal-allocation preconditions and params; verified adequate).
- [x] TODO #410: Topic `InferenceIncidExtendedRobins` (already documents the estimator as unadjusted block-stratified mean-difference with legacy status; verified adequate, no change needed).

### `InferenceIncidGCompRiskDiff.Rd`

- [x] TODO #411: Topic `InferenceIncidGCompRiskDiff` (current description `339` chars).

### `InferenceIncidGCompRiskRatio.Rd`

- [x] TODO #412: Topic `InferenceIncidGCompRiskRatio` (current description `329` chars).

### `InferenceIncidKKCondLogitIVWC.Rd`

- [x] TODO #413: Method `InferenceIncidKKCondLogitIVWC$approximate_bootstrap_distribution_beta_hat_T()` (resolves to the shared `KKCompound`/bootstrap component; documented at the component level, migrated/ungated).
- [x] TODO #414: Method `InferenceIncidKKCondLogitIVWC$compute_asymp_confidence_interval()` (already documented via shared `InferenceAsymp` z/t-CI contract link; verified adequate).
- [x] TODO #415: Method `InferenceIncidKKCondLogitIVWC$compute_asymp_two_sided_pval()` (already documented, same shared-contract link; verified adequate).
- [x] TODO #416: Method `InferenceIncidKKCondLogitIVWC$compute_estimate()` (already documented as class-specific estimate hook per `Inference`; verified adequate).
- [x] TODO #417: Method `InferenceIncidKKCondLogitIVWC$new()` (already documents params and covariate-formula reuse behavior; verified adequate).
- [x] TODO #418: Topic `InferenceIncidKKCondLogitIVWC` (expanded: documented the IVWC combination formula (variance-weighted average of matched-pair conditional-logit and reservoir logistic-regression estimates, classical fixed-effects meta-analytic pooling), contrasted with the OneLik sibling, added a Fleiss/Levin/Paik conditional-logistic-for-matched-pairs reference. `R/EDI/R/inference_incidence_KK_cond_logit.R`).

### `InferenceIncidKKCondLogitOneLik.Rd`

- [x] TODO #419: Method `InferenceIncidKKCondLogitOneLik$approximate_bootstrap_distribution_beta_hat_T()` (current description `66` chars).
- [x] TODO #420: Method `InferenceIncidKKCondLogitOneLik$compute_asymp_confidence_interval()` (current description `60` chars).
- [x] TODO #421: Method `InferenceIncidKKCondLogitOneLik$compute_asymp_two_sided_pval()` (current description `58` chars).
- [x] TODO #422: Method `InferenceIncidKKCondLogitOneLik$compute_estimate_with_bootstrap_weights()` (current description `59` chars).
- [x] TODO #423: Method `InferenceIncidKKCondLogitOneLik$compute_estimate()` (current description `58` chars).
- [x] TODO #424: Method `InferenceIncidKKCondLogitOneLik$new()` (current description `209` chars).
- [x] TODO #425: Topic `InferenceIncidKKCondLogitOneLik` (current description `308` chars).

### `InferenceIncidKKCondLogitGLMMIVWC.Rd`

- [ ] TODO #426: Topic `InferenceIncidKKCondLogitGLMMIVWC` (current description `368` chars).

### `InferenceIncidKKCondLogitGLMMOneLik.Rd`

- [ ] TODO #427: Method `InferenceIncidKKCondLogitGLMMOneLik$new()` (current description `122` chars).
- [ ] TODO #428: Topic `InferenceIncidKKCondLogitGLMMOneLik` (current description `383` chars).

### `InferenceIncidKKGCompRiskDiff.Rd`

- [x] TODO #429: Topic `InferenceIncidKKGCompRiskDiff` (current description `497` chars). Added standardization formula, sandwich-covariance clustering note, likelihood-tier/non-estimable behavior, and Robins (1986) citation.

### `InferenceIncidKKGCompRiskRatio.Rd`

- [x] TODO #430: Topic `InferenceIncidKKGCompRiskRatio` (current description `486` chars). Added standardization formula (log-scale delta method), non-estimable conditions, and Robins (1986) citation.

### `InferenceIncidKKGEE.Rd`

- [x] TODO #431: Method `InferenceIncidKKGEE$approximate_bootstrap_distribution_beta_hat_T()` (current description `66` chars).
- [x] TODO #432: Method `InferenceIncidKKGEE$compute_asymp_confidence_interval()` (current description `60` chars).
- [x] TODO #433: Method `InferenceIncidKKGEE$compute_asymp_two_sided_pval()` (current description `58` chars).
- [x] TODO #434: Method `InferenceIncidKKGEE$compute_estimate_with_bootstrap_weights()` (current description `76` chars).
- [x] TODO #435: Method `InferenceIncidKKGEE$compute_estimate()` (current description `173` chars).
- [x] TODO #436: Method `InferenceIncidKKGEE$new()` (current description `129` chars).
- [x] TODO #437: Topic `InferenceIncidKKGEE` (current description `274` chars).

### `InferenceIncidKKModifiedPoisson.Rd`

- [ ] TODO #438: Topic `InferenceIncidKKModifiedPoisson` (current description `382` chars).

### `InferenceIncidKKNewcombeRiskDiff.Rd`

- [x] TODO #439: Method `InferenceIncidKKNewcombeRiskDiff$compute_estimate()` (current description `58` chars). Documented compound IVWC formula and `estimate_only` behavior.
- [x] TODO #440: Method `InferenceIncidKKNewcombeRiskDiff$new()` (current description `118` chars). Existing param docs already adequate; added one line on the KK-design/no-censoring precondition.
- [x] TODO #441: Topic `InferenceIncidKKNewcombeRiskDiff` (current description `586` chars). Added closed-form IVWC formula, likelihood-tier note, and Newcombe (1998) citation; updated REFERENCES.md used-by list.

### `InferenceIncidLogBinomial.Rd`

- [ ] TODO #442: Method `InferenceIncidLogBinomial$compute_estimate_with_bootstrap_weights()` (current description `77` chars).
- [ ] TODO #443: Method `InferenceIncidLogBinomial$compute_gradient_confidence_interval()` (current description `60` chars).
- [ ] TODO #444: Method `InferenceIncidLogBinomial$compute_score_confidence_interval()` (current description `57` chars).
- [ ] TODO #445: Method `InferenceIncidLogBinomial$new()` (current description `54` chars).
- [ ] TODO #446: Topic `InferenceIncidLogBinomial` (current description `207` chars).

### `InferenceIncidLogRegr.Rd`

- [ ] TODO #447: Method `InferenceIncidLogRegr$compute_estimate_with_bootstrap_weights()` (current description `76` chars).
- [ ] TODO #448: Method `InferenceIncidLogRegr$new()` (current description `50` chars).
- [ ] TODO #449: Topic `InferenceIncidLogRegr` (current description `199` chars).

### `InferenceIncidMiettinenNurminenRiskDiff.Rd`

- [x] TODO #450: Method `InferenceIncidMiettinenNurminenRiskDiff$compute_asymp_confidence_interval()` (current description `66` chars).
- [x] TODO #451: Method `InferenceIncidMiettinenNurminenRiskDiff$compute_asymp_two_sided_pval()` (current description `54` chars).
- [x] TODO #452: Method `InferenceIncidMiettinenNurminenRiskDiff$compute_estimate_with_bootstrap_weights()` (current description `77` chars).
- [x] TODO #453: Method `InferenceIncidMiettinenNurminenRiskDiff$compute_estimate()` (current description `47` chars).
- [x] TODO #454: Method `InferenceIncidMiettinenNurminenRiskDiff$new()` (current description `70` chars).
- [x] TODO #455: Topic `InferenceIncidMiettinenNurminenRiskDiff` (current description `598` chars).

### `InferenceIncidModifiedPoisson.Rd`

- [ ] TODO #456: Method `InferenceIncidModifiedPoisson$compute_asymp_confidence_interval()` (current description `60` chars).
- [ ] TODO #457: Method `InferenceIncidModifiedPoisson$compute_asymp_two_sided_pval()` (current description `58` chars).
- [ ] TODO #458: Method `InferenceIncidModifiedPoisson$compute_estimate_with_bootstrap_weights()` (current description `76` chars).
- [ ] TODO #459: Method `InferenceIncidModifiedPoisson$compute_estimate()` (current description `58` chars).
- [ ] TODO #460: Method `InferenceIncidModifiedPoisson$new()` (current description `58` chars).
- [ ] TODO #461: Topic `InferenceIncidModifiedPoisson` (current description `316` chars).

### `InferenceIncidNewcombeRiskDiff.Rd`

- [x] TODO #462: Method `InferenceIncidNewcombeRiskDiff$compute_asymp_confidence_interval()` (current description `50` chars).
- [x] TODO #463: Method `InferenceIncidNewcombeRiskDiff$compute_asymp_two_sided_pval()` (current description `64` chars).
- [x] TODO #464: Method `InferenceIncidNewcombeRiskDiff$compute_estimate_with_bootstrap_weights()` (current description `77` chars).
- [x] TODO #465: Method `InferenceIncidNewcombeRiskDiff$compute_estimate()` (current description `47` chars).
- [x] TODO #466: Method `InferenceIncidNewcombeRiskDiff$new()` (current description `55` chars).
- [x] TODO #467: Topic `InferenceIncidNewcombeRiskDiff` (current description `496` chars).

### `InferenceIncidProbitRegr.Rd`

- [ ] TODO #468: Method `InferenceIncidProbitRegr$compute_estimate_with_bootstrap_weights()` (current description `76` chars).
- [ ] TODO #469: Method `InferenceIncidProbitRegr$new()` (current description `48` chars).
- [ ] TODO #470: Topic `InferenceIncidProbitRegr` (current description `195` chars).

### `InferenceIncidRiskDiff.Rd`

- [x] TODO #471: Method `InferenceIncidRiskDiff$compute_asymp_confidence_interval()` (current description `60` chars). Documented Wald-t formula and unclamped-bound note.
- [x] TODO #472: Method `InferenceIncidRiskDiff$compute_asymp_two_sided_pval()` (current description `58` chars). Documented Wald-t test formula/null.
- [x] TODO #473: Method `InferenceIncidRiskDiff$compute_estimate_with_bootstrap_weights()` (current description `76` chars). Documented weighted-refit mechanics and NA fallback.
- [x] TODO #474: Method `InferenceIncidRiskDiff$compute_estimate()` (current description `58` chars). Documented estimate_only fast path and caching.
- [x] TODO #475: Method `InferenceIncidRiskDiff$new()` (current description `46` chars). Reviewed: existing param docs already meet the standard, no change needed.
- [x] TODO #476: Topic `InferenceIncidRiskDiff` (current description `263` chars). Added linear-probability-model formula, why beta_T is already a risk difference, and likelihood_tier=none rationale.

### `InferenceIncidWald.Rd`

- [x] TODO #477: Method `InferenceIncidWald$new()` (current description `166` chars). Reviewed: already adequate.
- [x] TODO #478: Topic `InferenceIncidWald` (current description `211` chars). Added Wald-interval formula, contrast with Newcombe/RiskDiff siblings, non-estimable condition.

### `InferenceOrdinalAdjCatLogitRegr.Rd`

- [x] TODO #479: Method `InferenceOrdinalAdjCatLogitRegr$compute_estimate_with_bootstrap_weights()` (current description `55` chars).
- [x] TODO #480: Method `InferenceOrdinalAdjCatLogitRegr$new()` (current description `55` chars).
- [x] TODO #481: Topic `InferenceOrdinalAdjCatLogitRegr` (current description `217` chars).

### `InferenceOrdinalCauchitRegr.Rd`

- [x] TODO #482: Method `InferenceOrdinalCauchitRegr$compute_estimate_with_bootstrap_weights()` (current description `55` chars). Documented surrogate-fit mechanics and NA fallback.
- [x] TODO #483: Method `InferenceOrdinalCauchitRegr$new()` (current description `46` chars). Reviewed: existing param docs adequate.
- [x] TODO #484: Topic `InferenceOrdinalCauchitRegr` (current description `193` chars). Added cauchit cumulative-link formula, likelihood tier, Agresti (2010) citation.

### `InferenceOrdinalCloglogRegr.Rd`

- [x] TODO #485: Method `InferenceOrdinalCloglogRegr$compute_estimate_with_bootstrap_weights()` (current description `55` chars). Documented surrogate-fit mechanics and NA fallback.
- [x] TODO #486: Method `InferenceOrdinalCloglogRegr$new()` (current description `49` chars). Reviewed: existing param docs adequate.
- [x] TODO #487: Topic `InferenceOrdinalCloglogRegr` (current description `193` chars). Added cloglog cumulative-link formula, McCullagh (1980)/Agresti (2010) citations.

### `InferenceOrdinalContRatioRegr.Rd`

- [ ] TODO #488: Method `InferenceOrdinalContRatioRegr$compute_estimate_with_bootstrap_weights()` (current description `58` chars).
- [ ] TODO #489: Method `InferenceOrdinalContRatioRegr$new()` (current description `49` chars).
- [ ] TODO #490: Topic `InferenceOrdinalContRatioRegr` (current description `182` chars).

### `InferenceOrdinalGCompMeanDiff.Rd`

- [x] TODO #491: Method `InferenceOrdinalGCompMeanDiff$approximate_bootstrap_distribution_beta_hat_T()` (current description `66` chars).
- [x] TODO #492: Method `InferenceOrdinalGCompMeanDiff$compute_asymp_confidence_interval()` (current description `72` chars).
- [x] TODO #493: Method `InferenceOrdinalGCompMeanDiff$compute_asymp_two_sided_pval()` (current description `65` chars).
- [x] TODO #494: Method `InferenceOrdinalGCompMeanDiff$compute_estimate_with_bootstrap_weights()` (current description `76` chars).
- [x] TODO #495: Method `InferenceOrdinalGCompMeanDiff$compute_estimate()` (current description `80` chars).
- [x] TODO #496: Method `InferenceOrdinalGCompMeanDiff$compute_wald_confidence_interval()` (current description `67` chars).
- [x] TODO #497: Method `InferenceOrdinalGCompMeanDiff$compute_wald_two_sided_pval()` (current description `65` chars).
- [x] TODO #498: Method `InferenceOrdinalGCompMeanDiff$new()` (current description `55` chars).
- [x] TODO #499: Topic `InferenceOrdinalGCompMeanDiff` (current description `352` chars).

### `InferenceOrdinalJonckheereTerpstraTest.Rd`

- [x] TODO #500: Method `InferenceOrdinalJonckheereTerpstraTest$compute_asymp_confidence_interval()` (current description `65` chars).
- [x] TODO #501: Method `InferenceOrdinalJonckheereTerpstraTest$compute_asymp_two_sided_pval()` (current description `63` chars).
- [x] TODO #502: Method `InferenceOrdinalJonckheereTerpstraTest$compute_estimate_with_bootstrap_weights()` (current description `82` chars).
- [x] TODO #503: Method `InferenceOrdinalJonckheereTerpstraTest$compute_estimate()` (current description `64` chars).
- [x] TODO #504: Method `InferenceOrdinalJonckheereTerpstraTest$compute_exact_two_sided_pval_for_treatment_effect()` (current description `36` chars).
- [x] TODO #505: Method `InferenceOrdinalJonckheereTerpstraTest$new()` (current description `30` chars).
- [x] TODO #506: Topic `InferenceOrdinalJonckheereTerpstraTest` (current description `310` chars).

### `InferenceOrdinalKKCLMM.Rd`

- [ ] TODO #507: Method `InferenceOrdinalKKCLMM$new()` (current description `98` chars).
- [ ] TODO #508: Topic `InferenceOrdinalKKCLMM` (current description `186` chars).

### `InferenceOrdinalKKCLMMCauchit.Rd`

- [ ] TODO #509: Method `InferenceOrdinalKKCLMMCauchit$new()` (current description `100` chars).
- [ ] TODO #510: Topic `InferenceOrdinalKKCLMMCauchit` (current description `85` chars).

### `InferenceOrdinalKKCLMMCloglog.Rd`

- [ ] TODO #511: Method `InferenceOrdinalKKCLMMCloglog$new()` (current description `100` chars).
- [ ] TODO #512: Topic `InferenceOrdinalKKCLMMCloglog` (current description `113` chars).

### `InferenceOrdinalKKCLMMProbit.Rd`

- [ ] TODO #513: Method `InferenceOrdinalKKCLMMProbit$new()` (current description `99` chars).
- [ ] TODO #514: Topic `InferenceOrdinalKKCLMMProbit` (current description `83` chars).

### `InferenceOrdinalKKCondAdjCatLogitRegr.Rd`

- [x] TODO #515: Method `InferenceOrdinalKKCondAdjCatLogitRegr$approximate_bootstrap_distribution_beta_hat_T()` (current description `66` chars). Newly ungated 2026-08-19 (class migrated to `inherit = Inference`); method is provided by the already well-documented `KKPassThrough` component (`inference_mixin_kk_passthrough.R`) — no change needed, doc propagates automatically.
- [x] TODO #516: Method `InferenceOrdinalKKCondAdjCatLogitRegr$compute_asymp_confidence_interval()` (current description `43` chars). Documented Wald CI contract.
- [x] TODO #517: Method `InferenceOrdinalKKCondAdjCatLogitRegr$compute_asymp_two_sided_pval()` (current description `128` chars). Already adequate; no change needed.
- [x] TODO #518: Method `InferenceOrdinalKKCondAdjCatLogitRegr$compute_estimate_with_bootstrap_weights()` (current description `53` chars). Documented the weighted-surrogate-fit approximation (not an exact reweighted expanded-data refit).
- [x] TODO #519: Method `InferenceOrdinalKKCondAdjCatLogitRegr$compute_estimate()` (current description `38` chars). Documented the stacked-binary-expansion + conditional-logit fit.
- [x] TODO #520: Method `InferenceOrdinalKKCondAdjCatLogitRegr$new()` (current description `131` chars). Documented model form and deferred-fit behavior.
- [x] TODO #521: Topic `InferenceOrdinalKKCondAdjCatLogitRegr` (current description `260` chars). Full model/estimand/likelihood-tier doc added, contrasted with the non-KK `InferenceOrdinalAdjCatLogitRegr` sibling; added Agresti (2010) and KK14 `@references`, `REFERENCES.md` updated (`[Agresti2010Ordinal]` and `[KK14]` "Used by" lists).

### `InferenceOrdinalKKGEE.Rd`

- [x] TODO #522: Method `InferenceOrdinalKKGEE$approximate_bootstrap_distribution_beta_hat_T()` (current description `66` chars).
- [x] TODO #523: Method `InferenceOrdinalKKGEE$compute_asymp_confidence_interval()` (current description `60` chars).
- [x] TODO #524: Method `InferenceOrdinalKKGEE$compute_asymp_two_sided_pval()` (current description `58` chars).
- [x] TODO #525: Method `InferenceOrdinalKKGEE$compute_estimate_with_bootstrap_weights()` (current description `54` chars).
- [x] TODO #526: Method `InferenceOrdinalKKGEE$compute_estimate()` (current description `166` chars).
- [x] TODO #527: Method `InferenceOrdinalKKGEE$new()` (current description `127` chars).
- [x] TODO #528: Topic `InferenceOrdinalKKGEE` (current description `264` chars).

### `InferenceOrdinalKKGLMM.Rd`

- [x] TODO #529: Method `InferenceOrdinalKKGLMM$compute_asymp_confidence_interval()` (current description `60` chars). Newly ungated 2026-08-19 (class migrated to `inherit = Inference`); documented Wald CI contract.
- [x] TODO #530: Method `InferenceOrdinalKKGLMM$compute_asymp_two_sided_pval()` (current description `58` chars). Documented Wald test of H0: beta_T = delta.
- [x] TODO #531: Method `InferenceOrdinalKKGLMM$compute_estimate_with_bootstrap_weights()` (current description `55` chars). Documented the weighted-ordinary-logit (not reweighted-GLMM) fast-path approximation.
- [x] TODO #532: Method `InferenceOrdinalKKGLMM$compute_estimate()` (current description `58` chars). Documented model fit/caching/nonestimable-caching behavior.
- [x] TODO #533: Method `InferenceOrdinalKKGLMM$new()` (current description `131` chars). Documented random-intercept cumulative-logit model form and deferred-fit behavior.
- [x] TODO #534: Topic `InferenceOrdinalKKGLMM` (current description `430` chars). Full model/estimand/likelihood-tier doc added, contrasted with the GEE sibling; added Hedeker & Gibbons (1994) and Pinheiro & Bates (1995) `@references`, `REFERENCES.md` updated (new `[HedekerGibbons1994]` entry, added to `[PinheiroBates1995]`'s "Used by").

### `InferenceOrdinalOrderedProbitRegr.Rd`

- [ ] TODO #535: Method `InferenceOrdinalOrderedProbitRegr$compute_estimate_with_bootstrap_weights()` (current description `55` chars).
- [ ] TODO #536: Method `InferenceOrdinalOrderedProbitRegr$new()` (current description `46` chars).
- [ ] TODO #537: Topic `InferenceOrdinalOrderedProbitRegr` (current description `199` chars).

### `InferenceOrdinalPairedSignTest.Rd`

- [ ] TODO #538: Method `InferenceOrdinalPairedSignTest$approximate_bootstrap_distribution_beta_hat_T()` (current description `182` chars).
- [ ] TODO #539: Method `InferenceOrdinalPairedSignTest$approximate_jackknife_distribution_beta_hat_T()` (current description `162` chars).
- [ ] TODO #540: Method `InferenceOrdinalPairedSignTest$compute_asymp_confidence_interval()` (current description `62` chars).
- [ ] TODO #541: Method `InferenceOrdinalPairedSignTest$compute_asymp_two_sided_pval()` (current description `39` chars).
- [ ] TODO #542: Method `InferenceOrdinalPairedSignTest$compute_estimate_with_bootstrap_weights()` (current description `51` chars).
- [ ] TODO #543: Method `InferenceOrdinalPairedSignTest$compute_estimate()` (current description `73` chars).
- [ ] TODO #544: Method `InferenceOrdinalPairedSignTest$new()` (current description `122` chars).
- [ ] TODO #545: Topic `InferenceOrdinalPairedSignTest` (current description `320` chars).

### `InferenceOrdinalPartialProportionalOddsRegr.Rd`

- [x] TODO #546: Method `InferenceOrdinalPartialProportionalOddsRegr$benchmark_asymp_two_sided_pval_breakdown()` (current description `134` chars).
- [x] TODO #547: Method `InferenceOrdinalPartialProportionalOddsRegr$compute_asymp_confidence_interval()` (current description `143` chars).
- [x] TODO #548: Method `InferenceOrdinalPartialProportionalOddsRegr$compute_asymp_two_sided_pval()` (current description `140` chars).
- [x] TODO #549: Method `InferenceOrdinalPartialProportionalOddsRegr$compute_estimate_with_bootstrap_weights()` (current description `59` chars).
- [x] TODO #550: Method `InferenceOrdinalPartialProportionalOddsRegr$compute_estimate()` (current description `48` chars).
- [x] TODO #551: Method `InferenceOrdinalPartialProportionalOddsRegr$compute_wald_confidence_interval()` (current description `143` chars).
- [x] TODO #552: Method `InferenceOrdinalPartialProportionalOddsRegr$compute_wald_two_sided_pval()` (current description `140` chars).
- [x] TODO #553: Method `InferenceOrdinalPartialProportionalOddsRegr$new()` (current description `40` chars).
- [x] TODO #554: Topic `InferenceOrdinalPartialProportionalOddsRegr` (current description `306` chars).

### `InferenceOrdinalPropOddsRegr.Rd`

- [x] TODO #555: Method `InferenceOrdinalPropOddsRegr$compute_estimate_with_bootstrap_weights()` (current description `77` chars).
- [x] TODO #556: Method `InferenceOrdinalPropOddsRegr$new()` (current description `48` chars).
- [x] TODO #557: Topic `InferenceOrdinalPropOddsRegr` (current description `204` chars).

### `InferenceOrdinalRidit.Rd`

- [x] TODO #558: Method `InferenceOrdinalRidit$compute_asymp_confidence_interval()` (current description `69` chars).
- [x] TODO #559: Method `InferenceOrdinalRidit$compute_asymp_two_sided_pval()` (current description `67` chars).
- [x] TODO #560: Method `InferenceOrdinalRidit$compute_estimate_with_bootstrap_weights()` (current description `45` chars).
- [x] TODO #561: Method `InferenceOrdinalRidit$compute_estimate()` (current description `58` chars).
- [x] TODO #562: Method `InferenceOrdinalRidit$get_mean_ridit_treatment()` (current description `47` chars).
- [x] TODO #563: Method `InferenceOrdinalRidit$get_ridit_scores()` (current description `42` chars).
- [x] TODO #564: Method `InferenceOrdinalRidit$new()` (current description `45` chars).
- [x] TODO #565: Topic `InferenceOrdinalRidit` (current description `358` chars).

### `InferenceOrdinalStereotypeLogitRegr.Rd`

- [ ] TODO #566: Method `InferenceOrdinalStereotypeLogitRegr$compute_estimate_with_bootstrap_weights()` (current description `56` chars).
- [ ] TODO #567: Method `InferenceOrdinalStereotypeLogitRegr$new()` (current description `47` chars).
- [ ] TODO #568: Topic `InferenceOrdinalStereotypeLogitRegr` (current description `202` chars).

### `InferencePropBetaRegr.Rd`

- [ ] TODO #569: Method `InferencePropBetaRegr$compute_estimate_with_bootstrap_weights()` (current description `77` chars).
- [ ] TODO #570: Method `InferencePropBetaRegr$compute_estimate()` (current description `58` chars).
- [ ] TODO #571: Method `InferencePropBetaRegr$new()` (current description `46` chars).
- [ ] TODO #572: Topic `InferencePropBetaRegr` (current description `208` chars).

### `InferencePropFractionalLogit.Rd`

- [ ] TODO #573: Method `InferencePropFractionalLogit$compute_estimate_with_bootstrap_weights()` (current description `77` chars).
- [ ] TODO #574: Method `InferencePropFractionalLogit$compute_estimate()` (current description `58` chars).
- [ ] TODO #575: Method `InferencePropFractionalLogit$new()` (current description `47` chars).
- [ ] TODO #576: Topic `InferencePropFractionalLogit` (current description `241` chars).

### `InferencePropGCompMeanDiff.Rd`

- [x] TODO #577: Topic `InferencePropGCompMeanDiff` (current description `362` chars).

### `InferencePropKKGEE.Rd`

- [x] TODO #578: Method `InferencePropKKGEE$approximate_bootstrap_distribution_beta_hat_T()` (current description `66` chars).
- [x] TODO #579: Method `InferencePropKKGEE$compute_asymp_confidence_interval()` (current description `60` chars).
- [x] TODO #580: Method `InferencePropKKGEE$compute_asymp_two_sided_pval()` (current description `58` chars).
- [x] TODO #581: Method `InferencePropKKGEE$compute_estimate_with_bootstrap_weights()` (current description `76` chars).
- [x] TODO #582: Method `InferencePropKKGEE$compute_estimate()` (current description `171` chars).
- [x] TODO #583: Method `InferencePropKKGEE$new()` (current description `131` chars).
- [x] TODO #584: Topic `InferencePropKKGEE` (current description `300` chars).

### `InferencePropKKGLMM.Rd`

- [ ] TODO #585: Method `InferencePropKKGLMM$new()` (current description `95` chars).
- [ ] TODO #586: Topic `InferencePropKKGLMM` (current description `194` chars).

### `InferencePropKKQuantileRegrIVWC.Rd`

- [x] TODO #587: Method `InferencePropKKQuantileRegrIVWC$new()` (current description `101` chars). Reviewed: `new()` resolves to the shared `KKQuantileRegrIVWC` component's already fully-documented initializer (tau/transform_y_fn/model_formula all documented there); nothing to add.
- [x] TODO #588: Topic `InferencePropKKQuantileRegrIVWC` (current description `1458` chars). Reviewed: topic doc already covers the compound-estimator formula, logit-scale transform, Powell sandwich SE, and quantreg dependency in depth; already meets the standard.

### `InferencePropKKQuantileRegrOneLik.Rd`

- [x] TODO #589: Method `InferencePropKKQuantileRegrOneLik$compute_estimate()` (current description `57` chars). Reviewed: already documented via the shared `KKQuantileRegrOneLik` component (a prior pass added `@eqn`-level docs there).
- [x] TODO #590: Method `InferencePropKKQuantileRegrOneLik$new()` (current description `185` chars). Reviewed: already documented via the shared component initializer.
- [x] TODO #591: Topic `InferencePropKKQuantileRegrOneLik` (current description `542` chars). Added pinball-loss formula, contrast with IVWC sibling, Koenker (2005) citation.

### `InferencePropQuantileRegr.Rd`

- [x] TODO #592: Method `InferencePropQuantileRegr$compute_asymp_confidence_interval()` (current description `60` chars).
- [x] TODO #593: Method `InferencePropQuantileRegr$compute_asymp_two_sided_pval()` (current description `58` chars).
- [x] TODO #594: Method `InferencePropQuantileRegr$compute_estimate_with_bootstrap_weights()` (current description `77` chars).
- [x] TODO #595: Method `InferencePropQuantileRegr$compute_estimate()` (current description `66` chars).
- [x] TODO #596: Method `InferencePropQuantileRegr$new()` (current description `72` chars).
- [x] TODO #597: Topic `InferencePropQuantileRegr` (current description `834` chars).

### `InferencePropZeroOneInflatedBetaRegr.Rd`

- [ ] TODO #598: Method `InferencePropZeroOneInflatedBetaRegr$approximate_bootstrap_distribution_beta_hat_T()` (current description `66` chars).
- [ ] TODO #599: Method `InferencePropZeroOneInflatedBetaRegr$compute_estimate_with_bootstrap_weights()` (current description `77` chars).
- [ ] TODO #600: Method `InferencePropZeroOneInflatedBetaRegr$compute_estimate()` (current description `58` chars).
- [ ] TODO #601: Method `InferencePropZeroOneInflatedBetaRegr$new()` (current description `64` chars).
- [ ] TODO #602: Topic `InferencePropZeroOneInflatedBetaRegr` (current description `655` chars).

### `InferenceSuite.Rd`

- [x] TODO #603: Method `InferenceSuite$new()` (current description `164` chars).
- [x] TODO #604: Topic `InferenceSuite` (current description `706` chars).

### `InferenceSurvivalCoxPHRegr.Rd`

- [x] TODO #605: Method `InferenceSurvivalCoxPHRegr$compute_estimate_with_bootstrap_weights()` (current description `46` chars).
- [x] TODO #606: Method `InferenceSurvivalCoxPHRegr$compute_estimate()` (current description `53` chars).
- [x] TODO #607: Method `InferenceSurvivalCoxPHRegr$new()` (current description `37` chars).
- [x] TODO #608: Topic `InferenceSurvivalCoxPHRegr` (current description `220` chars).

### `InferenceSurvivalDepCensTransformRegr.Rd`

- [ ] TODO #609: Method `InferenceSurvivalDepCensTransformRegr$approximate_randomization_distribution_beta_hat_T()` (current description `69` chars).
- [ ] TODO #610: Method `InferenceSurvivalDepCensTransformRegr$compute_asymp_confidence_interval()` (current description `60` chars).
- [ ] TODO #611: Method `InferenceSurvivalDepCensTransformRegr$compute_asymp_two_sided_pval()` (current description `58` chars).
- [ ] TODO #612: Method `InferenceSurvivalDepCensTransformRegr$compute_bootstrap_confidence_interval_basic()` (current description `62` chars).
- [ ] TODO #613: Method `InferenceSurvivalDepCensTransformRegr$compute_bootstrap_confidence_interval_bca()` (current description `60` chars).
- [ ] TODO #614: Method `InferenceSurvivalDepCensTransformRegr$compute_bootstrap_confidence_interval_studentized()` (current description `68` chars).
- [ ] TODO #615: Method `InferenceSurvivalDepCensTransformRegr$compute_bootstrap_confidence_interval()` (current description `56` chars).
- [ ] TODO #616: Method `InferenceSurvivalDepCensTransformRegr$compute_estimate_with_bootstrap_weights()` (current description `58` chars).
- [ ] TODO #617: Method `InferenceSurvivalDepCensTransformRegr$compute_estimate()` (current description `58` chars).
- [ ] TODO #618: Method `InferenceSurvivalDepCensTransformRegr$compute_jackknife_bias_estimate()` (current description `62` chars).
- [ ] TODO #619: Method `InferenceSurvivalDepCensTransformRegr$compute_jackknife_estimate()` (current description `114` chars).
- [ ] TODO #620: Method `InferenceSurvivalDepCensTransformRegr$compute_jackknife_std_error()` (current description `63` chars).
- [ ] TODO #621: Method `InferenceSurvivalDepCensTransformRegr$compute_jackknife_wald_confidence_interval()` (current description `73` chars).
- [ ] TODO #622: Method `InferenceSurvivalDepCensTransformRegr$compute_jackknife_wald_two_sided_pval()` (current description `71` chars).
- [ ] TODO #623: Method `InferenceSurvivalDepCensTransformRegr$compute_lik_ratio_confidence_interval()` (current description `58` chars).
- [ ] TODO #624: Method `InferenceSurvivalDepCensTransformRegr$compute_rand_confidence_interval()` (current description `72` chars).
- [ ] TODO #625: Method `InferenceSurvivalDepCensTransformRegr$compute_rand_two_sided_pval()` (current description `122` chars).
- [ ] TODO #626: Method `InferenceSurvivalDepCensTransformRegr$compute_score_two_sided_pval()` (current description `89` chars).
- [ ] TODO #627: Method `InferenceSurvivalDepCensTransformRegr$new()` (current description `65` chars).
- [ ] TODO #628: Topic `InferenceSurvivalDepCensTransformRegr` (current description `240` chars).

### `InferenceSurvivalGehanWilcox.Rd`

- [x] TODO #629: Method `InferenceSurvivalGehanWilcox$compute_asymp_confidence_interval()` (current description `163` chars).
- [x] TODO #630: Method `InferenceSurvivalGehanWilcox$compute_asymp_two_sided_pval()` (current description `186` chars).
- [x] TODO #631: Method `InferenceSurvivalGehanWilcox$compute_estimate_with_bootstrap_weights()` (current description `77` chars).
- [x] TODO #632: Method `InferenceSurvivalGehanWilcox$compute_estimate()` (current description `156` chars).
- [x] TODO #633: Method `InferenceSurvivalGehanWilcox$compute_rand_confidence_interval()` (current description `154` chars).
- [x] TODO #634: Method `InferenceSurvivalGehanWilcox$new()` (current description `99` chars).
- [x] TODO #635: Topic `InferenceSurvivalGehanWilcox` (current description `931` chars).

### `InferenceSurvivalKKClaytonCopulaIVWC.Rd`

- [x] TODO #636: Method `InferenceSurvivalKKClaytonCopulaIVWC$approximate_bootstrap_distribution_beta_hat_T()` (reviewed: supplied by the KK component chain, not this Source; that shared implementation already documented via `KKCompound`/`KKPassThrough`).
- [x] TODO #637: Method `InferenceSurvivalKKClaytonCopulaIVWC$compute_asymp_confidence_interval()` (reviewed: `SurvivalKKClaytonCopulaIVWCSource` already documents params and links `InferenceAsymp`; adequate as-is).
- [x] TODO #638: Method `InferenceSurvivalKKClaytonCopulaIVWC$compute_asymp_two_sided_pval()` (reviewed: already documents the frailty/dependence-model p-value semantics; adequate as-is).
- [x] TODO #639: Method `InferenceSurvivalKKClaytonCopulaIVWC$compute_estimate_with_bootstrap_weights()` (reviewed: already documents the Bayesian-bootstrap weighted-surrogate-fit behavior and constant-weight fast path; adequate as-is).
- [x] TODO #640: Method `InferenceSurvivalKKClaytonCopulaIVWC$compute_estimate()` (reviewed: already documents log-time-ratio estimand; adequate as-is).
- [x] TODO #641: Method `InferenceSurvivalKKClaytonCopulaIVWC$duplicate()` (reviewed: intentionally not overridden by this Source per the "Static Cleanup" comment — inherited from the KK component chain, already documented there).
- [x] TODO #642: Method `InferenceSurvivalKKClaytonCopulaIVWC$new()` (reviewed: already documents params and delegation; adequate as-is).
- [x] TODO #643: Topic `InferenceSurvivalKKClaytonCopulaIVWC` (reviewed: already documents the Clayton-copula/Weibull-frailty closed form, cites Clayton 1978 and Oakes 1989, and cross-links the log-normal-frailty sibling class; adequate as-is).

### `InferenceSurvivalKKClaytonCopulaOneLik.Rd`

- [x] TODO #644: Method `InferenceSurvivalKKClaytonCopulaOneLik$approximate_bootstrap_distribution_beta_hat_T()` (current description `66` chars).
- [x] TODO #645: Method `InferenceSurvivalKKClaytonCopulaOneLik$compute_asymp_confidence_interval()` (current description `60` chars).
- [x] TODO #646: Method `InferenceSurvivalKKClaytonCopulaOneLik$compute_asymp_two_sided_pval()` (current description `122` chars).
- [x] TODO #647: Method `InferenceSurvivalKKClaytonCopulaOneLik$compute_estimate()` (current description `65` chars).
- [x] TODO #648: Method `InferenceSurvivalKKClaytonCopulaOneLik$duplicate()` (current description `57` chars).
- [x] TODO #649: Method `InferenceSurvivalKKClaytonCopulaOneLik$new()` (current description `106` chars).
- [x] TODO #650: Topic `InferenceSurvivalKKClaytonCopulaOneLik` (current description `119` chars).

### `InferenceSurvivalKKLWACoxPHIVWC.Rd`

- [x] TODO #651: Method `InferenceSurvivalKKLWACoxPHIVWC$new()` (current description `81` chars). Reviewed: already documented via the shared abstract component's initializer.
- [x] TODO #652: Topic `InferenceSurvivalKKLWACoxPHIVWC` (current description `292` chars). Added Cox+LWA sandwich formula, contrast with OneLik sibling, Lee-Wei-Amato (1992) citation.

### `InferenceSurvivalKKLWACoxPHOneLik.Rd`

- [x] TODO #653: Method `InferenceSurvivalKKLWACoxPHOneLik$new()` (current description `91` chars). Reviewed: already documented via the shared abstract component's initializer.
- [x] TODO #654: Topic `InferenceSurvivalKKLWACoxPHOneLik` (current description `208` chars). Added combined-partial-likelihood formula, contrast with IVWC sibling, likelihood_tier note.

### `InferenceSurvivalKKRankRegrIVWC.Rd`

- [x] TODO #655: Method `InferenceSurvivalKKRankRegrIVWC$new()` (reviewed: `SurvivalKKRankRegrIVWCSource$initialize` in `inference_survival_KK_rank_regr_ivwc_abstract.R` already documents params and delegates behavior; adequate as-is).
- [x] TODO #656: Topic `InferenceSurvivalKKRankRegrIVWC` (reviewed: existing topic doc already covers model (Gehan-Wilcoxon rank AFT via `aftgee`), matched/reservoir combination rule, hardening behavior, and `aftgee` package requirement; adequate as-is).

### `InferenceSurvivalKKStratCoxPHIVWC.Rd`

- [x] TODO #657: Method `InferenceSurvivalKKStratCoxPHIVWC$approximate_bootstrap_distribution_beta_hat_T()` (reviewed: supplied by the KK component chain, already documented there).
- [x] TODO #658: Method `InferenceSurvivalKKStratCoxPHIVWC$compute_asymp_confidence_interval()` (reviewed: `SurvivalKKStratCoxIVWCSource` already documents params and links `InferenceAsymp`; adequate as-is).
- [x] TODO #659: Method `InferenceSurvivalKKStratCoxPHIVWC$compute_asymp_two_sided_pval()` (reviewed: already documents partial-likelihood SE-based p-value semantics; adequate as-is).
- [x] TODO #660: Method `InferenceSurvivalKKStratCoxPHIVWC$compute_estimate()` (reviewed: already documents log-hazard-ratio estimand; adequate as-is).
- [x] TODO #661: Method `InferenceSurvivalKKStratCoxPHIVWC$new()` (reviewed: already documents params and delegation; adequate as-is).
- [x] TODO #662: Topic `InferenceSurvivalKKStratCoxPHIVWC` (expanded: added the matched-pair-as-stratum vs. reservoir-unstratified model description with Cox 1972 / Lee-Wei-Amato 1992 `@references`; updated `REFERENCES.md` "Used by" lists for both entries).

### `InferenceSurvivalKKStratCoxPHOneLik.Rd`

- [x] TODO #663: Method `InferenceSurvivalKKStratCoxPHOneLik$approximate_bootstrap_distribution_beta_hat_T()` (reviewed: supplied by the KK component chain, already documented there).
- [x] TODO #664: Method `InferenceSurvivalKKStratCoxPHOneLik$compute_asymp_confidence_interval()` (reviewed: `SurvivalKKStratCoxOneLikPartialLikelihoodSource` already documents params; adequate as-is).
- [x] TODO #665: Method `InferenceSurvivalKKStratCoxPHOneLik$compute_asymp_two_sided_pval()` (reviewed: already documents combined-likelihood p-value semantics; adequate as-is).
- [x] TODO #666: Method `InferenceSurvivalKKStratCoxPHOneLik$compute_estimate_with_bootstrap_weights()` (reviewed: already documents Bayesian-bootstrap weighted-surrogate-fit behavior; adequate as-is).
- [x] TODO #667: Method `InferenceSurvivalKKStratCoxPHOneLik$compute_estimate()` (reviewed: already documents combined-likelihood estimand; adequate as-is).
- [x] TODO #668: Method `InferenceSurvivalKKStratCoxPHOneLik$new()` (reviewed: already documents params and delegation; adequate as-is).
- [x] TODO #669: Topic `InferenceSurvivalKKStratCoxPHOneLik` (was thin, only `@keywords internal`, no title/description — added a full topic doc explaining the combined-partial-likelihood model, contrasting it with the two-stage IVWC sibling, and citing Cox 1972 / Lee-Wei-Amato 1992).

### `InferenceSurvivalKKWeibullFrailtyIVWC.Rd`

- [x] TODO #670: Method `InferenceSurvivalKKWeibullFrailtyIVWC$new()` (reviewed: `SurvivalKKWeibullFrailtyIVWCSource$initialize` already documents params; adequate as-is).
- [x] TODO #671: Topic `InferenceSurvivalKKWeibullFrailtyIVWC` (reviewed/expanded: existing doc already had a thorough log-normal-vs-gamma-frailty model discussion; added missing `@references` for Vaupel/Manton/Stallard 1979 and Hougaard 2000, added matching `REFERENCES.md` entries).

### `InferenceSurvivalKKWeibullFrailtyOneLik.Rd`

- [x] TODO #672: Method `InferenceSurvivalKKWeibullFrailtyOneLik$new()` (current description `63` chars).
- [x] TODO #673: Topic `InferenceSurvivalKKWeibullFrailtyOneLik` (current description `121` chars).

### `InferenceSurvivalKKWeibullMarginal.Rd`

- [x] TODO #674: Method `InferenceSurvivalKKWeibullMarginal$approximate_bootstrap_distribution_beta_hat_T()` (reviewed: supplied by the `KKPassThrough` component, already documented there).
- [x] TODO #675: Method `InferenceSurvivalKKWeibullMarginal$compute_asymp_confidence_interval()` (reviewed: `SurvivalKKWeibullMarginalSource` already documents params and cluster-robust CI behavior; adequate as-is).
- [x] TODO #676: Method `InferenceSurvivalKKWeibullMarginal$compute_asymp_two_sided_pval()` (reviewed: already documents cluster-robust p-value semantics; adequate as-is).
- [x] TODO #677: Method `InferenceSurvivalKKWeibullMarginal$compute_estimate_with_bootstrap_weights()` (reviewed: already documents Bayesian-bootstrap weighted-surrogate-fit behavior; adequate as-is).
- [x] TODO #678: Method `InferenceSurvivalKKWeibullMarginal$compute_estimate()` (reviewed: already documents log-time-ratio estimand; adequate as-is).
- [x] TODO #679: Method `InferenceSurvivalKKWeibullMarginal$duplicate()` (reviewed: already documents fit-cache-preserving duplication with params; adequate as-is).
- [x] TODO #680: Method `InferenceSurvivalKKWeibullMarginal$new()` (reviewed: already documents params; adequate as-is).
- [x] TODO #681: Topic `InferenceSurvivalKKWeibullMarginal` (reviewed: already documents the pooled working-independence Weibull AFT model, cluster-robust sandwich construction, contrast with the frailty sibling class, and the `survival::survreg` fallback equivalence; adequate as-is).

### `InferenceSurvivalKMDiff.Rd`

- [x] TODO #682: Method `InferenceSurvivalKMDiff$approximate_bootstrap_distribution_beta_hat_T()` (current description `66` chars).
- [x] TODO #683: Method `InferenceSurvivalKMDiff$compute_asymp_confidence_interval()` (current description `704` chars).
- [x] TODO #684: Method `InferenceSurvivalKMDiff$compute_asymp_log_rank_two_sided_pval_for_treatment_effect()` (current description `48` chars).
- [x] TODO #685: Method `InferenceSurvivalKMDiff$compute_asymp_two_sided_pval()` (current description `68` chars).
- [x] TODO #686: Method `InferenceSurvivalKMDiff$compute_estimate_with_bootstrap_weights()` (current description `76` chars).
- [x] TODO #687: Method `InferenceSurvivalKMDiff$compute_estimate()` (current description `58` chars).
- [x] TODO #688: Method `InferenceSurvivalKMDiff$compute_rand_confidence_interval()` (current description `63` chars).
- [x] TODO #689: Method `InferenceSurvivalKMDiff$new()` (current description `112` chars).
- [x] TODO #690: Topic `InferenceSurvivalKMDiff` (current description `296` chars).

### `InferenceSurvivalLogRank.Rd`

- [x] TODO #691: Method `InferenceSurvivalLogRank$compute_asymp_confidence_interval()` (current description `135` chars).
- [x] TODO #692: Method `InferenceSurvivalLogRank$compute_asymp_log_rank_two_sided_pval_for_treatment_effect()` (current description `77` chars).
- [x] TODO #693: Method `InferenceSurvivalLogRank$compute_asymp_two_sided_pval()` (current description `75` chars).
- [x] TODO #694: Method `InferenceSurvivalLogRank$compute_estimate_with_bootstrap_weights()` (current description `77` chars).
- [x] TODO #695: Method `InferenceSurvivalLogRank$compute_estimate()` (current description `88` chars).
- [x] TODO #696: Method `InferenceSurvivalLogRank$compute_rand_confidence_interval()` (current description `152` chars).
- [x] TODO #697: Method `InferenceSurvivalLogRank$new()` (current description `92` chars).
- [x] TODO #698: Topic `InferenceSurvivalLogRank` (current description `435` chars).

### `InferenceSurvivalRestrictedMeanDiff.Rd`

- [x] TODO #699: Method `InferenceSurvivalRestrictedMeanDiff$approximate_bootstrap_distribution_beta_hat_T()` (current description `66` chars).
- [x] TODO #700: Method `InferenceSurvivalRestrictedMeanDiff$compute_asymp_confidence_interval()` (current description `262` chars).
- [x] TODO #701: Method `InferenceSurvivalRestrictedMeanDiff$compute_asymp_two_sided_pval()` (current description `48` chars).
- [x] TODO #702: Method `InferenceSurvivalRestrictedMeanDiff$compute_estimate_with_bootstrap_weights()` (current description `76` chars).
- [x] TODO #703: Method `InferenceSurvivalRestrictedMeanDiff$compute_estimate()` (current description `58` chars).
- [x] TODO #704: Method `InferenceSurvivalRestrictedMeanDiff$compute_rand_confidence_interval()` (current description `63` chars).
- [x] TODO #705: Method `InferenceSurvivalRestrictedMeanDiff$new()` (current description `116` chars).
- [x] TODO #706: Topic `InferenceSurvivalRestrictedMeanDiff` (current description `296` chars).

### `InferenceSurvivalStratCoxPHRegr.Rd`

- [x] TODO #707: Method `InferenceSurvivalStratCoxPHRegr$compute_estimate_with_bootstrap_weights()` (current description `57` chars).
- [x] TODO #708: Method `InferenceSurvivalStratCoxPHRegr$compute_rand_confidence_interval()` (current description `148` chars).
- [x] TODO #709: Method `InferenceSurvivalStratCoxPHRegr$new()` (current description `103` chars).
- [x] TODO #710: Topic `InferenceSurvivalStratCoxPHRegr` (current description `304` chars).

### `InferenceSurvivalWeibullRegr.Rd`

- [ ] TODO #711: Method `InferenceSurvivalWeibullRegr$compute_asymp_confidence_interval()` (current description `60` chars).
- [ ] TODO #712: Method `InferenceSurvivalWeibullRegr$compute_asymp_two_sided_pval()` (current description `58` chars).
- [ ] TODO #713: Method `InferenceSurvivalWeibullRegr$compute_estimate_with_bootstrap_weights()` (current description `51` chars).
- [ ] TODO #714: Method `InferenceSurvivalWeibullRegr$compute_estimate()` (current description `58` chars).
- [ ] TODO #715: Method `InferenceSurvivalWeibullRegr$new()` (current description `49` chars).
- [ ] TODO #716: Topic `InferenceSurvivalWeibullRegr` (current description `267` chars).

### `ObservationalDesign.Rd`

- [x] TODO #717: Method `ObservationalDesign$assert_even_allocation()` (current description `124` chars).
- [x] TODO #718: Method `ObservationalDesign$is_an_observational_design()` (current description `125` chars).
- [x] TODO #719: Method `ObservationalDesign$new()` (current description `57` chars).
- [x] TODO #720: Topic `ObservationalDesign` (current description `551` chars).

### `ObservationalDesignBlocks.Rd`

- [x] TODO #721: Method `ObservationalDesignBlocks$new()` (current description `95` chars).
- [x] TODO #722: Topic `ObservationalDesignBlocks` (current description `615` chars).

### `ObservationalDesignMatching.Rd`

- [x] TODO #723: Method `ObservationalDesignMatching$new()` (current description `186` chars).
- [x] TODO #724: Topic `ObservationalDesignMatching` (current description `580` chars).

### `inv_logit.Rd`

- [x] TODO #725: Topic `inv_logit` (current description `77` chars).

### `logit.Rd`

- [x] TODO #726: Topic `logit` (current description `49` chars).

### `mn_pvalue_cpp.Rd`

- [x] TODO #727: Topic `mn_pvalue_cpp` (current description `175` chars).

### `newcombe_independent_ci_cpp.Rd`

- [x] TODO #728: Topic `newcombe_independent_ci_cpp` (current description `172` chars).

### `ols_hc2_post_fit_cpp.Rd`

- [x] TODO #729: Topic `ols_hc2_post_fit_cpp` (current description `87` chars).

### `ordinal_gcomp_post_fit_cpp.Rd`

- [x] TODO #730: Topic `ordinal_gcomp_post_fit_cpp` (current description `115` chars).

### `pocock_simon_assign_and_update_cpp.Rd`

- [x] TODO #731: Topic `pocock_simon_assign_and_update_cpp` (current description `95` chars).

### `pocock_simon_assign_cpp.Rd`

- [x] TODO #732: Topic `pocock_simon_assign_cpp` (current description `85` chars).

### `pocock_simon_redraw_w_cpp.Rd`

- [x] TODO #733: Topic `pocock_simon_redraw_w_cpp` (current description `89` chars).

### `robust_negbinreg.Rd`

- [x] TODO #734: Topic `robust_negbinreg` (current description `154` chars).

### `robust_survreg_with_surv_object.Rd`

- [x] TODO #735: Topic `robust_survreg_with_surv_object` (current description `190` chars).

### `robust_survreg.Rd`

- [x] TODO #736: Topic `robust_survreg` (current description `210` chars).

### `sample_mode.Rd`

- [x] TODO #737: Topic `sample_mode` (current description `70` chars).

### `set_cold_start_dispatch_policy.Rd`

- [x] TODO #738: Topic `set_cold_start_dispatch_policy` (current description `75` chars).

### `set_num_cores.Rd`

- [x] TODO #739: Topic `set_num_cores` (current description `279` chars).

### `set_optimization_dispatch_policy.Rd`

- [x] TODO #740: Topic `set_optimization_dispatch_policy` (current description `79` chars).

### `set_parallel_dispatch_policy.Rd`

- [x] TODO #741: Topic `set_parallel_dispatch_policy` (current description `278` chars).

### `set_warm_start_dispatch_policy.Rd`

- [x] TODO #742: Topic `set_warm_start_dispatch_policy` (current description `75` chars).

### `SimulationFramework.Rd`

- [x] TODO #743: Method `SimulationFramework$clear_all_intermediate_data_and_gc()` (current description `199` chars).
- [x] TODO #744: Method `SimulationFramework$get_all_intermediate_data()` (current description `143` chars).
- [x] TODO #745: Method `SimulationFramework$new()` (current description `99` chars).
- [x] TODO #746: Method `SimulationFramework$run()` (current description `151` chars).
- [x] TODO #747: Topic `SimulationFramework` (current description `417` chars).

### `SimulationFrameworkReport.Rd`

- [x] TODO #748: Method `SimulationFrameworkReport$get_errors()` (current description `53` chars).
- [x] TODO #749: Method `SimulationFrameworkReport$get_results()` (current description `36` chars).
- [x] TODO #750: Method `SimulationFrameworkReport$new()` (current description `106` chars).
- [x] TODO #751: Method `SimulationFrameworkReport$print()` (current description `38` chars).
- [x] TODO #752: Method `SimulationFrameworkReport$summarize()` (current description `43` chars).
- [x] TODO #753: Topic `SimulationFrameworkReport` (current description `370` chars).

### `summary_glm_lean.Rd`

- [x] TODO #754: Topic `summary_glm_lean` (current description `104` chars).

### `toggle_asserts.Rd`

- [x] TODO #755: Topic `toggle_asserts` (current description `731` chars).

### `transform_cont_y_based_on_response_type.Rd`

- [x] TODO #756: Topic `transform_cont_y_based_on_response_type` (current description `267` chars).

### `unset_num_cores.Rd`

- [x] TODO #757: Topic `unset_num_cores` (current description `187` chars).

## Python Package (`edi_kernels`) Public Function Docstrings

Added 2026-08-14. The same documentation-quality pass as the R TODOs above,
applied to the 59 public functions the `edi_kernels` pybind11 package exports
(`python/cpp/bindings_*.cpp`). These are deliberately easy tasks: almost every
function is a direct binding of an R-package kernel whose expanded roxygen
(written for the TODOs above; the R sibling is usually `<name>_cpp`, e.g.
`fast_ols` ↔ `fast_ols_cpp`) can be copied and adapted — translate roxygen
markup to the numpydoc-style plain-text docstrings the bindings already use
(string literal after the `py::arg(...)` list in `m.def(...)`), keep the
`fixed_idx`/`fixed_values` and `estimate_only` conventions described in the
module docstring, and note any binding-level differences from the R signature
(e.g. `std::optional` args exposed as `None` defaults). Where the R kernel has
no roxygen of its own, copy from the R6 class method documentation that wraps
it. After editing, rebuild and spot-check with `help(edi_kernels.<fn>)`, and
mirror the update into the PyPI README parameter tables if one exists for the
function.

- [x] TODO #758: Python function `edi_kernels.dnorm_fast()` — expand docstring from its R sibling's documentation.
- [x] TODO #759: Python function `edi_kernels.fast_adjacent_category_logit()` — expand docstring from its R sibling's documentation.
- [x] TODO #760: Python function `edi_kernels.fast_atan()` — expand docstring from its R sibling's documentation.
- [x] TODO #761: Python function `edi_kernels.fast_beta_regression()` — expand docstring from its R sibling's documentation.
- [x] TODO #762: Python function `edi_kernels.fast_clayton_weibull_aft_optim()` — expand docstring from its R sibling's documentation.
- [x] TODO #763: Python function `edi_kernels.fast_clogit_plus_glmm()` — expand docstring from its R sibling's documentation.
- [x] TODO #764: Python function `edi_kernels.fast_continuation_ratio_regression()` — expand docstring from its R sibling's documentation.
- [x] TODO #765: Python function `edi_kernels.fast_coxph_regression()` — expand docstring from its R sibling's documentation.
- [x] TODO #766: Python function `edi_kernels.fast_cpoisson_combined()` — expand docstring from its R sibling's documentation.
- [x] TODO #767: Python function `edi_kernels.fast_dep_cens_transform_optim()` — expand docstring from its R sibling's documentation.
- [x] TODO #768: Python function `edi_kernels.fast_digamma()` — expand docstring from its R sibling's documentation.
- [x] TODO #769: Python function `edi_kernels.fast_dnbinom_mu()` — expand docstring from its R sibling's documentation.
- [x] TODO #770: Python function `edi_kernels.fast_erfc()` — expand docstring from its R sibling's documentation.
- [x] TODO #771: Python function `edi_kernels.fast_gaussian_lmm()` — expand docstring from its R sibling's documentation.
- [x] TODO #772: Python function `edi_kernels.fast_gehan_wilcox_stats()` — expand docstring from its R sibling's documentation.
- [x] TODO #773: Python function `edi_kernels.fast_hurdle_negbin()` — expand docstring from its R sibling's documentation.
- [x] TODO #774: Python function `edi_kernels.fast_hurdle_poisson_glmm()` — expand docstring from its R sibling's documentation.
- [x] TODO #775: Python function `edi_kernels.fast_lbeta()` — expand docstring from its R sibling's documentation.
- [x] TODO #776: Python function `edi_kernels.fast_lgamma()` — expand docstring from its R sibling's documentation.
- [x] TODO #777: Python function `edi_kernels.fast_log1pexp()` — expand docstring from its R sibling's documentation.
- [x] TODO #778: Python function `edi_kernels.fast_log_dnorm()` — expand docstring from its R sibling's documentation.
- [x] TODO #779: Python function `edi_kernels.fast_log_pnorm()` — expand docstring from its R sibling's documentation.
- [x] TODO #780: Python function `edi_kernels.fast_logistic_glmm()` — expand docstring from its R sibling's documentation.
- [x] TODO #781: Python function `edi_kernels.fast_logistic_regression()` — expand docstring from its R sibling's documentation.
- [x] TODO #782: Python function `edi_kernels.fast_logrank_stats()` — expand docstring from its R sibling's documentation.
- [x] TODO #783: Python function `edi_kernels.fast_neg_bin()` — expand docstring from its R sibling's documentation.
- [x] TODO #784: Python function `edi_kernels.fast_ols()` — expand docstring from its R sibling's documentation.
- [x] TODO #785: Python function `edi_kernels.fast_ordinal_cauchit_regression()` — expand docstring from its R sibling's documentation.
- [x] TODO #786: Python function `edi_kernels.fast_ordinal_clmm()` — expand docstring from its R sibling's documentation.
- [x] TODO #787: Python function `edi_kernels.fast_ordinal_cloglog_regression()` — expand docstring from its R sibling's documentation.
- [x] TODO #788: Python function `edi_kernels.fast_ordinal_glmm()` — expand docstring from its R sibling's documentation.
- [x] TODO #789: Python function `edi_kernels.fast_ordinal_probit_regression()` — expand docstring from its R sibling's documentation.
- [x] TODO #790: Python function `edi_kernels.fast_ordinal_regression()` — expand docstring from its R sibling's documentation.
- [x] TODO #791: Python function `edi_kernels.fast_pchisq_upper()` — expand docstring from its R sibling's documentation.
- [x] TODO #792: Python function `edi_kernels.fast_poisson_glmm()` — expand docstring from its R sibling's documentation.
- [x] TODO #793: Python function `edi_kernels.fast_poisson_regression()` — expand docstring from its R sibling's documentation.
- [x] TODO #794: Python function `edi_kernels.fast_probit_regression()` — expand docstring from its R sibling's documentation.
- [x] TODO #795: Python function `edi_kernels.fast_qnorm()` — expand docstring from its R sibling's documentation.
- [x] TODO #796: Python function `edi_kernels.fast_ridit_analysis()` — expand docstring from its R sibling's documentation.
- [x] TODO #797: Python function `edi_kernels.fast_robust_regression()` — expand docstring from its R sibling's documentation.
- [x] TODO #798: Python function `edi_kernels.fast_stereotype_logit()` — expand docstring from its R sibling's documentation.
- [x] TODO #799: Python function `edi_kernels.fast_stratified_coxph_regression()` — expand docstring from its R sibling's documentation.
- [x] TODO #800: Python function `edi_kernels.fast_trigamma()` — expand docstring from its R sibling's documentation.
- [x] TODO #801: Python function `edi_kernels.fast_truncated_negbin_count()` — expand docstring from its R sibling's documentation.
- [x] TODO #802: Python function `edi_kernels.fast_weibull_frailty()` — expand docstring from its R sibling's documentation.
- [x] TODO #803: Python function `edi_kernels.fast_weibull_regression()` — expand docstring from its R sibling's documentation.
- [x] TODO #804: Python function `edi_kernels.fast_zero_augmented_poisson()` — expand docstring from its R sibling's documentation.
- [x] TODO #805: Python function `edi_kernels.fast_zero_augmented_poisson_with_var()` — expand docstring from its R sibling's documentation.
- [x] TODO #806: Python function `edi_kernels.fast_zero_one_inflated_beta()` — expand docstring from its R sibling's documentation.
- [x] TODO #807: Python function `edi_kernels.fast_zinb()` — expand docstring from its R sibling's documentation.
- [x] TODO #808: Python function `edi_kernels.fast_zinb_with_var()` — expand docstring from its R sibling's documentation.
- [x] TODO #809: Python function `edi_kernels.gee_pairs_singletons()` — expand docstring from its R sibling's documentation.
- [x] TODO #810: Python function `edi_kernels.get_survival_stat_diff()` — expand docstring from its R sibling's documentation.
- [x] TODO #811: Python function `edi_kernels.mn_ci()` — expand docstring from its R sibling's documentation.
- [x] TODO #812: Python function `edi_kernels.mn_pvalue()` — expand docstring from its R sibling's documentation.
- [x] TODO #813: Python function `edi_kernels.newcombe_independent_ci()` — expand docstring from its R sibling's documentation.
- [x] TODO #814: Python function `edi_kernels.ols_hc2_post_fit()` — expand docstring from its R sibling's documentation.
- [x] TODO #815: Python function `edi_kernels.pnorm_fast()` — expand docstring from its R sibling's documentation.
- [x] TODO #816: Python function `edi_kernels.wilcox_hl_point_estimate()` — expand docstring from its R sibling's documentation.
