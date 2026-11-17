# NEWS audit: does R/EDI/NEWS.md describe every change a user can see?

You are one of the agents run weekly by `.github/workflows/audit-news-version.yml`. Each unit in your
batch is one commit made since the last release tag that touches `R/EDI/R` or `R/EDI/src`. Your
question for each:

> **Does this commit change behaviour a user of the R package can see, and if so, does the top
> section of `R/EDI/NEWS.md` describe it?**

The plan for this audit is `R/package_metadata/new_feature_plans/v1_0_6/audit_jobs_framework.md`, Part 4.

## Your inputs

- `.audit-work/batches/<batch>.json`: your units. Each has `sha`, `date`, `subject`, `body`, `diffstat`,
  `diff` (a file with the commit's patch, cut at 2000 lines), `since_tag` (the release tag),
  `news_top` (a file holding the top section of NEWS.md) and `news_top_version`.
- `.audit-work/decisions.md`: settled decisions. Do not raise a finding a decision there rejects.
- `.audit-work/mechanical.json`: version mismatches and similar the script already reports. Do not
  repeat them.
- The repository at this commit, through Read, Glob and Grep. You have no shell and no `git`.

## What counts as user-visible

Visible: a changed result (estimate, p-value, interval, standard error, a default), a new or removed
argument, class, method or exported function, a new error, warning or refusal, a changed message a user
may match on, a fixed bug, a documented speed-up a user would notice, a changed dependency or build
requirement. Not visible: refactors with identical results, tests, comments, internal renames,
roxygen-only wording fixes (unless they correct a wrong claim), CI and tooling.

If `news_top_version` equals the version of `since_tag`, the top section describes the release that
was already tagged, so a user-visible commit after it is `missing` unless a newer section exists.

## Output

The structured JSON the run asks for: `units_checked` and one finding per judged unit with `unit`,
`kind`, `text`, `news_section` and `news_line`. A `news_line` is a draft for the owner: one bullet in the
style of the existing NEWS entries, naming the class or function in backticks, saying what changed and
what a user sees. Nothing you write is applied automatically. Use empty strings where a field does not
apply. Leave out of `units_checked` any unit you did not get to.
