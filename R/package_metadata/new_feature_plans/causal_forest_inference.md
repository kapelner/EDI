# Causal-forest inference and Bayesian tree models

## Status

Proposed statistical-inference feature. This is not a hardware-acceleration plan and
does not depend on FPGA, GPU, NPU, or architecture-specific code. Those backends
could eventually accelerate repeated prediction or dense nuisance-model stages, but
the first implementation should use mature R packages and preserve EDI's design and
estimand contracts.

## Executive decision

Add heterogeneous-treatment-effect (HTE) inference to EDI through two related but
distinct families:

1. honest causal forests, initially backed by `grf`, for frequentist CATE estimation,
   doubly robust average-effect estimation, pointwise CATE uncertainty, and calibrated
   heterogeneity tests; and
2. Bayesian additive regression trees (BART), with Bayesian causal forests (BCF) as
   the preferred causal parameterization, for posterior distributions of individual,
   subgroup, and average treatment effects.

Do not implement a forest engine from scratch. Build optional-package adapters,
EDI-native validation, design-aware propensity handling, a stable result contract,
and tests of statistical calibration. Keep the two families behind a common HTE
interface, but do not present a BART credible interval as a frequentist confidence
interval or a forest variance estimate as a posterior distribution.

## Why EDI needs this

Regression inference in EDI answers questions about a scalar treatment coefficient
or a marginal average contrast. A causal forest answers the additional question

\[
  \tau(x) = E[Y(1)-Y(0) \mid X=x],
\]

allowing treatment effects to vary with baseline covariates. This is useful when an
experiment may contain responders and nonresponders, when targeting a later policy,
or when an average effect hides substantively important variation.

A tree does not supply a single regression coefficient called `beta_w`. Therefore:

- `compute_estimate()` must continue to return one clearly labelled scalar effect,
  normally the sample average treatment effect (SATE) or a declared target-population
  ATE;
- `predict_cate()` must return the separate conditional effect surface;
- subgroup summaries must state how groups were chosen and whether the same data were
  used to discover and estimate them; and
- documentation must never describe a CATE at one covariate vector as the coefficient
  of treatment.

The value is primarily richer causal analysis, not faster estimation. Prediction from
an already fitted forest can be fast and parallel, but forest fitting and uncertainty
estimation will generally cost more than the existing parametric paths.

## Estimand contract

### Required estimands

The first release should support:

- `conditional`: `tau(x)` at observed or supplied covariate values;
- `marginal_mean_diff`: the average of conditional risk or mean differences over a
  declared empirical target population;
- `sample_average_treatment_effect`: the average over analysis rows, recorded
  explicitly rather than silently equated with a population ATE; and
- optional subgroup average treatment effects for prespecified groups.

ATT, policy value, transported ATE, ratios, odds ratios, and survival-scale effects
should be later additions. For a binary outcome, the default marginal effect must be a
risk difference on the response-probability scale, not a latent-probit contrast.

Each result must record the estimand, target rows or target population, treatment
levels and contrast direction, nuisance-estimation strategy, and analysis weights.
The existing marginal-estimand machinery should be extended rather than bypassed.
Likelihood-ratio and score tests must not be advertised for an estimator that does not
provide the corresponding likelihood.

### Identification assumptions

Every fit summary should distinguish estimation from identification. At minimum,
record:

- consistency and no interference;
- known randomization probabilities for randomized designs, including row-, block-,
  or cluster-specific probabilities where applicable;
- conditional exchangeability and positivity if observational use is enabled; and
- the experimental unit at which assignment, resampling, and variance calculation
  occur.

The initial scope should be randomized experiments. Observational support should be
opt-in and wait for overlap diagnostics, propensity-model diagnostics, sensitivity
language, and tests covering confounding and poor overlap.

## Causal-forest implementation

### Estimation pipeline

For binary treatment and continuous or binary outcomes:

1. Validate the design, outcome, treatment contrast, covariates, missingness policy,
   weights, clusters, and target population.
2. Obtain treatment propensities from the EDI design object. Do not estimate a
   propensity when the design supplies it. Pass heterogeneous design probabilities
   at row level where the backend supports them.
3. Estimate the conditional outcome nuisance function out of sample. Use backend
   out-of-bag estimates or explicit cross-fitting; never use in-sample nuisance fits
   merely for convenience.
4. Residualize treatment and outcome and fit an honest causal forest. Honesty must be
   the default so that split selection and leaf-effect estimation use separate data.
