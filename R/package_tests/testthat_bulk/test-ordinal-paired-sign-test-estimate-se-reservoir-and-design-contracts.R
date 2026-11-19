library(testthat)
library(EDI)

# docs-claims audit, finding docs-claims-d442518ff: InferenceOrdinalPairedSignTest claims
# (inference_ordinal_paired_sign_test.R) -- beta_hat_T = p_hat - 0.5 over untied pairs with ties
# dropped, SE = sqrt(p_hat (1 - p_hat) / n_eff), reservoir subjects ignored, no likelihood tests,
# randomization p-value available, and a matching design required.

sign_kk_design <- function(seed = 1L, n = 30L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "ordinal", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	des
}

sign_kk_fixture <- function(y_seed = 2L) {
	des <- sign_kk_design()
	set.seed(y_seed)
	y <- sample(1:5, 30L, replace = TRUE)
	des$add_all_subject_responses(y)
	inf <- InferenceOrdinalPairedSignTest$new(des, verbose = FALSE)
	list(des = des, inf = inf, p = inf$.__enclos_env__$private, y = y)
}

test_that("beta_hat_T is p_hat - 0.5 over untied pairs, with injected diffs mixing ties and an asymmetric sign count", {
	f <- sign_kk_fixture()
	f$p$cached_values$KKstats <- list(y_matched_diffs = c(1, 2, 0, -1, 3))
	expect_equal(f$inf$compute_estimate(), 3 / 4 - 0.5)
	expect_equal(f$p$cached_values$s_beta_hat_T, sqrt(0.75 * 0.25 / 4))
})

test_that("on a real KK fixture the estimate and Wald CI half-width follow the sign-count formulas", {
	f <- sign_kk_fixture()
	est <- f$inf$compute_estimate()
	m <- f$p$m; w <- f$p$w; y <- f$p$y
	diffs <- vapply(sort(unique(m[m > 0])), function(pid) {
		idx <- which(m == pid)
		y[idx[w[idx] == 1]] - y[idx[w[idx] == 0]]
	}, numeric(1))
	pos <- sum(diffs > 0); neg <- sum(diffs < 0); n_eff <- pos + neg
	expect_gt(sum(diffs == 0), 0L)  # the fixture has ties
	expect_false(pos == neg)        # and an asymmetric sign count
	p_hat <- pos / n_eff
	expect_equal(est, p_hat - 0.5)
	alpha <- 0.1
	ci <- f$inf$compute_asymp_confidence_interval(alpha = alpha)
	half <- qnorm(1 - alpha / 2) * sqrt(p_hat * (1 - p_hat) / n_eff)
	expect_equal(unname(ci), est + c(-1, 1) * half, tolerance = 1e-12)
	expect_equal(unname(diff(ci)) / 2, half, tolerance = 1e-12)
})

test_that("reservoir (unmatched) subjects do not affect the estimate or SE", {
	f1 <- sign_kk_fixture()
	m <- f1$p$m
	reservoir <- which(m == 0L)
	expect_gt(length(reservoir), 0L)
	y2 <- f1$y
	y2[reservoir] <- ifelse(y2[reservoir] >= 3L, 1L, 5L)  # change every reservoir response
	des2 <- sign_kk_design()
	des2$add_all_subject_responses(y2)
	inf2 <- InferenceOrdinalPairedSignTest$new(des2, verbose = FALSE)
	expect_identical(inf2$.__enclos_env__$private$m, m)
	expect_equal(inf2$compute_estimate(), f1$inf$compute_estimate())
	expect_equal(inf2$compute_asymp_confidence_interval(), f1$inf$compute_asymp_confidence_interval())
})

test_that("supports_likelihood_tests() is FALSE and only Wald inference is exposed", {
	f <- sign_kk_fixture()
	expect_false(f$p$supports_likelihood_tests())
	expect_identical(f$inf$get_supported_testing_types(), "wald")
	for (tt in c("score", "gradient", "lik_ratio")) {
		expect_error(f$inf$set_testing_type(tt), "does not support testing_type")
	}
	expect_null(f$inf$compute_score_two_sided_pval)
	expect_null(f$inf$compute_lik_ratio_two_sided_pval)
	expect_null(f$inf$compute_gradient_two_sided_pval)
})

test_that("compute_rand_two_sided_pval returns a valid p-value on a KK design", {
	f <- sign_kk_fixture()
	set.seed(11)
	pval <- f$inf$compute_rand_two_sided_pval(r = 49, show_progress = FALSE)
	expect_length(pval, 1L)
	expect_true(is.finite(pval) && pval >= 0 && pval <= 1)
})

test_that("$new() on a non-matching design throws the matching-design requirement", {
	set.seed(3)
	n <- 12L
	des <- DesignFixedBernoulli$new(n = n, response_type = "ordinal", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$overwrite_all_subject_assignments(rep(0:1, n / 2L))
	des$add_all_subject_responses(sample(1:4, n, replace = TRUE))
	expect_error(InferenceOrdinalPairedSignTest$new(des, verbose = FALSE),
		"requires a KK matching-on-the-fly design")
})
