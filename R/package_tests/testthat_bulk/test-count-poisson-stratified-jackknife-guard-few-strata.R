library(testthat)
library(EDI)

# v1.1.0-TODO-218: InferenceCountPoisson's design-conservative rule (max of the model p-value and a
# design-based jackknife p-value; union of the CIs) lost its design-based half on stratified designs with
# few strata. The automatic deletion unit there is the block (= stratum); with fewer than
# EDI_JACKKNIFE_MIN_DELETION_UNITS strata that jackknife is NA, so the raw Poisson test was reported and was
# oversized under overdispersion (calibration: size 0.08-0.11 with ~1 on FixedBlocking, SPBR and
# RandomBlockSize stratified on two binary covariates). The class now falls back to the stratified delete-1
# ("JKn") jackknife, unit = "observation_within_block" (Wolter 2007, Sec. 4.5). With ~1 the leave-one-out
# Poisson estimate is the closed-form log ratio of arm means, so the fallback is checked exactly against a
# hand computation.
# v1.0.6-TODO-4: DesignFixedBlocking and DesignSeqOneByOneSPBR no longer use the block (= stratum) as their
# automatic jackknife unit: FixedBlocking jackknifes one subject at a time within strata (the same stratified
# estimator the fallback uses) and SPBR one permuted block at a time. The fallback
# below is therefore checked on DesignSeqOneByOneRandomBlockSize, whose automatic unit is still the block.
# v1.0.6-TODO-231: DesignSeqOneByOneRandomBlockSize now records its permuted blocks at assignment and
# jackknifes one block at a time too. Only a design object without that record (saved before EDI 1.0.6)
# keeps the whole-stratum unit, so the fallback is checked on such an object (the record is cleared).

forget_recorded_blocks <- function(des) {
	des$.__enclos_env__$private$permuted_block_ids <- integer(0)
	invisible(des)
}

