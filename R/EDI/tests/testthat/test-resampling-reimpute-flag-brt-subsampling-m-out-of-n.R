# v1.0.7-TODO-190 (extension, owner request 2026-11-26): reimpute_missing_vals_each_resample on the
# bootstrap-randomization test (distribution, p-value, CI), the m-out-of-n bootstrap and PRW
# subsampling (distribution, p-value, CI), and InferenceSurvivalDepCensTransformRegr's
# _basic / _bca / _studentized bootstrap CIs. Every exported class must accept the argument
# (registry-wide, not a hand list); complete covariates make the two values identical; the BRT CI,
# which evaluates the same draws at many deltas, imputes each draw once, not once per delta.

REIMPUTE_EXT_CALLS = list(
	approximate_rand_bootstrap_distribution_beta_hat_T = list(B = 6),
	compute_rand_bootstrap_two_sided_pval = list(B = 6),
	compute_rand_bootstrap_confidence_interval = list(B = 6, alpha = 0.5, pval_epsilon = 0.5, max_expansions = 1L),
	approximate_m_out_of_n_bootstrap_distribution_beta_hat_T = list(B = 6),
	compute_m_out_of_n_bootstrap_two_sided_pval = list(B = 6, min_number_usable_samples = 1L),
	compute_m_out_of_n_bootstrap_confidence_interval = list(B = 6, min_number_usable_samples = 1L),
	approximate_subsampling_distribution_beta_hat_T = list(B = 6),
	compute_subsampling_two_sided_pval = list(B = 6, min_number_usable_samples = 1L),
	compute_subsampling_confidence_interval = list(B = 6, min_number_usable_samples = 1L)
)

reimpute_ext_responses = function(response_type, w, X) {
	n = length(w)
	eta = 0.4 * w + 0.5 * X$x2
	switch(response_type,
		continuous = list(ys = eta + rnorm(n)),
		incidence = list(ys = as.numeric(stats::runif(n) < stats::plogis(eta))),
		proportion = list(ys = pmin(pmax(stats::plogis(eta + rnorm(n, sd = 0.5)), 0.02), 0.98)),
		count = list(ys = as.numeric(stats::rpois(n, exp(0.5 + 0.3 * eta)))),
		ordinal = list(ys = factor(findInterval(eta + rnorm(n), c(-0.5, 0.5)) + 1L, levels = 1:3, ordered = TRUE)),
		survival = {
			t = stats::rexp(n, exp(-eta))
			cens = stats::runif(n) < 0.25
			list(ys = ifelse(cens, NA, t), y_Ls = ifelse(cens, t, NA), y_Rs = ifelse(cens, Inf, NA))
		})
}

reimpute_ext_design = function(design, response_type, with_missing, seed, n = 40L) {
	set.seed(seed)
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n), g = factor(sample(c("a", "b", "c"), n, replace = TRUE)))
	if (with_missing) X$x1[seq(3L, n, by = 6L)] = NA
	if (identical(design, "kk")) {
		des = DesignSeqOneByOneKK14$new(response_type = response_type, n = n, seed = 3L)
		for (t in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[t, , drop = FALSE])
		r = reimpute_ext_responses(response_type, des$get_w(), X)
		for (t in seq_len(n)) {
			y = r$ys[t]
			if (identical(response_type, "survival") && is.na(y)) des$add_one_subject_response(t, y_L = r$y_Ls[t], y_R = r$y_Rs[t])
			else des$add_one_subject_response(t, y = y)
		}
	} else {
		des = DesignFixedBernoulli$new(n = n, response_type = response_type, seed = 3L)
		des$add_all_subjects_to_experiment(X)
		des$assign_w_to_all_subjects()
		do.call(des$add_all_subject_responses, reimpute_ext_responses(response_type, des$get_w(), X))
	}
	des
}

