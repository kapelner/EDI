# Experimental Design and Inference (EDI) Software

[![CRAN](https://img.shields.io/cran/v/EDI.svg)](https://CRAN.R-project.org/package=EDI)
[![R-CMD-check](https://github.com/kapelner/EDI/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/kapelner/EDI/actions/workflows/R-CMD-check.yaml)
[![R coverage](https://codecov.io/gh/kapelner/EDI/branch/main/graph/badge.svg?flag=r)](https://codecov.io/gh/kapelner/EDI/flags/r)\
[![PyPI](https://img.shields.io/pypi/v/edi_kernels.svg)](https://pypi.org/project/edi_kernels/)
[![Python tests](https://github.com/kapelner/EDI/actions/workflows/python-tests.yml/badge.svg)](https://github.com/kapelner/EDI/actions/workflows/python-tests.yml)
[![Python coverage](https://codecov.io/gh/kapelner/EDI/branch/main/graph/badge.svg?flag=python)](https://codecov.io/gh/kapelner/EDI/flags/python)\
![Platforms](https://img.shields.io/badge/platform-linux%20%7C%20macOS%20%7C%20windows-lightgrey)
[![Last commit](https://img.shields.io/github/last-commit/kapelner/EDI)](https://github.com/kapelner/EDI/commits/main)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.22170036.svg)](https://doi.org/10.5281/zenodo.22170036)

**EDI** (Experimental Design and Inference) is software that marries experimental
designs (fixed and sequential) and inference procedures
(exact, asymptotic, and distribution-free) tailored to each design and
response type (continuous, incidence, count, proportion, survival with left/right censoring, and
ordinal). The core estimation and variance-computing kernels are written in C++ (Eigen +
LBFGS++) for speed.

This repo hosts the eponymous R package `EDI` under [`R/EDI`](R/EDI), with R6
classes for designs, inference, and simulation. It also hosts the distinct
Python package [`edi_kernels`](python/README.md), built with `pybind11` and no
R/Rcpp dependency, which provides high-speed bare-metal bindings to the shared
C++ core. See the [Python README](python/README.md) for its installation, usage,
and benchmark results.

## R package v1.0.0

The R package includes the code used to reproduce the simulations in the
papers cited below. To get started from the repository root, run
`R CMD INSTALL R/EDI`, then explore [`R/package_tests`](R/package_tests).

> **Benchmark report:** [`R/benchmark/benchmark_model_fits_R.html`](R/benchmark/benchmark_model_fits_R.html) — speed and correctness of every model-fitting kernel against its R canonical baseline.

### Installation

```r
install.packages("EDI")
```

Or the development version from this repo (requires a C++ compiler toolchain
for R packages, e.g. Rtools on Windows or Xcode command line tools on macOS):

```r
# from the repository root
install.packages("R/EDI", repos = NULL, type = "source")
```

### Local performance builds

`EDI`'s `configure` script resolves its compiler flags at install time based on
a handful of environment variables, so a plain `R CMD INSTALL R/EDI` already
builds the tuned, machine-specific configuration by default:

| Variable | Default | Effect |
| --- | --- | --- |
| `EDI_PORTABLE` | `0` | `1` drops `-march=native -mtune=native` (and the other non-portable flags below) for a fully portable, warning-free build. Set this for CRAN/CI-style checks. |
| `EDI_NATIVE_SPEED` | `1` | Adds `-O3`; `0` leaves `CXXFLAGS` at R's own default optimization level. |
| `EDI_NATIVE_LTO` | `0` | `1` adds `-flto` on top of the native-speed flags. Off by default — GCC/RcppEigen LTO builds have shown severe slowdowns on some of the small model-fit kernels. |
| `EDI_DISABLE_VECTORIZATION` | `0` | `1` adds `-DEIGEN_DONT_VECTORIZE -DEIGEN_UNALIGNED_VECTORIZE=0 -fno-tree-vectorize`, for isolating SIMD's contribution when benchmarking. |
| `EDI_DEBUG_SYMBOLS` | `0` | `1` adds `-g1 -fno-omit-frame-pointer` (profiler-friendly symbols) instead of stripping with `-g0`. |
| `EDI_UNITY` | `1` | Compiles `src/*.cpp` as ~10 merged "unity" translation units instead of one object per file, which amortizes RcppEigen's per-TU header-parsing cost. Set `0` for a targeted/incremental edit-compile loop on a single kernel file. |

When `EDI_PORTABLE=0` (the default), the non-portable build also carries
`-march=native -mtune=native -Wno-ignored-attributes` unconditionally, plus
`-DNDEBUG -DEIGEN_NO_DEBUG` and `-fstack-protector` regardless of
`EDI_PORTABLE`. For a fully portable install (e.g. matching what CRAN builds),
use:

```sh
EDI_PORTABLE=1 R CMD INSTALL R/EDI
```

To compare plain native versus native plus link-time optimization:

```sh
R CMD INSTALL R/EDI
EDI_NATIVE_LTO=1 R CMD INSTALL R/EDI
```

To benchmark the three builds back-to-back, run:

```sh
bash R/scripts/benchmark_build_modes.sh
```

To compare the current working tree, the current tree with vectorization
disabled, and the last committed `HEAD` snapshot across several hot C++ kernels,
run:

```sh
bash R/scripts/benchmark_simd_matrix.sh
```

This uses `EDI_DISABLE_VECTORIZATION=1` to add `-DEIGEN_DONT_VECTORIZE` and
`-fno-tree-vectorize` for the no-vectorization build.

To benchmark a randomization CI workload at `num_cores = 3` across the same
three build modes, run:

```sh
bash R/scripts/benchmark_randomization_ci_build_modes.sh
```

### Local performance tuning

Compiler flags aren't the only per-machine tuning `EDI` does. At runtime,
`tune_EDI_for_this_machine()` benchmarks four independent axes on your own
hardware — cold-start dispatch, warm-start dispatch, optimizer-algorithm
choice, and parallel (fork-cluster) execution — against the package's shipped
defaults, and persists only the deviations that win by a real margin (median
time at least 5% better, and by more than twice the candidate's own
interquartile spread) and pass a correctness gate (both settings are re-fit
on identical synthetic data and their outputs compared; a disagreement
discards the deviation rather than applying it):

```r
tune_EDI_for_this_machine()                   # standard effort; run on an idle machine
tune_EDI_for_this_machine(effort = "quick")   # coarser grid, fewer replicates
tune_EDI_for_this_machine(effort = "thorough") # full grid, more replicates
```

The result is saved to a per-user config file and applied automatically the
next time `library(EDI)` loads. Use `get_local_EDI_optimization()` to inspect
what's saved and `clear_local_EDI_optimization()` to return to the shipped
defaults.

**The parallel axis is the one exception.** Its preferred core count is
*recorded only* — it is never applied automatically, at load time or
otherwise. Instead, `library(EDI)` (and a saved tuning being applied) prints
a message reporting the preferred count and telling you to opt in yourself:

```
EDI: this machine's saved tuning found parallel execution fastest at 4
cores. This is not applied automatically -- call set_num_cores(4) to opt in.
```

You still have to call `set_num_cores(4)` (or whatever count the message
names) yourself for parallel execution to actually take effect — see
"Setting a seed for reproducible output" below for why `num_cores` also
matters for reproducibility.

### Why `EDI` targets the CPU (and not GPUs, TPUs, or quantum hardware)

All of the tuning above targets the CPU. That is deliberate: for the
workloads `EDI` is built for — designed experiments with roughly n < 1,000
subjects and B < 2,000 bootstrap or randomization replicates — accelerators
cannot help:

- **The total work is milliseconds.** An OLS or GLM fit at n = 1,000, p = 10
  is ~10⁵ flops, a few microseconds on one core; B = 2,000 of them is tens of
  milliseconds single-threaded. A GPU's fixed costs — kernel launch latency,
  host↔device transfer, first-use context setup — match or exceed the entire
  job.
- **The kernels are small, double-precision, iterative, and branchy.** IRLS,
  Newton with line search, bisection CIs, Laplace-approximated mixed models,
  Cox partial likelihoods, greedy and annealing design searches are sequential
  dependency chains with data-dependent branching — the wrong shape for GPUs
  and TPUs (throughput engines for large uniform tensor work; TPUs are
  bf16/int8 matmul units). The design matrix fits in L2 cache, so memory
  bandwidth, the one thing accelerators have in abundance, is irrelevant.
- **The batch is too small to amortize anything.** Batched GPU linear algebra
  needs thousands of simultaneous matrices to saturate the device; B < 2,000
  tiny fits would leave it mostly idle.
- **Quantum hardware maps onto parts of `EDI`, but the gain is limited.** The
  model fits are not quantum targets — data loading, readout, and
  dequantization erase every claimed linear-algebra speedup at `EDI`'s `n`
  and `p`. Two things do map cleanly: the design layer's binary-allocation
  searches (`DesignFixedOptimal` and its block variant are
  cardinality-constrained QUBOs, runnable on today's annealers and Ising
  machines) and the inference layer's Monte Carlo replicate loops (the
  amplitude-estimation setting, quadratic speedup in `1/ε`). The first is at
  best competitive with the package's own MILP and C++ annealing solvers, and
  any practical win at `n` in the hundreds more likely comes from a
  quantum-*inspired* classical solver; the second needs fault-tolerant
  hardware that does not exist. See
  [`quantum_upgrade.md`](R/package_metadata/new_feature_plans/quantum_upgrade.md)
  for the mapping, qubit-count estimates, and the planned optional
  QUBO-export hook.

**Where a GPU could still help.** The GPU-shaped computations are the
embarrassingly parallel outer loops: one small kernel over many independent
permutations or resamples (`ols_distr_parallel.cpp`,
`fast_wilcox_parallel.cpp`, `ridit_distr_parallel.cpp`,
`kk_compound_distr_parallel.cpp`, the bootstrap loops), the pairwise-distance
and design-search kernels behind `DesignFixedOptimal`, matching, and
rerandomization, and `SimulationFramework`'s replicate loop. For simple
statistics — mean differences, fixed-design OLS, rank sums — at B well beyond
2,000, or simulation studies running thousands of full inferences, a batched
GPU implementation could beat a multi-core CPU. Inside the n < 1,000,
B < 2,000 regime, launch and transfer overhead still dominates, so this is a
future direction, not a limitation of the current design. See
[`gpu_optimizations.md`](R/package_metadata/new_feature_plans/gpu_optimizations.md)
for the ranked candidates and the backend/dispatch design an optional GPU
path would need.

In this regime the costs that matter are CPU-side, and the package tunes for
them on the user's own hardware. Thread fork/join overhead versus
per-replicate work is measured directly: the parallel axis of
`tune_EDI_for_this_machine()` benchmarks bootstrap and randomization-CI
workloads across a core-count grid and finds the crossover where multi-core
beats serial on that machine, which is why parallel execution is opt-in via
`set_num_cores()` rather than always-on. The cold-start, warm-start, and
optimizer axes handle the other latency-dominated pieces the same way. The
remainder — R↔C++ dispatch overhead per call and algebraic reuse inside a
replicate loop (e.g. factoring a fixed design once) — is addressed in the
C++/Eigen kernels themselves, on top of OpenMP parallelism and the
hardware-specific compiler flags above. One library choice is left to the
user: the `XᵀX` cross-product at the heart of every IRLS/Newton iteration is
routed through whichever BLAS R is linked against (via `DSYRK`), so an
optimized BLAS (OpenBLAS, MKL, Accelerate) speeds that kernel over reference
BLAS. It is not required — at designed-experiment sizes the call is
microseconds either way — but it is free speed if your R already has one. At
designed-experiment scale, the CPU is the right hardware target, and driving
it to its ceiling is the route to speed.

### Getting Started

#### Historical experimental data example

You often already have data from a completed experiment — covariates, the
treatment that was actually assigned, and the observed outcome — rather than
a fresh design you're about to randomize. Load it into a matching `Design`
subclass by passing the recorded assignment vector to
`assign_w_to_all_subjects(w_precomputed = ...)`, then run the inference
procedure appropriate to how the data were collected. Here, a stratified-block
design with a survival (time-to-event) outcome:

```r
library(EDI)

n = 40
X = data.frame(
    age = rnorm(n, 60, 8),
    sex = factor(sample(c("M", "F"), n, replace = TRUE))
)
w = rbinom(n, 1, 0.5)                # the treatment actually assigned, historically
event_time = rexp(n, 0.1)            # observed time (event or censoring)
event_occurred = rbinom(n, 1, 0.8)   # 1 = death/event observed, 0 = right-censored

des = DesignFixedBlocking$new(n = n, response_type = "survival", strata_cols = "sex")
des$add_all_subjects_to_experiment(X)
des$assign_w_to_all_subjects(w_precomputed = w)
des$add_all_subject_responses(
    ys   = ifelse(event_occurred == 1, event_time, NA),
    y_Ls = ifelse(event_occurred == 0, event_time, NA),
    y_Rs = ifelse(event_occurred == 0, Inf, NA)
)

inf = InferenceSurvivalWeibullRegr$new(des)
inf$compute_estimate()
inf$compute_asymp_two_sided_pval()

# Likelihood-score p-value and confidence interval (asymptotic, no resampling)
inf$compute_score_two_sided_pval()
inf$compute_score_confidence_interval()

# Nonparametric bootstrap p-value and confidence interval
inf$set_seed(42)
inf$compute_bootstrap_two_sided_pval()
inf$compute_bootstrap_confidence_interval()

# Randomization (design-based) test and its inverted confidence interval
inf$compute_rand_two_sided_pval()
inf$compute_rand_confidence_interval()

# Parametric bootstrap likelihood-ratio p-value and confidence interval
inf$compute_lik_ratio_bootstrap_two_sided_pval()
inf$compute_lik_ratio_bootstrap_confidence_interval()
```

#### Sequential experimental data example

Sequential (matching-on-the-fly) designs assign treatment one subject at a
time as covariates arrive, then take the full response vector once every
subject has been enrolled. Here, Pocock and Simon (1975) minimization
balancing on `sex`, with a binary (incidence) outcome analyzed via probit
regression:

```r
library(EDI)

n = 60
des = DesignSeqOneByOnePocockSimon$new(n = n, response_type = "incidence", strata_cols = "sex")
for (i in seq_len(n)) {
    x_i = data.frame(sex = factor(sample(c("M", "F"), 1), levels = c("M", "F")))
    des$add_one_subject_to_experiment_and_assign(x_i)
}
des$add_all_subject_responses(rbinom(n, 1, 0.5))

inf = InferenceIncidProbitRegr$new(des)
inf$compute_estimate()
inf$compute_asymp_two_sided_pval()
```

#### Inference Suite example

Rather than picking a single inference procedure by hand, `InferenceSuite`
discovers and runs every procedure applicable to a design/response-type
combination at once, and summarizes their combined evidence as a single
Cauchy-combined p-value. Ordinal responses have the richest set of
applicable procedures (proportional odds, continuation ratio, adjacent
category, stereotype logit, and more), so they make a good showcase:

```r
library(EDI)

n = 80
X = data.frame(x1 = rnorm(n))
des = DesignFixedBernoulli$new(n = n, response_type = "ordinal")
des$add_all_subjects_to_experiment(X)
des$assign_w_to_all_subjects()
des$add_all_subject_responses(factor(sample(1:4, n, replace = TRUE), ordered = TRUE))

suite = InferenceSuite$new(des)
res = suite$run_all_inference(compute_conf_intervals = TRUE)

res$results_table             # one row per (class, method, type) combination fit
res$combined_evidence$pval    # the Cauchy-combined p-value across all usable rows
res$combined_evidence$n_classes_used

print(res)
.....
Combined evidence against the sharp null across 18 estimands
(155 inferences, weighting = uniform within estimand):
p = 0.000261

Per-estimand breakdown
Estimand: cauchit link effect (11 inferences):     p = 0.000314
Estimand: cauchit link effect cond (6 inferences): p = 0.001100
Estimand: cloglog link effect (10 inferences):     p = 0.000198
Estimand: cloglog link effect cond (6 inferences): p = 0.000286
Estimand: HL shift (4 inferences):                 p = 0.000388
Estimand: logodds adj cat (10 inferences):         p = 0.000198
Estimand: logodds adj cat cond (5 inferences):     p = 0.215000
Estimand: logodds cont ratio (11 inferences):      p = 0.000217
Estimand: logodds partial prop (6 inferences):     p = 0.000286
Estimand: logodds prop (15 inferences):            p = 0.000211
Estimand: logodds prop cond (16 inferences):       p = 0.000223
Estimand: mann whitney effect (6 inferences):      p = 0.000286
Estimand: mean Δ (18 inferences):                  p = 0.000286
Estimand: probit ordinal (11 inferences):          p = 0.000217
Estimand: probit ordinal cond (6 inferences):      p = 0.000286
Estimand: sign test effect (4 inferences):         p = 0.000195
Estimand: stereotype link effect (4 inferences):   p = 0.000133
Estimand: stoch ordering trend (6 inferences):     p = 0.000286
```

```r
# One CI-forest plot per estimand, keyed by estimand name
res$plots$ci_forest[["logodds cont ratio"]]
```

Each plot stacks every applicable procedure's confidence interval for that
estimand over an "Estimates" box-and-whisker subplot (if there are multiple
different estimate values), with the estimand's own Cauchy-combined p-value as the title:

![InferenceSuite CI-forest plot for the "logodds cont ratio" estimand, showing confidence intervals from multiple inference procedures (bootstrap, Bayes bootstrap, parametric bootstrap, gradient, likelihood ratio, score, jackknife, Wald) stacked above a combined estimates plot, titled "95% CIs (combined p = 0.000178)"](R/package_metadata/figures/inference_suite_logodds_cont_ratio_ci.png)

See `?InferenceSuite` for the Combined Evidence Metric's interpretation and
caveats — it is a joint test that *some* procedure detected a signal, not an
estimate of any single effect size.

### Design bakeoffs via SimulationFramework

`SimulationFramework` can also run several *designs* head-to-head under an
identical data-generating process, rather than comparing inference
procedures on one fixed design. Pass more than one design class in
`design_classes_and_params` and `$summarize()` reports `power`/`MSE`/
`coverage` broken out by design. Designs with required constructor arguments
(e.g. `DesignSeqOneByOnePocockSimon`'s `strata_cols`) get a sensible default
auto-injected if you don't supply one — here, comparing Pocock and Simon
(1975) minimization against the stepwise-weighted KK21 matching-on-the-fly
design, both analyzed with beta regression on a proportion outcome:

```r
library(EDI)

sim = SimulationFramework$new(
    response_type = "proportion",
    design_classes_and_params = list(
        DesignSeqOneByOnePocockSimon,
        DesignSeqOneByOneKK21stepwise
    ),
    inference_classes_and_params = list(InferencePropBetaRegr),
    inference_types_and_params = list(asymp_pval = list(delta = 0)),
    n = 60L, p = 4L, betaT = 0.15, Nrep_W = 40L,
    results_filename = tempfile(fileext = ".csv"),
    continue_from_last_result_row = FALSE,
    verbose = FALSE
)
sim$run()

report = SimulationFrameworkReport$new(sim)
report$summarize()[, .(design, power, MSE)]
```

```
                          design power         MSE
                          <char> <num>       <num>
1: DesignSeqOneByOneKK21stepwise 0.775 0.002522346
2:  DesignSeqOneByOnePocockSimon 0.650 0.004210140
```

Here KK21's outcome-weighted matching wins on both counts: higher power and
lower MSE than Pocock-Simon's covariate-only minimization, since KK21 also
uses the *response* to weight covariates it matches on.

(A `Nrep_W` of 40 keeps this quick to run; use a larger value, e.g. 1000+,
for a bakeoff you'd actually draw conclusions from.)

Re-running the same comparison at `betaT = 0` (no true treatment effect)
checks each design/inference combination's Type I error calibration instead
of its power — the `size` column should sit near `alpha` (0.05 here), with
`size_pval` the exact binomial test of `H0: true size = alpha`:

```r
sim0 = SimulationFramework$new(
    response_type = "proportion",
    design_classes_and_params = list(
        DesignSeqOneByOnePocockSimon,
        DesignSeqOneByOneKK21stepwise
    ),
    inference_classes_and_params = list(InferencePropBetaRegr),
    inference_types_and_params = list(asymp_pval = list(delta = 0)),
    n = 60L, p = 4L, betaT = 0, Nrep_W = 40L,
    results_filename = tempfile(fileext = ".csv"),
    continue_from_last_result_row = FALSE,
    verbose = FALSE
)
sim0$run()

report0 = SimulationFrameworkReport$new(sim0)
report0$summarize()[, .(design, size, size_pval)]
```

```
                          design  size size_pval
                          <char> <num>     <num>
1: DesignSeqOneByOneKK21stepwise  0.05         1
2:  DesignSeqOneByOnePocockSimon  0.05         1
```

Both designs land exactly at the nominal 5% level here, with `size_pval = 1`
(no evidence against correct calibration) — as expected, since only the
*power* comparison above depends on the true `betaT`, not the null.

### Setting a seed for reproducible output

Every layer accepts a `seed` for deterministic output, and reproducibility
only holds when `num_cores` (see `set_num_cores()`) is also the same across
runs — some designs' draws are only seed-reproducible single-threaded.

```r
# Design: pass seed to $new()
des = DesignFixedBernoulli$new(n = 100, response_type = "continuous", seed = 42)
des$add_all_subjects_to_experiment(X)
identical(des$draw_ws_according_to_design(r = 500), des$draw_ws_according_to_design(r = 500))  # TRUE

# Inference: call $set_seed() after construction
inf = InferenceAllSimpleAverageDiff$new(des)
inf$set_seed(42)
inf$compute_rand_two_sided_pval(r = 999, show_progress = FALSE)
inf$compute_bootstrap_confidence_interval(B = 999, show_progress = FALSE)

# SimulationFramework: pass seed to $new()
sim = SimulationFramework$new(
    response_type = "continuous",
    design_classes_and_params = list(DesignFixedBernoulli),
    inference_classes_and_params = list(InferenceAllSimpleAverageDiff),
    inference_types_and_params = list(asymp_pval = list(delta = 0)),
    n = 50L, Nrep_W = 200L, seed = 321
)
sim$run()
```

A design's `$duplicate()` clears the copy's seed — used internally to hand
each parallel resampling worker its own RNG stream instead of replaying the
parent's.

### Vignettes

See the following for more information:

```r
vignette("reproducibility", package = "EDI")      # RNG/seed conventions across designs, bootstrap, and simulation
vignette("extending-edi", package = "EDI")        # writing your own Design/Inference R6 subclasses
vignette("backend-contracts", package = "EDI")    # how the C++ core is shared between the R (Rcpp) and Python (pybind11) bindings
vignette("notation-glossary", package = "EDI")    # symbols/naming conventions shared across Design*/Inference* classes and docs
vignette("validation-evidence", package = "EDI")  # index into the test suite showing each model family computes what it claims
```

## Contributing

Issues and pull requests are welcome at
[github.com/kapelner/EDI](https://github.com/kapelner/EDI). See
[`CLAUDE.md`](CLAUDE.md) for repo-specific conventions (e.g. never running a
full package rebuild without being asked).

Adding a new `Inference*` model (a new estimation/testing procedure for an
existing design/response-type combination) touches capability metadata,
argument checking, documentation, unit and integration tests, C++ core
hygiene, the R/Python core split, and registration in the comprehensive test
harness — it's more than just getting the point estimate right. Follow
[`R/package_metadata/contracts/new_model_creation.md`](R/package_metadata/contracts/new_model_creation.md)
end to end before opening a PR for one.

## License

GPL-3 — see [`LICENSE`](LICENSE).

## Citation

If you use this software, please cite it — see [`CITATION.cff`](CITATION.cff)
or, from R, run `citation("EDI")`. A DOI for this release is available via
Zenodo: [10.5281/zenodo.22170036](https://doi.org/10.5281/zenodo.22170036).

## Lines of Code

<!-- cloc-table-start -->
Language|files|blank|comment|code
:-------|-------:|-------:|-------:|-------:
R|629|8163|38216|119876
C++|126|4437|6436|35287
Python|55|1416|3360|4502
C/C++ Header|20|423|789|2945
**SUM:**|**830**|**14439**|**48801**|**162610**
<!-- cloc-table-end -->

This table is generated by `cloc --vcs=git --include-lang="R,Python,C,C++,C/C++ Header" --exclude-ext="Rd,rd" .`
(`--vcs=git` counts only git-tracked files, so local artifacts such as
`python/.venv` don't skew the numbers). It is regenerated automatically on
every `git push` by the pre-push hook (`.githooks/pre-push`, which calls
[`scripts/update_readme_cloc.sh`](scripts/update_readme_cloc.sh)).
