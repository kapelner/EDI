# Release Scope: v4.0.0 (Tentative)

> **Depends on:** `release_v3_0_0.md` (ships first). Release index over plans
> in `../new_feature_plans/`; not new work of its own. (Global ordering: see
> `../new_feature_plans/_master.md`.)

Written 2026-09-19 (user decision). **Low priority and tentative.** The full
C++ migration and the language bindings that depend on it were moved here
from `release_v2_0_0.md` because they are "not a priority whatsoever." This
release has no committed scope beyond the items below and no decision batch
yet; revisit only after v3.0.0 nears completion. Nothing in v2.0.0 or v3.0.0
depends on it.

## In scope (by plan)

### Shared C++ inference and design backend

- `migrate_EDI_into_shared_cpp_backend.md` — one native implementation of
  model fitting and statistical inference behind a versioned `libedi_core` C
  ABI, with R and Python as thin adapters and a dual-backend compatibility
  window. Includes Phases 0–7 (portable inference algebra, evaluator vertical
  slice, draws-in resampling, Python and R on the shared ABI, native draws)
  and **Phase D** (the native design protocol: design handle, versioned RNG,
  serializable state). Practical first release estimated at 20–35 engineer-
  weeks; broad parity 50–90; Phase D adds an estimated 22–39, partly
  overlapping Phase 7. Effort figures are planning ranges only.

### Additional language bindings

- `more_language_bindings.md` — MATLAB, JVM, Stata, .NET, Julia, Node.js, and
  other bindings over the shared ABI, sequenced strictly after the shared
  backend so that no language gets a separately handwritten kernel
  implementation. Level K (kernels and inference) is the supported scope;
  Level W (full R6 workflow parity) is not promised.

## Implementation TODOs (dependency order)

- [ ] TODO-1: **Shared C++ inference and design backend**
  `migrate_EDI_into_shared_cpp_backend.md → CPPABI-001..` and `Phase D`
  (`CPPABI-D001..`) — land the ABI, the evaluator, draws-in inference, and
  the design handle, with the dual-backend window, before any downstream
  binding work.
- [ ] TODO-2: **Additional language bindings**
  `more_language_bindings.md → TODO-1..` — execute only after TODO-1's ABI,
  release, and ownership decisions are complete.

## Standing constraints

Same as every release: `define_inference_class()` for every new class; no
mixin splicing, no class-name dispatch; kernel conventions per
`sexp_removal_rcppeigen_conversion_spec.md`; targeted compile only (see the
repo `CLAUDE.md`). The existing public R and `edi_kernels` Python APIs must
keep working through the migration; the R-RNG path stays selectable for one
release cycle because native design generation changes the random stream.
