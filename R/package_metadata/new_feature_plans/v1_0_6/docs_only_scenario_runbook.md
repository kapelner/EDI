# Runbook: Docs-Only Scenario Runs, One Per Feature Area

> **Release:** v1.0.6-TODO-98 (`../../future_release_plans/release_v1_0_6.md`). Owner request 2026-11-18.
> **Trigger (decided by the owner 2026-11-18):** every feature area runs as a weekly CI job, skipped for an area
> when nothing relevant to it changed since its last run; see section 7. Sections 1-6 still apply: the job
> follows them (section 4 is pasted into its prompt verbatim), and a run by hand is still possible.
>
> **Related:**
> - v1.0.6-TODO-73..94: the 22 bugs the six v1.0.6 article agents found. They are the model for how findings are
>   written up (section 6).
> - v1.0.6-TODO-95, -96, -97: the mechanical checks (NA audit, message audit, option matrix) that would have caught
>   most of those 22. A scenario run finds what those checks cannot list in advance; it does not replace them.
> - The owner's agent-harness audit (tiers 1-5; gitignored notes, not in the public repo) and its verified
>   tier-1 findings, `release_v1_0_5.md` → "Agent-harness tier-1 findings, verified 2026-10-22" (v1.0.5-TODO-103..119).
>   A scenario run is a harness run aimed at one feature area instead of at a list of 50 short requests.

## 1. What a scenario run is

One fresh agent, with no knowledge of the EDI source, is given one feature area and must finish one realistic task
in it end to end, learning EDI only from the installed help pages and vignettes. Everything it trips over is
logged. A second pass (the coordinator, with source access) verifies each item and files the real ones as
release-prefixed TODOs.

Why it works: in v1.0.6 the agents writing six pkgdown articles were, in effect, six such runs. They found 22 bugs
that the testthat suite, the comprehensive suite, the argument-combination harness and the audit jobs had all
missed. None were wrong numbers on canonical inputs. They were:

- **silent `NA`s** on legal inputs (v1.0.6-TODO-74, -75, -90, -91);
- **documented options that crash** (`n = NULL` for sequential designs, v1.0.6-TODO-76..78; unequal block sizes,
  v1.0.6-TODO-73);
- **messages that say something false**: an argument the function does not take (v1.0.6-TODO-73), advice to use
  the `B` just used (v1.0.6-TODO-92), a fallback that does not exist (v1.0.6-TODO-84), survival wording on a
  continuous response (v1.0.6-TODO-93);
- **docs that say something false**: a "no intercept column" that needs one (v1.0.6-TODO-85), re-seeding
  claims (v1.0.6-TODO-79), a minimum-draw count (v1.0.6-TODO-82), a documented fallback that never runs
  (v1.0.6-TODO-90);
- **inputs accepted that should be refused**: `w` coded 1/2 (v1.0.6-TODO-86), a multi-valued statistic silently
  truncated (v1.0.6-TODO-83), `y = NA` (v1.0.6-TODO-94), a banned `delta` (v1.0.6-TODO-81);
- **an incoherent result**: a hypothesis shifted on two scales at once (v1.0.6-TODO-80);
- **gaps and inconsistencies in an API surface** outside the R6 registry (Python kernels, v1.0.6-TODO-87..89).

## 2. When to run, and which feature areas

Run one agent per feature area that landed or changed: a new design, a new inference family, a change to an
existing family's documented options, the Python kernels (`edi_kernels`), the custom-statistic API
(`InferenceRandCustom`), save/load, `SimulationFramework`, `InferenceSuite`. One area per agent; a run that tries
to cover two areas covers neither.

Run log (append a row per run; the TODO numbers are the ones the run produced):

