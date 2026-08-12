# SEXP Removal / RcppEigen-Only Core Conversion Spec

Generated: 2026-07-28

## Scope

This spec defines an implementation plan for removing `SEXP` (and other
R-specific `Rcpp::` types) from the *numeric core* of `EDI/src`, so that every
kernel's actual computation is expressed purely in terms of `Eigen` types and
plain C++, with R-glue confined to a thin, mechanically generated boundary
layer. This is prerequisite groundwork for exposing the same numeric cores to
Python (via pybind11) without duplicating logic, and is independently useful
because it makes the C++ cores unit-testable outside of R.

This spec does **not** implement Python bindings. It only produces
Rcpp-independent cores plus thin R adapters. See the earlier conversation
in this session for the follow-up pybind11 spec.

Related documents:

- [perf_experiments_final.md](perf_experiments_final.md) — do not duplicate
  perf work tracked there; this spec is structural, not a performance pass.

## Motivation

An audit of `EDI/src` (2026-07-28) found:

- 29 exported functions across 13 files declared with `SEXP` as the return
  type (`fast_survival_models_optim.cpp`, `fast_poisson_glmm.cpp`,
  `fast_cpoisson_combined.cpp`, `fast_clogit_plus_glmm.cpp`,
  `fast_zero_one_inflated_beta.cpp`, `fast_stereotype_logit.cpp`,
  `fast_ordinal_regression.cpp`, `fast_ordinal_probit_regression.cpp`,
  `fast_ordinal_cloglog_regression.cpp`, `fast_ordinal_cauchit_regression.cpp`,
  `fast_coxph_regression.cpp`, `sample_mode.cpp`, `fast_logrank.cpp`). In every
  case checked, the `SEXP` return type is cosmetic — the function body only
  ever returns `List::create(...)` or `wrap(...)`, both of which convert
  implicitly to `SEXP`. `sample_mode.cpp` is the one exception: it switches on
  `TYPEOF(data)` to dispatch across R vector types, which is a genuine
  R-boundary concern (see Non-Goals).
- 54 files call `List::create(...)` to build a named return list — this is
  the dominant SEXP-touching pattern, and in every sampled case it appears
  only in the last few lines of a function whose body up to that point is
  pure `Eigen::VectorXd`/`MatrixXd` arithmetic.
- 51 files accept `SEXP ..._sexp` parameters purely to build a zero-copy
  `Eigen::Map` over the R object (pattern: `SEXP X_sexp` ->
  `Rcpp::NumericMatrix X_r(X_sexp)` -> `Eigen::Map<const Eigen::MatrixXd>
  X(X_r.begin(), ...)`). RcppEigen already performs this exact conversion
  automatically when a parameter is declared as `Eigen::Map<const
  Eigen::MatrixXd>` directly — the manual `_sexp` + `NumericMatrix` + `Map`
  dance is unnecessary boilerplate, not a required pattern.
- 15 files depend on R's RNG (`unif_rand`, `GetRNGstate`/`PutRNGstate`,
  `R::runif`, etc.): `bootstrap_indices.cpp`, `bootstrap_match_indices.cpp`,
  `generate_permutations.cpp`, `pocock_simon_assign.cpp`,
  `design_fixed_greedy.cpp`, `efron_redraw.cpp`, `kk14_redraw.cpp`,
  `rerandomization_helpers.cpp`, `binary_match_search.cpp`,
  `atkinson_redraw_batch.cpp`, `atkinson_assign.cpp`, `fast_sample_int.cpp`,
  `simulation_dgp.cpp`, `sample_bootstrap_distr_weighted_distances.cpp`. This
  is the one place with a genuine design decision (see RNG Handling below),
  not a mechanical rewrite.
- Zero raw R C API calls (`Rf_allocVector`, `PROTECT`/`UNPROTECT`,
  `SET_VECTOR_ELT`) and zero callbacks into R (`Rcpp::Function`,
  `Rcpp::Environment`, `Rf_eval`) anywhere in `EDI/src`. This rules out the
  hardest class of R-coupling; everything remaining is either `Rcpp::` sugar
  types or RNG.

Net picture: the refactor is large in file count but low in algorithmic risk.
The numeric logic does not need to change; only the boundary code does.

## Non-Goals

- Do not change any numeric algorithm, tolerance, or default argument.
  Behavior must be bit-identical before/after for every migrated function
  (see Testing).
- Do not touch `perf_experiments_final.md`-tracked optimizations; if a
  migrated file happens to also need a perf fix, track that separately.
- Do not attempt to make RNG-dependent files produce cross-language-identical
  streams unless explicitly decided (see RNG Handling) — that is a distinct,
  larger effort (reimplementing R's Mersenne-Twister-with-inversion
  generator) and is out of scope here.
- Do not migrate `sample_mode.cpp`'s `TYPEOF`-dispatch logic into the
  Rcpp-free core. That function's job is literally "dispatch on R vector
  type," which is an R-boundary concern by definition — keep it entirely
  in the R-facing wrapper layer, unconverted.
- Do not build the pybind11 module in this pass. This spec stops at
  "Rcpp-free cores + thin Rcpp wrappers that produce byte-identical R
  output." Exposing the cores to Python is a follow-up spec.

