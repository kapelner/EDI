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

- [x] TODO-1: **Cache the package version once per session.** Replace the
  two `utils::packageVersion("EDI")` calls with a package-level value set
  in `.onLoad()` (or a memoised getter in `globals.R`). Same string, no
  disk read per design. Add a test that `edi_version_created` still
  equals `as.character(utils::packageVersion("EDI"))`.

- [x] TODO-2: **Measure construction without ingestion.** Time
  `Design$new()` with `X = NULL` and with covariates, and
  `covariate_impute_if_necessary_and_then_create_model_matrix()` alone,
  to split the remaining 1.4 ms of construction from the ~2.5 ms of
  ingestion before changing either. Promote to `R/benchmark/`.

- [x] TODO-3: **Build the model matrix lazily for designs that do not
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

- [x] TODO-4: **Trim the data.table round trips inside the builder.**
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

  Installed-package rerun on 2026-10-14 (EDI 1.0.3; n=1000, batch=100,
  seven repeats) met both timing limits: iBCRD construction + registration +
  assignment median 0.83 ms; blocking construction + registration +
  assignment median 1.91 ms. Lazy registration was 0.16 ms/call and deferred
  `get_X()` was 1.67 ms/call. The focused design/version/resample test passed
  17 assertions. The broad fixed-seed assignment equivalence against 1.0.2
  was not established by this run, so TODO 5 remains open pending that check.

  **Repeat diagnostic 2026-10-15:** the same installed-package benchmark
  script was run twice without compiling/installing: first at `n=1000`,
  `batch=50`, five repeats (iBCRD row 3.50 ms; blocking 5.90 ms), then with
  the acceptance settings `batch=100`, seven repeats (iBCRD 4.15 ms; blocking
  6.12 ms). Both exceed the timing targets and conflict sharply with the
  2026-10-14 measurements above. The per-stage CSVs are isolated at
  `/tmp/edi-todo59-installed-20261015.csv` and
  `/tmp/edi-todo59-installed-exact-20261015.csv`; no canonical benchmark
  artifact was changed. This is a repeatability warning, not evidence to
  replace the earlier acceptance result: TODO 5 remains open pending a
  controlled installed-package run and the missing fixed-seed 1.0.2
  assignment comparison.

  **Affinity-controlled repeat 2026-10-16:** to reduce scheduling variation,
  three more exact-acceptance runs (`n=1000`, `batch=100`, seven repeats)
  were pinned to allowed CPU 0. The host load average before this series was
  8.22 on 12 visible CPUs. The iBCRD row medians were 3.09, 2.87, and 2.86 ms;
  the blocking row medians were 6.88, 6.33, and 5.98 ms. All six exceed the
  respective limits, and the three pinned repetitions are substantially more
  consistent with each other than with the 2026-10-14 pass. Raw stage CSVs:
  `/tmp/edi-todo59-pinned-core0-20261016.csv`,
  `/tmp/edi-todo59-pinned-core0-b-20261016.csv`, and
  `/tmp/edi-todo59-pinned-core0-c-20261016.csv`. These remain diagnostic;
  the high host load and absent environment metadata for the earlier run mean
  they do not establish a code regression. A quiet-host controlled comparison
  and the 1.0.2 fixed-seed assignment baseline are still needed.

  **Compile-free source/stage audit (2026-10-16):** read-only inspection of
  the three pinned raw CSVs shows `DesignFixediBCRD$new() only` medians of
  2.05, 2.30, and 2.06 ms, already above the complete iBCRD acceptance ceiling
  of 1.5 ms; lazy registration itself is only 0.56–0.59 ms. Deferred first
  `get_X()` is 5.72–6.45 ms but is not part of the measured iBCRD
  construction/registration/assignment row. The combined blocking row is
  5.98–6.88 ms versus a 2.5 ms ceiling, while the stated delegated `block_ra`
  draw accounts for only 0.7 ms. Source inspection shows each fixed-design
  constructor routes through `DesignFixed` into `Design$initialize()`, which
  allocates five length-`n` response/assignment vectors when `n` is fixed;
  iBCRD then also initializes its implicit `m` block. This is a plausible
  allocation-cost probe, not proof that any allocation is unnecessary or safe
  to remove. No source/benchmark changes or timing runs were made in this
  audit. Next, once TODO-56 releases the CPU, perform a scratch-only,
  environment-recorded exact-acceptance rerun and add constructor-only
  `n=NULL` versus `n=1000` diagnostic measurements (plus constructor,
  registration, and assignment stages for blocking). If fixed-size allocation
  dominates as predicted, evaluate an opt-in/lazy vector-allocation design
  only with tests covering fixed-sample getters, assignments, and the full
  1.0.2 fixed-seed `w` baseline; otherwise revisit the timing target or
  identify the blocking stage before proposing a code edit. Keep all outputs
  in unique scratch paths and leave the canonical benchmark unchanged.

  **Source-backed allocation follow-up, 2026-10-16:** the fixed-size path
  allocates `y`, `y_original`, `w`, `y_L`, and `y_R` once in
  `Design$initialize()`; iBCRD then creates its single-block `m` vector once
  through `set_m(rep(1L, n))`. This is per-object construction, not a repeated
  allocation inside assignment. The exact-response setter indexes all five
  response/assignment vectors, and the public censoring-bound getters plus
  `get_effective_time()` preserve length-`n` semantics, so simply omitting
  `y_L`/`y_R` for non-survival designs is not a drop-in change. Lazy bounds
  would require a broader storage/API adjustment and synthesize equivalent
  vectors at later access; the current evidence does not show that it would
  materially improve the 1.5 ms ceiling. The raw-covariate copy remains
  intentional because exposed imputed data must not alias caller-mutable
  input. No low-risk allocation removal is supported by this source audit;
  do not edit or benchmark it based on this probe alone. At the time of this
  audit, defer timing while TODO-56's CPU-intensive study is active. Keep
  TODO-5 open for the quiet-host acceptance rerun and fixed-seed 1.0.2
  assignment comparison.

  **Parity-artifact audit 2026-10-18:** the searched installed library and
  retained temporary R-library copies identify as EDI 1.0.3; no installed
  EDI 1.0.2 binary or fixed-seed `w`-vector artifact was found. A candidate
  source archive exists at
  `/tmp/claude-1000/tmp.tRezeJm6cW/EDI_1.0.2.tar.gz` (SHA-256
  `01f79c8d52678cbd95af1b7ed25609a8f1c340f059531939c9c82fddd5c47af9`). Its
  embedded `DESCRIPTION` says EDI 1.0.2, `Repository: CRAN`, packaged
  2026-09-25; the archive contains source but no `libs/EDI.so` or object
  files. No trusted CRAN checksum or other provenance record for this
  temporary copy was found, so the internal metadata and locally computed
  hash do not authenticate it as the official baseline. A separate extracted
  `/tmp/claude-1000/EDI` tree is also labeled 1.0.2, but its `DESCRIPTION`
  hash differs from the archive's embedded file and they must not be treated
  as identical. The extant TODO-59 temporary CSVs are timing/stage reports,
  not assignment vectors. Until an authentic installed 1.0.2 baseline (or
  retained fixed-seed vectors with provenance) is available, exact assignment
  parity remains unavailable; do not infer it from the checkout's current
  fixed-seed tests.

  **Installed focused regression, 2026-10-18:**
  `test-design-covariate-missingness-methods-and-subject-data-cache-reference.R`
  passed 57 expectations (8 test blocks, 0 failures or warnings) against
  installed EDI 1.0.3, built 2026-10-18 00:57:28 UTC; `EDI.so` MD5
  `dd43c5d0e11708aea17ba82b900f66d1`. It checks lazy behavior against an
  eager comparison object, but the installed build metadata does not identify
  a checkout SHA, so this is installed-package evidence only. The output log
  is `/tmp/edi-todo59-installed-fixed-design-laziness-20261018.log`.
  **Timing evidence remains inconsistent:** the 2026-10-14 medians (0.83 ms
  iBCRD; 1.91 ms blocking) are within the 1.5/2.5 ms caps, while the exact
  settings on 2026-10-15 measured 4.15/6.12 ms and the three CPU-pinned
  2026-10-16 runs measured 2.86–3.09/5.98–6.88 ms, above both caps. Per the
  source/stage audit above, these measurements do not justify a speculative
  allocation change. The quiet-host acceptance rerun and authentic EDI 1.0.2
  assignment parity remain open.

  **Operational recheck, 2026-10-20:** the linked release checklist's
  read-only TODO-56 recheck found no `R`/`Rscript` process or open handles in
  the candidate/slice directories; the sequential pilot runs were also
  confirmed to terminate. This supersedes the earlier CPU-contention deferral
  only: TODO-56's artifact/reconciliation gate remains open, and those facts
  do not establish a quiet host during a future run or provide new timing
  evidence. TODO-5 can proceed once the host is otherwise quiet and the
  installed package/DLL identity is recorded; no benchmark was run for this
  update.
  **Reproducibility-gate improvement, 2026-10-20:** the benchmark sidecar
  now records `git status --porcelain=v1 --untracked-files=all` and a SHA-256
  of `git diff --binary HEAD`, in addition to HEAD and DLL identity. A bounded
  source-loaded smoke invocation (`n=5`, `batch=1`, one repeat) emitted both
  fields to `/tmp/edi-todo59-provenance-smoke-20261020.csv.provenance.txt`;
  the CSV and sidecar hashes are `e785cc58d05a0f33874db7b0ea0b7053e322cf8d9c39cd78e6501c6c6a7a631b`
  and `5728a707b4f604c7abe56878acfe5448624cfc0acb00a718d2620ab7c2cdaa69`.
  The smoke test used checkout R sources with `compile=FALSE`, installed EDI
  1.0.3's existing DLL (SHA-256
  `5a0b94978e5d9150d2aa6f69df7135a164fe032b3a3e301495c5cfd7f6ca3224`), and
  records a dirty worktree plus tracked-diff hash
  `0a4793d6e51ba10d15ef569f83e3d5a4a4a3a1aea029b0d5cd9d0077faace6a9`.
  This is metadata-path verification only, not a performance measurement or
  acceptance run. The status lists untracked paths but does not hash their
  contents. The quiet-host timing and authentic EDI 1.0.2 fixed-seed weight
  baseline remain missing.
  **Provenance failure-path hardening, 2026-10-20:** `read_benchmark_git_state()`
  now distinguishes a failed/unavailable Git status command from a successful
  empty status, and marks the diff digest unavailable when Git cannot run. The
  focused source-level test
  `test-benchmark-design-construction-provenance-reference.R` passed 17
  assertions for a clean temporary repository, a dirty tracked file, an
  untracked path (with tracked-diff digest unchanged), and a missing Git
  executable. It writes only its temporary repository under the system temp
  directory; no full benchmark or canonical output was used.