| Date | Feature area | Task given | EDI build | Findings |
|---|---|---|---|---|
| 2026-11-17 | Cluster and factorial designs | article `cluster-and-factorial-experiments.Rmd` | installed 1.0.4 | v1.0.6-TODO-73, -74 |
| 2026-11-17 | Reporting an analysis | article `reporting-an-analysis.Rmd` | installed 1.0.4 | v1.0.6-TODO-75 |
| 2026-11-17 | Sequential designs, `n = NULL`, save/restore | article `running-a-sequential-trial.Rmd` | installed 1.0.4 | v1.0.6-TODO-76..79 |
| 2026-11-17 | Custom randomization statistic | article `custom-randomization-statistic.Rmd` | installed 1.0.4 | v1.0.6-TODO-80..84 |
| 2026-11-17 | Python kernels | article `edi-from-python.Rmd` | installed 1.0.4 + wheel | v1.0.6-TODO-85..89 |
| 2026-11-17 | Missing data and censoring | articles `missing-covariates.Rmd`, `censored-survival-outcomes.Rmd` | installed 1.0.4 | v1.0.6-TODO-90..94 |

The 2026-11-17 runs were article-writing agents, not strictly docs-only: they could read source. Runs under this
runbook are docs-only (section 4), so later rows are not directly comparable with these six.

## 3. Before launching (coordinator)

1. **The EDI build must carry its docs.** Check the build the agent will use:
   ```r
   p = find.package("EDI", lib.loc = LIB); dir.exists(file.path(p, c("help", "html", "doc")))
   vignette(package = "EDI", lib.loc = LIB)
   ```
   All three must be `TRUE` and the vignette list non-empty. A dev install often has `help/` but no `doc/` (the
   user's installed 1.0.4 on 2026-11-18 had no `doc/`), and the tier-1 harness run lost most of its value to a
   build with no help at all. If the docs are missing, **stop and ask the owner** for a docs build (the harness
   build in `/tmp/edi_harness_build`). That build is a full `R CMD build` + `R CMD INSTALL` of EDI, so under the
   repo's `CLAUDE.md` it needs the owner's go-ahead in that turn; never run it, or any other compile, on your own.
2. **The build must contain the feature.** The installed build must be at or after the commit that landed the
   feature area under test. Record its version and commit in the run log.
3. **Python runs:** the agent needs an `edi_kernels` wheel built from the same commit. Building the wheel is also
   the owner's call; do not run `pip install` on `python/`.
4. **Write the task** (section 5) and pick the data. Simulate data with base R (never with EDI), or use a public
   data set from another package. Put the data and nothing else in the run's folder.
5. **Isolation.** The run's folder is a new empty directory outside the repo (the session scratchpad or
   `$TMPDIR`). For a clean context, launch with `claude -p` in that folder with `--setting-sources project,local`,
   `disableAllHooks: true` and plugins off (the harness's settings), so neither `CLAUDE.md` nor any hook leaks
   repo knowledge. A subagent inside a repo session also works but sees the repo's `CLAUDE.md`; note that in the
   run log.
6. **Limits:** at most 2 cores, no single R call longer than about 5 minutes, a total budget of about 90 minutes.

## 4. Rules for the docs-only agent

Give these to the agent verbatim as part of its prompt (section 5).

**What you may read:**
- R help pages: `?Topic`, `help(package = "EDI")`, `help.search()`, the HTML help index.
- Vignettes: `vignette(package = "EDI")`, `vignette("name", package = "EDI")`, and their rendered output under
  the installed `doc/` directory.
- What EDI prints to you while you use it: printed objects, `summary()`/`get_summary()` output, errors, warnings,
  messages, `names()`/`ls()` of an object, and any documented introspection method (`capabilities()`,
  `InferenceSuite` listings, `get_*` getters).
- For the Python area: `help()` on `edi_kernels` objects, docstrings, the `.pyi` stub's signatures and
  docstrings, the PyPI README.

**What you may not read:**
- Any source code: not the repo, not the installed `R/` directory, not `.cpp` files.
- Function or method bodies: no printing an R6 generator to read its methods, no `body()`, `deparse()`,
  `getAnywhere()`, `edit()`, `EDI:::` internals, `environment(fn)$...`, `inspect.getsource()`.
- The web, other agents' folders, the repo path.

Every time you want to break one of these rules to make progress, do not break it: log a "docs insufficient"
finding saying what you needed and could not find, then work around it or stop that branch.

**How to work:**
1. Pick a realistic analysis in your area and say at the start what a careful applied statistician would want
   from it. Go end to end: build the design, enroll subjects, assign, add responses, run inference, report the
   estimate, CI and p-value. Don't stop at the first thing that works.
2. Use the documented options, not just the defaults. For every argument or setting the help page offers that
   fits your task (e.g. `n = NULL`, unequal block or cluster sizes, censoring types, a missing covariate or
   response, `delta`, `unit`, `type`), try it. Use realistic data shapes: unequal group sizes, a strong effect
   as well as a null one, ties, small `n`.
3. **Follow every message literally.** When an error or warning tells you to do something (set an argument, call
   another method, increase `B`), do exactly that and record whether it worked.
4. **Check every number.** A result that is `NA`, `NaN` or `Inf` on finite inputs, with no warning or error
   explaining it, is a finding, even if another method gives a number. A CI must contain its estimate and fit the
   response's range. A p-value must be in [0, 1]. Where a standard package fits the same model (`lm`, `glm`,
   `survival`, `MASS`, `coin`, `quantreg`, `sandwich`, `statsmodels`, `scipy`, `lifelines`), cross-check to 3
   or more digits and record the comparison.
