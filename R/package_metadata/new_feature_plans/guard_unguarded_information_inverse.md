# Guard the Unguarded Information-Matrix Inverses (NegBin, ZINB, ZAP, Beta)

> **Release:** v1.1.0 (`../future_release_plans/release_v1_1_0.md → TODO-17q`;
> 2026-08-30, user decision). Correctness / hardening, not performance:
> five `with_var` kernels invert the free-parameter information matrix with a
> bare `.inverse()` and no invertibility check, while their siblings (Cox,
> ordinal, ZOIB) check `FullPivLU::isInvertible()` and return a `NaN`
> covariance otherwise. No Phase 0 dependency. **Bit-for-bit on every fit
> whose information matrix is invertible** (see "Equivalence"); only the
> singular case changes, from garbage to `NaN`.

Date: 2026-08-30

## The finding

`fast_negbin_regression_with_var_cpp` (`src/fast_negbin_regression.cpp:485`):

```cpp
Eigen::MatrixXd H_free = subset_matrix(res.XtWX, information_spec.free_idx, information_spec.free_idx);
Eigen::MatrixXd cov_free = H_free.inverse();
Eigen::MatrixXd vcov = expand_free_covariance(X.cols() + 1, information_spec, cov_free, true);
```

Its own roxygen (`:411-418`) says so: "inverted via a plain matrix inverse …
A rank-deficient or near-singular design … will therefore produce
numerically unstable or `NaN` variances rather than a graceful fallback."
Known, documented — and inconsistent with the rest of `src/`. The same bare
pattern appears at:

| site | kernel |
| --- | --- |
| `fast_negbin_regression.cpp:485` | `fast_negbin_regression_with_var_cpp` |
| `fast_zinb.cpp:457` | ZINB `with_var` |
| `fast_zero_augmented_poisson.cpp:340` | ZAP `with_var` (first variant) |
| `fast_zero_augmented_poisson.cpp:566` | ZAP `with_var` (second variant) |
| `fast_beta_regression.cpp:643` | `fast_beta_regression_with_var_cpp` (roxygen `:576` carries the same caveat) |

The guarded siblings — the pattern to adopt — are
`fast_coxph_regression.cpp:391-399` (and `:498`),
`fast_ordinal_regression.cpp:236-244` (and `:559`), and
`fast_zero_one_inflated_beta.cpp:618-627`, which additionally checks
`observed_information.allFinite()` before factoring.

**Why it matters.** On an exactly singular `H_free`, Eigen's `.inverse()`
divides by a zero pivot and the result is `Inf`/`NaN` — noisy but at least
visibly wrong. On a *near*-singular `H_free` (a covariate almost collinear
with the intercept, a dispersion parameter at the Poisson boundary that
`negbin_information_spec` did not catch, a beta-regression `phi` diverging)
it returns a **finite** matrix of enormous, meaningless entries, and the R
side then reports a finite, wildly wrong standard error with no warning.
The R consumers (`inference_count_negbin.R:458`, `:507`) do
`res$vcov %||% solve(hess)` — `%||%` treats a non-`NULL` matrix as valid, so
neither `NaN` nor garbage triggers the fallback; a `NaN` at least propagates
to `NA` in `ssq_b_2` and the SE, which is what the Cox precedent produces
and what `harden = TRUE` paths expect.

## The fix

One shared helper in `_helper_functions_core.h`, next to
`expand_free_covariance()` (`:595`):

```cpp
// Invert the free-parameter information block; NaN-filled on singular input.
// Uses .inverse() for the value (bit-for-bit with the pre-existing behaviour
// on invertible input) and FullPivLU only for the invertibility decision.
inline Eigen::MatrixXd invert_free_information(const Eigen::MatrixXd& H_free) {
    const int k = H_free.rows();
    if (k == 0) return Eigen::MatrixXd(0, 0);
    if (!H_free.allFinite()) return Eigen::MatrixXd::Constant(k, k, NaN);
    Eigen::FullPivLU<Eigen::MatrixXd> lu(H_free);
    if (!lu.isInvertible()) return Eigen::MatrixXd::Constant(k, k, NaN);
    return H_free.inverse();
}
```

and each of the five sites becomes
`Eigen::MatrixXd cov_free = invert_free_information(H_free);`. The
`expand_free_covariance(…, cov_free, true)` call after it already handles
a `NaN` block (it copies entries; fixed parameters get the usual fill).

