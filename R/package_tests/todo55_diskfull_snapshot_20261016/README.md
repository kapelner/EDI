# TODO-55 isolated sweep: disk-full snapshot

This directory preserves a copy of the failed isolated run's scratch artifacts.
The original under `/tmp/edi-todo55-sweep.TcjIMU/` was left untouched. No
canonical comprehensive result/report was modified.

## Run

Executed the copied `comprehensive_tests.R` by its absolute path, one core,
with 40 reps and a filtered proportion/inference-class slice:

```sh
Rscript /tmp/edi-todo55-sweep.TcjIMU/R/package_tests/comprehensive_tests.R \
  40 1 proportion NA \
  'InferenceAllSimpleAverageDiff|InferenceAllSimpleMeanDiffPooledVar|InferencePropGCompMeanDiff|InferenceAllSimpleWilcox' \
  NA NA NA NA fork=TRUE
```

The process terminated with exit status 1 after `/tmp` ran out of space while
appending a CSV record. It reached replicate 20. The copied CSV is 16,990,208
bytes and has SHA-256:

```text
2d4225a384b914dfa0624f4765f832fe8f2e8e633bdf3cc02a97eb35c98b93e5
```

Reading the incomplete CSV reported EOF inside a quoted string. Rows through
replicate 19 are complete (22,952 rows); replicate 20 has 467 parseable rows,
with 466 complete `ok` rows and one incomplete trailing row. Thus the parsed
total is 23,419 including the incomplete row; 23,418 complete rows are marked
`ok`. The final complete record is record id 23418:

```text
rep=20, beta_T=0, dataset=diamonds, response=proportion,
design=FixedMatchingGreedy,
inference=InferenceAllSimpleAverageDiff [design_formula=~1],
function=compute_bayesian_bootstrap_confidence_interval_wald, status=ok
```

The trailing record starts `compute_bayesian_bootstrap_confidence_interval_bca`
but is cut off mid-quoted field. Preserve this snapshot; any repair or resume
must use a further copy in an isolated output tree.

## Continuation facts / safe plan

- The driver is resumable from existing successful rows: startup loads the
  output CSV, seeds the completion cache from `status == "ok"`, and skips the
  matching `(rep, beta, dataset, response, design, inference, function)` keys.
- Argument 8 is a single-replicate filter, not a start/end range. To continue
  the full bounded slice, rerun the same 40-rep command against a valid output
  CSV; the cache should skip the existing successful keys and compute missing
  ones. Do not launch until explicitly approved, and do not point it at the
  canonical output.
- Before continuation, copy this snapshot into a fresh isolated tree, truncate
  only that continuation copy at the incomplete final CSV record, validate its
  header and successful-row count, and execute the copied script by absolute
  path (never source it from the checkout cwd). Keep output off `/tmp` while
  that filesystem remains full; verify available space and package database
  readability before running.
- After a run, inspect statuses and key coverage from that isolated result,
  confirm no duplicates or missing required rows, and preserve the new output
  separately. Do not reconcile into canonical files without separate approval.

Copied alongside this note: the driver, `_dataset_load.R`, and
`helper-likelihood-method-smoke.R` used by the isolated harness.
