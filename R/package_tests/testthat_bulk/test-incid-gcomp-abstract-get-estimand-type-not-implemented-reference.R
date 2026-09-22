library(testthat)
library(EDI)

# InferenceIncidGCompAbstract's get_estimand_type() is declared abstract at the base
# (stop(class(self)[1], " must implement get_estimand_type().")), overridden by its two concrete
# leaves (InferenceIncidGCompRiskDiff: "RD", InferenceIncidGCompRiskRatio: "RR") -- both
# extensively tested elsewhere this session, but the base's own not-implemented guard is never
# triggered through either and had zero test references anywhere. InferenceIncidGCompAbstract is
# deliberately left as a real, directly-instantiable classic R6 generator (per the sibling KK
# gcomp migration-golden test's own header comment: harvested as a component source, not deleted),
# so the guard is reachable simply by constructing the base class itself.

test_that("InferenceIncidGCompAbstract's own get_estimand_type() stops with the not-implemented message", {
	set.seed(1); n <- 20L
	X <- data.frame(x1 = rnorm(n))
	d <- DesignFixedBernoulli$new(response_type = "incidence", n = n, seed = 1L, verbose = FALSE)
	d$add_all_subjects_to_experiment(X); d$assign_w_to_all_subjects()
	w <- d$get_w()
	d$add_all_subject_responses(rbinom(n, 1, plogis(-0.3 + 0.8 * w)))

	inf <- EDI:::InferenceIncidGCompAbstract$new(d, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	expect_error(priv$get_estimand_type(), "InferenceIncidGCompAbstract must implement get_estimand_type\\(\\)\\.")
})

test_that("each concrete descendant overrides the guard with its own fixed estimand type", {
	set.seed(2); n <- 20L
	X <- data.frame(x1 = rnorm(n))
	d <- DesignFixedBernoulli$new(response_type = "incidence", n = n, seed = 1L, verbose = FALSE)
	d$add_all_subjects_to_experiment(X); d$assign_w_to_all_subjects()
	w <- d$get_w()
	d$add_all_subject_responses(rbinom(n, 1, plogis(-0.3 + 0.8 * w)))

	rd <- InferenceIncidGCompRiskDiff$new(d, verbose = FALSE)
	expect_identical(rd$.__enclos_env__$private$get_estimand_type(), "RD")

	rr <- InferenceIncidGCompRiskRatio$new(d, verbose = FALSE)
	expect_identical(rr$.__enclos_env__$private$get_estimand_type(), "RR")
})
