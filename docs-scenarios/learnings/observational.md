# Learnings: observational

Appended by each weekly docs-only scenario run.

## Run 2026-11-21 (run 44883784401, 8d8c5f78, ok)

## Covered
- `ObservationalDesign` (continuous and incidence): OLS, Lin, mean diff, logit (Wald and LR) matched `lm` / `glm` / `t.test` / `sandwich` HC2. Jackknife matched a hand delete-1 jackknife. Bootstrap and Bayesian bootstrap ran. Randomization test and CI refuse cleanly.
- `get_procedure_validity()`, `applicable_inference_class_names()`, `incompatible_inference_classes_due_to_design_structure()`, `supports_randomization_draw()` / `supports_resampling()` / `supports_resampling_replay()`, `capabilities()`, all on an observational design.
- `DesignFixedBlocking` with unequal strata: `equal_block_sizes` TRUE and FALSE, explicit `m` with no stratum column, numeric site codes. Randomization p-value checked against a hand within-block permutation test.
- `DesignFixedBinaryMatch(m = )` with an existing pairing: randomization p-value vs exact sign-flip enumeration; `InferenceContinKKOLSOneLik` vs `lm` with pair fixed effects.
- `DesignFixedBernoulli` randomization p-value vs a hand Bernoulli re-randomization; `DesignFixediBCRD` with the wrong `prob_T`.
- Bad `w_precomputed` inputs: 1/2, factor, logical, character, 0.5, NA, wrong length, all-zero.
- `missingness_method` `"error"` and `"drop_column"` on `ObservationalDesign`.
- `InferenceSuite` on `ObservationalDesign`: `methods = NULL`, a methods list with types, `num_cores` 1 vs 2, `B`, `r`.

## Not reached
- Survival (Cox, censoring) and ordinal/count outcomes on `ObservationalDesign`.
- `DesignFixedCluster` / `DesignFixedBlockedCluster` with an existing assignment and cluster IDs.
- `overwrite_all_subject_assignments()` used after `assign_w_to_all_subjects()` and before responses: does it reset caches and blocks?
- Blocking with different allocation ratios per stratum (e.g. 2:1 at one site), and `B_target` / `exact_num_blocks` with existing data.
- `model_formula` with a factor stratum on a blocked existing trial vs `lm` with fixed effects; `set_estimand()` on observational data.
- An all-one `w`, and `w` with a single treated subject.

## Workarounds
- Always pass `n = nrow(X)`: `n = NULL` fails at `add_all_subjects_to_experiment()`.
- Validate `w` yourself before loading: integer 0/1, no NA, right length, both arms present, one treated per pair for matched designs. EDI does not do this.
- `InferenceSuite$run_all_inference()` needs `screen = TRUE` or `html = TRUE`; wrap it in `capture.output()` to keep it quiet. Use `num_cores = 1L` when `set_num_cores(2)` is on (F3).
- `html = TRUE` with `output_dir = tempdir()` in `Rscript` produces "xdg-open: file ... does not exist", because the temp dir is gone before the browser opens.
- Wrong bootstrap type names (e.g. `"basic"` for p-values) error with the list of valid types; use `get_supported_bootstrap_pval_types()`.

## Confusing docs
- `?Design` / `?ObservationalDesign`: long paragraphs about internal migrations (`fix_design_hierarchy.md`, TODO numbers, `draw_ws_raw()` stubs) bury the user-relevant rule of which procedures are valid without a randomization law.
- The article's BCa paragraph (needs ≥ 5 sites) conflicts with `?InferenceJackknife` (auto unit on `DesignFixedBlocking` = subject).
- `equal_block_sizes` error timing: the help says at add time, the article says at the first use including inference fits; in practice it fires at bootstrap/randomization only.
- `missingness_method = "error"`: the article says it "stops so that nothing is changed silently", but the stop comes at `get_X()` or inference, not when the data are added.
- Installed version reports 1.0.4 while the help text refers to 1.0.5 / 1.0.6 changes.
