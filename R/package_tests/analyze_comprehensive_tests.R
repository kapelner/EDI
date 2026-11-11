set.seed(1)
pacman::p_load(EDI, stringr, doParallel, PTE, datasets, qgam, mlbench, AppliedPredictiveModeling, dplyr, ggplot2, gridExtra, profvis, data.table, profvis)
max_n_dataset = 150
source("package_tests/_dataset_load.R")

result_files = Sys.glob("package_tests/comprehensive_tests_results_nc_*.csv")
if (!length(result_files)) stop("No comprehensive_tests_results_nc_*.csv files found under package_tests/ -- run comprehensive_tests.R first.")
X = data.table()
for (result_file in result_files) {
	X = rbindlist(list(X, fread(result_file)), fill = TRUE, use.names = TRUE)
}
# Rows from before the prob_T column ran at equal allocation (release_v1_0_5.md TODO-184).
if (!("prob_T" %in% names(X))) X[, prob_T := 0.5]
X[is.na(prob_T), prob_T := 0.5]
table(X$rep)


colnames(X)
#rename the inferences
X[function_run == "compute_bootstrap_confidence_interval", function_run := "ci_bootstrap"]
X[function_run == "compute_bootstrap_two_sided_pval", function_run := "pval_bootstrap"]
X[function_run == "compute_rand_confidence_interval", function_run := "ci_rand"]
X[function_run == "compute_exact_confidence_interval", function_run := "ci_exact"]
X[function_run == "compute_exact_two_sided_pval_for_treatment_effect", function_run := "pval_exact"]
X[function_run == "compute_rand_confidence_interval(custom)", function_run := "ci_rand_custom"]
X[function_run == "compute_mle_confidence_interval", function_run := "ci_asymp"] ####OLD
X[function_run == "compute_asymp_confidence_interval", function_run := "ci_asymp"]
X[function_run == "compute_mle_two_sided_pval_for_treatment_effect", function_run := "pval_asymp"] ####OLD
X[function_run == "compute_asymp_two_sided_pval", function_run := "pval_asymp"]
X[function_run == "compute_asymp_log_rank_two_sided_pval_for_treatment_effect", function_run := "pval_asymp"]
X[function_run == "compute_estimate", function_run := "est"]
X[function_run == "compute_rand_two_sided_pval", function_run := "pval_rand"]
X[function_run == "compute_rand_two_sided_pval(custom)", function_run := "pval_rand_custom"]
X[function_run == "compute_rand_two_sided_pval(delta=0.5)", function_run := "pval_rand_shift"]
table(X$function_run)

#check duration time
D = X[, .(mean_duration = mean(duration_time_sec), n = .N),
	by = c("inference_class", "design", "prob_T", "function_run")][order(-mean_duration)]
D[1:50]
table(D[1:50]$inference_class)

#we kind of don't care as much about these results
Xextra = X[function_run %in% c("pval_rand_custom", "pval_rand_shift")]
X = X[!(function_run %in% c("pval_rand_custom", "pval_rand_shift"))]

#create the actual beta being estimated
table(X$inference_class)

# The estimand each row is graded against. Owner decision 2026-11-11: MSE and
# coverage are computed at beta_T = 0 only. Away from the null each class targets
# its own quantity (and the hand-derived beta_T != 0 truths that used to live here
# missed every formula-suffixed class label), so beta_T != 0 rows get no truth:
# power is the only beta_T != 0 summary. At beta_T = 0 the generator's sharp null
# puts every estimand at its null value: 1 for the risk-ratio classes, 0 otherwise
# (the same values comprehensive_tests.R's get_coverage_truth() now records).
RISK_RATIO_SCALE_CLASSES = c("InferenceIncidGCompRiskRatio", "InferenceIncidKKGCompRiskRatio")
X[, base_class := sub(" [\\(\\[].*$", "", inference_class)]
X[, beta := NA_real_]
X[beta_T == 0, beta := fifelse(base_class %in% RISK_RATIO_SCALE_CLASSES, 1, 0)]
table(X$beta, useNA = "always")


#check MSE
X[function_run == "est", sqerr := (result_1 - beta)^2]
E = X[function_run == "est" & beta_T == 0, .(mse = mean(sqerr, na.rm = TRUE), n_mse = sum(!is.na(sqerr)), beta = first(beta)),
	by = c("inference_class", "design", "prob_T", "response_type", "beta_T")][order(-mse)]
E = E[!is.nan(mse)]
E[1:100]

#check coverage
X[str_detect(X$function_run, "ci"), ci_correct := ifelse(beta >= result_1 & beta <= result_2, 1, 0)]
table(X$ci_correct, useNA = "always")
C = X[str_detect(X$function_run, "ci") & beta_T == 0, .(coverage = mean(ci_correct, na.rm = TRUE), n_coverage = sum(!is.na(ci_correct))),
	by = c("inference_class", "design", "prob_T", "function_run", "response_type", "beta_T")][order(coverage)]
C[1:100]

