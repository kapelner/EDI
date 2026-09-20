library(testthat)
library(EDI)
suppressPackageStartupMessages(library(survival))

# The internal Cox partial-likelihood kernels in inference_survival_coxph.R:
# .fit_survival_coxph_kernel() (coxph.fit adapter), .fit_survival_coxph_fixed_kernel()
# (null refits with one coefficient pinned via an offset), the R Breslow
# log-likelihood / finite-difference score / information helpers, and
# cox_partial_likelihood_coefficients_extreme(). References are survival::coxph
# fits (ties = "breslow") and closed-form Breslow score/information sums.

cox_data <- function(n = 80L, seed = 12L, strata = FALSE) {
	set.seed(seed)
	x1 <- rnorm(n); x2 <- rnorm(n)
	t <- round(rexp(n, exp(0.4 * x1 - 0.3 * x2)) * 10) / 10 + 0.1
	dead <- rbinom(n, 1, 0.75)
	list(X = cbind(x1 = x1, x2 = x2), y = t, dead = dead, strata = if (strata) rep(1:3, length.out = n) else NULL)
}

ref_loglik <- function(d, beta) {
	f <- if (is.null(d$strata)) coxph(Surv(d$y, d$dead) ~ d$X, ties = "breslow", init = beta, control = coxph.control(iter.max = 0))
		else coxph(Surv(d$y, d$dead) ~ d$X + strata(d$strata), ties = "breslow", init = beta, control = coxph.control(iter.max = 0))
	f$loglik[2]
}

ref_breslow_score_info <- function(d, beta) {
	X <- d$X; p <- ncol(X)
	strata <- if (is.null(d$strata)) rep(1L, nrow(X)) else d$strata
	eta <- as.numeric(X %*% beta)
	score <- numeric(p); info <- matrix(0, p, p)
	for (s in unique(strata)) {
		idx <- which(strata == s)
		for (tt in sort(unique(d$y[idx][d$dead[idx] == 1]))) {
			ev <- idx[d$dead[idx] == 1 & d$y[idx] == tt]
			risk <- idx[d$y[idx] >= tt]
			w <- exp(eta[risk]); S0 <- sum(w)
			S1 <- colSums(X[risk, , drop = FALSE] * w); S2 <- crossprod(X[risk, , drop = FALSE] * sqrt(w))
			m <- S1 / S0
			score <- score + colSums(X[ev, , drop = FALSE]) - length(ev) * m
			info <- info + length(ev) * (S2 / S0 - tcrossprod(m))
		}
	}
	list(score = score, info = info)
}

test_that("coxph kernel matches survival::coxph for plain, stratified and offset fits", {
	d <- cox_data()
	ref <- coxph(Surv(d$y, d$dead) ~ d$X, ties = "breslow")
	k <- EDI:::.fit_survival_coxph_kernel(d$X, d$y, d$dead)
	expect_equal(unname(k$b), unname(coef(ref)), tolerance = 1e-6)
	expect_equal(names(k$b), colnames(d$X))
	expect_equal(unname(k$vcov), unname(vcov(ref)), tolerance = 1e-6)
	expect_equal(k$neg_ll, -ref$loglik[2], tolerance = 1e-8)
	expect_equal(unname(k$fisher_information), unname(solve(vcov(ref))), tolerance = 1e-5)
	expect_true(k$converged)

	ds <- cox_data(strata = TRUE)
	ref_s <- coxph(Surv(ds$y, ds$dead) ~ ds$X + strata(ds$strata), ties = "breslow")
	ks <- EDI:::.fit_survival_coxph_kernel(ds$X, ds$y, ds$dead, strata = ds$strata)
	expect_equal(unname(ks$b), unname(coef(ref_s)), tolerance = 1e-6)
	expect_equal(ks$neg_ll, -ref_s$loglik[2], tolerance = 1e-8)

	off <- 0.3 * d$X[, 1]
	ref_o <- coxph(Surv(d$y, d$dead) ~ d$X[, 2] + offset(off), ties = "breslow")
	ko <- EDI:::.fit_survival_coxph_kernel(d$X[, 2, drop = FALSE], d$y, d$dead, offset = off)
	expect_equal(unname(ko$b), unname(coef(ref_o)), tolerance = 1e-6)
	expect_equal(ko$neg_ll, -ref_o$loglik[2], tolerance = 1e-8)
})

test_that("estimate_only skips variance work, a zero-column null model works with an offset, and bad fits return NULL", {
	d <- cox_data()
	ke <- EDI:::.fit_survival_coxph_kernel(d$X, d$y, d$dead, estimate_only = TRUE)
	expect_null(ke$vcov)
	expect_null(ke$fisher_information)
	expect_true(is.na(ke$neg_ll))
	expect_equal(unname(ke$b), unname(coef(coxph(Surv(d$y, d$dead) ~ d$X, ties = "breslow"))), tolerance = 1e-6)

	off <- 0.2 * d$X[, 1]
	k0 <- EDI:::.fit_survival_coxph_kernel(matrix(0, nrow(d$X), 0), d$y, d$dead, offset = off)
	expect_length(k0$b, 0L)
	expect_equal(dim(k0$vcov), c(0L, 0L))
	ref0 <- coxph(Surv(d$y, d$dead) ~ offset(off), ties = "breslow")
	expect_equal(k0$neg_ll, -utils::tail(ref0$loglik, 1L), tolerance = 1e-8)

	# Malformed input (mismatched lengths) makes coxph.fit error -> NULL.
	expect_null(EDI:::.fit_survival_coxph_kernel(d$X, d$y[-1], d$dead))
})

