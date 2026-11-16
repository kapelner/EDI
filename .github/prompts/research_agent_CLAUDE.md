# Research-agent instructions (algorithm audit)

These instructions are appended to the system prompt of every algorithm-research agent
(`--append-system-prompt-file` in `.github/workflows/algorithm-audit-drift.yml`). They hold the
research *method*; the task prompt holds the task. Owner decisions are dated; refine this file
from what the run's search logs (`R/package_metadata/audits/research_findings/<date>-run<id>-searches.md`)
show agents actually doing.

## Ground rules

- You are **read-only**. You may read the repo, run `git log` / `git show` / `git diff`, and
  search and fetch the web. You cannot edit files, open issues, or build anything. Never compile,
  install or run EDI (an R package with a large C++ core).
- Your full transcript is saved and audited. Report only searches you actually ran, with the exact
  query text. A reported search that is not in the transcript is treated as fabricated.
- Do not stop early. You have up to 80 turns. Stopping with turns left and methods unreviewed is
  a failed run (a previous agent reviewed 2 of 120 algorithms in 12 turns and stopped).

## The search plan (required; owner, 2026-11-16)

Work published under a synonym, a broader family or a narrower variant is easy to miss. For your
problem and **each** of its methods, cover every term class, using `task_problem.json`:

1. **problem**: search the problem itself by its `search_terms` ("fastest algorithm for X",
   "X large-scale", "X benchmark", "X solver comparison"). This is where alternatives that EDI
   does not use at all turn up.
2. **synonym**: each method under its synonyms (one query may combine several with OR).
3. **broader**: the method's broader family applied to this problem.
4. **narrower**: the variants and sub-techniques (step control, factorization, warm starts...).
5. **software**: the rival implementations: their docs, vignettes, benchmarks and NEWS.

and check these **venues** at least once per problem (a query or a fetch): **arXiv**
(`where: arxiv`), **CRAN Task Views** (`cran-task-views`, e.g.
https://cran.r-project.org/web/views/), the **Journal of Statistical Software** (`jss`) and
**The R Journal** (`r-journal`).

A class whose taxonomy list is empty needs no query. One query may serve several classes or
methods: list them all in `term_classes` / `method_ids`. Record every search and fetch in
`searches`, with a one-line `result` (including "nothing relevant"); the report flags any problem
whose searches skip a term class or venue. When a search shows the taxonomy is missing a useful
term (a synonym a paper used, a rival package), add it to `proposed_terms`.

**Start from the previous result.** If `previous_results.json` has one, do not redo it: read its
conclusions, findings and sources, and aim the search plan at what is **new since
`last_researched`** (papers, preprints, package releases and NEWS after that date) and at the
commits in `code_commits_since`. The plan still covers every term class; the queries are just
date-focused. Set each method's `vs_previous`: `unchanged` (say what you checked), `updated`
(say what changed; re-report a finding that still stands, citing its sources), or `new` (no
previous result).

## What counts as a faster acceptable method

Answer at the **problem** level: compare what EDI does with every way to solve the problem,
not only the variants of EDI's current method. A candidate is acceptable only if it keeps all of
these, or the finding says plainly which it breaks:

- **Same estimator / same answer** within numerical tolerance (otherwise it is an *estimator
  change*, reported as such, not a speedup);
- **exactness** where EDI promises it (exact tests, exact CIs);
- **determinism**: identical results for any thread count and seed (seeds per draw index);
- **numerical accuracy** at least as good, including tails and boundaries;
- a **GPL-3-compatible license** for any code or library it needs;
- a **win at EDI's sizes** (see the audit sections and entry details), not only asymptotically.

Do not re-report an option the catalog's "Options & disadvantages" tables already rejected,
unless new evidence (dated after the row's `reviewed` date) overturns the reason. "No faster
acceptable method found" is a complete, useful answer; give a one-line reason. A finding that is
about robustness rather than speed is still a finding; say so in `tradeoffs`. Spend effort where
it matters: hot paths (resampling loops, CI searches, per-replicate refits) and Prototype /
Investigate verdicts first; trivial closed forms need one line.

## Citing sources

- Every finding cites at least one URL you fetched this run. Never cite from memory.
- **CRAN at cran.r-project.org**: `https://cran.r-project.org/package=<pkg>` or
  `https://cran.r-project.org/web/packages/<pkg>/...`, never a mirror (other mirrors,
  `cloud.r-project.org`, rdrr.io, github.com/cran).
- **Papers: the DOI and an open copy.** List the DOI URL (`https://doi.org/<doi>`), not only a
  publisher page. If the publisher blocks you or is paywalled, also cite an open version
  (arXiv, bioRxiv / medRxiv, SSRN / RePEc, PubMed Central / Europe PMC, the authors' copy).
- Speedups are the sources' claims, never measurements; say where the number comes from, or
  "not quantified". `high` confidence only when a source benchmarks the same problem at
  comparable sizes.
