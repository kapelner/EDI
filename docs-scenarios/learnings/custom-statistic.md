# Learnings: custom-statistic

Appended by each weekly docs-only scenario run.

## Run 2026-11-18 (run 44358267779, 4ce2b712, ok)

## Covered
- InferenceRandCustom with R fn and C++ source (2/3-arg, lambda helper, Rcpp::cppFunction object); R vs C++ identical.
- Return-value contract: vector (first element kept), NULL/numeric(0)/NA (warning + NA), character/logical/list (silently coerced), error inside the stat (whole p-value errors), warning inside the stat (propagates).
- r: 1..9 (silent NA), 10, 0/negative/non-integer (rejected); NA-draw threshold max(10, r/10); floor 2/B.
- delta, alternative (incl. partial match "g"), na.rm, transform_responses (none/log/logit/bogus), permutations (list(w_mat=)), set_seed, num_cores 1 vs 2.
- CI: alpha values, pval_epsilon, ci_search_control mc_enable/bogus key, conservative bounds, sign/scale invariance.
- Response types incidence/count/proportion/survival with the custom stat; DesignFixedBlocking with unequal strata + ties.
- InferenceCustomRand/Asymp/Boot subclasses via getFromNamespace (extending-edi vignette).

## Not reached
- CI "errors if every delta rejected" path; KK/matched-pair/cluster/rerandomization designs with a trimmed-mean stat.
- type/args_for_type on custom incidence; zero_one_logit_clamp; debug=TRUE output when draws run in parallel.
- Why the lower CI bound was identical at r=1000 and r=2000 (0.6483714): check with other seeds.
- F10 follow-up: does InferenceRandCustom with a C++ stat or with closures over big objects behave the same across cores?

## Workarounds
- C++ helpers: put them as lambdas inside the single function (named helpers and // [[Rcpp::export]] break it).
- permutations must be list(w_mat = n x r 0/1 matrix).
- Custom shells: write the statistic inline in fit(), or set_num_cores(1), else silent NA with 2 cores.
- Never print an inference object (R6 print dumps all privates, very long).

## Confusing docs
- InferenceCustomRand help: transform_responses text says 'the default "log"' while Usage shows "none" (InferenceRandCI help explains "none" resolves to "log" for survival).
- InferenceRand help mentions "Before EDI 1.0.5" behaviour while the installed version is 1.0.4.
- Article says delta/CI are for continuous only; the code refuses some types (incidence, count/prop CI) but not others (survival, count/prop delta).
