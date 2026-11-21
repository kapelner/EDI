# v1.0.6-TODO-182: the nightly silent-NA gate (silent_na_output, run 44358510753 on 4ce2b712) saw
# InferenceAllSimpleAverageDiff$compute_bootstrap_confidence_interval() return the BCa-boundary NA
# with a warning in some calls and with none in others, on the 8-subject smoke fixtures. Cause:
# at 4ce2b712, ci_bca()'s failure handler warned only when every bootstrap draw was finite; with
# n = 8 a resample often has no treated or no control subject, so the draw is not finite and the
# NA was silent (fixed as v1.0.6-TODO-162). Repeat calls on one object follow the warn-once policy
# of edi_warn_bca_boundary_once() (v1.0.5 TODO-101): the all-finite boundary warning is raised once
# per object, and later NAs keep the recorded procedure_failure_reason. The non-finite-draw NA
# warns on every call. Either way, every NA is explained.

make_smoke_bernoulli_design_bca_repeat = function(seed) {
	n = 8L
	X = data.frame(x1 = seq(-1, 1, length.out = n), x2 = rep(c(0, 1), length.out = n))
	d = DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = seed)
	d$add_all_subjects_to_experiment(X)
	d$assign_w_to_all_subjects()
	d$add_all_subject_responses(seq_len(n) / n)
	d
}

bca_ci_call_with_warnings = function(inf, B) {
	warns = list()
	ci = withCallingHandlers(
		inf$compute_bootstrap_confidence_interval(B = B, type = "bca", show_progress = FALSE),
		warning = function(w) { warns[[length(warns) + 1L]] <<- w; invokeRestart("muffleWarning") }
	)
	list(ci = ci, warns = warns,
		reason = inf$.__enclos_env__$private$cached_values$procedure_failure_reason$bootstrap)
}

new_bca_repeat_inference = function(seed) {
	inf = InferenceAllSimpleAverageDiff$new(make_smoke_bernoulli_design_bca_repeat(seed))
	inf$num_cores = 1L
	inf$set_seed(7L)
	inf
}

test_that("BCa boundary NA with non-finite bootstrap draws warns on both calls on the same object", {
	inf = new_bca_repeat_inference(1L)
	draws = inf$approximate_bootstrap_distribution_beta_hat_T(B = 101, show_progress = FALSE)
	expect_true(any(!is.finite(draws)))  # precondition: a resample missing an arm
	inf = new_bca_repeat_inference(1L)
	first = bca_ci_call_with_warnings(inf, 101L)
	if (all(is.finite(first$ci))) skip("this platform's bootstrap draws do not put the BCa adjustment on the boundary")
	second = bca_ci_call_with_warnings(inf, 101L)
	for (res in list(first, second)) {
		expect_true(all(is.na(res$ci)))
		expect_length(res$warns, 1L)
		expect_true(inherits(res$warns[[1L]], "edi_procedure_na_warning"))
		expect_match(conditionMessage(res$warns[[1L]]), "bootstrap_bca_adjustment_on_boundary")
		expect_identical(res$reason, "bootstrap_bca_adjustment_on_boundary")
	}
})

test_that("BCa boundary NA with all draws finite warns once, then keeps its recorded reason", {
	inf = new_bca_repeat_inference(5L)
	draws = inf$approximate_bootstrap_distribution_beta_hat_T(B = 101, show_progress = FALSE)
	expect_true(all(is.finite(draws)))  # precondition: the all-finite branch
	inf = new_bca_repeat_inference(5L)
	first = bca_ci_call_with_warnings(inf, 101L)
	if (all(is.finite(first$ci))) skip("this platform's bootstrap draws do not put the BCa adjustment on the boundary")
	expect_true(all(is.na(first$ci)))
	expect_length(first$warns, 1L)
	expect_true(inherits(first$warns[[1L]], "edi_bootstrap_bca_boundary_warning"))
	expect_identical(first$reason, "bootstrap_bca_adjustment_on_boundary")
	second = bca_ci_call_with_warnings(inf, 101L)
	expect_true(all(is.na(second$ci)))
	expect_length(second$warns, 0L)  # warn-once per object (v1.0.5 TODO-101)
	expect_identical(second$reason, "bootstrap_bca_adjustment_on_boundary")
})
