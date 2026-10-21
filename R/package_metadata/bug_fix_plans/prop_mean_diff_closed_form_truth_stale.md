# Fix plan: proportion mean-diff closed-form coverage truth is stale relative to the 2026-09-15 DGP fix

> **TODO-55 status: core fix implemented 2026-10-07; release follow-up open.**
> The closed-form mean-difference
> truth now uses the same clamped-baseline logit shift as the proportion DGP.
> The audit also confirmed a separate truth mismatch for proportion
> `InferenceAllSimpleWilcox`; it now uses a response-qualified Monte Carlo
> fitted truth because its Hodges-Lehmann estimand has no mean-difference
> closed form. Targeted reference tests and stale-row rules were added. Raw
> result CSVs were deliberately left untouched for the next harness run.

Found 2026-09-25, investigated at user request while checking other proportion
classes for the pattern behind `mc_coverage_truth_covariate_mismatch.md`'s
TODO-11. Not the same bug -- this one uses the `COVERAGE_CLOSED_FORM` path,
not the Monte-Carlo path, and is more severe (0.00-0.33 coverage on affected
rows, not ~0.80).

## Symptom

`InferenceAllSimpleAverageDiff`, `InferenceAllSimpleMeanDiffPooledVar`, and
`InferencePropGCompMeanDiff` show near-zero coverage on `boston` (0.00, 0.00,
0.00 respectively, hundreds of rows each) at `beta_T = 0.5`, while showing
0.95-0.97 on `diamonds` and (mostly) `abalone`. Every CI method for a given
(class, dataset) agrees closely with every other method -- e.g. on
`AllSimpleAverageDiff`/`boston`, `asymp`/`wald`/`bootstrap`/`bootstrap_bca`/
`subsampling`/`bayesian_bootstrap` all return intervals in `[0.04, 0.17]`,
consistently -- so the CIs are not independently broken; they're all being
graded against the same wrong reference value.

## Root cause (before the 2026-10-07 fix)

`compute_prop_mean_diff_coverage_truth()` (`comprehensive_tests.R:3191`):

```r
compute_prop_mean_diff_coverage_truth = function(dataset_name, beta_T_val){
	y_p = datasets_and_response_models[[dataset_name]]$y_original$proportion
	mu_c = y_p
	mu_t = pmin(1, pmax(0, y_p + beta_T_val))
	mean(mu_t - mu_c)
}
```

computed the truth as a **raw additive shift clamped to [0, 1]**. But the
actual proportion DGP, `apply_treatment_effect_and_noise()`
(`comprehensive_tests.R:3128-3130`), was fixed on 2026-09-15 (per its own
code comment) to shift on the **logit scale**, with the baseline clamped to
`[0.05, 0.95]` first:

```r
p_base = pmin(0.95, pmax(0.05, y_t))
p_t = plogis(qlogis(p_base) + bt + eps)
```

specifically to avoid the boundary-clamping distortion a raw additive shift
causes. The truth function had never been updated to match and still
implemented the pre-fix formula. The sibling incidence function,
`incid_p_base_and_treated()` (`comprehensive_tests.R:3170-3174`), already
implements the *correct* pattern (`pmin(0.95, pmax(0.05, ...))` +
`plogis(qlogis(...) + beta_T_val)`); this looks like an omission when the
2026-09-15 fix was applied -- the incidence-side closed forms were updated
(or already correct) and the proportion mean-diff one was missed.

## Why some datasets look unaffected

Checked row timestamps directly: `diamonds` rows (2026-08-24 to 09-21, but
the ones checked here from before 09-13) and most `abalone` rows (09-02) for
these classes predate the 2026-09-15 DGP fix -- they are self-consistently
generated *and* graded under the old (raw-additive) DGP, so they coincidentally
pass. `boston`'s rows (09-15/09-16) are entirely post-fix: generated under the
corrected logit-scale DGP, graded against the still-uncorrected truth formula.
`AllSimpleMeanDiffPooledVar`/`abalone` (0.00 despite predating 09-15) is a
separate, already-diagnosed staleness layer -- those specific rows also
predate the 2026-09-06 fix that added `InferenceAllSimpleMeanDiffPooledVar`
to the `COVERAGE_CLOSED_FORM` fallback at all (see that fix's own code
comment at `comprehensive_tests.R:3200-3210`ish); before that fix this class
fell back to raw `beta_T_val` as truth, a third, compounding staleness.

## Verified

