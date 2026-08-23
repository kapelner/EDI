# Feasibility Report: Clayton Copula IVWC/OneLik Under Interval Censoring

## Status

Commissioned by TODO-11 in
`package_metadata/finished_features/interval_censored_survival_response.md`
("Commission a follow-up feasibility report for
`InferenceSurvivalKKWeibullFrailtyLoggammaIVWC`/`OneLik` under interval censoring,
scoping how the copula's matched-pair joint-survival structure interacts
with interval-censored marginals").

**Bottom line: feasible, and unlike TODO-10's dependent-censoring
question, this is a genuine engineering problem with a defined target —
but a materially harder one than the Tier 1/Tier 2 classes, concentrated
entirely in the matched-pairs half.** The reservoir half of both classes
already rides on the exact interval-censoring-capable kernel Tier 1
scoped (`fast_weibull_regression_general_cpp`) — confirmed by direct
code inspection, not inferred. The matched-pairs half needs new
closed-form algebra: not a `log(S(L) - S(R))` univariate difference, but
a bivariate rectangle-difference of the pair's *joint* survivor function,
with up to 9 branches (versus the current 4) depending on which pair
member(s) are exactly observed, right-censored, or genuinely
interval-censored. This report scopes exactly what those branches are.

## Two Classes, One Shared Bivariate Kernel

`R/EDI/R/inference_survival_KK_weibull_frailty_loggamma.R` defines two classes:

- **`InferenceSurvivalKKWeibullFrailtyLoggammaIVWC`** (line 36) — fits the
  matched-pairs component and the reservoir component *separately*, then
  inverse-variance-weight-combines the two log-time-ratio estimates
  (`shared()`, lines 318-358).
- **`InferenceSurvivalKKWeibullFrailtyLoggammaOneLik`** (line 468) — fits *one*
  combined likelihood in which matched pairs contribute the joint-copula
  term and reservoir subjects contribute as singleton (independent)
  Weibull terms in the same optimization.

Both ultimately call into the same C++ kernel, `ClaytonWeibullLikelihood`
(`R/EDI/src/fast_survival_models_optim.cpp:39-183`, via
`fast_clayton_weibull_aft_optim_cpp` / the `.fit_clayton_weibull_aft` R
wrapper in `other_helpers.R:1319`), which accepts a `pair_idx` matrix
(rows are the two subject indices making up a matched pair) *and* a
`singleton_rows` vector (unmatched or reservoir subjects) in the same
call — so IVWC's matched-pairs-only call and OneLik's matched+reservoir
call are the same kernel with different inputs, not two different
kernels. Any interval-censoring extension to this kernel benefits both
classes simultaneously.

## The Model Being Extended

The Clayton copula on Weibull cumulative hazards is, for a pair `(i1,
i2)` with Weibull cumulative hazards `H1 = exp((log y1 - eta1)/sigma)`,
`H2 = exp((log y2 - eta2)/sigma)`:

```
S(t1, t2) = A^(-1/theta),   A = exp(theta*H1) + exp(theta*H2) - 1
```

This is the closed-form bivariate survivor function of two
conditionally-independent Weibull hazards sharing a gamma frailty
`Z ~ Gamma(1/theta, 1/theta)` (Clayton 1978; Oakes 1989), integrated out
analytically — no numerical integration, which is exactly why this
kernel is fast enough to run per-pair inside an optimizer today. The
current C++ implementation (`fast_survival_models_optim.cpp:91-160`)
differentiates `S(t1,t2)` **0, 1, or 2 times** depending on how many of
the two pair members had an *exactly observed* event, producing exactly
four closed-form branches per pair:

| `dead1` | `dead2` | Contribution | Meaning |
|---|---|---|---|
| 0 | 0 | `-(1/theta) * log A` | `S(y1,y2)` itself (both right-censored) |
| 1 | 0 | `log f1 + (-1/theta-1) log A + (theta+1) H1` | `-dS/dt1` at `(y1,y2)` |
| 0 | 1 | mirror of above | `-dS/dt2` at `(y1,y2)` |
| 1 | 1 | `log(theta+1) + log f1 + log f2 + (-1/theta-2) log A + (theta+1)(H1+H2)` | `d^2S/dt1dt2` |

This is precisely the bivariate analog of what Tier 1's univariate
Weibull extension already does one dimension at a time (`S`, `-dS/dt`, or
nothing needed for an exact observation's density) — the structural
pattern generalizes cleanly, but the combinatorics do not stay linear:
univariate right-vs-exact is a 2-way choice per subject, so a *pair* of
univariate-only subjects is `2 x 2 = 4` cases, which is exactly the table
above. Once *each* member of the pair can independently be exact,
right-censored, *or* interval-censored (a 3-way choice), a pair becomes
`3 x 3 = 9` cases.

## What The 9 Cases Look Like

Reusing the pattern each of the current 4 branches already establishes
(0, 1, or 2 partial derivatives of `S(t1,t2)` depending on observation
type), the general term for a pair is a **finite difference of `S` over
a rectangle or half-strip in `(t1, t2)` space**, matching each member's
observation type to one of three operators:

- **Exact** (`f_i`): evaluate `-dS/dt_i` at the observed point (already
  in the current 4-branch code, e.g. the `mask10`/`mask01` branches'
  `log_f[i1]`/`log_f[i2]` terms) — no change needed for this axis.
- **Right-censored** (current `dead=0` case): evaluate `S` itself at the
  observed point — already in the code (`mask00`'s bare `S`, and the
  `(-1/theta-1)`-order terms in the mixed branches) — no change needed
  for this axis.
- **Interval-censored, `[L_i, R_i]`** (new): evaluate the *difference* of
  whatever the other axis's operator produces, taken between `t_i = L_i`
  and `t_i = R_i`. Concretely, for a pair where subject 1 is exact and
  subject 2 is interval-censored, the current `mask10`-style single
  partial derivative `-dS/dt1` becomes a *difference of two* evaluations
  of that same partial derivative, at `(y1, L2)` and `(y1, R2)`:
  `-dS/dt1(y1, L2) + dS/dt1(y1, R2)` (sign flips because `S` is
  decreasing in each argument — same sign logic already present when
  Tier 1 differences `S(L) - S(R)` for a single interval-censored
  subject). If *both* subjects are interval-censored, this becomes a
  **4-term rectangle difference** of `S` itself: `S(L1,L2) - S(R1,L2) -
  S(L1,R2) + S(R1,R2)`, the direct 2-D analog of the classic
  interval-censoring `S(L) - S(R)` construction. Every one of the 9 cases
  is one of: `S` evaluated 1, 2, or 4 times (0 exact axes), `dS/dt`
  evaluated 1 or 2 times (1 exact axis, other axis exact/right/interval
  respectively collapses back toward the current code), or `d^2S/dt1dt2`
  evaluated once (both exact, the current `mask11` case, unchanged).

This is real, nontrivial new algebra (each of the new terms needs its own
gradient contribution derived and added to the existing
`d_loglik_d_eta`/`d_loglik_d_log_sigma`/`d_loglik_d_log_theta`
accumulators, the way the existing 4 branches each do), but it is
**closed-form and mechanical** — no numerical integration, no new
random-effect quadrature, just more terms of the same `A =
exp(theta*H1) + exp(theta*H2) - 1` algebra already in the file. This
places it below Tier 3's typical bar of "genuinely open modeling
question" (contrast with TODO-10's report) and closer to "a large but
well-defined derivative-and-testing exercise" — closer in spirit to
Tier 1 than to TODO-10, just with roughly `9/4` the branch count and a
2-D rectangle-difference in place of a 1-D one.

## The Reservoir Half Is Already (Mostly) Done

Both classes' reservoir component fits an **ordinary, independent**
Weibull AFT — `weibull_for_reservoir()` in the IVWC class
(`inference_survival_KK_weibull_frailty_loggamma.R:389+`) calls
`fast_weibull_regression_general_cpp(y=..., y_L=..., y_R=..., X=...)`
directly (confirmed at `inference_survival_KK_weibull_frailty_loggamma.R:219-227`,
the fixed-VC fast path) — **this is the exact same kernel already scoped
as Tier 1** (`R/EDI/src/fast_weibull_regression.cpp:375`,
`fast_weibull_regression_general_cpp`, shared verbatim with
`InferenceSurvivalWeibullRegr`). Once Tier 1 lands and the
`supports_interval_or_left_censored_data()` guard is lifted for that
kernel's callers generally, the reservoir half of this class needs
essentially no new numerical work — just wiring `y_L`/`y_R` through
instead of `y`/`dead`, the same "OneLik-likely-free" pattern this
plan already documents for other Tier 2 KK classes. All of the genuinely
new work is in the matched-pairs half described above.

## OneLik vs. IVWC

Because both classes share the same `ClaytonWeibullLikelihood` kernel via
`pair_idx`/`singleton_rows`, the interval-censoring extension is a
**single shared implementation problem**, not two separate ones:

- **IVWC** calls the kernel with `pair_idx` only (matched pairs) in one
  call, then the reservoir Weibull kernel separately, then
  inverse-variance-combines. Once the kernel supports interval censoring
  for pairs, IVWC "just" needs its two component-fitting functions
  (`clayton_copula_for_matched_pairs()`,
  `weibull_for_reservoir()`) to pass `y_L`/`y_R` through instead of
  `y`/`dead` — structurally the smaller of the two classes' remaining
  work once the kernel itself is extended.
- **OneLik** calls the kernel with *both* `pair_idx` and
  `singleton_rows` in one combined call — the singleton branch (already
  present at `fast_survival_models_optim.cpp:162+`) is a plain univariate
  Weibull term, so it needs the same "add interval-differencing to a
  univariate branch" treatment Tier 1 already scopes, cheaply reusing
  that derivation.

## Recommendation

This is implementable, and should be written up as real TODOs in a
future planning pass (not this feasibility report) once Tier 1's
univariate interval-censoring work has actually landed and been
verified — the bivariate extension's building blocks (the
interval-difference operator applied to `S`, `dS/dt`, and the existing
`d^2S/dt1dt2` case) are best derived and tested *after* the univariate
case is proven correct in this codebase's actual test harness, both
because the univariate case is strictly simpler to get right first and
because several of the 9 new pair-branches degenerate exactly to
"apply the univariate interval-difference twice," so bugs there would
otherwise be hard to distinguish from new bivariate-specific bugs.
Concretely, a follow-up implementation TODO should scope: (1) deriving
and unit-testing all 9 branches' log-likelihood and gradient terms in
isolation (ideally against a brute-force numerical-integration reference
implementation for at least a few parameter settings, since this is
exactly the kind of closed-form derivative work where a sign error is
easy to introduce and hard to spot from fit output alone); (2) wiring
`y_L`/`y_R` through both classes' matched/reservoir component functions;
(3) re-verifying OneLik's `singleton_rows` branch shares Tier 1's
univariate derivation rather than re-deriving it independently.
