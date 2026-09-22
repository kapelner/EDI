library(testthat)
library(EDI)

# InferenceCountZeroAugmentedPoissonAbstract's za_family()/za_description() are declared abstract
# at the base (stop(class(self)[1], " must implement za_family()/za_description()")), overridden
# by each of its three concrete descendants (InferenceCountHurdlePoisson,
# InferenceCountZeroInflatedPoisson, InferenceCountZeroInflatedNegBin) -- all of which have
# dedicated family-descriptor test coverage (test-zero-inflated-count-family-descriptors-and-
# bootstrap-fallback-reference.R), but the base's own not-implemented guards are never triggered
# through any of them and had zero test references anywhere. Since the abstract is built via
# define_inference_class(inherit = Inference, ...) it is directly instantiable, so the guards are
# reachable simply by constructing the base class itself.

test_that("InferenceCountZeroAugmentedPoissonAbstract's own za_family()/za_description() stop with the not-implemented message", {
	set.seed(1); n <- 20L
	des <- DesignFixedBernoulli$new(n = n, response_type = "count", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(rpois(n, exp(0.5 + 0.5 * w)))

	inf <- EDI:::InferenceCountZeroAugmentedPoissonAbstract$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	expect_error(priv$za_family(), "InferenceCountZeroAugmentedPoissonAbstract must implement za_family\\(\\)\\.")
	expect_error(priv$za_description(), "InferenceCountZeroAugmentedPoissonAbstract must implement za_description\\(\\)\\.")
})

test_that("each concrete descendant overrides both guards with its own fixed family/description", {
	set.seed(2); n <- 20L
	des <- DesignFixedBernoulli$new(n = n, response_type = "count", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(rpois(n, exp(0.5 + 0.5 * w)))

	hurdle <- InferenceCountHurdlePoisson$new(des, verbose = FALSE)
	expect_identical(hurdle$.__enclos_env__$private$za_description(), "Hurdle Poisson")
	expect_no_error(hurdle$.__enclos_env__$private$za_family())

	zip <- InferenceCountZeroInflatedPoisson$new(des, verbose = FALSE)
	expect_identical(zip$.__enclos_env__$private$za_description(), "Zero-Inflated Poisson")
	expect_no_error(zip$.__enclos_env__$private$za_family())
})