## Target Architecture

### Canonical Result Container (replaces per-function `List::create`)

Rather than defining a bespoke plain-C++ struct per migrated function (which
would mean ~50 one-off types), use one generic ordered key/value container in
the Rcpp-free core, plus exactly one converter per target language. This
keeps the core's return-building code nearly line-for-line identical to the
current `List::create(Named("x") = a, Named("y") = b)` calls, so the mechanical
diff per function is small and easy to review.

Add `EDI/src/result_map.h` (no `Rcpp` or `pybind11` include — this is the
Rcpp-free core boundary):

```cpp
#ifndef EDI_RESULT_MAP_H
#define EDI_RESULT_MAP_H

#include <RcppEigen.h>  // for Eigen::VectorXd/MatrixXd only — not for SEXP use
#include <string>
#include <utility>
#include <variant>
#include <vector>

namespace edi {

// std::monostate represents R_NilValue / Python None (typed "not available").
using ResultValue = std::variant<
	std::monostate,
	bool,
	int,
	double,
	std::string,
	Eigen::VectorXd,
	Eigen::MatrixXd
>;

class ResultMap {
public:
	ResultMap& set(std::string name, ResultValue value) {
		entries_.emplace_back(std::move(name), std::move(value));
		return *this;
	}

	const std::vector<std::pair<std::string, ResultValue>>& entries() const {
		return entries_;
	}

private:
	std::vector<std::pair<std::string, ResultValue>> entries_;
};

} // namespace edi

#endif
```

Add `EDI/src/result_map_rcpp.h` (the only place that includes both
`result_map.h` and `Rcpp.h` — this header is never included by a core `.cpp`
file, only by the thin `// [[Rcpp::export]]` wrapper functions):

```cpp
#ifndef EDI_RESULT_MAP_RCPP_H
#define EDI_RESULT_MAP_RCPP_H

#include "result_map.h"
#include <Rcpp.h>

namespace edi {

inline Rcpp::List to_rcpp_list(const ResultMap& m) {
	Rcpp::List out;
	Rcpp::CharacterVector names;
	for (const auto& [name, value] : m.entries()) {
		out.push_back(std::visit([](auto&& v) -> SEXP {
			using T = std::decay_t<decltype(v)>;
			if constexpr (std::is_same_v<T, std::monostate>) {
				return R_NilValue;
			} else {
				return Rcpp::wrap(v);
			}
		}, value));
		names.push_back(name);
	}
	out.names() = names;
	return out;
}

} // namespace edi

#endif
```

A parallel `result_map_pybind.h` (pybind11 `py::dict` converter, same
`std::visit` shape) is added in the follow-up pybind11 spec, not here — but
because the core already returns `edi::ResultMap`, that follow-up file is
the *only* new code that spec needs to write per function; no core changes.

### Migration Pattern Per Function

For a function currently shaped like:

```cpp
// [[Rcpp::export]]
SEXP fast_poisson_glmm_cpp(SEXP X_sexp, SEXP y_sexp, /* ... */) {
	Rcpp::NumericMatrix X_r(X_sexp);
	Eigen::Map<const Eigen::MatrixXd> X(X_r.begin(), X_r.nrow(), X_r.ncol());
	// ... pure Eigen computation ...
	return List::create(
		Named("b") = par.head(p),
		Named("converged") = converged
	);
}
```

migrate to:

```cpp
// fast_poisson_glmm_core.h / .cpp — no Rcpp include
edi::ResultMap fast_poisson_glmm_core(
	const Eigen::Map<const Eigen::MatrixXd>& X,
	const Eigen::Map<const Eigen::VectorXd>& y,
	/* ... */
) {
	// ... identical Eigen computation, unchanged ...
	return edi::ResultMap{}
		.set("b", par.head(p))
		.set("converged", converged);
}
```

```cpp
// fast_poisson_glmm.cpp — thin Rcpp wrapper, kept in the R package build only
#include "fast_poisson_glmm_core.h"
#include "result_map_rcpp.h"

// [[Rcpp::export]]
Rcpp::List fast_poisson_glmm_cpp(
	const Eigen::Map<const Eigen::MatrixXd>& X,
	const Eigen::Map<const Eigen::VectorXd>& y,
	/* ... */
) {
	return edi::to_rcpp_list(fast_poisson_glmm_core(X, y, /* ... */));
}
```

Notes:

- Declaring the parameter directly as `Eigen::Map<const Eigen::MatrixXd>`
  lets RcppEigen's `Rcpp::as<>` perform the zero-copy conversion at the
  export boundary automatically — this deletes the manual `_sexp` +
  `NumericMatrix`/`NumericVector` + `Map` boilerplate in the 51 files that
  currently do it by hand, it does not just relocate it.
- The wrapper function is intentionally still declared with
  `// [[Rcpp::export]]` and still lives in the same `.cpp` file as before
  (or a small `_core.cpp` split — see File Structure) so `Rscript
  fast_roxygenize.R` continues to regenerate `RcppExports.cpp`/`RcppExports.R`
  unchanged in signature.
