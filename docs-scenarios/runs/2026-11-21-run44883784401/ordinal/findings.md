# Findings: ordinal (EDI 1.0.4)

### F1: `InferenceOrdinalPartialProportionalOddsRegr` with no non-parallel covariates gives a different CI and p-value than `InferenceOrdinalPropOddsRegr` on the same fit, because it quietly uses a t(n-1) reference instead of the normal.
- Kind: inconsistency
- Expected: ?InferenceOrdinalPartialProportionalOddsRegr (Description) says that with an empty `nonparallel` the fit uses the same fast solver as the proportional-odds class (`fast_ordinal_regression_with_var_cpp`). Its `compute_asymp_confidence_interval()` is called "Wald-style ... using the model-based standard error". So the CI and p-value should match `InferenceOrdinalPropOddsRegr`, which uses z. Neither page mentions a t reference or what its degrees of freedom are.
- Observed: the estimate and SE are identical (-2.066547, SE 0.4754593). PO gives CI (-2.998430, -1.134664) and p = 1.383764e-05 (z). PPO gives CI (-3.011274, -1.121819) and p = 3.665735e-05. `get_summary()` labels the PPO column `Pr(>|t|)`. The PPO p-value equals `2*pt(-|z|, df = 89)`, i.e. df = n - 1, even though the model has 8 parameters. A t(n-1) reference for an ML cumulative-logit fit is non-standard (polr/clm/VGAM all use z) and undocumented.
- Repro:
  ```r
.libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
suppressMessages(library(EDI)); set_num_cores(2)
set.seed(4242); n = 90
X = data.frame(age = round(rnorm(n, 55, 12)), base_pain = round(runif(n, 3, 9), 1), female = rbinom(n, 1, 0.55))
des = DesignFixedBernoulli$new(n = n, response_type = "ordinal", verbose = FALSE, seed = 11)
des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects(); w = des$get_w()
y = 1L + findInterval(rlogis(n) - 1.3*w + 0.35*(X$base_pain - 6) + 0.02*(X$age - 55), c(-1.2, 0, 1, 2.2))
des$add_all_subject_responses(y)
po  = InferenceOrdinalPropOddsRegr$new(des)
ppo = InferenceOrdinalPartialProportionalOddsRegr$new(des)   # nonparallel = character(0): same model
c(po = po$compute_estimate(), ppo = ppo$compute_estimate())
rbind(po = po$compute_asymp_confidence_interval(), ppo = ppo$compute_asymp_confidence_interval())
c(po = po$compute_asymp_two_sided_pval(), ppo = ppo$compute_asymp_two_sided_pval())
po$get_summary(); ppo$get_summary()
se = 0.4754593; c(z = 2*pnorm(-2.066547/se), t89 = 2*pt(-2.066547/se, 89))
  ```
- Workaround used, if any: for a z-based interval, compute est ± qnorm(0.975)·SE from `get_summary()` by hand, or use `InferenceOrdinalPropOddsRegr` when every term is parallel.

### F2: `nonparallel` accepts a covariate name that does not exist and silently fits the full proportional-odds model.
- Kind: accepted bad input
- Expected: ?InferenceOrdinalPartialProportionalOddsRegr, argument `nonparallel`: "Names of covariates ... allowed a separate coefficient at each cumulative threshold". The constructor already validates this argument, since it warns when given "treatment", so an unknown name (e.g. a typo) should raise an error or at least a warning.
- Observed: `nonparallel = "base_pian"` (a typo of `base_pain`) raises no error or warning, and the estimate is exactly the full-PO estimate (-2.066547) rather than the partial-PO estimate (-2.061829). By contrast, `nonparallel = "treatment"` warns: "'treatment' in `nonparallel` is ignored: ...". A user who mistypes a name believes they have relaxed proportional odds when they have not.
- Repro:
  ```r
.libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
suppressMessages(library(EDI)); set_num_cores(2)
set.seed(4242); n = 90
X = data.frame(age = round(rnorm(n, 55, 12)), base_pain = round(runif(n, 3, 9), 1), female = rbinom(n, 1, 0.55))
des = DesignFixedBernoulli$new(n = n, response_type = "ordinal", verbose = FALSE, seed = 11)
des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects(); w = des$get_w()
y = 1L + findInterval(rlogis(n) - 1.3*w + 0.35*(X$base_pain - 6) + 0.02*(X$age - 55), c(-1.2, 0, 1, 2.2))
des$add_all_subject_responses(y)
a = InferenceOrdinalPartialProportionalOddsRegr$new(des, nonparallel = "base_pian")   # typo, no message
b = InferenceOrdinalPartialProportionalOddsRegr$new(des, nonparallel = "base_pain")
print(c(typo = a$compute_estimate(), real = b$compute_estimate()), digits = 7)
  ```
