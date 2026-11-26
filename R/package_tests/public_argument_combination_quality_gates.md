# Public Argument Combination Quality Gates

The quality-gate checker enforces the argument-combination rollout without blocking broad coverage work too early.

Command:

```sh
Rscript package_tests/check_public_argument_combination_quality_gates.R report
Rscript package_tests/check_public_argument_combination_quality_gates.R ci
Rscript package_tests/check_public_argument_combination_quality_gates.R strict
```

Modes:

- `report`: writes gate CSVs and exits nonzero only for always-hard integrity failures.
- `ci`: same hard failures as `report`; this is intended for the bounded smoke/CI entry point.
- `strict`: also promotes future hard gates such as uncovered high-priority public APIs.

Outputs:

- `package_tests/public_argument_combination_quality_gates.csv`
- `package_tests/public_argument_combination_quality_gate_summary.csv`

Gate rows include `gate`, `severity`, `target`, `arg`, `value_expr`, `detail`, and `exempted`.

Implemented gates:

- `export_without_inventory`: exported `EDI` namespace symbols missing from the public API inventory.
- `multi_arg_without_combination_coverage`: public APIs with more than one configurable argument and no legal-combination case.
- `contract_without_registry_coverage`: public `checkmate` contracts with no registry target/argument row.
- `registry_value_never_selected`: registry values not selected by any valid generated case in the current artifact set.
- `unknown_constraint_status`: generated cases with an unrecognized constraint status.
- `ci_tier_unexpected_error`: smoke/CI result rows with unexpected errors or invariant failures.
- NA audit (v1.0.6-TODO-54, shared with `check_comprehensive_suite_quality_gates.R`; code and rule in `na_audit_gate.R`): an estimate, CI bound or p-value that comes back NA/NaN with no warning or error is a failure, read from the results' `output_outcome` column (`silent_na`, and `recorded_na` = a reason stored on the object but no warning) in `public_argument_combination_results.csv` and, when present, `public_argument_combination_data_shape_results.csv`. Gates: `silent_na_output` (hard), `silent_na_output_missing_input` (hard; a data-shape fixture with a missing covariate), `warned_na_output_not_allowlisted` (report), `na_output_allowlisted_todo` / `na_output_allowlisted_intentional` (report), `na_allowlist_invalid` (hard), `na_allowlist_unused` (report), `na_audit_not_evaluable` (report; results predate `output_outcome`). The only way past is a row of `package_tests/na_audit_allowlist.csv`: `kind = todo` citing an open release-prefixed TODO (the gate checks the release plans, and the row turns into `na_allowlist_invalid` once the TODO closes), or `kind = intentional` naming the `warning_class` a documented NA return raises.

Temporary exemptions can be added to `package_tests/public_argument_combination_gate_exemptions.csv` with exact `gate`, `target`, `arg`, and `value_expr` keys plus a reason. Empty exemption files are valid.
