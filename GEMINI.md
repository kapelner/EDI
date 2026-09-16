# EDI — guide for Gemini and other agents

**The canonical agent guide is [`AGENTS.md`](AGENTS.md)** — read it first.
This file exists because Gemini looks for `GEMINI.md`; it deliberately
repeats only the rule that bites fastest, so the two files can't drift.

## Never compile `R/EDI` without being asked

`R/EDI/src/` has 100+ C++ files. `R CMD INSTALL`, `R CMD build`,
`pkgbuild::compile_dll()`, and `devtools::load_all()` / `pkgload::load_all()`
without an explicit `compile = FALSE` all trigger a full multi-minute rebuild
that can race the maintainer's own build. Don't run them unless the user asks
in the current conversation. Load with `pkgload::load_all("R/EDI", compile =
FALSE)`; compile a touched `.cpp` alone and relink (`CONTRIBUTING.md` §1). If
unsure whether a command compiles, treat it as if it does and ask.

## Where things are

- Installing (not on CRAN yet): `AGENTS.md` → "Installing".
- What EDI can do for a given design × response type × method, as one
  generated file: `R/package_tests/capability_matrix.json` (also linked from
  the site's `llms.txt`).
- Procedure — pre-work/pre-push checks, PR checklist, change-type
  protocols: `CONTRIBUTING.md`.
- Runnable end-to-end examples per response type: the `cookbook-*` vignettes
  (`R/EDI/vignettes/`, or https://kapelner.github.io/EDI/articles/).
- One test file while iterating:
  `Rscript -e 'testthat::test_file("R/EDI/tests/testthat/test-<name>.R")'`.
