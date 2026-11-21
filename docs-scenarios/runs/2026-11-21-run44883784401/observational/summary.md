# Summary: observational / existing-experiment analysis (EDI 1.0.4 as installed)

## What I set out to do
Act as an analyst who receives finished data (assignment already made) and wants a defensible estimate, CI and p-value, with a randomization-based p-value where the design allows it. The aims were to:
1. load each data set the way the docs and the article "Analyzing an Experiment You Already Ran" describe (`assign_w_to_all_subjects(w_precomputed = )`);
2. pick the design class matching the real assignment law;
3. cross-check every number against base R / `sandwich` / hand-coded permutation tests;
4. check which procedures EDI allows when it did not make the assignment.

## What I finished (all in `analysis.R`, all simulated with base R and fixed seeds)
- **A. Confounded observational study, `ObservationalDesign`, n = 150.**
  - OLS estimate, CI and p-value equal `lm()` to all printed digits (2.3566, [1.5518, 3.1613], 4.24e-08).
  - Jackknife SE equals a hand-coded delete-1 jackknife (0.42476).
  - Lin estimator equals `lm(y ~ w * centered X)` with the HC2 SE and a t quantile (0.4381 vs 0.4418 recovered from the CI; that difference is just the t vs normal quantile).
  - Welch mean difference equals `t.test()` exactly.
  - Bootstrap and Bayesian-bootstrap CIs run.
  - Randomization test and CI refuse with a clear message, as documented.
  - `get_procedure_validity()` and `InferenceSuite` correctly leave out randomization procedures. `Inference$capabilities()` does not (F2).
- **B. Stratified trial, 4 sites of unequal size (8/12/20/30), `DesignFixedBlocking`.**
  - Tried `equal_block_sizes = FALSE`, an explicit `m` (with no site column in X), and numeric site codes.
  - Redraws reproduce the per-site treated counts.
  - OLS equals `lm()` exactly.
  - The randomization p-value of the mean difference agrees with a hand-coded within-site permutation test (0.005 vs 0.0025 at r = 2000 / 4000, and 0.14 vs 0.153 on another data set). The OLS randomization CI is consistent with its p-value.
  - I also re-ran the article's own four-site example: estimate 1.962, Wald CI [0.436, 3.489], randomization p = 0.016.
- **C. Matched pairs with known pairs, `DesignFixedBinaryMatch(m = pair)`.**
  - Redraws keep one treated per pair.
  - The randomization p-value (0.004, r = 999) agrees with the exact sign-flip test (0.0026, all 2^15 flips).
  - `InferenceContinKKOLSOneLik` equals `lm(y ~ w + x + factor(pair))` in estimate and SE. The CI uses z, not t, so the limits differ in the 2nd digit at 13 df.
- **D. Binary outcome, `ObservationalDesign`, `InferenceIncidLogRegr`.**
  - Agrees with `glm(binomial)` to about 5 digits: Wald, profile-LR CI and LR p-value.
- **Bernoulli existing trial (`DesignFixedBernoulli`, coin 0.5, 20/40 treated).** Redraws vary the number treated. The randomization p-value of 0.174 agrees with a hand-coded Bernoulli re-randomization (0.1705).
- **`DesignFixediBCRD` with the wrong `prob_T`.** It is accepted silently and redraws treat 40 instead of the observed 30. The article documents this, so it is not a finding.
- **Missingness options on `ObservationalDesign`.**
  - `"drop_column"` drops the column.
  - `"error"` does not stop at `add_all_subjects_to_experiment()`; it stops at the first `get_X()` or inference call, with a clear message. That works, but it is later than the article implies.
- **Bad treatment vectors.** I tried 1/2 coding, factor, logical, character, 0.5, NA, wrong length and all-zero on 3 design classes, which produced F5–F8.
- **`InferenceSuite` on the observational design.** I ran all methods and also restricted the methods; that is how F3 and F12 turned up.

## New findings (details in findings.md)
F1 `n = NULL` fails · F2 capabilities list randomization on an observational design · F3 parallel suite gives silent NA p-values ("ignoring SIGPIPE signal") · F4 help points to unshipped internal docs · F5 all-zero `w` gives a covariate slope as the treatment effect · F6 non-0/1 `w` accepted · F7 wrong-length `w` recycled · F8 `NA` in `w` gives an internal `qr` error · F9 matched-pair `w` not checked against `m` · F10 `equal_block_sizes` error timing contradicts both help and article · F11 article's BCa-NA claim is false · F12 CMH listed as applicable to an observational design but its Wald p-value needs redraws.

## What I could not do / why
- I did not test the survival path (`veteran` + Cox) on `ObservationalDesign`, and `InferenceSuite` with `compute_conf_intervals = TRUE` over all classes. I ran out of time; the article already covers the `veteran` example with iBCRD.
- I did not test `DesignFixedBlockedCluster` / `DesignFixedCluster` with an existing assignment.
- `coin::symmetry_test` errored on my one-sample formula (my misuse), so I replaced it with an exact enumeration. All cross-check packages I needed (`sandwich`, `survival`, `coin`) were installed.

## Places I had to guess
- I took `InferenceSuite`'s `num_cores = 2L` together with the global `set_num_cores(2)` to stay within "2 cores". That combination triggers F3, so the final script uses `num_cores = 1L` in the suite.
- I judged the "Bayesian bootstrap" and nonparametric bootstrap as valid on an observational design because `?ObservationalDesign` says so. I did not verify their calibration.
- For F6, I assumed the {0,1} wording in `?DesignFixed` is a contract, not a suggestion. `overwrite_all_subject_assignments()` does enforce it.
- Installed version is 1.0.4 (`packageVersion`, `get_edi_version_created()`), yet help pages describe behaviour "changed in 1.0.5" and "before EDI 1.0.6". I treated the docs as current. Anyone relying on `get_edi_version_created()` for reproducibility may be misled. I did not file this as a separate finding.

## Known findings re-checked
None: `known_findings.md` lists no earlier findings for this area (first run).
