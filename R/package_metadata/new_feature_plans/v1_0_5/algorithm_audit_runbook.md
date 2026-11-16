# Algorithm Audit Runbook (drift checks and re-review procedure)

> **Owns:** the recurring-audit procedure for `algorithm_choice_audit.md → TODO-7`
> (scheduled in `../../future_release_plans/release_v1_1_0.md → TODO-52`).
> **Status:** drafted 2026-10-22. The workflow has not yet run on GitHub.

## What runs, and when

| Layer | Trigger | Who/what | Output |
|---|---|---|---|
| Drift check | Monthly, 21st, 06:00 UTC (`workflow_dispatch` also works) | `.github/workflows/algorithm-audit-drift.yml` → `.github/scripts/algorithm_audit_drift.py` | One issue labelled `algorithm-audit-drift` (updated in place; closed when clean). Report also uploaded as the `drift-report` artifact. |
| Research (added 2026-11-16) | Monthly, first Thursday of the month at 23:59 Asia/Jerusalem, from 2026-12-03 (owner, 2026-11-16; was every 8 weeks for an hour); first full run dispatched by hand 2026-11-16; `workflow_dispatch` input `research_tasks` picks a subset (a problem id, an audit row letter for all its problems, `inventory`) or `none` | One Claude agent per **problem** of `audits/algorithm_taxonomy.json` (all methods EDI uses for it) plus one `inventory` agent, via `anthropics/claude-code-action`; prompts and JSON schemas in `.github/prompts/`; merged by `.github/scripts/algorithm_audit_research_report.py` | One pull request per run (label `algorithm-audit-research`, branch `algorithm-research/<date>-<run>`): `audits/research_findings/<date>-run<id>.md` plus inventory updates; no PR when there is nothing to report. Per-task JSON uploaded as `research-<task>` artifacts. |
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
   - NEWS comes from CRAN's rendered pages (`web/packages/<pkg>/news/news.html` for
     NEWS.md packages, `news.html` for NEWS.Rd); CRAN does not serve the raw `NEWS` /
     `NEWS.md` files. Each entry is one whole bullet. The pinned version is matched as a
     whole token in a heading (so `2.0-6` never matches `2.0-60`); if no heading names it,
     the report says so and shows the newest entries. A package with no NEWS page
     (e.g. nlme) is reported as such.
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
   - Runs `git log --since="<reviewed> 23:59:59"` over each row's files (a `reviewed`
     date covers that whole day, including commits made earlier that day); flags rows
     with commits and lists up to 8.
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

- **Problem tasks** (owner, 2026-11-16; replaced label batches, which replaced one agent per
  row). Research is organised **by problem**: `R/package_metadata/audits/algorithm_taxonomy.json`
  defines problems (e.g. `binary-glm-mle`) and methods (e.g. `irls`), and every inventory row
  has a `problem_id` and `method_id`. One agent per problem gets the problem and every method
  EDI uses for it (`task_problem.json`, from `--task-problem`), the problem's inventory rows
  (`row_entries.csv`) and its previous result (`previous_results.json`), and answers "what is
  the fastest acceptable way to solve this problem at EDI's sizes?". Why: the free-text
  `algorithm` labels fragmented the same work (logistic/Poisson GLM fits sat under ~30 labels
  in batches A.1-A.10, each researched alone), and no agent compared methods for a problem.
  Task prompt: `.github/prompts/algorithm_audit_research.md`; the research *method* is in
  `.github/prompts/research_agent_CLAUDE.md`, appended to the agents' system prompt
  (`--append-system-prompt-file`); refine it from the search logs.
- **Taxonomy search terms.** Each method lists `synonyms` (IRLS = iteratively reweighted
  least squares = Fisher scoring = Newton-Raphson for canonical-link GLMs), `broader`
  (second-order methods, GLM fitting), `narrower` (step-halving, trust region, LDLT/QR,
  warm starts) and `software` (glm, speedglm, fastglm, glmnet, liblinear, statsmodels); each
  problem lists `search_terms`. Agents return `proposed_terms`; the PR job adds them to the
  taxonomy. Check 4 flags rows whose ids are not in the taxonomy, unused taxonomy entries,
  and methods missing a term list.
