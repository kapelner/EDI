# Expected Fisher information for the cumulative-link ordinal classes (v1.0.6-TODO-142)

2026-11-19, agent (uncommitted). Classes: `InferenceOrdinalPropOddsRegr` (logit),
`InferenceOrdinalOrderedProbitRegr` (probit), `InferenceOrdinalCauchitRegr` (cauchit),
`InferenceOrdinalCloglogRegr` (cloglog).

## 1. What `supports_fisher_information()` enables

Defined in `R/EDI/R/inference_all_abstract_asymp_lik.R`:

- `get_supported_information_preferences()` becomes `c("auto", "fisher", "observed")` (was
  `c("auto", "observed")`), so `set_information_preference("fisher")` is allowed.
- `get_default_information_source()` (what `"auto"` resolves to) becomes `"fisher"` (was
  `"observed"`).
- It does **not** change the testing types offered (the TODO text said it did): those come from
  `supports_likelihood_tests()`.

The resolved source is read by `InferenceExtInformationMatrix$get_information_matrix()`, through
`spec$fisher_information(fit)` or `spec$observed_information(fit)`. Two places use it:

- **Score (Rao) test and score CI.** The information is evaluated at the **null (constrained)
  fit**: `score[j]^2 / (I_jj - I_jn I_nn^-1 I_nj)`. This is where the source matters most.
- **`private$get_standard_error()`**, evaluated at the **MLE**. The public Wald p-value and CI do
  not use it: `compute_asymp_two_sided_pval()` / `compute_asymp_confidence_interval()` with
  `testing_type = "wald"` short-circuit to the C++ `ssq_b_j` (observed information) whenever it
  is finite. So `get_standard_error()` only feeds the Wald fallback when `ssq_b_j` is not finite,
  the seeds and step sizes of the CI inversions (score / gradient / LR and parametric-bootstrap
  LR), and the summary-table fallback.

### What was wrong before

All four C++ fitters (`fast_ordinal_regression.cpp` and `ordinal_fixed_link_internal.h`) return
`fisher_information = observed_information = information = -Hessian`, with
`information_type = "observed"`. The C++ docs say so, and `test-ordinal-information-reuse.R`
asserts it. The R specs' `fisher_information` closures returned
`fit$fisher_information %||% -hessian`. So for probit, cauchit and cloglog, "fisher" was the
**observed** information under a "fisher" label, and `get_information_source_used()` reported
`"fisher"`. Expected information was never used by any of the four classes. Adding the flag to
PropOdds as it stood would have copied that mislabel. Each kernel has a correct
`expected_hessian()` (`ordinal_fixed_link_helpers.h`), but nothing calls or exports it.

## 2. Derivation

Model (the solvers' native parameterization, raw increasing thresholds, no log-difference
reparameterization; ordering is enforced by `validate_params()`, which returns 1e10 off the
ordered set):

    P(Y_i <= k | x_i) = F(z_ik),   z_ik = alpha_k + s * x_i' beta,   k = 1..K-1,

with s = -1 for logit, probit and cauchit, and s = +1 for the cloglog solver (the class reports
-beta_native). Write pi_ik = F(z_ik) - F(z_i,k-1), with F(z_i0) = 0 and F(z_iK) = 1, and
f = F'. Then

    d pi_ik / d alpha_m = f_im (1{m = k} - 1{m = k-1}),
    d pi_ik / d beta    = s x_i (f_ik - f_i,k-1) =: s x_i d_ik      (f_i0 = f_iK = 0).

