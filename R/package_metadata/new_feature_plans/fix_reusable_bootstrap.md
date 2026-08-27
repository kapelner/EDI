# Reusable-Bootstrap-Worker Support for `InferencePropZeroOneInflatedBetaRegr`

> **Depends on:** nothing new -- the reusable-worker contract
> (`supports_reusable_bootstrap_worker()` / `create_bootstrap_worker_state()`
> / `load_bootstrap_sample_into_worker()` / `compute_bootstrap_worker_estimate()`)
> is already implemented and shipped for every other class that uses it (see
> the audit below). This plan only extends it to the one class currently
> missing it. Additive, no public-contract change. **Release target: v1.1.0**
> (`release_v1_1_0.md → TODO-17e`; added to that release 2026-08-27 as a
> small follow-on fix to `local_machine_optimization.md`'s already-shipped
> `tune_EDI_for_this_machine()`, per user decision -- not new scope of its
> own).

Written 2026-08-27. Prompted by a live `tune_EDI_for_this_machine()` run this
session hanging its warm-start axis on `InferencePropZeroOneInflatedBetaRegr`'s
jackknife benchmark cell (traced live via `gdb` mid-run, then reproduced and
root-caused in isolation -- see "Root cause" below). The immediate symptom was
worked around by excluding this one class from the `jackknife` warm-start
operation in `local_machine_tuning_axes.R`
(`EDI_TUNING_WARM_START_OPERATION_EXCLUSIONS`); this plan is the real fix that
exclusion is standing in for.

## Why

`InferencePropZeroOneInflatedBetaRegr$compute_jackknife_estimate()` on a
50-observation dataset with no `y = 0`/`y = 1` boundary mass (an entirely
ordinary case for this response type -- not a contrived edge case) took
**7.6 seconds** for 50 leave-one-out folds, versus low-single-digit
milliseconds per fold for the equivalent raw fit called directly. Every other
warm-start operation for this same class (`rand`, `non_param_boot`,
`bayesian_boot`, `param_boot`) completed in under two seconds at the same `n`.
Jackknife alone is affected because it is the one operation whose generic
implementation (`InferenceJackknife$approximate_jackknife_distribution_beta_hat_T_private()`,
`inference_all_abstract_jackknife.R`) branches on
`supports_reusable_bootstrap_worker()`:

```r
jack = if (isTRUE(private$use_reusable_bootstrap_worker())) {
    private$compute_jackknife_distribution_with_reused_workers(...)
} else {
    unlist(private$par_lapply(seq_len(n_draws), function(i) {
        sub_inf = private$bootstrap_subset_inference(deletion_draws[[i]], smooth = FALSE)
        ...
        sub_inf$compute_estimate(estimate_only = TRUE)
    }, ...))
}
```

`InferencePropZeroOneInflatedBetaRegr` explicitly overrides
`supports_reusable_bootstrap_worker()` to `FALSE`
(`inference_proportion_zero_one_inflated_beta.R:504`), so every one of its 50
leave-one-out folds falls into the `else` branch: `bootstrap_subset_inference()`
constructs a brand-new `Design` + `Inference` R6 object pair from scratch, and
`compute_estimate()` on that fresh object runs the full
`generate_mod()` → `fit_with_hardened_qr_column_dropping()` machinery --
including a from-scratch QR-based column-selection search on **both** of this
class's design matrices (`X`, the beta-submodel covariates, and `X_zero_one`,
the zero/one-inflation-submodel covariates) -- with no warm start, no cached
column selection, and no reused object state carried over from the previous
fold.

## Audit: which other classes have this same exposure?

`supports_reusable_bootstrap_worker()` defaults to `FALSE` at the base
(`inference_all_abstract_non_param_boot.R:1115`) and each class opts in or out
explicitly. Audited every one of the 51 concrete classes
`edi_tuning_live_families()` currently enumerates by live instantiation
(not `grep` -- inheritance resolves the effective value dynamically, and a
`grep` pass over the 30 files that mention the method name at all is not the
same set as "every concrete class" or "what the method actually resolves to").

**Result: exactly one class needs this fix.**

