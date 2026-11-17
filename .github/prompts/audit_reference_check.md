# Reference check (monthly): does each cited DOI lead to the work the text names?

You are one of the agents run monthly by `.github/workflows/audit-reference-check.yml`. Plan:
`R/package_metadata/new_feature_plans/v1_0_6/audit_jobs_framework.md`, Part 4. You have read-only
tools and no web access: the Crossref record of every DOI is already in your batch.

## Your inputs

- Your batch file (named in the task message): `units`, each one reference entry, with `reason`,
  `file` and `lines` (where the entry is), `entry` (its text), `dois`, and `crossref` (for each DOI:
  the record's `title`, `subtitle`, `authors` (at most 25, with `n_authors`), `container` (journal
  or book), `volume`, `issue`, `page`, `type`, and the years `issued`, `published-print` and
  `published-online`).
  - An id like `R/EDI/REFERENCES.md#[Efron1971]` is a bullet of the package's reference map.
  - An id like `R/EDI/R/<file>.R#<doi>` is one citation inside a roxygen `@references` block; the
    entry text runs from the previous citation to this DOI. Text in `R/EDI/R/RcppExports.R` comes
    from C++ comments: report it the same way (a human fixes it in `R/EDI/src`).
- `.audit-work/decisions.md`: settled decisions and findings the owner rejected. Never raise a
  finding that matches one of them.
- `.audit-work/mechanical.json`: DOIs Crossref does not know. Do not repeat them.

## What to check, per entry

Compare the entry's title, authors and year with the record:

- `wrong-paper`: the DOI belongs to a different work (different title and authors). This is the
  most important finding.
- `title-typo`: the entry's title has a spelling mistake or a dropped or changed word compared with
  the record. Differences only in capitalisation, punctuation, quotes, italics or math markup are
  style, not findings.
- `title`: the title differs more than a typo (a translated or older title, a subtitle missing).
- `authors`: a name misspelled, missing, extra or in the wrong order. "et al." for many authors is
  fine; initials versus given names is style.
- `year`: the entry's year matches none of the record's years. Print and online years often
  differ by one; a year that matches either is correct.
- `venue`: journal, volume, issue or pages contradict the record.

Evidence in `text`: the entry's value and the record's value, side by side, and the `doi` you
compared (always give `doi` when the entry has several).

## Fixes (applied automatically only if they pass these checks)

Only `year` and `title-typo` can be applied. Give `old_text` (copied exactly from the entry, once),
`new_text`, `crossref_field` (`issued`, `published-print` or `published-online` for a year;
`title` for a title) and `crossref_value` (that field, copied exactly from the record). A year fix
must replace one four-digit year that matches none of the record's years with the year in the
field you cite. A title fix's `new_text` must equal the record's title apart from case and
punctuation, and must be close to the old text (a typo, not a different title). Everything else is
listed for a human, so report it anyway.

## Output

Return the structured JSON the run asks for: `units_checked` (every entry id you actually
compared) and `findings`. An entry that matches its record is listed in `units_checked` with no
finding. If you run out of turns, leave the entries you did not compare out of `units_checked`;
they are re-queued, never counted as clean.
