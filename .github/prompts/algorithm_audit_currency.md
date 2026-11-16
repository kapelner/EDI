# Algorithm-inventory currency check (monthly)

You are run monthly (first Thursday) by `.github/workflows/algorithm-audit-drift.yml` (40-day lookback, so consecutive runs overlap). You are **read-only**: you
may read the repo, run `git log`/`git show`/`git diff`, and fetch the web (to verify reference
URLs). You cannot edit files, open issues, or build anything. Never try to compile, install, or
run EDI (an R package with a large C++ core; see `CLAUDE.md`). Your only output is the
structured JSON the run asks for.

`R/package_metadata/audits/algorithm_inventory.csv` is the single source of truth for which
algorithms EDI implements and where (one row per `file` + `symbol`, with `problem`,
`algorithm`, `details`, `complexity`, `audit_row`, `verdict`, `refs`, `watch`). The mechanical
drift check already verifies that every file is inventoried or exempt, that every `symbol` still
appears in its file, and that every reference URL resolves. Your job is the judgement it can't
make. Your proposals are applied to the CSVs in a pull request the owner reviews, so be exact.
Read `currency_context.json` (in the working directory): it has the window in days,
`new_symbols` and `changed_entries`.

## 1. New functions (`new_symbols`)

These are functions added in the window that have no inventory row. Most are plumbing
(argument checks, getters, warnings, printing, tuning harness code). For each one, read it and
decide whether it **implements an algorithm**: an optimizer, a solver, a sampler or draw, a test
statistic or its null distribution, a resampling loop, a search, a numerical approximation, a
variance estimator, a matching or design-allocation step. If it only calls an inventoried
function, it is not new.

For each one that is an algorithm, propose the inventory row: `problem`, `algorithm` (short
canonical name, matching the names already used in the CSV where possible), `details`,
`complexity`, `audit_row` (A–AC; titles in `R/package_metadata/audits/algorithm_audit_row_map.json`),
`problem_id` and `method_id` (existing ids from
`R/package_metadata/audits/algorithm_taxonomy.json`: the computational problem it solves and the
method it uses; research is organised by problem, so pick the problem whose other methods it
competes with; if no problem or method fits, say so in `reason` and leave the row for a human),
and 1–3 `refs`. A reference is a Wikipedia URL
(`https://en.wikipedia.org/wiki/<Title>`) or a DOI URL (`https://doi.org/<doi>`) that **you
fetched this run** and that explains this algorithm. A CRAN page
(`https://cran.r-project.org/...`) is also accepted when the algorithm is best explained by a
package's documentation or vignette; cite it at cran.r-project.org, never at a mirror (other
mirrors, rdrr.io, github.com/cran). Prefer URLs already in
`R/package_metadata/audits/algorithm_references.csv`.

For the rest, a one-line reason is enough. Report every symbol in the list either way.

## 2. Changed entries (`changed_entries`)

The code of these inventoried functions changed in the window. For each one, read the current
code and its CSV row (`details`, `algorithm`, `complexity`), and the commits that changed it
(`git log --since=<window> -p -- <file>`). Report it as stale only if the row no longer
describes what the code does: different algorithm, a changed default, a step-control or
convergence change, a different complexity, or a moved responsibility. Cosmetic changes,
refactors and bug fixes that keep the algorithm are **not** stale. When it is stale, write the
corrected `details` text. Some functions have several inventory rows (one per algorithm
they implement); always give the `algorithm` value of the row you mean, or the correction
cannot be applied automatically. If the change could affect the row's `verdict`, say so in `issue`,
but never rewrite a verdict yourself: verdicts change only through a human re-review.
