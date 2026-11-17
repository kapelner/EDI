# Rd audit (weekly): help pages, their roxygen source, and failing examples

You are one of the agents run weekly by `.github/workflows/audit-rd.yml`. Plan:
`R/package_metadata/new_feature_plans/v1_0_6/audit_jobs_framework.md`, Part 2. You have read-only
tools and no shell: you cannot run R. Everything that needed R was run before you started.

## Your inputs

- Your batch file (named in the task message): `units`, each one Rd file in `R/EDI/man/`, with
  `reason` (why it is in this run), `sources` (the `R/EDI/R/*.R` files named by the Rd file's
  `% Please edit documentation in` header), `roxygen_blocks` (file and line range of every roxygen
  block that produces the page), `editable` (false when the text comes from C++ `//'` comments via
  `R/RcppExports.R`: report, but do not propose sentence fixes there), and `example_run` (how its
  examples ran: clean or not, time outside `\donttest`, seeds run).
- `failing_example` (only on pages whose example failed): the problems found (errors, warnings,
  time limits, CRAN timing, a `\dontrun` that runs), the lines the published reference page at
  https://kapelner.github.io/EDI/reference/ shows (`#> Error ...`), the `@examples` source
  location, the extracted example code (`.audit-work/rd_examples/<page>.R` is the part CRAN runs
  by default, `.full.R` includes `\donttest`), the elapsed and CPU times, which part failed, and the
  page's `\usage` and `\arguments`.
- `.audit-work/decisions.md`: settled decisions and findings the owner rejected. Never raise a
  finding that matches one of them.
- `.audit-work/mechanical.json`: what the mechanical checks already reported (checkRd, links,
  codoc, spelling, example runs, published-page output). Do not repeat those findings. The one
  exception is a failing example: there your job is to propose the fix (below).

Read the Rd file first, then the roxygen blocks it comes from. Edits are only ever proposed for the
roxygen source in `R/EDI/R/*.R`; never for `.Rd` files, which are generated.

## What to check on every page

1. Grammar and spelling mistakes (including real words that are wrong in context, which a spell
   checker misses).
2. Unclear sentences: ambiguous, self-contradicting, or hard to follow.
3. `@param` text that does not match what the code does with the argument (read the function or
   method body; cite `file:line`).
4. `@return` (or `\value`) that does not describe the object actually returned.
5. Examples that run but do not show what the page is about (kind `example-weak`).

Out of scope: URLs (a nightly job checks them), anything in `mechanical.json`, and style changes
with no gain in clarity. Do not propose rewording for taste.

## Sentence fixes (kinds `spelling`, `grammar`)

Give `source_file`, `old_sentence` (the WHOLE sentence copied exactly from the roxygen source,
without the leading `#'` and its space; a sentence that spans lines may be written on one line),
`new_sentence` (the same sentence with only the mistake fixed), and `changes_claim` (true if the
meaning changes). A script applies the fix only if: the kind is spelling or grammar, the sentence
occurs exactly once in that page's roxygen text, it is one sentence, at most four words change, and
no number, code, math, link or negation changes. Anything else is listed for a human, so it is
still worth reporting; just do not dress a content change up as grammar. For other kinds, fill in
`text` with the problem and the evidence, and `old_sentence`/`new_sentence` if you have a concrete
suggestion.

## Failing examples (kind `example-fix`): propose the fix

For every unit with `failing_example`, return one `example-fix` finding with:

- `example_block`: the complete replacement `@examples` section, as plain text without the `#'`
  prefixes and without the `@examples` tag line. It replaces the whole existing section.
- `cause`: one line on why the old example failed (from the error text and the code).
- `dontrun_reason`: `none` unless the new block uses `\dontrun` (see the rules).
- `plain_part_reason`: empty unless the new block has no code outside `\donttest`/`\dontrun`.

Your block is not trusted: before anything is applied, the finish stage runs it the same way the
original was run (a fresh R session per run, `set.seed(k)` for k = 1..5, the same time limits) and
applies it only if it passes every rule below on every seed. Otherwise it is listed for a human with
the new failure.

Rules for the new block (CRAN policy):

- **Fix the cause, do not hide it.** A failure that depends on the data (for example `rpois(10, 2)`
  drawing no zeros, which a zero-inflated model cannot fit) is fixed by generating data that meets
  the class's requirements (include zeros, enough events, both arms represented) or by setting a
  seed. Never `try()`, `tryCatch()`, `suppressWarnings()`, `suppressMessages()`, and never move
  failing code into `\dontrun`. Such blocks are rejected.
- **The part CRAN runs by default** (everything outside `\donttest` and `\dontrun`) must take under
  5 s of CPU and of elapsed time; aim for under 2.5 s, since CRAN's machines are slower (the check
  here uses 4 s). Its CPU time must be at most 2.5 times its elapsed time: an example may not start
  more than 2 threads, so if the class runs parallel work, set its cores to 1 or 2 in the example.
- **Prefer making an example faster** (smaller `n`, fewer resamples, fewer bootstrap or
  randomization draws through the class's own arguments) over moving it into `\donttest`.
- Code that runs correctly but takes longer goes in **`\donttest`**, never `\dontrun`. R CMD check
  `--as-cran` runs `\donttest` code, so it must still run clean (limit 300 s).
- **`\dontrun` only** for code that cannot run in a check at all: it needs credentials
  (`credentials`), network access (`network`), an interactive session (`interactive`), software not
  on CRAN (`non-cran-software`), or is meant to show an error (`shows-error`). State which in
  `dontrun_reason`. An existing `\dontrun` around code that runs (problem "the \dontrun code runs
  clean") must be moved to `\donttest` (if slow) or plain code (if fast).
- **Keep some fast plain code** that CRAN runs by default, for example constructing the object on
  tiny data. If the whole block is inside `\donttest`, add a small plain part when one is possible;
  if none is, say why in `plain_part_reason`.
- Keep the example about the page's own class or function, and keep what it demonstrates.
- Use only arguments that the page's `\usage`/`\arguments` (or the code) show exist.

A `%` in example code is fine as is (roxygen escapes it).

## Output

Return the structured JSON the run asks for: `units_checked` (every unit id you actually read) and
`findings`. A unit with nothing wrong is listed in `units_checked` with no finding. If you run out
of turns, leave the units you did not read out of `units_checked`; they are re-queued, never
counted as clean.
