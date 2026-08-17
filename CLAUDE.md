# EDI project instructions

## NEVER run a full `R CMD INSTALL` / package rebuild on EDI

`R/EDI` has 100+ `.cpp` files. A full install/rebuild recompiles all of them,
takes minutes, pegs the CPU, and locks up the user's machine. The user has
their own build/install tooling running independently — a second full build
can race it.

This rule was violated repeatedly in a past session (2026-08-17): `R CMD
INSTALL` was run directly multiple times, and separately, after promising to
"switch to the correct approach," `devtools::load_all(quiet = TRUE)` was run
— which defaults to `compile = TRUE` and **is** a full rebuild in disguise.
Saying the right thing and then running the wrong command anyway is exactly
the failure mode this section exists to prevent. A third variant also
happened: doing a full build inside an isolated `/tmp` copy of `R/EDI` to
"avoid" touching the user's working copy. That does not make it safe — it
still pegs the CPU for minutes and still isn't what was asked for. The rule
is about not running full builds of this codebase at all without being asked
in that turn, not about which directory the build happens to run in.

**Before running *any* command that touches compilation of `R/EDI`** —
`R CMD INSTALL`, `R CMD build`, `configure`, `pkgbuild::*`, `devtools::*`,
`pkgload::*`, a bare `g++`/`R CMD SHLIB` invocation, or any of these against
a copy/clone/worktree of `R/EDI` anywhere, including `/tmp` — stop and check
this file first. Do not rely on remembering the rule; grep for it.

**Do not run**, under any circumstance, without the user explicitly asking for
it in that exact turn:
- `R CMD INSTALL` (any form, any flags), on `R/EDI` or any copy of it
- `R CMD build`
- `pkgbuild::compile_dll()`
- `devtools::load_all()` / `pkgload::load_all()` **with no `compile` argument
  given** — the default is `compile = TRUE`, which is a full rebuild.
  `compile = FALSE` must be passed explicitly, every time, no exceptions.
- `devtools::load_all(compile = TRUE)` / `pkgload::load_all(compile = TRUE)`
  (the explicit form of the same thing)
- deleting a `00LOCK-*` directory and reinstalling to "fix" a broken install
- any of the above run against an isolated copy, `git worktree`, or `/tmp`
  checkout of `R/EDI` instead of the real working directory — this is still
  a full build and still not what was asked for

If `library(EDI)` fails or the package isn't installed/loadable, **stop and
ask the user** — do not attempt to fix it yourself by installing. They are
very likely mid-build via their own tooling; a broken/locked install state is
probably transient, not something to repair. If you already caused a partial/
broken state yourself (e.g. killed a build partway through), say so plainly
and ask how they want it handled — do not run more compile commands to try to
clean it up.

If you need to verify a C++ change, compile only the touched `.cpp` file(s)
directly (`g++`/`R CMD SHLIB` reusing the flags from `src/Makevars`), relink
the `.so` from touched + already-existing `.o` files, and load with
`pkgload::load_all(".", compile = FALSE)`. If the existing `.o` files needed
for a relink don't already exist (e.g. fewer than the full `.cpp` count),
that means a full build has never completed here — do not compile the
missing files yourself to "complete" it. Stop and ask; the missing `.o`s are
a sign someone else's build is in progress or was interrupted, and completing
it yourself is the exact full-rebuild-in-disguise this file forbids. See
memory `feedback_targeted_compile_only` for the exact targeted-compile
pattern.

When in doubt about whether an action counts as "a full rebuild," treat it as
one and ask first.
