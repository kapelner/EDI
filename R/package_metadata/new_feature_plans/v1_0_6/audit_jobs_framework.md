# Scheduled Audit Jobs: a Shared Framework, the Rd Audit, the TODO-Status Audit and the Other Audits

> **Status: PROPOSED 2026-11-17 (owner request).** Not yet placed in a release file. Like v1.0.7-TODO-11 / v1.0.7-TODO-12 / v1.0.7-TODO-14
> it is CI infrastructure with no package code, API or result changes, so it needs the same owner exception to
> `release_v1_0_6.md`'s entry rule, or it waits for v1.1.0.
>
> **Builds on:**
> - `.github/workflows/algorithm-audit-drift.yml`: the existing Claude-in-CI audit. Its prompt and schema layout
>   (`.github/prompts/`), its claude-code-action call, and the way it opens a labelled PR are reused here.
> - `.github/scripts/benchmark_gate.py` + the `benchmark-results` branch: the "only redo what changed, keep a
>   manifest on a data branch" pattern, reused here as the audit cache.
> - `scripts/check_doc_links.py`: already checks URLs, `\href{}` and `\doi{}` in roxygen and Markdown (nightly
>   "documentation links" job). The Rd audit does not check external URLs again.

## Why

Some kinds of drift are found only when someone happens to look:

- Rd examples break silently. `\donttest{}` blocks (80 of the 370 Rd files) do not run in a plain
  `R CMD check`.
- Docs reach other topics with `\link{}`, and topic renames leave dead links.
- Grammar and clarity slip in docs written in a hurry.
- Release files say a TODO is open when the work landed weeks ago. `release_v1_0_6.md` has 43 open boxes and
  0 ticked, while commits such as `54ec2162` ("v1.0.7 TODO-34: remove three dead C++ paths") say otherwise.

A weekly job that finds these and proposes the fix as a PR keeps them from piling up. Each job keeps notes, so
a run starts from what earlier runs established instead of re-reading everything.

## Part 1: the framework

### Shape of every audit

One workflow per audit, `.github/workflows/audit-<name>.yml`, each built from the same four stages. Shared code
lives in `.github/scripts/audit_common.py` (with `test_audit_common.py`).

1. **Mechanical checks** (no Claude, no API cost). Deterministic and fast. Their findings go into the PR as they
   are, and they also narrow what the Claude stage reads.
2. **Gate on the cache.** Load `<audit>/manifest.json` from the `audit-notes` branch and decide which units
   (one Rd file, one TODO) need a fresh look:
   - the unit is new, or its content hash changed;
   - something the unit depends on changed since its last audit (the per-audit rules are below);
   - its last verdict was a finding that is still open (not fixed and not rejected);
   - it is in this week's **rotation slice**: unchanged units are re-read on a cycle (default 8 weeks) so
     nothing is trusted forever. The slice is a stable hash of the unit id modulo the cycle length, so each
     unit is re-read on the same week of the cycle.
   - `workflow_dispatch` input `scope`: `auto` (the default; the rules above), `all` (full pass), or `none`
     (mechanical checks only).
3. **Claude stage.** Units go to agents in batches of at most 8 (the algorithm audit found that one agent
   given 120 items finishes 2). Each agent gets its prompt from `.github/prompts/audit_<name>.md`, an output
   schema `audit_<name>.schema.json`, its batch, and that audit's `decisions.md` (below). Tools are read-only,
   as in the algorithm audit: no Edit, Write or general Bash. The TODO audit also gets
   `Bash(git log:*)` and `Bash(git show:*)`.
4. **Apply and open the PR.** A script (not the agent) applies the findings that pass the audit's
   mechanical apply rules, and lists everything else under "Needs a human" in the PR body.

### The cache: `audit-notes` branch

An orphan branch, like `benchmark-results`. One folder per audit:

```
rd/
  manifest.json      unit id -> {hash, deps_hash, audited_at, run_id, verdict, finding_ids}
  findings.jsonl     every finding ever raised: id, unit, text, status (open/fixed/rejected), PR number
  decisions.md       settled conventions and rejected findings, written for the agent to read
  notes/<unit>.md    optional short per-unit notes the agent asked to keep (e.g. "this example is slow
                     on purpose; it shows the warm start")
todo/
  ...same layout
```

- **`decisions.md` is how the job learns.** At the start of each run, `audit_common.py` lists the audit's PRs
  closed since the last run:
  - a finding whose change was merged becomes `fixed`;
  - a finding whose change the owner reverted in the PR, or whose PR was closed unmerged, becomes `rejected`
    and is appended to `decisions.md` with the owner's review comment if there is one.

  The agent is told not to raise a finding that matches a rejected one. The owner can also edit
  `decisions.md` by hand (for example "we write 'randomisation' nowhere; US spelling throughout").
- The branch is written only by the audit jobs, after the PR is opened. Cache commits never touch `main`.
- A cache that cannot be read (the first run, or a corrupt file) fails open to a full pass. That is the same
  rule as the benchmark gate.

### PRs

- One open PR per audit at a time, on branch `audit/<name>`, labelled `audit-<name>`. If last week's PR is
  still open, the run rebases that branch onto `main` and adds its changes on top. Commits the owner pushed
  to the branch are kept. Findings the owner removed by editing the branch count as rejected.
- No PR when there is nothing to propose. The run summary still records what was checked.
- The PR body has three parts:
  1. **Applied changes**, grouped by file.
  2. **Mechanical findings** that need a human (e.g. a failing example whose fix is not obvious).
  3. **Coverage**: units checked this run (changed vs rotation), units skipped, and agents that failed
     (reported as NOT RUN, never as clean).