| Class | `supports_reusable_bootstrap_worker()` | Notes |
|---|---|---|
| `InferencePropZeroOneInflatedBetaRegr` | `FALSE` | **Affected** -- confirmed slow jackknife (this plan). |
| `InferenceCountHurdleNegBin` | `FALSE` | **Not affected.** Its `compute_jackknife_estimate()` self-detects and bails out via `private$mark_jackknife_nonestimable_if_block_unsupported()`-style short-circuit before doing any per-fold work at all (`nonestimable_reason = "hurdle_negbin_jackknife_not_supported"`), returning `NA` in ~0ms at every `n` tested (50/200/1000). No fix needed. |
| every other of the 51 live families | `TRUE` | Already supported (mostly via the generic `InferenceAsympLik`/design-backed engine in `inference_all_abstract_asymp.R` + `inference_all_abstract_non_param_boot.R`, or a class-specific implementation for the g-computation/quantile-regression/robust-regression families). |
| `InferenceIncidExactBinomial`, `InferenceIncidExactFisher`, `InferenceIncidExactZhang` | n/a | Not in the `jackknife` warm-start family at all -- these require a matched/KK design, which the tuning harness's synthetic-experiment builder never constructs (same pre-existing filter that excludes KK-matching-design classes generally). Irrelevant to this plan. |

Audit script (kept for reference, not part of the package):
`/tmp/.../audit_reusable_worker.R` -- for each of the 51 live families,
constructs the class on a small synthetic design and reads
`private$supports_reusable_bootstrap_worker()` directly.

## What the generic reusable-worker engine actually does (and doesn't)

Every class that returns `TRUE` and inherits the generic engine
(`inference_all_abstract_asymp.R:199-208`, delegating to
`inference_all_abstract_non_param_boot.R`'s `create_design_backed_bootstrap_worker_state()`
/ `load_bootstrap_sample_into_design_backed_worker()` /
`compute_bootstrap_worker_estimate_via_compute_treatment_estimate()`) gets:

- **One `self$duplicate()` clone, once**, instead of a fresh `generator$new()` +
  full `Design`/`Inference` constructor-validation pass on every fold.
- Per-fold, only a **cheap in-place field mutation** on that one cloned
  worker's private environment (`w_priv$X`, `w_priv$w`, `w_priv$y`, `w_priv$dead`,
  etc. reassigned to the subsetted vectors/matrix rows) instead of re-running
  object construction.

**Important, and easy to miss:** the generic engine's `load_bootstrap_sample_into_design_backed_worker()`
*also* resets `w_priv$best_X_colnames = NULL` and every design-matrix cache
(`cached_design_matrix`, `cached_reduced_X`, etc.) on every single load --
i.e. it does **not** cache the column-selection result across folds either.
Every class using this generic engine still re-runs its own
`fit_with_hardened_qr_column_dropping()`-based column search from scratch per
fold, exactly like the non-reusable path does. The saving is real but
narrower than "skip the column search" -- it is specifically "skip
constructing and validating a brand-new R6 object graph per fold." Given this
session's profiling showed `fit_with_hardened_qr_column_dropping()`'s `.Call`s
(the actual C++ fit attempts, potentially more than one per fold if the first
attempt fails `fit_ok()`) at ~75-86% of self-time inside one fold, **worker
reuse alone (i.e. adopting the generic engine unmodified) would not fully
close the gap for this class** -- see "Design" below for why the bespoke
implementation this plan proposes avoids that trap.

## Design: `get_bootstrap_worker_spec()` / worker-state contract for `InferencePropZeroOneInflatedBetaRegr`

This class cannot simply flip `supports_reusable_bootstrap_worker()` to
`TRUE` and inherit the generic engine unmodified: the generic
`load_bootstrap_sample_into_design_backed_worker()` only knows about one
design matrix (`private$X`) and the design's own `y`/`w`/etc. This class has
a **second, independent covariate matrix** (`X_zero_one`, built from
`private$model_formula_zero_one` via `private$build_component_matrix()`) that
the generic subsetting logic has no vocabulary for. A bespoke (but
contract-conformant) implementation is needed.