`FullPivLU::isInvertible()` uses Eigen's default threshold
(`ε · max(rows, cols)` relative to the largest pivot), the same one the Cox
and ordinal sites rely on today, so the five kernels become consistent with
those rather than introducing a new tolerance. The extra factorisation is
one O(p³) at p ≤ 20 per *observed-data* fit (the `with_var` kernels are not
the bootstrap-replicate hot path, which uses `estimate_only`), i.e.
negligible.

## Equivalence

- **Invertible `H_free` (every existing passing fixture):** the returned
  `vcov` is computed by the identical `H_free.inverse()` call as before —
  **bit-for-bit**. This is why the helper does *not* return
  `lu.inverse()` (full-pivot LU differs from `.inverse()`'s partial-pivot
  LU at the ulp and would move every SE in the package by ~1e-16, which
  the v1.1.0 additive constraint forbids without a documented reason).
- **Singular / non-finite `H_free`:** was `Inf`/`NaN`/garbage, becomes an
  all-`NaN` block → `NA` SE on the R side. Documented default change; the
  roxygen caveats at `fast_negbin_regression.cpp:411-418` and
  `fast_beta_regression.cpp:576` are rewritten to describe the guard.

## Items

- [ ] **TODO-1: Helper.** `invert_free_information()` in
  `_helper_functions_core.h` (Rcpp-free, `EDI_CORE_ONLY`-compatible; use
  `std::numeric_limits<double>::quiet_NaN()`, not `NA_REAL`, since the
  header is shared with the Python core).
- [ ] **TODO-2: Apply at the five sites.** Targeted compile of the five
  `.cpp` files only, per `CLAUDE.md`. Optionally refactor the four already-
  guarded sites to call the same helper **only if** they currently use
  `lu.inverse()` and the maintainer accepts the ulp-level change there;
  otherwise leave them (recommended for 1.1.0: leave them; note it as a
  1.2.0 tidy-up).
- [ ] **TODO-3: Tests.** `test-information-inverse-guard.R`, per kernel: (a)
  all existing `with_var` fixtures `identical()` before/after (the
  bit-for-bit claim); (b) a design with a duplicated covariate column and
  `harden = FALSE` (so the R side does not drop it) yields an all-`NaN`
  `vcov`, `NA` `ssq_b_2`, and — through the inference class — `NA` SE and
  `NA` asymptotic CI rather than a finite number; (c) for negbin, a
  dispersion-at-Poisson-boundary fixture confirms `negbin_information_spec`'s
  own handling still takes precedence (no regression in the boundary
  path); (d) a `H_free` containing `Inf` (forced via a warm start that
  overflows `exp(eta)`) returns `NaN` rather than throwing; (e) the
  `k = 0` free-parameter case (all fixed) returns a 0×0 block and the
  expanded `vcov` is the fixed-parameter fill only.
- [ ] **TODO-4: Roxygen.** Replace the "will produce numerically unstable or
  NaN variances" caveats at `fast_negbin_regression.cpp:411-418` and
  `fast_beta_regression.cpp:576` with a sentence describing the guard
  (`NaN` covariance when the free information block is singular; check
  `is.finite(vcov)`); add the same sentence to the ZINB/ZAP `with_var`
  docs. Per `fix_documentation.md` conventions, `parse()`-check only, no
  interim `roxygenize` (memory `feedback_no_interim_roxygenize`).
- [ ] **TODO-5: Audit sweep.** `grep -n "\.inverse()" src/*.cpp src/*.h`
  today lists the five sites above plus: `atkinson_assign.cpp:49` and
  `generate_permutations.cpp:107` (both `lu.inverse()` after a
  `FullPivLU` — check they test `isInvertible()` first; if not, they are
  design-side sites for the same guard), and `fast_gamma_functions.h:98`
  (an elementwise array reciprocal, not a matrix inverse — fine). Record
  the disposition of each in this file.

## Explicitly out of scope

- A rank-aware pseudo-inverse (what `fast_adjacent_category_logit_with_var_cpp`
  does, per the negbin roxygen). That changes *values* on rank-deficient
  designs rather than flagging them; the package's hardening philosophy
  (`fit_with_hardened_qr_column_dropping`) is to drop columns on the R side
  and treat a singular free block in C++ as non-estimable. Keep it that way.
- Surfacing `min_eigenvalue_information` (already returned by negbin) as a
  near-singularity warning on the R side — worth doing, separate plan.
