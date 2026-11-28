# Findings: custom-statistic (InferenceRandCustom, trimmed-mean difference), EDI 1.0.5

### F1: A randomization p-value is reused from an undocumented per-object cache after the statistic's behaviour changes, `clear_randomization_cache()` does not clear it, and after `compute_estimate()` the p-value silently mixes the new observed statistic with the old null distribution
- Kind: documented option fails
- Expected (and where the docs say so: help topic or vignette + section): `?Inference`, `clear_randomization_cache()`: "Drop the design-level cache of randomization permutations ... so the next randomization p-value / confidence interval redraws its permutations." Nothing in `?Inference`, `?InferenceRand`, `?InferenceRandCustom` or the article says that the *statistic values* (the null distribution) or the p-value are cached per object. A statistic that reads a tuning value from its enclosing environment (the article's own examples read the globals `H`, `X` and `m`) should be re-evaluated on the next call, or at least after `clear_randomization_cache()`.
- Observed: changing the trimming level from 0.2 to 0 and calling the p-value again on the same object returns the old p-value (0.2155689) without calling the statistic at all (a counting wrapper records 0 calls). This still happens after `clear_randomization_cache()`. If `compute_estimate()` is called in between (it re-calls the statistic), the next p-value is 0.1277445: the new observed statistic set against the cached trim-0.2 null distribution. That value is neither the old answer nor the correct new one (a fresh object gives 0.1357285). `compute_rand_confidence_interval()` on the same object *is* recomputed, so the object then reports a p-value and a CI that come from two different statistics. Changing `r` (500 -> 501) also forces recomputation. Output:
  `trim 0.2: 0.2155689 | TRIM=0 same object: 0.2155689 | after compute_estimate(): 0.1277445 | TRIM=0 fresh object: 0.1357285`
- Repro:
  ```r
.libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
suppressMessages(library(EDI)); set_num_cores(2)
set.seed(2026); n = 40
des = DesignFixediBCRD$new(response_type = "continuous", prob_T = 0.4, n = n, verbose = FALSE)
des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n))); des$assign_w_to_all_subjects()
w = des$get_w(); des$add_all_subject_responses(5 + w + rt(n, 3))
TRIM = 0.2
stat = function(y, w, dead) mean(y[w == 1], trim = TRIM) - mean(y[w == 0], trim = TRIM)
inf = InferenceRandCustom$new(des, custom_randomization_statistic_function = stat)
inf$set_seed(1); p_trim20 = inf$compute_rand_two_sided_pval(r = 500, show_progress = FALSE)
TRIM = 0                                  # analyst switches to the untrimmed mean difference
inf$clear_randomization_cache()           # documented: "the next randomization p-value ... redraws"
inf$set_seed(1); p_same_obj = inf$compute_rand_two_sided_pval(r = 500, show_progress = FALSE)
est_now = inf$compute_estimate()
inf$set_seed(1); p_mixed = inf$compute_rand_two_sided_pval(r = 500, show_progress = FALSE)
fresh = InferenceRandCustom$new(des, custom_randomization_statistic_function = stat)
fresh$set_seed(1); p_fresh = fresh$compute_rand_two_sided_pval(r = 500, show_progress = FALSE)
cat("trim 0.2:", p_trim20, "| TRIM=0 same object:", p_same_obj, "| after compute_estimate():", p_mixed,
    "| TRIM=0 fresh object:", p_fresh, "\n")
  ```
- Workaround used, if any: build a new `InferenceRandCustom` object whenever the statistic changes, and never change state that the statistic reads.

### F2: When the randomization CI fails because `r` is too small, the warning tells the `InferenceRandCustom` user to "use a bootstrap or asymptotic interval", which this class does not have, and does not mention `r`
- Kind: false message
- Expected (and where the docs say so: help topic or vignette + section): `?InferenceRandCustom` Description: "Only a randomization test and randomization confidence interval are available - there is no package point-estimator, Wald path, or bootstrap machinery on this class"; `capabilities()` returns only `"randomization_test" "randomization_ci"`. The p-value's own warning in the same situation says "Increase r".
- Observed: `compute_rand_confidence_interval(r = 9)` returns `c(NA, NA)` with: "InferenceRandCustom: randomization confidence interval returned NA (reason: rand_ci_search_bounds_failed). The search for the interval's bounds could not find deltas whose randomization p-values cross alpha (typically too few finite null-distribution draws at the deltas tried, or compute_rand_two_sided_pval() is NA). Check compute_rand_two_sided_pval() at delta = 0, or use a bootstrap or asymptotic interval." Following the message literally, `compute_rand_two_sided_pval(r = 9)` gives NA with "...at least 10 finite draws are needed. Increase r." Only that second message names the real fix. This is related to, but not the same as, known finding f4, which is about the count/proportion refusal message.
- Repro:
  ```r
.libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
suppressMessages(library(EDI)); set_num_cores(2)
set.seed(2026); n = 40
des = DesignFixediBCRD$new(response_type = "continuous", prob_T = 0.4, n = n, verbose = FALSE)
des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n))); des$assign_w_to_all_subjects()
w = des$get_w(); des$add_all_subject_responses(5 + w + rt(n, 3))
tm = function(y, w, dead) mean(y[w == 1], trim = 0.2) - mean(y[w == 0], trim = 0.2)
inf = InferenceRandCustom$new(des, custom_randomization_statistic_function = tm)
inf$set_seed(1); print(inf$compute_rand_confidence_interval(r = 9, show_progress = FALSE))
print(inf$capabilities())
inf$set_seed(1); print(inf$compute_rand_two_sided_pval(r = 9, show_progress = FALSE))   # the check the warning suggests
  ```
- Workaround used, if any: use `r >= 40` (alpha = 0.05), as `?InferenceRandCI` says.

### F3: The docs and the error message contradict each other on whether `InferenceRandCustom` on count/proportion responses offers a p-value at a nonzero `delta`; the code accepts it
- Kind: inconsistency
- Expected (and where the docs say so: help topic or vignette + section): `?InferenceRandCustom` Description: "The randomization CI is refused for incidence, count and proportion responses ...; on those types use the p-value, at `delta = 0` or at a chosen `delta`". The article ("Other response types") says the same and documents `delta` as a log rate ratio for counts. But `?InferenceRandCI`, `compute_rand_confidence_interval()`, "Estimand scale", says: "(a class with no randomization bootstrap, such as `InferenceRandCustom`, keeps only the p-value at `delta = 0`)".
- Observed: `compute_rand_two_sided_pval(delta = 0.5)` on a count response returns 0.4790419 with no warning. The CI refusal says only the delta = 0 p-value remains, and it still points to internal repo files: "Randomization confidence intervals are not supported for InferenceRandCustom with count responses: ... The randomization p-value at delta = 0 (compute_rand_two_sided_pval()) remains available. See TODO-119 in R/package_metadata/future_release_plans/release_v1_0_5.md."
- Repro:
  ```r
.libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
suppressMessages(library(EDI)); set_num_cores(2)
set.seed(2026); n = 40
des = DesignFixediBCRD$new(response_type = "count", prob_T = 0.4, n = n, verbose = FALSE)
des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n))); des$assign_w_to_all_subjects()
des$add_all_subject_responses(rpois(n, exp(1 + 0.5 * des$get_w())))
tm = function(y, w, dead) mean(y[w == 1], trim = 0.2) - mean(y[w == 0], trim = 0.2)
inf = InferenceRandCustom$new(des, custom_randomization_statistic_function = tm)
inf$set_seed(1); print(inf$compute_rand_two_sided_pval(r = 500, delta = 0.5, show_progress = FALSE))  # accepted
try(inf$compute_rand_confidence_interval(r = 200, show_progress = FALSE))
  ```
- Workaround used, if any: none needed. I relied on `?InferenceRandCustom` and checked by hand that the nonzero-delta p-value matches a manual multiplicative-shift computation (continuous log case, see analysis.R).

### F4: `type = "Zhang"` on an incidence response with a Bernoulli design fails with "only supported for incidence outcomes", and the message names a private method
- Kind: false message
- Expected (and where the docs say so: help topic or vignette + section): `?InferenceCustomRand` (superclass of `InferenceRandCustom`) and `?InferenceRandCI`, `compute_rand_two_sided_pval()`, `type`: "`"Zhang"` instead returns the Zhang exact combined test ...; it applies only to incidence responses on a Bernoulli or matching design." The response here is incidence and the design is `DesignFixedBernoulli`.
- Observed: `Error in private$assert_no_incidence_only_randomization_args(private$des_obj_priv_int$response_type, : Randomization type dispatch is only supported for incidence outcomes.` The same error comes with `args_for_type = list(Zhang = list(combination_method = "Stouffer"))`. Either Zhang is not available on this class, and the inherited help should say so, or the dispatch is broken. Either way the message is false: the outcome is incidence.
- Repro:
  ```r
.libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
suppressMessages(library(EDI)); set_num_cores(2)
set.seed(2026); n = 40
des = DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n))); des$assign_w_to_all_subjects()
des$add_all_subject_responses(rbinom(n, 1, 0.3 + 0.3 * des$get_w()))
rd = function(y, w, dead) mean(y[w == 1]) - mean(y[w == 0])
inf = InferenceRandCustom$new(des, custom_randomization_statistic_function = rd)
print(des$get_response_type())
try(inf$compute_rand_two_sided_pval(r = 300, type = "Zhang", show_progress = FALSE))
try(inf$compute_rand_two_sided_pval(r = 300, type = "Zhang", args_for_type = list(Zhang = list(combination_method = "Stouffer")), show_progress = FALSE))
  ```
- Workaround used, if any: default `type = NULL` (randomization draws), which works and returns a p-value.

### F5: A statistic that returns a non-number (character string, factor, complex, list, logical) is silently coerced, sometimes to a wrong value, although the docs say it must return one number
- Kind: accepted bad input
- Expected (and where the docs say so: help topic or vignette + section): `?InferenceRandCustom`: "It must return one scalar (a value of any other length is an error)". The article ("The statistic function"): "returns one number". The error text EDI uses for wrong lengths says "must return one number". I expected a non-numeric return to be an error, as a wrong length is.
- Observed: (same data, same seed, true numeric statistic p = 0.2155689)
  ```
  character returns character  -> estimate 0.66, p 0.2235529      (string parsed; rounding changes the p-value)
  factor    returns factor     -> estimate 1, p 1                 (factor level code used instead of 0.66)
  complex   returns complex    -> estimate 0.6581702, p 0.2155689 (imaginary part dropped; only R's coercion warning)
  list      returns list       -> estimate 0.6581702, p 0.2155689
  logical   returns logical    -> estimate 1, p 1
  ```
  No EDI warning or error appears for any of them. A non-numeric string such as `"abc"` becomes NA with R's "NAs introduced by coercion" warning. The factor case gives a plainly wrong estimate (1 instead of 0.66) and p = 1. The learnings file noted the coercion, but it was never reported as a finding.
- Repro:
  ```r
.libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
suppressMessages(library(EDI)); set_num_cores(2)
set.seed(2026); n = 40
des = DesignFixediBCRD$new(response_type = "continuous", prob_T = 0.4, n = n, verbose = FALSE)
des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n))); des$assign_w_to_all_subjects()
w = des$get_w(); des$add_all_subject_responses(5 + w + rt(n, 3))
tm = function(y, w, dead) mean(y[w == 1], trim = 0.2) - mean(y[w == 0], trim = 0.2)
stats = list(
  numeric   = tm,
  character = function(y, w, dead) sprintf("%.2f", tm(y, w)),
  factor    = function(y, w, dead) factor(sprintf("%.2f", tm(y, w))),
  complex   = function(y, w, dead) complex(real = tm(y, w), imaginary = 1),
  list      = function(y, w, dead) list(tm(y, w)),
  logical   = function(y, w, dead) tm(y, w) > 0)
for (nm in names(stats)) {
  inf = InferenceRandCustom$new(des, custom_randomization_statistic_function = stats[[nm]])
  inf$set_seed(1)
  est = inf$compute_estimate(); p = inf$compute_rand_two_sided_pval(r = 500, show_progress = FALSE)
  cat(sprintf("%-9s returns %-10s -> estimate %s, p %s\n", nm, class(stats[[nm]](des$get_y(), w, 1))[1], format(est), format(p)))
}
  ```
- Workaround used, if any: return `as.numeric(...)` of a plain double.

### F6: The article's minimum-finite-draws rule ("fewer than 10% of r ... the p-value is NA") is wrong; the code uses floor(r/10), so the p-value is returned with as few as 9.6% finite draws
- Kind: false docs
- Expected (and where the docs say so: help topic or vignette + section): article "Randomization Tests with Your Own Test Statistic", Pitfalls, "Draws where the statistic is not finite are dropped": "If fewer than 10 draws, or fewer than 10% of `r`, give a finite value, the p-value is `NA`." (`?InferenceRand` gives the precise rule, max(10, floor(r/10)), and the code follows it.)
- Observed: with r = 209 supplied draws of which 20 (9.6%) give a finite statistic, the p-value is 0.2857143, not NA. With r = 210 and 20 finite it is NA ("at least 21 are needed"). Boundaries checked: r=50/9 finite NA, 50/10 ok, 200/19 NA, 200/20 ok, 205/20 ok, 209/20 ok, 210/20 NA, 210/21 ok.
- Repro:
  ```r
.libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
suppressMessages(library(EDI)); set_num_cores(2)
set.seed(2026); n = 40
des = DesignFixediBCRD$new(response_type = "continuous", prob_T = 0.4, n = n, verbose = FALSE)
des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n))); des$assign_w_to_all_subjects()
w = des$get_w(); y = 5 + w + rt(n, 3); des$add_all_subject_responses(y)
stopifnot(w[1] == 1)
# statistic is finite only on draws with subject 1 treated (and on the observed assignment)
st = function(y, w, dead) if (w[1] == 1) mean(y[w == 1], trim = .2) - mean(y[w == 0], trim = .2) else NA_real_
# 209 supplied draws, exactly 20 with subject 1 treated (20/209 = 9.6% < 10%)
set.seed(3); r = 209
W = replicate(r, sample(w))
for (j in 1:r) { want = j <= 20; if ((W[1, j] == 1) != want) { i = which(W[, j] != W[1, j])[1]; W[c(1, i), j] = W[c(i, 1), j] } }
cat("finite draws:", sum(W[1, ] == 1), "of", r, "=", round(100 * mean(W[1, ] == 1), 1), "%\n")
inf = InferenceRandCustom$new(des, custom_randomization_statistic_function = st)
print(inf$compute_rand_two_sided_pval(r = r, permutations = list(w_mat = W), show_progress = FALSE))
  ```
- Workaround used, if any: none.

### F7: For a count response, `approximate_randomization_distribution_beta_hat_T()` and `compute_rand_two_sided_pval()` use different shifts for the same `delta` and the same default `transform_responses = "none"`, so the documented "same seed gives the draws the p-value was computed from" breaks at nonzero delta
- Kind: inconsistency
- Expected (and where the docs say so: help topic or vignette + section): `?InferenceRandCustom`, "The scale of `delta` by response type": "Under the default `transform_responses = "none"`: ... count: delta is a log rate ratio". The article says `approximate_randomization_distribution_beta_hat_T()` "returns the `r` values of the statistic under H0; with the same seed, they are the draws the p-value above was computed from". (`?InferenceRand` does say in the `approximate_...` argument text that "none" is additive there "unlike `compute_rand_two_sided_pval()`", so the two sibling methods document different meanings for the same default.)
- Observed: count response, delta = 0.5, seed 4, r = 500: `compute_rand_two_sided_pval()` = 0.5229541. The p-value recomputed from `approximate_...(delta = 0.5)` (default "none") = 0.3752495. From `approximate_...(delta = 0.5, transform_responses = "log")` = 0.5229541. So the null distribution a user plots, with the documented default, is not the one the p-value used.
- Repro:
  ```r
.libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
suppressMessages(library(EDI)); set_num_cores(2)
set.seed(2026); n = 40
des = DesignFixediBCRD$new(response_type = "count", prob_T = 0.4, n = n, verbose = FALSE)
des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n))); des$assign_w_to_all_subjects()
des$add_all_subject_responses(rpois(n, exp(1 + 0.5 * des$get_w())))
tm = function(y, w, dead) mean(y[w == 1], trim = 0.2) - mean(y[w == 0], trim = 0.2)
inf = InferenceRandCustom$new(des, custom_randomization_statistic_function = tm)
est = inf$compute_estimate()
pv = function(t0) min(1, 2 * (1 + min(sum(t0 >= est), sum(t0 <= est))) / (1 + sum(is.finite(t0))))
inf$set_seed(4); p = inf$compute_rand_two_sided_pval(r = 500, delta = 0.5, show_progress = FALSE)
inf$set_seed(4); t_none = inf$approximate_randomization_distribution_beta_hat_T(r = 500, delta = 0.5, show_progress = FALSE)
inf$set_seed(4); t_log = inf$approximate_randomization_distribution_beta_hat_T(r = 500, delta = 0.5, transform_responses = "log", show_progress = FALSE)
cat("compute_rand_two_sided_pval(delta=.5, 'none'):", p, "\n")
cat("p from approximate_...(delta=.5, 'none'):     ", pv(t_none), "\n")
cat("p from approximate_...(delta=.5, 'log'):      ", pv(t_log), "\n")
  ```
- Workaround used, if any: pass `transform_responses = "log"` (count) / `"logit"` (proportion) to `approximate_randomization_distribution_beta_hat_T()` explicitly.

### F8: The values of the `ci_search_control` entries `seed` and `fallback` are undocumented; `seed` is not an RNG seed, and `fallback = "na"` / `"error"` (the only other values the validator accepts) do not change anything
- Kind: insufficient docs
- Expected (and where the docs say so: help topic or vignette + section): `?InferenceRandCI`, `compute_rand_confidence_interval()`, `ci_search_control`: "Supported entries are `fallback`, `seed`, ...". No values are given for either entry. The same paragraph says a conservative bound is returned "rather than NA" when the search radius is exhausted, which suggests `fallback` controls that.
- Observed: `ci_search_control = list(seed = 99)` gives `Error in private$normalize_randomization_ci_search_control(ci_search_control, : Assertion on 'ctrl$seed' failed: Must be element of set {'asymp_then_boot','boot_then_asymp','asymp_only','boot_only','none'}, but types do not match (numeric != character).` The values can only be learned from this error, which also names a private method. On `InferenceRandCustom` all five values give the same CI. `fallback` accepts only `'fallback','na','error'` (again learned from the error). With a search radius that forces a conservative lower bound, all three values return the same bound `-0.1497985 1.661927` and the same message. Neither NA nor an error is produced.
- Repro:
  ```r
.libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
suppressMessages(library(EDI)); set_num_cores(2)
set.seed(2026); n = 40
des = DesignFixediBCRD$new(response_type = "continuous", prob_T = 0.4, n = n, verbose = FALSE)
des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n))); des$assign_w_to_all_subjects()
w = des$get_w(); des$add_all_subject_responses(5 + w + rt(n, 3))
tm = function(y, w, dead) mean(y[w == 1], trim = 0.2) - mean(y[w == 0], trim = 0.2)
inf = InferenceRandCustom$new(des, custom_randomization_statistic_function = tm)
# 'seed' reads like an RNG seed but is not one
inf$set_seed(1); try(inf$compute_rand_confidence_interval(r = 1000, show_progress = FALSE, ci_search_control = list(seed = 99)))
# the three values the validator accepts for 'fallback' all give the same conservative bound
small = list(max_radius_se_mult = 0.1, max_radius_scale_mult = 0.1)
for (f in c("fallback", "na", "error")) {
  inf$set_seed(1)
  ci = suppressMessages(inf$compute_rand_confidence_interval(r = 1000, show_progress = FALSE, ci_search_control = c(small, fallback = f)))
  cat("fallback =", f, ":", ci, "\n")
}
  ```
- Workaround used, if any: left both entries at their defaults.
