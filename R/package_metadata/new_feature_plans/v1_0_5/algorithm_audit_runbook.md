# Algorithm Audit Runbook (drift checks and re-review procedure)

> **Owns:** the recurring-audit procedure for `algorithm_choice_audit.md → TODO-7`
> (scheduled in `../../future_release_plans/release_v1_1_0.md → TODO-52`).
> **Status:** drafted 2026-10-22. The workflow has not yet run on GitHub.

## What runs, and when

| Layer | Trigger | Who/what | Output |
|---|---|---|---|
| Drift check | Monthly, 21st, 06:00 UTC (`workflow_dispatch` also works) | `.github/workflows/algorithm-audit-drift.yml` → `.github/scripts/algorithm_audit_drift.py` | One issue labelled `algorithm-audit-drift` (updated in place; closed when clean). Report also uploaded as the `drift-report` artifact. |
| Research (added 2026-11-16) | Same run, after the drift check's plan step; `workflow_dispatch` input `research_tasks` picks a subset (`A,J,inventory`) or `none` | One Claude agent per audit row (29) plus one `inventory` agent, via `anthropics/claude-code-action`; prompts and JSON schemas in `.github/prompts/`; merged by `.github/scripts/algorithm_audit_research_report.py` | One issue labelled `algorithm-audit-research` (updated in place; closed when clean). Per-task JSON uploaded as `research-<task>` artifacts. |
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
   - Reads each row's `reviewed` date from `audits/algorithm_audit_row_map.json`
     and the files it watches from the `watch` column of
     `audits/algorithm_inventory.csv` (a space-separated list of audit rows;
     row X watches every file with an entry whose `watch` contains X).
   - Runs `git log --since=<reviewed>` over each row's files; flags rows with
     commits and lists up to 8.
3. **Plan-state hygiene.**
   - For every audit TODO header line, each `release_vX_Y_Z.md → TODO-N`
     (ranges like `70..94` expanded) must resolve to an active TODO line in that
     release file. A missing target, or a `~~TODO-N~~` moved-stub, is
     "dangling".
   - Flags an unchecked audit TODO with neither a release tag nor "covered by".
4. **Algorithm inventory** (added 2026-11-16).
   - `audits/algorithm_inventory.csv` is the single source of truth for which
     algorithms EDI implements and where: one row per (file, symbol) with
     `problem`, `algorithm`, `details`, `complexity`, `audit_row` (A-AC,
     `" + "`-joined), `verdict`, `refs` (space-separated URLs), `watch`, `source`.
     `audits/algorithm_references.csv` lists every cited URL with its title.
   - Flags: a `R/EDI/src/*.cpp|*.h` or `R/EDI/R/*.R` file that is neither
     inventoried nor matched by an `exempt` entry in the row map; an exempt
     entry that matches nothing, or matches an inventoried file; an entry
     whose file is gone or whose `symbol` no longer appears in it; an unknown
     audit row; an audit row no entry watches; an entry with no reference; a
     reference URL missing from, or unused in, `algorithm_references.csv`.
   - Online only: every reference URL must still resolve (Wikipedia via its
     API, DOIs via the doi.org handle API, other URLs by GET). More than 3
     URLs that could not be checked makes the section "UNRELIABLE" and the
     report `FLAGGED`.

## Research agents (added 2026-11-16)

The drift check answers "did anything change?". The research layer answers the two
questions it can't: **is the inventory still accurate?** and **is each algorithm still the
fastest acceptable one for its job?**

- **Row tasks** (`.github/prompts/algorithm_audit_research.md`): one agent per audit row
  gets that row's inventory entries (`row_entries.csv`), groups them by distinct
  `algorithm`, reads the row's audit section and the catalog's options tables (so it does
  not re-report rejected options without new evidence), and searches the web for a faster
  algorithm that keeps the estimator, exactness, thread-count determinism, accuracy, and a
  GPL-3-compatible license, at EDI's actual sizes. Every finding cites URLs the agent
  fetched that run; speedups are the sources' claims, never measurements. Algorithms it
  did not reach are listed under "not reviewed", never silently skipped.
- **Inventory task** (`.github/prompts/algorithm_audit_currency.md`): reads
  `--currency-context 35` output (functions added in the last 35 days that the
  inventory lacks; inventory entries whose symbol appears in a changed line or hunk
  header). It proposes inventory rows (with fetched reference URLs) for new functions that
  implement an algorithm, and corrected `details` for rows that no longer describe the
  code. It never rewrites a verdict.
- **Read-only.** Agents get Read/Glob/Grep, WebSearch/WebFetch and `git log|show|diff`
  only; Edit/Write are disallowed and the job token is `contents: read`. They return JSON
  through `--json-schema`; nothing is committed. Applying a finding or a proposed row is a
  human (or a local Claude session) editing `algorithm_inventory.csv` /
  `algorithm_references.csv`, after which check 4 re-validates it.
- **Never silently clean.** A task with no output (no `ANTHROPIC_API_KEY` secret, agent
  failure, timeout, invalid JSON) is listed under "Tasks that did not run" and makes the
  report `FLAGGED`.
- **Findings are unverified.** They follow the verified/unverified rule below: a finding
  becomes a TODO only after a benchmark or the A/B harness
  (`../v1_2_0/algorithm_ab_testing_framework.md`) confirms it.
- **Setup and cost.** Needs the `ANTHROPIC_API_KEY` (API billing) or
  `CLAUDE_CODE_OAUTH_TOKEN` (subscription, from `claude setup-token`) repository
  secret. The Claude GitHub app was installed 2026-11-16, but neither secret was set. Each run is up to 30 agent sessions
  (max 80 turns, 60-minute timeout each, 4 in parallel), billed to that key. Use the
  `research_tasks` input to run a subset by hand.
- **Tests:** `python3 .github/scripts/test_algorithm_audit_drift.py` covers the
  currency-context parsing and the report merge (including the NOT RUN rule); the
  workflow runs it first.

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

- **New kernel, new algorithm, or renamed file/symbol:** add or edit its row in
  `audits/algorithm_inventory.csv` (cite at least one reference URL, and add
  any new URL to `audits/algorithm_references.csv`). Set `watch` when a change
  to the file should re-open an audit row. A new file with no algorithmic
  content goes in the row map's `exempt` map with a reason instead. The
  catalog's kernel tables are a frozen 2026-10-09 snapshot: never edit them.
- **Tests:** `python3 .github/scripts/test_algorithm_audit_drift.py`
  (planted-fixture tests for check 4, offline).
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
- **Coverage** (superseded 2026-11-16 by check 4). The row map used to list
  each row's files; those lists moved, unchanged, into the inventory's `watch`
  column, and coverage now spans `R/EDI/R` as well as `R/EDI/src`. Rows N-AC
  were mapped by file name and row text, so treat their `watch` letters as a
  first pass for the owner to refine.
- **Release gate.** `python3 .github/scripts/algorithm_audit_drift.py
  --release-gate` fails (exit 1) on any open `algorithm-audit-drift` or
  `-failure` issue or any row past its max age; exit 2 (gh unavailable) is not
  a pass. It is step 1a of `../../future_release_plans/release.md`.
