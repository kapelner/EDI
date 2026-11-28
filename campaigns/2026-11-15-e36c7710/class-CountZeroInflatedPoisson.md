[← Campaign 2026-11-15-e36c7710 summary](README.md)

# Class CountZeroInflatedPoisson

Part of the [Classes index](classes.md). Response type: count. Status: null effect complete, power effects in progress. Verdict: **fail** (662 flagged test(s): 624 failing, 3 pending, 35 cleared).

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/class-CountZeroInflatedPoisson-dark.png"><img alt="CountZeroInflatedPoisson convergence of the error with n" src="figures/class-CountZeroInflatedPoisson.png"></picture>

Convergence verdicts (worst over designs, formulas and effects; provisional until the class is complete):

| procedure | metric | verdict |
|---|---|---|
| estimator (bias) | bias | faster |
| gradient | coverage | undetermined |
| lik_ratio | coverage | undetermined |
| score | coverage | undetermined |
| wald | coverage | undetermined |
| gradient | size | undetermined |
| lik_ratio | size | undetermined |
| rand | size | not applicable |
| score | size | undetermined |
| wald | size | undetermined |

Null effect: 978 cells (247 failing). Size, coverage and bias / SD against the level each is held to.

| design | n | formula | procedure | size | coverage | bias / SD | size level | coverage level | verdict |
|---|---|---|---|---|---|---|---|---|---|
| Fixed:Bernoulli | 50 | `~.` | gradient | 0.109 | 0.885 | 0.0091 | 0.1 | 0.9 | ok |
| Fixed:Bernoulli | 200 | `~.` | gradient | 0.055 | 0.945 | 0.017 | 0.1 | 0.9 | ok |
| Fixed:Bernoulli | 1000 | `~.` | gradient | 0.046 | 0.954 | -0.029 | 0.0525 | 0.948 | ok |
| Fixed:Bernoulli | 50 | `~.` | lik_ratio | 0.103 | 0.903 | 0.0091 | 0.1 | 0.9 | ok |
| Fixed:Bernoulli | 200 | `~.` | lik_ratio | 0.055 | 0.945 | 0.017 | 0.1 | 0.9 | ok |
| Fixed:Bernoulli | 1000 | `~.` | lik_ratio | 0.046 | 0.954 | -0.029 | 0.0525 | 0.948 | ok |
| Fixed:Bernoulli | 50 | `~.` | rand | 0.071 |  | 0.0091 | 0.05 | 0.95 | ok |
| Fixed:Bernoulli | 200 | `~.` | rand | 0.055 |  | 0.017 | 0.05 | 0.95 | ok |
| Fixed:Bernoulli | 1000 | `~.` | rand | 0.055 |  | -0.029 | 0.05 | 0.95 | ok |
| Fixed:Bernoulli | 50 | `~.` | score | 0.137 | 0.887 | 0.0091 | 0.1 | 0.9 | ok |
| Fixed:Bernoulli | 200 | `~.` | score | 0.056 | 0.944 | 0.017 | 0.1 | 0.9 | ok |
| Fixed:Bernoulli | 1000 | `~.` | score | 0.046 | 0.954 | -0.029 | 0.0525 | 0.948 | ok |
| Fixed:Bernoulli | 50 | `~.` | wald | 0.121 | 0.879 | 0.0091 | 0.1 | 0.9 | ok |
| Fixed:Bernoulli | 200 | `~.` | wald | 0.065 | 0.935 | 0.017 | 0.1 | 0.9 | ok |
| Fixed:Bernoulli | 1000 | `~.` | wald | 0.051 | 0.949 | -0.029 | 0.0525 | 0.948 | ok |
| Fixed:Bernoulli | 50 | `~1` | gradient | 0.166 | 0.834 | -0.026 | 0.1 | 0.9 | **FAIL** |
| Fixed:Bernoulli | 200 | `~1` | gradient | 0.17 | 0.83 | -0.0066 | 0.1 | 0.9 | **FAIL** |
| Fixed:Bernoulli | 1000 | `~1` | gradient | 0.169 | 0.831 | 0.016 | 0.0525 | 0.948 | **FAIL** |
| Fixed:Bernoulli | 50 | `~1` | lik_ratio | 0.162 | 0.838 | -0.026 | 0.1 | 0.9 | **FAIL** |
| Fixed:Bernoulli | 200 | `~1` | lik_ratio | 0.169 | 0.831 | -0.0066 | 0.1 | 0.9 | **FAIL** |
| Fixed:Bernoulli | 1000 | `~1` | lik_ratio | 0.169 | 0.831 | 0.016 | 0.0525 | 0.948 | **FAIL** |
| Fixed:Bernoulli | 50 | `~1` | rand | 0.069 |  | -0.026 | 0.05 | 0.95 | ok |
| Fixed:Bernoulli | 200 | `~1` | rand | 0.044 |  | -0.0066 | 0.05 | 0.95 | ok |
| Fixed:Bernoulli | 1000 | `~1` | rand | 0.048 |  | 0.016 | 0.05 | 0.95 | ok |
| Fixed:Bernoulli | 50 | `~1` | score | 0.156 | 0.844 | -0.026 | 0.1 | 0.9 | **FAIL** |
| Fixed:Bernoulli | 200 | `~1` | score | 0.165 | 0.835 | -0.0066 | 0.1 | 0.9 | **FAIL** |
| Fixed:Bernoulli | 1000 | `~1` | score | 0.169 | 0.831 | 0.016 | 0.0525 | 0.948 | **FAIL** |
| Fixed:Bernoulli | 50 | `~1` | wald | 0.08 | 0.92 | -0.026 | 0.1 | 0.9 | ok |
| Fixed:Bernoulli | 200 | `~1` | wald | 0.057 | 0.943 | -0.0066 | 0.1 | 0.9 | ok |
| Fixed:Bernoulli | 1000 | `~1` | wald | 0.049 | 0.951 | 0.016 | 0.0525 | 0.948 | ok |
| Fixed:Bernoulli@0.2 | 50 | `~.` | gradient | 0.101 | 0.896 | -0.0085 | 0.1 | 0.9 | ok |
| Fixed:Bernoulli@0.2 | 200 | `~.` | gradient | 0.059 | 0.941 | 0.0021 | 0.1 | 0.9 | ok |
| Fixed:Bernoulli@0.2 | 1000 | `~.` | gradient | 0.04 | 0.96 | -0.051 | 0.0625 | 0.938 | ok |
| Fixed:Bernoulli@0.2 | 50 | `~.` | lik_ratio | 0.093 | 0.909 | -0.0085 | 0.1 | 0.9 | ok |
| Fixed:Bernoulli@0.2 | 200 | `~.` | lik_ratio | 0.056 | 0.944 | 0.0021 | 0.1 | 0.9 | ok |
| Fixed:Bernoulli@0.2 | 1000 | `~.` | lik_ratio | 0.04 | 0.96 | -0.051 | 0.0625 | 0.938 | ok |
| Fixed:Bernoulli@0.2 | 50 | `~.` | rand | 0.055 |  | -0.0085 | 0.05 | 0.95 | ok |
| Fixed:Bernoulli@0.2 | 200 | `~.` | rand | 0.111 |  | 0.0021 | 0.05 | 0.95 | **FAIL** |
| Fixed:Bernoulli@0.2 | 1000 | `~.` | rand | 0.043 |  | -0.051 | 0.05 | 0.95 | ok |
| Fixed:Bernoulli@0.2 | 50 | `~.` | score | 0.113 | 0.897 | -0.0085 | 0.1 | 0.9 | ok |
| Fixed:Bernoulli@0.2 | 200 | `~.` | score | 0.059 | 0.941 | 0.0021 | 0.1 | 0.9 | ok |
| Fixed:Bernoulli@0.2 | 1000 | `~.` | score | 0.041 | 0.959 | -0.051 | 0.0625 | 0.938 | ok |
| Fixed:Bernoulli@0.2 | 50 | `~.` | wald | 0.138 | 0.863 | -0.0085 | 0.1 | 0.9 | **FAIL** |
| Fixed:Bernoulli@0.2 | 200 | `~.` | wald | 0.071 | 0.929 | 0.0021 | 0.1 | 0.9 | ok |
| Fixed:Bernoulli@0.2 | 1000 | `~.` | wald | 0.043 | 0.957 | -0.051 | 0.0625 | 0.938 | ok |
| Fixed:Bernoulli@0.2 | 50 | `~1` | gradient | 0.173 | 0.827 | -0.23 | 0.1 | 0.9 | **FAIL** |
| Fixed:Bernoulli@0.2 | 200 | `~1` | gradient | 0.154 | 0.846 | -0.054 | 0.1 | 0.9 | **FAIL** |
| Fixed:Bernoulli@0.2 | 1000 | `~1` | gradient | 0.173 | 0.827 | 0.031 | 0.0625 | 0.938 | **FAIL** |
| Fixed:Bernoulli@0.2 | 50 | `~1` | lik_ratio | 0.164 | 0.836 | -0.23 | 0.1 | 0.9 | **FAIL** |
| Fixed:Bernoulli@0.2 | 200 | `~1` | lik_ratio | 0.154 | 0.846 | -0.054 | 0.1 | 0.9 | **FAIL** |
| Fixed:Bernoulli@0.2 | 1000 | `~1` | lik_ratio | 0.171 | 0.829 | 0.031 | 0.0625 | 0.938 | **FAIL** |
| Fixed:Bernoulli@0.2 | 50 | `~1` | rand | 0.168 |  | -0.23 | 0.05 | 0.95 | **FAIL** |
| Fixed:Bernoulli@0.2 | 200 | `~1` | rand | 0.062 |  | -0.054 | 0.05 | 0.95 | ok |
| Fixed:Bernoulli@0.2 | 1000 | `~1` | rand | 0.058 |  | 0.031 | 0.05 | 0.95 | ok |
| Fixed:Bernoulli@0.2 | 50 | `~1` | score | 0.169 | 0.831 | -0.23 | 0.1 | 0.9 | **FAIL** |
| Fixed:Bernoulli@0.2 | 200 | `~1` | score | 0.154 | 0.846 | -0.054 | 0.1 | 0.9 | **FAIL** |
| Fixed:Bernoulli@0.2 | 1000 | `~1` | score | 0.168 | 0.832 | 0.031 | 0.0625 | 0.938 | **FAIL** |
| Fixed:Bernoulli@0.2 | 50 | `~1` | wald | 0.132 | 0.868 | -0.23 | 0.1 | 0.9 | **FAIL** |
| Fixed:Bernoulli@0.2 | 200 | `~1` | wald | 0.067 | 0.933 | -0.054 | 0.1 | 0.9 | ok |
| Fixed:Bernoulli@0.2 | 1000 | `~1` | wald | 0.053 | 0.947 | 0.031 | 0.0625 | 0.938 | ok |
| Fixed:BinaryMatch | 50 | `~.` | gradient | 0.093 | 0.907 | -0.000037 | 0.1 | 0.9 | ok |
| Fixed:BinaryMatch | 200 | `~.` | gradient | 0.043 | 0.957 | -0.049 | 0.1 | 0.9 | ok |
| Fixed:BinaryMatch | 1000 | `~.` | gradient | 0.032 | 0.968 | -0.01 | 0.0525 | 0.948 | ok |
| Fixed:BinaryMatch | 50 | `~.` | lik_ratio | 0.089 | 0.919 | -0.000037 | 0.1 | 0.9 | ok |
| Fixed:BinaryMatch | 200 | `~.` | lik_ratio | 0.044 | 0.956 | -0.049 | 0.1 | 0.9 | ok |
| Fixed:BinaryMatch | 1000 | `~.` | lik_ratio | 0.032 | 0.968 | -0.01 | 0.0525 | 0.948 | ok |
| Fixed:BinaryMatch | 50 | `~.` | rand | 0.063 |  | -0.000037 | 0.05 | 0.95 | ok |
| Fixed:BinaryMatch | 200 | `~.` | rand | 0.046 |  | -0.049 | 0.05 | 0.95 | ok |
| Fixed:BinaryMatch | 1000 | `~.` | rand | 0.036 |  | -0.01 | 0.05 | 0.95 | ok |
| Fixed:BinaryMatch | 50 | `~.` | score | 0.112 | 0.907 | -0.000037 | 0.1 | 0.9 | ok |
| Fixed:BinaryMatch | 200 | `~.` | score | 0.044 | 0.956 | -0.049 | 0.1 | 0.9 | ok |
| Fixed:BinaryMatch | 1000 | `~.` | score | 0.032 | 0.968 | -0.01 | 0.0525 | 0.948 | ok |
| Fixed:BinaryMatch | 50 | `~.` | wald | 0.108 | 0.892 | -0.000037 | 0.1 | 0.9 | ok |
| Fixed:BinaryMatch | 200 | `~.` | wald | 0.053 | 0.947 | -0.049 | 0.1 | 0.9 | ok |
| Fixed:BinaryMatch | 1000 | `~.` | wald | 0.034 | 0.966 | -0.01 | 0.0525 | 0.948 | ok |
| Fixed:BinaryMatch | 50 | `~1` | gradient | 0.123 | 0.877 | 0.003 | 0.1 | 0.9 | ok |
| Fixed:BinaryMatch | 200 | `~1` | gradient | 0.089 | 0.911 | 0.01 | 0.1 | 0.9 | ok |
| Fixed:BinaryMatch | 1000 | `~1` | gradient | 0.091 | 0.909 | -0.0023 | 0.0525 | 0.948 | **FAIL** |
| Fixed:BinaryMatch | 50 | `~1` | lik_ratio | 0.12 | 0.88 | 0.003 | 0.1 | 0.9 | ok |
| Fixed:BinaryMatch | 200 | `~1` | lik_ratio | 0.088 | 0.912 | 0.01 | 0.1 | 0.9 | ok |
| Fixed:BinaryMatch | 1000 | `~1` | lik_ratio | 0.091 | 0.909 | -0.0023 | 0.0525 | 0.948 | **FAIL** |
| Fixed:BinaryMatch | 50 | `~1` | rand | 0.051 |  | 0.003 | 0.05 | 0.95 | ok |
| Fixed:BinaryMatch | 200 | `~1` | rand | 0.043 |  | 0.01 | 0.05 | 0.95 | ok |
| Fixed:BinaryMatch | 1000 | `~1` | rand | 0.046 |  | -0.0023 | 0.05 | 0.95 | ok |
| Fixed:BinaryMatch | 50 | `~1` | score | 0.118 | 0.882 | 0.003 | 0.1 | 0.9 | ok |
| Fixed:BinaryMatch | 200 | `~1` | score | 0.087 | 0.913 | 0.01 | 0.1 | 0.9 | ok |
| Fixed:BinaryMatch | 1000 | `~1` | score | 0.091 | 0.909 | -0.0023 | 0.0525 | 0.948 | **FAIL** |
| Fixed:BinaryMatch | 50 | `~1` | wald | 0.048 | 0.952 | 0.003 | 0.1 | 0.9 | ok |
| Fixed:BinaryMatch | 200 | `~1` | wald | 0.025 | 0.975 | 0.01 | 0.1 | 0.9 | ok |
| Fixed:BinaryMatch | 1000 | `~1` | wald | 0.021 | 0.979 | -0.0023 | 0.0525 | 0.948 | ok |
| Fixed:Blocking | 50 | `~.` | gradient | 0.095 | 0.906 | 0.01 | 0.1 | 0.9 | ok |
| Fixed:Blocking | 200 | `~.` | gradient | 0.044 | 0.956 | 0.0097 | 0.1 | 0.9 | ok |
| Fixed:Blocking | 1000 | `~.` | gradient | 0.053 | 0.947 | -0.009 | 0.0525 | 0.948 | ok |
| Fixed:Blocking | 50 | `~.` | lik_ratio | 0.09 | 0.918 | 0.01 | 0.1 | 0.9 | ok |
| Fixed:Blocking | 200 | `~.` | lik_ratio | 0.044 | 0.956 | 0.0097 | 0.1 | 0.9 | ok |
| Fixed:Blocking | 1000 | `~.` | lik_ratio | 0.053 | 0.947 | -0.009 | 0.0525 | 0.948 | ok |
| Fixed:Blocking | 50 | `~.` | rand | 0.053 |  | 0.01 | 0.05 | 0.95 | ok |
| Fixed:Blocking | 200 | `~.` | rand | 0.044 |  | 0.0097 | 0.05 | 0.95 | ok |
| Fixed:Blocking | 1000 | `~.` | rand | 0.054 |  | -0.009 | 0.05 | 0.95 | ok |
| Fixed:Blocking | 50 | `~.` | score | 0.117 | 0.901 | 0.01 | 0.1 | 0.9 | ok |
| Fixed:Blocking | 200 | `~.` | score | 0.044 | 0.956 | 0.0097 | 0.1 | 0.9 | ok |
| Fixed:Blocking | 1000 | `~.` | score | 0.053 | 0.947 | -0.009 | 0.0525 | 0.948 | ok |
| Fixed:Blocking | 50 | `~.` | wald | 0.108 | 0.892 | 0.01 | 0.1 | 0.9 | ok |
| Fixed:Blocking | 200 | `~.` | wald | 0.047 | 0.953 | 0.0097 | 0.1 | 0.9 | ok |
| Fixed:Blocking | 1000 | `~.` | wald | 0.053 | 0.947 | -0.009 | 0.0525 | 0.948 | ok |
| Fixed:Blocking | 50 | `~1` | gradient | 0.155 | 0.845 | 0.07 | 0.1 | 0.9 | **FAIL** |
| Fixed:Blocking | 200 | `~1` | gradient | 0.14 | 0.86 | -0.0043 | 0.1 | 0.9 | **FAIL** |
| Fixed:Blocking | 1000 | `~1` | gradient | 0.154 | 0.846 | -0.043 | 0.0525 | 0.948 | **FAIL** |
| Fixed:Blocking | 50 | `~1` | lik_ratio | 0.154 | 0.846 | 0.07 | 0.1 | 0.9 | **FAIL** |
| Fixed:Blocking | 200 | `~1` | lik_ratio | 0.139 | 0.861 | -0.0043 | 0.1 | 0.9 | **FAIL** |
| Fixed:Blocking | 1000 | `~1` | lik_ratio | 0.153 | 0.847 | -0.043 | 0.0525 | 0.948 | **FAIL** |
| Fixed:Blocking | 50 | `~1` | rand | 0.049 |  | 0.07 | 0.05 | 0.95 | ok |
| Fixed:Blocking | 200 | `~1` | rand | 0.044 |  | -0.0043 | 0.05 | 0.95 | ok |
| Fixed:Blocking | 1000 | `~1` | rand | 0.045 |  | -0.043 | 0.05 | 0.95 | ok |
| Fixed:Blocking | 50 | `~1` | score | 0.149 | 0.851 | 0.07 | 0.1 | 0.9 | **FAIL** |
| Fixed:Blocking | 200 | `~1` | score | 0.137 | 0.863 | -0.0043 | 0.1 | 0.9 | **FAIL** |
| Fixed:Blocking | 1000 | `~1` | score | 0.153 | 0.847 | -0.043 | 0.0525 | 0.948 | **FAIL** |
| Fixed:Blocking | 50 | `~1` | wald | 0.069 | 0.931 | 0.07 | 0.1 | 0.9 | ok |
| Fixed:Blocking | 200 | `~1` | wald | 0.047 | 0.953 | -0.0043 | 0.1 | 0.9 | ok |
| Fixed:Blocking | 1000 | `~1` | wald | 0.046 | 0.954 | -0.043 | 0.0525 | 0.948 | ok |
| Fixed:Blocking@0.2 | 50 | `~.` | gradient | 0.1 | 0.9 | -0.0016 | 0.1 | 0.9 | ok |
| Fixed:Blocking@0.2 | 200 | `~.` | gradient | 0.068 | 0.932 | -0.035 | 0.1 | 0.9 | ok |
| Fixed:Blocking@0.2 | 1000 | `~.` | gradient | 0.056 | 0.944 | -0.042 | 0.0625 | 0.938 | ok |
| Fixed:Blocking@0.2 | 50 | `~.` | lik_ratio | 0.093 | 0.91 | -0.0016 | 0.1 | 0.9 | ok |
| Fixed:Blocking@0.2 | 200 | `~.` | lik_ratio | 0.065 | 0.935 | -0.035 | 0.1 | 0.9 | ok |
| Fixed:Blocking@0.2 | 1000 | `~.` | lik_ratio | 0.056 | 0.944 | -0.042 | 0.0625 | 0.938 | ok |
| Fixed:Blocking@0.2 | 50 | `~.` | rand | 0.057 |  | -0.0016 | 0.05 | 0.95 | ok |
| Fixed:Blocking@0.2 | 200 | `~.` | rand | 0.092 |  | -0.035 | 0.05 | 0.95 | **FAIL** |
| Fixed:Blocking@0.2 | 1000 | `~.` | rand | 0.057 |  | -0.042 | 0.05 | 0.95 | ok |
| Fixed:Blocking@0.2 | 50 | `~.` | score | 0.116 | 0.91 | -0.0016 | 0.1 | 0.9 | ok |
| Fixed:Blocking@0.2 | 200 | `~.` | score | 0.066 | 0.934 | -0.035 | 0.1 | 0.9 | ok |
| Fixed:Blocking@0.2 | 1000 | `~.` | score | 0.055 | 0.945 | -0.042 | 0.0625 | 0.938 | ok |
| Fixed:Blocking@0.2 | 50 | `~.` | wald | 0.118 | 0.882 | -0.0016 | 0.1 | 0.9 | ok |
| Fixed:Blocking@0.2 | 200 | `~.` | wald | 0.079 | 0.921 | -0.035 | 0.1 | 0.9 | ok |
| Fixed:Blocking@0.2 | 1000 | `~.` | wald | 0.051 | 0.949 | -0.042 | 0.0625 | 0.938 | ok |
| Fixed:Blocking@0.2 | 50 | `~1` | gradient | 0.158 | 0.842 | -0.13 | 0.1 | 0.9 | **FAIL** |
| Fixed:Blocking@0.2 | 200 | `~1` | gradient | 0.172 | 0.828 | -0.067 | 0.1 | 0.9 | **FAIL** |
| Fixed:Blocking@0.2 | 1000 | `~1` | gradient | 0.152 | 0.848 | -0.072 | 0.0625 | 0.938 | **FAIL** |
| Fixed:Blocking@0.2 | 50 | `~1` | lik_ratio | 0.15 | 0.85 | -0.13 | 0.1 | 0.9 | **FAIL** |
| Fixed:Blocking@0.2 | 200 | `~1` | lik_ratio | 0.173 | 0.827 | -0.067 | 0.1 | 0.9 | **FAIL** |
| Fixed:Blocking@0.2 | 1000 | `~1` | lik_ratio | 0.152 | 0.848 | -0.072 | 0.0625 | 0.938 | **FAIL** |
| Fixed:Blocking@0.2 | 50 | `~1` | rand | 0.166 |  | -0.13 | 0.05 | 0.95 | **FAIL** |
| Fixed:Blocking@0.2 | 200 | `~1` | rand | 0.061 |  | -0.067 | 0.05 | 0.95 | ok |
| Fixed:Blocking@0.2 | 1000 | `~1` | rand | 0.049 |  | -0.072 | 0.05 | 0.95 | ok |
| Fixed:Blocking@0.2 | 50 | `~1` | score | 0.137 | 0.863 | -0.13 | 0.1 | 0.9 | **FAIL** |
| Fixed:Blocking@0.2 | 200 | `~1` | score | 0.166 | 0.834 | -0.067 | 0.1 | 0.9 | **FAIL** |
| Fixed:Blocking@0.2 | 1000 | `~1` | score | 0.152 | 0.848 | -0.072 | 0.0625 | 0.938 | **FAIL** |
| Fixed:Blocking@0.2 | 50 | `~1` | wald | 0.108 | 0.892 | -0.13 | 0.1 | 0.9 | ok |
| Fixed:Blocking@0.2 | 200 | `~1` | wald | 0.074 | 0.926 | -0.067 | 0.1 | 0.9 | ok |
| Fixed:Blocking@0.2 | 1000 | `~1` | wald | 0.045 | 0.955 | -0.072 | 0.0625 | 0.938 | ok |
| Fixed:Greedy | 50 | `~.` | gradient | 0.097 | 0.902 | -0.0051 | 0.1 | 0.9 | ok |
| Fixed:Greedy | 200 | `~.` | gradient | 0.044 | 0.956 | -0.0094 | 0.1 | 0.9 | ok |
| Fixed:Greedy | 1000 | `~.` | gradient | 0.053 | 0.947 | 0.023 | 0.0525 | 0.948 | ok |
| Fixed:Greedy | 50 | `~.` | lik_ratio | 0.093 | 0.918 | -0.0051 | 0.1 | 0.9 | ok |
| Fixed:Greedy | 200 | `~.` | lik_ratio | 0.044 | 0.956 | -0.0094 | 0.1 | 0.9 | ok |
| Fixed:Greedy | 1000 | `~.` | lik_ratio | 0.053 | 0.947 | 0.023 | 0.0525 | 0.948 | ok |
| Fixed:Greedy | 50 | `~.` | rand | 0.056 |  | -0.0051 | 0.05 | 0.95 | ok |
| Fixed:Greedy | 200 | `~.` | rand | 0.042 |  | -0.0094 | 0.05 | 0.95 | ok |
| Fixed:Greedy | 1000 | `~.` | rand | 0.054 |  | 0.023 | 0.05 | 0.95 | ok |
| Fixed:Greedy | 50 | `~.` | score | 0.124 | 0.894 | -0.0051 | 0.1 | 0.9 | ok |
| Fixed:Greedy | 200 | `~.` | score | 0.044 | 0.956 | -0.0094 | 0.1 | 0.9 | ok |
| Fixed:Greedy | 1000 | `~.` | score | 0.053 | 0.947 | 0.023 | 0.0525 | 0.948 | ok |
| Fixed:Greedy | 50 | `~.` | wald | 0.116 | 0.884 | -0.0051 | 0.1 | 0.9 | ok |
| Fixed:Greedy | 200 | `~.` | wald | 0.049 | 0.951 | -0.0094 | 0.1 | 0.9 | ok |
| Fixed:Greedy | 1000 | `~.` | wald | 0.058 | 0.942 | 0.023 | 0.0525 | 0.948 | ok |
| Fixed:Greedy | 50 | `~1` | gradient | 0.122 | 0.878 | -0.011 | 0.1 | 0.9 | ok |
| Fixed:Greedy | 200 | `~1` | gradient | 0.115 | 0.885 | -0.015 | 0.1 | 0.9 | ok |
| Fixed:Greedy | 1000 | `~1` | gradient | 0.111 | 0.889 | 0.015 | 0.0525 | 0.948 | **FAIL** |
| Fixed:Greedy | 50 | `~1` | lik_ratio | 0.121 | 0.879 | -0.011 | 0.1 | 0.9 | ok |
| Fixed:Greedy | 200 | `~1` | lik_ratio | 0.115 | 0.885 | -0.015 | 0.1 | 0.9 | ok |
| Fixed:Greedy | 1000 | `~1` | lik_ratio | 0.111 | 0.889 | 0.015 | 0.0525 | 0.948 | **FAIL** |
| Fixed:Greedy | 50 | `~1` | rand | 0.055 |  | -0.011 | 0.05 | 0.95 | ok |
| Fixed:Greedy | 200 | `~1` | rand | 0.043 |  | -0.015 | 0.05 | 0.95 | ok |
| Fixed:Greedy | 1000 | `~1` | rand | 0.048 |  | 0.015 | 0.05 | 0.95 | ok |
| Fixed:Greedy | 50 | `~1` | score | 0.119 | 0.881 | -0.011 | 0.1 | 0.9 | ok |
| Fixed:Greedy | 200 | `~1` | score | 0.114 | 0.886 | -0.015 | 0.1 | 0.9 | ok |
| Fixed:Greedy | 1000 | `~1` | score | 0.11 | 0.89 | 0.015 | 0.0525 | 0.948 | **FAIL** |
| Fixed:Greedy | 50 | `~1` | wald | 0.057 | 0.943 | -0.011 | 0.1 | 0.9 | ok |
| Fixed:Greedy | 200 | `~1` | wald | 0.03 | 0.97 | -0.015 | 0.1 | 0.9 | ok |
| Fixed:Greedy | 1000 | `~1` | wald | 0.031 | 0.969 | 0.015 | 0.0525 | 0.948 | ok |
| Fixed:Greedy@0.2 | 50 | `~.` | gradient | 0.092 | 0.911 | -0.043 | 0.1 | 0.9 | ok |
| Fixed:Greedy@0.2 | 200 | `~.` | gradient | 0.05 | 0.95 | -0.04 | 0.1 | 0.9 | ok |
| Fixed:Greedy@0.2 | 1000 | `~.` | gradient | 0.057 | 0.943 | -0.0069 | 0.0625 | 0.938 | ok |
| Fixed:Greedy@0.2 | 50 | `~.` | lik_ratio | 0.09 | 0.913 | -0.043 | 0.1 | 0.9 | ok |
| Fixed:Greedy@0.2 | 200 | `~.` | lik_ratio | 0.05 | 0.95 | -0.04 | 0.1 | 0.9 | ok |
| Fixed:Greedy@0.2 | 1000 | `~.` | lik_ratio | 0.056 | 0.944 | -0.0069 | 0.0625 | 0.938 | ok |
| Fixed:Greedy@0.2 | 50 | `~.` | rand | 0.055 |  | -0.043 | 0.05 | 0.95 | ok |
| Fixed:Greedy@0.2 | 200 | `~.` | rand | 0.079 |  | -0.04 | 0.05 | 0.95 | **FAIL** |
| Fixed:Greedy@0.2 | 1000 | `~.` | rand | 0.061 |  | -0.0069 | 0.05 | 0.95 | ok |
| Fixed:Greedy@0.2 | 50 | `~.` | score | 0.114 | 0.908 | -0.043 | 0.1 | 0.9 | ok |
| Fixed:Greedy@0.2 | 200 | `~.` | score | 0.051 | 0.949 | -0.04 | 0.1 | 0.9 | ok |
| Fixed:Greedy@0.2 | 1000 | `~.` | score | 0.055 | 0.945 | -0.0069 | 0.0625 | 0.938 | ok |
| Fixed:Greedy@0.2 | 50 | `~.` | wald | 0.116 | 0.884 | -0.043 | 0.1 | 0.9 | ok |
| Fixed:Greedy@0.2 | 200 | `~.` | wald | 0.059 | 0.941 | -0.04 | 0.1 | 0.9 | ok |
| Fixed:Greedy@0.2 | 1000 | `~.` | wald | 0.064 | 0.936 | -0.0069 | 0.0625 | 0.938 | ok |
| Fixed:Greedy@0.2 | 50 | `~1` | gradient | 0.132 | 0.868 | -0.15 | 0.1 | 0.9 | **FAIL** |
| Fixed:Greedy@0.2 | 200 | `~1` | gradient | 0.111 | 0.889 | -0.035 | 0.1 | 0.9 | ok |
| Fixed:Greedy@0.2 | 1000 | `~1` | gradient | 0.116 | 0.884 | 0.019 | 0.0625 | 0.938 | **FAIL** |
| Fixed:Greedy@0.2 | 50 | `~1` | lik_ratio | 0.127 | 0.873 | -0.15 | 0.1 | 0.9 | ok |
| Fixed:Greedy@0.2 | 200 | `~1` | lik_ratio | 0.107 | 0.893 | -0.035 | 0.1 | 0.9 | ok |
| Fixed:Greedy@0.2 | 1000 | `~1` | lik_ratio | 0.117 | 0.883 | 0.019 | 0.0625 | 0.938 | **FAIL** |
| Fixed:Greedy@0.2 | 50 | `~1` | rand | 0.185 |  | -0.15 | 0.05 | 0.95 | **FAIL** |
| Fixed:Greedy@0.2 | 200 | `~1` | rand | 0.044 |  | -0.035 | 0.05 | 0.95 | ok |
| Fixed:Greedy@0.2 | 1000 | `~1` | rand | 0.053 |  | 0.019 | 0.05 | 0.95 | ok |
| Fixed:Greedy@0.2 | 50 | `~1` | score | 0.119 | 0.881 | -0.15 | 0.1 | 0.9 | ok |
| Fixed:Greedy@0.2 | 200 | `~1` | score | 0.108 | 0.892 | -0.035 | 0.1 | 0.9 | ok |
| Fixed:Greedy@0.2 | 1000 | `~1` | score | 0.12 | 0.88 | 0.019 | 0.0625 | 0.938 | **FAIL** |
| Fixed:Greedy@0.2 | 50 | `~1` | wald | 0.102 | 0.898 | -0.15 | 0.1 | 0.9 | ok |
| Fixed:Greedy@0.2 | 200 | `~1` | wald | 0.028 | 0.972 | -0.035 | 0.1 | 0.9 | ok |
| Fixed:Greedy@0.2 | 1000 | `~1` | wald | 0.031 | 0.969 | 0.019 | 0.0625 | 0.938 | ok |
| Fixed:GreedyDOptimal | 50 | `~.` | gradient | 0.097 | 0.902 | -0.0051 | 0.1 | 0.9 | ok |
| Fixed:GreedyDOptimal | 200 | `~.` | gradient | 0.044 | 0.956 | -0.0094 | 0.1 | 0.9 | ok |
| Fixed:GreedyDOptimal | 1000 | `~.` | gradient | 0.053 | 0.947 | 0.023 | 0.0525 | 0.948 | ok |
| Fixed:GreedyDOptimal | 50 | `~.` | lik_ratio | 0.093 | 0.918 | -0.0051 | 0.1 | 0.9 | ok |
| Fixed:GreedyDOptimal | 200 | `~.` | lik_ratio | 0.044 | 0.956 | -0.0094 | 0.1 | 0.9 | ok |
| Fixed:GreedyDOptimal | 1000 | `~.` | lik_ratio | 0.053 | 0.947 | 0.023 | 0.0525 | 0.948 | ok |
| Fixed:GreedyDOptimal | 50 | `~.` | rand | 0.056 |  | -0.0051 | 0.05 | 0.95 | ok |
| Fixed:GreedyDOptimal | 200 | `~.` | rand | 0.042 |  | -0.0094 | 0.05 | 0.95 | ok |
| Fixed:GreedyDOptimal | 1000 | `~.` | rand | 0.054 |  | 0.023 | 0.05 | 0.95 | ok |
| Fixed:GreedyDOptimal | 50 | `~.` | score | 0.124 | 0.894 | -0.0051 | 0.1 | 0.9 | ok |
| Fixed:GreedyDOptimal | 200 | `~.` | score | 0.044 | 0.956 | -0.0094 | 0.1 | 0.9 | ok |
| Fixed:GreedyDOptimal | 1000 | `~.` | score | 0.053 | 0.947 | 0.023 | 0.0525 | 0.948 | ok |
| Fixed:GreedyDOptimal | 50 | `~.` | wald | 0.116 | 0.884 | -0.0051 | 0.1 | 0.9 | ok |
| Fixed:GreedyDOptimal | 200 | `~.` | wald | 0.049 | 0.951 | -0.0094 | 0.1 | 0.9 | ok |
| Fixed:GreedyDOptimal | 1000 | `~.` | wald | 0.058 | 0.942 | 0.023 | 0.0525 | 0.948 | ok |
| Fixed:GreedyDOptimal | 50 | `~1` | gradient | 0.122 | 0.878 | -0.011 | 0.1 | 0.9 | ok |
| Fixed:GreedyDOptimal | 200 | `~1` | gradient | 0.115 | 0.885 | -0.015 | 0.1 | 0.9 | ok |
| Fixed:GreedyDOptimal | 1000 | `~1` | gradient | 0.111 | 0.889 | 0.015 | 0.0525 | 0.948 | **FAIL** |
| Fixed:GreedyDOptimal | 50 | `~1` | lik_ratio | 0.121 | 0.879 | -0.011 | 0.1 | 0.9 | ok |
| Fixed:GreedyDOptimal | 200 | `~1` | lik_ratio | 0.115 | 0.885 | -0.015 | 0.1 | 0.9 | ok |
| Fixed:GreedyDOptimal | 1000 | `~1` | lik_ratio | 0.111 | 0.889 | 0.015 | 0.0525 | 0.948 | **FAIL** |
| Fixed:GreedyDOptimal | 50 | `~1` | rand | 0.055 |  | -0.011 | 0.05 | 0.95 | ok |
| Fixed:GreedyDOptimal | 200 | `~1` | rand | 0.043 |  | -0.015 | 0.05 | 0.95 | ok |
| Fixed:GreedyDOptimal | 1000 | `~1` | rand | 0.048 |  | 0.015 | 0.05 | 0.95 | ok |
| Fixed:GreedyDOptimal | 50 | `~1` | score | 0.119 | 0.881 | -0.011 | 0.1 | 0.9 | ok |
| Fixed:GreedyDOptimal | 200 | `~1` | score | 0.114 | 0.886 | -0.015 | 0.1 | 0.9 | ok |
| Fixed:GreedyDOptimal | 1000 | `~1` | score | 0.11 | 0.89 | 0.015 | 0.0525 | 0.948 | **FAIL** |
| Fixed:GreedyDOptimal | 50 | `~1` | wald | 0.057 | 0.943 | -0.011 | 0.1 | 0.9 | ok |
| Fixed:GreedyDOptimal | 200 | `~1` | wald | 0.03 | 0.97 | -0.015 | 0.1 | 0.9 | ok |
| Fixed:GreedyDOptimal | 1000 | `~1` | wald | 0.031 | 0.969 | 0.015 | 0.0525 | 0.948 | ok |
| Fixed:GreedyDOptimal@0.2 | 50 | `~.` | gradient | 0.092 | 0.911 | -0.043 | 0.1 | 0.9 | ok |
| Fixed:GreedyDOptimal@0.2 | 200 | `~.` | gradient | 0.05 | 0.95 | -0.04 | 0.1 | 0.9 | ok |
| Fixed:GreedyDOptimal@0.2 | 1000 | `~.` | gradient | 0.057 | 0.943 | -0.0069 | 0.0625 | 0.938 | ok |
| Fixed:GreedyDOptimal@0.2 | 50 | `~.` | lik_ratio | 0.09 | 0.913 | -0.043 | 0.1 | 0.9 | ok |
| Fixed:GreedyDOptimal@0.2 | 200 | `~.` | lik_ratio | 0.05 | 0.95 | -0.04 | 0.1 | 0.9 | ok |
| Fixed:GreedyDOptimal@0.2 | 1000 | `~.` | lik_ratio | 0.056 | 0.944 | -0.0069 | 0.0625 | 0.938 | ok |
| Fixed:GreedyDOptimal@0.2 | 50 | `~.` | rand | 0.055 |  | -0.043 | 0.05 | 0.95 | ok |
| Fixed:GreedyDOptimal@0.2 | 200 | `~.` | rand | 0.079 |  | -0.04 | 0.05 | 0.95 | **FAIL** |
| Fixed:GreedyDOptimal@0.2 | 1000 | `~.` | rand | 0.061 |  | -0.0069 | 0.05 | 0.95 | ok |
| Fixed:GreedyDOptimal@0.2 | 50 | `~.` | score | 0.114 | 0.908 | -0.043 | 0.1 | 0.9 | ok |
| Fixed:GreedyDOptimal@0.2 | 200 | `~.` | score | 0.051 | 0.949 | -0.04 | 0.1 | 0.9 | ok |
| Fixed:GreedyDOptimal@0.2 | 1000 | `~.` | score | 0.055 | 0.945 | -0.0069 | 0.0625 | 0.938 | ok |
| Fixed:GreedyDOptimal@0.2 | 50 | `~.` | wald | 0.116 | 0.884 | -0.043 | 0.1 | 0.9 | ok |
| Fixed:GreedyDOptimal@0.2 | 200 | `~.` | wald | 0.059 | 0.941 | -0.04 | 0.1 | 0.9 | ok |
| Fixed:GreedyDOptimal@0.2 | 1000 | `~.` | wald | 0.064 | 0.936 | -0.0069 | 0.0625 | 0.938 | ok |
| Fixed:GreedyDOptimal@0.2 | 50 | `~1` | gradient | 0.132 | 0.868 | -0.15 | 0.1 | 0.9 | **FAIL** |
| Fixed:GreedyDOptimal@0.2 | 200 | `~1` | gradient | 0.111 | 0.889 | -0.035 | 0.1 | 0.9 | ok |
| Fixed:GreedyDOptimal@0.2 | 1000 | `~1` | gradient | 0.116 | 0.884 | 0.019 | 0.0625 | 0.938 | **FAIL** |
| Fixed:GreedyDOptimal@0.2 | 50 | `~1` | lik_ratio | 0.127 | 0.873 | -0.15 | 0.1 | 0.9 | ok |
| Fixed:GreedyDOptimal@0.2 | 200 | `~1` | lik_ratio | 0.107 | 0.893 | -0.035 | 0.1 | 0.9 | ok |
| Fixed:GreedyDOptimal@0.2 | 1000 | `~1` | lik_ratio | 0.117 | 0.883 | 0.019 | 0.0625 | 0.938 | **FAIL** |
| Fixed:GreedyDOptimal@0.2 | 50 | `~1` | rand | 0.185 |  | -0.15 | 0.05 | 0.95 | **FAIL** |
| Fixed:GreedyDOptimal@0.2 | 200 | `~1` | rand | 0.044 |  | -0.035 | 0.05 | 0.95 | ok |
| Fixed:GreedyDOptimal@0.2 | 1000 | `~1` | rand | 0.053 |  | 0.019 | 0.05 | 0.95 | ok |
| Fixed:GreedyDOptimal@0.2 | 50 | `~1` | score | 0.119 | 0.881 | -0.15 | 0.1 | 0.9 | ok |
| Fixed:GreedyDOptimal@0.2 | 200 | `~1` | score | 0.108 | 0.892 | -0.035 | 0.1 | 0.9 | ok |
| Fixed:GreedyDOptimal@0.2 | 1000 | `~1` | score | 0.12 | 0.88 | 0.019 | 0.0625 | 0.938 | **FAIL** |
| Fixed:GreedyDOptimal@0.2 | 50 | `~1` | wald | 0.102 | 0.898 | -0.15 | 0.1 | 0.9 | ok |
| Fixed:GreedyDOptimal@0.2 | 200 | `~1` | wald | 0.028 | 0.972 | -0.035 | 0.1 | 0.9 | ok |
| Fixed:GreedyDOptimal@0.2 | 1000 | `~1` | wald | 0.031 | 0.969 | 0.019 | 0.0625 | 0.938 | ok |
| Fixed:iBCRD | 50 | `~.` | gradient | 0.09 | 0.904 | 0.07 | 0.1 | 0.9 | ok |
| Fixed:iBCRD | 200 | `~.` | gradient | 0.046 | 0.954 | 0.007 | 0.1 | 0.9 | ok |
| Fixed:iBCRD | 1000 | `~.` | gradient | 0.057 | 0.943 | -0.044 | 0.0525 | 0.948 | ok |
| Fixed:iBCRD | 50 | `~.` | lik_ratio | 0.084 | 0.922 | 0.07 | 0.1 | 0.9 | ok |
| Fixed:iBCRD | 200 | `~.` | lik_ratio | 0.046 | 0.954 | 0.007 | 0.1 | 0.9 | ok |
| Fixed:iBCRD | 1000 | `~.` | lik_ratio | 0.057 | 0.943 | -0.044 | 0.0525 | 0.948 | ok |
| Fixed:iBCRD | 50 | `~.` | rand | 0.058 |  | 0.07 | 0.05 | 0.95 | ok |
| Fixed:iBCRD | 200 | `~.` | rand | 0.042 |  | 0.007 | 0.05 | 0.95 | ok |
| Fixed:iBCRD | 1000 | `~.` | rand | 0.055 |  | -0.044 | 0.05 | 0.95 | ok |
| Fixed:iBCRD | 50 | `~.` | score | 0.102 | 0.906 | 0.07 | 0.1 | 0.9 | ok |
| Fixed:iBCRD | 200 | `~.` | score | 0.044 | 0.956 | 0.007 | 0.1 | 0.9 | ok |
| Fixed:iBCRD | 1000 | `~.` | score | 0.057 | 0.943 | -0.044 | 0.0525 | 0.948 | ok |
| Fixed:iBCRD | 50 | `~.` | wald | 0.101 | 0.899 | 0.07 | 0.1 | 0.9 | ok |
| Fixed:iBCRD | 200 | `~.` | wald | 0.052 | 0.948 | 0.007 | 0.1 | 0.9 | ok |
| Fixed:iBCRD | 1000 | `~.` | wald | 0.053 | 0.947 | -0.044 | 0.0525 | 0.948 | ok |
| Fixed:iBCRD | 50 | `~1` | gradient | 0.169 | 0.831 | 0.091 | 0.1 | 0.9 | **FAIL** |
| Fixed:iBCRD | 200 | `~1` | gradient | 0.155 | 0.845 | -0.012 | 0.1 | 0.9 | **FAIL** |
| Fixed:iBCRD | 1000 | `~1` | gradient | 0.163 | 0.837 | -0.011 | 0.0525 | 0.948 | **FAIL** |
| Fixed:iBCRD | 50 | `~1` | lik_ratio | 0.165 | 0.835 | 0.091 | 0.1 | 0.9 | **FAIL** |
| Fixed:iBCRD | 200 | `~1` | lik_ratio | 0.154 | 0.846 | -0.012 | 0.1 | 0.9 | **FAIL** |
| Fixed:iBCRD | 1000 | `~1` | lik_ratio | 0.163 | 0.837 | -0.011 | 0.0525 | 0.948 | **FAIL** |
| Fixed:iBCRD | 50 | `~1` | rand | 0.047 |  | 0.091 | 0.05 | 0.95 | ok |
| Fixed:iBCRD | 200 | `~1` | rand | 0.051 |  | -0.012 | 0.05 | 0.95 | ok |
| Fixed:iBCRD | 1000 | `~1` | rand | 0.043 |  | -0.011 | 0.05 | 0.95 | ok |
| Fixed:iBCRD | 50 | `~1` | score | 0.162 | 0.838 | 0.091 | 0.1 | 0.9 | **FAIL** |
| Fixed:iBCRD | 200 | `~1` | score | 0.154 | 0.846 | -0.012 | 0.1 | 0.9 | **FAIL** |
| Fixed:iBCRD | 1000 | `~1` | score | 0.163 | 0.837 | -0.011 | 0.0525 | 0.948 | **FAIL** |
| Fixed:iBCRD | 50 | `~1` | wald | 0.074 | 0.926 | 0.091 | 0.1 | 0.9 | ok |
| Fixed:iBCRD | 200 | `~1` | wald | 0.057 | 0.943 | -0.012 | 0.1 | 0.9 | ok |
| Fixed:iBCRD | 1000 | `~1` | wald | 0.043 | 0.957 | -0.011 | 0.0525 | 0.948 | ok |
| Fixed:iBCRD@0.2 | 50 | `~.` | gradient | 0.094 | 0.905 | 0.0087 | 0.1 | 0.9 | ok |
| Fixed:iBCRD@0.2 | 200 | `~.` | gradient | 0.063 | 0.937 | -0.046 | 0.1 | 0.9 | ok |
| Fixed:iBCRD@0.2 | 1000 | `~.` | gradient | 0.042 | 0.958 | -0.023 | 0.0625 | 0.938 | ok |
| Fixed:iBCRD@0.2 | 50 | `~.` | lik_ratio | 0.088 | 0.915 | 0.0087 | 0.1 | 0.9 | ok |
| Fixed:iBCRD@0.2 | 200 | `~.` | lik_ratio | 0.064 | 0.936 | -0.046 | 0.1 | 0.9 | ok |
| Fixed:iBCRD@0.2 | 1000 | `~.` | lik_ratio | 0.042 | 0.958 | -0.023 | 0.0625 | 0.938 | ok |
| Fixed:iBCRD@0.2 | 50 | `~.` | rand | 0.06 |  | 0.0087 | 0.05 | 0.95 | ok |
| Fixed:iBCRD@0.2 | 200 | `~.` | rand | 0.099 |  | -0.046 | 0.05 | 0.95 | **FAIL** |
| Fixed:iBCRD@0.2 | 1000 | `~.` | rand | 0.042 |  | -0.023 | 0.05 | 0.95 | ok |
| Fixed:iBCRD@0.2 | 50 | `~.` | score | 0.116 | 0.907 | 0.0087 | 0.1 | 0.9 | ok |
| Fixed:iBCRD@0.2 | 200 | `~.` | score | 0.06 | 0.94 | -0.046 | 0.1 | 0.9 | ok |
| Fixed:iBCRD@0.2 | 1000 | `~.` | score | 0.041 | 0.959 | -0.023 | 0.0625 | 0.938 | ok |
| Fixed:iBCRD@0.2 | 50 | `~.` | wald | 0.131 | 0.869 | 0.0087 | 0.1 | 0.9 | ok |
| Fixed:iBCRD@0.2 | 200 | `~.` | wald | 0.079 | 0.921 | -0.046 | 0.1 | 0.9 | ok |
| Fixed:iBCRD@0.2 | 1000 | `~.` | wald | 0.041 | 0.959 | -0.023 | 0.0625 | 0.938 | ok |
| Fixed:iBCRD@0.2 | 50 | `~1` | gradient | 0.149 | 0.851 | -0.093 | 0.1 | 0.9 | **FAIL** |
| Fixed:iBCRD@0.2 | 200 | `~1` | gradient | 0.161 | 0.839 | -0.066 | 0.1 | 0.9 | **FAIL** |
| Fixed:iBCRD@0.2 | 1000 | `~1` | gradient | 0.176 | 0.824 | 0.024 | 0.0625 | 0.938 | **FAIL** |
| Fixed:iBCRD@0.2 | 50 | `~1` | lik_ratio | 0.145 | 0.855 | -0.093 | 0.1 | 0.9 | **FAIL** |
| Fixed:iBCRD@0.2 | 200 | `~1` | lik_ratio | 0.158 | 0.842 | -0.066 | 0.1 | 0.9 | **FAIL** |
| Fixed:iBCRD@0.2 | 1000 | `~1` | lik_ratio | 0.176 | 0.824 | 0.024 | 0.0625 | 0.938 | **FAIL** |
| Fixed:iBCRD@0.2 | 50 | `~1` | rand | 0.178 |  | -0.093 | 0.05 | 0.95 | **FAIL** |
| Fixed:iBCRD@0.2 | 200 | `~1` | rand | 0.054 |  | -0.066 | 0.05 | 0.95 | ok |
| Fixed:iBCRD@0.2 | 1000 | `~1` | rand | 0.049 |  | 0.024 | 0.05 | 0.95 | ok |
| Fixed:iBCRD@0.2 | 50 | `~1` | score | 0.146 | 0.854 | -0.093 | 0.1 | 0.9 | **FAIL** |
| Fixed:iBCRD@0.2 | 200 | `~1` | score | 0.152 | 0.848 | -0.066 | 0.1 | 0.9 | **FAIL** |
| Fixed:iBCRD@0.2 | 1000 | `~1` | score | 0.176 | 0.824 | 0.024 | 0.0625 | 0.938 | **FAIL** |
| Fixed:iBCRD@0.2 | 50 | `~1` | wald | 0.102 | 0.898 | -0.093 | 0.1 | 0.9 | ok |
| Fixed:iBCRD@0.2 | 200 | `~1` | wald | 0.065 | 0.935 | -0.066 | 0.1 | 0.9 | ok |
| Fixed:iBCRD@0.2 | 1000 | `~1` | wald | 0.052 | 0.948 | 0.024 | 0.0625 | 0.938 | ok |
| Fixed:MatchingGreedyPairSwitching | 50 | `~.` | gradient | 0.105 | 0.892 | -0.0056 | 0.1 | 0.9 | ok |
| Fixed:MatchingGreedyPairSwitching | 200 | `~.` | gradient | 0.045 | 0.955 | -0.0003 | 0.1 | 0.9 | ok |
| Fixed:MatchingGreedyPairSwitching | 1000 | `~.` | gradient | 0.044 | 0.956 | 0.0094 | 0.0525 | 0.948 | ok |
| Fixed:MatchingGreedyPairSwitching | 50 | `~.` | lik_ratio | 0.098 | 0.909 | -0.0056 | 0.1 | 0.9 | ok |
| Fixed:MatchingGreedyPairSwitching | 200 | `~.` | lik_ratio | 0.045 | 0.955 | -0.0003 | 0.1 | 0.9 | ok |
| Fixed:MatchingGreedyPairSwitching | 1000 | `~.` | lik_ratio | 0.044 | 0.956 | 0.0094 | 0.0525 | 0.948 | ok |
| Fixed:MatchingGreedyPairSwitching | 50 | `~.` | rand | 0.063 |  | -0.0056 | 0.05 | 0.95 | ok |
| Fixed:MatchingGreedyPairSwitching | 200 | `~.` | rand | 0.043 |  | -0.0003 | 0.05 | 0.95 | ok |
| Fixed:MatchingGreedyPairSwitching | 1000 | `~.` | rand | 0.041 |  | 0.0094 | 0.05 | 0.95 | ok |
| Fixed:MatchingGreedyPairSwitching | 50 | `~.` | score | 0.12 | 0.894 | -0.0056 | 0.1 | 0.9 | ok |
| Fixed:MatchingGreedyPairSwitching | 200 | `~.` | score | 0.045 | 0.955 | -0.0003 | 0.1 | 0.9 | ok |
| Fixed:MatchingGreedyPairSwitching | 1000 | `~.` | score | 0.044 | 0.956 | 0.0094 | 0.0525 | 0.948 | ok |
| Fixed:MatchingGreedyPairSwitching | 50 | `~.` | wald | 0.0995 | 0.9 | -0.0056 | 0.1 | 0.9 | ok |
| Fixed:MatchingGreedyPairSwitching | 200 | `~.` | wald | 0.05 | 0.95 | -0.0003 | 0.1 | 0.9 | ok |
| Fixed:MatchingGreedyPairSwitching | 1000 | `~.` | wald | 0.042 | 0.958 | 0.0094 | 0.0525 | 0.948 | ok |
| Fixed:MatchingGreedyPairSwitching | 50 | `~1` | gradient | 0.117 | 0.883 | -0.052 | 0.1 | 0.9 | ok |
| Fixed:MatchingGreedyPairSwitching | 200 | `~1` | gradient | 0.098 | 0.902 | -0.024 | 0.1 | 0.9 | ok |
| Fixed:MatchingGreedyPairSwitching | 1000 | `~1` | gradient | 0.07 | 0.93 | 0.0014 | 0.0525 | 0.948 | ok |
| Fixed:MatchingGreedyPairSwitching | 50 | `~1` | lik_ratio | 0.117 | 0.883 | -0.052 | 0.1 | 0.9 | ok |
| Fixed:MatchingGreedyPairSwitching | 200 | `~1` | lik_ratio | 0.097 | 0.903 | -0.024 | 0.1 | 0.9 | ok |
| Fixed:MatchingGreedyPairSwitching | 1000 | `~1` | lik_ratio | 0.07 | 0.93 | 0.0014 | 0.0525 | 0.948 | ok |
| Fixed:MatchingGreedyPairSwitching | 50 | `~1` | rand | 0.061 |  | -0.052 | 0.05 | 0.95 | ok |
| Fixed:MatchingGreedyPairSwitching | 200 | `~1` | rand | 0.042 |  | -0.024 | 0.05 | 0.95 | ok |
| Fixed:MatchingGreedyPairSwitching | 1000 | `~1` | rand | 0.037 |  | 0.0014 | 0.05 | 0.95 | ok |
| Fixed:MatchingGreedyPairSwitching | 50 | `~1` | score | 0.117 | 0.883 | -0.052 | 0.1 | 0.9 | ok |
| Fixed:MatchingGreedyPairSwitching | 200 | `~1` | score | 0.096 | 0.904 | -0.024 | 0.1 | 0.9 | ok |
| Fixed:MatchingGreedyPairSwitching | 1000 | `~1` | score | 0.07 | 0.93 | 0.0014 | 0.0525 | 0.948 | ok |
| Fixed:MatchingGreedyPairSwitching | 50 | `~1` | wald | 0.043 | 0.957 | -0.052 | 0.1 | 0.9 | ok |
| Fixed:MatchingGreedyPairSwitching | 200 | `~1` | wald | 0.019 | 0.981 | -0.024 | 0.1 | 0.9 | ok |
| Fixed:MatchingGreedyPairSwitching | 1000 | `~1` | wald | 0.013 | 0.987 | 0.0014 | 0.0525 | 0.948 | ok |
| Fixed:Optimal | 50 | `~.` | gradient | 0.091 | 0.908 | 0.027 | 0.1 | 0.9 | ok |
| Fixed:Optimal | 200 | `~.` | gradient | 0.051 | 0.949 | -0.02 | 0.1 | 0.9 | ok |
| Fixed:Optimal | 1000 | `~.` | gradient | 0.048 | 0.952 | -0.0025 | 0.0525 | 0.948 | ok |
| Fixed:Optimal | 50 | `~.` | lik_ratio | 0.084 | 0.922 | 0.027 | 0.1 | 0.9 | ok |
| Fixed:Optimal | 200 | `~.` | lik_ratio | 0.051 | 0.949 | -0.02 | 0.1 | 0.9 | ok |
| Fixed:Optimal | 1000 | `~.` | lik_ratio | 0.048 | 0.952 | -0.0025 | 0.0525 | 0.948 | ok |
| Fixed:Optimal | 50 | `~.` | score | 0.106 | 0.908 | 0.027 | 0.1 | 0.9 | ok |
| Fixed:Optimal | 200 | `~.` | score | 0.051 | 0.949 | -0.02 | 0.1 | 0.9 | ok |
| Fixed:Optimal | 1000 | `~.` | score | 0.047 | 0.953 | -0.0025 | 0.0525 | 0.948 | ok |
| Fixed:Optimal | 50 | `~.` | wald | 0.093 | 0.907 | 0.027 | 0.1 | 0.9 | ok |
| Fixed:Optimal | 200 | `~.` | wald | 0.061 | 0.939 | -0.02 | 0.1 | 0.9 | ok |
| Fixed:Optimal | 1000 | `~.` | wald | 0.051 | 0.949 | -0.0025 | 0.0525 | 0.948 | ok |
| Fixed:Optimal | 50 | `~1` | gradient | 0.118 | 0.882 | 0.079 | 0.1 | 0.9 | ok |
| Fixed:Optimal | 200 | `~1` | gradient | 0.136 | 0.864 | -0.00079 | 0.1 | 0.9 | ok |
| Fixed:Optimal | 1000 | `~1` | gradient | 0.113 | 0.887 | 0.0097 | 0.0525 | 0.948 | **FAIL** |
| Fixed:Optimal | 50 | `~1` | lik_ratio | 0.116 | 0.884 | 0.079 | 0.1 | 0.9 | ok |
| Fixed:Optimal | 200 | `~1` | lik_ratio | 0.134 | 0.866 | -0.00079 | 0.1 | 0.9 | ok |
| Fixed:Optimal | 1000 | `~1` | lik_ratio | 0.113 | 0.887 | 0.0097 | 0.0525 | 0.948 | **FAIL** |
| Fixed:Optimal | 50 | `~1` | score | 0.113 | 0.887 | 0.079 | 0.1 | 0.9 | ok |
| Fixed:Optimal | 200 | `~1` | score | 0.133 | 0.867 | -0.00079 | 0.1 | 0.9 | ok |
| Fixed:Optimal | 1000 | `~1` | score | 0.112 | 0.888 | 0.0097 | 0.0525 | 0.948 | **FAIL** |
| Fixed:Optimal | 50 | `~1` | wald | 0.043 | 0.957 | 0.079 | 0.1 | 0.9 | ok |
| Fixed:Optimal | 200 | `~1` | wald | 0.039 | 0.961 | -0.00079 | 0.1 | 0.9 | ok |
| Fixed:Optimal | 1000 | `~1` | wald | 0.028 | 0.972 | 0.0097 | 0.0525 | 0.948 | ok |
| Fixed:Optimal@0.2 | 50 | `~.` | gradient | 0.11 | 0.893 | -0.0041 | 0.1 | 0.9 | ok |
| Fixed:Optimal@0.2 | 200 | `~.` | gradient | 0.071 | 0.929 | -0.041 | 0.1 | 0.9 | ok |
| Fixed:Optimal@0.2 | 1000 | `~.` | gradient | 0.052 | 0.948 | 0.00019 | 0.0625 | 0.938 | ok |
| Fixed:Optimal@0.2 | 50 | `~.` | lik_ratio | 0.102 | 0.902 | -0.0041 | 0.1 | 0.9 | ok |
| Fixed:Optimal@0.2 | 200 | `~.` | lik_ratio | 0.069 | 0.931 | -0.041 | 0.1 | 0.9 | ok |
| Fixed:Optimal@0.2 | 1000 | `~.` | lik_ratio | 0.051 | 0.949 | 0.00019 | 0.0625 | 0.938 | ok |
| Fixed:Optimal@0.2 | 50 | `~.` | score | 0.128 | 0.889 | -0.0041 | 0.1 | 0.9 | ok |
| Fixed:Optimal@0.2 | 200 | `~.` | score | 0.07 | 0.93 | -0.041 | 0.1 | 0.9 | ok |
| Fixed:Optimal@0.2 | 1000 | `~.` | score | 0.052 | 0.948 | 0.00019 | 0.0625 | 0.938 | ok |
| Fixed:Optimal@0.2 | 50 | `~.` | wald | 0.12 | 0.88 | -0.0041 | 0.1 | 0.9 | ok |
| Fixed:Optimal@0.2 | 200 | `~.` | wald | 0.086 | 0.914 | -0.041 | 0.1 | 0.9 | ok |
| Fixed:Optimal@0.2 | 1000 | `~.` | wald | 0.057 | 0.943 | 0.00019 | 0.0625 | 0.938 | ok |
| Fixed:Optimal@0.2 | 50 | `~1` | gradient | 0.134 | 0.866 | -0.18 | 0.1 | 0.9 | **FAIL** |
| Fixed:Optimal@0.2 | 200 | `~1` | gradient | 0.142 | 0.858 | -0.12 | 0.1 | 0.9 | ok |
| Fixed:Optimal@0.2 | 1000 | `~1` | gradient | 0.125 | 0.875 | -0.061 | 0.0625 | 0.938 | **FAIL** |
| Fixed:Optimal@0.2 | 50 | `~1` | lik_ratio | 0.131 | 0.869 | -0.18 | 0.1 | 0.9 | ok |
| Fixed:Optimal@0.2 | 200 | `~1` | lik_ratio | 0.14 | 0.86 | -0.12 | 0.1 | 0.9 | ok |
| Fixed:Optimal@0.2 | 1000 | `~1` | lik_ratio | 0.125 | 0.875 | -0.061 | 0.0625 | 0.938 | **FAIL** |
| Fixed:Optimal@0.2 | 50 | `~1` | score | 0.122 | 0.878 | -0.18 | 0.1 | 0.9 | ok |
| Fixed:Optimal@0.2 | 200 | `~1` | score | 0.125 | 0.875 | -0.12 | 0.1 | 0.9 | ok |
| Fixed:Optimal@0.2 | 1000 | `~1` | score | 0.123 | 0.877 | -0.061 | 0.0625 | 0.938 | **FAIL** |
| Fixed:Optimal@0.2 | 50 | `~1` | wald | 0.103 | 0.897 | -0.18 | 0.1 | 0.9 | ok |
| Fixed:Optimal@0.2 | 200 | `~1` | wald | 0.053 | 0.947 | -0.12 | 0.1 | 0.9 | ok |
| Fixed:Optimal@0.2 | 1000 | `~1` | wald | 0.039 | 0.961 | -0.061 | 0.0625 | 0.938 | ok |
| Fixed:OptimalBlocks | 50 | `~.` | gradient | 0.113 | 0.888 | 0.03 | 0.1 | 0.9 | ok |
| Fixed:OptimalBlocks | 200 | `~.` | gradient | 0.054 | 0.946 | 0.0031 | 0.1 | 0.9 | ok |
| Fixed:OptimalBlocks | 1000 | `~.` | gradient | 0.041 | 0.959 | 0.005 | 0.0525 | 0.948 | ok |
| Fixed:OptimalBlocks | 50 | `~.` | lik_ratio | 0.105 | 0.905 | 0.03 | 0.1 | 0.9 | ok |
| Fixed:OptimalBlocks | 200 | `~.` | lik_ratio | 0.054 | 0.946 | 0.0031 | 0.1 | 0.9 | ok |
| Fixed:OptimalBlocks | 1000 | `~.` | lik_ratio | 0.041 | 0.959 | 0.005 | 0.0525 | 0.948 | ok |
| Fixed:OptimalBlocks | 50 | `~.` | rand | 0.067 |  | 0.03 | 0.05 | 0.95 | ok |
| Fixed:OptimalBlocks | 200 | `~.` | rand | 0.051 |  | 0.0031 | 0.05 | 0.95 | ok |
| Fixed:OptimalBlocks | 1000 | `~.` | rand | 0.048 |  | 0.005 | 0.05 | 0.95 | ok |
| Fixed:OptimalBlocks | 50 | `~.` | score | 0.126 | 0.891 | 0.03 | 0.1 | 0.9 | ok |
| Fixed:OptimalBlocks | 200 | `~.` | score | 0.054 | 0.946 | 0.0031 | 0.1 | 0.9 | ok |
| Fixed:OptimalBlocks | 1000 | `~.` | score | 0.041 | 0.959 | 0.005 | 0.0525 | 0.948 | ok |
| Fixed:OptimalBlocks | 50 | `~.` | wald | 0.129 | 0.871 | 0.03 | 0.1 | 0.9 | ok |
| Fixed:OptimalBlocks | 200 | `~.` | wald | 0.058 | 0.942 | 0.0031 | 0.1 | 0.9 | ok |
| Fixed:OptimalBlocks | 1000 | `~.` | wald | 0.043 | 0.957 | 0.005 | 0.0525 | 0.948 | ok |
| Fixed:OptimalBlocks | 50 | `~1` | gradient | 0.17 | 0.83 | 0.031 | 0.1 | 0.9 | **FAIL** |
| Fixed:OptimalBlocks | 200 | `~1` | gradient | 0.132 | 0.868 | 0.029 | 0.1 | 0.9 | **FAIL** |
| Fixed:OptimalBlocks | 1000 | `~1` | gradient | 0.121 | 0.879 | -0.019 | 0.0525 | 0.948 | **FAIL** |
| Fixed:OptimalBlocks | 50 | `~1` | lik_ratio | 0.166 | 0.834 | 0.031 | 0.1 | 0.9 | **FAIL** |
| Fixed:OptimalBlocks | 200 | `~1` | lik_ratio | 0.132 | 0.868 | 0.029 | 0.1 | 0.9 | **FAIL** |
| Fixed:OptimalBlocks | 1000 | `~1` | lik_ratio | 0.121 | 0.879 | -0.019 | 0.0525 | 0.948 | **FAIL** |
| Fixed:OptimalBlocks | 50 | `~1` | rand | 0.075 |  | 0.031 | 0.05 | 0.95 | ok |
| Fixed:OptimalBlocks | 200 | `~1` | rand | 0.054 |  | 0.029 | 0.05 | 0.95 | ok |
| Fixed:OptimalBlocks | 1000 | `~1` | rand | 0.044 |  | -0.019 | 0.05 | 0.95 | ok |
| Fixed:OptimalBlocks | 50 | `~1` | score | 0.163 | 0.837 | 0.031 | 0.1 | 0.9 | **FAIL** |
| Fixed:OptimalBlocks | 200 | `~1` | score | 0.13 | 0.87 | 0.029 | 0.1 | 0.9 | ok |
| Fixed:OptimalBlocks | 1000 | `~1` | score | 0.121 | 0.879 | -0.019 | 0.0525 | 0.948 | **FAIL** |
| Fixed:OptimalBlocks | 50 | `~1` | wald | 0.079 | 0.921 | 0.031 | 0.1 | 0.9 | ok |
| Fixed:OptimalBlocks | 200 | `~1` | wald | 0.042 | 0.958 | 0.029 | 0.1 | 0.9 | ok |
| Fixed:OptimalBlocks | 1000 | `~1` | wald | 0.026 | 0.974 | -0.019 | 0.0525 | 0.948 | ok |
| Fixed:OptimalBlocks@0.2 | 50 | `~.` | gradient | 0.09 | 0.911 | 0.0054 | 0.1 | 0.9 | ok |
| Fixed:OptimalBlocks@0.2 | 200 | `~.` | gradient | 0.052 | 0.948 | -0.058 | 0.1 | 0.9 | ok |
| Fixed:OptimalBlocks@0.2 | 1000 | `~.` | gradient | 0.053 | 0.947 | 0.023 | 0.0625 | 0.938 | ok |
| Fixed:OptimalBlocks@0.2 | 50 | `~.` | lik_ratio | 0.084 | 0.919 | 0.0054 | 0.1 | 0.9 | ok |
| Fixed:OptimalBlocks@0.2 | 200 | `~.` | lik_ratio | 0.052 | 0.948 | -0.058 | 0.1 | 0.9 | ok |
| Fixed:OptimalBlocks@0.2 | 1000 | `~.` | lik_ratio | 0.053 | 0.947 | 0.023 | 0.0625 | 0.938 | ok |
| Fixed:OptimalBlocks@0.2 | 50 | `~.` | rand | 0.052 |  | 0.0054 | 0.05 | 0.95 | ok |
| Fixed:OptimalBlocks@0.2 | 200 | `~.` | rand | 0.085 |  | -0.058 | 0.05 | 0.95 | **FAIL** |
| Fixed:OptimalBlocks@0.2 | 1000 | `~.` | rand | 0.053 |  | 0.023 | 0.05 | 0.95 | ok |
| Fixed:OptimalBlocks@0.2 | 50 | `~.` | score | 0.106 | 0.911 | 0.0054 | 0.1 | 0.9 | ok |
| Fixed:OptimalBlocks@0.2 | 200 | `~.` | score | 0.052 | 0.948 | -0.058 | 0.1 | 0.9 | ok |
| Fixed:OptimalBlocks@0.2 | 1000 | `~.` | score | 0.052 | 0.948 | 0.023 | 0.0625 | 0.938 | ok |
| Fixed:OptimalBlocks@0.2 | 50 | `~.` | wald | 0.107 | 0.893 | 0.0054 | 0.1 | 0.9 | ok |
| Fixed:OptimalBlocks@0.2 | 200 | `~.` | wald | 0.06 | 0.94 | -0.058 | 0.1 | 0.9 | ok |
| Fixed:OptimalBlocks@0.2 | 1000 | `~.` | wald | 0.058 | 0.942 | 0.023 | 0.0625 | 0.938 | ok |
| Fixed:OptimalBlocks@0.2 | 50 | `~1` | gradient | 0.12 | 0.88 | -0.14 | 0.1 | 0.9 | ok |
| Fixed:OptimalBlocks@0.2 | 200 | `~1` | gradient | 0.123 | 0.877 | -0.051 | 0.1 | 0.9 | ok |
| Fixed:OptimalBlocks@0.2 | 1000 | `~1` | gradient | 0.132 | 0.868 | 0.024 | 0.0625 | 0.938 | **FAIL** |
| Fixed:OptimalBlocks@0.2 | 50 | `~1` | lik_ratio | 0.109 | 0.891 | -0.14 | 0.1 | 0.9 | ok |
| Fixed:OptimalBlocks@0.2 | 200 | `~1` | lik_ratio | 0.123 | 0.877 | -0.051 | 0.1 | 0.9 | ok |
| Fixed:OptimalBlocks@0.2 | 1000 | `~1` | lik_ratio | 0.131 | 0.869 | 0.024 | 0.0625 | 0.938 | **FAIL** |
| Fixed:OptimalBlocks@0.2 | 50 | `~1` | rand | 0.146 |  | -0.14 | 0.05 | 0.95 | **FAIL** |
| Fixed:OptimalBlocks@0.2 | 200 | `~1` | rand | 0.047 |  | -0.051 | 0.05 | 0.95 | ok |
| Fixed:OptimalBlocks@0.2 | 1000 | `~1` | rand | 0.064 |  | 0.024 | 0.05 | 0.95 | ok |
| Fixed:OptimalBlocks@0.2 | 50 | `~1` | score | 0.104 | 0.896 | -0.14 | 0.1 | 0.9 | ok |
| Fixed:OptimalBlocks@0.2 | 200 | `~1` | score | 0.119 | 0.881 | -0.051 | 0.1 | 0.9 | ok |
| Fixed:OptimalBlocks@0.2 | 1000 | `~1` | score | 0.132 | 0.868 | 0.024 | 0.0625 | 0.938 | **FAIL** |
| Fixed:OptimalBlocks@0.2 | 50 | `~1` | wald | 0.081 | 0.919 | -0.14 | 0.1 | 0.9 | ok |
| Fixed:OptimalBlocks@0.2 | 200 | `~1` | wald | 0.049 | 0.951 | -0.051 | 0.1 | 0.9 | ok |
| Fixed:OptimalBlocks@0.2 | 1000 | `~1` | wald | 0.044 | 0.956 | 0.024 | 0.0625 | 0.938 | ok |
| Fixed:Rerandomization | 50 | `~.` | gradient | 0.106 | 0.891 | -0.00062 | 0.1 | 0.9 | ok |
| Fixed:Rerandomization | 200 | `~.` | gradient | 0.048 | 0.952 | -0.0048 | 0.1 | 0.9 | ok |
| Fixed:Rerandomization | 1000 | `~.` | gradient | 0.054 | 0.946 | 0.014 | 0.0525 | 0.948 | ok |
| Fixed:Rerandomization | 50 | `~.` | lik_ratio | 0.1 | 0.913 | -0.00062 | 0.1 | 0.9 | ok |
| Fixed:Rerandomization | 200 | `~.` | lik_ratio | 0.048 | 0.952 | -0.0048 | 0.1 | 0.9 | ok |
| Fixed:Rerandomization | 1000 | `~.` | lik_ratio | 0.054 | 0.946 | 0.014 | 0.0525 | 0.948 | ok |
| Fixed:Rerandomization | 50 | `~.` | rand | 0.052 |  | -0.00062 | 0.05 | 0.95 | ok |
| Fixed:Rerandomization | 200 | `~.` | rand | 0.048 |  | -0.0048 | 0.05 | 0.95 | ok |
| Fixed:Rerandomization | 1000 | `~.` | rand | 0.057 |  | 0.014 | 0.05 | 0.95 | ok |
| Fixed:Rerandomization | 50 | `~.` | score | 0.122 | 0.894 | -0.00062 | 0.1 | 0.9 | ok |
| Fixed:Rerandomization | 200 | `~.` | score | 0.048 | 0.952 | -0.0048 | 0.1 | 0.9 | ok |
| Fixed:Rerandomization | 1000 | `~.` | score | 0.054 | 0.946 | 0.014 | 0.0525 | 0.948 | ok |
| Fixed:Rerandomization | 50 | `~.` | wald | 0.119 | 0.881 | -0.00062 | 0.1 | 0.9 | ok |
| Fixed:Rerandomization | 200 | `~.` | wald | 0.06 | 0.94 | -0.0048 | 0.1 | 0.9 | ok |
| Fixed:Rerandomization | 1000 | `~.` | wald | 0.056 | 0.944 | 0.014 | 0.0525 | 0.948 | ok |
| Fixed:Rerandomization | 50 | `~1` | gradient | 0.165 | 0.835 | 0.01 | 0.1 | 0.9 | **FAIL** |
| Fixed:Rerandomization | 200 | `~1` | gradient | 0.172 | 0.828 | -0.0098 | 0.1 | 0.9 | **FAIL** |
| Fixed:Rerandomization | 1000 | `~1` | gradient | 0.168 | 0.832 | 0.032 | 0.0525 | 0.948 | **FAIL** |
| Fixed:Rerandomization | 50 | `~1` | lik_ratio | 0.163 | 0.837 | 0.01 | 0.1 | 0.9 | **FAIL** |
| Fixed:Rerandomization | 200 | `~1` | lik_ratio | 0.172 | 0.828 | -0.0098 | 0.1 | 0.9 | **FAIL** |
| Fixed:Rerandomization | 1000 | `~1` | lik_ratio | 0.168 | 0.832 | 0.032 | 0.0525 | 0.948 | **FAIL** |
| Fixed:Rerandomization | 50 | `~1` | rand | 0.065 |  | 0.01 | 0.05 | 0.95 | ok |
| Fixed:Rerandomization | 200 | `~1` | rand | 0.064 |  | -0.0098 | 0.05 | 0.95 | ok |
| Fixed:Rerandomization | 1000 | `~1` | rand | 0.059 |  | 0.032 | 0.05 | 0.95 | ok |
| Fixed:Rerandomization | 50 | `~1` | score | 0.16 | 0.84 | 0.01 | 0.1 | 0.9 | **FAIL** |
| Fixed:Rerandomization | 200 | `~1` | score | 0.172 | 0.828 | -0.0098 | 0.1 | 0.9 | **FAIL** |
| Fixed:Rerandomization | 1000 | `~1` | score | 0.168 | 0.832 | 0.032 | 0.0525 | 0.948 | **FAIL** |
| Fixed:Rerandomization | 50 | `~1` | wald | 0.084 | 0.916 | 0.01 | 0.1 | 0.9 | ok |
| Fixed:Rerandomization | 200 | `~1` | wald | 0.067 | 0.933 | -0.0098 | 0.1 | 0.9 | ok |
| Fixed:Rerandomization | 1000 | `~1` | wald | 0.058 | 0.942 | 0.032 | 0.0525 | 0.948 | ok |
| Fixed:Rerandomization@0.2 | 50 | `~.` | gradient | 0.1 | 0.904 | -0.067 | 0.1 | 0.9 | ok |
| Fixed:Rerandomization@0.2 | 200 | `~.` | gradient | 0.059 | 0.941 | -0.14 | 0.1 | 0.9 | ok |
| Fixed:Rerandomization@0.2 | 1000 | `~.` | gradient | 0.047 | 0.953 | -0.035 | 0.0625 | 0.938 | ok |
| Fixed:Rerandomization@0.2 | 50 | `~.` | lik_ratio | 0.094 | 0.911 | -0.067 | 0.1 | 0.9 | ok |
| Fixed:Rerandomization@0.2 | 200 | `~.` | lik_ratio | 0.056 | 0.944 | -0.14 | 0.1 | 0.9 | ok |
| Fixed:Rerandomization@0.2 | 1000 | `~.` | lik_ratio | 0.047 | 0.953 | -0.035 | 0.0625 | 0.938 | ok |
| Fixed:Rerandomization@0.2 | 50 | `~.` | rand | 0.062 |  | -0.067 | 0.05 | 0.95 | ok |
| Fixed:Rerandomization@0.2 | 200 | `~.` | rand | 0.082 |  | -0.14 | 0.05 | 0.95 | **FAIL** |
| Fixed:Rerandomization@0.2 | 1000 | `~.` | rand | 0.046 |  | -0.035 | 0.05 | 0.95 | ok |
| Fixed:Rerandomization@0.2 | 50 | `~.` | score | 0.109 | 0.907 | -0.067 | 0.1 | 0.9 | ok |
| Fixed:Rerandomization@0.2 | 200 | `~.` | score | 0.052 | 0.948 | -0.14 | 0.1 | 0.9 | ok |
| Fixed:Rerandomization@0.2 | 1000 | `~.` | score | 0.044 | 0.956 | -0.035 | 0.0625 | 0.938 | ok |
| Fixed:Rerandomization@0.2 | 50 | `~.` | wald | 0.125 | 0.875 | -0.067 | 0.1 | 0.9 | ok |
| Fixed:Rerandomization@0.2 | 200 | `~.` | wald | 0.066 | 0.934 | -0.14 | 0.1 | 0.9 | ok |
| Fixed:Rerandomization@0.2 | 1000 | `~.` | wald | 0.049 | 0.951 | -0.035 | 0.0625 | 0.938 | ok |
| Fixed:Rerandomization@0.2 | 50 | `~1` | gradient | 0.162 | 0.838 | -0.17 | 0.1 | 0.9 | **FAIL** |
| Fixed:Rerandomization@0.2 | 200 | `~1` | gradient | 0.152 | 0.848 | -0.12 | 0.1 | 0.9 | **FAIL** |
| Fixed:Rerandomization@0.2 | 1000 | `~1` | gradient | 0.151 | 0.849 | -0.032 | 0.0625 | 0.938 | **FAIL** |
| Fixed:Rerandomization@0.2 | 50 | `~1` | lik_ratio | 0.161 | 0.839 | -0.17 | 0.1 | 0.9 | **FAIL** |
| Fixed:Rerandomization@0.2 | 200 | `~1` | lik_ratio | 0.146 | 0.854 | -0.12 | 0.1 | 0.9 | **FAIL** |
| Fixed:Rerandomization@0.2 | 1000 | `~1` | lik_ratio | 0.154 | 0.846 | -0.032 | 0.0625 | 0.938 | **FAIL** |
| Fixed:Rerandomization@0.2 | 50 | `~1` | rand | 0.178 |  | -0.17 | 0.05 | 0.95 | **FAIL** |
| Fixed:Rerandomization@0.2 | 200 | `~1` | rand | 0.037 |  | -0.12 | 0.05 | 0.95 | ok |
| Fixed:Rerandomization@0.2 | 1000 | `~1` | rand | 0.045 |  | -0.032 | 0.05 | 0.95 | ok |
| Fixed:Rerandomization@0.2 | 50 | `~1` | score | 0.157 | 0.843 | -0.17 | 0.1 | 0.9 | **FAIL** |
| Fixed:Rerandomization@0.2 | 200 | `~1` | score | 0.149 | 0.851 | -0.12 | 0.1 | 0.9 | **FAIL** |
| Fixed:Rerandomization@0.2 | 1000 | `~1` | score | 0.153 | 0.847 | -0.032 | 0.0625 | 0.938 | **FAIL** |
| Fixed:Rerandomization@0.2 | 50 | `~1` | wald | 0.124 | 0.876 | -0.17 | 0.1 | 0.9 | ok |
| Fixed:Rerandomization@0.2 | 200 | `~1` | wald | 0.046 | 0.954 | -0.12 | 0.1 | 0.9 | ok |
| Fixed:Rerandomization@0.2 | 1000 | `~1` | wald | 0.05 | 0.95 | -0.032 | 0.0625 | 0.938 | ok |
| SeqOneByOne:Atkinson | 50 | `~.` | gradient | 0.1 | 0.903 | 0.052 | 0.1 | 0.9 | ok |
| SeqOneByOne:Atkinson | 200 | `~.` | gradient | 0.045 | 0.955 | -0.048 | 0.1 | 0.9 | ok |
| SeqOneByOne:Atkinson | 1000 | `~.` | gradient | 0.048 | 0.952 | 0.014 | 0.0525 | 0.948 | ok |
| SeqOneByOne:Atkinson | 50 | `~.` | lik_ratio | 0.09 | 0.916 | 0.052 | 0.1 | 0.9 | ok |
| SeqOneByOne:Atkinson | 200 | `~.` | lik_ratio | 0.044 | 0.956 | -0.048 | 0.1 | 0.9 | ok |
| SeqOneByOne:Atkinson | 1000 | `~.` | lik_ratio | 0.048 | 0.952 | 0.014 | 0.0525 | 0.948 | ok |
| SeqOneByOne:Atkinson | 50 | `~.` | rand | 0.051 |  | 0.052 | 0.05 | 0.95 | ok |
| SeqOneByOne:Atkinson | 200 | `~.` | rand | 0.047 |  | -0.048 | 0.05 | 0.95 | ok |
| SeqOneByOne:Atkinson | 1000 | `~.` | rand | 0.053 |  | 0.014 | 0.05 | 0.95 | ok |
| SeqOneByOne:Atkinson | 50 | `~.` | score | 0.114 | 0.904 | 0.052 | 0.1 | 0.9 | ok |
| SeqOneByOne:Atkinson | 200 | `~.` | score | 0.045 | 0.955 | -0.048 | 0.1 | 0.9 | ok |
| SeqOneByOne:Atkinson | 1000 | `~.` | score | 0.048 | 0.952 | 0.014 | 0.0525 | 0.948 | ok |
| SeqOneByOne:Atkinson | 50 | `~.` | wald | 0.103 | 0.897 | 0.052 | 0.1 | 0.9 | ok |
| SeqOneByOne:Atkinson | 200 | `~.` | wald | 0.057 | 0.943 | -0.048 | 0.1 | 0.9 | ok |
| SeqOneByOne:Atkinson | 1000 | `~.` | wald | 0.051 | 0.949 | 0.014 | 0.0525 | 0.948 | ok |
| SeqOneByOne:Atkinson | 50 | `~1` | gradient | 0.147 | 0.853 | 0.036 | 0.1 | 0.9 | ok |
| SeqOneByOne:Atkinson | 200 | `~1` | gradient | 0.103 | 0.897 | -0.03 | 0.1 | 0.9 | ok |
| SeqOneByOne:Atkinson | 1000 | `~1` | gradient | 0.116 | 0.884 | 0.042 | 0.0525 | 0.948 | **FAIL** |
| SeqOneByOne:Atkinson | 50 | `~1` | lik_ratio | 0.144 | 0.856 | 0.036 | 0.1 | 0.9 | ok |
| SeqOneByOne:Atkinson | 200 | `~1` | lik_ratio | 0.103 | 0.897 | -0.03 | 0.1 | 0.9 | ok |
| SeqOneByOne:Atkinson | 1000 | `~1` | lik_ratio | 0.116 | 0.884 | 0.042 | 0.0525 | 0.948 | **FAIL** |
| SeqOneByOne:Atkinson | 50 | `~1` | rand | 0.073 |  | 0.036 | 0.05 | 0.95 | ok |
| SeqOneByOne:Atkinson | 200 | `~1` | rand | 0.044 |  | -0.03 | 0.05 | 0.95 | ok |
| SeqOneByOne:Atkinson | 1000 | `~1` | rand | 0.04 |  | 0.042 | 0.05 | 0.95 | ok |
| SeqOneByOne:Atkinson | 50 | `~1` | score | 0.139 | 0.861 | 0.036 | 0.1 | 0.9 | ok |
| SeqOneByOne:Atkinson | 200 | `~1` | score | 0.101 | 0.899 | -0.03 | 0.1 | 0.9 | ok |
| SeqOneByOne:Atkinson | 1000 | `~1` | score | 0.116 | 0.884 | 0.042 | 0.0525 | 0.948 | **FAIL** |
| SeqOneByOne:Atkinson | 50 | `~1` | wald | 0.064 | 0.936 | 0.036 | 0.1 | 0.9 | ok |
| SeqOneByOne:Atkinson | 200 | `~1` | wald | 0.033 | 0.967 | -0.03 | 0.1 | 0.9 | ok |
| SeqOneByOne:Atkinson | 1000 | `~1` | wald | 0.028 | 0.972 | 0.042 | 0.0525 | 0.948 | ok |
| SeqOneByOne:Bernoulli | 50 | `~.` | gradient | 0.0871 | 0.912 | 0.015 | 0.1 | 0.9 | ok |
| SeqOneByOne:Bernoulli | 200 | `~.` | gradient | 0.052 | 0.948 | 0.093 | 0.1 | 0.9 | ok |
| SeqOneByOne:Bernoulli | 1000 | `~.` | gradient | 0.034 | 0.966 | -0.0038 | 0.0525 | 0.948 | ok |
| SeqOneByOne:Bernoulli | 50 | `~.` | lik_ratio | 0.0791 | 0.927 | 0.015 | 0.1 | 0.9 | ok |
| SeqOneByOne:Bernoulli | 200 | `~.` | lik_ratio | 0.052 | 0.948 | 0.093 | 0.1 | 0.9 | ok |
| SeqOneByOne:Bernoulli | 1000 | `~.` | lik_ratio | 0.034 | 0.966 | -0.0038 | 0.0525 | 0.948 | ok |
| SeqOneByOne:Bernoulli | 50 | `~.` | rand | 0.045 |  | 0.015 | 0.05 | 0.95 | ok |
| SeqOneByOne:Bernoulli | 200 | `~.` | rand | 0.05 |  | 0.093 | 0.05 | 0.95 | ok |
| SeqOneByOne:Bernoulli | 1000 | `~.` | rand | 0.033 |  | -0.0038 | 0.05 | 0.95 | ok |
| SeqOneByOne:Bernoulli | 50 | `~.` | score | 0.103 | 0.913 | 0.015 | 0.1 | 0.9 | ok |
| SeqOneByOne:Bernoulli | 200 | `~.` | score | 0.053 | 0.947 | 0.093 | 0.1 | 0.9 | ok |
| SeqOneByOne:Bernoulli | 1000 | `~.` | score | 0.033 | 0.967 | -0.0038 | 0.0525 | 0.948 | ok |
| SeqOneByOne:Bernoulli | 50 | `~.` | wald | 0.116 | 0.884 | 0.015 | 0.1 | 0.9 | ok |
| SeqOneByOne:Bernoulli | 200 | `~.` | wald | 0.062 | 0.938 | 0.093 | 0.1 | 0.9 | ok |
| SeqOneByOne:Bernoulli | 1000 | `~.` | wald | 0.032 | 0.968 | -0.0038 | 0.0525 | 0.948 | ok |
| SeqOneByOne:Bernoulli | 50 | `~1` | gradient | 0.163 | 0.837 | -0.062 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:Bernoulli | 200 | `~1` | gradient | 0.153 | 0.847 | 0.044 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:Bernoulli | 1000 | `~1` | gradient | 0.137 | 0.863 | -0.0023 | 0.0525 | 0.948 | **FAIL** |
| SeqOneByOne:Bernoulli | 50 | `~1` | lik_ratio | 0.161 | 0.839 | -0.062 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:Bernoulli | 200 | `~1` | lik_ratio | 0.153 | 0.847 | 0.044 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:Bernoulli | 1000 | `~1` | lik_ratio | 0.137 | 0.863 | -0.0023 | 0.0525 | 0.948 | **FAIL** |
| SeqOneByOne:Bernoulli | 50 | `~1` | rand | 0.054 |  | -0.062 | 0.05 | 0.95 | ok |
| SeqOneByOne:Bernoulli | 200 | `~1` | rand | 0.049 |  | 0.044 | 0.05 | 0.95 | ok |
| SeqOneByOne:Bernoulli | 1000 | `~1` | rand | 0.039 |  | -0.0023 | 0.05 | 0.95 | ok |
| SeqOneByOne:Bernoulli | 50 | `~1` | score | 0.154 | 0.846 | -0.062 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:Bernoulli | 200 | `~1` | score | 0.153 | 0.847 | 0.044 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:Bernoulli | 1000 | `~1` | score | 0.137 | 0.863 | -0.0023 | 0.0525 | 0.948 | **FAIL** |
| SeqOneByOne:Bernoulli | 50 | `~1` | wald | 0.077 | 0.923 | -0.062 | 0.1 | 0.9 | ok |
| SeqOneByOne:Bernoulli | 200 | `~1` | wald | 0.053 | 0.947 | 0.044 | 0.1 | 0.9 | ok |
| SeqOneByOne:Bernoulli | 1000 | `~1` | wald | 0.042 | 0.958 | -0.0023 | 0.0525 | 0.948 | ok |
| SeqOneByOne:Bernoulli@0.2 | 50 | `~.` | gradient | 0.078 | 0.923 | -0.027 | 0.1 | 0.9 | ok |
| SeqOneByOne:Bernoulli@0.2 | 200 | `~.` | gradient | 0.05 | 0.95 | -0.0036 | 0.1 | 0.9 | ok |
| SeqOneByOne:Bernoulli@0.2 | 1000 | `~.` | gradient | 0.059 | 0.941 | -0.024 | 0.0625 | 0.938 | ok |
| SeqOneByOne:Bernoulli@0.2 | 50 | `~.` | lik_ratio | 0.074 | 0.928 | -0.027 | 0.1 | 0.9 | ok |
| SeqOneByOne:Bernoulli@0.2 | 200 | `~.` | lik_ratio | 0.047 | 0.953 | -0.0036 | 0.1 | 0.9 | ok |
| SeqOneByOne:Bernoulli@0.2 | 1000 | `~.` | lik_ratio | 0.056 | 0.944 | -0.024 | 0.0625 | 0.938 | ok |
| SeqOneByOne:Bernoulli@0.2 | 50 | `~.` | rand | 0.052 |  | -0.027 | 0.05 | 0.95 | ok |
| SeqOneByOne:Bernoulli@0.2 | 200 | `~.` | rand | 0.103 |  | -0.0036 | 0.05 | 0.95 | **FAIL** |
| SeqOneByOne:Bernoulli@0.2 | 1000 | `~.` | rand | 0.054 |  | -0.024 | 0.05 | 0.95 | ok |
| SeqOneByOne:Bernoulli@0.2 | 50 | `~.` | score | 0.1 | 0.923 | -0.027 | 0.1 | 0.9 | ok |
| SeqOneByOne:Bernoulli@0.2 | 200 | `~.` | score | 0.047 | 0.953 | -0.0036 | 0.1 | 0.9 | ok |
| SeqOneByOne:Bernoulli@0.2 | 1000 | `~.` | score | 0.056 | 0.944 | -0.024 | 0.0625 | 0.938 | ok |
| SeqOneByOne:Bernoulli@0.2 | 50 | `~.` | wald | 0.123 | 0.877 | -0.027 | 0.1 | 0.9 | ok |
| SeqOneByOne:Bernoulli@0.2 | 200 | `~.` | wald | 0.063 | 0.937 | -0.0036 | 0.1 | 0.9 | ok |
| SeqOneByOne:Bernoulli@0.2 | 1000 | `~.` | wald | 0.058 | 0.942 | -0.024 | 0.0625 | 0.938 | ok |
| SeqOneByOne:Bernoulli@0.2 | 50 | `~1` | gradient | 0.17 | 0.83 | -0.17 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:Bernoulli@0.2 | 200 | `~1` | gradient | 0.153 | 0.847 | -0.11 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:Bernoulli@0.2 | 1000 | `~1` | gradient | 0.158 | 0.842 | -0.035 | 0.0625 | 0.938 | **FAIL** |
| SeqOneByOne:Bernoulli@0.2 | 50 | `~1` | lik_ratio | 0.154 | 0.846 | -0.17 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:Bernoulli@0.2 | 200 | `~1` | lik_ratio | 0.15 | 0.85 | -0.11 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:Bernoulli@0.2 | 1000 | `~1` | lik_ratio | 0.157 | 0.843 | -0.035 | 0.0625 | 0.938 | **FAIL** |
| SeqOneByOne:Bernoulli@0.2 | 50 | `~1` | rand | 0.177 |  | -0.17 | 0.05 | 0.95 | **FAIL** |
| SeqOneByOne:Bernoulli@0.2 | 200 | `~1` | rand | 0.053 |  | -0.11 | 0.05 | 0.95 | ok |
| SeqOneByOne:Bernoulli@0.2 | 1000 | `~1` | rand | 0.057 |  | -0.035 | 0.05 | 0.95 | ok |
| SeqOneByOne:Bernoulli@0.2 | 50 | `~1` | score | 0.149 | 0.851 | -0.17 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:Bernoulli@0.2 | 200 | `~1` | score | 0.15 | 0.85 | -0.11 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:Bernoulli@0.2 | 1000 | `~1` | score | 0.156 | 0.844 | -0.035 | 0.0625 | 0.938 | **FAIL** |
| SeqOneByOne:Bernoulli@0.2 | 50 | `~1` | wald | 0.145 | 0.855 | -0.17 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:Bernoulli@0.2 | 200 | `~1` | wald | 0.063 | 0.937 | -0.11 | 0.1 | 0.9 | ok |
| SeqOneByOne:Bernoulli@0.2 | 1000 | `~1` | wald | 0.056 | 0.944 | -0.035 | 0.0625 | 0.938 | ok |
| SeqOneByOne:Efron | 50 | `~.` | gradient | 0.095 | 0.907 | 0.014 | 0.1 | 0.9 | ok |
| SeqOneByOne:Efron | 200 | `~.` | gradient | 0.064 | 0.936 | 0.011 | 0.1 | 0.9 | ok |
| SeqOneByOne:Efron | 1000 | `~.` | gradient | 0.051 | 0.949 | 0.01 | 0.0525 | 0.948 | ok |
| SeqOneByOne:Efron | 50 | `~.` | lik_ratio | 0.092 | 0.915 | 0.014 | 0.1 | 0.9 | ok |
| SeqOneByOne:Efron | 200 | `~.` | lik_ratio | 0.064 | 0.936 | 0.011 | 0.1 | 0.9 | ok |
| SeqOneByOne:Efron | 1000 | `~.` | lik_ratio | 0.051 | 0.949 | 0.01 | 0.0525 | 0.948 | ok |
| SeqOneByOne:Efron | 50 | `~.` | rand | 0.049 |  | 0.014 | 0.05 | 0.95 | ok |
| SeqOneByOne:Efron | 200 | `~.` | rand | 0.057 |  | 0.011 | 0.05 | 0.95 | ok |
| SeqOneByOne:Efron | 1000 | `~.` | rand | 0.053 |  | 0.01 | 0.05 | 0.95 | ok |
| SeqOneByOne:Efron | 50 | `~.` | score | 0.118 | 0.903 | 0.014 | 0.1 | 0.9 | ok |
| SeqOneByOne:Efron | 200 | `~.` | score | 0.065 | 0.935 | 0.011 | 0.1 | 0.9 | ok |
| SeqOneByOne:Efron | 1000 | `~.` | score | 0.051 | 0.949 | 0.01 | 0.0525 | 0.948 | ok |
| SeqOneByOne:Efron | 50 | `~.` | wald | 0.114 | 0.886 | 0.014 | 0.1 | 0.9 | ok |
| SeqOneByOne:Efron | 200 | `~.` | wald | 0.063 | 0.937 | 0.011 | 0.1 | 0.9 | ok |
| SeqOneByOne:Efron | 1000 | `~.` | wald | 0.056 | 0.944 | 0.01 | 0.0525 | 0.948 | ok |
| SeqOneByOne:Efron | 50 | `~1` | gradient | 0.161 | 0.839 | -0.031 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:Efron | 200 | `~1` | gradient | 0.171 | 0.829 | 0.024 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:Efron | 1000 | `~1` | gradient | 0.147 | 0.853 | -0.0068 | 0.0525 | 0.948 | **FAIL** |
| SeqOneByOne:Efron | 50 | `~1` | lik_ratio | 0.161 | 0.839 | -0.031 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:Efron | 200 | `~1` | lik_ratio | 0.17 | 0.83 | 0.024 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:Efron | 1000 | `~1` | lik_ratio | 0.147 | 0.853 | -0.0068 | 0.0525 | 0.948 | **FAIL** |
| SeqOneByOne:Efron | 50 | `~1` | rand | 0.064 |  | -0.031 | 0.05 | 0.95 | ok |
| SeqOneByOne:Efron | 200 | `~1` | rand | 0.064 |  | 0.024 | 0.05 | 0.95 | ok |
| SeqOneByOne:Efron | 1000 | `~1` | rand | 0.046 |  | -0.0068 | 0.05 | 0.95 | ok |
| SeqOneByOne:Efron | 50 | `~1` | score | 0.162 | 0.838 | -0.031 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:Efron | 200 | `~1` | score | 0.17 | 0.83 | 0.024 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:Efron | 1000 | `~1` | score | 0.147 | 0.853 | -0.0068 | 0.0525 | 0.948 | **FAIL** |
| SeqOneByOne:Efron | 50 | `~1` | wald | 0.081 | 0.919 | -0.031 | 0.1 | 0.9 | ok |
| SeqOneByOne:Efron | 200 | `~1` | wald | 0.064 | 0.936 | 0.024 | 0.1 | 0.9 | ok |
| SeqOneByOne:Efron | 1000 | `~1` | wald | 0.045 | 0.955 | -0.0068 | 0.0525 | 0.948 | ok |
| SeqOneByOne:iBCRD | 50 | `~.` | gradient | 0.103 | 0.892 | -0.00053 | 0.1 | 0.9 | ok |
| SeqOneByOne:iBCRD | 200 | `~.` | gradient | 0.055 | 0.945 | -0.012 | 0.1 | 0.9 | ok |
| SeqOneByOne:iBCRD | 1000 | `~.` | gradient | 0.046 | 0.954 | -0.055 | 0.0525 | 0.948 | ok |
| SeqOneByOne:iBCRD | 50 | `~.` | lik_ratio | 0.1 | 0.908 | -0.00053 | 0.1 | 0.9 | ok |
| SeqOneByOne:iBCRD | 200 | `~.` | lik_ratio | 0.054 | 0.946 | -0.012 | 0.1 | 0.9 | ok |
| SeqOneByOne:iBCRD | 1000 | `~.` | lik_ratio | 0.046 | 0.954 | -0.055 | 0.0525 | 0.948 | ok |
| SeqOneByOne:iBCRD | 50 | `~.` | rand | 0.051 |  | -0.00053 | 0.05 | 0.95 | ok |
| SeqOneByOne:iBCRD | 200 | `~.` | rand | 0.054 |  | -0.012 | 0.05 | 0.95 | ok |
| SeqOneByOne:iBCRD | 1000 | `~.` | rand | 0.051 |  | -0.055 | 0.05 | 0.95 | ok |
| SeqOneByOne:iBCRD | 50 | `~.` | score | 0.116 | 0.896 | -0.00053 | 0.1 | 0.9 | ok |
| SeqOneByOne:iBCRD | 200 | `~.` | score | 0.053 | 0.947 | -0.012 | 0.1 | 0.9 | ok |
| SeqOneByOne:iBCRD | 1000 | `~.` | score | 0.045 | 0.955 | -0.055 | 0.0525 | 0.948 | ok |
| SeqOneByOne:iBCRD | 50 | `~.` | wald | 0.126 | 0.874 | -0.00053 | 0.1 | 0.9 | ok |
| SeqOneByOne:iBCRD | 200 | `~.` | wald | 0.062 | 0.938 | -0.012 | 0.1 | 0.9 | ok |
| SeqOneByOne:iBCRD | 1000 | `~.` | wald | 0.05 | 0.95 | -0.055 | 0.0525 | 0.948 | ok |
| SeqOneByOne:iBCRD | 50 | `~1` | gradient | 0.182 | 0.818 | -0.048 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:iBCRD | 200 | `~1` | gradient | 0.156 | 0.844 | 0.016 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:iBCRD | 1000 | `~1` | gradient | 0.159 | 0.841 | -0.0011 | 0.0525 | 0.948 | **FAIL** |
| SeqOneByOne:iBCRD | 50 | `~1` | lik_ratio | 0.18 | 0.82 | -0.048 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:iBCRD | 200 | `~1` | lik_ratio | 0.156 | 0.844 | 0.016 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:iBCRD | 1000 | `~1` | lik_ratio | 0.159 | 0.841 | -0.0011 | 0.0525 | 0.948 | **FAIL** |
| SeqOneByOne:iBCRD | 50 | `~1` | rand | 0.062 |  | -0.048 | 0.05 | 0.95 | ok |
| SeqOneByOne:iBCRD | 200 | `~1` | rand | 0.05 |  | 0.016 | 0.05 | 0.95 | ok |
| SeqOneByOne:iBCRD | 1000 | `~1` | rand | 0.045 |  | -0.0011 | 0.05 | 0.95 | ok |
| SeqOneByOne:iBCRD | 50 | `~1` | score | 0.178 | 0.822 | -0.048 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:iBCRD | 200 | `~1` | score | 0.155 | 0.845 | 0.016 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:iBCRD | 1000 | `~1` | score | 0.158 | 0.842 | -0.0011 | 0.0525 | 0.948 | **FAIL** |
| SeqOneByOne:iBCRD | 50 | `~1` | wald | 0.091 | 0.909 | -0.048 | 0.1 | 0.9 | ok |
| SeqOneByOne:iBCRD | 200 | `~1` | wald | 0.058 | 0.942 | 0.016 | 0.1 | 0.9 | ok |
| SeqOneByOne:iBCRD | 1000 | `~1` | wald | 0.047 | 0.953 | -0.0011 | 0.0525 | 0.948 | ok |
| SeqOneByOne:iBCRD@0.2 | 50 | `~.` | gradient | 0.1 | 0.901 | -0.023 | 0.1 | 0.9 | ok |
| SeqOneByOne:iBCRD@0.2 | 200 | `~.` | gradient | 0.055 | 0.945 | -0.021 | 0.1 | 0.9 | ok |
| SeqOneByOne:iBCRD@0.2 | 1000 | `~.` | gradient | 0.059 | 0.941 | -0.04 | 0.0625 | 0.938 | ok |
| SeqOneByOne:iBCRD@0.2 | 50 | `~.` | lik_ratio | 0.093 | 0.913 | -0.023 | 0.1 | 0.9 | ok |
| SeqOneByOne:iBCRD@0.2 | 200 | `~.` | lik_ratio | 0.051 | 0.949 | -0.021 | 0.1 | 0.9 | ok |
| SeqOneByOne:iBCRD@0.2 | 1000 | `~.` | lik_ratio | 0.059 | 0.941 | -0.04 | 0.0625 | 0.938 | ok |
| SeqOneByOne:iBCRD@0.2 | 50 | `~.` | rand | 0.062 |  | -0.023 | 0.05 | 0.95 | ok |
| SeqOneByOne:iBCRD@0.2 | 200 | `~.` | rand | 0.086 |  | -0.021 | 0.05 | 0.95 | **FAIL** |
| SeqOneByOne:iBCRD@0.2 | 1000 | `~.` | rand | 0.056 |  | -0.04 | 0.05 | 0.95 | ok |
| SeqOneByOne:iBCRD@0.2 | 50 | `~.` | score | 0.11 | 0.905 | -0.023 | 0.1 | 0.9 | ok |
| SeqOneByOne:iBCRD@0.2 | 200 | `~.` | score | 0.048 | 0.951 | -0.021 | 0.1 | 0.9 | ok |
| SeqOneByOne:iBCRD@0.2 | 1000 | `~.` | score | 0.058 | 0.942 | -0.04 | 0.0625 | 0.938 | ok |
| SeqOneByOne:iBCRD@0.2 | 50 | `~.` | wald | 0.127 | 0.873 | -0.023 | 0.1 | 0.9 | ok |
| SeqOneByOne:iBCRD@0.2 | 200 | `~.` | wald | 0.068 | 0.932 | -0.021 | 0.1 | 0.9 | ok |
| SeqOneByOne:iBCRD@0.2 | 1000 | `~.` | wald | 0.06 | 0.94 | -0.04 | 0.0625 | 0.938 | ok |
| SeqOneByOne:iBCRD@0.2 | 50 | `~1` | gradient | 0.156 | 0.844 | -0.17 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:iBCRD@0.2 | 200 | `~1` | gradient | 0.156 | 0.844 | -0.094 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:iBCRD@0.2 | 1000 | `~1` | gradient | 0.157 | 0.843 | -0.041 | 0.0625 | 0.938 | **FAIL** |
| SeqOneByOne:iBCRD@0.2 | 50 | `~1` | lik_ratio | 0.152 | 0.848 | -0.17 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:iBCRD@0.2 | 200 | `~1` | lik_ratio | 0.155 | 0.845 | -0.094 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:iBCRD@0.2 | 1000 | `~1` | lik_ratio | 0.156 | 0.844 | -0.041 | 0.0625 | 0.938 | **FAIL** |
| SeqOneByOne:iBCRD@0.2 | 50 | `~1` | rand | 0.173 |  | -0.17 | 0.05 | 0.95 | **FAIL** |
| SeqOneByOne:iBCRD@0.2 | 200 | `~1` | rand | 0.053 |  | -0.094 | 0.05 | 0.95 | ok |
| SeqOneByOne:iBCRD@0.2 | 1000 | `~1` | rand | 0.045 |  | -0.041 | 0.05 | 0.95 | ok |
| SeqOneByOne:iBCRD@0.2 | 50 | `~1` | score | 0.15 | 0.85 | -0.17 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:iBCRD@0.2 | 200 | `~1` | score | 0.16 | 0.84 | -0.094 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:iBCRD@0.2 | 1000 | `~1` | score | 0.158 | 0.842 | -0.041 | 0.0625 | 0.938 | **FAIL** |
| SeqOneByOne:iBCRD@0.2 | 50 | `~1` | wald | 0.145 | 0.855 | -0.17 | 0.1 | 0.9 | ok |
| SeqOneByOne:iBCRD@0.2 | 200 | `~1` | wald | 0.064 | 0.936 | -0.094 | 0.1 | 0.9 | ok |
| SeqOneByOne:iBCRD@0.2 | 1000 | `~1` | wald | 0.055 | 0.945 | -0.041 | 0.0625 | 0.938 | ok |
| SeqOneByOne:KK14 | 50 | `~.` | gradient | 0.121 | 0.877 | -0.041 | 0.1 | 0.9 | ok |
| SeqOneByOne:KK14 | 200 | `~.` | gradient | 0.052 | 0.948 | 0.041 | 0.1 | 0.9 | ok |
| SeqOneByOne:KK14 | 1000 | `~.` | gradient | 0.04 | 0.96 | 0.0031 | 0.0525 | 0.948 | ok |
| SeqOneByOne:KK14 | 50 | `~.` | lik_ratio | 0.111 | 0.898 | -0.041 | 0.1 | 0.9 | ok |
| SeqOneByOne:KK14 | 200 | `~.` | lik_ratio | 0.052 | 0.948 | 0.041 | 0.1 | 0.9 | ok |
| SeqOneByOne:KK14 | 1000 | `~.` | lik_ratio | 0.04 | 0.96 | 0.0031 | 0.0525 | 0.948 | ok |
| SeqOneByOne:KK14 | 50 | `~.` | rand | 0.078 |  | -0.041 | 0.05 | 0.95 | ok |
| SeqOneByOne:KK14 | 200 | `~.` | rand | 0.057 |  | 0.041 | 0.05 | 0.95 | ok |
| SeqOneByOne:KK14 | 1000 | `~.` | rand | 0.038 |  | 0.0031 | 0.05 | 0.95 | ok |
| SeqOneByOne:KK14 | 50 | `~.` | score | 0.131 | 0.88 | -0.041 | 0.1 | 0.9 | ok |
| SeqOneByOne:KK14 | 200 | `~.` | score | 0.053 | 0.947 | 0.041 | 0.1 | 0.9 | ok |
| SeqOneByOne:KK14 | 1000 | `~.` | score | 0.04 | 0.96 | 0.0031 | 0.0525 | 0.948 | ok |
| SeqOneByOne:KK14 | 50 | `~.` | wald | 0.13 | 0.87 | -0.041 | 0.1 | 0.9 | ok |
| SeqOneByOne:KK14 | 200 | `~.` | wald | 0.055 | 0.945 | 0.041 | 0.1 | 0.9 | ok |
| SeqOneByOne:KK14 | 1000 | `~.` | wald | 0.041 | 0.959 | 0.0031 | 0.0525 | 0.948 | ok |
| SeqOneByOne:KK14 | 50 | `~1` | gradient | 0.158 | 0.842 | -0.03 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:KK14 | 200 | `~1` | gradient | 0.104 | 0.896 | 0.0036 | 0.1 | 0.9 | ok |
| SeqOneByOne:KK14 | 1000 | `~1` | gradient | 0.11 | 0.89 | -0.0041 | 0.0525 | 0.948 | **FAIL** |
| SeqOneByOne:KK14 | 50 | `~1` | lik_ratio | 0.155 | 0.845 | -0.03 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:KK14 | 200 | `~1` | lik_ratio | 0.1 | 0.9 | 0.0036 | 0.1 | 0.9 | ok |
| SeqOneByOne:KK14 | 1000 | `~1` | lik_ratio | 0.11 | 0.89 | -0.0041 | 0.0525 | 0.948 | **FAIL** |
| SeqOneByOne:KK14 | 50 | `~1` | rand | 0.08 |  | -0.03 | 0.05 | 0.95 | ok |
| SeqOneByOne:KK14 | 200 | `~1` | rand | 0.051 |  | 0.0036 | 0.05 | 0.95 | ok |
| SeqOneByOne:KK14 | 1000 | `~1` | rand | 0.052 |  | -0.0041 | 0.05 | 0.95 | ok |
| SeqOneByOne:KK14 | 50 | `~1` | score | 0.151 | 0.849 | -0.03 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:KK14 | 200 | `~1` | score | 0.1 | 0.9 | 0.0036 | 0.1 | 0.9 | ok |
| SeqOneByOne:KK14 | 1000 | `~1` | score | 0.11 | 0.89 | -0.0041 | 0.0525 | 0.948 | **FAIL** |
| SeqOneByOne:KK14 | 50 | `~1` | wald | 0.086 | 0.914 | -0.03 | 0.1 | 0.9 | ok |
| SeqOneByOne:KK14 | 200 | `~1` | wald | 0.033 | 0.967 | 0.0036 | 0.1 | 0.9 | ok |
| SeqOneByOne:KK14 | 1000 | `~1` | wald | 0.028 | 0.972 | -0.0041 | 0.0525 | 0.948 | ok |
| SeqOneByOne:KK21 | 50 | `~.` | gradient | 0.104 | 0.894 | -0.0075 | 0.1 | 0.9 | ok |
| SeqOneByOne:KK21 | 200 | `~.` | gradient | 0.061 | 0.939 | 0.035 | 0.1 | 0.9 | ok |
| SeqOneByOne:KK21 | 1000 | `~.` | gradient | 0.052 | 0.948 | 0.026 | 0.0525 | 0.948 | ok |
| SeqOneByOne:KK21 | 50 | `~.` | lik_ratio | 0.093 | 0.915 | -0.0075 | 0.1 | 0.9 | ok |
| SeqOneByOne:KK21 | 200 | `~.` | lik_ratio | 0.059 | 0.941 | 0.035 | 0.1 | 0.9 | ok |
| SeqOneByOne:KK21 | 1000 | `~.` | lik_ratio | 0.052 | 0.948 | 0.026 | 0.0525 | 0.948 | ok |
| SeqOneByOne:KK21 | 50 | `~.` | rand | 0.048 |  | -0.0075 | 0.05 | 0.95 | ok |
| SeqOneByOne:KK21 | 200 | `~.` | rand | 0.056 |  | 0.035 | 0.05 | 0.95 | ok |
| SeqOneByOne:KK21 | 1000 | `~.` | rand | 0.053 |  | 0.026 | 0.05 | 0.95 | ok |
| SeqOneByOne:KK21 | 50 | `~.` | score | 0.123 | 0.894 | -0.0075 | 0.1 | 0.9 | ok |
| SeqOneByOne:KK21 | 200 | `~.` | score | 0.06 | 0.94 | 0.035 | 0.1 | 0.9 | ok |
| SeqOneByOne:KK21 | 1000 | `~.` | score | 0.052 | 0.948 | 0.026 | 0.0525 | 0.948 | ok |
| SeqOneByOne:KK21 | 50 | `~.` | wald | 0.121 | 0.879 | -0.0075 | 0.1 | 0.9 | ok |
| SeqOneByOne:KK21 | 200 | `~.` | wald | 0.068 | 0.932 | 0.035 | 0.1 | 0.9 | ok |
| SeqOneByOne:KK21 | 1000 | `~.` | wald | 0.049 | 0.951 | 0.026 | 0.0525 | 0.948 | ok |
| SeqOneByOne:KK21 | 50 | `~1` | gradient | 0.128 | 0.872 | 0.035 | 0.1 | 0.9 | ok |
| SeqOneByOne:KK21 | 200 | `~1` | gradient | 0.121 | 0.879 | 0.051 | 0.1 | 0.9 | ok |
| SeqOneByOne:KK21 | 1000 | `~1` | gradient | 0.112 | 0.888 | 0.001 | 0.0525 | 0.948 | **FAIL** |
| SeqOneByOne:KK21 | 50 | `~1` | lik_ratio | 0.125 | 0.875 | 0.035 | 0.1 | 0.9 | ok |
| SeqOneByOne:KK21 | 200 | `~1` | lik_ratio | 0.119 | 0.881 | 0.051 | 0.1 | 0.9 | ok |
| SeqOneByOne:KK21 | 1000 | `~1` | lik_ratio | 0.112 | 0.888 | 0.001 | 0.0525 | 0.948 | **FAIL** |
| SeqOneByOne:KK21 | 50 | `~1` | rand | 0.055 |  | 0.035 | 0.05 | 0.95 | ok |
| SeqOneByOne:KK21 | 200 | `~1` | rand | 0.056 |  | 0.051 | 0.05 | 0.95 | ok |
| SeqOneByOne:KK21 | 1000 | `~1` | rand | 0.054 |  | 0.001 | 0.05 | 0.95 | ok |
| SeqOneByOne:KK21 | 50 | `~1` | score | 0.122 | 0.878 | 0.035 | 0.1 | 0.9 | ok |
| SeqOneByOne:KK21 | 200 | `~1` | score | 0.12 | 0.88 | 0.051 | 0.1 | 0.9 | ok |
| SeqOneByOne:KK21 | 1000 | `~1` | score | 0.112 | 0.888 | 0.001 | 0.0525 | 0.948 | **FAIL** |
| SeqOneByOne:KK21 | 50 | `~1` | wald | 0.047 | 0.953 | 0.035 | 0.1 | 0.9 | ok |
| SeqOneByOne:KK21 | 200 | `~1` | wald | 0.044 | 0.956 | 0.051 | 0.1 | 0.9 | ok |
| SeqOneByOne:KK21 | 1000 | `~1` | wald | 0.031 | 0.969 | 0.001 | 0.0525 | 0.948 | ok |
| SeqOneByOne:KK21stepwise | 50 | `~.` | gradient | 0.098 | 0.901 | -0.0066 | 0.1 | 0.9 | ok |
| SeqOneByOne:KK21stepwise | 200 | `~.` | gradient | 0.057 | 0.943 | 0.07 | 0.1 | 0.9 | ok |
| SeqOneByOne:KK21stepwise | 1000 | `~.` | gradient | 0.047 | 0.953 | 0.014 | 0.0525 | 0.948 | ok |
| SeqOneByOne:KK21stepwise | 50 | `~.` | lik_ratio | 0.091 | 0.918 | -0.0066 | 0.1 | 0.9 | ok |
| SeqOneByOne:KK21stepwise | 200 | `~.` | lik_ratio | 0.057 | 0.943 | 0.07 | 0.1 | 0.9 | ok |
| SeqOneByOne:KK21stepwise | 1000 | `~.` | lik_ratio | 0.047 | 0.953 | 0.014 | 0.0525 | 0.948 | ok |
| SeqOneByOne:KK21stepwise | 50 | `~.` | rand | 0.059 |  | -0.0066 | 0.05 | 0.95 | ok |
| SeqOneByOne:KK21stepwise | 200 | `~.` | rand | 0.058 |  | 0.07 | 0.05 | 0.95 | ok |
| SeqOneByOne:KK21stepwise | 1000 | `~.` | rand | 0.05 |  | 0.014 | 0.05 | 0.95 | ok |
| SeqOneByOne:KK21stepwise | 50 | `~.` | score | 0.118 | 0.898 | -0.0066 | 0.1 | 0.9 | ok |
| SeqOneByOne:KK21stepwise | 200 | `~.` | score | 0.056 | 0.944 | 0.07 | 0.1 | 0.9 | ok |
| SeqOneByOne:KK21stepwise | 1000 | `~.` | score | 0.047 | 0.953 | 0.014 | 0.0525 | 0.948 | ok |
| SeqOneByOne:KK21stepwise | 50 | `~.` | wald | 0.111 | 0.889 | -0.0066 | 0.1 | 0.9 | ok |
| SeqOneByOne:KK21stepwise | 200 | `~.` | wald | 0.06 | 0.94 | 0.07 | 0.1 | 0.9 | ok |
| SeqOneByOne:KK21stepwise | 1000 | `~.` | wald | 0.051 | 0.949 | 0.014 | 0.0525 | 0.948 | ok |
| SeqOneByOne:KK21stepwise | 50 | `~1` | gradient | 0.143 | 0.857 | -0.0086 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:KK21stepwise | 200 | `~1` | gradient | 0.114 | 0.886 | 0.022 | 0.1 | 0.9 | ok |
| SeqOneByOne:KK21stepwise | 1000 | `~1` | gradient | 0.108 | 0.892 | 0.011 | 0.0525 | 0.948 | **FAIL** |
| SeqOneByOne:KK21stepwise | 50 | `~1` | lik_ratio | 0.139 | 0.861 | -0.0086 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:KK21stepwise | 200 | `~1` | lik_ratio | 0.114 | 0.886 | 0.022 | 0.1 | 0.9 | ok |
| SeqOneByOne:KK21stepwise | 1000 | `~1` | lik_ratio | 0.108 | 0.892 | 0.011 | 0.0525 | 0.948 | **FAIL** |
| SeqOneByOne:KK21stepwise | 50 | `~1` | rand | 0.061 |  | -0.0086 | 0.05 | 0.95 | ok |
| SeqOneByOne:KK21stepwise | 200 | `~1` | rand | 0.051 |  | 0.022 | 0.05 | 0.95 | ok |
| SeqOneByOne:KK21stepwise | 1000 | `~1` | rand | 0.063 |  | 0.011 | 0.05 | 0.95 | ok |
| SeqOneByOne:KK21stepwise | 50 | `~1` | score | 0.136 | 0.864 | -0.0086 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:KK21stepwise | 200 | `~1` | score | 0.114 | 0.886 | 0.022 | 0.1 | 0.9 | ok |
| SeqOneByOne:KK21stepwise | 1000 | `~1` | score | 0.108 | 0.892 | 0.011 | 0.0525 | 0.948 | **FAIL** |
| SeqOneByOne:KK21stepwise | 50 | `~1` | wald | 0.063 | 0.937 | -0.0086 | 0.1 | 0.9 | ok |
| SeqOneByOne:KK21stepwise | 200 | `~1` | wald | 0.033 | 0.967 | 0.022 | 0.1 | 0.9 | ok |
| SeqOneByOne:KK21stepwise | 1000 | `~1` | wald | 0.042 | 0.958 | 0.011 | 0.0525 | 0.948 | ok |
| SeqOneByOne:PocockSimon | 50 | `~.` | gradient | 0.0991 | 0.898 | -0.0035 | 0.1 | 0.9 | ok |
| SeqOneByOne:PocockSimon | 200 | `~.` | gradient | 0.052 | 0.948 | -0.0084 | 0.1 | 0.9 | ok |
| SeqOneByOne:PocockSimon | 1000 | `~.` | gradient | 0.047 | 0.953 | 0.0042 | 0.0525 | 0.948 | ok |
| SeqOneByOne:PocockSimon | 50 | `~.` | lik_ratio | 0.0911 | 0.914 | -0.0035 | 0.1 | 0.9 | ok |
| SeqOneByOne:PocockSimon | 200 | `~.` | lik_ratio | 0.052 | 0.948 | -0.0084 | 0.1 | 0.9 | ok |
| SeqOneByOne:PocockSimon | 1000 | `~.` | lik_ratio | 0.047 | 0.953 | 0.0042 | 0.0525 | 0.948 | ok |
| SeqOneByOne:PocockSimon | 50 | `~.` | rand | 0.049 |  | -0.0035 | 0.05 | 0.95 | ok |
| SeqOneByOne:PocockSimon | 200 | `~.` | rand | 0.061 |  | -0.0084 | 0.05 | 0.95 | ok |
| SeqOneByOne:PocockSimon | 1000 | `~.` | rand | 0.051 |  | 0.0042 | 0.05 | 0.95 | ok |
| SeqOneByOne:PocockSimon | 50 | `~.` | score | 0.116 | 0.897 | -0.0035 | 0.1 | 0.9 | ok |
| SeqOneByOne:PocockSimon | 200 | `~.` | score | 0.052 | 0.948 | -0.0084 | 0.1 | 0.9 | ok |
| SeqOneByOne:PocockSimon | 1000 | `~.` | score | 0.047 | 0.953 | 0.0042 | 0.0525 | 0.948 | ok |
| SeqOneByOne:PocockSimon | 50 | `~.` | wald | 0.12 | 0.88 | -0.0035 | 0.1 | 0.9 | ok |
| SeqOneByOne:PocockSimon | 200 | `~.` | wald | 0.066 | 0.934 | -0.0084 | 0.1 | 0.9 | ok |
| SeqOneByOne:PocockSimon | 1000 | `~.` | wald | 0.048 | 0.952 | 0.0042 | 0.0525 | 0.948 | ok |
| SeqOneByOne:PocockSimon | 50 | `~1` | gradient | 0.157 | 0.843 | -0.043 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:PocockSimon | 200 | `~1` | gradient | 0.139 | 0.861 | -0.019 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:PocockSimon | 1000 | `~1` | gradient | 0.138 | 0.862 | 0.0015 | 0.0525 | 0.948 | **FAIL** |
| SeqOneByOne:PocockSimon | 50 | `~1` | lik_ratio | 0.155 | 0.845 | -0.043 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:PocockSimon | 200 | `~1` | lik_ratio | 0.139 | 0.861 | -0.019 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:PocockSimon | 1000 | `~1` | lik_ratio | 0.138 | 0.862 | 0.0015 | 0.0525 | 0.948 | **FAIL** |
| SeqOneByOne:PocockSimon | 50 | `~1` | rand | 0.062 |  | -0.043 | 0.05 | 0.95 | ok |
| SeqOneByOne:PocockSimon | 200 | `~1` | rand | 0.049 |  | -0.019 | 0.05 | 0.95 | ok |
| SeqOneByOne:PocockSimon | 1000 | `~1` | rand | 0.047 |  | 0.0015 | 0.05 | 0.95 | ok |
| SeqOneByOne:PocockSimon | 50 | `~1` | score | 0.153 | 0.847 | -0.043 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:PocockSimon | 200 | `~1` | score | 0.139 | 0.861 | -0.019 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:PocockSimon | 1000 | `~1` | score | 0.138 | 0.862 | 0.0015 | 0.0525 | 0.948 | **FAIL** |
| SeqOneByOne:PocockSimon | 50 | `~1` | wald | 0.078 | 0.922 | -0.043 | 0.1 | 0.9 | ok |
| SeqOneByOne:PocockSimon | 200 | `~1` | wald | 0.057 | 0.943 | -0.019 | 0.1 | 0.9 | ok |
| SeqOneByOne:PocockSimon | 1000 | `~1` | wald | 0.047 | 0.953 | 0.0015 | 0.0525 | 0.948 | ok |
| SeqOneByOne:RandomBlockSize | 50 | `~.` | gradient | 0.12 | 0.879 | -0.028 | 0.1 | 0.9 | ok |
| SeqOneByOne:RandomBlockSize | 200 | `~.` | gradient | 0.047 | 0.953 | 0.089 | 0.1 | 0.9 | ok |
| SeqOneByOne:RandomBlockSize | 1000 | `~.` | gradient | 0.055 | 0.945 | 0.024 | 0.0525 | 0.948 | ok |
| SeqOneByOne:RandomBlockSize | 50 | `~.` | lik_ratio | 0.108 | 0.898 | -0.028 | 0.1 | 0.9 | ok |
| SeqOneByOne:RandomBlockSize | 200 | `~.` | lik_ratio | 0.047 | 0.953 | 0.089 | 0.1 | 0.9 | ok |
| SeqOneByOne:RandomBlockSize | 1000 | `~.` | lik_ratio | 0.055 | 0.945 | 0.024 | 0.0525 | 0.948 | ok |
| SeqOneByOne:RandomBlockSize | 50 | `~.` | rand | 0.065 |  | -0.028 | 0.05 | 0.95 | ok |
| SeqOneByOne:RandomBlockSize | 200 | `~.` | rand | 0.051 |  | 0.089 | 0.05 | 0.95 | ok |
| SeqOneByOne:RandomBlockSize | 1000 | `~.` | rand | 0.061 |  | 0.024 | 0.05 | 0.95 | ok |
| SeqOneByOne:RandomBlockSize | 50 | `~.` | score | 0.131 | 0.884 | -0.028 | 0.1 | 0.9 | ok |
| SeqOneByOne:RandomBlockSize | 200 | `~.` | score | 0.047 | 0.953 | 0.089 | 0.1 | 0.9 | ok |
| SeqOneByOne:RandomBlockSize | 1000 | `~.` | score | 0.055 | 0.945 | 0.024 | 0.0525 | 0.948 | ok |
| SeqOneByOne:RandomBlockSize | 50 | `~.` | wald | 0.129 | 0.871 | -0.028 | 0.1 | 0.9 | ok |
| SeqOneByOne:RandomBlockSize | 200 | `~.` | wald | 0.057 | 0.943 | 0.089 | 0.1 | 0.9 | ok |
| SeqOneByOne:RandomBlockSize | 1000 | `~.` | wald | 0.056 | 0.944 | 0.024 | 0.0525 | 0.948 | ok |
| SeqOneByOne:RandomBlockSize | 50 | `~1` | gradient | 0.145 | 0.856 | -0.018 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:RandomBlockSize | 200 | `~1` | gradient | 0.141 | 0.859 | 0.019 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:RandomBlockSize | 1000 | `~1` | gradient | 0.155 | 0.845 | 0.058 | 0.0525 | 0.948 | **FAIL** |
| SeqOneByOne:RandomBlockSize | 50 | `~1` | lik_ratio | 0.143 | 0.857 | -0.018 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:RandomBlockSize | 200 | `~1` | lik_ratio | 0.139 | 0.861 | 0.019 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:RandomBlockSize | 1000 | `~1` | lik_ratio | 0.155 | 0.845 | 0.058 | 0.0525 | 0.948 | **FAIL** |
| SeqOneByOne:RandomBlockSize | 50 | `~1` | rand | 0.056 |  | -0.018 | 0.05 | 0.95 | ok |
| SeqOneByOne:RandomBlockSize | 200 | `~1` | rand | 0.053 |  | 0.019 | 0.05 | 0.95 | ok |
| SeqOneByOne:RandomBlockSize | 1000 | `~1` | rand | 0.042 |  | 0.058 | 0.05 | 0.95 | ok |
| SeqOneByOne:RandomBlockSize | 50 | `~1` | score | 0.137 | 0.863 | -0.018 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:RandomBlockSize | 200 | `~1` | score | 0.139 | 0.861 | 0.019 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:RandomBlockSize | 1000 | `~1` | score | 0.155 | 0.845 | 0.058 | 0.0525 | 0.948 | **FAIL** |
| SeqOneByOne:RandomBlockSize | 50 | `~1` | wald | 0.069 | 0.931 | -0.018 | 0.1 | 0.9 | ok |
| SeqOneByOne:RandomBlockSize | 200 | `~1` | wald | 0.057 | 0.943 | 0.019 | 0.1 | 0.9 | ok |
| SeqOneByOne:RandomBlockSize | 1000 | `~1` | wald | 0.04 | 0.96 | 0.058 | 0.0525 | 0.948 | ok |
| SeqOneByOne:RandomBlockSize@0.2 | 50 | `~.` | gradient | 0.106 | 0.89 | -0.019 | 0.1 | 0.9 | ok |
| SeqOneByOne:RandomBlockSize@0.2 | 200 | `~.` | gradient | 0.041 | 0.959 | -0.012 | 0.1 | 0.9 | ok |
| SeqOneByOne:RandomBlockSize@0.2 | 1000 | `~.` | gradient | 0.045 | 0.955 | -0.027 | 0.0625 | 0.938 | ok |
| SeqOneByOne:RandomBlockSize@0.2 | 50 | `~.` | lik_ratio | 0.103 | 0.903 | -0.019 | 0.1 | 0.9 | ok |
| SeqOneByOne:RandomBlockSize@0.2 | 200 | `~.` | lik_ratio | 0.042 | 0.958 | -0.012 | 0.1 | 0.9 | ok |
| SeqOneByOne:RandomBlockSize@0.2 | 1000 | `~.` | lik_ratio | 0.045 | 0.955 | -0.027 | 0.0625 | 0.938 | ok |
| SeqOneByOne:RandomBlockSize@0.2 | 50 | `~.` | rand | 0.0731 |  | -0.019 | 0.05 | 0.95 | ok |
| SeqOneByOne:RandomBlockSize@0.2 | 200 | `~.` | rand | 0.088 |  | -0.012 | 0.05 | 0.95 | **FAIL** |
| SeqOneByOne:RandomBlockSize@0.2 | 1000 | `~.` | rand | 0.052 |  | -0.027 | 0.05 | 0.95 | ok |
| SeqOneByOne:RandomBlockSize@0.2 | 50 | `~.` | score | 0.123 | 0.892 | -0.019 | 0.1 | 0.9 | ok |
| SeqOneByOne:RandomBlockSize@0.2 | 200 | `~.` | score | 0.042 | 0.958 | -0.012 | 0.1 | 0.9 | ok |
| SeqOneByOne:RandomBlockSize@0.2 | 1000 | `~.` | score | 0.041 | 0.959 | -0.027 | 0.0625 | 0.938 | ok |
| SeqOneByOne:RandomBlockSize@0.2 | 50 | `~.` | wald | 0.133 | 0.867 | -0.019 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:RandomBlockSize@0.2 | 200 | `~.` | wald | 0.053 | 0.947 | -0.012 | 0.1 | 0.9 | ok |
| SeqOneByOne:RandomBlockSize@0.2 | 1000 | `~.` | wald | 0.057 | 0.943 | -0.027 | 0.0625 | 0.938 | ok |
| SeqOneByOne:RandomBlockSize@0.2 | 50 | `~1` | gradient | 0.164 | 0.836 | -0.18 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:RandomBlockSize@0.2 | 200 | `~1` | gradient | 0.13 | 0.87 | -0.053 | 0.1 | 0.9 | ok |
| SeqOneByOne:RandomBlockSize@0.2 | 1000 | `~1` | gradient | 0.151 | 0.849 | -0.0078 | 0.0625 | 0.938 | **FAIL** |
| SeqOneByOne:RandomBlockSize@0.2 | 50 | `~1` | lik_ratio | 0.149 | 0.851 | -0.18 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:RandomBlockSize@0.2 | 200 | `~1` | lik_ratio | 0.121 | 0.879 | -0.053 | 0.1 | 0.9 | ok |
| SeqOneByOne:RandomBlockSize@0.2 | 1000 | `~1` | lik_ratio | 0.15 | 0.85 | -0.0078 | 0.0625 | 0.938 | **FAIL** |
| SeqOneByOne:RandomBlockSize@0.2 | 50 | `~1` | rand | 0.169 |  | -0.18 | 0.05 | 0.95 | **FAIL** |
| SeqOneByOne:RandomBlockSize@0.2 | 200 | `~1` | rand | 0.041 |  | -0.053 | 0.05 | 0.95 | ok |
| SeqOneByOne:RandomBlockSize@0.2 | 1000 | `~1` | rand | 0.049 |  | -0.0078 | 0.05 | 0.95 | ok |
| SeqOneByOne:RandomBlockSize@0.2 | 50 | `~1` | score | 0.141 | 0.859 | -0.18 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:RandomBlockSize@0.2 | 200 | `~1` | score | 0.118 | 0.882 | -0.053 | 0.1 | 0.9 | ok |
| SeqOneByOne:RandomBlockSize@0.2 | 1000 | `~1` | score | 0.152 | 0.848 | -0.0078 | 0.0625 | 0.938 | **FAIL** |
| SeqOneByOne:RandomBlockSize@0.2 | 50 | `~1` | wald | 0.112 | 0.888 | -0.18 | 0.1 | 0.9 | ok |
| SeqOneByOne:RandomBlockSize@0.2 | 200 | `~1` | wald | 0.053 | 0.947 | -0.053 | 0.1 | 0.9 | ok |
| SeqOneByOne:RandomBlockSize@0.2 | 1000 | `~1` | wald | 0.041 | 0.959 | -0.0078 | 0.0625 | 0.938 | ok |
| SeqOneByOne:SPBR | 50 | `~.` | gradient | 0.102 | 0.896 | 0.027 | 0.1 | 0.9 | ok |
| SeqOneByOne:SPBR | 200 | `~.` | gradient | 0.045 | 0.955 | -0.019 | 0.1 | 0.9 | ok |
| SeqOneByOne:SPBR | 1000 | `~.` | gradient | 0.048 | 0.952 | -0.038 | 0.0525 | 0.948 | ok |
| SeqOneByOne:SPBR | 50 | `~.` | lik_ratio | 0.091 | 0.917 | 0.027 | 0.1 | 0.9 | ok |
| SeqOneByOne:SPBR | 200 | `~.` | lik_ratio | 0.045 | 0.955 | -0.019 | 0.1 | 0.9 | ok |
| SeqOneByOne:SPBR | 1000 | `~.` | lik_ratio | 0.048 | 0.952 | -0.038 | 0.0525 | 0.948 | ok |
| SeqOneByOne:SPBR | 50 | `~.` | rand | 0.056 |  | 0.027 | 0.05 | 0.95 | ok |
| SeqOneByOne:SPBR | 200 | `~.` | rand | 0.047 |  | -0.019 | 0.05 | 0.95 | ok |
| SeqOneByOne:SPBR | 1000 | `~.` | rand | 0.05 |  | -0.038 | 0.05 | 0.95 | ok |
| SeqOneByOne:SPBR | 50 | `~.` | score | 0.127 | 0.892 | 0.027 | 0.1 | 0.9 | ok |
| SeqOneByOne:SPBR | 200 | `~.` | score | 0.047 | 0.953 | -0.019 | 0.1 | 0.9 | ok |
| SeqOneByOne:SPBR | 1000 | `~.` | score | 0.047 | 0.953 | -0.038 | 0.0525 | 0.948 | ok |
| SeqOneByOne:SPBR | 50 | `~.` | wald | 0.119 | 0.881 | 0.027 | 0.1 | 0.9 | ok |
| SeqOneByOne:SPBR | 200 | `~.` | wald | 0.06 | 0.94 | -0.019 | 0.1 | 0.9 | ok |
| SeqOneByOne:SPBR | 1000 | `~.` | wald | 0.048 | 0.952 | -0.038 | 0.0525 | 0.948 | ok |
| SeqOneByOne:SPBR | 50 | `~1` | gradient | 0.163 | 0.837 | 0.049 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:SPBR | 200 | `~1` | gradient | 0.149 | 0.851 | 0.0031 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:SPBR | 1000 | `~1` | gradient | 0.157 | 0.843 | -0.019 | 0.0525 | 0.948 | **FAIL** |
| SeqOneByOne:SPBR | 50 | `~1` | lik_ratio | 0.161 | 0.839 | 0.049 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:SPBR | 200 | `~1` | lik_ratio | 0.147 | 0.853 | 0.0031 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:SPBR | 1000 | `~1` | lik_ratio | 0.157 | 0.843 | -0.019 | 0.0525 | 0.948 | **FAIL** |
| SeqOneByOne:SPBR | 50 | `~1` | rand | 0.057 |  | 0.049 | 0.05 | 0.95 | ok |
| SeqOneByOne:SPBR | 200 | `~1` | rand | 0.035 |  | 0.0031 | 0.05 | 0.95 | ok |
| SeqOneByOne:SPBR | 1000 | `~1` | rand | 0.054 |  | -0.019 | 0.05 | 0.95 | ok |
| SeqOneByOne:SPBR | 50 | `~1` | score | 0.158 | 0.842 | 0.049 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:SPBR | 200 | `~1` | score | 0.147 | 0.853 | 0.0031 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:SPBR | 1000 | `~1` | score | 0.156 | 0.844 | -0.019 | 0.0525 | 0.948 | **FAIL** |
| SeqOneByOne:SPBR | 50 | `~1` | wald | 0.077 | 0.923 | 0.049 | 0.1 | 0.9 | ok |
| SeqOneByOne:SPBR | 200 | `~1` | wald | 0.039 | 0.961 | 0.0031 | 0.1 | 0.9 | ok |
| SeqOneByOne:SPBR | 1000 | `~1` | wald | 0.05 | 0.95 | -0.019 | 0.0525 | 0.948 | ok |
| SeqOneByOne:SPBR@0.2 | 50 | `~.` | gradient | 0.092 | 0.909 | -0.033 | 0.1 | 0.9 | ok |
| SeqOneByOne:SPBR@0.2 | 200 | `~.` | gradient | 0.057 | 0.943 | -0.025 | 0.1 | 0.9 | ok |
| SeqOneByOne:SPBR@0.2 | 1000 | `~.` | gradient | 0.039 | 0.961 | -0.029 | 0.0625 | 0.938 | ok |
| SeqOneByOne:SPBR@0.2 | 50 | `~.` | lik_ratio | 0.095 | 0.908 | -0.033 | 0.1 | 0.9 | ok |
| SeqOneByOne:SPBR@0.2 | 200 | `~.` | lik_ratio | 0.058 | 0.942 | -0.025 | 0.1 | 0.9 | ok |
| SeqOneByOne:SPBR@0.2 | 1000 | `~.` | lik_ratio | 0.041 | 0.959 | -0.029 | 0.0625 | 0.938 | ok |
| SeqOneByOne:SPBR@0.2 | 50 | `~.` | rand | 0.067 |  | -0.033 | 0.05 | 0.95 | ok |
| SeqOneByOne:SPBR@0.2 | 200 | `~.` | rand | 0.091 |  | -0.025 | 0.05 | 0.95 | **FAIL** |
| SeqOneByOne:SPBR@0.2 | 1000 | `~.` | rand | 0.041 |  | -0.029 | 0.05 | 0.95 | ok |
| SeqOneByOne:SPBR@0.2 | 50 | `~.` | score | 0.116 | 0.894 | -0.033 | 0.1 | 0.9 | ok |
| SeqOneByOne:SPBR@0.2 | 200 | `~.` | score | 0.054 | 0.946 | -0.025 | 0.1 | 0.9 | ok |
| SeqOneByOne:SPBR@0.2 | 1000 | `~.` | score | 0.043 | 0.957 | -0.029 | 0.0625 | 0.938 | ok |
| SeqOneByOne:SPBR@0.2 | 50 | `~.` | wald | 0.127 | 0.873 | -0.033 | 0.1 | 0.9 | ok |
| SeqOneByOne:SPBR@0.2 | 200 | `~.` | wald | 0.069 | 0.931 | -0.025 | 0.1 | 0.9 | ok |
| SeqOneByOne:SPBR@0.2 | 1000 | `~.` | wald | 0.044 | 0.956 | -0.029 | 0.0625 | 0.938 | ok |
| SeqOneByOne:SPBR@0.2 | 50 | `~1` | gradient | 0.162 | 0.838 | -0.16 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:SPBR@0.2 | 200 | `~1` | gradient | 0.161 | 0.839 | -0.048 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:SPBR@0.2 | 1000 | `~1` | gradient | 0.152 | 0.848 | -0.061 | 0.0625 | 0.938 | **FAIL** |
| SeqOneByOne:SPBR@0.2 | 50 | `~1` | lik_ratio | 0.16 | 0.84 | -0.16 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:SPBR@0.2 | 200 | `~1` | lik_ratio | 0.158 | 0.842 | -0.048 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:SPBR@0.2 | 1000 | `~1` | lik_ratio | 0.151 | 0.849 | -0.061 | 0.0625 | 0.938 | **FAIL** |
| SeqOneByOne:SPBR@0.2 | 50 | `~1` | rand | 0.177 |  | -0.16 | 0.05 | 0.95 | **FAIL** |
| SeqOneByOne:SPBR@0.2 | 200 | `~1` | rand | 0.06 |  | -0.048 | 0.05 | 0.95 | ok |
| SeqOneByOne:SPBR@0.2 | 1000 | `~1` | rand | 0.057 |  | -0.061 | 0.05 | 0.95 | ok |
| SeqOneByOne:SPBR@0.2 | 50 | `~1` | score | 0.152 | 0.848 | -0.16 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:SPBR@0.2 | 200 | `~1` | score | 0.156 | 0.844 | -0.048 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:SPBR@0.2 | 1000 | `~1` | score | 0.149 | 0.851 | -0.061 | 0.0625 | 0.938 | **FAIL** |
| SeqOneByOne:SPBR@0.2 | 50 | `~1` | wald | 0.111 | 0.889 | -0.16 | 0.1 | 0.9 | ok |
| SeqOneByOne:SPBR@0.2 | 200 | `~1` | wald | 0.066 | 0.934 | -0.048 | 0.1 | 0.9 | ok |
| SeqOneByOne:SPBR@0.2 | 1000 | `~1` | wald | 0.058 | 0.942 | -0.061 | 0.0625 | 0.938 | ok |
| SeqOneByOne:Urn | 50 | `~.` | gradient | 0.104 | 0.893 | 0.021 | 0.1 | 0.9 | ok |
| SeqOneByOne:Urn | 200 | `~.` | gradient | 0.046 | 0.954 | 0.046 | 0.1 | 0.9 | ok |
| SeqOneByOne:Urn | 1000 | `~.` | gradient | 0.051 | 0.949 | -0.075 | 0.0525 | 0.948 | ok |
| SeqOneByOne:Urn | 50 | `~.` | lik_ratio | 0.1 | 0.906 | 0.021 | 0.1 | 0.9 | ok |
| SeqOneByOne:Urn | 200 | `~.` | lik_ratio | 0.046 | 0.954 | 0.046 | 0.1 | 0.9 | ok |
| SeqOneByOne:Urn | 1000 | `~.` | lik_ratio | 0.051 | 0.949 | -0.075 | 0.0525 | 0.948 | ok |
| SeqOneByOne:Urn | 50 | `~.` | rand | 0.059 |  | 0.021 | 0.05 | 0.95 | ok |
| SeqOneByOne:Urn | 200 | `~.` | rand | 0.046 |  | 0.046 | 0.05 | 0.95 | ok |
| SeqOneByOne:Urn | 1000 | `~.` | rand | 0.051 |  | -0.075 | 0.05 | 0.95 | ok |
| SeqOneByOne:Urn | 50 | `~.` | score | 0.124 | 0.894 | 0.021 | 0.1 | 0.9 | ok |
| SeqOneByOne:Urn | 200 | `~.` | score | 0.046 | 0.954 | 0.046 | 0.1 | 0.9 | ok |
| SeqOneByOne:Urn | 1000 | `~.` | score | 0.051 | 0.949 | -0.075 | 0.0525 | 0.948 | ok |
| SeqOneByOne:Urn | 50 | `~.` | wald | 0.127 | 0.873 | 0.021 | 0.1 | 0.9 | ok |
| SeqOneByOne:Urn | 200 | `~.` | wald | 0.049 | 0.951 | 0.046 | 0.1 | 0.9 | ok |
| SeqOneByOne:Urn | 1000 | `~.` | wald | 0.05 | 0.95 | -0.075 | 0.0525 | 0.948 | ok |
| SeqOneByOne:Urn | 50 | `~1` | gradient | 0.168 | 0.832 | -0.012 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:Urn | 200 | `~1` | gradient | 0.137 | 0.863 | 0.046 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:Urn | 1000 | `~1` | gradient | 0.168 | 0.832 | -0.029 | 0.0525 | 0.948 | **FAIL** |
| SeqOneByOne:Urn | 50 | `~1` | lik_ratio | 0.165 | 0.835 | -0.012 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:Urn | 200 | `~1` | lik_ratio | 0.136 | 0.864 | 0.046 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:Urn | 1000 | `~1` | lik_ratio | 0.168 | 0.832 | -0.029 | 0.0525 | 0.948 | **FAIL** |
| SeqOneByOne:Urn | 50 | `~1` | rand | 0.056 |  | -0.012 | 0.05 | 0.95 | ok |
| SeqOneByOne:Urn | 200 | `~1` | rand | 0.042 |  | 0.046 | 0.05 | 0.95 | ok |
| SeqOneByOne:Urn | 1000 | `~1` | rand | 0.051 |  | -0.029 | 0.05 | 0.95 | ok |
| SeqOneByOne:Urn | 50 | `~1` | score | 0.164 | 0.836 | -0.012 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:Urn | 200 | `~1` | score | 0.137 | 0.863 | 0.046 | 0.1 | 0.9 | **FAIL** |
| SeqOneByOne:Urn | 1000 | `~1` | score | 0.168 | 0.832 | -0.029 | 0.0525 | 0.948 | **FAIL** |
| SeqOneByOne:Urn | 50 | `~1` | wald | 0.091 | 0.909 | -0.012 | 0.1 | 0.9 | ok |
| SeqOneByOne:Urn | 200 | `~1` | wald | 0.049 | 0.951 | 0.046 | 0.1 | 0.9 | ok |
| SeqOneByOne:Urn | 1000 | `~1` | wald | 0.056 | 0.944 | -0.029 | 0.0525 | 0.948 | ok |

