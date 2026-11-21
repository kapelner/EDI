# Findings: count outcomes (EDI 1.0.4)

All repros share the same 8-line data block at the top (simulated with base R, fixed seed); each block runs alone in a fresh R session.

### F1: `model_formula_zero = ~ 1` (ZIP/ZINB) and `model_formula_hurdle = ~ 1` (hurdle) quietly fit a zero/hurdle part of `~ w`, not the intercept-only part the user asked for
- Kind: silent change of your input
- Expected (and where the docs say so: help topic or vignette + section): `?InferenceCountZeroInflatedPoisson`, argument `model_formula_zero`: "Formula for the zero-inflation submodel" (same wording for `model_formula_hurdle` in `?InferenceCountHurdlePoisson` / `?InferenceCountHurdleNegBin`). The Description says the two submodels "may use different covariate formulas". By analogy with `pscl::zeroinfl(y ~ ... | 1)`, `~ 1` should give a constant excess-zero probability. No page says the treatment indicator is always added to the zero/hurdle part, or that it cannot be left out.
- Observed: the coefficient table has `zero:(Intercept)` and `zero:w` (`hurdle:(Intercept)`, `hurdle:w` for the hurdle class). EDI's count-part `w` = -0.38261, which is pscl's `| w` fit (-0.38261) and not pscl's `| 1` fit (-0.52665). So the reported rate ratio silently comes from a different model. `~ 0` behaves the same way. With ZINB and `~ 1`, the separation warning says "92 of 160 fitted zero probabilities are numerically 0 or 1". That cannot happen with a truly constant zero probability. It happens here because the hidden `w` term sends the control arm (92 subjects) to the boundary.
- Repro:
  ```r
.libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
suppressMessages({library(EDI); library(pscl)})
set.seed(2026); n = 160; fu = runif(n, .25, 1)
X = data.frame(log_fu = log(fu), prior = rpois(n, 1.5), age = runif(n, 4, 15))
des = DesignFixedBernoulli$new(n = n, response_type = "count", prob_T = 0.4, seed = 11)
des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects(); w = des$get_w()
y = ifelse(rbinom(n, 1, .3) == 1, 0, rnbinom(n, size = .9, mu = fu * exp(.3 - .5 * w + .35 * X$prior - .04 * X$age)))
des$add_all_subject_responses(y); d = data.frame(y, w, X)
zi = InferenceCountZeroInflatedPoisson$new(des, model_formula_zero = ~ 1)
zi$compute_estimate()
print(rownames(zi$get_summary()))            # zero part has "zero:w" although ~ 1 was asked
print(coef(zeroinfl(y ~ w + log_fu + prior + age | 1, data = d)))  # pscl intercept-only: count_w differs
print(coef(zeroinfl(y ~ w + log_fu + prior + age | w, data = d)))  # pscl with | w reproduces EDI
hp = InferenceCountHurdlePoisson$new(des, model_formula_hurdle = ~ 1)
hp$compute_estimate(); print(rownames(hp$get_summary()))
  ```
- Workaround used, if any: none inside EDI. To cross-check against pscl I used `| w` (and `| w + covariates`) in pscl.