- Workaround used, if any: check the names against `colnames(X)` before calling.

### F3: `benchmark_asymp_two_sided_pval_breakdown()` returns a different estimate, SE and p-value from `compute_estimate()` / `compute_asymp_two_sided_pval()`, although the docs say it runs the same computation.
- Kind: inconsistency
- Expected: ?InferenceOrdinalPartialProportionalOddsRegr, `benchmark_asymp_two_sided_pval_breakdown()`: "runs the same computation as `$compute_asymp_two_sided_pval()`", with only timing added.
- Observed: `compute_estimate()` = -2.066547 and `compute_asymp_two_sided_pval()` = 3.665735e-05. The breakdown returns beta_hat_T = -2.065944, s_beta_hat_T = 0.475439 and pval = 3.680663e-05, so it is a different (less converged) fit.
- Repro:
  ```r
.libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
suppressMessages(library(EDI)); set_num_cores(2)
set.seed(4242); n = 90
X = data.frame(age = round(rnorm(n, 55, 12)), base_pain = round(runif(n, 3, 9), 1), female = rbinom(n, 1, 0.55))
des = DesignFixedBernoulli$new(n = n, response_type = "ordinal", verbose = FALSE, seed = 11)
des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects(); w = des$get_w()
y = 1L + findInterval(rlogis(n) - 1.3*w + 0.35*(X$base_pain - 6) + 0.02*(X$age - 55), c(-1.2, 0, 1, 2.2))
des$add_all_subject_responses(y)
ppo = InferenceOrdinalPartialProportionalOddsRegr$new(des)
print(c(est = ppo$compute_estimate(), p = ppo$compute_asymp_two_sided_pval()), digits = 7)
print(unlist(ppo$benchmark_asymp_two_sided_pval_breakdown()[c("beta_hat_T", "s_beta_hat_T", "pval")]), digits = 7)
  ```
- Workaround used, if any: none needed; use the non-benchmark methods for reporting.

### F4: The proportional-odds, cloglog, probit and cauchit classes do not document their own constructor, and the inherited `Inference$new()` documents `harden` and `seed`, which these constructors reject.
- Kind: false docs
- Expected: ?InferenceOrdinalPropOddsRegr, ?InferenceOrdinalCloglogRegr, ?InferenceOrdinalOrderedProbitRegr and ?InferenceOrdinalCauchitRegr have no `$new()` section, so a user reads ?Inference, `Inference$new(des_obj, verbose, harden = TRUE, model_formula, smart_cold_start_default, seed = NULL)`. There, `harden` is described as the switch to "verify that the raw model converges without intervention", and `seed` as the reproducibility seed.
- Observed: `InferenceOrdinalPropOddsRegr$new(des, harden = FALSE)` fails with `unused argument (harden = FALSE)`, and the same happens for cloglog, probit and cauchit. `seed = 1L` fails with `unused argument (seed = 1)` on every ordinal class tested (PO, PPO, AdjCat, Cloglog, Probit, Cauchit, ContRatio, GComp, JT, Ridit, Stereotype). AdjCat, ContRatio, Stereotype and PPO accept `harden`, so the ordinal family is also inconsistent with itself.
- Repro:
  ```r
.libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
suppressMessages(library(EDI)); set_num_cores(2)
set.seed(4242); n = 90
X = data.frame(age = round(rnorm(n, 55, 12)), base_pain = round(runif(n, 3, 9), 1), female = rbinom(n, 1, 0.55))
des = DesignFixedBernoulli$new(n = n, response_type = "ordinal", verbose = FALSE, seed = 11)
des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects(); w = des$get_w()
y = 1L + findInterval(rlogis(n) - 1.3*w + 0.35*(X$base_pain - 6) + 0.02*(X$age - 55), c(-1.2, 0, 1, 2.2))
des$add_all_subject_responses(y)
for (cl in c("InferenceOrdinalPropOddsRegr", "InferenceOrdinalCloglogRegr", "InferenceOrdinalOrderedProbitRegr", "InferenceOrdinalCauchitRegr", "InferenceOrdinalAdjCatLogitRegr"))
  for (a in list(list(harden = FALSE), list(seed = 1L)))
    cat(cl, names(a), ":", tryCatch({do.call(get(cl)$new, c(list(des), a)); "accepted"}, error = function(e) conditionMessage(e)), "\n")
  ```
