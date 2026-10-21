# Randomization-CI High-Precision Refinement Ignores `lower`: Upper Bound Converges to the Wrong End of Its Bracket

> **Depends on:** none. (Global ordering: see `../new_feature_plans/_master.md`.) Slated for
> `../future_release_plans/release_v1_0_5.md → TODO-33`. Added 2026-09-24
> from the test-comment audit: originally pinned as `SOURCE BUG` in
> `test-rand-ci-bisection-and-high-precision-refinement-reference.R`
> (`high_precision_confirm_and_refine_ci_bound()`,
> `inference_all_abstract_rand_ci.R`). The test asserts the wrong behavior on
> a controlled fixture; how often production searches enter the refinement
> loop (`high_precision_confirm = TRUE` plus `mc_enable`) remains uncertain.
> Complements `../new_feature_plans/randomization_ci_search_precision.md` and
> `../new_feature_plans/randomization_ci_construction_audit.md`.

## The finding

In the refinement loop, when `p(m) >= threshold` the code always sets
`u2 <- m`. That is correct for a **lower** bound (the accepted side is the
upper end of the bracket) but wrong for an **upper** bound, where the
accepted side is the lower end. For an upper bound the loop therefore walks
`u2` down to `l2` instead of up to the crossing, and the refined upper bound
lands at the wrong end of its bracket. The function takes a `lower` flag but
the branch ignores it.

## Items

- [ ] **TODO-1: Reproduce end to end.** Find a real
  `compute_rand_confidence_interval()` call with `high_precision_confirm =
  TRUE` whose upper bound is moved to the wrong end; measure the coverage
  effect, not just the unit fixture. The controlled public-API regression in
  `R/package_tests/testthat_bulk/test-rand-ci-bisection-and-high-precision-refinement-reference.R`
  (`public randomization CI reaches both refinement directions when cheap
  p-values hide a wide crossing`) stubs
  `compute_randomization_ci_pval_cached`: it deterministically exercises the
  public orchestration and upper midpoint refinement with injected p-values,
  but does not demonstrate a trigger from actual permutation-backed real-data
  p-values. The 12 real-data runs below reached only the confirmation helper,
  not its inner refinement loop.
- [x] **TODO-2: Fix** by branching on `lower` (mirror the accepted/rejected
  side for the upper bound), and check the sibling refinement or bisection
  helpers for the same one-sided assumption.
- [x] **TODO-3: Flip the pinned test** to assert convergence to the correct
  crossing for both bounds; add a symmetric-statistic test where the lower
  and upper bounds must mirror each other.
- [x] **TODO-4: Coverage check** with the standard randomization-CI
  simulation for one tier-1 class after the fix. **Done 2026-10-14:**
  using the installed package, `InferenceContinOLS`, `n=32`, constant effect
  1, nominal 90% CI, `r=201`, sequential MC enabled, and full-precision
  confirmation, 461/500 intervals covered (92.2%); all 500 were finite.
  The exact 95% binomial interval was 89.49%-94.39%, which includes nominal
  90%. No Codex compile/build/install was run.

Verification (2026-10-07): the controlled public-API regression makes the
cheap p-values obscure a wide crossing and checks that both refined bounds
converge to the analytic normal-score crossings. The focused bulk suite
passed 27 expectations with `pkgload::load_all(compile = FALSE)`; the sibling
CRAN test passed 11. A bounded `InferenceContinOLS` check with a true effect
of 1, 12 independent Bernoulli designs (`n = 32`, `r = 201`, nominal 90% CI,
sequential MC enabled) produced 12 finite CIs and 11/12 covered the effect.
The confirmation helper was called for both bounds in every run, but the
inner refinement loop was not entered. This was a bounded smoke check;
the standard coverage simulation remains to be run. The 12-replicate result
cannot precisely estimate operating coverage or the pre-fix effect.

The 2026-10-14 500-replication installed-package coverage recheck is recorded
under TODO-4 above. TODO-1 remains open: no real-data run has yet been
confirmed to enter the inner high-precision refinement loop for the upper
bound.

**Installed-package public-API trigger search (2026-10-14):** instrumented
`InferenceContinOLS` confidence-interval calls on fixed real datasets through
the installed EDI 1.0.3 package; no build/install was run. The 100-case
`mtcars` run (`mpg ~ wt + hp`, `r = 1001`, default search controls,
`pval_epsilon = 0.005`) had zero errors and zero upper-bound inner-loop
entries; every call made only the two endpoint full-precision evaluations.
The necessary trigger condition—cheap endpoint p-span at or below tolerance,
full-precision endpoint p-span above tolerance, and bracket width above
tolerance—occurred 0/100 times. In 84 cases the bracket was still wider than
tolerance, but in all 84 the full-precision p-span was already at or below
tolerance. In the other direction, 7 cases had full-precision p-span above
tolerance, but their cheap p-span was also above tolerance, so the cheap
search would not enter confirmation. The instrumented CSV and harness are
`/tmp/edi-v105-todo33/mtcars_public_api_ci_probe_r1001.csv` and
`/tmp/edi-v105-todo33/public_api_probe.R`. Other bounded mtcars/airquality
public-API probes at `r = 201`/`1001`, including nondefault MC stress settings,
also produced no inner upper-bound entries. A new bounded `airquality` sweep
used the 111 complete cases (`Ozone ~ Wind + Temp`) through public
`InferenceContinOLS` calls: 25 seeds at `r=201`, `pval_epsilon=0.005`, then
10 seeds at `r=1001`, `pval_epsilon=0.001`; all 35 calls were error-free and
none entered the upper inner loop. At `r=201`, all 25 upper delta brackets
were narrower than the `0.005` tolerance (0.00406–0.00428), and cheap endpoint
p-spans were at least `0.00995`. At `r=1001`, all 10 brackets were narrower
than the `0.001` tolerance (0.000504–0.000521), while cheap p-spans were
`0.001998` or `0.003996`; the full-precision endpoint span was zero or
`0.001998`. These runs therefore did not satisfy the joint condition needed
to enter refinement. Harnesses and CSVs are
`/tmp/edi-v105-todo33-airquality-probe.R`,
`/tmp/edi-v105-todo33/airquality_public_api_ci_probe_r201.csv`,
`/tmp/edi-v105-todo33-airquality-r1001-probe.R`, and
`/tmp/edi-v105-todo33/airquality_public_api_ci_probe_r1001.csv`.
These are trigger-search results,
not evidence that the production bug is unreachable or that coverage is
unaffected. The controlled public-API regression remains the only confirmed
inner-loop reproduction.