The concrete template to follow is `inference_proportion_gcomp.R`'s own
`create_bootstrap_worker_state`/`load_bootstrap_sample_into_worker`/
`compute_bootstrap_worker_estimate` trio (read that file's implementation
directly, not just this plan's sketch) -- and its
`compute_bootstrap_worker_estimate()` reveals the pattern that actually
matters here: it does **not** route through the worker's own
`compute_estimate()` (which would re-trigger the full `generate_mod()` /
`fit_with_hardened_qr_column_dropping()` machinery every fold, the exact cost
this plan exists to eliminate). Instead it calls a **lightweight, direct
estimation helper** (`bootstrap_effect_from_sample()`) that fits *only* the
model, with no per-fold column-selection search at all. This directly answers
the "open question" this plan originally left open (see below): worker reuse
alone, if `compute_bootstrap_worker_estimate()` still goes through
`compute_estimate()`, would *not* eliminate the column-search cost -- so
don't do that. Follow gcomp's pattern instead.

### `supports_reusable_bootstrap_worker()`

```r
supports_reusable_bootstrap_worker = function(){
    TRUE
},
```

### `get_bootstrap_worker_spec()` / `create_bootstrap_worker_state()`

Clone once via the generic engine for the base `X`/`w`/`y`/etc. fields, **and
freeze the column selection** by running the real (full-sample,
`fit_with_hardened_qr_column_dropping()`-backed) fit exactly once here, at
worker-creation time -- not per fold. This is the crux of the fix: the
column-search cost is paid once per jackknife *run*, not once per *fold*.

```r
create_bootstrap_worker_state = function(){
    state = private$create_design_backed_bootstrap_worker_state()
    private$shared(estimate_only = FALSE)  # ensures best_X_colnames / best_X_zero_one_colnames are populated
    state$base_X_zero_one_full = private$build_component_matrix(private$model_formula_zero_one)
    state$best_X_colnames = private$best_X_colnames
    state$best_X_zero_one_colnames = private$best_X_zero_one_colnames
    state$fixed_idx_layout = private$cached_values$likelihood_test_context  # j_treat / column counts, for indexing into params
    state
},
```

### `load_bootstrap_sample_into_worker()`

Subsets the raw data only (both `X` via the generic helper, and the second
design matrix `X_zero_one` by row-indexing the same `indices`) -- no column
search, no `Design`/`Inference` reconstruction beyond what the generic loader
already does to the worker's cheap raw fields:

```r
load_bootstrap_sample_into_worker = function(worker_state, indices){
    private$load_bootstrap_sample_into_design_backed_worker(worker_state, indices)
    indices_int = if (is.list(indices)) as.integer(indices$i_b) else as.integer(indices)
    worker_state$runtime_X_zero_one = worker_state$base_X_zero_one_full[
        indices_int, worker_state$best_X_zero_one_colnames, drop = FALSE
    ]
    invisible(worker_state)
},
```

### `compute_bootstrap_worker_estimate()`

Calls `fast_zero_one_inflated_beta_cpp()` **directly**, on the fixed,
frozen column set from `create_bootstrap_worker_state()` -- mirroring
gcomp's `bootstrap_effect_from_sample()` pattern exactly (a lightweight
private helper, not `compute_estimate()`):

```r
compute_bootstrap_worker_estimate = function(worker_state){
    w_priv = worker_state$worker_priv
    X_sub = w_priv$X[, worker_state$best_X_colnames, drop = FALSE]
    res = tryCatch(
        fast_zero_one_inflated_beta_cpp(
            X_sub, worker_state$runtime_X_zero_one, w_priv$y,
            smart_cold_start = private$smart_cold_start_default
        ),
        error = function(e) NULL
    )
    j_treat = worker_state$fixed_idx_layout$j_treat
    if (is.null(res) || length(res$b) < j_treat || !is.finite(res$b[j_treat])) return(NA_real_)
    as.numeric(res$b[j_treat])
},
```

(This sketch elides the `required_cols`/treatment-column-preservation detail
`fit_with_hardened_qr_column_dropping()` guarantees on the full-sample fit --
verify the frozen `best_X_colnames`/`best_X_zero_one_colnames` always include
the treatment column by construction, per TODO-2, so a per-fold rank check
is never needed.)

