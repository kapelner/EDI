# Benchmark Harness: R6 Construction Inside the Timed Region Misreads Sub-10 ms Rows

> **Depends on:** nothing in the package. Touches only
> `R/benchmark/benchmark_model_fits.R` (the `procedure_specs` and
> `design_specs` blocks, roughly L1891–2104, and the methodology text for
> the two tables added 2026-10-07) and the generated
> `R/package_metadata/benchmark_model_fits.{md,_R.html}` plus their
> tracked copies in `R/benchmark/`. Independent of every item in
> `release_v1_0_5.md` and `release_v1_1_0.md`; it is a measurement fix,
> not a package change, and ships whenever the tables are next
> regenerated.
> **Release target: v1.0.5** (`release_v1_0_5.md → TODO-62`).

Written 2026-10-07, user decision. Found while root-causing the slow rows
of the 2026-10-07 benchmark extension against the installed CRAN EDI
1.0.2.

## Why

The "Exact CI for the log odds ratio" row reports `InferenceIncidExactZhang`
at 0.4x of `fisher.test(conf.int = TRUE)`. Profiled, the CI itself costs
about 1 ms (11 calls to `zhang_exact_fisher_pval_cpp` at 0.09 ms during
the inversion), the same as `fisher.test`'s 1 ms. The other 2 ms of the
row's 2.4 ms is `InferenceIncidExactZhang$new(des)`, which the harness
times on purpose (harness L2020–2022: `edi_expr = quote({ inf =
InferenceIncidExactZhang$new(des); ... })`) because results are cached
per object, so a fresh object is needed per repetition. The same shape
applies to every R6 row of the two new tables: each randomization-test,
bootstrap-CI and design row includes one R6 construction (1.4–2 ms) in
the timed region, which is invisible on a 700 ms row and decisive on a
2 ms one. The comparators construct nothing comparable, so the row
compares construction + work against work.

The construction cost is real and belongs in the report (a user pays it),
but it must be separated from the procedure cost or the table misstates
where the time goes. `design_construction_overhead.md` (`→ TODO-59`)
fixes part of the cost itself; this plan fixes the measurement.

## TODOs

- [ ] TODO-1: **Time construction separately for every R6 row.** For each
  spec in `procedure_specs` and `design_specs`, add an `edi_setup_expr`
  that constructs the object (and for designs, ingests covariates) and
  time it in its own loop with the same adaptive batching. Report three
  EDI columns: `EDI Total (ms)`, `EDI Construction (ms)`, `EDI Procedure
  (ms)`. Measure a procedure directly on a fresh preconstructed object so
  cache hits cannot enter the timed batch; see TODO-2 for the API decision.
  Compute `Speedup` and `Timing Pval` on the procedure column and show the
  total alongside, so neither number is hidden.

- [x] TODO-2: **Decide whether a public cache reset is worth adding.**
  Reusing one object would need a way to clear its result caches; today only
  `clear_likelihood_null_warm_cache()` and
  `clear_likelihood_test_eval_cache()` exist. If a general
  `reset_result_caches()` is not wanted as public API, keep the
  subtraction approach of TODO-1 and say so in the methodology text. Decision:
  do not add a benchmark-only public cache-reset API; `collect_prepared_timing_ms()`
  prepares a fresh inference object immediately before each timed procedure
  batch, and the methodology explains this cache-safe measurement design.
  This design decision is complete independently of the still-open installed
  timing and report-regeneration gates.

- [ ] TODO-3: **Methodology text.** Add a paragraph to both new tables
  explaining the three columns and that the comparators have no
  equivalent construction step. Update the "Row Highlighting" note so
  slower-than-canonical rows get a visible background (today
  `row_bg_color()` leaves them white, which read as "no slow rows" on
  2026-10-07).

  **Source progress 2026-10-10:** `row_bg_color()` now emits light red for a
  finite, significantly slower canonical comparison, and the shared markdown
  methodology and HTML legend define that color.  The harness now gives every
  R6 procedure/design row separate total, construction, and cache-safe
  procedure measurements.  It prepares a fresh configured object outside
  each timed procedure batch, so the procedure cannot become a cached repeat;
  `Speedup` and `Timing Pval` use that procedure column.  The TODO-2 decision
  is no benchmark-only public cache-reset API, because this harness-local
  preparation supplies fresh objects.  The shared procedure/design
  methodology describes the columns.  These TODO-1..3 source changes still
  need a focused installed run and generated-artifact sync, so their
  checkboxes remain open.