**Untracked-source content provenance regression, 2026-10-20:** the prior
status field captured untracked paths but did not distinguish different
contents at the same path, while the tracked-diff hash correctly excludes
untracked files. The harness now hashes a sorted Git untracked-file
path/content manifest and records that digest in the sidecar. The existing
temporary-repository test was extended to prove the digest changes when only
an untracked file's contents change, while status and tracked-diff digest stay
the same. It passed 24 expectations against installed EDI 1.0.3; it exercises
only the parsed Git-state helper and does not launch the timing benchmark. The
quiet-host timing and authentic EDI 1.0.2 assignment-parity gates remain open.

**Preserved-run reconciliation (2026-10-20):** the Oct 19 acceptance-settings
CSV and provenance sidecar are still present under
`/tmp/edi-todo59-design-bench-LIsn6K/`; their SHA-256 hashes match the values
recorded above, and their rows reproduce the logged 1.45 ms iBCRD and 3.65 ms
blocking medians (`n=1000`, `batch=100`, seven repeats). This confirms the
artifact/summary linkage, not a quiet-host acceptance result: the recorded
load was 3.81/4.23/4.23 at start and 3.94/4.23/4.23 at finish. Its EDI 1.0.3
DLL hash (`2de0c2d4918cb7fbd74d35a05c32893bfe58b00429a09d3ae6851c0e43c6946a`)
differs from the currently installed EDI 1.0.3 build (2026-10-20 07:40:04 UTC;
SHA-256
`db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`), which
matches checkout `R/EDI/src/EDI.so`; the Oct 19 sidecar records HEAD but not
the worktree diff fingerprint now emitted by the harness. At this audit, load
was 5.14/5.17/5.14 on 12 visible CPUs and no R/Rscript process was live, so no
timing run was started. The explicit 1.5/2.5 ms ceilings are unchanged; a
current quiet-host run with installed DLL and checkout status/diff provenance,
plus an authentic EDI 1.0.2 fixed-seed assignment artifact, remain the exact
acceptance inputs.

