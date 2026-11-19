library(testthat)
library(EDI)

# v1.1.0-TODO-218: InferenceCountPoisson's design-conservative rule (max of the model p-value and a
# design-based jackknife p-value; union of the CIs) lost its design-based half on stratified designs with
# few strata. The automatic deletion unit there is the block (= stratum); with fewer than
# EDI_JACKKNIFE_MIN_DELETION_UNITS strata that jackknife is NA, so the raw Poisson test was reported and was
# oversized under overdispersion (calibration: size 0.08-0.11 with ~1 on FixedBlocking, SPBR and
# RandomBlockSize stratified on two binary covariates). The class now falls back to the stratified delete-1
# jackknife. With ~1 the leave-one-out Poisson estimate is the closed-form log ratio of arm means, so the
# fallback is checked exactly against a hand computation.

strat_fixture <- function(design = c("blocking", "spbr"), n = 240L, seed = 3L) {
	design <- match.arg(design)
	set.seed(seed)
	X <- data.frame(x1 = rnorm(n), s1 = factor(rbinom(n, 1L, 0.5), levels = 0:1), s2 = factor(rbinom(n, 1L, 0.5), levels = 0:1))
	mu <- exp(0.5 + 0.8 * X$x1 + 0.3 * (as.integer(X$s1) - 1L))
	y_all <- rnbinom(n, size = 1.5, mu = mu)               # overdispersed: Poisson SE is too small
	if (design == "blocking") {
		des <- DesignFixedBlocking$new(n = n, response_type = "count", strata_cols = c("s1", "s2"), equal_block_sizes = FALSE, verbose = FALSE)
		des$add_all_subjects_to_experiment(X)
		des$assign_w_to_all_subjects()
		des$add_all_subject_responses(y_all)
	} else {
		des <- DesignSeqOneByOneSPBR$new(n = n, response_type = "count", strata_cols = c("s1", "s2"), verbose = FALSE)
		for (t in seq_len(n)) {
			des$add_one_subject_to_experiment_and_assign(X[t, , drop = FALSE])
			des$add_one_subject_response(t, y_all[t])
		}
	}
	list(des = des, y = as.numeric(des$get_y()), w = des$get_w(), strata = as.integer(interaction(X$s1, X$s2)))
}

hand_stratified_jackknife <- function(y, w, strata) {
	S1 <- sum(y[w == 1]); S0 <- sum(y[w == 0]); n1 <- sum(w); n0 <- length(w) - n1
	est <- log(S1 / n1) - log(S0 / n0)
	loo <- ifelse(w == 1, log((S1 - y) / (n1 - 1)) - log(S0 / n0), log(S1 / n1) - log((S0 - y) / (n0 - 1)))
	v <- sum(vapply(unique(strata), function(h) { th <- loo[strata == h]; (length(th) - 1) / length(th) * sum((th - mean(th))^2) }, numeric(1)))
	list(estimate = est, std_error = sqrt(v), model_se = sqrt(1 / S1 + 1 / S0))
}

for (design in c("blocking", "spbr")) {
	test_that(paste0("~1 Poisson on a 4-stratum ", design, " design reports the stratified-jackknife-widened Wald test"), {
		f <- strat_fixture(design)
		expect_equal(length(unique(f$des$get_block_ids())), 4L)
		inf <- InferenceCountPoisson$new(f$des, model_formula = ~1, verbose = FALSE)
		inf$num_cores <- 1L
		inf$set_testing_type("wald")
		p <- inf$.__enclos_env__$private
		hand <- hand_stratified_jackknife(f$y, f$w, f$strata)
		expect_equal(as.numeric(inf$compute_estimate()), hand$estimate, tolerance = 1e-8)

		# The leave-one-block-out jackknife has only 4 units, so it is NA ...
		expect_true(is.na(suppressWarnings(inf$compute_jackknife_wald_two_sided_pval())))
		# ... and the fallback is the stratified delete-1 jackknife.
		sj <- p$design_stratified_jackknife()
		expect_false(is.null(sj))
		expect_equal(sj$estimate, hand$estimate, tolerance = 1e-8)
		expect_equal(sj$std_error, hand$std_error, tolerance = 1e-6)
		expect_gt(sj$std_error, hand$model_se)                # overdispersion: design SE > Poisson SE

		p_model <- 2 * pnorm(-abs(hand$estimate / hand$model_se))
		p_sj <- 2 * pnorm(-abs(hand$estimate / hand$std_error))
		expect_equal(inf$compute_asymp_two_sided_pval(), max(p_model, p_sj), tolerance = 1e-6)
		ci <- unname(inf$compute_asymp_confidence_interval(0.05))
		z <- qnorm(0.975)
		expect_equal(ci, hand$estimate + c(-1, 1) * z * max(hand$model_se, hand$std_error), tolerance = 1e-6)
	})
}

test_that("the stratified fallback stays off where the block jackknife works, on unstratified designs and for other estimands", {
	# Unstratified design: the observation-level jackknife is used, no fallback.
	set.seed(5)
	n <- 120L
	des <- DesignFixediBCRD$new(n = n, response_type = "count", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rpois(n, 2))
	inf <- InferenceCountPoisson$new(des, model_formula = ~1, verbose = FALSE)
	inf$num_cores <- 1L
	expect_null(inf$.__enclos_env__$private$design_stratified_jackknife())

	# Many blocks (8 strata): leave-one-block-out has enough units, no fallback.
	set.seed(6)
	n <- 200L
	X <- data.frame(x1 = rnorm(n), s1 = factor(rbinom(n, 1L, 0.5), levels = 0:1))
	des <- DesignFixedBlocking$new(n = n, response_type = "count", strata_cols = c("x1", "s1"),
		preferred_num_bins_for_continuous_covariate = 4, equal_block_sizes = FALSE, verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rpois(n, exp(0.5 + 0.3 * X$x1)))
	expect_equal(length(unique(des$get_block_ids())), 8L)
	inf <- InferenceCountPoisson$new(des, model_formula = ~1, verbose = FALSE)
	inf$num_cores <- 1L
	expect_null(inf$.__enclos_env__$private$design_stratified_jackknife())
	expect_true(is.finite(suppressWarnings(inf$compute_jackknife_wald_two_sided_pval())))

	# A marginal estimand: the conditional-coefficient refits do not apply.
	f <- strat_fixture("blocking")
	inf <- InferenceCountPoisson$new(f$des, model_formula = ~1, verbose = FALSE)
	inf$num_cores <- 1L
	inf$set_estimand("marginal_mean_diff")
	expect_null(inf$.__enclos_env__$private$design_stratified_jackknife())
})
