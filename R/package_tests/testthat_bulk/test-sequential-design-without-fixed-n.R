# v1.0.6-TODO-76, v1.0.6-TODO-77, v1.0.6-TODO-78: a sequential design built with n = NULL (no
# planned sample size) must run end to end.
#  - TODO-76: KK14 / KK21 / KK21stepwise crashed ("missing value where TRUE/FALSE needed") once the
#    model matrix existed, because the t_0_pct burn-in compared t with t_0_pct * NULL. With n = NULL
#    the burn-in now lasts only until the covariate model matrix exists.
#  - TODO-77: check_experiment_completed() / assert_all_subjects_arrived() used `&` with a NULL n,
#    so every Inference*$new() on an n = NULL design errored "argument is of length zero".
#  - TODO-78: with n = NULL, responses had to arrive in enrollment order, and an out-of-order
#    response was refused with a message claiming the subject had not arrived.

library(testthat)
library(EDI)

enroll_seq = function(des, X) {
	for (i in seq_len(nrow(X))) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	invisible(des)
}

test_that("KK14, KK21 and KK21stepwise assign, match and analyze with n = NULL", {
	for (cls in c("DesignSeqOneByOneKK14", "DesignSeqOneByOneKK21", "DesignSeqOneByOneKK21stepwise")) {
		set.seed(20261118L)
		n = 40L
		X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
		des = get(cls)$new(response_type = "continuous", verbose = FALSE)
		expect_false(des$is_fixed_sample_size())
		expect_no_error(enroll_seq(des, X))
		w = des$get_w()
		expect_length(w, n)
		expect_true(all(w %in% c(0, 1)), info = cls)
		m = des$.__enclos_env__$private$m
		expect_length(m, n)
		expect_true(any(m > 0), info = paste(cls, "forms at least one match"))
		# Burn-in without n: no subject is matched on arrival before the model matrix exists
		# (t <= p + 2 = 4); the later member of every pair arrives after that.
		expect_true(all(tapply(seq_len(n)[m > 0], m[m > 0], max) > 4L), info = cls)
		y = X$x1 + w + rnorm(n, sd = 0.5)
		for (i in seq_len(n)) des$add_one_subject_response(i, y[i])
		expect_true(des$check_experiment_completed())
		est = InferenceContinKKOLSOneLik$new(des, verbose = FALSE)$compute_estimate()
		expect_true(is.finite(est), info = cls)
	}
})

test_that("KK14 with a fixed n keeps the t_0_pct burn-in", {
	set.seed(1L)
	n = 40L
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	des = DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	enroll_seq(des, X)
	m = des$.__enclos_env__$private$m
	# Every pair is closed by a subject arriving after t_0_pct * n = 14.
	expect_true(any(m > 0))
	expect_true(all(tapply(seq_len(n)[m > 0], m[m > 0], max) > 14L))
})

test_that("an n = NULL sequential design is analyzable once every enrolled subject has a response", {
	set.seed(7L)
	n = 20L
	X = data.frame(x1 = rnorm(n))
	y = rnorm(n)
	set.seed(99L)
	des_open = DesignSeqOneByOneEfron$new(response_type = "continuous", verbose = FALSE)
	enroll_seq(des_open, X)
	for (i in seq_len(n - 1L)) des_open$add_one_subject_response(i, y[i])
	expect_false(des_open$check_experiment_completed())
	expect_error(InferenceAllSimpleAverageDiff$new(des_open), "incomplete")
	des_open$add_one_subject_response(n, y[n])
	expect_true(des_open$check_experiment_completed())
	expect_no_error(des_open$assert_all_subjects_arrived())

	# Same seed with n fixed: same assignments, so the same estimate.
	set.seed(99L)
	des_fixed = DesignSeqOneByOneEfron$new(n = n, response_type = "continuous", verbose = FALSE)
	enroll_seq(des_fixed, X)
	for (i in seq_len(n)) des_fixed$add_one_subject_response(i, y[i])
	expect_identical(des_open$get_w(), des_fixed$get_w())
	expect_equal(
		InferenceAllSimpleAverageDiff$new(des_open)$compute_estimate(),
		InferenceAllSimpleAverageDiff$new(des_fixed)$compute_estimate()
	)
	expect_true(is.finite(InferenceContinOLS$new(des_open)$compute_asymp_two_sided_pval()))
})

test_that("a Bernoulli design with n = NULL bootstraps", {
	# The design's bootstrap index drawer used private$n, NULL here ("Expecting a single value").
	# (Other sequential designs refuse the nonparametric bootstrap by design.)
	set.seed(11L)
	n = 30L
	des = DesignSeqOneByOneBernoulli$new(response_type = "continuous", verbose = FALSE)
	enroll_seq(des, data.frame(x1 = rnorm(n)))
	for (i in seq_len(n)) des$add_one_subject_response(i, rnorm(1))
	ci = InferenceAllSimpleAverageDiff$new(des)$compute_bootstrap_confidence_interval(B = 101, type = "percentile")
	expect_true(all(is.finite(ci)))
})

test_that("with n = NULL responses may be added in any order", {
	set.seed(3L)
	des = DesignSeqOneByOneBernoulli$new(response_type = "continuous", verbose = FALSE)
	enroll_seq(des, data.frame(x1 = rnorm(5)))
	expect_no_error(des$add_one_subject_response(3, 30))
	expect_identical(des$get_y(), c(NA, NA, 30))
	expect_false(des$check_experiment_completed())
	for (i in c(5, 1, 4, 2)) des$add_one_subject_response(i, 10 * i)
	expect_identical(des$get_y(), c(10, 20, 30, 40, 50))
	expect_true(des$check_experiment_completed())
	expect_error(des$add_one_subject_response(6, 60), "subject 6")
})

test_that("with n = NULL a not-yet-arrived subject is refused even with asserts off", {
	old = options(edi.run_asserts = FALSE)
	on.exit(options(old), add = TRUE)
	des = DesignSeqOneByOneBernoulli$new(response_type = "continuous", verbose = FALSE)
	enroll_seq(des, data.frame(x1 = rnorm(3)))
	expect_error(des$add_one_subject_response(5, 1), "only 3 subject")
	des$add_one_subject_response(2, 1)
	expect_identical(des$get_y(), c(NA, 1))
})

test_that("with n = NULL censored survival responses may be added out of order", {
	set.seed(4L)
	des = DesignSeqOneByOneBernoulli$new(response_type = "survival", verbose = FALSE)
	enroll_seq(des, data.frame(x1 = rnorm(4)))
	des$add_one_subject_response(4, y_L = 2, y_R = Inf)
	des$add_one_subject_response(2, y = 1.5)
	expect_identical(des$get_y(), c(NA, 1.5, NA, NA))
	expect_identical(des$get_y_L(), c(NA, NA, NA, 2))
	expect_identical(des$get_y_R(), c(NA, NA, NA, Inf))
	des$add_one_subject_response(1, y = 3)
	des$add_one_subject_response(3, y_L = 0.5, y_R = 1)
	expect_true(des$check_experiment_completed())
	expect_identical(des$get_y_L(), c(NA, NA, 0.5, 2))
})