**Closure recipe and unresolved dependencies (2026-10-21):** when the user
authorizes the run in a quiet window, execute the installed-package harness
with a unique, previously nonexistent scratch CSV path, e.g.
`Rscript R/benchmark/benchmark_design_construction.R 1000 100 7 /tmp/edi-todo59-acceptance-<unique>.csv`.
Do not set `EDI_BENCH_SOURCE`; the paired `.provenance.txt` must show the
installed package and loaded R-namespace payload, native DLL hash, checkout
HEAD/status/diff and untracked-content manifest, R/session information,
thread environment, host load/affinity at both ends, and exact `n=1000`,
`batch=100`, seven repeats, seed 5901. Reconcile all ten output stages and
require the median `iBCRD construction + registration + assignment` to be
<= 1.5 ms and `blocking construction + registration + assignment` <= 2.5 ms;
retain the CSV and sidecar hashes without replacing older diagnostic artifacts.
The plan defines “quiet host” qualitatively but gives no numeric load cutoff;
if release acceptance needs a mechanically enforced threshold, the maintainer
must specify it before the run rather than deriving one from the failed
high-load measurements. The independent parity gate additionally needs an
authenticated EDI 1.0.2 package (or trusted checksum/signature) and recorded
same-seed assignment vectors for every concrete randomization-capable design
in `test-seed-reproducibility-all-designs.R`. Existing fixed-seed unit tests
and the unsigned local `v1.0.2` source ref do not supply that historical
artifact. No benchmark, package install, or source change was made for this
recipe; both acceptance gates remain open.

