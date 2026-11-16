# Monthly algorithm research: is each algorithm still the fastest for its job?

You are run monthly by `.github/workflows/algorithm-audit-drift.yml`, once per audit row
(A–AC). The task message names your row. You are **read-only**: you may read the repo, run
`git log`/`git show`/`git diff`, and search and fetch the web. You cannot edit files, open
issues, or build anything. Never try to compile, install, or run EDI (an R package with a large
C++ core; see `CLAUDE.md`). Your only output is the structured JSON the run asks for.

## What to read first (in this order)

1. `row_entries.csv` in the working directory: the rows of
   `R/package_metadata/audits/algorithm_inventory.csv` (the single source of truth for which
   algorithms EDI implements and where) whose `audit_row` contains your row letter. Group them
   by the `algorithm` column: you research each **distinct algorithm**, not each row.
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
- Speedups are claims from the sources, never measurements. Say where the number comes from
  ("Table 3 of <url>: 4x at n=1,000"). If the source gives no number, say "not quantified".
- A finding means "re-look", not "wrong". Do not overstate confidence. `high` only when a
  source benchmarks the same problem at comparable sizes.
- "No faster acceptable algorithm found" is a complete, useful answer. Say so per algorithm in
  `algorithms_reviewed` with a one-line reason.
- You will not finish every algorithm in a large row. List every one you did not get to in
  `not_reviewed` with the reason (e.g. "turn budget"). Nothing may be silently skipped.
- Spend your effort where it matters: algorithms in hot paths (resampling loops, CI searches,
  per-replicate refits) and rows whose verdict is Prototype or Investigate first; trivial closed
  forms last (one line each is enough: "closed form, O(n), nothing faster").