5. Retain out-of-bag CATE and nuisance predictions for training-row summaries and
   doubly robust scores.
6. Compute the scalar SATE/ATE from orthogonal or augmented inverse-probability
   weighted scores rather than simply averaging adaptively overfit in-sample leaves.
7. Return point predictions, uncertainty information, overlap and leaf-support
   diagnostics, tuning choices, seeds, and backend version.

Use `grf::causal_forest()` as the first adapter. Its honest forest, out-of-bag
prediction, forest variance estimates, cluster support, and ATE helper cover the core
requirements. EDI owns validation and semantics; it must not expose unreviewed backend
defaults as if they were EDI guarantees.

### Pointwise CATE uncertainty

The default frequentist CATE interval should use the forest's asymptotic variance
estimator, based on grouped trees / the bootstrap-of-little-bags construction provided
by the backend. Label it a pointwise interval. It is not a simultaneous confidence
band over all rows, and hundreds of pointwise intervals must not be interpreted as a
multiple-testing-corrected search for responders.

Expose diagnostics for insufficient effective neighbors, extreme propensities,
degenerate local treatment counts, and unstable variance estimates. Return `NA` with
a structured reason when the backend's variance conditions are not met.

### Average-effect uncertainty

Construct out-of-bag or cross-fitted doubly robust scores and average them at the
correct experimental-unit level. Use:

- heteroskedasticity-robust influence-function standard errors for independent units;
- cluster-robust aggregation when treatment is assigned by cluster or the design
  declares dependence; and
- design weights or target-population weights only through an explicit estimand
  contract.

The scalar estimate and standard error should interoperate with EDI's normal/Wald
inference components where their assumptions hold. The plan should not force a forest
through likelihood-based components.

### Heterogeneity assessment

Add calibrated tests and summaries rather than declaring heterogeneity because one
CATE is large. Candidate methods are:

- held-out calibration tests of whether forest predictions contain systematic
  treatment-effect information;
- best linear projection of effects onto prespecified covariates;
- rank-weighted average treatment effect (RATE) or targeting-operator summaries; and
- prespecified subgroup contrasts with multiplicity adjustment.

Discovery and confirmation must use separate data or honest/cross-fitted predictions.
The API must state whether a result is exploratory, pointwise, or confirmatory.

## Randomization, bootstrap, and repeated fitting

### Default: asymptotic forest inference

Ordinary bootstrap resampling is not required for the standard causal-forest path.
Honesty, subsampling, out-of-bag nuisance estimates, and the forest variance estimator
provide the primary frequentist machinery. Changing only a forest seed measures
algorithmic variation; it is not a sampling bootstrap.

### Fisher randomization tests

Offer a design-based randomization test as a separate inference mode:

1. State a sharp null, ordinarily `Y_i(1) = Y_i(0)` for every experimental unit.
2. Choose and freeze a scalar statistic before drawing assignments, such as absolute
   cross-fitted ATE, a held-out heterogeneity score, or a policy-value statistic.
3. Draw assignments through the design object's exact replay API rather than permuting
   rows naively.
4. Refit the complete forest and nuisance pipeline for each assignment unless the
   learned structure is demonstrably independent of treatment and outcomes under the
   chosen procedure.
5. Fix tuning rules and use deterministic, recorded seed streams so differing backend
   randomness does not contaminate the assignment distribution.
6. Compute a finite-Monte-Carlo corrected p-value, for example
   `(1 + number_as_or_more_extreme) / (B + 1)`.

This tests a Fisher sharp null. It must not be labelled a test of only the weak null
`ATE = 0` under arbitrary heterogeneous effects. Blocked, matched, clustered, and
restricted designs must replay their actual assignment mechanism. Existing
`assert_design_supports_randomization_draw()` and design replay hooks should gate the
feature.

### Bootstrap options

If bootstrap intervals are added, resample the assignment/observation unit and refit
the complete pipeline, including nuisance models and tuning. Cluster trials require a
cluster bootstrap; row bootstrapping would be invalid. Support percentile or
studentized intervals only after simulation demonstrates coverage.

EDI's combined bootstrap-randomization path should be treated as an explicitly named,
experimental method here. It answers a different repeated-sampling question from a
pure design-based randomization test. Do not silently route `bootstrap` to repeated
forest seeds, and do not call the posterior draws from BART a bootstrap.

## Bayesian additive regression trees (BART)

### Role in EDI

