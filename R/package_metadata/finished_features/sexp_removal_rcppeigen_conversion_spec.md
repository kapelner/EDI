# SEXP Removal / RcppEigen-Only Core Conversion Spec

> **Depends on:** `interval_censored_survival_response.md` (remaining `[~]` survival-file conversions are blocked on the y/y_L/y_R migration). Its conventions (Eigen::Map params, `edi::ResultMap`, `EDI_CORE_ONLY`) are prerequisites for every new-kernel plan. (Global ordering: see `_master.md`.)

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

- [performance_profiling_and_upgrades.md](../new_feature_plans/performance_profiling_and_upgrades.md) — do not duplicate
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
- Do not touch `new_feature_plans/performance_profiling_and_upgrades.md`-tracked optimizations; if a
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
- [x] TODO-5: Phase 2 — zero-copy input cleanup across the 51 `_sexp`-pattern
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
      **Update 2026-08-13: the `X`/`beta`/`params`/`Xzi` gap closed.** The
      design-matrix and coefficient-vector parameters in `fast_ols.cpp`,
      `fast_log_binomial_regression.cpp` (8 functions), `fast_robust_regression.cpp`,
      `fast_zinb.cpp`, `fast_gee.cpp`, and `fast_weibull_regression.cpp` (6
      functions, found in the same audit though not in the original named
      list) were converted from raw `SEXP` to `const Eigen::Map<Eigen::MatrixXd>&`/
      `const Eigen::Map<Eigen::VectorXd>&`, removing the manual
      `NumericMatrix`/`NumericVector` coercion boilerplate at each call site.
      This is a strictly narrower, safe slice of the `y`/`dead`/`weights`
      exception above: `X` (a model/design matrix) and `beta`/`params`
      (optimizer coefficient vectors) are always plain doubles in R — never
      subject to the `rbinom`-returns-int/`rnbinom`-returns-double ambiguity
      that motivates leaving `y`/`dead`/`weights`/`m_vec` on `SEXP` — so
      converting them doesn't touch anything the active `y`/`dead` →
      `y`/`y_L`/`y_R` migration cares about. `fast_jonckheere_terpstra.cpp`
      (also named in the original gap list) turned out to have no `X`/`beta`
      parameter at all, just `y`/`w` — already correctly exempt, nothing to
      do. **Real bug caught and fixed during this pass:** the first attempt
      at `fast_zinb_cpp` renamed its two matrix parameters from `X`/`Xzi` to
      `Xc`/`Xz` (to disambiguate from the internal `X`/`Xzi` local vars) —
      this broke R's argument partial-matching, since `X` in a call like
      `fast_zinb_cpp(X = ..., Xzi = ...)` no longer unambiguously matched
      either name (`argument 1 matches multiple formal arguments`), caught by
      `test-rcpp-fitting-real-data.R`. Fixed by keeping the exact original
      R-facing parameter names (`X`, `Xzi`, `beta`, `params`) on every
      converted function — verified by grepping `R/*.R` for existing
      named-argument call sites (`X = `, `params = `, etc.) before each
      rename decision, not just by re-running tests. Verified: full
      recompile clean; every existing test exercising these 6 files
      (`test-gee-warm-start.R`, `test-kk-gee-parity.R`,
      `test-ols-symmetric-crossprod-dsyrk.R`, `test-rcpp-fitting-equivalence.R`,
      `test-rcpp-fitting-real-data.R`, `test-robust-regression-mad.R`,
      `test-robust-regression-xtx-cache.R`, `test-warm-start-weights.R`,
      `test-weibull-aft-buffer-reuse.R`, `test-weibull-general-censoring.R`,
      `test-zinb-operator-workspace.R`, `test-zinb-std-lgamma.R`,
      `test-brt-smoothed-robust-regr-kernel.R`, `test-brt-smoothed-weibull-kernel.R`,
      `test-kk-gee-fallback.R`, `test-kk-ols-se.R`, `test-kk-robust-fallbacks.R`,
      `test-kk-robust-regr-use-rcpp.R`, `test-kk21-beta-std-lgamma.R`,
      `test-kk21-negbin-fast-digamma.R`, `test-kk21-weighted-crossprod.R`,
      `test-weibull-frailty.R`, `test-weibull-marginal.R`,
      `test-zero-augmented-poisson-hessian-workspace.R`,
      `test-zero-augmented-poisson-log1m.R`) pass with 0 failures, **except**
      `test-brt-weibull-kernel-matches-reference.R`'s second test (`the fast
      Weibull BRT kernel matches the generic per-draw fallback`), which fails
      for a reason unrelated to this change: `bootstrap_subset_inference`'s
      sub-design object has a `NULL` `dead` field immediately after
      construction (confirmed by direct inspection at the R6-object level,
      before any C++ call happens), and `inference_all_abstract_rand.R`
      (which owns the `dead`/`y_L`/`y_R` sync logic touched here) shows as
      concurrently modified (`git diff --stat`) by the in-progress
      `y`/`dead` → `y`/`y_L`/`y_R` migration mentioned above — this is that
      migration's own transitional breakage, not a regression from the
      `SEXP` cleanup. Remaining genuine gap in this TODO: the
      `y`/`dead`/`w`/`weights`/`m_vec` parameter family itself (the
      permanent exception, unaffected by this update) plus whatever
      individual functions elsewhere still have unconverted `X`/`beta`-shaped
      `SEXP` params that a full `grep -n "SEXP" *.cpp | grep -v RcppExports`
      sweep (not yet re-run after this pass) would surface.
      **Done 2026-08-16.** Re-ran the full sweep this TODO's own text
      flagged as outstanding: `grep -noE "SEXP [a-zA-Z_][a-zA-Z0-9_]*" *.cpp`
      across every file, filtered to non-`y`/`dead`/`w`/`weights`/`m_vec`
      names. Found zero remaining `X`/`beta`/`params`-shaped stragglers of
      the kind this TODO targets — the earlier 6-file pass had already
      caught all of those. What the fresh sweep *did* catch (a different
      shape than what this TODO's text anticipated: `SEXP` as a *return*
      type, matched by the same regex against the `SEXP funcname(` line)
      was `fast_cpoisson_combined.cpp`/`fast_clogit_plus_glmm.cpp`'s 6
      leftover score/Hessian functions and `fast_survival_models_optim.cpp`'s
      4 — all fixed as part of TODO-9/TODO-10's updates above, since
      that's squarely their scope (raw-`SEXP`-return migration), not this
      one's (zero-copy `SEXP`-*argument* cleanup). This TODO's own scope is
      therefore now fully closed: every `X`/`beta`/`params`-shaped argument
      in `EDI/src` is a concrete `Eigen::Map<...>`, and the only remaining
      `SEXP` arguments anywhere are the permanent `y`/`dead`/`w`/`weights`/
      `m_vec` exception (storage-mode ambiguity, documented above) or
      genuine R-boundary necessities (R6/XPtr object handles, dispatch on
      R vector type, attribute names) that were never in scope to begin
      with.
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
- [x] TODO-8: Phase 3 — migrate incidence/survival/proportion-family
      `List::create` files.
      Primary survival/proportion fitting functions done (`fast_weibull_regression.cpp`,
      `fast_weibull_frailty.cpp`, `fast_zero_one_inflated_beta.cpp`,
      `fast_zero_augmented_poisson.cpp`); `fast_coxph_regression.cpp` and
      `fast_logrank.cpp` still call `List::create` (also overlaps TODO-10).
      **Done 2026-08-16**, after the `y`/`dead` → `y`/`y_L`/`y_R` migration
      landed and the standing block was re-evaluated (see TODO-10's own
      entry for the full re-check — the short version: Cox/logrank/
      Gehan-Wilcox/Clayton-copula/dep-cens-transform all turned out to be
      permanently on `y`/`dead` by architectural design, delegating to
      `icenReg`/`interval` for interval-censored dispatch at the R layer
      rather than ever reaching these C++ kernels, so there was never
      further ground to shift under them). `fast_coxph_regression.cpp`'s
      own `List::create` turned out to already be gone by the time this
      landed (only a trivial `List::create()` empty-list sentinel remains,
      not worth touching) — its actual remaining `SEXP` gap was two
      external-pointer-returning cache builders, not `List::create` at all;
      see TODO-10 for that fix. `fast_logrank.cpp` (and, found in the same
      pass, `fast_gehan_wilcox.cpp` — identical shape, both build a
      6-field all-scalar result) converted from `wrap(List::create(...))`
      to `edi::to_rcpp_list(edi::ResultMap()...)`, return type retyped
      `SEXP` → `List`. Verified: see TODO-10's shared verification note
      below (same recompile + test pass covers both TODOs).
- [x] TODO-9: Phase 3 — migrate KK-combined/GLMM `List::create` files
      (`fast_clogit_plus_glmm.cpp`, `fast_cpoisson_combined.cpp`, and
      similarly state-heavy files).
      Done — both named files plus `fast_gee.cpp`, `fast_gaussian_lmm.cpp`,
      `fast_logistic_glmm.cpp`, `fast_ordinal_glmm.cpp`, `fast_ordinal_clmm.cpp`,
      `fast_hurdle_poisson_glmm.cpp` all build results via `edi::ResultMap`.
      **Update 2026-08-16:** `List::create`/`edi::ResultMap` usage in both
      named files was already correct when re-checked, but 6 of their
      score/Hessian functions (3 each) still declared `SEXP` as the return
      type wrapping a plain `wrap(VectorXd/MatrixXd)` — found during
      TODO-10's fresh sweep, since TODO-9 only ever checked `List::create`,
      not return types. Retyped all 6 to concrete `Eigen::VectorXd`/
      `Eigen::MatrixXd`, dropping the now-redundant `wrap()`. See TODO-10
      for verification.
- [x] TODO-10: Phase 4 — migrate the remaining raw-`SEXP`-return files:
      `fast_survival_models_optim.cpp`, `fast_zero_one_inflated_beta.cpp`,
      `fast_stereotype_logit.cpp`, `fast_ordinal_regression.cpp`,
      `fast_ordinal_probit_regression.cpp`,
      `fast_ordinal_cloglog_regression.cpp`,
      `fast_ordinal_cauchit_regression.cpp`, `fast_coxph_regression.cpp`,
      `fast_logrank.cpp`.
      **Half done 2026-08-12.** All 13 original files (plus
      `fast_poisson_glmm.cpp`, whose core is otherwise migrated, and
      `fast_gehan_wilcox.cpp`, found in this audit but missing from the
      original list) still declared `SEXP` as the wrapper return type;
      `sample_mode.cpp` correctly left alone. Converted the 7 files with no
      `dead`/`y_L`/`y_R` overlap with the active response-representation
      migration: `fast_zero_one_inflated_beta.cpp`
      (`get_zero_one_inflated_beta_score_cpp`/`_hessian_cpp`),
      `fast_stereotype_logit.cpp`
      (`get_stereotype_logit_score_cpp`/`_hessian_cpp`),
      `fast_ordinal_regression.cpp`
      (`get_ordinal_regression_score_cpp`/`_hessian_cpp`),
      `fast_ordinal_probit_regression.cpp`,
      `fast_ordinal_cloglog_regression.cpp`,
      `fast_ordinal_cauchit_regression.cpp` (same score/hessian pair each),
      and `fast_poisson_glmm.cpp` (`fast_poisson_glmm_cpp`,
      `get_poisson_glmm_score_cpp`/`_hessian_cpp`). All were the same
      shape: a manual `wrap(...)`/`wrap(-...)` call wrapping an
      `Eigen::VectorXd`/`MatrixXd` (or, for `fast_poisson_glmm_cpp`, an
      already-built `edi::to_rcpp_list(...)` `List`) inside a declared-`SEXP`
      signature — retyped the return type to the concrete
      `Eigen::VectorXd`/`Eigen::MatrixXd`/`List` and dropped the now-redundant
      `wrap()`, letting Rcpp's own attribute-exporter type traits do the
      SEXP conversion (matching the pattern `fast_weibull_regression.cpp`'s
      `get_weibull_regression_score_cpp`/`_hessian_cpp` already used).
      **Left blocked, not converted:** `fast_survival_models_optim.cpp` (21
      `dead`/`y_L`/`y_R` refs), `fast_coxph_regression.cpp` (33),
      `fast_logrank.cpp` (14), `fast_gehan_wilcox.cpp` (11) — all
      survival-family files deep in the active `y`/`dead` → `y`/`y_L`/`y_R`
      migration, same reasoning as TODO-8. Verified: full recompile clean
      (0 errors); runtime smoke test of all 7 converted files' score/Hessian
      (and `fast_poisson_glmm_cpp`'s full fit, both `estimate_only=TRUE` and
      the matched-pair-shaped default) confirmed correct numeric values —
      one smoke-test crash (`double free or corruption`) turned out to be
      test-script misuse, not a regression: `fast_poisson_glmm_cpp` is a
      matched-pair (group size exactly 2) kernel, and feeding it group size
      10 hit a pre-existing buffer-sizing assumption unrelated to this
      change; re-run with correctly-shaped matched-pair data (mirroring
      `test-glmm-cpp-equivalence.R`'s own fixture) passed cleanly and matched
      expected `lme4::glmer` reference values. Existing tests
      `test-custom-implementation-canonical-reductions.R` (18),
      `test-ordinal-cloglog-exp-cache.R` (7),
      `test-rcpp-fitting-equivalence.R` (68), `test-ordinal-gcomp-post-fit.R`
      (8), `test-glmm-cpp-equivalence.R` (11),
      `test-ordinal-cauchit-level-cache.R` (3),
      `test-ordinal-information-reuse.R` (6),
      `test-poisson-glmm-buffer-reuse.R` (19), and
      `test-stereotype-logit-hessian-allocs.R` (18) all pass with 0 failures.
      **Done 2026-08-16.** Confirmed the `y`/`dead` → `y`/`y_L`/`y_R`
      migration is complete (`interval_censored_survival_response.md`
      TODO-1 through TODO-9/13-18 all `[x]`) — but re-checked the 4
      previously-blocked files directly rather than assuming that unblocks
      them: `grep -c "y_L\|y_R"` is 0 in all of
      `fast_survival_models_optim.cpp`/`fast_coxph_regression.cpp`/
      `fast_logrank.cpp`/`fast_gehan_wilcox.cpp`, and that doc's own
      "Feasibility By Inference Type" section explains why —
      `InferenceSurvivalCoxPHRegr`/`StratCoxPHRegr` dispatch to
      `icenReg::ic_sp()` and `InferenceSurvivalLogRank`/`GehanWilcox`
      dispatch to `interval::ictest()` at the **R layer** for interval-
      censored input, keeping the existing `survival::coxph()`/
      `survdiff()`-shaped C++ kernels on `y`/`dead` untouched for ordinary
      right-censored data — these 4 files were never going to gain
      `y_L`/`y_R` support, migration or not, so the original "wait for the
      migration" framing was itself imprecise (nothing was ever going to
      unblock them through that path); `fast_survival_models_optim.cpp`
      backs `InferenceSurvivalKKClaytonCopulaIVWC`/`OneLik` and
      `InferenceSurvivalDepCensTransformRegr`, both explicitly flagged in
      that same document as Tier-3 "hard, structural, second-wave" work
      needing their own future feasibility report — same conclusion.
      Converted: `fast_survival_models_optim.cpp`'s 4 SEXP-returning score/
      Hessian functions (`get_clayton_weibull_aft_score_cpp`/`_hessian_cpp`,
      `get_dep_cens_transform_score_cpp`/`_hessian_cpp`) — same `wrap(...)`-
      wrapping-a-concrete-type shape as the 7 files above, retyped
      identically. `fast_coxph_regression.cpp`'s two cache-builder functions
      (`build_cox_data_cache_cpp`/`build_stratified_cox_data_cache_cpp`)
      return `Rcpp::XPtr<std::vector<CoxData>>`, not a plain `wrap()`
      value — first attempt retyped the declared return/parameter type from
      `SEXP` to the concrete `Rcpp::XPtr<std::vector<CoxData>>`, matching
      this TODO's usual pattern, but that doesn't compile: `CoxData` is
      defined in an anonymous namespace local to this one `.cpp` file
      (internal linkage), and `RcppExports.cpp` forward-declares each
      exported signature in its own separate translation unit where
      `CoxData` is neither visible nor (because of the anonymous namespace)
      shareable at all regardless of includes — confirmed by a real build
      failure (`'CoxData' was not declared in this scope`), not just
      reasoned about. Reverted those 3 signatures to `SEXP`, matching
      `sample_mode.cpp`'s existing precedent: a genuine, permanent exception
      to this spec's general "retype away from SEXP" rule, for the same
      underlying reason (the concrete type Rcpp would need to expose isn't
      one `RcppExports.cpp` can ever see). `fast_gehan_wilcox.cpp` got
      TODO-8's `List::create` → `edi::ResultMap` treatment (see that TODO).
      A fresh, non-mechanical `grep -n "SEXP" *.cpp | grep -v RcppExports`
      sweep (the thing TODO-5/14 flagged as never having been re-run) also
      turned up `fast_cpoisson_combined.cpp` (3 functions) and
      `fast_clogit_plus_glmm.cpp` (3 functions) — flagged in an earlier pass
      this session but never actually converted when that pass's focus
      shifted to `List::create` ownership decisions instead; same
      `wrap(VectorXd/MatrixXd)`/already-`edi::to_rcpp_list`-built-`List`
      shape as everything else here, retyped identically. After this pass,
      `grep -n "^SEXP " *.cpp` across the whole `src/` tree returns exactly
      one hit: `sample_mode.cpp`, the sole documented, intentional
      exception. Verified: `Rcpp::compileAttributes(".")` regenerated
      `RcppExports.cpp`/`.R` cleanly with all R-facing parameter names
      unchanged; targeted recompile (only the 6 touched files +
      `RcppExports.cpp`, not a full rebuild) succeeded with 0 errors after
      the `CoxData`/XPtr revert; manual smoke test of
      `fast_logrank_stats_cpp`/`fast_gehan_wilcox_stats_cpp`/
      `build_cox_data_cache_cpp`+`fast_coxph_regression_prebuilt_cpp`/
      `fast_coxph_regression_cpp`/`get_coxph_score_cpp` confirmed correct
      values (score ≈ 0 at the fitted MLE, prebuilt-cache and direct-fit
      paths agree bit-for-bit); 18 existing test files covering every
      touched function (`test-brt-smoothed-coxph-kernel.R`,
      `test-brt-smoothed-logrank-kernel.R`, `test-clogit-glmm-buffer-reuse.R`,
      `test-clogit-plus-glmm-cpp-equivalence.R`,
      `test-cox-component-composition.R`,
      `test-coxph-hessian-symmetric-writes.R`, `test-coxph-robust-vcov.R`,
      `test-dep-cens-transform-fast-pnorm.R`,
      `test-gehan-wilcox-fused-martingale.R`, `test-logrank-fused-martingale.R`,
      `test-logrank-gehan-wilcox-general-censoring.R`,
      `test-partial-likelihood-migration-baseline.R`,
      `test-rcpp-fitting-equivalence.R`, `test-rcpp-fitting-real-data.R`,
      `test-todo98-new-kernel-smoke.R`, plus `test-bayesian-bootstrap.R`,
      `test-custom-implementation-canonical-reductions.R`,
      `test-design-inference.R` for broader regression coverage) all pass
      with 0 failures, **except** one pre-existing, unrelated failure in
      `test-design-inference.R` (`InferenceOrdinalKKCondAdjCatLogitRegr`
      QR-rank hardening) — confirmed unrelated: that class has nothing to
      do with any file touched in this pass.
- [x] TODO-11: Phase 5 — full-repo `check_core_no_rcpp.sh` sweep +
      full `package_tests/` run.
      **Done 2026-08-13.** `check_core_no_rcpp.sh` runs clean: 55 migrated
      files checked (up from 49), 61 not-yet-migrated files correctly
      skipped, 0 violations. This count will keep climbing as Phase 2/3/4
      close out the rest (TODO-5/8/10 remain `[~]`, blocked on the active
      `y`/`y_L`/`y_R` migration) — re-run whenever those advance, not just
      once at the end.
      `package_tests/`'s `run_comprehensive_suite.R ci` tier run: first
      attempt was a false positive — `EDI` wasn't formally installed
      (`system.file(package="EDI")` empty; this repo is normally only
      loaded via `pkgload::load_all()`/`devtools::load_all()`, never
      `R CMD INSTALL`'d), so the `comprehensive_harness` subprocess step's
      `library(EDI)` call failed immediately (0.19s, 0 rows) but the harness
      still recorded `status="ok"` — caught by manually re-running the exact
      subprocess command and seeing the real error, not by trusting the CSV.
      After `EDI` was properly installed, re-ran with `--force`: all 5 CI
      steps (`argument_combinations` 29 rows, `comprehensive_harness` 0
      tracked rows but a real ~7s run producing `All tests complete!`,
      `dependency_gate` 11 rows, `internal_safety_nets` 239 rows/90s,
      `public_workflow_coverage` 277 rows) status `"ok"`, and both
      `comprehensive_suite_failures.csv` and
      `public_argument_combination_failures.csv` are header-only (0
      failures). `comprehensive_tests.R`'s own console output shows repeated
      `Skipping design (seq error): y_L was supplied without y_R` lines —
      the harness's own built-in skip-on-error handling for the in-progress
      `y`/`y_L`/`y_R` migration, not a suite failure. Only the `ci` tier was
      run (600s timeout, `bounded_filtered_run`/`small` resampling); the
      slower `nightly`/`release` tiers (`comprehensive_suite_runtime_tiers.R`)
      were not run this pass.
- [x] TODO-12 (separate follow-up spec, not this one): decide RNG-stream
      strategy for the 15 excluded files, then migrate them.
      Done. Strategy: draw exactly one value from R's live stream
      (`R::unif_rand()`) per call (or per OpenMP thread) to seed a local
      `edi_rng::RRng` -- a from-scratch, dependency-free, header-only port of
      R's actual Mersenne-Twister + Inversion normal generator (`RNG.h`),
      bit-exact-verified against live R `runif()`/`rnorm()` output. All
      RNG-touching downstream work runs on that local instance, decoupled
      from R's global state -- giving OpenMP-safety, `EDI_CORE_ONLY`
      portability, and genuine cross-language (R/Python/...) reproducibility
      for a given seed, without the complexity of continuing R's live
      `.Random.seed` stream. Migrated: `atkinson_assign.cpp`,
      `pocock_simon_assign.cpp` (assign functions), `bootstrap_indices.cpp`,
      `bootstrap_match_indices.cpp`, `fast_sample_int.cpp`,
      `sample_bootstrap_distr_weighted_distances.cpp`,
      `generate_permutations.cpp` (9 exported functions),
      `exchangeable_resampling_draws.cpp`, `design_fixed_greedy.cpp`,
      `rerandomization_helpers.cpp`, `binary_match_search.cpp`,
      `fast_shuffle.cpp`, `optimal_design_search.cpp` (2 functions),
      `random_block_size_speedups.cpp`, `spbr_speedups.cpp` (2 functions) --
      15 files. The last 4 of those were a later addition: they used
      `std::random_device`/system-clock seeding (not tied to R's RNG at all,
      so never `set.seed()`-reproducible to begin with) rather than
      `unif_rand()`, found via a second `grep` sweep for
      `mt19937|default_random_engine` after the initial 11-file pass; folded
      into the same pattern rather than left as a separate follow-up.
      `pocock_simon_redraw_w_cpp` got different, higher-risk treatment:
      it reads/writes R's live `.Random.seed` directly (via
      `rrng_from_live_r_state()`/`write_rrng_state_to_r()`), continuing R's
      actual stream rather than seeding fresh -- required because it has a
      real test asserting bit-exact match against a hand-written pure-R
      reference loop. Note this makes it the one function in the sweep that
      is NOT `EDI_CORE_ONLY`-portable. Deliberately left out of scope:
      `simulation_dgp.cpp` (`R::rbeta`/`R::rpois`/`R::rweibull` -- too many
      other R-only dependencies to port). Verified: full recompile clean (0
      errors); comprehensive smoke test across all touched functions
      (self-consistency under matching `set.seed()`, plus
      `pocock_simon_redraw_w_cpp`'s bit-exact-vs-pure-R check) all pass; ran
      every existing `testthat` file exercising touched code (permutations,
      bootstrap, pocock-simon, atkinson, greedy design, rerandomization,
      binary-match, optimal-design-search, stratified-bootstrap,
      random-block-size) -- 0 failures. One apparent failure
      (`rerandomization_search_cpp` under `identical()` across two runs) was
      diagnosed as pre-existing OpenMP work-stealing non-determinism (which
      thread claims which chunk/result-slot is decided by real-time OS
      scheduling via `std::atomic` `fetch_add`, not by RNG state) --
      confirmed via `OMP_NUM_THREADS=1`, which reproduces bit-exactly; not a
      regression from this change, and unrelated to the pre-existing
      `y`/`y_L`/`y_R` inference-hierarchy migration failures seen in
      `test-rand-bootstrap.R` (confirmed via `git diff --stat` that this
      change never touched `other_helpers.R`, the file driving that
      migration).
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
- [x] TODO-14: full accounting pass — everything the mechanical `_sexp`/
      `List::create` scans in TODO-5/6/7/8/9/10 missed.
      Opened 2026-08-13 after auditing `grep -l "List::create" *.cpp` /
      `grep -n "SEXP" *.cpp` directly rather than trusting the earlier
      TODOs' file lists: found 12 files with `List::create` never named in
      any TODO (`bootstrap_match_indices.cpp`, `build_info.cpp`,
      `build_kk_combined_clogit_design.cpp`, `compute_all_subject_data.cpp`,
      `exchangeable_resampling_draws.cpp`, `gcomp_speedups.cpp`,
      `kk_bootstrap_reservoir_stats.cpp`, `kk_cluster_ids.cpp`,
      `kk_lin_match_data.cpp`, `randomization_loop.cpp`,
      `survival_strata_ids.cpp`, `zhang_exact_speedups.cpp`) plus 2 files
      with un-migrated `SEXP`-returning functions
      (`fast_cpoisson_combined.cpp`, `fast_clogit_plus_glmm.cpp`) — all 14
      confirmed clear of the active `y`/`dead`/`y_L`/`y_R` migration
      (`grep -c "\bdead\b\|y_L\|y_R"` = 0 in each).
      **Decision: `List::create` in these 14 files is explicitly out of
      scope, not merely deferred.** None of them are bound into the Python
      layer (`python/CMakeLists.txt`/`bindings_*.cpp` don't reference them),
      so the only real beneficiary of an `edi::ResultMap` conversion — a
      single Rcpp-free core shared by both the R wrapper and a pybind11
      wrapper — doesn't apply; converting anyway would just add
      `ResultMap`'s measured ~8.7us double-copy overhead per call (see
      `new_feature_plans/performance_profiling_and_upgrades.md` TODO-130) on the R-only path for no
      benefit. Left as `List::create`, permanently, unless one of these
      files later gains a Python binding.
      **`SEXP`-argument cleanup done instead** (this MISSING part actually
      matters on the R-only path too, since it's paid on every call
      regardless of language): folded into TODO-5's update above --
      `fast_ols.cpp`, `fast_log_binomial_regression.cpp`,
      `fast_robust_regression.cpp`, `fast_zinb.cpp`, `fast_gee.cpp`,
      `fast_weibull_regression.cpp` converted from raw `SEXP` `X`/`beta`/
      `params`/`Xzi` parameters to `const Eigen::Map<Eigen::MatrixXd>&`/
      `const Eigen::Map<Eigen::VectorXd>&`, eliminating one manual
      `NumericMatrix`/`NumericVector` coercion + copy per call. Not done:
      a fresh, non-mechanical `grep -n "SEXP" *.cpp` sweep across the
      remaining ~90 files with `SEXP` parameters was not attempted this
      pass (most matches are the permanent `y`/`dead`/`weights`/`m_vec`
      exception or R6/XPtr/dispatch parameters that must stay `SEXP` --
      see the two rejected `AskUserQuestion` framings above -- but a few
      more `X`/`beta`-shaped stragglers, of the same shape just closed
      here, likely remain unaudited).
      **Done 2026-08-16.** Ran that deferred fresh sweep (folded into
      TODO-5's own re-run — see that TODO's update). Result: zero remaining
      `X`/`beta`/`params`-shaped `SEXP` argument stragglers anywhere in
      `src/`. The sweep did surface the two files this TODO's own text had
      already named as still having un-migrated `SEXP`-*returning*
      functions (`fast_cpoisson_combined.cpp`, `fast_clogit_plus_glmm.cpp`,
      3 functions each) — fixed as part of TODO-9/TODO-10 above, since a
      return-type fix is squarely those TODOs' scope. Also converted (also
      via TODO-10, once the survival-migration block cleared):
      `fast_survival_models_optim.cpp`'s 4 SEXP-returning functions and
      `fast_coxph_regression.cpp`'s 2 XPtr cache-builders (the latter
      staying on `SEXP`, for a newly-documented, genuine reason — see
      TODO-10). After `grep -n "^SEXP " *.cpp`, the only remaining hit
      anywhere in `src/` is `sample_mode.cpp`'s original, intentional,
      documented exception. This TODO's full accounting pass — the thing
      it was opened to do — is complete: every file with `List::create` or
      a raw-`SEXP` argument/return has now been either converted or
      explicitly, permanently exempted with a stated reason (Python-binding
      irrelevance, `ResultValue`'s missing integer-vector/nested-list
      support, storage-mode ambiguity, or genuine R-boundary necessity like
      XPtr/R6/dispatch-on-type).
- [x] TODO-15: Decide ownership of the two OLS-adjacent `List::create` files
      left dangling by TODO-6 (`match_data_compute_speedup.cpp`,
      `qr_reduce_design_matrix.cpp`) — TODO-6 deferred them to "whichever of
      TODO-7/8 (or a dedicated cleanup pass) actually owns them", but they
      appear in neither, nor in TODO-14's 14-file out-of-scope list. Apply
      TODO-14's rule: if they stay R-only (not referenced by
      `python/CMakeLists.txt`/`bindings_*.cpp`), record them as permanently
      out of scope like the other 14; otherwise convert them.
      **Done 2026-08-14.** Neither file appears in `python/CMakeLists.txt`
      or any `bindings_*.cpp` (`grep -rn` came back empty for both names) —
      confirmed R-only, so TODO-14's rule applies: permanently out of scope,
      joining the other 14. `qr_reduce_design_matrix.cpp` additionally has
      an `IntegerVector` `keep` field in every one of its three
      `List::create` call sites, which `edi::ResultValue` can't represent
      even if it were Python-bound (the same int-vector gap flagged
      repeatedly elsewhere in this spec) — a second, independent reason to
      leave it alone. `match_data_compute_speedup.cpp`'s single
      `List::create` (`compute_matching_wy_stats_cpp`) just re-packages
      fields already pulled out of another function's `List` return
      (`compute_zhang_match_data_cpp`, itself untouched `List::create`) —
      not core numeric-fitting logic, nothing to gain by touching it.
- [x] TODO-16: Add cheap input validation to `fast_poisson_glmm_cpp` (and
      audit its sibling matched-pair GLMM kernels) for the matched-pair
      group-size assumption. TODO-10's smoke testing showed that feeding it
      group size 10 crashes the R session with heap corruption
      (`double free or corruption`) from a pre-existing buffer-sizing
      assumption instead of failing cleanly. These are exported,
      user-reachable functions; malformed group structure should `stop()`
      with a clear message, never corrupt memory.
      **Done 2026-08-14.** Root cause wasn't the matched-pair group-size
      assumption itself (`PoissonGLMMData`/`PoissonGLMMObjective` size their
      scratch buffers dynamically off the actual max group size, verified by
      reading the code and by direct reproduction attempts with a single
      size-10 group, which ran fine) — it was that `fast_poisson_glmm_cpp`
      (the main fit entry point) validates `X`/`y`/`group_id` dimension
      consistency, but its sibling `get_poisson_glmm_score_cpp`/
      `get_poisson_glmm_hessian_cpp` never did, so a mismatched `y` or
      `group_id` (or a `par` of the wrong length) reads past the end of an
      `Eigen::Map`'s buffer — undefined behavior, not deterministic, matches
      the "double free or corruption" symptom. Reproduced directly:
      `get_poisson_glmm_score_cpp(X, y[1:3], group_id, par)` with `X` at 10
      rows silently returned garbage instead of crashing or erroring (UB,
      not guaranteed to crash every time). Auditing "sibling matched-pair
      GLMM kernels" found the identical gap in every getter-style function
      across the GLMM family, not just Poisson: `fast_logistic_glmm.cpp`
      (`get_logistic_glmm_score_cpp`/`_hessian_cpp`/`_neg_loglik_cpp`),
      `fast_hurdle_poisson_glmm.cpp` (6 functions: score/hessian/neg_loglik,
      each in a weighted and unweighted variant — the weighted ones were
      the worst case, indexing `group_id_r[i]` up to `X_r.rows()` inside a
      loop that runs unconditionally before any size check), and
      `fast_gaussian_lmm.cpp` (`get_gaussian_lmm_score_cpp`/`_fisher_cpp`,
      plus `fast_gaussian_lmm_gls_cpp` which has the same unchecked
      `group_id_r.data()` read). Added a `Rcpp::stop()` dimension check
      (`X.rows() == y.size() == group_id.size()`, plus `weights.size()`
      where applicable) and a `par`/`params` length check
      (`== ncol(X) + 1`) at the top of all 12 affected functions across the
      4 files, matching the exact error-message style
      `fast_poisson_glmm_cpp` already used. `fast_ordinal_glmm.cpp`,
      `fast_ordinal_clmm.cpp`, `fast_clogit_plus_glmm.cpp`, and
      `fast_cpoisson_combined.cpp` were also audited but have no
      getter-style functions in this shape — nothing to fix there.
      Verified: mismatched `y`, mismatched `group_id`, and mismatched
      `par`/`params` all now `stop()` with a clear message instead of
      silently misreading memory, confirmed for one function per file;
      valid inputs still produce identical output to before. Existing
      tests (`test-fast-log1pexp.R`, `test-gaussian-lmm-hessian-prealloc.R`,
      `test-glmm-cpp-equivalence.R`, `test-hurdle-poisson-glmm-buffer-reuse.R`,
      `test-hurdle-poisson-glmm-log1p-fast-path.R`,
      `test-poisson-glmm-buffer-reuse.R`, `test-rcpp-fitting-equivalence.R`)
      all pass with 0 failures.
- [x] TODO-17: Fix the `package_tests` comprehensive-suite harness
      false-positive found during TODO-11: the `comprehensive_harness` step
      recorded `status = "ok"` even though its subprocess died immediately
      (the `library(EDI)` call failed; 0.19s runtime, 0 tracked rows, still
      "ok") — caught only by manually re-running the exact subprocess
      command. The harness must treat subprocess startup failure / zero
      executed work as a failure, not success, or every future regression
      sweep that hits an environment problem will silently pass.
      **Done 2026-08-14 — with a corrected root cause.** The original
      diagnosis (a bug in `run_command_step`'s exit-status capture) turned
      out to be wrong on direct investigation: renaming the installed `EDI`
      library directory out of the way (so a subprocess `Rscript` genuinely
      can't find it) and re-running `run_command_step`'s exact `system2()`
      call in isolation correctly captured `status = 1` and the real error
      text every time, both standalone and through the full
      `run_comprehensive_suite.R ci --force` path — the exit-code capture
      mechanism itself is sound. Confirmed the real cause directly: mid-test,
      the renamed-away `EDI` directory reappeared on disk with a fresh
      timestamp while nothing in this session touched it — this repo's
      concurrent, independent auto-install tooling (mentioned throughout
      this document and `feedback_targeted_compile_only.md`) cycles the
      installed package in and out of existence on its own schedule.
      TODO-11's original run caught it mid-cycle: `EDI` was genuinely
      installed and the subprocess genuinely succeeded at that instant, then
      the tooling removed it again before the manual follow-up check a few
      minutes later — a real, transient environment race external to the
      harness, not a code defect. Still added a cheap, independent
      defense-in-depth check regardless, since relying solely on a numeric
      exit code from a nested `Rscript`-launches-`Rscript` call is
      inherently a little fragile across R versions/platforms even when it
      works today: `subprocess_output_has_fatal_marker()` in
      `run_comprehensive_suite.R` scans captured stdout+stderr for
      `"^Error in "` / `"^Execution halted$"` / `"there is no package
      called"` and downgrades an apparent `status = 0` to a recorded
      failure if any match, independent of whatever the raw exit code says.
      Verified: reproduced the exact original scenario (renamed `EDI` away,
      ran the full `ci`-tier suite with `--force`) and confirmed
      `comprehensive_harness` now correctly records `status = "error"`;
      restored `EDI` and re-ran, confirming the fix doesn't affect genuine
      successful runs (`comprehensive_harness` 10.6s, real duration, correct
      `"ok"`, matching the pre-fix successful-run shape).

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
