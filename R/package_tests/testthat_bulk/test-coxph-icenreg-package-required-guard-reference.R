library(testthat)
library(EDI)

# InferenceSurvivalCoxPHRegr$generate_mod_icen() (inference_survival_coxph.R) guards on
# assert_icenreg_installed(class(self)[1L]) (helper_package_checks.R) before dispatching to
# icenReg::ic_sp() for left-/interval-censored data. test-coxph-general-censoring-icenreg-dispatch.R
# already thoroughly covers this dispatch's actual NPMLE-fit arithmetic against an independent
# icenReg::ic_sp() reference, but always with the real icenReg package installed -- a codebase-wide
# grep confirmed the guard's own message ("Package 'icenReg' is required for <classname>. Please
# install it with install.packages(\"icenReg\").") had zero test references anywhere, so the "package
# unavailable" branch itself was never exercised. Reuses that same file's general_censoring_design()
# fixture pattern (one interval-censored subject per arm is sufficient to flip has_general_censoring()
# to TRUE and route compute_estimate() into generate_mod_icen()), reached via
# with_mocked_bindings(check_package_installed = function(...) FALSE, .package = "EDI"), the same
# established pattern used for the nbpMatching/quantreg/geepack "package unavailable" guards elsewhere
# in this suite.

general_censoring_design <- function() {
	ys    <- c(1,   NA,  NA, 2.5, NA,  NA)
	y_Ls  <- c(NA,  3,   2,  NA,  4,   3)
	y_Rs  <- c(NA,  Inf, 5,  NA,  Inf, 6)
	w <- c(0, 0, 0, 1, 1, 1)
	des <- DesignFixedBernoulli$new(n = 6L, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = seq_len(6L)))
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(ys, y_Ls, y_Rs)
	expect_true(des$has_general_censoring())
	des
}

test_that("InferenceSurvivalCoxPHRegr errors with the documented message when icenReg is (mocked as) unavailable, for general-censoring data", {
	des <- general_censoring_design()
	with_mocked_bindings(
		check_package_installed = function(...) FALSE,
		.package = "EDI",
		code = {
			inf <- InferenceSurvivalCoxPHRegr$new(des, verbose = FALSE)
			expect_error(
				inf$compute_estimate(),
				"Package 'icenReg' is required for InferenceSurvivalCoxPHRegr. Please install it with install.packages(\"icenReg\").",
				fixed = TRUE
			)
		}
	)
})

test_that("ordinary right-censored (non-general-censoring) data never reaches the icenReg guard, even with icenReg mocked as unavailable", {
	set.seed(1L)
	n <- 20L
	des <- DesignFixedBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(rexp(n, rate = exp(-0.3 * w)))
	expect_false(des$has_general_censoring())

	with_mocked_bindings(
		check_package_installed = function(...) FALSE,
		.package = "EDI",
		code = {
			inf <- InferenceSurvivalCoxPHRegr$new(des, verbose = FALSE)
			expect_no_error(inf$compute_estimate())
		}
	)
})
