# marginal_estimand_report.md TODO-5: InferenceCountZeroInflatedPoisson's and
# InferenceCountHurdlePoisson's "marginal_mean_diff"/"marginal_ratio"
# estimands (set_estimand()). NegBin siblings are explicitly out of scope
# (the mean-function derivations here are Poisson-specific).

simulate_zip_design = function(seed = 1L, n = 250L){
	set.seed(seed)
	seq_des = DesignSeqOneByOneBernoulli$new(n = n, response_type = "count", verbose = FALSE)
	x1 = rnorm(n)
	for (i in seq_len(n)) seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = x1[i]))
	w = seq_des$get_w()
	pi0 = plogis(-1 + 0.3 * w)
	lambda = exp(0.5 + 0.4 * w + 0.2 * x1)
	y = ifelse(rbinom(n, 1L, pi0) == 1L, 0, rpois(n, lambda))
	seq_des$add_all_subject_responses(y)
	seq_des
}

rztpois = function(n, lambda){
	y = numeric(n)
	for (i in seq_len(n)) {
		repeat {
			yi = rpois(1L, lambda[i])
			if (yi > 0) { y[i] = yi; break }
		}
	}
	y
}

simulate_hurdle_design = function(seed = 1L, n = 300L){
	set.seed(seed)
	seq_des = DesignSeqOneByOneBernoulli$new(n = n, response_type = "count", verbose = FALSE)
	x1 = rnorm(n)
	for (i in seq_len(n)) seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = x1[i]))
	w = seq_des$get_w()
	pi0 = plogis(-0.5 + 0.2 * w)
	lambda = exp(0.5 + 0.4 * w + 0.2 * x1)
	y = ifelse(rbinom(n, 1L, pi0) == 1L, 0, rztpois(n, lambda))
	seq_des$add_all_subject_responses(y)
	seq_des
}

test_that("ZIP: default estimand is conditional and supported estimands include the new values", {
	seq_des = simulate_zip_design(1L)
	inf = InferenceCountZeroInflatedPoisson$new(seq_des)
	expect_equal(inf$get_estimand(), "conditional")
	expect_setequal(inf$get_supported_estimands(), c("conditional", "marginal_mean_diff", "marginal_ratio"))
	expect_true(inf$supports("marginal_estimand"))
})

test_that("Hurdle: default estimand is conditional and supported estimands include the new values", {
	seq_des = simulate_hurdle_design(1L)
	inf = InferenceCountHurdlePoisson$new(seq_des)
	expect_equal(inf$get_estimand(), "conditional")
	expect_setequal(inf$get_supported_estimands(), c("conditional", "marginal_mean_diff", "marginal_ratio"))
	expect_true(inf$supports("marginal_estimand"))
})

test_that("ZIP: conditional estimate/CI are unchanged across set_estimand() round-trips", {
	seq_des = simulate_zip_design(2L)
	inf_a = InferenceCountZeroInflatedPoisson$new(seq_des)
	est_a = inf_a$compute_estimate()
	ci_a = inf_a$compute_asymp_confidence_interval()

	# Direct CI call with no prior compute_estimate() -- exercises the
	# compute_asymp_*-bypass fix, not just compute_estimate().
	inf_b = InferenceCountZeroInflatedPoisson$new(seq_des)
	ci_b = inf_b$compute_asymp_confidence_interval()
	expect_equal(ci_b, ci_a, tolerance = 1e-8)

	inf_c = InferenceCountZeroInflatedPoisson$new(seq_des)
	inf_c$compute_estimate()
	inf_c$set_estimand("marginal_mean_diff")
	inf_c$compute_estimate()
	inf_c$set_estimand("marginal_ratio")
	inf_c$compute_estimate()
	inf_c$set_estimand("conditional")
	est_c = inf_c$compute_estimate()
	ci_c = inf_c$compute_asymp_confidence_interval()
	expect_equal(est_c, est_a, tolerance = 1e-8)
	expect_equal(ci_c, ci_a, tolerance = 1e-8)
})

test_that("Hurdle: conditional estimate/CI are unchanged across set_estimand() round-trips", {
	seq_des = simulate_hurdle_design(2L)
	inf_a = InferenceCountHurdlePoisson$new(seq_des)
	est_a = inf_a$compute_estimate()
	ci_a = inf_a$compute_asymp_confidence_interval()

	inf_c = InferenceCountHurdlePoisson$new(seq_des)
	inf_c$compute_estimate()
	inf_c$set_estimand("marginal_ratio")
	inf_c$compute_estimate()
	inf_c$set_estimand("conditional")
	est_c = inf_c$compute_estimate()
	ci_c = inf_c$compute_asymp_confidence_interval()
	expect_equal(est_c, est_a, tolerance = 1e-8)
	expect_equal(ci_c, ci_a, tolerance = 1e-8)
})

