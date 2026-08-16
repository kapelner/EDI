# Unity-Build Collision Audit (R side)

> **Depends on:** none — this is the audit deliverable for
> `release_v1_0_0.md → TODO-6` (unity-build consolidation). It inventories
> every source-level obstacle to merging `R/EDI/src/*.cpp` files into shared
> translation units. Findings are **compiler-verified**, not static-analysis
> guesses.

Audited 2026-08-16. Method: (1) a static scan of all 106 `.cpp` files for
file-scope statics, anonymous-namespace names, surviving `#define`s,
file-scope `using namespace` directives, and file-scope type definitions;
(2) a trial build of 10 alphabetical unity groups (~10 files each, every
group led by `#include "_helper_functions.h"`); (3) a single mega-TU
containing all 105 non-`RcppExports` files compiled with `-fsyntax-only
-fpermissive`, which surfaces every pairwise collision at once (68s
elapsed, 2.6 GB peak RAM — confirming ~10 groups of 8–12 files is the right
shape, not one giant TU).

## Bottom line

**The tree is much closer to unity-safe than budgeted: 8 of 10 trial groups
compile clean as-is.** The complete collision inventory is 12 duplicated
anonymous-namespace helpers, 2 repeated-default-argument declaration
patterns, and 1 pre-existing ODR violation — roughly 16 mechanical fixes
across ~22 files (est. 2–4 hours, not the day-or-two originally budgeted in
`release_v1_0_0.md`). Zero macro leaks, zero file-scope `static` name
collisions, zero other type collisions: helper hygiene (anonymous
namespaces everywhere) is already consistent.

## A. Duplicated anonymous-namespace helpers (redefinition in a merged TU) — FIXED 2026-08-16

Fix is per-item: **hoist** to the named shared header when one exists, else
**rename** with a file-specific suffix. Hoisting is preferred where the
copies are identical — it also deletes duplicated code.

