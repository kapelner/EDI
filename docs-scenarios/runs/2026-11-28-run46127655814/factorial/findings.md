# Findings: factorial (run 2026-11-28, EDI 1.0.5)

### F1: `InferenceIncidExactFisher` and `InferenceIncidExtendedRobins` refuse a `DesignFixedFactorial`, although the docs say this design works unmodified with every Inference class (both accept the equivalent `DesignFixediBCRD`)
- Kind: false docs
- Expected: `?DesignFixedFactorial` Description: "so `DesignFixedFactorial` inherits `assign_w_to_all_subjects()`, ... and works unmodified with every `Inference` class". Article *Cluster-Randomized and Factorial Experiments*, section "What `DesignFixedFactorial` supports today": "With a single two-level factor, `DesignFixedFactorial` is a balanced complete randomization ... It works with every inference class, like any other two-arm design." Since a balanced complete randomization is what iBCRD is, Fisher's exact test (which conditions on the margins) should be accepted.
- Observed: both constructors error on the factorial design, and accept iBCRD with the same data:
  ```
  InferenceIncidExactFisher on iBCRD:      ok
  InferenceIncidExactFisher on Factorial:  Fisher exact inference requires iBCRD, blocking, or matching designs.
  InferenceIncidExtendedRobins on iBCRD:      ok
  InferenceIncidExtendedRobins on Factorial:  InferenceIncidExtendedRobins requires a blocking design with equal block sizes and even allocation.
  ```
  The ExtendedRobins message also says "requires a blocking design", but it accepts iBCRD, which is not a blocking design. (`InferenceIncidExactZhang` and `InferenceIncidExactBinomial` also refuse the factorial design; they refuse iBCRD too, so they are design-specific, but they still contradict "every Inference class".) Together with known finding f1 (no randomization test for incidence), this leaves a binary outcome on `DesignFixedFactorial` with no exact or randomization p-value at all.
- Repro:
  ```r
.libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
suppressPackageStartupMessages(library(EDI))
set.seed(5); n <- 60; X <- data.frame(x = rnorm(n)); y <- rbinom(n, 1, 0.4)
mk <- function(d) { d$add_all_subjects_to_experiment(X); d$assign_w_to_all_subjects(); d$add_all_subject_responses(y); d }
dF <- mk(DesignFixedFactorial$new(n = n, response_type = "incidence", factors = list(subject_line = 2)))
dI <- mk(DesignFixediBCRD$new(n = n, response_type = "incidence"))
for (cls in c("InferenceIncidExactFisher", "InferenceIncidExtendedRobins")) {
  cat(cls, "on iBCRD:     ", tryCatch({get(cls)$new(dI); "ok"}, error = function(e) conditionMessage(e)), "\n")
  cat(cls, "on Factorial: ", tryCatch({get(cls)$new(dF); "ok"}, error = function(e) conditionMessage(e)), "\n")
}
  ```
