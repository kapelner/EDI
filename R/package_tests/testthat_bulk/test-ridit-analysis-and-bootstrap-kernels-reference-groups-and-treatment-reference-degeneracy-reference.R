library(testthat)
library(EDI)

# fast_ridit_scores_cpp / fast_ridit_analysis_cpp / compute_ridit_rand_bootstrap_parallel_cpp:
# ridit scores r_k = P(Y < k) + P(Y = k) / 2 in a reference group, the estimate (mean treated ridit - 0.5)
# and its SE (sd(treated scores) / sqrt(n_T)), for reference = "control" and "pooled" against hand
# computations; the bootstrap kernel against the same statistic per replicate. A treatment reference
# uses 0.5 - mean control ridit, preserving the treated-minus-control orientation while avoiding the
# reference group's own identically-0.5 mean.

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

test_that("treatment-reference analysis uses the control comparison mean and preserves effect orientation", {
	f <- fx()
	r <- K("fast_ridit_analysis_cpp")(f$w, f$y, "treatment")
	r_control <- K("fast_ridit_analysis_cpp")(f$w, f$y, "control")
	expect_equal(r$mean_ridit_t, 0.5, tolerance = 1e-12)
	expect_equal(r$estimate, 0.5 - r$mean_ridit_c, tolerance = 1e-12)
	expect_equal(r$estimate, r_control$estimate, tolerance = 1e-12)
	expect_equal(r$se, sd(r$scores[f$w == 0]) / sqrt(sum(f$w == 0)), tolerance = 1e-12)
	expect_gt(r$estimate, 0.05)
	set.seed(9)
	i_mat <- vapply(1:4, function(b) sample(f$n, f$n, TRUE), integer(f$n))
	w_mat <- vapply(1:4, function(b) sample(f$w), numeric(f$n)); storage.mode(w_mat) <- "integer"
	got <- K("compute_ridit_rand_bootstrap_parallel_cpp")(f$y, i_mat, w_mat, "treatment", 1L)
	control <- K("compute_ridit_rand_bootstrap_parallel_cpp")(f$y, i_mat, w_mat, "control", 1L)
	expect_equal(as.numeric(got), as.numeric(control), tolerance = 1e-12)
	expect_true(any(abs(got) > 0.01))
})

test_that("class treatment reference reports the same non-degenerate effect orientation as control", {
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
	expect_equal(trt$compute_estimate(), ctrl$compute_estimate(), tolerance = 1e-12)
	expect_lt(trt$compute_asymp_two_sided_pval(0), 0.01)
})
