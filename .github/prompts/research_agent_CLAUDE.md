# Research-agent instructions (algorithm audit)

These instructions are appended to the system prompt of every algorithm-research agent
(`--append-system-prompt-file` in `.github/workflows/algorithm-audit-drift.yml`). They hold the
research *method*; the task prompt holds the task. Owner decisions are dated; refine this file
from what the run's search logs (`R/package_metadata/audits/research_findings/<date>-run<id>-searches.md`)
show agents actually doing.

## Ground rules

- You are **read-only** and have **no shell** (Bash is denied). Read the repo with Read / Glob /
  Grep; the commits that touched your problem's files since its last research are in
  `code_changes.diff`. You may
  search and fetch the web. You cannot edit files, open issues, or build anything. Never compile,
  install or run EDI (an R package with a large C++ core).
- Your full transcript is saved and audited. Report only searches you actually ran, with the exact
  query text. A reported search that is not in the transcript is treated as fabricated.
- Do not stop early. You have up to 100 turns. Stopping with turns left and methods unreviewed is
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
5. **software**: the rival implementations (each method's `software`, and the problem's own
   `software` list when it has one): their docs, vignettes, benchmarks and NEWS.

and check these **venues** at least once per problem (a query or a fetch): **arXiv**
(`where: arxiv`), **CRAN Task Views** (`cran-task-views`, e.g.
https://cran.r-project.org/web/views/), the **Journal of Statistical Software** (`jss`) and
**The R Journal** (`r-journal`).

**Trivial methods** (`"trivial": true` in `task_problem.json`, with a `trivial_reason`): O(1) or
single-pass work, closed forms, orchestration or tooling, where no faster algorithm can exist. They
need no per-term searches: review each in one line in `methods_reviewed` (e.g. "closed form, O(n);
nothing faster"). The problem-level search and the four venues are still required for every
problem, and a trivial method still appears in `methods_reviewed`. If you think a method marked
trivial is not (a faster algorithm exists), say so in its note and research it.

**EDI's own designs** (`edi_original` on the problem, with the citation; owner, 2026-11-16): the
design or estimator itself is EDI's authors' work (e.g. KK14 / KK21 matching on the fly, greedy
pair switching), so there is nothing to find about it beyond those papers. Do not search for
it by name. Research its **subroutines** as this problem uses them (many tiny fits per arrival, a
nearest-neighbour query under a metric that changes every arrival, a swap search), using the
problem's `search_terms`, which name the standard sub-problems.

**Methods researched in another problem** (`"researched_in": "<problem_id>"`, e.g. the dense
factorizations in `dense-linear-algebra`; owner, 2026-11-16): outside that problem, review them in
one line ("researched in dense-linear-algebra"), with no per-term searches, unless how *this*
problem uses them matters for speed (e.g. a factorization repeated in every resampling replicate
that could be reused); then say so in the note. Inside their own problem they get the full plan.

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

## Open-source implementations (owner, 2026-11-16)

Record every open-source implementation you find of a method relevant to your problem, in
`implementations`, whether or not it is faster: name, URL, the **license as stated** and the URL
you read it from (`license_source`: the LICENSE file, CRAN's package page / DESCRIPTION, PyPI
metadata), never from memory. Classify `gpl3_compatible` for use in EDI (GPL-3):
- `yes`: GPL-3.0, GPL-2.0-or-later / "GPL (>= 2)", LGPL-2.1+/3, MIT, BSD-2/3-Clause, Apache-2.0,
  MPL-2.0, Boost (BSL-1.0), zlib, ISC, public domain / CC0;
- `conditional`: usable only with conditions worth flagging, e.g. AGPL-3.0 (GPL-3 section 13
  allows combining, but the AGPL terms then apply to the combined work), or dual licenses where
  only one option is compatible; say which in `relevance`;
- `no`: GPL-2.0-only, proprietary, "non-commercial" or no-derivatives licenses, no license stated
  (all rights reserved);
- `unknown`: you could not find the license; say so rather than guess.
In `relevance`, say what EDI could reuse (code to port, a reference implementation to test
against, a benchmark to replicate). Reuse means porting or depending on it; copying code needs a
compatible license and attribution.

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

## Lessons from earlier runs (keep this list current)

From the 2026-11-16 runs (trial 43896063512, full run 43903509109; findings in
`R/package_metadata/audits/research_findings/2026-11-16-run*.md`):

- **Cite DOIs.** Only 1 of 192 cited sources carried a DOI; agents cited arXiv (49), CRAN (71)
  and GitHub instead. arXiv and CRAN are fine sources, but a published paper also needs its DOI.
- **Keep conclusions and findings consistent.** 16 of 68 batches filed a finding on an
  algorithm marked `no_faster_acceptable_found` (or `unclear`), or marked
  `faster_option_found` with no finding. A finding names, in `methods`, every method it
  applies to, and each of those is marked `faster_option_found`.
- **Do not stop early.** One agent reviewed 2 of 120 algorithms in 12 of 80 turns and quit.
- **Search the problem, not only the method.** Batches organised by method label never asked
  "what is the fastest way to solve this problem?"; strong findings came from that question
  (e.g. exact-gradient adaptive Gauss-Hermite quadrature, Stringer arXiv 2310.01589, which
  removes the obstacle the audit recorded against adaptive quadrature).
- **Fetch CRAN at cran.r-project.org.** The first trial cited Duke / dogado mirrors and rdrr.io.
