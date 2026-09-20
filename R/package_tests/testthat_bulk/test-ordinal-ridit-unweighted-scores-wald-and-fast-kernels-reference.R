library(testthat)
library(EDI)

# InferenceOrdinalRidit's unweighted layer: shared() (estimate, mean ridits,
# per-subject scores, SE caching), the two accessors, the normal-theory Wald
# outputs, and the fast randomization / bootstrap kernels and their decline
# guards, against a from-scratch ridit reference (Bross ridits relative to the
# reference distribution: r_k = sum_{j<k} p_j + p_k / 2).

rid_fx <- function(seed = 3L, n = 60L, reference = "control") {
	set.seed(seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "ordinal", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$overwrite_all_subject_assignments(rep(0:1, length.out = n))
	w <- des$get_w()
	y <- as.integer(pmin(sample(1:4, n, TRUE, prob = c(.4, .3, .2, .1)) + w * (runif(n) < .3), 4L))
	des$add_all_subject_responses(y)
	inf <- InferenceOrdinalRidit$new(des, reference = reference, verbose = FALSE)
	list(inf = inf, p = inf$.__enclos_env__$private, w = w, y = y, n = n)
}

ref_ridit <- function(y, w, reference) {
	ref_idx <- switch(reference, control = w == 0, treatment = w == 1, pooled = rep(TRUE, length(y)))
	cats <- sort(unique(y))
	p <- vapply(cats, function(k) mean(y[ref_idx] == k), numeric(1))
	r <- cumsum(p) - p / 2
	score <- r[match(y, cats)]
	list(scores = score, mean_t = mean(score[w == 1]), mean_c = mean(score[w == 0]), est = mean(score[w == 1]) - 0.5)
}

test_that("estimate, mean ridits and per-subject scores match the ridit definition for every reference group", {
	for (ref in c("control", "treatment", "pooled")) {
		f <- rid_fx(reference = ref)
		r <- ref_ridit(f$y, f$w, ref)
		expect_equal(f$inf$compute_estimate(), r$est, tolerance = 1e-10, info = ref)
		expect_equal(f$inf$get_mean_ridit_treatment(), r$mean_t, tolerance = 1e-10, info = ref)
		expect_equal(f$inf$get_ridit_scores(), r$scores, tolerance = 1e-10, info = ref)
		expect_equal(f$p$cached_values$mean_ridit_c, r$mean_c, tolerance = 1e-10, info = ref)
	}
	# The reference group's own mean ridit is exactly 1/2 under control / treatment referencing.
	expect_equal(rid_fx(reference = "control")$inf$get_mean_ridit_treatment() -
		ref_ridit(rid_fx()$y, rid_fx()$w, "control")$mean_t, 0)
	fc <- rid_fx(reference = "control"); fc$inf$compute_estimate()
	expect_equal(fc$p$cached_values$mean_ridit_c, 0.5)
})

test_that("estimate_only skips the SE, and a later full request computes it", {
	f <- rid_fx()
	f$inf$compute_estimate(estimate_only = TRUE)
	expect_null(f$p$cached_values$s_beta_hat_T)
	est <- f$p$cached_values$beta_hat_T
	f$p$shared(estimate_only = FALSE)
	expect_true(is.finite(f$p$cached_values$s_beta_hat_T) && f$p$cached_values$s_beta_hat_T > 0)
	expect_equal(f$p$cached_values$beta_hat_T, est)
	g <- rid_fx(); g$inf$compute_estimate(estimate_only = TRUE)
	expect_true(is.finite(g$inf$compute_asymp_two_sided_pval(0)))          # estimate-only first, then Wald output
	expect_true(all(is.finite(g$inf$compute_asymp_confidence_interval())))
	h <- rid_fx()                                                            # full request first
	expect_true(is.finite(h$inf$compute_asymp_two_sided_pval(0)))
})

test_that("Wald p-value and interval are normal-theory functions of the estimate and its SE", {
	f <- rid_fx()
	est <- f$inf$compute_estimate()
	f$inf$compute_asymp_two_sided_pval(0)
	se <- f$p$cached_values$s_beta_hat_T
	expect_equal(f$inf$compute_asymp_two_sided_pval(0), 2 * pnorm(-abs(est / se)), tolerance = 1e-10)
	expect_equal(f$inf$compute_asymp_two_sided_pval(0.1), 2 * pnorm(-abs((est - 0.1) / se)), tolerance = 1e-10)
	expect_equal(as.numeric(f$inf$compute_asymp_confidence_interval(0.1)), est + c(-1, 1) * qnorm(0.95) * se, tolerance = 1e-10)
	expect_equal(names(f$inf$compute_asymp_confidence_interval(0.1)), c("5%", "95%"))
	expect_error(f$inf$compute_asymp_two_sided_pval("a"))
})

test_that("the randomization kernel equals the ridit estimate recomputed per permutation, and declines off the sharp null", {
	f <- rid_fx()
	set.seed(5)
	W <- cbind(f$w, 1 - f$w, replicate(6, sample(f$w)))
	got <- f$p$compute_fast_randomization_distr(f$y, list(w_mat = W), 0, "none")
	ref <- vapply(seq_len(ncol(W)), function(j) {
		w <- W[, j]
		if (!any(w == 1) || !any(w == 0)) return(NA_real_)
		ref_ridit(f$y, w, "control")$est
	}, numeric(1))
	expect_equal(got, ref, tolerance = 1e-10)
	expect_null(f$p$compute_fast_randomization_distr(f$y, list(w_mat = W), 0.2, "none"))
	expect_null(f$p$compute_fast_randomization_distr(f$y, list(w_mat = W), 0, "log"))
})

test_that("the simple bootstrap kernel reproduces the ridit estimate on the same resampled indices", {
	f <- rid_fx()
	set.seed(11)
	got <- f$p$compute_fast_bootstrap_distr(6L, f$n, f$y, rep(1, f$n), f$w)
	set.seed(11)
	ref <- vapply(1:6, function(b) {
		repeat {
			i_b <- sample(f$n, f$n, replace = TRUE)
			if (any(f$w[i_b] == 1) && any(f$w[i_b] == 0)) break
		}
		ref_ridit(f$y[i_b], f$w[i_b], "control")$est
	}, numeric(1))
	expect_length(got, 6L)
	expect_equal(got, ref, tolerance = 1e-10)
	# A treatment-free assignment can never yield both arms: every attempt fails and the replicate is NA.
	set.seed(12)
	none <- f$p$compute_fast_bootstrap_distr(3L, f$n, f$y, rep(1, f$n), rep(0, f$n))
	expect_true(all(is.na(none)))
	f$p$is_KK <- TRUE                                                 # KK designs decline
	expect_null(f$p$compute_fast_bootstrap_distr(6L, f$n, f$y, rep(1, f$n), f$w))
})

test_that("randomization-bootstrap kernel declines for a shifted null and for smoothed draws", {
	f <- rid_fx()
	expect_null(f$p$compute_fast_rand_bootstrap_distr(f$y, list(), 0.5, "none"))
	expect_null(f$p$compute_fast_rand_bootstrap_distr(f$y, list(list(smooth_noise = c(0.1, 0.2))), 0, "none"))
})
