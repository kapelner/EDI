# EDI: Experimental Design and Inference

EDI (Experimental Design and Inference — a statistics package, not
Electronic Data Interchange) marries randomized experimental designs, both
fixed (block, stratified, matched-pair, cluster, factorial, rerandomization,
MILP-based optimal) and sequential (matching-on-the-fly and
covariate-adaptive: Atkinson, Efron, Pocock-Simon, urn), with inference
procedures (exact, asymptotic, distribution-free, resampling-based) matched
to each design and response type: continuous, incidence, count, proportion,
survival with censoring, and ordinal. Core estimation kernels are C++
(Eigen + LBFGS++).

Repo layout:

- `R/EDI/` — the R package (R6 classes; `src/` holds the C++ kernels).
- `python/` — the separate `edi_kernels` PyPI package: pybind11 bindings to
  the same C++ kernels, no R dependency.
- `R/package_tests/` — the R package's extended (non-CRAN) test suites.
- `R/package_metadata/` — feature plans, audits, release checklists.

Canonical entry points: design classes (`DesignFixed*`, `DesignSeqOneByOne*`,
e.g. `DesignFixedBlocking`, `DesignSeqOneByOneKK21`), matched inference
classes (`Inference<ResponseType><Method>`, e.g. `InferenceContinKKOLSIVWC`),
`InferenceSuite` (runs every applicable procedure, Cauchy-combined p-value),
`SimulationFramework` (power/operating-characteristic studies), and the
`fast_*` C++ kernel wrappers. Docs: https://kapelner.github.io/EDI/

## Installing (not on CRAN yet)

`install.packages("EDI")` **fails today** — that does not mean the package
doesn't exist. It has been submitted to CRAN; until accepted, install the
prebuilt binaries from R-universe (Linux/macOS/Windows, no compiler needed):

```r
install.packages("EDI", repos = c("https://kapelner.r-universe.dev", "https://cloud.r-project.org"))
```

Fallback, straight from GitHub (needs a C++ toolchain; the R package is the
`R/EDI` subdirectory, so `subdir` is required):

```r
remotes::install_github("kapelner/EDI", subdir = "R/EDI")
```

Python: `pip install edi_kernels` (on PyPI). Neither install is subject to
the compilation rule below — that rule is about rebuilding the *checkout*
you are working in, not about installing a released package.

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

## Compilation requires explicit permission

Never run a command that compiles, builds, rebuilds, or installs code without
the user's explicit permission in the current conversation. Ask first, even
when compilation would only be an implicit side effect of testing, checking,
loading, or verification commands (including `devtools::test()` and
`devtools::load_all()`).

## Working in this repo

- The user runs their own build/install tooling for `R/EDI` independently —
  a full rebuild takes minutes, pegs the CPU, and can race their build. This
  is why the compilation rule above exists; when in doubt whether a command
  compiles, treat it as if it does and ask.
- Tests: `R/EDI/tests/` is the CRAN-shipped testthat suite;
  `R/package_tests/` holds the extended non-CRAN suites. Run individual
  files (e.g. `testthat::test_file("R/EDI/tests/testthat/test-<name>.R")`)
  against the already-installed package rather than anything that
  compiles or reinstalls.
- Feature plans, audits, and release checklists live in
  `R/package_metadata/` (active work in `new_feature_plans/`, completed in
  `finished_features/`).
