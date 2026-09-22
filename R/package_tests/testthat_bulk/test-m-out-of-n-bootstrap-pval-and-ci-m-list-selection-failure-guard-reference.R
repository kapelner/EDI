library(testthat)
library(EDI)

# InferenceNonParamBootstrap$compute_m_out_of_n_bootstrap_two_sided_pval()/compute_m_out_of_n_bootstrap_confidence_interval():
# each has its OWN copy of the m-as-list data-adaptive-selection guard (distinct from the already-tested copy on
# approximate_m_out_of_n_bootstrap_distribution_beta_hat_T(), which hard stop()s -- these two instead cache the
# "m_out_of_n_m_selection_failed" nonestimable reason under harden = TRUE and silently return NA either way,
# never throwing). Neither method had any test calling it with m as a list.

fx <- function(seed = 1L, n = 60L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n))); des$assign_w_to_all_subjects()
	w <- des$get_w(); des$add_all_subject_responses(rnorm(n) + 0.5 * w)
	InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
}

stub_failed_selection <- function(inf) {
	unlockBinding("select_optimal_m_out_of_n_bootstrap", inf)
	inf$select_optimal_m_out_of_n_bootstrap <- function(...) list(m_optimal = NA_real_)
	invisible(inf)
}

test_that("under harden = TRUE (the default), a failed m selection makes the p-value NA with the shared reason", {
	inf <- fx(); expect_true(inf$.__enclos_env__$private$harden)
	stub_failed_selection(inf)
	pv <- inf$compute_m_out_of_n_bootstrap_two_sided_pval(delta = 0, B = 10, m = list(), show_progress = FALSE)
	expect_true(is.na(pv))
	expect_identical(inf$get_nonestimable_reason(), "m_out_of_n_m_selection_failed")
})

test_that("under harden = TRUE, a failed m selection makes the CI all-NA with the same reason, correctly-labelled alpha percentages", {
	inf <- fx()
	stub_failed_selection(inf)
	ci <- inf$compute_m_out_of_n_bootstrap_confidence_interval(alpha = 0.1, B = 10, m = list(), show_progress = FALSE)
	expect_true(all(is.na(ci)))
	expect_identical(names(ci), c("5%", "95%"))
	expect_identical(inf$get_nonestimable_reason(), "m_out_of_n_m_selection_failed")
})

test_that("under harden = FALSE, both methods still return NA silently (no error, no reason recorded)", {
	inf <- fx()
	p <- inf$.__enclos_env__$private
	unlockBinding("harden", p); p$harden <- FALSE
	stub_failed_selection(inf)
	pv <- inf$compute_m_out_of_n_bootstrap_two_sided_pval(delta = 0, B = 10, m = list(), show_progress = FALSE)
	expect_true(is.na(pv))
	expect_null(inf$get_nonestimable_reason())

	inf2 <- fx()
	p2 <- inf2$.__enclos_env__$private
	unlockBinding("harden", p2); p2$harden <- FALSE
	stub_failed_selection(inf2)
	ci <- inf2$compute_m_out_of_n_bootstrap_confidence_interval(alpha = 0.1, B = 10, m = list(), show_progress = FALSE)
	expect_true(all(is.na(ci)))
	expect_null(inf2$get_nonestimable_reason())
})

test_that("a real (unstubbed) list-m call succeeds end to end for both methods", {
	inf <- fx()
	pv <- inf$compute_m_out_of_n_bootstrap_two_sided_pval(delta = 0, B = 30, m = list(B = 30, alpha = 0.1), show_progress = FALSE)
	expect_true(is.finite(pv) && pv >= 0 && pv <= 1)

	inf2 <- fx()
	ci <- inf2$compute_m_out_of_n_bootstrap_confidence_interval(alpha = 0.1, B = 30, m = list(B = 30, alpha = 0.1), show_progress = FALSE)
	expect_true(all(is.finite(ci)))
})
