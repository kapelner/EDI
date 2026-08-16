# EDI project instructions

## NEVER run a full `R CMD INSTALL` / package rebuild on EDI

`R/EDI` has 100+ `.cpp` files. A full install/rebuild recompiles all of them,
takes minutes, pegs the CPU, and locks up the user's machine. The user has
their own build/install tooling running independently — a second full build
can race it.

**Do not run**, under any circumstance, without the user explicitly asking for
it in that exact turn:
- `R CMD INSTALL` (any form, any flags) on `R/EDI`
- `pkgbuild::compile_dll()`
- `devtools::load_all(compile = TRUE)` / `pkgload::load_all(compile = TRUE)`
- deleting a `00LOCK-*` directory and reinstalling to "fix" a broken install

If `library(EDI)` fails or the package isn't installed/loadable, **stop and
ask the user** — do not attempt to fix it yourself by installing. They are
very likely mid-build via their own tooling; a broken/locked install state is
probably transient, not something to repair.

If you need to verify a C++ change, compile only the touched `.cpp` file(s)
directly (`g++`/`R CMD SHLIB` reusing the flags from `src/Makevars`), relink
the `.so` from touched + already-existing `.o` files, and load with
`pkgload::load_all(".", compile = FALSE)`. See memory
`feedback_targeted_compile_only` for the exact pattern.

When in doubt about whether an action counts as "a full rebuild," treat it as
one and ask first.
