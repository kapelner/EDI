---
title: TODO-66 post-rebuild dispatch validation
author: Adam
date: 2026-10-18
branch: main
cost: { minutes: 5, tokens: 15208 }
touches:
  - R/package_metadata/future_release_plans/release_v1_0_5.md
  - R/package_tests/ci/test_runtimes.csv
  - R/package_tests/comprehensive_suite_coverage.csv
  - R/package_tests/comprehensive_suite_report.html
  - R/package_tests/comprehensive_suite_results.csv
  - R/package_tests/comprehensive_suite_slowest_cases.csv
  - R/package_tests/comprehensive_suite_workflow_coverage.csv
  - R/package_tests/comprehensive_suite_workflow_only_apis.csv
  - R/EDI/tests/testthat/test-reused-worker-resampling-nondegenerate.R
  - R/package_metadata/new_feature_plans/randomization_ci_affine_shift_reuse.md
---

## Decided
TODO-66 is closed by the non-reusable single-worker clamp plus current-artifact runtime validation: the focused source-loaded dispatch test passed 25 assertions, and three independent fresh R processes completed the ordinary nc=4, B=16 fit with 16 finite results each. The temporary DLL loaded by pkgload had the same MD5 as the installed DLL after rebuild.

## Tried and ruled out
Do not rerun the historical real-fork path in-process: prior evidence shows it can hang indefinitely, while the fixed non-reusable path should not fork. The bounded ordinary checks exercise real estimates without recreating that unsafe path.

## Watch out
This validates current checkout R code against the matching installed native library; it does not claim the native library was built from current C++ sources or identify the exact historical OpenMP/fork failure. A focused regression is behavior evidence, not a coverage-percentage claim.
