test_that("ordinal KK GEE does not advertise Bayesian bootstrap", {
	skip_if_not_installed("multgee")

	y = c(1L, 2L, 1L, 3L, 2L, 1L, 3L, 2L)
	des = DesignSeqOneByOneKK14$new(n = length(y), response_type = "ordinal", verbose = FALSE)
	for (i in seq_along(y)) {
		des$add_one_subject_to_experiment_and_assign(
			data.frame(x1 = i / 10, x2 = (i %% 3) / 10)
		)
	}
	des$.__enclos_env__$private$m = c(1L, 1L, 2L, 2L, 3L, 3L, 0L, 0L)
	des$add_all_subject_responses(y)
	inf = InferenceOrdinalKKGEE$new(des, verbose = FALSE)

	expect_false(inf$supports("bayesian_bootstrap")[["bayesian_bootstrap"]])
	expect_false(inf$.__enclos_env__$private$supports_bayesian_bootstrap())
	expect_error(
		inf$compute_bayesian_bootstrap_confidence_interval(B = 5L, show_progress = FALSE),
		"does not support Bayesian bootstrap",
		fixed = TRUE
	)
	expect_error(
		inf$compute_bayesian_bootstrap_two_sided_pval(B = 5L, show_progress = FALSE),
		"does not support Bayesian bootstrap",
		fixed = TRUE
	)
})
