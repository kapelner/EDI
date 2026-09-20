library(testthat)
library(EDI)

# Design's transform_y() (response re-coding from the original y), the small
# accessors / capability predicates (get_response_type_original, get_ordinal_
# levels, get_original_ordinal_levels, get_design_formula, is_a_bernoulli_capable),
# the assertion helpers (assert_fixed_sample, assert_all_subjects_arrived,
# assert_all_responses_recorded), warm_all_subject_data_cache(), and the
# registry-based abstract check. None had a direct test reference.

y_raw <- c(1.2, 3.4, 0.5, 7, 2, 2.2, 9, 0.1)

fixed_design <- function(response_type = "continuous", n = 8L, responses = TRUE) {
	des <- DesignFixedBernoulli$new(n = n, response_type = response_type, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = seq_len(n) + 0.5))
	des$assign_w_to_all_subjects()
	if (responses) des$add_all_subject_responses(y_raw[seq_len(n)])
	des
}

test_that("transform_y re-codes from the ORIGINAL response, keeps the original type, and records ordinal levels", {
	des <- fixed_design()
	expect_equal(des$get_response_type_original(), "continuous")
	out <- des$transform_y(function(y_original) as.integer(y_original > 2), "incidence")
	expect_equal(out, as.numeric(y_raw > 2))
	expect_equal(des$get_y(), as.numeric(y_raw > 2))
	expect_equal(des$get_response_type(), "incidence")
	expect_equal(des$get_response_type_original(), "continuous")
	expect_equal(des$get_y_original(), y_raw)

	# A second transform starts from y_original again, not from the previous transform.
	des$transform_y(function(y_original) as.integer(cut(y_original, c(-Inf, 1, 3, Inf), labels = FALSE)),
		"ordinal", c("lo", "mid", "hi"))
	expect_equal(des$get_y(), as.numeric(cut(y_raw, c(-Inf, 1, 3, Inf), labels = FALSE)))
	expect_equal(des$get_response_type(), "ordinal")
	expect_equal(des$get_ordinal_levels(), c("lo", "mid", "hi"))
	expect_null(des$get_original_ordinal_levels())

	des$transform_y(function(y_original) y_original * 2, "continuous")
	expect_equal(des$get_y(), y_raw * 2)
	expect_null(des$get_ordinal_levels())
})

test_that("transform_y validates its function, length, response type and transformed values", {
	des <- fixed_design()
	expect_error(des$transform_y(function(z) z, "count"), "first argument named 'y_original'")
	expect_error(des$transform_y(function(y_original) y_original[-1], "continuous"), "length 8")
	expect_error(des$transform_y(function(y_original) y_original * 0.5, "count"), "integerish")
	expect_error(des$transform_y(function(y_original) y_original, "bogus"))
	expect_error(des$transform_y(function(y_original) y_original, "ordinal", "only_one"))
	expect_error(des$transform_y("not a function", "continuous"))
	# Failed transforms leave the design untouched.
	expect_equal(des$get_y(), y_raw)
	expect_equal(des$get_response_type(), "continuous")
})

test_that("accessors report the design formula and stored ordinal levels", {
	des <- fixed_design()
	expect_s3_class(des$get_design_formula(), "formula")
	expect_equal(des$get_design_formula(), des$.__enclos_env__$private$design_formula)

	ord <- DesignFixedBernoulli$new(n = 4L, response_type = "ordinal", verbose = FALSE)
	ord$add_all_subjects_to_experiment(data.frame(x = 1:4))
	ord$assign_w_to_all_subjects()
	f <- factor(c("a", "b", "c", "b"), levels = c("a", "b", "c"), ordered = TRUE)
	old <- options(edi.run_asserts = FALSE); on.exit(options(old), add = TRUE)
	ord$add_all_subject_responses(f)
	expect_equal(ord$get_ordinal_levels(), c("a", "b", "c"))
	expect_equal(ord$get_original_ordinal_levels(), c("a", "b", "c"))
	expect_equal(ord$get_response_type_original(), "ordinal")
})

test_that("only Bernoulli-capable designs report is_a_bernoulli_capable", {
	expect_true(DesignFixedBernoulli$new(n = 4L, response_type = "continuous", verbose = FALSE)$is_a_bernoulli_capable())
	expect_true(DesignSeqOneByOneBernoulli$new(n = 4L, response_type = "continuous", verbose = FALSE)$is_a_bernoulli_capable())
	expect_false(DesignFixediBCRD$new(n = 4L, response_type = "continuous", verbose = FALSE)$is_a_bernoulli_capable())
	expect_false(DesignSeqOneByOneKK14$new(n = 4L, response_type = "continuous", verbose = FALSE)$is_a_bernoulli_capable())
})

test_that("assertion helpers signal only when their condition is violated", {
	fixed <- fixed_design()
	expect_silent(fixed$assert_fixed_sample())
	expect_silent(fixed$assert_all_subjects_arrived())
	expect_silent(fixed$assert_all_responses_recorded())

	seq_des <- DesignSeqOneByOneBernoulli$new(response_type = "continuous", verbose = FALSE)
	expect_error(seq_des$assert_fixed_sample(), "fixed sample")

	partial <- DesignSeqOneByOneBernoulli$new(n = 4L, response_type = "continuous", verbose = FALSE)
	for (i in 1:2) partial$add_one_subject_to_experiment_and_assign(data.frame(x = i))
	expect_error(partial$assert_all_subjects_arrived(), "haven't arrived")
	expect_error(partial$assert_all_responses_recorded(), "haven't arrived")

	no_resp <- fixed_design(responses = FALSE)
	expect_silent(no_resp$assert_all_subjects_arrived())
	expect_error(no_resp$assert_all_responses_recorded(), "responses aren't recorded")
	no_resp$add_all_subject_responses(y_raw)
	expect_silent(no_resp$assert_all_responses_recorded())

	# With assertions disabled the checks are inert.
	old <- options(edi.run_asserts = FALSE); on.exit(options(old), add = TRUE)
	expect_silent(seq_des$assert_fixed_sample())
	expect_silent(partial$assert_all_subjects_arrived())
})

test_that("warm_all_subject_data_cache does nothing without covariates; on a covariate design it errors at t = 1 (real source bug, not fixed)", {
	set.seed(3)
	n <- 10L
	plain <- DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	plain$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	plain$assign_w_to_all_subjects()
	plain$add_all_subject_responses(rnorm(n))
	priv0 <- plain$.__enclos_env__$private
	expect_false(isTRUE(priv0$uses_covariates))
	expect_false(plain$warm_all_subject_data_cache())
	expect_length(priv0$all_subject_data_cache, 0L)

	des <- DesignSeqOneByOneAtkinson$new(n = n, response_type = "continuous", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1), x2 = rnorm(1)))
	des$add_all_subject_responses(rnorm(n))
	priv <- des$.__enclos_env__$private
	expect_true(isTRUE(priv$uses_covariates))
	before <- names(priv$all_subject_data_cache)
	# SOURCE BUG (noted, not fixed): the warm-up loops t = 1..n and compute_all_
	# subject_data() names xt_prev with the kept-column names even though at very
	# small t the C++ result has no previous-row data, so the very first iteration
	# throws ("'names' attribute [2] must be the same length as the vector [0]").
	# Its only caller (the randomization setup) wraps the call in tryCatch and
	# ignores the failure, so the cache is never warmed for covariate designs.
	expect_error(des$warm_all_subject_data_cache(), "'names' attribute")
	expect_equal(priv$t, n)                         # on.exit restores the subject counter
	expect_equal(names(priv$all_subject_data_cache), before)
})

test_that("supports_resampling_by_registry_abstract_check is TRUE for concrete and unregistered classes", {
	des <- fixed_design()
	expect_true(des$.__enclos_env__$private$supports_resampling_by_registry_abstract_check())
	Custom <- R6::R6Class("UnregisteredThirdPartyDesign", inherit = DesignFixedBernoulli, lock_objects = FALSE)
	cust <- Custom$new(n = 4L, response_type = "continuous", verbose = FALSE)
	expect_true(cust$.__enclos_env__$private$supports_resampling_by_registry_abstract_check())
})