**Current-artifact identity recheck, 2026-10-21 (read-only):** the retained
Oct 19 acceptance-sized timing CSV and sidecar still hash to
`be8d37c0715d4422904d95d5d4b117d07573f43f52690b209c9ab72776f75ba4` and
`855f3c7f4ef79852a1a66cd05510bb8902b0f11a1b3e2f8fd9af7902ecc66c88`;
their run DLL SHA-256 remains `2de0c2d4918cb7fbd74d35a05c32893bfe58b00429a09d3ae6851c0e43c6946a`.
The Oct 20 provenance-smoke CSV/sidecar also retain their recorded hashes
`e785cc58d05a0f33874db7b0ea0b7053e322cf8d9c39cd78e6501c6c6a7a631b` and
`5728a707b4f604c7abe56878acfe5448624cfc0acb00a718d2620ab7c2cdaa69`; that
`n=5`, `batch=1`, one-repeat source-loaded smoke used DLL SHA-256
`5a0b94978e5d9150d2aa6f69df7135a164fe032b3a3e301495c5cfd7f6ca3224` and
load 4.24, so it is metadata-only. The installed package reports
`Built: 2026-10-21 11:12:19 UTC`; its DLL and checkout `R/EDI/src/EDI.so`
currently have the same SHA-256,
`f7cf39dec10be2caaf84f8813d38e2b0d1d8be1b9a070b0f30bd42f62d9006c7`.
Thus both retained runs use a different native artifact from the current
installation/checkout. Matching current DLL bytes do not attest the dirty
checkout's R payload or repair either run's host conditions. The quiet-host
acceptance run and authenticated EDI 1.0.2 fixed-seed assignment parity remain
open; no benchmark or test was run for this recheck.