**Additional bounded real-data MC-control stress (2026-10-15):** on `mtcars`
(`mpg ~ wt + hp`), 50 seeds per setting were run through the installed
EDI 1.0.3 public API with `r=1001`, no build/install, and instrumentation of
the cheap/full endpoint spans and upper bracket width. At `pval_epsilon=0.005`,
the two settings were aggressive (`mc_batch_size=10`, `mc_min_draws=10`,
`mc_conf_level=0.5`) and conservative (`25`, `100`, `0.99`): 100/100 calls
completed without errors, but 0 entered upper refinement. The full joint trigger
condition occurred 0/100 times: cheap span `<= 0.005` in 90/100, full-precision
span `> 0.005` in 6/100, and bracket width `> 0.005` in 82/100, with no overlap
of all three. Repeating the same 100 cases at `pval_epsilon=0.01` yielded zero
errors and zero inner entries: cheap span `<= 0.01` in 100/100, full-precision
span `> 0.01` in 0/100, and bracket width `> 0.01` in 100/100. The isolated
CSV outputs are `/tmp/edi-v105-todo33-mc-stress-r1001.csv` and
`/tmp/edi-v105-todo33-mc-stress-r1001-tol010.csv`, driven by
`/tmp/edi_todo33_mc_stress.R`. This extends the negative trigger search but
does not close TODO-1 or establish unreachability. Next useful experiment:
instrument a seed search on a real dataset with a steeper randomization
p-value crossing; only then run a pre/post coverage comparison on a
trigger-producing public case.

**Additional distinct bounded public-API trigger search (2026-10-16):**
verified EDI 1.0.3 was available and loaded before the probe, remained
available/version-stable during all 20 calls, and was available after them.
On the real `datasets::USArrests` data (`Murder` response, `Assault`,
`UrbanPop`, and `Rape` covariates; `n=50`), `InferenceContinOLS` used
Bernoulli assignment, `alpha=0.10`, `r=501`, `pval_epsilon=0.005`, and
sequential MC controls `mc_batch_size=10`, `mc_min_draws=10`,
`mc_conf_level=0.5`, with `high_precision_confirm=TRUE`. Across seeds
20261018–20261037, all 20 calls completed without errors and invoked the
full-precision endpoint confirmation (two endpoint evaluations), but none
entered the inner refinement loop. The three necessary numeric conditions
overlapped 0/20 times (cheap p-span `<= tol` in 13/20, full-precision
p-span `> tol` in 3/20, upper bracket width `> tol` in 12/20). The isolated
reproduction command was
`Rscript -e 'source("/tmp/edi-v105-todo33-usarrests-20261016/probe.R")'`;
script and CSV are `/tmp/edi-v105-todo33-usarrests-20261016/probe.R` and
`/tmp/edi-v105-todo33-usarrests-20261016/results.csv`. The 18/20 intervals
covering zero are only a descriptive fixed-dataset result, not a coverage
estimate. This is another bounded no-trigger result, not evidence of
unreachability; TODO-1 remains open, and no pre/post coverage comparison was
possible without a trigger-producing case.

**Tighter-tolerance distinct-data trigger search (2026-10-16):** on the real
`datasets::faithful` data (`eruptions + 0.5 * treatment`, covariate `waiting`,
`n=272`), eight installed-EDI 1.0.3 public-API calls used Bernoulli assignment,
`alpha=0.10`, `r=501`, `pval_epsilon=0.001`, and sequential MC controls
`mc_batch_size=5`, `mc_min_draws=5`, `mc_conf_level=0.5`, with
`high_precision_confirm=TRUE`. All eight completed without errors and none
entered the upper inner loop; each made only two full-precision endpoint
evaluations. Upper bracket widths were 0.0009427–0.0009501 (all below the
0.001 tolerance), while cheap and full-precision p-value spans were equal at
0.003992 or 0.007984 (both above tolerance). Thus this tighter-tolerance
real-data fixture still did not satisfy the joint trigger. This is a bounded
negative search only, not coverage evidence or evidence of unreachability.
The one-core script and CSV are
`/tmp/edi-v105-todo33-faithful-probe-20261016.R` and
`/tmp/edi-v105-todo33-faithful-probe-20261016.csv`.

