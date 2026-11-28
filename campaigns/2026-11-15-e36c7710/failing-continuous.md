[← Campaign 2026-11-15-e36c7710 summary](README.md)

# Failing cells: continuous

3 failing continuous cell(s) (provisional: confirmation pending or running).

| response | design | class | procedure | formula | n | n_eff | order (basis) | size | coverage | finite | accepted | note |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| continuous | Fixed:Bernoulli@0.2 | ContinLin | wald | ~. | 50 | 10 | 1 (assumed_default) | 0.17 **FAIL** (level 0.1, cap) | 0.83 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| continuous | SeqOneByOne:Bernoulli@0.2 | ContinLin | wald | ~. | 50 | 10 | 1 (assumed_default) | 0.192 **FAIL** (level 0.1, cap) | 0.808 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| continuous | Fixed:Blocking@0.2 | ContinQuantileRegr | wald | ~. | 1000 | 200 | 0.667 (literature) | 0.073 **FAIL** (level 0.05, rate check) | 0.927 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |

[← Campaign 2026-11-15-e36c7710 summary](README.md)
