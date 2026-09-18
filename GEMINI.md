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

<!-- graft:start -->
## Graft — repo context graph

This repo is indexed in `graft/`: small linked markdown nodes that explain each
system and carry exact file:line spans, kept in sync with the code through git.

For ANY task here — understanding how something works, finding where code lives,
or scoping a change — get context from the graph before grepping or opening
source files. Re-ask freely (it's cheap) and reuse literal identifiers you
already have (symbol, error string, file name) as the query. New to this repo?
Run `graft map` first — a token-budgeted orientation (dir clusters, hubs,
hotspots), no LLM, no key.

- Run `graft ask "<your question>" --source` → ranked nodes with the relevant
  code spans inlined (each hit's ≤8-line crux by default; `--full` for whole
  definitions when the crux isn't enough). Match the tool to the task shape:
  for understanding or editing, the top node IS the answer — cite its
  `covers:` file:line spans and edit straight from `--source`. For
  exhaustive tasks ("every occurrence / every caller of this pattern"), ranked
  results are top-N, not complete — run `graft grep "<literal>"` instead
  (exhaustive over indexed files, grouped by enclosing symbol), falling back
  to raw `grep -rn` only for unindexed files.
- `graft skeleton <file>` → every definition's signature + span, ~10× cheaper
  than reading the file; use it to skim an API surface.
- `graft callers <symbol>` gives precomputed, exact edges — who calls this.
  Add `--direction out` for what it calls, or `--depth N` to walk
  transitively for the full blast radius. For structural questions, skip
  ranking and use this directly.
- Or browse: `graft/INDEX.md` lists every node; follow the links.
- Monorepos and folders of multiple repos rank fairly across sub-projects —
  hits carry `[scope/]` labels naming which one they're from. Narrow with
  `graft ask "<task>" --in <scope>/` once you know where you're working.

If a returned span is truncated ("+N more lines"), open the file at that exact
range before finalizing. Only open source files when a node genuinely lacks a
needed detail, and then at the exact file:line the node points to — never
re-read whole files.

After big code changes, refresh the graph with `graft build` (deterministic,
no API key, $0).
<!-- graft:end -->
