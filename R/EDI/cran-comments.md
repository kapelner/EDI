# CRAN comments — EDI 1.0.2

> **Version plan (2026-09-24, user decision, superseding an earlier same-day
> note that named 1.1.0):** the first CRAN submission is **v1.0.2**. Versions
> 1.0.0 and 1.0.1 were GitHub-only releases. The test-environment and
> check-result details below were recorded for the 1.0.1 content and must be
> re-run and refreshed for 1.0.2 (a clean `R CMD check --as-cran`, a fresh
> win-builder run, and a fresh ASAN/UBSAN and valgrind confirmation) before
> submission.

## Resubmission

This is a resubmission. Thank you for the review. In this version we have
addressed both points you raised:

* **Examples in `\dontrun{}` / "Unexecutable code":** there is no `\dontrun{}`
  left anywhere in the package. The five Rd files you flagged for
  unexecutable code (`InferenceIncidCMH`, `InferenceIncidExtendedRobins`,
  `InferenceIncidKKCondLogitGLMMIVWC`, `InferenceSurvivalKKRankRegrIVWC`,
  `InferenceSurvivalStratCoxPHRegr`) had `\donttest{}` nested inside
  `\dontrun{}`; those examples, and all the other examples previously in
  `\dontrun{}`, are now unwrapped and run as normal examples, since they run in
  well under 5 seconds. Examples that were only placeholders (in
  `InferenceIncidExactFisher`, `InferenceIncidExactZhang`,
  `InferenceRandBootstrap` and `InferenceRandBootstrapCI`) have been replaced
  with complete, runnable ones. `\donttest{}` is used only where an example
  genuinely takes longer: the part of the `DesignFixedOptimal` example that
  compiles a custom C++ objective at run time with `RcppXPtrUtils` (about 8
  seconds), and the `BaiAdjustedTSource` examples, where loading the suggested
  package `nbpMatching` alone takes a few seconds. Both are also guarded with
  `requireNamespace()`, since those packages are in Suggests. Every Rd file's
  examples, excluding `\donttest{}` code, now run in under 2.5 seconds on our
  machine.

* **Modifying the global environment and the user's options:** the package no
  longer writes to `.GlobalEnv` or changes the user's `options()`, `par()` or
  working directory.
  * Loading the package no longer sets any options, and `toggle_asserts()`,
    `set_num_cores()` and `unset_num_cores()` no longer set any options either.
    That internal state is now kept in an environment inside the package
    namespace.
  * Every `<<-` in `R/globals.R`, `R/inference_suite.R` and
    `R/simulations_framework.R` has been replaced with explicit local
    environments.
  * A code path that could overwrite the user's `.Random.seed` has been
    removed. Where a function sets a seed the user asked for, the user's
    previous `.Random.seed` is restored with an immediate `on.exit()`.
  * Data sent to parallel worker processes no longer goes into those workers'
    global environments.
  * A call to another package's function that changes `options(contrasts)`
    without restoring it (`multgee::ordLORgee()`) is now wrapped so the user's
    option is restored with an immediate `on.exit()`.

  We verified this by checking that loading the package and running its
  parallel, simulation and inference entry points leave `options()`, the
  working directory, the contents of `.GlobalEnv` and (for seeded runs)
  `.Random.seed` unchanged.

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
