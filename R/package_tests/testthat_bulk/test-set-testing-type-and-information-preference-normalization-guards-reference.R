library(testthat)
library(EDI)

# InferenceAsympLik's private normalize_testing_type()/normalize_information_preference()
# (inference_all_abstract_asymp_lik.R:513-546), called by the public set_testing_type()/
# set_information_preference() setters, each end their switch()-based alias-normalization
# with a bare stop() default arm listing the legal values: "testing_type must be one of:
# wald, score, gradient, lik_ratio, lik_ratio_bartlett_approx, lik_ratio_bartlett_exact" and
# "information_preference must be one of: auto, fisher, observed". Distinct from the
# downstream "<class> does not support testing_type = ..." guard (which fires only for a
# syntactically-legal value the concrete class doesn't itself support, and is well covered
# elsewhere) -- this is the syntax-level guard for a value that isn't even one of the
# recognized aliases. A codebase-wide grep confirmed both exact messages had zero test
# references anywhere. Exercised via the plain public API (set_testing_type()/
# set_information_preference()), no mocking needed.

fx <- function() {
	set.seed(1)
	n <- 20L
	des <- DesignFixedBernoulli$new(n = n, response_type = "count", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rpois(n, 3))
	InferenceCountNegBin$new(des, verbose = FALSE)
}

test_that("set_testing_type() rejects an unrecognized value with the documented alias list", {
	inf <- fx()
	expect_error(
		inf$set_testing_type("bogus_type"),
		"testing_type must be one of: wald, score, gradient, lik_ratio, lik_ratio_bartlett_approx, lik_ratio_bartlett_exact",
		fixed = TRUE
	)
})

test_that("set_information_preference() rejects an unrecognized value with the documented alias list", {
	inf <- fx()
	expect_error(
		inf$set_information_preference("bogus_pref"),
		"information_preference must be one of: auto, fisher, observed",
		fixed = TRUE
	)
})

test_that("a legal alias for each normalizes without error (contrast against the guards above)", {
	inf <- fx()
	expect_silent(inf$set_testing_type("lrt"))
	expect_identical(inf$.__enclos_env__$private$testing_type, "lik_ratio")
	expect_silent(inf$set_information_preference("obs"))
	expect_identical(inf$.__enclos_env__$private$information_preference, "observed")
})
