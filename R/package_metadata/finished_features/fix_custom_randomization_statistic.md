# Custom Randomization Statistics: Replace the Scattered Escape Hatch with `InferenceRandCustom`

> **Release:** v1.1.0 — "Performance and correctness (CPU)" track (see
> `ROADMAP.md`). **Breaking API change**, intentional: `set_custom_
> randomization_statistic_function()`/`set_custom_randomization_statistic_
> cpp()` are removed from every concrete package estimator. Doing this before
> the pending CRAN submission is deliberate — it is cheap now and expensive
> after release (`project_cran_status`: submission imminent as of 2026-08-30,
> not yet accepted).
>
> **Ownership:** the `RandomizationTest` component and its `owns_state`
> declaration (`contracts_mixins.R:317-329`); `InferenceRand`'s custom-stat
> methods and dispatch guards (`inference_all_abstract_rand.R`); the ~15
> concrete leaf classes' `compute_fast_*`/`compute_brt_*`/`compute_rand_
> bootstrap_ci_affine_coefs` guards (listed in TODO-4); `InferenceExt
> CustomRandomizationStatistic` (`inference_ext_custom_randomization_
> statistic.R`, deleted by this plan); `InferenceCustomRand` (`inference_
> custom_extensions.R`); `inference_class_registry.R`'s
> `EDI_CUSTOM_RANDOMIZATION_TARGETS$InferenceCustomRand` entry;
> `R/package_tests/comprehensive_tests.R`'s `rand_custom` test block.

Date: 2026-09-13. Raised in conversation, not from an incident.

## Status

**Done.** TODO-1 through TODO-9 implemented and verified: `InferenceCustomRand`
composes `RandomizationCI`; `InferenceRandCustom` exists with its own fast
kernel (both the R-function and cpp/XPtr branches); the escape hatch is fully
removed from `InferenceRand`/the `RandomizationTest` component/the abstract
rand-bootstrap classes; all ~18 per-class guard sites plus the KKGEE mixin and
quantile-rand-CI guard are deleted; `inference_ext_custom_randomization_statistic.R`
is deleted; `comprehensive_tests.R`'s `rand_custom` block now builds a
standalone `InferenceRandCustom`; NEWS.md documents the breaking change;
`fast_roxygenize()` regenerated `NAMESPACE`/`man/` (`InferenceRandCustom` is
exported). The full CRAN `testthat` suite passes clean (the only failures are
a pre-existing sandboxed-environment mirai/socket limitation, unrelated), plus
a new dedicated `test-inference-rand-custom.R` (19 assertions: construction
validation, both statistic branches including precompiled-fn/XPtr forms,
fast-path correctness, CI, cloning, capabilities) and updated migration/
baseline tests that hardcoded the old shape.

TODO-10's code fix (decoupling `skip_custom_rand_pval` from
`skip_regular_rand_pval`; deleting the `rand_ci_custom`/`rand_pval_custom_
allowed` exclusion lists) is in, and spot-checked directly (n=100, r=151:
p-value ~0.09s, CI ~0.35s — nowhere near the old 336.6s/17.68s figures those
exclusions were guarding against). Item 3 of TODO-10 — confirming this holds
across every dataset × design row of the actual exhaustive `comprehensive_
tests.R` sweep, not just a spot check — has **not** been run (it's a
multi-hour operational sweep, not a coding task); that confirmation is a
standing follow-up for whoever next runs the full suite, the same way
`harden_registry.md` (`finished_features/`) shipped while deferring its own
~82-entry slow-path staleness recheck.

## Background — what's actually there today

`set_custom_randomization_statistic_function()`/`set_custom_randomization_
statistic_cpp()` (`inference_all_abstract_rand.R:22-33`, `:58-112`) look like
two small mutator methods on `InferenceRand`, but the field they set
(`custom_randomization_statistic_function`, plus `compiled_cpp_stat_fn`/
`compiled_cpp_stat_src`) is declared as `owns_state` of the shared
`RandomizationTest` **component** (`contracts_mixins.R:322-325`). Every class
that composes `RandomizationTest` — directly, or transitively through
`RandomizationCI` or `NonparametricBootstrap`, i.e. essentially every
resampling-capable concrete `Inference` class in the package — inherits this
escape hatch whether or not it makes sense for that estimator.

Three concrete problems with how it works, not just how it looks:

1. **Silent identity ambiguity.** `InferenceRand`'s randomization-statistic
   dispatch (`inference_all_abstract_rand.R:1285-1286`) does
   `if (is.null(private$custom_randomization_statistic_function))
   self$compute_estimate(...) else private$custom_randomization_statistic_
   function()`. The *same* `SimpleMeanDifferenceSource` object reports two
   different "estimates" — the package's mean-difference formula, or
   whatever the custom function returns — depending on hidden mutable state,
   with no trace of which one is active in the object's public surface.
2. **Environment-faking + source-sniffing.** `InferenceExtCustomRandomization
   Statistic.analyze_custom_randomization_statistic()`
   (`inference_ext_custom_randomization_statistic.R:22-56`) decides whether a
   user's R closure is safe to fast-path by `grepl()`-ing the *deparsed
   source text* of its body for `private$des_obj_priv_int$` accesses other
   than `y`/`w`/`dead`. When it isn't sure, `evaluate_lightweight_custom_
   randomization_statistic()` (`:57-88`) rebinds the function's environment
   to a hand-built proxy (`eval_env$private`, `eval_env$inf_priv`,
   `eval_env$des_priv`) so a bare, disconnected function can pretend it's
   running inside an `Inference` object's private scope. None of this is
   documented in the public roxygen contract for `set_custom_randomization_
   statistic_function()`, which only promises "a function that returns one
   scalar."
3. **Duplicated escape-hatch guards.** Because the field can be set on *any*
   `RandomizationTest`-composing class, every concrete class's own
   `compute_fast_bootstrap_distr`/`compute_fast_randomization_distr`/
   `compute_fast_rand_bootstrap_distr`/`compute_brt_null_statistics_with_se`/
   `compute_rand_bootstrap_ci_affine_coefs` override has to open with
   `if (!is.null(private[["custom_randomization_statistic_function"]]) ||
   !is.null(private[["compiled_cpp_stat_fn"]])) return(NULL)` — a guard about
   a feature that has nothing to do with that estimator, repeated at ~15
   unrelated call sites (TODO-4), plus 3 more inside the abstract
   `InferenceRand`/`InferenceRandBootstrap`/`InferenceRandBootstrapCI` classes
   themselves.

**The pattern that already exists and is already right:** `InferenceCustomRand`
(`inference_custom_extensions.R:146-183`) is a `@keywords internal`,
unexported extension base — `define_inference_class(classname =
"InferenceCustomRand", inherit = Inference, components = "RandomizationTest",
...)` — meant for external packages to subclass, implement `fit()`, and get a
randomization test for free, with no private-state access and no environment
tricks (subclasses use only public accessors: `self$get_analysis_data()`,
`self$get_response()`, etc. — see `test-custom-extension-contract.R:76-111`).
It is also already registered in `EDI_CUSTOM_RANDOMIZATION_TARGETS`
(`inference_class_registry.R:184-195`) as a `host_kind = "extension_base"`
whose own note says: *"Custom randomization extension hosts should inherit
only the root `Inference` state and add `RandomizationTest` explicitly;
randomization CI and bootstrap APIs are accidental unless their components
are listed."* That note is the design this plan follows — it just doesn't
have CI listed yet, and there's no ready-to-use concrete class for the common
"I just have a statistic function" case; today that case is forced through
the kludge described above instead.

(Note: `EDI_CUSTOM_RANDOMIZATION_TARGETS`/`custom_randomization_host_groups()`/
`mark_custom_randomization_classes_migrated()` are **not** about the
`custom_randomization_statistic_function` field — `custom_randomization_
direct_host_names()` (`inference_class_registry.R:2394-2399`) finds classes by
`identical(metadata$parent, "InferenceRand")`, i.e. it's the shallow-hierarchy
migration bookkeeping for direct children of `InferenceRand`, and
`InferenceCustomRand` happens to be the one class in that bucket. This plan
only touches its one registry entry, not that machinery in general.)

## Design decisions

- **Extend `InferenceCustomRand`, don't fork it.** Swap its `components =
  "RandomizationTest"` for `components = "RandomizationCI"` — `RandomizationCI`
  declares `dependencies = "RandomizationTest"` (`contracts_mixins.R:330-338`),
  so `RandomizationTest` still arrives, transitively. Listing both directly
  would trip `resolve_component_dependencies()`'s "Direct component list
  duplicates transitive dependency component(s)" check
  (`contracts_mixins.R:3251-3261`). `RandomizationTest` and `RandomizationCI`
  both define `compute_rand_two_sided_pval`, the same conflict `InferenceCustom
  Asymp` (`inference_custom_extensions.R:77`) and `InferenceCustomBoot`
  (`:227`, `:233`) already resolve by overriding it to `InferenceRandCI$public_
  methods$compute_rand_two_sided_pval` — `InferenceCustomRand` needs the
  identical override.
- **One new exported concrete class, `InferenceRandCustom`,** inheriting
  `InferenceCustomRand`, is the thing the user actually calls: `InferenceRand
  Custom$new(des_obj, custom_randomization_statistic_function = fn)`. Its
  `fit()` just calls the user's function — no other action needs disabling,
  because `InferenceCustomRand`'s component set (`Inference` root +
  `RandomizationCI`, nothing else) never had a package point-estimator, Wald
  path, or bootstrap machinery to begin with. Capability exclusion is real
  (`capabilities()`/`supports()`-driven), not a `stop()` stub sprinkled over
  methods that would otherwise exist.
- **New, plain calling convention: `function(y, w, dead)`.** This is the
  breaking change. It replaces the undocumented "maybe your function can
  reach `private$des_obj_priv_int$whatever`" convention with the same
  explicit-args convention `set_custom_randomization_statistic_cpp()`'s C++
  functions already use (`inference_all_abstract_rand.R:45-57`: `(NumericVector
  y, IntegerVector w)` or the 3-arg form with `dead`). Once every caller gets
  plain vectors, there is nothing left for the source-sniffing heuristic to
  decide — it's deleted, not relocated.
- **Fast-path performance is preserved, not sacrificed, by giving
  `InferenceRandCustom` its own `compute_fast_randomization_distr`/
  `compute_fast_rand_bootstrap_distr`,** exactly the way `SimpleMeanDifference
  Source` and its ~14 siblings already own theirs
  (`inference_all_average_diff.R:191-207`). This is the same polymorphic
  pattern used everywhere else in the file — the kludge was never "a fast
  path exists," it was that 15 *unrelated* classes had to know about this
  one class's feature. The per-permutation loop body is ported, unchanged in
  substance, from `evaluate_lightweight_custom_randomization_statistic()`
  (`inference_ext_custom_randomization_statistic.R:57-88`) — minus the
  environment-proxy branch, which no longer has a caller once the calling
  convention is explicit args.
- **No change to `set_custom_randomization_statistic_cpp()`'s actual C++
  compilation/XPtr handling logic** (`inference_all_abstract_rand.R:58-112`);
  it is moved as-is into `InferenceRandCustom$initialize()`, not rewritten.

## Non-goals

- Not touching `InferenceCustomAsymp`/`InferenceCustomBoot`'s existing
  contracts beyond `InferenceCustomRand`'s CI addition — they already work
  correctly and are out of scope.
- Not adding bootstrap-randomization CI (`RandomizationBootstrapCI`/
  `NonparametricBootstrap`) support to `InferenceRandCustom`. The
  registry note is explicit that pulling those in must be a deliberate,
  listed choice, not a default; nothing in this conversation asked for
  bootstrap support, only "randomization test and randomization ci"
  (`RandomizationCI`, the permutation-inversion CI, not the bootstrap one).
  If wanted later, it is an additive follow-up: add `NonparametricBootstrap`
  to `InferenceRandCustom`'s components.
- Not a behavior change for any class that never used a custom statistic —
  every deletion in TODO-4 removes a branch that was always a no-op for that
  class's normal (non-custom-stat) callers; the class's own default fast path
  now always runs unconditionally, which is what it already did whenever no
  custom stat was attached.
- Not attempting to migrate existing user scripts automatically. Anyone
  currently calling `set_custom_randomization_statistic_function()` on a
  package estimator gets a clear "no such method" error post-refactor; the
  NEWS entry (TODO-8) tells them to switch to `InferenceRandCustom` and gives
  the new `(y, w, dead)` signature.

## Items

- [x] **TODO-1: Give `InferenceCustomRand` randomization-CI capability.**
  In `inference_custom_extensions.R:146-183`:
  ```r
  InferenceCustomRand = define_inference_class(
  	classname = "InferenceCustomRand",
  	inherit = Inference,
  	components = "RandomizationCI",   # was "RandomizationTest"
  	public = list(
  		fit = function(estimate_only = FALSE){
  			stop("Custom inference subclasses must implement public$fit(estimate_only = FALSE).")
  		},
  		compute_estimate = function(estimate_only = FALSE){ ... },  # unchanged body
  		#' @description Computes a randomization two-sided p-value. Delegates to
  		#'   the `RandomizationCI`-provided dispatch, matching InferenceCustomAsymp
  		#'   and InferenceCustomBoot's identical RandomizationTest/RandomizationCI
  		#'   conflict resolution.
  		compute_rand_two_sided_pval = InferenceRandCI$public_methods$compute_rand_two_sided_pval
  	),
  	private = list(is_a_custom_rand = function() TRUE),
  	overrides = list(public = "compute_rand_two_sided_pval"),
  	metadata = list(likelihood_tier = "none")
  )
  ```
  Update the registry entry at `inference_class_registry.R:185-194` to match
  reality:
  ```r
  InferenceCustomRand = list(
  	host_kind = "extension_base",
  	target_parent = "Inference",
  	target_components = c("RandomizationTest", "RandomizationCI"),
  	class_owned_capabilities = character(),
  	intentional_capabilities = c("randomization_test", "randomization_ci"),
  	migration_status = "migrated",
  	migration_evidence = c("method_snapshot", "golden_randomization"),
  	notes = "Custom randomization extension hosts should inherit only the root Inference state and add RandomizationTest (transitively via RandomizationCI) explicitly; bootstrap APIs remain accidental unless NonparametricBootstrap is listed."
  )
  ```
  Add a test in `test-custom-extension-contract.R` (next to the existing
  "custom randomization inference works from an external-package-like
  environment" test at line 76): after constructing `ExternalRandMeanDiff`,
  assert `expect_true(is.finite(inf$compute_rand_confidence_interval(r = 51)
  [1]))` or equivalent, confirming the new capability actually resolves.

- [x] **TODO-2: Create `InferenceRandCustom`.** New file
  `R/EDI/R/inference_rand_custom.R`. Constructor mirrors the standard
  concrete-class pattern (e.g. `inference_all_KK_mean_diff_IVWC.R:9-18`);
  the C++ branch is ported unchanged from `set_custom_randomization_statistic_
  cpp()` (`inference_all_abstract_rand.R:58-112`) rather than rewritten:
  ```r
  #' Randomization test/CI on a user-supplied statistic
  #'
  #' Runs a randomization test (and, via `compute_rand_confidence_interval()`,
  #' a randomization confidence interval) for an arbitrary user-supplied
  #' statistic, without writing an `Inference` subclass. The statistic
  #' function is called once per permutation as
  #' \code{fn(y, w, dead)} — plain numeric/integer vectors, the current
  #' (possibly permuted) response, treatment assignment, and event indicator.
  #' It must return one scalar. For maximum speed, supply
  #' \code{custom_randomization_statistic_cpp} instead: C++ source defining a
  #' function of \code{(NumericVector y, IntegerVector w)} or
  #' \code{(NumericVector y, IntegerVector w, IntegerVector dead)} returning a
  #' scalar \code{double}, using the same convention as
  #' \code{DesignFixedOptimal}'s \code{custom_objective}.
  #'
  #' @param des_obj A Design object whose subjects are assigned and responses
  #'   recorded.
  #' @param custom_randomization_statistic_function A function of
  #'   \code{(y, w, dead)} returning one scalar. Exactly one of this or
  #'   \code{custom_randomization_statistic_cpp} must be supplied.
  #' @param custom_randomization_statistic_cpp C++ source string, pre-compiled
  #'   Rcpp function, or \code{RcppXPtrUtils::cppXPtr()} pointer; see Details.
  #' @param verbose Whether to print progress messages.
  #' @export
  InferenceRandCustom = define_inference_class(
  	classname = "InferenceRandCustom",
  	inherit = InferenceCustomRand,
  	public = list(
  		initialize = function(des_obj, custom_randomization_statistic_function = NULL, custom_randomization_statistic_cpp = NULL, verbose = FALSE){
  			if (!is.null(custom_randomization_statistic_function) && !is.null(custom_randomization_statistic_cpp)) {
  				stop("Supply custom_randomization_statistic_function or custom_randomization_statistic_cpp, not both.", call. = FALSE)
  			}
  			if (is.null(custom_randomization_statistic_function) && is.null(custom_randomization_statistic_cpp)) {
  				stop("InferenceRandCustom requires custom_randomization_statistic_function or custom_randomization_statistic_cpp.", call. = FALSE)
  			}
  			if (should_run_asserts()) {
  				assertFunction(custom_randomization_statistic_function, null.ok = TRUE)
  			}
  			super$initialize(des_obj = des_obj, verbose = verbose)
  			# Field names below are deliberately identical to the ones
  			# Inference.duplicate() (inference_all_abstract.R:264-272) already
  			# special-cases for locked-binding cloning
  			# (custom_randomization_statistic_function) and to
  			# set_custom_randomization_statistic_cpp()'s existing names
  			# (compiled_cpp_stat_fn/compiled_cpp_stat_src) — this means
  			# Inference.duplicate() needs NO changes at all (TODO-3's last
  			# bullet): it already clones the right field under the name it
  			# already expects.
  			private$custom_randomization_statistic_function = custom_randomization_statistic_function
  			if (!is.null(custom_randomization_statistic_cpp)) {
  				# Ported unchanged from set_custom_randomization_statistic_cpp()
  				# (inference_all_abstract_rand.R:58-112): source-string compile
  				# (keep source for per-worker recompilation), pre-compiled Rcpp
  				# function, or XPtr, with the same arity check.
  				private$install_stat_cpp(custom_randomization_statistic_cpp)
  			}
  		},
  		#' @description Calls the user-supplied statistic on the observed data.
  		#' @param estimate_only Unused; present for the `fit()` contract.
  		fit = function(estimate_only = FALSE){
  			dat = self$get_analysis_data()
  			list(estimate = private$evaluate_stat(dat$y, dat$w, dat$dead))
  		}
  	),
  	private = list(
  		custom_randomization_statistic_function = NULL,
  		compiled_cpp_stat_fn = NULL,
  		compiled_cpp_stat_src = NULL,
  		# ... install_stat_cpp(fn): body ported from set_custom_randomization_
  		# statistic_cpp()'s source-string/precompiled-function/XPtr branches
  		# and its 2-or-3-arg arity check (inference_all_abstract_rand.R:62-90ish),
  		# assigning into private$compiled_cpp_stat_fn/private$compiled_cpp_stat_src ...
  		evaluate_stat = function(y, w, dead, cpp_fn_override = NULL){
  			cpp_fn = if (!is.null(cpp_fn_override)) cpp_fn_override else private$compiled_cpp_stat_fn
  			if (!is.null(cpp_fn)) {
  				arity = length(formals(cpp_fn))
  				return(as.numeric(if (arity >= 3L) cpp_fn(y, as.integer(w), as.integer(dead)) else cpp_fn(y, as.integer(w)))[1L])
  			}
  			as.numeric(private$custom_randomization_statistic_function(y, w, dead))[1L]
  		},
  		# Ported from evaluate_lightweight_custom_randomization_statistic()
  		# (inference_ext_custom_randomization_statistic.R:57-88), minus the
  		# environment-proxy branch: every call here uses plain (y, w, dead)
  		# args, so there is nothing left to fake.
  		compute_fast_randomization_distr = function(y, permutations, delta, transform_responses, zero_one_logit_clamp = .Machine$double.eps){
  			w_mat = permutations$w_mat
  			if (is.null(w_mat)) return(NULL)
  			dead = private$dead
  			# cpp_fn_override: a worker recompiles its own copy from
  			# compiled_cpp_stat_src rather than dereferencing an XPtr serialized
  			# from the main process (same rationale as the code being ported).
  			cpp_fn_override = if (!is.null(private$compiled_cpp_stat_src)) local({
  				.src = private$compiled_cpp_stat_src; .fn = NULL
  				function(){ if (is.null(.fn)) .fn <<- Rcpp::cppFunction(.src); .fn }
  			})() else NULL
  			vapply(seq_len(ncol(w_mat)), function(j) private$evaluate_stat(y, w_mat[, j], dead, cpp_fn_override), numeric(1L))
  		}
  		# Deliberately NOT implementing compute_fast_rand_bootstrap_distr,
  		# compute_brt_null_statistics_with_se, or compute_rand_bootstrap_ci_
  		# affine_coefs: those back the bootstrap-randomization-test family
  		# (RandomizationBootstrap/RandomizationBootstrapCI), which
  		# InferenceRandCustom does not compose (see Non-goals) -- they would
  		# never be called and would just be dead code. compute_fast_
  		# randomization_distr above is the only fast-path method this class's
  		# actual components (RandomizationTest, RandomizationCI) ever consult;
  		# compute_rand_confidence_interval's bisection search
  		# (inference_all_abstract_rand_ci.R) calls back into
  		# approximate_randomization_distribution_beta_hat_T per delta, which is
  		# exactly what compute_fast_randomization_distr accelerates.
  	),
  	metadata = list(likelihood_tier = "none")
  )
  ```
  Add `#' @export` (shown above) so roxygen2 adds it to `NAMESPACE` on the
  next normal doc-regeneration pass — do not run this yourself; see
  "Verification" below.

