library(testthat)
library(EDI)

# InferenceExtExchangeableResamplingUnits$get_exchangeable_units("pair"/"matched_set"): two error guards on the
# matching-structure branch had no test calling them, though this shared extension's cluster/block branches and
# resolve_resampling_size() bounds are otherwise exhaustively covered elsewhere. (1) a design whose private
# environment has no init_matching_bootstrap_structure() function at all -- e.g. a non-matching design explicitly
# asked for "pair"/"matched_set" units, bypassing the usual auto-detected unit type -- errors with "Matching
# structure is unavailable for resampling.". (2) a matching-capable design whose init function runs but leaves
# both boot_pair_rows and boot_i_reservoir empty errors with "Matching structure has no exchangeable units.".

test_that("a design with no init_matching_bootstrap_structure() function errors when 'pair'/'matched_set' units are explicitly requested", {
	set.seed(1); n <- 30L
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n))); des$assign_w_to_all_subjects()
	w <- des$get_w(); des$add_all_subject_responses(rnorm(n) + 0.5 * w)
	inf <- InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	expect_false(is.function(p$des_obj_priv_int$init_matching_bootstrap_structure))
	expect_error(p$get_exchangeable_units("pair"), "Matching structure is unavailable for resampling\\.")
	expect_error(p$get_exchangeable_units("matched_set"), "Matching structure is unavailable for resampling\\.")
})

test_that("a matching-capable design whose init function produces no pairs or reservoir errors with the 'no exchangeable units' message", {
	set.seed(6); np <- 5L; ns <- 3L; n <- 2L * np + ns
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n)); for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	des$add_all_subject_responses(rnorm(n))
	inf <- InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	des_priv <- p$des_obj_priv_int
	expect_true(is.function(des_priv$init_matching_bootstrap_structure))
	unlockBinding("init_matching_bootstrap_structure", des_priv)
	des_priv$init_matching_bootstrap_structure <- function() {
		des_priv$boot_pair_rows <- NULL
		des_priv$boot_i_reservoir <- NULL
	}
	expect_error(p$get_exchangeable_units("pair"), "Matching structure has no exchangeable units\\.")
})

test_that("the ordinary (unstubbed) matching path succeeds and reports both pair and reservoir units", {
	set.seed(6); np <- 5L; ns <- 3L; n <- 2L * np + ns
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n)); for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	des$add_all_subject_responses(rnorm(n))
	inf <- InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	ui <- p$get_exchangeable_units("pair")
	expect_identical(ui$unit_type, "pair")
	expect_equal(ui$n_units, length(ui$units))
	expect_true(all(ui$unit_kind %in% c("pair", "reservoir")))
	expect_gt(ui$n_units, 0L)
})