## Why the design above should close the gap (not just reduce it)

The "Design" section's `create_bootstrap_worker_state()`/
`compute_bootstrap_worker_estimate()` split directly targets the actual
profiled bottleneck: `fit_with_hardened_qr_column_dropping()`'s QR-based
column search plus its retry-on-`fit_ok()`-failure loop, which this session's
`Rprof()` trace showed dominating self-time (`.Call` at ~75-86%) inside a
single fold. Freezing `best_X_colnames`/`best_X_zero_one_colnames` once, at
worker-creation time, and having `compute_bootstrap_worker_estimate()` call
`fast_zero_one_inflated_beta_cpp()` directly on that fixed column set --
never re-entering `generate_mod()`/`fit_with_hardened_qr_column_dropping()`
per fold -- removes the column search from the per-fold cost entirely, not
just the R6/`Design` construction overhead the *generic* engine alone would
have removed. This is the same reason gcomp's own worker-estimate function
bypasses `compute_estimate()` rather than reusing it naively.

This is a design argument, not yet a measurement -- TODO-3 below is still
required to confirm it empirically (re-run the exact `Rprof()` profiling this
plan's audit already did, before/after, on the same n=50 diagnosed case) and
must not be skipped just because the reasoning above is sound.

## Implementation TODOs

- [ ] TODO-1: Add `supports_reusable_bootstrap_worker()` (`TRUE`) and the
      three worker-contract methods above to
      `InferencePropZeroOneInflatedBetaRegr`'s private list
      (`inference_proportion_zero_one_inflated_beta.R`), modeled on
      `inference_proportion_gcomp.R`'s existing two-matrix-aware
      implementation as the concrete template rather than the sketch above.
- [ ] TODO-2: Verify empirically (don't assume) that the full-sample fit's
      frozen `best_X_colnames`/`best_X_zero_one_colnames`
      (`create_bootstrap_worker_state()`) always include the treatment
      column -- `fit_with_hardened_qr_column_dropping()`'s `required_cols`
      guarantees this for the *original* fit, but confirm the frozen names
      still resolve to a valid, treatment-including column subset after
      `load_bootstrap_sample_into_worker()`'s row-subsetting (a leave-one-out
      fold can't drop columns, only rows, so this should hold, but verify
      rather than assume before shipping).
- [ ] TODO-3: Re-profile `compute_jackknife_estimate()` on the exact
      diagnosed case (n=50, `edi_tuning_default_seed(cls, 50L)` synthetic
      data, no `y=0`/`y=1` boundary mass) before/after. Confirm the fix
      actually closes the gap (target: comparable per-fold cost to the
      other four warm-start operations, i.e. low hundreds of ms total for
      50 folds, not seconds). If it doesn't, open the column-selection-cache
      follow-up noted above rather than declaring this plan done.
- [ ] TODO-4: Golden-value regression test: `compute_jackknife_estimate()`
      (and `compute_jackknife_std_error()`/`compute_jackknife_wald_two_sided_pval()`)
      must return **bit-identical** results before and after this change, on
      both a "no boundary mass" dataset (the diagnosed case) and a normal
      dataset with real `y=0`/`y=1` observations. This is a performance-only
      change; any numeric difference is a bug in the worker-state
      subsetting, not an acceptable side effect.
- [ ] TODO-5: Remove the now-unnecessary `jackknife = "InferencePropZeroOneInflatedBetaRegr"`
      entry from `EDI_TUNING_WARM_START_OPERATION_EXCLUSIONS`
      (`local_machine_tuning_axes.R`) once TODO-3/4 confirm the fix, so the
      tuning harness resumes actually benchmarking this class's jackknife
      cold/warm-start policy like every other class's.
- [ ] TODO-6: Re-run `tune_EDI_for_this_machine(effort = "standard")` end to
      end once this lands, to confirm the jackknife warm-start axis for this
      class now completes at a normal pace and produces a real (not
      excluded) policy diff for it.

## Standing constraints

Same as every other plan in this directory: additive, bit-for-bit-identical
results (this is a pure performance change -- see TODO-4), targeted compile
only (`R/EDI/src/` isn't touched by this plan at all; it's R-layer only).