Directly recomputed the truth both ways for `boston` (`beta_T=0.5`):

| formula | truth |
|---|---|
| stale (raw additive, pre-fix code) | 0.466 |
| corrected (logit-scale, matching the actual DGP) | 0.112 |
| real per-row estimate (n=122) | mean 0.109, median 0.108, SD 0.021 |

The corrected formula matches the real estimator's behavior almost exactly;
the stale one is 17+ SDs off.

## Fix (implemented 2026-10-07)

Replaced `compute_prop_mean_diff_coverage_truth()`'s body with the same
pattern `incid_p_base_and_treated()` already uses:

```r
compute_prop_mean_diff_coverage_truth = function(dataset_name, beta_T_val){
	y_p = datasets_and_response_models[[dataset_name]]$y_original$proportion
	p_base = pmin(0.95, pmax(0.05, y_p))
	p_t = stats::plogis(stats::qlogis(p_base) + beta_T_val)
	mean(p_t - p_base)
}
```

Test-harness-only change; does not touch `R/EDI` source.

The implementation also qualifies MC truth specifications by response type.
This lets `InferenceAllSimpleWilcox__proportion` use the existing
`compute_mc_coverage_truth_simframe()` route while its continuous, incidence,
count, survival, and ordinal runs retain their existing native-scale truth.
The coverage-truth cache key now includes the response type so a generic class
can never reuse a truth fit from another response family.

## Completed audit

- `InferenceAllSimpleAverageDiff` on proportion and
  `InferencePropGCompMeanDiff` directly reference
  `compute_prop_mean_diff_coverage_truth()`.
- `InferenceAllSimpleMeanDiffPooledVar` reaches the same function through
  `get_coverage_truth()`'s response-family fallback. All three therefore use
  the corrected closed form.
- `InferenceAllSimpleWilcox` did not share the function. It fell through to
  raw `beta_T_val`, which is also wrong for the logit-scale proportion DGP:
  its Hodges-Lehmann estimand is a median of pairwise treated-minus-control
  differences. Because heterogeneous baselines and Gaussian DGP noise leave
  no suitable mean-difference closed form, only the proportion variant now
  uses an MC-refitted truth.
- `InferenceIncidGCompRiskDiff` and `InferenceIncidKKGCompRiskDiff` already
  route through `incid_p_base_and_treated()` and
  `compute_incid_risk_diff_coverage_truth()`. That path clamps baseline risk
  to `[0.05, 0.95]`, applies the logit shift, and averages the risk
  difference, matching the incidence DGP. No incidence change or stale-row
  rule is justified by TODO-55.
- The other direct mean-difference mapping is the survival AverageDiff
  closed form. It uses the survival DGP's multiplicative time shift and is
  unrelated.

