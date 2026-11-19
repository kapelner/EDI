# v1.0.6-TODO-162: a plain-bootstrap BCa interval that is NA because the adjusted tail is on
# the boundary must warn even when some bootstrap draws were not finite. Cause: ci_bca()'s
# failure handler warned only when every draw was finite (ctx$all_finite), and
# missing_bootstrap_ci() then saw the already-recorded reason (keep-first) and skipped its own
# warning, so the NA was silent. With few clusters a resample can hold no treated or no control
# cluster (non-finite mean difference), so this was common on DesignFixedCluster at 4 clusters.

make_cluster_bca_design_t162 = function(G, seed) {
	set.seed(seed)
	m = 6L
	n = G * m
	X = data.frame(x = rnorm(n), cl = factor(rep(seq_len(G), each = m)))
	d = DesignFixedCluster$new(n = n, response_type = "continuous", cluster_col = "cl", seed = seed)
	d$add_all_subjects_to_experiment(X)
	d$assign_w_to_all_subjects()
	w = d$get_w()
	u = rep(rnorm(G, 0, 0.5), each = m)
	d$add_all_subject_responses(1 + 0.5 * w + X$x + u + rnorm(n))
	d
}

test_that("BCa CI on the boundary with some non-finite bootstrap draws is NA with a warning", {
	ns = asNamespace("EDI")
	old_min = get("EDI_JACKKNIFE_MIN_DELETION_UNITS", envir = ns)
	locked = bindingIsLocked("EDI_JACKKNIFE_MIN_DELETION_UNITS", ns)
	if (locked) unlockBinding("EDI_JACKKNIFE_MIN_DELETION_UNITS", ns)
	assign("EDI_JACKKNIFE_MIN_DELETION_UNITS", 2L, envir = ns)
	on.exit({
		assign("EDI_JACKKNIFE_MIN_DELETION_UNITS", old_min, envir = ns)
		if (locked) lockBinding("EDI_JACKKNIFE_MIN_DELETION_UNITS", ns)
	}, add = TRUE)

	des = make_cluster_bca_design_t162(G = 4L, seed = 1003L)
	inf = InferenceAllSimpleAverageDiff$new(des)
	inf$num_cores = 1L
	inf$set_seed(3L)
	# Precondition: this case really has non-finite draws (a resample missing an arm).
	draws = inf$approximate_bootstrap_distribution_beta_hat_T(B = 201, show_progress = FALSE)
	expect_true(any(!is.finite(draws)))

	inf = InferenceAllSimpleAverageDiff$new(des)
	inf$num_cores = 1L
	inf$set_seed(3L)
	warns = list()
	ci = withCallingHandlers(
		inf$compute_bootstrap_confidence_interval(B = 201, type = "bca", show_progress = FALSE),
		warning = function(w) { warns[[length(warns) + 1L]] <<- w; invokeRestart("muffleWarning") }
	)
	expect_true(all(is.na(ci)))
	expect_length(warns, 1L)
	expect_true(inherits(warns[[1L]], "edi_procedure_na_warning"))
	expect_match(conditionMessage(warns[[1L]]), "bootstrap_bca_adjustment_on_boundary")
	expect_match(conditionMessage(warns[[1L]]), "not finite")
	expect_identical(inf$.__enclos_env__$private$cached_values$procedure_failure_reason$bootstrap,
		"bootstrap_bca_adjustment_on_boundary")
})