**Read-only artifact cross-check (2026-10-16):** inspected the existing
`mtcars` and `airquality` probe CSVs directly. `mtcars` has 100 rows in the
`r=1001` run, 5 in the later small probe, 20 in the `r=201` probe, and 100
rows in each of the two MC-control stress files; `airquality` has 100 rows
in the original probe, 25 at `r=201`, and 10 at `r=1001`. Every row records
`upper_inner_refine=FALSE` (0 triggered rows in all 460). Calls that reached
full-precision endpoint confirmation still did not necessarily run the
inner bisection. These artifacts therefore do not trigger the upper-bound
refinement and do not close TODO-1; they are bounded trigger-search failures,
not evidence of inaccessibility or coverage.

**Expanded read-only archived-run audit (2026-10-16):** checked the saved
TODO-33 CSV probes in `/tmp` (including the Boston, Pima, wt-only, Faithful,
USArrests, `mtcars`/`airquality`, and multi-control matrix/stress artifacts).
Across 1,132 recorded rows with an upper-refinement indicator, all flags were
false, all recorded upper full-precision evaluation counts were at most two,
and there were no recorded errors. Among the 812 rows with all four numeric
trigger fields available, zero met the joint condition `cheap_span <= tol`,
`full_span > tol`, and `width > tol`; 551 met the cheap-span and width
conditions but had `full_span <= tol`. A closest archived near miss is
`/tmp/edi-v105-todo33-matrix-r5001-eps-0.002-aggressive-20261016.csv`, seed
`20265015`: cheap and full spans are both `0.0019996` at tolerance `0.002`,
while the bracket width is `0.004167046`; it still used only the two endpoint
evaluations. This rules out simply re-labeling an archived call as an inner
trigger. No archived run supplies the required real-data pre/post counterfactual
or coverage comparison. The lowest-cost next experiment is a single
instrumented public-API seed search on a real dataset, retaining a candidate
only when the cheap-span stop occurs with a wide bracket and the fresh
full-precision endpoints straddle the threshold with p-span above tolerance;
then replay that retained case under the old upper-branch counterfactual before
considering repeated-trial coverage. Do not repeat a broad parameter grid.

The next runnable trigger criterion, after the active TODO-56 workload is
terminal, is a public `compute_rand_confidence_interval()` upper-bound call
with `high_precision_confirm=TRUE` whose normal cheap-search stop is the
cheap endpoint p-value span `<= tol` (a width-only stop cannot enter the
inner loop because the full-width guard then exits immediately). On its
fresh full-precision endpoint evaluation, require finite endpoint p-values
that straddle the threshold, `abs(p_u - p_l) > tol`, and `u - l > tol`; the
same-side fallback must not fire. Instrumentation must record at least one
midpoint evaluation / `upper_inner_refine=TRUE`, not merely two endpoint
evaluations or a call to the confirmation helper. Then retain the triggering
real-data input/seed and compare the fixed upper result with the old-branch
counterfactual; TODO-1 still requires an outer repeated-trial coverage
comparison on that trigger-producing configuration, not just one interval.

**Additional bounded Iris pilot audit (2026-10-16):** the workspace scratch
artifact `.scratch/todo33-iris-pilot/iris_public_api_ci_probe_r501.csv`
contains three rows (seeds 20261017–20261019). All three have
`upper_inner_refine=FALSE`, `joint_tripwire=FALSE`, two upper full-precision
endpoint evaluations, and no errors. This is another negative trigger-search
pilot only; it does not satisfy TODO-1 or alter the archived-run conclusion.

**Prepared `trees` search static review (2026-10-16):** the held 20-seed
installed-package harness at `/tmp/edi-todo33-ready-20261016/search.R` was
checked against the existing TODO-1 tripwire and retained-input requirements.
Its candidate predicate requires an upper bound, cheap endpoint p-span at or
below tolerance, a bracket wider than tolerance, finite fresh full-precision
endpoints that straddle the threshold with span above tolerance, no same-side
fallback, at least one midpoint evaluation, no call error, and a captured
permutation object. The replay bundle retains the data, response/covariates,
realized assignment, permutations, RNG kind/states, controls, bound entry and
diagnostics, and package/R session metadata. This is a static design review
only: the prepared search has not run and no candidate/result bundle exists.
**Harness amendment (2026-10-16):** the held script now records the loaded
EDI shared-library path and SHA-256 (with `<unavailable>` fallback), checks
that this provenance remains stable across the search, and requires the
expected upper-bound orientation `p(l) >= pval_th >= p(u)` in addition to the
existing straddle/span and midpoint gates. These amendments close the two
static-review caveats without changing the acceptance criteria. At preparation
time, the amended search had not run and no candidate bundle existed. Keep the
acceptance criteria unchanged; if a candidate is retained, pause for review
before any old-branch counterfactual or coverage run.

