# v1.0.6-TODO-141: three leftovers from v1.0.6-TODO-139.
# (1) The g-computation risk-ratio log-scale subsampling / m-out-of-n pivot
#     (compute_rr_resampling_pivot(), plain and KK) read the original estimate with
#     error = function(e) NA_real_, so a timeout became an NA result. It now uses
#     resampling_error_to_na, which re-throws control conditions.
# (2) The RR classes rejected a list-valued b / m ("b selection must be resolved before
#     drawing."). The size now goes through the same minimum-volatility selector as the
#     generic paths (select_resampling_size_from_spec()).
# (3) select_optimal_resample_size() turned any evaluator error, timeouts included, into a
#     non-estimable candidate. Control conditions now abort the selection.

rr_plain_des = function(seed = 5L, n = 80L){
	set.seed(seed)
	X = data.frame(x = rnorm(n))
	des = DesignFixediBCRD$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w = des$get_w()
	des$add_all_subject_responses(rbinom(n, 1, plogis(-0.3 + 0.8 * w + 0.5 * X$x)))
	des
}

rr_kk_des = function(n_pairs = 40L, seed = 6L){
	set.seed(seed)
	n = 2L * n_pairs
	x = rnorm(n)
	des = DesignFixedBinaryMatch$new(n = n, response_type = "incidence", m = rep(seq_len(n_pairs), each = 2L),
		verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	w = rep(c(0, 1), n_pairs)
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(rbinom(n, 1, plogis(-0.5 + 1.0 * w + 0.4 * x)))
	des
}

rr_new = function(kind, harden = TRUE){
	inf = if (kind == "plain") {
		InferenceIncidGCompRiskRatio$new(rr_plain_des(), verbose = FALSE)
	} else {
		InferenceIncidKKGCompRiskRatio$new(rr_kk_des(), verbose = FALSE)
	}
	inf$.__enclos_env__$private$harden = harden
	inf$num_cores = 1L
	inf
}

rr_stub_public = function(inf, name, fn){
	unlockBinding(name, inf)
	inf[[name]] = fn
	invisible(inf)
}

rr_fake_timeout = function() structure(
	class = c("TimeoutException", "error", "condition"),
	list(message = "fake timeout", call = NULL)
)

rr_calls = list(
	sub_ci = function(inf) inf$compute_subsampling_confidence_interval(B = 20, show_progress = FALSE),
	sub_pv = function(inf) inf$compute_subsampling_two_sided_pval(B = 20, show_progress = FALSE),
	mn_ci = function(inf) inf$compute_m_out_of_n_bootstrap_confidence_interval(B = 20, show_progress = FALSE),
	mn_pv = function(inf) inf$compute_m_out_of_n_bootstrap_two_sided_pval(B = 20, show_progress = FALSE)
)

test_that("a control condition raised by the original RR estimate is re-thrown on every log-scale resampling path", {
	for (kind in c("plain", "kk")) {
		for (cond in list(rr_fake_timeout(), simpleError("Estimate reached elapsed time limit"))) {
			for (nm in names(rr_calls)) {
				inf = rr_stub_public(rr_new(kind), "compute_estimate", function(...) stop(cond))
				expect_error(rr_calls[[nm]](inf), conditionMessage(cond), fixed = TRUE, info = paste(kind, nm))
			}
		}
	}
})

test_that("an ordinary RR estimate error still gives NA with the original-estimate reason", {
	for (kind in c("plain", "kk")) {
		for (nm in names(rr_calls)) {
			inf = rr_stub_public(rr_new(kind), "compute_estimate", function(...) stop("ordinary failure"))
			out = suppressWarnings(rr_calls[[nm]](inf))
			expect_true(all(is.na(out)), info = paste(kind, nm))
			expect_identical(inf$.__enclos_env__$private$cached_values$nonestimable_reason,
				"resampling_original_estimate_unavailable", info = paste(kind, nm))
		}
	}
})

test_that("the RR classes accept a list b / m and use the selector's size", {
	for (kind in c("plain", "kk")) {
		for (family in c("subsampling", "m_out_of_n")) {
			sub = family == "subsampling"
			ci_fun = if (sub) "compute_subsampling_confidence_interval" else "compute_m_out_of_n_bootstrap_confidence_interval"
			pv_fun = if (sub) "compute_subsampling_two_sided_pval" else "compute_m_out_of_n_bootstrap_two_sided_pval"
			size_arg = if (sub) "b" else "m"
			select_fun = if (sub) "select_optimal_b_subsampling" else "select_optimal_m_out_of_n_bootstrap"
			type_arg = if (sub) "subsampling_type" else "bootstrap_type"
			info = paste(kind, family)

			ci_args = list(alpha = 0.1, B = 30, show_progress = FALSE)
			ci_args[[size_arg]] = list(B = 25)
			inf = rr_new(kind)
			set.seed(21)
			ci_list = do.call(inf[[ci_fun]], ci_args)

			# Reference: run the selector on a fresh object (same alpha, B and RNG stream),
			# then the CI at the selected size. The pivot computes the original estimate before
			# selecting, so do the same first.
			ref = rr_new(kind)
			ref$compute_estimate()
			sel_args = list(B = 25L, alpha = 0.1, scaling = "sqrt_n", show_progress = FALSE)
			sel_args[type_arg] = list(NULL)
			set.seed(21)
			sel = do.call(ref[[select_fun]], sel_args)
			size = sel[[paste0(size_arg, "_optimal")]]
			expect_true(is.numeric(size) && is.finite(size), info = info)
			ci_args[[size_arg]] = size
			ci_ref = do.call(ref[[ci_fun]], ci_args)
			# Equal up to warm-start round-off in the replicate fits (cache order differs).
			expect_equal(ci_list, ci_ref, tolerance = 1e-8, info = info)
			expect_true(all(is.finite(ci_list)), info = info)

			# v1.0.6-TODO-137: at B = 30 the usable-draw cap (default 0.8) can trip on degenerate draws;
			# this test is about the list-valued size, so it lifts the cap.
			pv_args = list(B = 30, show_progress = FALSE, min_fraction_usable_samples = 0)
			pv_args[[size_arg]] = list(B = 25)
			pv = do.call(rr_new(kind)[[pv_fun]], pv_args)
			expect_true(is.finite(pv) && pv > 0 && pv <= 1, info = info)
		}
	}
})

test_that("a failed RR size selection gives NA with the family's selection reason, hardened or not", {
	for (kind in c("plain", "kk")) {
		for (harden in c(TRUE, FALSE)) {
			for (family in c("subsampling", "m_out_of_n")) {
				sub = family == "subsampling"
				reason = if (sub) "subsampling_b_selection_failed" else "m_out_of_n_m_selection_failed"
				select_fun = if (sub) "select_optimal_b_subsampling" else "select_optimal_m_out_of_n_bootstrap"
				size_arg = if (sub) "b" else "m"
				fail_selector = function(...) stats::setNames(list(NA_integer_), paste0(size_arg, "_optimal"))
				info = paste(kind, harden, family)
				for (target in c("ci", "pval")) {
					inf = rr_stub_public(rr_new(kind, harden = harden), select_fun, fail_selector)
					fun = if (target == "ci") {
						if (sub) inf$compute_subsampling_confidence_interval else inf$compute_m_out_of_n_bootstrap_confidence_interval
					} else {
						if (sub) inf$compute_subsampling_two_sided_pval else inf$compute_m_out_of_n_bootstrap_two_sided_pval
					}
					args = list(B = 20, show_progress = FALSE)
					args[[size_arg]] = list(B = 20)
					out = suppressWarnings(do.call(fun, args))
					expect_true(all(is.na(out)), info = paste(info, target))
					failures = unlist(inf$.__enclos_env__$private$cached_values$procedure_failure_reason)
					expect_true(reason %in% failures, info = paste(info, target))
				}
			}
		}
	}
})

test_that("select_optimal_resample_size() re-throws control conditions but keeps ordinary evaluator errors per candidate", {
	inf = rr_new("plain")
	priv = inf$.__enclos_env__$private
	for (cond in list(rr_fake_timeout(), simpleError("Estimate reached elapsed time limit"))) {
		expect_error(priv$select_optimal_resample_size(size_grid = c(10L, 12L, 14L), evaluator = function(size) stop(cond)),
			conditionMessage(cond), fixed = TRUE)
	}
	res = priv$select_optimal_resample_size(size_grid = c(10L, 12L, 14L), evaluator = function(size) stop("ordinary failure"))
	expect_identical(res$status, "nonestimable")
	expect_true(all(res$grid_table$status == "error"))
	expect_true(all(res$grid_table$dominant_failure_reason == "ordinary failure"))
	# End to end: a timeout inside compute_estimate aborts the public selectors.
	for (select_fun in c("select_optimal_b_subsampling", "select_optimal_m_out_of_n_bootstrap")) {
		inf2 = rr_stub_public(rr_new("plain"), "compute_estimate", function(...) stop(rr_fake_timeout()))
		expect_error(inf2[[select_fun]](B = 20, show_progress = FALSE), "fake timeout", fixed = TRUE, info = select_fun)
	}
})