### F2: For ZIP and hurdle Poisson, `get_summary()` prints a model-based SE and p-value for the treatment, but `compute_asymp_*` use a sandwich SE. The two disagree (p = 0.093 vs 0.299) and the summary does not say which SE it shows
- Kind: inconsistency
- Expected (and where the docs say so: help topic or vignette + section): `?Inference`, `get_summary()`: "Prints a coefficient summary table (Estimate / Std. Error / statistic / p-value) for the most recent fit". `?InferenceCountZeroInflatedPoisson` says "The Wald test, which uses a sandwich covariance" (the hurdle Poisson page says the same). A user would expect the summary row for the treatment to agree with the class's own Wald inference, or at least to be labelled as model-based.
- Observed: ZIP: summary `conditional:w` SE 0.3407256, p 0.09289. `compute_asymp_confidence_interval()` gives (-1.653951, 0.5088892), implied SE 0.551755, and `compute_asymp_two_sided_pval()` gives 0.2994. pscl model-based SE is 0.3407262 and `sandwich::sandwich()` SE is 0.5517578, so both numbers are right but for different covariances. Hurdle Poisson: summary SE 0.3088734 vs implied asymp SE 0.4546595 (p 0.277 vs summary 0.110). For NegBin, ZINB and HurdleNegBin, the summary SE and the CI SE agree (all model-based).
- Repro:
  ```r
.libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
suppressMessages({library(EDI); library(pscl)})
set.seed(2026); n = 160; fu = runif(n, .25, 1)
X = data.frame(log_fu = log(fu), prior = rpois(n, 1.5), age = runif(n, 4, 15))
des = DesignFixedBernoulli$new(n = n, response_type = "count", prob_T = 0.4, seed = 11)
des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects(); w = des$get_w()
y = ifelse(rbinom(n, 1, .3) == 1, 0, rnbinom(n, size = .9, mu = fu * exp(.3 - .5 * w + .35 * X$prior - .04 * X$age)))
des$add_all_subject_responses(y); d = data.frame(y, w, X)
library(sandwich)
zi = InferenceCountZeroInflatedPoisson$new(des)
s = zi$get_summary()                               # summary after the fit
zi$compute_estimate(); s = zi$get_summary()
ci = zi$compute_asymp_confidence_interval(); p = zi$compute_asymp_two_sided_pval()
cat("summary SE/p for w:", s["conditional:w", 2], s["conditional:w", 4], "\n")
cat("asymp CI:", ci, " implied SE:", diff(ci) / (2 * qnorm(.975)), " asymp p:", p, "\n")
m = zeroinfl(y ~ w + log_fu + prior + age, data = d)
cat("pscl model SE:", sqrt(vcov(m)["count_w", "count_w"]), " pscl sandwich SE:", sqrt(sandwich(m)["count_w", "count_w"]), "\n")
hp = InferenceCountHurdlePoisson$new(des); hp$compute_estimate(); s = hp$get_summary()
ci = hp$compute_asymp_confidence_interval()
cat("HurdlePoisson summary SE:", s["conditional:w", 2], " asymp-CI implied SE:", diff(ci) / (2 * qnorm(.975)), " p:", hp$compute_asymp_two_sided_pval(), "\n")
  ```
- Workaround used, if any: I report the `compute_asymp_*` results and cross-checked them against `sandwich::sandwich()` on the pscl fit.

### F3: `InferenceCountHurdleNegBin$get_summary()` gives `NA` for every Std. Error, z and p-value, although the class computes a finite Wald SE. It also drops the hurdle part and uses different row labels from the other two-part classes
- Kind: silent NA
- Expected (and where the docs say so: help topic or vignette + section): `?Inference`, `get_summary()`: "Pieces that are unavailable (e.g. a Wald standard error) are shown as NA". Here the Wald SE is available: `compute_asymp_confidence_interval()` uses it, and it matches `pscl::hurdle(dist = "negbin")` to 5 digits.
- Observed:
  ```
               Estimate Std. Error z value Pr(>|z|)
  (Intercept)  0.63124524         NA      NA       NA
  treatment   -0.66682670         NA      NA       NA
  ...
  ```
  The CI is (-1.5949100, 0.2612566), implied SE 0.4735206, and pscl gives SE 0.4735219. The hurdle-part rows are missing. The rows are labelled `treatment` / `(Intercept)`, while `InferenceCountHurdlePoisson`, ZIP and ZINB use `conditional:w` / `hurdle:...` / `zero:...`. No warning says why the SEs are missing.
- Repro:
  ```r
.libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
suppressMessages({library(EDI); library(pscl)})
set.seed(2026); n = 160; fu = runif(n, .25, 1)
X = data.frame(log_fu = log(fu), prior = rpois(n, 1.5), age = runif(n, 4, 15))
des = DesignFixedBernoulli$new(n = n, response_type = "count", prob_T = 0.4, seed = 11)
des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects(); w = des$get_w()
y = ifelse(rbinom(n, 1, .3) == 1, 0, rnbinom(n, size = .9, mu = fu * exp(.3 - .5 * w + .35 * X$prior - .04 * X$age)))
des$add_all_subject_responses(y); d = data.frame(y, w, X)
hn = InferenceCountHurdleNegBin$new(des)
hn$compute_estimate()
s = hn$get_summary()                              # every Std. Error is NA
ci = hn$compute_asymp_confidence_interval(); print(ci)
cat("implied SE:", diff(ci) / (2 * qnorm(.975)), "\n")
m = hurdle(y ~ w + log_fu + prior + age, data = d, dist = "negbin")
print(summary(m)$coef$count["w", ])
zn = InferenceCountZeroInflatedNegBin$new(des, model_formula_zero = ~ prior); zn$compute_estimate(); s2 = zn$get_summary()
  ```
