# Algorithm Audit Runbook (drift checks and re-review procedure)

> **Owns:** the recurring-audit procedure for `algorithm_choice_audit.md → TODO-7`
> (scheduled in `../future_release_plans/release_v1_1_0.md → TODO-52`).
> **Status:** drafted 2026-10-22. The workflow has not yet run on GitHub.

## What runs, and when

| Layer | Trigger | Who/what | Output |
|---|---|---|---|
| Drift check | Monthly, 21st, 06:00 UTC (`workflow_dispatch` also works) | `.github/workflows/algorithm-audit-drift.yml` → `.github/scripts/algorithm_audit_drift.py` | One issue labelled `algorithm-audit-drift` (updated in place; closed when clean). Report also uploaded as the `drift-report` artifact. |
| Full pass | Release close; new kernel family ships; a Prototype item resolves through the A/B harness | A human or a Claude session, following "Re-review procedure" below | Updated audit rows, summary table, exposure column; bumped `reviewed` dates; re-pinned versions |

The drift check never edits a file or commits. It answers only "did anything
that could invalidate a verdict change?"

## Drift-check list

Source of truth is the script; this is its contract.

1. **Comparator versions.**
   - Reads: package names in `R/EDI/DESCRIPTION` (Imports, Suggests, Depends,
     LinkingTo; base packages excluded) plus the audit's comparators
     (`survival`, `clinfun`, `coin`, `betareg`, `aftgee`, `icenReg`,
     `robustbase`, `coxme`, `lme4`, `glmmTMB`).
   - Compares CRAN's current version (crandb) with
     `R/package_metadata/audits/comparator_versions.json`.
   - Flags a changed version with the keyword-matching lines of that package's
     CRAN NEWS newer than the pinned version (keywords: default, algorithm,
     tie, quadrature, convergence, optimiz, starting value, deprecat, breaking,
     behaviour, numerical, accuracy, bug).
   - Lists unpinned packages, and packages not found on CRAN (ignored).
2. **Kernel drift.**
   - Reads `audits/algorithm_audit_row_map.json`: audit row → kernel files plus
     a per-row `reviewed` date.
   - Runs `git log --since=<reviewed>` over each row's files; flags rows with
     commits and lists up to 8.
   - Flags a map entry whose file no longer exists (renames break the map).
3. **Plan-state hygiene.**
   - For every audit TODO header line, each `release_vX_Y_Z.md → TODO-N`
     (ranges like `70..94` expanded) must resolve to an active TODO line in that
     release file. A missing target, or a `~~TODO-N~~` moved-stub, is
     "dangling".
   - Flags an unchecked audit TODO with neither a release tag nor "covered by".

## Guardrails

- **Read-only.** No commits, no plan edits, no auto-fixes by the workflow.
- **No builds, ever.** The check reads `DESCRIPTION`, git history, CRAN
  metadata and markdown. It never runs `R CMD INSTALL`/`build`, `load_all`,
  `pkgbuild`, or a compile. A Claude session doing a full pass follows
  `CLAUDE.md` (no full rebuilds; agents compile with `EDI_UNITY=0`).
- **A flag means "re-look", not "wrong".** Never schedule a bug or change a
  default from a flag alone.
- **Verified vs unverified.** Findings from a full pass are tagged
  *verified* (reproduced, test or oracle named) or *unverified*. Only verified
  findings become bug TODOs; unverified ones stay listed, as the 2026-10-09
  sweep's ~25 did.
- **Scope cap.** A full pass covers flagged rows only, not the whole catalog.
- **Provenance.** A re-review states the comparator versions and commit it
  was done against.
- **Default changes** found by a pass need an owner decision and a documented
  plan (release-equivalence rule D2) before they ship.
- **Keep the issue single.** One open `algorithm-audit-drift` issue at a time;
  the workflow updates it rather than opening duplicates.

## Re-review procedure (clearing a flagged row)

1. Read the issue; pick a row. Read the row's section in
   `algorithm_choice_audit.md` and the commits the report lists.
2. Re-run the row's method (not its conclusion): is the chosen algorithm still
   the right one for the problem, given the changed kernel code or comparator
   behaviour? Check the comparator NEWS lines first.
3. Outcomes:
   - *Verdict holds:* note the date in the row; nothing else.
   - *Verdict changes or a bug is found:* record it in the audit; if a bug is
     verified, add a TODO to the right release plan and put the
     `scheduled in release_vX.md → TODO-N` tag on the audit TODO.
4. In the same commit: set the row's `reviewed` date in
   `audits/algorithm_audit_row_map.json` to today, and re-pin versions with
   `python3 .github/scripts/algorithm_audit_drift.py --snapshot` (pins CRAN's
   current versions for every package, so only do this after reviewing all
   changed comparators).
5. Close the issue when nothing is left flagged, or leave it for the next run
   to update.

## Maintenance

- **New kernel or renamed file:** update `algorithm_audit_row_map.json`
  (a stale path is flagged under "Map error").
- **New audit row or TODO:** add the row to the map; give every audit TODO a
  `scheduled in` tag.
- **Local run:** `python3 .github/scripts/algorithm_audit_drift.py --offline`
  runs checks 2 and 3 with no network; omit `--offline` for check 1.
- **Baseline:** all row `reviewed` dates and the CRAN pins were set to
  2026-10-22 as a deliberate clean start (owner decision). The 2026-10-09 sweep
  and the v1.0.5 changes through that date are treated as already absorbed, so
  the first report only flags changes after 2026-10-22.
- GitHub disables scheduled workflows after 60 days with no repo activity; a
  manual dispatch re-arms it.

## Hardening (added 2026-10-22)

- **A broken run must not look clean.** crandb 404 means "not on CRAN"
  (ignored); any other failure (after one retry) is a fetch error. More than 3
  fetch errors makes the report `FLAGGED` with "CHECK UNRELIABLE" at the top of
  section 1. If the whole job fails or is cancelled, the `notify-failure` job
  opens or comments on an issue labelled `algorithm-audit-drift-failure`.
  `--snapshot` aborts rather than write a partial pin file.
- **Max review age.** A row whose `reviewed` date is older than
  `max_age_days` (180, in the row map) is flagged even with zero drift, so a
  quiet row still gets a real re-review.
- **Map coverage.** Every `*.cpp`/`*.h` in `R/EDI/src` must be mapped to a row
  or match an `exempt` pattern in the row map; otherwise it is flagged. An
  exempt pattern that matches nothing is flagged as stale. The exempt list has
  two groups: `infrastructure` (no algorithm choice) and `unassigned_kernels`
  (algorithm kernels no row covers yet; counted in the report, not flagged).
  As of 2026-10-22 `unassigned_kernels` is empty: rows A-AC cover every kernel.
  Rows N-AC were mapped by file name and row text, so treat that mapping as a
  first pass for the owner to refine.
- **Release gate.** `python3 .github/scripts/algorithm_audit_drift.py
  --release-gate` fails (exit 1) on any open `algorithm-audit-drift` or
  `-failure` issue or any row past its max age; exit 2 (gh unavailable) is not
  a pass. It is step 1a of `../future_release_plans/release.md`.
