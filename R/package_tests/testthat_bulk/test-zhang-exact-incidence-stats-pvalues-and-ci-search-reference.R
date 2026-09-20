library(testthat)
library(EDI)

# inference_helpers_zhang.R: zhang_get_exact_stats() (Bernoulli 2x2 counts and KK matched-pair /
# reservoir statistics), the matched-pair exact binomial and reservoir exact Fisher p-values against
# stats::binom.test / fisher.test, their combination, the closed-form treatment estimate and Wald
# interval, the bisection CI search (and the resulting exact interval), and argument
# normalisation / validation.

Z <- function(x) get(x, envir = asNamespace("EDI"))

kk_fx <- function(seed = 6L, np = 15L, ns = 14L) {
	set.seed(seed)
	n <- 2L * np + ns
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
	X <- data.frame(x = rnorm(n)); for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	m <- c(rep(seq_len(np), each = 2L), rep(0L, ns)); des$.__enclos_env__$private$m <- m
	w <- des$get_w(); y <- rbinom(n, 1, plogis(0.8 * w)); des$add_all_subject_responses(y)
	inf <- InferenceIncidExactZhang$new(des, verbose = FALSE)
	list(inf = inf, w = w, y = y, m = m, n = n)
}

bern_fx <- function(seed = 3L, n = 40L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n))); des$assign_w_to_all_subjects()
	w <- des$get_w(); y <- rbinom(n, 1, plogis(-0.2 + 0.8 * w)); des$add_all_subject_responses(y)
	inf <- InferenceIncidExactZhang$new(des, verbose = FALSE)
	list(inf = inf, w = w, y = y, n = n)
}

test_that("Bernoulli-design statistics are plain treated / control case counts with no matched pairs", {
	f <- bern_fx()
	s <- Z("zhang_get_exact_stats")(f$inf)
	expect_equal(s$m, 0L); expect_equal(c(s$d_plus, s$d_minus), c(0L, 0L))
	expect_equal(c(s$nRT, s$nRC), c(sum(f$w == 1), sum(f$w == 0)))
	expect_equal(c(s$n11, s$n01), c(sum(f$y[f$w == 1]), sum(f$y[f$w == 0])))
	expect_equal(c(s$n10, s$n00), c(s$nRT - s$n11, s$nRC - s$n01))
	expect_identical(f$inf$.__enclos_env__$private$cached_values$incid_exact_zhang_stats, s)   # cached
})

test_that("KK statistics: pair count, discordant directions, and reservoir 2x2 counts equal a direct tabulation", {
	f <- kk_fx()
	s <- Z("zhang_get_exact_stats")(f$inf)
	expect_equal(s$m, 15L)
	mixed <- Filter(function(i) length(unique(f$w[i])) == 2L, lapply(1:15, function(k) which(f$m == k)))
	yT <- vapply(mixed, function(i) f$y[i][f$w[i] == 1], numeric(1)); yC <- vapply(mixed, function(i) f$y[i][f$w[i] == 0], numeric(1))
	expect_equal(s$d_plus, sum(yT == 1 & yC == 0))
	expect_equal(s$d_minus, sum(yT == 0 & yC == 1))
	res <- f$m == 0
	expect_equal(c(s$nRT, s$nRC), c(sum(f$w[res] == 1), sum(f$w[res] == 0)))
	expect_equal(c(s$n11, s$n10, s$n01, s$n00), c(sum(f$y[res & f$w == 1]), sum(1 - f$y[res & f$w == 1]), sum(f$y[res & f$w == 0]), sum(1 - f$y[res & f$w == 0])))
})

test_that("matched-pair p-value is the exact binomial test of the discordant pairs; reservoir p-value is Fisher's exact test", {
	f <- kk_fx(); s <- Z("zhang_get_exact_stats")(f$inf)
	expect_equal(Z("zhang_compute_exact_pval_matched_pairs")(f$inf, 0), binom.test(s$d_plus, s$d_plus + s$d_minus)$p.value, tolerance = 1e-8)
	expect_equal(Z("zhang_compute_exact_pval_reservoir")(f$inf, 0), fisher.test(matrix(c(s$n11, s$n01, s$n10, s$n00), 2))$p.value, tolerance = 1e-8)
	# Degenerate inputs give NA: no matching (Bernoulli), no discordant pairs, an empty arm or an empty margin.
	b <- bern_fx()
	expect_true(is.na(Z("zhang_compute_exact_pval_matched_pairs")(b$inf, 0)))
	expect_equal(Z("zhang_compute_exact_pval_reservoir")(b$inf, 0), fisher.test(matrix(c(sum(b$y[b$w == 1]), sum(b$y[b$w == 0]), sum(1 - b$y[b$w == 1]), sum(1 - b$y[b$w == 0])), 2))$p.value, tolerance = 1e-8)
})