- Workaround used, if any: use `inf$set_seed()` after construction; there is no way to turn off hardening on these four classes.

### F5: The R6 cumulative-link classes report point estimates that are not at the MLE: they differ from `ordinal::clm` and from EDI's own C++ backend in the 3rd significant digit (up to 0.0036 for cauchit), so the Wald CI and p-value are off too.
- Kind: reference mismatch
- Expected: vignette("validation-evidence"), "Ordinal": `fast_ordinal_*_regression_with_var_cpp` is validated against `ordinal::clm` "usually to a tight numerical tolerance". ?InferenceOrdinalCauchitRegr, ?InferenceOrdinalCloglogRegr and ?InferenceOrdinalPropOddsRegr say "Fit by maximum likelihood" with that backend. The R6 `compute_estimate()` should therefore equal the clm MLE to at least 3-4 digits.
- Observed (seed 3, n = 90, 5 levels): the R6 estimates are cauchit -0.5246222, cloglog -0.5477529, logit -0.8360498. The `*_with_var_cpp` backends give -0.5282677, -0.5479361 (sign-flipped per its documented parametrisation; NR fit), -0.8360296. `clm` gives -0.5282620, -0.5479361, -0.8360989. Over 15 simulated trials the max |R6 - clm| was 0.0036 (cauchit), 0.0014 (cloglog), 5e-4 (probit) and 4e-4 (logit). On the main trial data, PO with `model_formula = ~ base_pain * female` gave -1.914314 vs clm -1.913091. EDI's own profile-LR interval matches clm to 5-6 digits (cauchit LR CI -1.332455, 0.2014417 vs clm -1.332469, 0.2014442). So the likelihood code is right, and only the reported point estimate (and the Wald CI centred on it: EDI -1.265985, 0.2167409 vs clm -1.2702142, 0.2136903) is under-converged. No warning is given. Setting `set_optimization_alg("newton_raphson")` on the R6 object does not change the estimate (-2.0665467 either way on the main data, vs NR backend -2.0670513).
- Repro:
  ```r
.libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
suppressMessages(library(EDI)); set_num_cores(2)
set.seed(3); n = 90
X = data.frame(age = round(rnorm(n, 55, 12)), base_pain = round(runif(n, 3, 9), 1), female = rbinom(n, 1, 0.55))
des = DesignFixedBernoulli$new(n = n, response_type = "ordinal", verbose = FALSE, seed = 3)
des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects(); w = des$get_w()
y = 1L + findInterval(rlogis(n) - 0.8*w + 0.35*(X$base_pain - 6) + 0.02*(X$age - 55), c(-1.2, 0, 1, 2.2))
des$add_all_subject_responses(y)
d = data.frame(y = factor(y, ordered = TRUE), w = w, X); Xm = cbind(w = w, as.matrix(X))
out = rbind(
  cauchit = c(R6 = InferenceOrdinalCauchitRegr$new(des)$compute_estimate(),
              cpp = fast_ordinal_cauchit_regression_with_var_cpp(Xm, y)$b[1],
              clm = unname(coef(ordinal::clm(y ~ w + age + base_pain + female, data = d, link = "cauchit"))["w"])),
  cloglog = c(InferenceOrdinalCloglogRegr$new(des)$compute_estimate(),
              fast_ordinal_cloglog_regression_with_var_cpp(Xm, y)$b[1],
              coef(ordinal::clm(y ~ w + age + base_pain + female, data = d, link = "cloglog"))["w"]),
  logit   = c(InferenceOrdinalPropOddsRegr$new(des)$compute_estimate(),
              fast_ordinal_regression_with_var_cpp(Xm, y, maxit = 1000L)$b[1],
              coef(ordinal::clm(y ~ w + age + base_pain + female, data = d))["w"]))
print(out, digits = 7)
inf = InferenceOrdinalCauchitRegr$new(des)
print(rbind(EDI_wald = inf$compute_asymp_confidence_interval(), EDI_LR = inf$compute_lik_ratio_confidence_interval(),
            clm_profile = confint(ordinal::clm(y ~ w + age + base_pain + female, data = d, link = "cauchit"), type = "profile")["w", ]), digits = 7)
  ```
