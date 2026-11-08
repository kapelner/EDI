# TODO-129 (estimator-internal RNG, coordinator default 2026-10-22):
# robust_survreg_with_surv_object()'s random-restart jitter must not consume
# or advance the caller's global RNG, and must be deterministic for given data.
# survreg failures are forced with a call-counting mock so the jitter path is
# exercised deterministically.

make_forced_failure_survreg = function(n_fail){
	real_survreg = survival::survreg
	state = new.env()
	state$calls = 0L
	state$n_fail = n_fail
	fake = function(...){
		state$calls = state$calls + 1L
		if (state$calls <= state$n_fail) stop("forced survreg failure (test)")
		real_survreg(...)
	}
	list(fake = fake, state = state)
}

robust_survreg_jitter_fixture = function(){
	set.seed(1)
	n = 60L
	list(
		X = matrix(rnorm(n * 2L), n),
		y = rexp(n),
		dead = rbinom(n, 1L, 0.7)
	)
}

test_that("robust_survreg: no-jitter fit leaves the caller's RNG untouched", {
	fx = robust_survreg_jitter_fixture()
	set.seed(99)
	before = .Random.seed
	mod = robust_survreg(fx$y, fx$dead, fx$X, dist = "lognormal")
	expect_false(is.null(mod))
	expect_true(identical(.Random.seed, before))
})

test_that("robust_survreg: jitter restarts are deterministic and do not advance the caller's RNG", {
	fx = robust_survreg_jitter_fixture()
	ref = robust_survreg(fx$y, fx$dead, fx$X, dist = "lognormal")
	mock = make_forced_failure_survreg(3L)
	local_mocked_bindings(survreg = mock$fake, .package = "survival")

	fit_under_caller_seed = function(caller_seed){
		mock$state$calls = 0L
		set.seed(caller_seed)
		before = .Random.seed
		mod = robust_survreg(fx$y, fx$dead, fx$X, dist = "lognormal")
		list(coef = stats::coef(mod), untouched = identical(.Random.seed, before), calls = mock$state$calls)
	}
	a = fit_under_caller_seed(1L)
	b = fit_under_caller_seed(2L)
	expect_identical(a$calls, 4L)
	expect_true(a$untouched)
	expect_true(b$untouched)
	expect_identical(a$coef, b$coef)
	# the jittered restart converges to the same MLE as the unjittered fit
	expect_equal(unname(a$coef), unname(stats::coef(ref)), tolerance = 1e-6)
})

test_that("robust_survreg: failed Weibull warm start falling through to the jitter loop leaves the caller's RNG untouched", {
	fx = robust_survreg_jitter_fixture()
	mock = make_forced_failure_survreg(2L)
	local_mocked_bindings(survreg = mock$fake, .package = "survival")
	set.seed(7)
	before = .Random.seed
	expect_false(is.null(robust_survreg(fx$y, fx$dead, fx$X, dist = "weibull", num_max_iter = 5L)))
	expect_true(identical(.Random.seed, before))
})

test_that("compute_estimate() does not advance the caller's RNG when the survreg jitter fires (GLMM Weibull frailty loggamma OneLik)", {
	set.seed(3)
	n = 40L
	des = DesignSeqOneByOneKK14$new(n = n, response_type = "survival", verbose = FALSE)
	x1 = rnorm(n)
	x2 = rnorm(n)
	for (i in seq_len(n)){
		w_i = des$add_one_subject_to_experiment_and_assign(data.frame(x1 = x1[i], x2 = x2[i]))
		des$add_one_subject_response(i, rexp(1, rate = exp(-0.1 + 0.2 * w_i + 0.15 * x1[i])))
	}
	mock = make_forced_failure_survreg(2L)
	local_mocked_bindings(survreg = mock$fake, .package = "survival")
	# force the survreg cold-start path (fast Weibull fit unavailable)
	local_mocked_bindings(fast_weibull_regression = function(...) stop("forced fast-fit failure (test)"), .package = "EDI")

	estimate_under_caller_seed = function(caller_seed){
		mock$state$calls = 0L
		inf = InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik$new(des, verbose = FALSE)
		set.seed(caller_seed)
		before = .Random.seed
		est = inf$compute_estimate()
		list(est = est, untouched = identical(.Random.seed, before), calls = mock$state$calls)
	}
	a = estimate_under_caller_seed(1L)
	b = estimate_under_caller_seed(2L)
	expect_gt(a$calls, 2L)  # the forced failures were hit, so the jitter fired
	expect_true(a$untouched)
	expect_true(b$untouched)
	expect_true(is.finite(a$est))
	expect_identical(a$est, b$est)
})

