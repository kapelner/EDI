# TODO-55 isolated resume candidate

This is a fresh copy prepared from the preserved disk-full snapshot at
`R/package_tests/todo55_diskfull_snapshot_20261016/`. The preserved snapshot
was not edited. The copied result CSV is still malformed at its trailing
record; no truncation, repair, or execution has been done yet.

The copied runner is at
`R/package_tests/todo55_resume_candidate_20261016/R/package_tests/comprehensive_tests.R`.
Executing it by absolute path should keep the generated result alongside the
copied script, isolated from canonical outputs. Expected output filename:

```text
comprehensive_tests_results_nc_1_proportion_filtered_class-InferenceAllSimpleAverageDiff_InferenceAllSimpleMeanDiffPooledVar_InferencePropGCompMeanDiff_InferenceAllSimpleWilcox.csv
```

Planned command after `/tmp` has safely reclaimed capacity and the package
database is confirmed readable:

```sh
Rscript /home/kapelner/workspace/EDI/R/package_tests/todo55_resume_candidate_20261016/R/package_tests/comprehensive_tests.R \
  40 1 proportion NA \
  'InferenceAllSimpleAverageDiff|InferenceAllSimpleMeanDiffPooledVar|InferencePropGCompMeanDiff|InferenceAllSimpleWilcox' \
  NA NA NA NA fork=TRUE
```

Before execution, repair only the candidate CSV by removing its incomplete
last record, validate that it reads with exactly 23,418 complete `ok` rows,
and confirm the output path resolves to this candidate directory. Run one core
only and stop on any disk or package-load error. Afterward, audit required
keys, statuses, duplicates, and missing rows; do not merge into canonical
artifacts without separate authorization.