The log-likelihood is l = sum_i log pi_{i,y_i}. Because sum_k pi_ik = 1, E[score] = 0, and the
expected information is

    I = E[-d2 l] = E[s s'] = sum_i sum_k (d pi_ik)(d pi_ik)' / pi_ik

(the second-derivative term sum_k d2 pi_ik = 0 drops out under the expectation). In blocks:

    I[a_m, a_m]   = sum_i f_im^2 (1/pi_im + 1/pi_i,m+1)
    I[a_m, a_m+1] = -sum_i f_im f_i,m+1 / pi_i,m+1            (tridiagonal threshold block)
    I[a_m, beta]  = s sum_i f_im (d_im/pi_im - d_i,m+1/pi_i,m+1) x_i'
    I[beta, beta] = sum_i x_i x_i' sum_k d_ik^2 / pi_ik

The link enters only through (F, f):

| link | F(z) | f(z) |
|---|---|---|
| logit | 1/(1+e^-z) | F(1-F) |
| probit | Phi(z) | phi(z) |
| cauchit | 1/2 + atan(z)/pi | 1/(pi(1+z^2)) |
| cloglog | 1 - exp(-e^z) | exp(z - e^z) |

This is McCullagh's (1980, JRSS-B 42, §5) general expression for cumulative-link models, and the
block form in Agresti, *Analysis of Ordinal Categorical Data* (2nd ed., §5.1–5.2). For K = 2 it
reduces to the binary GLM's X'WX with W = f^2 / (F(1-F)); for logit, W = F(1-F) (checked
numerically below). Expected and observed information coincide at the MLE only when the link is
canonical for the multinomial. No cumulative link is (the cumulative logit is not the multinomial
canonical link), so the two differ at finite n for all four links, by O_p(n^-1/2) relative.

Implementation: `ordinal_cumlink_expected_information(X, y, params, link, eta_sign)` in
`R/EDI/R/inference_ordinal_ordered_probit.R`, in pure R and vectorized, using the same 1e-12
floor on pi as the C++ likelihood. It returns NULL at a non-finite or non-ordered point.

## 3. Numerical verification

Scripts: `$TMPDIR/t201/verify.R` and `verify_b.R` (scratch, not committed). The design had
n = 100, X = (treatment, N(0,1), U(-1,1)), K = 4, alpha = (-0.8, 0.2, 1.1) and public
beta = (0.6, 0.5, -0.4).

### (a) Information at the true parameters: max |A - B| / max |B|

"E[s s'] C++" and "E[-H] C++" are exact y-expectations of the package's own C++ score / Hessian
kernels. Per-(i, k) contributions are obtained by appending one row to a base data set (the
likelihood is additive), weighted by the true pi_ik. "numDeriv" is the expectation of the
outer product of numerical gradients of log pi_ik. "C++ expected_hessian" is the unexported
kernel method, compiled standalone with `Rcpp::sourceCpp` in `$TMPDIR`. MC is 4000 simulated
data sets.

| link | vs E[s s'] C++ | vs E[-H] C++ | vs numDeriv | vs C++ expected_hessian | vs MC (B = 4000) |
|---|---|---|---|---|---|
| logit | 3.4e-16 | 8.2e-16 | 4.9e-11 | 5.5e-16 | 0.016 |
| probit | 6.8e-16 | 5.1e-16 | 3.0e-11 | 5.9e-16 | 0.052 |
| cauchit | 3.3e-16 | 1.7e-16 | 2.5e-11 | 4.4e-16 | 0.028 |
| cloglog | 9.1e-16 | 1.8e-15 | 2.7e-11 | 5.5e-16 | 0.023 |

The MC column is Monte Carlo error (O(B^-1/2) on a max-entry metric). K = 2 logit vs logistic
X'WX: 1.6e-16.

### (b, c) At the MLE: treatment SE from observed vs expected information vs `ordinal::clm` / `MASS::polr`

Three simulated data sets per cell. `info rel diff` = max|I_exp - I_obs| / max|I_obs|.

| link | n | se_obs / se_clm | se_exp / se_obs (range) | info rel diff (range) |
|---|---|---|---|---|
| logit | 100 | 1.0000–1.0001 | 0.994–1.001 | 0.018–0.036 |
| probit | 100 | 1.0000 | 0.994–0.998 | 0.022–0.033 |
| cauchit | 100 | 1.0000–1.0001 | 0.943–0.997 | 0.047–0.175 |
| cloglog | 100 | 1.0000 | 0.991–1.003 | 0.036–0.107 |
| logit | 1000 | 1.0000 | 1.000–1.001 | 0.007–0.008 |
| probit | 1000 | 1.0000 | 0.998–1.000 | 0.007–0.017 |
| cauchit | 1000 | 0.9998–1.0003 | 0.988–1.009 | 0.016–0.035 |
| cloglog | 1000 | 0.9999–1.0001 | 0.998–1.003 | 0.017–0.058 |

- EDI's observed-information SE equals `ordinal::clm`'s to <= 3e-4 relative for every link.
  `MASS::polr` agrees for logit, probit and cloglog. Its cauchit SEs are about 1% lower, because
  polr's Hessian comes from `optim` numerical differences.
- Expected vs observed: within about 0.6% for logit and probit at n = 100. Cauchit (up to 5.7%
  SE, 17% info) and cloglog (up to 0.9% SE, 11% info) differ more, as non-canonical heavy- or
  skew-tailed links should. The gap shrinks about n^-1/2 by n = 1000.
- Side note: the treatment estimates agree with clm to about 1e-3 (logit n = 1000: 0.7376 vs
  0.7390, about 1% of an SE). This is the solver's convergence tolerance. It is not new and not
  touched here.

## 4. Change

- `ordinal_cumlink_expected_information()` and `ordinal_cumlink_link_cdf_pdf()`: new shared
  helpers.
- `spec$fisher_information` now returns the expected information for all four classes. The
  shared `ordinal_cumlink_likelihood_test_spec()` (probit, PropOdds) gains a `link` argument;
  cauchit and cloglog have their own specs. Cloglog uses `eta_sign = +1`, matching its native
  Hessian and score. `observed_information` and the legacy `information` closures are unchanged.
- `InferenceOrdinalPropOddsRegr` gains `supports_fisher_information() = TRUE`. It is registered in
  the PropOdds override list and in `OrdinalProportionalOddsLikelihood$provides_private_methods`
  (`contracts_mixins.R`). The registry baseline needed no delta, because the class already
  listed `supports_fisher_information@InferenceOrdinalPropOddsRegr`, the inherited default bound
  on the composed class.
- No C++ change.

**Results that change:** the default (`"auto"` -> `"fisher"`) score test p-values and score CIs
of all four classes now use the expected information at the null fit. Before, they used the
observed information, labelled "fisher". The same applies to `get_standard_error()` at the MLE,
which feeds the CI-inversion seeds, the Wald fallback and the summary fallback. Public Wald
p-values and CIs are unchanged. LR and gradient statistics are unchanged.

## 5. Calibration (null size at 0.05)

Setup: `DesignSeqOneByOneBernoulli`, two covariates (0.5 x1 - 0.4 x2), K = 4, data generated
from each class's own link, beta_T = 0, 2 cores. MC SE is 0.007 at R = 1000 and 0.011 at R = 400.
"wald" is the public Wald (observed SE). The NA rate was 0 everywhere.

| link | n | R | wald | score, expected (new default) | score, observed (old default) | LR |
|---|---|---|---|---|---|---|
| logit | 100 | 1000 | 0.057 | 0.057 | 0.059 | 0.059 |
| probit | 100 | 1000 | 0.055 | 0.055 | 0.055 | 0.055 |
| cauchit | 100 | 1000 | 0.042 | 0.046 | 0.055 | 0.055 |
| cloglog | 100 | 1000 | 0.052 | 0.049 | 0.053 | 0.053 |
| logit | 40 | 1000 | 0.054 | 0.057 | 0.063 | 0.063 |
| probit | 40 | 1000 | 0.048 | 0.042 | 0.050 | 0.050 |
| cauchit | 40 | 1000 | 0.039 | **0.053** | **0.092** | 0.079 |
| cloglog | 40 | 1000 | 0.064 | 0.054 | 0.069 | 0.071 |

The expected-information score test is at or closer to nominal in 7 of 8 cells. Probit at n = 40
(0.042 vs 0.050) is the exception, and it is within 1.2 MC SE. Where it matters, at small n
with the non-canonical heavy- or skew-tailed links, the expected information is much better:
the cauchit observed-information score test was anti-conservative at n = 40 (0.092). This
supports keeping "fisher" (now real expected information) as the default.

Power check (beta_T = 0.5, n = 100, R = 400): rejection rates were Wald / score-expected /
score-observed / LR = logit 0.275 / 0.275 / 0.275 / 0.275, probit 0.623 / 0.620 / 0.623 / 0.623,
cauchit 0.300 / 0.313 / 0.338 / 0.335, and cloglog 0.613 / 0.595 / 0.615 / 0.615. The expected-
information score test loses no meaningful power. The cauchit score test's slightly higher
observed-information power matches its anti-conservative size.

## 6. Open items

- Public Wald p-values and CIs ignore `set_information_preference()` whenever the C++ `ssq_b_j`
  is finite: the `StandardModelCache` override of `compute_asymp_*` short-circuits to
  `s_beta_hat_T`. `get_standard_error()` honors the preference, so under "fisher" the Wald CI
  (observed) and `get_standard_error()` (expected) disagree. This is generic to every
  `StandardModelCache` class, not only ordinal. For canonical-link GLMs it is invisible, because
  observed equals expected at the MLE. It needs an owner decision on which should win.
- The C++ result field `fisher_information` (all four ordinal kernels) is the observed Hessian.
  It is honestly typed (`information_type = "observed"`), but the name invites this bug again.
  Rename it, or fill it from `expected_hessian()`, in a C++ pass (owner build; relates to
  v1.0.6-TODO-144).
- `InferenceOrdinalPartialProportionalOddsRegr` (cumulative logit with non-parallel effects) does not
  claim Fisher information. It would need its own derivation (category-specific slopes), so it
  is out of scope. The KK CLMM classes are mixed models, so this does not apply to them.
- `expected_hessian()` in `ordinal_fixed_link_helpers.h` reads `p[0]` when K = 1 (n_alpha = 0,
  empty vector). It is unreachable today, because nothing calls it. Guard it if it is ever
  exported.

## 7. Follow-up (v1.0.6-TODO-156 items 2 and 3, 2026-11-20, agent, uncommitted)

**Item 2 (C++ field name; PATCHED, needs owner build).** The four kernels (`fast_ordinal_regression.cpp`
and `ordinal_fixed_link_internal.h`) no longer return `fisher_information`; they return the observed
information as `observed_information` / `information` (`information_type = "observed"`), as before. Filling
the field from `expected_hessian()` was not chosen: every R caller passed that field to the next fit's
warm start, so it would have changed warm-start trajectories (and so results at the solver tolerance), and
it would add an expected-information pass to every bootstrap / randomization fit. The R callers (cumulative-
link classes, likelihood-test specs, PropOdds weighted refit, PartialPO fast path, ordinal G-computation,
ordinal KK combined weighted refit) now read `observed_information`, which is the same matrix on the old
build. `expected_hessian()` no longer reads `p[0]` when K = 1 (it now returns a zero matrix; the old code
fails `_GLIBCXX_ASSERTIONS`); for K = 2..5 and all four links its output is `identical()` to before.
Python's `fast_ordinal_*` dicts share these kernels and lose the `fisher_information` key too.

**Item 3 (PartialPO information).** Derivation, with clm's `nominal` parameterization
logit P(Y <= k | x) = alpha_k + x_np' gamma_k - x_par' beta, params = (alpha, beta, gamma_1, ..., gamma_{K-1}):
v_ik = dz_ik / dparams has 1 at alpha_k, -x_par at beta and x_np in the gamma_k block;
g_ik = f_ik v_ik - f_i,k-1 v_i,k-1 (f_i0 = f_iK = 0);

    expected  I = sum_i sum_k g_ik g_ik' / pi_ik
    observed  J = sum_i [ g g' / pi^2 - (f'_iy v_iy v_iy' - f'_i,y-1 v_i,y-1 v_i,y-1') / pi ],  f' = f (1 - 2F).

Implemented as `ordinal_partial_po_information()` (`inference_ordinal_partial_proportional_odds.R`), not wired
into the class. Checks (test `test-ordinal-partial-po-information-observed-matches-clm-expected-matches-vgam.R`):
J equals -numDeriv Hessian (<= 1e-6 relative) and gives `ordinal::clm`'s treatment SE; I gives
`VGAM::vglm(cumulative())`'s SE (VGAM's vcov is Fisher scoring's expected information); with no nonparallel
columns J equals the PropOdds kernel Hessian and I equals `ordinal_cumlink_expected_information()`.

**What the class publishes today.** The class has no likelihood tests (`likelihood_tier = "none"`), so a
Fisher information would have no consumer. Its Wald SE comes from the backend that fitted: the fast solver
(observed) with no nonparallel columns; VGAM (EXPECTED) with nonparallel columns; clm (observed) when VGAM
fails or is degenerate (non-finite log-likelihood). Under the owner rule of item 1 (Wald = observed), the
VGAM path is the exception. Size of moving it to observed (J at the VGAM MLE), treatment SE ratio J / VGAM,
K = 4, one nonparallel covariate, 5 data sets per n, VGAM and clm at the same MLE:

| n | median abs. change | max abs. change |
|---|---|---|
| 60 | 0.44% | 0.6% |
| 100 | 0.76% | 0.96% |
| 300 | 0.19% | 0.50% |
| 1000 | 0.05% | 0.22% |

(2 of 5 n = 60 data sets had a degenerate VGAM fit with NaN log-likelihood; the class already falls through
to clm, observed, there.) Estimates do not change. Open owner decision: (a) compute J at the VGAM MLE and
publish that SE (recommended: one R pass per fit, matches clm and the item-1 rule, unifies the three
backends); (b) put clm ahead of VGAM in the cascade (changes estimates when the two optimizers disagree);
(c) keep VGAM's expected SE as a documented exception, like probit / log-binomial in item 1.

**Owner decision 2026-11-20: option (a), implemented 2026-11-21.** The VGAM path now publishes the observed-information
SE at VGAM's estimate (`ordinal_partial_po_vgam_observed_se()`); a non-PD observed information sends the cascade to
clm. A larger A/B (40 data sets per n, same design) gives SE changes of median 0.1% / 0.8% / 0.3% / 0.2% and max
5.0% / 5.7% / 1.6% / 0.9% at n = 40 / 60 / 100 / 300, with every estimate identical; the 5-data-set table above
understated the small-n maximum.
