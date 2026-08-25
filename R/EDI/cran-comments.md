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

* NOTE: "Found the following possibly unsafe calls: unlockBinding(...)"
  (`R/contracts_mixins.R`, 3 sites). EDI's inference classes use a lazy
  component-loading mechanism: some optional public/private methods are
  installed onto an already-constructed R6 object's (locked, per R6's
  default) public/private environments the first time their capability is
  used, rather than at class-definition time, and after `clone()` the
  cloned copy's freshly-installed methods must be re-pointed at the
  clone's own enclosing environment rather than the original's. Both
  operations require reassigning an existing, already-locked R6 method
  binding, which is only possible via `unlockBinding()`. All three sites
  unlock only the one specific binding being reassigned, for the
  duration of a single `assign()` call, and unconditionally re-lock it
  immediately afterward (see the code comments at each call site in
  `contracts_mixins.R`) — no binding is ever left permanently unlocked.
  This is not a workaround for something else; it is the intended
  mechanism.

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
environments) — [TODO, not yet fillable: as of 2026-08-25 the last 7
`R-CMD-check` runs on `main` are `cancelled` (superseded by rapid
follow-up pushes during active development, not real failures) and the
3 before that are `failure`; there is no recent run that reached
completion to confirm ASAN/UBSAN/valgrind are clean. Before submission,
let one push's CI run finish uninterrupted and record the actual
clean/failing result here — do not fill in a "clean as of" date without
a real completed run backing it].

## Downstream dependencies

There are no reverse dependencies (new package).

## Other pre-submission checks (no network required to reproduce)

* The maintainer's ORCID iD (`0000-0001-5985-6792`) was previously flagged
  by `R CMD check --as-cran`'s "CRAN incoming feasibility" pass as
  "(possibly) invalid" — this is a sandbox/network-check artifact, not a
  real problem: the ORCID mod-11-2 check digit was verified by hand and is
  correct (checksum `2` for base digits `000000015985679`). The flag comes
  from that check's own online ORCID-registry lookup failing in a
  network-restricted environment, the same failure category as the
  `libcurl error code 7` Wikipedia-URL check failures seen in the same
  run (both checks require live network access this sandbox doesn't have
  to CRAN-external hosts) — not a genuinely malformed iD.
* `Description` now quotes `'Rcpp'` per CRAN's software-name-in-quotes
  policy (previously unquoted).
* Verified the two `URL:` field entries
  (`https://github.com/kapelner/EDI`, `https://pypi.org/project/edi_kernels/`)
  both resolve with `200 OK`.