test_that("fixed kernel pins one coefficient and matches an offset-only coxph refit", {
	d <- cox_data()
	fk <- EDI:::.fit_survival_coxph_fixed_kernel(d$X, d$y, d$dead, fixed_idx = 1L, fixed_value = 0.25)
	expect_equal(unname(fk$b[1]), 0.25)
	off <- 0.25 * d$X[, 1]
	ref <- coxph(Surv(d$y, d$dead) ~ d$X[, 2] + offset(off), ties = "breslow")
	expect_equal(unname(fk$b[2]), unname(coef(ref)), tolerance = 1e-6)
	expect_equal(fk$neg_ll, -ref$loglik[2], tolerance = 1e-8)
	expect_null(fk$vcov)
	# Information is embedded in the free block; the pinned row/column are zero.
	expect_equal(dim(fk$fisher_information), c(2L, 2L))
	expect_true(all(fk$fisher_information[1, ] == 0) && all(fk$fisher_information[, 1] == 0))
	expect_equal(unname(fk$fisher_information[2, 2]), 1 / as.numeric(vcov(ref)), tolerance = 1e-5)

	fk2 <- EDI:::.fit_survival_coxph_fixed_kernel(d$X, d$y, d$dead, fixed_idx = 2L, fixed_value = -0.1)
	expect_equal(unname(fk2$b[2]), -0.1)
	expect_equal(names(fk2$b), colnames(d$X))

	# Single covariate fixed: nothing left to estimate, offset-only null model.
	fk1 <- EDI:::.fit_survival_coxph_fixed_kernel(d$X[, 1, drop = FALSE], d$y, d$dead, fixed_idx = 1L, fixed_value = 0)
	expect_equal(unname(fk1$b), 0)
	expect_null(fk1$fisher_information)
	expect_equal(fk1$neg_ll, -utils::tail(coxph(Surv(d$y, d$dead) ~ offset(rep(0, nrow(d$X))), ties = "breslow")$loglik, 1L), tolerance = 1e-8)

	expect_null(EDI:::.fit_survival_coxph_fixed_kernel(d$X, d$y, d$dead, fixed_idx = 0L))
	expect_null(EDI:::.fit_survival_coxph_fixed_kernel(d$X, d$y, d$dead, fixed_idx = 3L))
	expect_null(EDI:::.fit_survival_coxph_fixed_kernel(matrix(0, nrow(d$X), 0), d$y, d$dead))
})

test_that("R Breslow negative log-likelihood matches coxph at arbitrary coefficients, with strata, and rejects bad inputs", {
	d <- cox_data()
	for (beta in list(c(0, 0), c(0.4, -0.3), c(-0.7, 0.5))) {
		expect_equal(EDI:::.cox_neg_loglik_breslow_r(d$X, d$y, d$dead, beta), -ref_loglik(d, beta), tolerance = 1e-8)
	}
	ds <- cox_data(strata = TRUE)
	expect_equal(EDI:::.cox_neg_loglik_breslow_r(ds$X, ds$y, ds$dead, c(0.2, 0.1), strata = ds$strata),
		-ref_loglik(ds, c(0.2, 0.1)), tolerance = 1e-8)
	expect_true(is.na(EDI:::.cox_neg_loglik_breslow_r(d$X, d$y, d$dead, c(0.1))))
	expect_true(is.na(EDI:::.cox_neg_loglik_breslow_r(d$X, d$y, d$dead, c(Inf, 0))))
	expect_true(is.na(EDI:::.cox_neg_loglik_breslow_r(d$X, d$y, d$dead, c(1000, 1000))))
})

test_that("finite-difference score and information match closed-form Breslow sums", {
	for (strata in c(FALSE, TRUE)) {
		d <- cox_data(strata = strata)
		beta <- c(0.3, -0.2)
		ref <- ref_breslow_score_info(d, beta)
		expect_equal(unname(EDI:::.cox_score_breslow_fd_r(d$X, d$y, d$dead, beta, strata = d$strata)), unname(ref$score), tolerance = 1e-4, info = as.character(strata))
		info_nll <- EDI:::.cox_information_breslow_fd_r(d$X, d$y, d$dead, beta, strata = d$strata)
		expect_equal(unname(info_nll), unname(ref$info), tolerance = 1e-3, info = as.character(strata))
		expect_true(isSymmetric(unname(info_nll)))
	}
	d <- cox_data()
	bad <- c(1000, 1000)
	expect_true(all(is.na(EDI:::.cox_score_breslow_fd_r(d$X, d$y, d$dead, bad))))
	expect_true(all(is.na(EDI:::.cox_information_breslow_fd_r(d$X, d$y, d$dead, bad))))
})

test_that("extreme-coefficient predicate flags non-finite values and anything beyond the threshold", {
	f <- EDI:::cox_partial_likelihood_coefficients_extreme
	expect_false(f(c(1, -2, 20)))
	expect_true(f(c(1, 20.01)))
	expect_true(f(c(1, -25)))
	expect_true(f(c(1, NA)))
	expect_true(f(c(Inf, 1)))
	expect_false(f(c(5, 6), threshold = 6))
	expect_true(f(c(5, 6.5), threshold = 6))
	expect_false(f(numeric(0)))
})