# The error message of one call, or NA when it ran (an NA result counts as running).
reimpute_ext_call = function(inf, method, args, value) {
	tryCatch({
		suppressMessages(suppressWarnings(do.call(inf[[method]], c(args, list(show_progress = FALSE,
			reimpute_missing_vals_each_resample = value)))))
		NA_character_
	}, error = function(e) conditionMessage(e))
}

test_that("every class's BRT, m-out-of-n and subsampling methods accept reimpute_missing_vals_each_resample", {
	skip_on_cran()
	checked = 0L
	for (design in c("bernoulli", "kk")) for (rt in c("continuous", "incidence", "proportion", "count", "ordinal", "survival")) {
		for (with_missing in c(FALSE, TRUE)) {
			des = tryCatch(reimpute_ext_design(design, rt, with_missing, seed = 13L), error = function(e) NULL)
			if (is.null(des)) next
			classes = tryCatch(EDI:::applicable_inference_class_names_for_design(des), error = function(e) character())
			for (cls in classes) {
				inf = tryCatch(suppressWarnings(get(cls, envir = asNamespace("EDI"))$new(des)), error = function(e) NULL)
				if (is.null(inf)) next
				for (method in names(REIMPUTE_EXT_CALLS)) {
					if (!is.function(inf[[method]])) next
					label = sprintf("%s$%s (%s, %s design, %s covariates)", cls, method, rt, design,
						if (with_missing) "missing" else "complete")
					# Missing covariates: only TRUE is new behaviour; it runs or is refused, never an argument error.
					for (value in if (with_missing) TRUE else c(FALSE, TRUE)) {
						msg = reimpute_ext_call(inf, method, REIMPUTE_EXT_CALLS[[method]], value)
						expect_false(isTRUE(grepl("unused argument", msg)), info = paste(label, "value", value, ":", msg))
						# Complete covariates: nothing to re-impute, so TRUE is never refused.
						if (!with_missing) {
							expect_false(isTRUE(grepl("reimpute_missing_vals_each_resample", msg)),
								info = paste(label, "value", value, ":", msg))
						}
					}
					checked = checked + 1L
				}
			}
		}
	}
	expect_gt(checked, 200L)
})

reimpute_ext_count_imputations = function(expr) {
	calls = 0L
	real = getFromNamespace("missRanger", "missRanger")
	testthat::local_mocked_bindings(missRanger = function(...) { calls <<- calls + 1L; real(...) }, .package = "EDI")
	force(expr)
	calls
}

test_that("the BRT confidence interval imputes each draw once, not once per delta", {
	skip_on_cran()
	des = reimpute_ext_design("bernoulli", "continuous", with_missing = TRUE, seed = 17L)
	inf = InferenceContinOLS$new(des)
	invisible(inf$compute_estimate())
	B = 19L
	# The default keeps the original imputation: nothing is imputed.
	expect_identical(reimpute_ext_count_imputations(suppressMessages(suppressWarnings(
		inf$compute_rand_bootstrap_confidence_interval(B = B, alpha = 0.2, show_progress = FALSE)))), 0L)
	# TRUE: the inversion evaluates many deltas on the same draws; each draw is imputed at most
	# once (a resample with no missing cell needs none), so the count stays at or below B.
	n_ci = reimpute_ext_count_imputations(suppressMessages(suppressWarnings(
		inf$compute_rand_bootstrap_confidence_interval(B = B, alpha = 0.2, show_progress = FALSE,
			reimpute_missing_vals_each_resample = TRUE))))
	expect_gt(n_ci, 0L)
	expect_lte(n_ci, B)
	# A single TRUE p-value on fresh draws imputes about as often as the whole CI.
	n_pval = reimpute_ext_count_imputations(suppressWarnings(
		inf$compute_rand_bootstrap_two_sided_pval(B = B, show_progress = FALSE, reimpute_missing_vals_each_resample = TRUE)))
	expect_gt(n_pval, 0L)
	expect_lte(n_pval, B)
})