BART is a complementary Bayesian model, not merely another implementation of a causal
forest. It represents a response surface as a sum of many weak regression trees and
uses MCMC to obtain posterior draws. For causal inference, each posterior draw can be
evaluated under both treatment assignments:

\[
  \tau_i^{(s)} = f^{(s)}(1, X_i) - f^{(s)}(0, X_i),
  \qquad
  \operatorname{ATE}^{(s)} = n^{-1}\sum_i \tau_i^{(s)}.
\]

This directly supplies posterior distributions for CATEs, subgroup effects, and the
sample-average effect. For probit BART, transform both potential outcomes to response
probabilities before subtracting; never report a latent-normal difference as a risk
difference.

### BART response-surface adapter

The simplest adapter fits `Y ~ f(W, X)` using an optional mature backend such as
`dbarts` or `BART`. It should:

- construct two prediction matrices per target row, one with `W = 1` and one with
  `W = 0`;
- retain or stream paired posterior predictions so contrasts preserve draw-wise
  dependence;
- summarize posterior means, medians, credible intervals, and probabilities such as
  `Pr(tau(x) > 0 | data)`;
- support continuous outcomes first and binary-probit outcomes second; and
- expose prior settings rather than burying them in backend defaults.

Because treatment and prognostic structure share the same regularization, this form
can suffer regularization-induced confounding. It is useful as a baseline and for
randomized experiments, but should not be the only Bayesian causal-tree option.

### Bayesian causal forest (BCF) adapter

Prefer BCF for the causal Bayesian path. Its model separates the prognostic and
treatment-effect surfaces:

\[
  Y_i = \mu(X_i, e_i) + \tau(X_i)W_i + \epsilon_i,
\]

where `e_i` is the propensity score. Separate priors allow stronger shrinkage of the
treatment-effect function toward homogeneity while allowing a flexible prognostic
surface. Including the propensity in the prognostic component helps mitigate
regularization-induced confounding.

For randomized EDI designs, obtain `e_i` from the design object. For observational
data, propensity estimates must be cross-fitted and their uncertainty and overlap
limitations documented. Evaluate `bcf`, `dbarts`, and `BART` for API stability,
maintenance, licensing, supported outcomes, weights/clusters, threading, and the
ability to return the posterior objects EDI needs. Register the selected packages in
`required_packages`; keep them in `Suggests` so base EDI installations remain light.

### Bayesian uncertainty and diagnostics

BART/BCF accessors must say `credible_interval`, not `confidence_interval`. A nominal
95% posterior interval does not automatically have 95% repeated-sampling coverage.
Calibration must be assessed in simulation across constant, sparse, nonlinear, and
strongly heterogeneous effects.

Record and report:

- number of chains, warmup/burn-in, retained draws, thinning, seeds, and threads;
- effective sample sizes and between-chain diagnostics where available;
- Monte Carlo standard errors for scalar ATE summaries;
- prior scales, tree counts, treatment-effect shrinkage, and residual model;
- warnings for nonconvergence, weak overlap, unsupported extrapolation, or excessive
  posterior storage; and
- whether posterior predictions were retained, thinned, streamed, or summarized.

Randomization testing with a BART-derived statistic is possible, but it requires a
fresh fit for each assignment with a fixed prior and MCMC policy. This will usually be
too expensive for the default path and should be an advanced option. Bayesian
posterior probabilities must not be marketed as randomization-test p-values.

## EDI API and class architecture

### Common HTE capability

Introduce a capability such as `heterogeneous_treatment_effects` and map it to a small
required public surface:

- `predict_cate(newdata = NULL, level = 0.95, ...)`;
- `get_cate_training()` using out-of-bag/cross-fitted estimates for forests;
- `compute_heterogeneity_test(method, ...)`;
- `get_effect_summary(target = c("sample", "population", "subgroup"), ...)`; and
- `get_hte_diagnostics()`.

`compute_estimate()` remains the scalar EDI entry point. A returned object should
carry an explicit uncertainty type (`forest_asymptotic`, `randomization`, `bootstrap`,
or `bayesian_posterior`) so downstream reporting cannot confuse them.

### Proposed class layering

Create an abstract or componentized HTE layer rather than duplicating validation and
result formatting in every response-specific class. Candidate concrete adapters are:

- continuous causal forest;
- incidence/binary causal forest;
- continuous BCF;
- continuous response-surface BART; and
- binary-probit BART after response-scale contrast tests are complete.

