# Outstanding owner decisions

Every release TODO that is waiting on an owner decision is listed here, one row each, with a link to the release
file that holds the TODO. The TODO entry itself keeps the full write-up (options, evidence, the agent's
recommendation); this file is only the index. Rule: see "Owner decisions go in DECISIONS.md" in the repo's
`CLAUDE.md`.

When the owner decides, record the decision (dated) in the TODO entry and delete the row here.

Last updated 2026-11-21.

| TODO | Decision needed | Options (details in the TODO) |
|---|---|---|
| [v1.0.5-TODO-174](release_v1_0_5.md) | Apply the shared C++ jump guard in `pval_invert_ci_cpp` (CI endpoint returned as the Wald seed when the bisection never moves)? | (a) apply the prototyped guard to the shared CI-inversion code; (b) leave as is |
| [v1.0.6-TODO-74](release_v1_0_6.md) | Jackknife on `DesignFixedBlockedCluster` | (a) implement a delete-one-cluster jackknife with blocks as strata; (b) keep the refusal and fix the advice |
| [v1.0.6-TODO-82](release_v1_0_6.md) | `na.rm` in `compute_rand_two_sided_pval()` does nothing | (a) remove the argument; (b) keep it as "drop non-finite draws" and fix the docs (honouring `na.rm = FALSE` literally breaks every rand CI) |
| [v1.0.6-TODO-290](release_v1_0_6.md) | Confirm: KK `lambda` allowed in closed [0, 1] (the entry said (0, 1); an existing test uses `lambda = 0`) | confirm, or tighten to (0, 1) and change the test |
| [v1.0.6-TODO-294](release_v1_0_6.md) | Rerandomization with `prop_acceptable`: which law the randomization reference follows | (a) or (b) as in the entry; agent recommends (b): realized allocations and cost unchanged |
| [v1.0.6-TODO-298](release_v1_0_6.md) | Fixed designs with the default `n = NULL` | (a) infer `n = nrow(X_all)`; (b) require `n` in every fixed-design constructor |
| [v1.0.6-TODO-303](release_v1_0_6.md) | Plain randomization test at `delta = 0` for incidence outcomes on `DesignFixedFactorial` / `DesignFixedBlocking` | allow it, or keep refusing and fix `supports()` and the "Use Zhang" advice |
| [v1.0.6-TODO-304](release_v1_0_6.md) | BCa acceleration on 2-block blocking designs | (a) within-block jackknife; (b) fall back to percentile/BC |
| [v1.0.6-TODO-305](release_v1_0_6.md) | Confirm: a one-level factor next to a two-level one (`list(dose = 1, arm = 2)`) now errors; an existing test had pinned it as accepted | confirm, or allow one-level factors again |
| [v1.0.6-TODO-308](release_v1_0_6.md) | Exact event time 0 | (a) refuse at data entry for every class; (b) refuse only in the parametric classes |
| [v1.0.6-TODO-340](release_v1_0_6.md) | Count estimand tags | retag GLM/count-part coefficients `log_rate_ratio_conditional` (keeping `marginal` for true marginal estimands such as PoissonKKGEE), or keep the current tags |
| [v1.0.6-TODO-342](release_v1_0_6.md) | `InferenceSuite`: rows that raised a separation/boundary warning | (a) down-weight them in Combined Evidence; (b) exclude them |
