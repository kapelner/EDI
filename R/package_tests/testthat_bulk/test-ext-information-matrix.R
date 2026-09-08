library(testthat)
library(EDI)

make_information_matrix_logit_inference <- function(seed = 1L, n = 80L){
	set.seed(seed)
	x = rnorm(n)
	w = rep(c(1, 0), length.out = n)
	des = DesignFixedTestFixture$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(rbinom(n, 1L, plogis(-0.2 + 0.5 * w + 0.3 * x)))
	InferenceIncidLogRegr$new(des, verbose = FALSE)
}

test_that("information-matrix mixin is composed into likelihood inference classes", {
	expect_true(is.list(EDI:::InferenceExtInformationMatrix))
	expect_named(
		EDI:::InferenceExtInformationMatrix$private,
		c(
			"get_information_matrix",
			"compute_variance_from_information_matrix",
			"compute_standard_error_from_information_matrix",
			"get_score_test_information_matrix",
			"score_test_with_ridge_fallback"
		)
	)

	inf = make_information_matrix_logit_inference()
	priv = inf$.__enclos_env__$private
	expect_true(all(names(EDI:::InferenceExtInformationMatrix$private) %in% names(priv)))
})

test_that("information-matrix mixin selects the requested source and derives standard errors", {
	inf = make_information_matrix_logit_inference(seed = 2L)
	priv = inf$.__enclos_env__$private
	fisher = diag(c(2, 4))
	observed = diag(c(3, 9))
	spec = list(full_fit = list(fisher_information = fisher, observed_information = observed), j = 2L)

	priv$information_preference = "fisher"
	expect_equal(priv$get_information_matrix(spec = spec), fisher)
	expect_equal(inf$get_information_source_used(), "fisher")

	priv$information_preference = "observed"
	expect_equal(priv$get_information_matrix(spec = spec), observed)
	expect_equal(inf$get_information_source_used(), "observed")

	priv$information_preference = "fisher"
	expect_equal(priv$compute_variance_from_information_matrix(fisher, 2L), 0.25)
	expect_equal(priv$compute_standard_error_from_information_matrix(spec = spec), 0.5)
	expect_true(is.na(priv$compute_variance_from_information_matrix(fisher, 3L)))
})

test_that("score_test_with_ridge_fallback recovers a finite p-value from a non-PD nuisance block", {
	inf = make_information_matrix_logit_inference(seed = 3L)
	priv = inf$.__enclos_env__$private

	# A 3x3 information matrix whose nuisance block (rows/cols 2:3, treatment
	# at index 1) is singular (rank-deficient by construction) -- the raw
	# Schur complement would be NA/non-positive without ridge regularization.
	information = matrix(c(
		4, 1, 1,
		1, 2, 2,
		1, 2, 2
	), nrow = 3, byrow = TRUE)
	score = c(1.5, 0, 0)

	p_value = priv$score_test_with_ridge_fallback(score, information, j = 1L)
	expect_true(is.finite(p_value))
	expect_true(p_value >= 0 && p_value <= 1)

	# Out-of-range j must fail gracefully, not error.
	expect_true(is.na(priv$score_test_with_ridge_fallback(score, information, j = 5L)))
	# A genuinely non-finite score must fail gracefully too.
	expect_true(is.na(priv$score_test_with_ridge_fallback(c(NA_real_, 0, 0), information, j = 1L)))
})

test_that("InferenceContinKKGLMM/InferenceCountKKGLMM score tests are no longer degenerate", {
	# Regression for the 2026-09-07 fix: compute_score_two_sided_pval() for
	# these two classes previously returned NA on the large majority of
	# calls (0% Type-I error AND 0% power -- a degenerate test) because the
	# null-constrained refit's observed information is only positive
	# definite on a minority of replicates (the random-intercept variance
	# component routinely sits near its lower boundary in small matched-pair
	# fits). The ridge-regularized fallback in score_test_with_ridge_
	# fallback() converts this into a working (if not perfectly calibrated
	# for the Gaussian-LMM case) test with real power.
	n <- 60L
	na_h0 <- 0L; na_h1 <- 0L; rej_h1 <- 0L
	R <- 20L
	for (r in seq_len(R)) {
		set.seed(90000L + r)
		des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
		for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
		add_all_subject_responses_seq(des, rnorm(n))
		inf0 <- InferenceContinKKGLMM$new(des, verbose = FALSE)
		if (is.na(inf0$compute_score_two_sided_pval())) na_h0 <- na_h0 + 1L

		set.seed(90000L + r)
		des2 <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
		for (i in seq_len(n)) des2$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
		w2 <- des2$get_w()
		add_all_subject_responses_seq(des2, 1.0 * w2 + rnorm(n))
		inf1 <- InferenceContinKKGLMM$new(des2, verbose = FALSE)
		p1 <- inf1$compute_score_two_sided_pval()
		if (is.na(p1)) na_h1 <- na_h1 + 1L else if (p1 < 0.05) rej_h1 <- rej_h1 + 1L
	}
	# Before the fix, na_h0/na_h1 were both close to R and rej_h1 was 0.
	expect_lt(na_h0 / R, 0.5)
	expect_lt(na_h1 / R, 0.5)
	expect_gt(rej_h1 / R, 0.3)
})