**Bounded `trees` public-API trigger search (2026-10-19):** the prepared
20-seed search ran against installed EDI 1.0.3 (seeds 20261081:20261100,
`r=1001`, `pval_epsilon=0.005`) and produced 0 errors and 0 eligible upper
inner-refinement triggers. All calls stopped at the cheap p-span check; each
made two fresh full-precision endpoint evaluations and zero midpoint
evaluations. No candidate/replay RDS was produced. The invocation returned
normally and stdout reported `errors=0; eligible_triggers=0`, but
`run_metadata.txt` has no explicit exit-code/completion footer. The scratch
manifest is under `/tmp/edi-todo33-ready-20261016/`: `RUN_COMMAND.txt`
SHA-256 `093a83a0fffe62743b8b9169cef19eacc6ce4aaabf969b4fd75e538c3484c3da`,
`run_metadata.txt` SHA-256
`cbaf672d1b8587ab6c337b72560aea29a5291365df013eb39a6b771fa208fe97`,
`search.R` SHA-256
`4cedea54f53f0c3a7a6397fb165c25d5b72270d332b6c095b48121279a08645c`, and
`trees_public_api_trigger_search.csv` SHA-256
`b99e918046108aca4cfc52971b8534be3d78f3d65d52ffaf8dc631033f071f3e`.
This closes only the bounded-search substep: it found no real-data trigger and
does not establish branch inaccessibility or validate current-checkout native
code. TODO-1 remains open pending a trigger-producing fixture; preserve replay
inputs and pause for review before any old-branch counterfactual or repeated-
trial coverage study.

**Early-stopped-cache isolation regression, 2026-10-20:** broadened the
existing bisection reference test to seed a caller cache with noisy
Monte-Carlo endpoint p-values whose span is within tolerance, then verify
that full-precision confirmation uses a separate cache and refines to the
independent step-crossing at 1.5. The test also checks that full-precision
calls share their fresh cache while the caller cache retains only its two
cheap endpoint entries. With checkout R sources loaded by
`pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE)`, the focused file
passed 37 expectations (0 failures, warnings, or skips). The p-value function
is stubbed; this is a source-level cache-contract regression, not a
permutation-backed real-data trigger, coverage estimate, or calibration run.
TODO-1 and its trigger-producing real-data/replay gate remain open.

**Installed-package recheck, 2026-10-20:**
`Rscript -e 'library(EDI); testthat::test_file("R/package_tests/testthat_bulk/test-rand-ci-bisection-and-high-precision-refinement-reference.R", reporter = "summary")'`
passed 37 expectations against installed EDI 1.0.3 at
`/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`; loaded DLL
`/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI/libs/EDI.so` had MD5
`a75519a9256c0b3121398032314291d4`. The regression uses controlled/stubbed
p-values for the bisection and cache-isolation paths; it does not run model
fits, a permutation-backed trigger, or a calibration study. It adds installed-
package contract evidence only: TODO-1 and the real-data trigger/replay gate
remain open. No build, install, or canonical result write occurred.

**Additional bounded packaged-real-data search (2026-10-20):** the new
`datasets::swiss` fixture (`Fertility` outcome; Agriculture, Examination,
Education, Catholic, and Infant.Mortality covariates; n=47) was run through
the public `InferenceContinOLS$compute_rand_confidence_interval()` path for
seeds 20261092:20261103, `alpha=0.10`, `r=501`, `pval_epsilon=0.005`, and
sequential-MC controls (`batch=5`, `min_draws=5`, `conf_level=0.5`). The
bounded script is `/tmp/edi_todo33_swiss_trigger_20261020.R`; it loaded
checkout R through `pkgload::load_all("R/EDI", compile=FALSE)` and did not
build/install. All 12 calls completed without errors and captured the public
upper-bound endpoint diagnostics. The three scalar conditions overlapped in
0/12 joint triggers: cheap p-span <= tolerance in 11/12, fresh full-precision
p-span > tolerance in 1/12, and bracket width > tolerance in 11/12. The one
full-span hit had a cheap span of 0.011976 (> tolerance), so it did not enter
confirmation; every actual confirmation used exactly two endpoint
evaluations and zero inner midpoints. No replay RDS was produced. A separate
compile-free startup check reported EDI 1.0.3 and loaded DLL MD5
`8b3ca30492d7b1c790deeebe94b201ad`; the search itself did not record a
same-process DLL path/hash, so this hash is contextual, not per-run identity.
This establishes only that this additional packaged fixture/seed set did not
meet the trigger gate; it is not evidence of unreachability and does not close
TODO-1 or authorize a synthetic substitute.

**Additional bounded `MASS::Cars93` packaged-real-data search (2026-10-20):**
the public `InferenceContinOLS$compute_rand_confidence_interval()` path was
run on `MASS::Cars93` (`Price` outcome; `MPG.highway`, `Horsepower`, and
`Weight` covariates; n=93), seeds 20261104:20261115, `alpha=0.10`, `r=501`,
`pval_epsilon=0.005`, and the same bounded sequential-MC controls. The exact
command was
`EDI_TODO33_DATASET=Cars93 EDI_TODO33_RESPONSE=Price EDI_TODO33_COVARIATES=MPG.highway,Horsepower,Weight EDI_TODO33_SEED_START=20261103 timeout 180s Rscript /tmp/edi_todo33_swiss_trigger_20261020.R`.
All 12 calls completed without errors. The cheap-span, full-span, and width
conditions held in 10/12, 2/12, and 10/12 cases respectively, but overlapped
in 0/12; every call made only two full-precision endpoint evaluations and
zero upper midpoint evaluations. Both full-span hits had cheap span above
tolerance and bracket width below tolerance. The run used checkout R via
`pkgload::load_all("R/EDI", compile=FALSE)` with EDI 1.0.3 and DLL
`/tmp/RtmpKXGNZS/pkgload3205a837/EDI.so`, MD5
`8b3ca30492d7b1c790deeebe94b201ad`; no build/install occurred. No replay RDS
was produced. This is another bounded negative packaged-data search, not
evidence of unreachability; TODO-1 remains open for an actual real-data
trigger and its replay/coverage comparison.

