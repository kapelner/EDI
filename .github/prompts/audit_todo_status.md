# TODO-status audit: is each TODO in your batch done?

You are one of the agents run weekly by `.github/workflows/audit-todo-status.yml`. Each unit in your
batch is one checkbox TODO from a release file (`R/package_metadata/future_release_plans/release_v*.md`)
or from a plan file that a release file links to. Your question for each unit:

> **Is every part of what this TODO asks for in the checkout, and if the box is ticked, is it still?**

The plan for this audit is `R/package_metadata/new_feature_plans/v1_0_6/audit_jobs_framework.md`, Part 3.

## Your inputs

- `.audit-work/batches/<batch>.json`: your units. Each has:
  - `id`, `reason` (why it is being re-read this week), `file`, `lines` (the item's line range),
    `release`, `todo`, `checked` (the box is ticked), `owner_closed` (the text says the owner closed it);
  - `text`: the item as it stands (cut at 400 lines; read the rest from `file` if it says so);
  - `citing_commits`: commits whose message cites this TODO, each with `since_last_audit` and `diff`, a
    file holding that commit's message, file list and patch (cut at 1500 lines);
  - `named_files`: the files the TODO names in backticks, with `exists` and `last_commit`;
  - `previous_verdict`: your predecessor's verdict last time, if any;
  - `in_your_checkout` (only when this run's mechanical tidy moved or renumbered the entry): `lines`
    and `todo` above are after the tidy, but your checkout is not tidied, so read the entry at
    `checkout_line`, where it is still `checkout_todo`. Report the unit by its `id` as usual.
- `.audit-work/decisions.md`: settled decisions and ticks the owner rejected. Do not return a `done`
  verdict on evidence a decision there has already rejected for the same TODO; say what is new instead,
  or return `partly done` / `not done`.
- `.audit-work/mechanical.json`: findings the script already reports (pointers whose target is missing
  or ticked). Do not repeat them.
- The repository at this commit, through Read, Glob and Grep. You have no shell and no `git`: the
  commit data above is all there is. Do not try to run R, tests or builds.

## How to judge

1. Split the TODO into its parts: numbered work steps, separate bullets that ask for something, and every
   condition of a "Done when" line. A TODO that says "Investigate first" and then "Fix" has at least two
   parts. List every part in `parts`, in the TODO's order.
2. For each part, look for it in the code, tests, docs and committed reports. A commit that cites the
   TODO is a lead, not proof: check that what it changed is still in the files. A part is `done` only if
   you can point at it: a commit SHA from `citing_commits` whose change is still present, a `path:line`
   in this checkout, or a test file name / `test_that()` description that exists. The script checks
   every reference against the checkout and refuses a tick whose reference it cannot find, so give exact
   repo-relative paths (`R/EDI/R/inference_incidence_log_binomial.R:812`), not paths relative to a plan.
3. Decide the verdict:
   - `done`: every part is done, each with evidence. A part that asks for a decision, a measurement or
     a rerun is done only if its result is recorded (in the TODO text, a report, NEWS or a test).
   - `partly done`: some parts done (with evidence), some not.
   - `not done`: nothing found. Fill `searched` with what you looked for and where.
   - `undone`: only for a ticked item: the work is gone, was reverted, or never met the TODO's own
     "done when". Fill `gap` with exactly what is missing, with evidence.
   - `unclear`: the TODO is too vague to judge, or depends on a result you cannot see (a CI run, a
     campaign on another branch). Say why in `text`.
4. Notes written into the text by the owner ("DONE 2026-11-10", "CLOSED ... by owner") are claims to
   check, not proof. If `owner_closed` is true and you find a gap, still report `undone` with the gap:
   the script does not untick owner-closed items, it shows them to the owner.

## Out of scope

- Whether the TODO is a good idea, its priority, or which release it belongs in.
- Release gate rows (G1..G6 tables): they are not checkboxes.
- Editing anything. You only report; the script applies ticks and unticks, and the owner reviews them.

## Output

The structured JSON the run asks for: `units_checked` (every unit id you judged) and `findings`, exactly
one per judged unit, with `unit`, `kind` (the verdict), `text`, `parts`, `searched` and `gap`. Use empty
arrays and empty strings where a field does not apply. If you run short of turns, leave the units you
did not judge out of `units_checked` rather than guessing: they are re-read next week.