- Workaround used, if any: for the reported PO number, take the LR/profile interval from EDI, which matches clm, and quote clm's point estimate for the cross-check.

### F6: `compute_asymp_confidence_interval()` on `InferenceOrdinalPropOddsRegr` (Wald) and `InferenceOrdinalRidit` accepts alpha outside (0, 1): alpha = 1.5 silently returns a reversed interval, and alpha < 0 returns NaN.
- Kind: accepted bad input
- Expected: alpha is a significance level in (0, 1). The LR, bootstrap and JT interval methods on the same objects reject alpha = 1.5 with "Assertion on 'alpha' failed".
- Observed: PO `compute_asymp_confidence_interval(alpha = 1.5)` returns `-1.74585 -2.38724` (lower > upper; neither contains the estimate -2.06655), with no message. Ridit returns `-0.216374 -0.283881`. alpha = -0.1 gives `NaN NaN`, with only base R's "In stats::qnorm(1 - alpha/2) : NaNs produced" warning.
- Repro:
  ```r
.libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
suppressMessages(library(EDI)); set_num_cores(2)
set.seed(4242); n = 90
X = data.frame(age = round(rnorm(n, 55, 12)), base_pain = round(runif(n, 3, 9), 1), female = rbinom(n, 1, 0.55))
des = DesignFixedBernoulli$new(n = n, response_type = "ordinal", verbose = FALSE, seed = 11)
des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects(); w = des$get_w()
y = 1L + findInterval(rlogis(n) - 1.3*w + 0.35*(X$base_pain - 6) + 0.02*(X$age - 55), c(-1.2, 0, 1, 2.2))
des$add_all_subject_responses(y)
po = InferenceOrdinalPropOddsRegr$new(des); rid = InferenceOrdinalRidit$new(des)
po$compute_asymp_confidence_interval(alpha = 1.5)
rid$compute_asymp_confidence_interval(alpha = 1.5)
po$compute_asymp_confidence_interval(alpha = -0.1)
tryCatch(po$compute_lik_ratio_confidence_interval(alpha = 1.5), error = function(e) conditionMessage(e))   # validated here
  ```
- Workaround used, if any: none; pass a valid alpha.

### F7: The alpha check says "Element 1 is not <= 1" when alpha = 1, which is <= 1.
- Kind: false message
- Expected: the message should state the actual constraint (alpha < 1, or alpha in (0, 1)).
- Observed: `compute_lik_ratio_confidence_interval(alpha = 1)`, the JT `compute_asymp_confidence_interval(alpha = 1)` and `compute_bootstrap_confidence_interval(alpha = 1)` all fail with "Assertion on 'alpha' failed: Element 1 is not <= 1." Likewise alpha = 0 gives "Element 1 is not >= 2.22507e-308." (i.e. the lower bound is expressed as the smallest double).
- Repro:
  ```r
.libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
suppressMessages(library(EDI)); set_num_cores(2)
set.seed(4242); n = 90
X = data.frame(age = round(rnorm(n, 55, 12)), base_pain = round(runif(n, 3, 9), 1), female = rbinom(n, 1, 0.55))
des = DesignFixedBernoulli$new(n = n, response_type = "ordinal", verbose = FALSE, seed = 11)
des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects(); w = des$get_w()
y = 1L + findInterval(rlogis(n) - 1.3*w + 0.35*(X$base_pain - 6) + 0.02*(X$age - 55), c(-1.2, 0, 1, 2.2))
des$add_all_subject_responses(y)
po = InferenceOrdinalPropOddsRegr$new(des)
tryCatch(po$compute_lik_ratio_confidence_interval(alpha = 1), error = function(e) conditionMessage(e))
tryCatch(InferenceOrdinalJonckheereTerpstraTest$new(des)$compute_asymp_confidence_interval(alpha = 1), error = function(e) conditionMessage(e))
  ```