Final names should follow the existing inference naming convention after a registry
audit. Define classes through `define_inference_class()`, declare response types and
design families, list optional backend packages in `required_packages`, set
`adjusts_for_covariates = TRUE`, and add precise compatibility-reason callbacks.

Register the new capability-to-method mapping in the inference class registry. Extend
`InferenceSuite` discovery, execution, summaries, and plotting only after the class
contract is stable. Large fitted forests and posterior draws need an explicit
serialization policy and size-aware print methods.

### Design compatibility rollout

Use a conservative staged matrix:

1. individually randomized, binary-treatment, fixed designs with known propensities;
2. blocked and matched designs, preserving their propensity and replay semantics;
3. cluster-randomized designs with cluster-level fitting/resampling and robust
   variance support;
4. observational data behind explicit diagnostics and identification warnings; and
5. sequential or response-adaptive designs only after their time-dependent assignment
   probabilities and replay semantics are formally supported.

Reject unsupported combinations early. Never flatten a cluster or constrained design
into an iid row problem.

## Implementation phases

### Phase 0: contracts and statistical specification

- Freeze the SATE, ATE, CATE, subgroup, and binary response-scale definitions.
- Specify result schemas and uncertainty-type labels.
- Add the HTE capability and public-method validation to the registry design.
- Define which EDI designs can provide exact propensity vectors and replay draws.
- Write simulation acceptance thresholds before selecting backend defaults.

### Phase 1: minimal `grf` adapter

- Implement continuous-outcome, binary-treatment causal forests for iid randomized
  designs.
- Pass known design propensities and use honest/out-of-bag predictions.
- Return scalar doubly robust SATE, training CATEs, new-data CATEs, and diagnostics.
- Make the backend optional and return an actionable missing-package error.

### Phase 2: frequentist inference

- Add robust average-effect standard errors and pointwise forest CATE intervals.
- Add held-out calibration and prespecified best-linear-projection tests.
- Add binary outcomes and verify response-scale semantics.
- Validate tuning, variance, and low-support failure behavior.

### Phase 3: design awareness

- Add blocked/matched propensity handling and exact replay.
- Add cluster IDs, cluster-aware sampling, and cluster-robust ATE inference.
- Gate incompatible sequential, interference-prone, or nonbinary-treatment designs.

### Phase 4: randomization and bootstrap modes

- Implement sharp-null randomization tests with full pipeline refits and reproducible
  seed streams.
- Add only bootstrap variants whose unit of resampling is known from the design.
- Keep pure randomization, sampling bootstrap, and EDI bootstrap-randomization results
  separately named and tested.

### Phase 5: BART and BCF

- Run a backend bakeoff using the contract and simulation suite.
- Implement continuous BCF first, using known design propensities.
- Add response-surface BART as a documented baseline.
- Add binary-probit BART only after probability-scale contrasts and calibration pass.
- Add MCMC diagnostics, posterior storage controls, and posterior predictive checks.

### Phase 6: integration and performance

- Integrate stable classes into `InferenceSuite` and reporting.
- Add CATE plots that clearly distinguish pointwise intervals from simultaneous bands.
- Benchmark fit, prediction, memory, threading, and repeated-refit workloads.
- Document reproducibility across backend versions and thread counts.

## Testing and validation

### Unit and contract tests

- Registry metadata, capability-method mapping, optional-package errors, serialization,
  and print/summary behavior.
- Known propensities are passed unchanged; unknown propensities follow the declared
  cross-fitting path.
- Treatment labels and contrast direction cannot silently flip.
- Training CATEs use out-of-bag/cross-fitted values.
- Binary contrasts are on the probability scale.
- Cluster designs never resample rows independently.
- Randomization draws come from design replay and are reproducible.
- Forest seeds alone are never accepted as bootstrap replicates.
- BART posterior contrasts pair potential-outcome predictions within the same draw.

### Simulation matrix

Cover randomized and, later, observational data-generating processes with:

- null, constant, sparse, smooth nonlinear, threshold, and high-dimensional treatment
  effects;
- strong prognostic structure with weak treatment heterogeneity;
- balanced and unequal assignment probabilities;
- good and poor overlap;
- iid, blocked, matched, and clustered assignment;
- continuous and binary outcomes; and
- irrelevant covariates, missingness, small leaves, and rare outcomes.

Measure ATE bias, RMSE, interval coverage, type-I error and power; CATE RMSE and
pointwise coverage; heterogeneity-test calibration; subgroup selection bias; BART
posterior calibration and MCMC error; runtime; and peak memory. Compare with the
correctly specified parametric estimator, a misspecified parametric estimator, and a
simple difference in means under randomization.

