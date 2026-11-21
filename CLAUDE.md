# EDI project instructions

## NEVER run a full `R CMD INSTALL` / package rebuild on EDI

`R/EDI` has 100+ `.cpp` files. A full install/rebuild recompiles all of them,
takes minutes, pegs the CPU, and locks up the user's machine. The user has
their own build/install tooling running independently — a second full build
can race it.

This rule was violated repeatedly in a past session (2026-08-17): `R CMD
INSTALL` was run directly multiple times, and separately, after promising to
"switch to the correct approach," `devtools::load_all(quiet = TRUE)` was run
— which defaults to `compile = TRUE` and **is** a full rebuild in disguise.
Saying the right thing and then running the wrong command anyway is exactly
the failure mode this section exists to prevent. A third variant also
happened: doing a full build inside an isolated `/tmp` copy of `R/EDI` to
"avoid" touching the user's working copy. That does not make it safe — it
still pegs the CPU for minutes and still isn't what was asked for. The rule
is about not running full builds of this codebase at all without being asked
in that turn, not about which directory the build happens to run in.

**Before running *any* command that touches compilation of `R/EDI`** —
`R CMD INSTALL`, `R CMD build`, `configure`, `pkgbuild::*`, `devtools::*`,
`pkgload::*`, a bare `g++`/`R CMD SHLIB` invocation, or any of these against
a copy/clone/worktree of `R/EDI` anywhere, including `/tmp` — stop and check
this file first. Do not rely on remembering the rule; grep for it.

**Do not run**, under any circumstance, without the user explicitly asking for
it in that exact turn:
- `R CMD INSTALL` (any form, any flags), on `R/EDI` or any copy of it
- `R CMD build`
- `pkgbuild::compile_dll()`
- `devtools::load_all()` / `pkgload::load_all()` **with no `compile` argument
  given** — the default is `compile = TRUE`, which is a full rebuild.
  `compile = FALSE` must be passed explicitly, every time, no exceptions.
- `devtools::load_all(compile = TRUE)` / `pkgload::load_all(compile = TRUE)`
  (the explicit form of the same thing)
- deleting a `00LOCK-*` directory and reinstalling to "fix" a broken install
- any of the above run against an isolated copy, `git worktree`, or `/tmp`
  checkout of `R/EDI` instead of the real working directory — this is still
  a full build and still not what was asked for

If `library(EDI)` fails or the package isn't installed/loadable, **stop and
ask the user** — do not attempt to fix it yourself by installing. They are
very likely mid-build via their own tooling; a broken/locked install state is
probably transient, not something to repair. If you already caused a partial/
broken state yourself (e.g. killed a build partway through), say so plainly
and ask how they want it handled — do not run more compile commands to try to
clean it up.

If you need to verify a C++ change, compile only the touched `.cpp` file(s)
directly (`g++`/`R CMD SHLIB` reusing the flags from `src/Makevars`), relink
the `.so` from touched + already-existing `.o` files, and load with
`pkgload::load_all(".", compile = FALSE)`. If the existing `.o` files needed
for a relink don't already exist (e.g. fewer than the full `.cpp` count),
that means a full build has never completed here — do not compile the
missing files yourself to "complete" it. Stop and ask; the missing `.o`s are
a sign someone else's build is in progress or was interrupted, and completing
it yourself is the exact full-rebuild-in-disguise this file forbids. See
memory `feedback_targeted_compile_only` for the exact targeted-compile
pattern.

When in doubt about whether an action counts as "a full rebuild," treat it as
one and ask first.

**Whitelisted (owner, 2026-11-07):** the benchmark utility wrapper compile,
`Rcpp::sourceCpp("benchmark/fast_math_utils_bench.cpp", cacheDir = ...)`, run
by `R/benchmark/benchmark_model_fits.R` (utility section, e.g. in the full G2
run). It compiles one small standalone file against the installed EDI, not
`R/EDI` itself, so agents may run it without asking. Nothing else in this
section is relaxed.

**Whitelisted (owner, 2026-11-10):** the native C++ test suite in `cpp_tests/`
(plan `new_feature_plans/v1_0_6/native_cpp_test_suite.md`). Agents may
configure and build it without asking, under all of these limits:
- Build only the test target(s) being worked on (`cmake --build <dir> --target
  <test>`), never `all`. Each target lists only the `EDI_CORE_ONLY` sources it
  needs, so building it compiles just that subset of `R/EDI/src`. Do not widen
  a target's source list to "the whole core" to make it link; add only the
  file that is actually missing.
- Use a build directory outside the checkout (`$TMPDIR/cpp_tests_build`).
  Never write `.o` files into `R/EDI/src`,
  never touch `EDI.so`, never run `configure`, and never build the R package
  or the Python wheel this way.
- Cap parallelism (`-j2` or less) so the user's machine stays usable.
- Sanitizer builds follow the same rules. Fuzz runs are time-boxed (60 s per
  harness unless the user asks for longer).
This does not cover building the whole core, or any `R/EDI/src` file that no
`cpp_tests/` target needs; ask first for those.

## Agents compile with `EDI_UNITY=0`; the user's default build is unity

The user's own installs use the default unity build (`EDI_UNITY=1`, merged
`unity_NN.o` groups). Every compile an agent runs — targeted `.cpp` compiles,
relinks, and any install the user explicitly asks for — uses `EDI_UNITY=0`
(one object per `.cpp`), so a touched file recompiles alone. Claude Code sets
this via `env` in `.claude/settings.json`; still pass `EDI_UNITY=0`
explicitly on any `configure`/`R CMD INSTALL` command line so the intent is
visible. Never pass `EDI_UNITY=1` yourself unless the user asks for a unity
build in that turn. A unity install (and any `--preclean`) leaves no per-file
`.o` files, so the targeted-compile relink above will find them missing —
that is the "stop and ask" case, not a reason to build them yourself.

