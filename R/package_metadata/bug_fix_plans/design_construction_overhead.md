# Design Construction Overhead: Version Stamp Disk Read and Eager Covariate Ingestion

> **Depends on:** nothing architectural. Touches `design_abstract.R →
> Design$initialize()` (the `utils::packageVersion("EDI")` call at L233,
> and its twin at L858) and `design_abstract.R →
> covariate_impute_if_necessary_and_then_create_model_matrix()`
> (L1018–1099). `pocock_simon_per_arrival_rebuild.md` (`release_v1_0_5.md
> → TODO-60`) touches the same builder from the sequential side; the two
> are independent in content and can land in either order, but rebase the
> second onto the first.
> **Release target: v1.0.5** (`release_v1_0_5.md → TODO-59`).

Written 2026-10-07, user decision. Found by the 2026-10-07 extension of
`R/benchmark/benchmark_model_fits.R` (new "Design Generation Performance"
table vs. `randomizr`, `blockTools`), root-caused the same day with
`Rprof` and micro-benchmarks against the installed CRAN EDI 1.0.2 (no
rebuild). Under the 2026-09-23 split rule this is a misfiring performance
path that already shipped, not new capability.

## Why

`DesignFixediBCRD` construction + one draw times at 0.03x of
`randomizr::complete_ra()`, and `DesignFixedBlocking` at 0.12x of
`randomizr::block_ra()`, although EDI's blocking *delegates* the draw to
`block_ra`. The randomization itself is microseconds in both packages.
The whole gap is what EDI does before the draw.

## Findings (Rprof over 20–30 repetitions, installed EDI 1.0.2, n = 1000, 4 covariates)

| Component | Cost per design | Notes |
|---|---|---|
| R6 construction, `Design$initialize()` | 1.4 ms | includes `utils::packageVersion("EDI")`, which reads and parses the installed `DESCRIPTION` from disk on every design |
| `as.data.table(private$Xraw)` copy | ~0.2 ms | deliberate copy (see the in-code comment about the bootstrap worker's data.frame) |
| data.table `[` column selections (`..analysis_col_names`, `.SDcols`) | 0.125 ms each, 2–3 per build | data.table dispatch overhead, not data movement |
| `columns_have_missingness_cpp`, `count_unique_values_cpp` | small | fine |
| `create_model_matrix_from_features()` → `model.frame`/`model.matrix` | 0.36 ms | |
| iBCRD draw (`generate_permutations_ibcrd_cpp`, r = 1) | microseconds | |
| `randomizr::block_ra()` (blocking only) | 0.7 ms | the delegated draw; `check_package_installed()` is already cached |

Total about 5 ms for the iBCRD row and 8 ms for blocking versus 0.12 ms
and 0.7 ms for the comparators. For designs whose assignment rule never
reads the model matrix (iBCRD, Bernoulli, Efron, blocking on raw strata,
most sequential designs) the ingestion work is spent before anyone needs
its output; the first consumer is usually the inference object, which is
constructed later.

## Proposal

All items are bit-preserving: they change when work happens, not what is
computed. The model matrix built lazily must be identical to the one
built eagerly (same `Xraw`, same formula, same `count_unique_values_cpp`
filter), which is a direct equality test.

## TODOs

- [ ] TODO-1: **Cache the package version once per session.** Replace the
  two `utils::packageVersion("EDI")` calls with a package-level value set
  in `.onLoad()` (or a memoised getter in `globals.R`). Same string, no
  disk read per design. Add a test that `edi_version_created` still
  equals `as.character(utils::packageVersion("EDI"))`.

- [ ] TODO-2: **Measure construction without ingestion.** Time
  `Design$new()` with `X = NULL` and with covariates, and
  `covariate_impute_if_necessary_and_then_create_model_matrix()` alone,
  to split the remaining 1.4 ms of construction from the ~2.5 ms of
  ingestion before changing either. Promote to `R/benchmark/`.

- [ ] TODO-3: **Build the model matrix lazily for designs that do not
  read it during assignment.** Introduce a private "model matrix is
  stale" flag set when `Xraw` changes, and build on first access of
  `private$X` (or of the public getter) rather than in `initialize()`.
  The sequential classes' per-arrival rebuild is handled by
  `pocock_simon_per_arrival_rebuild.md`; this item covers fixed designs.
  Gate: every public method that returns or uses `X`, `Ximp` or derived
  caches (`get_X()`, `duplicate()`, bootstrap worker creation, the
  inference constructors) must trigger the build. Test: for each fixed
  design class, construct with and without laziness and assert identical
  `X`, `Ximp`, `w` draws for a fixed seed, and identical inference
  estimates.

- [ ] TODO-4: **Trim the data.table round trips inside the builder.**
  Compute `analysis_col_names` and the `count_unique_values_cpp` filter
  in one pass and do a single column selection; skip the `as.data.table`
  copy when there is no missingness and `Xraw` is already a data.table
  that no in-place `set()` call will later mutate (verify the aliasing
  hazard before removing the copy; if unsure, keep the copy). Equality
  test as in TODO-3.

- [ ] TODO-5: **Re-run the design table.** Acceptance: iBCRD row ≤ 1.5 ms
  and blocking row ≤ 2.5 ms at n = 1000 (the delegated `block_ra` draw
  is 0.7 ms of that), with all design rows' `w` draws bit-identical to
  1.0.2 for a fixed seed. Update `benchmark_model_fits.md`.

## Out of scope

- Replacing `randomizr::block_ra` with a native blocking draw (it is 0.7
  ms; the rest of the row is the construction above).
- Sequential designs' O(t) per-arrival cost
  (`pocock_simon_per_arrival_rebuild.md`).
