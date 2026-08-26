# Cluster-Robust Model-Based Inference: CR-SE Component and Random-Cluster GLMM / GEE

> **Depends on:** `longitudinal_repeated_measures_response_type_report.md`
> Stage 1 (extraction of the clustered-fit core from the `KKGEE` / `KKGLMM`
> components — the same refactor this plan needs), the cluster-design
> classes (shipped), and `cluster_level_covariate_balancing_designs.md`
> (the design-side half). **Release target: v2.0.0**
> (`release_v2_0_0.md → TODO-2a`) because it generalizes the pair-specific
> GLMM/GEE component architecture rather than adding to it.

Written 2026-08-27. Owning plan for
`missing_inference_classes_literature_audit.md` item **#2** (Part 4A) and
theoretical-audit item **#29** (site random effects).

## Why

`DesignFixedCluster` / `BlockedCluster` exist and randomization / bootstrap
inference resample at the cluster level, but there is no model-based
cluster-robust SE and the GLMM / GEE components are KK-pair-specific.
Practice: random-cluster-intercept GLMM in 52% of cluster trials and GEE
in 16% (Fiero 2016); HLM is near-universal in IES education CRTs; cluster-
robust OLS SEs are the second rule of econometric field experiments;
small-cluster corrections (CR2/CR3, Satterthwaite df) are the recognized
gap (Kahan et al.).

## Proposal

- **`ClusterRobust` SE component** — CR0/CR1/CR2/CR3 sandwich with
  Satterthwaite / Bell-McCaffrey df, attachable to OLS, LPM, logistic,
  Poisson/NB, Cox (Lin-Wei), proportional odds; cluster ids from the
  design's `ClusterStructure`; wild-cluster bootstrap (Rademacher /
  Webb) as a `bootstrap_type` for few clusters.
- **`InferenceContinClusterGLMM` / `InferenceIncidClusterGLMM` /
  `InferenceCountClusterGLMM` / `InferenceOrdinalClusterGLMM`** — random-
  cluster-intercept mixed models on the generalized `GLMM` component
  (Gauss-Hermite / Laplace; `glmmTMB` fallback), with site as an
  alternative clustering (random-effects multi-site meta-analysis).
- **`Inference*ClusterGEE`** — exchangeable / independence working
  correlation on the generalized `GEE` component with small-sample
  corrections (Mancl-DeRouen, Kauermann-Carroll).
- Registry: `requires_cluster_design`; `run_all_inference()` offers these
  only on cluster designs.

## Tests

Parity vs `sandwich::vcovCL` + `clubSandwich` (CR2), `lme4::glmer` /
`glmmTMB`, `geepack::geeglm` with `geesmv` corrections; KK GLMM/GEE golden
tests unchanged after the component extraction; simulation coverage with
few clusters.

## TODOs

- [ ] TODO-1: Scoping detail after the longitudinal Stage 1 extraction
  lands — confirm the generalized `GLMM` / `GEE` component API.
- [ ] TODO-2: `ClusterRobust` component (CR0–CR3, df corrections, wild
  cluster bootstrap) on the regression classes.
- [ ] TODO-3: Cluster GLMM classes (continuous first, then incidence /
  count / ordinal).
- [ ] TODO-4: Cluster GEE classes with small-sample corrections.
- [ ] TODO-5: registry gating, `SimulationFramework` cluster-ICC generator,
  vignette.