**Additional bounded `datasets::airquality` packaged-real-data search
(2026-10-20):** using the same harness and public `InferenceContinOLS` path,
the 111 complete cases for `Ozone ~ Solar.R + Wind + Temp` were tested with
seeds 20261116:20261127 at `alpha=0.10`, `r=501`, `pval_epsilon=0.005`, and
sequential-MC controls (`batch=5`, `min_draws=5`, `conf_level=0.5`). The exact
command was
`EDI_TODO33_DATASET=airquality EDI_TODO33_RESPONSE=Ozone EDI_TODO33_COVARIATES=Solar.R,Wind,Temp EDI_TODO33_SEED_START=20261115 timeout 180s Rscript /tmp/edi_todo33_swiss_trigger_20261020.R`.
All 12 calls completed without errors. The cheap-span, full-span, and width
conditions held in 10/12, 2/12, and 10/12 cases respectively, but overlapped
in 0/12. The two full-span cases (seeds 20261123 and 20261125) both had width
below tolerance; all calls made exactly two fresh full-precision endpoint
evaluations and zero upper midpoint evaluations. The harness loaded checkout R
with `pkgload::load_all("R/EDI", compile=FALSE)`; EDI was 1.0.3 and the
same-process DLL was `/tmp/RtmppXCyHa/pkgload36202f4ee/EDI.so`, MD5
`8b3ca30492d7b1c790deeebe94b201ad`. No replay RDS was produced. This is a
bounded negative packaged-data search only, not evidence of unreachability;
TODO-1 remains open for a real-data trigger and replay/coverage comparison.

**Additional bounded `datasets::quakes` packaged-real-data search
(2026-10-20):** to try a larger and more heterogeneous continuous outcome,
the public `InferenceContinOLS` path was run on all 1,000 complete rows of
`mag ~ lat + long + depth + stations`, seeds 20261128:20261139, with the same
`alpha=0.10`, `r=501`, `pval_epsilon=0.005`, and sequential-MC controls
(`batch=5`, `min_draws=5`, `conf_level=0.5`). The exact command was
`EDI_TODO33_DATASET=quakes EDI_TODO33_RESPONSE=mag EDI_TODO33_COVARIATES=lat,long,depth,stations EDI_TODO33_SEED_START=20261127 timeout 180s Rscript /tmp/edi_todo33_swiss_trigger_20261020.R`.
All 12 calls completed without errors. The cheap-span condition held 0/12,
the fresh full-span condition 12/12, and the bracket-width condition 0/12;
there were 0 joint triggers. Every call made exactly two full-precision
endpoint evaluations and zero upper midpoint evaluations. These cases missed
confirmation because the cheap p-span exceeded tolerance and bracket width
was already below tolerance. The harness loaded checkout R with
`pkgload::load_all("R/EDI", compile=FALSE)`; EDI was 1.0.3 and the
same-process DLL was `/tmp/RtmpGJa2TM/pkgload3304bf752/EDI.so`, MD5
`8b3ca30492d7b1c790deeebe94b201ad`. No replay RDS was produced. This bounded
negative search does not establish unreachability; TODO-1 remains open for an
actual real-data trigger and replay/coverage comparison.

**Positive-trigger replay-path guard, 2026-10-21:** the pure-R sidecar
constructor now rejects a positive per-seed trigger result if no replay path
is supplied, and rejects supplied replay paths that do not name existing
files (or name directories). The existing focused reference test was extended
to cover positive-trigger/empty-path rejection and positive-trigger/missing-
file rejection; its existing positive fixture continues to prove that a
realistic replay-bundle path is accepted, while negative searches may retain
an empty replay-path vector. The isolated sidecar contract block passed 6
expectations with `Rscript -e`, sourcing
`R/package_tests/todo33_trigger_search_provenance.R` and using installed EDI
1.0.3; no model fit, permutation search, source load, build, install, or
canonical output write occurred. This closes only the sidecar validator
subgate. The current schema does not map replay paths to individual seed
rows, so no one-path-per-trigger constraint was added. Real-data strict
trigger, replay/counterfactual, and repeated-trial coverage gates remain open.

**Deterministic synthetic trigger/replay fixture, 2026-10-21:** broadened the
existing public-CI fixed-permutation test to serialize the adversarial 8-by-501
assignment matrix, observed assignment, outcome, search controls, and upper
trigger bracket as a replay bundle, then link that bundle from a positive
trigger run sidecar. The test reloads the saved inputs and recomputes the
upper endpoint with an independent plain-R permutation p-value inversion; it
also reproduces the pre-fix upper update from parent commit
`362c5d28fa6233d99d6d6815d1bffa02f5aa33ab` and verifies that its returned
endpoint remains on the accepted side while the fixed result is on the rejected
side. The exact filtered test passed 35 expectations with
`pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE)`; no build/install,
real-data search, or canonical output write occurred. This proves deterministic
trigger/replay and branch-divergence wiring on a deliberately constructed
permutation fixture, not that a natural public-data search reaches the trigger.
It does not replace the real-data old-branch replay or repeated-trial coverage
comparison; TODO-1 remains open for those gates.