- Workaround used, if any: none needed.

### F8: When every patient is in the same category, `InferenceOrdinalRidit` returns estimate 0 with NA CI and NA p-value, with no warning and `is_nonestimable() == FALSE`. `InferenceOrdinalPropOddsRegr` returns a finite estimate of 0 for an unidentified model.
- Kind: silent NA
- Expected: a result that cannot be computed should be signalled. ?Inference describes `is_nonestimable()` / `get_nonestimable_reason()` for exactly this. The regression classes do set the flag (AdjCat, ContRatio, Cloglog and Stereotype return NA with reasons such as `model_fit_unavailable`).
- Observed (n = 40, all y = 2): Ridit gives `0 NA NA NA` with nonestimable = FALSE, reason NULL and no warning. PO gives estimate `0` (not NA) with NA CI/p and nonestimable = TRUE, reason `model_standard_error_unavailable`. A treatment log-odds ratio of 0 is reported as if it were estimated, although no ordinal model is identified with one category. On the 90-patient data with a constant y, PO also emitted the unhelpful base-R warning "non-empty data for zero-extent matrix".
- Repro:
  ```r
.libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
suppressMessages(library(EDI)); set_num_cores(2)
set.seed(1); n = 40; X = data.frame(x1 = rnorm(n))
des = DesignFixedBernoulli$new(n = n, response_type = "ordinal", verbose = FALSE, seed = 1)
des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects()
des$add_all_subject_responses(rep(2L, n))      # every patient in the same category
for (cl in c("InferenceOrdinalPropOddsRegr", "InferenceOrdinalAdjCatLogitRegr", "InferenceOrdinalContRatioRegr", "InferenceOrdinalCloglogRegr", "InferenceOrdinalRidit", "InferenceOrdinalGCompMeanDiff", "InferenceOrdinalStereotypeLogitRegr")) {
  i = get(cl)$new(des)
  r = withCallingHandlers(c(est = i$compute_estimate(), ci = i$compute_asymp_confidence_interval(), p = i$compute_asymp_two_sided_pval()),
        warning = function(w) { cat("  [warning]", conditionMessage(w), "\n"); invokeRestart("muffleWarning") })
  cat(sprintf("%-38s %s | nonestimable=%s reason=%s\n", cl, paste(format(r, digits = 4), collapse = " "), i$is_nonestimable(), paste(i$get_nonestimable_reason(), collapse = "")))
}
  ```
- Workaround used, if any: check `length(unique(y)) >= 2` before analysing.

### F9: Under quasi-complete separation (every treated patient in the lowest category), `InferenceOrdinalPropOddsRegr` reports a huge Wald estimate and CI with no warning and no non-estimable flag, and its likelihood-ratio CI is `NA NA` with no warning.
- Kind: silent NA
- Expected: ?Inference says harden = TRUE applies "defensive strategies" and that non-estimability is recorded via `is_nonestimable()`. The MLE does not exist here (clm warns "Hessian is numerically singular" and returns SE = NA). The LR interval exists as (-Inf, upper), or at least an NA should come with a reason, as the class does elsewhere (the "edi_lik_test_unavailable_warning").
- Observed: estimate -14.80798, Wald CI (-412.96, 383.34) and p = 0.942, with no warning and `is_nonestimable() = FALSE`. `compute_lik_ratio_confidence_interval()` returns `NA NA` silently, while `compute_lik_ratio_two_sided_pval()` = 5.39e-07 on the same object. A user reading only the Wald output would conclude "no evidence" (p = 0.94) for an effect the LR test calls overwhelming.
- Repro:
  ```r
.libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
suppressMessages(library(EDI)); set_num_cores(2)
set.seed(7); n = 30; X = data.frame(x1 = rnorm(n))
des = DesignFixedBernoulli$new(n = n, response_type = "ordinal", verbose = FALSE, seed = 7)
des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects(); w = des$get_w()
y = ifelse(w == 1, 1L, sample(1:5, n, TRUE))   # every treated patient reports "none": quasi-separation
des$add_all_subject_responses(y); print(table(y, w))
po = InferenceOrdinalPropOddsRegr$new(des)
withCallingHandlers({
  print(c(est = po$compute_estimate(), po$compute_asymp_confidence_interval(), p = po$compute_asymp_two_sided_pval()))
  print(c(po$compute_lik_ratio_confidence_interval(), p_LR = po$compute_lik_ratio_two_sided_pval()))
}, warning = function(w) cat("WARNING:", conditionMessage(w), "\n"))
c(nonestimable = po$is_nonestimable()); po$get_nonestimable_reason()
# reference: clm flags the problem
d = data.frame(y = factor(y, ordered = TRUE), w = w, X); cm = ordinal::clm(y ~ w + x1, data = d); coef(summary(cm))["w", ]
  ```
