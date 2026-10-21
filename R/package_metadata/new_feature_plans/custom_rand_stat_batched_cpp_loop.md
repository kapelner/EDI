# Batched C++ Loop for the Custom Randomization Statistic

> **Release:** v1.2.0 (moved from v1.1.0 on 2026-10-20, user decision) (`../future_release_plans/release_v1_2_0.md → TODO-31`,
> added 2026-10-13, user decision). Randomization-inference CPU core: one new
> C++ export plus R-side wiring in `InferenceRandCustom`; no new algorithm.
> No Phase 0 dependency. The pattern already exists for the design side:
> `src/design_optimal_annealing_search.cpp:152-155` dereferences the user's
> `edi_design_objective_fn` XPtr once and calls it directly inside the
> annealing loop.
>
> **Depends on:** the per-process compile memo `cached_cpp_compile()`
> (`R/helper_user_compiled_fn.R`, landed 2026-10-13 alongside this plan).
> Without it, compiling a source string per distribution call leaves one
> `file*.cpp` per call in `tempdir()`. That leak exhausted `/tmp`'s inodes
> during a `comprehensive_tests.R` run on 2026-10-13.

Date: 2026-10-13

## The finding

`InferenceRandCustom$compute_fast_randomization_distr()`
(`R/inference_rand_custom.R`) is the fast path for every randomization test
and every bisection step of the randomization CI on this class. It loops over
the columns of `permutations$w_mat` **in R** (`vapply`) and calls
`private$evaluate_stat()` once per permutation. Every user form crosses
R ↔ C++ once per permutation:

| User supplies | Per-permutation call |
|---|---|
| C++ source string | Rcpp-generated R wrapper → compiled function (`cppFunction`) |
| Pre-compiled Rcpp function | same |
| `RcppXPtrUtils::cppXPtr()` pointer | R → `eval_custom_rand_stat[_dead]_xptr_cpp()` shim (`src/user_compiled_fn_shims.cpp`) → pointer |
| R function | R closure |

So supplying compiled C++ buys a fast statistic but not a fast loop. The
per-permutation R overhead is the `vapply` closure, `evaluate_stat()`'s
`formals()` arity check, `as.integer()`/`as.numeric()` coercions,
`y + delta * wj`, and the `.Call` boundary. For cheap statistics such as a
mean difference, that overhead is most of the cost. It is paid
`r × (number of bisection steps)` times per CI.

There is **no batched C++ loop over `w_mat` for the user statistic** anywhere
in `src/`. The shims evaluate one `(y, w)` at a time.

## Design

### New export (`src/user_compiled_fn_shims.cpp`, unity group `unity_06.cpp`)

```cpp
// [[Rcpp::export]]
Eigen::VectorXd compute_custom_rand_stat_distr_xptr_cpp(
    SEXP xptr, const Eigen::Map<Eigen::VectorXd> y,
    const Eigen::Map<Eigen::MatrixXi> w_mat, double delta,
    Rcpp::Nullable<Eigen::Map<Eigen::VectorXd>> dead);
```

- Dereference the XPtr **once** (`edi_rand_stat_fn` or `edi_rand_stat_dead_fn`,
  chosen by whether `dead` is supplied), as the annealing kernel does.
- Allocate a `y_shift` and a `w_dbl` buffer once. Per column `j`:
  `w_dbl = w_mat.col(j).cast<double>()`, then
  `y_shift = (delta != 0) ? y + delta * w_dbl : y`, then call the pointer.
  This is the same arithmetic as the R loop, so results must be bit-for-bit
  identical.
- **Serial**: user code carries no thread-safety guarantee, which is the same
  rule as `annealing_solve_custom()` ("always serial chains").
- Follows the SEXP/RcppEigen kernel conventions and the `EDI_CORE_ONLY`
  header split already used by `user_compiled_fns.h`.

### R wiring (`R/inference_rand_custom.R`)

`compute_fast_randomization_distr()` gains a first branch: when an XPtr is
available, return
`compute_custom_rand_stat_distr_xptr_cpp(xptr, y, w_mat, delta, dead_or_NULL)`.
The existing `vapply` path stays as the fallback for R functions and
pre-compiled Rcpp functions, which have no reachable C function pointer.

Today `install_stat_cpp()` wraps a user XPtr in an R closure around the
single-call shim and discards the raw pointer. It must also keep the raw
pointer and its arity in a private field (e.g. `compiled_cpp_stat_xptr`). The
`Inference.duplicate()` locked-binding special-case in
`inference_all_abstract.R` must learn the new field name. Per the
"main process only" rule in the roxygen docs, pointers do not survive
serialization to parallel workers; workers recompile from the retained source
(see D1).

### Decision D1 — source strings: **resolved 2026-10-13, option (b)** (user decision)