# ---------------------------------------------------------------------------
# G6 #50 owner decision 2026-10-23: the jitter is seeded from the calling
# object's seed (inference seed, else design seed) plus a fixed offset when one
# is set (`jitter_seed` argument), and from the fixed constant otherwise. The
# caller's RNG stays untouched either way. A recording mock captures every
# `init` that survreg sees, so the jitter draws themselves are compared (the
# jittered restart converges to the same MLE whatever the draws are).

make_recording_failure_survreg = function(n_fail){
	real_survreg = survival::survreg
	state = new.env()
	state$calls = 0L
	state$n_fail = n_fail
	state$inits = list()
	fake = function(...){
		state$calls = state$calls + 1L
		state$inits[[length(state$inits) + 1L]] = list(...)$init
		if (state$calls <= state$n_fail) stop("forced survreg failure (test)")
		real_survreg(...)
	}
	list(fake = fake, state = state)
}

# The inits the restart loop would use when its jitter stream is set.seed(s).
expected_jitter_inits = function(s, p, n_fail){
	old = if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) .Random.seed else NULL
	on.exit(if (!is.null(old)) assign(".Random.seed", old, envir = .GlobalEnv))
	set.seed(s, kind = "Mersenne-Twister", normal.kind = "Inversion", sample.kind = "Rejection")
	init = rep(0, p)
	out = list(init)
	for (k in seq_len(n_fail)){
		init = init + stats::rnorm(p)
		out[[length(out) + 1L]] = init
	}
	out
}

test_that("robust_survreg_with_surv_object: jitter_seed gives the same jitter (and fit) for the same seed, leaves the caller's RNG alone", {
	fx = robust_survreg_jitter_fixture()
	mock = make_recording_failure_survreg(3L)
	local_mocked_bindings(survreg = mock$fake, .package = "survival")
	surv = survival::Surv(fx$y, fx$dead)
	fit = function(jitter_seed, caller_seed){
		mock$state$calls = 0L
		mock$state$inits = list()
		set.seed(caller_seed)
		before = .Random.seed
		mod = robust_survreg_with_surv_object(surv, fx$X, dist = "lognormal", jitter_seed = jitter_seed)
		list(coef = stats::coef(mod), inits = mock$state$inits, untouched = identical(.Random.seed, before))
	}
	a = fit(5L, 1L)
	b = fit(5L, 2L)
	d = fit(6L, 1L)
	u = fit(NULL, 3L)
	p = ncol(fx$X) + 1L
	expect_length(a$inits, 4L)  # 3 forced failures + the successful restart
	expect_true(a$untouched)
	expect_true(b$untouched)
	expect_true(d$untouched)
	expect_true(u$untouched)
	# same seed -> identical jitter draws and fit, whatever the caller's seed
	expect_identical(a$inits, b$inits)
	expect_identical(a$coef, b$coef)
	# derived seed = jitter_seed + fixed offset
	expect_equal(a$inits, expected_jitter_inits(5L + EDI:::.robust_survreg_jitter_seed_offset, p, 3L), tolerance = 0)
	# a different seed draws a different jitter (the fit is the same MLE)
	expect_false(identical(a$inits[[2L]], d$inits[[2L]]))
	expect_equal(unname(a$coef), unname(d$coef), tolerance = 1e-6)
	# unseeded: the fixed internal constant, as before this change
	expect_equal(u$inits, expected_jitter_inits(EDI:::.robust_survreg_jitter_seed, p, 3L), tolerance = 0)
	# the seed must not be the object's own draw stream
	expect_false(identical(a$inits[[2L]], expected_jitter_inits(5L, p, 1L)[[2L]]))
})

