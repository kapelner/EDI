# Source comment rot audit (monthly): comments that contradict the code beside them

You are one of the agents run by `.github/workflows/audit-source-comment-rot.yml` (module
`.github/scripts/audits/source_comment_rot.py`). Each unit in your batch is one source file in
`R/EDI/R` or `R/EDI/src`. Your question, for each file:

> **Does a comment state something about the code next to it that the code does not do?**

You can read and search the repository (Read, Glob, Grep). You have no shell, cannot build or run
anything, and must not try to edit files: a script applies your corrections afterwards, under the
rules below.

## Your inputs

1. Your batch file (named in your task message), `.audit-work/batches/<batch>.json`: `units`, one per
   file, each with `id` (the file path, which you report back as `unit`), `language`, `lines`,
   `comment_lines`, `uncited_notes` (TODO/FIXME/XXX notes the mechanical stage already reports) and
   `reason` (why it is in this run: new, changed, open finding, rotation).
2. `.audit-work/decisions.md`: findings the owner rejected before, and conventions. Never raise a
   finding that matches an entry there.
3. `.audit-work/mechanical.json`: mechanical findings already reported. Do not repeat them; in
   particular, do not report TODO/FIXME/XXX notes.

## What to report

A comment, including a roxygen line (`#'`) and a Doxygen or block comment, that makes a checkable
claim about the code beside it, where the code says otherwise:

- a **default** (`# default 1e-8`, `@param tol ... Default 1e-6`) that differs from the default in the
  signature or the code;
- a **tolerance, limit or count** (`max 50 iterations`, `n >= 3`) the code does not use;
- a **formula** (`# Var = p(1-p)/n`, `// Newton step: H^{-1} g`) the code does not compute;
- an **always / never / only** claim (`# never returns NA`, `// always positive definite here`) the code
  visibly breaks (a branch that returns NA, a path that skips the check);
- a **name** of a function, argument, field or file the comment says is used and the code does not use
  (renamed or removed).

Check the claim against the code yourself: follow the called function when the claim depends on it.
Report only what you can show from the code. Read every file in your batch completely.

## Out of scope

- Comments that are vague, incomplete or badly written but not wrong.
- Stale history ("added 2026-08-21", "was slower before") unless it states something false about the
  current code.
- TODO/FIXME/XXX notes (the mechanical stage reports them).
- Generated files and anything outside your batch.
- Code changes. If the comment may be right and the code wrong (the comment states the intended
  behaviour, a documented default, a published formula), report it as `code_may_be_wrong`; a human
  decides.

## Your output (the structured JSON the run asks for)

- `units_checked`: every file `id` you read completely.
- `findings`: one per wrong comment line:
  - `unit`: the file path (the unit `id`);
  - `kind`: `contradiction` (the comment is wrong; the code is right) or `code_may_be_wrong`;
  - `line`: the line number of the comment line;
  - `old`: the comment line **exactly as it is in the file**, whole line, indentation and code before
    the comment included. It must occur only once in the file; if the same line occurs more than once,
    report it as `code_may_be_wrong` so a human applies it;
  - `new`: the corrected line. Change only the comment part: everything before the comment marker
    (`#`, `#'`, `//`, `/*`, ` *`) must stay character for character the same, and the line must stay
    one line. Leave `new` empty for `code_may_be_wrong` if you do not know the right wording;
  - `text`: one or two sentences: what the comment claims, what the code does, with the code line
    (`file:line`) that shows it;
  - `evidence`: `file:line` references you relied on.

A correction that would change code, span several lines, or match more than one line is not applied;
it goes to "Needs a human" with your text. If you run out of turns, leave the files you did not finish
out of `units_checked`; they are read again next run.
