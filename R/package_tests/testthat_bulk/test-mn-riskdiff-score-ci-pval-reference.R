library(testthat)
library(EDI)

# InferenceIncidMiettinenNurminenRiskDiff's compute_asymp_confidence_interval()/
# compute_asymp_two_sided_pval() invert a restricted-MLE score test (mn_ci_cpp/
# mn_pvalue_cpp) -- the actual named Miettinen-Nurminen method -- but the only
# prior coverage (test-incidence-exact-and-score-interval-contracts.R) is a
# basic sanity check (brackets the point estimate, finite p-value), never an
# independent verification of the restricted-MLE score formula itself. The
# weighted-bootstrap path (test-mn-riskdiff-weighted-bootstrap-reference.R)
# explicitly documents that it skips this score-test machinery entirely, so
# it provides no coverage of this method either.
#
# This file independently re-derives the restricted-MLE score test via a
# from-scratch one-dimensional log-likelihood maximization (stats::optimize),
# a different numerical route from the package's own closed-form cubic-root
# C++ solver, and cross-checks both the p-value and the CI bounds (via
# stats::uniroot bisection on the reference p-value function) against it.

make_mn_design <- function(y, w) {
	n <- length(y)
	des <- DesignSeqOneByOneBernoulli$new(n = n, response_type = "incidence")
	for (i in seq_len(n)) {
		des$add_one_subject_to_experiment_and_assign(data.frame(x1 = i / 10))
	}
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(y)
	des
}

mn_restricted_mle_pc <- function(delta, x_t, n_t, x_c, n_c) {
	lower <- max(1e-10, -delta + 1e-10)
	upper <- min(1 - 1e-10, 1 - delta - 1e-10)
	if (lower >= upper) return(NA_real_)
	ll <- function(pc) {
		x_t * log(pmax(pc + delta, 1e-14)) + (n_t - x_t) * log(pmax(1 - pc - delta, 1e-14)) +
			x_c * log(pmax(pc, 1e-14)) + (n_c - x_c) * log(pmax(1 - pc, 1e-14))
	}
	stats::optimize(ll, lower = lower, upper = upper, maximum = TRUE, tol = 1e-10)$maximum
}

mn_score_pval_reference <- function(delta, x_t, n_t, x_c, n_c) {
	pc_tilde <- mn_restricted_mle_pc(delta, x_t, n_t, x_c, n_c)
	if (is.na(pc_tilde)) return(NA_real_)
	pt_tilde <- pc_tilde + delta
	correction <- (n_t + n_c) / max(n_t + n_c - 1, 1)
	se <- sqrt(correction * (pt_tilde * (1 - pt_tilde) / n_t + pc_tilde * (1 - pc_tilde) / n_c))
	if (!is.finite(se) || se <= 0) return(NA_real_)
	z <- (x_t / n_t - x_c / n_c - delta) / se
	2 * stats::pnorm(-abs(z))
}

mn_score_ci_reference <- function(x_t, n_t, x_c, n_c, alpha) {
	est <- x_t / n_t - x_c / n_c
	pf <- function(d) mn_score_pval_reference(d, x_t, n_t, x_c, n_c) - alpha
	lo <- stats::uniroot(pf, lower = -0.999999, upper = est - 1e-8, tol = 1e-9)$root
	hi <- stats::uniroot(pf, lower = est + 1e-8, upper = 0.999999, tol = 1e-9)$root
	c(lo, hi)
}

test_that("Miettinen-Nurminen score p-value matches an independently-derived restricted-MLE score test", {
	set.seed(20260918)
	for (seed in 1:4) {
		set.seed(seed)
		n <- 30L
		w <- rep(c(0, 1), length.out = n)
		y <- rbinom(n, 1, 0.5)
		des <- make_mn_design(y, w)
		inf <- InferenceIncidMiettinenNurminenRiskDiff$new(des)
		counts <- inf$.__enclos_env__$private$cached_values$mn_counts
		if (is.null(counts)) {
			inf$compute_estimate()
			counts <- inf$.__enclos_env__$private$cached_values$mn_counts
		}
		for (delta in c(0, -0.2, 0.15)) {
			pval_pkg <- inf$compute_asymp_two_sided_pval(delta)
			pval_ref <- mn_score_pval_reference(delta, counts$x_t, counts$n_t, counts$x_c, counts$n_c)
			expect_equal(pval_pkg, pval_ref, tolerance = 1e-6)
		}
	}
})

test_that("Miettinen-Nurminen score CI bounds match an independent uniroot-bisected reference", {
	set.seed(9)
	n <- 40L
	w <- rep(c(0, 1), length.out = n)
	y <- rbinom(n, 1, 0.5)
	des <- make_mn_design(y, w)
	inf <- InferenceIncidMiettinenNurminenRiskDiff$new(des)
	counts <- inf$.__enclos_env__$private$cached_values$mn_counts
	if (is.null(counts)) {
		inf$compute_estimate()
		counts <- inf$.__enclos_env__$private$cached_values$mn_counts
	}
	for (alpha in c(0.05, 0.1)) {
		ci_pkg <- inf$compute_asymp_confidence_interval(alpha = alpha)
		ci_ref <- mn_score_ci_reference(counts$x_t, counts$n_t, counts$x_c, counts$n_c, alpha)
		expect_equal(unname(ci_pkg), ci_ref, tolerance = 1e-5)
	}
})

test_that("Miettinen-Nurminen score CI/p-value are unavailable when an arm is empty", {
	n <- 10L
	w <- rep(1, n)
	y <- rbinom(n, 1, 0.5)
	des <- make_mn_design(y, w)
	inf <- InferenceIncidMiettinenNurminenRiskDiff$new(des)
	expect_true(all(is.na(inf$compute_asymp_confidence_interval())))
	expect_true(is.na(inf$compute_asymp_two_sided_pval()))
})
