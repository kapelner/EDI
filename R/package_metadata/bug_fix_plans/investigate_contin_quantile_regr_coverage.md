# Investigate: `InferenceContinQuantileRegr` — Near-Universal `low_coverage` Across Every CI Method

> **Depends on:** none. Found 2026-09-24, via a dedicated cross-class
> investigation fork chasing the audit's `low_coverage` backlog after the
> `stale_ok_row_rows` prune. **Medium confidence on the primary claim
> (truth-mismatch hypothesis ruled out by direct distributional argument);
> low confidence on the actual root cause, which remains open.**

## The finding

33 of 33 `(formula, function_run)` cells for `InferenceContinQuantileRegr`
fail the audit's `low_coverage` check — every asymptotic method
(`asymp`, `wald`), every resampling family (`bootstrap`,
`bayesian_bootstrap` × 5 CI-construction variants, `m_out_of_n_bootstrap`,
`subsampling`, `rand_bootstrap` × 4 variants, `jackknife_wald`,
`rand`), for both `model_formula=~1` and `~.`. Coverage ranges from a mild
0.97-0.99 (over) to a severe 0.765-0.828 (under, worst:
`compute_rand_bootstrap_confidence_interval_symmetric-percentile-t`
at `~1`, `compute_bootstrap_confidence_interval_studentized` at `~.`),
with a mix of both over- and under-coverage across methods, all
`n>200` rows (some >1700), so this is not sampling noise on any single
cell.

This breadth — essentially every CI-producing method failing at once,
both formulas — is the exact symptom this codebase already has a named
pattern for: several sibling classes (`InferenceSurvivalLogRank`/
`GehanWilcox`, `InferenceOrdinalRidit`) previously showed identical
"near-universal miscoverage across every method simultaneously" and it
turned out to be a **harness truth-scale mismatch** (the audit's MC
truth registry, `COVERAGE_MC_SPEC` in `R/package_tests/comprehensive_tests.R`,
had no entry for the class, so `get_coverage_truth()` fell back to the raw
DGP shift parameter `beta_T_val` — correct for a collapsible
mean-difference estimand, wrong for a non-collapsible or differently-scaled
one), not a real CI defect.

## Truth-mismatch hypothesis: checked, RULED OUT

`InferenceContinQuantileRegr` is indeed **absent from `COVERAGE_MC_SPEC`**
(confirmed by grep — no entry, unlike its sibling
`InferencePropQuantileRegr`/`InferencePropKKQuantileRegrOneLik`, which
already got exactly this treatment), so `get_coverage_truth()` does fall
back to raw `beta_T_val` for it (`comprehensive_tests.R:3379-3396`,
`COVERAGE_CLOSED_FORM`/`COVERAGE_MC_SPEC` both miss). That looked like an
exact match to the known pattern at first glance.

