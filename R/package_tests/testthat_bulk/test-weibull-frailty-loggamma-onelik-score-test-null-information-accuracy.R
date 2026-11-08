library(testthat)
library(EDI)

# InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik (Clayton / loggamma-frailty Weibull AFT)
# score test. Its size on correctly specified matched-pair data is about 0.063 at n = 200
# (Wald 0.049, LR 0.045). The investigation (release_v1_0_5.md, TODO-189) ruled out the
# numerical suspects: the forward-difference observed information at the null fit matches a
# central-difference Jacobian of the analytic score, the analytic score matches a numerical
# gradient of the likelihood, and the null refit is converged in the nuisance parameters. The
# excess size is a finite-sample property of the score statistic itself: when the data show
# an effect, forcing beta_T = 0 lowers the null fit's log-theta, which lowers the efficient
# information for beta_T. This file pins the numerical facts, so a later change that breaks
# them (e.g. a coarser Hessian step or a looser null fit) shows up here.

clayton_score_fixture <- function(seed = 4L, n = 200L) {
	set.seed(seed)
	X <- data.frame(x1 = stats::rnorm(n), x2 = stats::rbinom(n, 1L, 0.5))
	des <- DesignFixedBinaryMatch$new(n = n, response_type = "survival")
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	m <- des$.__enclos_env__$private$m
	# Correctly specified: pairs share a Clayton(theta = 1) dependence, Weibull(1.5) margins.
	Z <- stats::rgamma(max(m), shape = 1, rate = 1)[m]
	U <- (1 + stats::rexp(n) / Z)^(-1)
	t <- (-log(U))^(1 / 1.5)
	cens <- stats::rexp(n, 0.3)
	ev <- t <= cens
	obs <- pmin(t, cens)
	des$add_all_subject_responses(ys = ifelse(ev, obs, NA), y_Ls = ifelse(ev, NA, obs), y_Rs = ifelse(ev, NA, Inf))
	inf <- InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik$new(des_obj = des, model_formula = ~1)
	inf$num_cores <- 1L
	inf
}

clayton_negloglik_r <- function(spec, par) {
	ns <- asNamespace("EDI")
	X <- spec$X
	nb <- ncol(X)
	sigma <- exp(par[nb + 1L])
	theta <- exp(par[nb + 2L])
	mt <- ns$.weibull_aft_margin_terms(spec$y, as.vector(X %*% par[seq_len(nb)]), sigma)
	H <- mt$H
	lf <- mt$log_f
	i1 <- spec$pair_idx[, 1L] + 1L
	i2 <- spec$pair_idx[, 2L] + 1L
	d1 <- spec$dead[i1]
	d2 <- spec$dead[i2]
	lA <- ns$.clayton_copula_logA(H[i1], H[i2], theta)
	ll <- ifelse(d1 == 0 & d2 == 0, -lA / theta,
		ifelse(d1 == 1 & d2 == 0, lf[i1] + (-1 / theta - 1) * lA + (theta + 1) * H[i1],
		ifelse(d1 == 0 & d2 == 1, lf[i2] + (-1 / theta - 1) * lA + (theta + 1) * H[i2],
			log(theta + 1) + lf[i1] + lf[i2] + (-1 / theta - 2) * lA + (theta + 1) * (H[i1] + H[i2]))))
	sg <- 0
	if (length(spec$singleton_rows) > 0L) {
		k <- spec$singleton_rows + 1L
		sg <- sum(spec$dead[k] * lf[k] - (1 - spec$dead[k]) * H[k])
	}
	-(sum(ll) + sg)
}

test_that("score-test ingredients at the null fit are numerically accurate (TODO-189 suspects ruled out)", {
	skip_if_not_installed("numDeriv")
	inf <- clayton_score_fixture()
	p_class <- inf$compute_score_two_sided_pval(delta = 0)
	expect_true(is.finite(p_class))

	spec <- inf$.__enclos_env__$private$get_likelihood_test_spec()
	pair_idx <- spec$pair_idx
	storage.mode(pair_idx) <- "integer"
	sr <- as.integer(spec$singleton_rows)
	j <- spec$j
	null_fit <- spec$fit_null(0)
	par0 <- as.numeric(null_fit$params)
	expect_equal(par0[j], 0)
	U0 <- as.numeric(spec$score(null_fit))
	I_fd <- as.matrix(spec$observed_information(null_fit))
	score_at <- function(p) EDI:::get_clayton_weibull_aft_score_cpp(spec$X, spec$y, spec$dead, pair_idx, sr, p)

	# (1) analytic score == numerical gradient of an independent R likelihood
	expect_equal(U0, -numDeriv::grad(function(p) clayton_negloglik_r(spec, p), par0), tolerance = 1e-6)

	# (2) the null refit is converged in the nuisance parameters (efficient score == raw score)
	expect_lt(max(abs(U0[-j])), 0.05)

	# (3) the forward-difference observed information matches a central-difference Jacobian
	I_cd <- -numDeriv::jacobian(score_at, par0)
	I_cd <- (I_cd + t(I_cd)) / 2
	expect_equal(I_fd, I_cd, tolerance = 1e-4)

	# (4) the class's p-value is the textbook U_T^2 / (I_TT - I_Tn I_nn^-1 I_nT) with either matrix
	stat <- function(I) {
		nu <- setdiff(seq_along(U0), j)
		U0[j]^2 / c(I[j, j] - I[j, nu] %*% solve(I[nu, nu], I[nu, j]))
	}
	expect_equal(p_class, stats::pchisq(stat(I_fd), 1, lower.tail = FALSE), tolerance = 1e-6)
	expect_equal(p_class, stats::pchisq(stat(I_cd), 1, lower.tail = FALSE), tolerance = 1e-4)
})