- Workaround used, if any: I took the SE from the width of `compute_asymp_confidence_interval()`.

### F4: An `offset(log_fu)` term in `model_formula` is accepted and echoed back by `get_model_formula()`, but it is silently dropped. The fit equals the no-offset fit in Poisson, NegBin and ZIP
- Kind: accepted bad input
- Expected (and where the docs say so: help topic or vignette + section): `vignette("cookbook-count")`, "Where to go next": "Exposure/offset (rates per unit time) is a planned addition". So offsets are not supported. A formula containing `offset()` should then raise an error, or at least a warning that the offset is ignored. Otherwise the user believes they analysed rates per unit of follow-up. `?InferenceCountPoisson`, `model_formula`: "a new design matrix is constructed from the design's imputed covariates". It says nothing about offset terms.
- Observed: no error, warning or message. `get_model_formula()` returns `~offset(log_fu) + prior + age`. Poisson: EDI -0.6178374, glm with offset -0.5406746, glm without offset -0.6178374. NegBin: EDI -0.5864577, MASS with offset -0.559916, without -0.5864579. ZIP: EDI -0.6290711, pscl with offset -0.5187766, without -0.6290719. With unequal follow-up, the reported log rate ratio is therefore not a per-person-year rate ratio.
- Repro:
  ```r
.libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
suppressMessages({library(EDI); library(pscl)})
set.seed(2026); n = 160; fu = runif(n, .25, 1)
X = data.frame(log_fu = log(fu), prior = rpois(n, 1.5), age = runif(n, 4, 15))
des = DesignFixedBernoulli$new(n = n, response_type = "count", prob_T = 0.4, seed = 11)
des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects(); w = des$get_w()
y = ifelse(rbinom(n, 1, .3) == 1, 0, rnbinom(n, size = .9, mu = fu * exp(.3 - .5 * w + .35 * X$prior - .04 * X$age)))
des$add_all_subject_responses(y); d = data.frame(y, w, X)
f_off = ~ offset(log_fu) + prior + age
po = InferenceCountPoisson$new(des, model_formula = f_off)
cat("EDI Poisson:", po$compute_estimate(), "  formula kept:", deparse(po$get_model_formula()), "\n")
cat("glm WITH offset:   ", coef(glm(y ~ w + prior + age + offset(log_fu), poisson, d))["w"], "\n")
cat("glm WITHOUT offset:", coef(glm(y ~ w + prior + age, poisson, d))["w"], "\n")
nb = InferenceCountNegBin$new(des, model_formula = f_off)
cat("EDI NegBin:", nb$compute_estimate(), "  MASS with offset:", coef(MASS::glm.nb(y ~ w + prior + age + offset(log_fu), d))["w"],
    "  without:", coef(MASS::glm.nb(y ~ w + prior + age, d))["w"], "\n")
zi = InferenceCountZeroInflatedPoisson$new(des, model_formula = f_off, model_formula_zero = f_off)
cat("EDI ZIP:", zi$compute_estimate(), "  pscl with offset:", coef(zeroinfl(y ~ w + prior + age + offset(log_fu) | w + prior + age, d))["count_w"],
    "  without:", coef(zeroinfl(y ~ w + prior + age | w + prior + age, d))["count_w"], "\n")
  ```
- Workaround used, if any: in the main analysis I entered `log(follow-up)` as an ordinary covariate (its coefficient is estimated rather than fixed at 1). That matches `glm(y ~ w + log_fu + ...)` to 7 digits.

