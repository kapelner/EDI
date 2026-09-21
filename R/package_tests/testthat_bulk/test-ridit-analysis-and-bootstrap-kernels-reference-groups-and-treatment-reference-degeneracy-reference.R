library(testthat)
library(EDI)

# fast_ridit_scores_cpp / fast_ridit_analysis_cpp / compute_ridit_rand_bootstrap_parallel_cpp:
# ridit scores r_k = P(Y < k) + P(Y = k) / 2 in a reference group, the estimate (mean treated ridit - 0.5)
# and its SE (sd(treated scores) / sqrt(n_T)), for reference = "control" and "pooled" against hand
# computations; the bootstrap kernel against the same statistic per replicate. SUSPECTED SOURCE BUG
# (pinned, not fixed): with reference = "treatment" the treated group's mean ridit is exactly 0.5 by
# construction, and the estimate is defined as mean_ridit_t - 0.5, so it is identically 0 (up to rounding)
# whatever the data -- InferenceOrdinalRidit(reference = "treatment") would report no effect.

K <- function(x) get(x, envir = asNamespace("EDI"))

fx <- function() {
	set.seed(4)
	n <- 80L
	w <- rep(0:1, each = 40L)
	y <- as.numeric(pmin(4, pmax(1, round(2.2 + 0.7 * w + rnorm(n)))))
	list(w = w, y = y, n = n)
}
ridit_scores <- function(y, ref) {
	tab <- table(factor(ref, levels = 1:4)); p <- as.numeric(tab / sum(tab))
	(cumsum(p) - p / 2)[y]
}

test_that("control-reference analysis: scores, reference proportions, group means, estimate and SE", {
	f <- fx()
	r <- K("fast_ridit_analysis_cpp")(f$w, f$y)
	sc <- ridit_scores(f$y, f$y[f$w == 0])
	expect_equal(as.numeric(r$scores), sc, tolerance = 1e-12)
	expect_equal(as.numeric(r$ref_p), as.numeric(table(factor(f$y[f$w == 0], levels = 1:4)) / 40), tolerance = 1e-12)
	expect_equal(r$levels, 1:4)
	expect_equal(r$mean_ridit_c, 0.5, tolerance = 1e-12)                   # the reference group's mean ridit is 1/2
	expect_equal(r$mean_ridit_t, mean(sc[f$w == 1]), tolerance = 1e-12)
	expect_equal(r$estimate, mean(sc[f$w == 1]) - 0.5, tolerance = 1e-12)
	expect_equal(r$se, sd(sc[f$w == 1]) / sqrt(40), tolerance = 1e-12)
	expect_gt(r$estimate, 0)                                                # the fixture has a positive effect
})

test_that("fast_ridit_scores_cpp scores each subject against the reference indices", {
	f <- fx()
	got <- K("fast_ridit_scores_cpp")(f$y, which(f$w == 0))
	expect_equal(as.numeric(got$scores), ridit_scores(f$y, f$y[f$w == 0]), tolerance = 1e-12)
	expect_equal(as.numeric(got$ref_p), as.numeric(table(factor(f$y[f$w == 0], levels = 1:4)) / 40), tolerance = 1e-12)
})

test_that("pooled-reference analysis scores against all subjects", {
	f <- fx()
	r <- K("fast_ridit_analysis_cpp")(f$w, f$y, "pooled")
	sc <- ridit_scores(f$y, f$y)
	expect_equal(as.numeric(r$scores), sc, tolerance = 1e-12)
	expect_equal(r$estimate, mean(sc[f$w == 1]) - 0.5, tolerance = 1e-12)
	expect_equal(r$se, sd(sc[f$w == 1]) / sqrt(40), tolerance = 1e-12)
	expect_equal(as.numeric(r$ref_p), as.numeric(table(factor(f$y, levels = 1:4)) / f$n), tolerance = 1e-12)
})

test_that("bootstrap kernel equals the per-replicate control / pooled ridit estimate", {
	f <- fx()
	set.seed(9)
	i_mat <- vapply(1:6, function(b) sample(f$n, f$n, TRUE), integer(f$n))
	w_mat <- vapply(1:6, function(b) sample(f$w), numeric(f$n))
	storage.mode(w_mat) <- "integer"
	for (rf in c("control", "pooled")) {
		got <- K("compute_ridit_rand_bootstrap_parallel_cpp")(f$y, i_mat, w_mat, rf, 1L)
		ref <- vapply(1:6, function(b) {
			yy <- f$y[i_mat[, b]]; ww <- w_mat[, b]
			sc <- ridit_scores(yy, if (rf == "control") yy[ww == 0] else yy)
			mean(sc[ww == 1]) - 0.5
		}, 0)
		expect_equal(as.numeric(got), ref, tolerance = 1e-10, info = rf)
	}
})

test_that("SUSPECTED SOURCE BUG (pinned): reference = 'treatment' makes the estimate identically zero, for the analysis and the bootstrap kernel", {
	f <- fx()
	r <- K("fast_ridit_analysis_cpp")(f$w, f$y, "treatment")
	expect_equal(r$mean_ridit_t, 0.5, tolerance = 1e-12)
	expect_equal(r$estimate, 0, tolerance = 1e-12)
	expect_gt(r$se, 0.01)                                                   # yet the SE is positive: z = 0 whatever the data
	expect_gt(K("fast_ridit_analysis_cpp")(f$w, f$y, "control")$estimate, 0.05)
	set.seed(9)
	i_mat <- vapply(1:4, function(b) sample(f$n, f$n, TRUE), integer(f$n))
	w_mat <- vapply(1:4, function(b) sample(f$w), numeric(f$n)); storage.mode(w_mat) <- "integer"
	got <- K("compute_ridit_rand_bootstrap_parallel_cpp")(f$y, i_mat, w_mat, "treatment", 1L)
	expect_equal(as.numeric(got), rep(0, 4), tolerance = 1e-12)
})

test_that("SUSPECTED SOURCE BUG (pinned) at the class level: InferenceOrdinalRidit(reference = 'treatment') reports estimate 0 and p = 1 even with a strong effect", {
	set.seed(4)
	n <- 80L
	des <- DesignFixediBCRD$new(n = n, response_type = "ordinal", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(as.numeric(pmin(4, pmax(1, round(2.2 + 0.9 * w + rnorm(n))))))
	ctrl <- InferenceOrdinalRidit$new(des, reference = "control", verbose = FALSE)
	trt <- InferenceOrdinalRidit$new(des, reference = "treatment", verbose = FALSE)
	expect_gt(ctrl$compute_estimate(), 0.1)
	expect_lt(ctrl$compute_asymp_two_sided_pval(0), 0.01)
	expect_equal(trt$compute_estimate(), 0, tolerance = 1e-12)
	expect_gt(trt$compute_asymp_two_sided_pval(0), 0.99)
})
