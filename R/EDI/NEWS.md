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
  classes.
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