## Implementation and validation (2026-10-09)

TODOs 1--4 are implemented. `edi_package_version()` now reads the version from
the session cache populated by `.onLoad()`. Fixed designs register `Xraw` and
mark their analysis matrix stale; `get_X()`, `get_X_imp()`, inference, shared
subject-data construction, and every fixed assignment rule that consumes
`private$X` force the same builder on first use. The builder now selects
analysis/nonconstant columns in one data.table subset. The raw/imputed copy was
deliberately retained because `get_X_imp()` exposes the table and aliasing it to
`Xraw` would allow caller-side `:=` to corrupt the raw covariates.

The focused, reusable stage benchmark is
`R/benchmark/benchmark_design_construction.R`. A source-loaded, non-compiling
run (`n=1000`, batches of 40, five repeats) measured medians of 0.925 ms for
construction alone, 0.250 ms for lazy registration, and 3.125 ms for the
deferred first `get_X()`. The complete source-loaded rows were 1.925 ms for
iBCRD and 4.225 ms for blocking while the two full comprehensive-regeneration
jobs were running concurrently. These figures are diagnostic rather than the
installed-package acceptance run used by `benchmark_model_fits.md`.

Focused regression coverage passes 57 expectations in
`test-design-covariate-missingness-methods-and-subject-data-cache-reference.R`;
the all-design seed/replay suite passes 25 expectations. These establish lazy
state, equality of `X`/`Ximp`, fixed-seed assignment equality, identical OLS
estimates, and unchanged version stamps. TODO-5 remains open because updating
the installed-package benchmark requires rebuilding/installing the checkout,
which this task explicitly forbids without separate permission.

Follow-up source audit (2026-10-11): `Inference$get_X()` bypassed the design
object's lazy-current gate and only rebuilt when the stored matrix was `NULL`.
For a sequential Pocock--Simon design, materializing a prefix matrix then
finishing enrollment leaves a non-`NULL`, stale prefix; an inference object
could therefore capture too few covariate rows. The accessor now also rebuilds
when `model_matrix_stale` is true. A focused regression materializes four of
eight rows, completes enrollment, then verifies that OLS construction receives
all eight rows and its estimate agrees with `lm.fit`. This is source-level
validation only; the installed benchmark gate remains TODO-5.

Focused source-overlay recheck (2026-10-20):
`pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE, export_all = FALSE)`
followed by `testthat::test_file("R/package_tests/testthat_bulk/test-pocock-simon-level-rows-and-binary-match-structure-reference.R", reporter = "summary")`
completed successfully with no failures, warnings, or skips. The tested R
namespace was loaded from the checkout; pkgload reused a temporary copy of
the existing `EDI.so`. Checkout `R/EDI/src/EDI.so` and installed EDI 1.0.3's
`libs/EDI.so` had identical SHA-256
`5a0b94978e5d9150d2aa6f69df7135a164fe032b3a3e301495c5cfd7f6ca3224`. This
checks the stale-prefix refresh and OLS reference against that reused native
artifact, not a rebuilt checkout. It does not alter the quiet-host timing or
authentic EDI 1.0.2 assignment-parity gates.

## Out of scope

- Replacing `randomizr::block_ra` with a native blocking draw (it is 0.7
  ms; the rest of the row is the construction above).
- Sequential designs' O(t) per-arrival cost
  (`pocock_simon_per_arrival_rebuild.md`).
