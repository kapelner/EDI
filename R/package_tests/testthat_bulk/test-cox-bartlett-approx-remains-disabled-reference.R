library(testthat)
library(EDI)

cox_bartlett_fixture <- function(class_gen, seed = 4401L) {
	set.seed(seed)
	n <- 60L
	des <- DesignFixedBernoulli$new(n = n, response_type = "survival", seed = seed)
	x1 <- rnorm(n)
	des$add_all_subjects_to_experiment(data.frame(x1 = x1))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	event_time <- rexp(n, rate = exp(0.25 * w + 0.15 * x1))
	censor_time <- rexp(n, rate = 0.2)
	y <- pmin(event_time, censor_time)
	dead <- as.integer(event_time <= censor_time)
	des$add_all_subject_responses(
		ifelse(dead == 1L, y, NA_real_),
		ifelse(dead == 0L, y, NA_real_),
		ifelse(dead == 0L, Inf, NA_real_)
	)
	class_gen$new(des, model_formula = ~ x1, verbose = FALSE)
}

test_that("Cox classes retain the evidence-based Bartlett-approx opt-out", {
	for (class_gen in list(InferenceSurvivalCoxPHRegr, InferenceSurvivalStratCoxPHRegr)) {
		inf <- cox_bartlett_fixture(class_gen)
		priv <- inf$.__enclos_env__$private

		expect_false(priv$supports_bartlett_likelihood_ratio_approx(), info = class(inf)[1L])
		expect_false(priv$supports_bartlett_likelihood_ratio_exact(), info = class(inf)[1L])
		expect_false("lik_ratio_bartlett_approx" %in% inf$get_supported_testing_types(), info = class(inf)[1L])
		expect_error(
			inf$compute_lik_ratio_bartlett_two_sided_pval(delta = 0, B = 3L),
			"does not support Bartlett-corrected likelihood-ratio inference",
			fixed = TRUE
		)
	}
})
