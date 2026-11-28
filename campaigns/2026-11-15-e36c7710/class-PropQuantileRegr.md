[← Campaign 2026-11-15-e36c7710 summary](README.md)

# Class PropQuantileRegr

Part of the [Classes index](classes.md). Response type: proportion. Status: null effect complete, power effects in progress. Verdict: **pass so far** (2 flagged test(s): 0 failing, 0 pending, 2 cleared).

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/class-PropQuantileRegr-dark.png"><img alt="PropQuantileRegr convergence of the error with n" src="figures/class-PropQuantileRegr.png"></picture>

Convergence verdicts (worst over designs, formulas and effects; provisional until the class is complete):

| procedure | metric | verdict |
|---|---|---|
| estimator (bias) | bias | faster |
| wald | coverage | slower |
| rand | size | not applicable |
| wald | size | slower |

Null effect: 384 cells (0 failing). Size, coverage and bias / SD against the level each is held to.

| design | n | formula | procedure | size | coverage | bias / SD | size level | coverage level | verdict |
|---|---|---|---|---|---|---|---|---|---|
| Fixed:Bernoulli | 50 | `~.` | rand | 0.044 |  | 0.0039 | 0.05 | 0.95 | ok |
| Fixed:Bernoulli | 200 | `~.` | rand | 0.055 |  | 0.022 | 0.05 | 0.95 | ok |
| Fixed:Bernoulli | 1000 | `~.` | rand | 0.047 |  | -0.018 | 0.05 | 0.95 | ok |
| Fixed:Bernoulli | 50 | `~.` | wald | 0.065 | 0.935 | 0.0039 | 0.1 | 0.9 | ok |
| Fixed:Bernoulli | 200 | `~.` | wald | 0.066 | 0.934 | 0.022 | 0.0698 | 0.93 | ok |
| Fixed:Bernoulli | 1000 | `~.` | wald | 0.046 | 0.954 | -0.018 | 0.0568 | 0.943 | ok |
| Fixed:Bernoulli | 50 | `~1` | rand | 0.053 |  | -0.019 | 0.05 | 0.95 | ok |
| Fixed:Bernoulli | 200 | `~1` | rand | 0.049 |  | -0.018 | 0.05 | 0.95 | ok |
| Fixed:Bernoulli | 1000 | `~1` | rand | 0.057 |  | 0.019 | 0.05 | 0.95 | ok |
| Fixed:Bernoulli | 50 | `~1` | wald | 0.034 | 0.966 | -0.019 | 0.1 | 0.9 | ok |
| Fixed:Bernoulli | 200 | `~1` | wald | 0.053 | 0.947 | -0.018 | 0.0698 | 0.93 | ok |
| Fixed:Bernoulli | 1000 | `~1` | wald | 0.049 | 0.951 | 0.019 | 0.0568 | 0.943 | ok |
| Fixed:Bernoulli@0.2 | 50 | `~.` | rand | 0.054 |  | -0.02 | 0.05 | 0.95 | ok |
| Fixed:Bernoulli@0.2 | 200 | `~.` | rand | 0.05 |  | 0.028 | 0.05 | 0.95 | ok |
| Fixed:Bernoulli@0.2 | 1000 | `~.` | rand | 0.066 |  | -0.07 | 0.05 | 0.95 | ok |
| Fixed:Bernoulli@0.2 | 50 | `~.` | wald | 0.077 | 0.923 | -0.02 | 0.1 | 0.9 | ok |
| Fixed:Bernoulli@0.2 | 200 | `~.` | wald | 0.076 | 0.924 | 0.028 | 0.1 | 0.9 | ok |
| Fixed:Bernoulli@0.2 | 1000 | `~.` | wald | 0.076 | 0.924 | -0.07 | 0.05 | 0.95 | ok |
| Fixed:Bernoulli@0.2 | 50 | `~1` | rand | 0.052 |  | 0.021 | 0.05 | 0.95 | ok |
| Fixed:Bernoulli@0.2 | 200 | `~1` | rand | 0.054 |  | 0.00036 | 0.05 | 0.95 | ok |
| Fixed:Bernoulli@0.2 | 1000 | `~1` | rand | 0.054 |  | -0.053 | 0.05 | 0.95 | ok |
| Fixed:Bernoulli@0.2 | 50 | `~1` | wald | 0.041 | 0.959 | 0.021 | 0.1 | 0.9 | ok |
| Fixed:Bernoulli@0.2 | 200 | `~1` | wald | 0.066 | 0.934 | 0.00036 | 0.1 | 0.9 | ok |
| Fixed:Bernoulli@0.2 | 1000 | `~1` | wald | 0.052 | 0.948 | -0.053 | 0.0698 | 0.93 | ok |
| Fixed:BinaryMatch | 50 | `~.` | rand | 0.047 |  | -0.0053 | 0.05 | 0.95 | ok |
| Fixed:BinaryMatch | 200 | `~.` | rand | 0.052 |  | 0.038 | 0.05 | 0.95 | ok |
| Fixed:BinaryMatch | 1000 | `~.` | rand | 0.053 |  | 0.013 | 0.05 | 0.95 | ok |
| Fixed:BinaryMatch | 50 | `~.` | wald | 0.06 | 0.94 | -0.0053 | 0.1 | 0.9 | ok |
| Fixed:BinaryMatch | 200 | `~.` | wald | 0.064 | 0.936 | 0.038 | 0.0698 | 0.93 | ok |
| Fixed:BinaryMatch | 1000 | `~.` | wald | 0.056 | 0.944 | 0.013 | 0.0568 | 0.943 | ok |
| Fixed:BinaryMatch | 50 | `~1` | rand | 0.044 |  | -0.044 | 0.05 | 0.95 | ok |
| Fixed:BinaryMatch | 200 | `~1` | rand | 0.055 |  | 0.051 | 0.05 | 0.95 | ok |
| Fixed:BinaryMatch | 1000 | `~1` | rand | 0.06 |  | -0.029 | 0.05 | 0.95 | ok |
| Fixed:BinaryMatch | 50 | `~1` | wald | 0.002 | 0.998 | -0.044 | 0.1 | 0.9 | ok |
| Fixed:BinaryMatch | 200 | `~1` | wald | 0.004 | 0.996 | 0.051 | 0.0698 | 0.93 | ok |
| Fixed:BinaryMatch | 1000 | `~1` | wald | 0.006 | 0.994 | -0.029 | 0.0568 | 0.943 | ok |
| Fixed:Blocking | 50 | `~.` | rand | 0.051 |  | 0.006 | 0.05 | 0.95 | ok |
| Fixed:Blocking | 200 | `~.` | rand | 0.053 |  | 0.011 | 0.05 | 0.95 | ok |
| Fixed:Blocking | 1000 | `~.` | rand | 0.052 |  | -0.048 | 0.05 | 0.95 | ok |
| Fixed:Blocking | 50 | `~.` | wald | 0.053 | 0.947 | 0.006 | 0.1 | 0.9 | ok |
| Fixed:Blocking | 200 | `~.` | wald | 0.065 | 0.935 | 0.011 | 0.0698 | 0.93 | ok |
| Fixed:Blocking | 1000 | `~.` | wald | 0.054 | 0.946 | -0.048 | 0.0568 | 0.943 | ok |
| Fixed:Blocking | 50 | `~1` | rand | 0.047 |  | 0.021 | 0.05 | 0.95 | ok |
| Fixed:Blocking | 200 | `~1` | rand | 0.044 |  | 0.064 | 0.05 | 0.95 | ok |
| Fixed:Blocking | 1000 | `~1` | rand | 0.047 |  | -0.014 | 0.05 | 0.95 | ok |
| Fixed:Blocking | 50 | `~1` | wald | 0.015 | 0.985 | 0.021 | 0.1 | 0.9 | ok |
| Fixed:Blocking | 200 | `~1` | wald | 0.025 | 0.975 | 0.064 | 0.0698 | 0.93 | ok |
| Fixed:Blocking | 1000 | `~1` | wald | 0.037 | 0.963 | -0.014 | 0.0568 | 0.943 | ok |
| Fixed:Blocking@0.2 | 50 | `~.` | rand | 0.038 |  | 0.045 | 0.05 | 0.95 | ok |
| Fixed:Blocking@0.2 | 200 | `~.` | rand | 0.057 |  | 0.01 | 0.05 | 0.95 | ok |
| Fixed:Blocking@0.2 | 1000 | `~.` | rand | 0.055 |  | -0.054 | 0.05 | 0.95 | ok |
| Fixed:Blocking@0.2 | 50 | `~.` | wald | 0.067 | 0.933 | 0.045 | 0.1 | 0.9 | ok |
| Fixed:Blocking@0.2 | 200 | `~.` | wald | 0.087 | 0.913 | 0.01 | 0.1 | 0.9 | ok |
| Fixed:Blocking@0.2 | 1000 | `~.` | wald | 0.068 | 0.932 | -0.054 | 0.05 | 0.95 | ok |
| Fixed:Blocking@0.2 | 50 | `~1` | rand | 0.054 |  | -0.02 | 0.05 | 0.95 | ok |
| Fixed:Blocking@0.2 | 200 | `~1` | rand | 0.039 |  | 0.031 | 0.05 | 0.95 | ok |
| Fixed:Blocking@0.2 | 1000 | `~1` | rand | 0.046 |  | 0.0032 | 0.05 | 0.95 | ok |
| Fixed:Blocking@0.2 | 50 | `~1` | wald | 0.046 | 0.954 | -0.02 | 0.1 | 0.9 | ok |
| Fixed:Blocking@0.2 | 200 | `~1` | wald | 0.033 | 0.967 | 0.031 | 0.1 | 0.9 | ok |
| Fixed:Blocking@0.2 | 1000 | `~1` | wald | 0.035 | 0.965 | 0.0032 | 0.0698 | 0.93 | ok |
| Fixed:Greedy | 50 | `~.` | rand | 0.04 |  | -0.0039 | 0.05 | 0.95 | ok |
| Fixed:Greedy | 200 | `~.` | rand | 0.047 |  | -0.00043 | 0.05 | 0.95 | ok |
| Fixed:Greedy | 1000 | `~.` | rand | 0.047 |  | 0.028 | 0.05 | 0.95 | ok |
| Fixed:Greedy | 50 | `~.` | wald | 0.046 | 0.954 | -0.0039 | 0.1 | 0.9 | ok |
| Fixed:Greedy | 200 | `~.` | wald | 0.057 | 0.943 | -0.00043 | 0.0698 | 0.93 | ok |
| Fixed:Greedy | 1000 | `~.` | wald | 0.053 | 0.947 | 0.028 | 0.0568 | 0.943 | ok |
| Fixed:Greedy | 50 | `~1` | rand | 0.048 |  | 0.072 | 0.05 | 0.95 | ok |
| Fixed:Greedy | 200 | `~1` | rand | 0.059 |  | -0.042 | 0.05 | 0.95 | ok |
| Fixed:Greedy | 1000 | `~1` | rand | 0.068 |  | 0.0095 | 0.05 | 0.95 | ok |
| Fixed:Greedy | 50 | `~1` | wald | 0.001 | 0.999 | 0.072 | 0.1 | 0.9 | ok |
| Fixed:Greedy | 200 | `~1` | wald | 0.009 | 0.991 | -0.042 | 0.0698 | 0.93 | ok |
| Fixed:Greedy | 1000 | `~1` | wald | 0.009 | 0.991 | 0.0095 | 0.0568 | 0.943 | ok |
| Fixed:Greedy@0.2 | 50 | `~.` | rand | 0.05 |  | -0.067 | 0.05 | 0.95 | ok |
| Fixed:Greedy@0.2 | 200 | `~.` | rand | 0.053 |  | -0.011 | 0.05 | 0.95 | ok |
| Fixed:Greedy@0.2 | 1000 | `~.` | rand | 0.047 |  | 0.022 | 0.05 | 0.95 | ok |
| Fixed:Greedy@0.2 | 50 | `~.` | wald | 0.085 | 0.915 | -0.067 | 0.1 | 0.9 | ok |
| Fixed:Greedy@0.2 | 200 | `~.` | wald | 0.07 | 0.93 | -0.011 | 0.1 | 0.9 | ok |
| Fixed:Greedy@0.2 | 1000 | `~.` | wald | 0.056 | 0.944 | 0.022 | 0.0698 | 0.93 | ok |
| Fixed:Greedy@0.2 | 50 | `~1` | rand | 0.068 |  | -0.0072 | 0.05 | 0.95 | ok |
| Fixed:Greedy@0.2 | 200 | `~1` | rand | 0.064 |  | 0.0018 | 0.05 | 0.95 | ok |
| Fixed:Greedy@0.2 | 1000 | `~1` | rand | 0.055 |  | -0.012 | 0.05 | 0.95 | ok |
| Fixed:Greedy@0.2 | 50 | `~1` | wald | 0.006 | 0.994 | -0.0072 | 0.1 | 0.9 | ok |
| Fixed:Greedy@0.2 | 200 | `~1` | wald | 0.008 | 0.992 | 0.0018 | 0.1 | 0.9 | ok |
| Fixed:Greedy@0.2 | 1000 | `~1` | wald | 0.011 | 0.989 | -0.012 | 0.0698 | 0.93 | ok |
| Fixed:GreedyDOptimal | 50 | `~.` | rand | 0.04 |  | -0.0039 | 0.05 | 0.95 | ok |
| Fixed:GreedyDOptimal | 200 | `~.` | rand | 0.047 |  | -0.00043 | 0.05 | 0.95 | ok |
| Fixed:GreedyDOptimal | 1000 | `~.` | rand | 0.047 |  | 0.028 | 0.05 | 0.95 | ok |
| Fixed:GreedyDOptimal | 50 | `~.` | wald | 0.046 | 0.954 | -0.0039 | 0.1 | 0.9 | ok |
| Fixed:GreedyDOptimal | 200 | `~.` | wald | 0.057 | 0.943 | -0.00043 | 0.0698 | 0.93 | ok |
| Fixed:GreedyDOptimal | 1000 | `~.` | wald | 0.053 | 0.947 | 0.028 | 0.0568 | 0.943 | ok |
| Fixed:GreedyDOptimal | 50 | `~1` | rand | 0.048 |  | 0.072 | 0.05 | 0.95 | ok |
| Fixed:GreedyDOptimal | 200 | `~1` | rand | 0.059 |  | -0.042 | 0.05 | 0.95 | ok |
| Fixed:GreedyDOptimal | 1000 | `~1` | rand | 0.068 |  | 0.0095 | 0.05 | 0.95 | ok |
| Fixed:GreedyDOptimal | 50 | `~1` | wald | 0.001 | 0.999 | 0.072 | 0.1 | 0.9 | ok |
| Fixed:GreedyDOptimal | 200 | `~1` | wald | 0.009 | 0.991 | -0.042 | 0.0698 | 0.93 | ok |
| Fixed:GreedyDOptimal | 1000 | `~1` | wald | 0.009 | 0.991 | 0.0095 | 0.0568 | 0.943 | ok |
| Fixed:GreedyDOptimal@0.2 | 50 | `~.` | rand | 0.05 |  | -0.067 | 0.05 | 0.95 | ok |
| Fixed:GreedyDOptimal@0.2 | 200 | `~.` | rand | 0.053 |  | -0.011 | 0.05 | 0.95 | ok |
| Fixed:GreedyDOptimal@0.2 | 1000 | `~.` | rand | 0.047 |  | 0.022 | 0.05 | 0.95 | ok |
| Fixed:GreedyDOptimal@0.2 | 50 | `~.` | wald | 0.085 | 0.915 | -0.067 | 0.1 | 0.9 | ok |
| Fixed:GreedyDOptimal@0.2 | 200 | `~.` | wald | 0.07 | 0.93 | -0.011 | 0.1 | 0.9 | ok |
| Fixed:GreedyDOptimal@0.2 | 1000 | `~.` | wald | 0.056 | 0.944 | 0.022 | 0.0698 | 0.93 | ok |
| Fixed:GreedyDOptimal@0.2 | 50 | `~1` | rand | 0.068 |  | -0.0072 | 0.05 | 0.95 | ok |
| Fixed:GreedyDOptimal@0.2 | 200 | `~1` | rand | 0.064 |  | 0.0018 | 0.05 | 0.95 | ok |
| Fixed:GreedyDOptimal@0.2 | 1000 | `~1` | rand | 0.055 |  | -0.012 | 0.05 | 0.95 | ok |
| Fixed:GreedyDOptimal@0.2 | 50 | `~1` | wald | 0.006 | 0.994 | -0.0072 | 0.1 | 0.9 | ok |
| Fixed:GreedyDOptimal@0.2 | 200 | `~1` | wald | 0.008 | 0.992 | 0.0018 | 0.1 | 0.9 | ok |
| Fixed:GreedyDOptimal@0.2 | 1000 | `~1` | wald | 0.011 | 0.989 | -0.012 | 0.0698 | 0.93 | ok |
| Fixed:iBCRD | 50 | `~.` | rand | 0.057 |  | 0.0077 | 0.05 | 0.95 | ok |
| Fixed:iBCRD | 200 | `~.` | rand | 0.048 |  | 0.017 | 0.05 | 0.95 | ok |
| Fixed:iBCRD | 1000 | `~.` | rand | 0.045 |  | -0.0013 | 0.05 | 0.95 | ok |
| Fixed:iBCRD | 50 | `~.` | wald | 0.073 | 0.927 | 0.0077 | 0.1 | 0.9 | ok |
| Fixed:iBCRD | 200 | `~.` | wald | 0.058 | 0.942 | 0.017 | 0.0698 | 0.93 | ok |
| Fixed:iBCRD | 1000 | `~.` | wald | 0.045 | 0.955 | -0.0013 | 0.0568 | 0.943 | ok |
| Fixed:iBCRD | 50 | `~1` | rand | 0.053 |  | -0.0097 | 0.05 | 0.95 | ok |
| Fixed:iBCRD | 200 | `~1` | rand | 0.056 |  | 0.066 | 0.05 | 0.95 | ok |
| Fixed:iBCRD | 1000 | `~1` | rand | 0.062 |  | 0.002 | 0.05 | 0.95 | ok |
| Fixed:iBCRD | 50 | `~1` | wald | 0.019 | 0.981 | -0.0097 | 0.1 | 0.9 | ok |
| Fixed:iBCRD | 200 | `~1` | wald | 0.045 | 0.955 | 0.066 | 0.0698 | 0.93 | ok |
| Fixed:iBCRD | 1000 | `~1` | wald | 0.056 | 0.944 | 0.002 | 0.0568 | 0.943 | ok |
| Fixed:iBCRD@0.2 | 50 | `~.` | rand | 0.056 |  | 0.046 | 0.05 | 0.95 | ok |
| Fixed:iBCRD@0.2 | 200 | `~.` | rand | 0.058 |  | -0.038 | 0.05 | 0.95 | ok |
| Fixed:iBCRD@0.2 | 1000 | `~.` | rand | 0.055 |  | 0.048 | 0.05 | 0.95 | ok |
| Fixed:iBCRD@0.2 | 50 | `~.` | wald | 0.073 | 0.927 | 0.046 | 0.1 | 0.9 | ok |
| Fixed:iBCRD@0.2 | 200 | `~.` | wald | 0.083 | 0.917 | -0.038 | 0.1 | 0.9 | ok |
| Fixed:iBCRD@0.2 | 1000 | `~.` | wald | 0.067 | 0.933 | 0.048 | 0.05 | 0.95 | ok |
| Fixed:iBCRD@0.2 | 50 | `~1` | rand | 0.055 |  | 0.033 | 0.05 | 0.95 | ok |
| Fixed:iBCRD@0.2 | 200 | `~1` | rand | 0.051 |  | 0.05 | 0.05 | 0.95 | ok |
| Fixed:iBCRD@0.2 | 1000 | `~1` | rand | 0.049 |  | 0.023 | 0.05 | 0.95 | ok |
| Fixed:iBCRD@0.2 | 50 | `~1` | wald | 0.046 | 0.954 | 0.033 | 0.1 | 0.9 | ok |
| Fixed:iBCRD@0.2 | 200 | `~1` | wald | 0.048 | 0.952 | 0.05 | 0.1 | 0.9 | ok |
| Fixed:iBCRD@0.2 | 1000 | `~1` | wald | 0.047 | 0.953 | 0.023 | 0.0698 | 0.93 | ok |
| Fixed:MatchingGreedyPairSwitching | 50 | `~.` | rand | 0.047 |  | 0.0038 | 0.05 | 0.95 | ok |
| Fixed:MatchingGreedyPairSwitching | 200 | `~.` | rand | 0.067 |  | -0.047 | 0.05 | 0.95 | ok |
| Fixed:MatchingGreedyPairSwitching | 1000 | `~.` | rand | 0.052 |  | -0.01 | 0.05 | 0.95 | ok |
| Fixed:MatchingGreedyPairSwitching | 50 | `~.` | wald | 0.07 | 0.93 | 0.0038 | 0.1 | 0.9 | ok |
| Fixed:MatchingGreedyPairSwitching | 200 | `~.` | wald | 0.076 | 0.924 | -0.047 | 0.0698 | 0.93 | ok |
| Fixed:MatchingGreedyPairSwitching | 1000 | `~.` | wald | 0.054 | 0.946 | -0.01 | 0.0568 | 0.943 | ok |
| Fixed:MatchingGreedyPairSwitching | 50 | `~1` | rand | 0.05 |  | 0.0013 | 0.05 | 0.95 | ok |
| Fixed:MatchingGreedyPairSwitching | 200 | `~1` | rand | 0.071 |  | -0.054 | 0.05 | 0.95 | ok |
| Fixed:MatchingGreedyPairSwitching | 1000 | `~1` | rand | 0.056 |  | -0.0053 | 0.05 | 0.95 | ok |
| Fixed:MatchingGreedyPairSwitching | 50 | `~1` | wald | 0.003 | 0.997 | 0.0013 | 0.1 | 0.9 | ok |
| Fixed:MatchingGreedyPairSwitching | 200 | `~1` | wald | 0.002 | 0.998 | -0.054 | 0.0698 | 0.93 | ok |
| Fixed:MatchingGreedyPairSwitching | 1000 | `~1` | wald | 0.007 | 0.993 | -0.0053 | 0.0568 | 0.943 | ok |
| Fixed:Optimal | 50 | `~.` | wald | 0.06 | 0.94 | -0.055 | 0.1 | 0.9 | ok |
| Fixed:Optimal | 200 | `~.` | wald | 0.067 | 0.933 | 0.022 | 0.0698 | 0.93 | ok |
| Fixed:Optimal | 1000 | `~.` | wald | 0.058 | 0.942 | 0.021 | 0.0568 | 0.943 | ok |
| Fixed:Optimal | 50 | `~1` | wald | 0.003 | 0.997 | -0.038 | 0.1 | 0.9 | ok |
| Fixed:Optimal | 200 | `~1` | wald | 0.004 | 0.996 | -0.0072 | 0.0698 | 0.93 | ok |
| Fixed:Optimal | 1000 | `~1` | wald | 0.007 | 0.993 | 0.03 | 0.0568 | 0.943 | ok |
| Fixed:Optimal@0.2 | 50 | `~.` | wald | 0.072 | 0.928 | -0.034 | 0.1 | 0.9 | ok |
| Fixed:Optimal@0.2 | 200 | `~.` | wald | 0.077 | 0.923 | -0.066 | 0.1 | 0.9 | ok |
| Fixed:Optimal@0.2 | 1000 | `~.` | wald | 0.062 | 0.938 | 0.029 | 0.05 | 0.95 | ok |
| Fixed:Optimal@0.2 | 50 | `~1` | wald | 0.004 | 0.996 | -0.0033 | 0.1 | 0.9 | ok |
| Fixed:Optimal@0.2 | 200 | `~1` | wald | 0.007 | 0.993 | -0.025 | 0.1 | 0.9 | ok |
| Fixed:Optimal@0.2 | 1000 | `~1` | wald | 0.008 | 0.992 | 0.057 | 0.0698 | 0.93 | ok |
| Fixed:OptimalBlocks | 50 | `~.` | rand | 0.041 |  | 0.029 | 0.05 | 0.95 | ok |
| Fixed:OptimalBlocks | 200 | `~.` | rand | 0.045 |  | 0.0055 | 0.05 | 0.95 | ok |
| Fixed:OptimalBlocks | 1000 | `~.` | rand | 0.051 |  | 0.035 | 0.05 | 0.95 | ok |
| Fixed:OptimalBlocks | 50 | `~.` | wald | 0.058 | 0.942 | 0.029 | 0.1 | 0.9 | ok |
| Fixed:OptimalBlocks | 200 | `~.` | wald | 0.06 | 0.94 | 0.0055 | 0.0698 | 0.93 | ok |
| Fixed:OptimalBlocks | 1000 | `~.` | wald | 0.062 | 0.938 | 0.035 | 0.0568 | 0.943 | ok |
| Fixed:OptimalBlocks | 50 | `~1` | rand | 0.052 |  | 0.023 | 0.05 | 0.95 | ok |
| Fixed:OptimalBlocks | 200 | `~1` | rand | 0.053 |  | 0.023 | 0.05 | 0.95 | ok |
| Fixed:OptimalBlocks | 1000 | `~1` | rand | 0.053 |  | 0.011 | 0.05 | 0.95 | ok |
| Fixed:OptimalBlocks | 50 | `~1` | wald | 0.01 | 0.99 | 0.023 | 0.1 | 0.9 | ok |
| Fixed:OptimalBlocks | 200 | `~1` | wald | 0.015 | 0.985 | 0.023 | 0.0698 | 0.93 | ok |
| Fixed:OptimalBlocks | 1000 | `~1` | wald | 0.014 | 0.986 | 0.011 | 0.0568 | 0.943 | ok |
| Fixed:OptimalBlocks@0.2 | 50 | `~.` | rand | 0.043 |  | -0.01 | 0.05 | 0.95 | ok |
| Fixed:OptimalBlocks@0.2 | 200 | `~.` | rand | 0.048 |  | 0.017 | 0.05 | 0.95 | ok |
| Fixed:OptimalBlocks@0.2 | 1000 | `~.` | rand | 0.049 |  | -0.024 | 0.05 | 0.95 | ok |
| Fixed:OptimalBlocks@0.2 | 50 | `~.` | wald | 0.066 | 0.934 | -0.01 | 0.1 | 0.9 | ok |
| Fixed:OptimalBlocks@0.2 | 200 | `~.` | wald | 0.068 | 0.932 | 0.017 | 0.1 | 0.9 | ok |
| Fixed:OptimalBlocks@0.2 | 1000 | `~.` | wald | 0.055 | 0.945 | -0.024 | 0.0698 | 0.93 | ok |
| Fixed:OptimalBlocks@0.2 | 50 | `~1` | rand | 0.034 |  | 0.023 | 0.05 | 0.95 | ok |
| Fixed:OptimalBlocks@0.2 | 200 | `~1` | rand | 0.055 |  | 0.013 | 0.05 | 0.95 | ok |
| Fixed:OptimalBlocks@0.2 | 1000 | `~1` | rand | 0.057 |  | 0.036 | 0.05 | 0.95 | ok |
| Fixed:OptimalBlocks@0.2 | 50 | `~1` | wald | 0.021 | 0.979 | 0.023 | 0.1 | 0.9 | ok |
| Fixed:OptimalBlocks@0.2 | 200 | `~1` | wald | 0.03 | 0.97 | 0.013 | 0.1 | 0.9 | ok |
| Fixed:OptimalBlocks@0.2 | 1000 | `~1` | wald | 0.015 | 0.985 | 0.036 | 0.0698 | 0.93 | ok |
| Fixed:Rerandomization | 50 | `~.` | rand | 0.045 |  | 0.0067 | 0.05 | 0.95 | ok |
| Fixed:Rerandomization | 200 | `~.` | rand | 0.054 |  | 0.0062 | 0.05 | 0.95 | ok |
| Fixed:Rerandomization | 1000 | `~.` | rand | 0.049 |  | 0.025 | 0.05 | 0.95 | ok |
| Fixed:Rerandomization | 50 | `~.` | wald | 0.057 | 0.943 | 0.0067 | 0.1 | 0.9 | ok |
| Fixed:Rerandomization | 200 | `~.` | wald | 0.056 | 0.944 | 0.0062 | 0.0698 | 0.93 | ok |
| Fixed:Rerandomization | 1000 | `~.` | wald | 0.046 | 0.954 | 0.025 | 0.0568 | 0.943 | ok |
| Fixed:Rerandomization | 50 | `~1` | rand | 0.043 |  | 0.057 | 0.05 | 0.95 | ok |
| Fixed:Rerandomization | 200 | `~1` | rand | 0.059 |  | -0.051 | 0.05 | 0.95 | ok |
| Fixed:Rerandomization | 1000 | `~1` | rand | 0.061 |  | -0.0029 | 0.05 | 0.95 | ok |
| Fixed:Rerandomization | 50 | `~1` | wald | 0.016 | 0.984 | 0.057 | 0.1 | 0.9 | ok |
| Fixed:Rerandomization | 200 | `~1` | wald | 0.049 | 0.951 | -0.051 | 0.0698 | 0.93 | ok |
| Fixed:Rerandomization | 1000 | `~1` | wald | 0.052 | 0.948 | -0.0029 | 0.0568 | 0.943 | ok |
| Fixed:Rerandomization@0.2 | 50 | `~.` | rand | 0.06 |  | -0.052 | 0.05 | 0.95 | ok |
| Fixed:Rerandomization@0.2 | 200 | `~.` | rand | 0.044 |  | -0.022 | 0.05 | 0.95 | ok |
| Fixed:Rerandomization@0.2 | 1000 | `~.` | rand | 0.056 |  | 0.058 | 0.05 | 0.95 | ok |
| Fixed:Rerandomization@0.2 | 50 | `~.` | wald | 0.083 | 0.917 | -0.052 | 0.1 | 0.9 | ok |
| Fixed:Rerandomization@0.2 | 200 | `~.` | wald | 0.071 | 0.929 | -0.022 | 0.1 | 0.9 | ok |
| Fixed:Rerandomization@0.2 | 1000 | `~.` | wald | 0.057 | 0.943 | 0.058 | 0.0698 | 0.93 | ok |
| Fixed:Rerandomization@0.2 | 50 | `~1` | rand | 0.053 |  | -0.00062 | 0.05 | 0.95 | ok |
| Fixed:Rerandomization@0.2 | 200 | `~1` | rand | 0.06 |  | 0.006 | 0.05 | 0.95 | ok |
| Fixed:Rerandomization@0.2 | 1000 | `~1` | rand | 0.063 |  | 0.084 | 0.05 | 0.95 | ok |
| Fixed:Rerandomization@0.2 | 50 | `~1` | wald | 0.05 | 0.95 | -0.00062 | 0.1 | 0.9 | ok |
| Fixed:Rerandomization@0.2 | 200 | `~1` | wald | 0.06 | 0.94 | 0.006 | 0.1 | 0.9 | ok |
| Fixed:Rerandomization@0.2 | 1000 | `~1` | wald | 0.055 | 0.945 | 0.084 | 0.0698 | 0.93 | ok |
| SeqOneByOne:Atkinson | 50 | `~.` | rand | 0.051 |  | -0.064 | 0.05 | 0.95 | ok |
| SeqOneByOne:Atkinson | 200 | `~.` | rand | 0.052 |  | 0.011 | 0.05 | 0.95 | ok |
| SeqOneByOne:Atkinson | 1000 | `~.` | rand | 0.047 |  | 0.028 | 0.05 | 0.95 | ok |
| SeqOneByOne:Atkinson | 50 | `~.` | wald | 0.073 | 0.927 | -0.064 | 0.1 | 0.9 | ok |
| SeqOneByOne:Atkinson | 200 | `~.` | wald | 0.063 | 0.937 | 0.011 | 0.0698 | 0.93 | ok |
| SeqOneByOne:Atkinson | 1000 | `~.` | wald | 0.062 | 0.938 | 0.028 | 0.0568 | 0.943 | ok |
| SeqOneByOne:Atkinson | 50 | `~1` | rand | 0.054 |  | -0.027 | 0.05 | 0.95 | ok |
| SeqOneByOne:Atkinson | 200 | `~1` | rand | 0.045 |  | 0.038 | 0.05 | 0.95 | ok |
| SeqOneByOne:Atkinson | 1000 | `~1` | rand | 0.044 |  | 0.024 | 0.05 | 0.95 | ok |
| SeqOneByOne:Atkinson | 50 | `~1` | wald | 0.002 | 0.998 | -0.027 | 0.1 | 0.9 | ok |
| SeqOneByOne:Atkinson | 200 | `~1` | wald | 0.011 | 0.989 | 0.038 | 0.0698 | 0.93 | ok |
| SeqOneByOne:Atkinson | 1000 | `~1` | wald | 0.013 | 0.987 | 0.024 | 0.0568 | 0.943 | ok |
| SeqOneByOne:Bernoulli | 50 | `~.` | rand | 0.063 |  | -0.015 | 0.05 | 0.95 | ok |
| SeqOneByOne:Bernoulli | 200 | `~.` | rand | 0.045 |  | 0.05 | 0.05 | 0.95 | ok |
| SeqOneByOne:Bernoulli | 1000 | `~.` | rand | 0.042 |  | -0.046 | 0.05 | 0.95 | ok |
| SeqOneByOne:Bernoulli | 50 | `~.` | wald | 0.071 | 0.929 | -0.015 | 0.1 | 0.9 | ok |
| SeqOneByOne:Bernoulli | 200 | `~.` | wald | 0.063 | 0.937 | 0.05 | 0.0698 | 0.93 | ok |
| SeqOneByOne:Bernoulli | 1000 | `~.` | wald | 0.041 | 0.959 | -0.046 | 0.0568 | 0.943 | ok |
| SeqOneByOne:Bernoulli | 50 | `~1` | rand | 0.055 |  | 0.012 | 0.05 | 0.95 | ok |
| SeqOneByOne:Bernoulli | 200 | `~1` | rand | 0.048 |  | 0.024 | 0.05 | 0.95 | ok |
| SeqOneByOne:Bernoulli | 1000 | `~1` | rand | 0.035 |  | -0.011 | 0.05 | 0.95 | ok |
| SeqOneByOne:Bernoulli | 50 | `~1` | wald | 0.038 | 0.962 | 0.012 | 0.1 | 0.9 | ok |
| SeqOneByOne:Bernoulli | 200 | `~1` | wald | 0.044 | 0.956 | 0.024 | 0.0698 | 0.93 | ok |
| SeqOneByOne:Bernoulli | 1000 | `~1` | wald | 0.037 | 0.963 | -0.011 | 0.0568 | 0.943 | ok |
| SeqOneByOne:Bernoulli@0.2 | 50 | `~.` | rand | 0.049 |  | 0.016 | 0.05 | 0.95 | ok |
| SeqOneByOne:Bernoulli@0.2 | 200 | `~.` | rand | 0.052 |  | 0.037 | 0.05 | 0.95 | ok |
| SeqOneByOne:Bernoulli@0.2 | 1000 | `~.` | rand | 0.046 |  | -0.046 | 0.05 | 0.95 | ok |
| SeqOneByOne:Bernoulli@0.2 | 50 | `~.` | wald | 0.073 | 0.927 | 0.016 | 0.1 | 0.9 | ok |
| SeqOneByOne:Bernoulli@0.2 | 200 | `~.` | wald | 0.072 | 0.928 | 0.037 | 0.1 | 0.9 | ok |
| SeqOneByOne:Bernoulli@0.2 | 1000 | `~.` | wald | 0.059 | 0.941 | -0.046 | 0.0698 | 0.93 | ok |
| SeqOneByOne:Bernoulli@0.2 | 50 | `~1` | rand | 0.067 |  | 0.023 | 0.05 | 0.95 | ok |
| SeqOneByOne:Bernoulli@0.2 | 200 | `~1` | rand | 0.044 |  | 0.013 | 0.05 | 0.95 | ok |
| SeqOneByOne:Bernoulli@0.2 | 1000 | `~1` | rand | 0.045 |  | -0.00068 | 0.05 | 0.95 | ok |
| SeqOneByOne:Bernoulli@0.2 | 50 | `~1` | wald | 0.048 | 0.952 | 0.023 | 0.1 | 0.9 | ok |
| SeqOneByOne:Bernoulli@0.2 | 200 | `~1` | wald | 0.044 | 0.956 | 0.013 | 0.1 | 0.9 | ok |
| SeqOneByOne:Bernoulli@0.2 | 1000 | `~1` | wald | 0.049 | 0.951 | -0.00068 | 0.0698 | 0.93 | ok |
| SeqOneByOne:Efron | 50 | `~.` | rand | 0.053 |  | 0.029 | 0.05 | 0.95 | ok |
| SeqOneByOne:Efron | 200 | `~.` | rand | 0.055 |  | 0.065 | 0.05 | 0.95 | ok |
| SeqOneByOne:Efron | 1000 | `~.` | rand | 0.042 |  | 0.00015 | 0.05 | 0.95 | ok |
| SeqOneByOne:Efron | 50 | `~.` | wald | 0.077 | 0.923 | 0.029 | 0.1 | 0.9 | ok |
| SeqOneByOne:Efron | 200 | `~.` | wald | 0.064 | 0.936 | 0.065 | 0.0698 | 0.93 | ok |
| SeqOneByOne:Efron | 1000 | `~.` | wald | 0.047 | 0.953 | 0.00015 | 0.0568 | 0.943 | ok |
| SeqOneByOne:Efron | 50 | `~1` | rand | 0.051 |  | 0.035 | 0.05 | 0.95 | ok |
| SeqOneByOne:Efron | 200 | `~1` | rand | 0.06 |  | 0.019 | 0.05 | 0.95 | ok |
| SeqOneByOne:Efron | 1000 | `~1` | rand | 0.045 |  | -0.01 | 0.05 | 0.95 | ok |
| SeqOneByOne:Efron | 50 | `~1` | wald | 0.026 | 0.974 | 0.035 | 0.1 | 0.9 | ok |
| SeqOneByOne:Efron | 200 | `~1` | wald | 0.06 | 0.94 | 0.019 | 0.0698 | 0.93 | ok |
| SeqOneByOne:Efron | 1000 | `~1` | wald | 0.038 | 0.962 | -0.01 | 0.0568 | 0.943 | ok |
| SeqOneByOne:iBCRD | 50 | `~.` | rand | 0.055 |  | 0.012 | 0.05 | 0.95 | ok |
| SeqOneByOne:iBCRD | 200 | `~.` | rand | 0.047 |  | -0.02 | 0.05 | 0.95 | ok |
| SeqOneByOne:iBCRD | 1000 | `~.` | rand | 0.044 |  | -0.0065 | 0.05 | 0.95 | ok |
| SeqOneByOne:iBCRD | 50 | `~.` | wald | 0.067 | 0.933 | 0.012 | 0.1 | 0.9 | ok |
| SeqOneByOne:iBCRD | 200 | `~.` | wald | 0.05 | 0.95 | -0.02 | 0.0698 | 0.93 | ok |
| SeqOneByOne:iBCRD | 1000 | `~.` | wald | 0.045 | 0.955 | -0.0065 | 0.0568 | 0.943 | ok |
| SeqOneByOne:iBCRD | 50 | `~1` | rand | 0.059 |  | 0.03 | 0.05 | 0.95 | ok |
| SeqOneByOne:iBCRD | 200 | `~1` | rand | 0.06 |  | -0.0069 | 0.05 | 0.95 | ok |
| SeqOneByOne:iBCRD | 1000 | `~1` | rand | 0.055 |  | 0.058 | 0.05 | 0.95 | ok |
| SeqOneByOne:iBCRD | 50 | `~1` | wald | 0.032 | 0.968 | 0.03 | 0.1 | 0.9 | ok |
| SeqOneByOne:iBCRD | 200 | `~1` | wald | 0.052 | 0.948 | -0.0069 | 0.0698 | 0.93 | ok |
| SeqOneByOne:iBCRD | 1000 | `~1` | wald | 0.053 | 0.947 | 0.058 | 0.0568 | 0.943 | ok |
| SeqOneByOne:iBCRD@0.2 | 50 | `~.` | rand | 0.065 |  | 0.034 | 0.05 | 0.95 | ok |
| SeqOneByOne:iBCRD@0.2 | 200 | `~.` | rand | 0.053 |  | 0.043 | 0.05 | 0.95 | ok |
| SeqOneByOne:iBCRD@0.2 | 1000 | `~.` | rand | 0.051 |  | -0.054 | 0.05 | 0.95 | ok |
| SeqOneByOne:iBCRD@0.2 | 50 | `~.` | wald | 0.081 | 0.919 | 0.034 | 0.1 | 0.9 | ok |
| SeqOneByOne:iBCRD@0.2 | 200 | `~.` | wald | 0.086 | 0.914 | 0.043 | 0.1 | 0.9 | ok |
| SeqOneByOne:iBCRD@0.2 | 1000 | `~.` | wald | 0.055 | 0.945 | -0.054 | 0.0698 | 0.93 | ok |
| SeqOneByOne:iBCRD@0.2 | 50 | `~1` | rand | 0.054 |  | 0.0066 | 0.05 | 0.95 | ok |
| SeqOneByOne:iBCRD@0.2 | 200 | `~1` | rand | 0.049 |  | -0.0065 | 0.05 | 0.95 | ok |
| SeqOneByOne:iBCRD@0.2 | 1000 | `~1` | rand | 0.044 |  | -0.0018 | 0.05 | 0.95 | ok |
| SeqOneByOne:iBCRD@0.2 | 50 | `~1` | wald | 0.055 | 0.945 | 0.0066 | 0.1 | 0.9 | ok |
| SeqOneByOne:iBCRD@0.2 | 200 | `~1` | wald | 0.049 | 0.951 | -0.0065 | 0.1 | 0.9 | ok |
| SeqOneByOne:iBCRD@0.2 | 1000 | `~1` | wald | 0.047 | 0.953 | -0.0018 | 0.0698 | 0.93 | ok |
| SeqOneByOne:KK14 | 50 | `~.` | rand | 0.058 |  | -0.026 | 0.05 | 0.95 | ok |
| SeqOneByOne:KK14 | 200 | `~.` | rand | 0.038 |  | 0.011 | 0.05 | 0.95 | ok |
| SeqOneByOne:KK14 | 1000 | `~.` | rand | 0.065 |  | -0.023 | 0.05 | 0.95 | ok |
| SeqOneByOne:KK14 | 50 | `~.` | wald | 0.065 | 0.935 | -0.026 | 0.1 | 0.9 | ok |
| SeqOneByOne:KK14 | 200 | `~.` | wald | 0.056 | 0.944 | 0.011 | 0.0698 | 0.93 | ok |
| SeqOneByOne:KK14 | 1000 | `~.` | wald | 0.068 | 0.932 | -0.023 | 0.0568 | 0.943 | ok |
| SeqOneByOne:KK14 | 50 | `~1` | rand | 0.043 |  | -0.013 | 0.05 | 0.95 | ok |
| SeqOneByOne:KK14 | 200 | `~1` | rand | 0.054 |  | 0.014 | 0.05 | 0.95 | ok |
| SeqOneByOne:KK14 | 1000 | `~1` | rand | 0.062 |  | 0.0024 | 0.05 | 0.95 | ok |
| SeqOneByOne:KK14 | 50 | `~1` | wald | 0.009 | 0.991 | -0.013 | 0.1 | 0.9 | ok |
| SeqOneByOne:KK14 | 200 | `~1` | wald | 0.013 | 0.987 | 0.014 | 0.0698 | 0.93 | ok |
| SeqOneByOne:KK14 | 1000 | `~1` | wald | 0.015 | 0.985 | 0.0024 | 0.0568 | 0.943 | ok |
| SeqOneByOne:KK21 | 50 | `~.` | rand | 0.047 |  | -0.033 | 0.05 | 0.95 | ok |
| SeqOneByOne:KK21 | 200 | `~.` | rand | 0.047 |  | 0.06 | 0.05 | 0.95 | ok |
| SeqOneByOne:KK21 | 1000 | `~.` | rand | 0.044 |  | -0.029 | 0.05 | 0.95 | ok |
| SeqOneByOne:KK21 | 50 | `~.` | wald | 0.066 | 0.934 | -0.033 | 0.1 | 0.9 | ok |
| SeqOneByOne:KK21 | 200 | `~.` | wald | 0.053 | 0.947 | 0.06 | 0.0698 | 0.93 | ok |
| SeqOneByOne:KK21 | 1000 | `~.` | wald | 0.044 | 0.956 | -0.029 | 0.0568 | 0.943 | ok |
| SeqOneByOne:KK21 | 50 | `~1` | rand | 0.057 |  | -0.016 | 0.05 | 0.95 | ok |
| SeqOneByOne:KK21 | 200 | `~1` | rand | 0.043 |  | 0.037 | 0.05 | 0.95 | ok |
| SeqOneByOne:KK21 | 1000 | `~1` | rand | 0.063 |  | -0.008 | 0.05 | 0.95 | ok |
| SeqOneByOne:KK21 | 50 | `~1` | wald | 0.007 | 0.993 | -0.016 | 0.1 | 0.9 | ok |
| SeqOneByOne:KK21 | 200 | `~1` | wald | 0.008 | 0.992 | 0.037 | 0.0698 | 0.93 | ok |
| SeqOneByOne:KK21 | 1000 | `~1` | wald | 0.014 | 0.986 | -0.008 | 0.0568 | 0.943 | ok |
| SeqOneByOne:KK21stepwise | 50 | `~.` | rand | 0.061 |  | 0.036 | 0.05 | 0.95 | ok |
| SeqOneByOne:KK21stepwise | 200 | `~.` | rand | 0.042 |  | 0.014 | 0.05 | 0.95 | ok |
| SeqOneByOne:KK21stepwise | 1000 | `~.` | rand | 0.069 |  | -0.035 | 0.05 | 0.95 | ok |
| SeqOneByOne:KK21stepwise | 50 | `~.` | wald | 0.072 | 0.928 | 0.036 | 0.1 | 0.9 | ok |
| SeqOneByOne:KK21stepwise | 200 | `~.` | wald | 0.052 | 0.948 | 0.014 | 0.0698 | 0.93 | ok |
| SeqOneByOne:KK21stepwise | 1000 | `~.` | wald | 0.066 | 0.934 | -0.035 | 0.0568 | 0.943 | ok |
| SeqOneByOne:KK21stepwise | 50 | `~1` | rand | 0.05 |  | 0.024 | 0.05 | 0.95 | ok |
| SeqOneByOne:KK21stepwise | 200 | `~1` | rand | 0.045 |  | 0.048 | 0.05 | 0.95 | ok |
| SeqOneByOne:KK21stepwise | 1000 | `~1` | rand | 0.057 |  | 0.035 | 0.05 | 0.95 | ok |
| SeqOneByOne:KK21stepwise | 50 | `~1` | wald | 0.004 | 0.996 | 0.024 | 0.1 | 0.9 | ok |
| SeqOneByOne:KK21stepwise | 200 | `~1` | wald | 0.012 | 0.988 | 0.048 | 0.0698 | 0.93 | ok |
| SeqOneByOne:KK21stepwise | 1000 | `~1` | wald | 0.008 | 0.992 | 0.035 | 0.0568 | 0.943 | ok |
| SeqOneByOne:PocockSimon | 50 | `~.` | rand | 0.05 |  | -0.05 | 0.05 | 0.95 | ok |
| SeqOneByOne:PocockSimon | 200 | `~.` | rand | 0.05 |  | -0.022 | 0.05 | 0.95 | ok |
| SeqOneByOne:PocockSimon | 1000 | `~.` | rand | 0.047 |  | 0.0011 | 0.05 | 0.95 | ok |
| SeqOneByOne:PocockSimon | 50 | `~.` | wald | 0.07 | 0.93 | -0.05 | 0.1 | 0.9 | ok |
| SeqOneByOne:PocockSimon | 200 | `~.` | wald | 0.066 | 0.934 | -0.022 | 0.0698 | 0.93 | ok |
| SeqOneByOne:PocockSimon | 1000 | `~.` | wald | 0.051 | 0.949 | 0.0011 | 0.0568 | 0.943 | ok |
| SeqOneByOne:PocockSimon | 50 | `~1` | rand | 0.046 |  | -0.06 | 0.05 | 0.95 | ok |
| SeqOneByOne:PocockSimon | 200 | `~1` | rand | 0.052 |  | 0.015 | 0.05 | 0.95 | ok |
| SeqOneByOne:PocockSimon | 1000 | `~1` | rand | 0.042 |  | -0.022 | 0.05 | 0.95 | ok |
| SeqOneByOne:PocockSimon | 50 | `~1` | wald | 0.015 | 0.985 | -0.06 | 0.1 | 0.9 | ok |
| SeqOneByOne:PocockSimon | 200 | `~1` | wald | 0.031 | 0.969 | 0.015 | 0.0698 | 0.93 | ok |
| SeqOneByOne:PocockSimon | 1000 | `~1` | wald | 0.031 | 0.969 | -0.022 | 0.0568 | 0.943 | ok |
| SeqOneByOne:RandomBlockSize | 50 | `~.` | rand | 0.063 |  | 0.0061 | 0.05 | 0.95 | ok |
| SeqOneByOne:RandomBlockSize | 200 | `~.` | rand | 0.048 |  | 0.0025 | 0.05 | 0.95 | ok |
| SeqOneByOne:RandomBlockSize | 1000 | `~.` | rand | 0.045 |  | -0.011 | 0.05 | 0.95 | ok |
| SeqOneByOne:RandomBlockSize | 50 | `~.` | wald | 0.075 | 0.925 | 0.0061 | 0.1 | 0.9 | ok |
| SeqOneByOne:RandomBlockSize | 200 | `~.` | wald | 0.058 | 0.942 | 0.0025 | 0.0698 | 0.93 | ok |
| SeqOneByOne:RandomBlockSize | 1000 | `~.` | wald | 0.049 | 0.951 | -0.011 | 0.0568 | 0.943 | ok |
| SeqOneByOne:RandomBlockSize | 50 | `~1` | rand | 0.05 |  | 0.033 | 0.05 | 0.95 | ok |
| SeqOneByOne:RandomBlockSize | 200 | `~1` | rand | 0.059 |  | 0.038 | 0.05 | 0.95 | ok |
| SeqOneByOne:RandomBlockSize | 1000 | `~1` | rand | 0.045 |  | -0.011 | 0.05 | 0.95 | ok |
| SeqOneByOne:RandomBlockSize | 50 | `~1` | wald | 0.022 | 0.978 | 0.033 | 0.1 | 0.9 | ok |
| SeqOneByOne:RandomBlockSize | 200 | `~1` | wald | 0.041 | 0.959 | 0.038 | 0.0698 | 0.93 | ok |
| SeqOneByOne:RandomBlockSize | 1000 | `~1` | wald | 0.043 | 0.957 | -0.011 | 0.0568 | 0.943 | ok |
| SeqOneByOne:RandomBlockSize@0.2 | 50 | `~.` | rand | 0.05 |  | 0.0067 | 0.05 | 0.95 | ok |
| SeqOneByOne:RandomBlockSize@0.2 | 200 | `~.` | rand | 0.058 |  | 0.0035 | 0.05 | 0.95 | ok |
| SeqOneByOne:RandomBlockSize@0.2 | 1000 | `~.` | rand | 0.058 |  | 0.02 | 0.05 | 0.95 | ok |
| SeqOneByOne:RandomBlockSize@0.2 | 50 | `~.` | wald | 0.072 | 0.928 | 0.0067 | 0.1 | 0.9 | ok |
| SeqOneByOne:RandomBlockSize@0.2 | 200 | `~.` | wald | 0.084 | 0.916 | 0.0035 | 0.1 | 0.9 | ok |
| SeqOneByOne:RandomBlockSize@0.2 | 1000 | `~.` | wald | 0.071 | 0.929 | 0.02 | 0.05 | 0.95 | ok |
| SeqOneByOne:RandomBlockSize@0.2 | 50 | `~1` | rand | 0.05 |  | 0.07 | 0.05 | 0.95 | ok |
| SeqOneByOne:RandomBlockSize@0.2 | 200 | `~1` | rand | 0.051 |  | 0.011 | 0.05 | 0.95 | ok |
| SeqOneByOne:RandomBlockSize@0.2 | 1000 | `~1` | rand | 0.063 |  | 0.029 | 0.05 | 0.95 | ok |
| SeqOneByOne:RandomBlockSize@0.2 | 50 | `~1` | wald | 0.032 | 0.968 | 0.07 | 0.1 | 0.9 | ok |
| SeqOneByOne:RandomBlockSize@0.2 | 200 | `~1` | wald | 0.046 | 0.954 | 0.011 | 0.1 | 0.9 | ok |
| SeqOneByOne:RandomBlockSize@0.2 | 1000 | `~1` | wald | 0.045 | 0.955 | 0.029 | 0.0698 | 0.93 | ok |
| SeqOneByOne:SPBR | 50 | `~.` | rand | 0.048 |  | 0.029 | 0.05 | 0.95 | ok |
| SeqOneByOne:SPBR | 200 | `~.` | rand | 0.058 |  | 0.012 | 0.05 | 0.95 | ok |
| SeqOneByOne:SPBR | 1000 | `~.` | rand | 0.053 |  | -0.028 | 0.05 | 0.95 | ok |
| SeqOneByOne:SPBR | 50 | `~.` | wald | 0.048 | 0.952 | 0.029 | 0.1 | 0.9 | ok |
| SeqOneByOne:SPBR | 200 | `~.` | wald | 0.074 | 0.926 | 0.012 | 0.0698 | 0.93 | ok |
| SeqOneByOne:SPBR | 1000 | `~.` | wald | 0.055 | 0.945 | -0.028 | 0.0568 | 0.943 | ok |
| SeqOneByOne:SPBR | 50 | `~1` | rand | 0.057 |  | 0.027 | 0.05 | 0.95 | ok |
| SeqOneByOne:SPBR | 200 | `~1` | rand | 0.05 |  | -0.0052 | 0.05 | 0.95 | ok |
| SeqOneByOne:SPBR | 1000 | `~1` | rand | 0.039 |  | 0.013 | 0.05 | 0.95 | ok |
| SeqOneByOne:SPBR | 50 | `~1` | wald | 0.025 | 0.975 | 0.027 | 0.1 | 0.9 | ok |
| SeqOneByOne:SPBR | 200 | `~1` | wald | 0.036 | 0.964 | -0.0052 | 0.0698 | 0.93 | ok |
| SeqOneByOne:SPBR | 1000 | `~1` | wald | 0.037 | 0.963 | 0.013 | 0.0568 | 0.943 | ok |
| SeqOneByOne:SPBR@0.2 | 50 | `~.` | rand | 0.042 |  | -0.075 | 0.05 | 0.95 | ok |
| SeqOneByOne:SPBR@0.2 | 200 | `~.` | rand | 0.064 |  | 0.024 | 0.05 | 0.95 | ok |
| SeqOneByOne:SPBR@0.2 | 1000 | `~.` | rand | 0.053 |  | 0.034 | 0.05 | 0.95 | ok |
| SeqOneByOne:SPBR@0.2 | 50 | `~.` | wald | 0.097 | 0.903 | -0.075 | 0.1 | 0.9 | ok |
| SeqOneByOne:SPBR@0.2 | 200 | `~.` | wald | 0.08 | 0.92 | 0.024 | 0.1 | 0.9 | ok |
| SeqOneByOne:SPBR@0.2 | 1000 | `~.` | wald | 0.068 | 0.932 | 0.034 | 0.0698 | 0.93 | ok |
| SeqOneByOne:SPBR@0.2 | 50 | `~1` | rand | 0.051 |  | -0.039 | 0.05 | 0.95 | ok |
| SeqOneByOne:SPBR@0.2 | 200 | `~1` | rand | 0.053 |  | 0.035 | 0.05 | 0.95 | ok |
| SeqOneByOne:SPBR@0.2 | 1000 | `~1` | rand | 0.042 |  | 0.12 | 0.05 | 0.95 | ok |
| SeqOneByOne:SPBR@0.2 | 50 | `~1` | wald | 0.041 | 0.959 | -0.039 | 0.1 | 0.9 | ok |
| SeqOneByOne:SPBR@0.2 | 200 | `~1` | wald | 0.04 | 0.96 | 0.035 | 0.1 | 0.9 | ok |
| SeqOneByOne:SPBR@0.2 | 1000 | `~1` | wald | 0.034 | 0.966 | 0.12 | 0.0698 | 0.93 | ok |
| SeqOneByOne:Urn | 50 | `~.` | rand | 0.041 |  | 0.043 | 0.05 | 0.95 | ok |
| SeqOneByOne:Urn | 200 | `~.` | rand | 0.047 |  | -0.018 | 0.05 | 0.95 | ok |
| SeqOneByOne:Urn | 1000 | `~.` | rand | 0.053 |  | -0.032 | 0.05 | 0.95 | ok |
| SeqOneByOne:Urn | 50 | `~.` | wald | 0.055 | 0.945 | 0.043 | 0.1 | 0.9 | ok |
| SeqOneByOne:Urn | 200 | `~.` | wald | 0.054 | 0.946 | -0.018 | 0.0698 | 0.93 | ok |
| SeqOneByOne:Urn | 1000 | `~.` | wald | 0.066 | 0.934 | -0.032 | 0.0568 | 0.943 | ok |
| SeqOneByOne:Urn | 50 | `~1` | rand | 0.048 |  | 0.028 | 0.05 | 0.95 | ok |
| SeqOneByOne:Urn | 200 | `~1` | rand | 0.05 |  | -0.021 | 0.05 | 0.95 | ok |
| SeqOneByOne:Urn | 1000 | `~1` | rand | 0.044 |  | 0.021 | 0.05 | 0.95 | ok |
| SeqOneByOne:Urn | 50 | `~1` | wald | 0.029 | 0.971 | 0.028 | 0.1 | 0.9 | ok |
| SeqOneByOne:Urn | 200 | `~1` | wald | 0.049 | 0.951 | -0.021 | 0.0698 | 0.93 | ok |
| SeqOneByOne:Urn | 1000 | `~1` | wald | 0.043 | 0.957 | 0.021 | 0.0568 | 0.943 | ok |

