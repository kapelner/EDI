[← Campaign 2026-11-09-8c32d060 summary](README.md)

# Failing cells: count

222 failing count cell(s) (provisional: confirmation pending or running).

| response | design | class | procedure | formula | n | n_eff | order (basis) | size | coverage | finite | accepted | note |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| count | Bernoulli | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.166 **FAIL** (level 0.1, cap) | 0.834 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Bernoulli@0.2 | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.168 **FAIL** (level 0.1, cap) | 0.833 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Blocking | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.158 **FAIL** (level 0.1, cap) | 0.842 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | iBCRD | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.164 **FAIL** (level 0.1, cap) | 0.836 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | OptimalBlocks | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.142 **FAIL** (level 0.1, cap) | 0.858 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Rerandomization | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.184 **FAIL** (level 0.1, cap) | 0.816 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Bernoulli | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.168 **FAIL** (level 0.1, cap) | 0.832 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Efron | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.166 **FAIL** (level 0.1, cap) | 0.834 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | iBCRD | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.188 **FAIL** (level 0.1, cap) | 0.812 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | KK14 | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.144 **FAIL** (level 0.1, cap) | 0.856 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | PocockSimon | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.151 **FAIL** (level 0.1, cap) | 0.849 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | RandomBlockSize | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.173 **FAIL** (level 0.1, cap) | 0.827 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | SPBR | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.17 **FAIL** (level 0.1, cap) | 0.83 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Urn | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.163 **FAIL** (level 0.1, cap) | 0.837 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Bernoulli | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.165 **FAIL** (level 0.1, cap) | 0.835 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Bernoulli@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.166 **FAIL** (level 0.1, cap) | 0.835 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Blocking | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.157 **FAIL** (level 0.1, cap) | 0.843 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | iBCRD | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.163 **FAIL** (level 0.1, cap) | 0.837 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | OptimalBlocks | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.141 **FAIL** (level 0.1, cap) | 0.859 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Rerandomization | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.182 **FAIL** (level 0.1, cap) | 0.818 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Bernoulli | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.166 **FAIL** (level 0.1, cap) | 0.834 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Efron | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.165 **FAIL** (level 0.1, cap) | 0.835 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | iBCRD | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.185 **FAIL** (level 0.1, cap) | 0.815 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | KK14 | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.142 **FAIL** (level 0.1, cap) | 0.858 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | PocockSimon | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.15 **FAIL** (level 0.1, cap) | 0.85 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | RandomBlockSize | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.17 **FAIL** (level 0.1, cap) | 0.83 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | SPBR | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.169 **FAIL** (level 0.1, cap) | 0.831 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Urn | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.162 **FAIL** (level 0.1, cap) | 0.838 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Bernoulli | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.163 **FAIL** (level 0.1, cap) | 0.837 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Bernoulli@0.2 | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.153 **FAIL** (level 0.1, cap) | 0.848 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Blocking | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.156 **FAIL** (level 0.1, cap) | 0.844 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | iBCRD | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.162 **FAIL** (level 0.1, cap) | 0.838 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | OptimalBlocks | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.141 **FAIL** (level 0.1, cap) | 0.859 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Rerandomization | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.179 **FAIL** (level 0.1, cap) | 0.821 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Bernoulli | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.165 **FAIL** (level 0.1, cap) | 0.835 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Efron | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.165 **FAIL** (level 0.1, cap) | 0.835 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | iBCRD | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.183 **FAIL** (level 0.1, cap) | 0.817 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | KK14 | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.142 **FAIL** (level 0.1, cap) | 0.858 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | PocockSimon | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.15 **FAIL** (level 0.1, cap) | 0.85 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | RandomBlockSize | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.168 **FAIL** (level 0.1, cap) | 0.832 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | SPBR | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.167 **FAIL** (level 0.1, cap) | 0.833 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Urn | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.157 **FAIL** (level 0.1, cap) | 0.843 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Bernoulli | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.157 **FAIL** (level 0.1, unknown) | 0.86 **FAIL** (level 0.9, unknown) | 971/1000 |  | rate unknown: open a TODO to establish it |
| count | Bernoulli@0.2 | CountZeroInflatedNegBin | gradient | ~. | 50 | 10 | unknown | 0.144 **FAIL** (level 0.1, unknown) | 0.865 **FAIL** (level 0.9, unknown) | 971/1000 |  | rate unknown: open a TODO to establish it |
| count | BinaryMatch | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.154 **FAIL** (level 0.1, unknown) | 0.849 **FAIL** (level 0.9, unknown) | 968/1000 |  | rate unknown: open a TODO to establish it |
| count | Blocking | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.155 **FAIL** (level 0.1, unknown) | 0.848 **FAIL** (level 0.9, unknown) | 964/1000 |  | rate unknown: open a TODO to establish it |
| count | Greedy | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.155 **FAIL** (level 0.1, unknown) | 0.856 **FAIL** (level 0.9, unknown) | 968/1000 |  | rate unknown: open a TODO to establish it |
| count | GreedyDOptimal | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.155 **FAIL** (level 0.1, unknown) | 0.856 **FAIL** (level 0.9, unknown) | 968/1000 |  | rate unknown: open a TODO to establish it |
| count | iBCRD | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.144 **FAIL** (level 0.1, unknown) | 0.862 **FAIL** (level 0.9, unknown) | 967/1000 |  | rate unknown: open a TODO to establish it |
| count | Optimal | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.145 **FAIL** (level 0.1, unknown) | 0.867 **FAIL** (level 0.9, unknown) | 971/1000 |  | rate unknown: open a TODO to establish it |
| count | OptimalBlocks | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.158 **FAIL** (level 0.1, unknown) | 0.854 **FAIL** (level 0.9, unknown) | 947/1000 |  | rate unknown: open a TODO to establish it |
| count | Rerandomization | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.153 **FAIL** (level 0.1, unknown) | 0.854 **FAIL** (level 0.9, unknown) | 972/1000 |  | rate unknown: open a TODO to establish it |
| count | Atkinson | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.154 **FAIL** (level 0.1, unknown) | 0.858 **FAIL** (level 0.9, unknown) | 962/1000 |  | rate unknown: open a TODO to establish it |
| count | Bernoulli | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.155 **FAIL** (level 0.1, unknown) | 0.849 **FAIL** (level 0.9, unknown) | 968/1000 |  | rate unknown: open a TODO to establish it |
| count | Efron | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.157 **FAIL** (level 0.1, unknown) | 0.851 **FAIL** (level 0.9, unknown) | 967/1000 |  | rate unknown: open a TODO to establish it |
| count | iBCRD | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.14 **FAIL** (level 0.1, unknown) | 0.872 (level 0.9, unknown) | 971/1000 |  | rate unknown: open a TODO to establish it |
| count | KK14 | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.135 **FAIL** (level 0.1, unknown) | 0.87 (level 0.9, unknown) | 970/1000 |  | rate unknown: open a TODO to establish it |
| count | KK21 | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.135 **FAIL** (level 0.1, unknown) | 0.869 **FAIL** (level 0.9, unknown) | 962/1000 |  | rate unknown: open a TODO to establish it |
| count | KK21stepwise | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.163 **FAIL** (level 0.1, unknown) | 0.848 **FAIL** (level 0.9, unknown) | 975/1000 |  | rate unknown: open a TODO to establish it |
| count | RandomBlockSize | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.139 **FAIL** (level 0.1, unknown) | 0.858 **FAIL** (level 0.9, unknown) | 970/1000 |  | rate unknown: open a TODO to establish it |
| count | SPBR | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.14 **FAIL** (level 0.1, unknown) | 0.871 (level 0.9, unknown) | 966/1000 |  | rate unknown: open a TODO to establish it |
| count | Urn | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.135 **FAIL** (level 0.1, unknown) | 0.867 **FAIL** (level 0.9, unknown) | 961/1000 |  | rate unknown: open a TODO to establish it |
| count | MatchingGreedyPairSwitching | CountZeroInflatedNegBin | gradient | ~. | 52 | 50 | unknown | 0.146 **FAIL** (level 0.1, unknown) | 0.859 **FAIL** (level 0.9, unknown) | 977/1000 |  | rate unknown: open a TODO to establish it |
| count | Bernoulli | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 50 | unknown | 0.149 **FAIL** (level 0.1, unknown) | 0.878 (level 0.9, unknown) | 971/1000 |  | rate unknown: open a TODO to establish it |
| count | Bernoulli@0.2 | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 10 | unknown | 0.139 **FAIL** (level 0.1, unknown) | 0.878 (level 0.9, unknown) | 971/1000 |  | rate unknown: open a TODO to establish it |
| count | BinaryMatch | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 50 | unknown | 0.154 **FAIL** (level 0.1, unknown) | 0.871 (level 0.9, unknown) | 968/1000 |  | rate unknown: open a TODO to establish it |
| count | Blocking | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 50 | unknown | 0.143 **FAIL** (level 0.1, unknown) | 0.872 (level 0.9, unknown) | 964/1000 |  | rate unknown: open a TODO to establish it |
| count | Greedy | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 50 | unknown | 0.143 **FAIL** (level 0.1, unknown) | 0.881 (level 0.9, unknown) | 968/1000 |  | rate unknown: open a TODO to establish it |
| count | GreedyDOptimal | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 50 | unknown | 0.143 **FAIL** (level 0.1, unknown) | 0.881 (level 0.9, unknown) | 968/1000 |  | rate unknown: open a TODO to establish it |
| count | iBCRD | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 50 | unknown | 0.143 **FAIL** (level 0.1, unknown) | 0.879 (level 0.9, unknown) | 967/1000 |  | rate unknown: open a TODO to establish it |
| count | Optimal | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 50 | unknown | 0.141 **FAIL** (level 0.1, unknown) | 0.876 (level 0.9, unknown) | 971/1000 |  | rate unknown: open a TODO to establish it |
| count | OptimalBlocks | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 50 | unknown | 0.154 **FAIL** (level 0.1, unknown) | 0.866 **FAIL** (level 0.9, unknown) | 947/1000 |  | rate unknown: open a TODO to establish it |
| count | Rerandomization | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 50 | unknown | 0.154 **FAIL** (level 0.1, unknown) | 0.87 (level 0.9, unknown) | 972/1000 |  | rate unknown: open a TODO to establish it |
| count | Atkinson | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 50 | unknown | 0.146 **FAIL** (level 0.1, unknown) | 0.874 (level 0.9, unknown) | 962/1000 |  | rate unknown: open a TODO to establish it |
| count | Bernoulli | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 50 | unknown | 0.154 **FAIL** (level 0.1, unknown) | 0.86 **FAIL** (level 0.9, unknown) | 968/1000 |  | rate unknown: open a TODO to establish it |
| count | Efron | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 50 | unknown | 0.149 **FAIL** (level 0.1, unknown) | 0.86 **FAIL** (level 0.9, unknown) | 967/1000 |  | rate unknown: open a TODO to establish it |
| count | iBCRD | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 50 | unknown | 0.14 **FAIL** (level 0.1, unknown) | 0.884 (level 0.9, unknown) | 971/1000 |  | rate unknown: open a TODO to establish it |
| count | KK21 | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 50 | unknown | 0.135 **FAIL** (level 0.1, unknown) | 0.885 (level 0.9, unknown) | 962/1000 |  | rate unknown: open a TODO to establish it |
| count | KK21stepwise | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 50 | unknown | 0.158 **FAIL** (level 0.1, unknown) | 0.859 **FAIL** (level 0.9, unknown) | 975/1000 |  | rate unknown: open a TODO to establish it |
| count | RandomBlockSize | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 50 | unknown | 0.139 **FAIL** (level 0.1, unknown) | 0.878 (level 0.9, unknown) | 970/1000 |  | rate unknown: open a TODO to establish it |
| count | MatchingGreedyPairSwitching | CountZeroInflatedNegBin | lik_ratio | ~. | 52 | 50 | unknown | 0.131 **FAIL** (level 0.1, unknown) | 0.884 (level 0.9, unknown) | 977/1000 |  | rate unknown: open a TODO to establish it |
| count | Bernoulli | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.095 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 968/1000 |  |  |
| count | Bernoulli@0.2 | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.0962 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 967/1000 |  |  |
| count | BinaryMatch | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.0848 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 967/1000 |  |  |
| count | Blocking | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.0948 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 960/1000 |  |  |
| count | Greedy | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.0916 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 961/1000 |  |  |
| count | GreedyDOptimal | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.0916 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 961/1000 |  |  |
| count | iBCRD | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.0912 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 965/1000 |  |  |
| count | OptimalBlocks | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.0944 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 943/1000 |  |  |
| count | Rerandomization | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.0972 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 967/1000 |  |  |
| count | Atkinson | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.0962 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 956/1000 |  |  |
| count | Bernoulli | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.0933 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 965/1000 |  |  |
| count | Efron | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.102 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 962/1000 |  |  |
| count | iBCRD | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.0814 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 970/1000 |  |  |
| count | KK21 | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.0865 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 959/1000 |  |  |
| count | KK21stepwise | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.0976 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 973/1000 |  |  |
| count | RandomBlockSize | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.101 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 966/1000 |  |  |
| count | SPBR | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.0924 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 963/1000 |  |  |
| count | Urn | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.0784 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 957/1000 |  |  |
| count | MatchingGreedyPairSwitching | CountZeroInflatedNegBin | rand | ~. | 52 | 50 | Inf (theory) | 0.086 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 977/1000 |  |  |
| count | Bernoulli@0.2 | CountZeroInflatedNegBin | rand | ~1 | 50 | 50 | Inf (theory) | 0.076 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Blocking | CountZeroInflatedNegBin | rand | ~1 | 50 | 50 | Inf (theory) | 0.078 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Greedy | CountZeroInflatedNegBin | rand | ~1 | 50 | 50 | Inf (theory) | 0.073 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | GreedyDOptimal | CountZeroInflatedNegBin | rand | ~1 | 50 | 50 | Inf (theory) | 0.073 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | OptimalBlocks | CountZeroInflatedNegBin | rand | ~1 | 50 | 50 | Inf (theory) | 0.076 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Atkinson | CountZeroInflatedNegBin | rand | ~1 | 50 | 50 | Inf (theory) | 0.079 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Efron | CountZeroInflatedNegBin | rand | ~1 | 50 | 50 | Inf (theory) | 0.076 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | RandomBlockSize | CountZeroInflatedNegBin | rand | ~1 | 50 | 50 | Inf (theory) | 0.078 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | SPBR | CountZeroInflatedNegBin | rand | ~1 | 50 | 50 | Inf (theory) | 0.078 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | MatchingGreedyPairSwitching | CountZeroInflatedNegBin | rand | ~1 | 52 | 50 | Inf (theory) | 0.074 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Bernoulli | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.205 **FAIL** (level 0.1, unknown) | 0.805 **FAIL** (level 0.9, unknown) | 971/1000 |  | rate unknown: open a TODO to establish it |
| count | Bernoulli@0.2 | CountZeroInflatedNegBin | score | ~. | 50 | 10 | unknown | 0.19 **FAIL** (level 0.1, unknown) | 0.824 **FAIL** (level 0.9, unknown) | 970/1000 |  | rate unknown: open a TODO to establish it |
| count | BinaryMatch | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.221 **FAIL** (level 0.1, unknown) | 0.801 **FAIL** (level 0.9, unknown) | 968/1000 |  | rate unknown: open a TODO to establish it |
| count | Blocking | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.216 **FAIL** (level 0.1, unknown) | 0.797 **FAIL** (level 0.9, unknown) | 964/1000 |  | rate unknown: open a TODO to establish it |
| count | Greedy | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.206 **FAIL** (level 0.1, unknown) | 0.805 **FAIL** (level 0.9, unknown) | 968/1000 |  | rate unknown: open a TODO to establish it |
| count | GreedyDOptimal | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.206 **FAIL** (level 0.1, unknown) | 0.805 **FAIL** (level 0.9, unknown) | 968/1000 |  | rate unknown: open a TODO to establish it |
| count | iBCRD | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.202 **FAIL** (level 0.1, unknown) | 0.815 **FAIL** (level 0.9, unknown) | 967/1000 |  | rate unknown: open a TODO to establish it |
| count | Optimal | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.208 **FAIL** (level 0.1, unknown) | 0.811 **FAIL** (level 0.9, unknown) | 971/1000 |  | rate unknown: open a TODO to establish it |
| count | OptimalBlocks | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.212 **FAIL** (level 0.1, unknown) | 0.797 **FAIL** (level 0.9, unknown) | 947/1000 |  | rate unknown: open a TODO to establish it |
| count | Rerandomization | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.224 **FAIL** (level 0.1, unknown) | 0.792 **FAIL** (level 0.9, unknown) | 972/1000 |  | rate unknown: open a TODO to establish it |
| count | Atkinson | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.229 **FAIL** (level 0.1, unknown) | 0.787 **FAIL** (level 0.9, unknown) | 962/1000 |  | rate unknown: open a TODO to establish it |
| count | Bernoulli | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.22 **FAIL** (level 0.1, unknown) | 0.792 **FAIL** (level 0.9, unknown) | 968/1000 |  | rate unknown: open a TODO to establish it |
| count | Efron | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.207 **FAIL** (level 0.1, unknown) | 0.809 **FAIL** (level 0.9, unknown) | 967/1000 |  | rate unknown: open a TODO to establish it |
| count | iBCRD | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.205 **FAIL** (level 0.1, unknown) | 0.801 **FAIL** (level 0.9, unknown) | 971/1000 |  | rate unknown: open a TODO to establish it |
| count | KK14 | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.19 **FAIL** (level 0.1, unknown) | 0.822 **FAIL** (level 0.9, unknown) | 970/1000 |  | rate unknown: open a TODO to establish it |
| count | KK21 | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.196 **FAIL** (level 0.1, unknown) | 0.821 **FAIL** (level 0.9, unknown) | 962/1000 |  | rate unknown: open a TODO to establish it |
| count | KK21stepwise | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.213 **FAIL** (level 0.1, unknown) | 0.798 **FAIL** (level 0.9, unknown) | 975/1000 |  | rate unknown: open a TODO to establish it |
| count | PocockSimon | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.183 **FAIL** (level 0.1, unknown) | 0.831 **FAIL** (level 0.9, unknown) | 973/1000 |  | rate unknown: open a TODO to establish it |
| count | RandomBlockSize | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.227 **FAIL** (level 0.1, unknown) | 0.806 **FAIL** (level 0.9, unknown) | 970/1000 |  | rate unknown: open a TODO to establish it |
| count | SPBR | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.199 **FAIL** (level 0.1, unknown) | 0.817 **FAIL** (level 0.9, unknown) | 966/1000 |  | rate unknown: open a TODO to establish it |
| count | Urn | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.186 **FAIL** (level 0.1, unknown) | 0.824 **FAIL** (level 0.9, unknown) | 961/1000 |  | rate unknown: open a TODO to establish it |
| count | MatchingGreedyPairSwitching | CountZeroInflatedNegBin | score | ~. | 52 | 50 | unknown | 0.199 **FAIL** (level 0.1, unknown) | 0.817 **FAIL** (level 0.9, unknown) | 977/1000 |  | rate unknown: open a TODO to establish it |
| count | Bernoulli | CountZeroInflatedNegBin | score | ~1 | 50 | 50 | unknown | 0.134 **FAIL** (level 0.1, unknown) | 0.869 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Bernoulli@0.2 | CountZeroInflatedNegBin | score | ~1 | 50 | 10 | unknown | 0.134 **FAIL** (level 0.1, unknown) | 0.863 **FAIL** (level 0.9, unknown) | 998/1000 |  | rate unknown: open a TODO to establish it |
| count | Blocking | CountZeroInflatedNegBin | score | ~1 | 50 | 50 | unknown | 0.135 **FAIL** (level 0.1, unknown) | 0.863 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Rerandomization | CountZeroInflatedNegBin | score | ~1 | 50 | 50 | unknown | 0.149 **FAIL** (level 0.1, unknown) | 0.853 **FAIL** (level 0.9, unknown) | 999/1000 |  | rate unknown: open a TODO to establish it |
| count | Bernoulli | CountZeroInflatedNegBin | score | ~1 | 50 | 50 | unknown | 0.137 **FAIL** (level 0.1, unknown) | 0.869 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Efron | CountZeroInflatedNegBin | score | ~1 | 50 | 50 | unknown | 0.136 **FAIL** (level 0.1, unknown) | 0.862 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | iBCRD | CountZeroInflatedNegBin | score | ~1 | 50 | 50 | unknown | 0.131 **FAIL** (level 0.1, unknown) | 0.871 (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | PocockSimon | CountZeroInflatedNegBin | score | ~1 | 50 | 50 | unknown | 0.127 (level 0.1, unknown) | 0.869 **FAIL** (level 0.9, unknown) | 999/1000 |  | rate unknown: open a TODO to establish it |
| count | RandomBlockSize | CountZeroInflatedNegBin | score | ~1 | 50 | 50 | unknown | 0.146 **FAIL** (level 0.1, unknown) | 0.857 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SPBR | CountZeroInflatedNegBin | score | ~1 | 50 | 50 | unknown | 0.13 **FAIL** (level 0.1, unknown) | 0.868 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Bernoulli | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.182 **FAIL** (level 0.1, unknown) | 0.818 **FAIL** (level 0.9, unknown) | 959/1000 |  | rate unknown: open a TODO to establish it |
| count | Bernoulli@0.2 | CountZeroInflatedNegBin | wald | ~. | 50 | 10 | unknown | 0.164 **FAIL** (level 0.1, unknown) | 0.836 **FAIL** (level 0.9, unknown) | 965/1000 |  | rate unknown: open a TODO to establish it |
| count | BinaryMatch | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.179 **FAIL** (level 0.1, unknown) | 0.821 **FAIL** (level 0.9, unknown) | 961/1000 |  | rate unknown: open a TODO to establish it |
| count | Blocking | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.18 **FAIL** (level 0.1, unknown) | 0.82 **FAIL** (level 0.9, unknown) | 953/1000 |  | rate unknown: open a TODO to establish it |
| count | Greedy | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.187 **FAIL** (level 0.1, unknown) | 0.813 **FAIL** (level 0.9, unknown) | 954/1000 |  | rate unknown: open a TODO to establish it |
| count | GreedyDOptimal | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.187 **FAIL** (level 0.1, unknown) | 0.813 **FAIL** (level 0.9, unknown) | 954/1000 |  | rate unknown: open a TODO to establish it |
| count | iBCRD | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.165 **FAIL** (level 0.1, unknown) | 0.835 **FAIL** (level 0.9, unknown) | 958/1000 |  | rate unknown: open a TODO to establish it |
| count | Optimal | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.175 **FAIL** (level 0.1, unknown) | 0.825 **FAIL** (level 0.9, unknown) | 965/1000 |  | rate unknown: open a TODO to establish it |
| count | OptimalBlocks | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.193 **FAIL** (level 0.1, unknown) | 0.807 **FAIL** (level 0.9, unknown) | 940/1000 |  | rate unknown: open a TODO to establish it |
| count | Rerandomization | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.195 **FAIL** (level 0.1, unknown) | 0.805 **FAIL** (level 0.9, unknown) | 964/1000 |  | rate unknown: open a TODO to establish it |
| count | Atkinson | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.189 **FAIL** (level 0.1, unknown) | 0.811 **FAIL** (level 0.9, unknown) | 952/1000 |  | rate unknown: open a TODO to establish it |
| count | Bernoulli | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.185 **FAIL** (level 0.1, unknown) | 0.815 **FAIL** (level 0.9, unknown) | 960/1000 |  | rate unknown: open a TODO to establish it |
| count | Efron | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.182 **FAIL** (level 0.1, unknown) | 0.818 **FAIL** (level 0.9, unknown) | 948/1000 |  | rate unknown: open a TODO to establish it |
| count | iBCRD | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.175 **FAIL** (level 0.1, unknown) | 0.825 **FAIL** (level 0.9, unknown) | 966/1000 |  | rate unknown: open a TODO to establish it |
| count | KK14 | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.156 **FAIL** (level 0.1, unknown) | 0.844 **FAIL** (level 0.9, unknown) | 959/1000 |  | rate unknown: open a TODO to establish it |
| count | KK21 | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.168 **FAIL** (level 0.1, unknown) | 0.832 **FAIL** (level 0.9, unknown) | 956/1000 |  | rate unknown: open a TODO to establish it |
| count | KK21stepwise | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.188 **FAIL** (level 0.1, unknown) | 0.812 **FAIL** (level 0.9, unknown) | 967/1000 |  | rate unknown: open a TODO to establish it |
| count | PocockSimon | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.153 **FAIL** (level 0.1, unknown) | 0.847 **FAIL** (level 0.9, unknown) | 960/1000 |  | rate unknown: open a TODO to establish it |
| count | RandomBlockSize | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.174 **FAIL** (level 0.1, unknown) | 0.826 **FAIL** (level 0.9, unknown) | 956/1000 |  | rate unknown: open a TODO to establish it |
| count | SPBR | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.171 **FAIL** (level 0.1, unknown) | 0.829 **FAIL** (level 0.9, unknown) | 954/1000 |  | rate unknown: open a TODO to establish it |
| count | Urn | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.167 **FAIL** (level 0.1, unknown) | 0.833 **FAIL** (level 0.9, unknown) | 951/1000 |  | rate unknown: open a TODO to establish it |
| count | MatchingGreedyPairSwitching | CountZeroInflatedNegBin | wald | ~. | 52 | 50 | unknown | 0.166 **FAIL** (level 0.1, unknown) | 0.834 **FAIL** (level 0.9, unknown) | 968/1000 |  | rate unknown: open a TODO to establish it |
| count | Bernoulli | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | 0.166 **FAIL** (level 0.1, unknown) | 0.834 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Bernoulli@0.2 | CountZeroInflatedPoisson | gradient | ~1 | 50 | 10 | unknown | 0.173 **FAIL** (level 0.1, unknown) | 0.827 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Blocking | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | 0.155 **FAIL** (level 0.1, unknown) | 0.845 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | iBCRD | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | 0.169 **FAIL** (level 0.1, unknown) | 0.831 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | OptimalBlocks | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | 0.17 **FAIL** (level 0.1, unknown) | 0.83 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Rerandomization | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | 0.165 **FAIL** (level 0.1, unknown) | 0.835 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Atkinson | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | 0.147 **FAIL** (level 0.1, unknown) | 0.853 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Bernoulli | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | 0.163 **FAIL** (level 0.1, unknown) | 0.837 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Efron | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | 0.161 **FAIL** (level 0.1, unknown) | 0.839 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | iBCRD | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | 0.182 **FAIL** (level 0.1, unknown) | 0.818 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | KK14 | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | 0.158 **FAIL** (level 0.1, unknown) | 0.842 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | KK21stepwise | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | 0.143 **FAIL** (level 0.1, unknown) | 0.857 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | PocockSimon | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | 0.157 **FAIL** (level 0.1, unknown) | 0.843 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | RandomBlockSize | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | 0.145 **FAIL** (level 0.1, unknown) | 0.856 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SPBR | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | 0.163 **FAIL** (level 0.1, unknown) | 0.837 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Urn | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | 0.168 **FAIL** (level 0.1, unknown) | 0.832 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Bernoulli | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | 0.162 **FAIL** (level 0.1, unknown) | 0.838 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Bernoulli@0.2 | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 10 | unknown | 0.164 **FAIL** (level 0.1, unknown) | 0.836 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Blocking | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | 0.154 **FAIL** (level 0.1, unknown) | 0.846 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | iBCRD | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | 0.165 **FAIL** (level 0.1, unknown) | 0.835 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | OptimalBlocks | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | 0.166 **FAIL** (level 0.1, unknown) | 0.834 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Rerandomization | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | 0.163 **FAIL** (level 0.1, unknown) | 0.837 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Atkinson | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | 0.144 **FAIL** (level 0.1, unknown) | 0.856 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Bernoulli | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | 0.161 **FAIL** (level 0.1, unknown) | 0.839 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Efron | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | 0.161 **FAIL** (level 0.1, unknown) | 0.839 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | iBCRD | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | 0.18 **FAIL** (level 0.1, unknown) | 0.82 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | KK14 | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | 0.155 **FAIL** (level 0.1, unknown) | 0.845 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | KK21stepwise | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | 0.139 **FAIL** (level 0.1, unknown) | 0.861 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | PocockSimon | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | 0.155 **FAIL** (level 0.1, unknown) | 0.845 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | RandomBlockSize | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | 0.143 **FAIL** (level 0.1, unknown) | 0.857 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SPBR | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | 0.161 **FAIL** (level 0.1, unknown) | 0.839 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Urn | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | 0.165 **FAIL** (level 0.1, unknown) | 0.835 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | KK14 | CountZeroInflatedPoisson | rand | ~. | 50 | 50 | Inf (theory) | 0.078 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Bernoulli@0.2 | CountZeroInflatedPoisson | rand | ~1 | 50 | 50 | Inf (theory) | 0.168 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | OptimalBlocks | CountZeroInflatedPoisson | rand | ~1 | 50 | 50 | Inf (theory) | 0.075 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Atkinson | CountZeroInflatedPoisson | rand | ~1 | 50 | 50 | Inf (theory) | 0.073 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | KK14 | CountZeroInflatedPoisson | rand | ~1 | 50 | 50 | Inf (theory) | 0.08 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Bernoulli | CountZeroInflatedPoisson | score | ~. | 50 | 50 | unknown | 0.137 **FAIL** (level 0.1, unknown) | 0.887 (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | KK14 | CountZeroInflatedPoisson | score | ~. | 50 | 50 | unknown | 0.132 **FAIL** (level 0.1, unknown) | 0.88 (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | RandomBlockSize | CountZeroInflatedPoisson | score | ~. | 50 | 50 | unknown | 0.131 **FAIL** (level 0.1, unknown) | 0.884 (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Bernoulli | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | 0.156 **FAIL** (level 0.1, unknown) | 0.844 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Bernoulli@0.2 | CountZeroInflatedPoisson | score | ~1 | 50 | 10 | unknown | 0.169 **FAIL** (level 0.1, unknown) | 0.831 **FAIL** (level 0.9, unknown) | 998/1000 |  | rate unknown: open a TODO to establish it |
| count | Blocking | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | 0.149 **FAIL** (level 0.1, unknown) | 0.851 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | iBCRD | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | 0.162 **FAIL** (level 0.1, unknown) | 0.838 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | OptimalBlocks | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | 0.163 **FAIL** (level 0.1, unknown) | 0.837 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Rerandomization | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | 0.16 **FAIL** (level 0.1, unknown) | 0.84 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Atkinson | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | 0.139 **FAIL** (level 0.1, unknown) | 0.861 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Bernoulli | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | 0.154 **FAIL** (level 0.1, unknown) | 0.846 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Efron | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | 0.162 **FAIL** (level 0.1, unknown) | 0.838 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | iBCRD | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | 0.178 **FAIL** (level 0.1, unknown) | 0.822 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | KK14 | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | 0.151 **FAIL** (level 0.1, unknown) | 0.849 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | KK21stepwise | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | 0.136 **FAIL** (level 0.1, unknown) | 0.864 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | PocockSimon | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | 0.153 **FAIL** (level 0.1, unknown) | 0.847 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | RandomBlockSize | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | 0.137 **FAIL** (level 0.1, unknown) | 0.863 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SPBR | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | 0.158 **FAIL** (level 0.1, unknown) | 0.842 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Urn | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | 0.164 **FAIL** (level 0.1, unknown) | 0.836 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Bernoulli@0.2 | CountZeroInflatedPoisson | wald | ~. | 50 | 10 | unknown | 0.138 **FAIL** (level 0.1, unknown) | 0.863 **FAIL** (level 0.9, unknown) | 880/1000 |  | rate unknown: open a TODO to establish it |
| count | Bernoulli@0.2 | CountZeroInflatedPoisson | wald | ~1 | 50 | 10 | unknown | 0.132 **FAIL** (level 0.1, unknown) | 0.868 **FAIL** (level 0.9, unknown) | 998/1000 |  | rate unknown: open a TODO to establish it |


[← Campaign 2026-11-09-8c32d060 summary](README.md)
