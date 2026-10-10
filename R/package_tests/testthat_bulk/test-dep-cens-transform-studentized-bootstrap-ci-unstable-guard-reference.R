library(testthat)
library(EDI)

dep_cens_fixture <- function(seed = 2L, n = 30L) {
	set.seed(seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n))); des$assign_w_to_all_subjects()
	w <- des$get_w(); des$add_all_subject_responses(rexp(n, exp(0.4 * w)))
	InferenceSurvivalDepCensTransformRegr$new(des, verbose = FALSE)
}

test_that("studentized bootstrap CI preserves a finite basic interval", {
	inf <- dep_cens_fixture()
	unlockBinding("compute_bootstrap_confidence_interval_basic", inf)
	inf$compute_bootstrap_confidence_interval_basic <- function(...) c(`2.5%` = 1, `97.5%` = 2)
	expect_identical(inf$compute_bootstrap_confidence_interval_studentized(alpha = 0.05), c(`2.5%` = 1, `97.5%` = 2))
})

test_that("studentized bootstrap CI remains unavailable after genuine basic-CI failure", {
	inf <- dep_cens_fixture(seed = 3L)
	unlockBinding("compute_bootstrap_confidence_interval_basic", inf)
	inf$compute_bootstrap_confidence_interval_basic <- function(...) stop("boom")
	expect_true(all(is.na(inf$compute_bootstrap_confidence_interval_studentized(alpha = 0.05))))
})
