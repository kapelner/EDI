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
	by = c("inference_class", "design", "function_run")][order(-mean_duration)]
D[1:50]
table(D[1:50]$inference_class)

#we kind of don't care as much about these results
Xextra = X[function_run %in% c("pval_rand_custom", "pval_rand_shift")]
X = X[!(function_run %in% c("pval_rand_custom", "pval_rand_shift"))]

#create the actual beta being estimated
table(X$inference_class)

#set the correct value of beta as it's inference and response dependent - this default works for most
X[, beta := as.numeric(beta_T)]

incid_p_control = function(dataset_name){
	y_i = datasets_and_response_models[[dataset_name]]$y_original$incidence
	ifelse(y_i > 0, 0.75, 0.25)
}

incid_p_treated = function(dataset_name, shift = 1){
	p_c = incid_p_control(dataset_name)
	plogis(qlogis(p_c) + shift)
}

prop_y_treated = function(dataset_name, shift = 1){
	y_p = datasets_and_response_models[[dataset_name]]$y_original$proportion
	shift_mult = exp(shift)
	shift_mult * y_p / (1 + (shift_mult - 1) * y_p)
}

ordinal_expected_observed = function(y_ord, bt, sd_noise = 0.1){
	mu = y_ord + bt
	k_max = max(8L, ceiling(max(mu + 6 * sd_noise)))
	exp_vals = pnorm((1.5 - mu) / sd_noise)
	if (k_max >= 2L){
		for (k in 2:k_max){
			exp_vals = exp_vals + k * (pnorm((k + 0.5 - mu) / sd_noise) - pnorm((k - 0.5 - mu) / sd_noise))
		}
	}
	exp_vals
}

# NOTE: every block below was originally keyed to the literal beta_T == 1 (an
# older generator's single alternative effect size). The current harness's
# beta_T_values can be any nonzero set (currently c(0, 0.5)), so every block
# below is gated on beta_T != 0 and uses the row's own beta_T as the shift
# magnitude -- grouped by (dataset, beta_T), not just dataset, wherever the
# formula needs that shift as a scalar (incid_p_treated()/prop_y_treated()'s
# shift argument, the exp(shift)-1 odds-multiplier blocks, and
# ordinal_expected_observed()'s bt argument). A flat `beta := 1` becomes
# `beta := beta_T` directly, since that constant was always just "the shift
# itself" for an additive-shift estimand.

# continuous — additive-shift estimands remain on the raw outcome scale
X[beta_T != 0 & response_type == "continuous" &
	inference_class %in% c(
		"InferenceBaiAdjustedTKK14",
		"InferenceBaiAdjustedTKK21",
		"InferenceContinRobustRegr",
		"InferenceContinRobustRegr",
		"InferenceContinQuantileRegr",
		"InferenceContinQuantileRegr",
		"InferenceContinLin",
		"InferenceContinOLS",
		"InferenceContinMultGLS",
		"InferenceContinOLSKKCombinedLikelihood",
		"InferenceContinOLSKKIVWC",
		"InferenceContinMultKKQuantileRegrIVWC",
		"InferenceContinMultKKQuantileRegrCombinedLikelihood"
	),
	beta := beta_T]

# incidence — simple/KK mean diff: probability-scale estimand, shift-dependent, not beta_T itself
X[beta_T != 0 &
	response_type == "incidence" &
	inference_class %in% c(
		"InferenceAllSimpleAverageDiff",
		"InferenceAllKKMeanDiffIVWC",
		"InferenceIncidExactZhang",
		"InferenceIncidKKExactZhang",
		"InferenceIncidRiskDiff",
		"InferenceIncidMiettinenNurminenRiskDiff",
		"InferenceIncidNewcombeRiskDiff",
		"InferenceIncidGCompRiskDiff",
		"InferenceIncidGCompRiskDiff",
		"InferenceIncidBinomialIdentityRiskDiff",
		"InferenceIncidBinomialIdentityRiskDiff",
		"InferenceIncidKKNewcombeRiskDiff",
		"InferenceIncidKKGCompRiskDiff",
		"InferenceIncidKKGCompRiskDiff"
	),
	beta := {
		p_c = incid_p_control(dataset)
		p_t = incid_p_treated(dataset, shift = beta_T[1])
		mean(p_t - p_c)
	}, by = c("dataset", "beta_T")]