Power effects: 684 cells (155 failing coverage).

| design | n | effect | formula | procedure | power | coverage of the true estimand | coverage level | verdict |
|---|---|---|---|---|---|---|---|---|
| Fixed:Bernoulli | 50 | power20 | `~.` | gradient | 0.216 | 0.898 | 0.9 | ok |
| Fixed:Bernoulli | 200 | power20 | `~.` | gradient | 0.178 | 0.958 | 0.938 | ok |
| Fixed:Bernoulli | 50 | power20 | `~.` | lik_ratio | 0.192 | 0.908 | 0.9 | ok |
| Fixed:Bernoulli | 200 | power20 | `~.` | lik_ratio | 0.178 | 0.96 | 0.938 | ok |
| Fixed:Bernoulli | 50 | power20 | `~.` | rand | 0.114 |  | 0.95 | ok |
| Fixed:Bernoulli | 200 | power20 | `~.` | rand | 0.174 |  | 0.95 | ok |
| Fixed:Bernoulli | 50 | power20 | `~.` | score | 0.224 | 0.896 | 0.9 | ok |
| Fixed:Bernoulli | 200 | power20 | `~.` | score | 0.18 | 0.96 | 0.938 | ok |
| Fixed:Bernoulli | 50 | power20 | `~.` | wald | 0.26 | 0.891 | 0.9 | ok |
| Fixed:Bernoulli | 200 | power20 | `~.` | wald | 0.2 | 0.956 | 0.938 | ok |
| Fixed:Bernoulli | 50 | power20 | `~1` | gradient | 0.272 | 0.812 | 0.9 | **FAIL** |
| Fixed:Bernoulli | 200 | power20 | `~1` | gradient | 0.262 | 0.834 | 0.938 | **FAIL** |
| Fixed:Bernoulli | 50 | power20 | `~1` | lik_ratio | 0.262 | 0.816 | 0.9 | **FAIL** |
| Fixed:Bernoulli | 200 | power20 | `~1` | lik_ratio | 0.262 | 0.834 | 0.938 | **FAIL** |
| Fixed:Bernoulli | 50 | power20 | `~1` | rand | 0.108 |  | 0.95 | ok |
| Fixed:Bernoulli | 200 | power20 | `~1` | rand | 0.106 |  | 0.95 | ok |
| Fixed:Bernoulli | 50 | power20 | `~1` | score | 0.258 | 0.816 | 0.9 | **FAIL** |
| Fixed:Bernoulli | 200 | power20 | `~1` | score | 0.26 | 0.832 | 0.938 | **FAIL** |
| Fixed:Bernoulli | 50 | power20 | `~1` | wald | 0.146 | 0.92 | 0.9 | ok |
| Fixed:Bernoulli | 200 | power20 | `~1` | wald | 0.114 | 0.954 | 0.938 | ok |
| Fixed:Bernoulli@0.2 | 50 | power20 | `~.` | gradient | 0.156 | 0.91 | 0.9 | ok |
| Fixed:Bernoulli@0.2 | 200 | power20 | `~.` | gradient | 0.112 | 0.964 | 0.9 | ok |
| Fixed:Bernoulli@0.2 | 50 | power20 | `~.` | lik_ratio | 0.164 | 0.912 | 0.9 | ok |
| Fixed:Bernoulli@0.2 | 200 | power20 | `~.` | lik_ratio | 0.116 | 0.962 | 0.9 | ok |
| Fixed:Bernoulli@0.2 | 50 | power20 | `~.` | rand | 0.122 |  | 0.95 | ok |
| Fixed:Bernoulli@0.2 | 200 | power20 | `~.` | rand | 0.206 |  | 0.95 | ok |
| Fixed:Bernoulli@0.2 | 50 | power20 | `~.` | score | 0.206 | 0.906 | 0.9 | ok |
| Fixed:Bernoulli@0.2 | 200 | power20 | `~.` | score | 0.122 | 0.966 | 0.9 | ok |
| Fixed:Bernoulli@0.2 | 50 | power20 | `~.` | wald | 0.241 | 0.877 | 0.9 | ok |
| Fixed:Bernoulli@0.2 | 200 | power20 | `~.` | wald | 0.146 | 0.952 | 0.9 | ok |
| Fixed:Bernoulli@0.2 | 50 | power20 | `~1` | gradient | 0.206 | 0.808 | 0.9 | **FAIL** |
| Fixed:Bernoulli@0.2 | 200 | power20 | `~1` | gradient | 0.188 | 0.84 | 0.9 | **FAIL** |
| Fixed:Bernoulli@0.2 | 50 | power20 | `~1` | lik_ratio | 0.212 | 0.814 | 0.9 | **FAIL** |
| Fixed:Bernoulli@0.2 | 200 | power20 | `~1` | lik_ratio | 0.19 | 0.836 | 0.9 | **FAIL** |
| Fixed:Bernoulli@0.2 | 50 | power20 | `~1` | rand | 0.292 |  | 0.95 | ok |
| Fixed:Bernoulli@0.2 | 200 | power20 | `~1` | rand | 0.088 |  | 0.95 | ok |
| Fixed:Bernoulli@0.2 | 50 | power20 | `~1` | score | 0.224 | 0.832 | 0.9 | **FAIL** |
| Fixed:Bernoulli@0.2 | 200 | power20 | `~1` | score | 0.19 | 0.84 | 0.9 | **FAIL** |
| Fixed:Bernoulli@0.2 | 50 | power20 | `~1` | wald | 0.154 | 0.878 | 0.9 | ok |
| Fixed:Bernoulli@0.2 | 200 | power20 | `~1` | wald | 0.084 | 0.946 | 0.9 | ok |
| Fixed:BinaryMatch | 50 | power20 | `~.` | gradient | 0.202 | 0.924 | 0.9 | ok |
| Fixed:BinaryMatch | 200 | power20 | `~.` | gradient | 0.166 | 0.946 | 0.938 | ok |
| Fixed:BinaryMatch | 50 | power20 | `~.` | lik_ratio | 0.19 | 0.93 | 0.9 | ok |
| Fixed:BinaryMatch | 200 | power20 | `~.` | lik_ratio | 0.164 | 0.944 | 0.938 | ok |
| Fixed:BinaryMatch | 50 | power20 | `~.` | rand | 0.112 |  | 0.95 | ok |
| Fixed:BinaryMatch | 200 | power20 | `~.` | rand | 0.168 |  | 0.95 | ok |
| Fixed:BinaryMatch | 50 | power20 | `~.` | score | 0.226 | 0.916 | 0.9 | ok |
| Fixed:BinaryMatch | 200 | power20 | `~.` | score | 0.164 | 0.944 | 0.938 | ok |
| Fixed:BinaryMatch | 50 | power20 | `~.` | wald | 0.224 | 0.927 | 0.9 | ok |
| Fixed:BinaryMatch | 200 | power20 | `~.` | wald | 0.172 | 0.942 | 0.938 | ok |
| Fixed:BinaryMatch | 50 | power20 | `~1` | gradient | 0.232 | 0.866 | 0.9 | ok |
| Fixed:BinaryMatch | 200 | power20 | `~1` | gradient | 0.214 | 0.912 | 0.938 | ok |
| Fixed:BinaryMatch | 50 | power20 | `~1` | lik_ratio | 0.226 | 0.866 | 0.9 | ok |
| Fixed:BinaryMatch | 200 | power20 | `~1` | lik_ratio | 0.21 | 0.912 | 0.938 | ok |
| Fixed:BinaryMatch | 50 | power20 | `~1` | rand | 0.104 |  | 0.95 | ok |
| Fixed:BinaryMatch | 200 | power20 | `~1` | rand | 0.132 |  | 0.95 | ok |
| Fixed:BinaryMatch | 50 | power20 | `~1` | score | 0.224 | 0.864 | 0.9 | ok |
| Fixed:BinaryMatch | 200 | power20 | `~1` | score | 0.206 | 0.912 | 0.938 | ok |
| Fixed:BinaryMatch | 50 | power20 | `~1` | wald | 0.098 | 0.942 | 0.9 | ok |
| Fixed:BinaryMatch | 200 | power20 | `~1` | wald | 0.074 | 0.982 | 0.938 | ok |
| Fixed:Blocking | 50 | power20 | `~.` | gradient | 0.192 | 0.912 | 0.9 | ok |
| Fixed:Blocking | 200 | power20 | `~.` | gradient | 0.178 | 0.952 | 0.938 | ok |
| Fixed:Blocking | 50 | power20 | `~.` | lik_ratio | 0.19 | 0.928 | 0.9 | ok |
| Fixed:Blocking | 200 | power20 | `~.` | lik_ratio | 0.178 | 0.952 | 0.938 | ok |
| Fixed:Blocking | 50 | power20 | `~.` | rand | 0.122 |  | 0.95 | ok |
| Fixed:Blocking | 200 | power20 | `~.` | rand | 0.168 |  | 0.95 | ok |
| Fixed:Blocking | 50 | power20 | `~.` | score | 0.214 | 0.912 | 0.9 | ok |
| Fixed:Blocking | 200 | power20 | `~.` | score | 0.178 | 0.952 | 0.938 | ok |
| Fixed:Blocking | 50 | power20 | `~.` | wald | 0.237 | 0.904 | 0.9 | ok |
| Fixed:Blocking | 200 | power20 | `~.` | wald | 0.2 | 0.942 | 0.938 | ok |
| Fixed:Blocking | 50 | power20 | `~1` | gradient | 0.276 | 0.844 | 0.9 | **FAIL** |
| Fixed:Blocking | 200 | power20 | `~1` | gradient | 0.248 | 0.828 | 0.938 | **FAIL** |
| Fixed:Blocking | 50 | power20 | `~1` | lik_ratio | 0.272 | 0.846 | 0.9 | **FAIL** |
| Fixed:Blocking | 200 | power20 | `~1` | lik_ratio | 0.248 | 0.828 | 0.938 | **FAIL** |
| Fixed:Blocking | 50 | power20 | `~1` | rand | 0.102 |  | 0.95 | ok |
| Fixed:Blocking | 200 | power20 | `~1` | rand | 0.118 |  | 0.95 | ok |
| Fixed:Blocking | 50 | power20 | `~1` | score | 0.27 | 0.846 | 0.9 | **FAIL** |
| Fixed:Blocking | 200 | power20 | `~1` | score | 0.246 | 0.824 | 0.938 | **FAIL** |
| Fixed:Blocking | 50 | power20 | `~1` | wald | 0.152 | 0.918 | 0.9 | ok |
| Fixed:Blocking | 200 | power20 | `~1` | wald | 0.12 | 0.942 | 0.938 | ok |
| Fixed:Blocking@0.2 | 50 | power20 | `~.` | gradient | 0.152 | 0.914 | 0.9 | ok |
| Fixed:Blocking@0.2 | 200 | power20 | `~.` | gradient | 0.132 | 0.952 | 0.9 | ok |
| Fixed:Blocking@0.2 | 50 | power20 | `~.` | lik_ratio | 0.142 | 0.918 | 0.9 | ok |
| Fixed:Blocking@0.2 | 200 | power20 | `~.` | lik_ratio | 0.138 | 0.956 | 0.9 | ok |
| Fixed:Blocking@0.2 | 50 | power20 | `~.` | rand | 0.138 |  | 0.95 | ok |
| Fixed:Blocking@0.2 | 200 | power20 | `~.` | rand | 0.19 |  | 0.95 | ok |
| Fixed:Blocking@0.2 | 50 | power20 | `~.` | score | 0.176 | 0.914 | 0.9 | ok |
| Fixed:Blocking@0.2 | 200 | power20 | `~.` | score | 0.148 | 0.958 | 0.9 | ok |
| Fixed:Blocking@0.2 | 50 | power20 | `~.` | wald | 0.195 | 0.894 | 0.9 | ok |
| Fixed:Blocking@0.2 | 200 | power20 | `~.` | wald | 0.166 | 0.946 | 0.9 | ok |
| Fixed:Blocking@0.2 | 50 | power20 | `~1` | gradient | 0.206 | 0.86 | 0.9 | ok |
| Fixed:Blocking@0.2 | 200 | power20 | `~1` | gradient | 0.25 | 0.852 | 0.9 | **FAIL** |
| Fixed:Blocking@0.2 | 50 | power20 | `~1` | lik_ratio | 0.216 | 0.86 | 0.9 | ok |
| Fixed:Blocking@0.2 | 200 | power20 | `~1` | lik_ratio | 0.256 | 0.848 | 0.9 | **FAIL** |
| Fixed:Blocking@0.2 | 50 | power20 | `~1` | rand | 0.314 |  | 0.95 | ok |
| Fixed:Blocking@0.2 | 200 | power20 | `~1` | rand | 0.088 |  | 0.95 | ok |
| Fixed:Blocking@0.2 | 50 | power20 | `~1` | score | 0.228 | 0.86 | 0.9 | ok |
| Fixed:Blocking@0.2 | 200 | power20 | `~1` | score | 0.256 | 0.846 | 0.9 | **FAIL** |
| Fixed:Blocking@0.2 | 50 | power20 | `~1` | wald | 0.138 | 0.922 | 0.9 | ok |
| Fixed:Blocking@0.2 | 200 | power20 | `~1` | wald | 0.09 | 0.938 | 0.9 | ok |
| Fixed:Greedy | 50 | power20 | `~.` | gradient | 0.244 | 0.922 | 0.9 | ok |
| Fixed:Greedy | 200 | power20 | `~.` | gradient | 0.158 | 0.948 | 0.938 | ok |
| Fixed:Greedy | 50 | power20 | `~.` | lik_ratio | 0.228 | 0.926 | 0.9 | ok |
| Fixed:Greedy | 200 | power20 | `~.` | lik_ratio | 0.158 | 0.946 | 0.938 | ok |
| Fixed:Greedy | 50 | power20 | `~.` | rand | 0.14 |  | 0.95 | ok |
| Fixed:Greedy | 200 | power20 | `~.` | rand | 0.146 |  | 0.95 | ok |
| Fixed:Greedy | 50 | power20 | `~.` | score | 0.256 | 0.908 | 0.9 | ok |
| Fixed:Greedy | 200 | power20 | `~.` | score | 0.16 | 0.944 | 0.938 | ok |
| Fixed:Greedy | 50 | power20 | `~.` | wald | 0.267 | 0.911 | 0.9 | ok |
| Fixed:Greedy | 200 | power20 | `~.` | wald | 0.166 | 0.938 | 0.938 | ok |
| Fixed:Greedy | 50 | power20 | `~1` | gradient | 0.248 | 0.852 | 0.9 | ok |
| Fixed:Greedy | 200 | power20 | `~1` | gradient | 0.214 | 0.9 | 0.938 | **FAIL** |
| Fixed:Greedy | 50 | power20 | `~1` | lik_ratio | 0.244 | 0.852 | 0.9 | ok |
| Fixed:Greedy | 200 | power20 | `~1` | lik_ratio | 0.214 | 0.9 | 0.938 | **FAIL** |
| Fixed:Greedy | 50 | power20 | `~1` | rand | 0.148 |  | 0.95 | ok |
| Fixed:Greedy | 200 | power20 | `~1` | rand | 0.116 |  | 0.95 | ok |
| Fixed:Greedy | 50 | power20 | `~1` | score | 0.244 | 0.858 | 0.9 | ok |
| Fixed:Greedy | 200 | power20 | `~1` | score | 0.214 | 0.9 | 0.938 | **FAIL** |
| Fixed:Greedy | 50 | power20 | `~1` | wald | 0.13 | 0.956 | 0.9 | ok |
| Fixed:Greedy | 200 | power20 | `~1` | wald | 0.07 | 0.97 | 0.938 | ok |
| Fixed:Greedy@0.2 | 50 | power20 | `~.` | gradient | 0.178 | 0.918 | 0.9 | ok |
| Fixed:Greedy@0.2 | 200 | power20 | `~.` | gradient | 0.112 | 0.946 | 0.9 | ok |
| Fixed:Greedy@0.2 | 50 | power20 | `~.` | lik_ratio | 0.162 | 0.932 | 0.9 | ok |
| Fixed:Greedy@0.2 | 200 | power20 | `~.` | lik_ratio | 0.116 | 0.942 | 0.9 | ok |
| Fixed:Greedy@0.2 | 50 | power20 | `~.` | rand | 0.14 |  | 0.95 | ok |
| Fixed:Greedy@0.2 | 200 | power20 | `~.` | rand | 0.186 |  | 0.95 | ok |
| Fixed:Greedy@0.2 | 50 | power20 | `~.` | score | 0.214 | 0.92 | 0.9 | ok |
| Fixed:Greedy@0.2 | 200 | power20 | `~.` | score | 0.128 | 0.942 | 0.9 | ok |
| Fixed:Greedy@0.2 | 50 | power20 | `~.` | wald | 0.243 | 0.895 | 0.9 | ok |
| Fixed:Greedy@0.2 | 200 | power20 | `~.` | wald | 0.148 | 0.934 | 0.9 | ok |
| Fixed:Greedy@0.2 | 50 | power20 | `~1` | gradient | 0.22 | 0.864 | 0.9 | ok |
| Fixed:Greedy@0.2 | 200 | power20 | `~1` | gradient | 0.192 | 0.87 | 0.9 | ok |
| Fixed:Greedy@0.2 | 50 | power20 | `~1` | lik_ratio | 0.222 | 0.868 | 0.9 | ok |
| Fixed:Greedy@0.2 | 200 | power20 | `~1` | lik_ratio | 0.194 | 0.872 | 0.9 | ok |
| Fixed:Greedy@0.2 | 50 | power20 | `~1` | rand | 0.39 |  | 0.95 | ok |
| Fixed:Greedy@0.2 | 200 | power20 | `~1` | rand | 0.106 |  | 0.95 | ok |
| Fixed:Greedy@0.2 | 50 | power20 | `~1` | score | 0.232 | 0.874 | 0.9 | ok |
| Fixed:Greedy@0.2 | 200 | power20 | `~1` | score | 0.204 | 0.868 | 0.9 | ok |
| Fixed:Greedy@0.2 | 50 | power20 | `~1` | wald | 0.116 | 0.92 | 0.9 | ok |
| Fixed:Greedy@0.2 | 200 | power20 | `~1` | wald | 0.076 | 0.968 | 0.9 | ok |
| Fixed:GreedyDOptimal | 50 | power20 | `~.` | gradient | 0.244 | 0.922 | 0.9 | ok |
| Fixed:GreedyDOptimal | 200 | power20 | `~.` | gradient | 0.158 | 0.948 | 0.938 | ok |
| Fixed:GreedyDOptimal | 50 | power20 | `~.` | lik_ratio | 0.228 | 0.926 | 0.9 | ok |
| Fixed:GreedyDOptimal | 200 | power20 | `~.` | lik_ratio | 0.158 | 0.946 | 0.938 | ok |
| Fixed:GreedyDOptimal | 50 | power20 | `~.` | rand | 0.14 |  | 0.95 | ok |
| Fixed:GreedyDOptimal | 200 | power20 | `~.` | rand | 0.146 |  | 0.95 | ok |
| Fixed:GreedyDOptimal | 50 | power20 | `~.` | score | 0.256 | 0.908 | 0.9 | ok |
| Fixed:GreedyDOptimal | 200 | power20 | `~.` | score | 0.16 | 0.944 | 0.938 | ok |
| Fixed:GreedyDOptimal | 50 | power20 | `~.` | wald | 0.267 | 0.911 | 0.9 | ok |
| Fixed:GreedyDOptimal | 200 | power20 | `~.` | wald | 0.166 | 0.938 | 0.938 | ok |
| Fixed:GreedyDOptimal | 50 | power20 | `~1` | gradient | 0.248 | 0.852 | 0.9 | ok |
| Fixed:GreedyDOptimal | 200 | power20 | `~1` | gradient | 0.214 | 0.9 | 0.938 | **FAIL** |
| Fixed:GreedyDOptimal | 50 | power20 | `~1` | lik_ratio | 0.244 | 0.852 | 0.9 | ok |
| Fixed:GreedyDOptimal | 200 | power20 | `~1` | lik_ratio | 0.214 | 0.9 | 0.938 | **FAIL** |
| Fixed:GreedyDOptimal | 50 | power20 | `~1` | rand | 0.148 |  | 0.95 | ok |
| Fixed:GreedyDOptimal | 200 | power20 | `~1` | rand | 0.116 |  | 0.95 | ok |
| Fixed:GreedyDOptimal | 50 | power20 | `~1` | score | 0.244 | 0.858 | 0.9 | ok |
| Fixed:GreedyDOptimal | 200 | power20 | `~1` | score | 0.214 | 0.9 | 0.938 | **FAIL** |
| Fixed:GreedyDOptimal | 50 | power20 | `~1` | wald | 0.13 | 0.956 | 0.9 | ok |
| Fixed:GreedyDOptimal | 200 | power20 | `~1` | wald | 0.07 | 0.97 | 0.938 | ok |
| Fixed:GreedyDOptimal@0.2 | 50 | power20 | `~.` | gradient | 0.178 | 0.918 | 0.9 | ok |
| Fixed:GreedyDOptimal@0.2 | 200 | power20 | `~.` | gradient | 0.112 | 0.946 | 0.9 | ok |
| Fixed:GreedyDOptimal@0.2 | 50 | power20 | `~.` | lik_ratio | 0.162 | 0.932 | 0.9 | ok |
| Fixed:GreedyDOptimal@0.2 | 200 | power20 | `~.` | lik_ratio | 0.116 | 0.942 | 0.9 | ok |
| Fixed:GreedyDOptimal@0.2 | 50 | power20 | `~.` | rand | 0.14 |  | 0.95 | ok |
| Fixed:GreedyDOptimal@0.2 | 200 | power20 | `~.` | rand | 0.186 |  | 0.95 | ok |
| Fixed:GreedyDOptimal@0.2 | 50 | power20 | `~.` | score | 0.214 | 0.92 | 0.9 | ok |
| Fixed:GreedyDOptimal@0.2 | 200 | power20 | `~.` | score | 0.128 | 0.942 | 0.9 | ok |
| Fixed:GreedyDOptimal@0.2 | 50 | power20 | `~.` | wald | 0.243 | 0.895 | 0.9 | ok |
| Fixed:GreedyDOptimal@0.2 | 200 | power20 | `~.` | wald | 0.148 | 0.934 | 0.9 | ok |
| Fixed:GreedyDOptimal@0.2 | 50 | power20 | `~1` | gradient | 0.22 | 0.864 | 0.9 | ok |
| Fixed:GreedyDOptimal@0.2 | 200 | power20 | `~1` | gradient | 0.192 | 0.87 | 0.9 | ok |
| Fixed:GreedyDOptimal@0.2 | 50 | power20 | `~1` | lik_ratio | 0.222 | 0.868 | 0.9 | ok |
| Fixed:GreedyDOptimal@0.2 | 200 | power20 | `~1` | lik_ratio | 0.194 | 0.872 | 0.9 | ok |
| Fixed:GreedyDOptimal@0.2 | 50 | power20 | `~1` | rand | 0.39 |  | 0.95 | ok |
| Fixed:GreedyDOptimal@0.2 | 200 | power20 | `~1` | rand | 0.106 |  | 0.95 | ok |
| Fixed:GreedyDOptimal@0.2 | 50 | power20 | `~1` | score | 0.232 | 0.874 | 0.9 | ok |
| Fixed:GreedyDOptimal@0.2 | 200 | power20 | `~1` | score | 0.204 | 0.868 | 0.9 | ok |
| Fixed:GreedyDOptimal@0.2 | 50 | power20 | `~1` | wald | 0.116 | 0.92 | 0.9 | ok |
| Fixed:GreedyDOptimal@0.2 | 200 | power20 | `~1` | wald | 0.076 | 0.968 | 0.9 | ok |
| Fixed:iBCRD | 50 | power20 | `~.` | gradient | 0.224 | 0.912 | 0.9 | ok |
| Fixed:iBCRD | 200 | power20 | `~.` | gradient | 0.17 | 0.966 | 0.938 | ok |
| Fixed:iBCRD | 50 | power20 | `~.` | lik_ratio | 0.22 | 0.922 | 0.9 | ok |
| Fixed:iBCRD | 200 | power20 | `~.` | lik_ratio | 0.17 | 0.966 | 0.938 | ok |
| Fixed:iBCRD | 50 | power20 | `~.` | rand | 0.12 |  | 0.95 | ok |
| Fixed:iBCRD | 200 | power20 | `~.` | rand | 0.168 |  | 0.95 | ok |
| Fixed:iBCRD | 50 | power20 | `~.` | score | 0.256 | 0.912 | 0.9 | ok |
| Fixed:iBCRD | 200 | power20 | `~.` | score | 0.17 | 0.968 | 0.938 | ok |
| Fixed:iBCRD | 50 | power20 | `~.` | wald | 0.255 | 0.876 | 0.9 | ok |
| Fixed:iBCRD | 200 | power20 | `~.` | wald | 0.188 | 0.962 | 0.938 | ok |
| Fixed:iBCRD | 50 | power20 | `~1` | gradient | 0.274 | 0.844 | 0.9 | **FAIL** |
| Fixed:iBCRD | 200 | power20 | `~1` | gradient | 0.256 | 0.836 | 0.938 | **FAIL** |
| Fixed:iBCRD | 50 | power20 | `~1` | lik_ratio | 0.27 | 0.844 | 0.9 | **FAIL** |
| Fixed:iBCRD | 200 | power20 | `~1` | lik_ratio | 0.256 | 0.836 | 0.938 | **FAIL** |
| Fixed:iBCRD | 50 | power20 | `~1` | rand | 0.11 |  | 0.95 | ok |
| Fixed:iBCRD | 200 | power20 | `~1` | rand | 0.112 |  | 0.95 | ok |
| Fixed:iBCRD | 50 | power20 | `~1` | score | 0.27 | 0.848 | 0.9 | **FAIL** |
| Fixed:iBCRD | 200 | power20 | `~1` | score | 0.254 | 0.836 | 0.938 | **FAIL** |
| Fixed:iBCRD | 50 | power20 | `~1` | wald | 0.144 | 0.934 | 0.9 | ok |
| Fixed:iBCRD | 200 | power20 | `~1` | wald | 0.118 | 0.942 | 0.938 | ok |
| Fixed:iBCRD@0.2 | 50 | power20 | `~.` | gradient | 0.158 | 0.91 | 0.9 | ok |
| Fixed:iBCRD@0.2 | 200 | power20 | `~.` | gradient | 0.136 | 0.942 | 0.9 | ok |
| Fixed:iBCRD@0.2 | 50 | power20 | `~.` | lik_ratio | 0.158 | 0.914 | 0.9 | ok |
| Fixed:iBCRD@0.2 | 200 | power20 | `~.` | lik_ratio | 0.138 | 0.944 | 0.9 | ok |
| Fixed:iBCRD@0.2 | 50 | power20 | `~.` | rand | 0.122 |  | 0.95 | ok |
| Fixed:iBCRD@0.2 | 200 | power20 | `~.` | rand | 0.226 |  | 0.95 | ok |
| Fixed:iBCRD@0.2 | 50 | power20 | `~.` | score | 0.21 | 0.918 | 0.9 | ok |
| Fixed:iBCRD@0.2 | 200 | power20 | `~.` | score | 0.158 | 0.95 | 0.9 | ok |
| Fixed:iBCRD@0.2 | 50 | power20 | `~.` | wald | 0.219 | 0.905 | 0.9 | ok |
| Fixed:iBCRD@0.2 | 200 | power20 | `~.` | wald | 0.172 | 0.934 | 0.9 | ok |
| Fixed:iBCRD@0.2 | 50 | power20 | `~1` | gradient | 0.212 | 0.84 | 0.9 | **FAIL** |
| Fixed:iBCRD@0.2 | 200 | power20 | `~1` | gradient | 0.25 | 0.802 | 0.9 | **FAIL** |
| Fixed:iBCRD@0.2 | 50 | power20 | `~1` | lik_ratio | 0.212 | 0.854 | 0.9 | **FAIL** |
| Fixed:iBCRD@0.2 | 200 | power20 | `~1` | lik_ratio | 0.258 | 0.802 | 0.9 | **FAIL** |
| Fixed:iBCRD@0.2 | 50 | power20 | `~1` | rand | 0.304 |  | 0.95 | ok |
| Fixed:iBCRD@0.2 | 200 | power20 | `~1` | rand | 0.112 |  | 0.95 | ok |
| Fixed:iBCRD@0.2 | 50 | power20 | `~1` | score | 0.224 | 0.858 | 0.9 | ok |
| Fixed:iBCRD@0.2 | 200 | power20 | `~1` | score | 0.276 | 0.806 | 0.9 | **FAIL** |
| Fixed:iBCRD@0.2 | 50 | power20 | `~1` | wald | 0.13 | 0.912 | 0.9 | ok |
| Fixed:iBCRD@0.2 | 200 | power20 | `~1` | wald | 0.124 | 0.922 | 0.9 | ok |
| Fixed:MatchingGreedyPairSwitching | 50 | power20 | `~.` | gradient | 0.214 | 0.914 | 0.9 | ok |
| Fixed:MatchingGreedyPairSwitching | 200 | power20 | `~.` | gradient | 0.164 | 0.946 | 0.938 | ok |
| Fixed:MatchingGreedyPairSwitching | 50 | power20 | `~.` | lik_ratio | 0.208 | 0.928 | 0.9 | ok |
| Fixed:MatchingGreedyPairSwitching | 200 | power20 | `~.` | lik_ratio | 0.164 | 0.946 | 0.938 | ok |
| Fixed:MatchingGreedyPairSwitching | 50 | power20 | `~.` | rand | 0.132 |  | 0.95 | ok |
| Fixed:MatchingGreedyPairSwitching | 200 | power20 | `~.` | rand | 0.154 |  | 0.95 | ok |
| Fixed:MatchingGreedyPairSwitching | 50 | power20 | `~.` | score | 0.228 | 0.92 | 0.9 | ok |
| Fixed:MatchingGreedyPairSwitching | 200 | power20 | `~.` | score | 0.164 | 0.946 | 0.938 | ok |
| Fixed:MatchingGreedyPairSwitching | 50 | power20 | `~.` | wald | 0.248 | 0.891 | 0.9 | ok |
| Fixed:MatchingGreedyPairSwitching | 200 | power20 | `~.` | wald | 0.182 | 0.944 | 0.938 | ok |
| Fixed:MatchingGreedyPairSwitching | 50 | power20 | `~1` | gradient | 0.198 | 0.906 | 0.9 | ok |
| Fixed:MatchingGreedyPairSwitching | 200 | power20 | `~1` | gradient | 0.214 | 0.886 | 0.938 | **FAIL** |
| Fixed:MatchingGreedyPairSwitching | 50 | power20 | `~1` | lik_ratio | 0.196 | 0.908 | 0.9 | ok |
| Fixed:MatchingGreedyPairSwitching | 200 | power20 | `~1` | lik_ratio | 0.208 | 0.888 | 0.938 | **FAIL** |
| Fixed:MatchingGreedyPairSwitching | 50 | power20 | `~1` | rand | 0.116 |  | 0.95 | ok |
| Fixed:MatchingGreedyPairSwitching | 200 | power20 | `~1` | rand | 0.126 |  | 0.95 | ok |
| Fixed:MatchingGreedyPairSwitching | 50 | power20 | `~1` | score | 0.194 | 0.908 | 0.9 | ok |
| Fixed:MatchingGreedyPairSwitching | 200 | power20 | `~1` | score | 0.208 | 0.888 | 0.938 | **FAIL** |
| Fixed:MatchingGreedyPairSwitching | 50 | power20 | `~1` | wald | 0.102 | 0.958 | 0.9 | ok |
| Fixed:MatchingGreedyPairSwitching | 200 | power20 | `~1` | wald | 0.074 | 0.968 | 0.938 | ok |
| Fixed:Optimal | 50 | power20 | `~.` | gradient | 0.216 | 0.932 | 0.9 | ok |
| Fixed:Optimal | 200 | power20 | `~.` | gradient | 0.158 | 0.956 | 0.938 | ok |
| Fixed:Optimal | 50 | power50 | `~.` | gradient | 0.516 | 0.932 | 0.9 | ok |
| Fixed:Optimal | 200 | power50 | `~.` | gradient | 0.498 | 0.962 | 0.938 | ok |
| Fixed:Optimal | 50 | power20 | `~.` | lik_ratio | 0.2 | 0.942 | 0.9 | ok |
| Fixed:Optimal | 200 | power20 | `~.` | lik_ratio | 0.158 | 0.956 | 0.938 | ok |
| Fixed:Optimal | 50 | power50 | `~.` | lik_ratio | 0.484 | 0.936 | 0.9 | ok |
| Fixed:Optimal | 200 | power50 | `~.` | lik_ratio | 0.498 | 0.962 | 0.938 | ok |
| Fixed:Optimal | 50 | power20 | `~.` | score | 0.222 | 0.934 | 0.9 | ok |
| Fixed:Optimal | 200 | power20 | `~.` | score | 0.158 | 0.956 | 0.938 | ok |
| Fixed:Optimal | 50 | power50 | `~.` | score | 0.506 | 0.93 | 0.9 | ok |
| Fixed:Optimal | 200 | power50 | `~.` | score | 0.496 | 0.962 | 0.938 | ok |
| Fixed:Optimal | 50 | power20 | `~.` | wald | 0.25 | 0.915 | 0.9 | ok |
| Fixed:Optimal | 200 | power20 | `~.` | wald | 0.168 | 0.95 | 0.938 | ok |
| Fixed:Optimal | 50 | power50 | `~.` | wald | 0.552 | 0.936 | 0.9 | ok |
| Fixed:Optimal | 200 | power50 | `~.` | wald | 0.518 | 0.95 | 0.938 | ok |
| Fixed:Optimal | 50 | power20 | `~1` | gradient | 0.22 | 0.892 | 0.9 | ok |
| Fixed:Optimal | 200 | power20 | `~1` | gradient | 0.192 | 0.876 | 0.938 | **FAIL** |
| Fixed:Optimal | 50 | power50 | `~1` | gradient | 0.472 | 0.912 | 0.9 | ok |
| Fixed:Optimal | 200 | power50 | `~1` | gradient | 0.412 | 0.89 | 0.938 | **FAIL** |
| Fixed:Optimal | 50 | power20 | `~1` | lik_ratio | 0.218 | 0.896 | 0.9 | ok |
| Fixed:Optimal | 200 | power20 | `~1` | lik_ratio | 0.19 | 0.878 | 0.938 | **FAIL** |
| Fixed:Optimal | 50 | power50 | `~1` | lik_ratio | 0.462 | 0.912 | 0.9 | ok |
| Fixed:Optimal | 200 | power50 | `~1` | lik_ratio | 0.406 | 0.89 | 0.938 | **FAIL** |
| Fixed:Optimal | 50 | power20 | `~1` | score | 0.212 | 0.894 | 0.9 | ok |
| Fixed:Optimal | 200 | power20 | `~1` | score | 0.19 | 0.88 | 0.938 | **FAIL** |
| Fixed:Optimal | 50 | power50 | `~1` | score | 0.462 | 0.912 | 0.9 | ok |
| Fixed:Optimal | 200 | power50 | `~1` | score | 0.404 | 0.89 | 0.938 | **FAIL** |
| Fixed:Optimal | 50 | power20 | `~1` | wald | 0.124 | 0.966 | 0.9 | ok |
| Fixed:Optimal | 200 | power20 | `~1` | wald | 0.072 | 0.974 | 0.938 | ok |
| Fixed:Optimal | 50 | power50 | `~1` | wald | 0.256 | 0.976 | 0.9 | ok |
| Fixed:Optimal | 200 | power50 | `~1` | wald | 0.182 | 0.978 | 0.938 | ok |
| Fixed:Optimal@0.2 | 50 | power20 | `~.` | gradient | 0.192 | 0.88 | 0.9 | ok |
| Fixed:Optimal@0.2 | 200 | power20 | `~.` | gradient | 0.122 | 0.946 | 0.9 | ok |
| Fixed:Optimal@0.2 | 50 | power50 | `~.` | gradient | 0.358 | 0.91 | 0.9 | ok |
| Fixed:Optimal@0.2 | 200 | power50 | `~.` | gradient | 0.336 | 0.964 | 0.9 | ok |
| Fixed:Optimal@0.2 | 50 | power20 | `~.` | lik_ratio | 0.188 | 0.894 | 0.9 | ok |
| Fixed:Optimal@0.2 | 200 | power20 | `~.` | lik_ratio | 0.132 | 0.948 | 0.9 | ok |
| Fixed:Optimal@0.2 | 50 | power50 | `~.` | lik_ratio | 0.342 | 0.91 | 0.9 | ok |
| Fixed:Optimal@0.2 | 200 | power50 | `~.` | lik_ratio | 0.342 | 0.964 | 0.9 | ok |
| Fixed:Optimal@0.2 | 50 | power20 | `~.` | score | 0.234 | 0.884 | 0.9 | ok |
| Fixed:Optimal@0.2 | 200 | power20 | `~.` | score | 0.142 | 0.948 | 0.9 | ok |
| Fixed:Optimal@0.2 | 50 | power50 | `~.` | score | 0.406 | 0.906 | 0.9 | ok |
| Fixed:Optimal@0.2 | 200 | power50 | `~.` | score | 0.364 | 0.966 | 0.9 | ok |
| Fixed:Optimal@0.2 | 50 | power20 | `~.` | wald | 0.231 | 0.853 | 0.9 | ok |
| Fixed:Optimal@0.2 | 200 | power20 | `~.` | wald | 0.15 | 0.944 | 0.9 | ok |
| Fixed:Optimal@0.2 | 50 | power50 | `~.` | wald | 0.439 | 0.861 | 0.9 | ok |
| Fixed:Optimal@0.2 | 200 | power50 | `~.` | wald | 0.4 | 0.946 | 0.9 | ok |
| Fixed:Optimal@0.2 | 50 | power20 | `~1` | gradient | 0.164 | 0.868 | 0.9 | ok |
| Fixed:Optimal@0.2 | 200 | power20 | `~1` | gradient | 0.194 | 0.844 | 0.9 | ok |
| Fixed:Optimal@0.2 | 50 | power50 | `~1` | gradient | 0.326 | 0.878 | 0.9 | ok |
| Fixed:Optimal@0.2 | 200 | power50 | `~1` | gradient | 0.316 | 0.886 | 0.9 | ok |
| Fixed:Optimal@0.2 | 50 | power20 | `~1` | lik_ratio | 0.164 | 0.88 | 0.9 | ok |
| Fixed:Optimal@0.2 | 200 | power20 | `~1` | lik_ratio | 0.194 | 0.85 | 0.9 | ok |
| Fixed:Optimal@0.2 | 50 | power50 | `~1` | lik_ratio | 0.332 | 0.88 | 0.9 | ok |
| Fixed:Optimal@0.2 | 200 | power50 | `~1` | lik_ratio | 0.32 | 0.89 | 0.9 | ok |
| Fixed:Optimal@0.2 | 50 | power20 | `~1` | score | 0.174 | 0.884 | 0.9 | ok |
| Fixed:Optimal@0.2 | 200 | power20 | `~1` | score | 0.2 | 0.854 | 0.9 | ok |
| Fixed:Optimal@0.2 | 50 | power50 | `~1` | score | 0.36 | 0.886 | 0.9 | ok |
| Fixed:Optimal@0.2 | 200 | power50 | `~1` | score | 0.332 | 0.892 | 0.9 | ok |
| Fixed:Optimal@0.2 | 50 | power20 | `~1` | wald | 0.096 | 0.92 | 0.9 | ok |
| Fixed:Optimal@0.2 | 200 | power20 | `~1` | wald | 0.062 | 0.96 | 0.9 | ok |
| Fixed:Optimal@0.2 | 50 | power50 | `~1` | wald | 0.19 | 0.94 | 0.9 | ok |
| Fixed:Optimal@0.2 | 200 | power50 | `~1` | wald | 0.15 | 0.966 | 0.9 | ok |
| Fixed:OptimalBlocks | 50 | power20 | `~.` | gradient | 0.198 | 0.906 | 0.9 | ok |
| Fixed:OptimalBlocks | 200 | power20 | `~.` | gradient | 0.192 | 0.956 | 0.938 | ok |
| Fixed:OptimalBlocks | 50 | power20 | `~.` | lik_ratio | 0.176 | 0.92 | 0.9 | ok |
| Fixed:OptimalBlocks | 200 | power20 | `~.` | lik_ratio | 0.192 | 0.956 | 0.938 | ok |
| Fixed:OptimalBlocks | 50 | power20 | `~.` | rand | 0.116 |  | 0.95 | ok |
| Fixed:OptimalBlocks | 200 | power20 | `~.` | rand | 0.18 |  | 0.95 | ok |
| Fixed:OptimalBlocks | 50 | power20 | `~.` | score | 0.208 | 0.904 | 0.9 | ok |
| Fixed:OptimalBlocks | 200 | power20 | `~.` | score | 0.19 | 0.956 | 0.938 | ok |
| Fixed:OptimalBlocks | 50 | power20 | `~.` | wald | 0.219 | 0.9 | 0.9 | ok |
| Fixed:OptimalBlocks | 200 | power20 | `~.` | wald | 0.204 | 0.946 | 0.938 | ok |
| Fixed:OptimalBlocks | 50 | power20 | `~1` | gradient | 0.26 | 0.846 | 0.9 | **FAIL** |
| Fixed:OptimalBlocks | 200 | power20 | `~1` | gradient | 0.23 | 0.858 | 0.938 | **FAIL** |
| Fixed:OptimalBlocks | 50 | power20 | `~1` | lik_ratio | 0.258 | 0.846 | 0.9 | **FAIL** |
| Fixed:OptimalBlocks | 200 | power20 | `~1` | lik_ratio | 0.23 | 0.858 | 0.938 | **FAIL** |
| Fixed:OptimalBlocks | 50 | power20 | `~1` | rand | 0.104 |  | 0.95 | ok |
| Fixed:OptimalBlocks | 200 | power20 | `~1` | rand | 0.118 |  | 0.95 | ok |
| Fixed:OptimalBlocks | 50 | power20 | `~1` | score | 0.256 | 0.848 | 0.9 | **FAIL** |
| Fixed:OptimalBlocks | 200 | power20 | `~1` | score | 0.232 | 0.858 | 0.938 | **FAIL** |
| Fixed:OptimalBlocks | 50 | power20 | `~1` | wald | 0.114 | 0.932 | 0.9 | ok |
| Fixed:OptimalBlocks | 200 | power20 | `~1` | wald | 0.1 | 0.962 | 0.938 | ok |
| Fixed:OptimalBlocks@0.2 | 50 | power20 | `~.` | gradient | 0.144 | 0.922 | 0.9 | ok |
| Fixed:OptimalBlocks@0.2 | 200 | power20 | `~.` | gradient | 0.114 | 0.96 | 0.9 | ok |
| Fixed:OptimalBlocks@0.2 | 50 | power20 | `~.` | lik_ratio | 0.14 | 0.928 | 0.9 | ok |
| Fixed:OptimalBlocks@0.2 | 200 | power20 | `~.` | lik_ratio | 0.122 | 0.964 | 0.9 | ok |
| Fixed:OptimalBlocks@0.2 | 50 | power20 | `~.` | rand | 0.118 |  | 0.95 | ok |
| Fixed:OptimalBlocks@0.2 | 200 | power20 | `~.` | rand | 0.182 |  | 0.95 | ok |
| Fixed:OptimalBlocks@0.2 | 50 | power20 | `~.` | score | 0.164 | 0.916 | 0.9 | ok |
| Fixed:OptimalBlocks@0.2 | 200 | power20 | `~.` | score | 0.126 | 0.962 | 0.9 | ok |
| Fixed:OptimalBlocks@0.2 | 50 | power20 | `~.` | wald | 0.207 | 0.892 | 0.9 | ok |
| Fixed:OptimalBlocks@0.2 | 200 | power20 | `~.` | wald | 0.144 | 0.942 | 0.9 | ok |
| Fixed:OptimalBlocks@0.2 | 50 | power20 | `~1` | gradient | 0.19 | 0.854 | 0.9 | **FAIL** |
| Fixed:OptimalBlocks@0.2 | 200 | power20 | `~1` | gradient | 0.198 | 0.874 | 0.9 | ok |
| Fixed:OptimalBlocks@0.2 | 50 | power20 | `~1` | lik_ratio | 0.196 | 0.862 | 0.9 | ok |
| Fixed:OptimalBlocks@0.2 | 200 | power20 | `~1` | lik_ratio | 0.202 | 0.876 | 0.9 | ok |
| Fixed:OptimalBlocks@0.2 | 50 | power20 | `~1` | rand | 0.374 |  | 0.95 | ok |
| Fixed:OptimalBlocks@0.2 | 200 | power20 | `~1` | rand | 0.082 |  | 0.95 | ok |
| Fixed:OptimalBlocks@0.2 | 50 | power20 | `~1` | score | 0.216 | 0.88 | 0.9 | ok |
| Fixed:OptimalBlocks@0.2 | 200 | power20 | `~1` | score | 0.212 | 0.878 | 0.9 | ok |
| Fixed:OptimalBlocks@0.2 | 50 | power20 | `~1` | wald | 0.104 | 0.912 | 0.9 | ok |
| Fixed:OptimalBlocks@0.2 | 200 | power20 | `~1` | wald | 0.066 | 0.962 | 0.9 | ok |
| Fixed:Rerandomization | 50 | power20 | `~.` | gradient | 0.232 | 0.898 | 0.9 | ok |
| Fixed:Rerandomization | 200 | power20 | `~.` | gradient | 0.178 | 0.944 | 0.938 | ok |
| Fixed:Rerandomization | 50 | power20 | `~.` | lik_ratio | 0.204 | 0.912 | 0.9 | ok |
| Fixed:Rerandomization | 200 | power20 | `~.` | lik_ratio | 0.178 | 0.944 | 0.938 | ok |
| Fixed:Rerandomization | 50 | power20 | `~.` | rand | 0.14 |  | 0.95 | ok |
| Fixed:Rerandomization | 200 | power20 | `~.` | rand | 0.154 |  | 0.95 | ok |
| Fixed:Rerandomization | 50 | power20 | `~.` | score | 0.258 | 0.9 | 0.9 | ok |
| Fixed:Rerandomization | 200 | power20 | `~.` | score | 0.178 | 0.944 | 0.938 | ok |
| Fixed:Rerandomization | 50 | power20 | `~.` | wald | 0.268 | 0.889 | 0.9 | ok |
| Fixed:Rerandomization | 200 | power20 | `~.` | wald | 0.176 | 0.936 | 0.938 | ok |
| Fixed:Rerandomization | 50 | power20 | `~1` | gradient | 0.272 | 0.802 | 0.9 | **FAIL** |
| Fixed:Rerandomization | 200 | power20 | `~1` | gradient | 0.242 | 0.852 | 0.938 | **FAIL** |
| Fixed:Rerandomization | 50 | power20 | `~1` | lik_ratio | 0.27 | 0.808 | 0.9 | **FAIL** |
| Fixed:Rerandomization | 200 | power20 | `~1` | lik_ratio | 0.242 | 0.85 | 0.938 | **FAIL** |
| Fixed:Rerandomization | 50 | power20 | `~1` | rand | 0.12 |  | 0.95 | ok |
| Fixed:Rerandomization | 200 | power20 | `~1` | rand | 0.08 |  | 0.95 | ok |
| Fixed:Rerandomization | 50 | power20 | `~1` | score | 0.272 | 0.814 | 0.9 | **FAIL** |
| Fixed:Rerandomization | 200 | power20 | `~1` | score | 0.24 | 0.85 | 0.938 | **FAIL** |
| Fixed:Rerandomization | 50 | power20 | `~1` | wald | 0.154 | 0.918 | 0.9 | ok |
| Fixed:Rerandomization | 200 | power20 | `~1` | wald | 0.092 | 0.942 | 0.938 | ok |
| Fixed:Rerandomization@0.2 | 50 | power20 | `~.` | gradient | 0.158 | 0.916 | 0.9 | ok |
| Fixed:Rerandomization@0.2 | 200 | power20 | `~.` | gradient | 0.118 | 0.952 | 0.9 | ok |
| Fixed:Rerandomization@0.2 | 50 | power20 | `~.` | lik_ratio | 0.152 | 0.926 | 0.9 | ok |
| Fixed:Rerandomization@0.2 | 200 | power20 | `~.` | lik_ratio | 0.122 | 0.96 | 0.9 | ok |
| Fixed:Rerandomization@0.2 | 50 | power20 | `~.` | rand | 0.122 |  | 0.95 | ok |
| Fixed:Rerandomization@0.2 | 200 | power20 | `~.` | rand | 0.204 |  | 0.95 | ok |
| Fixed:Rerandomization@0.2 | 50 | power20 | `~.` | score | 0.204 | 0.92 | 0.9 | ok |
| Fixed:Rerandomization@0.2 | 200 | power20 | `~.` | score | 0.136 | 0.96 | 0.9 | ok |
| Fixed:Rerandomization@0.2 | 50 | power20 | `~.` | wald | 0.211 | 0.895 | 0.9 | ok |
| Fixed:Rerandomization@0.2 | 200 | power20 | `~.` | wald | 0.148 | 0.954 | 0.9 | ok |
| Fixed:Rerandomization@0.2 | 50 | power20 | `~1` | gradient | 0.234 | 0.8 | 0.9 | **FAIL** |
| Fixed:Rerandomization@0.2 | 200 | power20 | `~1` | gradient | 0.208 | 0.852 | 0.9 | **FAIL** |
| Fixed:Rerandomization@0.2 | 50 | power20 | `~1` | lik_ratio | 0.242 | 0.814 | 0.9 | **FAIL** |
| Fixed:Rerandomization@0.2 | 200 | power20 | `~1` | lik_ratio | 0.212 | 0.854 | 0.9 | **FAIL** |
| Fixed:Rerandomization@0.2 | 50 | power20 | `~1` | rand | 0.342 |  | 0.95 | ok |
| Fixed:Rerandomization@0.2 | 200 | power20 | `~1` | rand | 0.076 |  | 0.95 | ok |
| Fixed:Rerandomization@0.2 | 50 | power20 | `~1` | score | 0.25 | 0.818 | 0.9 | **FAIL** |
| Fixed:Rerandomization@0.2 | 200 | power20 | `~1` | score | 0.21 | 0.854 | 0.9 | **FAIL** |
| Fixed:Rerandomization@0.2 | 50 | power20 | `~1` | wald | 0.172 | 0.868 | 0.9 | ok |
| Fixed:Rerandomization@0.2 | 200 | power20 | `~1` | wald | 0.088 | 0.948 | 0.9 | ok |
| SeqOneByOne:Atkinson | 50 | power20 | `~.` | gradient | 0.218 | 0.91 | 0.9 | ok |
| SeqOneByOne:Atkinson | 200 | power20 | `~.` | gradient | 0.182 | 0.958 | 0.938 | ok |
| SeqOneByOne:Atkinson | 50 | power20 | `~.` | lik_ratio | 0.204 | 0.92 | 0.9 | ok |
| SeqOneByOne:Atkinson | 200 | power20 | `~.` | lik_ratio | 0.182 | 0.958 | 0.938 | ok |
| SeqOneByOne:Atkinson | 50 | power20 | `~.` | rand | 0.118 |  | 0.95 | ok |
| SeqOneByOne:Atkinson | 200 | power20 | `~.` | rand | 0.178 |  | 0.95 | ok |
| SeqOneByOne:Atkinson | 50 | power20 | `~.` | score | 0.23 | 0.92 | 0.9 | ok |
| SeqOneByOne:Atkinson | 200 | power20 | `~.` | score | 0.18 | 0.958 | 0.938 | ok |
| SeqOneByOne:Atkinson | 50 | power20 | `~.` | wald | 0.244 | 0.919 | 0.9 | ok |
| SeqOneByOne:Atkinson | 200 | power20 | `~.` | wald | 0.186 | 0.96 | 0.938 | ok |
| SeqOneByOne:Atkinson | 50 | power20 | `~1` | gradient | 0.22 | 0.84 | 0.9 | **FAIL** |
| SeqOneByOne:Atkinson | 200 | power20 | `~1` | gradient | 0.202 | 0.872 | 0.938 | **FAIL** |
| SeqOneByOne:Atkinson | 50 | power20 | `~1` | lik_ratio | 0.216 | 0.846 | 0.9 | **FAIL** |
| SeqOneByOne:Atkinson | 200 | power20 | `~1` | lik_ratio | 0.202 | 0.874 | 0.938 | **FAIL** |
| SeqOneByOne:Atkinson | 50 | power20 | `~1` | rand | 0.12 |  | 0.95 | ok |
| SeqOneByOne:Atkinson | 200 | power20 | `~1` | rand | 0.11 |  | 0.95 | ok |
| SeqOneByOne:Atkinson | 50 | power20 | `~1` | score | 0.216 | 0.85 | 0.9 | **FAIL** |
| SeqOneByOne:Atkinson | 200 | power20 | `~1` | score | 0.202 | 0.874 | 0.938 | **FAIL** |
| SeqOneByOne:Atkinson | 50 | power20 | `~1` | wald | 0.122 | 0.944 | 0.9 | ok |
| SeqOneByOne:Atkinson | 200 | power20 | `~1` | wald | 0.086 | 0.956 | 0.938 | ok |
| SeqOneByOne:Bernoulli | 50 | power20 | `~.` | gradient | 0.188 | 0.93 | 0.9 | ok |
| SeqOneByOne:Bernoulli | 200 | power20 | `~.` | gradient | 0.2 | 0.952 | 0.938 | ok |
| SeqOneByOne:Bernoulli | 50 | power20 | `~.` | lik_ratio | 0.182 | 0.936 | 0.9 | ok |
| SeqOneByOne:Bernoulli | 200 | power20 | `~.` | lik_ratio | 0.2 | 0.952 | 0.938 | ok |
| SeqOneByOne:Bernoulli | 50 | power20 | `~.` | rand | 0.1 |  | 0.95 | ok |
| SeqOneByOne:Bernoulli | 200 | power20 | `~.` | rand | 0.194 |  | 0.95 | ok |
| SeqOneByOne:Bernoulli | 50 | power20 | `~.` | score | 0.198 | 0.93 | 0.9 | ok |
| SeqOneByOne:Bernoulli | 200 | power20 | `~.` | score | 0.2 | 0.952 | 0.938 | ok |
| SeqOneByOne:Bernoulli | 50 | power20 | `~.` | wald | 0.222 | 0.909 | 0.9 | ok |
| SeqOneByOne:Bernoulli | 200 | power20 | `~.` | wald | 0.202 | 0.954 | 0.938 | ok |
| SeqOneByOne:Bernoulli | 50 | power20 | `~1` | gradient | 0.26 | 0.832 | 0.9 | **FAIL** |
| SeqOneByOne:Bernoulli | 200 | power20 | `~1` | gradient | 0.25 | 0.846 | 0.938 | **FAIL** |
| SeqOneByOne:Bernoulli | 50 | power20 | `~1` | lik_ratio | 0.252 | 0.836 | 0.9 | **FAIL** |
| SeqOneByOne:Bernoulli | 200 | power20 | `~1` | lik_ratio | 0.25 | 0.844 | 0.938 | **FAIL** |
| SeqOneByOne:Bernoulli | 50 | power20 | `~1` | rand | 0.114 |  | 0.95 | ok |
| SeqOneByOne:Bernoulli | 200 | power20 | `~1` | rand | 0.098 |  | 0.95 | ok |
| SeqOneByOne:Bernoulli | 50 | power20 | `~1` | score | 0.248 | 0.844 | 0.9 | **FAIL** |
| SeqOneByOne:Bernoulli | 200 | power20 | `~1` | score | 0.242 | 0.848 | 0.938 | **FAIL** |
| SeqOneByOne:Bernoulli | 50 | power20 | `~1` | wald | 0.144 | 0.914 | 0.9 | ok |
| SeqOneByOne:Bernoulli | 200 | power20 | `~1` | wald | 0.102 | 0.966 | 0.938 | ok |
| SeqOneByOne:Bernoulli@0.2 | 50 | power20 | `~.` | gradient | 0.172 | 0.924 | 0.9 | ok |
| SeqOneByOne:Bernoulli@0.2 | 200 | power20 | `~.` | gradient | 0.132 | 0.958 | 0.9 | ok |
| SeqOneByOne:Bernoulli@0.2 | 50 | power20 | `~.` | lik_ratio | 0.176 | 0.934 | 0.9 | ok |
| SeqOneByOne:Bernoulli@0.2 | 200 | power20 | `~.` | lik_ratio | 0.134 | 0.958 | 0.9 | ok |
| SeqOneByOne:Bernoulli@0.2 | 50 | power20 | `~.` | rand | 0.114 |  | 0.95 | ok |
| SeqOneByOne:Bernoulli@0.2 | 200 | power20 | `~.` | rand | 0.234 |  | 0.95 | ok |
| SeqOneByOne:Bernoulli@0.2 | 50 | power20 | `~.` | score | 0.224 | 0.92 | 0.9 | ok |
| SeqOneByOne:Bernoulli@0.2 | 200 | power20 | `~.` | score | 0.138 | 0.96 | 0.9 | ok |
| SeqOneByOne:Bernoulli@0.2 | 50 | power20 | `~.` | wald | 0.254 | 0.882 | 0.9 | ok |
| SeqOneByOne:Bernoulli@0.2 | 200 | power20 | `~.` | wald | 0.158 | 0.944 | 0.9 | ok |
| SeqOneByOne:Bernoulli@0.2 | 50 | power20 | `~1` | gradient | 0.228 | 0.8 | 0.9 | **FAIL** |
| SeqOneByOne:Bernoulli@0.2 | 200 | power20 | `~1` | gradient | 0.204 | 0.834 | 0.9 | **FAIL** |
| SeqOneByOne:Bernoulli@0.2 | 50 | power20 | `~1` | lik_ratio | 0.22 | 0.806 | 0.9 | **FAIL** |
| SeqOneByOne:Bernoulli@0.2 | 200 | power20 | `~1` | lik_ratio | 0.208 | 0.836 | 0.9 | **FAIL** |
| SeqOneByOne:Bernoulli@0.2 | 50 | power20 | `~1` | rand | 0.326 |  | 0.95 | ok |
| SeqOneByOne:Bernoulli@0.2 | 200 | power20 | `~1` | rand | 0.072 |  | 0.95 | ok |
| SeqOneByOne:Bernoulli@0.2 | 50 | power20 | `~1` | score | 0.228 | 0.818 | 0.9 | **FAIL** |
| SeqOneByOne:Bernoulli@0.2 | 200 | power20 | `~1` | score | 0.21 | 0.84 | 0.9 | **FAIL** |
| SeqOneByOne:Bernoulli@0.2 | 50 | power20 | `~1` | wald | 0.184 | 0.838 | 0.9 | **FAIL** |
| SeqOneByOne:Bernoulli@0.2 | 200 | power20 | `~1` | wald | 0.092 | 0.928 | 0.9 | ok |
| SeqOneByOne:Efron | 50 | power20 | `~.` | gradient | 0.208 | 0.914 | 0.9 | ok |
| SeqOneByOne:Efron | 200 | power20 | `~.` | gradient | 0.168 | 0.95 | 0.938 | ok |
| SeqOneByOne:Efron | 50 | power20 | `~.` | lik_ratio | 0.194 | 0.922 | 0.9 | ok |
| SeqOneByOne:Efron | 200 | power20 | `~.` | lik_ratio | 0.168 | 0.95 | 0.938 | ok |
| SeqOneByOne:Efron | 50 | power20 | `~.` | rand | 0.118 |  | 0.95 | ok |
| SeqOneByOne:Efron | 200 | power20 | `~.` | rand | 0.162 |  | 0.95 | ok |
| SeqOneByOne:Efron | 50 | power20 | `~.` | score | 0.218 | 0.91 | 0.9 | ok |
| SeqOneByOne:Efron | 200 | power20 | `~.` | score | 0.166 | 0.95 | 0.938 | ok |
| SeqOneByOne:Efron | 50 | power20 | `~.` | wald | 0.267 | 0.895 | 0.9 | ok |
| SeqOneByOne:Efron | 200 | power20 | `~.` | wald | 0.178 | 0.946 | 0.938 | ok |
| SeqOneByOne:Efron | 50 | power20 | `~1` | gradient | 0.276 | 0.842 | 0.9 | **FAIL** |
| SeqOneByOne:Efron | 200 | power20 | `~1` | gradient | 0.256 | 0.828 | 0.938 | **FAIL** |
| SeqOneByOne:Efron | 50 | power20 | `~1` | lik_ratio | 0.276 | 0.846 | 0.9 | **FAIL** |
| SeqOneByOne:Efron | 200 | power20 | `~1` | lik_ratio | 0.256 | 0.828 | 0.938 | **FAIL** |
| SeqOneByOne:Efron | 50 | power20 | `~1` | rand | 0.106 |  | 0.95 | ok |
| SeqOneByOne:Efron | 200 | power20 | `~1` | rand | 0.102 |  | 0.95 | ok |
| SeqOneByOne:Efron | 50 | power20 | `~1` | score | 0.272 | 0.85 | 0.9 | **FAIL** |
| SeqOneByOne:Efron | 200 | power20 | `~1` | score | 0.256 | 0.828 | 0.938 | **FAIL** |
| SeqOneByOne:Efron | 50 | power20 | `~1` | wald | 0.148 | 0.938 | 0.9 | ok |
| SeqOneByOne:Efron | 200 | power20 | `~1` | wald | 0.108 | 0.942 | 0.938 | ok |
| SeqOneByOne:iBCRD | 50 | power20 | `~.` | gradient | 0.196 | 0.922 | 0.9 | ok |
| SeqOneByOne:iBCRD | 200 | power20 | `~.` | gradient | 0.184 | 0.954 | 0.938 | ok |
| SeqOneByOne:iBCRD | 50 | power20 | `~.` | lik_ratio | 0.186 | 0.926 | 0.9 | ok |
| SeqOneByOne:iBCRD | 200 | power20 | `~.` | lik_ratio | 0.186 | 0.954 | 0.938 | ok |
| SeqOneByOne:iBCRD | 50 | power20 | `~.` | rand | 0.122 |  | 0.95 | ok |
| SeqOneByOne:iBCRD | 200 | power20 | `~.` | rand | 0.192 |  | 0.95 | ok |
| SeqOneByOne:iBCRD | 50 | power20 | `~.` | score | 0.216 | 0.924 | 0.9 | ok |
| SeqOneByOne:iBCRD | 200 | power20 | `~.` | score | 0.186 | 0.954 | 0.938 | ok |
| SeqOneByOne:iBCRD | 50 | power20 | `~.` | wald | 0.237 | 0.909 | 0.9 | ok |
| SeqOneByOne:iBCRD | 200 | power20 | `~.` | wald | 0.196 | 0.948 | 0.938 | ok |
| SeqOneByOne:iBCRD | 50 | power20 | `~1` | gradient | 0.26 | 0.82 | 0.9 | **FAIL** |
| SeqOneByOne:iBCRD | 200 | power20 | `~1` | gradient | 0.26 | 0.844 | 0.938 | **FAIL** |
| SeqOneByOne:iBCRD | 50 | power20 | `~1` | lik_ratio | 0.258 | 0.822 | 0.9 | **FAIL** |
| SeqOneByOne:iBCRD | 200 | power20 | `~1` | lik_ratio | 0.26 | 0.846 | 0.938 | **FAIL** |
| SeqOneByOne:iBCRD | 50 | power20 | `~1` | rand | 0.114 |  | 0.95 | ok |
| SeqOneByOne:iBCRD | 200 | power20 | `~1` | rand | 0.1 |  | 0.95 | ok |
| SeqOneByOne:iBCRD | 50 | power20 | `~1` | score | 0.254 | 0.828 | 0.9 | **FAIL** |
| SeqOneByOne:iBCRD | 200 | power20 | `~1` | score | 0.258 | 0.846 | 0.938 | **FAIL** |
| SeqOneByOne:iBCRD | 50 | power20 | `~1` | wald | 0.154 | 0.924 | 0.9 | ok |
| SeqOneByOne:iBCRD | 200 | power20 | `~1` | wald | 0.104 | 0.954 | 0.938 | ok |
| SeqOneByOne:iBCRD@0.2 | 50 | power20 | `~.` | gradient | 0.172 | 0.912 | 0.9 | ok |
| SeqOneByOne:iBCRD@0.2 | 200 | power20 | `~.` | gradient | 0.124 | 0.968 | 0.9 | ok |
| SeqOneByOne:iBCRD@0.2 | 50 | power20 | `~.` | lik_ratio | 0.168 | 0.928 | 0.9 | ok |
| SeqOneByOne:iBCRD@0.2 | 200 | power20 | `~.` | lik_ratio | 0.128 | 0.97 | 0.9 | ok |
| SeqOneByOne:iBCRD@0.2 | 50 | power20 | `~.` | rand | 0.13 |  | 0.95 | ok |
| SeqOneByOne:iBCRD@0.2 | 200 | power20 | `~.` | rand | 0.204 |  | 0.95 | ok |
| SeqOneByOne:iBCRD@0.2 | 50 | power20 | `~.` | score | 0.214 | 0.922 | 0.9 | ok |
| SeqOneByOne:iBCRD@0.2 | 200 | power20 | `~.` | score | 0.13 | 0.968 | 0.9 | ok |
| SeqOneByOne:iBCRD@0.2 | 50 | power20 | `~.` | wald | 0.244 | 0.876 | 0.9 | ok |
| SeqOneByOne:iBCRD@0.2 | 200 | power20 | `~.` | wald | 0.164 | 0.946 | 0.9 | ok |
| SeqOneByOne:iBCRD@0.2 | 50 | power20 | `~1` | gradient | 0.254 | 0.796 | 0.9 | **FAIL** |
| SeqOneByOne:iBCRD@0.2 | 200 | power20 | `~1` | gradient | 0.214 | 0.85 | 0.9 | **FAIL** |
| SeqOneByOne:iBCRD@0.2 | 50 | power20 | `~1` | lik_ratio | 0.256 | 0.806 | 0.9 | **FAIL** |
| SeqOneByOne:iBCRD@0.2 | 200 | power20 | `~1` | lik_ratio | 0.212 | 0.848 | 0.9 | **FAIL** |
| SeqOneByOne:iBCRD@0.2 | 50 | power20 | `~1` | rand | 0.302 |  | 0.95 | ok |
| SeqOneByOne:iBCRD@0.2 | 200 | power20 | `~1` | rand | 0.09 |  | 0.95 | ok |
| SeqOneByOne:iBCRD@0.2 | 50 | power20 | `~1` | score | 0.252 | 0.81 | 0.9 | **FAIL** |
| SeqOneByOne:iBCRD@0.2 | 200 | power20 | `~1` | score | 0.218 | 0.84 | 0.9 | **FAIL** |
| SeqOneByOne:iBCRD@0.2 | 50 | power20 | `~1` | wald | 0.174 | 0.862 | 0.9 | ok |
| SeqOneByOne:iBCRD@0.2 | 200 | power20 | `~1` | wald | 0.094 | 0.932 | 0.9 | ok |
| SeqOneByOne:KK14 | 50 | power20 | `~.` | gradient | 0.194 | 0.902 | 0.9 | ok |
| SeqOneByOne:KK14 | 200 | power20 | `~.` | gradient | 0.184 | 0.954 | 0.938 | ok |
| SeqOneByOne:KK14 | 50 | power20 | `~.` | lik_ratio | 0.19 | 0.912 | 0.9 | ok |
| SeqOneByOne:KK14 | 200 | power20 | `~.` | lik_ratio | 0.186 | 0.958 | 0.938 | ok |
| SeqOneByOne:KK14 | 50 | power20 | `~.` | rand | 0.108 |  | 0.95 | ok |
| SeqOneByOne:KK14 | 200 | power20 | `~.` | rand | 0.166 |  | 0.95 | ok |
| SeqOneByOne:KK14 | 50 | power20 | `~.` | score | 0.224 | 0.898 | 0.9 | ok |
| SeqOneByOne:KK14 | 200 | power20 | `~.` | score | 0.186 | 0.96 | 0.938 | ok |
| SeqOneByOne:KK14 | 50 | power20 | `~.` | wald | 0.224 | 0.904 | 0.9 | ok |
| SeqOneByOne:KK14 | 200 | power20 | `~.` | wald | 0.202 | 0.946 | 0.938 | ok |
| SeqOneByOne:KK14 | 50 | power20 | `~1` | gradient | 0.254 | 0.846 | 0.9 | **FAIL** |
| SeqOneByOne:KK14 | 200 | power20 | `~1` | gradient | 0.238 | 0.85 | 0.938 | **FAIL** |
| SeqOneByOne:KK14 | 50 | power20 | `~1` | lik_ratio | 0.248 | 0.852 | 0.9 | **FAIL** |
| SeqOneByOne:KK14 | 200 | power20 | `~1` | lik_ratio | 0.238 | 0.85 | 0.938 | **FAIL** |
| SeqOneByOne:KK14 | 50 | power20 | `~1` | rand | 0.104 |  | 0.95 | ok |
| SeqOneByOne:KK14 | 200 | power20 | `~1` | rand | 0.13 |  | 0.95 | ok |
| SeqOneByOne:KK14 | 50 | power20 | `~1` | score | 0.248 | 0.848 | 0.9 | **FAIL** |
| SeqOneByOne:KK14 | 200 | power20 | `~1` | score | 0.236 | 0.85 | 0.938 | **FAIL** |
| SeqOneByOne:KK14 | 50 | power20 | `~1` | wald | 0.118 | 0.94 | 0.9 | ok |
| SeqOneByOne:KK14 | 200 | power20 | `~1` | wald | 0.092 | 0.958 | 0.938 | ok |
| SeqOneByOne:KK21 | 50 | power20 | `~.` | gradient | 0.214 | 0.94 | 0.9 | ok |
| SeqOneByOne:KK21 | 200 | power20 | `~.` | gradient | 0.174 | 0.948 | 0.938 | ok |
| SeqOneByOne:KK21 | 50 | power20 | `~.` | lik_ratio | 0.198 | 0.942 | 0.9 | ok |
| SeqOneByOne:KK21 | 200 | power20 | `~.` | lik_ratio | 0.174 | 0.948 | 0.938 | ok |
| SeqOneByOne:KK21 | 50 | power20 | `~.` | rand | 0.11 |  | 0.95 | ok |
| SeqOneByOne:KK21 | 200 | power20 | `~.` | rand | 0.16 |  | 0.95 | ok |
| SeqOneByOne:KK21 | 50 | power20 | `~.` | score | 0.222 | 0.936 | 0.9 | ok |
| SeqOneByOne:KK21 | 200 | power20 | `~.` | score | 0.174 | 0.948 | 0.938 | ok |
| SeqOneByOne:KK21 | 50 | power20 | `~.` | wald | 0.232 | 0.924 | 0.9 | ok |
| SeqOneByOne:KK21 | 200 | power20 | `~.` | wald | 0.184 | 0.946 | 0.938 | ok |
| SeqOneByOne:KK21 | 50 | power20 | `~1` | gradient | 0.236 | 0.85 | 0.9 | **FAIL** |
| SeqOneByOne:KK21 | 200 | power20 | `~1` | gradient | 0.218 | 0.874 | 0.938 | **FAIL** |
| SeqOneByOne:KK21 | 50 | power20 | `~1` | lik_ratio | 0.234 | 0.85 | 0.9 | **FAIL** |
| SeqOneByOne:KK21 | 200 | power20 | `~1` | lik_ratio | 0.216 | 0.874 | 0.938 | **FAIL** |
| SeqOneByOne:KK21 | 50 | power20 | `~1` | rand | 0.092 |  | 0.95 | ok |
| SeqOneByOne:KK21 | 200 | power20 | `~1` | rand | 0.122 |  | 0.95 | ok |
| SeqOneByOne:KK21 | 50 | power20 | `~1` | score | 0.226 | 0.854 | 0.9 | **FAIL** |
| SeqOneByOne:KK21 | 200 | power20 | `~1` | score | 0.216 | 0.874 | 0.938 | **FAIL** |
| SeqOneByOne:KK21 | 50 | power20 | `~1` | wald | 0.11 | 0.948 | 0.9 | ok |
| SeqOneByOne:KK21 | 200 | power20 | `~1` | wald | 0.08 | 0.956 | 0.938 | ok |
| SeqOneByOne:KK21stepwise | 50 | power20 | `~.` | gradient | 0.238 | 0.918 | 0.9 | ok |
| SeqOneByOne:KK21stepwise | 200 | power20 | `~.` | gradient | 0.19 | 0.946 | 0.938 | ok |
| SeqOneByOne:KK21stepwise | 50 | power20 | `~.` | lik_ratio | 0.22 | 0.932 | 0.9 | ok |
| SeqOneByOne:KK21stepwise | 200 | power20 | `~.` | lik_ratio | 0.186 | 0.946 | 0.938 | ok |
| SeqOneByOne:KK21stepwise | 50 | power20 | `~.` | rand | 0.13 |  | 0.95 | ok |
| SeqOneByOne:KK21stepwise | 200 | power20 | `~.` | rand | 0.178 |  | 0.95 | ok |
| SeqOneByOne:KK21stepwise | 50 | power20 | `~.` | score | 0.254 | 0.912 | 0.9 | ok |
| SeqOneByOne:KK21stepwise | 200 | power20 | `~.` | score | 0.184 | 0.946 | 0.938 | ok |
| SeqOneByOne:KK21stepwise | 50 | power20 | `~.` | wald | 0.264 | 0.907 | 0.9 | ok |
| SeqOneByOne:KK21stepwise | 200 | power20 | `~.` | wald | 0.194 | 0.942 | 0.938 | ok |
| SeqOneByOne:KK21stepwise | 50 | power20 | `~1` | gradient | 0.256 | 0.848 | 0.9 | **FAIL** |
| SeqOneByOne:KK21stepwise | 200 | power20 | `~1` | gradient | 0.22 | 0.878 | 0.938 | **FAIL** |
| SeqOneByOne:KK21stepwise | 50 | power20 | `~1` | lik_ratio | 0.252 | 0.848 | 0.9 | **FAIL** |
| SeqOneByOne:KK21stepwise | 200 | power20 | `~1` | lik_ratio | 0.22 | 0.88 | 0.938 | **FAIL** |
| SeqOneByOne:KK21stepwise | 50 | power20 | `~1` | rand | 0.098 |  | 0.95 | ok |
| SeqOneByOne:KK21stepwise | 200 | power20 | `~1` | rand | 0.118 |  | 0.95 | ok |
| SeqOneByOne:KK21stepwise | 50 | power20 | `~1` | score | 0.246 | 0.85 | 0.9 | **FAIL** |
| SeqOneByOne:KK21stepwise | 200 | power20 | `~1` | score | 0.22 | 0.882 | 0.938 | **FAIL** |
| SeqOneByOne:KK21stepwise | 50 | power20 | `~1` | wald | 0.134 | 0.96 | 0.9 | ok |
| SeqOneByOne:KK21stepwise | 200 | power20 | `~1` | wald | 0.08 | 0.966 | 0.938 | ok |
| SeqOneByOne:PocockSimon | 50 | power20 | `~.` | gradient | 0.236 | 0.91 | 0.9 | ok |
| SeqOneByOne:PocockSimon | 200 | power20 | `~.` | gradient | 0.164 | 0.956 | 0.938 | ok |
| SeqOneByOne:PocockSimon | 50 | power20 | `~.` | lik_ratio | 0.23 | 0.92 | 0.9 | ok |
| SeqOneByOne:PocockSimon | 200 | power20 | `~.` | lik_ratio | 0.162 | 0.956 | 0.938 | ok |
| SeqOneByOne:PocockSimon | 50 | power20 | `~.` | rand | 0.132 |  | 0.95 | ok |
| SeqOneByOne:PocockSimon | 200 | power20 | `~.` | rand | 0.16 |  | 0.95 | ok |
| SeqOneByOne:PocockSimon | 50 | power20 | `~.` | score | 0.25 | 0.914 | 0.9 | ok |
| SeqOneByOne:PocockSimon | 200 | power20 | `~.` | score | 0.16 | 0.956 | 0.938 | ok |
| SeqOneByOne:PocockSimon | 50 | power20 | `~.` | wald | 0.273 | 0.883 | 0.9 | ok |
| SeqOneByOne:PocockSimon | 200 | power20 | `~.` | wald | 0.18 | 0.948 | 0.938 | ok |
| SeqOneByOne:PocockSimon | 50 | power20 | `~1` | gradient | 0.252 | 0.832 | 0.9 | **FAIL** |
| SeqOneByOne:PocockSimon | 200 | power20 | `~1` | gradient | 0.236 | 0.858 | 0.938 | **FAIL** |
| SeqOneByOne:PocockSimon | 50 | power20 | `~1` | lik_ratio | 0.248 | 0.834 | 0.9 | **FAIL** |
| SeqOneByOne:PocockSimon | 200 | power20 | `~1` | lik_ratio | 0.236 | 0.858 | 0.938 | **FAIL** |
| SeqOneByOne:PocockSimon | 50 | power20 | `~1` | rand | 0.102 |  | 0.95 | ok |
| SeqOneByOne:PocockSimon | 200 | power20 | `~1` | rand | 0.102 |  | 0.95 | ok |
| SeqOneByOne:PocockSimon | 50 | power20 | `~1` | score | 0.248 | 0.838 | 0.9 | **FAIL** |
| SeqOneByOne:PocockSimon | 200 | power20 | `~1` | score | 0.236 | 0.856 | 0.938 | **FAIL** |
| SeqOneByOne:PocockSimon | 50 | power20 | `~1` | wald | 0.134 | 0.942 | 0.9 | ok |
| SeqOneByOne:PocockSimon | 200 | power20 | `~1` | wald | 0.11 | 0.952 | 0.938 | ok |
| SeqOneByOne:RandomBlockSize | 50 | power20 | `~.` | gradient | 0.208 | 0.908 | 0.9 | ok |
| SeqOneByOne:RandomBlockSize | 200 | power20 | `~.` | gradient | 0.182 | 0.962 | 0.938 | ok |
| SeqOneByOne:RandomBlockSize | 50 | power20 | `~.` | lik_ratio | 0.2 | 0.918 | 0.9 | ok |
| SeqOneByOne:RandomBlockSize | 200 | power20 | `~.` | lik_ratio | 0.182 | 0.962 | 0.938 | ok |
| SeqOneByOne:RandomBlockSize | 50 | power20 | `~.` | rand | 0.112 |  | 0.95 | ok |
| SeqOneByOne:RandomBlockSize | 200 | power20 | `~.` | rand | 0.178 |  | 0.95 | ok |
| SeqOneByOne:RandomBlockSize | 50 | power20 | `~.` | score | 0.236 | 0.904 | 0.9 | ok |
| SeqOneByOne:RandomBlockSize | 200 | power20 | `~.` | score | 0.18 | 0.962 | 0.938 | ok |
| SeqOneByOne:RandomBlockSize | 50 | power20 | `~.` | wald | 0.225 | 0.911 | 0.9 | ok |
| SeqOneByOne:RandomBlockSize | 200 | power20 | `~.` | wald | 0.204 | 0.944 | 0.938 | ok |
| SeqOneByOne:RandomBlockSize | 50 | power20 | `~1` | gradient | 0.264 | 0.858 | 0.9 | ok |
| SeqOneByOne:RandomBlockSize | 200 | power20 | `~1` | gradient | 0.246 | 0.858 | 0.938 | **FAIL** |
| SeqOneByOne:RandomBlockSize | 50 | power20 | `~1` | lik_ratio | 0.262 | 0.86 | 0.9 | ok |
| SeqOneByOne:RandomBlockSize | 200 | power20 | `~1` | lik_ratio | 0.242 | 0.858 | 0.938 | **FAIL** |
| SeqOneByOne:RandomBlockSize | 50 | power20 | `~1` | rand | 0.1 |  | 0.95 | ok |
| SeqOneByOne:RandomBlockSize | 200 | power20 | `~1` | rand | 0.092 |  | 0.95 | ok |
| SeqOneByOne:RandomBlockSize | 50 | power20 | `~1` | score | 0.262 | 0.852 | 0.9 | **FAIL** |
| SeqOneByOne:RandomBlockSize | 200 | power20 | `~1` | score | 0.24 | 0.86 | 0.938 | **FAIL** |
| SeqOneByOne:RandomBlockSize | 50 | power20 | `~1` | wald | 0.124 | 0.928 | 0.9 | ok |
| SeqOneByOne:RandomBlockSize | 200 | power20 | `~1` | wald | 0.106 | 0.952 | 0.938 | ok |
| SeqOneByOne:RandomBlockSize@0.2 | 50 | power20 | `~.` | gradient | 0.144 | 0.91 | 0.9 | ok |
| SeqOneByOne:RandomBlockSize@0.2 | 200 | power20 | `~.` | gradient | 0.128 | 0.958 | 0.9 | ok |
| SeqOneByOne:RandomBlockSize@0.2 | 50 | power20 | `~.` | lik_ratio | 0.152 | 0.916 | 0.9 | ok |
| SeqOneByOne:RandomBlockSize@0.2 | 200 | power20 | `~.` | lik_ratio | 0.128 | 0.96 | 0.9 | ok |
| SeqOneByOne:RandomBlockSize@0.2 | 50 | power20 | `~.` | rand | 0.118 |  | 0.95 | ok |
| SeqOneByOne:RandomBlockSize@0.2 | 200 | power20 | `~.` | rand | 0.204 |  | 0.95 | ok |
| SeqOneByOne:RandomBlockSize@0.2 | 50 | power20 | `~.` | score | 0.19 | 0.918 | 0.9 | ok |
| SeqOneByOne:RandomBlockSize@0.2 | 200 | power20 | `~.` | score | 0.144 | 0.958 | 0.9 | ok |
| SeqOneByOne:RandomBlockSize@0.2 | 50 | power20 | `~.` | wald | 0.234 | 0.888 | 0.9 | ok |
| SeqOneByOne:RandomBlockSize@0.2 | 200 | power20 | `~.` | wald | 0.176 | 0.944 | 0.9 | ok |
| SeqOneByOne:RandomBlockSize@0.2 | 50 | power20 | `~1` | gradient | 0.224 | 0.822 | 0.9 | **FAIL** |
| SeqOneByOne:RandomBlockSize@0.2 | 200 | power20 | `~1` | gradient | 0.226 | 0.83 | 0.9 | **FAIL** |
| SeqOneByOne:RandomBlockSize@0.2 | 50 | power20 | `~1` | lik_ratio | 0.22 | 0.834 | 0.9 | **FAIL** |
| SeqOneByOne:RandomBlockSize@0.2 | 200 | power20 | `~1` | lik_ratio | 0.228 | 0.832 | 0.9 | **FAIL** |
| SeqOneByOne:RandomBlockSize@0.2 | 50 | power20 | `~1` | rand | 0.326 |  | 0.95 | ok |
| SeqOneByOne:RandomBlockSize@0.2 | 200 | power20 | `~1` | rand | 0.094 |  | 0.95 | ok |
| SeqOneByOne:RandomBlockSize@0.2 | 50 | power20 | `~1` | score | 0.23 | 0.848 | 0.9 | **FAIL** |
| SeqOneByOne:RandomBlockSize@0.2 | 200 | power20 | `~1` | score | 0.236 | 0.84 | 0.9 | **FAIL** |
| SeqOneByOne:RandomBlockSize@0.2 | 50 | power20 | `~1` | wald | 0.14 | 0.892 | 0.9 | ok |
| SeqOneByOne:RandomBlockSize@0.2 | 200 | power20 | `~1` | wald | 0.104 | 0.93 | 0.9 | ok |
| SeqOneByOne:SPBR | 50 | power20 | `~.` | gradient | 0.212 | 0.912 | 0.9 | ok |
| SeqOneByOne:SPBR | 200 | power20 | `~.` | gradient | 0.154 | 0.958 | 0.938 | ok |
| SeqOneByOne:SPBR | 50 | power20 | `~.` | lik_ratio | 0.186 | 0.926 | 0.9 | ok |
| SeqOneByOne:SPBR | 200 | power20 | `~.` | lik_ratio | 0.154 | 0.958 | 0.938 | ok |
| SeqOneByOne:SPBR | 50 | power20 | `~.` | rand | 0.12 |  | 0.95 | ok |
| SeqOneByOne:SPBR | 200 | power20 | `~.` | rand | 0.154 |  | 0.95 | ok |
| SeqOneByOne:SPBR | 50 | power20 | `~.` | score | 0.224 | 0.916 | 0.9 | ok |
| SeqOneByOne:SPBR | 200 | power20 | `~.` | score | 0.154 | 0.958 | 0.938 | ok |
| SeqOneByOne:SPBR | 50 | power20 | `~.` | wald | 0.235 | 0.881 | 0.9 | ok |
| SeqOneByOne:SPBR | 200 | power20 | `~.` | wald | 0.178 | 0.946 | 0.938 | ok |
| SeqOneByOne:SPBR | 50 | power20 | `~1` | gradient | 0.324 | 0.814 | 0.9 | **FAIL** |
| SeqOneByOne:SPBR | 200 | power20 | `~1` | gradient | 0.204 | 0.842 | 0.938 | **FAIL** |
| SeqOneByOne:SPBR | 50 | power20 | `~1` | lik_ratio | 0.314 | 0.814 | 0.9 | **FAIL** |
| SeqOneByOne:SPBR | 200 | power20 | `~1` | lik_ratio | 0.204 | 0.844 | 0.938 | **FAIL** |
| SeqOneByOne:SPBR | 50 | power20 | `~1` | rand | 0.146 |  | 0.95 | ok |
| SeqOneByOne:SPBR | 200 | power20 | `~1` | rand | 0.096 |  | 0.95 | ok |
| SeqOneByOne:SPBR | 50 | power20 | `~1` | score | 0.31 | 0.816 | 0.9 | **FAIL** |
| SeqOneByOne:SPBR | 200 | power20 | `~1` | score | 0.204 | 0.846 | 0.938 | **FAIL** |
| SeqOneByOne:SPBR | 50 | power20 | `~1` | wald | 0.17 | 0.924 | 0.9 | ok |
| SeqOneByOne:SPBR | 200 | power20 | `~1` | wald | 0.1 | 0.958 | 0.938 | ok |
| SeqOneByOne:SPBR@0.2 | 50 | power20 | `~.` | gradient | 0.178 | 0.898 | 0.9 | ok |
| SeqOneByOne:SPBR@0.2 | 200 | power20 | `~.` | gradient | 0.134 | 0.946 | 0.9 | ok |
| SeqOneByOne:SPBR@0.2 | 50 | power20 | `~.` | lik_ratio | 0.178 | 0.894 | 0.9 | ok |
| SeqOneByOne:SPBR@0.2 | 200 | power20 | `~.` | lik_ratio | 0.138 | 0.946 | 0.9 | ok |
| SeqOneByOne:SPBR@0.2 | 50 | power20 | `~.` | rand | 0.142 |  | 0.95 | ok |
| SeqOneByOne:SPBR@0.2 | 200 | power20 | `~.` | rand | 0.222 |  | 0.95 | ok |
| SeqOneByOne:SPBR@0.2 | 50 | power20 | `~.` | score | 0.222 | 0.892 | 0.9 | ok |
| SeqOneByOne:SPBR@0.2 | 200 | power20 | `~.` | score | 0.146 | 0.948 | 0.9 | ok |
| SeqOneByOne:SPBR@0.2 | 50 | power20 | `~.` | wald | 0.263 | 0.864 | 0.9 | ok |
| SeqOneByOne:SPBR@0.2 | 200 | power20 | `~.` | wald | 0.17 | 0.928 | 0.9 | ok |
| SeqOneByOne:SPBR@0.2 | 50 | power20 | `~1` | gradient | 0.198 | 0.828 | 0.9 | **FAIL** |
| SeqOneByOne:SPBR@0.2 | 200 | power20 | `~1` | gradient | 0.214 | 0.834 | 0.9 | **FAIL** |
| SeqOneByOne:SPBR@0.2 | 50 | power20 | `~1` | lik_ratio | 0.198 | 0.836 | 0.9 | **FAIL** |
| SeqOneByOne:SPBR@0.2 | 200 | power20 | `~1` | lik_ratio | 0.216 | 0.84 | 0.9 | **FAIL** |
| SeqOneByOne:SPBR@0.2 | 50 | power20 | `~1` | rand | 0.312 |  | 0.95 | ok |
| SeqOneByOne:SPBR@0.2 | 200 | power20 | `~1` | rand | 0.09 |  | 0.95 | ok |
| SeqOneByOne:SPBR@0.2 | 50 | power20 | `~1` | score | 0.202 | 0.846 | 0.9 | **FAIL** |
| SeqOneByOne:SPBR@0.2 | 200 | power20 | `~1` | score | 0.226 | 0.844 | 0.9 | **FAIL** |
| SeqOneByOne:SPBR@0.2 | 50 | power20 | `~1` | wald | 0.114 | 0.9 | 0.9 | ok |
| SeqOneByOne:SPBR@0.2 | 200 | power20 | `~1` | wald | 0.092 | 0.932 | 0.9 | ok |
| SeqOneByOne:Urn | 50 | power20 | `~.` | gradient | 0.2 | 0.932 | 0.9 | ok |
| SeqOneByOne:Urn | 200 | power20 | `~.` | gradient | 0.172 | 0.96 | 0.938 | ok |
| SeqOneByOne:Urn | 50 | power20 | `~.` | lik_ratio | 0.192 | 0.946 | 0.9 | ok |
| SeqOneByOne:Urn | 200 | power20 | `~.` | lik_ratio | 0.172 | 0.962 | 0.938 | ok |
| SeqOneByOne:Urn | 50 | power20 | `~.` | rand | 0.106 |  | 0.95 | ok |
| SeqOneByOne:Urn | 200 | power20 | `~.` | rand | 0.158 |  | 0.95 | ok |
| SeqOneByOne:Urn | 50 | power20 | `~.` | score | 0.216 | 0.932 | 0.9 | ok |
| SeqOneByOne:Urn | 200 | power20 | `~.` | score | 0.17 | 0.962 | 0.938 | ok |
| SeqOneByOne:Urn | 50 | power20 | `~.` | wald | 0.207 | 0.905 | 0.9 | ok |
| SeqOneByOne:Urn | 200 | power20 | `~.` | wald | 0.174 | 0.958 | 0.938 | ok |
| SeqOneByOne:Urn | 50 | power20 | `~1` | gradient | 0.266 | 0.822 | 0.9 | **FAIL** |
| SeqOneByOne:Urn | 200 | power20 | `~1` | gradient | 0.276 | 0.85 | 0.938 | **FAIL** |
| SeqOneByOne:Urn | 50 | power20 | `~1` | lik_ratio | 0.264 | 0.824 | 0.9 | **FAIL** |
| SeqOneByOne:Urn | 200 | power20 | `~1` | lik_ratio | 0.276 | 0.85 | 0.938 | **FAIL** |
| SeqOneByOne:Urn | 50 | power20 | `~1` | rand | 0.112 |  | 0.95 | ok |
| SeqOneByOne:Urn | 200 | power20 | `~1` | rand | 0.106 |  | 0.95 | ok |
| SeqOneByOne:Urn | 50 | power20 | `~1` | score | 0.26 | 0.82 | 0.9 | **FAIL** |
| SeqOneByOne:Urn | 200 | power20 | `~1` | score | 0.278 | 0.854 | 0.938 | **FAIL** |
| SeqOneByOne:Urn | 50 | power20 | `~1` | wald | 0.14 | 0.916 | 0.9 | ok |
| SeqOneByOne:Urn | 200 | power20 | `~1` | wald | 0.112 | 0.95 | 0.938 | ok |

[← Campaign 2026-11-15-e36c7710 summary](README.md)