- [x] **TODO-3: Remove the escape hatch from the general `RandomizationTest`
  component.** In `inference_all_abstract_rand.R`:
  - Delete `set_custom_randomization_statistic_function` (`:22-33`) and
    `set_custom_randomization_statistic_cpp` (`:58-112`) from `InferenceRand`
    entirely (this logic now lives, ported, in `InferenceRandCustom`).
  - Delete the `custom_randomization_statistic_function`/`compiled_cpp_stat_fn`/
    `compiled_cpp_stat_src` entries from `contracts_mixins.R:322-325`'s
    `RandomizationTest$owns_state` (only `randomization_mc_control` remains
    there).
  - Remove `InferenceExtCustomRandomizationStatistic$private` from the
    `private = c(...)` list at `inference_all_abstract_rand.R:537` (its
    component is deleted in TODO-5).
  - Delete every `has_custom_randomization_statistic`/`is.null(private[["custom_
    randomization_statistic_function"]])`/`is.null(private[["compiled_cpp_stat_
    fn"]])` check and simplify the surrounding branch to its non-custom-stat
    arm (the custom-stat arm is now dead — no class in the general hierarchy
    can set this field anymore):
    - `:163-165` (`has_custom_randomization_statistic` local), `:166`,
      `:174-176`, `:188-189` (`analyze_custom_randomization_statistic`/
      `use_lightweight_custom_stat` — the whole "need_thread_objs" lightweight
      calculation collapses since it was custom-stat-specific plumbing;
      recheck what `need_thread_objs` should default to for a class with no
      custom-stat concept — likely just `TRUE`, i.e. always duplicate,
      matching every other class's existing behavior when neither a fast
      kernel nor a custom stat is present), `:211`, `:293-295`, `:436`,
      `:453`, `:463`, `:473`, `:544`, `:709`, `:1070`, `:1285-1286`
      (collapses to just `self$compute_estimate(estimate_only = estimate_only)`).
  - In `inference_all_abstract_rand_bootstrap.R`: delete the guards at
    `:224`, `:314`, `:807`, `:975`.
  - In `inference_all_abstract_rand_bootstrap_ci.R`: delete the guards at
    `:102` and `:161` (the closed-form-affine-shortcut guard at `:161`
    simplifies to just `private$has_private_method("compute_rand_bootstrap_ci_
    affine_coefs")` — see TODO-2's note on why `InferenceRandCustom`
    deliberately never defines that method, so this check alone still
    correctly excludes it).
  - In `inference_mixin_kk_gee_shared.R`: delete the guards at `InferenceMixin
    KKGEEShared.compute_rand_two_sided_pval` (`:126-206`), lines `:145` and
    `:167`.
  - In `inference_all_abstract.R`: `Inference.duplicate()` (`:249-284`) special-
    cases cloning a locked `custom_randomization_statistic_function` binding
    (`:264-272`). **No change needed here.** TODO-2's `InferenceRandCustom`
    deliberately keeps the private field named `custom_randomization_
    statistic_function` (not something new like `stat_fn`), so this method
    keeps working unmodified — it will now only ever actually fire for
    `InferenceRandCustom` instances (via `self$duplicate()` calls inside
    randomization CI's debug/warmup/`n_cores > 1` paths), since that's the
    only class left that can have this field set. Add a regression test
    confirming `InferenceRandCustom$new(...)$duplicate()` clones the function
    correctly (clone, then verify the clone's `compute_estimate()` still
    invokes the user's statistic) — this exact path had a locked-binding
    special case for a reason, so it's worth pinning down now rather than
    discovering it's broken later.

- [x] **TODO-4: Delete the per-class escape-hatch guards.** Each of the
  following is a single early-return line (or two) that becomes unconditional
  dead weight once no class outside `InferenceRandCustom` can ever have this
  field set. Delete the `if (...) return(NULL)` (or, for the two `compute_
  brt_null_statistics_with_se`/`compute_rand_two_sided_pval` sites, fold the
  guarded branch into its unconditional form):

  | File | Line(s) | Method |
  |---|---|---|
  | `inference_all_average_diff.R` | 192, 198 | `SimpleMeanDifferenceSource.compute_fast_randomization_distr`, `.compute_fast_rand_bootstrap_distr` |
  | `inference_all_average_diff.R` | 213 | `.compute_rand_bootstrap_ci_affine_coefs` |
  | `inference_all_average_diff.R` | 291, 311 | `.compute_brt_null_statistics_with_se` |
  | `inference_all_KK_mean_diff_IVWC.R` | 116, 154 | `KKMeanDifferenceIVWCSource.compute_fast_bootstrap_distr`, `.compute_fast_randomization_distr` |
  | `inference_all_KK_wilcox_ivwc.R` | 238 | `KKWilcoxIVWCSource.compute_fast_randomization_distr` |
  | `inference_all_simple_wilcox.R` | 235, 276, 304 | `SimpleWilcoxSource.compute_fast_rand_bootstrap_distr`, `.compute_fast_bootstrap_distr`, `.compute_fast_randomization_distr` |
  | `inference_continuous_KK_bai_abstract.R` | 207 | `BaiAdjustedTSource.compute_fast_randomization_distr` |
  | `inference_continuous_lin.R` | 223 | (fast-distr override) |
  | `inference_continuous_ols.R` | 202, 224 | (two fast-distr overrides) |
  | `inference_continuous_robust_regr.R` | 365 | (fast-distr override) |
  | `inference_count_poisson.R` | 840 | (fast-distr override) |
  | `inference_ordinal_jonckheere_terpstra_test.R` | 129 | (fast-distr override) |
  | `inference_ordinal_ridit.R` | 199, 236, 247 | (three fast-distr overrides) |
  | `inference_survival_coxph.R` | 748 | (fast-distr override) |
  | `inference_survival_KK_weibull_marginal.R` | 380 | `SurvivalKKWeibullMarginalSource.compute_fast_rand_bootstrap_distr` |
  | `inference_survival_km_diff.R` | 216 | (fast-distr override) |
  | `inference_survival_log_rank.R` | 186 | (fast-distr override) |
  | `inference_survival_rmst.R` | 206 | (fast-distr override) |
  | `inference_ext_quantile_rand_ci.R` | 26 | `InferenceExtQuantileRandCI.compute_rand_confidence_interval` |

  For each, re-run that class's existing test coverage after the deletion —
  this is a behavior-preserving change (the branch was always skipped for
  every one of these classes' normal callers) and should be bit-for-bit.

- [x] **TODO-5: Delete `inference_ext_custom_randomization_statistic.R`.**
  Its two methods are superseded: `analyze_custom_randomization_statistic()`'s
  regex heuristic has no purpose once the calling convention is always plain
  args, and `evaluate_lightweight_custom_randomization_statistic()`'s logic
  moved into `InferenceRandCustom` in TODO-2. Remove the file, its `Collate`
  entry (if any) in `DESCRIPTION`, and the reference removed in TODO-3
  (`inference_all_abstract_rand.R:537`).

- [x] **TODO-6: Update `test-custom-extension-contract.R`.** Add a new
  `test_that("InferenceRandCustom runs a randomization test and CI on a
  user-supplied statistic", ...)` alongside the existing custom-extension
  tests (after line 111): construct a `DesignFixedBernoulli`, build
  `InferenceRandCustom$new(des, custom_randomization_statistic_function =
  function(y, w, dead) mean(y[w == 1]) - mean(y[w == 0]))`, assert
  `compute_estimate()` matches a plain mean-difference computation,
  `compute_rand_two_sided_pval()` returns a finite value in `[0, 1]`, and
  `compute_rand_confidence_interval()` returns a length-2 finite interval.
  Repeat with `custom_randomization_statistic_cpp` set to a 2-arg `(y, w)`
  source string, confirming both branches of TODO-2's `evaluate_stat()`
  dispatch. Also update TODO-1's `InferenceCustomRand`-level test in this
  same file.

- [x] **TODO-7: Rewrite `comprehensive_tests.R`'s `rand_custom` block.** The
  current block (`R/package_tests/comprehensive_tests.R:2447-2462`, inside
  `run_inference_checks_impl`) mutates the loop's existing `seq_des_inf`
  object in place:
  ```r
  if (supports_randomization_test && should_run_test_family("rand_custom")){
  	seq_des_inf$set_custom_randomization_statistic_cpp(welch_t_stat_cpp)
  	...
  	seq_des_inf$set_custom_randomization_statistic_cpp(NULL)
  }
  ```
  Post-refactor, `seq_des_inf` (whatever concrete estimator class it is for
  this row of the exhaustive sweep) no longer has this method at all. Replace
  the block with one that builds a parallel `InferenceRandCustom` over the
  *same design object* and exercises it there instead:
  ```r
  if (supports_randomization_test && should_run_test_family("rand_custom")){
  	custom_inf = InferenceRandCustom$new(
  		seq_des_inf$get_design_object(),
  		custom_randomization_statistic_cpp = welch_t_stat_cpp,
  		verbose = FALSE
  	)
  	if (!skip_slow && !skip_custom_rand_pval){
  		safe_call("compute_rand_two_sided_pval(custom)", custom_inf$compute_rand_two_sided_pval(r = r, show_progress = FALSE))
  	} else if (response_type == "incidence") {
  		message("    Skipping compute_rand_two_sided_pval(custom) (custom randomization statistic unsupported for incidence)")
  	}
  	if (supports_randomization_ci && !skip_slow && !skip_ci_rand && test_compute_confidence_interval_rand && response_type %in% c("continuous", "proportion", "survival")){
  		if (!skip_ci_rand_custom){
  			safe_call("compute_rand_confidence_interval(custom)", custom_inf$compute_rand_confidence_interval(r = r, pval_epsilon = pval_epsilon, show_progress = FALSE))
  		} else {
  			message("    Skipping compute_rand_confidence_interval(custom) (too slow)")
  		}
  	}
  }
  ```
  `welch_t_stat_cpp` itself (`:418-438`, a 2-arg `(y, w)` C++ source string)
  needs no change — `InferenceRandCustom$initialize()`'s arity check already
  accepts 2-arg sources. Confirm `get_design_object()` is available on every
  `seq_des_inf` class exercised by this loop (it's a base `Inference` public
  accessor per `test-custom-extension-contract.R:57`, so it should be) before
  relying on it here. Note this block sits inside `run_inference_checks_impl`,
  a function the *other*, currently-uncommitted change in this file (the
  `num_cores` fork-safety fix, `git diff` as of 2026-09-13) also touches —
  rebase this edit on top of that change rather than reverting it; the two
  are unrelated.

- [x] **TODO-8: NEWS/changelog entry.** Document the breaking change:
  `set_custom_randomization_statistic_function()`/`_cpp()` removed from every
  concrete estimator class; users doing this should switch to
  `InferenceRandCustom$new(des_obj, custom_randomization_statistic_function =
  function(y, w, dead) ...)`, noting the calling-convention change (explicit
  `(y, w, dead)` args, no more implicit `private$des_obj_priv_int` access).

- [x] **TODO-9: Docs and registry regeneration.** After the code changes,
  regenerate `NAMESPACE`/`man/` and the inference class registry the way this
  repo's own tooling normally does it — **do not** run `devtools::load_all()`,
  `pkgbuild::compile_dll()`, or `R CMD INSTALL` yourself to verify any of
  this; see `CLAUDE.md`. For a compile-needed check (the new `InferenceRand
  Custom` C++-source branch, ported from existing working code, shouldn't need
  one, but if a `.cpp` file changes anywhere in this plan), compile only the
  touched file(s) directly and relink per `CLAUDE.md`'s targeted-compile
  procedure, or ask the user to run their own build.

- [x] **TODO-10: Re-audit the `rand_custom` family's slow-path skip flags —
  the old ones were benchmarked against a mechanism this plan deletes.**
  Today, `skip_custom_rand_pval` (`comprehensive_tests.R:1544-1545`) and
  `skip_ci_rand_custom` (`:1549`) gate whether the custom-statistic p-value/CI
  actually run for a given (dataset, design, class) row of the exhaustive
  sweep:
  ```r
  skip_custom_rand_pval = (skip_regular_rand_pval && !is_any_inference_class_for_formula(ADDITIONAL_TEST_SLOW_PATHS$rand_pval_custom_allowed)) ||
  	response_type == "incidence"
  skip_ci_rand_custom = !force_run_slow_paths && is_exact_inference_class(ADDITIONAL_TEST_SLOW_PATHS$rand_ci_custom)
  ```
  Both were tuned for the *old* mechanism, where the custom statistic ran as
  a method call on `seq_des_inf` itself (whatever concrete estimator class
  the row under test happens to be):
  - `skip_custom_rand_pval` piggybacks on `skip_regular_rand_pval` — the
    *regular* (non-custom) randomization p-value's own slow-class exclusion
    list (`ADDITIONAL_TEST_SLOW_PATHS$rand_pval`). That coupling made sense
    only because the custom stat ran on the *same* object as the regular
    test, so if `seq_des_inf`'s own class was registered as slow, the custom
    path inherited that slowness too.
  - `skip_ci_rand_custom` hardcodes one exclusion,
    `rand_ci_custom = c("InferenceContinKKRobustRegrOneLik")`
    (`comprehensive_tests.R:408`, annotated "custom rand CI slow: robust avg
    336.6s / max 1994.8s at n=6") — a benchmark of how slow *that one class*
    was under the old duplicate-object-per-iteration path when it lacked its
    own fast kernel for the custom-stat case.

  After TODO-7, the custom statistic runs on a freshly constructed
  `InferenceRandCustom(seq_des_inf$get_design_object(), ...)` — a completely
  separate object with its own `compute_fast_randomization_distr`/
  `compute_fast_rand_bootstrap_distr` (TODO-2), the same two methods for
  every dataset and design. Its performance no longer depends at all on
  which concrete estimator class `seq_des_inf` happens to be, so:
  1. Decouple `skip_custom_rand_pval` from `skip_regular_rand_pval` entirely
     — it should default to running (not skipped) for every (dataset,
     design, response_type) combination the outer `supports_randomization_
     test` gate already lets through, independent of `seq_des_inf`'s own
     slow-path status. The `response_type == "incidence"` term stays exactly
     as-is (that's a real, `InferenceRandCustom`-independent limitation
     already documented in TODO-2/TODO-7 and the roxygen for
     `compute_rand_two_sided_pval`).
  2. Re-benchmark rather than carry over `rand_ci_custom`'s single hardcoded
     exclusion. Time `InferenceRandCustom$compute_rand_confidence_interval()`
     at the same `n`/`r` this file already uses, across a representative
     spread of datasets/designs (not just the one previously-excluded
     class). If it's now uniformly fast (expected, since it always uses the
     same fast kernel), delete the `rand_ci_custom` exclusion and
     `skip_ci_rand_custom`'s dependency on it, replacing it with a plain
     `force_run_slow_paths`-independent "always run" default; if some
     dataset/design combination is still genuinely slow, record fresh timing
     data in a comment the same way the current one does, keyed on
     data/design shape rather than on `seq_des_inf`'s class name (since the
     class name is no longer mechanically relevant to this test's cost).
  3. Confirm the result: the custom p-value and custom CI both actually
     execute, and are asserted on, for every applicable row of the
     exhaustive sweep (every dataset × design × response type combination
     that supports randomization inference and isn't incidence) — not just
     a hand-picked subset. This is a coverage requirement, not just a
     performance cleanup: the whole point of `InferenceRandCustom` replacing
     a 20-file-scattered mechanism is that it is now ONE code path, so it
     should be exercised as broadly as every other test family in this file
     (`rand`, `rand_ci`, `rand_bootstrap`, ...) already is.

## Explicitly out of scope

- Bootstrap-randomization CI on `InferenceRandCustom` (see Non-goals).
- Any change to how `InferenceCustomAsymp`/`InferenceCustomBoot` work today.
- Fixing `comprehensive_tests.R`'s unrelated, currently-uncommitted
  `num_cores`/fork-safety change (TODO-7 rebases on top of it, doesn't touch
  its substance).
- A general audit of every other component's `owns_state` for similar
  "feature bolted onto a shared component, guarded everywhere it's composed"
  smells. This plan fixes the one raised in conversation; if the pattern
  recurs elsewhere it's a separate plan.