- `NA_REAL`/`NA_INTEGER` scalars stored as `double`/`int` payload values pass
  through `Rcpp::wrap` unchanged, since they're just bit patterns — no special
  case needed in `to_rcpp_list`.

### File Structure

Two layout options, in order of preference:

1. **Same file, split top/bottom** (preferred for smaller files — most of the
   50 files in scope): keep `fast_poisson_glmm.cpp` as one file, with the
   Rcpp-free core function(s) at the top (no `Rcpp.h` include needed there
   because `RcppEigen.h` already pulls in the Eigen types without requiring
   any `SEXP`/`List` usage) and the thin `// [[Rcpp::export]]` wrappers at
   the bottom. This avoids a wave of new files for simple cases.
2. **`_core.cpp` split** (use only for files that are large — e.g.
   `fast_survival_models_optim.cpp`, `fast_clogit_plus_glmm.cpp`,
   `fast_cpoisson_combined.cpp`, all with 3+ SEXP-returning entry points and
   substantial shared internal state/objective classes): extract to
   `fast_survival_models_optim_core.h`/`.cpp` + keep
   `fast_survival_models_optim.cpp` as the thin wrapper file. Do this only
   where the existing file has grown large enough that the split materially
   helps readability — don't split trivially small files just for
   consistency.

Either way, the invariant is: no `.cpp`/`.h` file that is part of a "core" is
allowed to `#include <Rcpp.h>` or reference `SEXP`, `Rcpp::List`,
`Rcpp::NumericVector`, etc. This is mechanically checkable (see Tests).

## RNG Handling

The 15 RNG-dependent files are not part of the mechanical SEXP-removal pass
in this spec. They need an explicit decision because R's RNG stream
(`GetRNGstate`/`unif_rand`/`PutRNGstate`) is what makes `set.seed()`
reproducible today, and swapping to `std::mt19937` changes that.

Decision for this spec: **do not migrate RNG-dependent files in Phase 1–4
below.** Leave them SEXP-touching and R-coupled for now. Track the RNG
question as a separate follow-up decision (own spec) with two options to
choose between at that time:

- keep R's RNG as the source of randomness (call `unif_rand()` from both the
  R build and, later, a small embedded-R-free reimplementation of R's
  Mersenne-Twister + inversion normal generator for the Python build), which
  preserves cross-language seed reproducibility at implementation cost, or
- accept that Python-side draws use a different generator (e.g.
  `std::mt19937` seeded independently), document the divergence, and give up
  cross-language bit-identical reproducibility for resampling-based
  inference.

This spec's Phase list therefore only covers the ~50 non-RNG files.

## Error Handling

