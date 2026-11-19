library(testthat)
library(EDI)

# docs-claims audit, finding docs-claims-dfbe3e8c5 (InferenceIncidLogBinomial):
#   - when the hardened refit drops covariates to get a usable fit, the class
#     raises one edi_covariate_dropped_warning per object (silent inside
#     resampling) naming the dropped columns and the reason;
#   - columns dropped only for linear dependence are not warned about.

catch_drop_warnings <- function(expr) {
	ws <- list()
	val <- withCallingHandlers(expr, warning = function(w) {
		if (inherits(w, "edi_covariate_dropped_warning")) ws[[length(ws) + 1L]] <<- w
		invokeRestart("muffleWarning")
	})
	list(value = val, warnings = ws)
}

# xt is a covariate on a tiny scale with a real effect, so its log-RR coefficient
# (~100) is over max_abs_reasonable_coef = 25 and the hardened loop drops it.
diverged_covariate_design <- function() {
	set.seed(2); n <- 60L
	X <- data.frame(x1 = rnorm(n), xt = rnorm(n) * 0.001)
	des <- DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(rbinom(n, 1, exp(-1.5 + 0.3 * w + 0.2 * X$x1 + 100 * X$xt)))
	des
}

test_that("log-binomial warns exactly once naming the dropped column, and not again during a bootstrap", {
	inf <- InferenceIncidLogBinomial$new(diverged_covariate_design(), verbose = FALSE)
	inf$num_cores <- 1L
	res <- catch_drop_warnings({
		set.seed(1)
		c(inf$compute_estimate(), inf$compute_asymp_two_sided_pval(),
			inf$compute_estimate(), inf$compute_bootstrap_two_sided_pval(B = 19, show_progress = FALSE))
	})
	expect_length(res$warnings, 1L)
	w <- res$warnings[[1L]]
	expect_identical(w$dropped, "xt")
	expect_identical(w$reason, "coefficient_diverged")
	expect_match(conditionMessage(w), "InferenceIncidLogBinomial: dropped covariate\\(s\\) xt")
	priv <- inf$.__enclos_env__$private
	expect_false("xt" %in% priv$best_X_colnames)
	expect_true("x1" %in% priv$best_X_colnames)
	expect_true(is.finite(res$value[1L]))
})

test_that("log-binomial: a column dropped only for linear dependence (x1_copy = 2 * x1) is not warned about", {
	set.seed(4); n <- 60L
	X <- data.frame(x1 = rnorm(n)); X$x1_copy <- 2 * X$x1
	des <- DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rbinom(n, 1, exp(-1.5 + 0.3 * as.numeric(des$get_w()) + 0.2 * X$x1)))
	inf <- InferenceIncidLogBinomial$new(des, verbose = FALSE)
	res <- catch_drop_warnings({ inf$compute_estimate(); inf$compute_asymp_two_sided_pval() })
	expect_true(is.finite(res$value))
	expect_length(res$warnings, 0L)
})
