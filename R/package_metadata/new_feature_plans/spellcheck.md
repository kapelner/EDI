# Spell-Check the Package Documentation — `spelling` + `inst/WORDLIST`

> **Depends on:** none (pure repository hygiene; no runtime code changes).
> Written 2026-09-16, user decision, alongside `implement_a_lintr.md` —
> the cheap, non-controversial half of the "what else can we gate before a
> push?" question. *(maintenance)* — no user-visible effect beyond fewer
> typos in the reference manual. (Global ordering: see `_master.md`;
> release index: `release_v1_1_0.md → TODO-24`.)

## Motivation

EDI's documentation surface is large — roxygen for every design and
inference class, five vignettes, `NEWS.md`, `REFERENCES.md`, the READMEs —
and it is the part of the package that agents and users actually read
first. Nothing checks it for spelling. Checked 2026-09-16: the `spelling`
package is **not** installed on the maintainer's machine, there is **no
`inst/WORDLIST`**, `DESCRIPTION` has `Encoding: UTF-8` but **no
`Language:` field**, and neither `.githooks/pre-push` nor any workflow runs
a spell check.

Unlike `lintr` (see `implement_a_lintr.md`), there is no style decision to
make first: `spelling::spell_check_package()` is a pure typo detector
over Rd/vignette/`DESCRIPTION` prose, and the only "policy" it needs is a
word list for the vocabulary a statistics package legitimately uses
(Kapelner–Krieger, Pocock–Simon, rerandomization, heteroskedasticity,
Cordeiro–McCullagh, the estimator/class names, `mirai`, `Rcpp`, …). The
setup cost is a one-time triage; the ongoing cost is near zero.

## Finding 1: false-positive load is the whole job

A first run over any statistics package produces hundreds of "misspellings"
that are proper nouns, method names, package names, and class identifiers.
The work is not fixing typos (there will be a handful) — it is building the
`inst/WORDLIST` so the check reports only real typos afterward. `spelling`
supports this directly: `spelling::update_wordlist()` writes every current
finding into `inst/WORDLIST`, after which `spell_check_package()` is
clean; typos found later are then genuinely new.

Two things that inflate the first run and should be handled by
configuration, not by wordlisting:

- **Class/function names in prose.** Roxygen wraps most in backticks/
  `\code{}`, which `spelling` skips; the ones written bare in running text
  will show up. Fix the prose (backtick them — it is also the documentation
  standard in `fix_documentation.md`) rather than wordlisting every class
  name.
- **`REFERENCES.md` / `@references`.** Author surnames and journal names
  are the bulk of the noise. Either exclude `REFERENCES.md` from the check
  (it is bibliographic data, not prose) or accept its names into the
  wordlist once; recommend excluding.

## Finding 2: `Language:` field

`spelling` reads `DESCRIPTION`'s `Language:` to pick the dictionary and
`R CMD check` reports its absence as a NOTE only under `--as-cran` when
`_R_CHECK_CRAN_INCOMING_` is on (not in our matrix, which disables it) —
but CRAN's own incoming check does flag it. Adding `Language: en-US` is a
one-line change with no downside, and settles the US/UK question that the
wordlist otherwise has to absorb ("randomization" vs "randomisation" —
the package is consistently US, so `en-US`).

## TODOs

### TODO-1 — Bootstrap the wordlist (~1 hour, one PR)

1. `DESCRIPTION`: add `Language: en-US`; add `spelling` to `Suggests`
   (it is a check-time tool, not a runtime dependency — same tier as
   `testthat`).
2. Run `spelling::spell_check_package("R/EDI")`, fix the real typos it
   finds in Rd/vignettes/`NEWS.md` (expect a handful; each is a real
   documentation fix), backtick any bare class/function names it flags in
   prose, then `spelling::update_wordlist("R/EDI")` to write
   `R/EDI/inst/WORDLIST` for the legitimate vocabulary that remains.
3. Review the generated `inst/WORDLIST` by eye once: anything that looks
   like a typo rather than a term is a typo `update_wordlist` just
   enshrined — remove it and fix the source.
4. Record the counts (typos fixed / terms wordlisted) in this plan.

### TODO-2 — Add the test that keeps it clean

`spelling::spell_check_test(vignettes = TRUE, error = FALSE, skip_on_cran = TRUE)`
in `R/EDI/tests/spelling.R` — the package's own recommended pattern. It
runs under `R CMD check` (our CI matrix, not CRAN), reports new
misspellings as a test failure, and costs about a second. Because the
comprehensive suite and bulk tests are already gated elsewhere, this is
the only spelling gate needed in CI.

### TODO-3 — Wire it in

1. `CONTRIBUTING.md` §4: one line — "`spelling::spell_check_package()`
   clean; new legitimate terms go in `inst/WORDLIST`, not `# nolint`".
2. `.githooks/pre-push`: run `spell_check_package()` **content-gated** on
   the same trigger `fast_roxygenize` already uses (roxygen `#'` edits) plus
   `R/EDI/vignettes/**` and `R/EDI/NEWS.md` changes. Seconds per push.
3. Devcontainer: add `spelling` to the Dockerfile's `install2.r` line.
4. `python/`: `README_PYPI.md`/`CHANGELOG.md` are covered by neither
   `spelling` (R-package-scoped) nor anything else. Out of scope here;
   note only that `codespell` would be the analog if wanted.

## Deferred (explicitly not in this plan)

- Grammar/style checking (`proselint` etc.) — different tool class, real
  false-positive cost, no clear payoff for API reference prose.
- Spell-checking code comments (`# ...` in `R/EDI/R`, `//` in `src/`) —
  `spelling` does not read them; `codespell` could, but comments are not
  user-facing and the noise from identifiers in comments is high. Revisit
  only if TODO-1 turns out to be quiet enough that expanding scope is
  free.
