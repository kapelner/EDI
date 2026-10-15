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
