# Copilot instructions for EDI

This file exists so GitHub Copilot (chat, coding agent, code review) picks up
the repo's conventions. **The canonical agent guide is [`AGENTS.md`](../AGENTS.md)**
— read it first; this file only adds the two things that bite fastest.

## The one hard rule: never compile `R/EDI` without being asked

`R/EDI/src/` has 100+ C++ files. `R CMD INSTALL`, `R CMD build`,
`pkgbuild::compile_dll()`, and `devtools::load_all()` / `pkgload::load_all()`
**without an explicit `compile = FALSE`** all trigger a full rebuild that
takes minutes and can race the maintainer's own build. Do not run any of them
unless the user asks for it in the current conversation. Load code with
`pkgload::load_all("R/EDI", compile = FALSE)`; compile a touched `.cpp` on
its own and relink. Full details: `AGENTS.md` and `CONTRIBUTING.md` §1. If
you're unsure whether a command compiles, treat it as if it does and ask.

## Workflow

- Contributor procedure (tests to run before starting and before pushing,
  the PR checklist, change-type protocols for new classes / kernels /
  seeded code): [`CONTRIBUTING.md`](../CONTRIBUTING.md).
- Repo map, entry points, and the plan-file convention
  (`R/package_metadata/new_feature_plans/`): `AGENTS.md`.
- Run one test file, not the suite, while iterating:
  `Rscript -e 'testthat::test_file("R/EDI/tests/testthat/test-<name>.R")'`.
- Docs: https://kapelner.github.io/EDI/ — `llms.txt` / `llms-full.txt` at
  the site root are agent-oriented summaries of the whole reference.
