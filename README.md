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

## R package

The R package includes the code used to reproduce the simulations in the
papers cited below. To get started from the repository root, run
`R CMD INSTALL R/EDI`, then explore [`R/package_tests`](R/package_tests).

> **Benchmark report:** [`R/benchmark/benchmark_model_fits_R.html`](R/benchmark/benchmark_model_fits_R.html) — speed and correctness of every model-fitting kernel against its R canonical baseline.

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
tune_EDI_for_this_machine()                 # standard effort; run on an idle machine
tune_EDI_for_this_machine(effort = "quick") # coarser grid, fewer replicates
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

### Setting a seed for reproducible output

All three layers of the package accept a seed for deterministic output.

**Design classes** — pass `seed` to `$new()`:

```r
# Fixed design: same seed → same draw_ws_according_to_design() every call
des = DesignFixedBernoulli$new(n = 100, response_type = "continuous", seed = 42)
des$add_all_subjects_to_experiment(X)
w1 = des$draw_ws_according_to_design(r = 500)
w2 = des$draw_ws_according_to_design(r = 500)
identical(w1, w2)  # TRUE

# Sequential design: same seed → same assignment sequence
des = DesignSeqOneByOneBernoulli$new(n = 100, response_type = "continuous", seed = 42)
for (i in seq_len(100)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
```

**Inference classes** — call `$set_seed()` after construction:

```r
inf = InferenceAllSimpleAverageDiff$new(des)
inf$set_seed(42)

# Same seed + same num_cores → identical p-value / CI / Bayesian-bootstrap distribution
p  = inf$compute_rand_two_sided_pval(r = 999, show_progress = FALSE)
ci = inf$compute_bootstrap_confidence_interval(B = 999, show_progress = FALSE)
```

Reproducibility is guaranteed only when `num_cores` is the same across runs
(cross-core determinism is out of scope). Set the number of parallel workers
before running:

```r
set_num_cores(4)   # or unset_num_cores() for serial
```

**SimulationFramework** — pass `seed` to `$new()`:

```r
sim = SimulationFramework$new(
    response_type = "continuous",
    design_classes_and_params = list(DesignFixedBernoulli),
    inference_classes_and_params = list(InferenceAllSimpleAverageDiff),
    inference_types_and_params = list(asymp_pval = list()),
    n = 50L, Nrep = 200L, seed = 321, ...
)
sim$run()
```

**Note on `duplicate()`:** Objects produced by `$duplicate()` have their seed
cleared intentionally. This prevents parallel inference workers from resetting
to the same RNG stream and producing duplicate treatment allocations.

### Experimental findings

The `R/scripts/benchmark_randomization_ci_ordinal_ppo.R` and
`R/scripts/benchmark_randomization_ci_cases.R` experiments show the native-speed
flags are beneficial for the heavier Eigen/OpenMP workloads but not universally
faster:

- **Ordinal PPO (`InferenceOrdinalMultiPartialProportionalOddsRegr`)** with `r=201` and `reps=3`: portable `≈19.2s`, native `≈16.6s`, native+LTO `≈16.7s`.
- **KK mean-difference IVWC (`InferenceAllKKMeanDiffIVWC`)**: portable ≈13.4s, native ≈13.1s, native+LTO ≈13.8s.
- **Proportion fractional logit and simple Poisson (`InferencePropMultiFractionalLogit`, `InferenceCountUnivPoissonRegr`)**: portable was slightly faster than both native and native+LTO on those lightweight cases.

Bottom line: use `EDI_NATIVE_SPEED`/`EDI_NATIVE_LTO` to benchmark and tune the
expensive ordinal/KK regressions locally, but keep the default portable flags
for general development and distribution.

### Bootstrap diagnostics for modified Poisson incidence inference

Trimmed versions of the `cars`/`FixedCluster` workload (for example,
`R/scripts/diagnose_modified_poisson_bootstrap.R`) used to hit
`Bootstrap confidence interval returned NA bounds` because the reduced design
matrix had as many covariates as rows. The inference object now falls back to
the univariate modified Poisson fit whenever the multivariate design is
underdetermined, so the diagnostics report 25/25 finite replicates and
`prop_illegal_values = 0.000` while retaining the same treatment estimate.

### Parametric bootstrap LR workflow

For likelihood-backed classes that support parametric-bootstrap likelihood-ratio
calibration, the intended user-facing entry points are:

- `compute_lik_ratio_bootstrap_two_sided_pval(delta = 0, B = 199, show_progress = FALSE)`
- `compute_lik_ratio_bootstrap_confidence_interval(alpha = 0.05, B = 199, show_progress = FALSE)`

These methods are available only for inference classes whose internal
`supports_lik_ratio_param_bootstrap()` capability is enabled. Unsupported
classes error rather than silently falling back to another procedure.

A typical flow is:

```r
library(EDI)

des = DesignFixedBernoulli$new(n = 80, response_type = "count", verbose = FALSE)
des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(80)))
des$overwrite_all_subject_assignments(rep(c(1, 0), length.out = 80))
des$add_all_subject_responses(rpois(80, lambda = exp(0.2 + 0.3 * des$get_w() + 0.2 * des$get_X()[, 1])))

inf = InferenceCountPoisson$new(des, model_formula = ~ x1, verbose = FALSE)
inf$set_seed(1)

p_boot = inf$compute_lik_ratio_bootstrap_two_sided_pval(
  delta = 0,
  B = 199,
  show_progress = FALSE
)

ci_boot = inf$compute_lik_ratio_bootstrap_confidence_interval(
  alpha = 0.05,
  B = 199,
  show_progress = FALSE
)
```

`delta = 0`, `B = 199`, and `show_progress = FALSE` are the standard defaults.
These routines are materially more expensive than the asymptotic LR methods
because they repeatedly simulate and refit null datasets.

## Citation

If you use this software, please cite it — see [`CITATION.cff`](CITATION.cff)
or, from R, run `citation("EDI")`.

## Lines of Code

<!-- cloc-table-start -->
Language|files|blank|comment|code
:-------|-------:|-------:|-------:|-------:
R|625|8121|38125|119540
C++|126|4437|6436|35287
Python|55|1416|3360|4502
C/C++ Header|20|423|789|2945
--------|--------|--------|--------|--------
SUM:|826|14397|48710|162274
<!-- cloc-table-end -->

This table is generated by `cloc --vcs=git --include-lang="R,Python,C,C++,C/C++ Header" --exclude-ext="Rd,rd" .`
(`--vcs=git` counts only git-tracked files, so local artifacts such as
`python/.venv` don't skew the numbers). It is regenerated automatically on
every `git push` by the pre-push hook (`.githooks/pre-push`, which calls
[`scripts/update_readme_cloc.sh`](scripts/update_readme_cloc.sh)).