- Known limits, from the algorithm-audit PRs (2026-11-16):
  - PRs opened with `GITHUB_TOKEN` trigger no other workflows, so `main`'s required checks do not run on
    them. The owner merges with the admin bypass.
  - The repository setting "Allow GitHub Actions to create and approve pull requests" must be on.
  - Schema files must stay free of single quotes (they are passed as `--json-schema '...'`).
  - `anthropics/claude-code-action` fails on a `push` event ("Unsupported event type: push"; it accepts
    schedule, workflow_dispatch, repository_dispatch, workflow_run and issue/PR events). A Claude audit
    that should run after a push gets it through a relay workflow and `workflow_run`
    (`rpy-parity-push.yml`), not through `on: push` or a `GITHUB_TOKEN` dispatch, which would run as
    `github-actions[bot]` and fail the action's human-actor check (2026-11-17).
- Each audit also checks its own result in the PR. The Rd audit, for example, re-runs `tools::checkRd` and the
  examples it changed on the PR branch, and puts that result in the body.
- Decisions for the owner (added 2026-11-18). A report's "Decisions for you" items each get an id
  (`<audit>-d<8 hex>`, stable across runs) and are kept in `<audit>/decisions_open.json` on `audit-notes`
  until a run no longer finds them, an unticked release TODO cites the id, or the id is listed in
  `R/package_metadata/audits/DISMISSED_DECISIONS.md`. Items with nothing to decide go in a collapsed
  "For information" block. `.github/scripts/audit_decisions.py` (run by `audit-status.yml`) lists every
  audit's open decisions in one pinned issue labelled `audit-decisions`, so they stay visible after the PR
  that raised them is merged.
- Mechanical findings (owner, 2026-11-19) have the same lifecycle. Each line of a report's "Mechanical
  findings" gets an id `<audit>-m<8 hex>` (from its unit and text) and is kept in
  `<audit>/mechanical_open.json` on `audit-notes`. It leaves the list when a run no longer finds it (it counts
  as fixed, and its `findings.jsonl` entry goes from `reported` to `fixed`), when an unticked release TODO
  cites the id, or when the id is listed in `DISMISSED_DECISIONS.md`. The `audit-decisions` issue lists the
  open ones under their own heading, "Mechanical findings". A module whose mechanical stage checks only some
  units each run returns `mechanical_scope_units` (the units it checked) in its parts, so findings on the
  other units are carried, not counted as fixed. Two more guards: a run with a not-run finding (kinds
  `not-run`, `unreadable`, `not-configured`, `tool`, `input`, `stage_failed`; rd and readme-drift emit
  `not-run` when R or EDI is missing) counts nothing as fixed; and kinds reported only once against a
  snapshot (`example-slower`, `license-changed`, `deprecated-call`, plus a module's
  `SPEC["mechanical_sticky_kinds"]`) stay open until cited or dismissed. Ids come from the unit plus the kind
  and the text with numbers masked, so a moving line number, duration or count keeps the id. Before this,
  mechanical findings were only re-listed in each PR body, with no way to cite or dismiss them (PR #65
  listed 125).
- **Every audit's findings reach that lifecycle** (owner, 2026-11-19). A module's apply() may return a
  mechanical line as a dict `{text, unit, kind, key}` (its own unit, and a key that survives rewording),
  and `mechanical_not_run: True` when its checks did not run. Audits that used to keep findings outside it:
  dead-code lists each confirmed candidate as a decision (`key "confirmed"`) as well as in
  `dead_code_candidates.md`, and a merged PR marks the candidate `listed`, not `fixed` (`merged_status`);
  compiled-code's detector findings with no proposal are a decision on every run (`key "detectors"`), and
  "newly hot" is a sticky mechanical kind; todo-status's `unclear` verdicts are decisions (`key "unclear"`);
  untested-code's Python regions are mechanical findings keyed by region id; test-suite-health no longer
  writes `test_suite_health.md` (deleting a line there was a second way to reject) and its findings are
  mechanical, keyed without line numbers; generated-drift's generator warnings are keyed by generator. The
  docs-scenario job keeps its own `findings.jsonl` (same cite and dismiss rules, ids `ds-...`), and its open
  findings get their own heading in the `audit-decisions` issue.

### Secrets, models and cost guard

- `ANTHROPIC_API_KEY` or `CLAUDE_CODE_OAUTH_TOKEN`, as for the algorithm audit. Without one, the Claude stage
  is NOT RUN, and the mechanical stage still runs and can still open a PR.
- Default model Sonnet 5.5. Opus 5.5 only where an audit says so.
- Each audit has `max_batches` (a hard stop per run). Units over the limit roll to next week, oldest first, and
  the PR body says how many rolled over.

## Part 2: the Rd audit

**Frequency: weekly, Saturday 06:07 UTC** (after the 02:07 nightly has finished, so the two do not compete for
runners).

### Mechanical checks (every Rd file, every week)

All of these run against a CI-built EDI. Building the package on a runner is what `R-CMD-check` already does;
the local no-rebuild rule in `CLAUDE.md` is about the owner's machine, and this job never runs locally.

