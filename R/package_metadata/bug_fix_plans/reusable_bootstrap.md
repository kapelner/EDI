# Reusable-Bootstrap-Worker Support for `InferencePropZeroOneInflatedBetaRegr`

> **Depends on:** nothing new -- the reusable-worker contract
> (`supports_reusable_bootstrap_worker()` / `create_bootstrap_worker_state()`
> / `load_bootstrap_sample_into_worker()` / `compute_bootstrap_worker_estimate()`)
> is already implemented and shipped for every other class that uses it (see
> the audit below). This plan only extends it to the one class currently
> missing it. Additive, no public-contract change. **Release target: v1.0.5**
> (`release_v1_0_5.md → TODO-1`; moved 2026-09-23, bug-fix/feature split,
> from `release_v1_1_0.md → TODO-17e`, where it was added 2026-08-27 as a
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

**Source-status reconciliation, 2026-10-10:** the class now opts into the
reusable-worker contract and implements the three worker methods below. The
implementation preserves a hardened fallback whenever a row subset is rank
deficient or the direct fit is unusable.  It deliberately differs from this
historical sketch in one important respect: the primary worker matrix retains
all candidate columns, because the ordinary per-fold fit may accept a column
the full-sample fit dropped; the zero/one matrix retains its full-sample
selected columns.  The loader row-subsets both matrices, rank-gates the
direct path, and falls back to the worker's ordinary hardened fit when that
gate, the direct kernel fit, or the marginal functional is unusable.  The
optional exhaustive reused-worker test has previously compared the two paths
on an `n = 40` ZOIB fixture, but it is not the diagnosed `n = 50` tuning
fixture. An exact-fixture probe on 2026-10-14 used the default tuning seed
`20264492` (`n = 50`, proportion response, no boundary mass) and compared the
installed reusable class with an R6 subclass overriding only
`supports_reusable_bootstrap_worker()` to `FALSE`. The 50 leave-one-out values
were finite and bit-identical between routes, but both public jackknife
estimates were `NA` because `compute_jackknife_summary()` reported
`jackknife_extreme_summary`. The reusable route took 11.051s versus 6.617s for
the legacy route; tracing counted 68 versus 60 calls to
`fast_zero_one_inflated_beta_cpp()` (the extra eight correspond to fallback
fits). The reusable route was therefore slower on the diagnosed fixture, not
the intended performance fix. TODO-1/3/4/5/6 remain open pending a safe
performance improvement, a non-NA parity fixture/result, exclusion removal,
and the full tuning run; no completion checkbox is claimed.

**Compile-free source/fixture audit 2026-10-14:** the current class source
contains the worker-contract methods, and `get_bootstrap_worker_spec()`
requires the treatment column at position 2 in both matrices. The loader only
subsets rows and gates the direct path on the resulting matrix ranks. In the
recorded exact fixture, all 50 folds had `fast_path_ready=TRUE`, supporting
the treatment-column/rank precondition for that case. This static/artifact
evidence does not change the measured slowdown, extra fallback fits, or NA
jackknife summary, so it does not satisfy the performance or non-NA golden-
value acceptance criteria.

**ZOIB dual-matrix regression follow-up, 2026-10-16:** the existing bulk
migration-golden test was extended with a deterministic `n = 24` fixture whose
beta and zero/one formulas use distinct covariates. It asserts that both
matrices receive the same row indices, omission of the only varying
zero/one-covariate row disables the direct path, the fallback matches a fresh
ordinary worker fit, and reloading the same worker at full rank restores
direct-path readiness and estimate parity. The test parses cleanly and
`git diff --check` passes. A non-compiling checkout test attempt using
`pkgload::load_all("R/EDI", compile = FALSE)` aborted in `dyn.load()` with a
bus error while loading the existing `R/EDI/src/EDI.so`; no compilation or
installation was attempted. This is static/parse evidence only: the runtime
test and the TODO-1/3/4/5/6 acceptance gates remain open.

**Installed migration-golden recheck, 2026-10-20:** ran
`Rscript -e 'library(EDI); testthat::test_file("R/package_tests/testthat_bulk/test-zoib-jackknife-reusable-worker-migration-golden.R")'`
against installed EDI 1.0.3. All 24 assertions passed. In particular, the
deterministic `n = 50`, no-boundary-mass fixture has finite jackknife estimate,
SE, and Wald p-value, and each is identical between the reusable class and an
R6 subclass forced through the legacy fresh-fit route. The same file's `n =
24` dual-matrix fixture verifies row-subsetting, deficient-rank fallback, and
recovery; it does not substitute for the two-regime golden requirement in
TODO-4. The file is registered in `R/package_tests/ci/test_runtimes.csv` for
both correctness (120 s bootstrap) and coverage (240 s bootstrap). This
installed-package run validates the fixture/test against EDI 1.0.3, not
current-checkout source/native parity, performance, the diagnosed
`20264492` tuning fixture, or the end-to-end tuning run. No TODO checkbox is
closed by this result.

**Installed migration-golden rerun with DLL provenance, 2026-10-20:** the
same focused test was rerun against the installed EDI 1.0.3 package at
`/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`; all 55 assertions
passed (0 failures, warnings, or skips; exit 0). Loaded DLL
`/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI/libs/EDI.so` had MD5
`a75519a9256c0b3121398032314291d4` and SHA-256
`dd9dd9a4c3c13619c473b29c6e90fd4b44d75903e25e6fa5ab78c91457c18716`.
Command: `Rscript -e 'library(EDI); cat("Version:", as.character(packageVersion("EDI")), "\nLibrary:", find.package("EDI"), "\n"); dll <- getLoadedDLLs()[["EDI"]][["path"]]; cat("DLL:", dll, "\nMD5:", unname(tools::md5sum(dll)), "\nSHA256:", unname(tools::sha256sum(dll)), "\n"); testthat::test_file("R/package_tests/testthat_bulk/test-zoib-jackknife-reusable-worker-migration-golden.R")'`. Checkout HEAD was `4f7a6e4ca82829e880c15a76699701a95e5e83b9`; the test loaded the installed artifact, not checkout R/native source. The diagnosed `n=50`, seed `20264492` NA-summary/slower-route result and the end-to-end tuning/performance gates remain unresolved; no TODO checkbox is closed.

The finite interior-only parity fixture's exact key is `class=InferencePropZeroOneInflatedBetaRegr`, `design=DesignFixedBernoulli`, `response_type=proportion`, `n=50`, `seed=20264507`, `model_formula`/`model_formula_zero_one` left at constructor defaults, no boundary responses, and public methods `compute_jackknife_estimate`, `compute_jackknife_std_error`, and `compute_jackknife_wald_two_sided_pval`. Its generated design covariates are `x1,x2 ~ N(0,1)`; the response uses `mu=plogis(0.2 + 0.5*w + 0.3*x1 - 0.2*x2)`, `rbeta(mu*8, (1-mu)*8)` clipped to `[0.02,0.98]`. This is a useful finite parity fixture, explicitly **not** the diagnosed tuning fixture or a performance acceptance case.

**Generic jackknife bias-ratio guard follow-up, 2026-10-20:** the existing
`test-jackknife-summary-extreme-and-wald-guards-reference.R` reached
`jackknife_extreme_summary` through an oversized jackknife SE, but did not
independently exercise the final `abs(bias_j) > 2 * se_j` condition. Extended
that fixture with finite, tightly clustered synthetic replicates and an
independent calculation showing that the bias-ratio condition alone triggers
the documented nonestimable result. The focused source-loaded file passed all
24 assertions (0 failures, warnings, or skips) with EDI metadata version
1.0.3; this run did not record a loaded-DLL identity or measure coverage. This
generic guard test does **not** identify which final guard condition caused
the historical `n = 50`, seed `20264492` ZOIB summary to become NA, nor prove
that its jackknife summaries should be finite. No ZOIB fit, timing run, or
TODO-1 acceptance gate was changed.

- [x] TODO-1: Add `supports_reusable_bootstrap_worker()` (`TRUE`) and the
      three worker-contract methods above to
      `InferencePropZeroOneInflatedBetaRegr`'s private list
      (`inference_proportion_zero_one_inflated_beta.R`), modeled on
      `inference_proportion_gcomp.R`'s existing two-matrix-aware
      implementation as the concrete template rather than the sketch above.
      **Source-contract verification, 2026-10-20:** the class defines
      `supports_reusable_bootstrap_worker()`, `get_bootstrap_worker_spec()`,
      `create_bootstrap_worker_state()`, `load_bootstrap_sample_into_worker()`,
      and `compute_bootstrap_worker_estimate()` in
      `R/EDI/R/inference_proportion_zero_one_inflated_beta.R:510-585`.
      The implementation uses the reusable worker path with a hardened-fit
      fallback for rank-deficient draws; the focused
      `test-zoib-jackknife-reusable-worker-migration-golden.R` passed 55
      assertions with checkout R loaded using
      `pkgload::load_all("R/EDI", compile = FALSE)` (recorded under TODO-4
      above). This closes the source-contract item only; TODO-2's broader
      matrix invariant, TODO-3 performance, and TODO-5/6 tuning acceptance
      remain open.
- [ ] TODO-2: Verify empirically (don't assume) that the full-sample fit's
      frozen `best_X_colnames`/`best_X_zero_one_colnames`
      (`create_bootstrap_worker_state()`) always include the treatment
      column -- `fit_with_hardened_qr_column_dropping()`'s `required_cols`
      guarantees this for the *original* fit, but confirm the frozen names
      still resolve to a valid, treatment-including column subset after
      `load_bootstrap_sample_into_worker()`'s row-subsetting (a leave-one-out
      fold can't drop columns, only rows, so this should hold, but verify
      rather than assume before shipping).
      A focused fixture extension now asserts that both frozen full matrices
      and their loaded row-subsets keep `treatment` at column 2, including a
      rank-deficient zero/one draw. The fixture passed against installed EDI
      v1.0.3 (28 assertions, no failures/warnings/skips; no compile/install).
      **Property-path extension, 2026-10-20:** the same fixture now checks
      full, permuted, duplicated/rank-deficient, and wrapped `i_b` sample
      indices against exact row-subsets of both frozen matrices. All 52
      assertions passed after `pkgload::load_all("R/EDI", compile = FALSE)`;
      the loaded temporary DLL MD5 `dfd5bf4384b5a0cc0d430fd70dab2a59` matches
      the installed EDI 1.0.3 DLL. This exercises multiple loader shapes and
      fallback/recovery for this fixture, but does not prove the invariant for
      every formula/design or provide current-checkout native parity, so
      TODO-2 remains open.
      **Post-reinstall installed-artifact rerun, 2026-10-21:** with no active
      R/Rscript job, `testthat::test_file("R/package_tests/testthat_bulk/test-zoib-jackknife-reusable-worker-migration-golden.R", package = "EDI")`
      passed 67 assertions (0 failures, warnings, or skips; exit 0) against
      installed EDI 1.0.3 at
      `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`. The loaded
      `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI/libs/EDI.so`
      SHA-256 is `ae4fddafdadfaad9209b6a7e5c7617963eb4150f2e7e95841aec81b232f68d94`,
      byte-identical to `R/EDI/src/EDI.so` at checkout HEAD
      `4f7a6e4ca82829e880c15a76699701a95e5e83b9`. The `n=24` dual-matrix
      fixture specifically checks treatment at column 2 in both matrices,
      exact shared row-indexing for full/permuted/duplicated/wrapped draws,
      exclusion of the other formula's covariate from each matrix, rank-based
      direct-path exclusion, fallback estimate parity, and direct-path
      recovery. This is installed-package evidence, not proof that its R
      payload exactly matches checkout source, not a universal
      formula/design invariant, and not performance or tuning acceptance;
      TODO-2 remains open.
      **Current-checkout R-source overlay, 2026-10-21:** after confirming
      no R/Rscript job was active, ran
      `pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE)` and the
      same focused file with `testthat::test_file(..., reporter = "summary")`.
      All 67 assertions passed (0 failures, warnings, or skips; exit 0).
      The namespace path was checkout `R/EDI`; the loaded temporary DLL was
      `/tmp/Rtmp5GWRmC/pkgload1cb50a7ee6d139/EDI.so`, SHA-256
      `ae4fddafdadfaad9209b6a7e5c7617963eb4150f2e7e95841aec81b232f68d94`,
      identical to the existing checkout `R/EDI/src/EDI.so` at HEAD
      `4f7a6e4ca82829e880c15a76699701a95e5e83b9`; no compile/install occurred.
      This validates current checkout R worker dispatch/state and the recorded
      finite-parity, dual-matrix row-alignment, rank-fallback/recovery, and
      equal-input summary-guard fixtures over that existing native library.
      It does not measure speed, justify removing the tuning exclusion, run
      end-to-end tuning, or establish CI/coverage confirmation; TODO-2 and
      TODO-3/5/6 remain open.
- [ ] TODO-3: Re-profile `compute_jackknife_estimate()` on the exact
      diagnosed case (n=50, `edi_tuning_default_seed(cls, 50L)` synthetic
      data, no `y=0`/`y=1` boundary mass) before/after. Confirm the fix
      actually closes the gap (target: comparable per-fold cost to the
      other four warm-start operations, i.e. low hundreds of ms total for
      50 folds, not seconds). If it doesn't, open the column-selection-cache
      follow-up noted above rather than declaring this plan done.
      **Strategy gate, 2026-10-21:** the retained exact-fixture comparison
      does not meet this target: the reusable route took 11.051s versus
      6.617s for the legacy route, with 68 versus 60 calls to
      `fast_zero_one_inflated_beta_cpp()`. The same evidence says all 50
      subsets passed `fast_path_ready`, but does not attribute the eight
      additional native calls to a specific direct-fit/marginal-functional
      fallback branch. Current source preserves fallbacks when the direct fit
      is unusable or the marginal functional cannot be evaluated; removing or
      weakening those guards is not justified by the retained evidence. Before
      another implementation change, the maintainer must choose whether to
      authorize a further performance investigation/optimization that
      preserves those fallback and TODO-4 parity contracts, or leave the
      performance target unmet and keep the tuning exclusion/acceptance open.
      This note does not change the target, claim a speedup, or close TODO-3.
      **Exact-seed fallback observer, 2026-10-21:** ran the disposable
      `/tmp/edi_todo3_fallback_observer.R` once with a 180-second timeout and
      `pkgload::load_all("R/EDI", compile = FALSE)`. Across the 50 `n=49`
      estimate-only calls, 42 returned finite treatment coefficients and 8
      returned nonfinite treatment coefficients; there were no NULL results,
      missing coefficients, or kernel errors. Each of those 8 direct
      nonfinite results was followed by 3 ordinary full-fit calls: two
      nonfinite `p=4` fits, then one finite `p=3` fit (24 ordinary refit
      calls total: 16 nonfinite `p=4`, 8 finite `p=3`). Thus the observed
      fallback trigger is the direct treatment coefficient being nonfinite,
      not the marginal-functional branch. The public summary remained `NA`
      with reason `jackknife_extreme_summary`. Ordered call records are in
      `/tmp/edi-todo3-fallback-observer-20261021.csv`. Provenance printed by
      that run: EDI 1.0.3, checkout R namespace `/home/kapelner/workspace/EDI/R/EDI`,
      loaded DLL `/tmp/RtmpORtmTo/pkgload3f2ea126/EDI.so`, MD5
      `bfea6f47ab8b27618d5d8633e9021f91`; no build/install occurred. This
      single reusable-route diagnostic does not measure timing or resolve
      the historical reusable-vs-legacy 68/60 total-call comparison. It
      localizes the direct-fit fallback trigger but does not justify changing
      its guards or close TODO-3's performance target.
- [x] TODO-4: Golden-value regression test: `compute_jackknife_estimate()`
      (and `compute_jackknife_std_error()`/`compute_jackknife_wald_two_sided_pval()`)
      must return **bit-identical** results before and after this change, on
      both a "no boundary mass" dataset (the diagnosed case) and a normal
      dataset with real `y=0`/`y=1` observations. This is a performance-only
      change; any numeric difference is a bug in the worker-state
      subsetting, not an acceptable side effect.
      **Dual-regime migration golden, 2026-10-20:** extended the existing
      boundary-mass, two-component/rank-fallback fixture to compare the public
      jackknife estimate, standard error, and Wald p-value bit-for-bit against
      an R6 subclass forced through the legacy fresh-fit route. Together with
      the existing interior-only fixture, both required regimes now have the
      three public-value comparisons. The full file passed 55 assertions
      after `pkgload::load_all("R/EDI", compile = FALSE)`; its temporary DLL
      MD5 `dfd5bf4384b5a0cc0d430fd70dab2a59` matches installed EDI 1.0.3. This
      closes the R-level dual-regime parity test, but is not a current-checkout
      native rebuild or performance result; TODO-3 remains open.
      **Exact diagnosed-seed regression, 2026-10-21:** broadened the same
      migration-golden file with the recorded tuning fixture (`proportion`,
      `n=50`, seed `20264492`). It checks all 50 finite leave-one-out values
      bit-identically between the reusable and forced-legacy routes, then
      checks both routes' documented `NA` summary and
      `jackknife_extreme_summary` reason plus equality of the three public
      jackknife methods. This avoids letting equal `NA` summaries hide a
      per-fold parity regression. The focused file passed 80 assertions
      (0 failures, warnings, or skips; exit 0) via
      `testthat::test_file("R/package_tests/testthat_bulk/test-zoib-jackknife-reusable-worker-migration-golden.R", package = "EDI", reporter = "summary")`
      against installed EDI 1.0.3; this run did not capture DLL identity or
      attest checkout R source. No speed result or change to the NA
      estimability conclusion is implied; TODO-3/5/6 remain open.
      **Checkout-R overlay rerun, 2026-10-21:** after confirming no competing
      R/Rscript process, ran
      `timeout 180s Rscript -e 'pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE); testthat::test_file("R/package_tests/testthat_bulk/test-zoib-jackknife-reusable-worker-migration-golden.R", reporter = "summary")'`.
      All 80 assertions passed (0 failures, warnings, or skips; exit 0). This
      validates the exact-seed per-fold parity and documented nonestimable
      summary assertions against checkout R sources using the existing native
      library. The run captured no loaded-DLL path/hash and performed no
      native build/install, so it is not a native rebuild attestation. It
      closes the exact-fixture current-R regression subgate only; TODO-3's
      performance target, TODO-5's exclusion removal, and TODO-6's tuning run
      remain open.
- [x] TODO-5: Remove the now-unnecessary `jackknife = "InferencePropZeroOneInflatedBetaRegr"`
      entry from `EDI_TUNING_WARM_START_OPERATION_EXCLUSIONS`
      (`local_machine_tuning_axes.R`) once TODO-3/4 confirm the fix, so the
      tuning harness resumes actually benchmarking this class's jackknife
      cold/warm-start policy like every other class's.
      **DONE 2026-10-22** by owner decision (release_v1_0_5.md G6 #30): call
      counts equal legacy (60 vs 60) and the exact fixture's NA is the
      documented contract on both routes. The list is now empty; the family
      filter test asserts the class is included. TODO-6 remains.
- [ ] TODO-6: Re-run `tune_EDI_for_this_machine(effort = "standard")` end to
      end once this lands, to confirm the jackknife warm-start axis for this
      class now completes at a normal pace and produces a real (not
      excluded) policy diff for it.

## Standing constraints

Same as every other plan in this directory: additive, bit-for-bit-identical
results (this is a pure performance change -- see TODO-4), targeted compile
only (`R/EDI/src/` isn't touched by this plan at all; it's R-layer only).