Power effects: 256 cells (0 failing coverage).

| design | n | effect | formula | procedure | power | coverage of the true estimand | coverage level | verdict |
|---|---|---|---|---|---|---|---|---|
| Fixed:Bernoulli | 50 | power20 | `~.` | rand | 0.11 |  | 0.95 | ok |
| Fixed:Bernoulli | 200 | power20 | `~.` | rand | 0.168 |  | 0.95 | ok |
| Fixed:Bernoulli | 50 | power20 | `~.` | wald | 0.124 | 0.95 | 0.9 | ok |
| Fixed:Bernoulli | 200 | power20 | `~.` | wald | 0.174 | 0.932 | 0.93 | ok |
| Fixed:Bernoulli | 50 | power20 | `~1` | rand | 0.084 |  | 0.95 | ok |
| Fixed:Bernoulli | 200 | power20 | `~1` | rand | 0.08 |  | 0.95 | ok |
| Fixed:Bernoulli | 50 | power20 | `~1` | wald | 0.036 | 0.972 | 0.9 | ok |
| Fixed:Bernoulli | 200 | power20 | `~1` | wald | 0.066 | 0.94 | 0.93 | ok |
| Fixed:Bernoulli@0.2 | 50 | power20 | `~.` | rand | 0.088 |  | 0.95 | ok |
| Fixed:Bernoulli@0.2 | 200 | power20 | `~.` | rand | 0.12 |  | 0.95 | ok |
| Fixed:Bernoulli@0.2 | 50 | power20 | `~.` | wald | 0.112 | 0.922 | 0.9 | ok |
| Fixed:Bernoulli@0.2 | 200 | power20 | `~.` | wald | 0.17 | 0.922 | 0.9 | ok |
| Fixed:Bernoulli@0.2 | 50 | power20 | `~1` | rand | 0.088 |  | 0.95 | ok |
| Fixed:Bernoulli@0.2 | 200 | power20 | `~1` | rand | 0.068 |  | 0.95 | ok |
| Fixed:Bernoulli@0.2 | 50 | power20 | `~1` | wald | 0.062 | 0.956 | 0.9 | ok |
| Fixed:Bernoulli@0.2 | 200 | power20 | `~1` | wald | 0.07 | 0.95 | 0.9 | ok |
| Fixed:BinaryMatch | 50 | power20 | `~.` | rand | 0.132 |  | 0.95 | ok |
| Fixed:BinaryMatch | 200 | power20 | `~.` | rand | 0.17 |  | 0.95 | ok |
| Fixed:BinaryMatch | 50 | power20 | `~.` | wald | 0.148 | 0.946 | 0.9 | ok |
| Fixed:BinaryMatch | 200 | power20 | `~.` | wald | 0.17 | 0.95 | 0.93 | ok |
| Fixed:BinaryMatch | 50 | power20 | `~1` | rand | 0.106 |  | 0.95 | ok |
| Fixed:BinaryMatch | 200 | power20 | `~1` | rand | 0.13 |  | 0.95 | ok |
| Fixed:BinaryMatch | 50 | power20 | `~1` | wald | 0.006 | 0.996 | 0.9 | ok |
| Fixed:BinaryMatch | 200 | power20 | `~1` | wald | 0.018 | 0.992 | 0.93 | ok |
| Fixed:Blocking | 50 | power20 | `~.` | rand | 0.13 |  | 0.95 | ok |
| Fixed:Blocking | 200 | power20 | `~.` | rand | 0.148 |  | 0.95 | ok |
| Fixed:Blocking | 50 | power20 | `~.` | wald | 0.146 | 0.964 | 0.9 | ok |
| Fixed:Blocking | 200 | power20 | `~.` | wald | 0.174 | 0.922 | 0.93 | ok |
| Fixed:Blocking | 50 | power20 | `~1` | rand | 0.068 |  | 0.95 | ok |
| Fixed:Blocking | 200 | power20 | `~1` | rand | 0.072 |  | 0.95 | ok |
| Fixed:Blocking | 50 | power20 | `~1` | wald | 0.024 | 0.992 | 0.9 | ok |
| Fixed:Blocking | 200 | power20 | `~1` | wald | 0.056 | 0.964 | 0.93 | ok |
| Fixed:Blocking@0.2 | 50 | power20 | `~.` | rand | 0.102 |  | 0.95 | ok |
| Fixed:Blocking@0.2 | 200 | power20 | `~.` | rand | 0.118 |  | 0.95 | ok |
| Fixed:Blocking@0.2 | 50 | power20 | `~.` | wald | 0.138 | 0.926 | 0.9 | ok |
| Fixed:Blocking@0.2 | 200 | power20 | `~.` | wald | 0.146 | 0.928 | 0.9 | ok |
| Fixed:Blocking@0.2 | 50 | power20 | `~1` | rand | 0.08 |  | 0.95 | ok |
| Fixed:Blocking@0.2 | 200 | power20 | `~1` | rand | 0.08 |  | 0.95 | ok |
| Fixed:Blocking@0.2 | 50 | power20 | `~1` | wald | 0.058 | 0.958 | 0.9 | ok |
| Fixed:Blocking@0.2 | 200 | power20 | `~1` | wald | 0.054 | 0.966 | 0.9 | ok |
| Fixed:Greedy | 50 | power20 | `~.` | rand | 0.15 |  | 0.95 | ok |
| Fixed:Greedy | 200 | power20 | `~.` | rand | 0.152 |  | 0.95 | ok |
| Fixed:Greedy | 50 | power20 | `~.` | wald | 0.174 | 0.918 | 0.9 | ok |
| Fixed:Greedy | 200 | power20 | `~.` | wald | 0.174 | 0.948 | 0.93 | ok |
| Fixed:Greedy | 50 | power20 | `~1` | rand | 0.09 |  | 0.95 | ok |
| Fixed:Greedy | 200 | power20 | `~1` | rand | 0.112 |  | 0.95 | ok |
| Fixed:Greedy | 50 | power20 | `~1` | wald | 0.006 | 0.998 | 0.9 | ok |
| Fixed:Greedy | 200 | power20 | `~1` | wald | 0.02 | 0.992 | 0.93 | ok |
| Fixed:Greedy@0.2 | 50 | power20 | `~.` | rand | 0.122 |  | 0.95 | ok |
| Fixed:Greedy@0.2 | 200 | power20 | `~.` | rand | 0.118 |  | 0.95 | ok |
| Fixed:Greedy@0.2 | 50 | power20 | `~.` | wald | 0.148 | 0.93 | 0.9 | ok |
| Fixed:Greedy@0.2 | 200 | power20 | `~.` | wald | 0.136 | 0.944 | 0.9 | ok |
| Fixed:Greedy@0.2 | 50 | power20 | `~1` | rand | 0.084 |  | 0.95 | ok |
| Fixed:Greedy@0.2 | 200 | power20 | `~1` | rand | 0.118 |  | 0.95 | ok |
| Fixed:Greedy@0.2 | 50 | power20 | `~1` | wald | 0.008 | 1 | 0.9 | ok |
| Fixed:Greedy@0.2 | 200 | power20 | `~1` | wald | 0.022 | 0.996 | 0.9 | ok |
| Fixed:GreedyDOptimal | 50 | power20 | `~.` | rand | 0.15 |  | 0.95 | ok |
| Fixed:GreedyDOptimal | 200 | power20 | `~.` | rand | 0.152 |  | 0.95 | ok |
| Fixed:GreedyDOptimal | 50 | power20 | `~.` | wald | 0.174 | 0.918 | 0.9 | ok |
| Fixed:GreedyDOptimal | 200 | power20 | `~.` | wald | 0.174 | 0.948 | 0.93 | ok |
| Fixed:GreedyDOptimal | 50 | power20 | `~1` | rand | 0.09 |  | 0.95 | ok |
| Fixed:GreedyDOptimal | 200 | power20 | `~1` | rand | 0.112 |  | 0.95 | ok |
| Fixed:GreedyDOptimal | 50 | power20 | `~1` | wald | 0.006 | 0.998 | 0.9 | ok |
| Fixed:GreedyDOptimal | 200 | power20 | `~1` | wald | 0.02 | 0.992 | 0.93 | ok |
| Fixed:GreedyDOptimal@0.2 | 50 | power20 | `~.` | rand | 0.122 |  | 0.95 | ok |
| Fixed:GreedyDOptimal@0.2 | 200 | power20 | `~.` | rand | 0.118 |  | 0.95 | ok |
| Fixed:GreedyDOptimal@0.2 | 50 | power20 | `~.` | wald | 0.148 | 0.93 | 0.9 | ok |
| Fixed:GreedyDOptimal@0.2 | 200 | power20 | `~.` | wald | 0.136 | 0.944 | 0.9 | ok |
| Fixed:GreedyDOptimal@0.2 | 50 | power20 | `~1` | rand | 0.084 |  | 0.95 | ok |
| Fixed:GreedyDOptimal@0.2 | 200 | power20 | `~1` | rand | 0.118 |  | 0.95 | ok |
| Fixed:GreedyDOptimal@0.2 | 50 | power20 | `~1` | wald | 0.008 | 1 | 0.9 | ok |
| Fixed:GreedyDOptimal@0.2 | 200 | power20 | `~1` | wald | 0.022 | 0.996 | 0.9 | ok |
| Fixed:iBCRD | 50 | power20 | `~.` | rand | 0.12 |  | 0.95 | ok |
| Fixed:iBCRD | 200 | power20 | `~.` | rand | 0.138 |  | 0.95 | ok |
| Fixed:iBCRD | 50 | power20 | `~.` | wald | 0.136 | 0.946 | 0.9 | ok |
| Fixed:iBCRD | 200 | power20 | `~.` | wald | 0.156 | 0.954 | 0.93 | ok |
| Fixed:iBCRD | 50 | power20 | `~1` | rand | 0.058 |  | 0.95 | ok |
| Fixed:iBCRD | 200 | power20 | `~1` | rand | 0.106 |  | 0.95 | ok |
| Fixed:iBCRD | 50 | power20 | `~1` | wald | 0.028 | 0.986 | 0.9 | ok |
| Fixed:iBCRD | 200 | power20 | `~1` | wald | 0.086 | 0.952 | 0.93 | ok |
| Fixed:iBCRD@0.2 | 50 | power20 | `~.` | rand | 0.116 |  | 0.95 | ok |
| Fixed:iBCRD@0.2 | 200 | power20 | `~.` | rand | 0.12 |  | 0.95 | ok |
| Fixed:iBCRD@0.2 | 50 | power20 | `~.` | wald | 0.16 | 0.926 | 0.9 | ok |
| Fixed:iBCRD@0.2 | 200 | power20 | `~.` | wald | 0.14 | 0.93 | 0.9 | ok |
| Fixed:iBCRD@0.2 | 50 | power20 | `~1` | rand | 0.088 |  | 0.95 | ok |
| Fixed:iBCRD@0.2 | 200 | power20 | `~1` | rand | 0.076 |  | 0.95 | ok |
| Fixed:iBCRD@0.2 | 50 | power20 | `~1` | wald | 0.076 | 0.946 | 0.9 | ok |
| Fixed:iBCRD@0.2 | 200 | power20 | `~1` | wald | 0.062 | 0.946 | 0.9 | ok |
| Fixed:MatchingGreedyPairSwitching | 50 | power20 | `~.` | rand | 0.128 |  | 0.95 | ok |
| Fixed:MatchingGreedyPairSwitching | 200 | power20 | `~.` | rand | 0.168 |  | 0.95 | ok |
| Fixed:MatchingGreedyPairSwitching | 50 | power20 | `~.` | wald | 0.148 | 0.922 | 0.9 | ok |
| Fixed:MatchingGreedyPairSwitching | 200 | power20 | `~.` | wald | 0.182 | 0.938 | 0.93 | ok |
| Fixed:MatchingGreedyPairSwitching | 50 | power20 | `~1` | rand | 0.1 |  | 0.95 | ok |
| Fixed:MatchingGreedyPairSwitching | 200 | power20 | `~1` | rand | 0.076 |  | 0.95 | ok |
| Fixed:MatchingGreedyPairSwitching | 50 | power20 | `~1` | wald | 0.008 | 0.998 | 0.9 | ok |
| Fixed:MatchingGreedyPairSwitching | 200 | power20 | `~1` | wald | 0.008 | 1 | 0.93 | ok |
| Fixed:Optimal | 50 | power20 | `~.` | wald | 0.154 | 0.938 | 0.9 | ok |
| Fixed:Optimal | 200 | power20 | `~.` | wald | 0.168 | 0.946 | 0.93 | ok |
| Fixed:Optimal | 50 | power20 | `~1` | wald | 0.01 | 0.994 | 0.9 | ok |
| Fixed:Optimal | 200 | power20 | `~1` | wald | 0.01 | 0.996 | 0.93 | ok |
| Fixed:Optimal@0.2 | 50 | power20 | `~.` | wald | 0.122 | 0.918 | 0.9 | ok |
| Fixed:Optimal@0.2 | 200 | power20 | `~.` | wald | 0.136 | 0.956 | 0.9 | ok |
| Fixed:Optimal@0.2 | 50 | power20 | `~1` | wald | 0.012 | 0.998 | 0.9 | ok |
| Fixed:Optimal@0.2 | 200 | power20 | `~1` | wald | 0.02 | 0.996 | 0.9 | ok |
| Fixed:OptimalBlocks | 50 | power20 | `~.` | rand | 0.148 |  | 0.95 | ok |
| Fixed:OptimalBlocks | 200 | power20 | `~.` | rand | 0.158 |  | 0.95 | ok |
| Fixed:OptimalBlocks | 50 | power20 | `~.` | wald | 0.15 | 0.942 | 0.9 | ok |
| Fixed:OptimalBlocks | 200 | power20 | `~.` | wald | 0.184 | 0.932 | 0.93 | ok |
| Fixed:OptimalBlocks | 50 | power20 | `~1` | rand | 0.088 |  | 0.95 | ok |
| Fixed:OptimalBlocks | 200 | power20 | `~1` | rand | 0.104 |  | 0.95 | ok |
| Fixed:OptimalBlocks | 50 | power20 | `~1` | wald | 0.032 | 0.988 | 0.9 | ok |
| Fixed:OptimalBlocks | 200 | power20 | `~1` | wald | 0.046 | 0.986 | 0.93 | ok |
| Fixed:OptimalBlocks@0.2 | 50 | power20 | `~.` | rand | 0.084 |  | 0.95 | ok |
| Fixed:OptimalBlocks@0.2 | 200 | power20 | `~.` | rand | 0.104 |  | 0.95 | ok |
| Fixed:OptimalBlocks@0.2 | 50 | power20 | `~.` | wald | 0.126 | 0.936 | 0.9 | ok |
| Fixed:OptimalBlocks@0.2 | 200 | power20 | `~.` | wald | 0.128 | 0.914 | 0.9 | ok |
| Fixed:OptimalBlocks@0.2 | 50 | power20 | `~1` | rand | 0.048 |  | 0.95 | ok |
| Fixed:OptimalBlocks@0.2 | 200 | power20 | `~1` | rand | 0.088 |  | 0.95 | ok |
| Fixed:OptimalBlocks@0.2 | 50 | power20 | `~1` | wald | 0.028 | 0.972 | 0.9 | ok |
| Fixed:OptimalBlocks@0.2 | 200 | power20 | `~1` | wald | 0.042 | 0.978 | 0.9 | ok |
| Fixed:Rerandomization | 50 | power20 | `~.` | rand | 0.12 |  | 0.95 | ok |
| Fixed:Rerandomization | 200 | power20 | `~.` | rand | 0.132 |  | 0.95 | ok |
| Fixed:Rerandomization | 50 | power20 | `~.` | wald | 0.16 | 0.946 | 0.9 | ok |
| Fixed:Rerandomization | 200 | power20 | `~.` | wald | 0.152 | 0.954 | 0.93 | ok |
| Fixed:Rerandomization | 50 | power20 | `~1` | rand | 0.076 |  | 0.95 | ok |
| Fixed:Rerandomization | 200 | power20 | `~1` | rand | 0.076 |  | 0.95 | ok |
| Fixed:Rerandomization | 50 | power20 | `~1` | wald | 0.042 | 0.968 | 0.9 | ok |
| Fixed:Rerandomization | 200 | power20 | `~1` | wald | 0.066 | 0.946 | 0.93 | ok |
| Fixed:Rerandomization@0.2 | 50 | power20 | `~.` | rand | 0.084 |  | 0.95 | ok |
| Fixed:Rerandomization@0.2 | 200 | power20 | `~.` | rand | 0.112 |  | 0.95 | ok |
| Fixed:Rerandomization@0.2 | 50 | power20 | `~.` | wald | 0.122 | 0.918 | 0.9 | ok |
| Fixed:Rerandomization@0.2 | 200 | power20 | `~.` | wald | 0.13 | 0.94 | 0.9 | ok |
| Fixed:Rerandomization@0.2 | 50 | power20 | `~1` | rand | 0.074 |  | 0.95 | ok |
| Fixed:Rerandomization@0.2 | 200 | power20 | `~1` | rand | 0.072 |  | 0.95 | ok |
| Fixed:Rerandomization@0.2 | 50 | power20 | `~1` | wald | 0.044 | 0.954 | 0.9 | ok |
| Fixed:Rerandomization@0.2 | 200 | power20 | `~1` | wald | 0.08 | 0.928 | 0.9 | ok |
| SeqOneByOne:Atkinson | 50 | power20 | `~.` | rand | 0.14 |  | 0.95 | ok |
| SeqOneByOne:Atkinson | 200 | power20 | `~.` | rand | 0.154 |  | 0.95 | ok |
| SeqOneByOne:Atkinson | 50 | power20 | `~.` | wald | 0.142 | 0.924 | 0.9 | ok |
| SeqOneByOne:Atkinson | 200 | power20 | `~.` | wald | 0.162 | 0.956 | 0.93 | ok |
| SeqOneByOne:Atkinson | 50 | power20 | `~1` | rand | 0.094 |  | 0.95 | ok |
| SeqOneByOne:Atkinson | 200 | power20 | `~1` | rand | 0.096 |  | 0.95 | ok |
| SeqOneByOne:Atkinson | 50 | power20 | `~1` | wald | 0.012 | 0.994 | 0.9 | ok |
| SeqOneByOne:Atkinson | 200 | power20 | `~1` | wald | 0.034 | 0.986 | 0.93 | ok |
| SeqOneByOne:Bernoulli | 50 | power20 | `~.` | rand | 0.128 |  | 0.95 | ok |
| SeqOneByOne:Bernoulli | 200 | power20 | `~.` | rand | 0.15 |  | 0.95 | ok |
| SeqOneByOne:Bernoulli | 50 | power20 | `~.` | wald | 0.14 | 0.92 | 0.9 | ok |
| SeqOneByOne:Bernoulli | 200 | power20 | `~.` | wald | 0.17 | 0.936 | 0.93 | ok |
| SeqOneByOne:Bernoulli | 50 | power20 | `~1` | rand | 0.078 |  | 0.95 | ok |
| SeqOneByOne:Bernoulli | 200 | power20 | `~1` | rand | 0.112 |  | 0.95 | ok |
| SeqOneByOne:Bernoulli | 50 | power20 | `~1` | wald | 0.048 | 0.972 | 0.9 | ok |
| SeqOneByOne:Bernoulli | 200 | power20 | `~1` | wald | 0.084 | 0.948 | 0.93 | ok |
| SeqOneByOne:Bernoulli@0.2 | 50 | power20 | `~.` | rand | 0.088 |  | 0.95 | ok |
| SeqOneByOne:Bernoulli@0.2 | 200 | power20 | `~.` | rand | 0.082 |  | 0.95 | ok |
| SeqOneByOne:Bernoulli@0.2 | 50 | power20 | `~.` | wald | 0.136 | 0.922 | 0.9 | ok |
| SeqOneByOne:Bernoulli@0.2 | 200 | power20 | `~.` | wald | 0.114 | 0.952 | 0.9 | ok |
| SeqOneByOne:Bernoulli@0.2 | 50 | power20 | `~1` | rand | 0.072 |  | 0.95 | ok |
| SeqOneByOne:Bernoulli@0.2 | 200 | power20 | `~1` | rand | 0.074 |  | 0.95 | ok |
| SeqOneByOne:Bernoulli@0.2 | 50 | power20 | `~1` | wald | 0.054 | 0.968 | 0.9 | ok |
| SeqOneByOne:Bernoulli@0.2 | 200 | power20 | `~1` | wald | 0.046 | 0.952 | 0.9 | ok |
| SeqOneByOne:Efron | 50 | power20 | `~.` | rand | 0.136 |  | 0.95 | ok |
| SeqOneByOne:Efron | 200 | power20 | `~.` | rand | 0.154 |  | 0.95 | ok |
| SeqOneByOne:Efron | 50 | power20 | `~.` | wald | 0.142 | 0.932 | 0.9 | ok |
| SeqOneByOne:Efron | 200 | power20 | `~.` | wald | 0.162 | 0.944 | 0.93 | ok |
| SeqOneByOne:Efron | 50 | power20 | `~1` | rand | 0.096 |  | 0.95 | ok |
| SeqOneByOne:Efron | 200 | power20 | `~1` | rand | 0.058 |  | 0.95 | ok |
| SeqOneByOne:Efron | 50 | power20 | `~1` | wald | 0.056 | 0.972 | 0.9 | ok |
| SeqOneByOne:Efron | 200 | power20 | `~1` | wald | 0.06 | 0.962 | 0.93 | ok |
| SeqOneByOne:iBCRD | 50 | power20 | `~.` | rand | 0.144 |  | 0.95 | ok |
| SeqOneByOne:iBCRD | 200 | power20 | `~.` | rand | 0.142 |  | 0.95 | ok |
| SeqOneByOne:iBCRD | 50 | power20 | `~.` | wald | 0.16 | 0.952 | 0.9 | ok |
| SeqOneByOne:iBCRD | 200 | power20 | `~.` | wald | 0.17 | 0.946 | 0.93 | ok |
| SeqOneByOne:iBCRD | 50 | power20 | `~1` | rand | 0.062 |  | 0.95 | ok |
| SeqOneByOne:iBCRD | 200 | power20 | `~1` | rand | 0.082 |  | 0.95 | ok |
| SeqOneByOne:iBCRD | 50 | power20 | `~1` | wald | 0.03 | 0.98 | 0.9 | ok |
| SeqOneByOne:iBCRD | 200 | power20 | `~1` | wald | 0.074 | 0.972 | 0.93 | ok |
| SeqOneByOne:iBCRD@0.2 | 50 | power20 | `~.` | rand | 0.094 |  | 0.95 | ok |
| SeqOneByOne:iBCRD@0.2 | 200 | power20 | `~.` | rand | 0.11 |  | 0.95 | ok |
| SeqOneByOne:iBCRD@0.2 | 50 | power20 | `~.` | wald | 0.132 | 0.952 | 0.9 | ok |
| SeqOneByOne:iBCRD@0.2 | 200 | power20 | `~.` | wald | 0.122 | 0.94 | 0.9 | ok |
| SeqOneByOne:iBCRD@0.2 | 50 | power20 | `~1` | rand | 0.068 |  | 0.95 | ok |
| SeqOneByOne:iBCRD@0.2 | 200 | power20 | `~1` | rand | 0.076 |  | 0.95 | ok |
| SeqOneByOne:iBCRD@0.2 | 50 | power20 | `~1` | wald | 0.068 | 0.954 | 0.9 | ok |
| SeqOneByOne:iBCRD@0.2 | 200 | power20 | `~1` | wald | 0.06 | 0.96 | 0.9 | ok |
| SeqOneByOne:KK14 | 50 | power20 | `~.` | rand | 0.116 |  | 0.95 | ok |
| SeqOneByOne:KK14 | 200 | power20 | `~.` | rand | 0.164 |  | 0.95 | ok |
| SeqOneByOne:KK14 | 50 | power20 | `~.` | wald | 0.116 | 0.93 | 0.9 | ok |
| SeqOneByOne:KK14 | 200 | power20 | `~.` | wald | 0.14 | 0.946 | 0.93 | ok |
| SeqOneByOne:KK14 | 50 | power20 | `~1` | rand | 0.072 |  | 0.95 | ok |
| SeqOneByOne:KK14 | 200 | power20 | `~1` | rand | 0.118 |  | 0.95 | ok |
| SeqOneByOne:KK14 | 50 | power20 | `~1` | wald | 0.034 | 0.99 | 0.9 | ok |
| SeqOneByOne:KK14 | 200 | power20 | `~1` | wald | 0.044 | 0.99 | 0.93 | ok |
| SeqOneByOne:KK21 | 50 | power20 | `~.` | rand | 0.12 |  | 0.95 | ok |
| SeqOneByOne:KK21 | 200 | power20 | `~.` | rand | 0.148 |  | 0.95 | ok |
| SeqOneByOne:KK21 | 50 | power20 | `~.` | wald | 0.152 | 0.948 | 0.9 | ok |
| SeqOneByOne:KK21 | 200 | power20 | `~.` | wald | 0.164 | 0.954 | 0.93 | ok |
| SeqOneByOne:KK21 | 50 | power20 | `~1` | rand | 0.092 |  | 0.95 | ok |
| SeqOneByOne:KK21 | 200 | power20 | `~1` | rand | 0.094 |  | 0.95 | ok |
| SeqOneByOne:KK21 | 50 | power20 | `~1` | wald | 0.024 | 0.99 | 0.9 | ok |
| SeqOneByOne:KK21 | 200 | power20 | `~1` | wald | 0.028 | 0.984 | 0.93 | ok |
| SeqOneByOne:KK21stepwise | 50 | power20 | `~.` | rand | 0.14 |  | 0.95 | ok |
| SeqOneByOne:KK21stepwise | 200 | power20 | `~.` | rand | 0.142 |  | 0.95 | ok |
| SeqOneByOne:KK21stepwise | 50 | power20 | `~.` | wald | 0.142 | 0.938 | 0.9 | ok |
| SeqOneByOne:KK21stepwise | 200 | power20 | `~.` | wald | 0.156 | 0.946 | 0.93 | ok |
| SeqOneByOne:KK21stepwise | 50 | power20 | `~1` | rand | 0.086 |  | 0.95 | ok |
| SeqOneByOne:KK21stepwise | 200 | power20 | `~1` | rand | 0.084 |  | 0.95 | ok |
| SeqOneByOne:KK21stepwise | 50 | power20 | `~1` | wald | 0.026 | 0.986 | 0.9 | ok |
| SeqOneByOne:KK21stepwise | 200 | power20 | `~1` | wald | 0.042 | 0.984 | 0.93 | ok |
| SeqOneByOne:PocockSimon | 50 | power20 | `~.` | rand | 0.102 |  | 0.95 | ok |
| SeqOneByOne:PocockSimon | 200 | power20 | `~.` | rand | 0.162 |  | 0.95 | ok |
| SeqOneByOne:PocockSimon | 50 | power20 | `~.` | wald | 0.132 | 0.944 | 0.9 | ok |
| SeqOneByOne:PocockSimon | 200 | power20 | `~.` | wald | 0.164 | 0.94 | 0.93 | ok |
| SeqOneByOne:PocockSimon | 50 | power20 | `~1` | rand | 0.048 |  | 0.95 | ok |
| SeqOneByOne:PocockSimon | 200 | power20 | `~1` | rand | 0.108 |  | 0.95 | ok |
| SeqOneByOne:PocockSimon | 50 | power20 | `~1` | wald | 0.018 | 0.99 | 0.9 | ok |
| SeqOneByOne:PocockSimon | 200 | power20 | `~1` | wald | 0.076 | 0.95 | 0.93 | ok |
| SeqOneByOne:RandomBlockSize | 50 | power20 | `~.` | rand | 0.136 |  | 0.95 | ok |
| SeqOneByOne:RandomBlockSize | 200 | power20 | `~.` | rand | 0.124 |  | 0.95 | ok |
| SeqOneByOne:RandomBlockSize | 50 | power20 | `~.` | wald | 0.138 | 0.918 | 0.9 | ok |
| SeqOneByOne:RandomBlockSize | 200 | power20 | `~.` | wald | 0.15 | 0.954 | 0.93 | ok |
| SeqOneByOne:RandomBlockSize | 50 | power20 | `~1` | rand | 0.098 |  | 0.95 | ok |
| SeqOneByOne:RandomBlockSize | 200 | power20 | `~1` | rand | 0.076 |  | 0.95 | ok |
| SeqOneByOne:RandomBlockSize | 50 | power20 | `~1` | wald | 0.044 | 0.976 | 0.9 | ok |
| SeqOneByOne:RandomBlockSize | 200 | power20 | `~1` | wald | 0.06 | 0.97 | 0.93 | ok |
| SeqOneByOne:RandomBlockSize@0.2 | 50 | power20 | `~.` | rand | 0.114 |  | 0.95 | ok |
| SeqOneByOne:RandomBlockSize@0.2 | 200 | power20 | `~.` | rand | 0.118 |  | 0.95 | ok |
| SeqOneByOne:RandomBlockSize@0.2 | 50 | power20 | `~.` | wald | 0.138 | 0.916 | 0.9 | ok |
| SeqOneByOne:RandomBlockSize@0.2 | 200 | power20 | `~.` | wald | 0.144 | 0.926 | 0.9 | ok |
| SeqOneByOne:RandomBlockSize@0.2 | 50 | power20 | `~1` | rand | 0.076 |  | 0.95 | ok |
| SeqOneByOne:RandomBlockSize@0.2 | 200 | power20 | `~1` | rand | 0.078 |  | 0.95 | ok |
| SeqOneByOne:RandomBlockSize@0.2 | 50 | power20 | `~1` | wald | 0.048 | 0.97 | 0.9 | ok |
| SeqOneByOne:RandomBlockSize@0.2 | 200 | power20 | `~1` | wald | 0.066 | 0.952 | 0.9 | ok |
| SeqOneByOne:SPBR | 50 | power20 | `~.` | rand | 0.118 |  | 0.95 | ok |
| SeqOneByOne:SPBR | 200 | power20 | `~.` | rand | 0.152 |  | 0.95 | ok |
| SeqOneByOne:SPBR | 50 | power20 | `~.` | wald | 0.136 | 0.96 | 0.9 | ok |
| SeqOneByOne:SPBR | 200 | power20 | `~.` | wald | 0.166 | 0.954 | 0.93 | ok |
| SeqOneByOne:SPBR | 50 | power20 | `~1` | rand | 0.07 |  | 0.95 | ok |
| SeqOneByOne:SPBR | 200 | power20 | `~1` | rand | 0.1 |  | 0.95 | ok |
| SeqOneByOne:SPBR | 50 | power20 | `~1` | wald | 0.038 | 0.982 | 0.9 | ok |
| SeqOneByOne:SPBR | 200 | power20 | `~1` | wald | 0.066 | 0.966 | 0.93 | ok |
| SeqOneByOne:SPBR@0.2 | 50 | power20 | `~.` | rand | 0.09 |  | 0.95 | ok |
| SeqOneByOne:SPBR@0.2 | 200 | power20 | `~.` | rand | 0.104 |  | 0.95 | ok |
| SeqOneByOne:SPBR@0.2 | 50 | power20 | `~.` | wald | 0.124 | 0.942 | 0.9 | ok |
| SeqOneByOne:SPBR@0.2 | 200 | power20 | `~.` | wald | 0.15 | 0.924 | 0.9 | ok |
| SeqOneByOne:SPBR@0.2 | 50 | power20 | `~1` | rand | 0.064 |  | 0.95 | ok |
| SeqOneByOne:SPBR@0.2 | 200 | power20 | `~1` | rand | 0.066 |  | 0.95 | ok |
| SeqOneByOne:SPBR@0.2 | 50 | power20 | `~1` | wald | 0.05 | 0.962 | 0.9 | ok |
| SeqOneByOne:SPBR@0.2 | 200 | power20 | `~1` | wald | 0.054 | 0.964 | 0.9 | ok |
| SeqOneByOne:Urn | 50 | power20 | `~.` | rand | 0.144 |  | 0.95 | ok |
| SeqOneByOne:Urn | 200 | power20 | `~.` | rand | 0.132 |  | 0.95 | ok |
| SeqOneByOne:Urn | 50 | power20 | `~.` | wald | 0.168 | 0.932 | 0.9 | ok |
| SeqOneByOne:Urn | 200 | power20 | `~.` | wald | 0.148 | 0.95 | 0.93 | ok |
| SeqOneByOne:Urn | 50 | power20 | `~1` | rand | 0.076 |  | 0.95 | ok |
| SeqOneByOne:Urn | 200 | power20 | `~1` | rand | 0.082 |  | 0.95 | ok |
| SeqOneByOne:Urn | 50 | power20 | `~1` | wald | 0.038 | 0.976 | 0.9 | ok |
| SeqOneByOne:Urn | 200 | power20 | `~1` | wald | 0.058 | 0.952 | 0.93 | ok |

[← Campaign 2026-11-15-e36c7710 summary](README.md)
