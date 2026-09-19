library(testthat)
library(EDI)

# InferenceAllAbstract's private assert_design_supports_resampling()/
# assert_design_supports_randomization_draw()/
# assert_design_supports_resampling_replay() are simple capability-gate
# guards, each called by resampling/randomization-CI machinery elsewhere in
# the class hierarchy before proceeding, but never exercised by name (or via
# a fixture forcing the guarded flag FALSE) anywhere in the suite --
# confirmed via repo-wide grep, zero references. Exercised here via direct
# private access, forcing each of the three `supports_design_*` flags FALSE
# in turn on an otherwise-default concrete inference object (which normally
# supports all three).

make_min_inference <- function() {
	set.seed(1)
	n <- 20L
	des <- DesignSeqOneByOneBernoulli$new(n = n, response_type = "continuous")
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	des$add_all_subject_responses(rnorm(n))
	InferenceAllSimpleAverageDiff$new(des)
}

test_that("all three assertion guards pass through silently when their capability flag is TRUE (the default here)", {
	inf <- make_min_inference()
	priv <- inf$.__enclos_env__$private

	expect_true(isTRUE(priv$supports_design_resampling))
	expect_true(isTRUE(priv$supports_design_randomization_draw))
	expect_true(isTRUE(priv$supports_design_resampling_replay))

	expect_null(priv$assert_design_supports_resampling("m1"))
	expect_null(priv$assert_design_supports_randomization_draw("m2"))
	expect_null(priv$assert_design_supports_resampling_replay("m3"))
})

test_that("assert_design_supports_resampling stops with the plain-DesignFixed message when its flag is FALSE", {
	inf <- make_min_inference()
	priv <- inf$.__enclos_env__$private
	priv$supports_design_resampling <- FALSE

	expect_error(
		priv$assert_design_supports_resampling("my_method"),
		"my_method is not available for plain DesignFixed objects\\. Use asymptotic inference or a concrete design subclass\\."
	)
})

test_that("assert_design_supports_randomization_draw stops with the no-randomization-mechanism message when its flag is FALSE", {
	inf <- make_min_inference()
	priv <- inf$.__enclos_env__$private
	priv$supports_design_randomization_draw <- FALSE

	expect_error(
		priv$assert_design_supports_randomization_draw("draw_method"),
		"draw_method is not available for this design \\(no randomization mechanism to draw a fresh assignment from\\)"
	)
})

test_that("assert_design_supports_resampling_replay stops with the no-replay message when its flag is FALSE", {
	inf <- make_min_inference()
	priv <- inf$.__enclos_env__$private
	priv$supports_design_resampling_replay <- FALSE

	expect_error(
		priv$assert_design_supports_resampling_replay("replay_method"),
		"replay_method is not available for this design \\(no randomization mechanism to replay against resampled data\\)"
	)
})

test_that("each guard is independent of the other two flags", {
	inf <- make_min_inference()
	priv <- inf$.__enclos_env__$private
	priv$supports_design_resampling <- FALSE

	# The other two flags are untouched and still pass through.
	expect_null(priv$assert_design_supports_randomization_draw("still_ok"))
	expect_null(priv$assert_design_supports_resampling_replay("still_ok_too"))
})
