# Migrate EDI into a Shared C++ Inference Backend

Date: 2026-08-27

Status: architecture, feasibility, and phased implementation report. Effort
estimates are planning ranges, not delivery commitments.

> **Related plans:** `more_language_bindings.md` defines the language demand
> and packaging strategy. This report defines the deeper migration required
> to make statistical inference—not only model-fitting kernels—available from
> the shared backend. It depends on the completed standalone-core work in
> `../finished_features/sexp_removal_rcppeigen_conversion_spec.md` and the
> existing Python package described by
> `../finished_features/python_bindings_package_spec.md`. Global ordering is in
> `_master.md`.

## Executive recommendation

EDI should converge on one implementation of model fitting and statistical
inference:

```text
R/EDI/src C++ kernels and inference engine
                  |
                  v
        versioned libedi_core C ABI
          /       |       |       \
         R      Python   JVM     other bindings
```

The C ABI is a stable, language-neutral calling contract exported by a shared
native library. It is not the public ergonomic API of any one language. R,
Python, Java, C#, JavaScript, Julia, MATLAB, Stata, Rust, Go, and other clients
should each retain a thin layer for their own arrays, exceptions, objects,
documentation, and package conventions.

This is feasible, but exposing the current fitting functions is only the
beginning. Most of EDI's bootstrap, randomization, score, and likelihood-ratio
inference is orchestrated in R. It constructs model-specific closures, clones
objects, generates design-aware draws, manages seeds and workers, refits
models, caches results, and translates numerical failures. Those workflows
cannot be made portable by adding `extern "C"` to the current helper
functions.

The recommended boundary is incremental:

1. make all inference algebra and model evaluation R-free C++;
2. expose score and likelihood-ratio tests and confidence intervals through
   an opaque analysis handle;
3. expose a **draws-in, inference-out** batch API in which callers provide
   bootstrap indices, Bayesian weights, or randomized assignments;
4. move only broadly reusable draw generation and execution policy into C++;
5. treat adaptive designs, arbitrary user statistics, and complete R6
   workflow parity as a later and separately justified scope.

This yields a useful cross-language inference library without first porting
the entire R object model. A practical first release is approximately **20–35
engineer-weeks** after the basic C ABI exists. Broad parity with the current R
inference system is approximately **50–90 engineer-weeks**, with substantial
uncertainty from model-family coverage and advanced resampling variants.

## Goals

- One mathematical implementation for R, Python, and future language
  bindings.
- Stable C ABI contracts for fitting, tests, intervals, and resampling.
- Preserve the existing public R and `edi_kernels` Python APIs during
  migration.
- Allow zero-copy input for compatible dense arrays.
- Preserve design-aware inference by making design inputs explicit rather
  than silently approximating them.
- Give every replicate a machine-readable outcome and retain aggregate
  failure diagnostics.
- Generate declarations, defaults, result schemas, and conformance fixtures
  from one manifest.
- Make the native library independently testable, versionable, and
  distributable.

## Non-goals for the first release

- Reimplementing all R6 design, response, and inference classes in every
  language.
- Calling R from `libedi_core`.
- Allowing foreign-language callbacks to execute inside OpenMP workers.
- Guaranteeing arbitrary user-defined statistics across the C ABI.
- Reproducing bit-identical random streams across all host languages.
- Browser JavaScript support; that is a separate WebAssembly project.
- Declaring a model to support bootstrap merely because its fit kernel exists.

## Why a C ABI

C++ does not provide one stable binary interface across compilers, standard
libraries, build modes, or exception runtimes. Exported C++ names, STL
containers, Eigen objects, templates, and exceptions are therefore poor
contracts for packages built by unrelated language toolchains.

A C ABI is a deliberately small interface using `extern "C"` symbols,
fixed-width primitive types, plain structs with versioned layouts, raw buffer
views, opaque handles, and integer status codes. The implementation can remain
modern C++; only the binary boundary is C-compatible.

The ABI must never expose:

- `std::vector`, `std::string`, templates, or Eigen types;
- C++ exceptions or compiler-specific enum layouts;
- R `SEXP`, Rcpp objects, or Python objects;
- the internal layout of `edi::ResultMap`; or
- ownership rules that depend on a host language's garbage collector.

The ABI should expose:

- a version and capability query;
- explicit array element type, dimensions, strides, and mutability;
- opaque model/analysis/result handles where caller-owned buffers are not
  sufficient;
- `edi_status` on every fallible operation;
- thread-local error detail retrievable immediately after failure;
- an EDI allocator/deallocator pair for EDI-owned memory; and
- explicit cancellation, seed, resource, and diagnostic policies.

## Why not expose all of EDI through language-to-R bridges?

### Short answer

We can, and for some deployments we should. An R bridge is the fastest route
to the complete current R feature set. It is a useful integration mode for
internal applications, research environments that already standardize on R,
rare workflows not yet migrated to C++, and validation of native results.

It is not a substitute for the C ABI when the intended product is an
idiomatic, independently installable package for another language. A bridge
makes R, the EDI R package, its compiled dependencies, its process/runtime
rules, and usually an object-conversion or service layer part of every
installation. The consumer is remotely controlling or embedding R; it is not
consuming a native EDI library.

The decision is therefore not “bridge or C ABI” for every use case:

| Intended use | Recommended integration |
|---|---|
| Prototype or internal analysis where R is already installed | Language-to-R bridge |
| Immediate access to the complete R6 workflow/design surface | R bridge, explicitly marketed as R-backed |
| Central statistical service used by several applications | Managed Rserve/service deployment can be appropriate |
| Native package installed through PyPI, Maven, NuGet, npm, Julia, or similar | C ABI plus idiomatic binding |
| Low-latency repeated fitting/resampling in a concurrent host | C ABI batch interface |
| Arbitrary R user extensions or custom R statistics | R-backed mode unless/until a plug-in contract exists |
| Parity testing during migration | Run both; R is the reference oracle |

### The examples do not all bridge in the required direction

The names are easy to conflate:

- `reticulate` embeds Python in an R session and is documented as an **R
  interface to Python**. It helps R code call Python; it does not by itself
  make an R package importable from Python. Python-to-R embedding is normally
  provided by a tool such as `rpy2`. See the
  [reticulate interface documentation](https://rstudio.github.io/reticulate/index.html)
  and [rpy2 documentation](https://rpy2.github.io/doc/latest/html/index.html).
- `rJava` is primarily the low-level interface for invoking a JVM from R. For
  Java-to-R, the related choices are JRI/REngine for in-process embedding or
  the REngine Rserve client for a separate R process. The Rserve project
  explicitly distinguishes JRI's linked, in-process model from Rserve's
  client/server model in its
  [official overview](https://www.rforge.net/Rserve/).
- `Rserve-Ruby-client`, `pyRserve`, Java REngine, JavaScript, PHP, C#, and
  other clients speak the Rserve protocol. They do provide language-to-R
  access, but require a running Rserve installation and are clients of an R
  service, not EDI-native bindings. Rserve's official page lists these clients
  and describes its TCP/IP or local-socket execution model.

These direction and deployment differences matter. There is no single bridge
package that can be wrapped once to yield equally maintained, idiomatic
packages in every target ecosystem.

### 1. Installation becomes a two-runtime deployment

A native EDI binding needs the language package and `libedi_core` plus its
declared native dependencies. An embedded-R binding additionally needs a
compatible R installation, the EDI R package, all of its R dependencies, the
bridge package/native extension, correctly configured library paths, and a
compatible shared R library. An Rserve client moves those dependencies to a
service host but adds server installation, process supervision,
authentication, TLS/network configuration, health checks, and capacity
management.

That may be entirely reasonable inside a controlled institution. It is a poor
default expectation for someone running `pip install`, adding a Maven/NuGet
dependency, deploying a Go/Rust executable, using a serverless platform, or
working in a locked-down enterprise environment. It also prevents the planned
Python benefit of wheels that do not require R or Python development headers.

### 2. It multiplies the compatibility matrix instead of narrowing it

Every bridge release must be tested across:

```text
host language/runtime version
    x bridge/client version
    x R version and platform build
    x EDI R package version
    x R dependency and compiled-library versions
    x BLAS/OpenMP/process configuration
```

Rserve reduces in-process linker conflicts, but the server and client protocol
versions still need coordinated testing. Embedding reduces network operations,
but creates a process containing two managed runtimes and their native
libraries. A C ABI does not eliminate platform testing; it makes one narrow,
versioned native contract the point that every binding tests.

### 3. Embedded R has different concurrency and lifecycle rules

R is a stateful runtime, not a reentrant numerical library that can be invoked
freely from arbitrary host threads. The `rpy2` low-level documentation warns
that unsynchronized multithreaded access to embedded R can crash and documents
a lock around critical R API access; initialization is process-global in
practice. See its
[multithreading discussion](https://rpy2.github.io/doc/v3.4.x/html/rinterface.html#multithreading).

That conflicts with the way Java/.NET/Node/Python servers commonly schedule
concurrent requests. A wrapper must serialize access, create separate worker
processes, or implement a pool of Rserve connections. Rserve states that
connections have separate workspaces and that concurrent threads must not
perform `eval` calls on the same connection without synchronization. These are
valid server semantics, but they are not the same as thread-safe independent
native analysis handles.

EDI's own bootstrap and randomization code also manages parallel workers.
Nesting host concurrency, Rserve processes, R parallelism, BLAS threads, and
OpenMP can cause oversubscription or process explosion. The shared backend can
instead own one documented inner-loop concurrency policy and expose batch
operations.

### 4. Data conversion and transport sit on the hottest path

An embedded bridge represents values in both the host and R memory/object
models. Conversion may copy matrices, rebuild data frames and factors, protect
R objects from garbage collection, and translate missing values, names,
classes, and index conventions. Some bridges can share selected array memory,
but complete R6 inference objects and resampling state are not portable array
views.

Rserve uses an efficient binary protocol, which is preferable to textual R
output, but large matrices and replicate-level results still cross a socket
and are serialized/deserialized. The official Rserve documentation describes
binary object transport and per-connection workspaces. Network/process
overhead may be negligible for a one-off long fit, but repeated CI inversion
and high-replicate resampling are precisely where a batch C ABI can keep data,
warm starts, and fit state inside one native analysis handle.

### 5. An R object interface is not a stable cross-language API

The easiest bridge wrapper sends R expressions and receives R lists or R6
objects. That exposes EDI's R function names, argument matching, formulas,
S3/R6 classes, warning text, global options, environments, and mutable object
state as an accidental foreign API. Each target language must still handwrite
conversions and decide how to present these constructs. A change that is
idiomatic and compatible within R may be a breaking change for a Java, C#,
Ruby, or JavaScript wrapper.

Using only typed wrapper functions on the R side improves this considerably,
but those wrappers then become a second language-neutral contract. EDI would
still need schemas, versions, result types, error categories, fixtures, and
client generation—the same contract work proposed for the C ABI—while
retaining the full R runtime requirement.

### 6. Error, cancellation, and resource behavior are harder to normalize

Foreign consumers expect typed exceptions/statuses, cancellation, deadlines,
memory limits, deterministic cleanup, and structured diagnostics. R conditions
include errors, warnings, messages, interrupts, and arbitrary user handlers.
An R session can also retain objects and options between calls. A bridge must
map all of this and decide whether a cancelled call leaves its session usable.

Rserve can isolate sessions and can run in object-capability (OCAP) mode, but a
production service still needs a deliberately restricted callable surface.
Allowing clients to evaluate arbitrary R expressions increases security and
operational risk. The [Rserve overview](https://www.rforge.net/Rserve/)
documents authentication, TLS, OCAP, connection-local workspaces, and its
threading constraints; using those features correctly is service engineering,
not free packaging.

### 7. It does not meet all target deployment environments

Some environments prohibit a child process or listening socket. Others do not
permit installing an R runtime dynamically, do not ship a compatible R build,
or require a single audited native dependency. Browser deployment would need
webR/WebAssembly and separately ported package dependencies; the
[webR documentation](https://docs.r-wasm.org/) describes a distinct
WebAssembly R runtime and notes platform resource constraints. Mobile,
embedded, serverless, and command-line distribution each add similar hurdles.

A small C-compatible library is not universally effortless, but it maps to
the native extension mechanisms already supported by the proposed language
ecosystems and can be packaged without an interpreter-level R dependency.

### 8. It preserves immediate functionality, not the desired source of truth

Using R as the permanent backend keeps the present split: fitting kernels are
portable C++, while inference policy remains implemented through R closures,
R6 state, and R worker orchestration. Python can either keep its separate
native fit surface or acquire a mandatory R dependency. Other bindings expose
R behavior indirectly and cannot independently test the mathematical library.

The C++ migration costs more initially because it moves the source of truth.
Its payoff is that R itself, Python, and every later language call the same
restricted fit, score/LR inversion, and batch resampling implementation. That
is the maintenance reduction this plan is intended to achieve.

### Where an R bridge remains the better choice

EDI should not reject bridges categorically. Provide or document an explicitly
R-backed option when one of these is true:

- a user needs complete Level W workflows before native migration reaches
  them;
- the deployment already operates a governed R/Rserve environment;
- an analysis depends on arbitrary R functions, formulas, extensions, or
  custom statistics that cannot cross the native ABI;
- request latency is dominated by a large fit and data movement is modest;
- independent R processes are desired for isolation; or
- the bridge is being used as the parity oracle for conformance testing.

An Rserve-based EDI service is preferable to separately embedding R in nine
language runtimes when complete R functionality is the requirement. It can
publish a narrow, versioned EDI service protocol rather than permit arbitrary
`eval`, pool isolated sessions, pin the full R environment, and centralize
operations. This is a deployable **service product**, not a native language
binding, and should be named and documented accordingly.

### Recommended hybrid policy

1. Continue the C ABI migration for Level K fitting and inference.
2. Use the R implementation as the statistical reference until R itself moves
   onto the shared engine.
3. Optionally specify one narrow EDI-over-Rserve service for users needing
   immediate Level W parity; do not create a different ad hoc bridge API per
   language.
4. Mark every language feature as `native`, `R-backed`, or `unavailable`.
5. Never silently fall back from native execution to an R service. The
   installation, performance, reproducibility, data-governance, and failure
   semantics differ materially and require explicit user choice.
6. Retire R-backed implementations feature by feature only when shared-core
   parity, diagnostics, and performance gates pass. Retain the service for
   genuinely R-extensible workflows if demand justifies it.

This policy obtains early full-function access without making an R runtime a
permanent hidden dependency of every EDI binding.

## Current state and migration gap

### Existing portable foundation

The Python build already demonstrates that the fit kernels can be compiled
without R. `python/CMakeLists.txt:8-15,171-223` builds sources from `R/EDI/src`
under `EDI_CORE_ONLY`. The current standalone path resolves the C++20, Eigen,
LBFGSpp, BLAS, and OpenMP dependencies. This is a strong base for
`libedi_core`; the proposal does not introduce a second mathematical source
tree.

The current portable surface is nevertheless primarily a collection of fit
kernels. The inference workflows remain above it.

### Score and likelihood-ratio tests

`R/EDI/R/inference_ext_likelihood_test_memoization.R:55-126` builds a
model-specific likelihood-test specification in R. That specification carries
the tested coefficient, full fit, restricted-fit closure, score and negative
log-likelihood closures, information evaluation, and warm starts.

`R/EDI/R/inference_ext_likelihood_test_memoization.R:128-217` then dispatches
to small C++ algebra helpers. The helpers currently return `Rcpp::List` values
from `R/EDI/src/_helper_functions.h`; they are native computations, but not a
standalone ABI. End-to-end inference still depends on R closures and
model-specific R dispatch.

### Confidence-interval inversion

The generic inversion paths in
`R/EDI/R/inference_ext_ci_inversion.R:57-260` pass R p-value or likelihood
callbacks into native root-search routines. `R/EDI/src/lrt_ci_newton.cpp:98-189`
and `:212-291` accept `Rcpp::Function` callbacks. That structure cannot be
called safely or efficiently from a language-neutral library, especially from
native worker threads.

The numerical algorithms can be retained, but they must call a native model
evaluator interface. Warm starts, Wald seeds, bracketing, maximum-absolute
bounds, degenerate intervals, and non-estimability reasons must become
explicit portable behavior.

### Bootstrap inference

`R/EDI/R/inference_all_abstract_non_param_boot.R:124-1891` owns much more than
an interval formula. It selects resampling units, generates draws, clones or
reuses workers, refits, manages seeds and parallelism, caches results, enforces
timeouts, and records failures. It also supports percentile, basic, Wald,
studentized/bootstrap-t, symmetric percentile-t, BCa, smoothed, calibrated,
double, prepivoted, m-out-of-n, and PRW variants.

The distribution summary in `R/EDI/R/helper_bootstrap_ci.R:5-22` is easy to
port. The hard part is defining what constitutes an exchangeable resampling
unit, rebuilding a valid analysis for every replicate, and preserving the
diagnostic semantics. BCa additionally needs jackknife influence information;
studentized intervals need a valid standard error for every replicate.

Bayesian bootstrap in
`R/EDI/R/inference_all_abstract_bayesian_bootstrap.R:82-250` adds Dirichlet
weights and design-aware weighting units. It should use the same batch engine,
but requires a weights contract rather than an index contract.

### Randomization inference

`R/EDI/R/inference_all_abstract_rand.R:131-351` checks design assumptions,
generates assignments, performs sharp-null response shifts, chooses fast batch
or reusable-worker execution, clones inference/design state, evaluates custom
statistics, and caches results. Its p-value logic at `:395-535` also includes
specialized branches and sequential Monte Carlo behavior.

There are many `compute_fast_randomization_distr` methods, but their existence
does not imply one general standalone engine. Some call true native batch
kernels; others still depend on R worker orchestration.

Bootstrap randomization compounds both workflows.
`R/EDI/R/inference_all_abstract_rand_bootstrap.R:201-361` resamples units,
draws a fresh assignment, applies the null shift, fits, and evaluates the
statistic. Its confidence-interval implementation in
`R/EDI/R/inference_all_abstract_rand_bootstrap_ci.R:27-485` adds common random
numbers, affine shortcuts for mean/OLS, studentized variants, smoothing,
bracket expansion, bisection, conservative boundaries, caching, and timeouts.

### Parametric likelihood-ratio bootstrap

`R/EDI/R/inference_all_abstract_param_boot.R:64-170` performs observed full
and restricted fits, simulates from the fitted null, and repeatedly performs
both fits with retry and failure diagnostics. Its interval path at `:206-339`
repeats the bootstrap p-value calculation inside a Monte Carlo-aware root
search.

The null simulator is model-family-specific. Many model classes implement
`simulate_under_lik_null`; some combinations are intentionally unsupported.
This work therefore requires a simulator registry and capability matrix, not
just a generic RNG call.

## Target native architecture

### Layer 1: R-free mathematical primitives

Extract or introduce value-returning C++ functions for:

- quadratic score statistics and rank/conditioning diagnostics;
- gradient tests from restricted scores;
- likelihood-ratio statistics from negative log likelihoods;
- asymptotic p-values and critical values;
- generic bracketing, bisection, and safeguarded Newton iteration;
- bootstrap distribution summaries; and
- finite-value filtering, quantiles, and Monte Carlo uncertainty.

These functions must accept ordinary C++ values and return typed structs. Rcpp
and host-language conversion belongs only in adapters.

### Layer 2: model-neutral evaluator

Introduce an internal, non-ABI C++ interface resembling:

```cpp
struct LikelihoodEvaluator {
    virtual FitResult fit_full(const FitOptions&) = 0;
    virtual FitResult fit_restricted(
        std::size_t tested_parameter,
        double null_value,
        const WarmStart* warm_start) = 0;
    virtual Evaluation evaluate(
        const FitResult& fit,
        EvaluationRequest request) = 0;
    virtual SimulatedData simulate_under_null(
        const FitResult& restricted_fit,
        std::uint64_t seed) = 0;
    virtual ~LikelihoodEvaluator() = default;
};
```

`Evaluation` should carry score, information, negative log likelihood,
coefficient and covariance data as requested. A capability bitset must state
which operations are valid for the selected model. Unsupported operations are
normal typed outcomes, not missing symbols or guessed fallbacks.

Each model family migrates its current likelihood-test specification into an
evaluator implementation. This is the largest reusable unit of work: once a
family supports restricted fitting and evaluation natively, score/LR tests,
their interval inversions, and parametric LR bootstrap can share it.

### Layer 3: immutable analysis description

Create an `AnalysisSpec` that contains all information now recovered from R6
objects and closures:

- response and model family;
- outcome, design matrix, weights, exposure, and offsets;
- treatment and tested-parameter mappings;
- groups, clusters, pairs, matched sets, blocks, and strata;
- survival time, event, censoring, truncation, and frailty fields;
- link, estimand, contrasts, and nuisance parameters;
- optimizer controls, tolerances, hardening options, and boundary policy; and
- design metadata required to validate supplied draws.

The specification should be immutable after analysis creation. Immutable
inputs make concurrency, caching, reproducibility, and host-language lifetime
rules substantially clearer.

### Layer 4: opaque C ABI handles

The first end-to-end ABI may resemble:

```c
typedef struct edi_analysis edi_analysis;

edi_status edi_analysis_create(
    const edi_model_spec* model,
    const edi_data_view* data,
    edi_analysis** out_analysis);

void edi_analysis_destroy(edi_analysis* analysis);

edi_status edi_score_test(
    edi_analysis* analysis,
    uint64_t tested_parameter,
    double null_value,
    const edi_test_options* options,
    edi_test_result* out_result);

edi_status edi_likelihood_ratio_test(
    edi_analysis* analysis,
    uint64_t tested_parameter,
    double null_value,
    const edi_test_options* options,
    edi_test_result* out_result);

edi_status edi_score_ci(
    edi_analysis* analysis,
    uint64_t tested_parameter,
    double confidence_level,
    const edi_ci_options* options,
    edi_ci_result* out_result);
```

The exact structs require an ABI review. Every public struct should begin with
`struct_size` and an ABI version so fields can be appended compatibly. Reserved
fields must be zero. Enum storage should use explicit fixed-width integer
fields at the boundary.

### Layer 5: batch resampling executor

The batch engine receives an immutable analysis plus a draw plan and produces
one typed record per replicate:

```text
draw input -> construct replicate view -> fit/evaluate -> statistic
           -> replicate status -> aggregate distribution and diagnostics
```

The native core should own parallel execution of native fits. A host binding
must not call back into Python, R, Java, or .NET from worker threads.

## ABI contracts required for inference

### Status and errors

At minimum distinguish:

- success;
- invalid argument or incompatible shape;
- unsupported model/capability;
- non-estimable parameter;
- singular or ill-conditioned information;
- optimizer non-convergence;
- numerical domain/overflow failure;
- insufficient usable replicates;
- timeout or cancellation;
- allocation failure; and
- internal invariant failure.

An aggregate call may succeed while individual replicates fail. Therefore the
result must contain both the call status and a replicate-status vector.
Returning only `NA`/`NaN` loses information required for diagnostics and
cross-language parity.

### Results

`edi_test_result` should include statistic, degrees of freedom, p-value,
estimate/null value, usable components, conditioning/rank information, fit
statuses, and warnings. `edi_ci_result` should include lower/upper endpoints,
endpoint openness, achieved p-values or objective values, iteration counts,
convergence state, and non-estimability/boundary reasons.

Resampling results additionally need requested/completed/usable counts,
replicate statistics, optional estimates/SEs, replicate statuses, seeds or
draw identifiers, failure-category counts, Monte Carlo standard error, and
whether a stopping rule was used.

Large variable-size outputs should use a size-query plus caller-owned-buffer
protocol or an opaque result handle with `edi_result_destroy`. Allocating with
one runtime and freeing with another is forbidden.

### Data and draws

Dense array views need element type, pointer, rank, dimensions, strides,
logical matrix order, and constness. The contract must define:

- whether indices are zero-based at the ABI boundary;
- whether a draw matrix is replicate-major or unit-major;
- how clusters/blocks map to rows;
- whether repeated indices are materialized or represented indirectly;
- how missing/non-finite values are treated;
- permitted aliasing between input and output;
- integer widths and overflow behavior; and
- whether noncontiguous input is supported or copied by the binding.

Use zero-based indices in the C ABI. R's wrapper should translate its public
one-based conventions.

### Randomness and reproducibility

The ABI must distinguish three modes:

1. caller-supplied draws: strongest cross-language parity;
2. core-generated draws from an explicit algorithm/version/seed; and
3. nondeterministic core generation requested explicitly.

For core-generated draws, record RNG algorithm, algorithm version, master
seed, stream-splitting rule, and number/order of draws. Reproducibility should
mean stable under a declared compatibility version; it should not be an
accidental property of thread scheduling.

## Feasibility by inference capability

| Capability | First useful ABI | Feasibility | Main missing work | Relative maintenance |
|---|---|---:|---|---:|
| LR statistic from supplied likelihoods | scalar utility | High | Rcpp-free result struct | Low |
| Score statistic from supplied score/information | buffer utility | High | typed matrices, rank diagnostics | Low |
| End-to-end LR test | analysis handle | High | restricted native refit/evaluator | Medium |
| End-to-end score test | analysis handle | Medium-high | model-native score/information | Medium-high |
| LR confidence interval | analysis handle + inverter | Medium-high | native callbacks, robust bracketing/warm starts | High |
| Score confidence interval | analysis handle + inverter | Medium | repeated restricted score evaluation | High |
| Percentile/basic CI from supplied distribution | vector utility | High | quantile policy and finite filtering | Low |
| Ordinary bootstrap with supplied indices | batch executor | Medium-high | replicate views and refits | Medium-high |
| Native ordinary bootstrap generation | resampling spec | Medium | exchangeability/design schema and RNG | High |
| Bayesian bootstrap with supplied weights | batch executor | Medium-high | weighted-family capability matrix | Medium-high |
| Studentized/bootstrap-t | batch executor | Medium | reliable replicate SE for every family | High |
| BCa | batch + jackknife | Medium | acceleration and design-aware delete units | High |
| Randomization with supplied assignments | batch executor | Medium-high | null transforms and design validation | Medium-high |
| Native randomization generation | design sampler | Medium | portable design hierarchy | High |
| Randomization CI | batch + inversion | Medium-low initially | nested evaluations and stable boundary search | Very high |
| Bootstrap-randomization test/CI | paired draw plan | Medium-low | compound resampling semantics | Very high |
| Parametric LR bootstrap | evaluator + simulators | Medium | per-family null simulator coverage | Very high |
| Adaptive/sequential design replay | workflow engine | Low for first release | mutable design state and stopping policy | Very high |

### Score and LR tests

These should be the first end-to-end inference features. The algebra is already
native; the central task is replacing R closures with `LikelihoodEvaluator`
implementations.

For every model family, declare separate capability flags for:

- full fitting;
- arbitrary single-parameter restriction;
- score vector;
- expected information;
- observed information;
- negative log likelihood;
- stable warm start; and
- null simulation.

LR testing needs full/restricted fits and comparable objective values. Score
testing needs a correct restricted score and information convention. The
capability matrix prevents a tempting but invalid assumption that all fitted
models support all tests.

Acceptance requires parity fixtures for interior nulls, boundary-adjacent
nulls, nuisance parameters, singular information, non-convergence, and
non-estimability—not only a happy-path p-value.

### Score and LR confidence intervals

CI inversion should live inside C++, immediately above the evaluator. Moving
only the root finder while retaining host callbacks would preserve the hardest
maintenance problem and introduce callback/lifetime/thread hazards.

The native interval algorithm must specify:

- confidence-level and tail conventions;
- initial estimate and Wald-based seed;
- left/right search and expansion rule;
- maximum iterations and absolute parameter bounds;
- safeguarded Newton versus bisection fallback;
- memoization key and warm-start selection;
- policy for failed intermediate fits;
- monotonicity violations and multiple crossings; and
- endpoint and interval failure diagnostics.

Tests and CIs should share cached restricted evaluations on an analysis
handle. Caching must be bounded and either handle-local or explicitly
synchronized.

### Nonparametric and Bayesian bootstrap

The first ABI should not generate draws. The caller supplies:

- an index matrix for case/unit bootstrap;
- a group-selection matrix plus group-to-row mapping for clustered designs;
- a weight matrix for Bayesian bootstrap; or
- a precomputed statistic vector when only interval summarization is needed.

The core validates each draw against the immutable analysis description and
runs refits in a batch. This preserves R's current design semantics and lets
other languages generate draws idiomatically without making those semantics
implicit.

Delivery order inside bootstrap support:

1. distribution summarization: percentile and basic intervals;
2. supplied-index ordinary bootstrap and Wald summaries;
3. supplied-weight Bayesian bootstrap;
4. studentized and symmetric percentile-t;
5. BCa with explicit jackknife deletion units;
6. smoothed and m-out-of-n variants;
7. calibrated, double, prepivoted, and PRW workflows.

Each advanced method needs its own capability and conformance fixtures. It
must not be represented as an option string accepted by every model.

### Randomization tests

The first useful API accepts complete assignment matrices. R can continue to
generate assignments from its existing design objects, while JVM/.NET/Python
clients can generate assignments from their own design layer or a simple
helper package. The core then applies a predefined null transform, refits, and
computes a predefined statistic ID.

Initial statistic IDs should cover EDI's common coefficient, score, LR, mean
difference, and studentized forms. Arbitrary user callbacks remain in the host
layer. If custom statistics later become essential, support either a separate
single-threaded callback API with explicit lifetime rules or a plug-in ABI;
do not mix managed callbacks into the normal parallel batch API.

Native assignment generation may follow for simple complete, blocked,
clustered, paired, and matched designs. Covariate-adaptive, sequential, or
response-adaptive designs require a versioned design state machine and belong
to a later workflow scope.

### Randomization confidence intervals

Randomization CIs invert a stochastic test and are substantially harder than
returning a randomization p-value. The implementation must preserve common
random numbers across candidate nulls, conservative discrete-p-value
boundaries, search caching, expansion limits, timeout/cancellation behavior,
and method-specific affine shortcuts.

Implement only after supplied-assignment randomization tests are stable. Start
with coefficient/mean/OLS cases and a fixed assignment matrix. Defer fully
general native-design inversion and randomization-bootstrap CIs.

### Parametric LR bootstrap

This feature should reuse the same restricted evaluator used by LR tests and
CIs, then add model-specific `simulate_under_null` implementations. For each
family, specify what is conditioned on, how nuisance parameters are chosen,
what censoring/group structure is preserved, and whether the simulator is
scientifically supported.

Start with one simple continuous family as a vertical slice, then add binary,
count, proportion, incidence, GLMM, and survival families only with dedicated
parity fixtures. CI inversion comes after the p-value path and should expose
Monte Carlo uncertainty and a deterministic common-random-number option.

## Recommended delivery phases

### Phase 0 — inventory and contracts (2–4 engineer-weeks)

- [ ] `CPPABI-001` Inventory every public fit and inference capability by
  response/model family.
- [ ] `CPPABI-002` Define the C ABI version, status taxonomy, ownership rules,
  array views, result structs, and thread-safety contract.
- [ ] `CPPABI-003` Define a machine-readable API/capability manifest.
- [ ] `CPPABI-004` Create golden R fixtures for fits, tests, intervals, and
  representative resampling runs.
- [ ] `CPPABI-005` Record which current behaviors are contractual versus
  accidental R implementation details.

Gate: the manifest can distinguish unsupported, not-yet-implemented, failed,
and non-estimable outcomes for every requested operation.

### Phase 1 — portable inference algebra (2–4 engineer-weeks)

- [ ] `CPPABI-101` Remove Rcpp types from score, gradient, and LR algebra.
- [ ] `CPPABI-102` Move CI search algorithms behind native callable objects.
- [ ] `CPPABI-103` Port bootstrap summaries and Monte Carlo diagnostics.
- [ ] `CPPABI-104` Add pure C++ unit fixtures plus C ABI conformance fixtures.

Gate: scalar/buffer-level utilities work without an R or Python runtime and
produce declared results on singular, boundary, and non-finite cases.

### Phase 2 — evaluator vertical slice (6–10 engineer-weeks)

- [ ] `CPPABI-201` Introduce `AnalysisSpec`, `LikelihoodEvaluator`, typed fit
  results, and capability flags.
- [ ] `CPPABI-202` Migrate one well-understood continuous family end to end.
- [ ] `CPPABI-203` Expose analysis creation/destruction, full/restricted fit,
  evaluation, score test, LR test, score CI, and LR CI.
- [ ] `CPPABI-204` Add bounded memoization and warm-start diagnostics.
- [ ] `CPPABI-205` Run identical serialized fixtures through C++, R adapter,
  and Python adapter.

Gate: no host callback occurs during tests or CI inversion, and the vertical
slice matches R within declared statistical and numerical tolerances.

### Phase 3 — common-family score/LR coverage (4–8 engineer-weeks)

- [ ] `CPPABI-301` Add binary, count, proportion, incidence, and survival
  evaluators in a risk-based order.
- [ ] `CPPABI-302` Add grouped/random-effect families only where their native
  restricted-fit and information contracts are complete.
- [ ] `CPPABI-303` Publish the generated capability matrix.
- [ ] `CPPABI-304` Add optimizer, boundary, singularity, and non-estimability
  fixture suites per family.

Gate: bindings can query support before a call and never infer inference
coverage from the presence of a fit function.

### Phase 4 — draws-in batch inference (8–14 engineer-weeks)

- [ ] `CPPABI-401` Add batch replicate execution with deterministic ordering,
  cancellation, and replicate-level statuses.
- [ ] `CPPABI-402` Support supplied case/group bootstrap index matrices.
- [ ] `CPPABI-403` Support supplied Bayesian bootstrap weights.
- [ ] `CPPABI-404` Support supplied randomization assignment matrices and
  predefined statistics/null transforms.
- [ ] `CPPABI-405` Add percentile, basic, Wald, and initial studentized
  summaries.
- [ ] `CPPABI-406` Define native inner-loop parallelism and oversubscription
  controls.

Gate: R can generate its existing draws, pass them to the core, and reproduce
the existing result distribution and failure accounting. At least Python and
one non-Python/non-R binding can consume the same fixture without callbacks.

### Phase 5 — make Python consume the C ABI (4–8 engineer-weeks)

Once the C ABI exists, Python should probably consume it too:

```text
R/EDI/src C++ kernels
          |
          v
   libedi_core C ABI
          |
          v
generated Python wrapper
          |
          v
 public edi_kernels API
```

A Python-level `ctypes` or CFFI wrapper can pass contiguous NumPy buffers
directly to `libedi_core`, translate status codes into Python exceptions, and
construct the existing result dictionaries.

This would replace much of the current duplicated surface:

- 4,317 lines of handwritten `bindings_*.cpp`;
- 36 lines of pybind-specific result conversion; and
- 1,618 lines of Python type stubs.

Not all 5,971 lines disappear. Documentation and idiomatic Python validation
remain, but declarations, defaults, result schemas, type signatures, and most
repetitive glue can be generated from the shared manifest.

Benefits:

- one native contract for every language;
- no separate mathematical binding logic for Python;
- new kernels and inference capabilities flow through the manifest;
- no pybind11 or Python development headers in the final architecture;
- potentially one platform wheel per architecture rather than separate
  CPython 3.9–3.13 extension wheels;
- independent testing of the exact `libedi_core` binary; and
- unchanged public `edi_kernels` names and result dictionaries.

Performance should remain effectively unchanged for model-fitting and
inference calls. Compatible contiguous NumPy arrays can be passed without a
copy. FFI overhead is insignificant relative to regression/GLMM fitting and
resampling. Scalar primitives should still be exposed in vectorized batches,
not invoked millions of times across the ABI.

Caveats:

- Python still needs a thin ergonomic layer for NumPy validation, optional
  arguments, exceptions, dictionaries, type hints, and documentation;
- the ABI must use caller-owned output buffers or carefully managed result
  handles;
- wheels must bundle the correct native library and compatible BLAS/OpenMP
  dependencies;
- noncontiguous or incorrectly typed arrays may require explicit copies; and
- pybind11 must not be deleted at the start of migration.

Migration steps:

1. implement the C ABI and shared conformance fixtures;
2. generate Python low-level declarations from the API manifest;
3. add an internal C-ABI Python backend without changing the public API;
4. run every existing Python test against both backends;
5. benchmark array conversion and result construction;
6. verify wheels and source installations on every supported platform;
7. make the C-ABI backend the default; and
8. remove pybind11 after at least one release cycle.

A smaller intermediate option is a tiny pybind11 module that calls the C ABI.
It reduces kernel-specific duplication but retains the CPython extension build
matrix. A pure Python `ctypes`/CFFI layer gives the larger maintenance
reduction.

Gate: public Python behavior, result schemas, documented exceptions, numerical
parity, and supported installation paths match the old backend. Both backends
remain selectable for one release cycle.

### Phase 6 — move R onto the shared engine (6–12 engineer-weeks)

- [ ] `CPPABI-601` Add thin R adapters that translate R objects to immutable
  analysis/draw specifications.
- [ ] `CPPABI-602` Run existing inference classes against old and shared
  backends using the same generated draws.
- [ ] `CPPABI-603` Preserve public R6 methods, result objects, warnings, and
  documentation.
- [ ] `CPPABI-604` Make the shared path default family by family.
- [ ] `CPPABI-605` remove duplicated R orchestration only after a release-cycle
  compatibility window.

Gate: the R package itself exercises the shared implementation; otherwise the
core will eventually drift from the reference implementation it was meant to
replace.

### Phase 7 — native draws and advanced methods (15–30 engineer-weeks)

- [ ] `CPPABI-701` Add a versioned RNG and simple design samplers.
- [ ] `CPPABI-702` Add design-aware cluster/block/pair bootstrap generation.
- [ ] `CPPABI-703` Add BCa, advanced studentized, smoothed, m-out-of-n, and
  selected calibrated methods.
- [ ] `CPPABI-704` Add randomization CI for the initial supported designs.
- [ ] `CPPABI-705` Add per-family parametric null simulators and LR bootstrap.
- [ ] `CPPABI-706` Evaluate double/prepivoted/PRW and
  bootstrap-randomization methods separately against observed demand.

Gate: every native generator can export its realized draws, replay them, and
match serial and parallel execution under its declared reproducibility
version.

Adaptive/sequential workflow migration is not included in this estimate. It
requires its own design-state protocol and plan.

## Language priority and expected consumers

The detailed demand assumptions and ranges live in `more_language_bindings.md`.
They are estimates, not observed user counts. For migration planning, the
important ordering is:

1. Python and R, because they validate that the existing products consume the
   shared backend;
2. MATLAB, the largest estimated new package-level audience;
3. JVM (Java first, with Kotlin/Scala using the same artifact) and Stata;
4. .NET (C# first, with F#/Visual Basic using the same artifact);
5. Julia;
6. server-side JavaScript/TypeScript;
7. Rust and Go; and
8. Ruby, PHP, and Perl as community-led or demand-triggered bindings.

The C SDK is first in **delivery** order even though it has few direct end
users, because it enables every row above. Julia is a useful early technical
proof because its C calling support is direct. MATLAB and Stata are especially
important because their users routinely perform serious statistical
inference; proprietary CI/tooling and ecosystem-specific command conventions
make them more expensive than their native wrapper size suggests.

Other serious-inference ecosystems worth considering are SAS and Fortran.
SAS may have material clinical/regulatory demand, but product integration,
licensing, validation expectations, and distribution require a separate
business case. Fortran can consume the C ABI with ISO C binding and needs only
a small module, but is more useful as an interoperability surface than as a
large new package audience. Kotlin/Scala and F#/Visual Basic should not receive
separate native libraries; they should share JVM and .NET packages.

Demand must be measured after launch using registry downloads adjusted for CI,
documentation traffic, citations, support requests, opt-in surveys, and—most
importantly—retained active projects. Raw downloads alone should not determine
advanced inference priorities.

## Maintainability assessment

### What becomes cheaper

- Mathematical fixes occur once.
- Score/LR fitting and inversion share one evaluator per model family.
- Resampling methods share one batch executor and diagnostic model.
- Defaults, enums, field schemas, declarations, and fixtures are generated.
- Python no longer has a parallel handwritten kernel declaration surface.
- Language packages mostly own array conversion and ergonomic presentation.
- The same native artifact can be tested independently and then bundled.

### What remains expensive

- Every model family needs correct restricted-fit, information, weighting, and
  simulation capabilities.
- ABI compatibility becomes a long-term product promise.
- Native binaries still need OS/architecture, BLAS, OpenMP, signing, and
  packaging work.
- Each language needs installation testing and idiomatic documentation.
- Statistical behavior changes require conformance review, not only compiler
  success.
- Advanced resampling multiplies runtime, failure modes, and test duration.

### Expected steady-state ownership

The maintainable team shape is one core/API maintainer group plus ecosystem
maintainers. Core owners review mathematical behavior, ABI evolution,
capability metadata, and shared fixtures. Binding owners review language
ergonomics and packaging. No binding owner should copy or independently alter
the inference algorithms.

Adding a normal fit/test capability should update the evaluator, manifest,
generated declarations, fixtures, and documentation once. If adding it
requires handwritten changes in every language, the architecture has failed
its main maintainability objective.

## Verification strategy

### Shared conformance corpus

Store serialized, versioned fixtures containing input data/specification,
realized draws where relevant, expected capability flags, expected output
schema, numerical reference values and tolerances, and expected status/warning
categories.

Coverage must include:

- one valid example per family and operation;
- defaults and optional branches;
- boundary parameters and degenerate samples;
- singular/ill-conditioned information;
- optimizer failure and recovery;
- invalid dimensions and draw plans;
- partial replicate failure and insufficient usable replicates;
- deterministic serial/parallel replay;
- cancellation and time-budget expiration;
- repeated creation/destruction and concurrent independent handles; and
- allocation and cleanup paths.

Numerical tolerances should distinguish deterministic algebra, optimizer
solutions, and Monte Carlo output. Resampling parity should normally compare
the same realized draws, not merely two independently generated distributions.

### Dual-backend migration tests

During migration, generate randomness once and feed identical draws to the old
R/pybind paths and the new core. Compare fit parameters, test statistics,
p-values, interval endpoints, replicate inclusion/exclusion, failure reasons,
and public result schemas. Investigate systematic differences; do not loosen a
single global tolerance until tests pass.

### Performance gates

Measure setup, fit, inference, resampling throughput, memory high-water mark,
and array conversion separately. Required protections include:

- no copy for compatible contiguous NumPy/native buffers;
- no per-replicate host-language callback;
- bounded handle caches;
- controlled OpenMP/BLAS oversubscription; and
- batch APIs for small scalar computations.

## Risks and mitigations

| Risk | Consequence | Mitigation |
|---|---|---|
| ABI designed from today's Python surface only | Later inference cannot fit without breaking changes | Design handles, statuses, buffers, and capability queries around the inference workflows first. |
| Porting R closures literally | Unsafe callbacks and poor parallelism | Replace them with native evaluators and predefined statistic IDs. |
| Overpromising model parity | Scientifically invalid methods appear supported | Generated per-family/per-method capability matrix and typed unsupported status. |
| RNG drift | Cross-language results appear inconsistent | Caller-supplied draws first; version native RNG and export realized draws later. |
| Replicate failures hidden as NaN | Unreproducible or biased inference | Per-replicate statuses and aggregate failure thresholds. |
| BLAS/OpenMP collisions | Crashes or severe oversubscription | One artifact policy, symbol checks, runtime controls, and packaging CI. |
| Premature removal of R/pybind paths | Difficult rollback and behavior regressions | Dual backends for at least one release cycle. |
| Advanced-method scope explosion | Core migration never ships | Gate work by tiers and ship draws-in basic inference first. |
| ABI frozen too early | Permanent awkward contracts | Experimental version namespace until two host bindings and R exercise it. |
| Host object lifetime leaks | Use-after-free or memory leaks | Immutable copied metadata, explicit handle lifetime, documented buffer borrowing. |

## Effort and staffing estimate

The phases overlap, and model-family work parallelizes after the evaluator
contract stabilizes. Approximate marginal effort:

| Workstream | Estimate |
|---|---:|
| ABI/manifest and portable algebra | 2–4 engineer-weeks |
| Model-neutral evaluator plus one vertical slice | 6–10 engineer-weeks |
| Initial-family score/LR tests | 4–8 engineer-weeks |
| Score/LR interval parity | 4–8 engineer-weeks |
| Draws-in resampling ABI and executor | 8–14 engineer-weeks |
| Python C-ABI migration | 4–8 engineer-weeks |
| R shared-backend migration | 6–12 engineer-weeks |
| Native draw generation | 15–30 engineer-weeks |
| Advanced bootstrap/randomization/parametric variants | 15–30 engineer-weeks |

The **20–35 week practical first release** includes common-family score/LR
tests and intervals, caller-supplied bootstrap/randomization draws, common
summaries, shared fixtures, and an initial Python consumer. It assumes the
basic fit-kernel C ABI and binary packaging foundation proceed with it.

The **50–90 week broad-parity range** includes R migration, substantially more
model families, native draw generation, advanced bootstrap variants,
randomization CIs, and parametric LR bootstrap. It excludes full adaptive and
sequential workflow parity and excludes the ongoing cost of supporting every
language package.

At least one senior statistical-computing owner must review the evaluator,
null simulation, and resampling semantics. ABI and release engineering can be
shared with a systems/package engineer. Ecosystem bindings can proceed in
parallel only after the ABI has passed both R and Python use.

## Decision checkpoints

1. **After Phase 0:** Is the desired product Level K inference or full Level W
   workflow parity? If Level W, create a separate workflow/state protocol
   plan before expanding this scope.
2. **After the evaluator vertical slice:** Can all required model-specific R
   closures be represented without weakening inference semantics?
3. **After draws-in bootstrap/randomization:** Does observed use justify
   native design/RNG generation, or is host-supplied generation sufficient?
4. **After Python and R dual backends:** Is the ABI stable enough to promise
   compatibility to JVM/.NET/MATLAB/Stata consumers?
5. **Before each advanced method:** Is there both model capability and user
   demand sufficient to pay its testing and long-term maintenance cost?

## Definition of done for the first inference release

- `libedi_core` exposes a documented, versioned, exception-safe C ABI.
- The API manifest generates declarations, capability documentation, and
  fixture inventories with a drift-check mode.
- At least one continuous plus representative binary/count family supports
  native full/restricted fits, score/LR tests, and their CIs.
- Ordinary bootstrap and randomization accept caller-supplied draws and return
  replicate-level diagnostics.
- Percentile/basic/Wald summaries are portable; advanced methods are either
  supported explicitly or rejected explicitly.
- R, Python, and one additional language execute the same conformance corpus.
- Python retains its existing public function names and result dictionaries.
- Old and new R/Python backends agree under identical realized draws and remain
  selectable for one release cycle.
- Binary artifacts pass the supported OS/architecture packaging matrix with a
  documented BLAS/OpenMP policy.
- No inference call depends on an R/Python/managed callback from native worker
  threads.
- Capability documentation makes clear that fit support and inference support
  are separate claims.

## Final recommendation

Approve the migration as an **inference-engine program**, not as a wrapper
generation exercise. Start with the portable evaluator and score/LR vertical
slice, then ship caller-supplied resampling draws. Make Python and R consume
the same ABI before scaling to many languages. This sequence tests the real
contract, removes duplicated mathematical glue, and gives other ecosystems a
credible inference API without requiring an immediate rewrite of EDI's entire
R workflow layer.