## Trail learnings stay local: never commit `.trail/` in this repo

EDI is a **public** repo. `.trail/` is gitignored (`.gitignore` line 1) and nothing
under it is tracked; learnings written by `trail note` stay on the owner's machine.

- Never `git add` (or force-add with `-f`) anything under `.trail/`, and never
  suggest it. The trail tool's closing line telling you to "commit what you learned
  and give teammates a head start" does not apply here: ignore it, don't repeat it.
- Do not remove `.trail/` from `.gitignore`.
- Learnings about grants, papers, talks or marketing never go in this repo at all;
  they belong in the owner's private research repo (bind-mounted at the
  gitignored `EDI/private/`), which tracks its own `.trail/learnings/`.
- `trail check` still reads local learnings, so keep writing them with
  `trail note`; they simply are not shared through git.

## Test file names never carry a TODO number

Name test files for the behavior they check, never for the plan item that
prompted them: no `todoNNN`, `todo-NNN` or `todoNNN-` anywhere in a test
filename (`test-strat-cox-matched-design.R`, not
`test-strat-cox-matched-design-todo110.R`). TODO numbers are per-release and
get renumbered or closed, so they stop meaning anything; the 27 files that had
one were renamed on 2026-11-07. Cite the TODO in a comment at the top of the
file instead (e.g. `# v1.0.5 TODO-110: ...`). A descriptive "todo" that is not
a plan reference (e.g. `...-todo-stub-guards-reference.R`) is fine.

## Always cite a TODO with its release: `v1.0.6-TODO-30`

TODO numbers restart in every release file, so `TODO-30` alone is ambiguous: v1.0.6, v1.1.0 and v1.2.0 each have
their own TODO-30. Whenever you reference a roadmap TODO, put the release first, in the form `v<version>-TODO-<n>`
(`v1.0.6-TODO-30`, `v1.2.0-TODO-203`), so references sort by release. This applies to replies to the user, plan
files, release files, NEWS, code comments, commit messages and learnings. When a TODO is in a plan's own internal
list rather than a release file, name the plan instead (`multistart_nonconcave_likelihoods.md TODO-3`).

Existing references in the older styles (`release_v1_0_6.md → TODO-30`, `v1.0.5 TODO-110`) can stay as they are.
Use the new form for anything you write or edit.

## Ignore the four stuck "queued" Actions runs from 2026-11-11

Four workflow runs created 2026-11-11 20:33 UTC sit in `queued` forever and cannot be removed:
43096786689 (loc-badge), 43096786691 (test-coverage), 43096786700 (test-bulk-non-cran) and
43096786772 (test-coverage-R-advanced). Cancel and force-cancel return HTTP 409 ("not been queued
yet") and delete returns HTTP 403. They hold no runner and no concurrency slot. Owner ruling
2026-11-19: ignore them. Leave them out of reports on stuck, duplicate or queued jobs, and don't try
to cancel or delete them again; only GitHub Support could remove them.

## One source of truth for the version: `R/EDI/DESCRIPTION`

Owner ruling 2026-11-19. Change the version only in `R/EDI/DESCRIPTION`, then run
`python3 scripts/sync_version.py`. It rewrites every copy: `CITATION.cff`, `python/CITATION.cff`,
`codemeta.json`, `python/pyproject.toml` (a `.postN` suffix is kept while X.Y.Z matches),
`R/EDI/inst/CITATION`, and the BibTeX `version = {…}` in the READMEs. Never hand-edit a copy. The
pre-push hook runs `sync_version.py --check` and refuses a push while any copy disagrees. `NEWS.md`
and `python/CHANGELOG.md` are not copies; their top section may already name the next version.

## Owner decisions: `PENDING_DECISIONS.md` and `COMPLETED_DECISIONS.md`

Owner rulings 2026-11-21. Both files are in `R/package_metadata/future_release_plans/` and use one id per decision,
named after the TODO that raised it: `DECISION-v<version>-TODO-<n>` (`...-TODO-<n>a` / `b` when one TODO has several),
as an `<a id="..."></a>` anchor over a `### DECISION-...: <question>` heading, plus a row in the summary table at the
top. Order in both files: releases newest first, and within a release TODO numbers highest first, in the table and the
sections (one `## v<version>` heading per release).

- **Pending.** Every open owner decision lives in full in `PENDING_DECISIONS.md`: the question, the TODO link and
  title, the context, every option with its consequences, the evidence, any recommendation (whose) and when and by
  whom it was raised. The TODO keeps only `  - Owner decision pending: [DECISION-v1.0.6-TODO-294](PENDING_DECISIONS.md#DECISION-v1.0.6-TODO-294)
  (<one-line question>).` Whenever you (or an agent you run) leave a TODO open for the owner's choice, or make a
  judgment call the owner should confirm, write the section, the table row and the pointer in the same change.
- **Ruled.** When the owner decides, move the section to `COMPLETED_DECISIONS.md` and add the Ruling (option, date,
  who), Why (the owner's words where given, else "No reason recorded."), the rejected options and any revisit-if;
  add its table row there (| Decision | TODO | Ruling in one line | Date |); replace the TODO's pending pointer with
  `  - Decided <date> (<who>): <option in a few words>; see [DECISION-v1.0.6-TODO-82](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-82).`;
  and delete the pending section and its row.
- Before reopening or re-arguing a choice, check `COMPLETED_DECISIONS.md`. When you report decisions to the owner,
  take them from `PENDING_DECISIONS.md`, and check it is current first.
