library(testthat)
library(EDI)

# Four separate quantile-regression initializer call sites -- InferenceContinQuantileRegr's own
# initialize() (inference_continuous_quantile_regr.R), InferencePropQuantileRegr's own initialize()
# (inference_proportion_quantile_regr.R), and the two shared KK free-function helpers
# .init_kk_quantile_regr_ivwc()/.init_kk_quantile_regr_one_lik() (inference_all_KK_quantile_regr_ivwc_
# abstract.R / _one_lik_abstract.R, covering InferenceContinKKQuantileRegrIVWC/InferencePropKKQuantileRegrIVWC
# and InferenceContinKKQuantileRegrOneLik/InferencePropKKQuantileRegrOneLik) -- each independently guard
# on `check_package_installed("quantreg")` before proceeding, all raising the identical message
# "Package 'quantreg' is required. Please install it with install.packages(\"quantreg\")." A
# codebase-wide grep confirmed this exact message had zero test references anywhere, despite all 6
# concrete classes using it being otherwise extensively tested elsewhere (weighted-refit reference
# files, migration-golden files, the tau-boundary guard covered last iteration in
# test-kk-quantile-regr-ivwc-onelik-init-tau-boundary-and-fixed-binary-match-design-reference.R) --
# every existing reference runs with the real quantreg package actually installed (a hard Imports
# dependency, so always present in CI), so the "package unavailable" branch was never exercised on any
# of the 4 call sites. Reached via with_mocked_bindings(check_package_installed = function(...) FALSE,
# .package = "EDI"), the same established pattern used for the analogous nbpMatching/glmmTMB guards
# elsewhere in this suite.

test_that("InferenceContinQuantileRegr errors with the documented message when quantreg is (mocked as) unavailable", {
	set.seed(1L)
	n <- 20L
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(rnorm(n) + 0.5 * w)

	with_mocked_bindings(
		check_package_installed = function(...) FALSE,
		.package = "EDI",
		code = {
			expect_error(
				InferenceContinQuantileRegr$new(des, verbose = FALSE),
				"Package 'quantreg' is required. Please install it with install.packages(\"quantreg\").",
				fixed = TRUE
			)
		}
	)
})

test_that("InferencePropQuantileRegr errors with the documented message when quantreg is (mocked as) unavailable", {
	set.seed(2L)
	n <- 20L
	des <- DesignFixedBernoulli$new(n = n, response_type = "proportion", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(plogis(rnorm(n) + 0.5 * w))

	with_mocked_bindings(
		check_package_installed = function(...) FALSE,
		.package = "EDI",
		code = {
			expect_error(
				InferencePropQuantileRegr$new(des, verbose = FALSE),
				"Package 'quantreg' is required. Please install it with install.packages(\"quantreg\").",
				fixed = TRUE
			)
		}
	)
})

test_that("InferenceContinKKQuantileRegrIVWC and InferenceContinKKQuantileRegrOneLik both error with the same documented message when quantreg is (mocked as) unavailable", {
	set.seed(3L)
	n <- 20L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	for (i in seq_len(n)) {
		x <- data.frame(x1 = rnorm(1))
		w <- des$add_one_subject_to_experiment_and_assign(x)
		des$add_one_subject_response(i, 0.4 * w + rnorm(1))
	}

	with_mocked_bindings(
		check_package_installed = function(...) FALSE,
		.package = "EDI",
		code = {
			expect_error(
				InferenceContinKKQuantileRegrIVWC$new(des, verbose = FALSE),
				"Package 'quantreg' is required. Please install it with install.packages(\"quantreg\").",
				fixed = TRUE
			)
			expect_error(
				InferenceContinKKQuantileRegrOneLik$new(des, verbose = FALSE),
				"Package 'quantreg' is required. Please install it with install.packages(\"quantreg\").",
				fixed = TRUE
			)
		}
	)
})

test_that("construction succeeds normally when quantreg is not mocked as unavailable", {
	set.seed(4L)
	n <- 20L
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(rnorm(n) + 0.5 * w)
	expect_no_error(InferenceContinQuantileRegr$new(des, verbose = FALSE))
})