| # | Name | Files | Suggested fix |
|---|---|---|---|
| 1 | `bounded_rand` | `bootstrap_indices.cpp`, `bootstrap_match_indices.cpp`, `exchangeable_resampling_draws.cpp`, `fast_sample_int.cpp`, `sample_bootstrap_distr_weighted_distances.cpp` (5 copies) | hoist to `RNG.h` (already the shared home of `edi_rng::RRng`, its parameter type) |
| 2 | `draw_seed_from_r` | `generate_permutations.cpp`, `pocock_simon_assign.cpp` | hoist to `RNG.h` |
| 3 | `GHRule` (struct) | `fast_clogit_plus_glmm.cpp`, `fast_logistic_glmm.cpp` | hoist to `_glmm_engine.h` (or rename) |
| 4 | `SubjectRecord` (struct) + `record_less` | `fast_gehan_wilcox.cpp`, `fast_logrank.cpp` | hoist to a small shared survival-rank header, or rename per file |
| 5 | `logit_cpp`, `inv_logit_cpp`, `apply_shift` | `fast_kk_wilcox_parallel.cpp`, `fast_wilcox_hl.cpp` | hoist (logit/inv_logit are generic; `_helper_functions_core.h` may already have equivalents — check before adding) |
| 6 | `plogis_array` | `fast_cpoisson_combined.cpp`, `gcomp_speedups.cpp` | hoist or rename |
| 7 | `cluster_meat` | `gcomp_speedups.cpp`, `robust_post_fit_speedups.cpp` | hoist or rename |
| 8 | `all_finite_mat`, `all_finite_vec` | `fast_log_binomial_regression.cpp`, `robust_post_fit_speedups.cpp` (manifests as overload *ambiguity*) | hoist single canonical versions |
| 9 | `score_weighted_crossprod_colwise_assign` (template) | `fast_logistic_regression.cpp`, `fast_probit_regression.cpp` | hoist (it's a template — header is its natural home anyway) |

**Fixed — one item per row above:**

- **1, 2 (`bounded_rand`, `draw_seed_from_r`):** hoisted into `namespace edi_rng` in `RNG.h` (`bounded_rand`) and a new `r_seed_draw.h` (`draw_seed_from_r`, kept out of `RNG.h` since it needs `R::unif_rand()` and `RNG.h` is deliberately Rcpp/R-free). `bounded_rand` call sites needed no changes (ADL resolves it via its `edi_rng::RRng&` argument); `draw_seed_from_r` takes no arguments, so its ~11 call sites across `generate_permutations.cpp`/`pocock_simon_assign.cpp` were qualified to `edi_rng::draw_seed_from_r()`.
- **3 (`GHRule`):** turned out `_glmm_engine.h` already had an identical, unused canonical `glmm::GHRule`. Both files now `using GHRule = glmm::GHRule;` instead of redefining the struct. The near-duplicate *functions* built on it (`gauss_hermite_rule` vs `gauss_hermite_rule_log` vs `glmm::gauss_hermite_rule`, all computing the same values) were deliberately left alone — only the struct was an actual collision; consolidating the functions is a separate, out-of-scope cleanup.
- **4 (`SubjectRecord`/`record_less`):** hoisted into a new `survival_rank_record.h` (`namespace edi_survival`), pulled in via `using` declarations — no call-site changes.
- **5 (`logit_cpp`/`inv_logit_cpp`/`apply_shift`):** `logit_cpp`/`inv_logit_cpp` (byte-identical) hoisted into a new `zero_one_logit_transform.h` (`namespace edi_transform`). **`apply_shift` was NOT hoisted or merged** — its two copies have diverged: `fast_wilcox_hl.cpp`'s supports an additional `transform_code == 4` (count-response, multiplicative-with-rounding) branch that `fast_kk_wilcox_parallel.cpp`'s lacks. Renamed to `apply_shift_hl` / `apply_shift_kk_wilcox` respectively (2 call sites each) to eliminate the build collision without silently changing either file's behavior. **This divergence is a live latent bug worth a human decision**: `transform_code` is a caller-supplied R-side integer with no internal validation, so if `compute_matching_wilcox_distr_parallel_cpp`'s R caller ever passes `transform_code = 4` for a count response, it silently falls through to the wrong additive-shift branch instead of erroring or computing the intended rounded multiplicative shift. Flagging for follow-up, not fixed here (behavior change, out of this pass's scope).
- **6 (`plogis_array`):** hoisted into `_helper_functions_core.h`, next to the pre-existing (differently-named, differently-implemented) `plogis_array_safe`. Kept as a separate function, not consolidated into `plogis_array_safe`, since it uses a different implementation strategy (vectorized Eigen `select` vs. a scalar loop) — a performance characteristic, not just a formatting difference.
- **7 (`cluster_meat`):** **NOT hoisted or merged** — same shape of divergence as `apply_shift`: `gcomp_speedups.cpp`'s copy uses a `std::unordered_map<int, Eigen::VectorXd>` keyed directly by cluster id, `robust_post_fit_speedups.cpp`'s uses a lookup-table-to-position plus a `std::vector` of accumulators (a different, likely faster, strategy). Same result, different algorithm. Renamed to `cluster_meat_gcomp` / `cluster_meat_robust` (1 call site each).
- **8 (`all_finite_mat`/`all_finite_vec`):** hoisted into `_helper_functions_core.h` using the more general `Eigen::Ref<const ...>` parameter signature (a strict generalization of both prior copies — `robust_post_fit_speedups.cpp`'s plain `const Eigen::MatrixXd&`/`VectorXd&` call sites still bind via `Ref`'s converting constructor). ~23 call sites across both files needed no changes.
- **9 (`score_weighted_crossprod_colwise_assign`):** byte-identical; hoisted into `_helper_functions_core.h` as-is.

**Verified:** every touched file re-`-fsyntax-only` clean individually, both in the default R build and (where applicable — i.e. files that are part of the `EDI_CORE_ONLY` Python-bound set or otherwise support that mode) under `-DEDI_CORE_ONLY`. `fast_kk_wilcox_parallel.cpp` and `gcomp_speedups.cpp` fail under `-DEDI_CORE_ONLY` — pre-existing, unrelated to this pass: both unconditionally `#include <RcppEigen.h>` with no core-only branch at all, and neither is in `python/CMakeLists.txt`'s compiled-file list.

**Ground truth:** the full 105-file mega-TU (`-fsyntax-only -fpermissive`) now compiles with **zero errors** (54s, 2.6 GB peak RAM) — down from the original 22 item-A errors (0 from items B/C, already fixed). Every collision the audit identified is resolved.

## B. Repeated default arguments on `*_internal` cross-TU declarations — FIXED 2026-08-16

C++ forbids specifying a default argument for the same parameter twice in
one TU. Today each `.cpp` re-declares the extern `*_internal` functions
locally *with* defaults; merged, the compiler rejects the repeats.

- `fast_logistic_regression_internal`: defaults at the definition
  (`fast_logistic_regression.cpp:95`) and in local re-declarations in
  `fast_hurdle_negbin.cpp:19` and `fast_gee.cpp`.
- `fast_poisson_regression_internal`: same pattern
  (`fast_poisson_regression.cpp:305` + its declarers — enumerate during the
  fix pass).

**Fix:** declare each shared `*_internal` once, with defaults, in a header
(a new `_internal_decls.h` or the appropriate existing shared header);
definition and all users include it; delete every local re-declaration.
This is also just better hygiene — the local extern declarations can drift
from the real signatures silently today. Sweep for the same pattern on any
other `*_internal` the fix pass encounters.

**Fixed:** sweep confirmed exactly two functions collide across files —
`fast_logistic_regression_internal` (defined in
`fast_logistic_regression.cpp`, called from `fast_hurdle_negbin.cpp` and
`fast_gee.cpp`) and `fast_poisson_regression_internal` (defined in
`fast_poisson_regression.cpp`, called from `fast_gee.cpp`).
`fast_logrank_internal`'s cross-file grep hit was a false positive — a
comment in `fast_gehan_wilcox.cpp`, no real re-declaration — and no other
`*_internal` name spans more than one file.

The sweep also turned up a live drift instance the audit only speculated
about: `fast_hurdle_negbin.cpp`'s and `fast_gee.cpp`'s local
re-declarations gave `smart_cold_start` a default of `true`, while the real
definitions default it to `false` (and both local copies invented a default
for `weights`, which has none at the definitions). Currently inert — every
actual call site at both locations passes every argument explicitly — but
exactly the kind of silent divergence a shared declaration point closes off
for good.

Created `internal_fn_decls.h`: declares both functions once, with defaults
matching the real definitions, `#include`s `_helper_functions_core.h` for
`ModelResult`/Eigen/`optional`/`string` (safe to re-include anywhere via its
own guard). Both defining `.cpp` files now `#include` it and had their
out-of-line definitions stripped of defaults (repeating a default already
given by a visible prior declaration is itself a compile error — not merely
redundant). Both calling-only `.cpp` files had their hand-written
forward declarations deleted in favor of the `#include`. Verified: all four
files re-syntax-checked individually (clean), and the mega-TU compile no
longer reports any `*_internal`/"default argument" errors — the remaining
errors are exactly item A's nine anonymous-namespace collisions.

## C. Pre-existing ODR violation (fix regardless of unity) — FIXED 2026-08-16

`struct DigammaFunctor` is defined at **file scope** (external linkage) in
both `fast_beta_regression.cpp:16` and `fast_zero_one_inflated_beta.cpp:14`.
That is an ODR violation in *today's* per-file build — silent UB if the
definitions ever diverge. In the mega-TU it surfaces as "reference to
'DigammaFunctor' is ambiguous". **Fix:** hoist one canonical definition to
`fast_gamma_functions.h` (its topical home) or wrap each in the file's
anonymous namespace. Prefer the hoist.

**Fixed:** hoisted the canonical `struct DigammaFunctor` (an Eigen
`unaryExpr` adaptor over `fast_digamma`) to `fast_gamma_functions.h`,
immediately after `fast_digamma`'s definition — both call sites already pull
that header transitively (`_helper_functions(.h|_core.h)` →
`fast_gamma_functions.h`), so no new includes were needed. Removed the
duplicate from `fast_beta_regression.cpp`'s anonymous namespace and the
file-scope (externally-linked) duplicate from
`fast_zero_one_inflated_beta.cpp`. `fast_zero_one_inflated_beta.cpp`'s
sibling `LgammaFunctor` (single-file, no collision) was left as-is. Verified:
both files re-syntax-checked individually (clean), and the mega-TU compile
no longer mentions `DigammaFunctor` among its errors — the remaining errors
are exactly items A and B below, unaffected.

## Wrapper-level requirements (validated in the trial, not per-file work)

- **Every unity TU must begin with `#include "_helper_functions.h"`** — it
  owns the NDEBUG-before-Eigen discipline (see its header comment). The
  trial wrappers led with it and all groups honored the assert-disabling
  behavior. Individual files that include `RcppEigen.h`/`Eigen/Dense`
  directly need no edits; the wrapper's first include wins.
- `using namespace` at file scope (`Rcpp` in 100 files, `Eigen` in 22,
  `glmm` in 1) caused **no** ambiguities in any trial group. No cleanup
  required; be aware directives leak forward across merged files, so a
  future ambiguity would be grouping-dependent.
- `RcppExports.cpp` stays its own TU (regenerated by Rcpp; never merge).

## Regression protection

Unity-safety rots silently (a future file adding a colliding static breaks
whichever grouping merges the pair). Once the fixes land, add the mega-TU
`-fsyntax-only` compile (~68s) as a cheap CI step or pre-push hook item —
it is grouping-independent, so it protects every present and future
grouping on both the R and Python (CMake `UNITY_BUILD`) sides.

## Developer workflow note

`EDI_UNITY=1` (the R-side default) breaks the previous fast single-file
edit-compile loop: editing one kernel `.cpp` changes only that file's mtime,
not its containing `unity_NN.cpp` wrapper's (the wrapper's own content, a
fixed `#include` list, doesn't change), so an incremental `R CMD INSTALL`
has no signal telling it to recompile that unity group. **Set `EDI_UNITY=0`
for local iterative work** (e.g. in `~/.Renviron`) — it restores the exact
previous one-object-per-file behavior. Every *fresh* build (CI, CRAN,
`--preclean`) is unaffected regardless, since the wrappers are always
regenerated from the current source tree before each such build. See
`configure`'s own comment on this for the full explanation, including why
the obvious fix (compiler-generated `.d` dependency files + a Makevars
`-include`) was tried and reverted after it broke `R CMD INSTALL` outright.

## Status — ALL ITEMS FIXED, both R and Python sides wired and verified (2026-08-16)

- [x] Audit complete (this document).
- [x] Fix pass: items A1–A9, B, C. All fixed — see per-item notes above.
- [x] Re-run the mega-TU compile → **zero errors** (was 22, all item A; B/C
  were already at 0 by that point). 54s, 2.6 GB peak RAM.
- [x] Two latent bugs discovered as a byproduct — both now resolved
  (2026-08-16):
  1. **Item B's default-argument drift**: needed no further action.
     `internal_fn_decls.h` already declares `smart_cold_start = false`
     (matching the real definitions), and every actual call site passes
     the argument explicitly rather than relying on any default — the
     drift was eliminated as a side effect of item B's fix itself.
  2. **`apply_shift` transform_code == 4 gap**: fixed.
     `apply_shift_kk_wilcox` (`fast_kk_wilcox_parallel.cpp`) was missing
     the count-response multiplicative-with-rounding branch that
     `apply_shift_hl` (`fast_wilcox_hl.cpp`) already had. Traced the
     exposure: `rand_bootstrap_transform_code()`
     (`inference_all_abstract_rand_bootstrap.R`) — documented there as
     "the shared C++ shift code used by all BRT batch kernels" — maps
     `response_type == "count"` to code 4, and `"count"` is an explicitly
     documented supported `response_type` for `InferenceAllKKWilcoxIVWC`
     (`inference_all_KK_wilcox_ivwc.R`), the sole caller of
     `apply_shift_kk_wilcox`'s C++ entry point. Not reachable via any
     *current* R call path (that call site still computes its own local
     0..3-only `transform_code` instead of using the shared helper), but a
     silent-wrong-answer trap the moment it is. Added the matching branch
     to `apply_shift_kk_wilcox`, bringing it to parity with
     `apply_shift_hl`; both functions now handle transform codes 0..4
     identically (kept as separate named functions, not unified, since
     they're called from different files). Verified: both files
     re-`-fsyntax-only` clean, and the full mega-TU still compiles with
     zero errors after the change (no regression).
- [x] Build wiring implemented and verified (2026-08-16) — see
  `release_v1_0_0.md → TODO-6` for the full write-up: `configure` now
  generates `src/unity_NN.cpp` (10 groups, `EDI_UNITY=1` default) with
  idempotent (compare-before-write) regeneration and an `EDI_UNITY=0`
  escape hatch; `R CMD INSTALL` verified end-to-end (real compile + link +
  load); numeric output confirmed bit-identical between `EDI_UNITY=1` and
  `EDI_UNITY=0` across kernels from every touched file. One real bug found
  and reverted during implementation: an `-MMD -MP` + Makevars `-include`
  auto-dependency-tracking addition silently broke `R CMD SHLIB`/`INSTALL`
  outright (built only the first object, reported success, never linked) —
  root cause not fully diagnosed, do not reintroduce; see that file's
  in-code comment.
- [x] Standing regression gate implemented:
  `scripts/check_unity_build_safety.sh` (repo root) generates the unity
  wrappers in an isolated scratch copy — independent of whatever
  `EDI_UNITY` setting the working tree currently has configured — and
  `-fsyntax-only`-checks all 10 in parallel (~30-40s). Wired into
  `.githooks/pre-push`, gated on the same C++-file-change condition as the
  existing R install/test steps. Verified both the pass and (via a
  deliberately introduced, then reverted, syntax error) the fail path.
- [x] **`EDI_CORE_ONLY`-only collision found and fixed (2026-08-16).** The R
  mega-TU audit above only ever compiled the *non*-`EDI_CORE_ONLY` branch
  (the R build never defines that macro), so it was structurally blind to
  collisions that exist only inside `#ifdef EDI_CORE_ONLY` code — exactly
  the branch the Python extension compiles. This blind spot surfaced the
  moment the Python side's own unity build was tried for real: CMake's
  batching merged `miettinen_nurminen_speedups.cpp`, `newcombe_speedups.cpp`,
  `fast_gehan_wilcox.cpp`, `fast_logrank.cpp`, `fast_wilcox_hl.cpp`,
  `fast_survival_stats.cpp`, and `fast_ridit_analysis.cpp` into one
  translation unit, and each independently declared its own file-scope
  `constexpr double NA_REAL = std::numeric_limits<double>::quiet_NaN();`
  under `EDI_CORE_ONLY` — a hard redefinition error once merged, same bug
  family as item A, just invisible to the R-only audit method. Fixed by
  hoisting one canonical definition into a new leaf header,
  `na_real_core.h`, using `inline constexpr` (the C++17 mechanism
  specifically designed to let an identical definition appear in every
  including TU without an ODR violation) rather than plain `constexpr`
  (internal linkage, redefinition-prone once merged — the same class of
  fix as items A/C, just via `inline` instead of a single shared
  non-inline definition). All 7 files now `#include "na_real_core.h"`
  instead of defining `NA_REAL` locally. This is a **methodology
  finding**, not just a bug: any future R-side-only verification pass on
  this codebase should also compile-check the `EDI_CORE_ONLY` branch
  (e.g. `check_unity_build_safety.sh` could be extended to also
  `-fsyntax-only` a `-DEDI_CORE_ONLY` mega-TU/unity-group build if this
  branch grows more such collisions later) rather than assuming the R-side
  mega-TU covers both.
- [x] **Python side: CMake `UNITY_BUILD` flipped on and verified
  (2026-08-16).** `python/CMakeLists.txt`'s `_core` target now sets
  `UNITY_BUILD ON UNITY_BUILD_BATCH_SIZE 10` (5 groups over ~49 source
  files). Verified locally end-to-end, not just compiled: a clean
  `pip install -e ".[test]"` build succeeds, the built `_core` extension
  imports and a direct kernel call (`fast_logistic_regression`) returns
  correct output, and the full test suite passes (**181/181**). The
  original sequencing note (wait for the full multi-platform
  `cibuildwheel` wheel CI matrix to cycle green before flipping this) was
  explicitly waived per instruction — that full-matrix validation is
  deferred to a later, real CI run rather than blocking this change; the
  local single-platform build+import+test-suite pass above is the
  substitute evidence for now.

## Appendix: how to actually test the unity build locally

`~/.Renviron` is set to `EDI_UNITY=0` (see the Developer workflow note
above) so a plain `R CMD INSTALL` builds per-file, fast, by default. To
deliberately test the unity build itself, override the variable for that
one invocation:

```
EDI_UNITY=1 R CMD INSTALL R/EDI
```

`--preclean` is orthogonal — it just forces every object to rebuild from
scratch (ignoring any existing `.o` files), which is good hygiene when
deliberately verifying a from-clean build (closer to what CI/CRAN actually
does) but not required for the `EDI_UNITY` override itself to take effect:
`configure` re-runs and regenerates `src/Makevars`/`unity_*.cpp` on every
`R CMD INSTALL` from a source directory regardless. If you want the closest
local proxy to CI, combine both:

```
EDI_UNITY=1 EDI_PORTABLE=1 R CMD INSTALL --preclean R/EDI
```
