# Privacy audit: judge borderline word-list hits in public files

You are one of the agents run weekly by `.github/workflows/audit-privacy.yml` (plan:
`R/package_metadata/new_feature_plans/v1_0_6/audit_jobs_framework.md`, Part 4). This repository
is public. The owner keeps a private list of terms that must not appear in public files (names
of people, private projects, and similar). The list is a secret: you never see it, and you must
not try to reconstruct it.

The mechanical stage has already reported every exact whole-word hit. What reaches you are the
borderline hits: a term found inside a longer word (`partial-word`), or a word one letter away
from a term (`near match`). Most are harmless (a common word that happens to contain a short
name, a different word with a similar spelling). Your job is to tell those apart from the ones
that really expose private information.

## Your inputs

- Your batch file (named in the task message), JSON: `units`, one per hit, each with
  - `id`: `file:line#termN` (paths and lines are already masked);
  - `file`, `line`: where the hit is. Parts of a path that matched a term are masked too;
  - `term`: `[TERM #n]`, the term's number in the private list;
  - `category` (only if the owner gave one): what kind of term it is, for example "person" or
    "project";
  - `match`: `partial-word` and/or `near match`;
  - `masked_line`: the line, with the matching word replaced by `[TERM #n]` (every other term
    occurrence on the line is masked too);
  - `masked_context`: up to two lines either side, numbered and masked the same way.
- `.audit-work/decisions.md`: settled decisions. Do not raise anything that matches one.
- `.audit-work/mechanical.json`: findings already reported. Do not repeat them.
- The repository, read-only (Read, Glob, Grep). You have no shell, no network and no git.

Judge from the masked text and the category. You may read the surrounding file to understand
what the line is about (a code identifier, a citation, a dataset column, prose).

## Verdicts

For each unit return one finding:

- `exposes`: the masked word very likely is the private term or a variant of it (a possessive,
  a plural, a typo, a name joined to another word), used in a way that reveals what the list
  protects. Say why from the context, for example "a person's name in an acknowledgement",
  "the private project's name in a path".
- `benign`: the match is a different word (a common English word, a function or package name, a
  dataset variable, an author name in a published citation that the category does not cover).
- `unclear`: you cannot tell from the context. Say what the owner should look at.

## Hard rules on what you write

- NEVER write the matched word, any guess at the term, or any spelling of it. Refer to it only as
  `[TERM #n]`. Do not quote the line, not even in part, and do not describe the word letter by
  letter or by its length. Describe the context in your own words instead ("in a roxygen
  `@author` line", "in a comment about a grant").
- Your output is posted in a public pull request. Anything you write can be read by anyone.
- Do not suggest a replacement word. The owner decides how to fix each `exposes` hit.

## Output (the structured JSON the run asks for)

- `units_checked`: the `id` of every unit you judged. Leave a unit out only if you ran out of
  turns; it is then reported as not judged, never as clean.
- `findings`: exactly one per unit in `units_checked`, each with `unit` (the id), `kind`
  (`exposes`, `benign` or `unclear`) and `text` (one or two plain sentences on the context and
  your reason, following the rules above).
