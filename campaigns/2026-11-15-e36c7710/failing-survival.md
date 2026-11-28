[← Campaign 2026-11-15-e36c7710 summary](README.md)

# Failing cells: survival

38 failing survival cell(s) (provisional: confirmation pending or running).

| response | design | class | procedure | formula | n | n_eff | order (basis) | size | coverage | finite | accepted | note |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| survival | Fixed:Greedy | SurvivalCoxPHRegr | rand | ~. | 1000 | 1000 (proxy) | Inf (theory) | 0.073 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| survival | Fixed:GreedyDOptimal | SurvivalCoxPHRegr | rand | ~. | 1000 | 1000 (proxy) | Inf (theory) | 0.073 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| survival | Fixed:Greedy@0.2 | SurvivalDepCensTransformRegr | score | ~. | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.073 **FAIL** (level 0.05, rate check) | 0.927 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| survival | Fixed:GreedyDOptimal@0.2 | SurvivalDepCensTransformRegr | score | ~. | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.073 **FAIL** (level 0.05, rate check) | 0.927 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| survival | SeqOneByOne:KK14 | SurvivalGLMMWeibullFrailtyLoggammaOneLik | gradient | ~1 | 1000 | 1000 (proxy) | unknown | 0.08 **FAIL** (level 0.0525, unknown) | 0.92 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| survival | SeqOneByOne:KK14 | SurvivalGLMMWeibullFrailtyLoggammaOneLik | lik_ratio | ~1 | 1000 | 1000 (proxy) | unknown | 0.08 **FAIL** (level 0.0525, unknown) | 0.92 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| survival | SeqOneByOne:KK14 | SurvivalGLMMWeibullFrailtyLoggammaOneLik | score | ~. | 50 | 50 (proxy) | unknown | 0.148 **FAIL** (level 0.1, unknown) | 0.851 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| survival | SeqOneByOne:KK21 | SurvivalGLMMWeibullFrailtyLoggammaOneLik | score | ~. | 50 | 50 (proxy) | unknown | 0.145 **FAIL** (level 0.1, unknown) | 0.852 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| survival | SeqOneByOne:KK21stepwise | SurvivalGLMMWeibullFrailtyLoggammaOneLik | score | ~. | 50 | 50 (proxy) | unknown | 0.137 **FAIL** (level 0.1, unknown) | 0.858 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| survival | Fixed:BinaryMatch | SurvivalGLMMWeibullFrailtyLoggammaOneLik | score | ~1 | 50 | 50 (proxy) | unknown | 0.136 **FAIL** (level 0.1, unknown) | 0.864 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| survival | SeqOneByOne:KK14 | SurvivalGLMMWeibullFrailtyLoggammaOneLik | score | ~1 | 50 | 50 (proxy) | unknown | 0.164 **FAIL** (level 0.1, unknown) | 0.839 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| survival | SeqOneByOne:KK21 | SurvivalGLMMWeibullFrailtyLoggammaOneLik | score | ~1 | 50 | 50 (proxy) | unknown | 0.145 **FAIL** (level 0.1, unknown) | 0.856 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| survival | SeqOneByOne:KK21stepwise | SurvivalGLMMWeibullFrailtyLoggammaOneLik | score | ~1 | 50 | 50 (proxy) | unknown | 0.149 **FAIL** (level 0.1, unknown) | 0.851 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| survival | SeqOneByOne:KK14 | SurvivalGLMMWeibullFrailtyLoggammaOneLik | score | ~1 | 1000 | 1000 (proxy) | unknown | 0.083 **FAIL** (level 0.0525, unknown) | 0.917 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| survival | SeqOneByOne:KK21 | SurvivalGLMMWeibullFrailtyLoggammaOneLik | score | ~1 | 1000 | 1000 (proxy) | unknown | 0.079 **FAIL** (level 0.0525, unknown) | 0.921 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| survival | SeqOneByOne:KK14 | SurvivalGLMMWeibullFrailtyLoggammaOneLik | wald | ~1 | 1000 | 1000 (proxy) | unknown | 0.081 **FAIL** (level 0.0525, unknown) | 0.919 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| survival | SeqOneByOne:KK21stepwise | SurvivalKKStratCoxPHOneLik | gradient | ~. | 50 | 50 (proxy) | 1 (assumed_default) | 0.146 **FAIL** (level 0.1, cap) | 0.886 (level 0.9, cap) | 1000/1000 |  |  |
| survival | Fixed:Rerandomization@0.2 | SurvivalRestrictedMeanDiff | rand | ~. | 50 | 50 | Inf (theory) | 0.073 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| survival | Fixed:Rerandomization@0.2 | SurvivalRestrictedMeanDiff | rand | ~1 | 50 | 50 | Inf (theory) | 0.073 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| survival | Fixed:Bernoulli | SurvivalWeibullRegr | gradient | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.081 (level 0.05, rate check) | 0.918 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| survival | Fixed:iBCRD | SurvivalWeibullRegr | gradient | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.079 **FAIL** (level 0.05, rate check) | 0.921 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| survival | Fixed:Rerandomization | SurvivalWeibullRegr | gradient | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.082 **FAIL** (level 0.05, rate check) | 0.918 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| survival | Fixed:Rerandomization@0.2 | SurvivalWeibullRegr | gradient | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.08 **FAIL** (level 0.05, rate check) | 0.92 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| survival | Fixed:iBCRD | SurvivalWeibullRegr | lik_ratio | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.079 **FAIL** (level 0.05, rate check) | 0.921 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| survival | Fixed:Rerandomization | SurvivalWeibullRegr | lik_ratio | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.082 **FAIL** (level 0.05, rate check) | 0.918 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| survival | Fixed:Rerandomization@0.2 | SurvivalWeibullRegr | lik_ratio | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.08 **FAIL** (level 0.05, rate check) | 0.92 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| survival | Fixed:iBCRD | SurvivalWeibullRegr | rand | ~1 | 50 | 50 (proxy) | Inf (theory) | 0.073 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| survival | Fixed:Rerandomization | SurvivalWeibullRegr | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.094 **FAIL** (level 0.0625, rate) | 0.904 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| survival | Fixed:Bernoulli | SurvivalWeibullRegr | score | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.081 **FAIL** (level 0.05, rate check) | 0.918 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| survival | Fixed:iBCRD | SurvivalWeibullRegr | score | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.08 **FAIL** (level 0.05, rate check) | 0.92 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| survival | Fixed:iBCRD@0.2 | SurvivalWeibullRegr | score | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.074 **FAIL** (level 0.05, rate check) | 0.926 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| survival | Fixed:Rerandomization | SurvivalWeibullRegr | score | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.083 **FAIL** (level 0.05, rate check) | 0.917 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| survival | Fixed:Rerandomization@0.2 | SurvivalWeibullRegr | score | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.08 **FAIL** (level 0.05, rate check) | 0.919 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| survival | SeqOneByOne:Bernoulli | SurvivalWeibullRegr | score | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.073 **FAIL** (level 0.05, rate check) | 0.926 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| survival | Fixed:Bernoulli | SurvivalWeibullRegr | wald | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.081 **FAIL** (level 0.05, rate check) | 0.919 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| survival | Fixed:iBCRD | SurvivalWeibullRegr | wald | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.08 **FAIL** (level 0.05, rate check) | 0.92 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| survival | Fixed:Rerandomization | SurvivalWeibullRegr | wald | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.082 **FAIL** (level 0.05, rate check) | 0.918 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| survival | Fixed:Rerandomization@0.2 | SurvivalWeibullRegr | wald | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.077 **FAIL** (level 0.05, rate check) | 0.923 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |

[← Campaign 2026-11-15-e36c7710 summary](README.md)