5. **Check the docs against what happens.** Every claim the help page or vignette makes that you rely on (a
   default, a fallback, a range, an argument's meaning, an input layout, a reproducibility promise), test it
   directly.
6. **Keep a log as you go**, not at the end, in `findings.md` in your folder, one entry per issue (section 6
   format). A minimal repro is mandatory: a copy-pasteable script that uses only the data in your folder or
   data it simulates with base R and a fixed seed.
7. Do not install, update or build anything, and do not try to fix EDI.

**What counts as a finding:**

| Kind | Example |
|---|---|
| silent `NA` | `compute_jackknife_wald_confidence_interval(unit = "cluster")` gives `c(NA, NA)` with no warning |
| documented option fails | `n = NULL` is documented, but the first assignment errors |
| false message | an error tells you to set an argument the constructor does not take |
| useless message | the error is about a different problem than the one you caused, or names internals |
| false docs | the docs say X needs no intercept column; it does |
| insufficient docs | you could not find how to do a step without reading source |
| accepted bad input | `w` coded 1/2 runs and returns `nan` or a flipped sign |
| silent change of your input | a two-valued return truncated to one value without a word |
| reference mismatch | EDI and a standard package disagree beyond rounding on the same model |
| inconsistency | two parts of one API use different conventions for the same thing |

## 5. Prompt template

Fill in the braces. Keep the task concrete; one paragraph.

~~~~text
You are testing the R package EDI from its documentation alone. EDI is installed in {LIB}
(use .libPaths(c("{LIB}", .libPaths())) first). Your working folder is {RUN_DIR}; work only there.

Feature area: {AREA}.
Task: {TASK, e.g. "A school district randomizes 24 schools of different sizes, blocked by district, to a
reading program. Design the assignment, simulate a plausible outcome, analyze it the way you would report it
to a journal, and say whether the analysis respects the clustering."}
Data: {DATA FILES or "simulate it with base R, fixed seed"}.

Rules: {paste section 4 of the runbook verbatim}

Deliverables in {RUN_DIR}:
- analysis.R (or .py): the end-to-end script you ended with;
- findings.md: one entry per finding, in the format below, each with a minimal repro;
- summary.md: what you set out to do, what you finished, what you could not do and why, and every place you had
  to guess.

Finding format:
### F{n}: {one-sentence statement of what is wrong}
- Kind: {from the table}
- Expected (and where the docs say so: help topic or vignette + section):
- Observed (exact output, including the exact message text):
- Repro:
  ```r
  ...
  ```
- Workaround used, if any:
~~~~

## 6. After the run (coordinator)

1. **Verify each finding against the source**, as the v1.0.5 tier-1 findings were. Reproduce it on the same
   build, find the cause in the source, and add `file ~Lnnn` pointers. Classify it: a real bug, a docs-only fix,
   intended behaviour that the docs fail to state (that is still a docs finding), or the agent's mistake (drop it,
   and note it in the run log if the docs invited the mistake).
2. **De-duplicate.** Search the current release file and the next minor's (`release_v1_1_0.md` etc.) for an open
   TODO on the same cause. If one exists, add the new repro to it rather than filing a second TODO.
3. **Place it by the release's entry rule.** A fix that meets the current patch release's entry rule (wrong
   output, crash, NA where a value is defined, ...) goes in the current release file; a new option, API or
   convention change goes in the next minor's.
4. **File it in the house style**, one TODO per cause, following v1.0.6-TODO-73..94:
   ~~~~markdown
   - [ ] TODO-<n> (added <date>, agent, owner request; found by the <area> docs-only scenario agent): **<What is
     wrong, as one sentence a user would recognise.>** <Where: `R/EDI/R/<file>.R` (~L<n>), the function, and the
     cause in one or two sentences.> <What the docs or message claim, and what happens instead.>
     Repro (installed <version>):
     ```r
     <minimal repro, comment on the line that shows the problem, e.g. `# NA, no warning`>
     ```
     Fix: <the fix, or the two options if the owner must choose>; add a test with this repro (<what it asserts>).
     <Any article or vignette that works around it and must be updated once fixed.>
   ~~~~
   Cite related TODOs as `v<version>-TODO-<n>`. Name the agent's run in the "found by" note so the run log row
   can point at it. The coordinator writes to the release file; the scenario agent never does.
5. **Feed the mechanical checks.** If a finding is of a kind that v1.0.6-TODO-95 (NA audit), -96 (message audit)
   or -97 (option-matrix tests) should catch but did not, say so in the TODO, so the gap in that check is fixed
   too.
6. **Add the run-log row** in section 2 (date, area, task, build version and commit, TODO numbers, and "subagent,
   saw repo `CLAUDE.md`" when the run was not a clean `claude -p` run).

## 7. The weekly CI job

`.github/workflows/audit-docs-scenarios.yml` ("audit · weekly · docs-scenarios", Saturday 01:07 UTC, plus
`workflow_dispatch` with `areas` = `changed`, `all` or a comma-separated list of area ids). It is listed on the
audit status board (`audit-status.yml`).

**Files.**
- `.github/prompts/docs_scenario_areas.json`: the feature areas (id, title, task, the paths that make the area
  due, the articles the agent gets) and the defaults (model, turns, dollar cap, minutes, areas per run). Add an
  area there; never rename an id (its state would start over).
- `.github/prompts/docs_scenario.md`: the prompt, section 5 above plus what CI needs. Section 4 of this runbook
  is pasted into it at run time, so the rules have one source: edit them here.
- `.github/scripts/docs_scenarios.py` (`plan`, `render`, `collect`, `report`) and its tests,
  `.github/scripts/test_audit_docs_scenarios.py`.

**Stages.** `prepare` decides which areas are due and writes one context kit per due area. When none is due
the run ends there and EDI is not built. `build-r` builds EDI once per run as section 3.1 asks:
`R CMD build` (vignettes rendered) and `R CMD INSTALL --html` of the tarball, then checks that `help/`,
`html/` and `doc/` exist and the vignette list is not empty. `build-wheel` builds a regular (not editable)
`edi_kernels` wheel, only when the Python area runs. `scenario` runs one agent per area (matrix, at most 4 at
once), and `publish` writes the findings file, opens the PR and saves the state.

**Skip rule.** An area is due when one of its paths changed between its last successful run and `HEAD`,
measured with `scripts/significant_changes.py`: an R, C++ or Python file whose only edits are comments or
whitespace does not count (owner ruling 2026-11-17), while every man page, vignette, article, README and
`.pyi` change counts, because that script counts every non-source file git reports. Docs changes therefore
count with no extra rule, which this job needs since the agent learns EDI only from the docs. A roxygen-only
edit is dropped from the R file but reaches the area through the `man/*.Rd` file it regenerates; a Python
docstring is a string token, so it counts as code. An area with no successful run, or whose last-run commit
is gone from history, is due. A `changed` run takes at most `max_areas_per_run` areas (default 8), never-run
areas first and then those waiting longest; the rest stay due and run the next week.

**Isolation.** The agent runner has no checkout of the repository. It gets the installed EDI library (R code
byte-compiled into a lazy-load database; no `R/` sources, no `src/`), EDI's dependencies installed from
`DESCRIPTION` alone, the reference packages for cross-checks, and a kit with the prompt, the area's
learnings, known findings, changed paths and articles (as `.Rmd` text, since the installed package carries
the CRAN vignettes but not the pkgdown articles). The agent works in an empty folder under `RUNNER_TEMP`,
started with `claude -p` there (`--setting-sources project,local`, no MCP servers), so no `CLAUDE.md` or hook
reaches it. It needs Bash to run R, so Bash is allowed; network, install, `git` and `gh` commands, the web tools
and subagents are denied, as are reads of credential paths and of the workspace. No GitHub token is in its
environment and the job's token is read-only. The Python area installs the wheel into a venv: the installed
package holds the compiled module, the `.pyi` stub and the thin Python layer (`__init__.py`, `_checks.py`),
which the rules forbid reading as source, but not `python/cpp` or `R/EDI/src`. The rules in section 4 remain
the main barrier against reading method bodies (printing an R6 generator would show them), as in a run by hand.
The Claude Code CLI is used, not `anthropics/claude-code-action`, because the action runs in the checked-out
workspace (and refuses some events); the secrets and the NOT RUN convention are the same as in the other
Claude jobs.

**State.** The `audit-notes` branch, folder `docs-scenarios/`, saved with `audit_run.py save-notes` (the
audits' retrying push; each job writes only its own folder):
- `state.json`: per area, the last successful run's commit, time and run id, and the last attempt's outcome.
  An area's commit advances only when its agent finished (`summary.md` written); a run that timed out keeps
  its findings but the area runs again next week.
- `learnings/<area>.md`: each run's `learnings_update.md` (covered, not reached, workarounds, confusing docs)
  appended under a dated heading. The next agent reads it first and is told to go where earlier runs did not.
- `findings.jsonl`: every finding ever reported, with id `ds-<area>-<run id>-f<n>` and a status re-derived each
  run: `filed` when an unticked TODO in a release file cites the id (`closed` when it is ticked), `dismissed`
  when `R/package_metadata/audits/DISMISSED_DECISIONS.md` lists it, otherwise `open`. The agent sees them in
  `known_findings.md` and must not report them again.
- `runs/<date>-run<id>/<area>/`: that run's summary, findings and learnings update.

**Output.** One PR per run with new findings (label `audit-docs-scenarios`, branch
`audit/docs-scenarios/<date>-run<id>`), adding `R/package_metadata/audits/docs_scenario_findings/<date>-run<id>.md`
(date plus run id, so two runs on one day never overwrite each other). Each finding carries its repro; one
without a runnable repro is listed but not registered. The job never writes to a release file: triage the PR
by section 6, cite each finding's id in the TODO you file (that marks it `filed`), or dismiss it in
`DISMISSED_DECISIONS.md` with a reason. Merge the PR to keep the record. Transcripts (secrets redacted) are
artifacts for 30 days.

**Budget.** Per area: Opus 5.5 at its default effort, at most 250 turns, a `--max-budget-usd` cap of $15 and
80 minutes for the agent (job limit 110). Estimate: $5-12 per area, so a full first pass of all 17 areas is about
$100-200, spread over three weeks by the 8-area cap; a typical week with a few changed areas is about $15-50, and
a week with no relevant change costs nothing beyond a 1-minute plan job. Wall time: about 45-60 minutes for
the EDI build (two compiles plus the vignettes), then the agents in waves of 4 (8 areas: about 3 hours).

**CI settings (owner, 2026-11-18):** weekly (Saturday 01:07 UTC), Claude Opus 5.5 at effort `high`, at most $30 and 80
minutes per area, at most 8 areas per run. An area runs when something relevant changed since its last successful run,
and in any case every 42 days, so its learnings keep going deeper. Order within the cap: never run, then changed, then
periodic re-runs.