Replace the 19 `Rcpp::stop(...)` call sites in migrated core functions with
a plain `std::runtime_error` (or a small `edi::CoreError` subclass if a
distinguishable exception type proves useful during migration — decide when
the first case is hit, don't pre-build it speculatively). The thin Rcpp
wrapper does not need to catch and re-wrap: Rcpp already translates
`std::exception` into an R condition at the export boundary, matching
current `Rcpp::stop` behavior.

## Testing

For every migrated function, migration must be a no-op from R's point of
view. Verify with:

1. Build the package before migration
   (`R CMD INSTALL --no-docs EDI`) and capture output of the existing test
   file that exercises the function (from `package_tests/` — identify via
   `grep -rl <function_name> package_tests/`) as a baseline.
2. Migrate the function per the pattern above.
3. Run `Rscript fast_roxygenize.R` to regenerate `RcppExports.cpp`/`.R`
   ([[feedback_roxygenize]]).
4. Rebuild and re-run the same test file; diff against the baseline. Outputs
   must be bit-identical (not just "close") since no numeric code changed.
5. Add a compile-time check that core files stay Rcpp-free: a small script
   (`scripts/check_core_no_rcpp.sh`) that greps every file matching
   `*_core.cpp`/`*_core.h` plus every file with a "core function" region for
   `#include <Rcpp` or `\bSEXP\b` and fails if found. Wire this into whatever
   CI/pre-commit check already runs `fast_roxygenize.R` if one exists;
   otherwise leave it as a standalone script invoked manually until a CI
   pass is added.

Do not skip step 4's bit-identical diff even for functions that look like
pure refactors — this is the entire safety net for a change that touches
~50 files without altering intended behavior.

## Status (updated 2026-08-11)

Audited against the current state of `EDI/src` and `python/cpp`. This section
tracks progress; see TODO Checklist below for the item-by-item breakdown it's
based on.

- **Infrastructure (Phase 1) is done.** `result_map.h` and `result_map_rcpp.h`
  both exist as specified. The pilot migration (`fast_poisson_glmm_cpp`) is
  done in substance — its core is extracted into
  `fast_poisson_glmm_internal`, which returns `edi::ResultMap`, and the
  wrapper takes `Eigen::Map`/plain Rcpp-sugar params directly and calls
  `edi::to_rcpp_list(...)`. One deviation from the Migration Pattern as
  written: the wrapper's declared return type is still `SEXP`, not
  `Rcpp::List` — functionally identical (per this doc's own "cosmetic" note
  in Motivation) but not literally matching the pattern; folding this into
  Phase 4 cleanup is the cheapest way to close it out.
- **`scripts/check_core_no_rcpp.sh` now exists** (`R/scripts/check_core_no_rcpp.sh`
  + `check_core_no_rcpp.py`) and has been run. It doesn't do a naive whole-file
  grep — since this codebase's actual convention (documented in
  `fast_gamma_functions.h`, not anticipated by this doc when it was written)
  is same-file `#ifdef EDI_CORE_ONLY`/`#ifndef EDI_CORE_ONLY` splitting rather
  than separate `*_core.cpp` files, the script statically tracks that
  conditional nesting to determine which lines would survive an
  `EDI_CORE_ONLY` compile, and only flags `SEXP`/`Rcpp::`/`#include
  <Rcpp...>` in *those* lines (comments and string/char literals are
  stripped first, so prose that merely mentions "SEXP" doesn't trip it).
  Whole-file `*_core.cpp`/`*_core.h` files are checked unconditionally in
  full. Verified against a positive control (an injected `SEXP` parameter
  was caught at the correct line, then reverted) and a negative control (a
  real doc comment containing the literal word "SEXP" was correctly not
  flagged). **Current result: 49 migrated files checked (the same set with
  Python/pybind11 bindings), 0 violations — every core region that has
  actually been through the `EDI_CORE_ONLY` split is genuinely Rcpp/SEXP-free
  today.** 69 files were skipped as not-yet-migrated (no `EDI_CORE_ONLY`
  guard found), consistent with Phase 2/3/4 still being open for them.
- **Phase 3 (`List::create` → `ResultMap`) is substantially further along
  than the checklist reflects.** 32 files already build results via
  `edi::ResultMap`, covering essentially every primary fitting function
  across all four family groupings in TODO-6–9 (continuous/OLS, count/
  ordinal, incidence/survival/proportion, and GLMM/KK-combined, including the
  large state-heavy files called out as Phase-3-last: `fast_clogit_plus_glmm.cpp`,
  `fast_cpoisson_combined.cpp`). This looks like it happened outside/ahead of
  this checklist rather than because of it — worth reconciling with whoever
  did that work rather than re-deriving it from scratch.
  28 files still call `List::create` somewhere; that remainder is concentrated in:
  - RNG-dependent files correctly left alone per the RNG Handling exclusion
    (`bootstrap_match_indices.cpp`, `exchangeable_resampling_draws.cpp`,
    `generate_permutations.cpp`, `randomization_loop.cpp`,
    `simulation_dgp.cpp`, `test_smart_starts.cpp`);
  - design/matching/speedup helper files never explicitly named in the
    phase breakdown (`build_kk_combined_clogit_design.cpp`,
    `build_kk_combined_ols_design.cpp`, `gcomp_speedups.cpp`,
    `robust_post_fit_speedups.cpp`, `match_data_compute_speedup.cpp`,
    `qr_reduce_design_matrix.cpp`, `kk_bootstrap_reservoir_stats.cpp`,
    `kk_cluster_ids.cpp`, `kk_lin_match_data.cpp`, `zhang_exact_speedups.cpp`,
    `survival_strata_ids.cpp`, `base_bootstrap_loop.cpp`, `build_info.cpp`);
  - secondary exported helpers (score/hessian/post-fit getters) living in
    otherwise-migrated model files (e.g. `fast_coxph_regression.cpp`,
    `fast_logrank.cpp`, `fast_ordinal_regression.cpp`,
    `fast_zero_augmented_poisson.cpp`, `fast_zinb.cpp`,
    `fast_gehan_wilcox.cpp`, `fast_jonckheere_terpstra.cpp`,
    `fast_ridit_analysis.cpp`).
- **Phase 4 (raw `SEXP`-return wrapper signatures) has not been started.**
  All 13 files from the Motivation audit still declare their exported
  wrapper functions as returning `SEXP` rather than `Rcpp::List`, including
  `fast_poisson_glmm.cpp` despite its core being migrated (see above). One
  additional file not in the original 13, `fast_gehan_wilcox.cpp`, was found
  in this audit with the same pattern and should be folded into TODO-10.
  `sample_mode.cpp` is unchanged, as intended (Non-Goals).
- **Phase 2 (zero-copy `Eigen::Map` params) update (2026-08-12): substantially
  executed, with one known gap and one deliberately-paused edge.**
  - Converted all 38 files matched by the `_sexp`-naming target list (the
    5 files excluded for RNG/callback/scalar-only reasons — see the earlier
    audit — correctly untouched). 377 parameters converted automatically,
    plus manual fixes for cases the conversion script couldn't handle safely
    on its own: a raw-R-C-API function (`fast_bai_parallel.cpp`), a few
    files where a comment embedded inside a multi-line parameter list broke
    the script's comma-splitting (`compute_all_subject_data.cpp`,
    `compute_mahal_distances.cpp`, `fast_gaussian_lmm.cpp`,
    `fast_logistic_glmm.cpp`), an internal (non-exported) helper shared by
    two exported wrappers (`gcomp_speedups.cpp`'s
    `compute_gcomp_logistic_post_fit`), and a delegate-call mismatch where a
    wrapper forwarded the derived `Eigen::Map` instead of the raw parameter
    to a SEXP-taking internal sibling (`robust_post_fit_speedups.cpp`).
  - **Real regression found and fixed during verification, not just a
    mechanical port:** `Eigen::Map`-typed parameters require an *exact* R
    type match — no int↔double coercion, unlike the
    `NumericVector(SEXP)`/`IntegerVector(SEXP)` constructors the pre-Phase-2
    code used, which coerced silently. R's own RNG functions are
    inconsistent about this (`rbinom`/`rpois` return integer, `rnbinom`
    returns double), so no single static Eigen type is safe for
    response/count-like data. Found via the project's own
    `test-rcpp-fitting-equivalence.R`/`test-fast_glm_outputs.R`/etc. failing
    after the conversion. Fixed by reverting *only* the affected parameter
    (`y`, `dead`, `w`, `weights`, `m_vec`, and their `_r`-suffixed variants)
    back to `SEXP` → coercing `NumericVector`/`IntegerVector` → `Eigen::Map`,
    preserving each function's original coercion type exactly, while keeping
    every other parameter (`X`, etc.) as the zero-copy direct `Eigen::Map`.
    109 of the 134 converted functions needed this exception (8 found via
    the failing tests, 101 more via a systematic sweep of every
    response/count-shaped `Eigen::Map<VectorXd/Xi>` parameter across all 134
    functions). Verified: full package compiles clean, all 6
    kernel-equivalence test files pass with 0 failures, and a full test-suite
    run confirms zero remaining `"Wrong R type for mapped vector"` errors
    anywhere (the only failures left are from an unrelated, actively-in-flight
    `y`/`y_L`/`y_R` censored-response API change elsewhere in the repo).
  - **Known real gap, not yet closed:** the target-file list was built from
    `grep -rl "_sexp" *.cpp`, which missed files where an *earlier* session
    had already stripped the `_sexp` suffix from argument names (leaving
    clean `SEXP X, SEXP y` signatures with no `_sexp` substring left to
    match) without doing the actual Phase 2 type conversion. Confirmed still
    on the old manual pattern: `fast_ols.cpp`, `fast_log_binomial_regression.cpp`,
    `fast_robust_regression.cpp`, `fast_zinb.cpp`, `fast_gee.cpp`,
    `fast_jonckheere_terpstra.cpp`, plus a handful of individual functions in
    files that were otherwise converted (`fast_ridit_analysis.cpp`'s
    `fast_ridit_analysis_cpp`, `fast_wilcox_hl.cpp`'s
    `wilcox_hl_point_estimate_cpp`, `fast_wilcox_parallel.cpp`'s
    `compute_wilcox_distr_from_list_parallel_cpp`, `fast_weibull_regression.cpp`
    (all 3 exports), `fast_survival_stats.cpp` (all 4 exports)).
  - **Deliberately not touched further this session:** closing the gap above
    would mean converting exactly the `y`/`dead`/`weights`-shaped parameters
    that are the subject of an active, separate, in-progress change elsewhere
    in the repo (migrating the response representation from `y`/`dead` to
    `y`/`y_L`/`y_R`). Touching those parameters now would conflict with that
    work; left alone until it lands.
