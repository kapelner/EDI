# Regression tests for fix_design_hierarchy.md TODO-52/TODO-53: splitting the single
# supports_resampling() capability into supports_randomization_draw()/
# supports_resampling_replay(), and migrating ObservationalDesign's draw_ws_raw()
# throwing stub onto metadata.
#
# Live bug this fixes: ObservationalDesign never overrode the old, unsplit
# supports_resampling(), so it inherited Design's default (TRUE for any concrete
# class). compute_rand_two_sided_pval() therefore passed the eligibility assert
# cleanly and only failed later, deep inside draw_ws_raw()'s throwing stub -- a worse
# error, at a worse call depth, than the assert layer is meant to give.
#
# Scope note: only supports_randomization_draw()/supports_resampling_replay() are
# FALSE for ObservationalDesign. The general supports_resampling() stays TRUE, since
# plain nonparametric/Bayesian/m-out-of-n/PRW-subsampling bootstrap never redraw w (they
# resample already-observed units and their fixed, observed assignment) and are
# explicitly documented as remaining available for this class.

build_observational_design = function() {
	set.seed(20260816)
	n = 12L
	des = ObservationalDesign$new(n = n, response_type = "continuous")
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects(w_precomputed = rep(c(0, 1), each = n / 2))
	des$add_all_subject_responses(rnorm(n))
	des
}

test_that("ObservationalDesign's capability split is correct: general resampling TRUE, mechanism-dependent capabilities FALSE", {
	des = build_observational_design()
	expect_true(des$supports_resampling())
	expect_false(des$supports_randomization_draw())
	expect_false(des$supports_resampling_replay())
	expect_true(des$supports("resampling"))
	expect_false(des$supports("randomization_draw"))
	expect_false(des$supports("resampling_replay"))
})

test_that("an ordinary concrete design has all three capabilities TRUE", {
	set.seed(20260816)
	des = DesignFixedBernoulli$new(n = 12L, response_type = "continuous")
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(12)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(12))
	expect_true(des$supports_resampling())
	expect_true(des$supports_randomization_draw())
	expect_true(des$supports_resampling_replay())
})

test_that("randomization test correctly rejects ObservationalDesign with a clear, early error (not the deep draw_ws_raw stub)", {
	des = build_observational_design()
	inf = InferenceAllSimpleMeanDiffPooledVar$new(des, verbose = FALSE)
	expect_error(
		inf$compute_rand_two_sided_pval(r = 21),
		"Randomization inference is not available for this design"
	)
})

test_that("bootstrap randomization test (BRT) correctly rejects ObservationalDesign", {
	des = build_observational_design()
	inf = InferenceAllSimpleMeanDiffPooledVar$new(des, verbose = FALSE)
	expect_error(
		inf$approximate_rand_bootstrap_distribution_beta_hat_T(B = 21),
		"Bootstrap randomization inference is not available for this design"
	)
})

test_that("plain nonparametric and Bayesian bootstrap remain available for ObservationalDesign", {
	des = build_observational_design()
	inf1 = InferenceAllSimpleMeanDiffPooledVar$new(des, verbose = FALSE)
	boot_distr = inf1$approximate_bootstrap_distribution_beta_hat_T(B = 21, show_progress = FALSE)
	expect_length(boot_distr, 21)
	expect_true(all(is.finite(boot_distr)))

	inf2 = InferenceAllSimpleMeanDiffPooledVar$new(des, verbose = FALSE)
	bayes_distr = inf2$approximate_bayesian_bootstrap_distribution_beta_hat_T(B = 21, show_progress = FALSE)
	expect_length(bayes_distr, 21)
	expect_true(all(is.finite(bayes_distr)))
})

test_that("draw_ws_raw() throwing stub remains as a fallback for callers that don't check supports() first", {
	des = build_observational_design()
	expect_error(
		des$draw_ws_according_to_design(1L),
		"Observational designs are not controlled designs based on randomized allocations"
	)
})