- **Required search plan, recorded and audited.** For its problem and each method, an agent
  must search the problem, every synonym, broader and narrower term and the rival software,
  and check arXiv, CRAN Task Views, JSS and The R Journal; it reports each search
  (`query`, `where`, `term_classes`, `method_ids`, `result`). The report flags ("Search-plan
  gaps") any term class or venue a problem's searches skipped, and any agent that reports
  more searches than its transcript shows.
- **Trivial methods** (owner, 2026-11-16): 23 methods are marked `"trivial": true` in the
  taxonomy, with a `trivial_reason` (O(1) or single-pass work, closed-form formulas,
  randomization rules costing one draw per subject, orchestration and tooling). They are
  reviewed in one line and need no per-term searches; the coverage check skips them. The
  problem-level search and the four venues stay required for every problem. Borderline
  methods with known faster algorithms (DeLong variance, erfc normal CDF, separation
  detection, linear search) were deliberately left non-trivial.
- **Collecting problem: `dense-linear-algebra`** (owner, 2026-11-16). The generic dense
  factorizations and inversions (Cholesky/LDLT, QR, LU, Gauss-Jordan, eigen pseudo-inverse,
  Sherman-Morrison, Schur complement) appear inside 12 problems; each agent researched them
  a little and left coverage gaps. They are now researched once: the problem's
  `collects_methods` lists them, its agent gets every inventory row using them (57 rows),
  and each method carries `researched_in: dense-linear-algebra`. Elsewhere they are reviewed
  in one line and the coverage check skips them; inside `dense-linear-algebra` the full plan
  applies. Check 4 flags a `researched_in` that points at a problem not collecting the method.
- **EDI's own designs** (owner, 2026-11-16). Problems built on the authors' own methods carry
  `edi_original` (the citation): `kk21-covariate-weights`, `kk-sequential-matching`,
  `greedy-swap-allocation-search`, `matched-pair-reservoir-estimators`. Agents do not search
  for the design by name (only its papers exist); they research its subroutines as used, and
  the first two problems' `search_terms` name those standard sub-problems (many small
  regressions and screening; online nearest-neighbour search under a changing metric).
  `matched-pair-reservoir-estimators` also has `skip_research` (all five methods are trivial
  closed forms): its rows stay inventoried, but it gets no research agent.
- **Open-source implementations** (owner, 2026-11-16): agents record every open-source
  implementation they find (`implementations`: name, URL, license as stated with the URL it
  was read from, `gpl3_compatible` yes / conditional / no / unknown, language, methods,
  relevance). The findings file lists them compatible-first; `research_log.json` keeps them
  per problem across runs.
- **Tool policy** (2026-11-16 security fix). In full run 43925959437 all 82 agents used Bash
  (556 calls: reading their inputs, `curl` of CRAN tarballs, `gh api`) although
  `--allowedTools` listed only `Bash(git log/show/diff:*)`: the allow list does not restrict.
  A transcript scan found no environment, token or credential access. `--disallowedTools` now
  denies `Bash`, `Agent`, `Task`, `Edit`, `Write`, `NotebookEdit`, and `Read` on `//proc`,
  `//sys`, `//etc`, `~/.config`, `~/.ssh` and the Claude credentials file (deny always wins).
  The git history agents used the shell for is precomputed as `code_changes.diff`
  (`--code-changes <task>`, 400 KB cap). The report flags any transcript that calls a denied tool.
- **Inventory shards** (2026-11-16). The same run's inventory agent got 281 new functions and
  264 changed entries, delegated to four sub-agents through the Agent tool, and submitted an
  empty answer before they returned. The currency work is now split into `inventory.1` ...
  `inventory.N` (about 40 items each, a file's items in one shard; `--inventory-shards`);
  `research_tasks=inventory` runs all of them, and the PR job merges their outputs. The plan
  job checks out full history so it plans the same shards the research jobs compute.
- **Never use "Update branch" on a research PR** (2026-11-16). On PR #14 it merged `main`
  into the bot branch line by line; both sides had appended a key to the same taxonomy entry,
  the merge dropped a comma, and `algorithm_taxonomy.json` became invalid JSON on `main`
  (merge 36c47841). The next run's plan and drift jobs then crashed. Repaired by a three-way
  structural merge from the two parents (main's version plus only what the PR added relative
  to the common ancestor). Merge research PRs as they are; fix conflicts on `main`.
- **Transcripts.** Each agent's full Claude Code transcript is the run artifact
  `transcript-<problem>` (90 days; never `show_full_output`, which would print it in the
  public log). `.github/scripts/algorithm_audit_search_log.py` extracts every WebSearch
  query and WebFetch URL; the PR commits them as
  `audits/research_findings/<date>-run<id>-searches.md`, next to the findings, for critique.
- Every method of a problem is accounted for: one in neither `methods_reviewed` nor
  `not_reviewed` is flagged **silently skipped**. (History: one agent per row reviewed 2 of
  120 algorithms in 12 of its 80 turns, so labels were batched in eights; batching by label
  then fragmented problems, so tasks became problems.)
  - **Previous results** (owner, 2026-11-16): `R/package_metadata/audits/research_log.json`
    holds each problem's last research result (date, run, per-method conclusions and notes,
    findings, sources). The PR job updates it for every problem whose agent ran (a method in
    `not_reviewed` keeps its old entry; a problem whose task did not run keeps its whole
    entry and date); the prepare step gives each agent `previous_results.json` for its problem
    (`algorithm_audit_drift.py --previous-results <problem_id>`), with the commits that
    touched the problem's files since.
    Agents search only for what is new since `last_researched` and report `vs_previous`
    (`unchanged` / `updated` / `new`); the findings file shows the counts. A finding that
    still stands must be re-reported, since the log keeps only the latest run's findings.
    **Every algorithm is researched in every monthly run** (owner, 2026-11-16): the log
    shortens each agent's work, it does not skip anything. A rotation that skips unchanged,
    recently researched algorithms was considered (about a third of the cost) and rejected.
  - **Consistency check** (2026-11-16): a finding naming a method not marked
    `faster_option_found`, or a `faster_option_found` method no finding names, is listed under
    "Inconsistent agent output" and flags the report (first seen in batch A.1 of the
    2026-11-16 full run: a `glm.nb` finding marked `no_faster_acceptable_found`).
  - **Open copies of papers** (owner, 2026-11-16): agents must cite a paper's DOI, not only
    a publisher page, and an open version when the publisher blocks them. For every cited
    DOI the PR job (`add_open_copies` → `doi_access`) tries the **publisher page first**
    (owner, 2026-11-16): if it loads and OpenAlex does not mark the published version
    closed, the DOI link stands. Only if the page is blocked (403 etc.) or paywalled does it
    fall back to OpenAlex and list "Open copies", best first: arXiv, bioRxiv / medRxiv,
    PubMed Central / Europe PMC (never a publisher page); with none, the report says "No
    open copy found" (first case: the glmGamPoi paper, whose OUP page returns 403; OpenAlex
    gives its bioRxiv preprint and PMC8023675).