## Performance expectations

These are planning ranges to replace with EDI benchmarks, not promises:

- A 2,000-tree causal forest will commonly take roughly 5--50 times as long as a
  single low-dimensional linear or generalized-linear fit, depending on `n`, `p`,
  tuning, threads, and variance requests.
- Parallel forest building may provide approximately 2--8 times wall-clock speedup on
  4--16 useful cores before memory bandwidth and tree imbalance dominate.
- Prediction from a retained forest can serve large batches efficiently, but EDI's
  main benefit is effect heterogeneity rather than prediction throughput.
- A randomization test with `B` draws costs approximately `B + 1` full pipelines;
  999 draws can therefore mean hundreds to roughly one thousand times one-fit cost,
  reduced only by safe parallelism and reuse proven not to alter the statistic.
- BART/BCF MCMC may take roughly 10--100 times a simple regression fit and require
  material posterior storage. Multiple chains and randomization refits multiply that
  cost.

Benchmarks must report statistical settings, backend versions, core counts, memory,
and accuracy together. A faster configuration that damages coverage or CATE quality
is not an optimization.

## Risks and non-goals

- CATE estimates can be noisy even when the ATE is precise; polished plots must not
  imply individual-level certainty.
- Adaptive subgroup discovery can badly inflate false positives.
- Weak overlap causes extrapolation that neither forests nor BART magically repairs.
- Backend defaults and APIs may change, so adapters need version checks and regression
  tests.
- Randomization refitting and Bayesian MCMC can be prohibitively expensive.
- Survival, competing risks, multiple treatments, continuous doses, instrumental
  variables, interference, policy learning, and simultaneous CATE bands are not
  first-release requirements.
- Hardware-specific kernels and a native EDI forest implementation are non-goals.

## Acceptance criteria

The first causal-forest release is complete when it:

- supports continuous outcomes in individually randomized binary-treatment designs;
- uses known design propensities, honesty, and out-of-bag/cross-fitted predictions;
- returns a clearly labelled scalar SATE plus CATE predictions through separate APIs;
- provides robust SATE uncertainty and pointwise CATE uncertainty with honest labels;
- registers its metadata, optional dependency, capabilities, and compatibility rules;
- rejects unsupported design structures rather than approximating them silently; and
- meets prespecified bias, coverage, type-I-error, reproducibility, and memory targets.

The first Bayesian release additionally requires a reviewed BCF/BART backend,
draw-wise potential-outcome contrasts, explicit priors, MCMC diagnostics,
probability-scale handling for binary outcomes if enabled, and simulation evidence
that credible intervals are acceptably calibrated for the supported scope.

## Recommended delivery order

1. `grf` continuous causal forest for fixed randomized designs.
2. Robust ATE inference, pointwise CATE intervals, and heterogeneity diagnostics.
3. Blocked/matched and cluster-aware support.
4. Sharp-null randomization tests and carefully scoped bootstrap support.
5. Continuous BCF, then response-surface BART.
6. Binary outcomes, broader designs, and advanced estimands.

This order gives EDI a useful HTE feature early while postponing the most expensive
and easiest-to-misinterpret inference modes.

## Primary references

- Wager, S. and Athey, S. (2018). *Estimation and Inference of Heterogeneous Treatment
  Effects using Random Forests*. Journal of the American Statistical Association.
  https://doi.org/10.1080/01621459.2017.1319839
- Athey, S., Tibshirani, J., and Wager, S. (2019). *Generalized Random Forests*.
  Annals of Statistics. https://doi.org/10.1214/18-AOS1709
- `grf` reference documentation: https://grf-labs.github.io/grf/REFERENCE.html
- Chipman, H. A., George, E. I., and McCulloch, R. E. (2010). *BART: Bayesian
  Additive Regression Trees*. Annals of Applied Statistics.
  https://doi.org/10.1214/09-AOAS285
- Hill, J. L. (2011). *Bayesian Nonparametric Modeling for Causal Inference*.
  Journal of Computational and Graphical Statistics.
  https://doi.org/10.1198/jcgs.2010.08162
- Hahn, P. R., Murray, J. S., and Carvalho, C. M. (2020). *Bayesian Regression Tree
  Models for Causal Inference: Regularization, Confounding, and Heterogeneous
  Effects*. Bayesian Analysis. https://doi.org/10.1214/19-BA1195
