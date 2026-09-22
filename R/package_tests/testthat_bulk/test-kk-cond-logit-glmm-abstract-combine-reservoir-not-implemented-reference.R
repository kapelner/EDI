library(testthat)
library(EDI)

# InferenceAbstractKKCondLogitGLMM's combine_reservoir_into_glmm() is declared abstract at the
# base (stop("must implement combine_reservoir_into_glmm()")), overridden by each of its three
# concrete descendants (InferenceIncidKKCondLogitGLMMIVWC: FALSE, InferenceIncidKKCondLogitGLMMOneLik:
# TRUE, InferencePropKKGLMM: TRUE) -- all of which are well-tested, but the base's own
# not-implemented guard is never triggered through any of them (each overrides it), and had zero
# test references anywhere. Since the abstract is built via define_inference_class(inherit =
# Inference, ...) it is directly instantiable (not a true R6 "abstract class"), so the guard is
# reachable simply by constructing the base class itself and calling the private method.

test_that("InferenceAbstractKKCondLogitGLMM's own combine_reservoir_into_glmm() stops with the not-implemented message", {
	set.seed(1); n <- 20L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	des$add_all_subject_responses(rbinom(n, 1, plogis(0.3 * w)))

	inf <- EDI:::InferenceAbstractKKCondLogitGLMM$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	expect_error(priv$combine_reservoir_into_glmm(), "must implement combine_reservoir_into_glmm\\(\\)")
})

test_that("the non-IVWC concrete descendant overrides the guard with its own fixed value", {
	set.seed(2); n <- 20L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	des$add_all_subject_responses(rbinom(n, 1, plogis(0.3 * w)))

	onelik <- InferenceIncidKKCondLogitGLMMOneLik$new(des, verbose = FALSE)
	expect_identical(onelik$.__enclos_env__$private$combine_reservoir_into_glmm(), TRUE)
})
