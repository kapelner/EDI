library(testthat)
library(EDI)

# Dependent-censoring bootstrap intervals are not overwritten based on their
# sign, width, or agreement with a Wald interval. Only non-finite numerical
# output is unavailable.

mk <- function(est = 0.3, se = 0.1, df = Inf) {
	set.seed(1); n <- 40L
	d <- DesignFixedBernoulli$new(response_type = "survival", n = n, seed = 1L, verbose = FALSE)
	d$add_all_subjects_to_experiment(data.frame(x = rnorm(n))); d$assign_w_to_all_subjects()
	d$add_all_subject_responses(ys = rexp(n) + 0.1, y_Ls = rep(NA, n), y_Rs = rep(NA, n))
	inf <- InferenceSurvivalDepCensTransformRegr$new(d, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	p$cached_values$beta_hat_T <- est; p$cached_values$s_beta_hat_T <- se; p$cached_values$df <- df
	list(inf = inf, p = p)
}

test_that("finite dependent-censoring bootstrap intervals are returned unchanged", {
	f <- mk(est = 0.05, se = 0.1)
	for (ci in list(c(0.01, 0.4), c(0.4, 0.9), c(-1e9, 1e9), c(-3, 3))) {
		expect_identical(f$p$dep_cens_validate_bootstrap_ci(ci, 0.05), ci)
	}
})

test_that("non-finite dependent-censoring bootstrap output is unavailable without a Wald substitution", {
	f <- mk()
	for (ci in list(c(NA, 1), c(1, Inf), 0.1)) {
		out <- f$p$dep_cens_validate_bootstrap_ci(ci, 0.05)
		expect_true(all(is.na(out)))
		expect_identical(names(out), c("2.5%", "97.5%"))
	}
})

test_that("studentized wrapper preserves a finite basic interval regardless of sign or width", {
	f <- mk()
	unlockBinding("compute_bootstrap_confidence_interval_basic", f$inf)
	f$inf$compute_bootstrap_confidence_interval_basic <- function(...) c(`2.5%` = 0.1, `97.5%` = 1e10)
	expect_identical(f$inf$compute_bootstrap_confidence_interval_studentized(alpha = 0.05), c(`2.5%` = 0.1, `97.5%` = 1e10))
})
