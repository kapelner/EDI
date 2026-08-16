# CRAN comments — EDI 1.0.0

<!-- DRAFT (2026-08-15). Placeholders in [brackets] are filled from the final
     pre-submission runs; see release_v1_0_0.md -> Release Gate. Do not
     submit while any [TODO] remains. -->

## Submission

First submission of EDI to CRAN (new package).

## Test environments

* GitHub Actions (continuously, on every push — .github/workflows/R-CMD-check.yaml):
  * macOS (latest), R release
  * Windows (latest), R release
  * Ubuntu (latest), R devel, release, and oldrel-1
  * Ubuntu, R release with no Suggests installed (`_R_CHECK_SUGGESTS_ONLY_`)
  * R-devel with ASAN/UBSAN (rocker/r-devel-san)
  * R-devel under valgrind memcheck
* win-builder: [TODO — release + devel results, date]
* mac-builder: [TODO — result, date]
* Local: [TODO — platform, R version, `NOT_CRAN=false R CMD check --as-cran` result and total check time]

## R CMD check results

[TODO: e.g. "0 errors | 0 warnings | 1 note" from the final win-builder/local runs]

* NOTE: New submission. [Only expected NOTE; justify any others here.]

## Check time and tests

The test suite is intentionally skipped on CRAN (`tests/testthat.R` runs it
only when `NOT_CRAN=true`): it is large, and it runs continuously on our CI
matrix — macOS/Windows/Linux across R devel/release/oldrel-1 with
`--as-cran`, a no-Suggests leg, ASAN/UBSAN, and valgrind (see Test
environments above) — so running it on CRAN's machines would add check time
without adding coverage. Examples run normally.

[TODO: total check time of the final NOT_CRAN=false run.]

## Compiled code

The package compiles a large C++ kernel tree (RcppEigen/RcppNumerical).
ASAN/UBSAN and valgrind runs are part of continuous CI (see Test
environments) and are clean as of [TODO: date/commit].

## Downstream dependencies

There are no reverse dependencies (new package).
