# v1.0.6-TODO-194: PRW subsampling CI / p-value setup had no deadline check, and its
# centered pivot read the original estimate with error = function(e) NA_real_, so a
# timeout or other control condition raised there became an NA result with reason
# "subsampling_original_estimate_unavailable". The m-out-of-n siblings check the
# deadline at setup and re-throw control conditions. Both families now share one
# setup helper (resampling_centered_pivot_for_inference()), so they behave the same.

timeout_fixture <- function(seed = 1L, n = 60L) {
	set.seed(seed)
	x <- rnorm(n)
	des <- DesignFixediBCRD$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(x + des$get_w() + rnorm(n))
	inf <- InferenceContinOLS$new(des, verbose = FALSE)
	inf$num_cores <- 1L
	inf$.__enclos_env__$private$seed <- 3L
	inf
}

stub_estimate_error <- function(inf, condition) {
	unlockBinding("compute_estimate", inf)
	inf$compute_estimate <- function(...) stop(condition)
	invisible(inf)
}

fake_timeout <- function() structure(
	class = c("TimeoutException", "error", "condition"),
	list(message = "fake timeout", call = NULL)
)

test_that("an expired deadline aborts subsampling CI and p-value setup, as it does for m-out-of-n", {
	inf <- timeout_fixture()
	withr::local_options(list(EDI.ci_timeout_deadline = proc.time()[["elapsed"]] - 100))
	expect_error(inf$compute_subsampling_confidence_interval(B = 20, show_progress = FALSE),
		"subsampling CI setup reached elapsed time limit", fixed = TRUE)
	expect_error(inf$compute_subsampling_two_sided_pval(B = 20, show_progress = FALSE),
		"subsampling p-value setup reached elapsed time limit", fixed = TRUE)
	expect_error(inf$compute_m_out_of_n_bootstrap_confidence_interval(B = 20, show_progress = FALSE),
		"m-out-of-n bootstrap CI setup reached elapsed time limit", fixed = TRUE)
	expect_error(inf$compute_m_out_of_n_bootstrap_two_sided_pval(B = 20, show_progress = FALSE),
		"m-out-of-n bootstrap p-value setup reached elapsed time limit", fixed = TRUE)
	expect_error(inf$approximate_subsampling_distribution_beta_hat_T(B = 20, show_progress = FALSE),
		"subsampling distribution setup reached elapsed time limit", fixed = TRUE)
})

test_that("a control condition raised while computing the original estimate is re-thrown on both subsampling paths", {
	for (cond in list(fake_timeout(), simpleError("Estimate reached elapsed time limit"))) {
		inf <- stub_estimate_error(timeout_fixture(), cond)
		expect_error(inf$compute_subsampling_confidence_interval(B = 20, show_progress = FALSE), conditionMessage(cond), fixed = TRUE)
		expect_error(inf$compute_subsampling_two_sided_pval(B = 20, show_progress = FALSE), conditionMessage(cond), fixed = TRUE)
		expect_error(inf$compute_m_out_of_n_bootstrap_confidence_interval(B = 20, show_progress = FALSE), conditionMessage(cond), fixed = TRUE)
		expect_error(inf$compute_m_out_of_n_bootstrap_two_sided_pval(B = 20, show_progress = FALSE), conditionMessage(cond), fixed = TRUE)
		expect_error(inf$approximate_subsampling_distribution_beta_hat_T(B = 20, b = 15, debug = TRUE, show_progress = FALSE),
			conditionMessage(cond), fixed = TRUE)
		expect_error(inf$.__enclos_env__$private$evaluate_subsampling_size(b = 15L, B = 20, alpha = 0.05),
			conditionMessage(cond), fixed = TRUE)
	}
})

test_that("an ordinary estimate error still gives NA with the family's reason on both paths", {
	for (family in c("subsampling", "m_out_of_n")) {
		ci_fun <- if (family == "subsampling") "compute_subsampling_confidence_interval" else "compute_m_out_of_n_bootstrap_confidence_interval"
		pv_fun <- if (family == "subsampling") "compute_subsampling_two_sided_pval" else "compute_m_out_of_n_bootstrap_two_sided_pval"
		reason <- paste0(family, "_original_estimate_unavailable")

		inf <- stub_estimate_error(timeout_fixture(), simpleError("ordinary failure"))
		ci <- suppressWarnings(inf[[ci_fun]](B = 20, show_progress = FALSE))
		expect_true(all(is.na(ci)), info = family)
		expect_identical(names(ci), c("2.5%", "97.5%"), info = family)
		# An unusable original estimate is a primary-fit failure, so it is filed as nonestimable.
		expect_identical(inf$.__enclos_env__$private$cached_values$nonestimable_reason, reason, info = family)

		inf2 <- stub_estimate_error(timeout_fixture(), simpleError("ordinary failure"))
		expect_identical(suppressWarnings(inf2[[pv_fun]](B = 20, show_progress = FALSE)), NA_real_, info = family)
		# An unusable original estimate is a primary-fit failure, so it is filed as nonestimable.
		expect_identical(inf2$.__enclos_env__$private$cached_values$nonestimable_reason, reason, info = family)
	}
})

test_that("the shared setup reproduces the pivot-based CI and p-value on ordinary data", {
	inf <- timeout_fixture()
	priv <- inf$.__enclos_env__$private
	for (family in c("subsampling", "m_out_of_n")) {
		size <- 20L
		draws <- if (family == "subsampling") {
			inf$approximate_subsampling_distribution_beta_hat_T(B = 40, b = size, show_progress = FALSE)
		} else {
			inf$approximate_m_out_of_n_bootstrap_distribution_beta_hat_T(B = 40, m = size, show_progress = FALSE)
		}
		est <- inf$compute_estimate()
		fpc <- if (family == "subsampling") 1 / sqrt(1 - size / 60) else 1
		cs <- fpc * sqrt(size) * (draws[is.finite(draws)] - est)
		q <- quantile(cs, c(0.025, 0.975), names = FALSE, type = 8)
		ref_ci <- c(est - q[2] / sqrt(60), est - q[1] / sqrt(60))
		t_obs <- sqrt(60) * est
		ref_pv <- min(1, max(2 / length(cs), 2 * min(mean(cs <= t_obs), mean(cs >= t_obs))))

		setup <- priv$resampling_centered_pivot_for_inference(family, "ci", B = 40, size = size, alpha = 0.05, show_progress = FALSE)
		expect_true(is.null(setup$value), info = family)
		expect_equal(setup$pivot$centered_scaled, cs, tolerance = 1e-12, info = family)
		ci <- if (family == "subsampling") {
			inf$compute_subsampling_confidence_interval(B = 40, b = size, show_progress = FALSE)
		} else {
			inf$compute_m_out_of_n_bootstrap_confidence_interval(B = 40, m = size, show_progress = FALSE)
		}
		expect_equal(as.numeric(ci), ref_ci, tolerance = 1e-10, info = family)
		pv <- if (family == "subsampling") {
			inf$compute_subsampling_two_sided_pval(B = 40, b = size, show_progress = FALSE)
		} else {
			inf$compute_m_out_of_n_bootstrap_two_sided_pval(B = 40, m = size, show_progress = FALSE)
		}
		expect_equal(pv, ref_pv, tolerance = 1e-12, info = family)
	}
})