- Workaround used, if any: use the LR p-value, the JT/Ridit nonparametric classes, or a randomization test for such data.

### F10: `InferenceSuite`'s combined-evidence Cauchy combination quietly floors every input p-value at 1e-4, so the "combined" p (1.05e-4) is larger than 19 of the 21 p-values it combines and 27x the Liu–Xie value.
- Kind: reference mismatch
- Expected: ?InferenceSuite (`run_all_inference()` Returns, `combined_evidence`; References: Liu & Xie 2020): "the Cauchy-combination-test p-value/statistic across all usable rows under the resolved weighting policy". The Liu–Xie statistic is T = sum w_i tan((0.5 - p_i) pi), with p = 0.5 - atan(T)/pi. No truncation of the p_i is documented.
- Observed: EDI gives stat = 3043.733 and pval = 1.045788e-04. The Liu–Xie formula on `results_table$pval` and `results_table$weight` gives stat = 81447 and p = 3.91e-06. Replacing every p_i by `pmax(p_i, 1e-4)` reproduces EDI's stat and p exactly. The per-estimand lines in the screen summary have the same floor: "logodds prop (2 inferences): p = 0.000100" for constituent p-values 1.38e-05 and 4.56e-06, whose CCT is 6.9e-06. With strong effects, the combined evidence is therefore always reported as no stronger than about 1e-4, with no note.
- Repro:
  ```r
.libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
suppressMessages(library(EDI)); set_num_cores(2)
set.seed(4242); n = 90
X = data.frame(age = round(rnorm(n, 55, 12)), base_pain = round(runif(n, 3, 9), 1), female = rbinom(n, 1, 0.55))
des = DesignFixedBernoulli$new(n = n, response_type = "ordinal", verbose = FALSE, seed = 11)
des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects(); w = des$get_w()
y = 1L + findInterval(rlogis(n) - 1.3*w + 0.35*(X$base_pain - 6) + 0.02*(X$age - 55), c(-1.2, 0, 1, 2.2))
des$add_all_subject_responses(y)
res = InferenceSuite$new(des)$run_all_inference(screen = TRUE, plots = FALSE, num_cores = 2L, methods = c("wald", "lik_ratio"), max_secs_per_class = 15)
tb = res$results_table
cct = function(p, w) { w = w / sum(w); T = sum(w * tan((0.5 - p) * pi)); c(stat = T, pval = 0.5 - atan(T) / pi) }
rbind(EDI = unlist(res$combined_evidence[c("stat", "pval")]),
      LiuXie_by_hand = cct(tb$pval, tb$weight),
      by_hand_p_floored_at_1e4 = cct(pmax(tb$pval, 1e-4), tb$weight))
range(tb$pval)
  ```
- Workaround used, if any: recompute the CCT by hand from `results_table`.

