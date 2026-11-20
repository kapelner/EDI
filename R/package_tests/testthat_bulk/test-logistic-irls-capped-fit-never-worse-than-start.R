# v1.0.6-TODO-272: the safeguarded (step-halving) logistic IRLS pass checked each step at the top
# of the next iteration, so the step taken at iter = maxit - 1 was never checked. A fit that hit
# the iteration cap from a far warm start could return a negative log-likelihood far above its
# start (seed-1 fixture below: start 408.4, maxit = 1 returned 36767.6, maxit = 2 returned
# 66070.6). The last step is now checked with the same halving rule, so the returned fit is never
# worse than its start, and its mu / score agree with the returned coefficients.
#
# Needs a build of EDI that contains the patched kernel (R/EDI/src/fast_logistic_regression.cpp).

logistic_capped_fixture = function(){
	set.seed(1)
	n = 30
	X = cbind(1, rnorm(n))
	y = rbinom(n, 1, plogis(drop(X %*% c(0, 1))))
	list(X = X, y = as.numeric(y), n = n, start = c(0.3, -25))
}

logistic_neg_ll_at = function(X, y, b){
	eta = drop(X %*% b)
	sum(pmax(eta, 0) + log1p(exp(-abs(eta))) - y * eta)
}

test_that("a capped logistic IRLS fit never returns a worse log-likelihood than its warm start", {
	d = logistic_capped_fixture()
	nll_start = logistic_neg_ll_at(d$X, d$y, d$start)
	prev = Inf
	for (m in 1:8) {
		fit = EDI:::fast_logistic_regression_weighted_cpp(X = d$X, y = d$y, weights = rep(1, d$n),
			warm_start_beta = d$start, maxit = m)
		expect_lte(fit$neg_ll, nll_start)
		# Each extra iteration of the (deterministic) safeguarded pass can only lower the objective.
		expect_lte(fit$neg_ll, prev + 1e-8)
		prev = fit$neg_ll
		# The reported state belongs to the returned coefficients.
		expect_equal(fit$neg_ll, logistic_neg_ll_at(d$X, d$y, fit$b), tolerance = 1e-10)
		mu_b = plogis(drop(d$X %*% fit$b))
		expect_equal(as.numeric(fit$mu), mu_b, tolerance = 1e-10)
		expect_equal(as.numeric(fit$score), drop(crossprod(d$X, d$y - mu_b)), tolerance = 1e-8)

		u = EDI:::fast_logistic_regression_cpp(X = d$X, y = d$y, warm_start_beta = d$start, maxit = m)
		expect_lte(u$neg_ll, nll_start)
		expect_equal(as.numeric(u$b), as.numeric(fit$b))
	}
})

test_that("random far warm starts at small maxit never end above their start", {
	for (s in 1:40) {
		set.seed(s)
		n = 30
		X = cbind(1, rnorm(n))
		y = as.numeric(rbinom(n, 1, plogis(drop(X %*% c(0, 1)))))
		ws = c(runif(1, -1, 1), sample(c(-1, 1), 1) * runif(1, 5, 40))
		nll_start = logistic_neg_ll_at(X, y, ws)
		for (m in c(1L, 2L, 3L, 5L)) {
			fit = EDI:::fast_logistic_regression_weighted_cpp(X = X, y = y, weights = rep(1, n),
				warm_start_beta = ws, maxit = m)
			expect_lte(fit$neg_ll, nll_start + 1e-8)
		}
	}
})

test_that("the default-maxit fit from the far warm start still matches glm", {
	d = logistic_capped_fixture()
	fit = EDI:::fast_logistic_regression_weighted_cpp(X = d$X, y = d$y, weights = rep(1, d$n),
		warm_start_beta = d$start)
	g = glm.fit(d$X, d$y, family = binomial(), control = glm.control(epsilon = 1e-12))
	expect_true(isTRUE(fit$converged))
	expect_equal(as.numeric(fit$b), unname(g$coefficients), tolerance = 1e-7)
})
