library(testthat)
library(EDI)

# apply_treatment_and_noise_cpp() (simulation_dgp.cpp:12-30), the exported C++ kernel behind
# simulations_framework.R's data-generating process, validates that y_linear_model and w have
# matching lengths before anything else -- "apply_treatment_and_noise_cpp: y_linear_model and w
# must have the same length." Its sibling argument-validation guards (phi_proportion/k_survival/
# the four *_clamp bounds, the count/survival non-finite-mean guards, and the unknown-response_type
# guard) are all already covered elsewhere; a codebase-wide grep confirmed only this one length-
# mismatch guard had zero test references anywhere. Exercised via a direct call to the exported C++
# kernel itself (not through simulations_framework.R's R-side wrapper -- a deliberate choice this
# iteration, since that R source file has an unrelated in-progress edit from another session; this
# kernel is a separate, untouched file), so no risk of interfering with that concurrent work.

test_that("apply_treatment_and_noise_cpp() rejects y_linear_model/w length mismatches", {
	f <- getFromNamespace("apply_treatment_and_noise_cpp", "EDI")
	expect_error(
		f(
			y_linear_model = rnorm(5), w = c(1L, 0L, 1L), response_type = "continuous",
			betaT = 0.5, sd_noise = 1, prob_censoring = 0, n_ordinal_levels = 4L,
			phi_proportion = 2, k_survival = 1
		),
		"apply_treatment_and_noise_cpp: y_linear_model and w must have the same length.",
		fixed = TRUE
	)
})

test_that("matching lengths do not trigger the guard", {
	f <- getFromNamespace("apply_treatment_and_noise_cpp", "EDI")
	set.seed(1)
	res <- f(
		y_linear_model = rnorm(5), w = c(1L, 0L, 1L, 0L, 1L), response_type = "continuous",
		betaT = 0.5, sd_noise = 1, prob_censoring = 0, n_ordinal_levels = 4L,
		phi_proportion = 2, k_survival = 1
	)
	expect_length(res$y, 5L)
})