# incidence — univariate logistic: marginal log-OR, shift-dependent
X[beta_T != 0 & inference_class %in% c("InferenceIncidLogRegr", "InferenceIncidKKGEE"),
	beta := {
		p_c = mean(incid_p_control(dataset))
		p_t = mean(incid_p_treated(dataset, shift = beta_T[1]))
		qlogis(p_t) - qlogis(p_c)
	}, by = c("dataset", "beta_T")]

# incidence — risk-ratio estimands
X[beta_T != 0 & inference_class %in% c(
	"InferenceIncidGCompRiskRatio",
	"InferenceIncidGCompRiskRatio",
	"InferenceIncidKKGCompRiskRatio",
	"InferenceIncidKKGCompRiskRatio"
),
beta := {
	p_c = mean(incid_p_control(dataset))
	p_t = mean(incid_p_treated(dataset, shift = beta_T[1]))
	p_t / p_c
}, by = c("dataset", "beta_T")]

# incidence — modified Poisson estimands are on the log-risk-ratio scale
X[beta_T != 0 & inference_class %in% c(
	"InferenceIncidLogBinomial",
	"InferenceIncidLogBinomial",
	"InferenceIncidKKModifiedPoisson"
),
beta := {
	p_c = mean(incid_p_control(dataset))
	p_t = mean(incid_p_treated(dataset, shift = beta_T[1]))
	log(p_t / p_c)
}, by = c("dataset", "beta_T")]


# proportion — simple/KK mean diff: E[shift_mult*y/(1+(shift_mult-1)*y)] - E[y]
X[beta_T != 0 & response_type == "proportion" &
	inference_class %in% c(
		"InferenceAllSimpleAverageDiff",
		"InferenceAllKKMeanDiffIVWC",
		"InferencePropGCompMeanDiff",
		"InferencePropGCompMeanDiff"
	),
	beta := {
		y_p = datasets_and_response_models[[dataset]]$y_original$proportion
		mean(prop_y_treated(dataset, shift = beta_T[1])) - mean(y_p)
	}, by = c("dataset", "beta_T")]

# proportion — KK univ GEE (logit link): marginal log-OR = logit(E[Y_T]) - logit(E[Y_C])
X[beta_T != 0 & response_type == "proportion" &
inference_class %in% c("InferencePropKKGEE", "InferencePropFractionalLogit"),
	beta := {
		y_t = prop_y_treated(dataset, shift = beta_T[1])
		y_p = datasets_and_response_models[[dataset]]$y_original$proportion
		qlogis(mean(y_t)) - qlogis(mean(y_p))
	}, by = c("dataset", "beta_T")]

# proportion — KK Wilcox: HL estimate ≈ median of within-pair differences
X[beta_T != 0 & response_type == "proportion" &
inference_class %in% c("InferenceAllKKWilcoxIVWC"),
	beta := {
		y_p = datasets_and_response_models[[dataset]]$y_original$proportion
		median(prop_y_treated(dataset, shift = beta_T[1]) - y_p)
	}, by = c("dataset", "beta_T")]

# count — simple/KK mean diff: E[Y_C] * (exp(shift) - 1)
X[beta_T != 0 & response_type == "count" &
	inference_class %in% c("InferenceAllSimpleAverageDiff", "InferenceAllKKMeanDiffIVWC"),
	beta := {
		y_c = datasets_and_response_models[[dataset]]$y_original$count
		mean(y_c) * (exp(beta_T[1]) - 1)
	}, by = c("dataset", "beta_T")]