**Negative-search provenance sidecar contract, 2026-10-21:** added the
TODO-33-specific helper `R/package_tests/todo33_trigger_search_provenance.R`
and a focused contract case in the existing bisection/refinement reference
test. The contract stores before/after package, source-payload, DLL, checkout,
and actual trigger-runner identities together with run settings/environment,
the input data, every per-seed result, and any trigger replay paths. It allows
an empty replay-path vector and zero triggers, so a completed negative search
retains a reproducible run record instead of only a console log. The scratch
runner integration is in `/tmp/edi_todo33_trigger_search_with_provenance_20261021.R`;
the existing trigger-positive replay RDS branch is unchanged. The single
filtered test passed 9 expectations (0 failures, warnings, or skips) against
installed EDI 1.0.3; the helper/test are pure R and no model or permutation
search was run. This validates sidecar construction and no-overwrite behavior,
not the real-data search itself. TODO-1 remains open for a trigger-producing
run, old-branch replay, and repeated-trial coverage comparison.

**Current-checkout-R/current-user-native focused recheck, 2026-10-21:** after
confirming no R/Rscript process was active and 16 GiB remained on `/tmp`, ran
the focused reference file through
`pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE)` followed by
`testthat::test_file("R/package_tests/testthat_bulk/test-rand-ci-bisection-and-high-precision-refinement-reference.R", reporter = "summary")`.
The test completed successfully with no failures reported. The loaded EDI
namespace was `/home/kapelner/workspace/EDI/R/EDI`, version 1.0.3; the
temporary loaded DLL was
`/tmp/RtmpFsnInz/pkgload25ba783c6/EDI.so`, MD5
`bfea6f47ab8b27618d5d8633e9021f91`, SHA-256
`0e5130770d0a74d86c26ba220c64561dffb71003510b678522ca860b7f37efc0`.
That SHA-256 matches both checkout `R/EDI/src/EDI.so` and the user-installed
library DLL at
`/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI/libs/EDI.so`.
`pkgload` used `compile = FALSE`; no build/install or canonical output write
occurred. This closes only the focused checkout-R/current-native test-contract
recheck after correcting the active-MC-control fixture diagnostics. It does
not produce a real-data strict-refinement trigger, old-branch replay, or
repeated-trial coverage comparison; TODO-33 remains open.

**Additional bounded `datasets::CO2` packaged-real-data search
(2026-10-21):** to screen a distinct repeated-measures dataset, the public
`InferenceContinOLS$compute_rand_confidence_interval()` path used all 84
complete cases of `uptake ~ conc + Treatment + Plant`, seeds 20261301:20261308,
`alpha=0.10`, `r=501`, `pval_epsilon=0.005`, and sequential-MC controls
(`batch=5`, `min_draws=5`, `conf_level=0.5`, `high_precision_confirm=TRUE`).
Exact command:
`timeout 240s env EDI_TODO33_DATASET=CO2 EDI_TODO33_RESPONSE=uptake EDI_TODO33_COVARIATES=conc,Treatment,Plant EDI_TODO33_SEED_START=20261300 EDI_TODO33_NSEEDS=8 Rscript /tmp/edi_todo33_swiss_trigger_20261020.R > /tmp/edi_todo33_CO2_trigger_search_20261021.log 2>&1`.
All eight public calls completed without errors. The cheap endpoint p-span
was at or below tolerance in 6/8, the fresh full-precision endpoint p-span
exceeded tolerance in 1/8, and the upper bracket width exceeded tolerance in
6/8; the joint trigger count was 0/8. The sole full-span hit (seed 20261308)
also had cheap span above tolerance and bracket width below tolerance. The
other six wide-bracket/cheap-stop cases had full-precision p-span at or below
tolerance. Every actual confirmation made exactly two fresh endpoint
evaluations and zero midpoint evaluations; no trigger RDS was produced. The
run loaded checkout R with `pkgload::load_all("R/EDI", compile=FALSE)` and
reported EDI 1.0.3, DLL MD5 `ea0e2f72d87d401db15557e0ecc151c9`; the loaded
DLL hash matches both checkout and installed `EDI.so` (SHA-256
`ae4fddafdadfaad9209b6a7e5c7617963eb4150f2e7e95841aec81b232f68d94`). The
retained log SHA-256 is
`82e269204b79e473dddbdbb48b9459161923214852eadede3c6a359903c2c93a`.
This narrows the trigger search but does not establish branch
unreachability, perform an old-branch counterfactual, or estimate coverage.
The strict trigger remains: ordinary cheap-search stop by endpoint p-span
`<= tol` (not width-only stop); finite fresh full-precision endpoint p-values
with upper orientation and a threshold straddle; full-span `> tol`; bracket
width `> tol`; no same-side fallback; and at least one upper midpoint
evaluation (`upper_inner_refine=TRUE`). A trigger-producing retained case and
its old-branch/repeated-trial coverage comparison remain open.

