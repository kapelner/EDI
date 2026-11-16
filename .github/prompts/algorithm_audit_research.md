# Algorithm research task (monthly): one problem, every method EDI uses for it

You are one of the research agents run monthly by `.github/workflows/algorithm-audit-drift.yml`.
Your task message names one **problem** (a `problem_id` from
`R/package_metadata/audits/algorithm_taxonomy.json`). Your question:

> **What is the fastest acceptable way to solve this problem at the sizes EDI runs at, and is
> any method EDI uses for it slower than the best known acceptable alternative?**

How to research (the search plan, sources, acceptability rules, citation rules) is in your
research-agent instructions (`.github/prompts/research_agent_CLAUDE.md`, appended to your
system prompt). Follow them exactly; the run transcript is audited against what you report.

## Your inputs (working directory)

1. `task_problem.json`: your problem (`title`, `description`, `search_terms`) and every method
   EDI uses for it, each with its `synonyms`, `broader`, `narrower` and `software` terms.
2. `row_entries.csv`: every row of `R/package_metadata/audits/algorithm_inventory.csv` (the
   single source of truth for which algorithms EDI implements and where) with your
   `problem_id`: files, symbols, details, complexity, audit row, current verdicts.
3. `previous_results.json`: the last research result for this problem (per-method conclusions,
   findings, sources, `last_researched`), with `code_commits_since` (commits that touched its
   files since then), or `{"no_previous": true}`.
4. In the repo: the audit sections of the rows your entries belong to
   (`R/package_metadata/new_feature_plans/v1_0_5/algorithm_choice_audit.md`; titles and
   `reviewed` dates in `R/package_metadata/audits/algorithm_audit_row_map.json`), the
   "Options & disadvantages" tables in
   `R/package_metadata/new_feature_plans/v1_0_5/algorithm_choice_audit_catalog.md` (options
   already considered and why they were rejected), and the code at each entry's file/symbol.

## Your output (the structured JSON the run asks for)

- `problem_id`: yours.
- `methods_reviewed` / `not_reviewed`: every `method_id` in `task_problem.json` appears in
  exactly one of the two. `not_reviewed` only if you genuinely ran out of turns, with the reason.
- `findings`: candidates faster than what EDI uses, each naming the `methods` it would replace or
  improve. Every method with a finding is marked `faster_option_found`, and every
  `faster_option_found` method appears in some finding's `methods`.
- `searches`: every search and source check you ran, in order, with its `term_classes` and
  `method_ids` (see the search plan in your instructions). This is checked for coverage and
  against the run transcript.
- `proposed_terms`: search terms missing from the taxonomy that turned out to matter (a synonym
  a paper used, a rival package you found). They are added to the taxonomy in the research PR.
