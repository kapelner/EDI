library(testthat)
library(EDI)

# InferenceAsympLikStdModCache's shared() (inference_all_abstract_asymp_lik_std_mod_cache.R --
# spliced into every "StandardModelCache" host, reached here through InferencePropFractionalLogit,
# a direct non-IVWC composer) has a guard distinct from the sibling "model_fit_unavailable" guard
# (generate_mod() returns NULL entirely): when generate_mod() returns a non-NULL model_output but
# its beta_hat_T (or, absent that field, b[2]) is non-finite, shared() caches
# "model_treatment_estimate_unavailable". This had no test reference anywhere. Reached by mocking
# generate_mod() (unlockBinding, private) to return a well-formed-looking model_output list whose
# treatment coefficient is explicitly NA.

frac_fixture <- function(seed = 1L, n = 40L) {
	set.seed(seed)
	x <- rnorm(n)
	des <- DesignFixediBCRD$new(n = n, response_type = "proportion", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- pmin(pmax(plogis(0.3 * w + 0.5 * x + rnorm(n, sd = 0.5)), 0.02), 0.98)
	des$add_all_subject_responses(y)
	InferencePropFractionalLogit$new(des, verbose = FALSE)
}

test_that("shared() caches 'model_treatment_estimate_unavailable' when generate_mod()'s beta_hat_T/b[2] is non-finite", {
	inf <- frac_fixture()
	p <- inf$.__enclos_env__$private
	unlockBinding("generate_mod", p)
	p$generate_mod <- function(estimate_only = FALSE) {
		list(b = c(0.3, NA_real_), fisher_information = diag(2))
	}

	res <- inf$compute_estimate()
	expect_true(is.na(res))
	expect_identical(inf$get_nonestimable_reason(), "model_treatment_estimate_unavailable")
	expect_true(is.na(p$cached_values$df))
})

test_that("shared() also fires when beta_hat_T is explicitly non-finite despite a finite b[2]", {
	inf <- frac_fixture(seed = 2L)
	p <- inf$.__enclos_env__$private
	unlockBinding("generate_mod", p)
	p$generate_mod <- function(estimate_only = FALSE) {
		list(beta_hat_T = NaN, b = c(0.3, 0.5), fisher_information = diag(2))
	}

	res <- inf$compute_estimate()
	expect_true(is.na(res))
	expect_identical(inf$get_nonestimable_reason(), "model_treatment_estimate_unavailable")
})
