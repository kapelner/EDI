# Investigation: Randomization p-Values Under `DesignSeqOneByOneKK21stepwise` Are Conservative at the Null (Incidence)

> **Depends on:** none. (Global ordering: see `../new_feature_plans/_master.md`.) Slated for
> `../future_release_plans/release_v1_0_5.md → TODO-53`. Added 2026-09-24
> from the triage of the stale-cache regeneration findings
> (`stale_worker_cache_resampling.md`, TODO-7). **Status 2026-10-20:** the
> replay defect is fixed and the owner accepted the approximate stepwise default
> on the paired simulation below. Open follow-up: the Zhang-dispatch question.

## The finding

Under a true null and `DesignSeqOneByOneKK21stepwise` with an incidence
response (n = 148, one covariate, `r = 151`), the randomization p-value is
super-uniform: 60 fresh simulations gave **0 rejections at 0.05, median p
0.71, mean p 0.66** (uniform would give about 0.5 / 0.5 and about 5%
rejections). The existing comprehensive-test rows say the same: 0/80 null
rejections for `InferenceIncidKKGCompRiskDiff` (median p 0.62).

`InferenceAllSimpleAverageDiff`'s randomization p-value on the same data is
identical (median 0.71, mean 0.66), and `InferenceIncidKKGCompRiskDiff`
returns the same p-values, so the cause is shared: the KK21stepwise design
replay (`draw_ws_according_to_design()`), the randomization loop for KK
designs, or the shared estimate/tie handling, not a class-specific fit. For
comparison the same test under `DesignFixedBernoulli` is not conservative
(reject 0.033 with 60 reps).

The power cost is visible: at `beta_T = 0.5` the KK randomization test rejects
0.183 versus 0.317 for the conditional-logit Wald test on the same data.

## First measurement (2026-09-24)

