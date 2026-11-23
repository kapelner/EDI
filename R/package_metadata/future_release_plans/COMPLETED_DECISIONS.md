# Completed owner decisions

Every owner ruling on a choice recorded in the release TODOs, in one place: the question, the options that were on
the table, the ruling (option, date, who), why, the options rejected and when to revisit. Same id scheme as
[PENDING_DECISIONS.md](PENDING_DECISIONS.md): `DECISION-v<version>-TODO-<n>`, with `...-TODO-<n>a` / `b` when one TODO
holds several rulings. The TODO entry keeps one line in place of the ruling:

`  - Decided <date> (<who>): <option in a few words>; see [DECISION-v1.0.6-TODO-82](COMPLETED_DECISIONS.md#DECISION-v1.0.6-TODO-82).`

When a pending decision is ruled on, its section moves here from `PENDING_DECISIONS.md` with Ruling / Why / date
added. Before reopening or re-arguing a choice, check this file. Order: releases newest first, and within a release,
TODO numbers highest first (table and sections alike). Rule: see "Owner decisions: `PENDING_DECISIONS.md`,
`COMPLETED_DECISIONS.md` and `DISMISSED_DECISIONS.md`" in the repo's `CLAUDE.md`.

Last updated 2026-11-23.

## Summary

| Decision | TODO | Ruling in one line | Date |
|---|---|---|---|
| [DECISION-v2.0.0-TODO-6f](#DECISION-v2.0.0-TODO-6f) | [v2.0.0-TODO-6f](release_v2_0_0.md) | e-value safe testing shelved (no mid-stream candidate addition in EDI) | 2026-09-09 |
| [DECISION-v2.0.0-TODO-6g](#DECISION-v2.0.0-TODO-6g) | [v2.0.0-TODO-6g](release_v2_0_0.md) | ModelDiagnostics contract and pilot ship in 1.x (in-sample checks need no fold substrate) | 2026-09-05 |
| [DECISION-v2.0.0-TODO-6i](#DECISION-v2.0.0-TODO-6i) | [v2.0.0-TODO-6i](release_v2_0_0.md) | ModelDiagnostics pilot cut to the Incidence GLM family; the other eight families move to v2.0.0 | 2026-10-22 |
| [DECISION-v1.2.0-TODO-258](#DECISION-v1.2.0-TODO-258) | [v1.2.0-TODO-258](release_v1_2_0.md) | one rerandomization kernel, documented default change, bundled with the RNG streams change | 2026-11-20 |
| [DECISION-v1.2.0-TODO-36](#DECISION-v1.2.0-TODO-36) | [v1.2.0-TODO-36](release_v1_2_0.md) | calibration campaigns on free GitHub-hosted runners only | undated |
| [DECISION-v1.2.0-TODO-31](#DECISION-v1.2.0-TODO-31) | [v1.2.0-TODO-31](release_v1_2_0.md) | D1 (b): also accept Eigen-typed source strings (additive); Eigen-only deferred to v2.0.0-TODO-7b | 2026-10-13 |
| [DECISION-v1.1.0-TODO-218a](#DECISION-v1.1.0-TODO-218a) | [v1.1.0-TODO-218](release_v1_1_0.md) | CountPoisson blocking-design fix accepted (stratified within-block jackknife fallback) | 2026-11-19 |
| [DECISION-v1.1.0-TODO-217](#DECISION-v1.1.0-TODO-217) | [v1.1.0-TODO-217](release_v1_1_0.md) | ZINB n = 50 oversize ruled inherent (small-sample degeneracy) | 2026-11-19 |
| [DECISION-v1.1.0-TODO-216](#DECISION-v1.1.0-TODO-216) | [v1.1.0-TODO-216](release_v1_1_0.md) | ZIP `~1` oversize ruled inherent (misspecification), documented | 2026-11-19 |
| [DECISION-v1.1.0-TODO-215](#DECISION-v1.1.0-TODO-215) | [v1.1.0-TODO-215](release_v1_1_0.md) | ExtendedRobins rows stay for now, citing this TODO; owner revisits later | 2026-11-17 |
| [DECISION-v1.1.0-TODO-194a](#DECISION-v1.1.0-TODO-194a) | [v1.1.0-TODO-194](release_v1_1_0.md) | path-audit gate: complete cloud campaign or local regeneration, whichever first | 2026-11-13 |
| [DECISION-v1.1.0-TODO-194b](#DECISION-v1.1.0-TODO-194b) | [v1.1.0-TODO-194](release_v1_1_0.md) | cloud comprehensive study runs 50 reps | 2026-11-13 |
| [DECISION-v1.1.0-TODO-184](#DECISION-v1.1.0-TODO-184) | [v1.1.0-TODO-184](release_v1_1_0.md) | frailty `~1` score rows: inherent misspecification, rows stay | 2026-11-12 |
| [DECISION-v1.1.0-TODO-163](#DECISION-v1.1.0-TODO-163) | [v1.1.0-TODO-163](release_v1_1_0.md) | 1.0.5: keep grading KK StratCox `~.` against the harness truth; known limitation in NEWS | 2026-10-31 |
| [DECISION-v1.1.0-TODO-158](#DECISION-v1.1.0-TODO-158) | [v1.1.0-TODO-158](release_v1_1_0.md) | observational classes get the `Fixed` prefix; old names deprecated for one release | 2026-10-25 |
| [DECISION-v1.1.0-TODO-61](#DECISION-v1.1.0-TODO-61) | [v1.1.0-TODO-61](release_v1_1_0.md) | Cox ties: Efron default, Breslow available | 2026-10-19 |
| [DECISION-v1.1.0-TODO-48](#DECISION-v1.1.0-TODO-48) | [v1.1.0-TODO-48](release_v1_1_0.md) | portable build by default everywhere; `EDI_PORTABLE=0` opt-in | 2026-10-14 |
| [DECISION-v1.1.0-TODO-15c](#DECISION-v1.1.0-TODO-15c) | [v1.1.0-TODO-15c](release_v1_1_0.md) | full hard `dead` -> `uncensored` rename, no compat alias | 2026-08-19 |
| [DECISION-v1.1.0-TODO-1a](#DECISION-v1.1.0-TODO-1a) | [v1.1.0-TODO-1](release_v1_1_0.md) | Cox-family randomization CI: refuse, like the stratified class | 2026-09-06 |
| [DECISION-v1.0.6-TODO-410](#DECISION-v1.0.6-TODO-410) | [v1.0.6-TODO-410](release_v1_0_6.md) | keep the L-BFGS Newton finish, accept the 1.3x-3x cost, allowlist the slowed benchmark rows | 2026-11-23 |
| [DECISION-v1.0.6-TODO-380a](#DECISION-v1.0.6-TODO-380a) | [v1.0.6-TODO-380](release_v1_0_6.md) | new testing type `lik_ratio_bartlett_approx_design_conservative` | 2026-11-21 |
| [DECISION-v1.0.6-TODO-380b](#DECISION-v1.0.6-TODO-380b) | [v1.0.6-TODO-380](release_v1_0_6.md) | `InferenceCountPoisson` gets the same split (default Bartlett result changes) | 2026-11-21 |
| [DECISION-v1.0.6-TODO-380c](#DECISION-v1.0.6-TODO-380c) | [v1.0.6-TODO-380](release_v1_0_6.md) | the testing type you ask for is the test you get (no silent Wald -> bootstrap fallback) | 2026-11-21 |
| [DECISION-v1.0.6-TODO-352](#DECISION-v1.0.6-TODO-352) | [v1.0.6-TODO-352](release_v1_0_6.md) | set the version to 1.0.5 (next release to ship) | 2026-11-21 |
| [DECISION-v1.0.6-TODO-327](#DECISION-v1.0.6-TODO-327) | [v1.0.6-TODO-327](release_v1_0_6.md) | Bartlett LR stays model-only; design-conservative variant becomes its own option (v1.0.6-TODO-380) | 2026-11-21 |
| [DECISION-v1.0.6-TODO-326](#DECISION-v1.0.6-TODO-326) | [v1.0.6-TODO-326](release_v1_0_6.md) | DepCens Bayesian bootstrap unsupported (warn, NA) | 2026-11-21 |
| [DECISION-v1.0.6-TODO-285](#DECISION-v1.0.6-TODO-285) | [v1.0.6-TODO-285](release_v1_0_6.md) | 1.2-1.3x is close enough; no further speedups; allowlist row stays until the v1.0.6 release | 2026-11-21 |
| [DECISION-v1.0.6-TODO-270a](#DECISION-v1.0.6-TODO-270a) | [v1.0.6-TODO-270](release_v1_0_6.md) | few permuted blocks per stratum: auto unit switches to observation_within_block | 2026-11-20 |
| [DECISION-v1.0.6-TODO-235](#DECISION-v1.0.6-TODO-235) | [v1.0.6-TODO-235](release_v1_0_6.md) | refuse the surrogate Bayesian bootstrap of the loggamma Weibull frailty IVWC class | 2026-11-19 |
| [DECISION-v1.0.6-TODO-234](#DECISION-v1.0.6-TODO-234) | [v1.0.6-TODO-234](release_v1_0_6.md) | align both treated-count roundings (changes realized allocations at ties / n = 3 mod 4) | 2026-11-19 |
| [DECISION-v1.0.6-TODO-233](#DECISION-v1.0.6-TODO-233) | [v1.0.6-TODO-233](release_v1_0_6.md) | report the convex hull of the accepted set | 2026-11-20 |
| [DECISION-v1.0.6-TODO-232](#DECISION-v1.0.6-TODO-232) | [v1.0.6-TODO-232](release_v1_0_6.md) | document now, no more start candidates; ridge detector in v1.1.0-TODO-258 | 2026-11-19 |
| [DECISION-v1.0.6-TODO-231a](#DECISION-v1.0.6-TODO-231a) | [v1.0.6-TODO-231](release_v1_0_6.md) | stratified jackknife variance: keep the rescaled replicates | 2026-11-20 |
| [DECISION-v1.0.6-TODO-231b](#DECISION-v1.0.6-TODO-231b) | [v1.0.6-TODO-231](release_v1_0_6.md) | keep the stratified jackknife bias formula, documented | 2026-11-20 |
| [DECISION-v1.0.6-TODO-231c](#DECISION-v1.0.6-TODO-231c) | [v1.0.6-TODO-231](release_v1_0_6.md) | ObservationalDesignBlocks with < 5 blocks: delete one observation within a block | 2026-11-20 |
| [DECISION-v1.0.6-TODO-231d](#DECISION-v1.0.6-TODO-231d) | [v1.0.6-TODO-231](release_v1_0_6.md) | stratified jackknife-Wald uses t with df = sum_h(n_h - 1) | 2026-11-20 |
| [DECISION-v1.0.6-TODO-230a](#DECISION-v1.0.6-TODO-230a) | [v1.0.6-TODO-230](release_v1_0_6.md) | g-comp RR subsampling cap default 0.8 (was 0.95) | 2026-11-20 |
| [DECISION-v1.0.6-TODO-230b](#DECISION-v1.0.6-TODO-230b) | [v1.0.6-TODO-230](release_v1_0_6.md) | symmetric centered p-value for every ratio pivot | 2026-11-20 |
| [DECISION-v1.0.6-TODO-230c](#DECISION-v1.0.6-TODO-230c) | [v1.0.6-TODO-230](release_v1_0_6.md) | user-settable generic cap: yes, later (v1.0.6-TODO-269) | 2026-11-20 |
| [DECISION-v1.0.6-TODO-222](#DECISION-v1.0.6-TODO-222) | [v1.0.6-TODO-222](release_v1_0_6.md) | the R guard is the fix; the C++ root fix is optional later | 2026-11-19 |
| [DECISION-v1.0.6-TODO-220](#DECISION-v1.0.6-TODO-220) | [v1.0.6-TODO-220](release_v1_0_6.md) | keep glm's expected-information Wald SE for probit / identity / log binomial (documented exception) | 2026-11-19 |
| [DECISION-v1.0.6-TODO-218a](#DECISION-v1.0.6-TODO-218a) | [v1.0.6-TODO-218](release_v1_0_6.md) | softer "no evidence of zero inflation" message instead of the warning | 2026-11-19 |
| [DECISION-v1.0.6-TODO-218b](#DECISION-v1.0.6-TODO-218b) | [v1.0.6-TODO-218](release_v1_0_6.md) | 5% cutoff for the no-inflation message confirmed | 2026-11-19 |
| [DECISION-v1.0.6-TODO-215a](#DECISION-v1.0.6-TODO-215a) | [v1.0.6-TODO-215](release_v1_0_6.md) | Wald always uses observed information; "fisher" stays the score-test default | 2026-11-19 |
| [DECISION-v1.0.6-TODO-215b](#DECISION-v1.0.6-TODO-215b) | [v1.0.6-TODO-215](release_v1_0_6.md) | partial PO on VGAM: publish the observed SE at the VGAM MLE | 2026-11-20 |
| [DECISION-v1.0.6-TODO-213](#DECISION-v1.0.6-TODO-213) | [v1.0.6-TODO-213](release_v1_0_6.md) | pass the realized treated count to the kernel; only redraws change | 2026-11-19 |
| [DECISION-v1.0.6-TODO-212](#DECISION-v1.0.6-TODO-212) | [v1.0.6-TODO-212](release_v1_0_6.md) | bump `EDI_TUNING_SCHEMA_VERSION` 1 -> 2; users re-tune once | 2026-11-19 |
| [DECISION-v1.0.6-TODO-211](#DECISION-v1.0.6-TODO-211) | [v1.0.6-TODO-211](release_v1_0_6.md) | delete the orphan scripts `heavy_paths.R` / `heavy_only.R` | 2026-11-19 |
| [DECISION-v1.0.6-TODO-210a](#DECISION-v1.0.6-TODO-210a) | [v1.0.6-TODO-210](release_v1_0_6.md) | record the three LR-bootstrap CI reasons in `procedure_failure_reason` | 2026-11-19 |
| [DECISION-v1.0.6-TODO-210b](#DECISION-v1.0.6-TODO-210b) | [v1.0.6-TODO-210](release_v1_0_6.md) | error up front when B < 2/alpha - 1 (breaking) | 2026-11-19 |
| [DECISION-v1.0.6-TODO-209](#DECISION-v1.0.6-TODO-209) | [v1.0.6-TODO-209](release_v1_0_6.md) | leave the default tolerance | 2026-11-19 |
| [DECISION-v1.0.6-TODO-208a](#DECISION-v1.0.6-TODO-208a) | [v1.0.6-TODO-208](release_v1_0_6.md) | guard via v1.0.6-TODO-30 candidate 1; BRT reusable worker added to its scope | 2026-11-19 |
| [DECISION-v1.0.6-TODO-208b](#DECISION-v1.0.6-TODO-208b) | [v1.0.6-TODO-208](release_v1_0_6.md) | clear "estimand not supported" error now; `InferenceCountNegBin` added to v1.4.0-TODO-17 | 2026-11-19 |
| [DECISION-v1.0.6-TODO-206](#DECISION-v1.0.6-TODO-206) | [v1.0.6-TODO-206](release_v1_0_6.md) | document that the estimate need not lie in the exact CI; regenerate the matching-design rows | 2026-11-19 |
| [DECISION-v1.0.6-TODO-204](#DECISION-v1.0.6-TODO-204) | [v1.0.6-TODO-204](release_v1_0_6.md) | add a little noise to both tuning fixtures | 2026-11-19 |
| [DECISION-v1.0.6-TODO-203](#DECISION-v1.0.6-TODO-203) | [v1.0.6-TODO-203](release_v1_0_6.md) | probit on a one-level response returns NA; the old zeros were a bug | 2026-11-20 |
| [DECISION-v1.0.6-TODO-201](#DECISION-v1.0.6-TODO-201) | [v1.0.6-TODO-201](release_v1_0_6.md) | add `supports_fisher_information()` to PropOdds; check cauchit / cloglog; verify the information per link | 2026-11-19 |
| [DECISION-v1.0.6-TODO-195](#DECISION-v1.0.6-TODO-195) | [v1.0.6-TODO-195](release_v1_0_6.md) | item (2): drop aliased count-part covariates on the positive rows, as `glm` does | 2026-11-19 |
| [DECISION-v1.0.6-TODO-191](#DECISION-v1.0.6-TODO-191) | [v1.0.6-TODO-191](release_v1_0_6.md) | drop degenerate subsamples, NA above a 5% cap (later 0.8 under v1.0.6-TODO-230); Firth deferred | 2026-11-19 |
| [DECISION-v1.0.6-TODO-187](#DECISION-v1.0.6-TODO-187) | [v1.0.6-TODO-187](release_v1_0_6.md) | disallow `n = NULL` for `DesignSeqOneByOneiBCRD` (breaking) | 2026-11-19 |
| [DECISION-v1.0.6-TODO-177](#DECISION-v1.0.6-TODO-177) | [v1.0.6-TODO-177](release_v1_0_6.md) | sequential designs seed each assignment from (seed, subject index); session RNG untouched | 2026-11-18 |
| [DECISION-v1.0.6-TODO-175](#DECISION-v1.0.6-TODO-175) | [v1.0.6-TODO-175](release_v1_0_6.md) | keep the log-scale width cap of 5 for theta-free RR intervals | 2026-11-19 |
| [DECISION-v1.0.6-TODO-168](#DECISION-v1.0.6-TODO-168) | [v1.0.6-TODO-168](release_v1_0_6.md) | both: add a symmetric studentized log-RR interval and document the undercoverage | 2026-11-19 |
| [DECISION-v1.0.6-TODO-160](#DECISION-v1.0.6-TODO-160) | [v1.0.6-TODO-160](release_v1_0_6.md) | both: +/-10 link-scale bound always; check RR on log(RR) | 2026-11-18 |
| [DECISION-v1.0.6-TODO-158a](#DECISION-v1.0.6-TODO-158a) | [v1.0.6-TODO-158](release_v1_0_6.md) | perfect predictors: detect in the constructor, drop the columns with a warning | 2026-11-18 |
| [DECISION-v1.0.6-TODO-156](#DECISION-v1.0.6-TODO-156) | [v1.0.6-TODO-156](release_v1_0_6.md) | keep the generic reason; no class-specific risk-diff reason | 2026-11-18 |
| [DECISION-v1.0.6-TODO-152](#DECISION-v1.0.6-TODO-152) | [v1.0.6-TODO-152](release_v1_0_6.md) | (c) both: LBFGS candidate from pscl's start and zero-part separation detection | 2026-11-19 |
| [DECISION-v1.0.6-TODO-149](#DECISION-v1.0.6-TODO-149) | [v1.0.6-TODO-149](release_v1_0_6.md) | keep `InferenceOrdinalGCompMeanDiff$get_standard_error()` private | 2026-11-18 |
| [DECISION-v1.0.6-TODO-147](#DECISION-v1.0.6-TODO-147) | [v1.0.6-TODO-147](release_v1_0_6.md) | Zhang estimate uses all subjects, as documented | 2026-11-18 |
| [DECISION-v1.0.6-TODO-143](#DECISION-v1.0.6-TODO-143) | [v1.0.6-TODO-143](release_v1_0_6.md) | allow the plain rand test/CI at nonzero delta under general censoring | 2026-11-18 |
| [DECISION-v1.0.6-TODO-138](#DECISION-v1.0.6-TODO-138) | [v1.0.6-TODO-138](release_v1_0_6.md) | warn when a hardened refit drops a covariate, in every such class | 2026-11-18 |
| [DECISION-v1.0.6-TODO-135](#DECISION-v1.0.6-TODO-135) | [v1.0.6-TODO-135](release_v1_0_6.md) | BCa also blocked below 5 deletion units | 2026-11-18 |
| [DECISION-v1.0.6-TODO-133](#DECISION-v1.0.6-TODO-133) | [v1.0.6-TODO-133](release_v1_0_6.md) | an empty reservoir arm warns too | 2026-11-18 |
| [DECISION-v1.0.6-TODO-132](#DECISION-v1.0.6-TODO-132) | [v1.0.6-TODO-132](release_v1_0_6.md) | option 1: `estimate_only` computes the same IVW combination | 2026-11-19 |
| [DECISION-v1.0.6-TODO-115](#DECISION-v1.0.6-TODO-115) | [v1.0.6-TODO-115](release_v1_0_6.md) | fix the RMST horizon across randomization draws | 2026-11-18 |
| [DECISION-v1.0.6-TODO-101](#DECISION-v1.0.6-TODO-101) | [v1.0.6-TODO-101](release_v1_0_6.md) | no new Python dependency; private numpy-only checks | 2026-11-18 |
| [DECISION-v1.0.6-TODO-99a](#DECISION-v1.0.6-TODO-99a) | [v1.0.6-TODO-99](release_v1_0_6.md) | ~12 min strict article render accepted; no CI-size switch | 2026-11-18 |
| [DECISION-v1.0.6-TODO-99b](#DECISION-v1.0.6-TODO-99b) | [v1.0.6-TODO-99](release_v1_0_6.md) | per-chunk opt-out for the deliberate warning chunk | 2026-11-18 |
| [DECISION-v1.0.6-TODO-98a](#DECISION-v1.0.6-TODO-98a) | [v1.0.6-TODO-98](release_v1_0_6.md) | weekly CI job over every feature area | 2026-11-18 |
| [DECISION-v1.0.6-TODO-98b](#DECISION-v1.0.6-TODO-98b) | [v1.0.6-TODO-98](release_v1_0_6.md) | weekly; Opus 5.5 effort high; $30 per-area cap; re-run unchanged areas every 42 days | 2026-11-18 |
| [DECISION-v1.0.6-TODO-87](#DECISION-v1.0.6-TODO-87) | [v1.0.6-TODO-87](release_v1_0_6.md) | keep the removal of the always-NaN keys | 2026-11-19 |
| [DECISION-v1.0.6-TODO-82](#DECISION-v1.0.6-TODO-82) | [v1.0.6-TODO-82](release_v1_0_6.md) | keep `na.rm`, documented as "drop non-finite draws" | 2026-11-18 |
| [DECISION-v1.0.6-TODO-76](#DECISION-v1.0.6-TODO-76) | [v1.0.6-TODO-76](release_v1_0_6.md) | KK with `n = NULL` matches once the model matrix exists; `n` not required | 2026-11-18 |
| [DECISION-v1.0.6-TODO-61](#DECISION-v1.0.6-TODO-61) | [v1.0.6-TODO-61](release_v1_0_6.md) | randomization replicates never chain warm starts, for any class | 2026-11-19 |
| [DECISION-v1.0.6-TODO-60](#DECISION-v1.0.6-TODO-60) | [v1.0.6-TODO-60](release_v1_0_6.md) | milder clamp (y(n-1)+0.5)/n in both KK21 proportion speedups | 2026-11-19 |
| [DECISION-v1.0.6-TODO-12](#DECISION-v1.0.6-TODO-12) | [v1.0.6-TODO-12](release_v1_0_6.md) | minimum 95% valid replicates, user-settable | 2026-11-19 |
| [DECISION-v1.0.6-TODO-4a](#DECISION-v1.0.6-TODO-4a) | [v1.0.6-TODO-4](release_v1_0_6.md) | trailing partial permuted block merged into the previous block | 2026-11-19 |
| [DECISION-v1.0.6-TODO-4b](#DECISION-v1.0.6-TODO-4b) | [v1.0.6-TODO-4](release_v1_0_6.md) | FixedBlocking: stratified JKn delete-one within strata (Wolter) | 2026-11-19 |
| [DECISION-v1.0.5-TODO-192](#DECISION-v1.0.5-TODO-192) | [v1.0.5-TODO-192](release_v1_0_5.md) | analysis scripts from `main` (TODO-200); acceptance list from the pinned commit (2026-11-17) | 2026-11-10 |
| [DECISION-v1.0.5-TODO-174](#DECISION-v1.0.5-TODO-174) | [v1.0.5-TODO-174](release_v1_0_5.md) | jump guard applied (67347569); owner approval not recorded | 2026-11-07 |
| [DECISION-v1.0.5-TODO-189](#DECISION-v1.0.5-TODO-189) | [v1.0.5-TODO-189](release_v1_0_5.md) | accept the score oversize as a documented finite-sample property; bootstrap score p in v1.1.0-TODO-166 | 2026-11-09 |
| [DECISION-v1.0.5-TODO-185](#DECISION-v1.0.5-TODO-185) | [v1.0.5-TODO-185](release_v1_0_5.md) | leave the ZIP/ZINB partial-collapse ridge case; pseudo-inverse score test deferred to v1.1.0-TODO-3a | 2026-11-06 |
| [DECISION-v1.0.5-TODO-184a](#DECISION-v1.0.5-TODO-184a) | [v1.0.5-TODO-184](release_v1_0_5.md) | coverage graded at the null only (beta_T = 0.5 rows: coverage_truth NA) | 2026-11-11 |
| [DECISION-v1.0.5-TODO-184b](#DECISION-v1.0.5-TODO-184b) | [v1.0.5-TODO-184](release_v1_0_5.md) | verify the prob_T 0.2 cells from the survival G4 regeneration's rows, not a separate run | 2026-11-12 |
| [DECISION-v1.0.5-TODO-184c](#DECISION-v1.0.5-TODO-184c) | [v1.0.5-TODO-184](release_v1_0_5.md) | no randomization bootstrap where the bootstrap is illegal (sequential designs except Bernoulli) | 2026-11-14 |
| [DECISION-v1.0.5-TODO-183](#DECISION-v1.0.5-TODO-183) | [v1.0.5-TODO-183](release_v1_0_5.md) | even-only designs take no prob_T argument until upgraded | 2026-11-03 |
| [DECISION-v1.0.5-TODO-179](#DECISION-v1.0.5-TODO-179) | [v1.0.5-TODO-179](release_v1_0_5.md) | LogBinomial Wald NA at a boundary MLE; frailty cells accepted as documented | 2026-11-09 |
| [DECISION-v1.0.5-TODO-176](#DECISION-v1.0.5-TODO-176) | [v1.0.5-TODO-176](release_v1_0_5.md) | option (ii): treatment-only Stereotype fit at the loading boundary is non-estimable; A + B otherwise | 2026-10-31 |
| [DECISION-v1.0.5-TODO-171](#DECISION-v1.0.5-TODO-171) | [v1.0.5-TODO-171](release_v1_0_5.md) | drop the max(model, Wald) clamp in InferenceCountKKGLMM | 2026-10-28 |
| [DECISION-v1.0.5-TODO-168](#DECISION-v1.0.5-TODO-168) | [v1.0.5-TODO-168](release_v1_0_5.md) | document the ExtendedRobins small-block limitation, no code change | 2026-10-28 |
| [DECISION-v1.0.5-TODO-165](#DECISION-v1.0.5-TODO-165) | [v1.0.5-TODO-165](release_v1_0_5.md) | percentile default for KMDiff and QuantileRegr classes; mid-rank z0 for every class | 2026-10-27 |
| [DECISION-v1.0.5-TODO-163](#DECISION-v1.0.5-TODO-163) | [v1.0.5-TODO-163](release_v1_0_5.md) | keep the independent-arms RMST SE in 1.0.x, documented; design-aware variance in v1.1.0 | 2026-10-27 |
| [DECISION-v1.0.5-TODO-162](#DECISION-v1.0.5-TODO-162) | [v1.0.5-TODO-162](release_v1_0_5.md) | defer to v1.1.0 with fix (b), the SPBR permuted block as the jackknife unit | 2026-10-27 |
| [DECISION-v1.0.5-TODO-161](#DECISION-v1.0.5-TODO-161) | [v1.0.5-TODO-161](release_v1_0_5.md) | accept the RMST BCa NA rows in the audit baseline | 2026-10-27 |
| [DECISION-v1.0.5-TODO-131a](#DECISION-v1.0.5-TODO-131a) | [v1.0.5-TODO-131](release_v1_0_5.md) | re-solve the optimal blocks on each resampled dataset (overrides the reuse default) | 2026-10-23 |
| [DECISION-v1.0.5-TODO-131b](#DECISION-v1.0.5-TODO-131b) | [v1.0.5-TODO-131](release_v1_0_5.md) | keep re-solving for every method incl. ompr, document the cost | 2026-10-23 |
| [DECISION-v1.0.5-TODO-129a](#DECISION-v1.0.5-TODO-129a) | [v1.0.5-TODO-129](release_v1_0_5.md) | accept the seeded KK bootstrap draw change | 2026-10-22 |
| [DECISION-v1.0.5-TODO-129b](#DECISION-v1.0.5-TODO-129b) | [v1.0.5-TODO-129](release_v1_0_5.md) | jitter seeded from the object seed; KKRankRegrIVWC deterministic in 1.0.5 (overrides default) | 2026-10-23 |
| [DECISION-v1.0.5-TODO-128](#DECISION-v1.0.5-TODO-128) | [v1.0.5-TODO-128](release_v1_0_5.md) | apply patch 14 at G1 with a KKT convergence gate | 2026-10-22 |
| [DECISION-v1.0.5-TODO-126a](#DECISION-v1.0.5-TODO-126a) | [v1.0.5-TODO-126](release_v1_0_5.md) | MC coverage truth requests a cheap inference type instead of rand_pval, now | 2026-10-22 |
| [DECISION-v1.0.5-TODO-126b](#DECISION-v1.0.5-TODO-126b) | [v1.0.5-TODO-126](release_v1_0_5.md) | defer the native Clayton maxit / fallback-start fix to v1.1.0-TODO-70 | 2026-10-22 |
| [DECISION-v1.0.5-TODO-124a](#DECISION-v1.0.5-TODO-124a) | [v1.0.5-TODO-124](release_v1_0_5.md) | raise r to >= 19 in a few representative migration goldens | 2026-10-22 |
| [DECISION-v1.0.5-TODO-124b](#DECISION-v1.0.5-TODO-124b) | [v1.0.5-TODO-124](release_v1_0_5.md) | investigate the bootstrap-CI-NA finding in 1.0.5 (TODO-129) | 2026-10-22 |
| [DECISION-v1.0.5-TODO-123](#DECISION-v1.0.5-TODO-123) | [v1.0.5-TODO-123](release_v1_0_5.md) | apply patch 08; the BRT Cox literal maxit 20 stays | 2026-10-22 |
| [DECISION-v1.0.5-TODO-120](#DECISION-v1.0.5-TODO-120) | [v1.0.5-TODO-120](release_v1_0_5.md) | accept the dep-cens bootstrap default B 1000 -> 501 | 2026-10-22 |
| [DECISION-v1.0.5-TODO-119a](#DECISION-v1.0.5-TODO-119a) | [v1.0.5-TODO-119](release_v1_0_5.md) | refuse rand CIs on exact 0/1 proportions under a logit shift | 2026-10-22 |
| [DECISION-v1.0.5-TODO-119b](#DECISION-v1.0.5-TODO-119b) | [v1.0.5-TODO-119](release_v1_0_5.md) | keep refusing scale-mismatched rand CIs; inversion is v1.1.0-TODO-65 | 2026-10-22 |
| [DECISION-v1.0.5-TODO-119c](#DECISION-v1.0.5-TODO-119c) | [v1.0.5-TODO-119](release_v1_0_5.md) | rand-CI Monte Carlo SE docs only; attribute is v1.1.0-TODO-66 | 2026-10-22 |
| [DECISION-v1.0.5-TODO-118](#DECISION-v1.0.5-TODO-118) | [v1.0.5-TODO-118](release_v1_0_5.md) | delete the unused generate_permutations_blocking_cpp kernel (patch 13 withdrawn) | 2026-10-22 |
| [DECISION-v1.0.5-TODO-116a](#DECISION-v1.0.5-TODO-116a) | [v1.0.5-TODO-116](release_v1_0_5.md) | defer NegBin jackknife and NB eps_g tightening to v1.1.0-TODO-67; apply patch 04 (later reversed) | 2026-10-22 |
| [DECISION-v1.0.5-TODO-116b](#DECISION-v1.0.5-TODO-116b) | [v1.0.5-TODO-116](release_v1_0_5.md) | path audit counts ok rows with non-finite results as non-estimable | 2026-10-23 |
| [DECISION-v1.0.5-TODO-116c](#DECISION-v1.0.5-TODO-116c) | [v1.0.5-TODO-116](release_v1_0_5.md) | withdraw patch 04; NegBin C++ eps_g default stays 1e-6 | 2026-11-04 |
| [DECISION-v1.0.5-TODO-115](#DECISION-v1.0.5-TODO-115) | [v1.0.5-TODO-115](release_v1_0_5.md) | keep max(model p, Wald) for Hurdle/CondPoisson/CountKKGLMM, no warning (also TODO-121) | 2026-10-22 |
| [DECISION-v1.0.5-TODO-114](#DECISION-v1.0.5-TODO-114) | [v1.0.5-TODO-114](release_v1_0_5.md) | defer full fast-C++ get_summary() tables to v1.1.0-TODO-56 | 2026-10-22 |
| [DECISION-v1.0.5-TODO-112](#DECISION-v1.0.5-TODO-112) | [v1.0.5-TODO-112](release_v1_0_5.md) | accept the seeded rand p/CI default change | 2026-10-22 |
| [DECISION-v1.0.5-TODO-111](#DECISION-v1.0.5-TODO-111) | [v1.0.5-TODO-111](release_v1_0_5.md) | the representative-subset smoke test closes the coverage item | 2026-10-22 |
| [DECISION-v1.0.5-TODO-109](#DECISION-v1.0.5-TODO-109) | [v1.0.5-TODO-109](release_v1_0_5.md) | accept the all-censored RMST arm = horizon default change | 2026-10-22 |
| [DECISION-v1.0.5-TODO-105](#DECISION-v1.0.5-TODO-105) | [v1.0.5-TODO-105](release_v1_0_5.md) | defer the add_block_fixed_effects opt-in to v1.1.0-TODO-64 | 2026-10-22 |
| [DECISION-v1.0.5-TODO-103](#DECISION-v1.0.5-TODO-103) | [v1.0.5-TODO-103](release_v1_0_5.md) | close with per-class CR2 in v1.1.0-TODO-55; accept the Satterthwaite df default change | 2026-10-22 |
| [DECISION-v1.0.5-TODO-101](#DECISION-v1.0.5-TODO-101) | [v1.0.5-TODO-101](release_v1_0_5.md) | document the BCa small-B guard (no fallback, guard unchanged) | 2026-10-22 |
| [DECISION-v1.0.5-TODO-97a](#DECISION-v1.0.5-TODO-97a) | [v1.0.5-TODO-97](release_v1_0_5.md) | Option A, one neutral ResamplingCore component; NonparametricBootstrap helper bodies win | 2026-10-22 |
| [DECISION-v1.0.5-TODO-97b](#DECISION-v1.0.5-TODO-97b) | [v1.0.5-TODO-97](release_v1_0_5.md) | (b) drop the load_resampling_draw_into_worker() dispatcher | 2026-10-22 |
| [DECISION-v1.0.5-TODO-97c](#DECISION-v1.0.5-TODO-97c) | [v1.0.5-TODO-97](release_v1_0_5.md) | (a) move the create_bootstrap_worker_state() NULL default into ResamplingCore | 2026-10-22 |
| [DECISION-v1.0.5-TODO-97d](#DECISION-v1.0.5-TODO-97d) | [v1.0.5-TODO-97](release_v1_0_5.md) | do the ResamplingCore refactor now, in 1.0.5 | 2026-10-22 |
| [DECISION-v1.0.5-TODO-67a](#DECISION-v1.0.5-TODO-67a) | [v1.0.5-TODO-67](release_v1_0_5.md) | approve the replacement protocol (mASMD primary, ~200 paired cases, matched-fraction guard) | 2026-10-22 |
| [DECISION-v1.0.5-TODO-67b](#DECISION-v1.0.5-TODO-67b) | [v1.0.5-TODO-67](release_v1_0_5.md) | confirm the R6 pass rules as proposed (margin 0.01, fraction guard 0.02) | 2026-10-23 |
| [DECISION-v1.0.5-TODO-62](#DECISION-v1.0.5-TODO-62) | [v1.0.5-TODO-62](release_v1_0_5.md) | (b) <= 0.01 log-bound tolerance; speed target deferred to v1.1.0-TODO-68; regenerate both reports | 2026-10-22 |
| [DECISION-v1.0.5-TODO-61](#DECISION-v1.0.5-TODO-61) | [v1.0.5-TODO-61](release_v1_0_5.md) | confirmed: match_objective = "distance" stays the default | 2026-10-22 |
| [DECISION-v1.0.5-TODO-60](#DECISION-v1.0.5-TODO-60) | [v1.0.5-TODO-60](release_v1_0_5.md) | accept the Pocock-Simon stream change with missing covariates as intended | 2026-11-10 |
| [DECISION-v1.0.5-TODO-59](#DECISION-v1.0.5-TODO-59) | [v1.0.5-TODO-59](release_v1_0_5.md) | G2 quiet-host cutoff: 1-min load average < 1.0, nothing else running | 2026-10-22 |
| [DECISION-v1.0.5-TODO-58a](#DECISION-v1.0.5-TODO-58a) | [v1.0.5-TODO-58](release_v1_0_5.md) | (a) restate the >= 1x target as workload-specific; speed acceptance to v1.1.0-TODO-68 | 2026-10-22 |
| [DECISION-v1.0.5-TODO-58b](#DECISION-v1.0.5-TODO-58b) | [v1.0.5-TODO-58](release_v1_0_5.md) | accept the Cox parity drift under the D2 rule; G3 met | 2026-11-10 |
| [DECISION-v1.0.5-TODO-57](#DECISION-v1.0.5-TODO-57) | [v1.0.5-TODO-57](release_v1_0_5.md) | (b) ship the R slices; native and fork/mirai work to v1.1.0-TODO-63 | 2026-10-22 |
| [DECISION-v1.0.5-TODO-56](#DECISION-v1.0.5-TODO-56) | [v1.0.5-TODO-56](release_v1_0_5.md) | confirm the 16 target IDs and argv as listed | 2026-10-22 |
| [DECISION-v1.0.5-TODO-55](#DECISION-v1.0.5-TODO-55) | [v1.0.5-TODO-55](release_v1_0_5.md) | noisy marginal coverage truth | 2026-10-21 |
| [DECISION-v1.0.5-TODO-53](#DECISION-v1.0.5-TODO-53) | [v1.0.5-TODO-53](release_v1_0_5.md) | accept the approximate condition_on_ws_for_rand_tests = TRUE default | 2026-10-20 |
| [DECISION-v1.0.5-TODO-52](#DECISION-v1.0.5-TODO-52) | [v1.0.5-TODO-52](release_v1_0_5.md) | (a) close the investigation; the G4 audit decides | 2026-10-22 |
| [DECISION-v1.0.5-TODO-33](#DECISION-v1.0.5-TODO-33) | [v1.0.5-TODO-33](release_v1_0_5.md) | (a) accept the synthetic trigger/replay evidence and close | 2026-10-22 |
| [DECISION-v1.0.5-TODO-31a](#DECISION-v1.0.5-TODO-31a) | [v1.0.5-TODO-31](release_v1_0_5.md) | 20-node acceptance = agreement with the 320-node optimum (0.75 SE / 0.10); revisit after TODO-153 | 2026-10-21 |
| [DECISION-v1.0.5-TODO-31b](#DECISION-v1.0.5-TODO-31b) | [v1.0.5-TODO-31](release_v1_0_5.md) | (i) accept the diagnosis, (ii)(a) runtime-probed link mapping, (iii)(a) R-only convergence fix | 2026-10-22 |
| [DECISION-v1.0.5-TODO-23a](#DECISION-v1.0.5-TODO-23a) | [v1.0.5-TODO-23](release_v1_0_5.md) | all-attempts coverage, <= 5% invalid per family, >= 457 attempts | 2026-10-21 |
| [DECISION-v1.0.5-TODO-23b](#DECISION-v1.0.5-TODO-23b) | [v1.0.5-TODO-23](release_v1_0_5.md) | calibrate after G1; all 18 CI operations; waive the targeted-compile criterion | 2026-10-22 |
| [DECISION-v1.0.5-TODO-18a](#DECISION-v1.0.5-TODO-18a) | [v1.0.5-TODO-18](release_v1_0_5.md) | (a) calibrate only the 9 named cells; drop plan TODO-3 | 2026-10-22 |
| [DECISION-v1.0.5-TODO-18b](#DECISION-v1.0.5-TODO-18b) | [v1.0.5-TODO-18](release_v1_0_5.md) | (b) re-solve DesignFixedOptimalBlocks on each resample; keep re-solving for ompr too | 2026-10-23 |
| [DECISION-v1.0.5-TODO-18c](#DECISION-v1.0.5-TODO-18c) | [v1.0.5-TODO-18](release_v1_0_5.md) | TODO-18 acceptance is simultaneous, Holm across 18 tests | 2026-10-28 |
| [DECISION-v1.0.5-TODO-18d](#DECISION-v1.0.5-TODO-18d) | [v1.0.5-TODO-18](release_v1_0_5.md) | option A, accept C2 and N5 as a documented limitation; fix to v1.0.6-TODO-18 | 2026-11-12 |
| [DECISION-v1.0.5-TODO-17](#DECISION-v1.0.5-TODO-17) | [v1.0.5-TODO-17](release_v1_0_5.md) | defer the Wilcoxon-specific remedy (to v1.5.0-TODO-1) | 2026-10-21 |
| [DECISION-v1.0.5-TODO-16](#DECISION-v1.0.5-TODO-16) | [v1.0.5-TODO-16](release_v1_0_5.md) | Clopper-Pearson 95% per method and stratum, 500 outer datasets, finite-p denominator | 2026-10-22 |
| [DECISION-v1.0.5-TODO-14](#DECISION-v1.0.5-TODO-14) | [v1.0.5-TODO-14](release_v1_0_5.md) | (a) predeclared expected skip for FixedBinaryMatch ~1 x pte_example; run authorized | 2026-10-22 |
| [DECISION-v1.0.5-TODO-12](#DECISION-v1.0.5-TODO-12) | [v1.0.5-TODO-12](release_v1_0_5.md) | approve the 720-evaluation bit-for-bit sweep after G1 | 2026-10-22 |
| [DECISION-v1.0.5-TODO-10a](#DECISION-v1.0.5-TODO-10a) | [v1.0.5-TODO-10](release_v1_0_5.md) | cap matched-Cox covariates; Firth to v1.1.0-TODO-69; document ionosphere limitation | 2026-10-22 |
| [DECISION-v1.0.5-TODO-10b](#DECISION-v1.0.5-TODO-10b) | [v1.0.5-TODO-10](release_v1_0_5.md) | keep the first-K = 6 cap rule; accept the R7 convergence thresholds | 2026-10-23 |
| [DECISION-v1.0.5-TODO-8](#DECISION-v1.0.5-TODO-8) | [v1.0.5-TODO-8](release_v1_0_5.md) | (a) fresh provenance-pinned 400-seed null rerun on the G1 build | 2026-10-22 |
| [DECISION-v1.0.5-TODO-6](#DECISION-v1.0.5-TODO-6) | [v1.0.5-TODO-6](release_v1_0_5.md) | (a) close on the existing evidence | 2026-10-22 |
| [DECISION-v1.0.5-TODO-5](#DECISION-v1.0.5-TODO-5) | [v1.0.5-TODO-5](release_v1_0_5.md) | option 1, refuse the Cox-family randomization CI | 2026-09-06 |
| [DECISION-v1.0.5-TODO-4a](#DECISION-v1.0.5-TODO-4a) | [v1.0.5-TODO-4](release_v1_0_5.md) | apply patch 07 only with B07/B07b after the guard-test review | 2026-10-22 |
| [DECISION-v1.0.5-TODO-4b](#DECISION-v1.0.5-TODO-4b) | [v1.0.5-TODO-4](release_v1_0_5.md) | close the before/after sub-item on existing captures plus G1 guard tests | 2026-10-23 |
| [DECISION-v1.0.5-TODO-3a](#DECISION-v1.0.5-TODO-3a) | [v1.0.5-TODO-3](release_v1_0_5.md) | (a) delete the unused exports (shim kept) | 2026-10-22 |
| [DECISION-v1.0.5-TODO-3b](#DECISION-v1.0.5-TODO-3b) | [v1.0.5-TODO-3](release_v1_0_5.md) | defer the Lin kernel to v1.1.0-TODO-57 | 2026-10-22 |
| [DECISION-v1.0.5-TODO-3c](#DECISION-v1.0.5-TODO-3c) | [v1.0.5-TODO-3](release_v1_0_5.md) | delete the bisection_ci_parallel_cpp shim too | 2026-10-28 |
| [DECISION-v1.0.5-TODO-2a](#DECISION-v1.0.5-TODO-2a) | [v1.0.5-TODO-2](release_v1_0_5.md) | (a) accept and restate the speedups as workload-specific | 2026-10-22 |
| [DECISION-v1.0.5-TODO-2b](#DECISION-v1.0.5-TODO-2b) | [v1.0.5-TODO-2](release_v1_0_5.md) | (b) defer direct order-statistic inversion to v1.1.0-TODO-62 | 2026-10-22 |
| [DECISION-v1.0.5-TODO-1a](#DECISION-v1.0.5-TODO-1a) | [v1.0.5-TODO-1](release_v1_0_5.md) | (a) optimize the retry chain | 2026-10-22 |
| [DECISION-v1.0.5-TODO-1b](#DECISION-v1.0.5-TODO-1b) | [v1.0.5-TODO-1](release_v1_0_5.md) | remove the ZOIB jackknife tuning exclusion now | 2026-10-22 |
| [DECISION-v1.0.5-TODO-1c](#DECISION-v1.0.5-TODO-1c) | [v1.0.5-TODO-1](release_v1_0_5.md) | waive reusable_bootstrap.md TODO-2/TODO-3 for v1.0.5 | 2026-11-10 |
| [DECISION-v1.0.5-TODO-1d](#DECISION-v1.0.5-TODO-1d) | [v1.0.5-TODO-1](release_v1_0_5.md) | "completed, default kept" meets plan TODO-6; TODO-1 closed | 2026-11-10 |

## v2.0.0

<a id="DECISION-v2.0.0-TODO-6f"></a>
### DECISION-v2.0.0-TODO-6f: Pursue the e-value / safe-testing plan (`e_value_safe_testing.md`)?

- **TODO:** [v2.0.0-TODO-6f](release_v2_0_0.md): **SHELVED**
- **Question:** The plan's TODO-1: pursue e-value safe testing at all?
- **Options on the table:** (a) pursue it; (b) no (shelve, keep the plan doc as a record).
- **Ruling:** (b) "no": shelved; nothing remains here, the plan doc is kept as a record, not an active item, 2026-09-09, owner (user decision)
- **Why:** Its sole justification was surviving adaptive mid-stream inclusion of more candidate models, but `applicable_design_classes` is discovered structurally and fit once; EDI's workflow never adds candidates mid-stream and none is planned. Without that use case the plan's own Stage 1 is conceded to be a valid but strictly less powerful alternative to CCT, for no benefit.
- **Rejected:** (a) pursuing it.

<a id="DECISION-v2.0.0-TODO-6g"></a>
### DECISION-v2.0.0-TODO-6g: Do `ModelDiagnostics`' checks need the v2.0.0 fold / split substrate, or can they ship in 1.x?

- **TODO:** [v2.0.0-TODO-6g](release_v2_0_0.md): **MOVED to v1.1.0 → `TODO-17z`**
- **Question:** The model-selection plan's TODO-1(e): `ModelDiagnostics` was scheduled with the v2.0.0 fold / split substrate.
- **Options on the table:** (a) keep it in v2.0.0 with the substrate; (b) move the declaration contract and pilot batteries to 1.x.
- **Ruling:** (b) moved to v1.1.0 `TODO-17z` (later v1.3.0-TODO-5); amended 2026-09-10 (user decision): no longer "nothing remains here", since v2.0.0-TODO-6i promotes the per-class rollout ledger to scoped v2.0.0 work, 2026-09-05, owner (user decision)
- **Why:** `ModelDiagnostics`' checks are in-sample and need no fold/split substrate, so the declaration contract and pilot batteries ship in 1.x.
- **Rejected:** (a) waiting for the v2.0.0 substrate.

<a id="DECISION-v2.0.0-TODO-6i"></a>
### DECISION-v2.0.0-TODO-6i: `ModelDiagnostics` pilot: nine families in v1.3.0, or Incidence GLM only?

- **TODO:** [v2.0.0-TODO-6i](release_v2_0_0.md): **`ModelDiagnostics` full-roster rollout + visualization**
- **Question:** The v1.3.0 contract item was to ship nine pilot battery families; cutting the pilot moves the other eight families (Cox, Poisson / quasi / robust, NB / ZINB / hurdle, ordinal, OLS / robust, Beta / ZOIB / fractional logit, GEE, GLMM) here.
- **Options on the table:** (a) the nine-family pilot in v1.3.0; (b) cut the pilot to the Incidence GLM family (logit / probit / log / identity / modified-Poisson links), moving the rest to v2.0.0.
- **Ruling:** (b) the pilot was cut to the Incidence GLM family (v1.3.0); this v2.0.0 item owns the other eight pilot families, each with its own known-violation recovery test, 2026-10-22, owner (user decision)
- **Why:** No reason recorded.
- **Rejected:** (a) the nine-family pilot.

## v1.2.0

<a id="DECISION-v1.2.0-TODO-258"></a>
### DECISION-v1.2.0-TODO-258: Route every rerandomization path through `rerandomization_search_cpp`: documented default change or opt-in?

- **TODO:** [v1.2.0-TODO-258](release_v1_2_0.md): **Route every rerandomization path through `rerandomization_search_cpp`.**
- **Question:** Generalizing the kernel to any n_T and deleting both R paths changes seeded assignments for odd n or prob_T != 0.5 (their distribution does not change).
- **Options on the table:** (a) one kernel, shipped as a documented default change; (b) opt-in.
- **Ruling:** (a) one kernel, a documented default change, not opt-in. NEWS ("Changes that alter results"): "For odd n or prob_T != 0.5, `DesignFixedRerandomization`'s seeded rerandomized assignments differ from v1.1; their distribution is unchanged." Regenerate every fixture and cross-platform digest pinned to those draws in the same PR; ship it in the same release as the non-R RNG streams change (`performance_profiling_and_upgrades.md` TODO-149, in v1.2.0-TODO-11), 2026-11-20, owner
- **Why:** So seeded streams change once in the 1.x line (the reason for bundling with the RNG streams change); no other reason recorded.
- **Rejected:** (b) opt-in.

<a id="DECISION-v1.2.0-TODO-36"></a>
### DECISION-v1.2.0-TODO-36: Calibration-campaign runners: free GitHub-hosted only, or self-hosted / paid runners?

- **TODO:** [v1.2.0-TODO-36](release_v1_2_0.md): **Published monthly calibration study: size,**
- **Question:** Which runners the monthly calibration campaign may use.
- **Options on the table:** (a) free GitHub-hosted runners only; (b) self-hosted or paid runners.
- **Ruling:** (a) free GitHub-hosted runners only (no self-hosted or paid runners), undated, owner
- **Why:** No reason recorded.
- **Rejected:** (b) self-hosted or paid runners.

<a id="DECISION-v1.2.0-TODO-31"></a>
### DECISION-v1.2.0-TODO-31: Custom C++ randomization statistic source strings: how do they reach the batched C++ loop (D1)?

- **TODO:** [v1.2.0-TODO-31](release_v1_2_0.md): **Batched C++ loop for the custom randomization statistic**
- **Question:** The documented source-string signature is Rcpp-typed; the pointer convention in `user_compiled_fns.h` is Eigen-typed. Plan `custom_rand_stat_batched_cpp_loop.md` Decision D1.
- **Options on the table:** (a) a generated adapter that wraps `y`/`w` into Rcpp vectors per call (keeps the speedup for legacy sources, but puts two R-vector allocations and R-API calls inside the loop); (b) accept Eigen-typed source strings as well (they and XPtrs get the C++ loop; Rcpp-typed sources unchanged, additive); (c) make the Eigen convention the only source-string signature (a documented-signature break).
- **Ruling:** (b) source strings may now also use the Eigen-typed `user_compiled_fns.h` signature; those sources, and XPtrs, get the C++ loop; existing Rcpp-typed sources are unchanged, 2026-10-13, owner (user decision)
- **Why:** The change is additive: every existing Rcpp-typed source behaves exactly as before.
- **Rejected:** (a) the per-call adapter; (c) Eigen-only, deferred to `release_v2_0_0.md → TODO-7b` (a 1.x warning on Rcpp-typed sources pointing at the Eigen form is the deprecation path).

## v1.1.0

<a id="DECISION-v1.1.0-TODO-218a"></a>
### DECISION-v1.1.0-TODO-218a: `InferenceCountPoisson` `~1` oversized on blocking designs: accept the stratified within-block jackknife fix?

- **TODO:** [v1.1.0-TODO-218](release_v1_1_0.md): **`InferenceCountPoisson` `~1`: every model-based test oversized on the blocking designs (FixedBlocking, SeqOneByOneSPBR, SeqOneByOneRandomBlockSize); cause unknown.**
- **Question:** The agent found a code bug: every model-based test of this class reports max(model p, jackknife p), and the leave-one-stratum jackknife with few strata is anti-conservative; the fix uses the stratified delete-1 jackknife. Done when the cells pass or the behaviour is documented with an owner ruling.
- **Options on the table:** (a) accept the fix (a code bug, not an inherent property); (b) rule it inherent and keep the accepted rows.
- **Ruling:** (a) fix accepted; reworked the same day to reuse the shared estimator instead of a private copy, 2026-11-19, owner
- **Why:** No reason recorded.
- **Rejected:** (b) ruling it inherent.

<a id="DECISION-v1.1.0-TODO-217"></a>
### DECISION-v1.1.0-TODO-217: `InferenceCountZeroInflatedNegBin` likelihood tests oversized at n = 50: a code bug or inherent?

- **TODO:** [v1.1.0-TODO-217](release_v1_1_0.md): **`InferenceCountZeroInflatedNegBin`: Wald / score / LR / gradient oversized at n = 50.**
- **Question:** Part (a): 215 flags at n = 50 on all 19 designs (size and 1 - coverage 0.134-0.230); none at n = 200 or 1000 except one `~1` score cell. Done when the cells pass, or the owner rules it inherent and the rows stay with a reason.
- **Options on the table:** (a) fix (document a minimum n and recommend the Wald with a bootstrap at small n, or a boundary-aware reference distribution); (b) rule it inherent and keep the accepted rows.
- **Ruling:** (b) inherent (small-sample degeneracy at n = 50, not a code bug); the accepted rows (reason starting `v1.1.0-TODO-217`) stay with that reason; documented in the class roxygen and Rd ("Many covariates in small samples": adjust for fewer covariates or prefer the LR test at small n), 2026-11-19, owner
- **Why:** Small-sample degeneracy at n = 50, not a code bug.
- **Rejected:** (a) a code fix.

<a id="DECISION-v1.1.0-TODO-216"></a>
### DECISION-v1.1.0-TODO-216: `InferenceCountZeroInflatedPoisson` `~1` likelihood tests anti-conservative at every n: code bug or inherent?

- **TODO:** [v1.1.0-TODO-216](release_v1_1_0.md): **`InferenceCountZeroInflatedPoisson`: model-based likelihood tests anti-conservative when covariates are omitted (`~1`), at every n.**
- **Question:** Score / gradient / LR with `~1` have size and 1 - coverage 0.134-0.173 at n = 50, 200 and 1000 (98 flags), the same pattern as TODO-174 (Hurdle Poisson); the agent found inherent misspecification, not a code bug.
- **Options on the table:** (a) robust (sandwich-information) score / LR variants shared with TODO-174; (b) document it in the class roxygen and point to ZeroInflatedNegBin or the sandwich Wald, ruling it inherent.
- **Ruling:** (b) inherent (model misspecification), done; the accepted rows (reason starting `v1.1.0-TODO-216`) stay; documented in the class roxygen and Rd ("Omitted covariates": prefer the sandwich Wald, adjust for covariates, or use ZeroInflatedNegBin), mirroring HurdlePoisson, 2026-11-19, owner
- **Why:** Model misspecification (omitted covariates), not a code bug.
- **Rejected:** (a) as a requirement here: the robust variants are optional and go with v1.1.0-TODO-174, which has the same cause.

<a id="DECISION-v1.1.0-TODO-215"></a>
### DECISION-v1.1.0-TODO-215: ExtendedRobins matched-design anti-conservatism: keep the accepted calibration rows (citing this TODO) for now?

- **TODO:** [v1.1.0-TODO-215](release_v1_1_0.md): **`InferenceIncidExtendedRobins`: owner revisit of the matched-design anti-conservatism (size about 0.15 at every n).**
- **Question:** The allowlist-hygiene audit (PR #19, 2026-11-17) removed the 24 `calibration_study_accepted.csv` rows citing the closed v1.0.5-TODO-168, so later campaigns would flag these cells again.
- **Options on the table:** (a) keep the rows, citing this TODO; (b) let the cells flag again.
- **Ruling:** (a) the rows stay for now and cite this TODO; the owner will look into the behaviour later, 2026-11-17, owner
- **Why:** No reason recorded (interim ruling pending the owner's revisit).
- **Rejected:** (b) letting the cells flag.
- **Revisit if:** the owner looks into the behaviour (this TODO).

<a id="DECISION-v1.1.0-TODO-194a"></a>
### DECISION-v1.1.0-TODO-194a: Cloud comprehensive study: what gates the path audits at a release?

- **TODO:** [v1.1.0-TODO-194](release_v1_1_0.md): **Run `comprehensive_tests.R` in the cloud after each calibration campaign.**
- **Question:** Which regeneration satisfies the path-audit release gate.
- **Options on the table:** Not recorded beyond the ruling.
- **Ruling:** a complete cloud campaign or a complete local regeneration at the release commit, whichever finishes first, 2026-11-13, owner
- **Why:** No reason recorded.

<a id="DECISION-v1.1.0-TODO-194b"></a>
### DECISION-v1.1.0-TODO-194b: Cloud comprehensive study: how many reps?

- **TODO:** [v1.1.0-TODO-194](release_v1_1_0.md): **Run `comprehensive_tests.R` in the cloud after each calibration campaign.**
- **Question:** Replicate count of the cloud comprehensive campaign.
- **Options on the table:** Not recorded beyond the ruling.
- **Ruling:** 50 reps, 2026-11-13, owner
- **Why:** So coverage can still be assessed from the comprehensive results.

<a id="DECISION-v1.1.0-TODO-184"></a>
### DECISION-v1.1.0-TODO-184: Weibull log-gamma frailty OneLik `~1` score rows: harness misspecification (inherent) or a defect?

- **TODO:** [v1.1.0-TODO-184](release_v1_1_0.md): **`InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik`: Weibull frailty (log-gamma) OneLik: Wald oversized at n = 50.**
- **Question:** An earlier 2026-11-07 investigation called `~.` n = 50 small-sample and `~1` honest harness misspecification (BinaryMatch pairs on covariates `~1` omits); the `~1` part needed an owner ruling.
- **Options on the table:** (a) inherent misspecification, rows stay; (b) a defect to fix.
- **Ruling:** (a) the 4 `~1` rows (n = 50 / 200) are inherent misspecification, not a defect; they stay, and their reason says so, 2026-11-12, owner
- **Why:** No reason recorded beyond the investigation (BinaryMatch pairs on covariates that `~1` omits).
- **Rejected:** (b) treating them as a defect.

<a id="DECISION-v1.1.0-TODO-163"></a>
### DECISION-v1.1.0-TODO-163: KK StratCox `~.` small-sample attenuation in v1.0.5: keep grading against the harness truth, or exclude the arm?

- **TODO:** [v1.1.0-TODO-163](release_v1_1_0.md): **`InferenceSurvivalKKStratCoxPHOneLik` on `~.`: small-sample attenuation, anti-conservative tests, and an unvalidated coverage truth.**
- **Question:** The harness truth matches pairs on the full X and caps only the Cox formula; R7 capped X before matching, so it validated a different estimand. What to do with the `~.` arm for 1.0.5?
- **Options on the table:** (a) keep grading it against the harness truth and document a known limitation; (b) exclude the arm via `COVERAGE_TRUTH_UNAVAILABLE_REAL_COVARIATES`.
- **Ruling:** (a) the `~.` arm stays graded against the harness truth and is documented as a known limitation in NEWS; the arm-level exclusion exists but is empty, 2026-10-31, owner
- **Why:** No reason recorded. Expect low-coverage audit findings for this arm until this TODO lands.
- **Rejected:** (b) excluding the arm.

<a id="DECISION-v1.1.0-TODO-158"></a>
### DECISION-v1.1.0-TODO-158: Observational designs: rename the three fixed classes with a `Fixed` prefix?

- **TODO:** [v1.1.0-TODO-158](release_v1_1_0.md): **Split `ObservationalDesign` into `FixedObservationalDesign` and `SeqOneByOneObservationalDesign`.**
- **Question:** Splitting the observational family into fixed and sequential halves: what happens to the three existing classes' names?
- **Options on the table:** (a) all three get the `Fixed` prefix and stay fixed designs (old names as deprecated aliases); (b) keep the current names.
- **Ruling:** (a) `ObservationalDesign` -> `FixedObservationalDesign`, `ObservationalDesignBlocks` -> `FixedObservationalDesignBlocks`, `ObservationalDesignMatching` -> `FixedObservationalDesignMatching`; each old name stays a deprecated alias for one release (warn once, same class object), 2026-10-25, owner
- **Why:** No reason recorded.
- **Rejected:** (b) keeping the unprefixed names.

<a id="DECISION-v1.1.0-TODO-61"></a>
### DECISION-v1.1.0-TODO-61: Cox ties: make Efron the default, with `ties = "breslow"` available?

- **TODO:** [v1.1.0-TODO-61](release_v1_1_0.md): **Cox `ties`: Efron becomes the default, `ties = "breslow"` exposed**
- **Question:** The Cox kernel is Breslow-only today.
- **Options on the table:** (a) Efron default, Breslow available; (b) keep Breslow.
- **Ruling:** (a) Efron is the default and `ties = "breslow"` stays available (not yet implemented), 2026-10-19, owner
- **Why:** Matches `survival::coxph`; more accurate under heavy ties; few users yet, so the default change is cheap now.
- **Rejected:** (b) Breslow default.

<a id="DECISION-v1.1.0-TODO-48"></a>
### DECISION-v1.1.0-TODO-48: Cross-platform reproducibility D1: portable build by default, or tuned by default?

- **TODO:** [v1.1.0-TODO-48](release_v1_1_0.md): **Cross-platform reproducibility guarantee**
- **Question:** Plan `cross_platform_reproducibility.md` Decision D1: which build every install gets by default.
- **Options on the table:** (a) portable by default everywhere (GitHub source, CRAN, r-universe, CI), tuned build opt-in via `EDI_PORTABLE=0`; (b) a tuned / native build by default.
- **Ruling:** (a) portable build by default for every install, with `EDI_PORTABLE=0` as the opt-in tuned build (implemented in the source tree), 2026-10-14, owner
- **Why:** No reason recorded in the release file; see the plan's D1 section (the float "tolerance" level still covers opt-in native builds, which CI's `native` leg measures).
- **Rejected:** (b) tuned by default.

<a id="DECISION-v1.1.0-TODO-15c"></a>
### DECISION-v1.1.0-TODO-15c: `dead` -> `uncensored` rename: R layer only, or R, C++ and Python, with or without a compat alias?

- **TODO:** [v1.1.0-TODO-15c](release_v1_1_0.md): **`dead` → `uncensored` rename**
- **Question:** Scoping of renaming the survival event / censoring indicator `dead` to `uncensored` (~576 R occurrences, `src/*.cpp`/`*.h`, Python binding).
- **Options on the table:** (a) R layer only; (b) full rename in R, C++ and the Python binding; with or without a `spec$dead` backward-compat alias.
- **Ruling:** (b) full rename: R, C++ and Python binding identifiers / args / columns all renamed; no `spec$dead` backward-compat alias (a hard break). The item later moved to `release_v1_4_0.md → TODO-2`; the decision is unchanged, only its release slot, 2026-08-19, owner (user decision)
- **Why:** The package is still pre-1.0.0-frozen public API territory for this field.
- **Rejected:** (a) R-layer-only; a compat alias.

<a id="DECISION-v1.1.0-TODO-1a"></a>
### DECISION-v1.1.0-TODO-1a: Cox-family randomization CI on the wrong scale: refuse it, or fix it?

- **TODO:** [v1.1.0-TODO-1](release_v1_1_0.md): **Phase 0 decision batch (item 12, `randomization_ci_construction_audit.md → TODO-1`)**
- **Question:** The Cox-family randomization CI was on the wrong scale.
- **Options on the table:** (a) refuse it, like the stratified class; (b) build a correctly scaled inversion.
- **Ruling:** (a) refuse, like the stratified class; implemented the same day (see v1.1.0-TODO-17x), 2026-09-06, owner (user decision)
- **Why:** No reason recorded.
- **Rejected:** (b) a corrected inversion. (A second item, the null construction, was withdrawn 2026-09-05: the code already uses impute-then-permute, verified by test.)

## v1.0.6

<a id="DECISION-v1.0.6-TODO-410"></a>
### DECISION-v1.0.6-TODO-410: L-BFGS Newton finish: accept the 1.3x-3x cost, or finish only the multistart winner (results move by up to 8e-4)?

- **TODO:** [v1.0.6-TODO-410](release_v1_0_6.md): **Likelihood fits through the shared L-BFGS wrapper got 1.3x-3x slower with v1.0.6-TODO-169.**
- **Context:** the v1.0.6-TODO-169 finish (`lbfgs_finish_with_newton_decrement()`) runs after every L-BFGS run whose
  gradient is above 1e-6, which on the benchmark data is every run, including each multistart start. Each finish
  evaluates at least one Hessian, and in the GLMM/CLMM/frailty kernels that Hessian is a central difference of the
  gradient costing about as much as the whole L-BFGS fit. Measured by kernel swap (2026-11-23, numbers in the TODO's
  measurement note): the finish is the whole slowdown, and it is not useless: on the benchmark fixtures it moves 6 of
  20 kernel/section fits toward the reference fitter (largest: ZIP wald 6.5e-3 -> 1.6e-4 vs pscl, clogit+GLMM 0.015),
  and on the colon scaling variants it fixes most of the raw / x1000 / +1e5 failures.
- **Options on the table:** (a) keep the finish everywhere as it is and put the slowed rows into
  `R/benchmark/benchmark_regression_allowlist.csv` citing v1.0.6-TODO-410: no result changes. (b) In the four
  multistart kernels (CLMM, ordinal GLMM, Poisson GLMM, logistic GLMM) run each start without the finish and finish only
  the winner (an L-BFGS restart from the best start, with the finish); allowlist the single-start rows (ZIP, ZINB,
  hurdle NegBin, clogit+GLMM, Weibull frailty, Gaussian LMM), where one Hessian is the floor. Results move by up to
  7.9e-4 in the estimate (SE 8.9e-5, negLL 3e-5) on the benchmark data, inside the rule's own tolerance; on colon CLMM
  x1000 loses a partial improvement that was still wrong (estimate 0 instead of -0.218, truth -0.170). (c) (b) plus
  forward instead of central differences in `numerical_hessian()` during the finish: a further 10-40% on CLMM, frailty
  and ZINB, results move <= 6e-5 on benchmark data. (d) Remove the finish (back to the v1.0.4 verdict): restores speed,
  brings back the TODO-169 failures (wrong estimates reported as converged on raw and rescaled colon covariates).
- **Evidence:** times OFF / ON / (b), ms: CLMM wald 39 / 106 / 52, models 113 / 223 / 128; ordinal GLMM wald 37 / 103 /
  76; Poisson GLMM wald 17 / 21.5 / 16.8; logistic GLMM wald 15 / 20.5 / 17. A cheaper screen that skips the finish
  using LBFGSpp's quasi-Newton inverse Hessian was tried and rejected: it underestimates the Newton decrement by up to
  1e5x on the raw colon designs and keeps the old errors.
- **Recommendation (agent):** (b); (c) only if the remaining CLMM wald row (1.3x after (b)) must pass the canary
  without an allowlist entry.
- **Raised:** 2026-11-23, by the measurement agent working on v1.0.6-TODO-410.
- **Ruling:** (a) keep the finish everywhere and accept the cost; the slowed rows (CLMM, ordinal GLMM, Poisson GLMM,
  logistic GLMM kernel, Gaussian LMM, ZIP, ZINB, hurdle NegBin, conditional-logit + GLMM, Weibull frailty) go into
  `R/benchmark/benchmark_regression_allowlist.csv` citing v1.0.6-TODO-410. 2026-11-23, owner.
- **Why:** No reason recorded.
- **Rejected:** (b) finish only the multistart winner (the agent's recommendation; moves estimates by up to 7.9e-4);
  (c) (b) plus forward-difference Hessians; (d) remove the finish.
- **Revisit if:** the allowlist rows come out at the v1.0.6 release and these fits still fail the 1.25x canary, or a
  kernel gets an analytic Hessian that makes the finish cheap.


<a id="DECISION-v1.0.6-TODO-380a"></a>
### DECISION-v1.0.6-TODO-380a: Name of the opt-in design-conservative Bartlett option

- **TODO:** [v1.0.6-TODO-380](release_v1_0_6.md): **A separate opt-in design-conservative Bartlett option, and "the testing type you ask for is the test you get".**
- **Question:** Following DECISION-v1.0.6-TODO-327, the design-conservative Bartlett version becomes its own option: a new testing type, or an argument on the Bartlett methods?
- **Options on the table:** (a) a new testing type, e.g. `"lik_ratio_bartlett_approx_design_conservative"` (recommended: works through `set_testing_type()` and `InferenceSuite`); (b) an argument on the Bartlett methods.
- **Ruling:** (a) the new testing type is named `"lik_ratio_bartlett_approx_design_conservative"`, 2026-11-21, owner
- **Why:** No reason recorded (the recommendation was a testing type, so it works through `set_testing_type()` and `InferenceSuite`).
- **Rejected:** (b) an argument on the Bartlett methods.

<a id="DECISION-v1.0.6-TODO-380b"></a>
### DECISION-v1.0.6-TODO-380b: Does `InferenceCountPoisson` get the same model-only / design-conservative Bartlett split?

- **TODO:** [v1.0.6-TODO-380](release_v1_0_6.md): **A separate opt-in design-conservative Bartlett option, and "the testing type you ask for is the test you get".**
- **Question:** `InferenceCountPoisson`'s `lik_ratio_bartlett_approx` is already wrapped in its design-conservative rule (`R/EDI/R/inference_count_poisson.R:404`), the opposite of the KK count OneLik classes after DECISION-v1.0.6-TODO-327.
- **Options on the table:** (a) split it the same way (its current Bartlett result becomes the new option, so the default changes and needs a NEWS entry); (b) leave it as is.
- **Ruling:** (a) same split: its `lik_ratio_bartlett_approx` becomes the model-only Bartlett test and its current result moves to `"lik_ratio_bartlett_approx_design_conservative"`; changes the default Bartlett result, NEWS entry required, 2026-11-21, owner
- **Why:** No reason recorded (recommended for one rule across the count classes, in line with "the testing type you ask for is the test you get").
- **Rejected:** (b) leave it as is.

<a id="DECISION-v1.0.6-TODO-380c"></a>
### DECISION-v1.0.6-TODO-380c: May a testing type silently return another procedure (e.g. Wald falling back to a bootstrap interval)?

- **TODO:** [v1.0.6-TODO-380](release_v1_0_6.md): **A separate opt-in design-conservative Bartlett option, and "the testing type you ask for is the test you get".**
- **Question:** The KK count OneLik classes (and several count-likelihood / survival classes) fall back to the nonparametric-bootstrap interval when the model-based SE is unavailable under `testing_type = "wald"`.
- **Options on the table:** (a) keep silent fallbacks; (b) a testing type always returns that test: the Wald result, or NA with a recorded `procedure_failure_reason` and a classed warning (v1.0.6-TODO-255 convention), the bootstrap as its own option if still wanted.
- **Ruling:** (b) a testing type must return that test, never another procedure, 2026-11-21, owner
- **Why:** Owner principle: "If the user wants wald, we should always give wald." Changes results where a fallback fired, so it needs a NEWS entry.
- **Rejected:** (a) silent fallbacks.

<a id="DECISION-v1.0.6-TODO-352"></a>
### DECISION-v1.0.6-TODO-352: Development builds report the last release's version: what version should the development tree carry?

- **TODO:** [v1.0.6-TODO-352](release_v1_0_6.md): **Development builds still report version 1.0.4, so saved designs are stamped with a release whose seeding rule differs.**
- **Question:** `R/EDI/DESCRIPTION` said 1.0.4 while NEWS.md has a development section and the docs date the sequential seeding rule to v1.0.6, so a trial file stamped "1.0.4" points to the wrong allocation rule.
- **Options on the table:** (a) a development version above the last release (e.g. 1.0.5.9000), changed only in DESCRIPTION and then `python3 scripts/sync_version.py` (the entry's proposal); (b) set the version to the next release to ship.
- **Ruling:** (b) set the version to 1.0.5, 2026-11-21, owner
- **Why:** 1.0.5 is "the next release to ship; release_v1_0_5.md is closed and soon to be released" (owner).
- **Rejected:** (a) a `.9000` development version.

<a id="DECISION-v1.0.6-TODO-327"></a>
### DECISION-v1.0.6-TODO-327: KK count OneLik: keep `lik_ratio_bartlett_approx` model-only, or make it design-conservative like `lik_ratio`?

- **TODO:** [v1.0.6-TODO-327](release_v1_0_6.md): **`set_testing_type("lik_ratio_bartlett_*")` makes `compute_asymp_*()` return NULL on `InferenceContinKKOLSOneLik` and `InferenceCountPoisson`.**
- **Question:** On the KK count OneLik classes `lik_ratio` is design-conservative, but `lik_ratio_bartlett_approx` dispatches to the model-only Bartlett method, giving a narrower CI on the fixture: [-0.262, 0.663] vs [-0.277, 0.695].
- **Options on the table:** (a) keep Bartlett model-only and document it; (b) make it design-conservative, like `InferenceCountPoisson`.
- **Ruling:** (a) `lik_ratio_bartlett_approx` stays the model-only Bartlett-corrected LR test, documented in the class roxygen; a separate opt-in design-conservative Bartlett option is v1.0.6-TODO-380, 2026-11-21, owner
- **Why:** No reason recorded here; see the owner principle in DECISION-v1.0.6-TODO-380c.
- **Rejected:** (b) design-conservative Bartlett by default.

<a id="DECISION-v1.0.6-TODO-326"></a>
### DECISION-v1.0.6-TODO-326: DepCens Bayesian bootstrap resamples a Cox log HR: add weights to the dependent-censoring likelihood, or make the method unsupported?

- **TODO:** [v1.0.6-TODO-326](release_v1_0_6.md): **The `InferenceSurvivalDepCensTransformRegr` Bayesian bootstrap resamples a Cox log hazard ratio, not the class's log time ratio.**
- **Question:** `compute_estimate_with_bootstrap_weights()` replaces every weighted draw with a weighted `survival::coxph` surrogate, whose coefficient is a log hazard ratio (about -beta / sigma under a log-normal AFT) that ignores the dependent censoring.
- **Options on the table:** (a) add observation weights to the dependent-censoring likelihood (`DepCensTransformLikelihood`, `fast_dep_cens_transform_optim_cpp`) and refit per draw, warm-started from the full-data params; (b) if that is too slow or too unstable on small samples, make the Bayesian bootstrap unsupported (as the jackknife and randomization methods already are), with the reason in the docs.
- **Ruling:** (b) the Bayesian-bootstrap methods warn `edi_unsupported_procedure` and return NA, 2026-11-21, owner (recorded by the coordinator)
- **Why:** No reason recorded; the owner chose (b) on the code reading, without a numerical reproduction first.
- **Rejected:** (a) a weighted dependent-censoring refit.

<a id="DECISION-v1.0.6-TODO-285"></a>
### DECISION-v1.0.6-TODO-285: Zhang hull CI at ~1.2-1.3x the pre-hull time: accept, or pursue further speedups?

- **TODO:** [v1.0.6-TODO-285](release_v1_0_6.md): **The Zhang exact CI's convex-hull scan costs about 2x the v1.0.4 CI.**
- **Question:** After the C++ kernels the n = 1000 Bernoulli Fisher CI takes 9.6 ms vs 7.95 ms pre-hull (1.21x by medians, 1.26x median per-round ratio; earlier runs 1.19-1.29x), at about the canary's 1.25x but not clearly under it.
- **Options on the table:** (a) accept; (b) skip outcomes far below the mode with a certified error bound and an exact fallback near alpha (not bit-identical, ~2%); (c) a scan restricted to breakpoints when one component is present.
- **Ruling:** (a) 1.2-1.3x the pre-hull CI is close enough; the further options are not pursued. The benchmark allowlist row stays (it sits at about the canary's 1.25x and would fail intermittently); remove it at the v1.0.6 release, when the canary baseline includes the hull, 2026-11-21, owner
- **Why:** "1.2-1.3x the pre-hull CI is close enough" (owner).
- **Rejected:** (b) and (c).

<a id="DECISION-v1.0.6-TODO-270a"></a>
### DECISION-v1.0.6-TODO-270a: Permuted-block jackknife with few units per stratum: switch to `observation_within_block`, or a t reference?

- **TODO:** [v1.0.6-TODO-270](release_v1_0_6.md): **Permuted-block jackknife with few units per stratum is oversized.**
- **Question:** InferenceCountPoisson, RandomBlockSize, prob_T 0.2, n = 200, `~1`: jackknife-Wald size 0.082 [0.066, 0.101] (16-20 deletion units, 3-4 in the smallest stratum), against 0.055 with the "observation_within_block" unit; SPBR about 0.061 pooled over 3000 reps.
- **Options on the table:** (a) in `resolve_jackknife_unit("auto")`, when any stratum has fewer than about 5 permuted-block units, use "observation_within_block" (delete one subject within its stratum, Wolter 2007 Sec. 4.5); shared code, affects every class using the automatic unit; (b) a t reference with (units - strata) df.
- **Ruling:** (a), 2026-11-20, owner
- **Why:** No reason recorded.
- **Rejected:** (b) the t reference with (units - strata) df.

<a id="DECISION-v1.0.6-TODO-235"></a>
### DECISION-v1.0.6-TODO-235: `InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC`'s surrogate Bayesian bootstrap: refuse it, or build a weighted fit?

- **TODO:** [v1.0.6-TODO-235](release_v1_0_6.md): **KK IVWC leftovers after the Bayesian-bootstrap fix.**
- **Question:** Item (1): the class's own Bayesian-bootstrap hook is a marginal-Weibull surrogate, not the IVW estimator (bootstrap mean 0.55 vs estimate 0.63).
- **Options on the table:** (a) refuse it like the Normal IVWC class (v1.0.6-TODO-217); (b) build a weighted fit.
- **Ruling:** (a) refuse it (same mechanism as the Normal IVWC class), 2026-11-19, owner (ruling undated; applied in the agent's 2026-11-19 status)
- **Why:** No reason recorded.
- **Rejected:** (b) a weighted fit.

<a id="DECISION-v1.0.6-TODO-234"></a>
### DECISION-v1.0.6-TODO-234: Treated-count rounding across designs: align `DesignFixediBCRD` and the rerandomization `prop_acceptable` path, or document?

- **TODO:** [v1.0.6-TODO-234](release_v1_0_6.md): **Treated-count rounding differs between designs.**
- **Question:** (1) `DesignFixediBCRD` rounds a .5 tie up (n = 21, prob_T = 0.5: 11 treated) while `DesignSeqOneByOneiBCRD` uses R's `round()` (10). (2) `DesignFixedRerandomization` with `prop_acceptable` at prob_T = 0.5 uses `complete_randomization_forced_balanced_cpp` = floor(n/2) (n = 23: 11) while the other paths use `round(n * prob_T)` (12); the null is right but the documented count is wrong. Both fixes change realized allocations.
- **Options on the table:** (1) align (one-line R change in `design_fixed_ibcrd.R`, changes realized fixed allocations at ties) or document the difference; (2) use the forced-balanced kernel only when n is even (changes realized allocations for n = 3 mod 4) or document.
- **Ruling:** "align both", 2026-11-19, owner (ruling undated; recorded in the agent's 2026-11-19 DONE note)
- **Why:** No reason recorded.
- **Rejected:** documenting the differences instead.

<a id="DECISION-v1.0.6-TODO-233"></a>
### DECISION-v1.0.6-TODO-233: Gapped Zhang exact CIs: report the convex hull of the accepted set, or keep the connected piece and document it?

- **TODO:** [v1.0.6-TODO-233](release_v1_0_6.md): **Zhang exact CIs can have gaps.**
- **Question:** The combined two-sided exact p-value is not monotone in delta and can jump, so in about 2.5% of ordinary `InferenceIncidExactZhang` CIs on matching designs (8 of 323 checked) the accepted set has gaps, and the bisection returns only the piece around its starting point.
- **Options on the table:** (a) report the convex hull of the accepted set (conservative, standard for exact CIs); (b) keep the connected piece and document it.
- **Ruling:** (a) report the convex hull, 2026-11-20, owner (ruling undated; recorded by the 2026-11-20 DONE note)
- **Why:** No reason recorded by the owner; the option was described as "conservative, standard for exact CIs".
- **Rejected:** (b) the connected piece.

<a id="DECISION-v1.0.6-TODO-232"></a>
### DECISION-v1.0.6-TODO-232: Small ZIP fits stopping unflagged below a ridge: more start candidates, or document now?

- **TODO:** [v1.0.6-TODO-232](release_v1_0_6.md): **Small ZIP fits that stop unflagged below the maximum.**
- **Question:** After the sharpened pscl start (x10), 41 of 96 sweep fits still stop unflagged at an interior maximum below a ridge; with continuous covariates in the zero formula the ZIP MLE often does not exist at small n. More candidates (x5 / x10 / x20 together) still leave 35 of 96, at ~3x cost.
- **Options on the table:** (a) add more start candidates (~3x cost); (b) document now, with a ridge detector later.
- **Ruling:** (b) document now, no more start candidates; the ridge detector (an LP over which zeros can be separated from every positive, then compare the Poisson fit on the rest) is filed by the coordinator as v1.1.0-TODO-258, 2026-11-19, owner
- **Why:** No reason recorded (recorded cost of more candidates: ~3x).
- **Rejected:** (a) more start candidates.

<a id="DECISION-v1.0.6-TODO-231a"></a>
### DECISION-v1.0.6-TODO-231a: Stratified jackknife variance: keep the rescaled (reweighting-equivalent) replicates, or the literal (n_h-1)/n_h form?

- **TODO:** [v1.0.6-TODO-231](release_v1_0_6.md): **Stratified jackknife follow-ups.**
- **Question:** Item (1): TODO-4 applies Wolter's JKn formulas to reweighting-equivalent replicates theta* = theta-hat + r_h (theta_(h,i) - theta-hat), r_h = n_h(N-1)/(N(n_h-1)), because EDI's replicates are unweighted subset refits and the literal (n_h-1)/n_h weight undercovers on SPBR (0.89-0.93 vs 0.92-0.96). The bias form rested on recollection of Wolter (paywalled); verify against the book.
- **Options on the table:** (a) confirm the rescaled form; (b) switch to the literal form (one-line change in `edi_jackknife_bias_variance()`).
- **Ruling:** (a) variance: rescaled form kept, 2026-11-20, owner via the agent E status note of 2026-11-20 ("kept per the owner decision"; the ruling itself may be earlier)
- **Why:** No reason recorded by the owner; the coverage numbers above (literal form undercovers on SPBR).
- **Rejected:** (b) the literal (n_h-1)/n_h form.

<a id="DECISION-v1.0.6-TODO-231b"></a>
### DECISION-v1.0.6-TODO-231b: Stratified jackknife bias on EDI's unweighted refits: keep, set to 0, or a ratio correction?

- **TODO:** [v1.0.6-TODO-231](release_v1_0_6.md): **Stratified jackknife follow-ups.**
- **Question:** The bias sum_h (n_h-1)(theta_bar_h - theta_hat) is the stratified jackknife bias of Jones (1974) / Krewski & Rao (1981) on REWEIGHTED replicates; the r_h rescaling is first order only, so on EDI's refits it equals the ordinary unstratified bias (N-1)(theta_bar - theta_hat), which also counts the between-stratum spread. Sim (g(mean), 40000 reps): true bias 0.0815 / 0.0067 / -0.0004; Jones on reweighted 0.0854 / 0.0061 / -0.0005; EDI 0.108 / 0.036 / -0.0028 (overcorrects by up to ~0.4 SE when strata differ strongly; 0 for a difference in means); literal raw-refit form -0.10 / -0.088 (worse).
- **Options on the table:** (a) keep (documented); (b) set the stratified bias to 0 / report theta_hat; (c) a ratio correction (bias x (N-1)/N sum n_h^2 v_h/(n_h-1) / sum n_h (m_h^2 + v_h); matched Jones in the scalar sim, unproven for regressions).
- **Ruling:** (a) keep the current bias formula, documented in the roxygen (caveat: equals the ordinary (N-1)(theta_bar - theta_hat), can over-correct nonlinear estimators when strata differ), 2026-11-20, owner
- **Why:** No reason recorded.
- **Rejected:** (b) zero bias; (c) the ratio correction.

<a id="DECISION-v1.0.6-TODO-231c"></a>
### DECISION-v1.0.6-TODO-231c: `ObservationalDesignBlocks` with few strata-like blocks: keep leave-one-block-out, or delete within blocks?

- **TODO:** [v1.0.6-TODO-231](release_v1_0_6.md): **Stratified jackknife follow-ups.**
- **Question:** Item (5): ObservationalDesignBlocks resolves to "block"; its blocks are user-defined matched sets / strata / clusters, so leave-one-block-out is right for matched sets and clusters but NA with < 5 strata-like blocks (explicit `unit = "observation_within_block"` works). Its bootstrap resamples within blocks (strata reading).
- **Options on the table:** (a) keep; (b) switch to "observation_within_block" when there are < 5 blocks.
- **Ruling:** (b) with fewer than 5 blocks, `"auto"` resolves to "observation_within_block" (delete one observation within a block), 2026-11-20, owner
- **Why:** No reason recorded.
- **Rejected:** (a) keep "block" always.

<a id="DECISION-v1.0.6-TODO-231d"></a>
### DECISION-v1.0.6-TODO-231d: Stratified jackknife-Wald: z or t reference with df = sum_h (n_h - 1)?

- **TODO:** [v1.0.6-TODO-231](release_v1_0_6.md): **Stratified jackknife follow-ups.**
- **Question:** Item (6): 400 reps (n = 148, 2 prognostic binary strata, incidence, beta 0): jackknife-Wald z coverage 0.930, with t(sum_h (n_h-1) ~ 31 df) 0.943; mean SE 0.078 = SD 0.078; bias negligible. The shortfall is the z reference at ~31 df plus SE noise (MC SE 0.012).
- **Options on the table:** (a) keep z; (b) t reference with df = sum_h (n_h - 1) for stratified units (changes results).
- **Ruling:** (b) stratified jackknife Wald uses a t reference with df = sum_h(n_h - 1), 2026-11-20, owner
- **Why:** No reason recorded beyond the coverage numbers.
- **Rejected:** (a) z reference.

<a id="DECISION-v1.0.6-TODO-230a"></a>
### DECISION-v1.0.6-TODO-230a: Default `min_fraction_usable_samples` cap for g-comp RR subsampling / m-out-of-n: 0.95 or 0.80?

- **TODO:** [v1.0.6-TODO-230](release_v1_0_6.md): **Ratio subsampling follow-ups.**
- **Question:** Item (1): at 0.95, 9% (subsampling) / 29% (m-out-of-n) of null datasets return NA, the size among the rest is 0.016 / 0.000, and 7 / 9 of the 11 datasets where Wald rejects become NA, because degenerate draws pile up where log RR-hat is extreme. At 0.80: 0% NA, size 0.040 / 0.030. (From v1.0.6-TODO-191: 0.90 gives NA 2% / 5%, size 0.031 / 0.011.)
- **Options on the table:** (a) keep 0.95; (b) 0.90; (c) 0.80.
- **Ruling:** (c) default 0.8 (was 0.95) on the public methods and the private RR pivot; still user-settable; the bootstrap / Bayesian-bootstrap `na.rm` 0.95 unchanged, 2026-11-20, owner via the agent's 2026-11-20 note ("Owner decision applied"; ruling date not stated)
- **Why:** No reason recorded beyond the size / NA numbers.
- **Rejected:** (a) 0.95; (b) 0.90.

<a id="DECISION-v1.0.6-TODO-230b"></a>
### DECISION-v1.0.6-TODO-230b: KK g-comp RR subsampling size: symmetric centered p-value for ratio pivots, or document?

- **TODO:** [v1.0.6-TODO-230](release_v1_0_6.md): **Ratio subsampling follow-ups.**
- **Question:** Item (3): the KK g-comp RR subsampling / m-out-of-n size stays low (0.015 / 0.010) because the subsample law of log RR* is skewed toward the observed effect, so the equal-tailed p = 2 min(.) doubles the heavy tail. A symmetric p-value (mean(|pivot| >= |t|)) gives 0.045 (subsampling; non-KK 0.055) but m-out-of-n stays 0.015. Changing the p-value type is a methodology change.
- **Options on the table:** (a) symmetric centered p-value for ratio pivots; (b) document.
- **Ruling:** (a) switch to the symmetric centered p-value; applied to all ratio pivots since no class became anti-conservative, 2026-11-20, owner
- **Why:** "consistency across ratio pivots preferred if size holds" (owner).
- **Rejected:** (b) document only.

<a id="DECISION-v1.0.6-TODO-230c"></a>
### DECISION-v1.0.6-TODO-230c: Make the 0.8 usable-draw cap on the generic ratio subsampling / m-out-of-n paths user-settable?

- **TODO:** [v1.0.6-TODO-230](release_v1_0_6.md): **Ratio subsampling follow-ups.**
- **Question:** The generic paths' cap is the fixed constant `ratio_resampling_min_fraction_usable = 0.8`; exposing it needs a new argument on the generic public methods in `inference_all_abstract_non_param_boot.R`.
- **Options on the table:** (a) make it user-settable now; (b) later, as a separate TODO; (c) keep it fixed.
- **Ruling:** (b) yes, later: a separate TODO (became v1.0.6-TODO-269, since done), 2026-11-20, owner ("yes, later", per the v1.0.6-TODO-269 header)
- **Why:** No reason recorded.
- **Rejected:** (a) now; (c) keep fixed.

<a id="DECISION-v1.0.6-TODO-222"></a>
### DECISION-v1.0.6-TODO-222: ZINB randomization oversize: take the R guard as the fix, or wait for the C++ root fix?

- **TODO:** [v1.0.6-TODO-222](release_v1_0_6.md): **`InferenceCountZeroInflatedNegBin`: the randomization test is oversized because `fast_zinb_cpp()` accepts non-MLE fits on permuted draws.**
- **Question:** Two acceptance shortcuts in `fast_zinb.cpp` accept non-MLE fits. An R guard (`fast_zinb_cpp_guarded()`) refits suspect fits with L-BFGS from a cold and the warm start and keeps the lowest nll (n = 50 `~.` randomization size 0.082 -> 0.045; about half of n = 50 fits trigger 2-3 extra fits); the root fix is C++ and needs a rebuild.
- **Options on the table:** (a) take the R guard as the fix (C++ root fix optional later); (b) fix the C++ acceptance paths first.
- **Ruling:** (a) the R guard is taken as the fix, with a NEWS "Changes that alter results" bullet and a class roxygen / Rd "Fitting" paragraph, 2026-11-19, owner
- **Why:** No reason recorded.
- **Rejected:** (b) waiting for the C++ root fix (kept as optional follow-up: if done, remove the R guard and its "Fitting" caveat).

<a id="DECISION-v1.0.6-TODO-220"></a>
### DECISION-v1.0.6-TODO-220: Probit / identity-binomial / log-binomial Wald SE: switch to observed information or keep glm's expected-information convention?

- **TODO:** [v1.0.6-TODO-220](release_v1_0_6.md): **Wald SEs that are not observed information, and SE paths that disagree.**
- **Question:** Item (1): `InferenceIncidProbitRegr` exposes only expected information, and `InferenceIncidBinomialIdentityRiskDiff` / `InferenceIncidLogBinomial` take their public Wald SE from the IRLS expected X'WX (as `glm()` does for non-canonical links; observed SE 0.5% / 7.7% higher on one fixture).
- **Options on the table:** (a) switch them to observed to follow the v1.0.6-TODO-215 rule (probit needs a real observed-Hessian closure); (b) keep glm's convention and leave the documented exception.
- **Ruling:** (b) keep `glm()`'s convention (expected information) for these three classes; the documented exception to the v1.0.6-TODO-215 observed-information rule stays, 2026-11-19, owner
- **Why:** No reason recorded.
- **Rejected:** (a) switching to observed information.

<a id="DECISION-v1.0.6-TODO-218a"></a>
### DECISION-v1.0.6-TODO-218a: ZIP / ZINB zero-part separation warning on data with no excess zeros: keep, silence, or soften?

- **TODO:** [v1.0.6-TODO-218](release_v1_0_6.md): **Zero-part separation warning follow-ups.**
- **Question:** Item (1): on ordinary count data with no excess zeros, ZIP's zero part saturates and ZINB falls back to its zero-inflation-off boundary fit, so `edi_zero_part_separation_warning` fires (about 12 existing test files, and calibration runs without inflation).
- **Options on the table:** (a) keep it (it is true: the zero part is not identified); (b) silence it for ZINB boundary fits only; (c) replace it with a softer message such as "no evidence of zero inflation".
- **Ruling:** (c) a softer message (`edi_no_zero_inflation_message`) in the no-inflation case; the warning stays for real separation, 2026-11-19, owner
- **Why:** No reason recorded.
- **Rejected:** (a) keep the warning everywhere; (b) silence it for ZINB boundary fits only.

<a id="DECISION-v1.0.6-TODO-218b"></a>
### DECISION-v1.0.6-TODO-218b: Confirm the 5% cutoff (`ZERO_AUGMENTED_NO_INFLATION_MAX_LOGIT` = qlogis(0.05)) for the no-inflation message

- **TODO:** [v1.0.6-TODO-218](release_v1_0_6.md): **Zero-part separation warning follow-ups.**
- **Question:** The implementing agent chose a 5% bound (every zero logit <= qlogis(0.05) ~ -2.94), not "every logit <= -10": on plain Poisson / NB data the MLE usually sends one arm to pi -> 0 and leaves the other at 0.5-4% (e.g. ZINB n = 500: 247 of 500 to 0, 3.7% for the rest).
- **Options on the table:** (a) confirm the 5% cutoff; (b) a stricter rule such as every logit <= -10.
- **Ruling:** (a) the 5% cutoff is confirmed, 2026-11-19, owner
- **Why:** No reason recorded by the owner (the agent's reason is above).
- **Rejected:** (b) "every logit <= -10".

<a id="DECISION-v1.0.6-TODO-215a"></a>
### DECISION-v1.0.6-TODO-215a: Public Wald p-value / CI vs `get_standard_error()` under "fisher": which information source wins?

- **TODO:** [v1.0.6-TODO-215](release_v1_0_6.md): **Information-source follow-ups.**
- **Question:** Item (1): for every `StandardModelCache` class the public Wald p-value and CI use the C++ `ssq_b_j` (observed information) whenever it is finite, while `get_standard_error()` follows the information preference; under "fisher" the two disagree (invisible for canonical-link GLMs, visible for the ordinal links after TODO-201). Which wins?
- **Options on the table:** (a) the information preference governs the Wald SE too; (b) the public Wald p-value and CI always use observed information.
- **Ruling:** (b) the public Wald p-value and CI always use observed information, including any fallback when the C++ `ssq_b_j` is not finite; "fisher" stays the score-test default; document that the information preference applies to score tests and score CIs only, 2026-11-19, owner
- **Why:** Observed information is the standard for Wald SEs (Efron & Hinkley 1978) and matches glm / polr / clm; "fisher" stays the score-test default because TODO-201 showed it calibrates better.
- **Rejected:** (a) letting the preference drive the Wald SE.

<a id="DECISION-v1.0.6-TODO-215b"></a>
### DECISION-v1.0.6-TODO-215b: `InferenceOrdinalPartialProportionalOddsRegr` on the VGAM path: which Wald SE source?

- **TODO:** [v1.0.6-TODO-215](release_v1_0_6.md): **Information-source follow-ups.**
- **Question:** Item (3): the class's published Wald SE is EXPECTED on the VGAM path (any nonparallel column), against the item-1 rule, while the fast-solver and clm fallback paths are observed. Moving the VGAM path to observed changes the treatment SE by a median 0.4-0.8% (max 1.0%) at n = 60-100, 0.2% (max 0.5%) at n = 300, 0.05% (max 0.2%) at n = 1000; estimates do not change.
- **Options on the table:** (a) publish the observed SE computed at the VGAM MLE (one R pass per fit, matches clm, follows item 1, makes the three backends agree); (b) put clm ahead of VGAM (moves estimates when the optimizers disagree); (c) keep VGAM's expected SE as a documented exception. Tables in the research note (section 7).
- **Ruling:** (a) publish the observed SE at the VGAM MLE, 2026-11-20, owner
- **Why:** No reason recorded by the owner; the agent recommended (a): one R pass per fit, matches clm, follows item 1, makes the three backends agree.
- **Rejected:** (b) clm ahead of VGAM; (c) VGAM's expected SE as a documented exception.

<a id="DECISION-v1.0.6-TODO-213"></a>
### DECISION-v1.0.6-TODO-213: iBCRD tie rounding: change the realized count (R side) or only the redraws (kernel side)?

- **TODO:** [v1.0.6-TODO-213](release_v1_0_6.md): **`DesignSeqOneByOneiBCRD`'s realized assignment and its randomization redraws round the treated count differently.**
- **Question:** When `n * prob_T` ends in .5, `assign_wt()` uses R's `round()` (half to even) but the C++ kernel uses `std::round` (half away from zero), so the randomization distribution is wrong for about half of odd n at the default prob_T.
- **Options on the table:** (a) R side uses `floor(x + 0.5)` (changes some realized allocations); (b) `draw_ws_raw` passes `round(n * prob_T) / n` to the kernel (keeps realized allocations, changes only redraws).
- **Ruling:** (b) pass the realized treated count to the kernel, so only the redraws change, 2026-11-19, owner
- **Why:** No reason recorded (recorded consequence: realized allocations are kept).
- **Rejected:** (a) changing the R-side rounding.

<a id="DECISION-v1.0.6-TODO-212"></a>
### DECISION-v1.0.6-TODO-212: Bump `EDI_TUNING_SCHEMA_VERSION` to invalidate tuning policies timed on covariate-dropped fits?

- **TODO:** [v1.0.6-TODO-212](release_v1_0_6.md): **Vacuous NA-equals-NA goldens and fixture follow-ups.**
- **Question:** Item (3): saved `tune_EDI_for_this_machine()` policies were timed on covariate-dropped continuous / proportion / survival fits before TODO-204. Invalidate them, or leave them valid?
- **Options on the table:** (a) bump `EDI_TUNING_SCHEMA_VERSION` so saved policies are invalidated; (b) leave them valid.
- **Ruling:** (a) bump `EDI_TUNING_SCHEMA_VERSION` 1 -> 2 (saved v1 policies are ignored; users re-tune once), 2026-11-19, owner (done by the coordinator)
- **Why:** No reason recorded.
- **Rejected:** (b) leaving saved policies valid.

<a id="DECISION-v1.0.6-TODO-211"></a>
### DECISION-v1.0.6-TODO-211: Orphan benchmark scripts that now hit the LR-bootstrap minimum-B error: raise B, pass alpha = 0.2, or delete?

- **TODO:** [v1.0.6-TODO-211](release_v1_0_6.md): **Leftovers of the LR-bootstrap minimum-B check.**
- **Question:** Item (1): `R/benchmark/heavy_paths.R` (PB = 10, now hard-errors) and `R/benchmark/heavy_only.R` (PB_H = 5, times the error inside tryCatch) are orphans that nothing references.
- **Options on the table:** (a) raise to B >= 39; (b) pass alpha = 0.2; (c) delete them.
- **Ruling:** (c) delete both scripts, 2026-11-19, owner (done by the coordinator)
- **Why:** Nothing referenced them.
- **Rejected:** (a) raise B; (b) alpha = 0.2.

<a id="DECISION-v1.0.6-TODO-210a"></a>
### DECISION-v1.0.6-TODO-210a: Record the three LR-bootstrap CI NA reasons in `procedure_failure_reason`?

- **TODO:** [v1.0.6-TODO-210](release_v1_0_6.md): **LR-bootstrap CI leftovers.**
- **Question:** Item (1): the three new LR-bootstrap CI NA reasons (`lik_ratio_bootstrap_ci_pval_at_estimate_unavailable`, `..._rejects_at_estimate`, `..._bound_not_found`) warn but are not recorded in `procedure_failure_reason`; record them?
- **Options on the table:** (a) record them; (b) leave them as warnings only.
- **Ruling:** (a) record the three reasons in `procedure_failure_reason`, as other procedures do, 2026-11-19, owner
- **Why:** So audits that read the recorded reasons see them (owner).
- **Rejected:** (b) warnings only.

<a id="DECISION-v1.0.6-TODO-210b"></a>
### DECISION-v1.0.6-TODO-210b: LR-bootstrap CI with B < 2/alpha - 1: warn up front or error up front?

- **TODO:** [v1.0.6-TODO-210](release_v1_0_6.md): **LR-bootstrap CI leftovers.**
- **Question:** Item (2): the LR-bootstrap CI and p-value don't check `B` up front; with B < 2/alpha - 1 the CI can never be found and this is only reported after the search. Add an up-front warning or error?
- **Options on the table:** (a) an up-front warning; (b) an up-front error.
- **Ruling:** (b) error up front when B < 2/alpha - 1, 2026-11-19, owner
- **Why:** No reason recorded. Recorded consequence: breaking, such calls used to return a warned NA after the search.
- **Rejected:** (a) a warning.

<a id="DECISION-v1.0.6-TODO-209"></a>
### DECISION-v1.0.6-TODO-209: Tighten the identity-binomial default tolerance so exact-tie draws stop depending on warm-start order?

- **TODO:** [v1.0.6-TODO-209](release_v1_0_6.md): **Leftovers from the identity-binomial randomization fix.**
- **Question:** Item (3): the identity-binomial MLE near the mu = 0 bound is accurate to ~1e-6 at the default tol, so exact-tie draws depend slightly on warm-start order; tightening tol moves stored estimates by ~1e-6.
- **Options on the table:** (a) tighten the tolerance (moves stored estimates by ~1e-6); (b) leave the default tolerance.
- **Ruling:** (b) leave the default tolerance, 2026-11-19, owner
- **Why:** TODO-205 already removed the 143 stalled tie draws (1 left).
- **Rejected:** (a) tightening the tolerance.
- **Revisit if:** the item (2) kernel fix changes the picture.

<a id="DECISION-v1.0.6-TODO-208a"></a>
### DECISION-v1.0.6-TODO-208a: ZIP BRT worker vs slow-path difference on barely identified inflation: document or guard?

- **TODO:** [v1.0.6-TODO-208](release_v1_0_6.md): **Two failing tests and two leftovers.**
- **Question:** Item (3): `InferenceCountZeroInflatedPoisson` BRT worker and slow path differ by ~0.1 / ~0.2 on plain Poisson data where the inflation part is barely identified (the reused worker warm-starts from a saturated zero part). Document or guard?
- **Options on the table:** (a) document; (b) guard (agent's recommendation: guard, under v1.0.6-TODO-30 candidate 1, no warm start from a saturated or ridge zero part).
- **Ruling:** (b) guard: folded into v1.0.6-TODO-30 (fix candidate 1, cold start when the zero part is saturated), with the BRT reusable worker added to its scope, 2026-11-19, owner
- **Why:** No reason recorded beyond the agent's recommendation (guard, not document).
- **Rejected:** (a) document only.

<a id="DECISION-v1.0.6-TODO-208b"></a>
### DECISION-v1.0.6-TODO-208b: NegBin classes without `set_estimand`: a clear "estimand not supported" error now, or wait for v1.4.0-TODO-17?

- **TODO:** [v1.0.6-TODO-208](release_v1_0_6.md): **Two failing tests and two leftovers.**
- **Question:** Item (4): `InferenceCountHurdleNegBin` has no `set_estimand` (errors "attempt to apply non-function"); v1.4.0-TODO-17 extends `set_estimand` later. Should the error become a clear "estimand not supported" error sooner?
- **Options on the table:** (a) add a clear error now; (b) leave it until v1.4.0-TODO-17.
- **Ruling:** (a) add a clear "estimand not supported" error to the NegBin classes now, and add plain `InferenceCountNegBin` to v1.4.0-TODO-17, 2026-11-19, owner
- **Why:** No reason recorded.
- **Rejected:** (b) waiting for v1.4.0.

<a id="DECISION-v1.0.6-TODO-206"></a>
### DECISION-v1.0.6-TODO-206: Pooled Zhang estimate outside the exact CI: document it, or change the estimate or the CI?

- **TODO:** [v1.0.6-TODO-206](release_v1_0_6.md): **The pooled Zhang estimate can lie outside the exact CI.**
- **Question:** After v1.0.6-TODO-147 the point estimate uses the pooled table while the exact CI inverts the combined matched + reservoir test, so the two are different quantities (in every case checked the estimate was inside, e.g. 2.34 in [0.66, 5.53]). Document that the estimate is not guaranteed to lie in the CI, or change one of them?
- **Options on the table:** (a) document that the estimate is not guaranteed to lie in the CI; (b) change one of the two quantities.
- **Ruling:** (a) document that the estimate is not guaranteed to lie in the exact CI, and regenerate the stored test results holding Zhang estimates on matching designs, 2026-11-19, owner
- **Why:** No reason recorded.
- **Rejected:** (b) changing the estimate or the CI.

<a id="DECISION-v1.0.6-TODO-204"></a>
### DECISION-v1.0.6-TODO-204: Perfect-predictor tuning fixtures: add noise to `inference_migration_complete_design()` / `edi_tuning_synthetic_experiment()`?

- **TODO:** [v1.0.6-TODO-204](release_v1_0_6.md): **Unmuffled procedure-NA warnings in two tests, and a fixture that is an exact perfect predictor.**
- **Question:** Item (2): `inference_migration_complete_design()` adds noise collinear with x, so y is exactly linear in w, x, z and every caller with covariates hits `edi_perfect_predictor_warning`; `edi_tuning_synthetic_experiment()` has no noise for proportion / continuous responses. Make the noise non-collinear at the source (may move goldens and the benchmark tuner's inputs)?
- **Options on the table:** (a) add a little (non-collinear) noise to both fixtures, at the cost of moving goldens and the tuner's inputs; (b) leave the fixtures as they are.
- **Ruling:** (a) add a little noise to both fixtures, 2026-11-19, owner
- **Why:** No reason recorded.
- **Rejected:** (b) leaving the noise-free fixtures.

<a id="DECISION-v1.0.6-TODO-203"></a>
### DECISION-v1.0.6-TODO-203: Ordered probit on a one-level response: NA (like cauchit / cloglog), or the old estimate 0?

- **TODO:** [v1.0.6-TODO-203](release_v1_0_6.md): **The three fixed-link ordinal kernels (cauchit, cloglog, probit) disagree on edge cases.**
- **Question:** After unifying the kernels, `InferenceOrdinalOrderedProbitRegr` on a one-level response gives NA instead of estimate 0 (a threshold-free fit with `converged = TRUE`), and single-level bootstrap draws are dropped instead of entering as exact zeros, which moves probit bootstrap CIs / p-values on such data. Confirm?
- **Options on the table:** (a) NA, as cauchit / cloglog already did (user-visible change for probit); (b) keep the old zeros.
- **Ruling:** (a) confirmed: probit on a one-level response returns NA, 2026-11-20, owner
- **Why:** "the old zeros were a bug" (owner).
- **Rejected:** (b) the old estimate 0 / zero draws.

<a id="DECISION-v1.0.6-TODO-201"></a>
### DECISION-v1.0.6-TODO-201: Should `InferenceOrdinalPropOddsRegr` support Fisher information like its probit sibling?

- **TODO:** [v1.0.6-TODO-201](release_v1_0_6.md): **`InferenceOrdinalPropOddsRegr` lacks `supports_fisher_information()`, unlike its probit sibling.**
- **Question:** Adding `supports_fisher_information()` changes the testing types offered and the information source PropOdds uses (results change), so it was left out of the bit-identical refactor. Should PropOdds support it (and check cauchit / cloglog for the same gap)?
- **Options on the table:** (a) add it (and check cauchit / cloglog); (b) leave PropOdds without it.
- **Ruling:** (a) add `supports_fisher_information()` to PropOdds and check cauchit / cloglog for the same gap; verify the Fisher information is mathematically correct for each link, 2026-11-19, owner
- **Why:** No reason recorded.
- **Rejected:** (b) leaving PropOdds without the flag.

<a id="DECISION-v1.0.6-TODO-195"></a>
### DECISION-v1.0.6-TODO-195: Drop aliased count-part covariates on the positive rows, so more small-n zero-augmented fits stay estimable?

- **TODO:** [v1.0.6-TODO-195](release_v1_0_6.md): **Leftovers from the zero-augmented identification fix.**
- **Question:** item (2), a change that alters results: drop aliased count-part covariates on the positive rows (as
  `glm` would), so more small-n datasets stay estimable instead of NA?
- **Options on the table:** (a) drop the aliased count-part covariates on the positive rows, as `glm` does; or keep
  returning NA (`zero_augmented_count_treatment_unidentified`) as the v1.0.6-TODO-186 guard does.
- **Ruling:** (a), 2026-11-19, owner. The docs must say it is the same as what `glm` does and link `glm`'s
  documentation.
- **Why:** no reason recorded beyond the item's own: more small-n datasets stay estimable instead of NA, matching
  `glm`.
- **Rejected:** keeping such fits NA.

<a id="DECISION-v1.0.6-TODO-191"></a>
### DECISION-v1.0.6-TODO-191: Risk-ratio subsampling / m-out-of-n p-values that almost never reject: which fix?

- **TODO:** [v1.0.6-TODO-191](release_v1_0_6.md): **Risk-ratio subsampling and m-out-of-n p-values almost never
  reject.**
- **Question:** how to fix the near-zero null size of the g-computation RR subsampling and m-out-of-n tests.
- **Options on the table:** larger default b / m for ratio estimands; drop degenerate subsamples; a studentized
  pivot; Firth fits in subsamples. Evidence (null size, 200 datasets, n = 80): dropping degenerate draws gives
  subsampling 0.040 and m-out-of-n 0.035 (threshold-insensitive); Firth in subsamples 0.050 / 0.015; b = n/2 gives
  0.090 (plain, anti-conservative through the (1 - b/n) factor) or 0.020 (with sqrt(b/(1 - b/n))); studentized
  0.08-0.12 (anti-conservative, Hauck-Donner). Agent's recommended fix (owner decision): treat a degenerate subsample
  (an arm with zero or all events, or a non-converged/separated fit) as unusable in `compute_rr_resampling_pivot()`,
  count it, and return NA with a recorded reason when the dropped fraction exceeds a cap (0.05 or 0.10); Firth later;
  do not use a studentized pivot or just raise the default b; document that the ordinary bootstrap is the better
  choice for RR.
- **Ruling:** drop degenerate subsamples (an arm with zero or all events, or a separated / non-converged fit) and
  return NA with a recorded reason when their fraction exceeds 5% (same threshold as v1.0.6-TODO-12), 2026-11-19,
  owner. Firth inside subsamples is deferred: noted as `firth_penalties_report.md TODO-6` (v1.1.0).
- **Why:** No reason recorded beyond the evidence above.
- **Rejected:** a studentized pivot; raising the default b; Firth subsample fits for now.
- **Later:** the owner reopened the TODO the same day ("keep this TODO open"; the code stays as shipped, documented as
  provisional), and the default cap was changed to 0.8 by the owner on 2026-11-20 under v1.0.6-TODO-230 (1).

<a id="DECISION-v1.0.6-TODO-187"></a>
### DECISION-v1.0.6-TODO-187: `DesignSeqOneByOneiBCRD` with `n = NULL`: fix the redraw, or disallow `n = NULL`?

- **TODO:** [v1.0.6-TODO-187](release_v1_0_6.md): **`DesignSeqOneByOneiBCRD` with `n = NULL` has the wrong
  randomization distribution.**
- **Question:** with no planned `n` the design falls back to a Bernoulli coin but redraws with forced balance at `t`.
- **Options on the table:** (a) when `private$n` is NULL, redraw with `generate_permutations_bernoulli_cpp(t, r,
  prob_T)` (the entry's "likely fix"); (b) disallow `n = NULL` for this design.
- **Ruling:** (b), 2026-11-19, owner: disallow `n = NULL` for `DesignSeqOneByOneiBCRD` with an assertion in the
  constructor (the design is kept; its Bernoulli fallback and the wrong redraw go away). Breaking.
- **Why:** No reason recorded.
- **Rejected:** (a) the Bernoulli redraw.

<a id="DECISION-v1.0.6-TODO-177"></a>
### DECISION-v1.0.6-TODO-177: Should sequential designs carry their own randomness, seeded per subject?

- **TODO:** [v1.0.6-TODO-177](release_v1_0_6.md): **Sequential designs get their own randomness, seeded per
  subject.**
- **Question:** a `DesignSeqOneByOne*` design calls `set.seed(seed)` once at construction and then draws from R's
  global stream, so (a) any RNG use between construction and the assignments changes the allocation, (b) a saved
  trial does not continue exactly after `readRDS()` without the user saving `.Random.seed`, and (c) it resets the
  session's stream. Raised as an open owner question in v1.0.6-TODO-79.
- **Options on the table (v1.0.6-TODO-79):** fix the docs only (say this for sequential designs and show saving
  `.Random.seed`, done there), or make sequential designs carry their own RNG state (a larger change; would make
  save/restore exact without user code).
- **Ruling:** own randomness, 2026-11-18, owner (the TODO was added as an owner decision): when `seed` is given,
  derive each assignment's draw from `(seed, subject index t)` (the seed-per-draw-index rule EDI already uses so
  results don't depend on the thread count), run it with the session's RNG state saved and restored. `seed = NULL`
  keeps using the session's stream.
- **Why:** allocations then depend only on the seed and the subjects' data, a saved trial continues exactly, and the
  session's stream is untouched.
- **Rejected:** documentation-only.

<a id="DECISION-v1.0.6-TODO-175"></a>
### DECISION-v1.0.6-TODO-175: Hold theta-free RR intervals to the log-scale width cap of 5, or the +/-10 bound only?

- **TODO:** [v1.0.6-TODO-175](release_v1_0_6.md): **Remaining raw-ratio-scale guards for the g-computation risk
  ratio.**
- **Question:** theta-free RR intervals (subsampling / m-out-of-n) are also held to the log-scale width cap of 5
  (bounds more than ~148x apart are rejected, as for log-OR subsampling).
- **Options on the table:** (a) keep the width cap of 5; (b) the +/-10 bound only.
- **Ruling:** (a), 2026-11-19, owner. No code change.
- **Why:** No reason recorded.
- **Rejected:** (b).

<a id="DECISION-v1.0.6-TODO-168"></a>
### DECISION-v1.0.6-TODO-168: KK g-comp RR studentized Bayesian-bootstrap undercoverage: new interval, documentation, or both?

- **TODO:** [v1.0.6-TODO-168](release_v1_0_6.md): **Investigate the low coverage of the
  `InferenceIncidKKGCompRiskRatio` studentized Bayesian-bootstrap interval.**
- **Question:** the raw studentized interval covers about 0.89 at n = 60 (a small-sample property of the Bayesian
  bootstrap-t, not KK-specific, not the truth).
- **Options on the table:** (a) switch to a symmetric studentized interval on log RR (0.93 KK, 0.91 plain) and/or
  (b) document the small-sample undercoverage and point to log Wald / percentile / log basic.
- **Ruling:** both, 2026-11-19, owner: (a) add a symmetric studentized Bayesian-bootstrap interval on log RR for the
  two g-computation risk-ratio classes; (b) document the small-sample undercoverage of the raw-scale studentized
  interval (about 0.89 at n = 60, 0.93 at n = 200) and point to log Wald / percentile / log basic.
- **Why:** No reason recorded. Agent's recommendation was (b), plus (a) if a log-scale studentized RR path is wanted
  for consistency.
- **Rejected:** none.

<a id="DECISION-v1.0.6-TODO-160"></a>
### DECISION-v1.0.6-TODO-160: Tighten the bootstrap extreme-interval check for log-scale and ratio estimands?

- **TODO:** [v1.0.6-TODO-160](release_v1_0_6.md): **Gaps left in the bootstrap extreme-interval check.**
- **Question:** (1) for log-scale estimands with a large outcome SD the outcome-SD cap (~100 log units) never binds,
  so degenerate Poisson/NegBin intervals are not caught; tightening it changes intervals accepted today. (2) The raw
  risk ratio of `InferenceIncidGCompRiskRatio` / `InferenceIncidKKGCompRiskRatio` keeps the outcome-SD cap: should a
  ratio scale get its own rule (e.g. apply the check to log RR)?
- **Options on the table:** change (1), change (2), both, or neither.
- **Ruling:** do both, 2026-11-18, owner. (1) For link-scale estimands always apply the +/-10 link-scale bound,
  whatever the outcome SD (newly rejects only intervals with a bound beyond a ratio of e^10). (2) Run the check for
  the g-computation risk-ratio classes on log(RR) with the link-scale rule.
- **Why:** No reason recorded.
- **Rejected:** keeping the outcome-SD cap for these cases.

<a id="DECISION-v1.0.6-TODO-158a"></a>
### DECISION-v1.0.6-TODO-158a: Perfect predictors among the inference covariates: drop them with a warning, or fit as specified?

- **TODO:** [v1.0.6-TODO-158](release_v1_0_6.md): **Detect perfect predictors in the inference covariates, drop
  them and warn.**
- **Question:** how to handle covariates that predict the response exactly (leakage).
- **Options on the table:** drop the columns in the constructor with a warning; fit as specified and mark the SE
  nonestimable.
- **Ruling:** 2026-11-18, owner. In the top `Inference` class's constructor, check whether `y ~ w + X` fits with zero
  residual variance; if so, find the smallest set of columns whose removal restores a nonzero residual (it can be a
  combination, e.g. `y = x1 + x2`) and raise one classed warning (e.g. `edi_perfect_predictor_warning`) naming them
  and suggesting leakage. The detection is a cheap least-squares residual check, not a model fit. The constructor
  drops those columns from the covariates the class will use, with the warning, and every later fit (estimate, CIs,
  resampling) uses the reduced set, so the model is fitted once, without them.
- **Why:** with an exact fit the estimate of tau is exact but the SE is 0, so p-values and intervals degenerate;
  randomization keeps the reduced model unbiased.
- **Rejected:** fit as specified and mark the SE nonestimable.
- **Note:** the per-response-type definition (owner, 2026-11-18) stays in the TODO as the specification; the three
  implementation judgment calls are pending as [DECISION-v1.0.6-TODO-158](PENDING_DECISIONS.md#DECISION-v1.0.6-TODO-158).

<a id="DECISION-v1.0.6-TODO-156"></a>
### DECISION-v1.0.6-TODO-156: Should risk-diff's `generate_mod()` set a class-specific nonestimable reason?

- **TODO:** [v1.0.6-TODO-156](release_v1_0_6.md): **`inference_incidence_risk_diff.R` (~L217-273) hard-codes the
  nonestimable reason `"model_fit_unavailable"`.**
- **Question:** the fix uses `generate_mod_nonestimable_reason %||% ...`, but no output changes today because
  risk-diff's `generate_mod()` never sets a reason; should it?
- **Options on the table:** add a class-specific reason; keep the generic one.
- **Ruling:** the fix stands (a reason set by `generate_mod()` is used); no class-specific reason is added,
  2026-11-18, owner (TODO closed).
- **Why:** "OLS risk difference fails in essentially one way (treatment not identified), which
  `model_fit_unavailable` already covers."
- **Rejected:** a class-specific reason.

<a id="DECISION-v1.0.6-TODO-152"></a>
### DECISION-v1.0.6-TODO-152: ZIP fits under zero-part separation: LBFGS candidate, separation detection, or both?

- **TODO:** [v1.0.6-TODO-152](release_v1_0_6.md): **ZIP fits under separation in the zero-inflation part.** (Split
  out of v1.0.6-TODO-142 item (3), where it was first left for an owner decision: LBFGS candidate from pscl's start,
  separation detection, or leave to v1.1.0's multistart work.)
- **Question:** the zero-part coefficients diverge (supremum at infinity); warm and cold starts stop at different
  points.
- **Options on the table:** (a) an LBFGS candidate from pscl's start, keeping the lower nll (cheap; the
  multi-candidate pattern used elsewhere); (b) detect separation in the zero part and warn / mark the zero-part
  estimate nonestimable; (c) both; (from TODO-142) leave to v1.1.0's multistart work. Constraint: respect the
  2026-11-16 rule that replicates chain warm starts only when `likelihood_concave` is TRUE.
- **Ruling:** (c) both, 2026-11-19, owner: an LBFGS candidate from pscl's start keeping the lower nll, and detect
  separation in the zero part and warn / mark the zero-part estimate nonestimable. Done together with
  v1.0.6-TODO-30 (same flat zero-inflation region); the TODO's header records "owner decision: keep for v1.0.6"
  (2026-11-18).
- **Why:** No reason recorded.
- **Rejected:** (a) or (b) alone; deferring to v1.1.0.

<a id="DECISION-v1.0.6-TODO-149"></a>
### DECISION-v1.0.6-TODO-149: `InferenceOrdinalGCompMeanDiff$get_standard_error()`: keep it private, or drop `Wald`?

- **TODO:** [v1.0.6-TODO-149](release_v1_0_6.md): **Remaining G-computation studentized gaps.**
- **Question:** the ordinal class's `get_standard_error()` "error" is not a bug: it is private there (the class
  composes `Wald`).
- **Options on the table:** keep it private (agent's recommendation); drop `Wald` to match the sibling classes.
- **Ruling:** keep `InferenceOrdinalGCompMeanDiff`'s `get_standard_error()` private (it composes `Wald`); no change,
  2026-11-18, owner.
- **Why:** No reason recorded (agent's recommendation).
- **Rejected:** dropping `Wald`.

<a id="DECISION-v1.0.6-TODO-147"></a>
### DECISION-v1.0.6-TODO-147: Should `InferenceIncidExactZhang`'s estimate use all subjects on KK designs, as documented?

- **TODO:** [v1.0.6-TODO-147](release_v1_0_6.md): **`InferenceIncidExactZhang`'s point estimate ignores the matched
  pairs on KK designs.**
- **Question:** the code counts the reservoir only (estimate always 0 when every subject is matched), while the docs
  say the pooled 2x2 table across all subjects.
- **Options on the table:** fix the code to match the docs; or change the docs.
- **Ruling:** the estimate must use all subjects, as documented, 2026-11-18, owner.
- **Why:** No reason recorded beyond matching the documentation.
- **Rejected:** documenting the reservoir-only estimate.

<a id="DECISION-v1.0.6-TODO-143"></a>
### DECISION-v1.0.6-TODO-143: Allow the plain randomization test / CI at nonzero delta under general censoring?

- **TODO:** [v1.0.6-TODO-143](release_v1_0_6.md): **In the slow randomization-bootstrap path with general censoring
  and `delta != 0`, `y_L`/`y_R` may not be shifted along with `y_sim`.**
- **Question:** the plain rand test / CI refused nonzero delta under general censoring; with the bounds shift now in
  place for the bootstrap randomization test, allow the plain ones too, with the same shift?
- **Options on the table:** allow with the same bounds shift; keep refusing.
- **Ruling:** allow, 2026-11-18, owner ("Follow-up 2026-11-18 (owner decision, agent)").
- **Why:** No reason recorded.
- **Rejected:** keeping the refusal.

<a id="DECISION-v1.0.6-TODO-138"></a>
### DECISION-v1.0.6-TODO-138: When separation forces a hardened refit that drops a covariate, warn?

- **TODO:** [v1.0.6-TODO-138](release_v1_0_6.md): **When separation forces a hardened refit,
  `InferenceIncidProbitRegr` silently drops the separated covariate; it must warn.**
- **Question:** the hardened QR step drops the covariate and reports the reduced fit with no message.
- **Options on the table:** warn; stay silent.
- **Ruling:** warn, naming the dropped column(s) and why, 2026-11-18, owner. Check every class sharing that
  harden-and-refit step (logit, g-computation, other GLM families) and warn there too; once per object, never inside
  resampling.
- **Why:** No reason recorded.
- **Rejected:** silent drops.

<a id="DECISION-v1.0.6-TODO-135"></a>
### DECISION-v1.0.6-TODO-135: Gate BCa below 5 deletion units too, like the jackknife?

- **TODO:** [v1.0.6-TODO-135](release_v1_0_6.md): **A jackknife with very few deletion units returns a finite but
  meaningless SE with no warning.**
- **Question:** the jackknife summary is NA below `EDI_JACKKNIFE_MIN_DELETION_UNITS = 5`; BCa was deliberately not
  gated (it uses replicates directly; with 2 units the acceleration is 0, so bias-corrected percentile), "owner to
  confirm".
- **Options on the table:** leave BCa ungated; gate it too.
- **Ruling:** BCa is also blocked below 5 units, 2026-11-18, owner.
- **Why:** No reason recorded.
- **Rejected:** leaving BCa ungated.

<a id="DECISION-v1.0.6-TODO-133"></a>
### DECISION-v1.0.6-TODO-133: Warn when an empty reservoir arm drops the KK Strat Cox IVWC reservoir half?

- **TODO:** [v1.0.6-TODO-133](release_v1_0_6.md): **`InferenceSurvivalKKStratCoxPHIVWC`'s reservoir treatment-only
  fallback is never checked.**
- **Question:** an empty arm dropped the reservoir silently (routine for small KK reservoirs, same as the sibling IVWC
  classes); to warn, change `nRT > 0L && nRC > 0L` to `nRT + nRC > 0L`.
- **Options on the table:** silent (as the siblings); warn.
- **Ruling:** an empty reservoir arm warns too, 2026-11-18, owner.
- **Why:** No reason recorded.
- **Rejected:** silent drop.

<a id="DECISION-v1.0.6-TODO-132"></a>
### DECISION-v1.0.6-TODO-132: KK Strat Cox IVWC `estimate_only = TRUE` is a different estimator: which way to align?

- **TODO:** [v1.0.6-TODO-132](release_v1_0_6.md): **`InferenceSurvivalKKStratCoxPHIVWC`'s `estimate_only = TRUE` is a
  different estimator.**
- **Question:** `estimate_only` weights the halves by sample size, the full call by inverse variance; resampling
  replicates use `estimate_only`.
- **Options on the table:**
  1. `estimate_only = TRUE` computes the same inverse-variance-weighted (IVW) combination as the full call
     (coordinator's recommendation). Bootstrap, jackknife and reusable-worker replicates then estimate the reported
     quantity, and the call-order dependence goes away. Cost: each replicate also computes both halves' variances, so
     resampling is slower for this class. Point estimates unchanged; bootstrap/jackknife results change.
  2. Report the sample-size-weighted estimator everywhere (make the full call match `estimate_only`). Keeps
     resampling fast, but changes the reported point estimate and uses a less efficient combination.
  3. Keep both and document the mismatch. No code change; the resampling intervals stay for a different estimator
     than the one reported, so this only labels the problem.
  Options 1 and 2 are "Changes that alter results" NEWS entries. Whichever is chosen, check the other KK IVWC classes
  for the same split (the 2026-11-07 Stereotype bug was the same kind).
- **Ruling:** option 1, 2026-11-19, owner; check the other KK IVWC classes for the same split. (First deferred by the
  owner on 2026-11-18: "leave for later".)
- **Why:** No reason recorded (coordinator's recommendation).
- **Rejected:** options 2 and 3.

<a id="DECISION-v1.0.6-TODO-115"></a>
### DECISION-v1.0.6-TODO-115: RMST randomization test: fix the horizon across draws, or require a prespecified `tau`?

- **TODO:** [v1.0.6-TODO-115](release_v1_0_6.md): **RMST on interval-censored `DesignFixedBlockedCluster` data with a
  strong effect: randomization p-value >= 0.05 and asymptotic CI NA.**
- **Question:** the default tau is recomputed in every randomization draw (observed 39, null draws 162-180), so the
  test has power below alpha at large effects (0.027 vs 0.927 with a prespecified tau = 30; null 0.047 both).
- **Options on the table:** fix the horizon across draws (pooled or observed tau held fixed); or document that `tau`
  must be prespecified for randomization tests.
- **Ruling:** fix the horizon across draws, 2026-11-18, owner.
- **Why:** No reason recorded beyond the power evidence.
- **Rejected:** documentation-only.

<a id="DECISION-v1.0.6-TODO-101"></a>
### DECISION-v1.0.6-TODO-101: Python input validation: adopt a dependency, or hand-written checks?

- **TODO:** [v1.0.6-TODO-101](release_v1_0_6.md): **Input-validation gate for the Python kernels.**
- **Question:** how to validate inputs before the pybind11 kernels.
- **Options on the table:** a third-party validator (`beartype`, `typeguard`, `jaxtyping`, `pydantic`,
  `icontract` / `deal`); or a private numpy-only module.
- **Ruling:** no new dependency, 2026-11-18, owner (the plan that follows in the TODO: a private
  `edi_kernels/_checks.py` with checkmate-named helpers).
- **Why:** Python has no checkmate equivalent for numpy values: `beartype`, `typeguard` and `jaxtyping` check types
  and shapes, not finite or 0/1 values; `pydantic` is heavy and awkward with arrays; `icontract` / `deal` still need
  every check written by hand.
- **Rejected:** every third-party validator.

<a id="DECISION-v1.0.6-TODO-99a"></a>
### DECISION-v1.0.6-TODO-99a: Strict article render over the ~10 min target: accept, or add a CI-size switch?

- **TODO:** [v1.0.6-TODO-99](release_v1_0_6.md): **Articles as a CI gate.**
- **Question:** the full strict render takes 12 m 20 s on 2 workers because three articles take 4-7 min each
  (`matching-on-the-fly` 398 s, `planning-a-study` 305 s, `learn-statistics-through-edi` 240 s).
- **Options on the table:** accept the runtime; a CI-size switch for their simulations; run them on push to main only.
- **Ruling:** the ~12 min runtime is acceptable; no CI-size switch, 2026-11-18, owner.
- **Why:** No reason recorded.
- **Rejected:** a CI-size switch; push-to-main only.

<a id="DECISION-v1.0.6-TODO-99b"></a>
### DECISION-v1.0.6-TODO-99b: The article chunk that shows a warning on purpose: hide it, or opt it out of the gate?

- **TODO:** [v1.0.6-TODO-99](release_v1_0_6.md): **Articles as a CI gate.**
- **Question:** `cluster-and-factorial-experiments.Rmd` chunk `cluster-warning` fails the gate because it shows EDI's
  cluster-SE warning on purpose.
- **Options on the table:** `warning = FALSE` and show the text another way; or a per-chunk opt-out in the gate.
- **Ruling:** per-chunk opt-out, 2026-11-18, owner.
- **Why:** No reason recorded.
- **Rejected:** `warning = FALSE`.

<a id="DECISION-v1.0.6-TODO-98a"></a>
### DECISION-v1.0.6-TODO-98a: What triggers the docs-only scenario agents?

- **TODO:** [v1.0.6-TODO-98](release_v1_0_6.md): **Scenario tests written from the docs alone, per feature area.**
- **Question:** the trigger for a docs-only agent run when a feature area lands or changes.
- **Options on the table:** a release-gate checklist item; a step in the new-feature plan template.
- **Ruling:** neither: run every feature area as a weekly CI job (the `ANTHROPIC_API_KEY` secret is set, as for the
  other Claude CI jobs), 2026-11-18, owner. An area is skipped when nothing relevant to it changed since its last run,
  and the job keeps a durable store of what earlier runs learned (findings, workarounds, already-filed TODOs) that
  each run reads first and updates.
- **Why:** No reason recorded.
- **Rejected:** the release-gate item and the plan-template step.

<a id="DECISION-v1.0.6-TODO-98b"></a>
### DECISION-v1.0.6-TODO-98b: Docs-scenario job settings: caps, effort and re-runs of unchanged areas

- **TODO:** [v1.0.6-TODO-98](release_v1_0_6.md): **Scenario tests written from the docs alone, per feature area.**
- **Question:** the 8-area / $15 caps, the effort level, and a periodic re-run of unchanged areas (agent's estimate:
  $5-12 per area, ~4 h for an 8-area run).
- **Options on the table:** as built (8 areas per run, $15 cap, no re-run of unchanged areas), or other values.
- **Ruling:** 2026-11-18, owner: weekly; Claude Opus 5.5 at effort `high`; $30 per-area cap; unchanged areas re-run
  every 42 days.
- **Why:** No reason recorded.
- **Rejected:** the $15 cap; no re-runs of unchanged areas.

<a id="DECISION-v1.0.6-TODO-87"></a>
### DECISION-v1.0.6-TODO-87: Keep the removal of the always-NaN keys from the Python kernel outputs?

- **TODO:** [v1.0.6-TODO-87](release_v1_0_6.md): **Variance outputs are missing from the Python kernels.**
- **Question:** the fix removed always-NaN keys the C++ never set (logged under Changed in `python/CHANGELOG.md`: may
  break code that checks they exist).
- **Options on the table:** (a) keep the removal; restoring the keys is the implied alternative (not recorded).
- **Ruling:** (a) keep the removal (already logged under Changed in `python/CHANGELOG.md`), 2026-11-19, owner. No
  further change.
- **Why:** No reason recorded.
- **Rejected:** restoring the keys.

<a id="DECISION-v1.0.6-TODO-82"></a>
### DECISION-v1.0.6-TODO-82: `na.rm` in `compute_rand_two_sided_pval()`: remove it, or keep it as "drop non-finite draws"?

- **TODO:** [v1.0.6-TODO-82](release_v1_0_6.md): **`na.rm` in `compute_rand_two_sided_pval()` does nothing, and the
  finite-draw minimum is misdocumented.**
- **Question:** the argument is asserted but never used; non-finite draws are always dropped.
- **Options on the table:** honour `na.rm = FALSE` literally (return NA if any draw is non-finite); remove the
  argument; keep it as "drop non-finite draws" and fix the docs. Honouring `na.rm = FALSE` literally would break
  every rand CI, because the CI search (`inference_all_abstract_rand_ci.R` ~L454) passes `na.rm = FALSE` and some
  draws fail.
- **Ruling:** keep `na.rm`, documented as "drop non-finite draws", 2026-11-18, owner.
- **Why:** honouring it literally would break every rand CI (above).
- **Rejected:** removing the argument; honouring `na.rm = FALSE` literally.

<a id="DECISION-v1.0.6-TODO-76"></a>
### DECISION-v1.0.6-TODO-76: KK designs with `n = NULL`: what does the burn-in mean, or require `n`?

- **TODO:** [v1.0.6-TODO-76](release_v1_0_6.md): **KK14, KK21 and KK21stepwise crash on the first assignment when
  `n = NULL`.**
- **Question:** what burn-in means without `n`.
- **Options on the table:** an absolute `t_0`; burn-in until the covariate model matrix exists (as implemented); or
  require `n` for KK designs and error clearly at construction.
- **Ruling:** KK designs with `n = NULL` start matching once the covariate model matrix exists (no requirement for
  `n`), 2026-11-18, owner.
- **Why:** No reason recorded.
- **Rejected:** requiring `n`; an absolute `t_0`.

<a id="DECISION-v1.0.6-TODO-61"></a>
### DECISION-v1.0.6-TODO-61: Should randomization replicates chain warm starts?

- **TODO:** [v1.0.6-TODO-61](release_v1_0_6.md): **Randomization distribution of warm-started fits depends on the
  core count.**
- **Question:** the reused-worker randomization path chained warm starts within each core's chunk, so results
  depended on the core count.
- **Options on the table:** start every permutation's fit from the full-data MLE; or fix chunk boundaries
  independently of cores (keeping the chaining).
- **Ruling:** accepted the fix, 2026-11-19, owner: randomization replicates never chain warm starts, for any class;
  every permutation starts from the full-data fit. Supersedes the 2026-11-16 ruling that concave classes chain.
- **Why:** No reason recorded; the fix showed no measurable slowdown (Poisson, NegBin, PropOdds) and made 1-core vs
  2-core bit-identical.
- **Rejected:** chaining with core-independent chunks; the 2026-11-16 concave-classes-chain rule.

<a id="DECISION-v1.0.6-TODO-60"></a>
### DECISION-v1.0.6-TODO-60: KK21 proportion speedup: which clamp for 0/1 responses?

- **TODO:** [v1.0.6-TODO-60](release_v1_0_6.md): **KK21 proportion speedup loses all weights when a response is 0 or
  1.**
- **Question (open design question, both KK21 classes):** the eps clamp makes a 0/1 response a +/-36 logit outlier for
  the OLS t-statistics.
- **Options on the table:** (a) the eps clamp (as fixed first); (b) a milder clamp such as (y(n-1)+0.5)/n, which
  would keep more signal.
- **Ruling:** (b), 2026-11-19, owner: use the milder clamp (y(n-1)+0.5)/n in both KK21 proportion speedups; document
  it as the standard choice in the literature (Smithson & Verkuilen 2006) and add it to REFERENCES.md.
- **Why:** it keeps more signal; it is the standard choice in the literature (Smithson & Verkuilen 2006).
- **Rejected:** (a) the eps clamp.

<a id="DECISION-v1.0.6-TODO-12"></a>
### DECISION-v1.0.6-TODO-12: Bootstrap p-values with `na.rm = TRUE`: minimum valid-replicate fraction, and user-settable?

- **TODO:** [v1.0.6-TODO-12](release_v1_0_6.md): **Fractional-validity guard for bootstrap p-values with `na.rm`.**
- **Question:** decide the threshold and whether it is user-settable.
- **Options on the table:** a threshold value; fixed or user-settable.
- **Ruling:** default minimum 95% valid replicates, user-settable, 2026-11-19, owner.
- **Why:** it mirrors the 5% invalid-interval cap for CIs.
- **Rejected:** a fixed (non-settable) threshold.

<a id="DECISION-v1.0.6-TODO-4a"></a>
### DECISION-v1.0.6-TODO-4a: SPBR jackknife: is a trailing partial permuted block its own unit or merged into the previous one?

- **TODO:** [v1.0.6-TODO-4](release_v1_0_6.md): **Block jackknife on SPBR / FixedBlocking leaves out whole strata.**
- **Question:** with the permuted block as the jackknife unit on `DesignSeqOneByOneSPBR` (fix (b), owner-chosen at
  v1.0.5-TODO-162), what to do with partial trailing blocks.
- **Options on the table:** its own unit; merge into the previous block.
- **Ruling:** merged into the previous block (not its own unit), 2026-11-19, owner.
- **Why:** No reason recorded.
- **Rejected:** its own unit.

<a id="DECISION-v1.0.6-TODO-4b"></a>
### DECISION-v1.0.6-TODO-4b: FixedBlocking jackknife: delete-one within strata, or the t(G - 1) / minimum-group rule?

- **TODO:** [v1.0.6-TODO-4](release_v1_0_6.md): **Block jackknife on SPBR / FixedBlocking leaves out whole strata.**
- **Question:** FixedBlocking has no permuted blocks.
- **Options on the table:** (a) delete-one within strata; the t(G - 1) / minimum-group rule from the rejected fix (a)
  of v1.0.5-TODO-162.
- **Ruling:** (a) delete-one within strata, the stratified JKn jackknife (Wolter, Introduction to Variance
  Estimation): each subject is a unit, each stratum's contribution weighted by (n_h - 1)/n_h; document it and add
  Wolter to REFERENCES.md, 2026-11-19, owner.
- **Why:** No reason recorded.
- **Rejected:** the t(G - 1) / minimum-group rule.
- **Note:** the implementation deviated from the literal (n_h - 1)/n_h weighting (reweighting-equivalent replicates,
  "owner to confirm" in the TODO); the variance form was kept by the owner under v1.0.6-TODO-231 (1), 2026-11-20.

## v1.0.5

<a id="DECISION-v1.0.5-TODO-192"></a>
### DECISION-v1.0.5-TODO-192: Calibration publish job: run the gate scripts from the campaign's pinned commit or from `main`?

- **TODO:** [v1.0.5-TODO-192](release_v1_0_5.md) (ticked): **One registry that says, per inference procedure, whether
  it is asymptotic or finite-sample valid.** Section 4 of the plan was left unimplemented.
- **Context:** plan `new_feature_plans/v1_0_5/inference_procedure_regime_registry.md`, section 4 ("Open decision for
  the owner (do not implement without asking)"). The publish job checks out the campaign's pinned commit
  (`calibration-study.yml`, `ref: needs.plan.outputs.sha`), so gate changes reach only campaigns started after they
  land; the campaign running when this was written (`2026-11-09-8c32d060`) kept the strict gate.
- **Options:** (a) keep the pinned commit (reproducibility argues for it); (b) run the analysis scripts from `main`.
- **Agent's note (2026-11-21):** the campaign it was raised for has ended, so the question may now only matter for
  future gate changes during a running campaign.
- **Raised:** 2026-11-10, in the plan.
- **Ruling:** (b), the analysis scripts run from `main`, with one exception: the acceptance list comes from the
  campaign's pinned commit. 2026-11-10, owner: the owner's own v1.0.5-TODO-200 (added 2026-11-10, owner; "the publish
  job runs the analysis scripts from `main` and records both commits"; its entry: "Owner approved all points
  2026-11-10"). Implemented in 168c2e92 (2026-11-10) as the separate `analyze` job of `calibration-study.yml`: on HEAD
  the analysis scripts and registry come from the run's own commit (`ref: ${{ github.sha }}`, `main` at dispatch, so a
  campaign is gated by the rules current at completion; both commits recorded as `SHA=` / `ANALYSIS_SHA=` in
  `campaign.env`), while the merge and the roster use the pinned commit (`needs.plan.outputs.sha`). Exception (owner,
  2026-11-17, workflow comment above `analyze` and learning l-991a46f4): `calibration_study_accepted.csv` is read from
  the campaign's pinned commit, so rows added on `main` apply from the next campaign. The pending entry was written
  from the plan's section 4, which predates TODO-200; it was closed 2026-11-23 (coordinator, owner request to fix
  stale entries).
- **Why:** gate changes should apply to the campaign being analysed (v1.0.5-TODO-200); for the acceptance list
  (2026-11-17), a row added mid-campaign re-levelled its cell at the next wave and withdrew flags the BH screen
  promised never to withdraw (campaign 2026-11-15-e36c7710: 120 flags at wave 5 -> 0 at wave 6 after c28bbb34).
- **Rejected:** (a) keep the pinned commit for the whole analysis.

<a id="DECISION-v1.0.5-TODO-174"></a>
### DECISION-v1.0.5-TODO-174: Apply the prototyped jump guard to the shared C++ `pval_invert_ci_cpp`?

- **TODO:** [v1.0.5-TODO-174](release_v1_0_5.md): **`pval_invert_ci_cpp` returns its Wald seed as a CI endpoint when
  the bisection never moves.**
- **Context:** `pval_invert_ci_cpp` is shared CI-inversion code: every score / Bartlett /
  `invert_test_pval_confidence_interval` CI goes through it. The Stereotype symptom is gone after v1.0.5-TODO-175
  (2026-11-07): CI ends equal to the Wald end bit-for-bit 2/300 -> 0/300 on null reps 1-25.
- **Options:**
  - (a) jump guard: if the bisection collapses onto the initial outer point and |p(a) - p(b0)| > 1e-3, restart the
    outward search from b0, NA after 3 restarts (-> `finalize_inverted_ci`'s Wald fallback with warning). Prototype
    `/tmp/claude-1000/t174/todo174_jump_guard.diff`, verified with `Rcpp::sourceCpp` on the extracted function: a
    smooth p with an isolated dip at the seed gives lower -0.2390 before, -0.7609 after (the true root); identical on
    smooth p. Over 1,576 CI rows (2026-10-28) only the 2 Stereotype rows change. Not run through the full CI suite.
    Cost: up to 60 extra p evaluations per restart. Default-output change: NEWS, canonical CSVs (G4), equivalence note.
  - (b) on an NA midpoint, halve back toward a (up to 20 times) instead of stopping: not prototyped; narrows every CI
    that now ends on an NA midpoint, and must not treat an NA cliff edge (p ~0.35 right before the NA) as a root.
  - (c) leave the shared code as is.
- **Raised:** 2026-10-28, owner; "open: owner decision on applying (a) to the shared C++" since 2026-11-07.
- **Ruling:** (a), the jump guard, applied by an agent on 2026-11-07 and committed in 67347569 (2026-11-08); owner
  approval not recorded. Evidence: the guard is in `pval_invert_ci_cpp` on HEAD (`R/EDI/src/lrt_ci_newton.cpp`, the
  "TODO-174 jump guard" block: up to 3 outward restarts, then NA for that side); the release file's status-table row in
  67347569 reads "2026-11-07: jump guard applied ... Verified by sourceCpp swap", while the same commit's TODO entry
  still said "Open: owner decision on applying (a) to the shared C++"; checked on the installed build 2026-11-10 (EDI.so
  2026-11-10 16:48: isolated low-p point at the seed gives the true root -0.7611, 1.0.2 gave -0.2390; smooth case
  unchanged); NEWS bullet "Likelihood CI inversion no longer returns an isolated low-p point as an endpoint." No owner
  ruling, owner request or G6 item approving it was found. The owner's 2026-11-10 "Final benchmark gate" note (release
  file, dependency diagram) lists "the TODO-174 CI jump guard in `lrt_ci_newton.cpp`" among the changes the final
  benchmark run must cover, so the owner knew it was in. Recorded 2026-11-23 (coordinator, owner request to fix stale
  entries).
- **Why:** No reason recorded.
- **Rejected:** (b) NA-midpoint halving (not prototyped) and (c) leave the shared code as is, by the change as applied.
- **Revisit if:** the owner wants the change reverted, or the G4 rows show CIs that moved outside the 2 Stereotype rows.

<a id="DECISION-v1.0.5-TODO-189"></a>
### DECISION-v1.0.5-TODO-189: Frailty Weibull score test runs ~1.5 points high under a correct model: fix in 1.0.5 or accept as documented?

- **TODO:** [v1.0.5-TODO-189](release_v1_0_5.md): **`InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik` (Clayton / loggamma-frailty Weibull) score test runs about 1.5 points high even when the model is correct.**
- **Question:** the score size is 0.063 / 0.061 / 0.067 over three correctly specified cells (pooled 191/3000 = 0.064, about [0.055, 0.073]) while Wald 0.049 and LR 0.045 on the same data. Fix or accept?
- **Options on the table:** not fixable in 1.0.5 without changing what the test is (every valid score-test variant uses the null-restricted nuisance estimates). Options for later: (a) a parametric-bootstrap-calibrated score p-value (the class already has `simulate_under_lik_null` for the LR bootstrap); (b) recommend Wald / LR for this class in the Rd. The default testing type is Wald, so default output is unaffected.
- **Ruling:** accept as documented (the agent's suggestion): a finite-sample property of the score test, not a bug; documented in the class roxygen ("Score test at small n"); the bootstrap-calibrated score p-value is v1.1.0-TODO-166. 2026-11-09, owner (accepted the agent's recommendation).
- **Why:** a finite-sample property of the score test, not a bug; default output (Wald) is unaffected. The calibration accepted-row reason for the score cells can cite this entry.
- **Rejected:** a 1.0.5 code change.
- **Revisit if:** v1.1.0-TODO-166 (bootstrap-calibrated score p-value) lands.

<a id="DECISION-v1.0.5-TODO-185"></a>
### DECISION-v1.0.5-TODO-185: ZIP/ZINB partial-collapse ridge case: fix the score test in 1.0.5 or leave it?

- **TODO:** [v1.0.5-TODO-185](release_v1_0_5.md): **`InferenceCountZeroInflatedNegBin` / `InferenceCountZeroInflatedPoisson` score CIs are not inverted from their tests at `prob_T = 0.2`.**
- **Question:** after fixing the boundary case (true pi = 0: zero-inflated calibration data plus the no-zeros error and resampling fallback), should the partial-collapse case (data have zeros but the zi part still sits on a ridge) also be fixed now?
- **Options on the table:** (a) an eigen-truncated pseudo-inverse of `I_nn` in the score test (gives stable answers, ZINB 0.0504/0.0504); (b) leave it.
- **Ruling:** (b) not done; the eigen-truncated pseudo-inverse score test is deferred to `release_v1_1_0.md` TODO-3a, after the diagnostics-return feature. Date not recorded exactly (within the 2026-11-04..06 resolution), owner.
- **Why:** owner: "rare, numerical error acceptable".
- **Rejected:** the pseudo-inverse score test in 1.0.5.

<a id="DECISION-v1.0.5-TODO-184a"></a>
### DECISION-v1.0.5-TODO-184a: Where is coverage graded in the comprehensive survival rows: at every beta_T or at the null only?

- **TODO:** [v1.0.5-TODO-184](release_v1_0_5.md): **`prob_T = 0.2` cells in the comprehensive and calibration tests**
- **Question:** coverage truths are computed at prob_T 0.5; for estimands that cannot be averaged across subgroups (e.g. a marginal Cox hazard ratio) the target can depend on the allocation ratio, so low coverage at 0.2 may be a truth artefact.
- **Options on the table:** grade coverage at every beta_T; grade it at the null only.
- **Ruling:** coverage is graded at the null only; beta_T = 0.5 rows carry `coverage_truth = NA`. 2026-11-11, owner.
- **Why:** No reason recorded beyond the "Known risk" above (at beta_T = 0 the coverage truth no longer depends on allocation, d05eee79).
- **Rejected:** grading coverage at beta_T = 0.5.

<a id="DECISION-v1.0.5-TODO-184b"></a>
### DECISION-v1.0.5-TODO-184b: Verify the comprehensive prob_T = 0.2 cells from a separate run or from the survival G4 regeneration's rows?

- **TODO:** [v1.0.5-TODO-184](release_v1_0_5.md): **`prob_T = 0.2` cells in the comprehensive and calibration tests**
- **Question:** how to verify the comprehensive 0.2 cells.
- **Options on the table:** a separate verification run; the survival G4 regeneration's own rows.
- **Ruling:** verify from the survival G4 regeneration's own rows (batch-1 rerun `~/edi_regen/regen_survival_b1r_20261111/`, then batches 2-3), not from a separate run. 2026-11-12, owner.
- **Why:** the batch-1 rows already cover Bernoulli, FixediBCRD, FixedBlocking and SPBR at 0.2 for CoxPHRegr, StratCoxPHRegr, LogRank, GehanWilcox and AllSimple*; the aborted 2026-11-11 batch-1 run (`regen_survival_b1_20261111/`) showed exactly 2x rows on those designs, no duplicate ids. At beta_T = 0 the coverage truth no longer depends on allocation (d05eee79), so the "Known risk" is moot there.
- **Rejected:** a separate verification run.

<a id="DECISION-v1.0.5-TODO-184c"></a>
### DECISION-v1.0.5-TODO-184c: Should the randomization bootstrap (BRT) run on sequential designs other than Bernoulli?

- **TODO:** [v1.0.5-TODO-184](release_v1_0_5.md): **`prob_T = 0.2` cells in the comprehensive and calibration tests**
- **Question:** keep BRT on `DesignSeqOneByOne*` designs (the 2026-09-11 `1b2f1c74` choice) or exclude it where the bootstrap itself is not allowed.
- **Options on the table:** keep BRT there; exclude `randomization_bootstrap(_ci)` on `DesignSeqOneByOne` except Bernoulli.
- **Ruling:** "BRT cannot run on designs where bootstrap is illegal"; `inference_class_registry.R` excludes `randomization_bootstrap(_ci)` on `DesignSeqOneByOne` except Bernoulli (reverses `1b2f1c74`). 2026-11-14, owner.
- **Why:** owner: "BRT cannot run on designs where bootstrap is illegal"; the bootstrap is unproven on KK designs.
- **Rejected:** keeping BRT on KK / other sequential designs (the 2026-09-11 choice).

<a id="DECISION-v1.0.5-TODO-183"></a>
### DECISION-v1.0.5-TODO-183: Should designs that cannot honour unequal allocation still take a `prob_T` argument?

- **TODO:** [v1.0.5-TODO-183](release_v1_0_5.md): **`supports_unequal_allocation` registry capability.**
- **Question:** what to do with `prob_T` on even-only designs (Efron, Atkinson, PocockSimon, KK14, KK21, KK21stepwise, BinaryMatch, PairSwitching).
- **Options on the table:** keep the argument (flagged by the registry capability); remove it.
- **Ruling:** remove `prob_T` from those constructors until the design is upgraded; they pass 0.5 to the base class and `get_prob_T()` returns 0.5; the registry entry stays FALSE as a backstop for subclasses. 2026-11-03, owner.
- **Why:** owner: "a design that cannot honour unequal allocation should not take `prob_T` at all, until it is upgraded".
- **Rejected:** keeping `prob_T` on even-only designs.
- **Revisit if:** a design is upgraded to honour unequal allocation.

<a id="DECISION-v1.0.5-TODO-179"></a>
### DECISION-v1.0.5-TODO-179: LogBinomial Wald and frailty `~1` cells oversized at n = 200: accept as honest, or change the LogBinomial Wald at the boundary?

- **TODO:** [v1.0.5-TODO-179](release_v1_0_5.md): **two anti-conservative cells that persist at n = 200, so not small-sample.**
- **Question:** both cells were investigated as honest properties (LogBinomial: MLE on the exp(Xb) = 1 boundary in ~1/3 of reps, Wald size 0.17 there, 0.050 interior, `glm(binomial(log))` identical; frailty `~1`: harness misspecification, BinaryMatch pairs on covariates that `~1` omits, Clayton-copula SE 12% too small, nominal when correctly specified).
- **Options on the table (agent recommendation 2026-11-07):** (1) reword the LogBinomial wald accepted rows as honest; (2) reword the frailty score / wald `~1` rows as honest harness misspecification; (3) optional, for v1.1: make Wald NA at the boundary (with LR suggested) for LogBinomial / RiskDiff, and check the Clayton score information. A principled boundary fix (Wald NA when `n_active_bounds > 0` / any eta >= -1e-6, or fall back to LR) gives size 0.050 on interior reps with ~67% yield, but changes default output.
- **Ruling:** LogBinomial half: make Wald NA at a boundary MLE now (option (3) brought into 1.0.5; R only), with `fit_null`'s strictly feasible last-resort start; the frailty half accepted as documented, rows reworded. 2026-11-09, owner.
- **Why:** No reason recorded beyond the investigation. Effect measured: LogBinomial Wald size over finite reps 0.041 (n = 50) / 0.047 (n = 200), coverage 0.959 / 0.953, Wald NA in 68% / 66% of reps; LR CIs falling back to Wald 526 -> 75 of 1000 at n = 50.
- **Rejected:** accepting the LogBinomial Wald cell as is; `InferenceIncidBinomialIdentityRiskDiff` was not changed (needs its own decision) and LR oversize at boundary MLEs went to v1.1.0-TODO-189.

<a id="DECISION-v1.0.5-TODO-176"></a>
### DECISION-v1.0.5-TODO-176: Stereotype logit `~1`: accept boundary treatment-only fits, or report them non-estimable?

- **TODO:** [v1.0.5-TODO-176](release_v1_0_5.md): **`InferenceOrdinalStereotypeLogitRegr` drops the covariates in most fits.**
- **Question:** with the recommended fix A + B (adjacent-category two-stage start; reduced-information usability check at the loading boundary), what to do for `~1`.
- **Options on the table:** (i) accept boundary fits too (A + B as prototyped); (ii) report non-estimable when the treatment-only fit is at the boundary. Either is a default-output change (most adjusted estimates / SEs; ~half the NAs become estimates; `full_neg_loglik` drops, so LR / score / gradient p move, coordinate with TODO-175); re-measure the class docs' "10-12% covariate drop / 30-38% non-estimable"; ~25% more multistart time (estimated, not measured). B alone must not ship (accepts the spurious cold points). Prototype reps 1-40, before -> A -> A+B: `~.` NA 19 -> 2 -> 0; `~1` NA 22 -> 22 -> 0; 400-rep `~1` Wald 9.3%, sd 0.475 vs SE 0.361.
- **Ruling:** option (ii): a treatment-only fit (`~1`, or every covariate dropped) whose loadings are at the boundary is non-estimable, reason `stereotype_treatment_only_fit_at_loading_boundary`; A + B otherwise as prototyped. 2026-10-31, owner.
- **Why:** No reason recorded. (The prototype's `~1` A+B fits were oversized: 9.3% Wald size, sd 0.475 vs SE 0.361; the 2x4 table is nearly saturated, boundary MLE in 335/400.)
- **Rejected:** (i) accepting boundary `~1` fits.

<a id="DECISION-v1.0.5-TODO-171"></a>
### DECISION-v1.0.5-TODO-171: `InferenceCountKKGLMM`: keep the max(model, Wald) clamp on LR / score / gradient, or drop it?

- **TODO:** [v1.0.5-TODO-171](release_v1_0_5.md): **`InferenceCountKKGLMM` LR p-value equals its Wald p-value exactly on every replicate.**
- **Question:** LR equals Wald by design: the LR is computed and then clamped to `max(p_LR, p_wald)` (`.conservative_kk_onelik_*`). Drop the clamp to match the sibling classes?
- **Options on the table:** keep the clamp (documented); drop it to match siblings `InferenceContinKKGLMM` / `InferenceIncidKKCondLogitGLMM*` (default-output change: LR / score / gradient p-values and CIs get smaller / narrower).
- **Ruling:** drop the max(model, Wald) rule to match the sibling KK GLMM classes; the jackknife-inflated Wald SE is unchanged. 2026-10-28, owner.
- **Why:** consistency with the sibling KK GLMM classes, which have no clamp.
- **Rejected:** keeping the clamp.

<a id="DECISION-v1.0.5-TODO-168"></a>
### DECISION-v1.0.5-TODO-168: `InferenceIncidExtendedRobins` undercovers on matched pairs: change the SE or document?

- **TODO:** [v1.0.5-TODO-168](release_v1_0_5.md): **`InferenceIncidExtendedRobins` wald undercovers on matched pairs.**
- **Question:** null size 0.183 on BinaryMatch n = 200 (paired z 0.07); the agent proposed SE = sqrt(var(d_b) / B) (~+37% SE on pairs; changes wald SE/CI/p on every blocking design).
- **Options on the table:** (a) change the SE (documented default change, regenerate goldens); (b) document the limitation, no code change.
- **Ruling:** (b) document the limitation, no code change. 2026-10-28, owner. Accepted rows relabelled 2026-11-12 to "v1.0.5 TODO-168 (owner ruling 2026-10-28: published estimator, inherent at small blocks)".
- **Why:** checked against the paper (Azriel, Krieger, Kapelner, arXiv:2607.05768, Sec. 2.3.2): the kernel faithfully implements Eq. 12 + Eq. 13; it is the published estimator used outside its range ("conservative only for large samples, i.e. nB sufficiently large"; the paper's simulations find Robins "wildly missized", anti-conservative at nB = 2). The agent's "should divide by n/2" reading is wrong.
- **Rejected:** (a) the var(d_b)/B SE.

<a id="DECISION-v1.0.5-TODO-165"></a>
### DECISION-v1.0.5-TODO-165: KMDiff BCa NA at large B: change the default bootstrap type, fix z0 ties, or accept?

- **TODO:** [v1.0.5-TODO-165](release_v1_0_5.md): **KMDiff BCa bootstrap CIs NA even at large B.**
- **Question:** whether the BCa z0 should handle ties (e.g. mid-rank `mean(boot < est) + 0.5*mean(boot == est)`), whether BCa is a sensible default for a step-function estimand, or accept.
- **Options on the table:** (1) default bootstrap type -> percentile for KMDiff (the original recommendation; changes 1.0.x default output); the same override for the Contin/Prop (KK) QuantileRegr classes (no ties but |z0| ~0.15); (2) mid-rank z0 for every class (fixes AllSimpleWilcox count/ordinal ties but changes BCa for every class with ties; does not help KMDiff); (3) accept.
- **Ruling:** "owner approved all three": percentile default for `InferenceSurvivalKMDiff` and the 6 QuantileRegr classes in `get_bootstrap_dispatch_policy()`, and mid-rank z0 for every class. 2026-10-27, owner.
- **Why:** No reason recorded beyond the evidence: KMDiff BCa NA at B = 151 / 1001 0.543 / 0.015 vs percentile 0 NA with coverage 0.960; BCa without guard 0.954; AllSimpleWilcox count/ordinal 79% / 95% of bootstrap values tied with the estimate.
- **Rejected:** accepting the NA rate.
- Note: the entry says "all three" without listing a third item; the two named changes are (1) the percentile overrides (KMDiff and QuantileRegr) and (2) mid-rank z0.

<a id="DECISION-v1.0.5-TODO-163"></a>
### DECISION-v1.0.5-TODO-163: RMST Wald SE ignores the design: make it design-aware in 1.0.x or keep the independent-arms SE?

- **TODO:** [v1.0.5-TODO-163](release_v1_0_5.md): **RMST Wald/asymptotic CIs slightly too wide; some bootstrap p-values miscalibrated.**
- **Question:** `compute_s_beta_hat_T` uses a per-arm Greenwood-type variance summed across independent arms, ignoring pairing / blocking / balance (SD/RMS SE 0.72 FixedBinaryMatch ... 0.98 iBCRD).
- **Options on the table:** keep the unadjusted SE and document it, accepting the findings in the audit baseline (agent recommendation, except the KK21stepwise Bayesian-bootstrap item, later shown not to be a bug); design-aware variances now.
- **Ruling:** keep the unadjusted (independent-arms) SE in 1.0.x; document that it is conservative under every design other than Bernoulli / BCRD / iBCRD; design-aware variances moved to v1.1.0 (RMST design-aware variance TODO, v1.1.0-TODO-161); accept the findings in the audit baseline. 2026-10-27, owner.
- **Why:** conservative under restricted designs is expected; precedent: the baseline accepts over-coverage for InferenceAllSimpleAverageDiff and KMDiff p-value miscalibration.
- **Rejected:** design-aware variances in 1.0.x.

<a id="DECISION-v1.0.5-TODO-162"></a>
### DECISION-v1.0.5-TODO-162: RMST (suite-wide) jackknife-Wald undercoverage on blocked designs: fix shape and timing?

- **TODO:** [v1.0.5-TODO-162](release_v1_0_5.md): **RMST jackknife-Wald undercovers on blocked designs at beta 0.**
- **Question:** the "block" unit on blocking designs is the stratum (G = 2-4), with z instead of t(G-1): coverage SPBR 0.838, FixedBlocking 0.860 suite-wide. Agent recommendation: fix, do not baseline; owner to choose fix shape and minimum group count.
- **Options on the table:** (a) `df = G - 1` for block/cluster units and refuse when G < 3 (threshold: owner); (b) use the SPBR permuted block (~37 units) as the jackknife unit (changes `get_block_ids()` semantics). Either requires regenerating the SPBR/FixedBlocking jackknife rows and the baseline (G4).
- **Ruling:** deferred to v1.1.0 with fix (b), the SPBR permuted block as the jackknife unit (`release_v1_1_0.md` TODO-162, later v1.0.6-TODO-4); fix (a) not applied; 1.0.5 ships the current behavior, listed under NEWS Known limitations, with the SPBR/FixedBlocking jackknife-Wald rows accepted in the baseline citing this TODO. 2026-10-27, owner.
- **Why:** No reason recorded.
- **Rejected:** fix (a) (t(G-1) df, minimum 3 groups); fixing in 1.0.5.

<a id="DECISION-v1.0.5-TODO-161"></a>
### DECISION-v1.0.5-TODO-161: RMST BCa NA on 13-24% of rows at B = 151: accept, raise the harness B, or change the default type?

- **TODO:** [v1.0.5-TODO-161](release_v1_0_5.md): **RMST BCa bootstrap CIs return NA on 13-24% of rows at B = 151.**
- **Question:** whether the NA rate is just the TODO-101 guard (|z0| noise at B = 151) or RMST-specific.
- **Options on the table:** accept in the audit baseline; raise the harness B for BCa calls (to 501: +~11.6 h, +50% for this class); change the class's default type.
- **Ruling:** accept in the audit baseline (the three keys' `detail` carries the pooled R4B numbers 0.735 / 0.735 / 0.750; 23% / 23% / 21% NA). 2026-10-27, owner.
- **Why:** the investigation found the generic TODO-101 guard, no RMST bug: pure noise around z0 = 0 gives 19.2% NA at B = 151, 0% at B = 501 / 1001; finite rows cover 0.94-0.96. Same mechanism as TODO-129, where the guard and the BCa default were kept.
- **Rejected:** raising the harness B; changing the default type.

<a id="DECISION-v1.0.5-TODO-131a"></a>
### DECISION-v1.0.5-TODO-131a: On a bootstrap-randomization replay, keep `DesignFixedOptimalBlocks`' observed blocks or re-solve on the resample?

- **TODO:** [v1.0.5-TODO-131](release_v1_0_5.md): **Bootstrap-randomization replay drew assignments from the original sample's cached design structure.**
- **Question (G6 #51):** (a) keep the observed blocks (each resampled unit keeps the block id it carried) and redraw within them; (b) re-solve the optimal blocking on the resample. (b) changes the design being replayed and costs a solve per draw.
- **Ruling:** (b) re-solve optimal blocks on each resampled dataset (same solver and settings on the resampled covariates, solve under the replay draw's seed, a failed solve makes that draw NA); overrides the same-day coordinator default (a). 2026-10-23, owner via G6 #51.
- **Why:** No reason recorded. Measured: carried blocks unbalanced 2-5 of 5 per draw before, 0 after; re-solve cost +6 ms (n = 40 K-way), +27-33 ms (greedy, n = 40-200), +1.7 s (n = 12) and +79 s (n = 16) for exact `ompr`.
- **Rejected:** (a) reuse the observed blocks (the coordinator's default).

<a id="DECISION-v1.0.5-TODO-131b"></a>
### DECISION-v1.0.5-TODO-131b: Re-solve cost with `ompr`: keep re-solving for every method, or restrict it?

- **TODO:** [v1.0.5-TODO-131](release_v1_0_5.md): **Bootstrap-randomization replay drew assignments from the original sample's cached design structure.**
- **Question:** the exact `ompr` method costs ~1.7 s per replay draw at n = 12 and ~79 s at n = 16.
- **Options on the table:** G6 #51 follow-up options; (c) keep re-solving everywhere and document the cost.
- **Ruling:** (c): keep re-solving on every replay draw for ALL methods (incl. `ompr`) and document the cost (roxygen "Cost of randomization-bootstrap replay" paragraph recommending `"K-way"`/`"greedy"` or a small B with `ompr`; NEWS replay bullet). No code change. 2026-10-23, owner via G6 #51.
- **Why:** No reason recorded.
- **Rejected:** the other follow-up options (not recorded in the entry).

<a id="DECISION-v1.0.5-TODO-129a"></a>
### DECISION-v1.0.5-TODO-129a: The KK pass-through bootstrap now honours `set_seed()`: accept the seeded-draw change or revert?

- **TODO:** [v1.0.5-TODO-129](release_v1_0_5.md): **Bootstrap CIs come back NA for some seeds on `DesignFixedBinaryMatch` n = 60**
- **Question (G6 #49):** that changes seeded KK bootstrap draws once; unseeded calls are unchanged. Accept (with a NEWS line), or revert and file for v1.1.0?
- **Ruling:** accept; also covers the three further offenders found by the seed sweep (`InferencePropGCompMeanDiff` bootstrap, the calibrated / double / prepivoted bootstrap CIs, the quantile IVWC randomization CI); one NEWS line covers all. 2026-10-22, owner via G6 #49 (G6 #29 / TODO-112 accept-all precedent).
- **Why:** before the fix, a seeded KK bootstrap depended on the caller's global RNG state and advanced it; precedent of the accept-all ruling for documented seeded-draw default changes.
- **Rejected:** revert and defer to v1.1.0.

<a id="DECISION-v1.0.5-TODO-129b"></a>
### DECISION-v1.0.5-TODO-129b: Should estimator-internal randomness honour `set_seed()` and leave the caller's RNG alone?

- **TODO:** [v1.0.5-TODO-129](release_v1_0_5.md): **Bootstrap CIs come back NA for some seeds on `DesignFixedBinaryMatch` n = 60**
- **Question (G6 #50):** two cases: (a) `robust_survreg_with_surv_object()`'s survreg restart jitter (GLMM Weibull frailty OneLik classes, KK21 survival designs); (b) `InferenceSurvivalKKRankRegrIVWC`'s `aftgee::aftsrr(se = "ISMB")` multiplier bootstrap (legacy IVWC, never published).
- **Options on the table:** coordinator default 2026-10-22: (a) jitter from a fixed internal seed with the caller's `.Random.seed` saved and restored; (b) defer to v1.1.0-TODO-72.
- **Ruling:** owner override: (a) jitter seeded from the object seed (`jitter_seed` argument; NULL keeps the fixed constant 20261022 for unseeded fits); (b) `InferenceSurvivalKKRankRegrIVWC` made deterministic in 1.0.5 (v1.1.0-TODO-72 moved back). 2026-10-23, owner via G6 #50.
- **Why:** No reason recorded.
- **Rejected:** the coordinator default (fixed internal seed; defer (b)).

<a id="DECISION-v1.0.5-TODO-128"></a>
### DECISION-v1.0.5-TODO-128: Apply C++ patch 14 (log-/identity-binomial active-set step)?

- **TODO:** [v1.0.5-TODO-128](release_v1_0_5.md): **The covariate-adjusted `InferenceIncidLogBinomial` jackknife depends on the call history.**
- **Question (G6 #46):** patch 14 (active-set projection of the IRLS step plus a convergence test on the undamped increment) moves boundary full-data estimates toward the MLE, and some hard boundary fits / refits would report non-convergence (NA).
- **Options on the table:** apply at G1; do not apply.
- **Ruling:** apply at G1, with a KKT convergence gate folded in (converged only if the projected gradient is small and every held bound has a correct-sign multiplier; interior fits bit-identical) and an R-only boundary-MLE warning in 1.0.5. The user applies and builds it. 2026-10-22, owner via G6 #46.
- **Why:** No reason recorded beyond the evidence (on 28 synthetic boundary sets the unpatched kernel claims convergence on all 28).
- **Rejected:** leaving the boundary stall.

<a id="DECISION-v1.0.5-TODO-126a"></a>
### DECISION-v1.0.5-TODO-126a: Should the harness MC coverage truth stop requesting `rand_pval`?

- **TODO:** [v1.0.5-TODO-126](release_v1_0_5.md): **Generic Bartlett p-value stall for `InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik` with formula `~.`.**
- **Question (G6 #47):** `comprehensive_tests.R`'s MC coverage truth requests `rand_pval` (r = 201; ~20 min on the `~.` diamonds case) although it uses only `res$estimate`. Request a cheap inference type (e.g. `asymp_pval`) after verifying the estimate is identical, or leave it to v1.1.0 TODO-59? Recommend do now.
- **Ruling:** do now (harness only, agent work; verify identical truths on the TODO-127 classes plus the TODO-126 case). 2026-10-22, owner via G6 #47.
- **Why:** the recommendation: the truth does not depend on the type; asymp is 5-60x faster.
- **Rejected:** deferring to v1.1.0 TODO-59.

<a id="DECISION-v1.0.5-TODO-126b"></a>
### DECISION-v1.0.5-TODO-126b: Native Clayton Weibull LBFGS hits its iteration cap at n = 3000: raise `maxit` / seed the fallback now?

- **TODO:** [v1.0.5-TODO-126](release_v1_0_5.md): **Generic Bartlett p-value stall for `InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik` with formula `~.`.**
- **Question (G6 #48):** the LBFGS hits its 2000-iteration cap at n = 3000 with ~25 covariates and falls to R BFGS (~6 s per draw). Raise `maxit` or seed the R fallback with the capped iterate? Both change estimates at the tolerance level and need G1. Recommend defer.
- **Ruling:** defer to v1.1.0, `release_v1_1_0.md → TODO-70`. 2026-10-22, owner via G6 #48.
- **Why:** both options change estimates at the tolerance level and need a build (G1).
- **Rejected:** raising `maxit` or seeding the fallback in 1.0.5.

<a id="DECISION-v1.0.5-TODO-124a"></a>
### DECISION-v1.0.5-TODO-124a: Raise `r` in the migration goldens so the rand columns are not NA vs NA?

- **TODO:** [v1.0.5-TODO-124](release_v1_0_5.md): **"Randomization p-value NA vs NA" in the four KK continuous goldens (OLS/robust IVWC and OneLik) -- mostly a fixture quirk, one real IVWC bug.**
- **Question (G6 #13):** raise `r` from 9 to >= 19 (the finite-draw floor is 10) in a few representative migration goldens. Recommend yes, a few representatives.
- **Ruling:** yes, a few representative goldens (agent test work; the box stays checked because it is a follow-up, not a reopening). 2026-10-22, owner via G6 #13.
- **Why:** so the rand columns are not NA vs NA.
- **Rejected:** leaving `r = 9`; raising it in every golden.

<a id="DECISION-v1.0.5-TODO-124b"></a>
### DECISION-v1.0.5-TODO-124b: The unowned bootstrap-CI-NA finding: investigate in 1.0.5 or file for v1.1.0?

- **TODO:** [v1.0.5-TODO-124](release_v1_0_5.md): **"Randomization p-value NA vs NA" in the four KK continuous goldens (OLS/robust IVWC and OneLik) -- mostly a fixture quirk, one real IVWC bug.**
- **Question (G6 #44):** bootstrap CIs came back NA for several seeds on `DesignFixedBinaryMatch` n = 60 for the OneLik classes, robust IVWC and `InferenceContinOLS` ("generic, seed-dependent, not investigated"). (a) Open a 1.0.5 TODO and investigate; (b) file for v1.1.0. Recommend (a).
- **Ruling:** (a); opened as TODO-129. 2026-10-22, owner via G6 #44.
- **Why:** cheap, and it may be a real bootstrap bug (the recommendation).
- **Rejected:** (b) filing for v1.1.0.

<a id="DECISION-v1.0.5-TODO-123"></a>
### DECISION-v1.0.5-TODO-123: Apply patch 08 (Cox descent guard, `maxit` 20 -> 100), and the BRT Cox kernel's literal 20 too?

- **TODO:** [v1.0.5-TODO-123](release_v1_0_5.md): **`optimize_likelihood_newton` reports false non-convergence at the optimum**
- **Question (G6 #16):** apply patch 08; change the BRT Cox kernel's literal 20 as well? Recommend apply, leave BRT.
- **Ruling:** apply 08 in G1; the BRT literal 20 stays (apply order: `cpp_patches_v105/README.md → Owner-approved for G1`). 2026-10-22, owner via G6 #16.
- **Why:** changing the BRT literal alters bootstrap NA rates.
- **Rejected:** changing the BRT Cox kernel's `maxit` literal.

<a id="DECISION-v1.0.5-TODO-120"></a>
### DECISION-v1.0.5-TODO-120: Accept the dep-cens bootstrap default B 1000 -> 501?

- **TODO:** [v1.0.5-TODO-120](release_v1_0_5.md): **One default `B` for the dependent-censoring bootstrap.**
- **Question (G6 #29):** accept the documented default change (NEWS entry exists). Recommend accept.
- **Ruling:** accept (with the other two G6 #29 default changes, TODO-109 and TODO-112). 2026-10-22, owner via G6 #29.
- **Why:** the recommendation; NEWS entries exist.
- **Rejected:** keeping B = 1000.

<a id="DECISION-v1.0.5-TODO-119a"></a>
### DECISION-v1.0.5-TODO-119a: Randomization CIs on exact 0/1 proportions under a logit shift: refuse, or invert differently?

- **TODO:** [v1.0.5-TODO-119](release_v1_0_5.md): **Randomization CIs come back on the wrong scale for proportion, count and ordinal responses.**
- **Question (G6 #10, second half):** exact 0/1 are clamped to +-36 on the logit shift, so p(delta) is flat and the search hits the +-12 boundary or excludes the estimate (ZOIB: [0.875, 12.8] vs estimate 0.58; 2 of 3 seeds hit the boundary). Refuse when any exact 0/1 under a logit shift, or invert differently.
- **Ruling:** refuse exact 0/1 proportions (error class `edi_rand_ci_exact_zero_one_refused`, message names score / gradient / Bartlett-LR, asymptotic and bootstrap CIs), incl. `InferencePropKKQuantileRegrIVWC`. 2026-10-22, owner via G6 #10 (second half).
- **Why:** the logit shift cannot move exact 0/1, so the inverted CI is meaningless; interior data is unaffected.
- **Rejected:** a different inversion.

<a id="DECISION-v1.0.5-TODO-119b"></a>
### DECISION-v1.0.5-TODO-119b: Scale-mismatched randomization CIs: invert on the estimand's own scale now, or keep refusing?

- **TODO:** [v1.0.5-TODO-119](release_v1_0_5.md): **Randomization CIs come back on the wrong scale for proportion, count and ordinal responses.**
- **Question (G6 #10, first half):** invert randomization CIs on the estimand's own scale (new v1.1.0 TODO) or keep refusing. Recommend keep refusing now.
- **Ruling:** keep refusing in 1.0.5; estimand-scale inversion is `release_v1_1_0.md → TODO-65`. 2026-10-22, owner via G6 #10 (accept-all batch).
- **Why:** the recommendation.
- **Rejected:** estimand-scale inversion in 1.0.5.
- **Revisit if:** v1.1.0-TODO-65 lands.

<a id="DECISION-v1.0.5-TODO-119c"></a>
### DECISION-v1.0.5-TODO-119c: Monte Carlo SE of the rand CI: a returned attribute or docs only?

- **TODO:** [v1.0.5-TODO-119](release_v1_0_5.md): **Randomization CIs come back on the wrong scale for proportion, count and ordinal responses.**
- **Question (G6 #41):** recommend docs only now, attribute in v1.1.0.
- **Ruling:** docs only now (the sentence is in; G8); the attribute is `release_v1_1_0.md → TODO-66`. 2026-10-22, owner via G6 #41.
- **Why:** the recommendation.
- **Rejected:** the returned attribute in 1.0.5.

<a id="DECISION-v1.0.5-TODO-118"></a>
### DECISION-v1.0.5-TODO-118: The `std::round` issue in `generate_permutations_blocking_cpp`: patch it or delete the unused kernel?

- **TODO:** [v1.0.5-TODO-118](release_v1_0_5.md): **Null assignment draws for blocked (and similar) designs are generated one draw at a time in R, so adding cores does not help.**
- **Question:** the `std::round` item was first written as C++ patch 13.
- **Options on the table:** apply patch 13; delete the kernel.
- **Ruling:** delete the unused kernel `generate_permutations_blocking_cpp` and `generate_permutations_blocking_internal` (from `generate_permutations.cpp`, `RcppExports.cpp`, `RcppExports.R`, the Rd, the two bare-kernel tests and the profiler entries); patch 13 withdrawn. 2026-10-22, owner.
- **Why:** no R code calls the kernel.
- **Rejected:** patch 13.

<a id="DECISION-v1.0.5-TODO-116a"></a>
### DECISION-v1.0.5-TODO-116a: NegBin follow-ups: jackknife with convergence checks, NB `eps_g` tightening, patch 04 now?

- **TODO:** [v1.0.5-TODO-116](release_v1_0_5.md): **Stubs for unsupported procedures return NA silently and also clear a valid cached SE; separately, the NegBin fit stops short of the MLE.**
- **Question (G6 #40):** (a) enable the NegBin jackknife with per-replicate convergence checks? (b) tighten hurdle/ZAP/`helper_glm_fit` NB `eps_g` like NegBin? Recommend defer both to v1.1.0 (default changes, unvalidated). (c) Apply patch 04 (NegBin `eps_g` default 1e-10, a default change)? Recommend apply with its listed tests in G1.
- **Ruling:** (a)(b) deferred to `release_v1_1_0.md → TODO-67`; (c) apply patch 04 with its listed tests in G1. 2026-10-22, owner via G6 #40. (c) was later reversed: see [DECISION-v1.0.5-TODO-116c](#DECISION-v1.0.5-TODO-116c).
- **Why:** (a)(b) are default changes and unvalidated.
- **Rejected:** (a)(b) in 1.0.5.

<a id="DECISION-v1.0.5-TODO-116b"></a>
### DECISION-v1.0.5-TODO-116b: Path audit: how to count a failed procedure that returns NA without flagging the object?

- **TODO:** [v1.0.5-TODO-116](release_v1_0_5.md): **Stubs for unsupported procedures return NA silently and also clear a valid cached SE; separately, the NegBin fit stops short of the MLE.**
- **Question:** after this TODO a failed procedure returns NA without flagging the object; the harness records that as `status=ok`, so the path audit counted it as estimable.
- **Options on the table:** leave the counting; count a `status=ok` row with a missing or non-finite `result_1`/`result_2` as non-estimable.
- **Ruling:** fix the counting before G4: `classify_nonestimability_rows()` (`path_audits_source.R`) counts such rows as non-estimable; refusals and skips stay in `n`; outputs stamped `PATH_AUDIT_COUNTING_RULE = "2026-10-23"` with an allowlist `counting_rule_change` row. 2026-10-23, owner.
- **Why:** otherwise the path audit counts failed procedures as estimable.
- **Rejected:** keeping the old counting.

<a id="DECISION-v1.0.5-TODO-116c"></a>
### DECISION-v1.0.5-TODO-116c: Keep or withdraw patch 04 (NegBin `eps_g` default 1e-10)?

- **TODO:** [v1.0.5-TODO-116](release_v1_0_5.md): **Stubs for unsupported procedures return NA silently and also clear a valid cached SE; separately, the NegBin fit stops short of the MLE.**
- **Question:** G6 #40 (c) had approved patch 04; the five NegBin tests passed with it in a /tmp build.
- **Ruling:** patch 04 WITHDRAWN (patch files 04 + 04b deleted; `cpp_patches_v105/README.md` note 04); the C++ default stays 1e-6 and the tight tolerance is opt-in per call via `negbin_fit_with_eps_fallback()` (`inference_count_negbin.R:575-583`). 2026-11-04, owner (reverses G6 #40 (c)).
- **Why:** committed `src/fast_negbin_regression.cpp:403-411` (436ca96b, 2026-10-25) measured a 1e-10 `eps_g` default converging 7/40 at n = 20 (15/40 n = 100, 22/40 n = 300) versus 40/40 at 1e-6; the five NegBin tests do not exercise the C++ default, so their passing says nothing about patch 04; patches 04 and 04b were not in the tree.
- **Rejected:** the 1e-10 C++ default.

<a id="DECISION-v1.0.5-TODO-115"></a>
### DECISION-v1.0.5-TODO-115: Hurdle / CondPoisson / CountKKGLMM `max(model p, Wald)` rule: keep or return the model p, and warn?

- **TODO:** [v1.0.5-TODO-115](release_v1_0_5.md): **`InferenceIncidKKCondLogitOneLik` returns NA score and LR tests and CIs, with no warning, when `beta_T` is the only free parameter.** Also governs [v1.0.5-TODO-121](release_v1_0_5.md) (**Silent Wald fallback: score and LR p-values are numerically identical to Wald.**).
- **Question (G6 #11, TODO-115/121):** (a) keep (documented "never anti-conservative"); (b) return the model p. And should a conservative-max Wald return warn? Recommend keep, no warning when a model value was computed.
- **Ruling:** (a) keep the max rule; no warning when a model value was computed (today's behaviour, no code change); the classed warning stays only for the model-unavailable fallback. 2026-10-22, owner via G6 #11.
- **Why:** the recommendation ("never anti-conservative").
- **Rejected:** (b) return the model p; warning on every conservative-max return.
- **Note:** for `InferenceCountKKGLMM` the rule was later dropped ([DECISION-v1.0.5-TODO-171](#DECISION-v1.0.5-TODO-171), 2026-10-28).

<a id="DECISION-v1.0.5-TODO-114"></a>
### DECISION-v1.0.5-TODO-114: Full `get_summary()` coefficient tables for the fast-C++ paths: now or later?

- **TODO:** [v1.0.5-TODO-114](release_v1_0_5.md): **`get_summary()` is broken for most classes.**
- **Question (G6 #9, TODO-114 / v1.1.0 TODO-56):** full coefficient tables for fast-C++ paths with unnamed `b`. Recommend defer.
- **Ruling:** deferred (`release_v1_1_0.md → TODO-56`). 2026-10-22, owner via G6 #9 (recorded in the G6 list only).
- **Why:** the recommendation; the base-class fix already returns and prints a table.
- **Rejected:** full tables in 1.0.5.

<a id="DECISION-v1.0.5-TODO-112"></a>
### DECISION-v1.0.5-TODO-112: Accept the seeded rand p / CI default change (reproducible but different)?

- **TODO:** [v1.0.5-TODO-112](release_v1_0_5.md): **Randomization p-values and CIs ignore both the design seed and `Inference$set_seed()`, and the design-level permutation cache ignores the seed.**
- **Question (G6 #29):** accept the documented default change (NEWS entry exists). Recommend accept.
- **Ruling:** accept (with TODO-109 and TODO-120). 2026-10-22, owner via G6 #29.
- **Why:** the recommendation; NEWS entries exist.
- **Rejected:** keeping the unseeded draws.

<a id="DECISION-v1.0.5-TODO-111"></a>
### DECISION-v1.0.5-TODO-111: Does the representative-subset zero-covariate smoke test close the coverage item?

- **TODO:** [v1.0.5-TODO-111](release_v1_0_5.md): **The KK and frailty survival classes crash when the covariate frame has zero columns.**
- **Question (G6 #34):** accept the representative-subset smoke test (KK/frailty classes x match/KK14, 214 expectations pass) as closing the coverage item, or require every procedure x every matching design? Recommend accept.
- **Ruling:** accept; the smoke test closes the coverage item. 2026-10-22, owner via G6 #34.
- **Why:** the recommendation.
- **Rejected:** every procedure x every matching design.

<a id="DECISION-v1.0.5-TODO-109"></a>
### DECISION-v1.0.5-TODO-109: Accept the all-censored RMST arm = horizon default change (was NA)?

- **TODO:** [v1.0.5-TODO-109](release_v1_0_5.md): **The Turnbull (interval-censored) RMST/median path silently drops exact events, and still uses a separate τ per arm.**
- **Question (G6 #29):** accept the documented default change (NEWS entry exists). Recommend accept.
- **Ruling:** accept (with TODO-112 and TODO-120). 2026-10-22, owner via G6 #29.
- **Why:** the recommendation; NEWS entries exist.
- **Rejected:** keeping NA for an all-censored arm.

<a id="DECISION-v1.0.5-TODO-105"></a>
### DECISION-v1.0.5-TODO-105: Build the `add_block_fixed_effects` opt-in now, or document and defer?

- **TODO:** [v1.0.5-TODO-105](release_v1_0_5.md): **Regression inference on blocking designs adds no block fixed effects, and this is not documented.**
- **Question (G6 #7):** build `add_block_fixed_effects` (default FALSE) now or document only and defer. Recommend defer (docs shipped). It would touch the same 37 classes (plus KK/IVWC/OneLik variants if wanted).
- **Ruling:** defer; filed as `release_v1_1_0.md → TODO-64`; TODO-105 box checked. 2026-10-22, owner via G6 #7.
- **Why:** the recommendation; the docs already shipped.
- **Rejected:** building the opt-in in 1.0.5.

<a id="DECISION-v1.0.5-TODO-103"></a>
### DECISION-v1.0.5-TODO-103: Close the cluster-SE TODO with per-class CR2 tracked in v1.1.0, and accept the Satterthwaite df default change?

- **TODO:** [v1.0.5-TODO-103](release_v1_0_5.md): **Asymptotic SEs ignore clustering on cluster designs.**
- **Question (G6 #8):** close the box with per-class CR2 tracked in v1.1.0 TODO-55; accept the default change to non-integer Satterthwaite df on cluster designs. Recommend yes to both.
- **Ruling:** yes to both: box closed, per-class CR2 tracked as `release_v1_1_0.md → TODO-55`; the documented non-integer Satterthwaite df default change on cluster designs accepted (NEWS line present). 2026-10-22, owner via G6 #8.
- **Why:** the recommendation.
- **Rejected:** keeping the box open for per-class CR2.

<a id="DECISION-v1.0.5-TODO-101"></a>
### DECISION-v1.0.5-TODO-101: BCa small-B policy: document, fall back to percentile, or relax the guard?

- **TODO:** [v1.0.5-TODO-101](release_v1_0_5.md): **Bootstrap CIs silently return `c(NA, NA)` whenever they are wider than 5 outcome units.**
- **Question (G6 #12, from the maintainer brief):** (a) document; (b) percentile fallback; (c) relax the guard (the 5% invalid-interval cap was confirmed 2026-10-21). Recommend (a).
- **Ruling:** (a) document (agent doc work; guard unchanged, no fallback): the "Minimum B for BCa" section of `InferenceNonParamBootstrap` says the guard is deliberate, the interval is `c(NA, NA)` with the warning when it trips, and an NA counts as invalid under the 5% cap. 2026-10-22, owner via G6 #12.
- **Why:** the recommendation.
- **Rejected:** (b) percentile fallback; (c) relaxing the guard.

<a id="DECISION-v1.0.5-TODO-97a"></a>
### DECISION-v1.0.5-TODO-97a: Which component boundary for the shared resampling helpers, and which duplicated helper bodies win?

- **TODO:** [v1.0.5-TODO-97](release_v1_0_5.md): **Inference component dependencies declare packaging, not use.**
- **Question:** the component-boundary option for the cross-called resampling helpers (G6 #18), and decision 1:
  which body wins for the duplicated helpers.
- **Options on the table:** (a) one neutral resampling-support component holding the shared cache/worker and
  cross-cycle helpers (simple dependency DAG, but risks an overly broad mixed-responsibility component); (b) separate
  cache/worker and jackknife-bootstrap support components (narrower, but the extracted methods must have no back-calls
  or state ownership tied to their current providers); (c) keep the existing component names and choose one-way
  ownership for the cross-called helpers (minimal new registry surface, may couple unrelated capabilities). The
  TODO-1 fixture compares each class's effective component list and method-owner bindings, so a helper component changes
  the golden; the owner had to specify grouping/ownership and how the golden is preserved (never weakened or
  regenerated implicitly).
- **Ruling:** Option A, one neutral `ResamplingCore` component, confirmed; decision 1: the `NonparametricBootstrap`
  bodies of `resolve_jackknife_unit`, `jackknife_block_size_gt_one_unsupported` and
  `mark_jackknife_nonestimable_if_block_unsupported` win and the `Jackknife` copies are removed. 2026-10-22, owner via
  G6 #18 ("PARTLY DECIDED 2026-10-22").
- **Why:** every class with `Jackknife` also has `NonparametricBootstrap`; the only body difference was that the
  surviving copy of `jackknife_block_size_gt_one_unsupported` re-raises EDI control conditions (interrupts, timeouts)
  from `get_block_ids()` and swallows only other errors. Removing the copies removes the remaining
  `Jackknife`↔`NonparametricBootstrap` duplicate edges.
- **Rejected:** (b) separate support components; (c) keep names with one-way ownership.

<a id="DECISION-v1.0.5-TODO-97b"></a>
### DECISION-v1.0.5-TODO-97b: Keep or drop the `load_resampling_draw_into_worker()` loader dispatcher?

- **TODO:** [v1.0.5-TODO-97](release_v1_0_5.md): **Inference component dependencies declare packaging, not use.**
- **Question:** G6 #18 decision 2, the loader-injection signature.
- **Options on the table:** (a) keep the dispatcher (it dispatched via `private[[contract$loader]]`, invisible to the
  call-graph checker); (b) drop it and have each call site call its own loader.
- **Ruling:** (b), drop the dispatcher. 2026-10-22, owner via G6 #18.
- **Why:** the dispatch was invisible to the call-graph checker. No further reason recorded.
- **Rejected:** (a).

<a id="DECISION-v1.0.5-TODO-97c"></a>
### DECISION-v1.0.5-TODO-97c: Where does the `create_bootstrap_worker_state()` `NULL` default live?

- **TODO:** [v1.0.5-TODO-97](release_v1_0_5.md): **Inference component dependencies declare packaging, not use.**
- **Question:** G6 #18 decision 3, the hook-default move.
- **Options on the table:** (a) move the `NULL` default from `NonparametricBootstrap` into `ResamplingCore` when that
  component is created (plan TODO-3); (b) leave it in `NonparametricBootstrap`.
- **Ruling:** (a). 2026-10-22, owner via G6 #18. Condition: the overrides (`Wald`, the cached-likelihood base and about
  10 leaf classes) must still win; verify merge order through the method-owner golden, do not assume it.
- **Why:** No reason recorded.
- **Rejected:** (b).

<a id="DECISION-v1.0.5-TODO-97d"></a>
### DECISION-v1.0.5-TODO-97d: When to do the `ResamplingCore` refactor?

- **TODO:** [v1.0.5-TODO-97](release_v1_0_5.md): **Inference component dependencies declare packaging, not use.**
- **Question:** the timing of the `ResamplingCore` refactor itself.
- **Options on the table:** (a) last in 1.0.5 after G4/G5 (recommended); (b) defer to v1.1.0; (c) do it now.
- **Ruling:** (c), do it now, in 1.0.5 ("owner: do it now"; owner instruction). 2026-10-22, owner. G6 #18 then fully
  decided.
- **Why:** No reason recorded.
- **Rejected:** (a) last in 1.0.5, (b) defer to v1.1.0.

<a id="DECISION-v1.0.5-TODO-67a"></a>
### DECISION-v1.0.5-TODO-67a: Recover the KK21 speedup fixture and metric, or approve a replacement protocol?

- **TODO:** [v1.0.5-TODO-67](release_v1_0_5.md): **KK21 Weibull AFT fits converge to the wrong point**
- **Question:** G6 #24: recover the historical fixture/generator, seed, options and metric, or approve a replacement
  (choose its paired-case count/seed schedule, approve/replace mASMD as primary outcome and its numeric acceptance
  rule, decide whether matched fraction/pair count is a required guard and its denominator, and the handling of failed
  or nonestimable paired cases).
- **Options on the table:** (a) recover the historical inputs (a bounded lookup on 2026-10-21 found them not
  recoverable); (b) approve the replacement protocol.
- **Ruling:** (b), approve the replacement: mASMD is the primary outcome, ~200 paired fixed-seed cases, a
  matched-fraction guard, nonestimable cases stay in the denominator. The numeric margin is a runbook proposal the
  owner confirms before the run (G4-C runbook R6). 2026-10-22, owner via G6 #24.
- **Why:** the original seeds/options/metric were not recoverable from the repo, history or scratch.
- **Rejected:** (a).

<a id="DECISION-v1.0.5-TODO-67b"></a>
### DECISION-v1.0.5-TODO-67b: Confirm the R6 matching-quality pass rules?

- **TODO:** [v1.0.5-TODO-67](release_v1_0_5.md): **KK21 Weibull AFT fits converge to the wrong point**
- **Question:** closing audit 2026-10-23 ("NEEDS-DECISION (owner), confirmation only"): G6 #24 approved the protocol
  but left the numeric margin for the owner to confirm before the run. Confirm the proposed pass rules, or name others.
- **Options on the table:** (a) confirm as proposed: the upper 95% bound of the mean paired mASMD delta <= 0.01
  (`--margin 0.01`); the corrected mean matched fraction >= the old mean - 0.02 (`--fraction-guard 0.02`); the
  corrected arm has no more nonestimable cases than the old arm; (b) name other rules. No agent work was left; after the
  answer it is gated: G1 (formal re-run of the native sub-gate test), R6, and regeneration of the affected benchmark
  rows.
- **Ruling:** (a), confirmed as proposed; now owner-approved (runbook R6, G6 #24). 2026-10-23, owner via closing-audit
  decision 3. #24 fully decided.
- **Why:** No reason recorded.
- **Rejected:** (b).

<a id="DECISION-v1.0.5-TODO-62"></a>
### DECISION-v1.0.5-TODO-62: Zhang exact-CI endpoint metric and tolerance, the Fisher/EDI speed target, and which report copy is canonical?

- **TODO:** [v1.0.5-TODO-62](release_v1_0_5.md): **Benchmark harness: R6 construction inside the timed region misreads
  sub-10 ms rows**
- **Question:** G6 #21: the Zhang exact-CI endpoint error metric and numeric tolerance. G6 #39: (i) the owner-approved
  procedure-speed target (Fisher/EDI >= 1) measured 0.149-0.208x in every run: restate/defer or optimize the Zhang CI?
  (ii) the two Markdown report copies disagree (BinaryMatch row, Oct 14 sections, OLS-kernel text): which is canonical?
- **Options on the table:** #21: (b) <= 0.01 max abs log-bound difference, which admits both observed cases (0.0044 and
  0.0064), or another metric/bound; #39 (i) restate/defer vs optimize; (ii) regenerate both copies from the harness in
  the G2 run vs pick one copy.
- **Ruling:** #21 (b) <= 0.01 max abs log-bound difference; #39 (i) restate/defer (`release_v1_1_0.md → TODO-68`);
  (ii) regenerate both Markdown copies from the harness in the G2 run. 2026-10-22, owner via G6 #21 and #39 (the
  accept-all batch: each recommendation).
- **Why:** the recommendation's reason: <= 0.01 admits both observed cases 0.0044 and 0.0064. No further reason
  recorded.
- **Rejected:** optimizing the Zhang CI for 1.0.5; picking one report copy by hand.

<a id="DECISION-v1.0.5-TODO-61"></a>
### DECISION-v1.0.5-TODO-61: Confirm the shipped `match_objective = "distance"` default?

- **TODO:** [v1.0.5-TODO-61](release_v1_0_5.md): **Binary matching hands `nonbimatch` squared distances with a
  `double.xmax` diagonal**
- **Question:** G6 #42: explicitly confirm the shipped default `match_objective = "distance"` (unsquared; changes ~22%
  of matched pairs vs 1.0.x), which was accepted only implicitly.
- **Options on the table:** confirm, or restore the squared objective as the default.
- **Ruling:** confirmed: `match_objective = "distance"` stays the shipped default. 2026-10-22, owner via G6 #42.
- **Why:** No reason recorded (the recommendation was "confirm").
- **Rejected:** a squared-distance default.

<a id="DECISION-v1.0.5-TODO-60"></a>
### DECISION-v1.0.5-TODO-60: Accept the changed fixed-seed Pocock-Simon sequence with missing covariates, or restore 1.0.2's stream?

- **TODO:** [v1.0.5-TODO-60](release_v1_0_5.md): **Pocock–Simon: O(t) work per arrival (O(n²) per trial)**
- **Question:** the G3 parity check fails one must-match case, `SeqPocockSimon_late_level_and_NA:assign` (8 of 24
  entries differ). Root cause: in 1.0.2 every arrival rebuilt the model matrix, and with a missing covariate that runs
  `missRanger` imputation, which draws from R's RNG; 1.0.5 defers the rebuild (`pocock_simon_per_arrival_rebuild.md`
  TODO-3), so the RNG stream differs. Fixtures without missing covariates match exactly.
- **Options on the table:** (a) accept as an intended change: mark the case EXPECTED-DIFFER in the parity script and add
  a NEWS note that fixed-seed Pocock-Simon sequences change when covariates have missing values; (b) restore 1.0.2's
  stream.
- **Ruling:** (a), accept as an intended change. 2026-11-10, owner.
- **Why:** No reason recorded.
- **Rejected:** (b).

<a id="DECISION-v1.0.5-TODO-59"></a>
### DECISION-v1.0.5-TODO-59: What numeric quiet-host cutoff does G2 use?

- **TODO:** [v1.0.5-TODO-59](release_v1_0_5.md): **Design construction overhead: `packageVersion()` disk read and
  eager covariate ingestion**
- **Question:** G6 #43 (optional): the numeric quiet-host cutoff for G2 ("the maintainer must choose a numeric cutoff
  only if one is required").
- **Options on the table:** the recommended 1-minute load average < 1.0 with nothing else running, or another cutoff /
  none.
- **Ruling:** 1-minute load average < 1.0 with nothing else running. 2026-10-22, owner via G6 #43.
- **Why:** No reason recorded.

<a id="DECISION-v1.0.5-TODO-58a"></a>
### DECISION-v1.0.5-TODO-58a: Keep the >= 1x-vs-`boot` bootstrap speed target, or restate it?

- **TODO:** [v1.0.5-TODO-58](release_v1_0_5.md): **Nonparametric bootstrap worker: per-draw data.frame subsetting,
  model-matrix rebuild and R-level rank check**
- **Question:** G6 #38: the >= 1x-vs-`boot` target is almost certainly unmet (full-size diagnostic OLS 0.137x,
  logistic 1.030x, Cox 0.392x; "no safe R-only optimization").
- **Options on the table:** (a) restate the target as workload-specific, move speed acceptance to v1.1.0 and close on G3
  parity; (b) keep >= 1x and authorize more optimization (overlaps TODO-57 plan TODO-7). Recommended (a).
- **Ruling:** (a): the target is restated as workload-specific; speed acceptance moves to `release_v1_1_0.md → TODO-68`;
  the TODO closes on G3 parity (plus the G2 original-B run recorded with provenance). 2026-10-22, owner via G6 #38.
- **Why:** No reason recorded beyond the measured shortfall.
- **Rejected:** (b).

<a id="DECISION-v1.0.5-TODO-58b"></a>
### DECISION-v1.0.5-TODO-58b: Accept the Cox bootstrap parity drift under the D2 rule, or require 1e-10?

- **TODO:** [v1.0.5-TODO-58](release_v1_0_5.md): **Nonparametric bootstrap worker: per-draw data.frame subsetting,
  model-matrix rebuild and R-level rank check**
- **Question:** G3 parity, 2026-11-10: OLS and logistic pass; Cox fails the 1e-10 tolerance: 108 of 500 draws differ by
  > 1e-10, max 2.1e-8 (relative 4.5e-8), median 1.3e-11, distribution SD changes by 8e-11. This is fit-convergence-level
  drift (1.0.5 changed the Cox Newton path, e.g. patch 08), not a behavior change.
- **Options on the table:** (a) accept under the D2 numerical-equivalence rule (a Cox coefficient tolerance of ~1e-7);
  (b) require 1e-10.
- **Ruling:** (a), accept the Cox drift under the D2 numerical-equivalence rule (max 2.1e-8, relative 4.5e-8); G3 for
  TODO-58 is met. 2026-11-10, owner.
- **Why:** the drift is fit-convergence-level, not a behavior change (agent's reading); no owner reason recorded.
- **Rejected:** (b).

<a id="DECISION-v1.0.5-TODO-57"></a>
### DECISION-v1.0.5-TODO-57: Keep all Bayesian-bootstrap performance work in 1.0.5, or ship the R slices and move the rest?

- **TODO:** [v1.0.5-TODO-57](release_v1_0_5.md): **Bayesian bootstrap performance: parallel scaling and native weighted
  refits**
- **Question:** G6 #37.
- **Options on the table:** (a) keep all of it in 1.0.5 (R slices plan TODO-1/2/3/7, TODO-11 item 7 audit, native
  weighted Cox/Weibull refits, fork/mirai validation runs); (b) ship the R slices already done and move plan
  TODO-2/3/5/6 (native)/7/8/9 to v1.1.0. Recommended (b): large, needs a build and owner-authorized fork runs.
- **Ruling:** (b). Plan TODO-2/3/5/6 (native weighted Cox/Weibull)/7/8/9 and the TODO-11 item 7 audit moved to
  `release_v1_1_0.md → TODO-63`. Plan TODO-1 (the harness) was not named and stays with TODO-57; only its
  owner-authorized baseline run is left (G2). 2026-10-22, owner via G6 #37.
- **Why:** the recommendation's reason: the work is large and needs a build and owner-authorized fork runs.
- **Rejected:** (a).

<a id="DECISION-v1.0.5-TODO-56"></a>
### DECISION-v1.0.5-TODO-56: Confirm the exact 16 target IDs and argv for the one safe regeneration slice?

- **TODO:** [v1.0.5-TODO-56](release_v1_0_5.md): **`InferenceIncidModifiedPoisson`'s non-robust SE was severely
  over-conservative**
- **Question:** G6 #5: confirm the exact 16 target IDs and argv for the one safe slice (preserve the 152-row partial run;
  do not merge or restart the broad run).
- **Options on the table:** confirm as listed in the entry (recommended), or change the target list.
- **Ruling:** confirmed as listed; G7 may run that slice with a receipt; the 152-row partial run stays untouched.
  2026-10-22, owner via G6 #5.
- **Why:** No reason recorded.

<a id="DECISION-v1.0.5-TODO-55"></a>
### DECISION-v1.0.5-TODO-55: Which estimand does the proportion mean-diff coverage truth use, zero-noise conditional or noisy marginal?

- **TODO:** [v1.0.5-TODO-55](release_v1_0_5.md): **Proportion mean-diff closed-form coverage truth is stale relative
  to the 2026-09-15 DGP fix**
- **Question:** the DGP adds `N(0, 0.1)` noise inside the logit transform, while the corrected closed form omits that
  noise and is the zero-noise conditional contrast; its exact noisy marginal-mean contrast may differ. A maintainer had
  to confirm which estimand the coverage truth uses.
- **Options on the table:** (a) the zero-noise closed form (conditional contrast); (b) the noisy marginal contrast
  `E[p_t(eps)] - E[p_c(eps)]`.
- **Ruling:** (b), noisy marginal truth. 2026-10-21, owner.
- **Why:** the DGP adds the `N(0, SD_NOISE)` logit noise in both arms and the estimator is a difference of observed
  proportion means, so coverage truth is the noisy marginal contrast. (It differs from the zero-noise closed form by at
  most ~3e-4 at `SD_NOISE = 0.1`.)
- **Rejected:** (a).

<a id="DECISION-v1.0.5-TODO-53"></a>
### DECISION-v1.0.5-TODO-53: Accept the approximate `condition_on_ws_for_rand_tests = TRUE` default for KK21stepwise randomization p-values?

- **TODO:** [v1.0.5-TODO-53](release_v1_0_5.md): **Randomization p-values are conservative at the null under
  `DesignSeqOneByOneKK21stepwise` (incidence)**
- **Question:** the remaining release blocker was the owner's decision on the approximate default (redraw approximation)
  versus exact replay (`FALSE`).
- **Options on the table:** (a) keep the approximate default `TRUE`; (b) switch to exact replay.
- **Ruling:** (a), approximate default accepted. 2026-10-20, owner.
- **Why (evidence recorded with the ruling):** paired null simulation, recompiled install (EDI 1.0.3 string):
  `DesignSeqOneByOneKK21stepwise`, incidence, n = 148, one covariate, outcome depends on the covariate with no treatment
  effect, r = 151, 200 experiments, same data/observed design/draw seed in both arms, mean-difference statistic computed
  directly from `draw_ws_according_to_design()` draws (inclusive tails). `TRUE` (default): reject@0.05 0.030, @0.10
  0.085, mean p 0.550, median 0.579. `FALSE` (exact replay): 0.030, 0.090, 0.542, 0.556. Mid-p is near uniform in both
  (KS p = 0.17/0.25). Paired p-values correlate 0.986 (mean diff -0.008, SD 0.048); mean SD of the reference draws
  0.0797 vs 0.0792 (ratio 0.999); ties about 4% of each reference distribution. The residual inclusive-tail conservatism
  is the documented discreteness effect, not the redraw approximation. Caveat (verified 2026-10-20 on the same 200
  experiments): the original 60-null result (median p 0.71) came from the Zhang exact combined test, not these draws: the
  public-API p-value had reject@0.05 0.010, @0.10 0.020, mean 0.723, median 0.816 (correlation with the draw-based
  p-values 0.70), versus 0.030/0.085/0.550/0.579 for the draws. Before TODO-99, `compute_rand_two_sided_pval()` returned
  it for matched/Bernoulli incidence designs (`should_use_zhang_incidence_randomization()`), so
  `condition_on_ws_for_rand_tests` could not affect that p-value [(audit 2026-11-04): the Zhang dispatch was removed
  2026-10-20, `inference_all_abstract_rand.R:330-334`; Zhang is now explicit only (`type = "Zhang"`), so the default
  draw-based p-value is affected by `condition_on_ws_for_rand_tests`]. Single configuration only (one covariate, one
  statistic, incidence); the 95% interval on a 0.05 rejection rate at 200 reps is about +/-0.03.
- **Rejected:** (b).

<a id="DECISION-v1.0.5-TODO-52"></a>
### DECISION-v1.0.5-TODO-52: Recover the orphan low-coverage findings' provenance, run a replacement study, or close?

- **TODO:** [v1.0.5-TODO-52](release_v1_0_5.md): **six audited findings show real but heterogeneous historical flags
  (`pval_miscalibration`, `low_coverage`, or `biased_estimate`)**
- **Question:** G6 #25: provenance recovery or approval of a replacement targeted study.
- **Options on the table:** (a) close the investigation and let the G4 audit decide; (b) recover the historical cells'
  inputs; (c) approve a replacement targeted study / calibration criterion.
- **Ruling:** (a), close; the post-G4 audit of the regenerated CSVs re-checks coverage, p-value calibration and bias for
  these classes under current code, and any class still flagged gets its own focused TODO. The two unchecked sub-items
  (historical-cell recovery / replacement study; owner-approved calibration criterion for the pilots) are superseded and
  not required for 1.0.5. 2026-10-22, owner via G6 #25.
- **Why:** the flagged historical cells cannot be replayed, and no common mechanism was found.
- **Rejected:** (b), (c).

<a id="DECISION-v1.0.5-TODO-33"></a>
### DECISION-v1.0.5-TODO-33: Accept the synthetic trigger/replay evidence, or run a real-data search and coverage study?

- **TODO:** [v1.0.5-TODO-33](release_v1_0_5.md): **Randomization-CI high-precision refinement ignores `lower`**
- **Question:** G6 #23.
- **Options on the table:** (a) accept the synthetic trigger/replay evidence and close; (b) approve a larger real-data
  trigger search and coverage study on an idle host.
- **Ruling:** (a), accept and close. 2026-10-22, owner via G6 #23.
- **Why:** the fix (the direction branch in `high_precision_confirm_and_refine_ci_bound()`) is exercised in both
  directions by the forced-trigger public-API regression and the analytic crossing fixture (30 assertions), plus the
  shared-cache contract test (37); the 500-replication OLS coverage check (92.2% at nominal 90%) and roughly 255
  real-data CI calls on `mtcars`, `airquality` and `trees` showed no errors. The natural trigger is rare and a search
  would rerun the same code.
- **Rejected:** (b), the real-data trigger search and the larger idle-host coverage study.

<a id="DECISION-v1.0.5-TODO-31a"></a>
### DECISION-v1.0.5-TODO-31a: What is the 1.0.5 acceptance criterion for the shipped 20-node GLMM quadrature?

- **TODO:** [v1.0.5-TODO-31](release_v1_0_5.md): **Random-effect variance collapse in GLMM/CLMM fits**
- **Question:** the 1e-4 exact-NLL rule at 20 fixed nodes measures quadrature error, not optimizer quality, so it cannot
  gate the shipped setting.
- **Options on the table:** the "cheap option for 1.0.5" (option (1)): accept the 20-node setting by agreement with the
  320-node optimum at the measured level and document the limitation; or a tight tolerance / adaptive quadrature now.
- **Ruling:** the cheap option (1): the 20-node (shipped) acceptance is agreement with the 320-node optimum, not the
  1e-4 exact-NLL rule, which stays as the optimizer-correctness gate at 320 nodes. Numeric bound confirmed:
  |coefficient diff| <= 0.75 SE and |log sigma diff| <= 0.10 on the ten fixtures (seeds 41001:41010), plus documentation
  of the limitation. 2026-10-21, owner ("do (1) and revisit after todo153").
- **Why:** measured baseline 2026-10-21 (installed EDI 1.0.3, Poisson GLMM, seeds 41001:41010): 20-node vs 320-node
  optimum max |intercept diff| 0.67 SE, max |slope diff| 0.62 SE, max |log sigma diff| 0.084; 40 nodes is no better; a
  tight tolerance therefore cannot gate the shipped setting. Real accuracy is deferred to adaptive quadrature.
- **Revisit if:** after `performance_profiling_and_upgrades.md → TODO-153` (adaptive quadrature, v1.2.0) lands.

<a id="DECISION-v1.0.5-TODO-31b"></a>
### DECISION-v1.0.5-TODO-31b: Cloglog CLMM residual: accept the diagnosis, how to map the link name, and the 1.0.5 scope for the false `converged = TRUE`?

- **TODO:** [v1.0.5-TODO-31](release_v1_0_5.md): **Random-effect variance collapse in GLMM/CLMM fits**
- **Question:** G6 #45 (plan `../bug_fix_plans/v1_0_5/clmm_sigma_collapse_false_convergence.md`).
- **Options on the table:** (i) accept that the golden cloglog `log_sigma = -5` is the correct MLE and that
  `ordinal::clmm`'s cloglog/loglog link names are swapped (closing the residual as a reference error), and file an
  upstream report? (ii) EDI's own `ordinal::clmm` cloglog calls (BB weighted refit, `use_rcpp = FALSE`): (a)
  runtime-probed name mapping (R-only); (b) hard-code `"loglog"`; (c) refuse cloglog there until a native weighted
  kernel exists. (iii) 1.0.5 scope for the false `converged = TRUE`: (a) R-only `clmm_eps_g = 1e-12` plus gradient
  acceptance <= 1e-4 with one Newton retry (~3x CLMM fit cost; estimates move up to ~6e-3, median ~2e-4; G4 rows for all
  four KKCLMM classes); (b) (a) plus porting `fast_ordinal_glmm.cpp`'s polish/projected-gradient (KKT) convergence into
  `fast_ordinal_clmm.cpp` in G1; (c) defer to v1.1.0 and document. Recommended yes/yes, (a), (a).
- **Ruling:** (i) accept the diagnosis; the cloglog residual is a reference error; the upstream report is drafted at
  `../bug_fix_plans/v1_0_5/upstream_ordinal_clmm_link_swap_report.md` and the owner sends it. (ii)(a) runtime-probed
  link-name mapping. (iii)(a) R-only plan TODO-3 + TODO-4, accepting the fit cost; C++ TODO-5 is not in 1.0.5 scope
  (v1.1.0, or G1 only if that build happens anyway). 2026-10-22, owner via G6 #45.
- **Why:** No reason recorded beyond the recommendation.
- **Rejected:** (ii)(b), (ii)(c); (iii)(b) unless the G1 build happens anyway, (iii)(c).

<a id="DECISION-v1.0.5-TODO-23a"></a>
### DECISION-v1.0.5-TODO-23a: What are the RMST coverage-calibration acceptance criteria?

- **TODO:** [v1.0.5-TODO-23](release_v1_0_5.md): **`InferenceSurvivalRestrictedMeanDiff` computes RMST to a different
  truncation horizon τ per treatment arm**
- **Question:** the acceptance criteria for the TODO-5 coverage calibration: denominator, invalid-interval cap,
  replicates.
- **Ruling (2026-10-21, owner):**
  - **Denominator:** accept on the **all-attempts** denominator. Every attempted replicate counts; an invalid,
    non-finite or missing interval counts as noncoverage (the BCa diagnostic is 33/35 = 94% finite-only but 33/120 =
    27.5% all-attempts, the gap being almost entirely invalid intervals). The generic `SimulationFrameworkReport`
    finite-only rate (invalid excluded) is not acceptance evidence for this item.
  - **Invalid fraction:** report the invalid count per method family and cap it separately: a family fails if more than
    5% of attempts yield an invalid interval (5% cap confirmed by the owner 2026-10-21: "keep 5%, conventional and
    strict").
  - **Precision / replicates:** target a 95% binomial half-width of about 2 points at coverage 0.95, i.e. at least 457
    attempted replicates per method family (120 replicates gives only about +/-4 points). A family passes when its exact
    binomial interval for all-attempts coverage contains 0.95.
- **Why:** for the cap, the owner's words: "conventional and strict". The finite-only rate hides invalid intervals.
- **Rejected:** the finite-only denominator; a looser invalid cap.

<a id="DECISION-v1.0.5-TODO-23b"></a>
### DECISION-v1.0.5-TODO-23b: Go-ahead for the RMST calibration, its target operations, and the targeted-compile criterion?

- **TODO:** [v1.0.5-TODO-23](release_v1_0_5.md): **`InferenceSurvivalRestrictedMeanDiff` computes RMST to a different
  truncation horizon τ per treatment arm**
- **Question:** G6 #22: go-ahead for the coverage-calibration simulation (criteria already set). G6 #36: (i) is the
  affected-method target the audit's 16 low-coverage operations or all 18 source/raw candidate CI operations, and which
  run/grid/attempt statuses define the anti-join? (ii) waive linked-plan TODO-3's targeted-compile criterion in favour of
  CI run 38808821543 plus the G1 build?
- **Options on the table:** #22 go / no-go; #36 (i) 16 operations, or all 18 reconciled against a fresh current-source
  run (recommended), not the merged historical union; (ii) waive (recommended) or keep.
- **Ruling:** go ahead after G1 (at least 457 attempts per family, all-attempts coverage, at most 5% invalid); (i) all 18
  source/raw CI operations, reconciled against a fresh current-source run; (ii) waived. Procedure: G4-C runbook R4.
  2026-10-22, owner via G6 #22 and #36.
- **Why:** No reason recorded beyond the recommendations.
- **Rejected:** the 16-operation target; the merged historical union; keeping the targeted-compile criterion.

<a id="DECISION-v1.0.5-TODO-18a"></a>
### DECISION-v1.0.5-TODO-18a: Calibrate the 9 named smoothed-bootstrap cells or all 16 supported cells, and drop the historical reproduction?

- **TODO:** [v1.0.5-TODO-18](release_v1_0_5.md): **`smoothed` randomization-bootstrap p-value adds unclamped continuous
  noise to binary/ordinal responses**
- **Question:** G6 #35.
- **Options on the table:** (a) only the 9 cells the plan names; (b) all 16 source-supported cells (4,500 vs 8,000
  estimable outer cases at B = 101); and drop plan TODO-3 (historical reproduction; inputs are gone)? Recommended (a) and
  drop.
- **Ruling:** (a) the 9 named cells; plan TODO-3 dropped. Acceptance follows the #20 rule (Clopper-Pearson 95% per
  variant x cell, at least 500 finite p-values, B = 101, paired percentile/smoothed); procedure G4-C runbook R3; the plan
  TODO-1/2 investigation comes first. 2026-10-22, owner via G6 #35 (with #20).
- **Why:** the historical inputs are gone. No further reason recorded.
- **Rejected:** (b).

<a id="DECISION-v1.0.5-TODO-18b"></a>
### DECISION-v1.0.5-TODO-18b: On a bootstrap-randomization replay, does `DesignFixedOptimalBlocks` reuse its blocks or re-solve them?

- **TODO:** [v1.0.5-TODO-18](release_v1_0_5.md): **`smoothed` randomization-bootstrap p-value adds unclamped continuous
  noise to binary/ordinal responses** (G6 #51, shared with TODO-131)
- **Question:** `DesignFixedOptimalBlocks` replays with its cached `private$block_ids`, which index the ORIGINAL rows, on
  an iid resample (no `m_vec_b`); the redrawn `w` is balanced within stale position-blocks. Should replay re-solve the
  blocks or reuse them?
- **Options on the table:** (a) keep the observed blocks (each resampled unit keeps the block id it carried) and redraw
  within them; (b) re-solve the optimal blocking on the resample; (b) changes the design being replayed and costs a solve
  per draw.
- **Ruling:** (b), re-solve the optimal blocks on each resampled dataset; overrides the same-day coordinator default
  (a) ("DECIDED-by-default 2026-10-23 ... reuse, do not re-solve", struck out). Done in TODO-131: same solver and
  settings on the resampled covariates, solve under the replay draw's seed, a failed solve makes that draw `NA`.
  2026-10-23, owner via G6 #51. Follow-up owner choice the same day (ompr cost): (c) keep re-solving everywhere,
  documented (re-solve for every method incl. `ompr`, ~1.7 s/draw at n = 12 and ~79 s/draw at n = 16; documented in the
  `DesignFixedOptimalBlocks` @details and the NEWS replay bullet; no code change).
- **Why:** No reason recorded.
- **Rejected:** (a) reuse.

<a id="DECISION-v1.0.5-TODO-18c"></a>
### DECISION-v1.0.5-TODO-18c: Is the TODO-18 acceptance rule per cell or simultaneous?

- **TODO:** [v1.0.5-TODO-18](release_v1_0_5.md): **`smoothed` randomization-bootstrap p-value adds unclamped continuous
  noise to binary/ordinal responses**
- **Question:** the #20 rule read per cell with no multiplicity correction; amend it for TODO-18?
- **Ruling:** amended: the TODO-18 acceptance rule is simultaneous, Holm across the 18 cell x variant tests (see runbook
  R3), replacing the per-cell no-multiplicity reading of #20 for this TODO only; TODO-16 (R1) keeps #20 as decided.
  2026-10-28, owner.
- **Why:** No reason recorded.
- **Rejected:** the per-cell no-multiplicity reading for TODO-18.

<a id="DECISION-v1.0.5-TODO-18d"></a>
### DECISION-v1.0.5-TODO-18d: R3 cells C2 and N5 fail for both bootstrap variants: accept as a limitation, or fix in 1.0.5?

- **TODO:** [v1.0.5-TODO-18](release_v1_0_5.md): **`smoothed` randomization-bootstrap p-value adds unclamped continuous
  noise to binary/ordinal responses**
- **Question:** R3 ran: N3/N6/N7 pass, N4 passes on its 2,000-rep rerun, N5 fails marginally, C2 fails at 13.4-14.2% (a
  high p/n limitation). Open: the owner decision on C2/N5.
- **Options on the table:** option A, accept C2 and N5 as a documented limitation (move the fix on); others not recorded.
- **Ruling:** option A: C2 and N5 are accepted as a documented limitation; the fix moves to `release_v1_0_6.md` TODO-18.
  2026-11-12, owner.
- **Why:** TODO-18's question (does smoothing break calibration?) is answered no: in every cell smoothed and percentile
  reject at the same rate. C2/N5 fail equally for both variants, from the unstudentized bootstrap at high p / n
  (diamonds `~.`, 24 columns at n = 148).

<a id="DECISION-v1.0.5-TODO-17"></a>
### DECISION-v1.0.5-TODO-17: Fix the Wilcoxon resampling p-value collapse in 1.0.5, or defer the Wilcoxon-specific remedy?

- **TODO:** [v1.0.5-TODO-17](release_v1_0_5.md): **`InferenceAllSimpleWilcox` resampling-family p-values collapse to
  exactly 1**
- **Question:** a maintainer decision on the Wilcoxon-specific remedy or an explicit deferral. If proceeding: require
  nondegenerate-estimand parity, conditional size calibration for HL-zero ties, and a permanent tied p-value/CI
  regression before post-fix comprehensive regeneration; no generic mid-p change.
- **Options on the table:** (a) proceed with a Wilcoxon-specific remedy in 1.0.5 under those conditions; (b) defer.
- **Ruling:** (b), defer the Wilcoxon-specific remedy. Keep the deterministic inclusive-tail method and document the
  conservatism (roxygen on `InferenceAllSimpleWilcox`); no generic mid-p change. TODO-3..7 of the linked plan stay open
  until a candidate passes the conditional-size gate. The item is closed for 1.0.5 as deferred
  (`release_v1_5_0.md → TODO-1`; wording corrected 2026-10-22, it previously said "stays unchecked"); the resampling CI
  undercoverage (~48-57%) from the same mechanism is also deferred and documented, not fixed. 2026-10-21, owner (the
  TODO header also records "CLOSED 2026-10-21 by owner decision: deferred").
- **Why:** No reason recorded.
- **Rejected:** (a); any generic mid-p change.

<a id="DECISION-v1.0.5-TODO-16"></a>
### DECISION-v1.0.5-TODO-16: What is the Type-I acceptance rule for the ordinal / smoothed-bootstrap calibrations?

- **TODO:** [v1.0.5-TODO-16](release_v1_0_5.md): **Ordinal cumulative-link parametric-bootstrap inference — two distinct
  bugs found investigating `InferenceOrdinalCloglogRegr`'s 60% Type-I error**
- **Question:** G6 #20 (TODO-16/18): the acceptance rule and denominator (cells, DGP, per-cell vs simultaneous,
  confidence level, >= 500 estimable cases per stratum). The entry listed the owner choices: approve the true-null
  DGP/dataset and whether `~1` and `~.` are separate strata; select outer replicate target, inner LR-bootstrap B,
  interval confidence level, treatment of failures in any acceptance denominator, and per-method/cell interval vs a
  simultaneous/multiplicity-adjusted criterion.
- **Ruling:** a Clopper-Pearson 95% interval per method and stratum; 500 outer datasets per stratum; a finite-p
  denominator with attempted/nonestimable counts shown; `~1` and `~.` are separate strata. Procedure for the Cloglog
  direct-LR / LR-bootstrap / Bartlett null: G4-C runbook R1. 2026-10-22, owner via G6 #20. (For TODO-18 only, amended
  2026-10-28 to a simultaneous Holm rule: DECISION-v1.0.5-TODO-18c.)
- **Why:** No reason recorded. (Planning half-widths at p = 0.05: about 1.9 points at 500 outer datasets, 1.35 at
  1,000, 0.96 at 2,000.)
- **Rejected:** a simultaneous / multiplicity-adjusted criterion (for TODO-16).

<a id="DECISION-v1.0.5-TODO-14"></a>
### DECISION-v1.0.5-TODO-14: How does the 8,640-key gate treat the FixedBinaryMatch `~1` x `pte_example` keys that cannot run?

- **TODO:** [v1.0.5-TODO-14](release_v1_0_5.md): **`InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC` randomization
  distribution all-NA in production**
- **Question:** G6 #33: the 8,640-key gate rejects any skip "unless independently approved before the run", but the
  FixedBinaryMatch `~1` setup cannot run on `pte_example` (no pair ids). Also authorize the multi-hour (~3.5-4.1 h) run.
- **Options on the table:** (a) approve those keys as a predeclared expected skip with counts in the manifest; (b) shrink
  the manifest; (c) supply a pairing source. Recommended (a).
- **Ruling:** (a), predeclared expected skip with counts in the manifest; the multi-hour run is authorized (G4-C runbook
  R5). 2026-10-22, owner via G6 #33.
- **Why:** No reason recorded.
- **Rejected:** (b), (c).

<a id="DECISION-v1.0.5-TODO-12"></a>
### DECISION-v1.0.5-TODO-12: Approve the release-wide reused-worker bit-for-bit sweep?

- **TODO:** [v1.0.5-TODO-12](release_v1_0_5.md): **Latent `cached_mod` reset gap, same bug shape as TODO-9**
- **Question:** G6 #28 (first half): approve the release-wide bit-for-bit sweep (`scripts/reused_worker_bitforbit_sweep.R`,
  720 evaluations). (The second half, a `.postN` Python release for patch 06 under TODO-108/106, belongs to those TODOs.)
- **Ruling:** approved, to run after G1. 2026-10-22, owner via G6 #28. (Push/tag of the Python release still needs its own
  go-ahead.)
- **Why:** No reason recorded.

<a id="DECISION-v1.0.5-TODO-10a"></a>
### DECISION-v1.0.5-TODO-10a: Matched-Cox MC truth: covariate cap or Firth, target population, and the ionosphere disposition?

- **TODO:** [v1.0.5-TODO-10](release_v1_0_5.md): **MC coverage-truth uses the wrong covariate set**
- **Question:** G6 #19: the matched-Cox MC-truth target population (finite empirical rows vs specified
  superpopulation), covariate cap or Firth, and the PropBeta/FractionalLogit `ionosphere` disposition (plan TODO-11).
- **Ruling:** in 1.0.5, cap the covariates of `InferenceSurvivalKKStratCoxPHOneLik` and
  `InferenceSurvivalKKLWACoxPHOneLik` (plan range 5-8, harness rows and MC truth alike), with a capped-truth convergence
  check before they leave `COVERAGE_TRUTH_UNAVAILABLE` (G4-C runbook R7). Firth for matched Cox:
  `release_v1_1_0.md → TODO-69`. Document the ionosphere PropBeta/FractionalLogit high-p/n under-coverage as a
  limitation, with no SE correction. The recommendation named no target population; under the cap the truth keeps the
  harness's finite empirical rows (agent's reading). 2026-10-22, owner via G6 #19 (final-audit recommendation).
- **Why:** No reason recorded.
- **Rejected:** Firth for 1.0.5; an SE correction for the ionosphere classes.

<a id="DECISION-v1.0.5-TODO-10b"></a>
### DECISION-v1.0.5-TODO-10b: Keep the first-K = 6 cap rule, and accept the R7 convergence thresholds?

- **TODO:** [v1.0.5-TODO-10](release_v1_0_5.md): **MC coverage-truth uses the wrong covariate set**
- **Question:** closing audit 2026-10-23 ("NEEDS-DECISION (owner)", no agent work left; both answers needed before R7
  runs): (1) keep the cap rule "the first K = 6 columns of the dataset's X, in dataset column order" for 1.0.5? (2) accept
  R7's agent-proposed convergence thresholds?
- **Options on the table:** (1) keep (coordinator recommends keep), or a principled selection such as the top-K by
  variance or by marginal association, which changes the harness and the truth cache key; (2) accept: at mc_n = 12000,
  every pairwise difference <= 2 combined MC SEs, and every 6000 -> 12000 move < 1 SE; or set others.
- **Ruling:** (1) KEEP the first-K = 6 cap rule for 1.0.5 (no principled selection; harness and truth cache key
  unchanged); (2) ACCEPT the R7 thresholds (all estimates within 2 combined MC SEs across both schemes and seeds at
  mc_n = 12000; every 6000 -> 12000 move < 1 MC SE), now owner-approved (runbook R7, G6 #19). 2026-10-23, owner via
  closing-audit decision 2. #19 fully decided.
- **Why:** No reason recorded beyond the coordinator's recommendation.
- **Rejected:** a principled top-K selection.

<a id="DECISION-v1.0.5-TODO-8"></a>
### DECISION-v1.0.5-TODO-8: The stereotype-logit 400-seed null calibration cannot be replayed: rerun, or close on the old numbers?

- **TODO:** [v1.0.5-TODO-8](release_v1_0_5.md): **Stereotype-logit multimodal likelihood**
- **Question:** G6 #32: the plan TODO-4 calibration cannot be replayed (386/400 historical vs 224/400 current denominator
  unreconciled).
- **Options on the table:** (a) approve a fresh provenance-pinned rerun (n = 100 and n = 50, per-seed status/error
  stage/elapsed) on the G1 build under the #20 rule; (b) close on the 2026-10-14 numbers. Recommended (a), folded into
  #20.
- **Ruling:** (a), a fresh provenance-pinned 400-seed null rerun (n = 100 K = 5, n = 50 K = 3) on the G1 build under the
  #20 Clopper-Pearson rule (G4-C runbook R2). 2026-10-22, owner via G6 #32 (with #20).
- **Why:** the historical denominator is unreconciled. No further reason recorded.
- **Rejected:** (b).

<a id="DECISION-v1.0.5-TODO-6"></a>
### DECISION-v1.0.5-TODO-6: Approve a replacement replay protocol for the Clayton/loggamma optimizer fix, or close on existing evidence?

- **TODO:** [v1.0.5-TODO-6](release_v1_0_5.md): **`InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik` optimizer
  stability**
- **Question:** G6 #6: approve a replacement protocol and numeric runtime/estimate/SE/Bartlett criteria (the original
  inputs are gone), or close.
- **Options on the table:** (a) close on the existing evidence; (b) approve a replacement protocol with explicit
  criteria for both formulas.
- **Ruling:** (a), close on the existing evidence; the replay/criteria gate is dropped; the separate `~.` stall (>5:24 in
  the generic Bartlett p-value path) moves to TODO-126. 2026-10-22, owner via G6 #6.
- **Why:** the historical inputs can never be replayed. Evidence accepted: the root cause (no dependence-parameter cap;
  gradient inconsistent with the clipped objective) is fixed in `fast_survival_models_optim.cpp`; the golden censored
  outputs and native boundary fit in `test-clayton-logtheta-optimizer-bound.R` pass (22 expectations) on the user-rebuilt
  package; the filtered `~1` probe took 0.36-0.38 s per approximate Bartlett p-value versus the historical 159.7-178.7 s.
- **Rejected:** (b).

<a id="DECISION-v1.0.5-TODO-5"></a>
### DECISION-v1.0.5-TODO-5: Cox-family randomization CI on the wrong scale: refuse, or fix the scale?

- **TODO:** [v1.0.5-TODO-5](release_v1_0_5.md): **Randomization CI construction audit**
- **Question:** §A: the Cox-family classes run the generic randomization-CI driver, which shifts responses on the
  log-time (AFT) scale but seeds, brackets and reports on the log-hazard-ratio scale (on a Weibull DGP with true log HR
  −1.6 the Cox rand CI came back [−1.702, −1.264] with the lower bound equal to the estimate).
  (`randomization_ci_construction_audit.md → TODO-1`, listed as v1.1.0 Phase 0 item 12.)
- **Options on the table:** option 1, refuse (like the stratified class); others in the plan.
- **Ruling:** option 1, refuse: the six log-HR classes are listed in `EDI_LOG_HAZARD_RATIO_INFERENCE_CLASSES`, excluded
  from the `randomization_ci` capability and refused with an explanation on a direct call; randomization p-value and
  randomization-bootstrap CI untouched. 2026-09-06, owner (recorded as "user decision"), implemented the same day.
- **Why:** No reason recorded.

<a id="DECISION-v1.0.5-TODO-4a"></a>
### DECISION-v1.0.5-TODO-4a: Apply C++ patch 07 (ZINB pseudo-inverse)?

- **TODO:** [v1.0.5-TODO-4](release_v1_0_5.md): **Guard the unguarded information-matrix inverses**
- **Question:** G6 #26: patch 07 (ZINB pseudo-inverse; the 1e-6 null-loading threshold is a judgment call and vcov goes
  all-NaN -> partly finite): apply?
- **Options on the table:** apply only with the B07/B07b companions and a review of the TODO-4 guard tests (recommended);
  apply alone; do not apply.
- **Ruling:** apply 07 only together with B07/B07b, and only after a review of the TODO-4 guard tests. Apply order:
  `../bug_fix_plans/v1_0_5/cpp_patches_v105/README.md → Owner-approved for G1`, step 1. 2026-10-22, owner via G6 #26.
- **Why:** No reason recorded.

<a id="DECISION-v1.0.5-TODO-4b"></a>
### DECISION-v1.0.5-TODO-4b: Close the guard before/after sub-item on existing captures, or require the exhaustive matrix?

- **TODO:** [v1.0.5-TODO-4](release_v1_0_5.md): **Guard the unguarded information-matrix inverses**
- **Question:** closing audit 2026-10-23 ("NEEDS-DECISION (owner)") on the sub-item "Run linked-plan TODO-3's
  before/after comparison ...". The linked plan's TODO-1..6 boxes are all checked; its notes record paired
  pre-guard/current captures for Beta (synthetic and readingskills), NegBin (quine and canonical GLM), hurdle
  (salamanders and a synthetic GLMM), and the ZAP/ZINB Bartlett replays, each saying "the remaining paired matrix is
  open". No tracked runner exists (the drivers are only in volatile `/tmp/edi-todo4-*.R`); the "before" side needs a
  pre-guard DLL, i.e. building an older checkout, which is the user's job, never an agent's.
- **Options on the table:** (a) close on the existing paired captures plus the G1 step-1/step-8 guard tests
  (recommended); (b) require the exhaustive matrix: an agent promotes the `/tmp` drivers into
  `R/package_tests/calibration/` and the user builds a pre-guard reference library. Either way, patches 01 + 07 (with
  B07/B07b) still close at G1.
- **Ruling:** (a), close on the existing paired pre-guard/current captures (Beta, NegBin, hurdle, ZAP/ZINB Bartlett
  replays) plus the G1 guard tests (runbook step 2 (a) and (f)); no exhaustive before/after matrix; the drivers are not
  promoted and no pre-guard library is built. 2026-10-23, owner via closing-audit decision 4.
- **Why:** No reason recorded beyond the recommendation.
- **Rejected:** (b).

<a id="DECISION-v1.0.5-TODO-3a"></a>
### DECISION-v1.0.5-TODO-3a: Delete the eight unused native exports, or keep them for 1.0.5?

- **TODO:** [v1.0.5-TODO-3](release_v1_0_5.md): **Wire the unused OLS randomization-distribution kernel; triage dead
  kernels**
- **Question:** G6 #3 (TODO-3a): eight unused exports (`compute_wilcox_distr_parallel_cpp`,
  `compute_wilcox_distr_from_list_parallel_cpp`, `base_bootstrap_loop_cpp`, `matching_bootstrap_loop_cpp`,
  `fill_i_b_with_matches_loop_cpp`, `bisection_ci_parallel_cpp`, `bisection_ci_single_bound_cpp`,
  `bisection_ci_loop_cpp`).
- **Options on the table:** (a) delete (touches Rcpp registration, unity grouping, Rd, tests); (b) keep for 1.0.5 and file
  a v1.1.0 TODO. Recommended (b).
- **Ruling:** (a), delete: seven kernels deleted, `bisection_ci_parallel_cpp` kept as a compatibility shim (itself
  deleted 2026-10-28, DECISION-v1.0.5-TODO-3c). 2026-10-22, owner via G6 #3 (against the recommendation).
- **Why:** No reason recorded.
- **Rejected:** (b).

<a id="DECISION-v1.0.5-TODO-3b"></a>
### DECISION-v1.0.5-TODO-3b: Build the Lin randomization kernel now, or defer?

- **TODO:** [v1.0.5-TODO-3](release_v1_0_5.md): **Wire the unused OLS randomization-distribution kernel; triage dead
  kernels**
- **Question:** G6 #4 (TODO-3b / TODO-6 stretch).
- **Options on the table:** build now; defer (recommended).
- **Ruling:** deferred to v1.1.0 (`release_v1_1_0.md → TODO-57`); closed for 1.0.5. 2026-10-22, owner via G6 #4.
- **Why:** No reason recorded.
- **Rejected:** building it in 1.0.5.

<a id="DECISION-v1.0.5-TODO-3c"></a>
### DECISION-v1.0.5-TODO-3c: Delete the kept `bisection_ci_parallel_cpp` compatibility shim too?

- **TODO:** [v1.0.5-TODO-3](release_v1_0_5.md): **Wire the unused OLS randomization-distribution kernel; triage dead
  kernels**
- **Question:** after G6 #3, `bisection_ci_parallel_cpp` was kept as a shim; delete it?
- **Ruling:** delete the kept shim. 2026-10-28, owner.
- **Why:** re-checked dead in production: no R caller outside the generated `RcppExports.R`, no `NAMESPACE` export, no
  Python binding, and `edi::bisection_ci_search` was reachable only through it (the live randomization CI search is the R
  code). Consequence recorded: the tail/discontinuity/validation assertions that pinned that search are gone, so nothing
  in the suite now pins a C++ bisection.
- **Rejected:** keeping the shim.

<a id="DECISION-v1.0.5-TODO-2a"></a>
### DECISION-v1.0.5-TODO-2a: Accept the measured affine-reuse speedups, or keep the 20-30x target?

- **TODO:** [v1.0.5-TODO-2](release_v1_0_5.md): **Randomization CI affine-shift reuse**
- **Question:** G6 #2: measured affine-reuse speedups are 1.1-2.1x (1.05-2.14x OLS, 1.13-1.59x average difference) vs
  the projected 20-30x.
- **Options on the table:** (a) accept and restate as workload-specific; (b) keep 20-30x and authorize more optimization
  (then a G2 re-time). Recommended (a).
- **Ruling:** (a), accept and restate; TODO-2 closed. 2026-10-22, owner via G6 #2.
- **Why:** the 20–30× figure was a projection of avoided distribution work, not a runtime ratio; the measured
  end-to-end speedups (1.1–1.6× average difference, 1.05–2.14× OLS) are accepted as workload-specific. The plan's TODO-8
  was always out of TODO-2's scope (DECISION-v1.0.5-TODO-2b).
- **Rejected:** (b).

<a id="DECISION-v1.0.5-TODO-2b"></a>
### DECISION-v1.0.5-TODO-2b: Adopt, defer or drop direct order-statistic inversion (affine-shift plan TODO-8)?

- **TODO:** [v1.0.5-TODO-2](release_v1_0_5.md): **Randomization CI affine-shift reuse**
- **Question:** G6 #31: plan `randomization_ci_affine_shift_reuse.md` TODO-8 (direct order-statistic inversion,
  "decision-gated, optional"); the owner asked about it but had not decided.
- **Options on the table:** (a) adopt in 1.0.5; (b) defer to v1.1.0; (c) drop. It buys exactness, not wall time, and
  moves CI endpoints (a default change). Recommended (b).
- **Ruling:** (b), defer: `release_v1_1_0.md → TODO-62`. 2026-10-22, owner via G6 #31.
- **Why:** it buys exactness, not wall time, and moves CI endpoints (the recommendation's reason).
- **Rejected:** (a), (c).

<a id="DECISION-v1.0.5-TODO-1a"></a>
### DECISION-v1.0.5-TODO-1a: The reusable ZOIB jackknife is slower: optimize the retry chain, or accept the unmet target?

- **TODO:** [v1.0.5-TODO-1](release_v1_0_5.md): **Reusable-bootstrap-worker support for
  `InferencePropZeroOneInflatedBetaRegr`**
- **Question:** G6 #1: the reusable ZOIB jackknife is slower on the diagnosed fixture.
- **Options on the table:** (a) optimize the retry chain, then re-time; (b) accept the unmet target, document, keep the
  legacy route for tuning. Recommended (b).
- **Ruling:** (a); implemented the same day (native calls 68 -> 60 = legacy). 2026-10-22, owner via G6 #1 (against the
  recommendation).
- **Why:** No reason recorded.
- **Rejected:** (b).

<a id="DECISION-v1.0.5-TODO-1b"></a>
### DECISION-v1.0.5-TODO-1b: Remove the ZOIB `jackknife` tuning exclusion now, or wait for a non-NA fixture?

- **TODO:** [v1.0.5-TODO-1](release_v1_0_5.md): **Reusable-bootstrap-worker support for
  `InferencePropZeroOneInflatedBetaRegr`**
- **Question:** G6 #30: remove the ZOIB `jackknife` entry from `EDI_TUNING_WARM_START_OPERATION_EXCLUSIONS`
  (`local_machine_tuning_axes.R` ~L261, a one-line R edit, plan TODO-5) now, or keep it until a non-NA exact tuning
  fixture exists?
- **Options on the table:** (a) remove now (recommended); (b) keep until a non-NA exact tuning fixture exists.
- **Ruling:** (a), remove now (agent, one R line); the plan TODO-6 tuning run is G2. 2026-10-22, owner via G6 #30.
- **Why:** call counts now equal legacy and the NA of the exact tuning fixture is the documented contract on both routes.
- **Rejected:** (b).

<a id="DECISION-v1.0.5-TODO-1c"></a>
### DECISION-v1.0.5-TODO-1c: Finish `reusable_bootstrap.md` TODO-2 and TODO-3, or waive them for v1.0.5?

- **TODO:** [v1.0.5-TODO-1](release_v1_0_5.md): **Reusable-bootstrap-worker support for
  `InferencePropZeroOneInflatedBetaRegr`**
- **Question:** the linked plan still had TODO-2 (frozen-colnames invariant; open because it is not universal across
  formulas and designs) and TODO-3 (target "low hundreds of ms for 50 folds", last measured 5.84 s) open: finish them or
  record an owner waiver.
- **Ruling:** waive TODO-2 and TODO-3 for v1.0.5. The TODO-3 speed target ("low hundreds of ms" for 50 folds; now 5.84 s
  vs 7.85 s legacy) moves to `release_v1_1_0.md` TODO-191. 2026-11-10, owner.
- **Why:** for TODO-2, "the invariant holds on every tested fixture; no proof for every formula and design needed".
- **Rejected:** finishing them in v1.0.5.

<a id="DECISION-v1.0.5-TODO-1d"></a>
### DECISION-v1.0.5-TODO-1d: Does "completed, default kept" meet plan TODO-6's "a real (not excluded) policy diff"?

- **TODO:** [v1.0.5-TODO-1](release_v1_0_5.md): **Reusable-bootstrap-worker support for
  `InferencePropZeroOneInflatedBetaRegr`**
- **Question:** the G2 tuning run (2026-11-10) completed the ZOIB jackknife axis (not excluded) but kept the shipped
  default, i.e. no policy diff, and per-cell pace was not recorded; plan TODO-6 asks for "a real (not excluded) policy
  diff". Accept "completed, default kept" as meeting it, and move a realistic proportion fixture (noise, plus 0/1 mass for
  ZOIB) on?
- **Options on the table:** (a) accept TODO-6 as met (axis completes, decisive verdict) and move the fixture; (b) not.
- **Ruling:** (a): "completed, default kept" meets plan TODO-6 (ticked in `reusable_bootstrap.md`); TODO-1 CLOSED. The
  realistic proportion fixture moves to `release_v1_0_6.md` TODO-11 (first filed as `release_v1_1_0.md` TODO-192).
  2026-11-10, owner.
- **Why:** the direct A/B (2026-11-10, 5 interleaved reps, quiet host) showed the shipped warm-start setting wins
  decisively: median time ON vs OFF n = 50 5.12 vs 5.17 s (tie), n = 200 0.76 vs 10.6 s, n = 1000 13.0 vs 248 s, so "no
  diff" is a decisive verdict, not a skipped cell. Caveat recorded: the tuning fixture is noiseless for proportion
  responses, so the 14-19x ratios are likely inflated and the zero/one submodel is never exercised; this applies to every
  proportion class the tuner times.
- **Rejected:** (b).

## Owner rulings outside TODOs

Rulings recorded as sections of the repo's `CLAUDE.md` (pointers only; the text lives there):

- 2026-08-17 (owner): never run a full `R CMD INSTALL` / package rebuild of EDI without being asked in that turn
  (`CLAUDE.md`, "NEVER run a full `R CMD INSTALL` / package rebuild on EDI").
- 2026-11-07 (owner): the benchmark utility wrapper compile (`Rcpp::sourceCpp("benchmark/fast_math_utils_bench.cpp")`)
  is whitelisted (same section, "Whitelisted (owner, 2026-11-07)").
- 2026-11-10 (owner): the native C++ test suite in `cpp_tests/` may be built by agents within limits (same section,
  "Whitelisted (owner, 2026-11-10)").
- Agents compile with `EDI_UNITY=0`; the owner's default build is unity (`CLAUDE.md`, "Agents compile with
  `EDI_UNITY=0`; the user's default build is unity").
- 2026-10-25 (owner): `.trail/` is never committed in this public repo (`CLAUDE.md`, "Trail learnings stay local").
- 2026-11-07 (owner): test file names never carry a TODO number (`CLAUDE.md`, "Test file names never carry a TODO
  number").
- TODOs are always cited with their release, `v1.0.6-TODO-30` (`CLAUDE.md`, "Always cite a TODO with its release").
- 2026-11-19 (owner): ignore the four stuck "queued" Actions runs of 2026-11-11 (`CLAUDE.md`, "Ignore the four stuck
  "queued" Actions runs from 2026-11-11").
- 2026-11-19 (owner): one source of truth for the version, `R/EDI/DESCRIPTION` + `scripts/sync_version.py`
  (`CLAUDE.md`, "One source of truth for the version").
- 2026-11-21 (owner): owner decisions live in `PENDING_DECISIONS.md` / `COMPLETED_DECISIONS.md` (`CLAUDE.md`, "Owner
  decisions: `PENDING_DECISIONS.md`, `COMPLETED_DECISIONS.md` and `DISMISSED_DECISIONS.md`").
- 2026-11-22 (owner): dismissed audit ids (`rd-d<hex>` / `rd-m<hex>`) go in
  `R/package_metadata/audits/DISMISSED_DECISIONS.md`, named in the same `CLAUDE.md` section ("Dismissed").