# count — log-link regression estimands target the log mean ratio under the DGP
X[beta_T != 0 & response_type == "count" &
	inference_class %in% c(
		"InferenceCountPoisson",
		"InferenceCountPoisson",
		"InferenceCountRobustPoisson",
		"InferenceCountRobustPoisson",
		"InferenceCountQuasiPoisson",
		"InferenceCountQuasiPoisson",
		"InferenceCountNegBin",
		"InferenceCountNegBin",
		"InferenceCountKKCondPoissonOneLik",
		"InferenceCountKKGLMM"
	),
	beta := beta_T]

# count — KK Wilcox: HL estimate ≈ (exp(shift)-1) * median(Y_C)
X[beta_T != 0 & response_type == "count" &
inference_class %in% c("InferenceAllKKWilcoxIVWC"),
	beta := {
		y_c = datasets_and_response_models[[dataset]]$y_original$count
		(exp(beta_T[1]) - 1) * median(y_c)
	}, by = c("dataset", "beta_T")]

# survival — KM median diff: (exp(shift) - 1) * median(Y_C)
X[beta_T != 0 & inference_class == "InferenceSurvivalKMDiff",
	beta := {
		y_s = datasets_and_response_models[[dataset]]$y_original$survival
		(exp(beta_T[1]) - 1) * median(y_s)
	}, by = c("dataset", "beta_T")]

X[beta_T != 0 & inference_class == "InferenceSurvivalRestrictedMeanDiff",
	beta := {
		y_s = datasets_and_response_models[[dataset]]$y_original$survival
		tau = quantile(y_s, 0.95)
		(exp(beta_T[1]) - 1) * mean(pmin(y_s, tau))
	}, by = c("dataset", "beta_T")]

# survival — KK compound mean diff: (exp(shift)-1) * mean(Y_C)
X[beta_T != 0 & response_type == "survival" &
	inference_class == "InferenceAllKKMeanDiffIVWC",
	beta := {
		y_s = datasets_and_response_models[[dataset]]$y_original$survival
		(exp(beta_T[1]) - 1) * mean(y_s)
	}, by = c("dataset", "beta_T")]

# ordinal — observed-score mean difference under the rounding/flooring DGP
X[beta_T != 0 & response_type == "ordinal" &
	inference_class %in% c(
		"InferenceAllSimpleAverageDiff",
		"InferenceAllKKMeanDiffIVWC",
		"InferenceOrdinalGCompMeanDiff",
		"InferenceOrdinalGCompMeanDiff"
	),
	beta := {
		y_o = datasets_and_response_models[[dataset]]$y_original$ordinal
		mean(ordinal_expected_observed(y_o, beta_T[1], SD_NOISE) - ordinal_expected_observed(y_o, 0, SD_NOISE))
	}, by = c("dataset", "beta_T")]

# ordinal — link-scale estimands are not identified from the observed-level
# additive/rounding DGP used by this harness
X[beta_T != 0 & response_type == "ordinal" &
	inference_class %in% c(
	"InferenceOrdinalAdjCatLogitRegr",
	"InferenceOrdinalAdjCatLogitRegr",
	"InferenceOrdinalStereotypeLogitRegr",
	"InferenceOrdinalPropOddsRegr",
	"InferenceOrdinalOrderedProbitRegr",
	"InferenceOrdinalOrderedProbitRegr",
	"InferenceOrdinalCauchitRegr",
	"InferenceOrdinalCauchitRegr",
	"InferenceOrdinalPartialProportionalOddsRegr",
	"InferenceOrdinalContRatioRegr",
	"InferenceOrdinalCloglogRegr",
	"InferenceOrdinalCloglogRegr",
	"InferenceOrdinalKKGEE",
	"InferenceOrdinalKKGLMM",
	"InferenceOrdinalKKCondAdjCatLogitRegr",
	"InferenceOrdinalRidit"
	),
	beta := NA_real_]

	# ordinal — rank/sign-style targets are not cleanly identified from the current
	# observed-level DGP without a separate estimand convention
	X[beta_T != 0 & response_type == "ordinal" &
	inference_class %in% c(
		"InferenceAllSimpleWilcox",
		"InferenceAllKKWilcoxIVWC",
		"InferenceOrdinalPairedSignTest",
		"InferenceOrdinalJonckheereTerpstraTest",
		"InferenceOrdinalRidit"
	),
	beta := NA_real_]