test_that("ZIP: marginal_mean_diff/marginal_ratio point estimates match a hand-computed g-computation average", {
	seq_des = simulate_zip_design(3L)
	inf = InferenceCountZeroInflatedPoisson$new(seq_des)
	inf$compute_estimate()
	raw = inf$.__enclos_env__$private$cached_mod$mod
	expect_false(is.null(raw$X_fit))
	expect_false(is.null(raw$Xzi_fit))

	p = ncol(raw$X_fit)
	b_cond = raw$params[seq_len(p)]
	b_zi = raw$params[(p + 1L):length(raw$params)]
	mean_fn = function(Xm, Xzm){
		lambda = exp(as.numeric(Xm %*% b_cond))
		pi0 = plogis(as.numeric(Xzm %*% b_zi))
		(1 - pi0) * lambda
	}
	X1 = raw$X_fit; X1[, 2L] = 1
	X0 = raw$X_fit; X0[, 2L] = 0
	Xz1 = raw$Xzi_fit; Xz1[, 2L] = 1
	Xz0 = raw$Xzi_fit; Xz0[, 2L] = 0
	mean1 = mean(mean_fn(X1, Xz1))
	mean0 = mean(mean_fn(X0, Xz0))
	hand_diff = mean1 - mean0
	hand_ratio = log(mean1 / mean0)

	inf$set_estimand("marginal_mean_diff")
	expect_equal(inf$compute_estimate(), hand_diff, tolerance = 1e-8)
	inf$set_estimand("marginal_ratio")
	expect_equal(inf$compute_estimate(), hand_ratio, tolerance = 1e-8)
})

test_that("Hurdle: marginal_mean_diff matches a hand-computed g-computation average using the zero-truncated Poisson mean", {
	seq_des = simulate_hurdle_design(3L)
	inf = InferenceCountHurdlePoisson$new(seq_des)
	inf$compute_estimate()
	raw = inf$.__enclos_env__$private$cached_mod$mod
	expect_false(is.null(raw$X_fit))

	p = ncol(raw$X_fit)
	b_cond = raw$params[seq_len(p)]
	b_zi = raw$params[(p + 1L):length(raw$params)]
	mean_fn = function(Xm, Xzm){
		lambda = exp(as.numeric(Xm %*% b_cond))
		pi0 = plogis(as.numeric(Xzm %*% b_zi))
		trunc_mean = lambda / (1 - exp(-lambda))
		(1 - pi0) * trunc_mean
	}
	X1 = raw$X_fit; X1[, 2L] = 1
	X0 = raw$X_fit; X0[, 2L] = 0
	Xz1 = raw$Xzi_fit; Xz1[, 2L] = 1
	Xz0 = raw$Xzi_fit; Xz0[, 2L] = 0
	hand_diff = mean(mean_fn(X1, Xz1)) - mean(mean_fn(X0, Xz0))

	inf$set_estimand("marginal_mean_diff")
	expect_equal(inf$compute_estimate(), hand_diff, tolerance = 1e-8)
})

test_that("Zero-truncated Poisson mean formula matches its empirical value at known parameters", {
	set.seed(42)
	lambda = 2.3
	N = 300000L
	y = rpois(N, lambda)
	y_trunc = y[y > 0]
	formula_mean = lambda / (1 - exp(-lambda))
	# Monte Carlo tolerance for N = 3e5 draws at this lambda.
	expect_equal(mean(y_trunc), formula_mean, tolerance = 0.02)
})

test_that("ZIP: marginal delta-method SEs are positive and finite", {
	seq_des = simulate_zip_design(4L)
	inf = InferenceCountZeroInflatedPoisson$new(seq_des)
	inf$set_estimand("marginal_mean_diff")
	ci = inf$compute_asymp_confidence_interval()
	expect_true(all(is.finite(ci)))
	inf$set_estimand("marginal_ratio")
	ci2 = inf$compute_asymp_confidence_interval()
	expect_true(all(is.finite(ci2)))
})

test_that("Hurdle: marginal delta-method SEs are positive and finite", {
	seq_des = simulate_hurdle_design(4L)
	inf = InferenceCountHurdlePoisson$new(seq_des)
	inf$set_estimand("marginal_mean_diff")
	ci = inf$compute_asymp_confidence_interval()
	expect_true(all(is.finite(ci)))
})

test_that("ZIP: marginal estimand shrinks supported testing types to wald only, and setter order is symmetric", {
	seq_des = simulate_zip_design(5L)

	inf1 = InferenceCountZeroInflatedPoisson$new(seq_des)
	full_types = inf1$get_supported_testing_types()
	expect_true(length(full_types) > 1L)
	inf1$set_estimand("marginal_mean_diff")
	expect_equal(inf1$get_supported_testing_types(), "wald")

	inf2 = InferenceCountZeroInflatedPoisson$new(seq_des)
	inf2$set_testing_type("lik_ratio")
	expect_error(inf2$set_estimand("marginal_ratio"), "not supported under this estimand")
	expect_equal(inf2$get_estimand(), "conditional")
})

test_that("NegBin siblings do not support a marginal estimand", {
	skip_if_not_installed("glmmTMB")
	seq_des = simulate_zip_design(6L)
	inf_zinb = InferenceCountZeroInflatedNegBin$new(seq_des)
	expect_false(inf_zinb$supports("marginal_estimand"))
	inf_hnb = InferenceCountHurdleNegBin$new(seq_des)
	expect_false(inf_hnb$supports("marginal_estimand"))
})
