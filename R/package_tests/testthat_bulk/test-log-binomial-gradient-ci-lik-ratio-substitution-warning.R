library(testthat)
library(EDI)

# TODO-190 (v1.0.5): InferenceIncidLogBinomial$compute_gradient_confidence_interval() returns the
# likelihood-ratio interval when gradient inversion gives no usable interval. That substitution used
# to be silent (LR bounds under the gradient label, and an "NA is returned unchanged" warning that
# was wrong). It now warns once with class edi_lik_ci_lik_ratio_fallback and records the reason in
# cached_values$ci_fallback_reason["gradient"], like the Wald-fallback convention (TODO-115).
#
# Seeds: incidence calibration reps (cal_run_rep() seed formula, cal_rt_index("incidence") = 2,
# DesignFixedBernoulli, null effect, `~.`). In 1600 reps (n = 50 / 200, prob_T 0.5 / 0.2, `~1` / `~.`)
# the substitution fired only at n = 50 `~.` (reps 31 @ 0.5; 4, 30, 81 @ 0.2): the MLE has a y = 1
# row at exp(X b) = 1 and the gradient test is undefined at delta = estimate (boundary null fit not
# a Kuhn-Tucker point to tolerance / multipliers not identified).

cal_incidence_rep <- function(n, rep, prob_T = 0.5) {
	set.seed(1e6 * 2L + 7L * n + rep)
	X <- data.frame(x1 = stats::rnorm(n), x2 = stats::rbinom(n, 1L, 0.5))
	des <- if (prob_T == 0.5) DesignFixedBernoulli$new(n = n, response_type = "incidence") else
		DesignFixedBernoulli$new(n = n, response_type = "incidence", prob_T = prob_T)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(ys = stats::rbinom(n, 1L, stats::plogis(-0.5 + 0.5 * X$x1 + 0.5 * X$x2)))
	InferenceIncidLogBinomial$new(des, model_formula = ~ ., verbose = FALSE)
}

quiet_boundary <- function(expr) suppressWarnings(expr, classes = "edi_binomial_mle_boundary_warning")
cv <- function(o) o$.__enclos_env__$private$cached_values

test_that("n = 50 rep 31: the LR interval is returned with a classed warning and a recorded reason", {
	o <- cal_incidence_rep(50L, 31L)
	w <- NULL
	ci <- withCallingHandlers(quiet_boundary(o$compute_gradient_confidence_interval()),
		edi_lik_ci_lik_ratio_fallback = function(cnd) { w <<- cnd; invokeRestart("muffleWarning") })
	expect_s3_class(w, "edi_lik_ci_lik_ratio_fallback")
	expect_identical(w$testing_type, "gradient")
	expect_identical(w$substitute, "lik_ratio")
	expect_match(conditionMessage(w), "NOT a gradient interval", fixed = TRUE)
	lr <- quiet_boundary(o$compute_lik_ratio_confidence_interval())
	expect_equal(unname(ci), unname(lr), tolerance = 1e-8)
	expect_equal(unname(ci), c(-1.3235562, -0.1303495), tolerance = 1e-6)
	expect_named(ci, c("2.5%", "97.5%"))
	rec <- cv(o)$ci_fallback_reason[["gradient"]]
	expect_match(rec, "likelihood-ratio interval was returned", fixed = TRUE)
	expect_match(rec, "Kuhn-Tucker", fixed = TRUE)
	expect_false(o$is_nonestimable())
})

test_that("the substitution warns once per object, and the held NA warning is not shown", {
	o <- cal_incidence_rep(50L, 31L)
	classes <- character()
	collect <- function(expr) withCallingHandlers(quiet_boundary(expr),
		warning = function(cnd) { classes <<- c(classes, class(cnd)[1L]); invokeRestart("muffleWarning") })
	collect(o$compute_gradient_confidence_interval())
	expect_identical(classes, "edi_lik_ci_lik_ratio_fallback")
	classes <- character()
	ci2 <- collect(o$compute_gradient_confidence_interval(0.10))
	expect_length(classes, 0L)
	expect_true(all(is.finite(ci2)))
})

test_that("n = 50 rep 30 @ prob_T 0.2: the substituted LR interval is a real LR interval (TODO-179 feasible null start)", {
	# Until 2026-11-09 the LR inversion here also failed (every null-refit start
	# was infeasible beyond the estimate) and fell back to the Wald interval.
	# v1.0.5 TODO-179 added a strictly feasible last-resort start to fit_null.
	o <- cal_incidence_rep(50L, 30L, prob_T = 0.2)
	w <- NULL
	ci <- withCallingHandlers(quiet_boundary(o$compute_gradient_confidence_interval()),
		edi_lik_ci_lik_ratio_fallback = function(cnd) { w <<- cnd; invokeRestart("muffleWarning") })
	expect_s3_class(w, "edi_lik_ci_lik_ratio_fallback")
	expect_identical(w$substitute, "lik_ratio")
	lr <- quiet_boundary(o$compute_lik_ratio_confidence_interval())
	expect_equal(unname(ci), unname(lr), tolerance = 1e-8)
	expect_false("lik_ratio" %in% names(cv(o)$ci_fallback_reason))
	spec <- o$.__enclos_env__$private$get_likelihood_test_spec()
	lr_at <- function(d) 2 * (spec$neg_loglik(spec$fit_null(d)) - spec$neg_loglik(spec$full_fit))
	expect_equal(c(lr_at(ci[[1L]]), lr_at(ci[[2L]])), rep(stats::qchisq(0.95, 1), 2L), tolerance = 1e-3)
})

test_that("when the LR inversion itself fell back to Wald, the substitute is reported as Wald", {
	o <- cal_incidence_rep(50L, 30L, prob_T = 0.2)
	quiet_boundary(o$compute_estimate())
	priv <- o$.__enclos_env__$private
	priv$cached_values$ci_fallback_reason <- c(lik_ratio = "the root search returned no finite bounds")
	w <- NULL
	withCallingHandlers(edi_warn_log_binomial_gradient_ci_lik_ratio_substitution_once(o, priv),
		edi_lik_ci_lik_ratio_fallback = function(cnd) { w <<- cnd; invokeRestart("muffleWarning") })
	expect_s3_class(w, "edi_lik_ci_lik_ratio_fallback")
	expect_identical(w$substitute, "wald")
	expect_match(cv(o)$ci_fallback_reason[["gradient"]], "itself the Wald interval", fixed = TRUE)
})

test_that("an ordinary fit (n = 200 rep 2) inverts the gradient test itself: no substitution", {
	o <- cal_incidence_rep(200L, 2L)
	expect_no_warning(ci <- quiet_boundary(o$compute_gradient_confidence_interval()), class = "edi_lik_ci_lik_ratio_fallback")
	expect_true(all(is.finite(ci)))
	expect_false("gradient" %in% names(cv(o)$ci_fallback_reason))
	lr <- quiet_boundary(o$compute_lik_ratio_confidence_interval())
	expect_false(isTRUE(all.equal(unname(ci), unname(lr), tolerance = 1e-6)))
})
