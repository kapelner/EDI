library(testthat)
library(EDI)

# The parametric-bootstrap replicate loop read each simulated refit's coefficient as
# `(fit$b %||% fit$params)[spec$j]`, but spec$j indexes the ANCHOR fit's vector. For
# InferenceOrdinalAdjCatLogitRegr the anchor exposes only `params` (thresholds + slopes) while a
# refit exposes both `b` (slopes only) and `params`, so a replicate read b[j]: NA with few
# covariates (zero usable replicates) or a different covariate's slope with many (replicates of
# +10..+30 around a treatment estimate of -0.25, giving a CI of about [-30, -11]). Found
# 2026-09-21 via a comprehensive_tests results audit (iris).

pb_fixture = function(n_cov = 2L, n = 150L, seed = 1L) {
	set.seed(seed)
	X = as.data.frame(matrix(rnorm(n * n_cov), n, n_cov)); colnames(X) = paste0("x", seq_len(n_cov))
	w = rbinom(n, 1, 0.5)
	y = as.integer(cut(0.4 * w + 0.6 * X$x1 + rlogis(n), c(-Inf, -1, 0, 1, Inf)))
	d = DesignFixedBernoulli$new(n = n, response_type = "ordinal", verbose = FALSE)
	d$add_all_subjects_to_experiment(X)
	d$overwrite_all_subject_assignments(w)
	d$add_all_subject_responses(y)
	d
}

pb_replicates = function(cls, des, B = 20L) {
	inst = get(cls, envir = asNamespace("EDI"))$new(des)
	est = suppressWarnings(inst$compute_estimate())
	batch = suppressMessages(suppressWarnings(inst$.__enclos_env__$private$run_param_bootstrap_estimate_batch(B = B, max_attempts_per_replicate = 2L, show_progress = FALSE)))
	list(est = est, batch = batch)
}

test_that("AdjCat parametric-bootstrap replicates are the treatment coefficient, with few and with many covariates", {
	for (n_cov in c(2L, 6L)) {
		r = pb_replicates("InferenceOrdinalAdjCatLogitRegr", pb_fixture(n_cov))
		expect_false(is.null(r$batch))
		expect_gte(r$batch$n_success, 10L)
		sd_reps = stats::sd(r$batch$finite_reps)
		expect_lt(abs(stats::median(r$batch$finite_reps) - r$est), 3 * sd_reps + 0.3)
	}
})

test_that("every cheap ordinal threshold class yields parametric-bootstrap replicates centred near its estimate", {
	des = pb_fixture(3L)
	bad = character()
	for (cls in c("InferenceOrdinalAdjCatLogitRegr", "InferenceOrdinalPropOddsRegr", "InferenceOrdinalCauchitRegr",
			"InferenceOrdinalCloglogRegr", "InferenceOrdinalOrderedProbitRegr", "InferenceOrdinalContRatioRegr")) {
		r = pb_replicates(cls, des)
		ok = !is.null(r$batch) && r$batch$n_success >= 10L &&
			abs(stats::median(r$batch$finite_reps) - r$est) < 3 * stats::sd(r$batch$finite_reps) + 0.3
		if (!isTRUE(ok)) bad = c(bad, cls)
	}
	expect_equal(bad, character())
})
