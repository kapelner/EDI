library(testthat)
library(EDI)

skip_if_not_installed("survival")

make_mismatched_followup_rmst_fixture <- function() {
	set.seed(72301L)
	n <- 24L
	des <- DesignFixedBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = seq_len(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	stopifnot(any(w == 0), any(w == 1))
	y <- numeric(n)
	y[w == 0] <- seq(0.5, 4, length.out = sum(w == 0))
	y[w == 1] <- seq(0.5, 10, length.out = sum(w == 1))
	dead <- rep(c(1, 0, 1), length.out = n)
	des$add_all_subject_responses(
		ifelse(dead == 1, y, NA_real_),
		ifelse(dead == 0, y, NA_real_),
		ifelse(dead == 0, Inf, NA_real_)
	)
	list(des = des, y = y, dead = dead, w = w)
}

test_that("weighted RMST differences truncate both arms at the shared supported horizon", {
	f <- make_mismatched_followup_rmst_fixture()
	inf <- InferenceSurvivalRestrictedMeanDiff$new(f$des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	tau <- min(max(f$y[f$w == 0]), max(f$y[f$w == 1]))
	fit <- survival::survfit(survival::Surv(f$y, f$dead) ~ f$w)
	tab <- summary(fit, rmean = tau)$table
	expected <- unname(tab["f$w=1", "rmean"] - tab["f$w=0", "rmean"])
	individual <- summary(fit, rmean = "individual")$table
	old_value <- unname(individual["f$w=1", "rmean"] - individual["f$w=0", "rmean"])

	expect_equal(tau, 4)
	expect_gt(abs(expected - old_value), 0.1)
	expect_equal(
		priv$weighted_survival_stat_diff(rep(1, length(f$y)), "restricted_mean"),
		expected,
		tolerance = 1e-10
	)
})

test_that("zero bootstrap weights determine the shared horizon from retained rows", {
	f <- make_mismatched_followup_rmst_fixture()
	inf <- InferenceSurvivalRestrictedMeanDiff$new(f$des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	weights <- rep(1, length(f$y))
	weights[f$w == 0 & f$y > 3] <- 0
	weights[f$w == 1 & f$y > 7] <- 0
	keep <- weights > 0
	tau <- min(max(f$y[keep & f$w == 0]), max(f$y[keep & f$w == 1]))
	fit <- survival::survfit(
		survival::Surv(f$y[keep], f$dead[keep]) ~ f$w[keep],
		weights = weights[keep]
	)
	tab <- summary(fit, rmean = tau)$table
	expected <- unname(tab["f$w[keep]=1", "rmean"] - tab["f$w[keep]=0", "rmean"])

	expect_equal(
		priv$weighted_survival_stat_diff(weights, "restricted_mean"),
		expected,
		tolerance = 1e-10
	)
})