- **Inventory task** (`.github/prompts/algorithm_audit_currency.md`): reads
  `--currency-context 40` output (functions added in the last 40 days that the
  inventory lacks; inventory entries whose symbol appears in a changed line or hunk
  header). It proposes inventory rows (with fetched reference URLs) for new functions that
  implement an algorithm, and corrected `details` for rows that no longer describe the
  code. It never rewrites a verdict.
- **Agents are read-only; the PR job writes.** Agents get Read/Glob/Grep,
  WebSearch/WebFetch and `git log|show|diff` only; Edit/Write are disallowed and their job
  token is `contents: read`. They return JSON through `--json-schema`. A separate
  `research-pr` job (`.github/scripts/algorithm_audit_research_apply.py`) turns that JSON
  into one pull request (changed 2026-11-16 from an issue, owner decision, so results live
  in the repo):
  - `R/package_metadata/audits/research_findings/<date>-run<id>.md`: the full report (findings,
    tasks that did not run, algorithms not reviewed or silently skipped, inventory changes
    applied and held).
  - Inventory changes it can apply mechanically: a proposed new row, only with reference
    URLs the job verified itself (Wikipedia API, Crossref) and a known audit row; a stale
    `details` correction, only when it names exactly one inventory row. Everything else is
    listed under "Needs a human". **Verdicts are never changed.**
  - The PR body carries an online run of check 4 on the branch, because required status
    checks do not run on a PR opened with `GITHUB_TOKEN`; the owner merges with the admin
    bypass. Faster-algorithm findings stay unverified: promote a confirmed one to a release
    TODO by hand.
  - Expect two "failed" runs per research PR (R-CMD-check, test-coverage-python on the
    `pull_request` event). A PR opened by `github-actions[bot]` creates them with zero jobs;
    they never start, and GitHub closes them as "failure" the moment the PR is merged
    (first seen on PR #10, 2026-11-16). Nothing was tested; ignore them.
  - Before merging a PR you pushed a fix to, check that the PR's head commit shows it.
    On PR #10 GitHub had not registered a pushed fix (35a3fc3) when the PR was merged
    minutes later, so the merge took the bot's original commit; the fix went to `main`
    by cherry-pick instead.
  - Needs Settings > Actions > General > "Allow GitHub Actions to create and approve pull
    requests".
- **Never silently clean.** A task with no output (no `ANTHROPIC_API_KEY` secret, agent
  failure, timeout, invalid JSON) is listed under "Tasks that did not run" in the findings
  file, and such a run always opens a PR.
- **Findings are unverified.** They follow the verified/unverified rule below: a finding
  becomes a TODO only after a benchmark or the A/B harness
  (`../v1_2_0/algorithm_ab_testing_framework.md`) confirms it.
- **Setup and cost.** Needs the `ANTHROPIC_API_KEY` (API billing) or
  `CLAUDE_CODE_OAUTH_TOKEN` (subscription, from `claude setup-token`) repository
  secret; `CLAUDE_CODE_OAUTH_TOKEN` was set 2026-11-16. Each research run is about 70
  agent sessions. Models (owner, 2026-11-16; the action's default was Sonnet 5.5):
  research batches run Opus 5.5 at the default effort, the `inventory` agent Sonnet 5.5
  at `--effort medium` (set per task in the prepare step) (max 100 turns since 2026-11-16, was 80: problem trials used up to 65; 20-minute timeout each since 2026-11-16 (slowest observed 5.7 min), 6 in parallel), billed to that
  secret. Trial run 2026-11-16 (row A as a single task, plus inventory): $0.30 and $0.67,
  12 and 18 turns. Use the `research_tasks` input to run a subset by hand.
- **No overlapping research runs** (owner, 2026-11-16). Two research runs would open PRs
  editing the same inventory CSVs. The plan job's "Wait for earlier research runs" step
  makes a run that will do research wait (polling every 60 s, plan timeout 180 min) while
  any earlier run of this workflow still has `research (...)` or `research-pr` jobs
  unfinished. Not a workflow-level `concurrency:` group: GitHub keeps one pending run per
  group and cancels the older, so a weekly no-op Thursday trigger could cancel a real
  research run queued behind a manual one. Runs with no research never wait or block,
  nothing is cancelled, and only earlier run ids are waited on (no deadlock). Separately,
  an unmerged research PR still conflicts with the next one: merge each before the next run.
- **Schedule mechanics.** Cron is UTC with no DST, and a cron that restricts both
  day-of-month and day-of-week matches either one, so `59 20 * * 4` and `59 21 * * 4` both
  fire every Thursday; the plan job keeps the one that is 23:59 in Jerusalem (20:59 UTC in
  summer, 21:59 in winter) on a first Thursday (day ≤ 7) on or after `RESEARCH_START`
  (2026-12-03). Drift runs only on its monthly cron (and on manual dispatch); a `skipped`
  job never triggers the failure notice. Each run costs roughly $75-80 of Opus usage
  (68 batches at about $1.09 each in the 2026-11-16 trial).
- **Tests:** `python3 .github/scripts/test_algorithm_audit_drift.py` covers the
  currency-context parsing and the report merge (including the NOT RUN rule); the
  workflow runs it first.

## Turning research findings into TODOs (owner, 2026-11-16)

After each research PR is merged:

1. **Housekeeping.** Apply the findings file's "Needs a human" items to the inventory /
   taxonomy by hand, and re-review every inventory row flagged "may affect the verdict"
   (Re-review procedure below); record outcomes in `algorithm_choice_audit.md`'s
   re-review log.
2. **Triage every new finding** (findings file section 1; each heading carries its id,
   e.g. `binary-glm-mle#43925959437.1`) into `R/package_metadata/audits/research_triage.csv`
   (`finding_id, run, problem_id, finding, decision, status, reason, todo, revisit, decided`):
   - **reject**: changes the estimator when that is not wanted, does not apply at EDI's
     sizes, incompatible license, or already rejected for a reason that still holds;
   - **defer**: plausible but low value now; give a `revisit` date;
   - **investigate** (the normal path): a release TODO with a bounded benchmark and a stop
     condition, e.g. "benchmark X against the current kernel at EDI sizes; done when there
     is a >= 1.5x win with identical results, or closed with the numbers". A correctness or
     regression item goes to the current bug-fix release if it meets that release's entry
     rule; performance work goes to v1.1.0+; an estimator change needs the owner's decision;
   - **adopt**: only once something in the repo verifies it (a benchmark, the A/B harness).
   Drafts are `status: proposed` (a Claude session may draft them); the owner's decision makes
   them `approved`, and only then is the TODO added to the release file and cited in `todo`
   as `TODO-<n>-v<version>`.
3. **Feedback.** The next run's agents get each problem's decisions in
   `previous_results.json` (`triage`), set `previous_finding_id` when re-reporting the same
   idea, and do not re-report a rejected (or not-yet-due deferred) finding without
   `new_evidence`. The report splits section 1 (new) from 1b (re-reported, with the earlier
   decision) and flags re-reports without new evidence (section 8).
4. **Annotate:** `python3 .github/scripts/algorithm_audit_triage.py annotate` writes each
   decision under its finding in the findings files; `... summary` shows what still needs a
   decision. Check 4 validates the CSV (decisions, statuses, existing finding ids, approved
   TODOs that exist in their release file, defers with a revisit date; due defers flagged).

## Guardrails

- **No commits to `main`, no plan edits.** The drift check is read-only; the research job
  only opens a pull request (inventory CSVs and a findings file), which the owner reviews.
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