test_that("GLMM Weibull frailty loggamma OneLik: the survreg jitter follows set_seed(), then the design seed, else the fixed constant", {
	make_des = function(design_seed = NULL){
		set.seed(3)
		n = 40L
		des = DesignSeqOneByOneKK14$new(n = n, response_type = "survival", verbose = FALSE, seed = design_seed)
		set.seed(3)
		x1 = rnorm(n)
		x2 = rnorm(n)
		ts = rexp(n)
		for (i in seq_len(n)){
			w_i = des$add_one_subject_to_experiment_and_assign(data.frame(x1 = x1[i], x2 = x2[i]))
			des$add_one_subject_response(i, ts[i] * exp(0.2 * w_i + 0.15 * x1[i]))
		}
		des
	}
	mock = make_recording_failure_survreg(2L)
	local_mocked_bindings(survreg = mock$fake, .package = "survival")
	local_mocked_bindings(fast_weibull_regression = function(...) stop("forced fast-fit failure (test)"), .package = "EDI")
	run = function(des, inf_seed, caller_seed){
		mock$state$calls = 0L
		mock$state$inits = list()
		inf = InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik$new(des, verbose = FALSE)
		if (!is.null(inf_seed)) inf$set_seed(inf_seed)
		set.seed(caller_seed)
		before = .Random.seed
		est = inf$compute_estimate()
		list(est = est, inits = mock$state$inits, untouched = identical(.Random.seed, before))
	}
	des = make_des()
	a = run(des, 5L, 1L)
	b = run(des, 5L, 2L)
	d = run(des, 6L, 1L)
	u = run(des, NULL, 1L)
	expect_gt(length(a$inits), 2L)  # the forced failures were hit, so the jitter fired
	expect_true(a$untouched && b$untouched && d$untouched && u$untouched)
	expect_true(is.finite(a$est))
	expect_identical(a$est, b$est)
	expect_identical(a$inits, b$inits)
	expect_false(identical(a$inits[[2L]], d$inits[[2L]]))
	p = length(a$inits[[1L]])
	expect_equal(a$inits[1:3], expected_jitter_inits(5L + EDI:::.robust_survreg_jitter_seed_offset, p, 2L), tolerance = 0)
	expect_equal(u$inits[1:3], expected_jitter_inits(EDI:::.robust_survreg_jitter_seed, p, 2L), tolerance = 0)
	# TODO-112 fallback: no inference seed -> the design seed
	des_seeded = make_des(design_seed = 11L)
	g = run(des_seeded, NULL, 1L)
	h = run(des_seeded, 11L, 2L)
	expect_true(g$untouched)
	expect_identical(g$inits, h$inits)
	expect_equal(g$inits[1:3], expected_jitter_inits(11L + EDI:::.robust_survreg_jitter_seed_offset, p, 2L), tolerance = 0)
})

test_that("KK21 / KK21stepwise survival weight fits seed the survreg jitter from the design seed", {
	set.seed(20)
	n = 40L
	x1 = rnorm(n)
	w = rep(0:1, n / 2L)
	y = rexp(n, rate = exp(-0.4 * x1))
	dead = rbinom(n, 1L, 0.8)
	X = cbind(x1 = x1)
	mock = make_recording_failure_survreg(2L)
	local_mocked_bindings(survreg = mock$fake, .package = "survival")
	local_mocked_bindings(fast_weibull_regression = function(...) stop("forced fast-fit failure (test)"), .package = "EDI")
	kk21 = function(seed){
		mock$state$calls = 0L
		mock$state$inits = list()
		des = DesignSeqOneByOneKK21$new(n = 6L, response_type = "survival", seed = seed)
		set.seed(99)
		before = .Random.seed
		wt = des$.__enclos_env__$private$compute_weight_KK21_survival(X, y, dead, 1L)
		list(wt = wt, inits = mock$state$inits, untouched = identical(.Random.seed, before))
	}
	kk21sw = function(seed){
		mock$state$calls = 0L
		mock$state$inits = list()
		des = DesignSeqOneByOneKK21stepwise$new(n = 6L, response_type = "survival", seed = seed)
		set.seed(99)
		before = .Random.seed
		wt = des$.__enclos_env__$private$compute_weights_KK21stepwise_survival(X, y, w, dead)
		list(wt = wt, inits = mock$state$inits, untouched = identical(.Random.seed, before))
	}
	for (f in list(kk21, kk21sw)){
		a = f(5L)
		b = f(5L)
		u = f(NULL)
		expect_true(a$untouched && b$untouched && u$untouched)
		expect_true(all(is.finite(a$wt)))
		expect_identical(a$inits, b$inits)
		p = length(a$inits[[1L]])
		expect_equal(a$inits[1:3], expected_jitter_inits(5L + EDI:::.robust_survreg_jitter_seed_offset, p, 2L), tolerance = 0)
		expect_equal(u$inits[1:3], expected_jitter_inits(EDI:::.robust_survreg_jitter_seed, p, 2L), tolerance = 0)
	}
})
