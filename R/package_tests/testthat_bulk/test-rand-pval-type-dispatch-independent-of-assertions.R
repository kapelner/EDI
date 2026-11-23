# v1.0.6-TODO-405: compute_rand_two_sided_pval(type = "Zhang") dispatched to the Zhang exact test inside an
# `if (should_run_asserts())` block (inference_all_abstract_rand_ci.R, and the same in
# inference_mixin_kk_gee_shared.R), so with assertions off `type` was ignored and the randomization-draw
# p-value came back (0.42 instead of 0.527 below), and a `type` a non-incidence class cannot use was silently
# ignored too. The dispatch and its refusals now run whatever the assertion setting.

make_incidence_bernoulli_design = function(){
	set.seed(405)
	n = 40
	des = DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rbinom(n, 1, plogis(-0.2 + 0.9 * des$get_w())))
	des
}

test_that("type = 'Zhang' gives the same p-value with assertions on and off", {
	inf = InferenceIncidLogRegr$new(make_incidence_bernoulli_design(), verbose = FALSE)
	p_on = inf$compute_rand_two_sided_pval(r = 99, type = "Zhang", show_progress = FALSE)
	toggle_asserts(FALSE)
	on.exit(toggle_asserts(TRUE), add = TRUE)
	p_off = inf$compute_rand_two_sided_pval(r = 99, type = "Zhang", show_progress = FALSE)
	toggle_asserts(TRUE)
	expect_true(is.finite(p_on))
	expect_identical(p_off, p_on)
	# and the Zhang p-value is not the draw-based one
	set.seed(1)
	p_draws = inf$compute_rand_two_sided_pval(r = 99, show_progress = FALSE)
	expect_false(isTRUE(all.equal(p_draws, p_on)))
})

test_that("a type a non-incidence class cannot use is refused with assertions off", {
	set.seed(406)
	n = 40
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n))
	inf = InferenceContinOLS$new(des, verbose = FALSE)
	toggle_asserts(FALSE)
	on.exit(toggle_asserts(TRUE), add = TRUE)
	expect_error(inf$compute_rand_two_sided_pval(r = 49, type = "Zhang", show_progress = FALSE),
		"only supported for incidence")
})
