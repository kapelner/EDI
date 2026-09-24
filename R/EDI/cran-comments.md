# CRAN comments — EDI 1.0.2

> **Version plan (2026-09-24, user decision, superseding an earlier same-day
> note that named 1.1.0):** the first CRAN submission is **v1.0.2**. Versions
> 1.0.0 and 1.0.1 were GitHub-only releases. The test-environment and
> check-result details below were recorded for the 1.0.1 content and must be
> re-run and refreshed for 1.0.2 (a clean `R CMD check --as-cran`, a fresh
> win-builder run, and a fresh ASAN/UBSAN and valgrind confirmation) before
> submission.

## Submission

First submission of EDI to CRAN (new package).

## R CMD check results

Status: 0 WARNINGs, 0 ERRORs, 1 NOTE.

* NOTE: New submission. (Expected, unavoidable for a first CRAN submission.)

INFO (not a NOTE): installed package size 25.0Mb (R 13.8Mb, help 2.6Mb, libs
8.1Mb) — the package compiles a large C++ kernel tree (RcppEigen/
RcppNumerical/LBFGSpp) covering every response-type/design combination;
size is dominated by compiled code and documentation, not data.


## Check time and tests

The test suite is intentionally skipped on CRAN (`tests/testthat.R` runs it
only when `NOT_CRAN=true`): it is large, and it runs continuously on our CI
matrix — macOS/Windows/Linux across R devel/release/oldrel-1 with
`--as-cran`, a no-Suggests leg, ASAN/UBSAN, and valgrind (see Test
environments below) — so running it on CRAN's machines would add check time
without adding coverage. Examples (including `--run-donttest`) run
normally.


## Compiled code

The package compiles a large C++ kernel tree (RcppEigen/RcppNumerical).
ASAN/UBSAN and valgrind runs are part of continuous CI (see Test
environments below); the most recent run predating this exact 1.0.2 content
was green (recorded for 1.0.1); a fresh confirmation for 1.0.2 is still to be
run. Note that 1.0.2 fixes a heap overflow in `fast_zero_one_inflated_beta_cpp()`
(an unchecked warm-start length), found with valgrind after the last recorded
valgrind run, so the valgrind job should be rerun on the 1.0.2 tree.


## Test environments

* GitHub Actions (continuously, on every push —
  `.github/workflows/R-CMD-check.yaml`, 10 jobs):
  * macOS (latest), R release
  * Windows (latest), R release
  * Windows (latest), R devel
  * Ubuntu (latest), R devel, release, and oldrel-1
  * Ubuntu, R release with no Suggests installed (`_R_CHECK_SUGGESTS_ONLY_`)
  * Ubuntu, R release with `_R_CHECK_CRAN_INCOMING_` left enabled (the
    "R-CMD-check-incoming" job) — continuous coverage of the
    Title/Description phrasing policy, misspellings, URL validity, and
    license-text checks that would otherwise only be caught at manual
    pre-submission time; `error-on: "warning"` since the "New submission"
    NOTE is unavoidable here
  * R-devel with ASAN/UBSAN (rocker/r-devel-san)
  * R-devel under valgrind memcheck
* win-builder (2026-09-14, on the 1.0.1 content; to be repeated for 1.0.2): uploaded to all three sections (R-devel,
  R-release, R-oldrelease). Status: clean on all three — no WARNINGs or
  ERRORs, and no NOTEs beyond the expected "New submission".
* mac-builder: not used for this submission — the builder on
  mac.r-project.org is currently down.
* Local: R Under development (unstable) (2026-04-23 r89955),
  x86_64-pc-linux-gnu, Ubuntu 26.04 LTS, gcc/gfortran 15.2.0.
  Install (compile) ~27min; everything else together well under 10 minutes: 30s
  examples, 183s donttest, 21s PDF manual, 41s HTML manual.
