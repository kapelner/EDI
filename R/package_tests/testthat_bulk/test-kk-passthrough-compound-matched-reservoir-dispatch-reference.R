library(testthat)
library(EDI)

# InferenceMixinKKPassThroughCompound's only_matches()/only_reservoir()/
# compute_estimate_from_matched_and_reservoir() (inference_mixin_kk_passthrough_compound.R) decide
# which of a matched-pairs fit and a reservoir fit to run for a KK compound estimator. Every prior
# test reference for these three functions was a metadata existence check
# (EDI:::component_private_names(...) %in% ...), never a behavioral call -- reached here via
# InferenceBaiAdjustedTKK14, a non-IVWC concrete host of the same shared mixin (the IVWC compound
# estimators are out of scope for this suite).
#
# only_matches()/only_reservoir() read private$cached_values$KKstats directly, so their boundary
# cases are exercised by seeding that field with a synthetic KKstats list -- the same kind of
# direct-private-state injection this suite already uses for other structurally-real-but-
# not-naturally-reachable guards. compute_estimate_from_matched_and_reservoir()'s
# has_match_structure-gated nonestimable branch is exercised the same way, via
# private$has_match_structure (unlockBinding, since it's a plain field set at construction).

bai_fixture_priv <- function(n = 12L, seed = 1L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	des$add_all_subject_responses(rnorm(n) + w)
	InferenceBaiAdjustedTKK14$new(des, verbose = FALSE)$.__enclos_env__$private
}

test_that("only_matches is FALSE with no KKstats, and TRUE exactly when nRT<=1 or nRC<=1 (finite)", {
	p <- bai_fixture_priv()
	p$cached_values$KKstats <- NULL
	expect_false(p$only_matches())

	p$cached_values$KKstats <- list(nRT = 0, nRC = 5, m = 3); expect_true(p$only_matches())
	p$cached_values$KKstats <- list(nRT = 5, nRC = 1, m = 3); expect_true(p$only_matches())
	p$cached_values$KKstats <- list(nRT = 5, nRC = 5, m = 3); expect_false(p$only_matches())
	p$cached_values$KKstats <- list(nRT = NA_real_, nRC = 5, m = 3); expect_false(p$only_matches())
	p$cached_values$KKstats <- list(nRT = 5, nRC = NA_real_, m = 3); expect_false(p$only_matches())
})

test_that("only_reservoir is FALSE with no KKstats, and TRUE exactly when m<=1 (finite)", {
	p <- bai_fixture_priv()
	p$cached_values$KKstats <- NULL
	expect_false(p$only_reservoir())

	p$cached_values$KKstats <- list(nRT = 5, nRC = 5, m = 1); expect_true(p$only_reservoir())
	p$cached_values$KKstats <- list(nRT = 5, nRC = 5, m = 0); expect_true(p$only_reservoir())
	p$cached_values$KKstats <- list(nRT = 5, nRC = 5, m = 5); expect_false(p$only_reservoir())
	p$cached_values$KKstats <- list(nRT = 5, nRC = 5, m = NA_real_); expect_false(p$only_reservoir())
})

test_that("compute_estimate_from_matched_and_reservoir is nonestimable ('kk_design_required') without match structure, and calls neither callback", {
	p <- bai_fixture_priv()
	unlockBinding("has_match_structure", p)
	p$has_match_structure <- FALSE
	called <- character()
	p$compute_estimate_from_matched_and_reservoir(
		run_matched = function() called <<- c(called, "matched"),
		run_reservoir = function() called <<- c(called, "reservoir")
	)
	expect_length(called, 0L)
	expect_true(isTRUE(p$cached_values$nonestimable))
	expect_identical(p$cached_values$nonestimable_reason, "kk_design_required")
})

test_that("compute_estimate_from_matched_and_reservoir dispatches to exactly the matched, reservoir, or both callbacks", {
	p <- bai_fixture_priv()
	unlockBinding("has_match_structure", p)
	p$has_match_structure <- TRUE

	run <- function(kkstats) {
		p$cached_values$KKstats <- kkstats
		called <- character()
		p$compute_estimate_from_matched_and_reservoir(
			run_matched = function() called <<- c(called, "matched"),
			run_reservoir = function() called <<- c(called, "reservoir")
		)
		called
	}

	expect_identical(run(list(nRT = 0, nRC = 5, m = 3)), "matched")           # only_matches
	expect_identical(run(list(nRT = 5, nRC = 5, m = 1)), "reservoir")         # only_reservoir
	expect_identical(run(list(nRT = 5, nRC = 5, m = 5)), c("matched", "reservoir"))  # both
})
