context("TODO-101: BCa boundary failure keeps its specific reason and warns once")

fx_bca_101 = function(seed){
	set.seed(seed); n = 60
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous")
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(as.numeric(des$get_w()) * 0.5 + X$x1 + rnorm(n))
	inf = InferenceContinOLS$new(des, verbose = FALSE)
	inf$num_cores = 1L
	inf
}
pf_101 = function(inf) inf$.__enclos_env__$private$cached_values$procedure_failure_reason$bootstrap

# seed 1 is a BCa boundary failure at B = 101, seed 4 a success (deterministic under set.seed)
test_that("BCa boundary NA keeps bootstrap_bca_adjustment_on_boundary and warns exactly once", {
	inf = fx_bca_101(1)
	n_warn = 0L
	ci = withCallingHandlers(
		inf$compute_bootstrap_confidence_interval(B = 101, show_progress = FALSE),
		edi_bootstrap_bca_boundary_warning = function(w) {
			n_warn <<- n_warn + 1L
			expect_identical(w$B, 101)
			expect_identical(w$type, "bca")
			expect_identical(w$reason, "bootstrap_bca_adjustment_on_boundary")
			expect_match(conditionMessage(w), "BCa adjustment on the boundary at B = 101")
			expect_match(conditionMessage(w), "501 recommended")
			invokeRestart("muffleWarning")
		})
	expect_true(all(is.na(ci)))
	expect_identical(pf_101(inf), "bootstrap_bca_adjustment_on_boundary")
	expect_identical(n_warn, 1L)
	# second call on the same object: same reason, no second warning
	expect_no_warning(ci2 <- inf$compute_bootstrap_confidence_interval(B = 101, show_progress = FALSE),
		message = "edi_bootstrap_bca_boundary_warning")
	expect_true(all(is.na(ci2)))
	expect_identical(pf_101(inf), "bootstrap_bca_adjustment_on_boundary")
	expect_identical(n_warn, 1L)
})

test_that("a successful BCa CI is silent and clears a stale reason", {
	inf = fx_bca_101(4)
	inf$.__enclos_env__$private$cached_values$procedure_failure_reason = list(bootstrap = "bootstrap_stale_reason")
	expect_no_warning(ci <- inf$compute_bootstrap_confidence_interval(B = 101, show_progress = FALSE),
		message = "edi_bootstrap_bca_boundary_warning")
	expect_true(all(is.finite(ci)))
	expect_null(pf_101(inf))
})

test_that("an unrelated failure keeps its own reason and does not warn", {
	inf = fx_bca_101(4)
	est = as.numeric(inf$compute_estimate())
	stub = function(...) rep(NA_real_, 101)
	nm = "approximate_bootstrap_distribution_beta_hat_T"
	if (bindingIsLocked(nm, inf)) unlockBinding(nm, inf)
	assign(nm, stub, envir = inf)
	expect_no_warning(ci <- inf$compute_bootstrap_confidence_interval(B = 101, type = "percentile", show_progress = FALSE),
		message = "edi_bootstrap_bca_boundary_warning")
	expect_true(all(is.na(ci)))
	expect_identical(pf_101(inf), "bootstrap_too_few_finite_estimates")
})
