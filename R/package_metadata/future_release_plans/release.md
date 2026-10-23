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
   `scripts/submission_tar_build_and_win_mac_check.sh` (builds the tarball with
   `--compact-vignettes=gs+qpdf` first, then uploads to win-builder via FTP;
   mac-builder has no known scriptable upload path, so that step is manual —
   see the script's own comments). This script is meant to be run by a human
   on their own machine, not executed by an agent (win-builder/mac-builder
   hosts are outside any sandboxed network allowlist).
1a. **Algorithm-audit gate.** No open `algorithm-audit-drift` issue and no
   row past its max age (the monthly drift check's output; see
   `../new_feature_plans/algorithm_audit_runbook.md`). Run
   `python3 .github/scripts/algorithm_audit_drift.py --release-gate` (needs
   `gh auth login`; exit 0 = pass, 1 = fail, 2 = could not be determined, which
   is not a pass). Do this before step 7. It also covers a failed drift
   workflow (`algorithm-audit-drift-failure` issue). A release that adds or
   changes kernels also gets the audit's full pass first (audit TODO-7).
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
   `new_feature_plans/` or `../bug_fix_plans/` to `../finished_features/`, per the standing
   constraint.

## Regression checks against the previous release (every release)

Added 2026-10-23 (owner decision). Two manual checks compare this release
against the reports committed with the previous one. They are too slow for
the pre-push hook and too noisy (benchmarks) for shared CI runners, so they
are a release step. Run both after the release build is installed and the
comprehensive results are regenerated and merged, and before the release
push. Each release's own plan file records the results (commands, ratios,
allowlisted items and their reasons).

**Rule for both:** a flagged row either matches an intentional change made in
this release (recorded with its reason: `--allow` for benchmarks, a row in
the path-audit allowlist) or it blocks the release until it is explained or
fixed. Never allowlist something only because it is inconvenient.

### Benchmarks (R and Python)

- **Host:** quiet machine, 1-minute load average below 1.0, nothing else
  running (never during a comprehensive-suite run).
- **Build:** time on the same build flavor as the baseline. The baseline
  report records its flags (`EDI_PORTABLE=0` / `-march=native` as of
  2026-10). The comparison tool warns when the flags differ; a portable vs
  native mismatch makes the R comparison informational only.
- **Baseline:** `B=$(mktemp -d)`, then
  `git show HEAD:R/package_metadata/benchmark_model_fits.md > $B/benchmark_model_fits.md`
  and the same for `python/benchmark/benchmark_model_fits_python.html`
  (or point the tool at `git:<previous-release-tag>:<path>`).
- **Python build:** the Python benchmark CMake-builds its own extension into
  `/tmp/edi_py_build_check` from the current C++ sources (a full compile the
  first time). Build it before the quiet window; it needs
  `~/.venvs/edi-py-bench/bin/python` (statsmodels). Check its log says
  "built OK", or every EDI column comes out NA.
- **Run (both from `R/`, full runs only):**
  `( cd R && Rscript benchmark/benchmark_model_fits.R )` (about 90 min; a
  `--sections` run rewrites the tracked report with only those sections, so
  never use it for the release run), then
  `( cd R && ~/.venvs/edi-py-bench/bin/python benchmark/benchmark_model_fits_python.py )`.
- **Compare:**
  `Rscript R/benchmark/compare_benchmark_runs.R --old $B/benchmark_model_fits.md --new R/package_metadata/benchmark_model_fits.md --part R --normalize-host`
  and the same with `--part Python` against the Python HTML. Flags a row at
  >= 1.25x slower and >= 0.05 ms slower, or a time that became NA. Exit 0
  pass, 1 regression, 2 usage/parse error. Re-run the benchmark once before
  believing a single flagged row (noise). The host factor printed by
  `--normalize-host` should be about 0.8-1.25.
- **Know what it cannot see:** the benchmark rows mostly call C++ kernels
  directly with default arguments, so slowdowns that live in R classes
  (tolerances, retries, seeding, design re-solves) do not show up. List
  those in the release's plan file instead.
- **After it passes:** commit the regenerated reports
  (`R/package_metadata/benchmark_model_fits.md`,
  `benchmark_model_fits_R.html`, the Python HTML, and the `R/benchmark/`
  copies) with the release; they are the next release's baseline.

### Path audits

- **Needs:** the release build installed (it reads the registry live) and the
  regenerated comprehensive results merged into the canonical
  `R/package_tests/comprehensive_tests_results_nc_*.csv` (it pools only
  those; `_filtered_` files and per-run dirs are ignored). Run it from `R/`.
- **Generate into a scratch dir** (tracked files untouched):

      S=/tmp/edi_path_audits_$(date -u +%Y%m%dT%H%M%SZ); mkdir -p $S
      cp R/package_tests/path_audits_source.R R/package_tests/path_audits_nonestimability_defaults.csv $S/
      for f in R/package_tests/comprehensive_tests_results_nc_*.csv; do case $f in *_filtered_*) ;; *) ln -s "$PWD/$f" $S/ ;; esac; done
      ( cd R && Rscript $S/path_audits_source.R ) 2>&1 | tee $S/gen.log
      Rscript R/package_tests/compare_path_audits.R --new-dir $S --out-dir $S/compare

  (about 1 min, about 4 GB RAM). Baseline defaults to `HEAD`; pass the
  previous release tag to compare against it.
- **Pass:** exit 0 / `RESULT: PASS`, and no `path_audits: could not ...`
  warnings in `gen.log`. A worsening is: supported -> unsupported or not
  implemented, a lost cell or row, lost guaranteed status, newly SLOW, an
  estimable rate down by more than 0.02 (n >= 30 on both sides) or to 0%.
- **Allowlist:** `R/package_tests/path_audits_regression_allowlist.csv`, one
  row per intentional change with its TODO/NEWS source and reason. A cell
  that only lost observations usually means results are not merged yet:
  re-run after the merge instead of allowlisting it.
- **Counting rule (fixed 2026-10-23):** a row counts as non-estimable when
  it is flagged "Explicitly non-estimable", has `status=error`, or is a
  `status=ok` row whose recorded result is missing or non-finite ("Invalid
  output detected", "Allowed missing output", a degenerate CI, a non-fatal
  numerical message). Refusals and skips (`Skipping ...`, timeouts, "not
  supported", "must implement", "requires", the truth-anomaly filter) are not
  failures. See `classify_nonestimability_rows()` in `path_audits_source.R`.
  Before the fix an unflagged NA counted as estimable. Outputs are stamped
  with the rule version (`PATH_AUDIT_COUNTING_RULE`: an HTML comment and a
  `counting_rule` column in the defaults CSV). The defaults CSV is rewritten
  whenever its stamp differs, even if the row count did not grow.
  `compare_path_audits.R` reports a stamp mismatch, and the allowlist row
  `counting_rule_2026_10_23` then excuses rate drops only (not support or
  cell changes). It stops matching once both sides carry the same stamp.
  If you bump the rule, add a matching `counting_rule_change` allowlist row.
- **After it passes:** copy `path_audits.html` and
  `path_audits_nonestimability_defaults.csv` from `$S` into
  `R/package_tests/`, re-run the compare with the default `--new-dir`, and
  commit both with the release.

## Coordination with the Python package

`edi_kernels` (PyPI) ships from the same commit family as the matching CRAN
release. Tagging/pushing/submitting each package is still a separate
explicit go-ahead per the rule above.
