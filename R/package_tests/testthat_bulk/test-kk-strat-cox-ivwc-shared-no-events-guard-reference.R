library(testthat)
library(EDI)

# InferenceSurvivalKKStratCoxPHIVWC's private shared() (inference_survival_KK_strat_cox.R) has an
# early guard, checked before either the stratified-Cox (matched-pairs) or standard-Cox (reservoir)
# fits are attempted: `if (sum(private$dead) == 0L) { private$cache_nonestimable_estimate(
# "kk_strat_cox_ivwc_no_events"); return(invisible(NULL)) }` -- when every subject in the design is
# right-censored (no observed events at all), the Cox partial likelihood has no information to fit
# on. This is a distinct, earlier guard from the matched-reservoir combination branches already
# closed this stretch in test-kk-strat-cox-ivwc-shared-matched-reservoir-combination-branches-
# reference.R (which mocks the component fitters and never triggers this all-censored precondition).
# A codebase-wide grep confirms "kk_strat_cox_ivwc_no_events" had no test reference anywhere. Reached
# directly with real (all-censored) survival data on a real KK design, no mocking needed.

test_that("a design where every subject is censored (no observed events) is nonestimable with the documented reason, without attempting either component fit", {
	set.seed(1); n <- 20L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "survival", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	y <- rexp(n, 0.1)
	for (i in seq_len(n)) des$add_one_subject_response(i, y_L = y[i], y_R = Inf)   # right-censored: no events anywhere

	inf <- InferenceSurvivalKKStratCoxPHIVWC$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	expect_equal(sum(priv$dead), 0L)   # confirms the fixture actually exercises the "no events" precondition

	est <- inf$compute_estimate()
	expect_true(is.na(est))
	expect_true(inf$is_nonestimable("estimate"))
	expect_equal(inf$get_nonestimable_reason(), "kk_strat_cox_ivwc_no_events")
	expect_null(priv$cached_values$beta_T_matched)   # neither component fit was ever attempted
	expect_null(priv$cached_values$beta_T_reservoir)
})

test_that("at least one observed event does not trigger the guard", {
	set.seed(2); n <- 20L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "survival", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	y <- rexp(n, exp(0.3 * des$get_w()))
	des$add_all_subject_responses(y)   # ordinary exact event times: not all censored

	inf <- InferenceSurvivalKKStratCoxPHIVWC$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	expect_gt(sum(priv$dead), 0L)

	inf$compute_estimate()
	expect_false(identical(inf$get_nonestimable_reason(), "kk_strat_cox_ivwc_no_events"))
})
