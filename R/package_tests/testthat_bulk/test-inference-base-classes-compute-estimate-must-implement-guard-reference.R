library(testthat)
library(EDI)

# Two sibling compute_estimate() stubs -- inference_all_abstract.R's base Inference class and
# inference_all_abstract_asymp.R's InferenceAsymp (which overrides the same method) -- both stop()
# "Must be implemented by concrete class." Unlike Design/DesignFixed/DesignSeqOneByOne, there is no
# registry-level abstract-instantiation guard on the Inference side, so both classic R6 generators
# are directly instantiable and the stub is reachable simply by constructing them and calling
# compute_estimate(). Zero test references anywhere for either occurrence.

fx <- function(seed = 1L, n = 10L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n))
	des
}

test_that("the base Inference class's own compute_estimate() errors with the documented message", {
	Inference <- getFromNamespace("Inference", "EDI")
	inf <- Inference$new(fx(seed = 1L), verbose = FALSE)
	expect_error(
		inf$compute_estimate(),
		"Must be implemented by concrete class\\."
	)
})

test_that("InferenceAsymp's own compute_estimate() errors with the documented message", {
	InferenceAsymp <- getFromNamespace("InferenceAsymp", "EDI")
	inf <- InferenceAsymp$new(fx(seed = 2L), verbose = FALSE)
	expect_error(
		inf$compute_estimate(),
		"Must be implemented by concrete class\\."
	)
})

test_that("a real concrete class overrides compute_estimate and returns a finite value", {
	inf <- InferenceContinLin$new(fx(seed = 3L), verbose = FALSE)
	est <- inf$compute_estimate()
	expect_true(is.finite(est))
})
