# Public Argument Combination Runner

The public argument-combination runner complements `package_tests/comprehensive_tests.R`.

Use `comprehensive_tests.R` for end-to-end statistical workflows across datasets, response families, designs, and inference classes. Its durable result keys are `dataset`, `response_type`, `design`, `inference_class`, and `function_run`.

Use the public argument-combination runner when the question is whether legal public API argument values also work together. It generates fixture-backed calls from the public API inventory, extracted `checkmate` contracts, the reviewed argument registry, and cross-argument constraints.

The two result families intentionally stay separate:

- Statistical comprehensive results keep the `comprehensive_tests_results_*` naming pattern.
- Argument-combination results keep the `public_argument_combination_*` naming pattern.
- Integrated argument-combination files add join-compatible labels without replacing statistical results.

Primary commands:

```sh
Rscript package_tests/generate_public_argument_combinations.R
Rscript package_tests/run_public_argument_combinations.R
Rscript package_tests/analyze_public_argument_combinations.R
Rscript package_tests/public_argument_combination_integration.R
Rscript package_tests/check_public_argument_combination_quality_gates.R report
```

Entry-point commands:

```sh
Rscript package_tests/run_public_argument_combination_ci.R
Rscript package_tests/run_public_argument_combination_nightly.R
```

When `EDI` is not installed in the active R library, the entry points fall back to `EDI.Rcheck/EDI` if that checked package directory exists.

The CI entry point runs the bounded smoke target set and writes the standard argument-combination artifacts. The nightly entry point defaults to the same bounded target set; pass `ALL` as the first argument to generate from every registry target, or pass a regular expression to select a target subset.

Integrated artifacts:

- `package_tests/public_argument_combination_cases_integrated.csv`
- `package_tests/public_argument_combination_results_integrated.csv`
- `package_tests/public_argument_combination_coverage_integrated.csv`

Integrated rows include `response_type`, `design_type`, `design`, `inference_class`, `function_run`, `dataset_name`, and `dataset` where fixture or target metadata can provide them. `dataset_name` and `dataset` use the deterministic fixture id because argument-combination cases are fixture-backed rather than dataset-backed.

To promote a failure into a focused `testthat` regression test:

1. Open `package_tests/public_argument_combination_failures.csv`.
2. Copy the failing `target`, `fixture_id`, `argument_signature`, `status`, `invariant_status`, and `error_message`.
3. Build the same fixture with `build_public_argument_fixtures(fixture_ids = "<fixture_id>")`.
4. Recreate the public call from `argument_signature`.
5. Assert the documented behavior in the relevant `EDI/tests/testthat/` file.

## Data-shape matrix

The cases above vary argument values on the canonical fixtures, which are all `n = 8`, fixed `n`,
equal blocks and clusters, complete covariates, right censoring at most and no treatment effect.
The data-shape matrix (v1.0.7-TODO-41) varies the data instead:

| Axis | Values |
|---|---|
| design | `DesignFixedBernoulli`, `DesignFixedBlocking`, `DesignFixedCluster`, `DesignFixedBlockedCluster`, `DesignSeqOneByOneBernoulli`, `DesignSeqOneByOneKK21` |
| response type | all six |
| sample size | fixed `n`; `n = NULL` with 30 of 40 responses in (mid-stream); `n = NULL` with all in (end) |
| group sizes | equal; unequal (strata of 17 and 23, clusters of 2 to 6) |
| censoring | none, right, interval (survival only) |
| missing covariate | no; yes (two `NA`s in `x1`) |
| effect | null; strong (0 far outside the bootstrap distribution) |
| inference class | a few per response type, plus the KK classes on KK21 |

Cells cover every legal pair of axis values, not the full factorial (`pairwise_data_shape_cells()` in
`generate_public_argument_combinations.R`; legality is `data_shape_cell_violations()` in
`public_argument_combination_constraints.R`). Each cell runs `compute_estimate`, the asymptotic CI and
p-value, the bootstrap CI and p-value (`B = 501`), the randomization p-value (`r = 101`) and the
jackknife CI. An `InferenceRandCustom` block adds R and C++ statistics that return one value, several
values or `NA`. Fixtures are built from their ids (`build_data_shape_fixture()`), so a design EDI
refuses to build becomes that cell's error rather than stopping the run.

```sh
Rscript package_tests/run_public_argument_data_shape_matrix.R [out_dir] [cell_filter] [max_cells] [timeout_sec]
EDI_DATA_SHAPE_LOAD_ALL=1 Rscript package_tests/run_public_argument_data_shape_matrix.R "$TMPDIR/ds"   # source tree, compile = FALSE
```

It writes `public_argument_combination_data_shape_{cases,results,failures,summary}.csv` to `out_dir`.
Every result row (here and in the main runner) has an `output_outcome`: `finite`, `warned_na`,
`recorded_na` (all `NA`, no warning, only a reason stored on the object), `silent_na`, `nonfinite`,
`non_numeric`, `clear_error`, `unclear_error` (an R or C++ internal error such as "missing value where
TRUE/FALSE needed"), `unsupported` or `not_run`. A cell passes with finite output, a warned `NA` or a
clear error. The failures file lists `silent_na`, `recorded_na`, `unclear_error`, `nonfinite` and failed
invariants, and its `known_todo` column names the open release TODO a failure is already filed under.
