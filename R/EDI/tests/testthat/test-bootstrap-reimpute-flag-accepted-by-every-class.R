# v1.0.7-TODO-190: every inference class's nonparametric bootstrap methods accept
# reimpute_missing_vals_each_resample, including the classes that override them (g-computation,
# zero-augmented, dependent censoring, the KK passthrough). Before, those overrides failed with
# "unused argument". With complete covariates both values must run; with missing covariates TRUE
# either runs or gives the documented refusal, never an argument error. Classes come from the
# registry (applicable_inference_class_names_for_design), not a hand list.

REIMPUTE_FLAG_METHODS = c("approximate_bootstrap_distribution_beta_hat_T", "compute_bootstrap_confidence_interval",
	"compute_bootstrap_two_sided_pval")

reimpute_flag_responses = function(response_type, w, X) {
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

reimpute_flag_design = function(design, response_type, with_missing, seed) {
	set.seed(seed)
	n = 40L
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n), g = factor(sample(c("a", "b", "c"), n, replace = TRUE)))
	if (with_missing) X$x1[c(3, 9, 15, 21, 27, 33)] = NA
	if (identical(design, "kk")) {
		des = DesignSeqOneByOneKK14$new(response_type = response_type, n = n, seed = 3L)
		for (t in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[t, , drop = FALSE])
		w = des$get_w()
		r = reimpute_flag_responses(response_type, w, X)
		for (t in seq_len(n)) {
			y = r$ys[t]
			if (identical(response_type, "survival") && is.na(y)) des$add_one_subject_response(t, y_L = r$y_Ls[t], y_R = r$y_Rs[t])
			else des$add_one_subject_response(t, y = y)
		}
	} else {
		des = DesignFixedBernoulli$new(n = n, response_type = response_type, seed = 3L)
		des$add_all_subjects_to_experiment(X)
		des$assign_w_to_all_subjects()
		do.call(des$add_all_subject_responses, reimpute_flag_responses(response_type, des$get_w(), X))
	}
	des
}

# The error message of one bootstrap call, or NA when it ran (an NA result counts as running).
reimpute_flag_call = function(inf, method, value) {
	tryCatch({
		suppressWarnings(inf[[method]](B = 6, show_progress = FALSE, reimpute_missing_vals_each_resample = value))
		NA_character_
	}, error = function(e) conditionMessage(e))
}

test_that("every class's bootstrap methods accept reimpute_missing_vals_each_resample", {
	skip_on_cran()
	checked = 0L
	for (design in c("bernoulli", "kk")) for (rt in c("continuous", "incidence", "proportion", "count", "ordinal", "survival")) {
		for (with_missing in c(FALSE, TRUE)) {
			des = tryCatch(reimpute_flag_design(design, rt, with_missing, seed = 11L), error = function(e) NULL)
			if (is.null(des)) next
			classes = tryCatch(EDI:::applicable_inference_class_names_for_design(des), error = function(e) character())
			for (cls in classes) {
				inf = tryCatch(suppressWarnings(get(cls, envir = asNamespace("EDI"))$new(des)), error = function(e) NULL)
				if (is.null(inf)) next
				for (method in REIMPUTE_FLAG_METHODS) {
					if (!is.function(inf[[method]])) next
					label = sprintf("%s$%s (%s, %s design, %s covariates)", cls, method, rt, design,
						if (with_missing) "missing" else "complete")
					for (value in c(FALSE, TRUE)) {
						msg = reimpute_flag_call(inf, method, value)
						expect_false(isTRUE(grepl("unused argument", msg)), info = paste(label, "value", value, ":", msg))
						# Complete covariates: nothing to re-impute, so TRUE is never refused.
						if (!with_missing || !value) {
							expect_false(isTRUE(grepl("reimpute_missing_vals_each_resample", msg)),
								info = paste(label, "value", value, ":", msg))
						}
					}
					checked = checked + 1L
				}
			}
		}
	}
	expect_gt(checked, 100L)
})

test_that("an override with its own resampler refuses TRUE with missing covariates, and runs FALSE", {
	des = reimpute_flag_design("bernoulli", "proportion", with_missing = TRUE, seed = 5L)
	inf = InferencePropGCompMeanDiff$new(des)
	expect_error(inf$compute_bootstrap_confidence_interval(B = 6, show_progress = FALSE, reimpute_missing_vals_each_resample = TRUE),
		"reimpute_missing_vals_each_resample = FALSE")
	expect_error(inf$approximate_bootstrap_distribution_beta_hat_T(B = 6, show_progress = FALSE, reimpute_missing_vals_each_resample = TRUE),
		"reimpute_missing_vals_each_resample = FALSE")
	expect_length(inf$approximate_bootstrap_distribution_beta_hat_T(B = 6, show_progress = FALSE), 6L)
})

test_that("a pass-through override forwards TRUE: g-computation re-imputes each resample", {
	des = reimpute_flag_design("bernoulli", "incidence", with_missing = TRUE, seed = 7L)
	inf = InferenceIncidGCompRiskDiff$new(des)
	calls = 0L
	real = getFromNamespace("missRanger", "missRanger")
	testthat::local_mocked_bindings(missRanger = function(...) { calls <<- calls + 1L; real(...) }, .package = "EDI")
	invisible(suppressWarnings(inf$compute_bootstrap_confidence_interval(B = 6, type = "percentile", show_progress = FALSE)))
	expect_identical(calls, 0L)
	invisible(suppressWarnings(inf$compute_bootstrap_confidence_interval(B = 6, type = "percentile", show_progress = FALSE,
		reimpute_missing_vals_each_resample = TRUE)))
	expect_gte(calls, 6L)
})
