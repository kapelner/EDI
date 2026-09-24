library(testthat)
library(EDI)

# InferenceRandBootstrap's private load_rand_bootstrap_assignment_into_worker() (inference_all_
# abstract_rand_bootstrap.R) has two defensive guards on its "no precomputed draw$w_b -- draw a fresh
# assignment from the worker's own design object" fallback path (the branch taken whenever a bootstrap
# draw carries only i_b/m_vec_b, not a precomputed w_b -- the ordinary case for every non-"fast" class):
# (1) if no design object can be located anywhere in worker_state (neither worker_des directly, nor
# inf_priv$des_obj via worker_inf/worker_priv/worker), it stops with "Reusable BRT worker has no design
# object to draw assignments from."; (2) if the freshly-drawn assignment's length doesn't match
# draw$i_b's length, it stops with "Fresh assignment length does not match the bootstrap sample size."
# Both had no test reference anywhere -- confirmed via a zero-hit grep for the exact messages. The
# function's normal dispatch (via approximate_rand_bootstrap_distribution_beta_hat_T()/compute_rand_
# bootstrap_two_sided_pval()) always supplies a real worker_des with a design whose draw_ws_according_
# to_design(1L) length matches draw$i_b by construction, so both guards are only reachable by calling
# this private helper directly with a hand-built worker_state/draw, the same "call the private helper
# in isolation" technique used for the sibling rand_bootstrap_ci_* guards
# (test-rand-bootstrap-two-sided-pval-observed-statistic-unavailable-guard-reference.R).
#   1. worker_state with no design object reachable anywhere (and draw$w_b unset) triggers guard 1.
#   2. A reachable design object whose draw produces a different length than draw$i_b triggers guard 2.
#   3. The same design object, with draw$i_b at the design's own n, does NOT error.

smd_fixture <- function(n = 20L, seed = 1L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = seed)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(w + rnorm(n, sd = 0.5))
	inf <- InferenceAllSimpleAverageDiff$new(des)
	list(inf = inf, des = des, priv = inf$.__enclos_env__$private)
}

test_that("no design object reachable anywhere in worker_state triggers the documented 'no design object' error", {
	f <- smd_fixture()
	worker_state <- list(worker_priv = list())                                       # no des_obj field at all
	draw <- list(i_b = 1:5, w_b = NULL, m_vec_b = NULL)
	expect_error(
		f$priv$load_rand_bootstrap_assignment_into_worker(worker_state, draw, delta = 0, transform_responses = "none", y0_full = f$des$get_y()),
		"Reusable BRT worker has no design object to draw assignments from\\."
	)
})

test_that("a fresh assignment length mismatched against draw$i_b triggers the documented length-mismatch error", {
	f <- smd_fixture(seed = 2L)
	worker_state <- list(worker_des = f$des$duplicate())
	draw <- list(i_b = 1:7, w_b = NULL, m_vec_b = NULL)                               # 7 != des$get_n() == 20
	expect_error(
		f$priv$load_rand_bootstrap_assignment_into_worker(worker_state, draw, delta = 0, transform_responses = "none", y0_full = f$des$get_y()),
		"Fresh assignment length does not match the bootstrap sample size\\."
	)
})

test_that("a design object whose draw length matches draw$i_b at n does not error", {
	f <- smd_fixture(seed = 3L)
	worker_state <- list(worker_des = f$des$duplicate())
	draw <- list(i_b = seq_len(f$des$get_n()), w_b = NULL, m_vec_b = NULL)
	expect_no_error(
		f$priv$load_rand_bootstrap_assignment_into_worker(worker_state, draw, delta = 0, transform_responses = "none", y0_full = f$des$get_y())
	)
})