Under the same null, over 80 fresh KK21stepwise designs (n = 148), the
empirical standard deviation of `InferenceAllSimpleAverageDiff`'s estimate was
0.0741 while the mean standard deviation of its randomization distribution
(`r = 151`) was 0.0817, a ratio of **1.10**; the distribution is centred at
-0.0003 (the estimator's own mean is 0.0124, standard error about 0.008). So
the randomization draws are about 10% more variable than the design's true
sampling distribution. That is a modest excess and does not by itself explain
a mean p of 0.66, but it points at TODO-1 (replay fidelity) as the place to
look first, and it says the conservatism is a width problem rather than a
location problem.

## Items

- [x] **TODO-1: Check the replay is faithful.** Compare the distribution of
  the randomization draws' allocations (match structure, arm balance) against
  fresh runs of the design on the same covariates. A replay that is
  systematically more variable than the real design widens the reference
  distribution and inflates p.
- [x] **TODO-2: Rule out tie/discreteness effects.** With an incidence
  response the statistic is discrete; check how ties with the observed
  statistic are counted (`>=` versus `>`), and whether the match-structure
  (pairs + reservoir) combination produces a mass at the observed value.
- [x] **TODO-3: Same check for other KK21stepwise response types**
  (continuous, count) to see whether the conservatism is incidence-specific.
- [x] **TODO-4: Decide.** If it is a design-replay defect, fix it and
  regenerate; if it is inherent (the test is exact for the sequential design
  and merely discrete), document it and stop chasing the audit flag.

## Resolution 2026-10-09

**A replay defect was confirmed and fixed.** `DesignSeqOneByOneKK21` and its
stepwise subclass inherited KK14's `draw_ws_raw()`, which conditions every
draw on the one realized match vector `m`. That is valid for KK14 because its
covariate-only pair formation does not depend on treatment assignments. It is
not a faithful replay for KK21: its covariate weights use preceding outcomes
and assignments, so a different assignment path can create different pairs.
On a deterministic incidence fixture (`n = 60`), the inherited path fixed the
pair count at the observed 24. Full sequential replay averaged 25.08 pairs
(SD 1.13), matching 60 independently rerun designs at 25.17 (SD 1.11);
treatment-count SDs were likewise 1.59 versus 1.68 for fresh designs. The new
private replay resets assignment/match state, reveals only responses observed
before each assignment, recomputes outcome-adaptive weights and pairs, and
restores the completed design on exit.

**The original incidence conservatism is mostly discrete exact-test behavior,
not evidence for another defect.** A separate null calibration compared full
replay with the legacy fixed-pair draw over 30 incidence experiments (`n = 60`,
199 draws each). Full replay rejected 3.3%, with median p 0.648 and mean p
0.613; legacy draws gave the same rejection rate, median 0.643 and mean 0.609.
Exact ties averaged 3.50% of each reference distribution (maximum 8.04%).
Changing the inclusive exact tails (`>=`/`<=`) to strict tails lowered mean p
to 0.544; the mid-p rule gave 0.579. Those alternatives gain power by giving
up the current finite-sample exact/conservative convention, so the inclusive
rule remains unchanged.

**The response-type comparison separates replay from discreteness.** In the
same calibration shape, continuous outcomes had no ties and full replay moved
the mean/median p-values to 0.529/0.553 (legacy 0.549/0.643). Count outcomes
had 1.17% mean tie mass and full-replay mean/median 0.542/0.603 (legacy
0.545/0.633). Thus the replay bug affects all outcome-adaptive KK21 families,
while the unusually large remaining shift for incidence is explained by its
coarser statistic. A focused regression with
`condition_on_ws_for_rand_tests = FALSE` covers incidence, continuous and
count, proves exact replay draws no longer condition on every realized pair,
and verifies all completed-design state is restored. Separate tests cover the
default pair-conditioned behavior. The permutation and seed suites were
reported to pass 90 assertions with `pkgload::load_all(..., compile = FALSE)`;
that historical count has not been re-measured here.

## Contract reconciliation 2026-10-20

The replay correction is not the default behavior for
`DesignSeqOneByOneKK21stepwise`. Its constructor defaults
`condition_on_ws_for_rand_tests = TRUE`, which uses the fast KK14-style
realized-pair redraw and is documented in the class roxygen as approximate.
Setting it to `FALSE` replays the full sequential rule and refits the
stepwise weights along each assignment path; this is the slower exact option.
Plain `DesignSeqOneByOneKK21` remains a separate case: its marginal weights do
not depend on assignment, so realized-pair conditioning is exact there.

The existing permutation tests exercise the stepwise exact option across
incidence, continuous, and count outcomes, and separately check that the
default stepwise path conditions on realized pairs. No source/test change was
needed for this reconciliation. The remaining product decision is whether
the approximate stepwise default is acceptable for the v1.0.5 release; the
historical exact-replay calibration must not be presented as calibration of
that default. No tail/tie rule change is proposed: inclusive tails retain the
finite-sample conservative convention.

## Focused permutation-suite recheck 2026-10-20

The installed EDI 1.0.3 run passed 117 assertions. A current-checkout
source-loaded rerun with `pkgload::load_all("R/EDI", compile = FALSE,
quiet = TRUE)` also passed 117 assertions (0 failures, warnings, or skips).
Its loaded native artifact was
`/tmp/RtmpaNk2wz/pkgload5280e41417f1b/EDI.so`, MD5
`dfd5bf4384b5a0cc0d430fd70dab2a59`; no checkout compilation occurred. The
historical 90-assertion report predates commit `39e3ca04`, which added two
default pair-conditioning tests to this file (53 net lines), so the difference
is an inventory/version difference rather than a current test failure. This
does not validate current-checkout native code or reproduce the historical
calibration. The suite covers exact opt-in replay and approximate default
behavior, but does not decide whether that default is acceptable for release.
TODO-53 remains open pending the owner decision.

## Default-vs-exact comparison and owner decision 2026-10-20

Paired null simulation (recompiled install): n = 148, one covariate, incidence
outcome depending on the covariate, no treatment effect, r = 151, 200
experiments. Same data, same observed design (the flag does not change the
assignments) and same draw seed in both arms; statistic = mean difference
computed directly from `draw_ws_according_to_design()` with inclusive tails.

| | reject .05 | reject .10 | mean p | median p |
|---|---|---|---|---|
| `condition_on_ws_for_rand_tests = TRUE` (default) | 0.030 | 0.085 | 0.550 | 0.579 |
| `FALSE` (exact replay) | 0.030 | 0.090 | 0.542 | 0.556 |
| `TRUE`, mid-p | 0.035 | 0.095 | 0.531 | 0.554 |
| `FALSE`, mid-p | 0.035 | 0.095 | 0.524 | 0.531 |

Paired p-value correlation 0.986 (mean difference -0.008, SD 0.048); mean SD
of the reference draws 0.0797 (`TRUE`) vs 0.0792 (`FALSE`); tie mass about 4%.
Mid-p is near uniform under both (KS p = 0.17 / 0.25). The approximation is
indistinguishable from exact replay in this configuration, so the owner
accepted the approximate default. Limits: one configuration, one covariate,
one statistic, incidence only; +/-0.03 binomial half-width on the rejection
rate.

**Zhang dispatch finding (open, separate from this decision).** The original
60-null incidence result (median p 0.71, identical for
`InferenceAllSimpleAverageDiff` and `InferenceIncidKKGCompRiskDiff`) is
consistent with the Zhang exact combined test, not the design draws:
`compute_rand_two_sided_pval()` returns it when
`should_use_zhang_incidence_randomization()` is TRUE (incidence, no custom
statistic, Bernoulli or matched design, class composes `InferenceRandCI`). On
the TODO-53 fixture it is TRUE and the p-value is bit-identical (0.7483772)
under `TRUE` and `FALSE`. The owner states binary-response rand tests should
draw `w` vectors rather than use Zhang; reversing the 2026-08-23 dispatch would
change `compute_rand_two_sided_pval()` and `compute_rand_confidence_interval()`
and three pinned tests
(`test-incidence-classes-rand-two-sided-pval-zhang-eligible-dispatch-sweep-reference.R`,
`test-incid-wald-cmh-rand-two-sided-pval-zhang-eligible-dispatch-reference.R`,
`test-rand-two-sided-pval-incidence-non-zhang-eligible-unsupported-guard-reference.R`).
**Verified and resolved 2026-10-20.** On the same 200 experiments the
public-API p-value (Zhang path) gave reject@0.05 0.010, @0.10 0.020, mean
0.723, median 0.816 (correlation 0.70 with the draw-based p-values), which is
the original finding; the draws give 0.030/0.085/0.550/0.579. The owner decided
`compute_rand_two_sided_pval()` must always use the `w` draws; the dispatch was
removed (release_v1_0_5.md TODO-99).

**Wide class/dispatch regression, 2026-10-20:**
`test-incidence-classes-rand-two-sided-pval-zhang-eligible-dispatch-sweep-reference.R`
passed 30 expectations with checkout R loaded using
`pkgload::load_all("R/EDI", compile = FALSE)` against the user's freshly
rebuilt native library. Across six Zhang-eligible classes on Bernoulli and
KK14 designs, the test checks finite reproducible draw-based p-values, refusal
of nonzero incidence shifts, and continued explicit `type = "Zhang"` access.
The native DLL SHA-256 was
`db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`.
This closes the wide focused-dispatch-test gate only; regenerating and
reconciling the comprehensive incidence `rand` rows remains open. No CI
change is required because incidence randomization CIs remain disabled.

**Post-reinstall installed-library recheck, 2026-10-20:** reran the same
30-assertion file directly against installed EDI 1.0.3 with
`testthat::test_file("R/package_tests/testthat_bulk/test-incidence-classes-rand-two-sided-pval-zhang-eligible-dispatch-sweep-reference.R", reporter = "summary")`.
Result: 24 passed and the same six nonzero-`delta` refusal assertions failed:
Probit, BinomialIdentityRiskDiff, ModifiedPoisson, KKCondLogitOneLik,
KKCondLogitIVWC, and KKNewcombeRiskDiff. Provenance: package path
`/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`, package version
1.0.3, R Under development (2026-10-13 r90668), installed `EDI.so` MD5
`8b3ca30492d7b1c790deeebe94b201ad`, SHA-256
`db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`.
Direct inspection of the installed namespace confirms this is an R-layer
staleness, not a DLL conclusion: `InferenceRand` still unconditionally takes
the default Zhang branch when `should_use_zhang_incidence_randomization()` is
true, while `InferenceRandCI` and `InferenceMixinKKGEEShared` still default
`rand_type` to Zhang in that branch. The checkout implementations instead
reserve Zhang for explicit `type`; the targeted four-assertion nonzero-delta
test passing after reinstall does not cover these six class refusals. Keep the
installed-package gate open until the exact checkout R definitions are
actually installed and this same 30-assertion command passes; comprehensive
incidence `rand` row regeneration/reconciliation remains a separate open gate.

**Install/source timestamp reconciliation:** the installed package metadata
reports `Built: R 4.7.0; x86_64-pc-linux-gnu; 2026-10-20 07:40:04 UTC`
(10:40:04 +0300). The relevant dirty checkout R files were subsequently
modified at 10:45:20 +0300 (`inference_all_abstract_rand_ci.R` and
`inference_mixin_kk_gee_shared.R`) and 10:48:54 +0300
(`inference_all_abstract_rand.R`); `NEWS.md` was modified at 10:48:09 +0300.
Thus the installed package predates these checkout edits, consistent with the
observed namespace bodies. The matching installed/checkout DLL SHA-256
`db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041` establishes
native-library identity only; it does not establish freshness of the installed
R source layer. No source or installation was changed for this reconciliation.

**Companion dispatch/guard regressions, 2026-10-20:** six additional focused
files passed 47 assertions with checkout R loaded using
`pkgload::load_all("R/EDI", compile = FALSE)` against the same rebuilt native
DLL: extended Robins, log-binomial, Wald/CMH, KK g-computation risk difference,
non-Zhang-eligible incidence refusal, and the Zhang eligibility predicate.
Together with the 30-assertion wide class sweep, all 77 assertions passed with
no failures, warnings, or skips. Comprehensive incidence `rand` result-row
regeneration and exact-key reconciliation remain open.

**Expected-outcome validator, 2026-10-21:** added a TODO-99-specific artifact
wrapper and row-contract check in
`comprehensive_incidence_rand_pvalue_attempt_manifest.R`. It runs after the
existing provenance/exact-key/terminal-field validator and checks manifest
`expected_status`/`expected_skip_reason` against result rows by the complete
incidence-rand key. The focused synthetic pure-R test passed 8 expectations,
including rejection of a standard-statistic `delta=0.5` result marked `ok`
and one with an incorrect skip reason. This does not establish that the
comprehensive rows were generated from current checkout R definitions; full
incidence `rand` regeneration and reconciliation remain open.

**Artifact-wrapper regression, 2026-10-21:** added a synthetic end-to-end
fixture to `test-comprehensive-incidence-rand-attempt-manifest-reference.R`
that writes a temporary results CSV and schema-2 provenance sidecar, then
calls `validate_comprehensive_incidence_rand_pvalue_result_artifact()` with
the exact-key expected manifest. It accepts the valid artifact and rejects a
row with the wrong status. The entire focused test file passed against
installed EDI 1.0.3 (`Rscript -e 'testthat::test_file(...)'`); this validates
the pure-R artifact wrapper only, not native dispatch or result generation.
Together with the direct expected-outcome checks, this closes the synthetic
validator-integration subgate. Current-source runtime eligibility, a
provenance-stamped comprehensive incidence-`rand` run, exact-key/status
reconciliation, and any canonical update authorization remain open.

**Signed-shift boundary regression, 2026-10-21:** the existing six-class
dispatch regression previously tested refusal only for a positive nonzero
shift. It now also checks `delta=-0.3` for each of the same six
Zhang-eligible incidence classes. The installed-package run passed all 36
expectations, including both shift signs; the installed EDI 1.0.3 R layer at
`/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI` exposes the guard in
`InferenceIncidProbitRegr$public_methods$compute_rand_two_sided_pval`. This
closes only the signed argument-boundary test gap. Current-source comprehensive
incidence `rand` regeneration and exact-key/status reconciliation remain open.

**Retained-artifact reconciliation audit, 2026-10-21 (read-only):** the
`/tmp/edi-todo99-incidence-rand-preflight/` roster has 189,280 unique
candidate keys, but its README identifies it as a structural upper bound, not
an attempt/result manifest. Its candidate TSV SHA-256 is
`696d34fd507010c3969d71d15899576bdba725fd39d4fa71f932aeb5a6f099f0`. The
preflight records `comprehensive_tests.R` SHA-256
`39f1abc8e492b2307ed4229b1bf36d42021464af1521578e4683aaf3d3de7189`, whereas
the current working runner hashes to
`72cd9d6b5f7afe58b5113eb7c7f1836a03e0b98cd386c09ef025c0f7b56d1221`; the
dataset loader hash still matches
(`7e3cf603ef384c369c4435dc5ca0b541d9248bbda9e5db7f3c17b2b41628bdda`).
Regenerate eligibility and expected keys from the stabilized runner before
using that roster for reconciliation.

The retained canonical `comprehensive_tests_results_nc_1_incidence.csv` is
525,863,531 bytes (about 502 MiB), dated 2026-10-09, with no matching
provenance sidecar. A read-only natural-key comparison found 17,746 incidence
rand p-value rows across 14 historical `github_commit_id` values; 14,470
match the stale candidate roster (6,983 plain calls and 7,487
`delta=0.5` calls), with no duplicate canonical keys. This partial overlap is
not current-source evidence: the CSV predates the dispatch change, lacks run
provenance, and is incomplete relative to the candidate roster. The only
isolated TODO-99 output remains the two-row cars/Bernoulli/Probit scratch CSV
at `/tmp/edi-todo99-one-rep-GHPmHC/`, without a receipt sidecar or loaded
R-payload/DLL identity; `/tmp/edi-todo99-one-rep.Wx5ecd/` is empty. No complete
current-source artifact is available. The remaining gate is to regenerate
the runtime expected manifest and full incidence-rand results with attempt
events and run provenance into isolated output, validate exact keys and
expected statuses, then update the canonical slice only with explicit
authorization. No R run, output merge, or canonical write occurred in this
audit.

**Manifest/runner wiring audit, 2026-10-21 (read-only; partially superseded
by the artifact-wrapper regression above):** `trail callers`/`rg` checks find
`comprehensive_incidence_rand_pvalue_attempt_manifest()` only in its focused
reference test, rather than in the comprehensive runner. The expected-outcome
test originally exercised the row helper without the outer artifact wrapper;
the later artifact-wrapper regression above now covers the integrated
synthetic CSV+sidecar+expected-outcome path. That fixture closes only the
validator-integration subgate: its exact expected keys/statuses are supplied
synthetically, and the wrapper still has no production-runner caller. It does
not establish actual incidence runtime eligibility or current-source row
completeness. The release gate still requires a stabilized runner to emit
runtime attempt/eligibility records and provenance into isolated output,
followed by exact-key/status reconciliation. Updating canonical rows requires
separate explicit authorization. No test, simulation, build, install, or
canonical write was performed in this read-only audit.

**Attempt-event/result reconciliation contract, 2026-10-21:** extended the
TODO-99 artifact validator to require the attempt-event CSV named by the run
receipt, verify its resolved path/byte count/SHA-256, and reconcile keyed
events and result rows to the caller-supplied expected manifest. Each expected
operation must have exactly one `started` and one `terminal` event, a matching
terminal result, and the expected status; missing/extra/duplicate keys,
unpaired events, and status mismatches are rejected. The focused pure-R test
`test-comprehensive-incidence-rand-attempt-manifest-reference.R` passed 14
expectations against installed EDI 1.0.3; its artifacts are synthetic and
under `/tmp`. The test also confirms that unkeyed `setup_skipped` and
`setup_failure` events are retained only as context, never counted as
operation attempts. Follow-up on the runner's three `setup_skipped` sites
found the effective `design_formula` in scope; each now records its deparsed
value. The existing outer `setup_failure` site already records
`model_formula`. A focused pure-R source/writer regression passed with no
failures, confirming all three call sites pass formula context and the event
writer preserves it. These records remain unkeyed because setup failure has
no inference/function operation key, so formula context does not identify a
specific inference-method attempt.
The expected manifest remains caller-supplied and the wrapper still has no
production-runner caller. Runtime eligibility/full-roster completeness,
current-source isolated regeneration and reconciliation, and explicit
authorization for canonical updates remain open.
