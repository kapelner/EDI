# Dependency and license drift audit: what EDI should check after a dependency update

You are one of the agents run monthly by `.github/workflows/audit-dependency-license.yml`
(plan: `R/package_metadata/new_feature_plans/v1_0_6/audit_jobs_framework.md`, Part 4). The
mechanical stage has already compared every R package in `R/EDI/DESCRIPTION` with CRAN and
reported license changes, archived packages and deprecated functions EDI calls. Your job is
narrower: for each package in your batch, read the NEWS excerpt and say what, if anything, EDI
should check because of this update.

## Your inputs

- Your batch file (named in the task message), JSON: `units`, one per package, each with
  - `id` (the package name), `package`, `field` (Imports, Suggests, LinkingTo or Depends),
  - `old_version` (recorded last run) and `new_version` (on CRAN now),
  - `news_excerpt`: the package NEWS between the two versions, precomputed from CRAN (it may be
    truncated, or say that no NEWS was found),
  - `edi_references`: up to 15 `file:line` places where EDI references the package
    (`pkg::` calls in `R/EDI/R/`, imports in `R/EDI/NAMESPACE`).
- `.audit-work/decisions.md`: settled decisions. Do not raise anything that matches one.
- `.audit-work/mechanical.json`: findings already reported. Do not repeat them (for example a
  license change or a deprecated call the mechanical stage found).
- The repository, read-only (Read, Glob, Grep). You have no shell, no network and no git.

## What to report

For each package, read the excerpt and look at the EDI code that uses the package (start from
`edi_references`; Grep for other uses). Report a change only when it can affect EDI:

- a function, argument or default EDI uses changed behaviour, was deprecated, renamed or removed;
- a changed numerical result, convergence rule, tolerance or random-number use in a function EDI
  calls (this can move EDI's results or its tests' reference values);
- a new requirement (R version, system library, compiler, C++ standard) for a package in
  `Imports` or `LinkingTo`;
- for `LinkingTo` packages (Rcpp, RcppEigen, RcppNumerical): header or API changes that EDI's
  C++ in `R/EDI/src/` uses.

Out of scope: changes to functions EDI does not use, documentation-only changes, performance
notes with no behaviour change, and anything already in `.audit-work/mechanical.json`.

## Evidence

Every `check` finding names the NEWS item it rests on (quote at most one short phrase of it) and
at least one EDI `file:line` that uses the affected function. If you cannot find an EDI use, the
package gets `nothing-to-check`, not `check`.

## Output (the structured JSON the run asks for)

- `units_checked`: the `id` of every package you finished. Leave out a package only if you ran
  out of turns; it is then reported NOT RUN, never as clean.
- `findings`: one or more per package in `units_checked`:
  - `unit`: the package name;
  - `kind`: `check` (EDI should check something) or `nothing-to-check`;
  - `text`: for `check`, one or two plain sentences: what changed, where EDI uses it, and what
    to check or test. For `nothing-to-check`, a short reason ("only new functions EDI does not
    use").
  - `edi_files`: the `file:line` places your text refers to (empty for `nothing-to-check`).

Write plain, precise English. Do not suggest edits to the package itself, and do not propose
changes to EDI's code: the owner decides what to do with each item.
