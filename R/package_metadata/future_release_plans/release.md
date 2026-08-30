# Release Mechanics (applies to every release)

> This document holds everything that is **the same checklist regardless of
> which release** — CRAN submission mechanics, CI coverage, and release
> bookkeeping. It exists so `release_v1_0_0.md`, `release_v1_1_0.md`, and
> every future `release_v*.md` state their release-specific scope only, and
> point here for the generic "how do we actually ship a release" steps
> instead of re-copying them. Nothing in this file is release-specific; if
> you find yourself writing "for this release, additionally..." here, it
> probably belongs in the release-specific file instead.

## CI coverage already enforced on every push

Audited 2026-08-15 against `.github/workflows/R-CMD-check.yaml`, extended
2026-08-25. This runs continuously and needs no manual action per release:

- `--as-cran` across a matrix of macOS/Windows/Linux × devel/release/oldrel-1
  (6 configs as of 2026-08-25, including a Windows R-devel leg) with
  `error-on: "note"`.
- A no-Suggests leg (`dependencies: NA` + `_R_CHECK_SUGGESTS_ONLY_`).
- ASAN/UBSAN (`rocker/r-devel-san`) and valgrind memcheck.
- `\donttest{}` examples on most legs.
- Portable Makevars (`EDI_PORTABLE=1`) and compacted vignettes.
- A dedicated `R-CMD-check-incoming` job with `_R_CHECK_CRAN_INCOMING_` left
  enabled (`error-on: "warning"`, since "New submission" is an unavoidable
  NOTE) — continuous coverage of the Title/Description phrasing policy,
  misspellings, URL validity, and license-text checks. Metadata-only,
  platform-independent, so one Linux job suffices; it does **not** substitute
  for win-builder/mac-builder below, which run on CRAN's own machines with a
  different toolchain.
- Package-size, Rd, and example-timing NOTEs fail CI via `error-on`.

`r-hub v2` (`rhub::rhub_check()`) was investigated (2026-08-25) and rejected
as a CI addition for this repo: its tooling hard-requires the R package at
the git repository root, and this repo keeps the package at `R/EDI`. Do not
re-attempt without first restructuring the repo.

## The pre-submission steps CI cannot cover

These are genuinely manual, once-per-release steps — run them only when
actually preparing a submission-candidate tarball, not on every push.

1. **win-builder + mac-builder.** Run win-builder (release + devel) and
   mac-builder before submission — they are the only place CRAN-incoming
   checks run on CRAN's own build machines (subtly different
   toolchain/environment than GitHub's runners), and the only remaining
   coverage gap after the CI job above. Use
   `R/EDI/scripts/submission_tar_build_and_win_mac_check.sh` (builds the tarball with
   `--compact-vignettes=gs+qpdf` first, then uploads to win-builder via FTP;
   mac-builder has no known scriptable upload path, so that step is manual —
   see the script's own comments). This script is meant to be run by a human
   on their own machine, not executed by an agent (win-builder/mac-builder
   hosts are outside any sandboxed network allowlist).
2. **Measure the CRAN-facing check profile** on the release-candidate tree
   (`NOT_CRAN=false R CMD check --as-cran` from a clean checkout — never run
   this without being explicitly asked in that turn; it compiles the whole
   package and can lock up a machine for minutes). Confirm compile time is
   within CRAN's tolerance, and that no new NOTE/WARNING classes appeared
   since the last measurement.
3. **`cran-comments.md`.** Fill in test environments, check results, and NOTE
   justifications for the actual release candidate — this file is
   release-specific content (dates, versions, timings), not something this
   document tracks.
4. **No-reverse-deps statement** (or, once EDI has reverse dependents, the
   real reverse-dependency check).
5. **CHANGELOG entry**, dated at actual submission time (house convention),
   summarizing what shipped in this release.
6. **Version bump** in `DESCRIPTION`.
7. **Tagging, pushing, and submitting** (CRAN or PyPI) — each of these is a
   **separate explicit go-ahead**. No release plan authorizes them by itself;
   ask before doing any of the three, every release.
8. **On acceptance:** move every closed in-scope plan from
   `new_feature_plans/` to `../finished_features/`, per the standing
   constraint.

## Coordination with the Python package

`edi_kernels` (PyPI) ships from the same commit family as the matching CRAN
release. Tagging/pushing/submitting each package is still a separate
explicit go-ahead per the rule above.
