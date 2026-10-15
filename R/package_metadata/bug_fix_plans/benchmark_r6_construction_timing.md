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

- [ ] TODO-2: **Decide whether a public cache reset is worth adding.**
  Reusing one object would need a way to clear its result caches; today only
  `clear_likelihood_null_warm_cache()` and
  `clear_likelihood_test_eval_cache()` exist. If a general
  `reset_result_caches()` is not wanted as public API, keep the
  subtraction approach of TODO-1 and say so in the methodology text.

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

## Acceptance

The Zhang row shows procedure time at parity with `fisher.test` (about
1.0x) with construction reported beside it; every R6 row in the two
tables shows all three columns; the Python section is still present in
the regenerated md (the harness falls back to
`python/benchmark/benchmark_model_fits_python.html` since 2026-10-07).