- [ ] TODO-4: **Section filter for reruns.** If the harness cannot yet run
  only the procedure and design tables, add a `sections=` argument (the
  full run is about 90 minutes; these two tables are a few minutes) and
  use it to regenerate the md/html and sync the `R/benchmark/` copies.

  **Source progress 2026-10-10:** `benchmark_model_fits.R` now accepts
  `--sections=procedures,designs` (or the space-separated form), defaults to
  the exhaustive five-section run, and validates section names.  Disabled
  sections skip their timing loops; excluding `utility` also skips its
  standalone `sourceCpp()` wrapper compile.  The focused generated report
  names the selected sections.  Regeneration and artifact synchronization
  remain open pending an authorized benchmark run, so this checkbox stays
  unchecked.

  Focused installed-package run completed on 2026-10-14 in an isolated copy
  of the staged benchmark inputs (`EDI 1.0.3`, `--sections=procedures,designs`):
  all 15 procedure and 6 design rows ran, and the generated report contained
  the separate total/construction/procedure columns. The Zhang exact-CI row
  measured 4.55 ms total, 0.85 ms construction, and 3.66 ms procedure versus
  0.75 ms for `fisher.test()` (0.21x procedure speedup), so the plan's parity
  acceptance is not met. The run also confirms the report-generation path;
  tracked generated-artifact synchronization is still open because the
  corresponding workspace report contains staged user edits that must be
  preserved during reconciliation.

  **Isolated report-write diagnostic 2026-10-14:** a final instrumented run of
  the official `--sections=designs` section completed all six rows under
  installed EDI 1.0.3, in `/tmp/edi-todo62-instrumented.xpTSrk/R`. Immediately
  before both final writes, `getwd()` was that R root; destinations resolved
  to its `package_metadata/benchmark_model_fits.md` and
  `package_metadata/benchmark_model_fits_R.html`; both parent directories
  existed and had write access (`file.access(..., 2L) == 0`). The report
  targets did not yet exist, and both writes succeeded without warnings or
  errors. The Markdown report (55,116 bytes) retained the Python section and
  all six design rows. Full row output (`EDI total / construction / procedure;
  canonical; speedup; timing p-value`) was:

  | Design / comparator | EDI ms (total / construct / procedure) | Canonical ms | Speedup | p-value |
  | --- | ---: | ---: | ---: | ---: |
  | iBCRD / `randomizr::complete_ra` | 1.16 / 0.98 / 0.05 | 0.16 | 3.08x | 1.11e-08 |
  | Blocking / `randomizr::block_ra(blocks precomputed)` | 2.85 / 1.55 / 1.31 | 0.67 | 0.51x | 2.98e-08 |
  | BinaryMatch / `nbpMatching::gendistance + nonbimatch + coin flips` | 359.50 / 1.28 / 406.50 | 508.00 | 1.25x | 0.00249 |
  | BinaryMatch / `blockTools::block(n.tr=2,optGreedy) + assignment` | 387.00 / 1.17 / 361.00 | 378.50 | 1.05x | 0.171 |
  | Pocock-Simon / `carat::PocSimMIN(p=0.8)` | 326.00 / 0.88 / 316.50 | 4.70 | 0.015x | 2.36e-11 |
  | Pocock-Simon / `Minirand::Minirand(Range,p=0.8)` loop | 312.00 / 1.00 / 366.50 | 1187.00 | 3.24x | 7.41e-17 |

  The prior two full-section errors were `Error in file(con, "w") : cannot
  open the connection` after the six design rows, but their logs did not
  retain the suppressed open warning/path (`options(warn=-1)`). The original
  `/tmp/edi-todo61-bench-retry.TVVJ2s/R` tree is now sparse; direct small and
  full-report-content write probes there both succeed. The failure is not
  reproducible, so no harness or tracked generated artifact was changed and
  no further full run was attempted. Keep report regeneration/synchronization
  open until it is done from the canonical checkout.

  **Noncanonical Zhang timing probe, 2026-10-15:** one fixed synthetic
  Bernoulli-incidence fixture (`n=1000`, seed 20261015) was timed against
  installed EDI 1.0.3 using fresh R6 objects for every procedure call. Median
  construction was 1.00 ms, Zhang CI procedure 4.83 ms, and
  `fisher.test(conf.int=TRUE)` 0.87 ms (0.18x procedure speedup); the maximum
  absolute log-bound difference was 0.00642. This fixture is not the canonical
  benchmark's generated-data fixture and its one-run result does not replace
  the canonical report or establish a general slowdown. It does show that
  procedure time and interval agreement can vary on a separate data table, so
  the canonical Zhang parity row remains the acceptance target. Harness and
  result: `/tmp/edi-todo62-zhang-procedure-20261015.R` and
  `/tmp/edi-todo62-zhang-procedure-20261015.csv`; no canonical artifacts were
  changed.

  **Canonical Zhang source/profile audit (2026-10-16; isolated installed
  EDI 1.0.3 fixture):** the fixed report fixture was reconstructed from the
  benchmark's `Procedure incidence_bernoulli` seed (`45265`), giving the
  2x2 table `n11=348, n01=152, n10=303, n00=197`. The isolated official
  collector measured 6.387 ms median for the EDI interval procedure versus
  1.105 ms for `fisher.test(conf.int=TRUE)` (0.173x; 10 samples); constructor
  median was 1.255 ms, separate from this procedure comparison. The interval
  bounds differed by at most 0.00442 on the log scale. This confirms the
  canonical procedure parity criterion is unmet; it is not a tracked-report
  regeneration or a package-version comparison.

  Source inspection locates the likely dominant work in the two independent
  `zhang_bisect_ci_boundary()` inversions, not R6 construction: each midpoint
  invokes `zhang_exact_fisher_pval_cpp()`, whose noncentral Fisher routine
  rebuilds the support and its log-combinatorial weights (including repeated
  `lgamma` calls and a temporary vector), normalizes them, then scans the
  support again to sum the two-sided tail. On this table the support has 501
  points (`x=0..500`); the endpoint search uses parameter-width tolerance
  capped at `1e-6`, so this repeats O(501) kernel work across many scalar
  evaluations per endpoint. No call-count or CPU profile was collected, so
  this is a control-flow-based bottleneck diagnosis, not a measured function
  attribution. A low-risk candidate for a future authorized source change is
  a CI-specific prepared-table evaluator that computes the support's
  log-combinatorial base weights once and reuses them as `delta_0` changes,
  while leaving the scalar p-value kernel unchanged. It must be checked
  against the current scalar path and `fisher.test()` on boundary, sparse,
  and canonical tables before claiming parity or replacing the row. The
  isolated run script, summary, and samples are preserved under
  `/tmp/edi-todo62-canonical-zhang-20261016.{R,csv}` and
  `/tmp/edi-todo62-canonical-zhang-20261016-summary.txt`; no shared benchmark
  outputs were edited, and no build/install was run.

  **Synchronized Zhang rerun still required (audit clarification, 2026-10-16):**
  the 10 rows in the preserved CSV are not paired measurements: the script
  collects all EDI timings and then all `fisher.test()` timings in separate
  adaptive batches. Pairing by row index therefore does not synchronize host
  load or thermal state. The fixture and objective are comparable (same seed
  45265, n=1000 table `348,303,152,197`; `num_cores=1`; Fisher bounds logged
  before comparison), but 6.387 ms versus 1.105 ms (`0.173x`) is a sequential
  same-run comparison, not paired evidence. Earlier figures (3.66/0.75 ms and
  4.83/0.87 ms) point in the same direction while varying materially in
  scale. After any optimization, retain the official procedure-only run and
  fixture, and additionally warm both paths then alternate fresh-object EDI
  procedure calls and `fisher.test(conf.int=TRUE)` calls on the same fixed
  table, randomizing path order per pair. Keep construction outside the
  procedure timer and report it separately; preserve all raw paired samples,
  medians/spread and paired speed ratios, plus EDI version, DLL path/mtime,
  R/platform, thread limits, and the fixture table. Recheck both CI endpoints
  against `log(fisher.test(tab)$conf.int)` using the preexisting interval
  tolerance. `R/package_metadata/benchmark_model_fits.md` still has the old
  unsplit row (2.44 ms EDI vs 0.96 ms canonical, 0.39x) and lacks construction
  and procedure columns, so the generated artifacts are not synchronized with
  current harness methodology. This does not change the existing approximate
  1.0x parity target or endpoint criterion. Since “about 1.0x” has no numeric
  band in the plan, that band must be declared before the acceptance run, not
  inferred after observing its result.

  **Synchronized paired measurement (2026-10-16; installed EDI 1.0.3, no
  build/install):** on the same canonical table, 30 warmed pairs alternated
  EDI/Fisher call order at random; each EDI inference object was fresh and
  constructed outside the CI timer. EDI procedure median was 7.750 ms (IQR
  7.090–9.019), versus Fisher 1.717 ms (IQR 1.444–1.794). The paired
  Fisher/EDI speedup median was 0.208x (IQR 0.188–0.246), confirming the
  approximate-1.0x speed gate remains unmet. Separately timed construction
  median was 2.287 ms (IQR 2.091–2.379). The maximum absolute log-bound
  discrepancy remained 0.004413 (EDI log bounds 0.132031, 0.667727; Fisher
  0.127618, 0.668427): endpoint closeness is separate from, and does not
  compensate for, the speed failure. Raw pairs, construction samples,
  metadata, and harness are isolated in
  `scratch/todo62_paired_zhang_20261016_02/` and
  `scratch/todo62_paired_zhang_20261016_01/`; canonical artifacts were not
  touched.

  **Endpoint/kernel-work diagnostic (2026-10-16; installed EDI 1.0.3):** on
  the same fixture, the lower and upper endpoint each evaluated the scalar
  p-value 22 times (including the outside-bracket evaluation and bisection),
  44 calls total. The independently counted endpoint values matched the
  uninstrumented public CI to `1e-12`; counters were added only to a local
  equivalent p-value closure, not by tracing or patching installed bindings.
  For the exact 44 observed deltas, an uninstrumented aggregate scalar-wrapper
  sequence had median 4.619 ms (IQR 3.744–5.496), versus 5.586 ms (IQR
  4.794–7.694) for the public CI in randomized-order pairs; the median ratio
  was 0.709. This sequence includes R `vapply`/wrapper overhead, so it is a
  rough aggregate cost estimate, not attribution to compiled kernel internals
  or proof that support/log-weight construction dominates. The paired run and
  count artifacts are in `scratch/todo62_zhang_endpoint_profile_20261016_01/`.

  **Next source-hotspot step:** quantify the native scalar kernel's internal
  support/log-weight work against a prepared-weight candidate on the canonical
  table and boundary/sparse fixtures. This requires a compiled C++ change and
  therefore explicit compile permission; until then the prepared-table
  candidate remains unvalidated. Preserve the current speed/parity gate and
  the listed scalar, boundary/sparse, serial, and parallel CI checks.

  **Prepared-table candidate architecture (read-only audit, 2026-10-16):**
  Trail callers show two distinct consumer groups for the scalar
  `zhang_exact_fisher_pval_cpp()` kernel. The CI route is
  `InferenceIncidExactZhang$compute_exact_confidence_interval()` →
  `zhang_ci_exact_combined()` → two calls to
  `zhang_bisect_ci_boundary()` (or the two closures in
  `zhang_compute_ci_bounds_parallel()` when `num_cores > 1`) →
  `zhang_compute_exact_pval_reservoir()` → scalar kernel. The independent
  pointwise p-value route is
  `compute_exact_two_sided_pval_for_treatment_effect_by_type()` /
  `zhang_pval_exact_combined()` → `zhang_compute_exact_pval_reservoir()` →
  the same scalar kernel. The benchmark also directly times the scalar kernel;
  the kernel profiler and `test-zhang-fisher-std-lgamma.R` exercise it. Keep
  those non-CI consumers on the existing scalar implementation.

  A safe design boundary is a CI-only, immutable prepared-table value created
  inside `zhang_ci_exact_combined()` from validated reservoir counts. It can
  hold support limits, the observed support index, and each support point's
  delta-independent log-combinatorial base weight. CI endpoint closures then
  pass only the candidate `delta_0` to a new internal evaluator. For the
  serial path, capture this value in the two closures for the lifetime of one
  CI call. For the parallel path, capture/pass an ordinary serializable value
  and let each endpoint worker read its own copy; alternatively prepare once
  per worker if transport/backend semantics require it. Do not introduce a
  mutable process-global cache, an R6 persistent cache, or shared mutable C++
  state. This keeps cache lifetime bounded to one CI request, preserves scalar
  p-value behavior and thread safety, and avoids changing the generic
  `zhang_bisect_ci_boundary()` used by other callers. The exact worker capture
  can avoid cross-worker transport entirely: `zhang_compute_ci_bounds_parallel()`
  sends two endpoint specs through `private$par_lapply()`, which may use a
  persistent socket cluster, mirai daemons, or a lazily created Unix cluster,
  and deliberately falls back to serial when a CI deadline is active (also
  on unsupported non-Unix parallel setups). Prepare the immutable table value
  inside each endpoint worker once, before bisection; the two parallel workers
  then own independent read-only values, while the serial CI path prepares
  once and shares it between its two local endpoint closures. This requires
  no `export_list` or backend-specific closure semantics, no R6 cache, and no
  process-global mutable state.

  Proposed validation before replacing the CI evaluator: (1) compare prepared
  and existing scalar p-values over a fixed delta grid (including 0, both
  tails, and values near the safe log-odds cap) on the canonical 2x2 table,
  a sparse table, and zero-cell/boundary tables; require matching finite/NA
  behavior and tight absolute error (target `<=1e-12`, or document any
  stricter exact-equality result); (2) compare serial and supported parallel
  CI endpoints and verify their ordering/finite-or-infinite behavior; (3)
  compare the canonical endpoint logs with `log(stats::fisher.test(tab)$conf.int)`
  under the existing CI tolerance, plus existing Zhang sparse/zero-cell
  regression references; (4) rerun the scalar kernel's existing direct tests
  unchanged. Performance acceptance should report the same fixture and
  installed-package version, 10+ procedure samples with median and spread,
  constructor separately, total, procedure speedup versus `fisher.test`,
  and maximum absolute log-bound discrepancy. Until this design is built and
  tested under explicit compile permission, it is only a candidate; no parity
  or speedup is claimed.

  **Official six-design report-path recheck (2026-10-15; isolated, not baseline
  promotion):** ran `Rscript benchmark/benchmark_model_fits.R
  --sections=designs` from `/tmp/edi-todo62-official-designs-lBPkQo` against
  installed EDI 1.0.3, with the report and Python-input files staged under
  that temporary tree. No build/install occurred. The process exited 0 with
  `Benchmark complete.`; both generated
  `package_metadata/benchmark_model_fits.md` (55,150 bytes) and
  `benchmark_model_fits_R.html` (18,915 bytes) were written successfully. The
  Markdown retained the Python section and contained all six expected design
  rows plus total/construction/procedure columns. Fresh row values
  (total/construction/procedure; canonical; speedup; Welch p) were: iBCRD
  `1.63/1.69/0.07 ms; 0.29 ms; 3.9x; 9.67e-8`, blocking
  `6.15/2.98/3.53 ms; 1.45 ms; 0.41x; 2.71e-11`, BinaryMatch vs.
  nbpMatching `751/2.51/714 ms; 1207 ms; 1.69x; 0.00113`, BinaryMatch vs.
  blockTools `839/2.46/795.5 ms; 1002 ms; 1.26x; 0.0413`, Pocock-Simon vs.
  carat `757.5/2.06/687 ms; 12.25 ms; 0.018x; 3.7e-11`, and Pocock-Simon
  vs. Minirand `804/1.96/762.5 ms; 2518 ms; 3.3x; 1.15e-7`.

  Compared with the earlier isolated official run above, the row direction is
  stable: iBCRD, nbpMatching, blockTools, and Minirand are faster on EDI's
  procedure measurement; blocking and carat remain slower. Absolute medians
  moved substantially (for example, Pocock-Simon procedure/canonical was
  316.5/4.70 ms vs. 687/12.25 ms now), and separately measured medians are
  not additive (the iBCRD total median is below its construction median).
  Treat these as run-to-run timing variation, not a source regression or a
  replacement for the tracked canonical report. The report-write path is
  reproduced successfully; the separate Zhang parity/artifact-sync gates
  remain open. Isolated outputs are under
  `/tmp/edi-todo62-official-designs-lBPkQo/`.