**Retained trigger/replay inventory correction, 2026-10-21 (read-only):**
the CO2 result above is not current-native evidence. Its log reports a
temporary `pkgload` DLL MD5 `ea0e2f72d87d401db15557e0ecc151c9`, but a fresh
read-only comparison finds checkout and installed `EDI.so` are both MD5
`a07120a2c7181f9992aa1c4993fcffdf` / SHA-256
`f7cf39dec10be2caaf84f8813d38e2b0d1d8be1b9a070b0f30bd42f62d9006c7`.
Thus the earlier claim that this log's DLL matches today's checkout/installed
artifact is stale; the search remains a bounded negative screen. Two other
retained 2026-10-21 logs are likewise negative: `mcycle` (`accel ~ times`,
n=133, seeds 20261401:20261406; 0/6 joint triggers) and `swiss`
(`Fertility ~ Agriculture + Examination + Education + Catholic +
Infant.Mortality`, n=47, seeds 20261201:20261206; 0/6 joint triggers).
Their log SHA-256 values are respectively
`166fbe8130fefc30fc47c8c98eb76488fa67627137704104226b6cacb307dba9` and
`3056a9d0c431ff985e5e080e3ebb83396ede1053b7ba8e9df3291b96bbd0f47d`; both
also report the `ea0e2f...151c9` temporary DLL. None of these three logs has
the TODO-33 provenance sidecar, a trigger-positive replay path, or the saved
permutation/assignment inputs needed to rerun the exact case. The older
`/tmp/edi-todo33-ready-20261016/` tree contains only a 20-seed trees CSV,
runner, command, and metadata explicitly stating no retained candidate or
candidate inputs. A deterministic synthetic replay is present in the tracked
test, but it proves branch behavior only, not a natural-data trigger. No
retained real-data failure can therefore be safely reproduced from existing
artifacts. Next acceptance requires a naturally triggering, provenance-stamped
search on the approved current source/native pair; retain the full trigger
inputs and replay bundle, then compare current and old-branch endpoints before
the separately required repeated-trial coverage assessment. No replay/search,
build/install, or canonical write was performed in this audit.

**Installed contract-test recheck, 2026-10-21:** the bounded existing test
`R/package_tests/testthat_bulk/test-rand-ci-bisection-and-high-precision-refinement-reference.R`
passed all 37 expectations with 0 failures, warnings, or skips using installed
EDI 1.0.3. It was run with `library(EDI)` followed in the same `Rscript`
process by `testthat::test_file(..., reporter = "summary")`; the test process
reported DLL
`/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI/libs/EDI.so`, MD5
`ea0e2f72d87d401db15557e0ecc151c9`. This confirms the controlled
public-orchestration/cache contract under the currently installed artifact;
the test stubs p-values and does not establish a permutation-backed trigger.
The retained real-data search evidence above remains negative: no run has
recorded the joint cheap-span stop, wide bracket, finite fresh full-precision
straddling endpoints with span above tolerance, and at least one upper
midpoint (`upper_inner_refine = TRUE`). Remaining acceptance is a
trigger-producing real-data input/seed replayed against the old-branch
counterfactual, followed by the required repeated-trial coverage comparison.
No build/install or canonical-result write occurred.

**Installed-package diagnostic rerun, 2026-10-21:** the focused reference file
was run with `Rscript -e 'library(EDI); testthat::test_file("R/package_tests/testthat_bulk/test-rand-ci-bisection-and-high-precision-refinement-reference.R")'`
against installed EDI 1.0.3 (welcome banner); the process completed with 6
failures, 0 warnings, 0 skips, and 54 passes. This was an installed-package
run, not a current-checkout R-layer validation; no DLL hash/path was captured.
The then-current fixture diagnostics observed scorer-call/t0s length
disagreements (11 scorer records versus 3 cached full calls; t0s lengths 500
and 50 versus the 501-draw oracle), two full-call p-value/oracle differences
(0.2480 vs 0.251 and 0.0533 vs 0.251), and the existing bound disagreement
(4.43 vs 4.04). These observations were inconclusive for checkout behavior:
the current source explicitly installs the passed full-precision MC control
on the inference private state, while the installed 1.0.3 run may have a
stale R namespace. The scorer instrumentation was subsequently corrected to
record the active MC control separately from the requested flag; at the time
of this diagnostic, that correction had not yet been run. A later complete-file
checkout-R/source-overlay pass is recorded below.

**Triage of installed-layer fixture failures:** the three `scored_upper`
failures recorded in the release checklist are one cascade, not three
independent regressions or an invalid fixture. The installed EDI 1.0.3 R layer
does not propagate the supplied full-precision control (`mc_enable = FALSE`)
to the inference object's active MC state. The test filters scorer records to
those with that active control, so it gets zero rows; the 0-vs-3 `vapply`
mismatch and subsequent `scored_upper[[i]]` bounds error follow. The current
checkout's `compute_randomization_ci_pval_cached()` scopes the passed control
onto the object's private state, and the recorded complete-file source-overlay
pass supports the fixture under current R source. This is an installed-R-layer
mismatch diagnosis, not a real-data trigger or coverage result. TODO-33 remains
open for trigger/replay and repeated-trial coverage; no production change,
build/install, or canonical result write was made.

**Additional bounded `datasets::UScrime` packaged-real-data screen
(2026-10-20):** a retained log for the public upper-bound screen covers
`M ~ So + Ed + Po1 + Po2 + LF + M.F + Pop + NW + U1 + U2 + GDP + Ineq +
Prob + Time` on 47 rows, seeds 20261584:20261595. Its 12-row summary reports
0 errors, cheap-span hits 12/12, fresh full-span hits 0/12, width hits 12/12,
and joint upper-inner-refinement triggers 0/12. Every call made two full
endpoint evaluations and zero upper midpoint evaluations. The retained log
`/tmp/edi_todo33_uscrime_trigger_20261020.log` has SHA-256
`798e145dda4262b7627eef61dfb54bebaf3a83af3012bb845a9bebb2fa8b5ae8`; it
identifies EDI 1.0.3 and a temporary loaded DLL with MD5
`8b3ca30492d7b1c790deeebe94b201ad`, but contains no exact invocation,
effective `r`/Monte Carlo settings, source hash, or explicit process-exit
footer. Treat this as a bounded negative screen only—not a replay bundle,
unreachability proof, calibration result, or closure of TODO-1's trigger and
counterfactual-replay gate.