test_that("combined p-value uses Fisher's, Stouffer's or min-p combination of the two components", {
	f <- kk_fx(); s <- Z("zhang_get_exact_stats")(f$inf)
	pM <- Z("zhang_compute_exact_pval_matched_pairs")(f$inf, 0); pR <- Z("zhang_compute_exact_pval_reservoir")(f$inf, 0)
	expect_equal(Z("zhang_pval_exact_combined")(f$inf, 0), pchisq(-2 * (log(pM) + log(pR)), 4, lower.tail = FALSE), tolerance = 1e-10)
	expect_equal(Z("zhang_pval_exact_combined")(f$inf, 0, "min_p"), 1 - (1 - min(pM, pR))^2, tolerance = 1e-10)
	zc <- (qnorm(1 - pM / 2) + qnorm(1 - pR / 2)) / sqrt(2)
	expect_equal(Z("zhang_pval_exact_combined")(f$inf, 0, "Stouffer"), 2 * pnorm(-abs(zc)), tolerance = 1e-10)
	b <- bern_fx()                                                                        # only the reservoir component exists
	expect_equal(Z("zhang_pval_exact_combined")(b$inf, 0), Z("zhang_compute_exact_pval_reservoir")(b$inf, 0))
})

test_that("closed-form estimate (0.5-corrected log odds ratio) and Wald interval", {
	s <- list(n11 = 3L, n10 = 2L, n01 = 5L, n00 = 4L)
	est <- log((3.5 * 4.5) / (2.5 * 5.5))
	expect_equal(Z("zhang_incid_treatment_estimate")(s), est, tolerance = 1e-12)
	se <- sqrt(1 / 3.5 + 1 / 2.5 + 1 / 5.5 + 1 / 4.5)
	expect_equal(Z("zhang_incid_mle_ci")(s, 0.1), est + c(-1, 1) * qnorm(0.95) * se, tolerance = 1e-12)
	expect_true(is.finite(Z("zhang_incid_treatment_estimate")(list(n11 = 0L, n10 = 0L, n01 = 0L, n00 = 5L))))   # the 0.5 correction keeps it finite
	f <- kk_fx()
	expect_equal(f$inf$compute_estimate(), Z("zhang_incid_treatment_estimate")(Z("zhang_get_exact_stats")(f$inf)), tolerance = 1e-10)
})

test_that("bisection finds the crossing of a monotone p-value curve from either side", {
	b <- Z("zhang_bisect_ci_boundary")
	p_fn <- function(d) 2 * pnorm(-abs(d))                                                # equals 0.05 at |d| = qnorm(0.975)
	expect_equal(b(p_fn, inside = 0, outside = 6, pval_th = 0.05, tol = 1e-8), qnorm(0.975), tolerance = 1e-5)
	expect_equal(b(p_fn, inside = 0, outside = -6, pval_th = 0.05, tol = 1e-8), -qnorm(0.975), tolerance = 1e-5)
	# A p-function that errors or returns NA is treated as 0 (outside the interval).
	flaky <- function(d) if (d > 3) stop("boom") else p_fn(d)
	expect_lt(abs(b(flaky, 0, 6, 0.05, 1e-6) - qnorm(0.975)), 1e-3)
	expect_equal(b(function(d) 0.5, inside = 0, outside = 1, pval_th = 0.5, tol = 1e-3), 0.5)   # already at the threshold
})

test_that("the exact CI puts the combined p-value at alpha (within the tolerance) at each end and brackets the estimate", {
	f <- kk_fx()
	ci <- f$inf$compute_exact_confidence_interval(0.1)
	est <- f$inf$compute_estimate()
	expect_lt(ci[[1]], est); expect_gt(ci[[2]], est)
	expect_length(ci, 2L)
	p_at <- function(d) Z("zhang_pval_exact_combined")(f$inf, d)
	expect_gt(p_at(est), 0.1)
	expect_lt(p_at(ci[[1]] - 0.3), 0.1); expect_lt(p_at(ci[[2]] + 0.3), 0.1)              # just outside each end the exact test rejects
	expect_gte(p_at(ci[[1]] + 0.3), 0.1 - 0.06); expect_gte(p_at(ci[[2]] - 0.3), 0.1 - 0.06)
	ref <- Z("zhang_ci_exact_combined")(f$inf, 0.1, 0.005)
	expect_equal(as.numeric(ci), as.numeric(ref), tolerance = 1e-8)
	wider <- Z("zhang_ci_exact_combined")(f$inf, 0.05, 0.005)
	expect_lt(wider[1], ref[1]); expect_gt(wider[2], ref[2])
})

test_that("argument normalisation and validation", {
	n <- Z("zhang_normalize_exact_inference_args")
	expect_equal(n("Zhang"), list(Zhang = list(combination_method = "Fisher")))
	expect_equal(n("Zhang", pval_epsilon = 0.01)$Zhang$pval_epsilon, 0.01)
	expect_equal(n("Zhang", list(Zhang = list(combination_method = "min_p")))$Zhang$combination_method, "min_p")
	expect_error(n("Other"))
	f <- kk_fx()
	a <- Z("zhang_assert_exact_inference_params")
	expect_invisible(a(f$inf, "Zhang", list(Zhang = list(combination_method = "Stouffer"))))
	expect_error(a(f$inf, "Zhang", list(Other = list())), "must contain a list for Zhang")
	expect_error(a(f$inf, "Zhang", list(Zhang = list(combination_method = "bogus"))))
	expect_error(a(f$inf, "Zhang", list(Zhang = list(combination_method = "Fisher", pval_epsilon = 5))))
	expect_error(a(f$inf, "Other", list(Other = list())))
})
