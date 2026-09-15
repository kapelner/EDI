library(EDI)

# Smoothed BRT noise must respect the response support. Raw-scale Gaussian noise
# added to count responses produced negative / non-integer counts, so every
# glmmTMB Poisson fit in the smoothed null distribution failed with
# "negative values not allowed for the 'Poisson' family" (2026-09-15 count suite,
# InferenceCountKKGLMM on diamonds).

make_smoothed_count_kk_design <- function(seed = 20260915L, n = 40L){
	set.seed(seed)
	x1 <- rnorm(n)
	x2 <- rnorm(n)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "count", verbose = FALSE)
	for (i in seq_len(n)) {
		w_i <- des$add_one_subject_to_experiment_and_assign(data.frame(x1 = x1[i], x2 = x2[i]))
		mu_i <- exp(0.20 + 0.35 * w_i + 0.20 * x1[i] - 0.10 * x2[i] + rnorm(1, sd = 0.15))
		des$add_one_subject_response(i, rpois(1L, lambda = mu_i))
	}
	des
}

test_that("add_rand_bootstrap_smooth_noise keeps count responses on the non-negative integer support", {
	des <- make_smoothed_count_kk_design()
	inf <- InferenceCountKKGLMM$new(des, model_formula = ~ x1 + x2, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	y <- c(0L, 0L, 1L, 3L, 7L)
	noise <- c(-0.9, 0.4, -0.6, 0.51, -2.7)
	y_count <- priv$add_rand_bootstrap_smooth_noise(y, noise, "count")
	expect_true(is.integer(y_count))
	expect_true(all(y_count >= 0L))
	expect_equal(y_count, c(0L, 0L, 0L, 4L, 4L))
	# continuous responses keep the raw additive kernel noise
	expect_equal(priv$add_rand_bootstrap_smooth_noise(as.numeric(y), noise, "continuous"), as.numeric(y) + noise)
})

test_that("smoothed BRT p-value for a glmmTMB Poisson GLMM emits no GLMM fit errors", {
	skip_if_not_installed("glmmTMB")
	des <- make_smoothed_count_kk_design()
	# use_rcpp = FALSE routes every null-draw refit through glmmTMB, whose Poisson
	# family rejects negative responses outright: before the fix all B draws failed
	# ("GLMM FIT ERROR: negative values not allowed for the 'Poisson' family") and the
	# p-value was NA. (With use_rcpp = TRUE the same failure surfaced only at the CI
	# inversion's large null shifts, where round(y_noisy * e^delta) went far negative.)
	inf <- InferenceCountKKGLMM$new(des, model_formula = ~ x1 + x2, use_rcpp = FALSE, verbose = FALSE)
	inf$set_seed(20260915L)
	msgs <- capture_messages(
		pval <- inf$compute_rand_bootstrap_two_sided_pval(B = 12L, type = "smoothed", show_progress = FALSE)
	)
	expect_false(any(grepl("GLMM FIT ERROR", msgs, fixed = TRUE)), info = paste(head(msgs, 3), collapse = "\n"))
	expect_true(is.finite(pval))
	expect_true(pval >= 0 && pval <= 1)
})