### F5: `InferenceCountKKGLMM`'s Wald CI and p-value use the jackknife SE, not the "model-based GLMM standard error" the help page promises. `get_summary()` labels that SE as the model's Std. Error with `use_rcpp = TRUE`, but shows the real model SE with `use_rcpp = FALSE`
- Kind: false docs
- Expected (and where the docs say so: help topic or vignette + section): `?InferenceCountKKGLMM`, Description, "Likelihood tier": "Wald (model-based standard error)". `compute_wald_confidence_interval()`: "\hatbeta_T \pm t\cdot \hat{se}(\hatbeta_T), using the model-based GLMM standard error". `compute_wald_two_sided_pval()`: "using the model-based GLMM standard error". The page says nothing about a design-conservative combination with the jackknife (unlike `?InferenceCountPoisson`, which documents its union/max rule).
- Observed: the point estimate matches `lme4::glmer(nAGQ = 25)` (0.6536454 vs 0.6536464), but the model SE is 0.132512. EDI's Wald CI is (0.3144976, 0.9927933), implied SE 0.1730378. That is exactly the SE of `compute_jackknife_wald_confidence_interval()` (0.1730378). `get_summary()` with `use_rcpp = TRUE` prints `Std. Error 0.1730378`. With `use_rcpp = FALSE` it prints `w ... Std. Error 0.1324980`, which is the model SE, yet that object's Wald CI is still (0.3145827, 0.9927678). On 4 seeds the reported "Wald" SE was 1.05 to 1.56 times the glmer SE. The LR/score/gradient CIs are consistent with the model SE (e.g. LR CI 0.3966 to 0.9167). So the Wald interval is much wider than the other test types for no documented reason.
- Repro:
  ```r
.libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
suppressMessages({library(EDI); library(lme4)})
set.seed(1); n = 100; x = rnorm(n)
des = DesignSeqOneByOneKK14$new(n = n, response_type = "count", verbose = FALSE)
for (i in 1:n) { wi = des$add_one_subject_to_experiment_and_assign(data.frame(x = x[i]))
  des$add_one_subject_response(i, rpois(1, exp(0.5 + 0.4 * wi + 0.5 * x[i] + rnorm(1, 0, 0.5)))) }
d = data.frame(y = des$get_y(), w = des$get_w(), x = x, cid = factor(des$get_matching_cluster_ids()))
g = InferenceCountKKGLMM$new(des); g$compute_estimate()
ci = g$compute_wald_confidence_interval()
cat("EDI wald CI:", ci, " implied SE:", diff(ci) / 2 / qnorm(.975), "\n")
jk = g$compute_jackknife_wald_confidence_interval()
cat("EDI jackknife CI:", jk, " implied SE:", diff(jk) / 2 / qnorm(.975), "\n")
m = glmer(y ~ w + x + (1 | cid), family = poisson, data = d, nAGQ = 25)
cat("glmer nAGQ=25: est", fixef(m)["w"], " model SE", sqrt(vcov(m)["w", "w"]), "\n")
s1 = g$get_summary()                                    # 'Std. Error' 0.173 (jackknife)
g2 = InferenceCountKKGLMM$new(des, use_rcpp = FALSE); g2$compute_estimate()
s2 = g2$get_summary()                                   # 'Std. Error' 0.1325 (model) ...
cat("use_rcpp=FALSE wald CI:", g2$compute_wald_confidence_interval(), "\n")  # ... but CI still uses 0.173
  ```
- Workaround used, if any: I used the LR test type (`set_testing_type("lik_ratio")`) for model-based inference and treated the Wald output as design-conservative.

### F6: `InferenceCountKKGLMM$get_supported_testing_types()` lists `"lik_ratio_bartlett_approx"`, and `set_testing_type()` accepts it, but `compute_asymp_confidence_interval()` / `compute_asymp_two_sided_pval()` then fail with "Unsupported testing_type"
- Kind: inconsistency
- Expected (and where the docs say so: help topic or vignette + section): `?InferenceAsymp`, `get_supported_testing_types()` / `set_testing_type()`: the supported list is what the generic `compute_asymp_*` methods dispatch on. A listed type should work with `compute_asymp_*`, or should not be listed.
- Observed: `get_supported_testing_types()` returns `"wald" "score" "lik_ratio" "gradient" "lik_ratio_bartlett_approx"`. `set_testing_type("lik_ratio_bartlett_approx")` is silent. Then:
  `Error in g$compute_asymp_confidence_interval() : Unsupported testing_type for InferenceCountKKGLMM: lik_ratio_bartlett_approx` (the same for `compute_asymp_two_sided_pval()`). The dedicated `compute_lik_ratio_bartlett_approx_confidence_interval()` works (0.3919, 0.9398).
- Repro:
  ```r
.libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
suppressMessages(library(EDI))
set.seed(1); n = 100; x = rnorm(n)
des = DesignSeqOneByOneKK14$new(n = n, response_type = "count", verbose = FALSE)
for (i in 1:n) { wi = des$add_one_subject_to_experiment_and_assign(data.frame(x = x[i]))
  des$add_one_subject_response(i, rpois(1, exp(0.5 + 0.4 * wi + 0.5 * x[i] + rnorm(1, 0, 0.5)))) }
g = InferenceCountKKGLMM$new(des)
print(g$get_supported_testing_types())
g$set_testing_type("lik_ratio_bartlett_approx")        # accepted
try(g$compute_asymp_confidence_interval())              # Unsupported testing_type
try(g$compute_asymp_two_sided_pval())
cat("the dedicated method compute_lik_ratio_bartlett_approx_confidence_interval() does work (about 2 min): 0.3919096 0.9398060\n")
  ```