The documented source-string signature is Rcpp-typed
(`NumericVector y, IntegerVector w[, IntegerVector dead]`). The pointer
convention in `user_compiled_fns.h` is Eigen-typed
(`const Eigen::VectorXd& y, const Eigen::VectorXd& w[, const Eigen::VectorXd& dead]`).

**Chosen: (b) accept Eigen-typed source strings as well.** `install_stat_cpp()`
reads the signature of a source string before compiling it:

- **Eigen-typed:** the source goes through `normalize_user_cpp_fn(src,
  "custom_randomization_statistic_cpp", "rand_stat" | "rand_stat_dead")`. That
  function compiles it once per process through
  `cached_cpp_compile(..., "cppXPtr")` and checks the recorded `args` against
  `EDI_USER_CPP_SIGNATURES`. It then takes the batched pointer path. The source
  is retained, so workers recompile it locally.
- **Rcpp-typed:** unchanged. It compiles through `cached_cpp_compile(src)`
  (`cppFunction`) and keeps the R loop.

The signature is detected from the argument list in the source text, with the
same parsing rule `RcppXPtrUtils::cppXPtr()` uses to record `args`. That
parser is internal to RcppXPtrUtils, so EDI carries a small local copy. This
avoids compiling a legacy source twice just to inspect its signature. A
source that matches neither convention gets the existing arity/signature
error.

The change is additive: every existing Rcpp-typed source behaves exactly as
before. Only Eigen-typed sources, which are new, get the C++ loop.

**Rejected alternatives:**

- (a) A generated adapter that wraps `y`/`w` into Rcpp vectors per call. It
  would keep the speedup for legacy sources, but it puts two R-vector
  allocations and R-API calls inside the loop.
- (c) Making the Eigen convention the only source-string signature. That is a
  documented-signature break, so it is deferred to v2.0.0
  (`../future_release_plans/release_v2_0_0.md → TODO-7b`). The deprecation
  path is a 1.x warning on Rcpp-typed sources pointing at the Eigen form.

## TODOs

- [x] TODO-1: Owner decision D1 → **(b)** (2026-10-13, user decision). (c) is
  deferred to `release_v2_0_0.md → TODO-7b`.
- [ ] TODO-2: `compute_custom_rand_stat_distr_xptr_cpp()` in
  `user_compiled_fn_shims.cpp` (2- and 3-argument forms; `dead = NULL`
  selects the 2-argument typedef). Compile only the touched unity group per
  the repo-root `CLAUDE.md`'s targeted-compile rule.
- [ ] TODO-3: In `install_stat_cpp()`: add source-signature detection
  (Eigen-typed vs Rcpp-typed, per D1). Route Eigen-typed sources through
  `normalize_user_cpp_fn()`. Retain the raw XPtr, its arity and the source in
  private fields. Teach `Inference.duplicate()` the new private field.
- [ ] TODO-4: Wire the batched kernel into
  `compute_fast_randomization_distr()` for user XPtrs and Eigen-typed
  sources. Workers recompile Eigen-typed sources from the retained source via
  `cached_cpp_compile(..., "cppXPtr")`, once per process. Rcpp-typed sources,
  pre-compiled Rcpp functions and R functions keep the `vapply` loop.
- [ ] TODO-5: **Gate — bit-for-bit equality** with the R loop. Cover the
  2- and 3-argument forms, `delta = 0` and `delta != 0`, the XPtr form, the
  Eigen-typed source form, survival (`dead`), a forked worker (recompile from
  source) and a `mirai` worker. Rcpp-typed sources must be routed exactly as
  before. Add a test that an Eigen-typed source and the equivalent Rcpp-typed
  source give identical distributions. Run the existing `test-inference-rand-custom*`
  and `test-user-compiled-*` suites unchanged.
- [ ] TODO-6: Benchmark (through the v1.1.0 noise-floor harness,
  `performance_profiling_and_upgrades.md → TODO-132..135`): a mean-difference
  statistic at n ∈ {50, 500}, r ∈ {501, 5001}, test plus CI. Record the
  speedup over the R loop here. No speedup number is claimed in ROADMAP/NEWS
  until it is measured.
- [ ] TODO-7: Docs. Update the `custom_randomization_statistic_cpp` roxygen
  `@param`: document the Eigen-typed source form and say that it, and
  XPtrs, run the permutation loop in C++. Also update the `user_compiled_fns.h` header
  comment, and `vignettes/extending-edi.Rmd` if the extension contract text
  mentions the per-permutation call. Add a NEWS entry.

## Standing constraints

Additive: with no user-visible switches, results are bit-for-bit identical
to 1.0.x (TODO-5 is the gate). No full package rebuilds by agents (see
the repo-root `CLAUDE.md`). Tick TODOs here, not only in the release file.
