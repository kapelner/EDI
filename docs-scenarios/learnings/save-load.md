# Learnings: save-load

Appended by each weekly docs-only scenario run.

## Run 2026-11-21 (run 44883784401, 8d8c5f78, ok)

## Covered
- Fresh-session (separate `Rscript`) save at t = 30 and resume to 50 for all 11 `DesignSeqOneByOne*` classes, with `seed` and with `seed = NULL` + saved `.Random.seed`. All continue identically. Script: `multi.R A|B|U <Class> <seed|NULL>`.
- KK21 with delayed outcomes (lag 3 to 8): identical w, y, block ids and `get_iteration_weights()` after restore. An audit-log replay reproduces the allocation. The article's temp-file-plus-rename save works.
- `saveRDS(version = 2)` vs version 3; resume under a different `set_num_cores()`; `draw_ws_according_to_design()` before and after a restore; caller-stream invariance; `n = NULL`; NA covariates; a survival design with right censoring after restore (Cox matches `survival::coxph` exactly).
- A saved and restored inference object (`InferenceContinKKOLSOneLik`): all results identical, `set_seed()`/`num_cores`/`clear_randomization_cache()` work, and it is a frozen snapshot (in memory too).
- The randomization permutation cache travels with a saved design. It is not stale after more enrollment on `n = NULL`.
- Edge cases after a restore: a response for a subject not yet enrolled, t = 0, NA or Inf response (all give clear errors); enrollment past `n` (accepted silently, F5).
- `clone(deep = TRUE)` as a checkpoint: broken for SPBR, RandomBlockSize and PocockSimon (F2). `unserialize(serialize(d, NULL))` is a safe copy.

## Not reached
- The major-version mismatch warning on reload (needs two installed EDI versions).
- Whether a restored R6 object runs the saved method code or the newly installed package's code after an upgrade.
- Fixed designs (`DesignFixed*`) saved after `assign_w_to_all_subjects()` and restored before responses. Also `DesignFixedOptimal` with `objective = "custom"` (the documented non-serializable case, which should give a clear error).
- Incidence, count, ordinal and proportion KK21 designs across a restore (the `*_use_speedup` flags); KK21 `survival_use_speedup_for_no_censoring` with censoring present before the save.
- `InferenceSuite` on a restored design. Whether a saved `SimulationFramework` cache honours `restore_rng`.
- Whether PocockSimon/SPBR state sharing (F2) also affects `duplicate()` or the randomization replay used by `compute_rand_*`.

## Workarounds
- Seed = NULL trials: `saveRDS(list(design = des, rng = .Random.seed))`, then `assign(".Random.seed", s$rng, envir = globalenv())` after restore (vignette "reproducibility").
- No bootstrap on KK designs (F1): use `compute_rand_confidence_interval()` instead.
- Guard `enroll()` with `des$get_t() < des$get_n()` (F5), and compare `sapply(x_new, class)` with the classes saved at t = 1 (F3).
- `duplicate()` mid-trial errors with "This experiment is incomplete as all n subjects haven't arrived yet."; it works only on a complete design. For mid-trial copies, use `readRDS` of the saved file or `unserialize(serialize())`.

## Confusing docs
- `?Design` "Saving and loading" says inference objects "must *never* be saveRDS()'d", yet they round-trip perfectly. The real point is that they snapshot the design at `$new()`, in memory as well, and the docs do not say that plainly.
- `?Design` and `vignette("reproducibility")` date the per-subject seeding to "v1.0.6", while `packageVersion()` is 1.0.4 (F4).
- `?DesignSeqOneByOneKK21stepwise` usage shows no `seed` argument, although the article says everything applies to all sequential designs. It works through `...`.
- `?Design`'s worked example points to a test file path (`R/EDI/tests/testthat/test-save-load-design.R`) that users cannot see.
