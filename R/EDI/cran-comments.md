# CRAN comments — EDI 1.0.0

## Submission

First submission of EDI to CRAN (new package).

## R CMD check results

Status: 0 WARNINGs, 0 ERRORs on all platforms. NOTEs:

* NOTE: "Found the following possibly unsafe calls: unlockBinding(...)"
  (`R/contracts_mixins.R`, 3 sites).

  EDI's inference classes use a lazy component-loading mechanism: some
  optional public/private methods are installed onto an already-constructed
  R6 object's (locked, per R6's default) public/private environments the
  first time their capability is used, rather than at class-definition
  time, and after `clone()` the cloned copy's freshly-installed methods
  must be re-pointed at the clone's own enclosing environment rather than
  the original's. Both operations require reassigning an existing,
  already-locked R6 method binding, which is only possible via
  `unlockBinding()`. All three sites unlock only the one specific binding
  being reassigned, for the duration of a single `assign()` call, and
  unconditionally re-lock it immediately afterward (see the code comments
  at each call site in `contracts_mixins.R`) — no binding is ever left
  permanently unlocked. This is not a workaround for something else; it is
  the intended mechanism.

* NOTE: New submission. (Expected)

* NOTE: Possibly misspelled words in DESCRIPTION: "Efron", "Pocock" — both
  are surnames (Efron's bootstrap, the Pocock boundary/Pocock-Simon
  minimization), not misspellings.

* NOTE: A batch of Wikipedia URLs flagged as possibly invalid, all with
  HTTP 429 (Too Many Requests) — win-builder/CRAN's own URL checker is
  being rate-limited by Wikipedia, the links themselves are valid.

* NOTE: "Overall checktime 13 min > 10 min" (CRAN flavor
  `r-devel-windows-x86_64`) — the package compiles a large C++ kernel tree
  (RcppEigen/RcppNumerical; see "Compiled code" below), so total check time
  is compile-time-dominated and varies with the check machine's CPU. This
  does not reproduce on every machine/flavor (it did not appear on the
  win-builder/mac-builder runs above, nor on the other CRAN flavors); when
  it does, it reflects compile time on that specific machine, not a
  package-side slowdown.


## Check time and tests

The test suite is intentionally skipped on CRAN (`tests/testthat.R` runs it
only when `NOT_CRAN=true`): it is large, and it runs continuously on our CI
matrix — macOS/Windows/Linux across R devel/release/oldrel-1 with
`--as-cran`, a no-Suggests leg, ASAN/UBSAN, and valgrind (see Test
environments above) — so running it on CRAN's machines would add check time
without adding coverage. Examples run normally.


## Compiled code

The package compiles a large C++ kernel tree (RcppEigen/RcppNumerical).
ASAN/UBSAN and valgrind runs are part of continuous CI (see Test
environments) — confirmed clean as of CI run 33121847188 (2026-08-27,
commit f581b174): "R-devel (ASAN/UBSAN)" passed in 1h11m59s and "R-devel
(valgrind)" passed in 1h31m34s, both as part of a fully green 10-job run
(no cancellations, no other job failures).


## Test environments

* GitHub Actions (continuously, on every push — .github/workflows/R-CMD-check.yaml,
  10 jobs; last fully green run: 33121847188, 2026-08-27):
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
* win-builder (2026-08-30):
  * R-devel: R Under development (unstable) (2026-08-27 r90452 ucrt),
    x86_64-w64-mingw32, Windows Server 2022 x64 (build 20348). Status:
    2 NOTEs — https://win-builder.r-project.org/cvrhfj5vvQ1d/00check.log
  * R-release: R 4.6.1 (2026-06-24 ucrt), x86_64-w64-mingw32. Status:
    2 NOTEs — https://win-builder.r-project.org/8j8jTxjvIrf2/00check.log
* mac-builder (2026-08-29): macOS Tahoe 26.6, aarch64-apple-darwin23, R 4.6.1
  Patched (2026-07-27 r90311), Apple clang 17.0.0, GNU Fortran (GCC) 14.2.0.
  Status: 1 NOTE —
  https://mac.r-project.org/macbuilder/results/1788035096-11c57fc8646da48a/
* Local: R Under development (unstable) (2026-04-23 r89955), x86_64-pc-linux-gnu,
  Ubuntu 26.04 LTS, gcc/gfortran 15.2.0. `NOT_CRAN=false R CMD check --as-cran`
  via `scripts/submission_tar_build_and_win_mac_check.sh` (2026-08-29).
  Status: 2 NOTEs, 0 WARNINGs. Install (compile) ~39min; everything else
  together well under 10 minutes: 49s examples, 334s donttest, 16s vignette
  rebuild, 38s PDF manual, 68s HTML manual.


