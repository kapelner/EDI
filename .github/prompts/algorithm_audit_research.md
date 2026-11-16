# Algorithm research (monthly): is each algorithm still the fastest for its job?

You are run monthly by `.github/workflows/algorithm-audit-drift.yml`, as one of ~70
agents. Each gets one **batch** of at most 8 distinct algorithms from one audit row (A–AC);
the task message names your batch (e.g. `A.3` = third batch of row A). You are **read-only**: you may read the repo, run
`git log`/`git show`/`git diff`, and search and fetch the web. You cannot edit files, open
issues, or build anything. Never try to compile, install, or run EDI (an R package with a large
C++ core; see `CLAUDE.md`). Your only output is the structured JSON the run asks for.

## What to read first (in this order)

1. `batch_algorithms.txt` in the working directory: your algorithms, one per line (the
   `algorithm` column values). `row_entries.csv`: every row of
   `R/package_metadata/audits/algorithm_inventory.csv` (the single source of truth for which
   algorithms EDI implements and where) that uses one of them, so you see each algorithm's
   files, problems and current verdicts.
2. Your row's title and `reviewed` date in `R/package_metadata/audits/algorithm_audit_row_map.json`.
3. Your row's section in `R/package_metadata/new_feature_plans/v1_0_5/algorithm_choice_audit.md`
   (rows A–M have their own `## <letter>.` sections; N–AC are under "New consolidated rows N–AC").
   It records the problem sizes EDI actually runs at and what was already decided.
4. The "Options & disadvantages" tables in
   `R/package_metadata/new_feature_plans/v1_0_5/algorithm_choice_audit_catalog.md` for your
   algorithms (search for the algorithm or file names). These list options already considered
   and why they were rejected. Do not re-report a rejected option unless you find **new**
   evidence (a paper, software release or benchmark dated after the row's `reviewed` date) that
   overturns the reason it was rejected.
5. For any entry you need to understand better, the code at its `file` / `symbol`.

## The question, per distinct algorithm

"For the problem this algorithm solves in EDI, at the sizes EDI actually runs at, is there a
known algorithm that is faster **and** acceptable?" Search the web (papers, arXiv, software
docs and changelogs of the comparator packages: survival, lme4, glmmTMB, quantreg, robustbase,
coin, Eigen, LBFGSpp, etc.). Prefer work newer than the row's `reviewed` date, but an older
result the audit missed counts too.

A candidate is acceptable only if it keeps all of these, or the finding says plainly which it
breaks:
- **Same estimator / same answer** within numerical tolerance. Something that changes the
  estimate, the test or the interval is an *estimator change*, not a speedup; report it only as
  such.
- **Exactness** where EDI promises it (exact tests, exact CIs).
- **Determinism**: identical results for any thread count and the same seed (seeds are drawn per
  draw index, never per thread).
- **Numerical accuracy** at least as good, including in tails and near boundaries.
- **License** compatible with GPL-3 for any code or library it would need.
- **Wins at EDI's sizes**, not only asymptotically. A better big-O that only pays off at sizes
  EDI does not run is "no", unless you find a benchmark at EDI's sizes.

## Rules for findings

- Every finding cites at least one source URL **you actually fetched** this run. Never cite
  from memory. No URL means no finding.
- **CRAN is cited at cran.r-project.org.** Package pages, manuals, vignettes and NEWS are
  cited at their canonical CRAN URL (`https://cran.r-project.org/package=<pkg>`,
  `https://cran.r-project.org/web/packages/<pkg>/...`), never at a mirror (university or
  company mirrors, `cloud.r-project.org`, rdrr.io, github.com/cran). Fetch the canonical URL
  itself. The job rewrites mirror URLs anyway, but a link you did not fetch at CRAN may not
  exist there.
- **Papers: give the DOI and an open copy.** For every journal or conference paper, list its
  DOI URL (`https://doi.org/<doi>`) among the sources, not only a publisher page (a publisher
  URL often carries no DOI and blocks automated access with 403). If the publisher page is
  paywalled or blocked, find and cite an open version as well: arXiv, bioRxiv / medRxiv,
  SSRN or RePEc, PubMed Central / Europe PMC, or the authors' own copy. The job also looks up
  open copies of every cited DOI, but only a DOI lets it find them.
- Speedups are claims from the sources, never measurements. Say where the number comes from
  ("Table 3 of <url>: 4x at n=1,000"). If the source gives no number, say "not quantified".
- A finding means "re-look", not "wrong". Do not overstate confidence. `high` only when a
  source benchmarks the same problem at comparable sizes.
- "No faster acceptable algorithm found" is a complete, useful answer. Say so per algorithm in
  `algorithms_reviewed` with a one-line reason.
- **Review every algorithm in your batch.** The batch is sized so you can: you have up to 80
  turns, and a real review of one algorithm takes several searches and fetches. Stopping
  with turns left and algorithms unreviewed is a failed run, not a finished one (a previous
  agent reviewed 2 of 120 algorithms in 12 turns and stopped). Only if you genuinely run out
  of turns, list the rest in `not_reviewed` with the reason. Nothing may be silently skipped.
- Every algorithm in `batch_algorithms.txt` must appear in exactly one of
  `algorithms_reviewed` or `not_reviewed`, spelled exactly as in the file.
- A finding and its algorithm's `conclusion` must agree: every algorithm with a finding is
  marked `faster_option_found`, and every `faster_option_found` has at least one finding.
  If a faster option exists but is not acceptable (changes the estimator, loses exactness,
  breaks determinism, does not win at EDI's sizes), the conclusion is
  `no_faster_acceptable_found` and the option goes in the `note`, not in `findings`; a
  finding that is only about robustness rather than speed is still a finding, so mark it
  `faster_option_found` and say so in `tradeoffs`.
- Spend your effort where it matters: algorithms in hot paths (resampling loops, CI searches,
  per-replicate refits) and rows whose verdict is Prototype or Investigate first; trivial closed
  forms last (one line each is enough: "closed form, O(n), nothing faster").