**Additional bounded `MASS::survey` packaged-real-data search (2026-10-20):**
to test a distinct sample of continuous measurements, the public
`InferenceContinOLS` path was run on the 170 complete cases of
`Pulse ~ Age + Height + Sex`, seeds 20261164:20261175, with the unchanged
`alpha=0.10`, `r=501`, `pval_epsilon=0.005`, and sequential-MC controls
(`batch=5`, `min_draws=5`, `conf_level=0.5`). The exact command was
`EDI_TODO33_DATASET=survey EDI_TODO33_RESPONSE=Pulse EDI_TODO33_COVARIATES=Age,Height,Sex EDI_TODO33_SEED_START=20261163 timeout 180s Rscript /tmp/edi_todo33_swiss_trigger_20261020.R`.
All 12 calls completed without errors. The cheap-span, fresh full-span, and
bracket-width conditions held in 11/12, 1/12, and 11/12 cases respectively;
the joint count was 0/12. The lone full-span case (seed 20261171) also had
cheap span above tolerance and bracket width below tolerance. Every call made
exactly two full-precision endpoint evaluations and zero upper midpoint
evaluations. The harness loaded checkout R using
`pkgload::load_all("R/EDI", compile=FALSE)`; EDI was 1.0.3 and the
same-process DLL was `/tmp/Rtmp1LEzai/pkgload33b246c07/EDI.so`, MD5
`8b3ca30492d7b1c790deeebe94b201ad`. No replay RDS was produced. This bounded
negative search does not establish unreachability. The suggested
`datasets::attitude` candidate (30 rows; `rating` outcome and the other six
ratings as covariates) was screened on seeds 20261176:20261187 with the
unchanged public-API controls; the joint trigger occurred 0/12 times. Exact
command: `EDI_TODO33_DATASET=attitude EDI_TODO33_RESPONSE=rating EDI_TODO33_COVARIATES=complaints,privileges,learning,raises,critical,advance EDI_TODO33_SEED_START=20261175 timeout 180s Rscript /tmp/edi_todo33_swiss_trigger_20261020.R`. No replay bundle was produced; TODO-1 remains open, and this negative result does not establish unreachability.

**Additional bounded `datasets::stackloss` small-sample search
(2026-10-20):** the public `InferenceContinOLS` path was run on all 21 rows
of `stack.loss ~ Air.Flow + Water.Temp + Acid.Conc.`, seeds
20261152:20261163, with the same `alpha=0.10`, `r=501`,
`pval_epsilon=0.005`, and sequential-MC controls (`batch=5`, `min_draws=5`,
`conf_level=0.5`). The exact successful command was
`EDI_TODO33_DATASET=stackloss EDI_TODO33_RESPONSE=stack.loss EDI_TODO33_COVARIATES=Air.Flow,Water.Temp,Acid.Conc. EDI_TODO33_SEED_START=20261151 timeout 180s Rscript /tmp/edi_todo33_swiss_trigger_20261020.R`.
All 12 calls completed without errors. The cheap-span, fresh full-span, and
bracket-width conditions held in 12/12, 0/12, and 10/12 cases respectively;
the joint count was 0/12. Every call made exactly two full-precision endpoint
evaluations and zero upper midpoint evaluations. In every case the full
p-span remained at or below tolerance. The harness loaded checkout R with
`pkgload::load_all("R/EDI", compile=FALSE)`; EDI was 1.0.3 and the
same-process DLL was `/tmp/RtmpY0mIVV/pkgload32b9f4c46/EDI.so`, MD5
`8b3ca30492d7b1c790deeebe94b201ad`. No replay RDS was produced. This bounded
negative search does not establish unreachability; TODO-1 remains open for an
actual real-data trigger and replay/coverage comparison.

**Additional bounded `datasets::trees` small-sample search (2026-10-20):**
to try a small-N continuous-outcome case, the public `InferenceContinOLS`
path was run on all 31 rows of `Volume ~ Girth + Height`, seeds
20261140:20261151, with the same `alpha=0.10`, `r=501`,
`pval_epsilon=0.005`, and sequential-MC controls (`batch=5`, `min_draws=5`,
`conf_level=0.5`). The exact command was
`EDI_TODO33_DATASET=trees EDI_TODO33_RESPONSE=Volume EDI_TODO33_COVARIATES=Girth,Height EDI_TODO33_SEED_START=20261139 timeout 180s Rscript /tmp/edi_todo33_swiss_trigger_20261020.R`.
All 12 calls completed without errors. The cheap-span, full-span, and
bracket-width conditions held in 10/12, 0/12, and 10/12 cases respectively;
the joint count was 0/12. Every call made exactly two full-precision endpoint
evaluations and zero upper midpoint evaluations. In all cases the full
p-span remained at or below tolerance, so confirmation was not triggered.
The harness loaded checkout R with `pkgload::load_all("R/EDI",
compile=FALSE)`; EDI was 1.0.3 and the same-process DLL was
`/tmp/Rtmp5XeoSS/pkgload33dd87933/EDI.so`, MD5
`8b3ca30492d7b1c790deeebe94b201ad`. No replay RDS was produced. This bounded
negative search does not establish unreachability; TODO-1 remains open for an
actual real-data trigger and replay/coverage comparison.