- Workaround used, if any: declare the A step as `DesignFixedBlocking` with `strata_cols` = the other factor (the article's 2 x 2 recipe), where `InferenceIncidExactFisher` is accepted; or declare `DesignFixediBCRD` with `w_precomputed`.

### F2: On a blocking design, the `unit = "observation"` jackknife warning sends the user to `unit = "block"`, which returns NA with 2 blocks; the unit that works (`"observation_within_block"`, which is also the default) is never mentioned
- Kind: useless message
- Expected: `?InferenceJackknife` "Deletion units": `"observation_within_block"` is the automatic unit on a blocking design and can be "requested explicitly through `unit` ... on any blocking design". A warning about an unsupported unit should point to that unit (or to `"auto"`).
- Observed: on the 2 x 2 main-effect design (`DesignFixedBlocking`, `strata_cols = "B"`, 2 blocks of 100):
  ```
  unit = observation
  WARNING: InferenceIncidRiskDiff: jackknife returned NA (reason: jackknife_block_size_gt_one_not_supported). Deletion unit "observation" is not supported on this blocking design because its blocks hold more than one subject; use unit = "block" (leave-one-block-out). ...
  unit = block
  WARNING: ... The jackknife has only 2 deletion units (unit = "block"); at least 5 are needed. ... Use a randomization test (compute_rand_two_sided_pval()) or the model-based standard error. ...
  following the block warning's advice:
  [1] "Randomization tests are not supported for incidence. Use Zhang method."
  unit = observation_within_block
       2.5%     97.5%
  0.1165452 0.3531396
  ```
  When I followed the first warning, the second one sent me to a randomization test, and that errors for incidence (known f1/f3). `unit = "cluster"` gives the same "use unit = \"block\"" advice on a design that has no clusters.
- Repro:
  ```r
.libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
suppressPackageStartupMessages(library(EDI))
set.seed(7); n <- 200
A <- rep(0:1, each = 100); B <- rep(rep(0:1, each = 50), 2)
y <- rbinom(n, 1, 0.15 + 0.12 * A + 0.06 * A * B)
d <- DesignFixedBlocking$new(n = n, response_type = "incidence", strata_cols = "B")
d$add_all_subjects_to_experiment(data.frame(age = rnorm(n), B = factor(B)))
d$assign_w_to_all_subjects(w_precomputed = A); d$add_all_subject_responses(y)
inf <- InferenceIncidRiskDiff$new(d)
for (u in c("auto", "observation", "block", "observation_within_block"))
  { cat("unit =", u, "\n"); print(withCallingHandlers(inf$compute_jackknife_wald_confidence_interval(unit = u),
      warning = function(w) { cat("WARNING:", conditionMessage(w), "\n"); invokeRestart("muffleWarning") })) }
cat("following the block warning's advice:\n")
print(tryCatch(inf$compute_rand_two_sided_pval(r = 199, show_progress = FALSE), error = function(e) conditionMessage(e)))
  ```
- Workaround used, if any: `unit = "auto"` or `unit = "observation_within_block"`.

### F3: The estimand labels disagree across the API. `InferenceSuite` calls the covariate-adjusted logistic coefficient "log_odds_ratio_marginal" and the unadjusted Fisher odds ratio "conditional", while `get_estimand()` calls every class's default "conditional", including g-computation's marginal risk difference
- Kind: inconsistency
- Expected: `?InferenceIncidLogRegr` *Estimand*: under the default `estimand = "conditional"`, the estimate is the covariate-adjusted log-odds ratio; the marginal versions are `"marginal_mean_diff"`/`"marginal_ratio"`. `?InferenceIncidGCompRiskDiff` Description: the class "estimates the marginal (standardized) risk difference". `?Inference` `get_estimand()`: "the current target estimand". `?InferenceSuite` `run_all_inference()` reports an "estimand (where declared)" per row and groups the combined-evidence p-value by estimand. One target should get one label everywhere.
- Observed (2 x 2 main-effect design for factor A, adjusted for age and the other factor B):
  ```
  InferenceIncidLogRegr          estimate 1.0291  get_estimand() = conditional
  InferenceIncidProbitRegr       estimate 0.5961  get_estimand() = conditional
  InferenceIncidGCompRiskDiff    estimate 0.1800  get_estimand() = conditional
  InferenceIncidExactFisher      estimate 1.0184  get_estimand() = conditional
  LogRegr after set_estimand('marginal_mean_diff'): estimate 0.1800284  get_estimand() = marginal_mean_diff
  ...
                inference_class method  estimate                   estimand
  1   InferenceIncidExactFisher  exact 1.0184472 log_odds_ratio_conditional
  2       InferenceIncidLogRegr   wald 1.0290644    log_odds_ratio_marginal
  3 InferenceIncidGCompRiskDiff   wald 0.1800284            mean_difference
  4    InferenceIncidProbitRegr   wald 0.5961475     probit_effect_marginal
  ```
  - The suite labels LogRegr's default, covariate-adjusted coefficient (equal to `glm(y ~ A + age + factor(B), binomial)`, 1.029064) as **marginal**. The object itself says **conditional**, and its help means conditional.
  - The suite labels the covariate-unadjusted Fisher odds ratio as **conditional**. That may mean "conditional MLE", but it is a different sense of the word from LogRegr's "conditional" (conditional on covariates), so the suite's two log-odds groups are named in a way that reverses the class help.
  - Through `get_estimand()`, the g-computation marginal risk difference (0.1800284) is "conditional". The `set_estimand()` error on that class explains "conditional" as "the treatment effect the class reports (for a regression model, the model-scale coefficient)", but GComp reports a standardized marginal RD, not a model-scale coefficient. The same number from `InferenceIncidLogRegr` is labelled `"marginal_mean_diff"`.
  - The suite's combined-evidence printout then puts the adjusted logistic row and the Fisher row in different estimand groups ("logodds marginal" vs "logodds cond"), the reverse of what the class help says.
- Repro:
  ```r
.libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
suppressPackageStartupMessages(library(EDI))
set.seed(7); n <- 200
A <- rep(0:1, each = 100); B <- rep(rep(0:1, each = 50), 2); age <- rnorm(n, 45, 12)
y <- rbinom(n, 1, 0.15 + 0.12 * A + 0.06 * A * B)
d <- DesignFixedBlocking$new(n = n, response_type = "incidence", strata_cols = "B")
d$add_all_subjects_to_experiment(data.frame(age = age, B = factor(B)))
d$assign_w_to_all_subjects(w_precomputed = A); d$add_all_subject_responses(y)
cls <- c("InferenceIncidLogRegr", "InferenceIncidProbitRegr", "InferenceIncidGCompRiskDiff", "InferenceIncidExactFisher")
for (cl in cls) { o <- get(cl)$new(d); cat(sprintf("%-30s estimate %.4f  get_estimand() = %s\n", cl, o$compute_estimate(), o$get_estimand())) }
L <- InferenceIncidLogRegr$new(d); L$set_estimand("marginal_mean_diff")
cat("LogRegr after set_estimand('marginal_mean_diff'): estimate", L$compute_estimate(), " get_estimand() =", L$get_estimand(), "\n")
s <- InferenceSuite$new(d)
res <- s$run_all_inference(screen = TRUE, plots = FALSE, classes = cls, methods = c("wald", "exact"))
print(res$results_table[, c("inference_class", "method", "estimate", "estimand")])
# reference: covariate-adjusted logistic coefficient is a conditional log-OR
print(coef(glm(y ~ A + age + factor(B), binomial))["A"])
  ```
- Workaround used, if any: I took the target of each class from its own help page, not from `get_estimand()` or the suite's `estimand` column.

### F4: `get_summary()` on `InferenceIncidGCompRiskDiff`/`InferenceIncidGCompRiskRatio` prints an unlabelled table of logistic working-model coefficients, with a "Value" column, and leaves out the risk difference/ratio the class estimates
- Kind: inconsistency
- Expected: `?Inference` `get_summary()`: "Prints a coefficient summary table (Estimate / Std. Error / statistic / p-value) ... model-based classes show the full coefficient table when coefficient names and a covariance matrix are available, otherwise ... a one-row treatment summary." For g-computation, the reported treatment effect (`compute_estimate()` = 0.180 RD, or 2.20 RR) should be in the summary, and coefficient rows should be named.
- Observed:
  ```
  compute_estimate(): 0.1800284
              Value Std. Error    z value    Pr(>|z|)
  [1,] -1.963834855 0.74237289 -2.6453483 0.008160688
  [2,]  1.029064426 0.35277192  2.9170814 0.003533235
  [3,]  0.002303347 0.01382484  0.1666093 0.867677503
  [4,]  0.233898819 0.34308244  0.6817569 0.495392688
  rownames(get_summary()):NULL
  GCompRiskRatio compute_estimate(): 2.200255
  (identical unlabelled 4-row table)
  ```
  The rows are the logistic coefficients (intercept, A, age, B; compare `glm` in the repro). Nothing tells you which row is the treatment, and neither the RD nor the RR, nor their SEs, appear. On the same data, `InferenceIncidLogRegr$get_summary()` prints a single labelled `treatment` row, so the two classes behave differently in opposite directions.
- Repro:
  ```r
.libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
suppressPackageStartupMessages(library(EDI))
set.seed(7); n <- 200
A <- rep(0:1, each = 100); B <- rep(rep(0:1, each = 50), 2); age <- rnorm(n, 45, 12)
y <- rbinom(n, 1, 0.15 + 0.12 * A + 0.06 * A * B)
d <- DesignFixedBlocking$new(n = n, response_type = "incidence", strata_cols = "B")
d$add_all_subjects_to_experiment(data.frame(age = age, B = factor(B)))
d$assign_w_to_all_subjects(w_precomputed = A); d$add_all_subject_responses(y)
G <- InferenceIncidGCompRiskDiff$new(d)
cat("compute_estimate():", G$compute_estimate(), "\n")
cat("asymp CI:", G$compute_asymp_confidence_interval(), "\n")
sm <- G$get_summary()
cat("rownames(get_summary()):"); print(rownames(sm))
R <- InferenceIncidGCompRiskRatio$new(d); cat("GCompRiskRatio compute_estimate():", R$compute_estimate(), "\n"); R$get_summary()
L <- InferenceIncidLogRegr$new(d); L$get_summary()
print(coef(summary(glm(y ~ A + age + factor(B), binomial))))
  ```
- Workaround used, if any: report `compute_estimate()`, `compute_asymp_confidence_interval()` and `compute_asymp_two_sided_pval()` directly.

### F5: `InferenceIncidExactFisher` silently ignores the blocks of a `DesignFixedBlocking` built with `m =` and runs a pooled Fisher test, whereas the same blocks given through `strata_cols` give the stratified exact Mantel-Haenszel test (CMH uses the blocks either way)
- Kind: inconsistency
- Expected: `?DesignFixedBlocking` `m`: explicit block identifiers that bypass covariate-derived construction; `get_block_ids()` returns them. `?InferenceIncidExactFisher`: "When the design has *blocking structure* (`DesignFixedBlocking`, ...), a separate 2x2 table is built per block-defining covariate stratum ... `mantelhaen.test` (exact conditional test) is used instead". A `DesignFixedBlocking` with `m` has blocking structure, so the stratified test should run, or at least a warning should say the blocks are not used. This matters for the 2 x 2 recipe: declaring the other factor as `m =` is a natural way to say "A was randomized within levels of B".
- Observed (same data, same 2 blocks of 100):
  ```
  strata_cols Fisher logOR 0.5239  p 0.17286 | CMH 0.0900 p 0.12654
  m           Fisher logOR 0.3795  p 0.24494 | CMH 0.0900 p 0.12654
  block ids from m design: 100 100
  stratified exact MH logOR 0.5239 p 0.17286 ; pooled fisher.test logOR 0.3795 p 0.24494
  ```
  With `m`, the Fisher result equals the pooled `fisher.test`, with no warning. With `strata_cols`, it equals `mantelhaen.test(exact = TRUE)`.
- Repro:
  ```r
.libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
suppressPackageStartupMessages(library(EDI))
set.seed(11); n <- 200
blk <- rep(1:2, each = 100)                       # e.g. send-time factor as the block
A <- unlist(lapply(1:2, function(b) sample(rep(0:1, 50))))
y <- rbinom(n, 1, ifelse(blk == 1, 0.1, 0.6) + 0.15 * A)
X <- data.frame(age = rnorm(n))
# same blocks, declared two documented ways
d_cov <- DesignFixedBlocking$new(n = n, response_type = "incidence", strata_cols = "blk")
d_cov$add_all_subjects_to_experiment(data.frame(X, blk = factor(blk)))
d_m <- DesignFixedBlocking$new(n = n, response_type = "incidence", m = blk)
d_m$add_all_subjects_to_experiment(X)
for (d in list(d_cov, d_m)) { d$assign_w_to_all_subjects(w_precomputed = A); d$add_all_subject_responses(y) }
for (nm in c("strata_cols", "m")) {
  d <- if (nm == "m") d_m else d_cov
  f <- InferenceIncidExactFisher$new(d)
  cat(sprintf("%-11s Fisher logOR %.4f  p %.5f | ", nm, f$compute_estimate(), f$compute_exact_two_sided_pval_for_treatment_effect()))
  cm <- InferenceIncidCMH$new(d); cat(sprintf("CMH %.4f p %.5f\n", cm$compute_estimate(), cm$compute_asymp_two_sided_pval()))
}
cat("block ids from m design:", table(d_m$get_block_ids()), "\n")
mh <- mantelhaen.test(table(A, y, blk), exact = TRUE); ft <- fisher.test(table(A, y))
cat(sprintf("stratified exact MH logOR %.4f p %.5f ; pooled fisher.test logOR %.4f p %.5f\n", log(mh$estimate), mh$p.value, log(ft$estimate), ft$p.value))
  ```
- Workaround used, if any: put the blocking factor into `X` and name it in `strata_cols`.

### F6: `DesignFixedFactorial` (a balanced design) accepts a `w_precomputed` it could never produce (150 treated / 50 control) without a word, and its randomization test then uses a reference distribution of 100/100 allocations
- Kind: accepted bad input
- Expected: `?DesignFixedFactorial`: assignment counts are "balanced as evenly as possible across cells ... off by at most one subject"; `?Design` `assert_even_allocation()`: "`Design$initialize()` calls this for every class whose registry capability `supports_unequal_allocation` is `FALSE` (... factorial ...)". An observed assignment that has probability zero under the declared design should be refused, or at least warned about, because the randomization test that conditions on this design is then not a valid test. The article ("What this recipe does not cover") asks users to compare `draw_ws_according_to_design()` with the real cell counts, which shows the mismatch is known to matter. Nothing checks it, even in this extreme case.
- Observed: no error and no warning at assignment or at the test:
  ```
  treated in supplied w: 150
  treated in every redraw: 100
  [1] 0.003992016
  ```
  `DesignFixedBlocking` (`prob_T = 0.5`, 2 strata of 100) likewise accepts the same 150/50 `w` and runs its randomization test silently.
- Repro:
  ```r
.libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
suppressPackageStartupMessages(library(EDI))
set.seed(3); n <- 200
X <- data.frame(age = rnorm(n))
w_obs <- c(rep(1, 150), rep(0, 50))            # 150 treated / 50 control
y <- rnorm(n) + 0.3 * w_obs
d <- DesignFixedFactorial$new(n = n, response_type = "continuous", factors = list(subject_line = 2))
d$add_all_subjects_to_experiment(X)
withCallingHandlers(d$assign_w_to_all_subjects(w_precomputed = w_obs),
  warning = function(w) cat("WARNING:", conditionMessage(w), "\n"))
d$add_all_subject_responses(y)
cat("treated in supplied w:", sum(d$get_w()), "\n")
cat("treated in every redraw:", unique(colSums(d$draw_ws_according_to_design(100))), "\n")
inf <- InferenceAllSimpleAverageDiff$new(d); inf$set_seed(1)
withCallingHandlers(print(inf$compute_rand_two_sided_pval(r = 500, show_progress = FALSE)),
  warning = function(w) cat("WARNING:", conditionMessage(w), "\n"))
  ```
- Workaround used, if any: none needed for my analysis (my assignments were balanced). Check `sum(w)` against `draw_ws_according_to_design()` by hand.

### F7: `get_w_factorial()` returns row names like "1", "2", "1.1", "2.1" that look like subject indices but are not (subject 3 is row "1.1")
- Kind: inconsistency
- Expected: `?DesignFixedFactorial` `get_w_factorial()`: "A data frame with `n` rows ... giving each subject's level". Row i is subject i, so row names should be `1:n` (or absent), as in `get_w()` order. The article works around this with `data.frame(..., row.names = NULL)` without explaining why.
- Observed:
  ```
  [1] 0 1 0 1 1 0
      subject_line
  1              1
  2              2
  1.1            1
  2.1            2
  2.2            2
  1.2            1
  [1] "1"   "2"   "1.1" "2.1" "2.2" "1.2"
  ```
  The names are the `expand.grid` row of the cell, de-duplicated. Anyone who merges or indexes by row name (`wf["2", ]` is subject 2 only by accident; `wf["3", ]` is `NA`) gets the wrong subject.
- Repro:
  ```r
.libPaths(c("/home/runner/work/_temp/lib", .libPaths()))
suppressPackageStartupMessages(library(EDI))
d <- DesignFixedFactorial$new(n = 6, response_type = "continuous", factors = list(subject_line = 2), seed = 1)
d$add_all_subjects_to_experiment(data.frame(x = 1:6)); d$assign_w_to_all_subjects()
print(d$get_w()); wf <- d$get_w_factorial(); print(wf); print(rownames(wf))
  ```
- Workaround used, if any: `rownames(wf) <- NULL`, or use positional indexing only.