test_that("m-out-of-n and subsampling re-impute per resample only with TRUE", {
	skip_on_cran()
	des = reimpute_ext_design("bernoulli", "continuous", with_missing = TRUE, seed = 19L, n = 80L)
	for (method in c("approximate_m_out_of_n_bootstrap_distribution_beta_hat_T", "approximate_subsampling_distribution_beta_hat_T")) {
		inf = InferenceContinOLS$new(des)
		invisible(inf$compute_estimate())
		expect_identical(reimpute_ext_count_imputations(suppressWarnings(inf[[method]](B = 8, show_progress = FALSE))), 0L,
			info = method)
		n_true = reimpute_ext_count_imputations(suppressWarnings(inf[[method]](B = 8, show_progress = FALSE,
			reimpute_missing_vals_each_resample = TRUE)))
		expect_gt(n_true, 0L, label = method)
		expect_lte(n_true, 8L, label = method)
	}
})

test_that("with complete covariates TRUE and FALSE give identical BRT, m-out-of-n and subsampling results", {
	skip_on_cran()
	des = reimpute_ext_design("bernoulli", "continuous", with_missing = FALSE, seed = 23L)
	for (method in c("approximate_rand_bootstrap_distribution_beta_hat_T", "compute_rand_bootstrap_two_sided_pval",
			"approximate_m_out_of_n_bootstrap_distribution_beta_hat_T", "approximate_subsampling_distribution_beta_hat_T")) {
		run = function(value) {
			set.seed(5L)
			inf = InferenceContinOLS$new(des)
			suppressWarnings(inf[[method]](B = 8, show_progress = FALSE, reimpute_missing_vals_each_resample = value))
		}
		expect_identical(run(FALSE), run(TRUE), info = method)
	}
})

test_that("DepCens basic / bca / studentized CIs pass the flag through", {
	skip_on_cran()
	des = reimpute_ext_design("bernoulli", "survival", with_missing = TRUE, seed = 29L, n = 60L)
	inf = InferenceSurvivalDepCensTransformRegr$new(des)
	invisible(suppressWarnings(inf$compute_estimate()))
	expect_identical(reimpute_ext_count_imputations(suppressWarnings(
		inf$compute_bootstrap_confidence_interval_basic(B = 12, show_progress = FALSE))), 0L)
	expect_gt(reimpute_ext_count_imputations(suppressWarnings(
		inf$compute_bootstrap_confidence_interval_basic(B = 12, show_progress = FALSE, reimpute_missing_vals_each_resample = TRUE))), 0L)
	for (method in c("compute_bootstrap_confidence_interval_bca", "compute_bootstrap_confidence_interval_studentized")) {
		fresh = InferenceSurvivalDepCensTransformRegr$new(des)
		expect_gt(reimpute_ext_count_imputations(suppressWarnings(
			fresh[[method]](B = 12, show_progress = FALSE, reimpute_missing_vals_each_resample = TRUE))), 0L, label = method)
	}
})

test_that("a reimputing BCa does not leak its jackknife into a later default jackknife on the same object", {
	skip_on_cran()
	mk = function() {
		set.seed(3); n = 60
		X = data.frame(a = rnorm(n), b = rnorm(n), f = factor(sample(c("u", "v", "w"), n, TRUE)))
		X$a[sample(n, 12)] = NA; X$b[sample(n, 9)] = NA
		d = DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = 1)
		d$add_all_subjects_to_experiment(X); d$assign_w_to_all_subjects()
		d$add_all_subject_responses(rnorm(n) + 0.5 * d$get_w())
		InferenceContinOLS$new(d)
	}
	se_fresh = mk()$compute_jackknife_std_error()
	used = mk()
	set.seed(9)
	suppressWarnings(used$compute_bootstrap_confidence_interval(B = 199, type = "bca", show_progress = FALSE,
		reimpute_missing_vals_each_resample = TRUE))
	expect_true(any(grepl("::reimpute$", names(used$.__enclos_env__$private$cached_values$jack_distr_cache))))
	expect_identical(used$compute_jackknife_std_error(), se_fresh)
})
