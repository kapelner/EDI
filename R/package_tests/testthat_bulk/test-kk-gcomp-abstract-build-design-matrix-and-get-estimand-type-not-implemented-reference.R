library(testthat)
library(EDI)

# InferenceIncidKKGCompAbstract's build_design_matrix() and get_estimand_type() are declared
# abstract at the base (stop(class(self)[1], " must implement <name>().")), overridden by its two
# concrete leaves (InferenceIncidKKGCompRiskDiff, InferenceIncidKKGCompRiskRatio -- both
# extensively tested elsewhere this session), but the base's own not-implemented guards are never
# triggered through either and had zero test references anywhere. InferenceIncidKKGCompAbstract
# is a real, directly-instantiable classic R6 generator (inherit = InferenceAbstractKKMarginalIncid,
# harvested as a component source rather than deleted, per that migration's own golden-test
# header comment), so the guards are reachable simply by constructing the base class itself.

make_kk_gcomp_fixture <- function() {
	set.seed(1); n <- 20L
	x <- rnorm(n)
	des <- DesignFixedBinaryMatch$new(n = n, response_type = "incidence", m = rep(seq_len(n / 2L), each = 2L), verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	w <- rep(c(0, 1), n / 2L)
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(rbinom(n, 1, plogis(-0.5 + w + 0.4 * x)))
	des
}

test_that("InferenceIncidKKGCompAbstract's own build_design_matrix()/get_estimand_type() stop with the not-implemented message", {
	inf <- EDI:::InferenceIncidKKGCompAbstract$new(make_kk_gcomp_fixture(), verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	expect_error(priv$build_design_matrix(), "InferenceIncidKKGCompAbstract must implement build_design_matrix\\(\\)\\.")
	expect_error(priv$get_estimand_type(), "InferenceIncidKKGCompAbstract must implement get_estimand_type\\(\\)\\.")
})

test_that("each concrete descendant overrides both guards with its own fixed estimand type", {
	des <- make_kk_gcomp_fixture()
	rd <- InferenceIncidKKGCompRiskDiff$new(des, verbose = FALSE)
	expect_identical(rd$.__enclos_env__$private$get_estimand_type(), "RD")
	expect_no_error(rd$.__enclos_env__$private$build_design_matrix())

	rr <- InferenceIncidKKGCompRiskRatio$new(des, verbose = FALSE)
	expect_identical(rr$.__enclos_env__$private$get_estimand_type(), "RR")
	expect_no_error(rr$.__enclos_env__$private$build_design_matrix())
})
