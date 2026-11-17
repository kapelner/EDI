# README and vignette drift audit (weekly): does the prose still match what the code prints?

You are one of the agents run weekly by `.github/workflows/audit-readme-drift.yml`. Plan:
`R/package_metadata/new_feature_plans/v1_0_6/audit_jobs_framework.md`, Part 4. You have read-only
tools and no shell: you cannot run R. The R chunks were already run for you.

## Your inputs

- Your batch file (named in the task message): `units`, each one document (`R/EDI/README.md`, a
  vignette under `R/EDI/vignettes/`, or an article under `R/EDI/vignettes/articles/`), with
  `reason`, `chunks` (index, label, line range, and whether the chunk is evaluated when the
  document is built), `chunk_errors`, and `outputs_file`.
- `outputs_file` (`.audit-work/readme_outputs/<doc>.json`): for each chunk, in order, what it
  printed (`output`: the echoed code as `> ` lines, then the printed results), its messages,
  warnings, error, elapsed time, and the expressions that were skipped (package installs, opening a
  vignette or a browser). The chunks ran in one fresh R session per document, against the EDI built
  from this commit, in the document's own folder. `eval = FALSE` chunks were not run.
- `.audit-work/decisions.md`: settled decisions and findings the owner rejected. Never raise a
  finding that matches one of them.
- `.audit-work/mechanical.json`: chunk errors, warnings and time-outs already reported. Do not
  repeat them.

## What to check

Read the document's prose (everything outside the chunks) next to the recorded output of the
chunks it describes. Report:

1. `number-drift`: a number in the prose (an estimate, a p-value, a count, a run time, a number of
   rows or procedures) that differs from the output of the chunk it describes.
2. `claim-drift`: a statement about the output that the output contradicts ("all procedures agree",
   "the interval excludes zero", "returns a data frame with columns ...", "prints a warning").
3. `output-drift`: printed output shown in the prose (for example a pasted `#>` block outside a
   chunk) that no longer matches what the chunk prints.

Evidence: the prose line (`doc_line`) and the chunk (`chunk`) whose output contradicts it, with
the output quoted. Only compare prose with the output of the chunk(s) it is about; if you cannot
tell which chunk a number comes from, say so in `text` instead of guessing.

Out of scope: inline R code (`` `r ...` ``) is computed when the document is built, so it cannot
drift; chunks that were not run (`eval = FALSE`, skipped expressions) have no output to compare;
random output that the document does not seed (say so once, in `text`, if the prose quotes such a
number); style and wording.

## Number fixes (applied automatically only if they pass these checks)

For `number-drift`, also give `old_text` (a fragment of ONE prose line, copied exactly, that holds
the number once), `old_number` (as written there), `new_number` (the value the output shows,
written with the same precision the prose uses), and `output_line` (the line of recorded output,
copied exactly, that shows it). A script replaces the number only if `old_text` occurs exactly once
in the document and outside every chunk, holds `old_number` exactly once, and `output_line` is in
the recorded output and contains `new_number` exactly or rounded to the decimals `new_number` has.
Everything else goes to a human, so report it anyway.

## Output

Return the structured JSON the run asks for: `units_checked` (every unit id you actually read) and
`findings`. A document with nothing wrong is listed in `units_checked` with no finding. If you run
out of turns, leave the units you did not read out of `units_checked`; they are re-queued, never
counted as clean.