strat_fixture <- function(design = c("blocking", "spbr", "rbs"), n = 240L, seed = 3L) {
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
		des <- if (design == "spbr") {
			DesignSeqOneByOneSPBR$new(n = n, response_type = "count", strata_cols = c("s1", "s2"), verbose = FALSE)
		} else {
			DesignSeqOneByOneRandomBlockSize$new(n = n, response_type = "count", strata_cols = c("s1", "s2"), verbose = FALSE)
		}
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

# compute_jackknife_summary() applies Wolter's JKn to reweighting-equivalent replicates: the within-stratum
# sums carry ((N - 1)/N)^2 n_h/(n_h - 1) instead of (n_h - 1)/n_h, and the bias is the ordinary
# (N - 1)(mean - estimate) (see edi_jackknife_bias_variance()).
hand_jkn <- function(y, w, strata) {
	S1 <- sum(y[w == 1]); S0 <- sum(y[w == 0]); n1 <- sum(w); n0 <- length(w) - n1
	est <- log(S1 / n1) - log(S0 / n0)
	loo <- ifelse(w == 1, log((S1 - y) / (n1 - 1)) - log(S0 / n0), log(S1 / n1) - log((S0 - y) / (n0 - 1)))
	N <- length(loo)
	se <- sqrt(sum(vapply(unique(strata), function(h) { th <- loo[strata == h]; n_h <- length(th)
		((N - 1) / N)^2 * n_h / (n_h - 1) * sum((th - mean(th))^2) }, numeric(1))))
	bias <- (N - 1) * (mean(loo) - est)
	list(estimate = est, jk_estimate = est - bias, std_error = se, model_se = sqrt(1 / S1 + 1 / S0))
}

for (design in "rbs") {
	test_that(paste0("~1 Poisson on a 4-stratum ", design, " design reports the stratified-jackknife-widened Wald test"), {
		f <- strat_fixture(design)
		forget_recorded_blocks(f$des)
		expect_equal(length(unique(f$des$get_block_ids())), 4L)
		inf <- InferenceCountPoisson$new(f$des, model_formula = ~1, verbose = FALSE)
		inf$num_cores <- 1L
		inf$set_testing_type("wald")
		p <- inf$.__enclos_env__$private
		hand <- hand_stratified_jackknife(f$y, f$w, f$strata)
		expect_equal(as.numeric(inf$compute_estimate()), hand$estimate, tolerance = 1e-8)

		# The leave-one-block-out jackknife has only 4 units, so it is NA ...
		expect_true(is.na(suppressWarnings(inf$compute_jackknife_wald_two_sided_pval())))
		# ... and the fallback is the stratified delete-1 (JKn) jackknife, unit "observation_within_block".
		expect_true(p$use_within_block_jackknife_fallback())
		jkn <- hand_jkn(f$y, f$w, f$strata)
		expect_equal(inf$compute_jackknife_std_error(unit = "observation_within_block"), jkn$std_error, tolerance = 1e-6)
		expect_equal(inf$compute_jackknife_estimate(unit = "observation_within_block"), jkn$jk_estimate, tolerance = 1e-8)
		expect_gt(jkn$std_error, hand$model_se)                # overdispersion: design SE > Poisson SE

		p_model <- 2 * pnorm(-abs(hand$estimate / hand$model_se))
		# v1.0.6-TODO-231: the stratified jackknife uses t with sum_h (n_h - 1) df.
		df_jk <- length(f$strata) - length(unique(f$strata))
		p_jk <- 2 * pt(-abs(jkn$jk_estimate / jkn$std_error), df_jk)
		expect_equal(inf$compute_asymp_two_sided_pval(), max(p_model, p_jk), tolerance = 1e-6)
		ci <- unname(inf$compute_asymp_confidence_interval(0.05))
		z <- qnorm(0.975)
		ci_model <- hand$estimate + c(-1, 1) * z * hand$model_se
		ci_jk <- jkn$jk_estimate + c(-1, 1) * qt(0.975, df_jk) * jkn$std_error
		expect_equal(ci, c(min(ci_model[1], ci_jk[1]), max(ci_model[2], ci_jk[2])), tolerance = 1e-6)
	})
}

test_that("~1 Poisson on a 4-stratum FixedBlocking design uses the stratified jackknife directly (v1.0.6-TODO-4)", {
	f <- strat_fixture("blocking")
	inf <- InferenceCountPoisson$new(f$des, model_formula = ~1, verbose = FALSE)
	inf$num_cores <- 1L
	inf$set_testing_type("wald")
	p <- inf$.__enclos_env__$private
	expect_identical(p$resolve_jackknife_unit("auto"), "observation_within_block")
	hand <- hand_stratified_jackknife(f$y, f$w, f$strata)
	# No fallback needed: the automatic jackknife is the stratified delete-1 jackknife.
	expect_false(p$use_within_block_jackknife_fallback())
	# compute_jackknife_summary() applies Wolter's JKn to reweighting-equivalent replicates: the
	# within-stratum sums carry ((N - 1)/N)^2 n_h/(n_h - 1) instead of (n_h - 1)/n_h, and the bias is
	# the ordinary (N - 1)(mean - estimate) (see edi_jackknife_bias_variance()).
	S1 <- sum(f$y[f$w == 1]); S0 <- sum(f$y[f$w == 0]); n1 <- sum(f$w); n0 <- length(f$w) - n1
	loo <- ifelse(f$w == 1, log((S1 - f$y) / (n1 - 1)) - log(S0 / n0), log(S1 / n1) - log((S0 - f$y) / (n0 - 1)))
	N <- length(loo)
	se_jk <- sqrt(sum(vapply(unique(f$strata), function(h) { th <- loo[f$strata == h]; n_h <- length(th)
		((N - 1) / N)^2 * n_h / (n_h - 1) * sum((th - mean(th))^2) }, numeric(1))))
	expect_equal(inf$compute_jackknife_std_error(), se_jk, tolerance = 1e-6)
	bias <- (N - 1) * (mean(loo) - hand$estimate)
	expect_equal(inf$compute_jackknife_estimate(), hand$estimate - bias, tolerance = 1e-8)
	p_model <- 2 * pnorm(-abs(hand$estimate / hand$model_se))
	p_jk <- 2 * pt(-abs((hand$estimate - bias) / se_jk), N - length(unique(f$strata)))
	expect_equal(inf$compute_asymp_two_sided_pval(), max(p_model, p_jk), tolerance = 1e-6)
})

test_that("~1 Poisson on a 4-stratum SPBR design uses the permuted-block jackknife (v1.0.6-TODO-4)", {
	f <- strat_fixture("spbr")
	inf <- InferenceCountPoisson$new(f$des, model_formula = ~1, verbose = FALSE)
	inf$num_cores <- 1L
	p <- inf$.__enclos_env__$private
	expect_identical(p$resolve_jackknife_unit("auto"), "permuted_block")
	expect_false(p$use_within_block_jackknife_fallback())
	expect_true(is.finite(inf$compute_jackknife_wald_two_sided_pval()))
})

test_that("~1 Poisson on a 4-stratum RandomBlockSize design uses its recorded permuted blocks (v1.0.6-TODO-231)", {
	f <- strat_fixture("rbs")
	inf <- InferenceCountPoisson$new(f$des, model_formula = ~1, verbose = FALSE)
	inf$num_cores <- 1L
	p <- inf$.__enclos_env__$private
	expect_identical(p$resolve_jackknife_unit("auto"), "permuted_block")
	expect_false(p$use_within_block_jackknife_fallback())
	expect_true(is.finite(inf$compute_jackknife_wald_two_sided_pval()))
})

test_that("the stratified fallback stays off on unstratified designs and where the automatic unit is not the block, and covers marginal estimands", {
	# Unstratified design: the observation-level jackknife is used, no fallback.
	set.seed(5)
	n <- 120L
	des <- DesignFixediBCRD$new(n = n, response_type = "count", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rpois(n, 2))
	inf <- InferenceCountPoisson$new(des, model_formula = ~1, verbose = FALSE)
	inf$num_cores <- 1L
	expect_false(inf$.__enclos_env__$private$use_within_block_jackknife_fallback())

	# Many blocks (8 strata): no fallback (since v1.0.6-TODO-4 the automatic unit here is the subject
	# within its stratum, not the block, so the jackknife is finite regardless of the stratum count).
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
	expect_false(inf$.__enclos_env__$private$use_within_block_jackknife_fallback())
	expect_true(is.finite(suppressWarnings(inf$compute_jackknife_wald_two_sided_pval())))

	# A marginal estimand: the shared jackknife refits under the active estimand, so the fallback applies too.
	f <- strat_fixture("rbs")
	forget_recorded_blocks(f$des)
	inf <- InferenceCountPoisson$new(f$des, model_formula = ~1, verbose = FALSE)
	inf$num_cores <- 1L
	inf$set_estimand("marginal_mean_diff")
	expect_true(inf$.__enclos_env__$private$use_within_block_jackknife_fallback())
	expect_true(is.finite(inf$.__enclos_env__$private$design_jackknife_pval()))
})
