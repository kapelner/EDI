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
  effect, not just the unit fixture. A controlled public-API regression now
  forces the branch, but 12 real-data runs below reached only the confirmation
  helper, not its inner refinement loop.
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
static-review caveats without changing the acceptance criteria. The amended
search has not run and no candidate bundle exists. Keep it held until TODO-56
is terminal and host load is suitable; if a candidate is retained, pause for
review before any old-branch counterfactual or coverage run.
