library(testthat)
library(EDI)

# get_memoized_likelihood_test_pval / compute_likelihood_test_two_sided_pval on a real InferenceAsympLik host with a synthetic
# specification: LR p = chisq_1 upper tail of 2 * (null nll - full nll); score p = chisq_1 upper tail of s_j^2 / (I_jj - I_jn I_nn^-1 I_nj);
# Bartlett-corrected LR divides the statistic by a (stubbed) factor;
# results are cached per (type, delta[, B]); unusable pieces give NA and a nonestimable flag.

mk <- function() {
	set.seed(1); n <- 30L
	d <- DesignFixedBernoulli$new(response_type = "continuous", n = n, seed = 1L, verbose = FALSE)
	d$add_all_subjects_to_experiment(data.frame(x = rnorm(n))); d$assign_w_to_all_subjects(); d$add_all_subject_responses(rnorm(n))
	inf <- InferenceContinOLS$new(d, verbose = FALSE); inf$compute_estimate()
	list(inf = inf, p = inf$.__enclos_env__$private)
}
info <- matrix(c(4, 1, 0.5, 1, 3, 0.2, 0.5, 0.2, 2), 3)
calls <- new.env(); calls$fit_null <- 0L
spec_for <- function(full_nll = 10, null_nll = 12, score = c(0.3, 1.2, -0.4), j = 2L, information = info) {
	list(j = j, full_fit = list(params = c(1, 2, 3)),
		fit_null = function(delta, start = NULL) { calls$fit_null <- calls$fit_null + 1L; list(params = c(1, delta, 3), nll = null_nll) },
		neg_loglik = function(fit) if (is.null(fit$nll)) full_nll else fit$nll,
		score = function(fit) score, information = function(fit) information)
}
host_with_spec <- function(h, spec) {
	unlockBinding("get_likelihood_test_spec", h$p); h$p$get_likelihood_test_spec <- function() spec
	unlockBinding("get_score_test_information_matrix", h$p); h$p$get_score_test_information_matrix <- function(spec, fit) spec$information(fit)
	h
}

test_that("likelihood-ratio p-value is the upper chi-square(1) tail of twice the negative log-likelihood gap; cached per delta", {
	h <- host_with_spec(mk(), spec_for(full_nll = 10, null_nll = 12)); calls$fit_null <- 0L
	p <- h$p$compute_likelihood_test_two_sided_pval(0.5, "lik_ratio")
	expect_equal(p, pchisq(2 * (12 - 10), df = 1, lower.tail = FALSE), tolerance = 1e-8)
	expect_equal(h$p$compute_likelihood_test_two_sided_pval(0.5, "lik_ratio"), p)
	expect_identical(calls$fit_null, 1L)
	expect_equal(h$p$compute_likelihood_test_two_sided_pval(0.6, "lik_ratio"), p, tolerance = 1e-8)      # separate delta, same stubbed nlls
	expect_identical(calls$fit_null, 2L)
	g <- host_with_spec(mk(), spec_for(full_nll = 10, null_nll = 10))
	expect_equal(g$p$compute_likelihood_test_two_sided_pval(0, "lik_ratio"), 1, tolerance = 1e-8)
})

test_that("score p-value is chi-square(1) of s_j^2 over the Schur-complement information", {
	h <- host_with_spec(mk(), spec_for())
	s <- c(0.3, 1.2, -0.4); j <- 2L
	I_eff <- info[j, j] - info[j, -j] %*% solve(info[-j, -j]) %*% info[-j, j]
	expect_equal(h$p$compute_likelihood_test_two_sided_pval(0.5, "score"), pchisq(s[j]^2 / drop(I_eff), df = 1, lower.tail = FALSE), tolerance = 1e-6)
})

test_that("score p-value falls back through the ridge branch when the Schur complement is not positive; missing pieces give NA", {
	bad_info <- matrix(c(1, 1, 1, 1, 1, 1, 1, 1, 1), 3)                       # singular
	h <- host_with_spec(mk(), spec_for(information = bad_info))
	p <- h$p$compute_likelihood_test_two_sided_pval(0.5, "score")
	expect_true(is.na(p) || (p >= 0 && p <= 1))
	g <- host_with_spec(mk(), modifyList(spec_for(), list(score = function(fit) stop("no score"))))
	expect_true(is.na(g$p$compute_likelihood_test_two_sided_pval(0.5, "score")))
})

