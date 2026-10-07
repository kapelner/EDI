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
  (ms)` = total − construction (procedure measured directly where the
  object can be reused, which requires a public cache reset; see TODO-2).
  Compute `Speedup` and `Timing Pval` on the procedure column and show the
  total alongside, so neither number is hidden.

- [ ] TODO-2: **Decide whether a public cache reset is worth adding.**
  Measuring the procedure directly (fresh caches, same object) needs a
  way to clear an inference object's result caches; today only
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

- [ ] TODO-4: **Section filter for reruns.** If the harness cannot yet run
  only the procedure and design tables, add a `sections=` argument (the
  full run is about 90 minutes; these two tables are a few minutes) and
  use it to regenerate the md/html and sync the `R/benchmark/` copies.

## Acceptance

The Zhang row shows procedure time at parity with `fisher.test` (about
1.0x) with construction reported beside it; every R6 row in the two
tables shows all three columns; the Python section is still present in
the regenerated md (the harness falls back to
`python/benchmark/benchmark_model_fits_python.html` since 2026-10-07).