## Acceptance

The Zhang row shows procedure time at parity with `fisher.test` (about
1.0x) with construction reported beside it; every R6 row in the two
tables shows all three columns; the Python section is still present in
the regenerated md (the harness falls back to
`python/benchmark/benchmark_model_fits_python.html` since 2026-10-07).

**Tracked-artifact preflight (2026-10-18; read-only):** no report was
regenerated or edited. All four tracked outputs still contain the old,
unsplit Zhang row (`2.44 ms` EDI vs. `0.96 ms` Fisher, `0.39x`), so neither
the procedure-only parity gate nor the report synchronization gate is
closed. The two HTML copies are byte-identical (SHA-256
`ae366ee3a325ac42e70dacd55e736d3743529fe6e3680f309973403d3d0f0408`), but
the Markdown copies are not: `R/package_metadata/benchmark_model_fits.md`
has the Oct. 14 OLS batch-kernel follow-up and additional benchmark sections
absent from `R/benchmark/benchmark_model_fits.md` (their SHA-256s are
`27c0153604eadd3ba9578a63457e1ba4106e42a1ed0181e834fc46021dc69ab1` and
`9cf7b03ae0dbc13e4a67ea38c374d80cad8fed700f2ecbe50efd979d40624a7e`,
respectively). The current harness source already emits separate total,
construction, and procedure columns and supports `--sections=procedures,designs`;
the checked-in reports therefore predate the current harness. At synchronization,
preserve/reconcile the Markdown-only material explicitly rather than assuming
the two Markdown files are interchangeable. This preflight does not alter the
previous acceptance: obtain the owner-approved numeric Zhang parity band,
run the synchronized canonical fixture and confirm endpoint tolerance, then
regenerate and reconcile all four outputs from the harness.