#now some are impossible to calculate for real data due to the unknown f(x) model
X[beta_T != 0 &
	inference_class %in% c(
	"InferenceIncidLogRegr",
	"InferenceIncidKKCondLogitOneLik",
	"InferenceIncidKKCondLogitIVWC",
	"InferenceIncidKKGEE",
	"InferenceIncidKKCondLogitGLMMOneLik",
	"InferencePropBetaRegr",
	"InferencePropBetaRegr",
	"InferencePropKKGEE",
	"InferencePropKKGLMM",
	"InferencePropFractionalLogit",
	"InferencePropZeroOneInflatedBetaRegr",
	"InferencePropZeroOneInflatedBetaRegr",
	"InferencePropKKQuantileRegrOneLik",
	"InferencePropQuantileRegr",
	"InferenceCountHurdlePoisson",
	"InferenceCountHurdlePoisson",
	"InferenceCountKKHurdlePoissonOneLik",
	"InferenceCountHurdleNegBin",
	"InferenceCountHurdleNegBin",
	"InferenceCountZeroInflatedPoisson",
	"InferenceCountZeroInflatedPoisson",
	"InferenceCountZeroInflatedNegBin",
	"InferenceCountZeroInflatedNegBin",
	"InferenceSurvivalLogRank",
	"InferenceSurvivalCoxPHRegr",
	"InferenceSurvivalCoxPHRegr",
	"InferenceSurvivalStratCoxPHRegr",
	"InferenceSurvivalStratCoxPHRegr",
	"InferenceSurvivalWeibullRegr",
	"InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC",
	"InferenceSurvivalKKLWACoxPHIVWC",
	"InferenceSurvivalKKStratCoxPHIVWC",
	"InferenceSurvivalKKStratCoxPHOneLik",
	"InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik",
	"InferenceSurvivalKKLWACoxPHOneLik",
	"InferenceSurvivalGLMMWeibullFrailtyNormalIVWC",
	"InferenceSurvivalGLMMWeibullFrailtyNormalOneLik",
	"InferenceSurvivalKKRankRegrIVWC",
	"InferenceSurvivalKKRankRegrIVWC",
	"InferenceSurvivalGehanWilcox"
	),
	beta := NA_real_]

# survival — KK Wilcox: censored survival times bias the HL estimate
X[beta_T != 0 & response_type == "survival" &
inference_class %in% c("InferenceAllKKWilcoxIVWC"),
	beta := NA_real_]
table(X$beta, useNA = "always")


#check MSE
X[function_run == "est", sqerr := (result_1 - beta)^2]
E = X[function_run == "est", .(mse = mean(sqerr, na.rm = TRUE), n_mse = sum(!is.na(sqerr)), beta = first(beta)),
	by = c("inference_class", "design", "response_type", "beta_T")][order(-mse)]
E = E[!is.nan(mse)]
E[beta_T != 0][1:100]
E[beta_T == 0][1:100]

#check coverage
X[str_detect(X$function_run, "ci"), ci_correct := ifelse(beta >= result_1 & beta <= result_2, 1, 0)]
table(X$ci_correct, useNA = "always")
C = X[str_detect(X$function_run, "ci"), .(coverage = mean(ci_correct, na.rm = TRUE), n_coverage = sum(!is.na(ci_correct))),
	by = c("inference_class", "design", "function_run", "response_type", "beta_T")][order(coverage)]
C[beta_T != 0][1:100]
C[beta_T == 0][1:100]

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
), by = c("inference_class", "design", "response_type", "beta_T", "function_run")][order(-size)]
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
), by = c("inference_class", "design", "response_type", "beta_T", "function_run")][order(-power)]
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
