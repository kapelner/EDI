library(testthat)
library(EDI)

# InferenceOrdinalRidit$compute_estimate_with_bootstrap_weights() was only
# ever reached with ordinary positive weights via the Bayesian-bootstrap smoke
# checks. This file pins its weighted ridit computation for all three
# reference distributions against an independent from-scratch reference, and
# exercises its four early-NA-return branches (no positive-weight rows, empty
# reference group, and one arm empty after weighting).

make_ridit_fixture <- function(seed = 3L, n = 60L) {
	set.seed(seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "ordinal", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$overwrite_all_subject_assignments(rep(0:1, length.out = n))
	w <- des$get_w()
	y <- sample(1:4, n, TRUE, prob = c(.4, .3, .2, .1)) + w * (runif(n) < .3)
	y <- as.integer(pmin(y, 4L))
	des$add_all_subject_responses(y)
	list(des = des, w = w, y = y, n = n)
}

weighted_inf <- function(f, reference) {
	inf <- InferenceOrdinalRidit$new(f$des, reference = reference, verbose = FALSE)
	inf$.__enclos_env__$private$current_bayesian_bootstrap_context <- list(
		row_to_unit = seq_len(f$n), unit_group_id = rep(1L, f$n), n_units = f$n
	)
	inf
}

ref_weighted_ridit <- function(y, w, wt, reference) {
	ok <- wt > 0
	ref_idx <- switch(reference, control = ok & w == 0, treatment = ok & w == 1, pooled = ok)
	cats <- sort(unique(y[ok]))
	p <- vapply(cats, function(k) sum(wt[ref_idx & y == k]) / sum(wt[ref_idx]), numeric(1))
	ridit <- cumsum(p) - p / 2
	score <- ridit[match(y, cats)]
	t_idx <- ok & w == 1
	sum(wt[t_idx] * score[t_idx]) / sum(wt[t_idx]) - 0.5
}

test_that("weighted ridit estimate matches an independent weighted-ridit reference for every reference distribution", {
	f <- make_ridit_fixture()
	set.seed(99)
	wt <- runif(f$n, 0.2, 3)
	for (reference in c("control", "treatment", "pooled")) {
		est <- weighted_inf(f, reference)$compute_estimate_with_bootstrap_weights(wt)
		expect_equal(est, ref_weighted_ridit(f$y, f$w, wt, reference), tolerance = 1e-10, info = reference)
	}
})

test_that("unit weights reproduce the unweighted estimate and zero-weight rows are dropped", {
	f <- make_ridit_fixture()
	for (reference in c("control", "treatment", "pooled")) {
		unweighted <- InferenceOrdinalRidit$new(f$des, reference = reference, verbose = FALSE)$compute_estimate()
		expect_equal(weighted_inf(f, reference)$compute_estimate_with_bootstrap_weights(rep(1, f$n)),
			unweighted, tolerance = 1e-10, info = reference)
	}
	wt <- rep(1, f$n); wt[1:6] <- 0
	est <- weighted_inf(f, "control")$compute_estimate_with_bootstrap_weights(wt)
	expect_equal(est, ref_weighted_ridit(f$y, f$w, wt, "control"), tolerance = 1e-10)
})

test_that("weighted path leaves SE/df NA and caches the weighted mean ridit and scores", {
	f <- make_ridit_fixture()
	set.seed(5)
	wt <- runif(f$n, 0.2, 3)
	inf <- weighted_inf(f, "control")
	est <- inf$compute_estimate_with_bootstrap_weights(wt)
	cv <- inf$.__enclos_env__$private$cached_values
	expect_true(is.na(cv$s_beta_hat_T))
	expect_true(is.na(cv$df))
	expect_equal(cv$beta_hat_T, est)
	expect_equal(cv$mean_ridit_t - 0.5, est, tolerance = 1e-12)
	expect_length(cv$scores, f$n)
})

test_that("early-NA branches: all-zero weights, empty reference group, and an arm emptied by zero weights", {
	f <- make_ridit_fixture()

	inf0 <- weighted_inf(f, "control")
	expect_true(is.na(inf0$compute_estimate_with_bootstrap_weights(rep(0, f$n))))
	expect_true(is.na(inf0$.__enclos_env__$private$cached_values$beta_hat_T))

	wt_no_control <- ifelse(f$w == 0, 0, 1)
	expect_true(is.na(weighted_inf(f, "control")$compute_estimate_with_bootstrap_weights(wt_no_control)))

	wt_no_treated <- ifelse(f$w == 1, 0, 1)
	expect_true(is.na(weighted_inf(f, "treatment")$compute_estimate_with_bootstrap_weights(wt_no_treated)))
	# pooled reference is nonempty, but the treated arm is empty after weighting.
	expect_true(is.na(weighted_inf(f, "pooled")$compute_estimate_with_bootstrap_weights(wt_no_treated)))
	# control reference is nonempty, but the treated arm is empty.
	expect_true(is.na(weighted_inf(f, "control")$compute_estimate_with_bootstrap_weights(wt_no_treated)))
})