**But the DGP rules this out for this specific class.** The harness's
continuous-response generator (`apply_treatment_effect_and_noise()`,
`comprehensive_tests.R:3099-3103`) is:
```r
eps = rnorm(1, 0, SD_NOISE)
bt = ifelse(w_t == 1, beta_T, 0)
return(y_t + bt + eps)
```
— a **deterministic, homogeneous, purely additive** treatment shift
(`beta_T` if treated, `0` if not), added on top of a (possibly nonlinear
in covariates) baseline `y_t` plus symmetric zero-mean noise. The median
of a random variable is shift-equivariant for *any* underlying
distribution: `median(Y + c) = median(Y) + c` for any constant `c`,
regardless of `Y`'s shape. Since `bt` depends only on `w` (never on `x`
or on any random component) and treatment is randomized (so the `x`-
distribution doesn't differ by arm), the true `tau=0.5` quantile
treatment effect equals `beta_T` **exactly** — both the marginal
(`~1`) and the `x`-conditional (`~.`) version, with no dependence on
whether `y_t(x)` is linear (`InferenceContinQuantileRegr` defaults to
`tau=0.5`, confirmed via its own roxygen docstring,
`inference_continuous_quantile_regr.R:1-40`). So, unlike `LogRank`/
`GehanWilcox`/`Ridit`, the raw-`beta_T_val` fallback is actually the
*correct* truth here in principle — there's no structural estimand-scale
mismatch to fix by adding a `COVERAGE_MC_SPEC` entry. Adding one would be
a no-op at best (an MC-fitted truth would just re-derive `beta_T`).

## What remains unexplained

The near-universal-failure symptom is real and needs a different
explanation. Two candidate, unconfirmed directions:

1. **Quantile-regression SE finite-sample breakdown under this harness's
   DGP.** `SD_NOISE = 0.1` (`comprehensive_tests.R:834`) is very small —
   this is a near-noiseless location-shift model. `quantreg`'s Powell-style
   `"nid"` sandwich SE (this class's default, per its own docstring) is a
   kernel-density/sparsity-function estimator at the target quantile;
   such estimators are known to be sensitive to bandwidth choice and can
   misbehave when the residual distribution is very concentrated. This
   would explain the `asymp`/`wald` failures (both use the same sandwich
   SE) but not obviously the independently-implemented resampling-family
   failures — unless those also route through the same asymptotic SE
   machinery internally, not verified here.
2. **Compounding with `TODO-20`'s tie-sensitivity hypothesis**
   (`release_v1_0_5.md`, with-replacement bootstrap + quantile
   regression's simplex-method tie sensitivity) for the resampling-family
   methods specifically (`bootstrap`, `m_out_of_n_bootstrap`,
   `subsampling`, `rand_bootstrap` variants all fail here too) — plausible
   but not confirmed to be the same mechanism as TODO-20's original
   `InferenceContinKKQuantileRegrOneLik`/`InferencePropKKQuantileRegrOneLik`
   finding, since this class isn't a "OneLik"/KK class and has a
   structurally different (non-matched-pair) resampling path.

Neither direction was traced to an exact line or reproduced empirically —
this fork prioritized ruling out the higher-prior truth-mismatch
hypothesis over speculative SE-formula tracing, given the time budget.

## Follow-up investigation, 2026-09-24: hypothesis (2) refuted, hypothesis (1) narrowed but not confirmed at the DGP level

Re-read the per-`function_run` breakdown for every one of the 33 cells
(coverage number + over/under direction). Key data point: **the pure
asymptotic methods (`compute_asymp_confidence_interval`,
`compute_wald_confidence_interval`) show undercoverage too** — 0.911-0.924
for both `~1` and `~.`. These involve zero resampling. Since `TODO-20`'s
tie-sensitivity hypothesis only applies to with-replacement bootstrap
resampling, **it cannot be driving this on its own — direction (2) alone
is refuted as a sufficient explanation** (it may still be a compounding
factor for the resampling-specific methods, unconfirmed either way).

**TODO-3 resolved, confirming the shared-mechanism reading of direction
(1):** grepped `.extract_se_from_rq_fit()` (`R/EDI/R/helper_matching.R:172-190`,
the class's shared SE-extraction helper) and confirmed it is called from
**both** the main/observed fit (`inference_continuous_quantile_regr.R:290`,
feeding `asymp`/`wald`) **and** the bootstrap-weighted refit
(`inference_continuous_quantile_regr.R:134`, feeding
`jackknife_wald`/studentized-bootstrap-family/`symmetric-percentile-t`
variants) — always via `summary(fit, se = "nid")`, with an `"iid"`
fallback only on a bad/non-finite `"nid"` SE. This is a single, unguarded
shared code path, so every method that consumes this SE (not just plain
`asymp`/`wald`) inherits whatever miscalibration `"nid"` has under this
harness — a clean mechanistic explanation for why `studentized`-bootstrap
and `symmetric-percentile-t` variants fail alongside `asymp`/`wald`, while
purely percentile-based CI methods (`bca`, plain `bootstrap`/`rand_bootstrap`,
which don't consume this SE at all) instead show mild OVER-coverage — a
different, likely-benign phenomenon, not investigated further here.

**Standalone simulation (fresh script, not touching package internals):**
replicated the harness's simplest continuous DGP exactly (`n=100`,
Bernoulli 1:1 allocation, `y = 2 + 0.5*w + N(0, 0.1^2)`, `tau=0.5`,
`quantreg::rq(y ~ treatment + intercept - 1)`, 2000 reps) and compared the
reported `"nid"` SE against the empirical sampling SD of the estimator.
Result: **`"nid"` is well-calibrated under this simplest case** — mean
reported SE 0.0265 vs. empirical SD 0.0249 (ratio 1.065, mildly
conservative if anything), giving 0.954 empirical coverage of a naive
normal CI built from it. **This means the `"nid"` formula is not
inherently broken for a simple-random-sample, homoskedastic, linear-in-w
DGP** — the undercoverage seen in the real audit must come from something
my simplified simulation didn't reproduce.

**New leading candidate, NOT yet confirmed:** `audit_comprehensive_results.R`
deliberately pools across every EDI randomization `design` type into one
audit cell per `(class, formula, function_run)` (a documented, intentional
choice this session made — design shouldn't affect a correctly-implemented
resampling test's validity). But `"nid"` is an *asymptotic, iid-sampling*
sandwich estimator — it has no notion of EDI's non-Bernoulli designs
(matched-pair, blocked, KK-family, D-optimal, etc.), several of which
deliberately induce dependence between treatment assignment and
covariates/potential outcomes to reduce variance. If `"nid"`'s SE is
systematically wrong (in either direction) specifically under those
design types while correct under simple Bernoulli/iBCRD — which my
simulation, run only under simple 1:1 allocation, cannot distinguish from
"correct everywhere" — pooling them into one audit cell would produce
exactly the net-undercoverage signature observed, driven by a subset of
design types, not a universal breakdown. **Not tested**: a
design-stratified version of the simulation above (repeat under e.g. a
matched-pair or KK21 design and compare `"nid"` SE to empirical SD
specifically for that design) would confirm or refute this directly —
left as TODO-1 below.

**Conclusion: real, well-evidenced shared mechanism (TODO-3's question is
answered), but the actual trigger condition under EDI's real harness is
still not pinned down to an exact reproducible cause** — keeping this as
`investigate_*.md`, not renaming to `fix_*.md`, and NOT added to
`release_v1_5_0.md` per that file's "only confirmed bugs land here" bar.
This does not look like an inherent unfixable `quantreg` limitation
(the simple case is well-calibrated) — it looks like a real, specific,
findable trigger condition that just hasn't been isolated yet.

## Follow-up investigation, 2026-09-24 (second pass): TODO-1's design-pooling hypothesis REFUTED; new leading candidate found

Rather than a fresh simulation, computed coverage directly from the real
raw harness output (`R/package_tests/comprehensive_tests_results_nc_1_continuous.csv`,
which carries per-row `design`/`dataset` columns) for
`compute_asymp_confidence_interval`/`compute_wald_confidence_interval` at
`beta_T=0`, `model_formula=~1`.

**Stratifying by `design` alone refutes the hypothesis directly**: coverage
under plain `Bernoulli` (simple 1:1 random assignment, no matched-pair/
blocking structure at all) is 0.908-0.924 — essentially the same
undercoverage magnitude as `FixedBlocking` (0.875-0.920) and
`FixedMatchingGreedy` (0.891-0.942), the two most structurally different
non-Bernoulli designs. If "`nid` breaks under non-Bernoulli designs" were
the mechanism, `Bernoulli` should show near-nominal coverage while only
the structured designs fail — it does not. This directly contradicts the
TODO-1 hypothesis, which is now **refuted**.

**Cross-tabulating `dataset × design` jointly (counts + coverage) surfaces
a different, better-supported pattern**: coverage is noisy and inconsistent
across design types WITHIN a dataset (e.g. `pte_example`: `Bernoulli`=0.94,
`FixedMatchingGreedy`=0.88, `FixedBlocking`=0.96 — no consistent
ordering), but **`diamonds` and `pte_example` (the two largest, most
"real-world"/complex datasets) show worse coverage across nearly every
design they appear in than `ionosphere`/`iris`** (which are closer to
nominal or perfect). Since `model_formula=~1` means the fitted quantile
regression uses only an intercept + treatment indicator — no covariates —
this residual-distribution shape comes entirely from `diamonds`'s/
`pte_example`'s raw response distribution (price, a classically
right-skewed/heavy-tailed variable, for `diamonds`). `"nid"`'s sandwich SE
is a kernel-density/sparsity-function estimator evaluated at the target
quantile of the residual distribution — exactly the kind of estimator
known to be sensitive to skewness/heavy tails, unlike the near-Gaussian
`iris`/`ionosphere` residuals. This is a **dataset-shape hypothesis**, not
a design hypothesis: it predicts undercoverage tracks the response
variable's distributional shape (skew/kurtosis), not the randomization
mechanism.

**Not yet confirmed** — this is a strong, well-evidenced re-framing (the
design-pooling hypothesis is now cleanly closed) but the dataset-shape
hypothesis itself has not been directly tested (e.g. by computing
skewness/kurtosis per dataset and checking correlation with per-dataset
coverage, or by a fresh simulation with a skewed/heavy-tailed noise
distribution instead of `rnorm`). Kept as `investigate_*.md`, NOT added to
`release_v1_5_0.md` — no confirmed, fixable bug yet, just a substantially
narrowed and re-targeted open question.

## Follow-up investigation, 2026-09-24 (third pass): dataset-shape/skewness hypothesis REFUTED

Computed actual skewness/excess-kurtosis of each dataset's raw continuous
response variable (the exact value fed to `finagle_different_responses_from_continuous()`
before `scale()`, which doesn't change shape) via `moments::skewness()`/
`kurtosis()`:

| dataset | response | n | skewness | excess kurtosis |
|---|---|---|---|---|
| `diamonds` | `log(price)` | 53940 | **0.115** | **-1.097** |
| `pte_example` | `PTE::continuous_example$y` | 154 | -0.669 | -0.060 |
| `iris` | `Sepal.Width` | 150 | 0.316 | 0.181 |
| `ionosphere` | `Ionosphere$V3` | 351 | **-1.844** | **3.026** |

This **directly contradicts** the hypothesis as stated. `diamonds` — the
dataset previously identified as showing the *worst* coverage — has by far
the *least* extreme skew/kurtosis of the four (nearly symmetric after the
log-transform, and platykurtic/thin-tailed). `ionosphere` — previously
identified as showing *near-nominal* coverage — has by far the *most*
extreme skew (-1.84, more than 5x diamonds' magnitude) and heavy tails
(excess kurtosis +3.03, vs. diamonds' -1.10). If raw-response
skewness/kurtosis droze `"nid"`'s undercoverage, the ranking should run the
opposite direction. It does not. **Hypothesis (dataset response-shape
sensitivity of `"nid"`) is REFUTED.**

(Live per-dataset coverage could not be recomputed this pass to double-check
the previously-reported numbers themselves — `comprehensive_tests_results_nc_1_continuous.csv`
currently has **zero rows** for `InferenceContinQuantileRegr` at all,
confirming the previous fork's note that concurrent sessions are actively
rewriting this file. The skewness/kurtosis measurements above are
dataset-property facts independent of harness state, so the refutation
stands regardless; it rests on the earlier fork's own documented
per-dataset coverage table, which is the best record currently available.)

**Root cause remains open — both leading hypotheses (design-pooling,
dataset-shape) are now refuted.** What's left unexplained: `diamonds` and
`pte_example` showing worse coverage than `iris`/`ionosphere` for some OTHER
reason not yet identified. Candidate directions not yet explored: dataset
size/effective-n differences after `slice_sample(n=148, replace=TRUE)` (note
`ionosphere` n=351 is NOT downsampled the same way — check whether the
`max_n_dataset=148` resampling itself, or resulting duplicate-row density,
differs meaningfully by dataset and interacts with `"nid"`'s
sparsity-density estimator, which is sensitive to tied/duplicated
observations, not just to distributional shape); or something dataset-
specific in how `quantreg::rq()` handles near-degenerate designs under
`~1` when the underlying response has many exact ties post-rounding/
resampling (with-replacement resampling to n=148 from ionosphere's smaller
n=351 population would create real duplicate rows, plausibly relevant given
this class's known tie-sensitivity via `TODO-20`/`TODO-3` above — but this
would need directly checking each dataset's actual tie/duplicate rate in the
sampled data, not yet done).

**Not fixable/inherent determination possible yet** — no confirmed mechanism.
Kept as `investigate_*.md`. **Not added to `release_v1_5_0.md`** — two
refuted hypotheses in a row is real progress (narrows the search space) but
is not a confirmed, fixable bug.

## TODOs

- [x] TODO-1 (RESOLVED 2026-09-24, REFUTED): design-pooling is not the
  driver — `Bernoulli`-design coverage is just as bad as structured
  designs (0.908-0.924 vs. 0.875-0.942), computed directly from real
  harness data, not a fresh simulation. See follow-up section above.
- [x] TODO-2 (RESOLVED 2026-09-24, REFUTED): tested the dataset-shape
  hypothesis directly via real `moments::skewness()`/`kurtosis()` on each
  dataset's raw response — `diamonds` (previously worst coverage) is the
  LEAST skewed/most platykurtic of the 4; `ionosphere` (previously
  near-nominal coverage) is by far the MOST skewed/leptokurtic. Opposite
  of the predicted ranking. See "Follow-up investigation, third pass"
  above. New candidate directions (tie/duplicate density from
  with-replacement resampling to n=148, not yet checked per-dataset) noted
  there — TODO-5 below.
- [ ] TODO-5 (added 2026-09-24): check each dataset's actual duplicate/tied-
  value rate in the harness's resampled (`n=148`, with replacement) draw of
  the continuous response — `ionosphere`'s native n=351 means resampling to
  148 creates real duplicates at a different rate than `diamonds`'s n=53940
  (near-zero duplicate rate even after resampling). Given this class's
  established tie-sensitivity (`TODO-20`, `TODO-3` above), a tie-driven
  mechanism plausibly explains the dataset-level pattern where a pure
  response-shape mechanism does not — untested.
- [ ] TODO-3 (RESOLVED 2026-09-24, see above): confirmed the resampling
  `studentized`/`symmetric-percentile-t` methods share the exact same
  `"nid"`-based SE machinery as `asymp`/`wald`, via
  `.extract_se_from_rq_fit()` (`R/EDI/R/helper_matching.R:172-190`),
  called from both the main fit and the bootstrap-weighted refit. This
  refutes TODO-20's tie-sensitivity hypothesis as a SUFFICIENT
  explanation (asymp/wald involve no resampling at all) while not ruling
  it out as a possible compounding factor for the bootstrap-only methods.
- [ ] TODO-4: Confirm this class is unaffected by `TODO-28`
  (`cached_design_matrix` staleness) — not checked. Given the failure
  spans `asymp`/`wald` (non-bootstrap) too, TODO-28 alone cannot be the
  whole explanation even if it partially applies to the bootstrap-family
  subset, but should still be ruled in/out for completeness.

## Standing constraints

No `R CMD INSTALL`/rebuild of `R/EDI` without being asked in that turn;
verify via `pkgload::load_all(".", compile = FALSE)` only.
