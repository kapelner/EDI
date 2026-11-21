# Summary: save-load (EDI 1.0.4, first run on this area)

## What I set out to do
A careful applied statistician running a sequential trial across several months and machines wants five things:
1. a restored design continues *exactly* as an unsaved one would, given the same seed;
2. the trial file carries everything needed (seed, responses, KK21 weight history, version);
3. the restored design rejects or flags operator errors (duplicate enrollment, changed covariate types);
4. the final analysis on the restored design is the same as on an unsaved one, and is correct against a reference;
5. clear rules for whether inference objects can be saved.

## What I finished
- **Core scenario (`analysis.R`).** KK21 trial, continuous outcome, n = 50, p = 3 covariates, seed 7041. Outcomes arrive 3 to 8 enrollments late. Machine A is a fresh `Rscript`: it creates the design, enrolls 30 subjects, and saves the trial file atomically (temp file + rename, as in the article). The file holds the design, an audit log, the covariate classes, the versions and a fingerprint of the allocation rule. Machine B is another fresh `Rscript` with a different `set.seed`: it restores the file, enrolls up to 50 and records all outcomes. Compared with an uninterrupted in-memory run, the assignments, responses, pairs and KK21 iteration weights are all `identical()`. A replay from the audit log reproduces every assignment.
  - Final analysis (`InferenceContinKKOLSOneLik`): estimate 1.0330, 95% asymptotic CI [0.4301, 1.6359], asymptotic p = 0.0015, randomization p = 0.012 (r = 499, inference seed 1), randomization CI [0.2817, 1.7921]. The true effect is 0.7. The CIs contain the estimate and the p-values are in [0, 1].
  - Cross-check: `InferenceContinOLS` against `lm(y ~ w + covariates)` gives estimate 0.936061, CI [0.413026, 1.4591], p = 0.000778716. The largest absolute difference is 4e-16.
- **Every sequential class, fresh-session save at t = 30 and resume to 50** (`multi.R`): Bernoulli (prob_T = 0.4), iBCRD (prob_T = 0.4), RandomBlockSize (strata, block_sizes 2/4/6), SPBR (2 strata columns), Efron, Urn (alpha 1, beta 3), Atkinson, PocockSimon, KK14, KK21, and KK21stepwise (seed passed through `...`; its usage shows no `seed`). Each was run with `seed = 11` and with `seed = NULL` plus a saved/restored `.Random.seed`. All 22 combinations continue identically to an uninterrupted run.
- **Save options.** `saveRDS(version = 2)` and the default version 3 give identical continuations. Resuming under `set_num_cores(1)` after saving under 2 cores gives the same result.
- **Other documented promises after a restore.** Seeded assignment and `draw_ws_according_to_design()` leave the caller's `.Random.seed` untouched (KK21, PocockSimon, Atkinson, Efron). Redraws are the same before and after a restore. A mid-trial redraw does not change later assignments. The version stamp survives the restore ("1.0.4"). The overwrite warning text matches the article.
- **Other restored designs.** `n = NULL` (KK14, KK21) and missing covariate values (KK14, KK21) resume identically. A survival KK14 trial with right censoring (`y_L`, `y_R = Inf`) survives the restore: `get_y_L()`/`get_y_R()` are kept, and `InferenceSurvivalCoxPHRegr` matches `survival::coxph` exactly (0.8854268, CI [0.1235383, 1.647315], p = 0.02274044).
- **Inference objects saved with `saveRDS`** (the docs say never to do this). A restored inference object reproduces its estimate, CI, asymptotic p, randomization p, randomization CI and `delta` p-value exactly, including methods never called before saving. `clear_randomization_cache()`, `set_seed()` and `num_cores` work on it. It is a frozen snapshot: a response corrected on the design saved next to it is not reflected (1.0330 stays, while a fresh object gives the new value). I checked that the same holds in memory: an inference object snapshots the design when it is built. This is consistent and documented, so I did not log it as a finding.
- **A design saved after responses and after a randomization test** (its permutation cache travels with it). A fresh inference object on the restored design gives an identical randomization p. On an `n = NULL` design, an interim randomization p at t = 30, then save/restore, then enrollment to 50, gives the same final p before and after `clear_randomization_cache()`, so the cache is not stale.

## New findings (see findings.md)
- **F1:** the bootstrap error on KK designs names the whole "DesignSeqOneByOne" family, which also includes designs where it works. The KK help page lists the bootstrap as a method.
- **F2:** `clone(deep = TRUE)` of an SPBR, RandomBlockSize or PocockSimon design shares the per-stratum state with the original. The original's later assignments change, and SPBR's blocks break.
- **F3:** a covariate value that arrives as text after a restore rewrites the column for all earlier subjects. The final analysis then returns `NA` without a warning.
- **F4:** the version stamp "1.0.4" sits on a build whose seeding the docs attribute to "v1.0.6", so the stamp is misleading for an audit trail.
- **F5:** subject n + 1 is accepted silently; `check_experiment_completed()` is `TRUE` and the analysis uses n + 1 subjects.

## What I could not do, and why
- **Major-version mismatch warning on reload.** I could not test it: only one EDI version is installed, and the stored stamp is private (changing it would need internals).
- **Bootstrap CI/p on the KK21 trial.** Not available (F1). I used the randomization CI instead.
- **Old-code-in-object risk.** R6 objects serialize their method closures, so a design restored under a newer EDI may run the *saved* methods. I could not check this with one installed version. The docs do not say which code a restored object runs.
- **Cross-checking `InferenceContinKKOLSOneLik`'s estimate.** No standard package fits the KK one-likelihood combined estimator. I cross-checked OLS (`lm`) and Cox (`survival::coxph`) instead.

## Where I had to guess
- I read "save the design as the docs say" as `saveRDS(des, file, version = 2)` (the `?Design` recommendation), wrapped in the article's temp-file-plus-rename. I also checked that version 3 works.
- With `seed = NULL`, an "unsaved" run means the same `set.seed(42)` at the start of both runs plus `.Random.seed` saved next to the design, as `vignette("reproducibility")` shows. Without saving `.Random.seed`, continuations differ, as documented (my first, unfair, comparison).
- Urn `alpha = 0` is rejected. The help says alpha > 0, so this is not a finding; I used alpha = 1, beta = 3.
- KK21stepwise shows no `seed` in its usage. I passed it through `...`, and it was honoured.
- F2 is about `clone()`, which is not `saveRDS`. I included it because a deep clone is the in-memory form of a trial checkpoint, and it disagrees with what `saveRDS` copies do.

## Known findings re-checked
None: `known_findings.md` lists no earlier findings for this area (first run).
