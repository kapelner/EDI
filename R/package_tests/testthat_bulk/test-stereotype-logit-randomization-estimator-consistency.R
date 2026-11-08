library(testthat)
library(EDI)

# TODO-178 (release_v1_0_5.md, fixed 2026-11-07): InferenceOrdinalStereotypeLogitRegr
#   (1) computed the observed randomization statistic with a single-start refit from the object's warm
#       start (not the class's multistart estimator the workers apply to each draw) and wrote that
#       refit's "params" back as the object's warm start, so later fits on the object (the SE fit,
#       bootstrap draws, likelihood null refits) depended on whether a randomization p had been
#       computed;
#   (2) gave different estimates for compute_estimate(estimate_only = TRUE) (what every
#       randomization / bootstrap draw uses) and compute_estimate(): the estimate-only path kept a
#       screening fit with no information matrix (so the TODO-176 loading-boundary / PD rule never ran)
#       and the full path kept the C++ fit's early stop.
# Since the fix the hook is shared() + the cached estimate, the primary fit is always cold, and both
# modes select by neg-loglik and then compute the information at the selected parameters.
#
# Data: the calibration fast tier's ordinal null replicates at n = 200 (see
# test-stereotype-logit-null-refit-history-independence.R). Before the fix: rep 26 `~ 1`
# estimate_only 0.27434 vs 0.26741 (true saturated MLE 0.27395); after a randomization p the Wald CI
# was (-0.4769, 1.0248) vs (-0.5174, 1.0522) fresh; rep 1 `~ .` observed randomization statistic 0.497
# (cold single start) vs the reported estimate 0.391.

stereotype_null_rep <- function(rep = 1L, n = 200L, model_formula = ~ .) {
	set.seed(1e6 * 5 + 7L * n + rep)
	X <- data.frame(x1 = stats::rnorm(n), x2 = stats::rbinom(n, 1L, 0.5))
	des <- DesignFixedBernoulli$new(n = n, response_type = "ordinal", verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	lat <- 0.5 * X$x1 + 0.5 * X$x2 + stats::rlogis(n)
	des$add_all_subject_responses(factor(cut(lat, c(-Inf, -1, 0, 1, Inf), labels = FALSE), levels = 1:4, ordered = TRUE))
	inf <- InferenceOrdinalStereotypeLogitRegr$new(des, model_formula = model_formula, verbose = FALSE)
	inf$num_cores <- 1L
	inf
}

test_that("estimate_only = TRUE and FALSE give the same estimate (and the same non-estimability)", {
	skip_on_cran()
	for (rep in c(1L, 26L, 28L, 33L)) for (f in list(~ 1, ~ .)) {
		a <- suppressWarnings(stereotype_null_rep(rep, model_formula = f)$compute_estimate(estimate_only = TRUE))
		b <- suppressWarnings(stereotype_null_rep(rep, model_formula = f)$compute_estimate(estimate_only = FALSE))
		expect_identical(a, b, info = paste(rep, deparse(f)))
	}
	# rep 26 `~ 1`: the interior saturated MLE is the log odds ratio of category 4 vs 1.
	expect_equal(suppressWarnings(stereotype_null_rep(26L, model_formula = ~ 1)$compute_estimate()), 0.27395, tolerance = 1e-3)
})

test_that("the observed randomization statistic is the reported estimate", {
	skip_on_cran()
	inf <- stereotype_null_rep(1L)
	t_obs <- inf$.__enclos_env__$private$compute_treatment_estimate_during_randomization_inference(estimate_only = TRUE)
	expect_identical(t_obs, stereotype_null_rep(1L)$compute_estimate())
	expect_null(inf$.__enclos_env__$private$get_fit_warm_start("params"))
})

test_that("a randomization p-value leaves later fits on the object unchanged", {
	skip_on_cran()
	for (f in list(~ 1, ~ .)) {
		a <- stereotype_null_rep(26L, model_formula = f)
		set.seed(5)
		invisible(suppressWarnings(a$compute_rand_two_sided_pval(r = 30, show_progress = FALSE)))
		b <- stereotype_null_rep(26L, model_formula = f)
		expect_identical(suppressWarnings(a$compute_asymp_confidence_interval()),
			suppressWarnings(b$compute_asymp_confidence_interval()), info = deparse(f))
		set.seed(7)
		bd_a <- suppressWarnings(a$approximate_bootstrap_distribution_beta_hat_T(B = 15, show_progress = FALSE))
		# b has the same history except the randomization p (a brand-new object
		# draws different bootstrap indices from the same seed).
		set.seed(7)
		bd_b <- suppressWarnings(b$approximate_bootstrap_distribution_beta_hat_T(B = 15, show_progress = FALSE))
		expect_identical(bd_a, bd_b, info = deparse(f))
	}
})