| Check | How | Finding when |
|---|---|---|
| Rd syntax and structure | `tools::checkRd()` on every file | any warning or note |
| Topic links | resolve every `\link{}` / `\link[pkg]{}` / `\linkS4class{}` against EDI's aliases and the aliases of the installed target package (`tools:::.check_Rd_xrefs` covers most of this) | target not found, or found only in a package EDI does not import or suggest |
| Code vs docs | `tools::codoc()`, `tools::codocClasses()` | documented arguments or defaults that differ from the code |
| Examples run | each file's `\examples` extracted with `tools::Rd2ex(commentDonttest = FALSE)` and run in its own `Rscript` with a time limit (60 s; 300 s for `\donttest`), several files in parallel | error, warning, or time limit hit |
| CRAN timing | time of the part of each example *outside* `\donttest{}` | over 5 s (CRAN's limit) |
| Spelling | `spelling::spell_check_files()` on the Rd files, with a new `R/EDI/inst/WORDLIST` seeded on the first run | unknown word not in the wordlist |

Example timings are kept in the manifest, so the PR can also report an example that became much slower.

### Claude stage (changed files + rotation)

- **Unit:** one Rd file. Its hash covers the Rd text. Its dependency hash covers the roxygen block it came from
  and the signature of the function or class it documents.
- **What the agent checks:** grammar, spelling the wordlist allows but is still wrong, unclear sentences,
  `@param` text that does not match what the code does, `@return` that does not describe the returned object,
  and examples that run but do not show what the page is about.
- **Out of scope for the agent:** URLs (nightly link job), anything the mechanical stage already reports, and
  style changes with no clarity gain.
- **Model:** Sonnet 5.5. First full pass: 370 files, 47 batches. After that, roughly the changed files plus a
  1/8 rotation, about 50 files (7 batches) a week.

### Where fixes go

- Rd files are generated. Every text fix is made in the roxygen block in `R/EDI/R/*.R` that produces the
  page. The agent reports the Rd file and the source block; the apply script locates the block with the
  `% Please edit documentation in R/<file>.R` header that roxygen writes into each Rd file.
- After all fixes are applied, the PR job runs roxygen **once** (no interim runs, matching the doc-batch rule)
  and commits the regenerated Rd files with the source changes.
- **Apply automatically:** spelling and grammar fixes that change at most one sentence, and wordlist
  additions for EDI's own terms (class names, method names).
- **CRAN timing and `\dontrun` / `\donttest`** (owner, 2026-11-17). Every examples block is timed the way
  CRAN reports it. The part CRAN runs by default (outside `\donttest{}` and `\dontrun{}`) must stay under 5 s
  CPU and elapsed time (aim for 2.5 s; 4 s in CI, which is faster than CRAN's slowest machines), with CPU
  time no more than 2.5 times elapsed (at most 2 threads). The `\donttest{}` part is timed separately: R CMD
  check `--as-cran` runs it, so it must run clean (report it over 60 s). Rules for a proposed block:
  - make slow code faster first (smaller n, fewer draws through the class's own arguments);
  - code that runs but is slow goes in `\donttest{}`, never `\dontrun{}`;
  - `\dontrun{}` only for code that cannot run in a check (credentials, network, interactive, software not
    on CRAN, or code meant to show an error); `\dontrun{}` around runnable code is a finding;
  - each page keeps a small fast plain part where one is possible, not everything in `\donttest{}`.
- **Random failures and the published site** (owner, 2026-11-17, from the
  `InferenceCountZeroInflatedNegBin` page, whose `\donttest{}` example draws `rpois(10, 2)` with no seed and
  errors whenever no zero is drawn). Each example runs 5 times with seeds 1..5 in fresh sessions, and fails
  if any seed fails (examples slower than 30 s run once). The audit also reads the `#> Error` and
  `#> Warning` lines in the Examples section of every page on the published pkgdown reference
  (https://kapelner.github.io/EDI/reference/), which shows the run that built the site. A fix must run
  clean on all 5 seeds, and must make the example robust (data that meets the class's requirements, or a
  seed), never hide the error (`try()`, `tryCatch()` or `\dontrun{}`).
- **Failing examples are fixed, not only reported** (owner, 2026-11-17). An Rd file whose example errors,
  warns or hits its time limit is a Claude unit in that run whatever its rotation week. The agent gets the
  roxygen `@examples` block, the error text, the elapsed time and the function's usage, and returns a
  complete replacement block with a one-line cause. The finish stage installs EDI and runs the proposed
  example exactly as the mechanical stage ran the original (fresh session, same time limits, CRAN's 5 s rule
  outside `\donttest{}`). The new block goes into the roxygen source only if it runs with no error and no
  warning; otherwise the proposal and its new failure go to "Needs a human". Unverified examples are never
  applied.
- **Needs a human:** examples whose proposed fix did not run clean, broken links whose right target is not
  obvious, codoc mismatches, and any change to what a sentence claims.

## Part 3: the TODO-status audit (audit 6)

**Frequency: weekly, Wednesday 06:07 UTC.** Mid-week, so the ticks are current before the owner's planning.

### Scope

- **Units:** every checkbox TODO (`- [ ]` / `- [x]`) in:
  - `future_release_plans/release_v*.md` for releases not yet on CRAN;
  - the plan files those releases link to under `new_feature_plans/` and `bug_fix_plans/`.
- **Out of scope:**
  - `finished_features/` and released versions' files (v1.0.0, and v1.0.5 once it is on CRAN);
  - struck-through moved items (`~~TODO-8~~ → moved ...`). The audit checks only that the target the pointer
    names exists.

Today that is roughly 360 release-file TODOs plus about 1,280 plan-file checkboxes. Nearly all of them are
in releases v1.1.0 and later, and work on those is rare.

### Mechanical tidy (owner request, 2026-11-18)

Before the gate and the Claude stage, `.github/scripts/audits/_todo_tidy.py` tidies the unreleased release
files. No API cost; the result is the PR's first commit, the ticks are the second.

1. **Duplicate TODO numbers.** Two top-level entries that lead with the same number collide (a struck
   pointer for a split part, `~~TODO-5 (steps 5–8)~~ → moved ...`, shares its live entry's number on
   purpose and does not). The entry added first keeps the number: its `(added YYYY-MM-DD` date, else the
   git-blame date of its first line, else file order. Each later one gets the next number above every
   number the file uses. A reference is rewritten only when it is provably about the renumbered entry:
   inside its own block (lead id, `v<release>-TODO-<n>`, unqualified `TODO-<n>` that is not a nested
   `- TODO-<n>:` lead quoting a plan), on a line anywhere that also carries the entry's bold title, or in
   a file the entry introduced (named only by it, first committed on or after its added date). Every
   other reference goes under "Decisions for you". Old-style references are listed, never rewritten.
2. **Numeric order.** Each contiguous run of entries (separated only by blank lines, same indent, same
   heading) is sorted by number (`TODO-4 < 4b < 5 < 17`); a block moves as a unit and headings, prose,
   tables and gaps stay put. Sorting within runs, not globally, keeps the topic sections ("Bugs found by
   the data-shape matrix (TODO-107..115)") intact. Not sorted: runs under a heading that declares a
   deliberate order (`(dependency order)`, `strictly ordered`, ...) and releases closed to new TODOs. The
   step is checked to be a permutation of lines and raises otherwise.

The tidy edits the work tree, so `audit_run.py` runs it only on a runner (`GITHUB_ACTIONS=true`) or with
`AUDIT_TIDY=1`. Dry run on copies: `python3 .github/scripts/audits/_todo_tidy.py --repo . --src <copies>
--out <dir>`. The pre-push guard against new duplicates is separate (`scripts/check_todo_duplicates.py`).

Decided (owner, 2026-11-18): sections whose heading declares a deliberate order ("dependency order",
"strictly ordered", and the other phrases `ORDERED_HEADING` in `_todo_tidy.py` matches) stay exempt from
reordering; only their duplicates are renumbered.

### When a TODO is re-checked

- its text changed;
- a commit since the last audit cites it in the `v<version>-TODO-<n>` form, the older `v<version> TODO-<n>`
  form, or a plan's own `<plan>.md TODO-<n>`;
- a file the TODO names (paths in backticks, class names mapped to their files) changed since the last audit;
- it is ticked and in the rotation slice. Ticked items are rotated more slowly, on a 12-week cycle.
- open TODOs in the current and next release get a **4-week rotation**; later releases get 12 weeks.

### What the agent decides

For each TODO it returns one of:

| Verdict | Meaning | Needs |
|---|---|---|
| `done` | every part of the TODO's request is in `main` | evidence for each part: commit SHA, `file:line`, or test name |
| `partly done` | some parts are done | which parts are done (with evidence) and which are left |
| `not done` | nothing yet, or nothing the agent could find | what it searched |
| `undone` | ticked, but the work is gone or never met the TODO's own "done when" | evidence of the gap |
| `unclear` | the TODO is too vague to judge | why |

**Model, by release (owner, 2026-11-17):**

- **Opus 5.5** for TODOs in the current release and the next one (today v1.0.6 and v1.1.0, and the plan files
  they link to). Judging "done" means reading a TODO's acceptance criteria against the code, which is the call
  that goes wrong on a weaker model, and these are the TODOs whose ticks gate a release.
- **Sonnet 5.5** for TODOs in v1.2.0 and later. Work on them is rare, and a wrong verdict there costs little:
  the owner still reviews every tick in the PR.
- The script works out "current" and "next" from the release files, so the split moves with each release
  without editing the job. A TODO moved between release files is judged by the model of the release it is in
  now.
- **Rough cost:** about $10 a run, $45 a month, and about $110 for the first full pass, against about $20,
  $85 and $200 with Opus for every TODO. The estimate is based on the algorithm audit's measured Opus batch
  (about $1.09 for 8 items) and Sonnet costing half as much.

### Apply rules (mechanical)

- `done` with evidence for every part: change `- [ ]` to `- [x]` and append
  ` *(ticked by the TODO audit <date>: <evidence>)*` to the TODO's first line. The original text is never
  edited.
- `undone`: change `- [x]` to `- [ ]` and append ` *(unticked by the TODO audit <date>: <gap>)*`.
  - The audit **never** unticks an item the owner closed explicitly ("CLOSED ... by owner",
    "owner decision ... done"). Those go to "Needs a human".
- `partly done`: the box is not changed. The PR body lists the parts and their evidence, so the owner can
  split the TODO or tick it.
- `not done` and `unclear`: no change. They appear in the PR body only if they changed since the last run.
- **A tick never closes a release gate by itself.** Gate rows in release files (G1..G6 tables) are not
  checkboxes and are never edited.
- **Cross-file consistency:** when a TODO is a pointer ("moved to `release_v1_1_0.md → TODO-157`") and its
  target is ticked, the PR body lists the pointer too. The script does not tick pointers.

The owner reviews every tick in the PR. A tick the owner reverts on the PR branch is a rejected finding, and
`decisions.md` records why, so the same TODO is not ticked again on the same evidence.

## Part 4: all audits and how often each runs

The framework is built with the Rd audit. The other audits follow, each a prompt, a schema, a units/deps
function and apply rules on top of `audit_common.py`.

| Audit | Frequency | Claude | Model | Notes |
|---|---|---|---|---|
| Rd audit (Part 2) | weekly, Sat 06:07 UTC | changed + 1/8 rotation | Sonnet | first |
| TODO-status audit (Part 3) | weekly, Wed 06:07 UTC | changed + 4/12-week rotation | Opus for the current and next release; Sonnet for v1.2.0 and later | second |
| Privacy check on public files | weekly, Mon 06:07 UTC | only borderline hits | Sonnet | word list kept in the private repo and passed as a secret, so the list itself is never public |
| README / vignette / article drift | weekly, Thu 06:07 UTC | changed docs + rotation | Sonnet | runs every chunk, then checks prose numbers against output |
| Test-suite health | weekly, Tue 06:07 UTC | none at first | — | tests with no expectations, permanent skips, never-hit functions, tests that flip between nightlies |
| Docs claims vs behaviour | monthly, 2nd Saturday | rotation over all exported classes | Opus | pulls testable claims from roxygen, checks a test covers each |
| R ↔ Python parity | monthly, 3rd Saturday; also after a `python/` or kernel change | changed bindings | Sonnet | defaults, argument names, docstrings vs R |
| Dependency and license drift | monthly, 1st Monday | only summarising | Sonnet | must skip the dataset rows deliberately pinned to old releases |
| CRAN check-results watcher | daily, 07:07 UTC | none | — | reads CRAN's check page for EDI; opens or updates ONE issue (label `cran-check`) when any platform shows a NOTE, WARNING or ERROR, and closes it when clean. An issue, not a PR: there is nothing to write. CRAN sets a fix deadline, so this is the time-critical one |
| Allowlist and baseline hygiene | weekly, Mon 07:07 UTC | none at first | — | allowlist and accepted-row entries (path audits, `comprehensive_results_audit_baseline.csv`, calibration acceptances) whose cited TODO is ticked or missing, or that no longer trigger; the PR removes them. Reads the TODO audit's verdicts |
| Generated-file drift | weekly, Tue 07:07 UTC | none | — | regenerates `RcppExports`, the Rd files and the committed reports that can be rebuilt without timing (not the benchmark reports), and reports any difference from what is committed; the PR is the regenerated files |
| NEWS and version consistency | weekly, Thu 07:07 UTC | commits since the last release tag | Sonnet | behaviour-changing commits with no NEWS entry (Claude judges "behaviour-changing"; the PR drafts the entry under "Needs a human"); version numbers that disagree across `DESCRIPTION`, the Python package, the citation file and the README (mechanical) |
| CI self-check | weekly, Fri 06:07 UTC | none | — | action versions behind their latest major, scheduled workflows GitHub disabled (it does so after 60 days of repo inactivity), run time per job against its 8-week median, bot PRs and `audit/*` / `algorithm-research/*` branches open over 4 weeks; one issue (label `ci-self-check`) |
| Python dependency vulnerabilities | weekly, Fri 07:07 UTC | none | — | `pip-audit` on the Python package's dependencies; one issue (label `python-vulnerabilities`) |
| Dead code | monthly, 2nd Monday | candidates only | Sonnet | exported R functions with no caller, test or example; C++ functions nothing reaches (call graph of the linked objects). Claude rules out the false positives (R6 methods called by name, `.Call` targets). The PR lists candidates; it removes nothing. v1.0.7-TODO-34's three dead C++ paths were found by hand |
| Reference check | monthly, 3rd Monday | changed references + 1/6 rotation | Sonnet | each DOI in `REFERENCES.md` and the roxygen `@references` resolves (Crossref) to the paper the text names: title, authors, year. The nightly link job checks only that the DOI resolves |
| Compiled-code audit (Part 5) | monthly, 4th Saturday; also when a hot function's assembly changes | flagged hot loops only | Opus | at most 3 verified suggestions per run |
| Results freshness | weekly, Sun 06:07 UTC | none | — | comprehensive-test and calibration CSV rows generated before the class or kernel behind them last changed. Each results file gets a manifest (row group → class, commit, generated_at), and the class → files map reuses `benchmark_gate.py`'s file rules. One issue (label `results-freshness`) listing the stale row groups and the regeneration command for each; it opens no PR, because regenerating is a campaign, not an edit |
| Numerical-robustness review | monthly, 1st Saturday | kernels changed since the last run + 1/6 rotation | Opus | the bug patterns that have actually happened here: `converged = TRUE` set without checking the convergence criterion, unguarded `log(0)` / `exp` overflow / division by a near-zero information, NA returned where a value is defined, a null refit with a single cold start. A finding counts only if the agent writes a failing test for it; the job runs the test on the PR branch and keeps the finding only if it fails. The PR adds the failing tests (marked `skip("v<version>-TODO-<n>")` once the owner opens a TODO) |
| Thread and random-number review | monthly, 3rd Sunday | parallel and resampling code changed since the last run + 1/6 rotation | Opus | random streams seeded per thread instead of per draw index, shared mutable state inside parallel loops, results that depend on the worker count. Same rule as above: a finding needs a test that shows the result changing with `set_num_cores()`. The existing worker-count invariance tests (v1.1.0 TODO-48) are the template |
| Source comment rot | monthly, 4th Sunday | changed source files + 1/8 rotation | Sonnet | code comments that contradict the code beside them (a stated default, tolerance, formula or "never"/"always" that the code does not do); `TODO` / `FIXME` / `XXX` notes in `R/EDI/R` and `R/EDI/src` with no release TODO citing them. The PR fixes the comments; a contradiction where the code may be the wrong side goes under "Needs a human" |
| Code duplication | weekly, Sun 07:07 UTC; plus a per-push check (no Claude) | candidates with no verdict yet, at most 96 a run | Sonnet | owner request 2026-11-18. jscpd 5.4.2 (`--min-tokens 50`, comments skipped) over `R/EDI/R`, `R/EDI/src`, `python/src`, `python/cpp`; runs merged across gaps ≤ 8 lines, extended 20 lines, diffed token by token; divergent near-clones ranked first (v1.0.6-TODO-71 / v1.0.6-TODO-75, v1.0.7-TODO-43). Verdicts intentional / refactor / divergence_bug in `code-duplication/verdicts.json` on `audit-notes`; ids `dup-<hex>` survive line moves; decisions `code-duplication-d<hex>`. One issue. `code-duplication-push.yml`: new clones and edits to one copy of a known pair, job summary plus one updated PR comment, non-blocking (`FAIL_ON_DIVERGENCE`) |
| Untested code | weekly, Tue 09:07 UTC | the top 12 uncovered regions not yet attempted (3 per agent) | Opus | owner request 2026-11-18. Reads coverage, never re-measures it for the ranking: the newest `coverage-lines` artifact of `test-coverage-R.yaml` on main (covr R lines plus the gcov lines of `R/EDI/src`; written by `audits/untested_code_export.R` in the merge job) and the newest `coverage-python` artifact (`pytest --cov`, uploaded by `test-coverage-python.yml`). Regions (runs of uncovered lines in one function) carried to HEAD through `git diff`, ids `unt-<hex>` from file, function and code text, so they survive line moves. Ranked by risk: exported functions and documented public R6 methods (+ `compute_*` / design entry points), Rcpp-exported kernels, error and guard branches, code changed in the last 90 days, code a current-release TODO fix changed (commit message or a SHA the release file names); size only breaks ties; at most 2 regions per function and 3 per file a run. Not ranked: `nocov`, platform branches, the registry's measurement artifacts and `codecov.yml` ignores, isolated `-O2` C++ lines, and rows of `R/package_metadata/audits/untested_code_allowlist.csv`, each of which must lead with an open release TODO (allowlist hygiene removes rows whose TODO is closed). Outcomes test / unreachable / intended / bug. The finish stage builds EDI in place with covr's `--coverage` flags (`EDI_UNITY=0`, new `finish_coverage_build` input of `audit.yml`), runs each test under `pkgload::load_all(compile = FALSE)` and keeps it only if it passes, asserts a value and runs at least half of its region (covr tracing of the loaded namespace for R, which also attributes composed classes; gcov for C++). One PR with the kept tests; bug tests reported, never committed; unreachable regions feed the dead-code audit (`untested-code/unreachable.json`). A failed region is retried after 4 weeks, twice, then becomes a decision. Skipped when `significant_changes.py` finds no code or test change. Future work: a mutation-testing pass over the kept tests (do they fail when the covered line changes?) |
| Algorithm audit (exists) | monthly (unchanged) | — | — | stays as it is; may move onto `audit_common.py` later |

All schedules avoid 02:07–05:00 UTC, when the nightly runs.

**Not here: two checks the owner moved to the push CI on 2026-11-17**, both in
`.github/workflows/R-CMD-check.yaml`:

- **CRAN's additional checks** (rchk, LTO, no-long-double, the newest GCC and Clang): the
  `R-CMD-check-cran-extra` job, in R-hub's containers for those CRAN machines. rchk runs on every push and PR;
  the other four run weekly with the long legs (owner, 2026-11-17, to stay under the 20-runner limit).
- **Size and time budgets** (source tarball size against CRAN's 5 MB limit, installed size, install, examples,
  tests and whole-check times): each CRAN-platform leg records its figures, and the
  `package-budget` job compares them with the last 8 weeks (`.github/scripts/package_budget.py`). Its history
  is `budgets/history.jsonl` on the `audit-notes` branch, the branch this framework's cache will use.
  The slowest test files come from the bulk test run instead (`test-times` job in
  `.github/workflows/test-bulk-non-cran.yml`), which already times every file; it also lists the files that took
  longer than their estimate in `R/package_tests/ci/test_runtimes.csv`.

Three of these report with an **issue** instead of a PR (CRAN watcher, CI self-check, Python vulnerabilities):
they find conditions outside the repository, with nothing to commit. They use the algorithm-drift pattern: one
issue per audit, updated in place, closed when clean. They still use the cache, so an unchanged condition does
not re-notify.

**Order after the Rd and TODO audits:** the CRAN watcher (cheap, time-critical), then allowlist hygiene (it
keeps the other gates honest, and it needs the TODO audit), then the rest.

## Part 5: the compiled-code audit

**Frequency: monthly, 4th Saturday 06:07 UTC, and whenever the assembly of a hot function changes** (checked
weekly by hash; the Claude stage runs only for the changed functions).

It asks "is this algorithm compiled well?". The algorithm audit asks "is there a better algorithm?". Findings
that survive go to the PR and to `audits/further_optimizations.md`.

### Why not every function

- A few inner loops (likelihood evaluations, Newton steps, resampling loops) take nearly all the time. An
  inefficiency in a setup function saves nothing.
- Eigen templates inline into very long functions, and a reader can find a plausible "inefficiency" in any of
  them. Without a measurement, the result is a list of unproven micro-changes.
- EDI builds portable (`EDI_PORTABLE=1`, baseline x86-64) by default. "This loop does not use AVX2" is true of
  the assembly and is not a finding: fixing it needs run-time dispatch, which is a design decision, not a
  maintenance fix. The agent is told so.

### Stages

1. **Pick the hot functions (mechanical).** Run the nightly benchmark sections under `perf record` on a
   CI-built EDI with CRAN's flags (`-O2`, portable, `EDI_UNITY=0` so each function keeps its own symbol) and
   keep the functions that make up the top 90% of samples inside `EDI.so`.
2. **Detectors on those functions (mechanical).**

   | Detector | How |
   |---|---|
   | loop not vectorized, and why | GCC `-fopt-info-vec-missed`, Clang `-Rpass-missed=loop-vectorize` |
   | call not inlined in a hot loop | `-fopt-info-inline-missed` |
   | allocation inside a loop | `operator new` / `malloc` call inside a loop body in the disassembly |
   | R API call or interrupt check in an inner loop | `Rf_*` / `R_CheckUserInterrupt` call inside a loop body |
   | Eigen bounds or assert checks left on | `__assert_fail` / Eigen assert symbols reachable from the loop |
   | scalar `exp` / `log` / `pow` in a loop | libm call inside a loop body |
   | indirect call in a loop | `call *` inside a loop body |

3. **Claude stage.** One agent per flagged function (not batched: each needs the source, the disassembly and
   the detector output). It proposes a **source change** and says which detector finding it removes. Model:
   Opus 5.5.
4. **Verify before the PR is ready** (owner, 2026-11-17: GitHub runner time only, no Claude; jobs
   `verify-*` in `audit-compiled-code.yml`, driver `.github/scripts/compiled_code_verify.py`). The agent also
   writes R bench code (`bench_setup()`, `bench_run(d)`) that calls the changed function directly. The finish
   job applies the clean proposals (at most 3) to a **draft** PR. Then:
   - build the run's commit and, in parallel, the commit plus each proposal alone (the default unity,
     portable build, the same for all);
   - on each proposal's build, run the tests related to the changed file (`select_pr_coverage_tests.py`,
     900 s budget);
   - run the bench code on both builds: results must agree under the D2 closed-form tier (integers,
     logicals, strings exact; doubles within `1e-10 * max(1, |base|)`);
   - time it in 20 ABBA blocks of fresh processes on one runner (`compiled_code_bench.R`); the estimate is
     the median block log-ratio, with a seeded bootstrap 95% interval.

   A proposal is kept only if its tests pass, its results agree, and the interval's upper end is at least 2%
   faster. The PR branch is rebuilt with the kept proposals, the result table goes into the PR body and the
   PR is marked ready; with none kept the PR is closed. The next run's harvest records each dropped proposal
   as rejected, so it lands in `decisions.md` and is not proposed again. A function with a proposal still in a
   PR is not re-read. Not done: confirming that the detector finding is gone from the new assembly.

### Cache

- **Unit:** one hot function. **Hash:** its disassembly with addresses and symbol offsets stripped. A source
  change that leaves the assembly alone is skipped. A compiler upgrade changes the hash and re-audits the
  function.
- The manifest also keeps each function's share of the profile, so the PR can report a function that became
  hot.

### PR

One PR with the verified changes, each with its before/after timing table and the detector finding it
removes. Unverified ideas never appear as changes. Detector findings with no kept proposal are listed under
"Needs a human" once, then only when they change.

## Done when

- `audit_common.py` with tests: cache load/save, gate, rotation, closed-PR → decisions, single open PR.
- `audit-rd.yml` has run once in `scope: all`, then twice in `auto`. The second `auto` run re-reads only
  changed files plus the rotation slice, and does not re-raise a finding rejected in the first PR.
- `audit-todo.yml` has run once in `all`. The owner has reviewed its first PR, and its rejected ticks are in
  `todo/decisions.md`.
- Each audit job has a short section in the runbook (`v1_0_5/algorithm_audit_runbook.md` or a new
  `audit_jobs_runbook.md`).

## TODOs

- [x] TODO-1: `audit-notes` orphan branch + `audit_common.py` (manifest, hashing, rotation, `scope` input, *(ticked by the TODO audit 2026-11-19: .github/scripts/audit_run.py:444; .github/workflows/audit.yml:144; .github/scripts/audit_common.py:145; .github/scripts/audit_common.py:72; .github/scripts/audit_common.py:110; .github/scripts/audit_common.py:210; .github/workflows/audit.yml:43; .github/scripts/audit_common.py:147; .github/workfl...)*
  fail-open) + tests.
- [ ] TODO-2: PR handling in `audit_common.py`: single open PR per audit, rebase onto `main`, closed-PR
  harvesting into `findings.jsonl` / `decisions.md` + tests.
- [x] TODO-3: Rd mechanical stage (checkRd, xrefs, codoc, examples with time limits and CRAN timing, *(ticked by the TODO audit 2026-11-19: .github/scripts/audits/rd_check.R:35; .github/scripts/audits/rd_check.R:137; .github/scripts/audits/rd_check.R:186; .github/scripts/audits/rd.py:136; .github/scripts/audits/rd_check.R:51; .github/scripts/audits/rd_check.R:215; R/EDI/inst/WORDLIST:1)*
  spelling + seeded `inst/WORDLIST`).
- [x] TODO-4: Rd Claude stage: prompt, schema, batching, roxygen-source mapping, apply rules, one roxygen run. *(ticked by the TODO audit 2026-11-19: .github/prompts/audit_rd.md; .github/prompts/audit_rd.schema.json; .github/scripts/audits/rd.py:42; .github/scripts/audits/_doc_audit_shared.py:135; .github/scripts/audits/rd.py:616; .github/scripts/audits/rd.py:740; .github/scripts/audits/_doc_audit_shared.py:358)*
- [ ] TODO-5: `audit-rd.yml`, first `all` run, owner review.
- [x] TODO-6: TODO-status audit: unit parser for release and plan files (checkbox, id, moved pointers, *(ticked by the TODO audit 2026-11-19: .github/scripts/audits/todo_status.py:78; .github/scripts/audits/todo_status.py:60; .github/scripts/test_audit_todo_status.py:166; .github/scripts/audits/todo_status.py:273; .github/scripts/audits/todo_status.py:304; .github/prompts/audit_todo_status.md:34; .github/prompts/audit_todo_status.schem...)*
  owner-closed markers), dependency rules (commit citations, named files), prompt and schema with
  per-part evidence, tick/untick apply rules.
- [ ] TODO-7: `audit-todo.yml`, first `all` run, owner review.
- [ ] TODO-8: runbook section for both jobs.
- [x] TODO-9: issue-reporting mode in `audit_common.py` (one issue per audit, updated in place, closed when *(ticked by the TODO audit 2026-11-19: .github/scripts/audit_common.py:34; .github/scripts/audit_common.py:507; .github/scripts/audit_run.py:355; .github/scripts/audits/cran_watcher.py:1; .github/workflows/audit-cran-watcher.yml; .github/scripts/test_audit_cran_watcher.py)*
  clean) + the CRAN check-results watcher.
- [x] TODO-10: allowlist and baseline hygiene (after TODO-7: it reads the TODO audit's verdicts). *(ticked by the TODO audit 2026-11-19: .github/scripts/audits/allowlist_hygiene.py:24; .github/scripts/audits/allowlist_hygiene.py:76; .github/scripts/audits/allowlist_hygiene.py:210; .github/workflows/audit-allowlist-hygiene.yml:16; test_audit_allowlist_hygiene.py)*
- [x] TODO-11: generated-file drift; NEWS and version consistency. *(ticked by the TODO audit 2026-11-19: .github/scripts/audits/generated_drift.py:1; .github/workflows/audit-generated-drift.yml:16; test_audit_generated_drift.py; .github/scripts/audits/news_version.py:1; .github/workflows/audit-news-version.yml:15; test_audit_news_version.py)*
- [x] TODO-12: CI self-check; Python dependency vulnerabilities. *(ticked by the TODO audit 2026-11-19: .github/scripts/audits/ci_self_check.py:1; .github/workflows/audit-ci-self-check.yml:14; test_audit_ci_self_check.py; .github/scripts/audits/python_vulns.py:1; .github/workflows/audit-python-vulns.yml:13; test_audit_python_vulns.py)*
- [x] TODO-13: dead code; reference check. *(ticked by the TODO audit 2026-11-19: .github/scripts/audits/dead_code.py:1; .github/workflows/audit-dead-code.yml:19; test_audit_dead_code.py; .github/scripts/audits/reference_check.py:1; .github/workflows/audit-reference-check.yml:18; test_audit_reference_check.py)*
- [ ] TODO-14: compiled-code audit, stages 1-2 (hot-function profile, detectors, assembly-hash cache). Run
  it once and review the detector output before building stages 3-4.
- [x] TODO-15: compiled-code audit, stages 3-4 (Claude proposals, benchmark and results verification, PR).
  Stage 4 done 2026-11-17 as above; it has not run on GitHub yet.
- [x] TODO-16: the remaining Part 4 audits: privacy check, README / vignette drift, test-suite health, docs *(ticked by the TODO audit 2026-11-19: .github/scripts/audits/privacy.py:1; .github/workflows/audit-privacy.yml:16; test_audit_privacy.py; .github/scripts/audits/readme_drift.py:1; .github/workflows/audit-readme-drift.yml:18; test_audit_readme_drift.py; .github/scripts/audits/test_suite_health.py:1; .github/workflows/audit-test-suite-...)*
  claims vs behaviour, R ↔ Python parity, dependency and license drift.
- [ ] TODO-17: results freshness (manifest per results file; needs the class → files rules shared with
  `benchmark_gate.py`, so factor them into a module both import).
- [x] TODO-18: numerical-robustness review and thread and random-number review (both keep a finding only when *(ticked by the TODO audit 2026-11-19: .github/scripts/audits/numerical_robustness.py:30; .github/workflows/audit-numerical-robustness.yml; test_audit_numerical_robustness.py; .github/scripts/audits/thread_rng.py:31; .github/workflows/audit-thread-rng.yml; test_audit_thread_rng.py; .github/scripts/audits/numerical_robustness.py:19; .g...)*
  the agent's test fails on the PR branch).
- [x] TODO-19: source comment rot. *(ticked by the TODO audit 2026-11-19: .github/scripts/audits/source_comment_rot.py:26; .github/prompts/audit_source_comment_rot.md; .github/workflows/audit-source-comment-rot.yml; test_audit_source_comment_rot.py)*
- [ ] TODO-20: code duplication (built 2026-11-18, not yet run on GitHub): owner review of the first issue and the
  first PR comment, then decide on `FAIL_ON_DIVERGENCE`.
- [ ] TODO-21: untested code (built 2026-11-18, not yet run on GitHub): owner review of the first PR (are the
  kept tests real reference tests, not self-referential?), first allowlist rows (the mirai and daemon paths CI
  never runs are the first candidates), then decide on the per-run cap (12) and the model (Opus). Later, not now
  (owner): a mutation-testing pass that changes each line a kept test covers and checks the test fails.
