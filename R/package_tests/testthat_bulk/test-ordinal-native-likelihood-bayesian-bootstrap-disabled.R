test_that("ordinal native-likelihood classes do not advertise Bayesian bootstrap", {
	set.seed(82401)
	y = rep(1:4, each = 3L)
	des = DesignSeqOneByOneBernoulli$new(n = length(y), response_type = "ordinal", verbose = FALSE)
	for (i in seq_along(y)) {
		des$add_one_subject_to_experiment_and_assign(
			data.frame(x1 = i / length(y), x2 = (i %% 3L) / 10)
		)
	}
	des$add_all_subject_responses(y)

	classes = list(
		InferenceOrdinalStereotypeLogitRegr$new(des, verbose = FALSE),
		InferenceOrdinalAdjCatLogitRegr$new(des, verbose = FALSE)
	)
	for (inf in classes) {
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
	}
})

test_that("continuation-ratio Bayesian bootstrap remains enabled", {
	set.seed(82402)
	y = rep(1:4, each = 3L)
	des = DesignSeqOneByOneBernoulli$new(n = length(y), response_type = "ordinal", verbose = FALSE)
	for (i in seq_along(y)) {
		des$add_one_subject_to_experiment_and_assign(data.frame(x1 = i / length(y)))
	}
	des$add_all_subject_responses(y)

	inf = InferenceOrdinalContRatioRegr$new(des, verbose = FALSE)
	expect_true(inf$supports("bayesian_bootstrap")[["bayesian_bootstrap"]])
	expect_true(inf$.__enclos_env__$private$supports_bayesian_bootstrap())
})
