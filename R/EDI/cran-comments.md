# CRAN comments — EDI 1.0.5

> **Before submitting (delete this block):** fill in the four `[TODO]` items below from
> `./scripts/submission_tar_build_and_win_mac_check.sh` (local `R CMD check --as-cran`) and the
> win-builder runs, and confirm the last full `R-CMD-check.yaml` run on the submitted commit is
> green. Drafted 2026-11-24 from: CRAN's EDI 1.0.2 check page (OK on all 13 flavors that day),
> the `DESCRIPTION` diff against tag `v1.0.2`, `NEWS.md`, and `R-CMD-check.yaml` run
> 45403920576 (4e83509a, all 21 jobs green). The run on cf2beb67 (today's hurdle and
> randomization fixes) was still running when this was written.

## Submission

This is an update of EDI from 1.0.2, the version on CRAN, to 1.0.5. Versions 1.0.3 and 1.0.4
were not submitted to CRAN; their changes are included here and listed in `NEWS.md`.

The update is mainly a correctness release. It fixes wrong results found by an audit of the
package's algorithms and by large simulation sweeps: coverage and type I error problems in
several confidence intervals and tests, and convergence problems in several model fits. Seeded
random draws are now identical on Linux, macOS and Windows at every thread count. `NEWS.md`
lists every change; the ones that change results are under "Changes that alter results", and the
few API changes are under "Breaking changes".

* **Reverse dependencies:** EDI has none on CRAN, so no other package is affected by the API
  changes.
* **Dependencies:** no new Imports. Suggests gains `optmatch` and `clubSandwich` (both on
  CRAN, used conditionally via `requireNamespace()`), and `betareg` now requires >= 3.2-6.
* **Description:** one sentence was added, "EDI replaces the 'SeqExpMatch' package".
  'SeqExpMatch' is my earlier CRAN package (same maintainer); EDI covers everything it did.
  [TODO: say whether you are asking CRAN to archive SeqExpMatch, or that it stays on CRAN for
  now.]
* **Maintainer:** unchanged.

## R CMD check results

[TODO: paste the summary from the local `--as-cran` run, e.g.]

0 ERRORs | 0 WARNINGs | [n] NOTEs

* [TODO: list each NOTE and its explanation. An "installed package size" NOTE, if it appears, is
  compiled code and documentation, as for 1.0.2: the package compiles a large C++ kernel tree
  (RcppEigen / RcppNumerical / LBFGSpp) covering every response type and design. The source
  tarball is 3.1 MB.]

## Tests and check time

As in 1.0.2, the test suite is skipped on CRAN (`tests/testthat.R` runs it only when
`NOT_CRAN=true`). It is large and runs on every push on the CI matrix below, including ASAN/UBSAN
and valgrind, so running it on CRAN's machines would add check time without adding coverage.
Examples, including `\donttest{}` code, run normally; every Rd file's examples outside
`\donttest{}` run in under 2.5 seconds on our machine.

The package still has no `\dontrun{}`, does not write to the global environment, and leaves
`options()`, the working directory and `.Random.seed` as it found them (the release script
checks all of these before every submission).

## Compiled code

ASAN/UBSAN (rocker/r-devel-san) and valgrind memcheck run on every push. [TODO: confirm from
the sanitizer outputs (`tests/testthat.Rout` in each job's check directory) that no errors are
reported in EDI's code before writing "clean". Both jobs pass whenever `R CMD check` passes, and
on run 45403920576 they ended with WARNINGs (valgrind 2 WARNINGs and 1 NOTE, ASAN/UBSAN 3
WARNINGs) that still need explaining.] `rchk` and CRAN's additional checks (clang 23, gcc 16,
LTO, `--no-long-double`) are also part of CI and passed on that run.

## Test environments

* GitHub Actions (`.github/workflows/R-CMD-check.yaml`, on every push):
  * macOS (latest), R release, with and without OpenMP
  * Windows (latest), R release and R devel
  * Ubuntu (latest), R devel, release and oldrel-1; R devel with development versions of
    dependencies; R release with no Suggests installed; R release with
    `_R_CHECK_CRAN_INCOMING_` enabled
  * R devel with ASAN/UBSAN, and R devel under valgrind
  * CRAN additional checks: rchk, clang 23, gcc 16, LTO, `--no-long-double`
* win-builder: [TODO: date and result for R-devel, R-release and R-oldrelease]
* mac-builder: [TODO: date and result, or "not used"]
* Local: [TODO: R version from the check log (currently R Under development (unstable)
  (2026-10-13 r90668)), x86_64-pc-linux-gnu, Ubuntu 26.04.1 LTS, gcc 15.2.0; install and
  check times]