- **This session's actual contribution: an argument-*naming* cleanup, not
  Phase 2.** Per explicit user request, stripped the `_sexp` suffix from the
  argument *names* (not types) of all 41 `NAMESPACE`-exported (public) C++
  functions across 16 source files — e.g.
  `fast_weibull_regression_cpp(X_sexp, y_sexp, dead_sexp, ...)` became
  `fast_weibull_regression_cpp(X, y, dead, ...)`. Parameters are still typed
  `SEXP`; the manual `NumericMatrix`/`Eigen::Map` conversion lines are still
  present; internal (non-exported) functions in those same 16 files were
  deliberately left untouched, per instruction. Net effect: nicer R-facing
  argument names now show up in `?fast_weibull_regression_cpp` etc., but this
  doesn't advance Phase 2, 3, or 4 of this spec — it's an orthogonal,
  smaller-scope fix that happened to touch an overlapping set of files.
  Also updated as part of that work: `RcppExports.R`/`.cpp`, man pages,
  `NAMESPACE` (regenerated, unchanged), and the handful of R call sites/tests
  that passed those arguments by name.
- **TODO-13 (pybind11 layer) is done and shipped**, despite being explicitly
  out of scope for this doc. `python/cpp/result_map_pybind.h` exists as the
  pybind11 twin of `result_map_rcpp.h`, 10 `bindings_*.cpp` files
  (~3,760 lines) wrap all 33 `edi::ResultMap`-returning cores (37 bound
  functions), and the resulting `edi_kernels` package was actually
  published to PyPI as `py-v1.0.0` — verified post-publish by installing
  from `pypi.org` into an independent venv and passing the full 181-test
  suite, not just a local build check. A critical sdist-install bug found
  2026-08-10 was fixed and verified (`.post1`). Tracked in full by a
  separate `python_bindings_package_spec.md`; its own remaining open items
  are documentation polish (parameter-level docs, a PyPI-specific README),
  not the binding layer.

## Implementation Phases

