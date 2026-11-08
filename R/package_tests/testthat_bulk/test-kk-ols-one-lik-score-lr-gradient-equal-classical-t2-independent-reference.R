library(testthat)
library(EDI)

# TODO-115 (2026-10-22): independent-reference check that InferenceContinKKOLSOneLik's score,
# likelihood-ratio and gradient tests agree, and with what.
#
# Derivation. The class's likelihood (get_likelihood_test_spec(), inference_continuous_KK_ols_one_lik.R)
# is the Gaussian log-likelihood of ONE OLS fit y_s = X_s beta + e on the stacked KK design (pair-difference
# rows (0, 1, x_T - x_C) / response y_T - y_C, over reservoir rows (1, w, x) / y; all-matched: (1, x_T - x_C)),
# with sigma^2 held FIXED at the full-model unbiased estimate s^2 = RSS_full / (n - p). With sigma^2 fixed the
# log-likelihood l(beta) = -RSS(beta) / (2 s^2) is exactly quadratic, and RSS(beta) = RSS_full +
# (beta - beta_hat)' X'X (beta - beta_hat). Let beta_0 be the restricted MLE (beta_T = delta, nuisance
# profiled) and I = X'X / s^2. Then the score U(beta_0) = I (beta_hat - beta_0) and, because U is zero in the
# nuisance coordinates at beta_0:
#   LR       = 2 (l(beta_hat) - l(beta_0))        = (RSS_null(delta) - RSS_full) / s^2
#   score    = U(beta_0)' I^{-1} U(beta_0)         = (beta_hat - beta_0)' I (beta_hat - beta_0)
#   gradient = U(beta_0)' (beta_hat - beta_0)      = U_T(beta_0) (beta_hat_T - delta)
# are all the SAME number, equal to t^2 = ((beta_hat_T - delta) / se_classical)^2 where se_classical =
# s * sqrt([(X'X)^{-1}]_TT) is the classical homoskedastic lm() standard error. This is an identity (not an
# asymptotic agreement), so the three p-values are identical: p = pchisq(t^2, 1, lower = FALSE) =
# 2 pnorm(-|t|) (chi-square(1), NOT lm()'s t(n - p) p-value; the t/F version is the separate exact-Bartlett
# LR path). All three CIs invert the same statistic, so each equals the closed form
# beta_hat_T +/- qnorm(1 - alpha/2) se_classical. The Wald path differs legitimately: it uses the HC2
# sandwich SE with t(n - p) (documented on compute_asymp_two_sided_pval()).
#
# Reference: everything below is computed by hand from the raw data and the design's pair ids (stacked design
# built here, lm.fit for full and restricted fits, explicit score/information algebra), never through EDI's
# likelihood-test code. Tolerances: p-values 1e-10 (closed-form on both sides; observed gaps ~1e-16); CIs
# 1e-4 * se_classical (EDI inverts numerically -- uniroot / Newton -- observed gaps <= 3e-6 * se).

ref_stack = function(m, y, X, w) {
	m[is.na(m)] = 0
	ids = sort(unique(m[m > 0]))
	pair_row = function(k) { i = which(m == k); t1 = i[w[i] == 1]; t0 = i[w[i] == 0]; c(y[t1] - y[t0], X[t1, ] - X[t0, ]) }
	dd = matrix(unlist(lapply(ids, pair_row)), nrow = length(ids), byrow = TRUE)
	r = which(m == 0)
	if (length(r) > 0L) {
		list(Xs = rbind(cbind(0, 1, dd[, -1L, drop = FALSE]), cbind(1, w[r], X[r, , drop = FALSE])), ys = c(dd[, 1L], y[r]), j = 2L)
	} else {
		list(Xs = cbind(1, dd[, -1L, drop = FALSE]), ys = dd[, 1L], j = 1L)
	}
}

ref_lik_stats = function(Xs, ys, j, delta) {
	full = lm.fit(Xs, ys)
	n = nrow(Xs); p = ncol(Xs)
	b = unname(full$coefficients)
	rss1 = sum(full$residuals^2)
	s2 = rss1 / (n - p)
	b0 = rep(delta, p)
	if (p > 1L) b0[-j] = unname(lm.fit(Xs[, -j, drop = FALSE], ys - delta * Xs[, j])$coefficients)
	rss0 = sum((ys - Xs %*% b0)^2)
	U = unname(drop(crossprod(Xs, ys - Xs %*% b0))) / s2
	I = crossprod(Xs) / s2
	se = sqrt(s2 * solve(crossprod(Xs))[j, j])
	list(LR = (rss0 - rss1) / s2, score = drop(crossprod(U, solve(I, U))), gradient = U[j] * (b[j] - delta),
		t2 = ((b[j] - delta) / se)^2, beta = b[j], se = se)
}

