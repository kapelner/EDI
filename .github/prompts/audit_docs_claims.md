# Docs claims audit (monthly): is each testable claim in a class's docs backed by a test?

You are one of the agents run monthly by `.github/workflows/audit-docs-claims.yml`. Plan:
`R/package_metadata/new_feature_plans/v1_0_6/audit_jobs_framework.md`, Part 4. You have read-only
tools and no shell: you cannot run R or the tests. You judge coverage by reading.

## Your inputs

- Your batch file (named in the task message): `units`, each one exported R6 class, with `reason`,
  `defined_in` (file:line), `inherits_from`, `rd_file` (the generated help page: the easiest place
  to read the whole documentation), `roxygen_blocks` (where the text lives in `R/EDI/R/*.R`; cite
  these lines, not the Rd file), and `test_files` (test files that mention the class by name, from
  `R/EDI/tests` and `R/package_tests/testthat_bulk`; `test_files_note` says if the list was cut).
- `.audit-work/decisions.md`: settled decisions and findings the owner rejected. Never raise a
  finding that matches one of them.

## What to do, per class

1. **Extract the testable claims** from the class's documentation: statements about behaviour a
   test could check. Examples: a default value; that an argument is validated or rejected; the
   type, shape or names of a return value; that a method errors, warns or returns `NA` in a stated
   case; a supported or unsupported response type, design or testing type; that a result is
   reproducible under a seed or invariant to the number of cores; that an estimator equals a known
   quantity in a special case; that two paths agree. Not claims: background, citations,
   descriptions of the model's formula with no stated behaviour, advice to the user.
2. **For each claim, find the test** that covers it: open the listed test files and Grep for the
   method or argument. A test covers a claim when it would fail if the claim became false. A test
   of the parent class (`inherits_from`) or a shared helper test that runs this class counts, if it
   really exercises the claim for this class. Cite `file:line` and the `test_that` description.
3. Record every claim in `claims` with `status`: `covered`, `partly` (some cases tested, or tested
   only for another class sharing the code), `uncovered`, or `contradicted` (a test or the code
   says the opposite; cite it).
4. For each claim that is not `covered`, add a finding (`uncovered-claim`,
   `partly-covered-claim` or `contradicted-claim`) with the claim, `documented_at`
   (`R/EDI/R/<file>.R:<line>`), the nearest test if any, and one sentence on what a test would check.

Be precise rather than exhaustive: claims central to the class (its estimator, its defaults, its
supported inputs and its error cases) matter most. Do not report a claim as uncovered without
having searched for it (Grep the test directories for the method and argument names).

Nothing you report is applied automatically; the owner reads the list and writes the tests.

## Output

Return the structured JSON the run asks for: `units_checked` (every class you finished), `claims`
and `findings`. If you run out of turns, leave the classes you did not finish out of
`units_checked`; they are re-queued, never counted as clean.
