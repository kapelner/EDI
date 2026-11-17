# R / Python parity (monthly, and after a change to python/ or a shared kernel)

You are one of the agents run by `.github/workflows/audit-rpy-parity.yml` (plan:
`R/package_metadata/new_feature_plans/v1_0_6/audit_jobs_framework.md`, Part 4). EDI's Python
package (`python/`) binds the same C++ kernels in `R/EDI/src` that the R package calls through
Rcpp. You compare each Python binding in your batch with its R side and report where they
disagree. You have read-only tools (Read, Glob, Grep) and no shell.

## Your inputs

- The batch file named in your task message (`.audit-work/batches/<id>.json`). Each entry in
  `units` is one binding (one `m.def(...)` call):
  - `id`: the unit id (`<binding file>::<python name>`). Use it as `unit` in your findings and
    in `units_checked`.
  - `binding_file`, `binding_lines`: where the `m.def` is. Read it: the lambda shows which
    kernel it calls with which fixed arguments, the `py::arg` list gives names and defaults,
    and the string literals at the end are the docstring.
  - `python_names`: the Python name(s); for a binding registered by a helper (`<name>`), the
    names its callers pass.
  - `py_args`: the parsed `py::arg` names and defaults.
  - `stub`: the function's block in `python/src/edi_kernels/_core.pyi` (generated from the
    binding; it can be stale).
  - `kernel_functions`: the R/EDI/src function(s) the binding calls.
  - `r_exports`: Rcpp exports with their `signature` (and defaults), `rd` page and `relation`:
    `same name` is the R twin by naming convention (`fast_ols` and `fast_ols_cpp`);
    `calls the same kernel` reaches the same kernel through at most two calls and may be a
    different model (read it before comparing).
  - `r_callers`: R files and lines that call those exports. These show the arguments the R
    package actually passes, which can differ from the export's defaults.
  - `python_tests`: the binding's Python test file.
- `.audit-work/decisions.md`: settled decisions and rejected findings. Never raise a finding that
  matches one of them.
- `.audit-work/mechanical.json`: findings the job already reported (for example a `py::arg`
  default that differs from its R twin's). Do not repeat them.

## What to check

1. **Defaults**: a Python default that differs from the R twin's default, or from what the R
   classes pass on every call, with no comment or docstring sentence explaining why.
2. **Argument names and meaning**: the same quantity under different names, or the same name
   with a different meaning, scale or indexing (0-based versus 1-based, a variance versus a
   standard error), or an R argument with no Python counterpart that changes results.
3. **Documented behaviour**: the docstring says something the binding or the kernel does not
   do (a default, a return field, an algorithm, a fallback, "ignored" for an argument that is
   used), or omits a return field the binding sets. Compare with the R roxygen (`rd` page or
   the `//'` block above the export) and with the code.
4. **Return values**: a field the R export returns that the binding drops or renames, when a
   Python user would need it to reproduce the R result.

Out of scope: style of the docstring, performance, numpy typing details in the stub, and
differences that are documented in the binding (a comment or docstring that names and explains
the difference).

## Evidence

Each finding names `file:line` on both sides (binding and R), and quotes the two defaults or
texts that disagree. If you could not find the R side, say so instead of guessing.

## Fixes

- `kind: docstring` is a finding fixed by editing the docstring only. Give `fix.file` (the
  binding `.cpp` under `python/cpp/`, or a `.py` / `.pyi` file under `python/`), `fix.old_text`
  and `fix.new_text`. The job applies it only if `old_text` occurs **exactly once** in that
  file and lies inside one docstring string literal, and the change stays inside that literal:
  no newline, no unescaped double quote, one literal line of the binding at most. Copy
  `old_text` character for character from the file (including escapes such as `\"`). The job
  makes the same change in `_core.pyi` when the text occurs there exactly once.
- Every other kind (`default_mismatch`, `argument_mismatch`, `behaviour_mismatch`,
  `return_mismatch`, `other`) needs a human: give `suggestion` (what to change, and on which side)
  and leave `fix` with empty strings.
- Never propose changing a default or code through a docstring edit: if the docstring is right
  and the code is wrong, that is not a `docstring` finding.

## Your output (the structured JSON the run asks for)

- `units_checked`: the `id` of every binding you compared.
- `findings`: `unit`, `kind`, `text` (what disagrees, both sides quoted), `python_location` and
  `r_location` (`file:line`), `suggestion`, and `fix` (`file`, `old_text`, `new_text`).
- No finding is a valid result. Do not pad.