### Phase 1: Infrastructure

- Add `EDI/src/result_map.h` and `EDI/src/result_map_rcpp.h` as specified
  above.
- Migrate exactly one representative function end-to-end
  (`fast_poisson_glmm_cpp` in `fast_poisson_glmm.cpp`, chosen because it was
  already inspected in this spec's audit) to validate the pattern, including
  the bit-identical test-diff step.
- Add `scripts/check_core_no_rcpp.sh`.

### Phase 2: Zero-copy Input Cleanup (51 files)

- For every file using the manual `SEXP ..._sexp` -> `Rcpp::NumericMatrix`/
  `NumericVector` -> `Eigen::Map` pattern, change the parameter type directly
  to `const Eigen::Map<const Eigen::MatrixXd>&` / `const Eigen::Map<const
  Eigen::VectorXd>&` and delete the manual conversion lines. This phase does
  not require the `ResultMap` change yet and can proceed independently/in
  parallel with Phase 3 — do it first since it is lower-risk and mechanically
  identical across all 51 files.
- Exclude the 15 RNG files (Non-Goals) and `sample_mode.cpp` (needs its
  `SEXP`/`TYPEOF` dispatch, Non-Goals).

### Phase 3: Output Migration — `List::create` Files (54 files)

- For each file, split the tail `List::create(...)` into an `edi::ResultMap`
  build, per the Migration Pattern.
- Batch by response-type family for reviewability (matches the existing
  `Collate:` grouping in `EDI/DESCRIPTION`): continuous/OLS family first
  (smallest, already partly audited), then count/ordinal, then
  incidence/survival/proportion, then the KK-combined/GLMM files last (they
  tend to be the largest and most state-heavy, e.g.
  `fast_clogit_plus_glmm.cpp`, `fast_cpoisson_combined.cpp`).
- Apply the File Structure decision (same-file split vs `_core` split) per
  file as encountered, not all upfront.

### Phase 4: Output Migration — Raw `SEXP`-Return Files (13 files, 29 functions)

- Same pattern as Phase 3; these are functionally identical to Phase 3 cases
  (return type is cosmetic — see Motivation) except the declared return type
  changes from `SEXP` to `Rcpp::List` on the wrapper.
- `sample_mode.cpp` is excluded (Non-Goals) — leave entirely as-is.

### Phase 5: Verification Sweep

- Run `scripts/check_core_no_rcpp.sh` across all of `EDI/src` and fix any
  remaining leaks.
- Run the full `package_tests/` suite once (not per-file) to catch any
  cross-file interaction missed by the per-function bit-identical diffs.
- Update `[[feedback_roxygenize]]`-style docs if any exported function
  signature's argument order changed (it should not have — flag if it did).

## TODO Checklist

- [x] TODO-1: Add `EDI/src/result_map.h` (`edi::ResultValue`, `edi::ResultMap`).
      Done — file exists as specified.
- [x] TODO-2: Add `EDI/src/result_map_rcpp.h` (`edi::to_rcpp_list`).
      Done — file exists as specified.
- [x] TODO-3: Add `scripts/check_core_no_rcpp.sh`.
      Done — `R/scripts/check_core_no_rcpp.sh` (+ companion `.py`). Tracks
      `EDI_CORE_ONLY` conditional nesting rather than naive whole-file grep
      (see Status). Run against `R/EDI/src`: 49 migrated files checked, 0
      violations.
- [x] TODO-4: Migrate `fast_poisson_glmm_cpp` end-to-end as the pilot; confirm
      bit-identical test diff before proceeding further.
      Done in substance (core in `fast_poisson_glmm_internal`, returns
      `edi::ResultMap`, wrapper takes `Eigen::Map` params directly and calls
      `edi::to_rcpp_list`). Minor gap: wrapper return type is still declared
      `SEXP` rather than `Rcpp::List` — fold that into TODO-10.
- [~] TODO-5: Phase 2 — zero-copy input cleanup across the 51 `_sexp`-pattern
      files (excludes the 15 RNG files and `sample_mode.cpp`).
      **Update 2026-08-12: substantially done, deliberately not 100%.** All
      38 files matched by the `_sexp`-naming scan converted to direct
      `Eigen::Map` parameters (see Status for the full breakdown, including a
      real type-strictness regression found and fixed along the way). One
      parameter family is a **permanent, intentional exception, not a
      leftover**: `y`/`dead`/`w`/`weights`/`m_vec`-shaped parameters were
      kept on `SEXP` → coercing `NumericVector`/`IntegerVector` →
      `Eigen::Map`, because `Eigen::Map<VectorXd>`/`Eigen::Map<VectorXi>`
      require an *exact* R storage-mode match and R's own generators don't
      honor a consistent int/double contract for this kind of data
      (`rbinom`/`rpois` return integer, `rnbinom` returns double, for
      conceptually identical "count" data) — a real, general Rcpp/RcppEigen
      limitation, not something fixable by picking a "better" static type.
      Remaining genuine gap (not exempted, just not reached): `fast_ols.cpp`,
      `fast_log_binomial_regression.cpp`, `fast_robust_regression.cpp`,
      `fast_zinb.cpp`, `fast_gee.cpp`, `fast_jonckheere_terpstra.cpp`, and a
      few individual functions elsewhere — missed because they'd already had
      `_sexp` stripped from argument names in an earlier session, so the
      `grep -rl "_sexp"` scan used to build today's target list didn't catch
      them despite the manual conversion pattern still being present.
      Deliberately left alone rather than closed out immediately: finishing
      it means touching the same `y`/`dead`/`weights` parameters an active,
      separate, in-progress change elsewhere in the repo is mid-migrating
      (`y`/`dead` → `y`/`y_L`/`y_R`) — revisit once that lands.
- [x] TODO-6: Phase 3 — migrate continuous/OLS-family `List::create` files.
      **Done 2026-08-12.** `fast_ols.cpp`/`fast_robust_regression.cpp` were
      already fully on `edi::ResultMap` (no remaining work — done ahead of
      this checklist by whoever did that earlier pass). The two remaining
      OLS-specific files converted this session:
      `robust_post_fit_speedups.cpp` (`ols_hc2_setup_cpp`,
      `ols_hc2_post_fit_cpp`, `ols_hc2_post_fit_precomputed_cpp`,
      `glm_sandwich_post_fit_cpp`, `glm_cluster_sandwich_post_fit_cpp` — the
      shared `summarize_with_vcov` helper now builds `edi::ResultMap` instead
      of `Rcpp::List` directly, each export wraps it with
      `edi::to_rcpp_list`) and `build_kk_combined_ols_design.cpp`
      (`build_matching_combined_ols_design_cpp`). Both files' portable cores
      (`ols_hc2_post_fit_result`, `summarize_with_vcov_result`) were already
      Rcpp-free plain-struct returns from an earlier pass — this just closed
      the last `List::create` mile at the R boundary. No overlap with the
      active `y`/`dead` → `y`/`y_L`/`y_R` response-representation migration
      elsewhere in the repo (checked: neither file references `dead`, `y_L`,
      or `y_R` — continuous/OLS models have no censoring concept). Verified:
      full recompile clean, `test-kk-ols-se.R` (21 assertions) and
      `test-ols-hc2-hat-vectorized.R` (4 assertions) both pass with 0
      failures. Two more OLS-*adjacent* files still have `List::create`
      (`match_data_compute_speedup.cpp`, `qr_reduce_design_matrix.cpp`) but
      are shared cross-family infrastructure, not OLS-specific — left for
      whichever of TODO-7/8 (or a dedicated cleanup pass) actually owns them.
- [x] TODO-7: Phase 3 — migrate count/ordinal-family `List::create` files.
      **Done 2026-08-12.** Primary fitting functions were already done across
      binomial/poisson/negbin/beta and ordinal variants; this pass closed the
      three secondary exported helpers named in this TODO:
      `fast_zinb.cpp` (`fast_zinb_cpp`'s `estimate_only` branch — the nested
      `coefficients = list(cond=, zi=)` sub-list has no `edi::ResultMap`
      representation since `ResultValue`'s variant doesn't include a list
      type, so the flat fields (`params`, `converged`, `iterations`) go
      through `edi::ResultMap`/`to_rcpp_list` and `coefficients` is attached
      after, mirroring the pattern the non-`estimate_only` branch already
      used one call below via `make_uniform_likelihood_fit_result`),
      `fast_ridit_analysis.cpp` (`fast_ridit_scores_cpp`,
      `fast_ridit_analysis_cpp` — `scores`/`ref_p` go through `ResultMap` as
      `Eigen::VectorXd::Map(...)`, but `levels` stays on the `wrap()` path
      deliberately: it's an integer category-label vector and `ResultValue`
      has no integer-vector member, so routing it through `ResultMap` would
      silently turn it into a double vector on the R side — the same
      type-strictness hazard flagged earlier this session for `y`/`dead`/
      `weights`), and `fast_jonckheere_terpstra.cpp`
      (`exact_jonckheere_terpstra_pval_cpp` — all 7 fields are scalar
      int/double, straightforward `ResultMap` conversion, file had no
      `EDI_CORE_ONLY` split and isn't in `python/CMakeLists.txt`, so
      `result_map_rcpp.h` was added unconditionally like
      `build_kk_combined_ols_design.cpp` in TODO-6).
      `fast_ordinal_regression.cpp` was also audited (it's mostly already on
      `edi::ResultMap`/`edi::to_rcpp_list`; its remaining SEXP-return
      functions are TODO-10's concern, not TODO-7's) but its two
      `List::create` calls (`expand_continuation_ratio_data_cpp`,
      `expand_adjacent_category_data_cpp`) were deliberately left alone: all
      three fields they return (`y`, `w`, `strata`) are integer vectors
      consumed downstream as strata/grouping keys, the same
      `ResultValue`-has-no-integer-vector gap as `levels` above, and higher
      risk since strata/grouping values are more likely to hit an
      `Eigen::Map<VectorXi>`-typed consumer than a display-only ridit level.
      No overlap with the active `y`/`dead` → `y`/`y_L`/`y_R` migration
      elsewhere in the repo (checked: none of the four files reference
      `dead`, `y_L`, or `y_R`). Verified: full recompile clean; runtime
      smoke test of all four converted functions confirmed correct values
      *and* correct R-side types (`levels`/`stat2`/`n_treat`/`n_control`
      stayed integer, `params`/`scores`/`vcov` stayed double); existing
      tests `test-rcpp-fitting-equivalence.R` (68 assertions),
      `test-zinb-operator-workspace.R` (7), `test-rcpp-fitting-real-data.R`
      (37), `test-zinb-std-lgamma.R` (3), and
      `test-brt-smoothed-noise-mat-plumbing.R` (7) all pass with 0 failures
      (run via `pkgload::load_all(compile = FALSE)` since compiling had
      already produced a fresh `.so`). `test-rand-bootstrap.R` and
      `test-bayesian-bootstrap.R` show pre-existing failures referencing
      `y_L`/`y_R`/`deads` — these are from the user's concurrent in-progress
      migration in unrelated files, not from this TODO-7 change (none of the
      four files touched here are anywhere near bootstrap/design code).
- [~] TODO-8: Phase 3 — migrate incidence/survival/proportion-family
      `List::create` files.
      Primary survival/proportion fitting functions done (`fast_weibull_regression.cpp`,
      `fast_weibull_frailty.cpp`, `fast_zero_one_inflated_beta.cpp`,
      `fast_zero_augmented_poisson.cpp`); `fast_coxph_regression.cpp` and
      `fast_logrank.cpp` still call `List::create` (also overlaps TODO-10).
- [x] TODO-9: Phase 3 — migrate KK-combined/GLMM `List::create` files
      (`fast_clogit_plus_glmm.cpp`, `fast_cpoisson_combined.cpp`, and
      similarly state-heavy files).
      Done — both named files plus `fast_gee.cpp`, `fast_gaussian_lmm.cpp`,
      `fast_logistic_glmm.cpp`, `fast_ordinal_glmm.cpp`, `fast_ordinal_clmm.cpp`,
      `fast_hurdle_poisson_glmm.cpp` all build results via `edi::ResultMap`.
- [ ] TODO-10: Phase 4 — migrate the remaining raw-`SEXP`-return files:
      `fast_survival_models_optim.cpp`, `fast_zero_one_inflated_beta.cpp`,
      `fast_stereotype_logit.cpp`, `fast_ordinal_regression.cpp`,
      `fast_ordinal_probit_regression.cpp`,
      `fast_ordinal_cloglog_regression.cpp`,
      `fast_ordinal_cauchit_regression.cpp`, `fast_coxph_regression.cpp`,
      `fast_logrank.cpp`.
      Not started — all 13 original files (plus `fast_poisson_glmm.cpp`,
      whose core is otherwise migrated, and `fast_gehan_wilcox.cpp`, found in
      this audit but missing from the original list) still declare `SEXP`
      as the wrapper return type. `sample_mode.cpp` correctly left alone.
- [~] TODO-11: Phase 5 — full-repo `check_core_no_rcpp.sh` sweep +
      full `package_tests/` run.
      Sweep half done: `check_core_no_rcpp.sh` now runs clean (0 violations)
      against every file that has actually been through the `EDI_CORE_ONLY`
      split — but that's only 49 of ~118 relevant files today, so this sweep
      needs re-running as Phase 2/3/4 close out the rest, not just once at
      the end. The full `package_tests/` run has not been done as part of
      this pass.
- [ ] TODO-12 (separate follow-up spec, not this one): decide RNG-stream
      strategy for the 15 excluded files, then migrate them.
      Not started.
- [x] TODO-13 (separate follow-up spec, not this one): write the pybind11
      binding layer against the now-Rcpp-free cores, adding
      `result_map_pybind.h`.
      Done, and shipped: `python/cpp/result_map_pybind.h` exists, 10
      `bindings_*.cpp` files (~3,760 lines) bind all 33 kernels / 37
      functions, and `edi_kernels` `py-v1.0.0` was published to real PyPI
      (Trusted Publisher, verified by installing from `pypi.org` into an
      independent venv and passing the full 181-test suite) — not just a
      local build. A critical sdist-install bug found 2026-08-10 was fixed
      and verified (`.post1`). Tracked in detail by a separate
      `python_bindings_package_spec.md`, whose own remaining open items
      (parameter-level docs for all 37 functions, a PyPI-specific README)
      are documentation polish, not the binding layer itself.

## Acceptance Criteria

The feature is complete when:

- No file under `EDI/src` that is part of a migrated function's core
  contains `#include <Rcpp` or the token `SEXP`, except the excluded RNG
  files and `sample_mode.cpp`.
- Every migrated function's R-visible output is bit-identical to its
  pre-migration output on the existing `package_tests/` suite.
- `RcppExports.cpp`/`RcppExports.R` regenerate via `Rscript fast_roxygenize.R`
  with unchanged exported function signatures (name, argument order, argument
  types as seen from R).
- `scripts/check_core_no_rcpp.sh` passes across `EDI/src`.
- `edi::ResultMap`/`edi::ResultValue` is the only return-building mechanism
  used by migrated core functions — no new bespoke per-function result
  structs were introduced.
