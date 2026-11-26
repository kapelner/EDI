# v1.0.7-TODO-183: InferenceSurvivalCoxPHRegr returned a silent NA when a
# partial-likelihood coefficient diverged (found by the real-data crash corpus on
# cgd, udca, supraclavicular, frailtypack::reduce). The estimate stays NA under the
# current rule (any coefficient beyond 20), but it now says why and names the
# diverged column.

test_that("CoxPH warns, naming the column, when a covariate's coefficient diverges", {
	set.seed(20261126)
	n = 80
	w = rep(c(0, 1), each = n / 2)
	x1 = rnorm(n)
	# x_rare = 1 only for subjects who are censored: the partial likelihood is
	# monotone in its coefficient, which runs off to -Inf.
	dead = rbinom(n, 1, 0.7)
	x_rare = as.numeric(dead == 0 & runif(n) < 0.5)
	y = rexp(n, rate = exp(0.3 * w + 0.2 * x1))
	des = DesignFixedBernoulli$new(n = n, response_type = "survival")
	des$add_all_subjects_to_experiment(data.frame(x1 = x1, x_rare = x_rare))
	des$assign_w_to_all_subjects(w_precomputed = w)
	des$add_all_subject_responses(
		ys = ifelse(dead == 1, y, NA),
		y_Ls = ifelse(dead == 1, NA, y),
		y_Rs = ifelse(dead == 1, NA, Inf)
	)
	inf = InferenceSurvivalCoxPHRegr$new(des)
	w_caught = NULL
	est = withCallingHandlers(inf$compute_estimate(), warning = function(cnd) {
		if (inherits(cnd, "edi_procedure_na_warning")) w_caught <<- cnd
		invokeRestart("muffleWarning")
	})
	expect_true(is.na(est))
	expect_false(is.null(w_caught))
	expect_s3_class(w_caught, "edi_estimate_unavailable_warning")
	expect_identical(w_caught$reason, "coxph_extreme_coefficients")
	expect_match(conditionMessage(w_caught), "x_rare", fixed = TRUE)
	expect_true(inf$is_nonestimable("estimate"))
})

test_that("CoxPH stays quiet when no coefficient diverges", {
	set.seed(20261127)
	n = 80
	w = rep(c(0, 1), each = n / 2)
	x1 = rnorm(n)
	y = rexp(n, rate = exp(0.3 * w + 0.2 * x1))
	dead = rbinom(n, 1, 0.8)
	des = DesignFixedBernoulli$new(n = n, response_type = "survival")
	des$add_all_subjects_to_experiment(data.frame(x1 = x1))
	des$assign_w_to_all_subjects(w_precomputed = w)
	des$add_all_subject_responses(
		ys = ifelse(dead == 1, y, NA),
		y_Ls = ifelse(dead == 1, NA, y),
		y_Rs = ifelse(dead == 1, NA, Inf)
	)
	inf = InferenceSurvivalCoxPHRegr$new(des)
	expect_no_warning(est <- inf$compute_estimate(), class = "edi_procedure_na_warning")
	expect_true(is.finite(est))
})
