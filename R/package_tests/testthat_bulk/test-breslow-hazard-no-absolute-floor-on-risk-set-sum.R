# v1.0.6-TODO-16: .breslow_hazard() used to floor each rescaled risk-set sum at an absolute 1e-10,
# so a late risk set whose linear predictors all sit more than ~23 below the global maximum got a
# hazard increment orders of magnitude too small, and Cox simulations inverting it drew wrong times.

breslow_reference = function(y, dead, X, b){
	eta = as.numeric(X %*% b)
	M = max(eta)
	et = sort(unique(y[dead > 0.5]))
	cumsum(vapply(et, function(t){
		e = eta[y >= t]
		m = max(e)
		sum(dead[y == t] > 0.5) * exp(M - m) / sum(exp(e - m))
	}, numeric(1)))
}

test_that("Breslow increments are exact when a late risk set has very low relative risk", {
	y = c(1, 2, 3); dead = c(1, 1, 1)
	X = matrix(c(30, 0, 0), ncol = 1)
	bh = EDI:::.breslow_hazard(y, dead, X, 1)
	expect_equal(bh$times, c(1, 2, 3))
	expect_equal(bh$cumhaz, cumsum(c(1 / (1 + 2 * exp(-30)), exp(30) / 2, exp(30))), tolerance = 1e-12)
	expect_equal(bh$cumhaz, breslow_reference(y, dead, X, 1), tolerance = 1e-12)
})

test_that("Breslow stays finite and correct when the rescaled risk-set sum underflows", {
	# Spread of 700: exp(-700) underflows to a subnormal, so the log-scale branch is used.
	y = c(1, 2, 3, 4); dead = c(1, 1, 0, 1)
	X = matrix(c(700, 0, 1, 0.5), ncol = 1)
	bh = EDI:::.breslow_hazard(y, dead, X, 1)
	expect_true(all(is.finite(bh$cumhaz)))
	expect_equal(bh$cumhaz, breslow_reference(y, dead, X, 1), tolerance = 1e-12)
	# Beyond double range the increment is Inf rather than a floored finite value.
	bh_inf = EDI:::.breslow_hazard(y, dead, matrix(c(800, 0, 1, 0.5), ncol = 1), 1)
	expect_equal(bh_inf$cumhaz[1], 1)
	expect_true(all(is.infinite(bh_inf$cumhaz[-1])))
})

test_that("Breslow hazard on ordinary data matches the plain d_k / R_k recursion exactly", {
	set.seed(51)
	for (r in 1:50){
		n = sample(10:150, 1)
		X = matrix(rnorm(n * 2), n, 2); b = rnorm(2, sd = 0.5)
		y = round(rexp(n), 2); dead = rbinom(n, 1, 0.7)
		if (sum(dead) == 0) next
		eta = as.numeric(X %*% b); risk = exp(eta - max(eta))
		et = sort(unique(y[dead == 1]))
		h = 0; ref = numeric(length(et))
		for (k in seq_along(et)){
			h = h + sum(dead[y == et[k]]) / sum(risk[order(y, -dead)][sort(y) >= et[k]])
			ref[k] = h
		}
		expect_identical(EDI:::.breslow_hazard(y, dead, X, b)$cumhaz, ref)
	}
})

test_that("Cox simulation from the Breslow baseline reaches late event times for low-risk subjects", {
	set.seed(1)
	y = c(1, 2, 3); dead = c(1, 1, 1)
	X = matrix(c(30, 0, 0), ncol = 1)
	bh = EDI:::.breslow_hazard(y, dead, X, 1)
	sims = replicate(200, EDI:::.cox_simulate_from_breslow(bh, y, dead, X, 1)$y_sim[2:3])
	# Under the old 1e-10 floor the cumulative hazard topped out near 2e10, far below the
	# ~1e13 targets of the low-risk subjects, so almost every draw fell to max_time (6).
	expect_lt(mean(sims == 6), 0.5)
})