`test-comprehensive-proportion-coverage-truth-reference.R` independently
constructs the treated probability through an odds multiplication (rather
than copying the implementation's `qlogis`/`plogis` expression), verifies
all three mean-difference dispatch paths, checks both incidence GComp
siblings, and proves the Wilcox MC route is proportion-only.

**Estimand semantics question (2026-10-18; resolved by the 2026-10-21 owner
decision below):**
the comprehensive proportion DGP draws `eps ~ N(0, SD_NOISE)` with
`SD_NOISE = 0.1` and applies it inside `plogis(qlogis(p_base) + bt + eps)`.
The closed-form truth and its independent reference currently omit `eps`, so
they compute the clamped-baseline, zero-noise logit-shift contrast. The exact
marginal mean contrast under the noisy DGP would instead integrate the
logistic-normal response over `eps` and need not equal that closed form.
At the time of this note, the coverage estimand had not yet been selected.
The owner resolved the choice on 2026-10-21 in favor of the noisy marginal
mean; see the decision and implementation record below. The earlier closed
form was the zero-noise conditional contrast, not an exact marginal
expectation under the full noisy DGP.

**Illustrative analytic sensitivity only (2026-10-20; prepared before the
estimand decision):**
to show the scale of the noise distinction without using dataset rows, the
following Gaussian-quadrature calculation compared the zero-noise contrast
with the logistic-normal marginal contrast at representative fixed baseline
probabilities `p = {0.1, 0.2, 0.5, 0.8, 0.9}`, treatment log-odds shift
`beta = 0.5`, and Gaussian noise SD `0.1`. For each `p`, the zero-noise value
is `plogis(qlogis(p) + beta) - p`; the marginal value is
`integral[plogis(qlogis(p) + beta + z) - plogis(qlogis(p) + z)] phi(z; 0, 0.1)
dz`, evaluated with base R `integrate()` over `(-Inf, Inf)` at `rel.tol =
1e-12`. The resulting `(p, zero-noise, noisy marginal, marginal-minus-zero)`
values were:

| p | zero-noise | noisy marginal | marginal-minus-zero |
|---:|---:|---:|---:|
| 0.1 | 0.05482809896 | 0.05491920733 | 0.00009110837 |
| 0.2 | 0.09187513274 | 0.09182481165 | -0.00005032109 |
| 0.5 | 0.12245933120 | 0.12217284861 | -0.00028648260 |
| 0.8 | 0.06833243833 | 0.06839061025 | 0.00005817192 |
| 0.9 | 0.03686267382 | 0.03696400487 | 0.00010133105 |

Reproduction (R):

```r
plogis_marginal <- function(p, beta, sd = 0.1) {
  integrate(function(z) plogis(qlogis(p) + beta + z) * dnorm(z, 0, sd),
            -Inf, Inf, rel.tol = 1e-12)$value
}
ps <- c(0.1, 0.2, 0.5, 0.8, 0.9)
beta <- 0.5
data.frame(
  p = ps,
  zero_noise = plogis(qlogis(ps) + beta) - ps,
  noisy_marginal = vapply(ps, function(p) {
    plogis_marginal(p, beta) - plogis_marginal(p, 0)
  }, numeric(1))
)
```

These are pointwise sensitivity values for selected fixed probabilities,
not a dataset-weighted truth calculation or a rerun of the comprehensive
DGP. The owner subsequently selected the noisy marginal estimand below; these
figures quantify the scale and baseline-dependent direction of its
difference from the former zero-noise conditional contrast in this
illustrative setting.

**Pure-R candidate-oracle regression, 2026-10-20:** the existing focused
coverage-truth test now independently evaluates the noisy-marginal candidate
by integrating the treated and control logistic-normal means at the five
representative baseline probabilities above, and checks them against the
retained quadrature values. At the time, the source exposed only the
zero-noise closed form; this test added no marginal-truth API and did not
select or change the default estimand. The full focused file passed 26
assertions with checkout R loaded using
`pkgload::load_all("R/EDI", compile = FALSE)`; this
test is pure R and does not run simulations or call native code. The maintainer
decision was recorded the following day; comprehensive-row
regeneration/re-audit remains open.

## TODO

1. [x] Apply the fix above once it's safe to edit `comprehensive_tests.R`
   (not mid-run).
2. [x] Add `stale_ok_row_rules.csv` rules to expire the affected pre-fix rows
   for `AllSimpleAverageDiff`/`AllSimpleMeanDiffPooledVar`/`PropGCompMeanDiff`
   on every dataset (they were generated under the wrong DGP, not just
   graded with the wrong truth -- unlike TODO-11's classes, these need
   full regeneration, not just a re-audit, since the raw response values
   themselves came from the old DGP).
3. [x] Check whether `InferenceAllSimpleWilcox` (also showing low coverage on
   `boston`/`abalone`/`diamonds`, e.g. 0.12-0.33) shares this bug or has an
   unrelated cause -- Wilcox's estimand is rank/median-based, not a mean
   difference, so `compute_prop_mean_diff_coverage_truth` may never have
   been the right truth for it even before this bug. Confirmed as a separate
   raw-`beta_T_val` truth mismatch and routed through proportion-only MC
   truth; its pre-fix rows are included in the stale-row rules.
4. [x] Check `InferenceIncidGCompRiskDiff`/`InferenceIncidKKGCompRiskDiff` and
   any other class sharing `compute_prop_mean_diff_coverage_truth` or a
   similarly-shaped closed form for the same "DGP changed, truth function
   didn't" pattern. The incidence paths already match their DGP; no change.
5. [ ] Re-audit and prune `comprehensive_results_audit_baseline.csv` for
   findings this closes after the comprehensive rows regenerate.

   Focused installed-package validation on 2026-10-14 passed all 18
   assertions in `test-comprehensive-proportion-coverage-truth-reference.R`.
   **Current-source recheck 2026-10-18:** after
   `pkgload::load_all("R/EDI", compile = FALSE)` at checkout HEAD
   `efdc1b4ebe07c6dc3aadba713b5f5fe0722fdfe1`, the same test passed all 18
   assertions with 0 failures, warnings, or skips. The installed package was
   EDI 1.0.3; its `EDI.so` at
   `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI/libs/EDI.so` and
   the DLL loaded by `pkgload` had matching MD5
   `dd43c5d0e11708aea17ba82b900f66d1`. This focused harness-truth test does
   not call native code and is not validation of release TODO-10's separate
   ordinal MC-truth dispatch.
   **Current-source recheck 2026-10-20:** after
   `pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE, export_all = FALSE)`
   at checkout HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9`, the focused
   test again passed all 18 assertions with no failures, warnings, or skips.
   The loaded namespace path was the checkout `R/EDI`; pkgload used a
   temporary copy of existing EDI 1.0.3 native `EDI.so`. Checkout
   `R/EDI/src/EDI.so` and installed
   `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI/libs/EDI.so` have
   matching SHA-256 `5a0b94978e5d9150d2aa6f69df7135a164fe032b3a3e301495c5cfd7f6ca3224`.
   The test itself extracts and evaluates only named R assignments from the
   checkout harness; it does not call native code. No build/install or
   canonical regeneration occurred. This recheck predates the 2026-10-21
   owner decision selecting noisy marginal truth; comprehensive-row
   regeneration and audit-baseline pruning remain open.
   Then a two-replicate comprehensive replay on `boston` at `beta_T=0.5`
   regenerated 20 Wald result rows spanning both design formulas for
   `InferenceAllSimpleAverageDiff`, `InferenceAllSimpleMeanDiffPooledVar`,
   `InferencePropGCompMeanDiff`, and `InferencePropWilcox`. The regenerated
   confidence-interval rows use the corrected proportion truth (0.1115437).
   This scoped replay is a smoke check only: it writes a filtered result CSV,
   not the canonical `comprehensive_tests_results_nc_1_proportion.csv` that
   the baseline audit consumes, and does not regenerate the full set of
   historical rows invalidated by the stale-row rules. TODO 5 therefore
   remains open pending the full row regeneration and baseline re-audit.

**Candidate-estimand regression, 2026-10-20 (before the owner decision):**
the existing focused test
`R/package_tests/testthat_bulk/test-comprehensive-proportion-coverage-truth-reference.R`
at that time verified that `record_result()` graded a CI against the
then-selected zero-noise coverage truth rather than `beta_T`, and independently computed a
noisy logistic-normal marginal candidate by quadrature at five fixed baseline
probabilities. The complete file passed 26 expectations with
`pkgload::load_all("R/EDI", compile = FALSE, export_all = FALSE)`; no failures,
warnings, or skips. This pure-R test is decision-support only: it adds no
marginal-truth API and did not choose or change the default estimand. The
owner subsequently selected noisy marginal truth, as recorded below; full
proportion-row regeneration and baseline re-audit/pruning remain open.

Independent of `mc_coverage_truth_covariate_mismatch.md`'s TODO-6/TODO-11
(different mechanism, different classes) -- do not conflate when resolving
either.

## Owner decision 2026-10-21: noisy marginal truth

The estimand question (zero-noise conditional vs noisy marginal) is settled:
coverage truth is the **noisy marginal** mean contrast, because the DGP adds
`N(0, SD_NOISE)` logit noise in both arms and the estimator is a difference
of observed proportion means. `compute_prop_mean_diff_coverage_truth()` in
`comprehensive_tests.R` now integrates the noise with `prop_logistic_normal_mean()`
(40-node Gauss-Hermite). It differs from the earlier zero-noise form by at
most ~3e-4 at `SD_NOISE = 0.1`, so the earlier 0.466-vs-0.112 `boston` finding
is unaffected. The focused test pins the new truth against an independent
`integrate()` oracle (28 assertions pass). Proportion-row regeneration and the
baseline re-audit remain open.

**Retained-artifact audit, 2026-10-21:** the canonical proportion results
(2026-10-09), broad affected-class filtered results (2026-10-09), and Boston
Wald smoke output (2026-10-14) all predate this owner decision. The retained
`/tmp/edi-todo55-sweep`, `-isolated`, and `-smoke` snapshots/outputs are dated
2026-10-16 and also predate it; none can close regeneration under the selected
noisy-marginal truth. The baseline snapshot in the isolated directory is also
not a post-regeneration audit. The existing independent-reference test was
rerun after confirming no active R/Rscript process; it passed 28 expectations
under a 60-second cap without build/install. That bounded test validates the
helper/oracle and CI-grading fixture, not comprehensive output rows. Canonical
results remain untouched; full row regeneration followed by baseline
re-audit/pruning is still required.

**Owner-decision regression follow-up, 2026-10-21:** the existing focused
test now checks that `record_result()` stores the selected noisy-marginal
coverage truth using an independent `integrate()` oracle at the fixture's
`SD_NOISE=0.1`; the zero-noise override was removed. The retained five-point
quadrature fixture also compares the selected helper against its independent
reference values. `Rscript -e
'testthat::test_file("R/package_tests/testthat_bulk/test-comprehensive-proportion-coverage-truth-reference.R")'`
passed 29 expectations with no failures, warnings, or skips. This pure-R
test runs with installed EDI 1.0.3 loaded while extracting only the named
current checkout harness assignments; its attempt-event writer is stubbed,
so it validates coverage-truth persistence/grading but not event-ledger
behavior. No compilation, installation, comprehensive run, or canonical
write occurred. The test is already registered in the bulk correctness and
coverage tiers. This closes only the focused truth-to-row regression; full
affected-row regeneration and baseline re-audit/pruning remain open.

**Resume-cache invalidation correction, 2026-10-21:** the existing TODO-55
`stale_ok_row_rules.csv` cutoffs were `2026-10-08`, but the pruner removes
only successful rows whose date is strictly before the cutoff. Consequently,
the canonical 2026-10-09 rows survived and would remain eligible in the
completed-row cache after the 2026-10-21 noisy-marginal decision. All four
TODO-55 class-wide rules now use `before_timestamp=2026-10-22`, covering all
prior function runs for the three mean-difference classes and proportion
Wilcox. The existing pruning safety fixture now reads those actual rules and
verifies that 2026-10-09 and 2026-10-21 rows are expired while 2026-10-22
cutoff-day rows remain. Its focused command
`Rscript -e 'testthat::test_file("R/package_tests/testthat_bulk/test-prune-stale-result-rows-safety-reference.R")'`
passed 18 expectations (no failures, warnings, or skips) using only synthetic
temporary CSVs/repository state. No canonical result was pruned or written.
Because the cutoff is date-granular, run the new regeneration on or after
2026-10-22 so newly generated selected-truth rows are outside the stale
window. The runner timestamps rows with `format(Sys.time(), ...)` without an
explicit timezone, and the pruner compares only `substr(timestamp, 1, 10)`;
therefore this is the R process's local calendar date, not a UTC instant.
Before starting, verify that the actual run process reports local date
2026-10-22 or later and record its timezone alongside run provenance. The test's
2026-10-22 00:00:00 fixture is intentionally the inclusive boundary: all rows
on that local date survive, while all earlier local dates are expired. Full
regeneration and baseline re-audit/pruning remain open.

**Retained-artifact inventory, 2026-10-21:** the canonical filtered artifact
`R/package_tests/comprehensive_tests_results_nc_1_proportion_filtered_class-Inference_AllSimpleAverageDiff_AllSimpleMeanDiffPooledVar_PropGCompMeanDiff_AllSimpleWilcox.csv`
contains 140,960 unique rows for the four affected classes: 43,998
`InferenceAllSimpleAverageDiff`, 7,585 `InferenceAllSimpleMeanDiffPooledVar`,
69,643 `InferencePropGCompMeanDiff`, and 19,734 proportion
`InferenceAllSimpleWilcox`. Every row has `status=ok`, no duplicate ID, and
timestamp 2026-10-09, so all precede the 2026-10-22 cutoff; no provenance
sidecar was found. The broader `comprehensive_tests_results_nc_1_proportion.csv`
does not contain these class names. The retained `/tmp/edi-todo13-*` inventory
has 29 PropGComp-only CSVs (3,120 rows, 1,740 unique IDs, 1,380 repeated
occurrences); all are `status=ok` and dated 2026-10-20 or 2026-10-21. Only 28
have sidecars; those recorded CSV hashes match, but their receipts span six
runner/payload/DLL/HEAD identity cohorts. The remaining pilot CSV has no
sidecar. These pilots are incomplete and pre-cutoff, and do not establish
post-decision provenance for any of the other three classes. No run, canonical
write, or pruning occurred for this inventory. The remaining gate is a fresh,
isolated, exact-key/value-validated four-class regeneration on or after the
R process's local 2026-10-22 date, with timezone and matching current
coverage-truth/package/DLL provenance captured, followed by baseline re-audit
and pruning only of findings resolved by those rows.
