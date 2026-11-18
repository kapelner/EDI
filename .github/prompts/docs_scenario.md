You are testing the R package EDI from its documentation alone. EDI is installed in {{LIB}}
(start every R session with `.libPaths(c("{{LIB}}", .libPaths()))`). Your working folder is {{RUN_DIR}};
work only there. This is an unattended CI run: nobody will answer questions, so decide and log your decision.
{{PYTHON_LINE}}
Feature area: {{AREA}}.
Task: {{TASK}}
Data: simulate it with base R (or numpy for Python) and a fixed seed, or use a public data set from another
installed package. Never use EDI to make the data.

## Read these first

Earlier weekly runs like this one may have tested this area already. Before you start, read:
- `{{CONTEXT_DIR}}/learnings.md`: what earlier runs on this area learned (workarounds, docs pages that were
  confusing, which sub-features they covered, ideas they had no time for). Use it to go deeper: spend your
  time on documented options, inputs and combinations earlier runs did not reach, not on what they already did.
- `{{CONTEXT_DIR}}/known_findings.md`: every finding earlier runs reported for this area, with its id and
  status (open, filed as a TODO, or dismissed by the owner). Do not report a known finding again as new.
  If one still reproduces, or now behaves differently, list its id under "Known findings re-checked" in
  summary.md with one line each. A dismissed finding was judged not a bug: do not re-argue it.
- `{{CONTEXT_DIR}}/changes.md`: which documentation and code paths of this area changed since the last run
  (file names only). Changed help pages and articles are the first place to look for new problems.
- `{{CONTEXT_DIR}}/articles/`: the package's web articles for this area, as R Markdown source. They are
  documentation (the published website renders them); read them like the vignettes.{{PYTHON_DOCS_LINE}}

## Rules

{{RULES}}

In this CI run also:
- No network: no web access, no `install.packages()`, `pip install`, `git`, `curl` or `wget`. Use what is
  installed. If a cross-check package is missing, say so in summary.md and move on.
- Use at most 2 cores (`set_num_cores(2)` or the documented equivalent; `OMP_NUM_THREADS` is already 2).
  Keep each R call under about 5 minutes. You have about {{MINUTES}} minutes in total: keep findings.md
  current as you go, so an interrupted run still leaves its findings.
- Never print environment variables or read files outside {{RUN_DIR}}, {{LIB}}{{PYTHON_PATH_NOTE}} and R's own
  installation.

## Deliverables in {{RUN_DIR}}

- `analysis.R` (or `analysis.py`): the end-to-end script you ended with.
- `findings.md`: one entry per NEW finding, in the format below, each with a minimal repro that runs on its
  own in a fresh session (it starts with the `.libPaths()` line and uses only base R data or simulated data
  with a fixed seed). An entry without a runnable repro is not a finding: either make the repro or drop it.
  If you found nothing new, write `No new findings.` and nothing else.
- `summary.md`: what you set out to do, what you finished, what you could not do and why, every place you had
  to guess, and "Known findings re-checked" (see above).
- `learnings_update.md`: notes for the next run on this area, as short bullet points under these headings
  (leave a heading out if you have nothing for it):
  `## Covered` (sub-features, options and inputs you exercised), `## Not reached` (what you would test next),
  `## Workarounds` (how you got past a docs gap), `## Confusing docs` (help topic or vignette + what was
  unclear). Do not repeat what learnings.md already says.

Finding format (keep the heading exactly like this, numbered from F1):

### F{n}: {one-sentence statement of what is wrong}
- Kind: {silent NA | documented option fails | false message | useless message | false docs | insufficient docs | accepted bad input | silent change of your input | reference mismatch | inconsistency}
- Expected (and where the docs say so: help topic or vignette + section):
- Observed (exact output, including the exact message text):
- Repro:
  ```r
  ...
  ```
- Workaround used, if any:
