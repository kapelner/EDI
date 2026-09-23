library(testthat)
library(EDI)

# InferenceMLEorKMSummaryTable (inference_all_abstract_mle_or_KM_summary_table.R) is the shared base
# for many concrete MLE/KM-summary-table classes (InferenceContinOLS, InferenceSurvivalCoxPH, hurdle/
# zero-augmented count classes, etc.), but its OWN dispatch logic -- extract_vcov()'s two extraction
# paths, shared()'s treatment-coefficient-name fallback and caching, and its two explicit stop()
# guards -- had no direct test reference anywhere (confirmed via grep; the concrete-class test files
# that mention it only assert on inheritance/method-name contracts or note the class's NA-on-failure
# behavior in passing, never construct a controlled generate_mod() fixture to exercise these branches
# directly). Every concrete class's own generate_mod() supplies a real, well-behaved fitted model with
# a "treatment"-named coefficient, so these branches are never actually hit in practice by any single
# concrete class's own tests. Exercised here via a minimal FakeMLESummaryTable subclass that overrides
# only generate_mod() to return a controlled model_output fixture, per the file's own "must implement
# generate_mod()" contract.
#   1. extract_vcov(): a model_output whose class is literally "list" (Rcpp-backed models) skips
#      stats::vcov() entirely and reads $vcov directly.
#   2. extract_vcov(): a model_output with a real S3 vcov() method (e.g. lm) uses stats::vcov()
#      exactly, matching an independent vcov(fit) call.
#   3. extract_vcov(): a model_output with NO usable vcov() method (an unclassed-into-"list" object
#      whose class has no registered vcov method) falls back to reading $vcov after the tryCatch.
#   4. shared(): the treatment coefficient is read from "treatment" when present regardless of
#      position; when absent, it falls back to the LAST coefficient by position.
#   5. shared(): caching -- generate_mod() is called at most once across repeated estimate-only and
#      full calls (cached_mod reuse); estimate-only short-circuits before the vcov/summary-table pass.
#   6. shared(): the summary table's z-value and two-sided p-value match an independently
#      hand-computed z = beta/se, p = 2*pnorm(-|z|).
#   7. shared()'s two explicit stop() guards: a NULL $coefficients from generate_mod(), and a
#      model_output extract_vcov() can't get a vcov matrix from at all.
#   8. get_standard_error() returns NA_real_ when the cached SE isn't a length-1 value.
#   9. compute_asymp_two_sided_pval(delta != 0) is a documented TO-DO stub that errors (source note,
#      not a bug -- unimplemented on purpose).

FakeMLE <- R6::R6Class("FakeMLESummaryTable",
	inherit = EDI:::InferenceMLEorKMSummaryTable,
	lock_objects = FALSE,
	private = list(
		fake_model = NULL,
		generate_mod_calls = 0L,
		generate_mod = function(estimate_only = FALSE) {
			private$generate_mod_calls <- private$generate_mod_calls + 1L
			private$fake_model
		}
	),
	parent_env = asNamespace("EDI")
)

mle_fixture <- function(seed = 1L, n = 20L) {
	set.seed(seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n))
	FakeMLE$new(des_obj = des, verbose = FALSE)
}

test_that("extract_vcov(): a model_output whose class is literally \"list\" reads $vcov directly, skipping stats::vcov() entirely", {
	inf <- mle_fixture(1L)
	priv <- inf$.__enclos_env__$private
	vcov_mat <- matrix(c(0.1, 0.02, 0.02, 0.2), 2, 2, dimnames = list(c("a", "treatment"), c("a", "treatment")))
	model_output <- list(coefficients = c(a = 1, treatment = 2), vcov = vcov_mat)
	expect_identical(class(model_output), "list")
	expect_identical(priv$extract_vcov(model_output), vcov_mat)
})

test_that("extract_vcov(): a model_output with a real S3 vcov() method uses stats::vcov() exactly", {
	inf <- mle_fixture(2L)
	priv <- inf$.__enclos_env__$private
	fit <- lm(y ~ x, data = data.frame(x = 1:20, y = 1:20 + rnorm(20)))
	expect_false(identical(class(fit), "list"))
	expect_equal(priv$extract_vcov(fit), as.matrix(vcov(fit)))
})

test_that("extract_vcov(): a model_output with no usable vcov() method falls back to $vcov after the tryCatch", {
	inf <- mle_fixture(3L)
	priv <- inf$.__enclos_env__$private
	vcov_mat <- matrix(c(0.3, 0, 0, 0.4), 2, 2, dimnames = list(c("a", "treatment"), c("a", "treatment")))
	model_output <- structure(list(coefficients = c(a = 1, treatment = 2), vcov = vcov_mat), class = "not_a_real_model_class_edi_test")
	expect_error(stats::vcov(model_output))                                         # confirms no registered vcov method exists
	expect_identical(priv$extract_vcov(model_output), vcov_mat)
})

test_that("shared(): the treatment coefficient is read from \"treatment\" when present regardless of position, else falls back to the LAST coefficient by position", {
	inf1 <- mle_fixture(4L)
	priv1 <- inf1$.__enclos_env__$private
	priv1$fake_model <- list(
		coefficients = c(treatment = 2.5, a = 1, b = 0.5),                          # "treatment" not last
		vcov = diag(c(0.1, 0.2, 0.3), 3, 3, names = TRUE)
	)
	dimnames(priv1$fake_model$vcov) <- list(names(priv1$fake_model$coefficients), names(priv1$fake_model$coefficients))
	expect_equal(inf1$compute_estimate(), 2.5)

	inf2 <- mle_fixture(5L)
	priv2 <- inf2$.__enclos_env__$private
	priv2$fake_model <- list(
		coefficients = c(a = 1, b = 0.5, some_other_name = 7.25),                   # no "treatment" -> falls back to last
		vcov = diag(c(0.1, 0.2, 0.3), 3, 3)
	)
	dimnames(priv2$fake_model$vcov) <- list(names(priv2$fake_model$coefficients), names(priv2$fake_model$coefficients))
	expect_equal(inf2$compute_estimate(), 7.25)
})

test_that("shared(): generate_mod() is called at most once across repeated estimate-only and full calls; estimate-only short-circuits before the vcov/summary-table pass", {
	inf <- mle_fixture(6L)
	priv <- inf$.__enclos_env__$private
	priv$fake_model <- list(
		coefficients = c(a = 1, treatment = 2),
		vcov = matrix(c(0.1, 0, 0, 0.2), 2, 2, dimnames = list(c("a", "treatment"), c("a", "treatment")))
	)
	priv$shared(estimate_only = TRUE)
	expect_equal(priv$generate_mod_calls, 1L)
	expect_null(priv$cached_values$summary_table)                                   # not built yet

	priv$shared(estimate_only = TRUE)                                               # cached beta_hat_T short-circuits
	expect_equal(priv$generate_mod_calls, 1L)

	priv$shared(estimate_only = FALSE)                                              # now builds the full summary table
	expect_equal(priv$generate_mod_calls, 1L)                                       # cached_mod reused, not refit
	expect_false(is.null(priv$cached_values$summary_table))

	priv$shared(estimate_only = FALSE)
	expect_equal(priv$generate_mod_calls, 1L)
})

test_that("shared(): the summary table's z-value and two-sided p-value match an independently hand-computed z = beta/se, p = 2*pnorm(-|z|)", {
	inf <- mle_fixture(7L)
	priv <- inf$.__enclos_env__$private
	vcov_mat <- matrix(c(0.16, 0.0, 0.0, 0.25), 2, 2, dimnames = list(c("a", "treatment"), c("a", "treatment")))
	priv$fake_model <- list(coefficients = c(a = -1, treatment = 3), vcov = vcov_mat)

	priv$shared(estimate_only = FALSE)
	tbl <- priv$cached_values$summary_table
	se_treat <- sqrt(vcov_mat["treatment", "treatment"])
	z_treat <- 3 / se_treat
	expect_equal(tbl["treatment", "Std. Error"], se_treat)
	expect_equal(tbl["treatment", "z value"], z_treat)
	expect_equal(tbl["treatment", "Pr(>|z|)"], 2 * pnorm(-abs(z_treat)))
	expect_equal(priv$get_standard_error(), se_treat)
	expect_equal(inf$compute_asymp_two_sided_pval(0), 2 * pnorm(-abs(z_treat)))
})

test_that("shared()'s two explicit stop() guards fire with a message naming the class", {
	no_coef <- mle_fixture(8L)
	priv_no_coef <- no_coef$.__enclos_env__$private
	priv_no_coef$fake_model <- list(coefficients = NULL, vcov = diag(2))
	expect_error(priv_no_coef$shared(estimate_only = TRUE), "coefficients.*is NULL.*generate_mod.*FakeMLESummaryTable")

	no_vcov <- mle_fixture(9L)
	priv_no_vcov <- no_vcov$.__enclos_env__$private
	priv_no_vcov$fake_model <- list(coefficients = c(a = 1, treatment = 2))         # no $vcov field at all, not class "list"-only issue
	class(priv_no_vcov$fake_model) <- "not_a_real_model_class_edi_test_2"
	expect_error(priv_no_vcov$shared(estimate_only = FALSE), "[Cc]ould not extract vcov.*FakeMLESummaryTable")
})

test_that("get_standard_error() returns NA_real_ when the cached SE isn't a length-1 value", {
	inf <- mle_fixture(10L)
	priv <- inf$.__enclos_env__$private
	priv$fake_model <- list(
		coefficients = c(a = 1, treatment = 2),
		vcov = matrix(c(0.1, 0, 0, 0.2), 2, 2, dimnames = list(c("a", "treatment"), c("a", "treatment")))
	)
	priv$shared(estimate_only = FALSE)                                              # populate the cache validly first

	priv$cached_values$s_beta_hat_T <- NULL
	expect_true(is.na(priv$get_standard_error()))                                   # shared() short-circuits (summary_table cached); reads the corrupted cache

	priv$cached_values$s_beta_hat_T <- c(1, 2)
	expect_true(is.na(priv$get_standard_error()))
})

test_that("compute_asymp_two_sided_pval(delta != 0) is a documented TO-DO stub that errors (not implemented on purpose)", {
	inf <- mle_fixture(11L)
	priv <- inf$.__enclos_env__$private
	priv$fake_model <- list(
		coefficients = c(a = 1, treatment = 2),
		vcov = matrix(c(0.1, 0, 0, 0.2), 2, 2, dimnames = list(c("a", "treatment"), c("a", "treatment")))
	)
	expect_error(inf$compute_asymp_two_sided_pval(1), "TO-DO")
})