kk14_fixture = function(seed, n = 60L) {
	set.seed(seed)
	des = DesignSeqOneByOneKK14$new(response_type = "continuous", n = n, verbose = FALSE)
	X = data.frame(x1 = rnorm(n), x2 = runif(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w = des$get_w()
	y = 1 + 0.6 * w + 0.5 * X$x1 - X$x2 + rnorm(n)
	des$add_all_subject_responses(y)
	c(list(des = des), ref_stack(des$.__enclos_env__$private$m[seq_len(n)], y, as.matrix(X), w))
}

fixed_match_fixture = function(seed, n = 50L) {
	set.seed(seed)
	des = DesignFixedBinaryMatch$new(response_type = "continuous", n = n, verbose = FALSE)
	X = data.frame(x1 = rnorm(n), x2 = runif(n))
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w = des$get_w()
	y = 1 + 0.6 * w + 0.5 * X$x1 - X$x2 + rnorm(n)
	des$add_all_subject_responses(y)
	c(list(des = des), ref_stack(des$.__enclos_env__$private$m[seq_len(n)], y, as.matrix(X), w))
}

# All-matched with ~1: beta_T is the only parameter (the TODO-122 path where the 6-digit
# score == LR == gradient agreement was first observed).
fixed_match_intercept_only_fixture = function(seed, n = 40L) {
	set.seed(seed)
	m = rep(seq_len(n / 2L), each = 2L)
	des = DesignFixedBinaryMatch$new(response_type = "continuous", n = n, m = m, design_formula = ~ 1, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	w = as.vector(replicate(n / 2L, sample(0:1)))
	des$assign_w_to_all_subjects(w)
	y = 0.5 * w + rep(rnorm(n / 2L), each = 2L) + rnorm(n)
	des$add_all_subject_responses(y)
	c(list(des = des), ref_stack(m, y, matrix(nrow = n, ncol = 0L), w))
}

lik_types = c("score", "lik_ratio", "gradient")

check_fixture = function(f, label, expect_reservoir) {
	expect_identical(f$j, if (expect_reservoir) 2L else 1L, info = label)
	inf = InferenceContinKKOLSOneLik$new(f$des, verbose = FALSE)
	ref0 = ref_lik_stats(f$Xs, f$ys, f$j, 0)
	# the hand-built stacked design is the one EDI fits
	expect_equal(unname(inf$compute_estimate()), ref0$beta, tolerance = 1e-10, info = label)
	for (delta in c(0, 0.4, -0.25)) {
		r = ref_lik_stats(f$Xs, f$ys, f$j, delta)
		# the theory: LR == score == gradient == classical t^2, identically
		expect_equal(r$score, r$LR, tolerance = 1e-10, info = paste(label, delta))
		expect_equal(r$gradient, r$LR, tolerance = 1e-10, info = paste(label, delta))
		expect_equal(r$t2, r$LR, tolerance = 1e-10, info = paste(label, delta))
		p_ref = stats::pchisq(r$t2, df = 1, lower.tail = FALSE)
		for (tt in lik_types) {
			inf$set_testing_type(tt)
			expect_equal(inf$compute_asymp_two_sided_pval(delta = delta), p_ref, tolerance = 1e-10,
				info = paste(label, tt, delta))
		}
	}
	ci_ref = ref0$beta + c(-1, 1) * stats::qnorm(0.975) * ref0$se
	for (tt in lik_types) {
		inf$set_testing_type(tt)
		ci = unname(inf$compute_asymp_confidence_interval(alpha = 0.05))
		expect_lt(max(abs(ci - ci_ref)), 1e-4 * ref0$se, label = paste(label, tt, "CI gap / se-scaled tol"))
	}
}

test_that("KK14 (pairs + reservoir): score, LR and gradient p-values and CIs equal the classical-t^2 chi-square(1) reference", {
	for (seed in 1:3) {
		f = kk14_fixture(seed)
		expect_gt(sum(f$Xs[, 1L] == 1), 2L)                                     # reservoir rows present
		check_fixture(f, paste0("KK14 seed ", seed), expect_reservoir = TRUE)
	}
})

test_that("fixed binary match design (all matched, covariates): score, LR and gradient equal the reference", {
	skip_if_not_installed("nbpMatching")
	for (seed in 3:5) check_fixture(fixed_match_fixture(seed), paste0("fixed match seed ", seed), expect_reservoir = FALSE)
})

test_that("fixed binary match, ~1 (beta_T is the only parameter): score, LR and gradient equal the reference", {
	for (seed in 1:2) check_fixture(fixed_match_intercept_only_fixture(seed), paste0("fixed match ~1 seed ", seed), expect_reservoir = FALSE)
})