- Workaround used, if any: I called the dedicated `compute_lik_ratio_bartlett_approx_*` method directly.

### F7: When every control subject has a zero count, Poisson, QuasiPoisson and RobustPoisson return a randomization p-value of exactly 1 for every `alternative`, with no warning. Once the separated fit exists, every randomization refit returns the observed estimate (22.79) unchanged
- Kind: silent NA
- Expected (and where the docs say so: help topic or vignette + section): `?InferenceRand`, `compute_rand_two_sided_pval()`, argument `alternative`: the two-sided p is "\min(1, \max(2/B, 2\min(P(T_0 >= t), P(T_0 <= t))))" over the reference statistics T_0 from redrawn assignments. The redrawn assignments give estimates between -1.77 and 1.85, against t = 22.79, so the p-value should be about 2/199 = 0.01. A manual randomization test gives 0.005. If the separated observed estimate is unusable, the result should be `NA` with a warning. (`?InferenceCountZeroInflatedPoisson` item (iii) says that class "never warm-starts a randomization ... refit from a full-data fit whose zero part is on the ridge". The plain Poisson family seems to lack the same guard.)
- Observed: on a fresh object, `approximate_randomization_distribution_beta_hat_T(r = 199)` gives sensible draws (min -1.774, max 1.849). After `compute_estimate()` (22.79156, no warning), the same call returns 199 draws that all equal 22.79156. `compute_rand_two_sided_pval()` computes the estimate first, so it always sees the stuck draws and returns `1` for `"two.sided"`, `"greater"` and `"less"`. QuasiPoisson and RobustPoisson also return 1. NegBin returns 0.01005 on the same data. So the strongest possible evidence of an effect is reported as none. RobustPoisson's asymptotic p for the same object is 0 (sandwich SE 0.1433, the same as `sandwich::vcovHC(glm, "HC0")`), so its two p-values are 0 and 1.
- Repro:
  ```r
.libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
suppressMessages(library(EDI))
set.seed(3); n = 30; w = rep(0:1, each = 15); X = data.frame(x = rnorm(n))
y = ifelse(w == 1, rpois(n, 2), 0L)                     # every control child has 0 visits
des = DesignFixedBernoulli$new(n = n, response_type = "count"); des$add_all_subjects_to_experiment(X)
des$overwrite_all_subject_assignments(w); des$add_all_subject_responses(y)
fresh = InferenceCountPoisson$new(des); fresh$set_seed(1)
b0 = fresh$approximate_randomization_distribution_beta_hat_T(r = 199, show_progress = FALSE)
cat("draws on a fresh object:   ", summary(b0), "\n")      # sensible: -1.77 .. 1.85
o = InferenceCountPoisson$new(des)
cat("estimate:", o$compute_estimate(), "\n")             # 22.79 (separated, like glm's 21.09)
o$set_seed(1); b = o$approximate_randomization_distribution_beta_hat_T(r = 199, show_progress = FALSE)
cat("draws after compute_estimate():", summary(b), "\n") # all 199 == 22.79156
for (alt in c("two.sided", "greater", "less")) { o$set_seed(1)
  cat(alt, "rand p:", o$compute_rand_two_sided_pval(r = 199, show_progress = FALSE, alternative = alt), "\n") }  # all 1
for (cl in c("InferenceCountQuasiPoisson", "InferenceCountRobustPoisson", "InferenceCountNegBin")) {
  q = get(cl)$new(des); q$set_seed(1); cat(cl, "rand p:", q$compute_rand_two_sided_pval(r = 199, show_progress = FALSE), "\n") }
d = data.frame(y, w, X); obs = coef(glm(y ~ w + x, poisson, d))["w"]      # manual randomization test
set.seed(9); nul = replicate(199, { dd = d; dd$w = rbinom(n, 1, .5); suppressWarnings(coef(glm(y ~ w + x, poisson, dd))["w"]) })
cat("manual rand p:", (1 + sum(abs(nul) >= abs(obs))) / 200, "\n")
  ```
- Workaround used, if any: NegBin's randomization test, or a manual permutation test.