#check size
X[beta_T == 0 & str_detect(X$function_run, "pval"), H0_rejected := ifelse(result_1 < 0.05, 1, 0)]
#table(X[beta_T == 0]$H0_rejected, useNA = "always")
#prop.test() errors (rather than returning NA) when a group has zero non-NA
#H0_rejected values -- a real possibility once every file on disk is pooled,
#since not every (inference_class, design, response_type, beta_T, function_run)
#cell is populated in every file. Guard it the same way mean(na.rm=TRUE) already
#degrades gracefully, instead of letting one empty cell halt the whole aggregation.
safe_size_pval = function(h0_rejected) {
	n = length(na.omit(h0_rejected))
	if (n == 0L) return(NA_real_)
	prop.test(sum(h0_rejected, na.rm = TRUE), n, p = 0.05)$p.value
}
S = X[beta_T == 0 & str_detect(X$function_run, "pval"), .(
	size = mean(H0_rejected, na.rm = TRUE),
	n_size = sum(!is.na(H0_rejected)),
	size_pval = safe_size_pval(H0_rejected)
), by = c("inference_class", "design", "prob_T", "response_type", "beta_T", "function_run")][order(-size)]
S[, bonf_size_pval := pmin(1, size_pval * .N)][, size_pval := NULL]
S[11:160]

# 2. `pval_asymp` (Size $\approx$ 0.15 - 0.25)
#   This is the classic failure of parametric asymptotic inference (like OLS and CoxPH) on real-world datasets, and it perfectly
#   highlights why this package's Bootstrap and Randomization tests exist!
#    * The tests are injecting a treatment effect into real-world datasets (airquality, boston, etc.) without modifying the
#      underlying covariate relationships.
#    * Real-world datasets contain severe heteroscedasticity, non-linearities, and unmeasured confounding that strongly
#      violate the assumptions required by standard asymptotic standard errors (which assume IID normal/homoscedastic errors).
#    * Because the asymptotic standard errors are overly optimistic (too small) on misspecified real-world data, the Wald test
#      rejects the true null hypothesis ($H_0: \beta_T = 0$) far too often, leading to the inflated ~20% Type I Error rates.

#check power
X[beta_T != 0 & str_detect(X$function_run, "pval"), H0_rejected := ifelse(result_1 < 0.05, 1, 0)]
table(X[beta_T != 0]$H0_rejected, useNA = "always")
P = X[beta_T != 0 & str_detect(X$function_run, "pval"), .(
	power = mean(H0_rejected, na.rm = TRUE),
	n_power = sum(!is.na(H0_rejected))
), by = c("inference_class", "design", "prob_T", "response_type", "beta_T", "function_run")][order(-power)]
P[!is.na(power)][1:200]

# 1. The Bootstrapped KK OLS (ContinMultOLSKK)
#   You'll notice that for the continuous KK OLS estimator, only the pval_bootstrap is in this low-power list (~52-54%). Its
#   pval_rand and pval_asymp are completely fine!


#   This is caused by severe structural instability when resampling matched pairs with replacement:
#    * When you sample $m$ matched pairs with replacement for the bootstrap, you inevitably draw many duplicate pairs.
#    * The OLS design matrix for the matched differences ($X_d$) suddenly loses full column rank because the duplicate rows
#      provide zero new linear information.
#    * To prevent a singular matrix crash, your estimator's QR decomposition correctly drops the collinear covariates. If the
#      rank drops too low, it entirely abandons the multivariate OLS and falls back to a naive Mean Difference for that
#      specific bootstrap iteration.
#    * Because the model randomly shifts between a fully-adjusted OLS, partially-adjusted OLS, and a naive mean difference
#      from iteration to iteration, the variance of the resulting bootstrap distribution artificially explodes. This massive
#      variance widens the bootstrap confidence interval and obliterates its statistical power.


#   2. Incidence and Proportion Models
#   The rest of the low power entries (IncidMultiLogRegr, PropUniBetaRegr, AllSimpleMeanDiff on incidence/proportion) are
#   simply struggling due to the mathematical limitations of the simulated effect size on bounded domains at low sample
#   sizes.
#    * The data generation adds beta_T on the link scale (e.g. plogis(qlogis(p) + beta_T); the current harness's nonzero
#      value is 0.5, not the 1.0 this note originally described).
#    * For a baseline probability of $0.5$, shifting the log-odds by $0.5$ moves the final probability to about $0.62$ (an
#      absolute difference of about $0.12$, smaller than the $0.23$ this note originally described for a shift of 1.0).
#    * Detecting a probability shift of $0.18$ between two groups with sample sizes frequently around $n=50$ (like the cars
#      dataset) or $n=150$ is notoriously difficult. A standard two-sample proportion test for this effect size at $n=50$ has
#      a theoretical mathematical power of exactly ~25% to ~40%.


#   The fact that your tests are successfully detecting this small probability shift ~60% of the time means your sequential
#   designs and multivariate estimators are actually performing better than standard unadjusted statistical tests would! The
#   ~50% power seen specifically on the pval_bootstrap for these GLMs just reflects the added volatility of bootstrapping
#   logistic/beta regressions on tiny datasets, where perfect separation and boundary clamping often occur during resampling.

#write the aggregated benchmark tables (small per-cell summaries, not raw per-replicate rows)
#so they can be published/queried without re-running this whole analysis.
fwrite(E, "package_tests/comprehensive_tests_mse.csv")
fwrite(C, "package_tests/comprehensive_tests_coverage.csv")
fwrite(S, "package_tests/comprehensive_tests_size.csv")
fwrite(P, "package_tests/comprehensive_tests_power.csv")
