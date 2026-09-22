library(testthat)
library(EDI)

# InferenceAbstractKKModifiedPoisson's build_design_matrix() is declared abstract at the base
# (stop(class(self)[1], " must implement build_design_matrix().")), overridden by its concrete
# leaf InferenceIncidKKModifiedPoisson (which just delegates to private$create_design_matrix()) --
# extensively tested elsewhere this session -- but the base's own not-implemented guard is never
# triggered through it and had zero test references anywhere. InferenceAbstractKKModifiedPoisson
# is a real, directly-instantiable classic R6 generator (inherit = InferenceAbstractKKMarginalIncid),
# so the guard is reachable simply by constructing the base class itself.

test_that("InferenceAbstractKKModifiedPoisson's own build_design_matrix() stops with the not-implemented message", {
	set.seed(1); n <- 20L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	des$add_all_subject_responses(rbinom(n, 1, plogis(0.3 * w)))

	inf <- EDI:::InferenceAbstractKKModifiedPoisson$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	expect_error(priv$build_design_matrix(), "InferenceAbstractKKModifiedPoisson must implement build_design_matrix\\(\\)\\.")
})

test_that("InferenceIncidKKModifiedPoisson overrides the guard, delegating to create_design_matrix()", {
	set.seed(2); n <- 20L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	des$add_all_subject_responses(rbinom(n, 1, plogis(0.3 * w)))

	inf <- InferenceIncidKKModifiedPoisson$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	expect_equal(priv$build_design_matrix(), priv$create_design_matrix())
})