### F11: In the `InferenceSuite` screen summary, every estimand group with a single inference prints "p = NA", although that row has a valid p-value.
- Kind: silent NA
- Expected: the summary lists a combined p per estimand. With one member, the CCT of one p-value is that p-value. ?InferenceSuite documents `pval = NA` only for the overall combined evidence "if fewer than 2 rows are usable", and there 21 rows are usable.
- Observed (same run as F10): "Estimand: HL shift (1 inferences): p = NA", "logodds partial prop (1 inferences): p = NA", "mann whitney effect (1 inferences): p = NA", "stoch ordering trend (1 inferences): p = NA". The rows themselves have p = 1.07e-05, 3.85e-05, 5.78e-07 and 5.76e-05. The footer also says "weighting = uniform within estimand", while `combined_evidence$weighting` is "estimand_grouped".
- Repro (look at the "Estimand:" lines of the printed summary):
  ```r
.libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
suppressMessages(library(EDI)); set_num_cores(2)
set.seed(4242); n = 90
X = data.frame(age = round(rnorm(n, 55, 12)), base_pain = round(runif(n, 3, 9), 1), female = rbinom(n, 1, 0.55))
des = DesignFixedBernoulli$new(n = n, response_type = "ordinal", verbose = FALSE, seed = 11)
des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects(); w = des$get_w()
y = 1L + findInterval(rlogis(n) - 1.3*w + 0.35*(X$base_pain - 6) + 0.02*(X$age - 55), c(-1.2, 0, 1, 2.2))
des$add_all_subject_responses(y)
res = InferenceSuite$new(des)$run_all_inference(screen = TRUE, plots = FALSE, num_cores = 2L, methods = c("wald", "lik_ratio"), max_secs_per_class = 15)
tb = res$results_table
cct = function(p, w) { w = w / sum(w); T = sum(w * tan((0.5 - p) * pi)); c(stat = T, pval = 0.5 - atan(T) / pi) }
rbind(EDI = unlist(res$combined_evidence[c("stat", "pval")]),
      LiuXie_by_hand = cct(tb$pval, tb$weight),
      by_hand_p_floored_at_1e4 = cct(pmax(tb$pval, 1e-4), tb$weight))
range(tb$pval)
  ```
- Workaround used, if any: read `results_table` instead of the printed summary.

### F12: ?InferenceOrdinalJonckheereTerpstraTest says exact enumeration is capped at one million allocations, with a warning and the asymptotic p-value above that. In fact an exact p-value is returned for 2.5e25 allocations, with no warning.
- Kind: false docs
- Expected: ?InferenceOrdinalJonckheereTerpstraTest, Description: "Exact enumeration is capped at one million allocations; above that limit the public method warns and returns the asymptotic normal p-value instead."
- Observed: with n = 90 (53 treated), choose(90, 53) = 2.5e25 allocations. `compute_exact_two_sided_pval_for_treatment_effect()` returns 8.481248e-06, not the asymptotic 5.764237e-05, and gives no warning. The value equals the exact conditional permutation p-value (two-sided as 2·min one-sided), computed by hand over the category counts. So the method is right and the documentation is wrong: it should describe the actual algorithm and limit, and the two-sided convention, since coin's exact Wilcoxon uses |U - mu| and gives a different value on tied data.
- Repro:
  ```r
.libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
suppressMessages(library(EDI)); set_num_cores(2)
set.seed(4242); n = 90
X = data.frame(age = round(rnorm(n, 55, 12)), base_pain = round(runif(n, 3, 9), 1), female = rbinom(n, 1, 0.55))
des = DesignFixedBernoulli$new(n = n, response_type = "ordinal", verbose = FALSE, seed = 11)
des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects(); w = des$get_w()
y = 1L + findInterval(rlogis(n) - 1.3*w + 0.35*(X$base_pain - 6) + 0.02*(X$age - 55), c(-1.2, 0, 1, 2.2))
des$add_all_subject_responses(y)
jt = InferenceOrdinalJonckheereTerpstraTest$new(des)
withCallingHandlers(p_exact <- jt$compute_exact_two_sided_pval_for_treatment_effect(), warning = function(w) cat("WARNING:", conditionMessage(w), "\n"))
c(n_allocations = choose(n, sum(w)), asymptotic = jt$compute_asymp_two_sided_pval(), exact = p_exact)
# exact conditional (permutation) distribution of U given the category margins, by enumeration over category counts
nk = tabulate(y); K = length(nk); nT = sum(w); nC = n - nT
Uobs = sum(outer(y[w == 1], y[w == 0], ">")) + 0.5 * sum(outer(y[w == 1], y[w == 0], "=="))
grid = expand.grid(lapply(nk, function(m) 0:m)); grid = grid[rowSums(grid) == nT, , drop = FALSE]
lw = apply(grid, 1, function(t) sum(lchoose(nk, t))); pr = exp(lw - max(lw)); pr = pr / sum(pr)
U = apply(grid, 1, function(t) { cc = nk - t; sum(t * (c(0, cumsum(cc)[-K]) + 0.5 * cc)) })
c(by_hand_2min = min(1, 2 * min(sum(pr[U <= Uobs + 1e-9]), sum(pr[U >= Uobs - 1e-9]))))
  ```
- Workaround used, if any: none needed.