test_that("Bartlett LR divides the LR statistic by the (stubbed) factor; non-positive / failing factors and unsupported classes give NA", {
	h <- host_with_spec(mk(), spec_for(full_nll = 10, null_nll = 12))
	unlockBinding("supports_bartlett_likelihood_ratio_approx", h$p); h$p$supports_bartlett_likelihood_ratio_approx <- function() TRUE
	unlockBinding("get_bartlett_factor_approx", h$p); h$p$get_bartlett_factor_approx <- function(spec, delta, full_fit, null_fit, B) 1.25
	expect_equal(h$p$compute_likelihood_test_two_sided_pval(0.5, "lik_ratio_bartlett_approx", bartlett_B = 50L),
		pchisq(4 / 1.25, df = 1, lower.tail = FALSE), tolerance = 1e-8)
	h$p$get_bartlett_factor_approx <- function(spec, delta, full_fit, null_fit, B) 0
	expect_true(is.na(h$p$compute_likelihood_test_two_sided_pval(0.7, "lik_ratio_bartlett_approx")))
	h$p$get_bartlett_factor_approx <- function(spec, delta, full_fit, null_fit, B) stop("simulation failed")
	expect_true(is.na(h$p$compute_likelihood_test_two_sided_pval(0.8, "lik_ratio_bartlett_approx")))
	off <- host_with_spec(mk(), spec_for()); unlockBinding("supports_bartlett_likelihood_ratio_exact", off$p)
	off$p$supports_bartlett_likelihood_ratio_exact <- function() FALSE
	expect_true(is.na(off$p$compute_likelihood_test_two_sided_pval(0.5, "lik_ratio_bartlett_exact")))
})

test_that("the Bartlett-approx cache is keyed by B: changing B recomputes with the new factor", {
	h <- host_with_spec(mk(), spec_for(full_nll = 10, null_nll = 12))
	unlockBinding("supports_bartlett_likelihood_ratio_approx", h$p); h$p$supports_bartlett_likelihood_ratio_approx <- function() TRUE
	unlockBinding("get_bartlett_factor_approx", h$p); seen <- integer(); h$p$get_bartlett_factor_approx <- function(spec, delta, full_fit, null_fit, B) { seen <<- c(seen, B); B / 50 }
	a <- h$p$compute_likelihood_test_two_sided_pval(0.5, "lik_ratio_bartlett_approx", bartlett_B = 50L)
	a2 <- h$p$compute_likelihood_test_two_sided_pval(0.5, "lik_ratio_bartlett_approx", bartlett_B = 50L)
	b <- h$p$compute_likelihood_test_two_sided_pval(0.5, "lik_ratio_bartlett_approx", bartlett_B = 100L)
	expect_identical(seen, c(50L, 100L)); expect_equal(a, a2)
	expect_equal(a, pchisq(4 / 1, 1, lower.tail = FALSE), tolerance = 1e-8); expect_equal(b, pchisq(4 / 2, 1, lower.tail = FALSE), tolerance = 1e-8)
})

test_that("unsupported testing types error; a missing spec is NA and flags the fit nonestimable; unusable p-values flag the SE", {
	h <- host_with_spec(mk(), spec_for())
	expect_error(h$p$get_memoized_likelihood_test_pval(0, "wald", spec = spec_for()), "Unsupported testing_type: wald")
	g <- mk(); unlockBinding("get_likelihood_test_spec", g$p); g$p$get_likelihood_test_spec <- function() NULL
	expect_true(is.na(g$p$compute_likelihood_test_two_sided_pval(0, "lik_ratio")))
	expect_true(isTRUE(g$inf$is_nonestimable()))
	k <- host_with_spec(mk(), spec_for(full_nll = NA_real_))
	expect_true(is.na(k$p$compute_likelihood_test_two_sided_pval(0, "lik_ratio")))
	expect_true(isTRUE(k$inf$is_nonestimable("se")))
})
