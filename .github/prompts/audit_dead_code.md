# Dead-code audit (monthly): confirm or rule out each candidate

You are one of the agents run by `.github/workflows/audit-dead-code.yml` (module
`.github/scripts/audits/dead_code.py`). A mechanical cross-reference found functions in EDI that
nothing seems to use. It is a word search over the sources, so it misses uses it cannot see. Your job,
for each candidate in your batch, is to decide whether it is really unused.

You can read and search the repository (Read, Glob, Grep). You have no shell, cannot build or run
anything, and must not try to edit files.

## Your inputs

1. Your batch file (named in your task message), `.audit-work/batches/<batch>.json`: `units`, one per
   candidate, each with
   - `id`: the unit id you report back (`R:<name>` or `cpp:<file>::<name>`);
   - `lang` (`R` or `C++`), `name`, `kind`, `file`, `line`: what and where;
   - `definition`: the first lines of its definition;
   - `note` (C++ only) and `r_name` (an Rcpp export's R wrapper name): what the search found;
   - `searched`: which directories the mechanical search covered;
   - `reason`: why it is in this run (new, changed, open finding, rotation).
2. `.audit-work/decisions.md`: candidates the owner rejected before, and conventions. Never confirm a
   candidate that matches an entry there.
3. `.audit-work/mechanical.json`: mechanical findings already reported (empty for this audit).

## What counts as a use

A candidate is **not** dead if any of these reaches it:

- **R:** a call from R code by any route the word search misses: a name built as a string
  (`paste0("Inference", x)`, `sprintf(...)`) and resolved with `get()`, `getExportedValue()`,
  `match.fun()`, `do.call()`, `exists()` or `[[ ]]` on a namespace or environment; an R6 class or method
  reached through a registry, a factory (`define_inference_class()`, the design and inference class
  registries), `inherit =`, or `$set()`; an S3 method dispatched by `UseMethod()`; a function a user is
  meant to call (documented as public in its roxygen block, listed in a vignette or README); a use in
  `python/` that calls into R.
- **C++:** a call through a macro, a function pointer or a template parameter; a use in a header that
  is included elsewhere; a call from `python/cpp` (pybind11 bindings) or `R/benchmark`; an overload
  or a same-named function in another translation unit that the call actually resolves to; an
  `.Call()` target registered by hand; code guarded by `#ifdef` that is compiled on another platform
  or build (`EDI_CORE_ONLY`, `EDI_UNITY`, the Python build).
- **An Rcpp export with no R caller** is reported for its R wrapper. If C++ code calls the function
  directly, the function is used and only the `[[Rcpp::export]]` may be unneeded: say so in `text` and
  mark it `unsure` unless the export is clearly unused from R (then `confirmed`, with that wording).

Search for the name yourself (Grep, including partial names and string forms) before you confirm.
Test files that only test the candidate itself do not make it used, but say so in `text` (the test
would go with it).

## Out of scope

- Whether the code is good, slow or duplicated. Only "is anything using it".
- Proposing a removal patch. The PR lists candidates; the owner removes code by hand.
- Candidates not in your batch.

## Your output (the structured JSON the run asks for)

- `units_checked`: the `id` of every candidate you reached a verdict on.
- `findings`: one entry per checked candidate:
  - `unit`: its `id`;
  - `kind`: `confirmed` (nothing reaches it), `false_positive` (something does), or `unsure`;
  - `text`: one or two sentences. For `confirmed`: what you searched and that nothing calls it, and
    what else would go with it (a test, a declaration, a helper only it uses). For `false_positive`:
    the use, as `file:line` and how it reaches the candidate. For `unsure`: what you could not settle;
  - `evidence`: `file:line` references you relied on (may be empty for `confirmed`).

Every `confirmed` and `false_positive` verdict must rest on searches you actually ran. If you run out of
turns, leave the remaining ids out of `units_checked`; they are read again next run.
