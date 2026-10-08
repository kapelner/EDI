library(testthat)
library(EDI)

clayton_optimizer_source = function() {
	candidates = c(
		file.path("R", "EDI", "src", "fast_survival_models_optim.cpp"),
		file.path("..", "..", "src", "fast_survival_models_optim.cpp"),
		file.path("..", "src", "fast_survival_models_optim.cpp"),
		file.path("src", "fast_survival_models_optim.cpp")
	)
	hit = candidates[file.exists(candidates)]
	if (!length(hit)) return(NA_character_)
	paste(readLines(hit[[1L]], warn = FALSE), collapse = "\n")
}

clayton_bound_fixture = function(n_pairs = 30L, seed = 918L) {
	set.seed(seed)
	n = n_pairs * 2L
	w = rep(c(0, 1), n_pairs)
	pair_idx = matrix(seq_len(n) - 1L, ncol = 2L, byrow = TRUE)
	u1 = runif(n_pairs)
	v = runif(n_pairs)
	theta = 2.5
	u2 = (v^(-theta / (theta + 1)) * (u1^(-theta) - 1) + 1)^(-1 / theta)
	H = as.numeric(rbind(-log(u1), -log(u2)))
	y = exp(0.3 + 0.6 * w + 0.8 * log(H))
	dead = rep(1, n)
	list(
		X = cbind(w = w), y = y, dead = dead,
		pair_idx = pair_idx, singleton_rows = integer(0),
		start = c(0, 0, 0)
	)
}

clayton_censored_golden_fixture = function(n_pairs = 60L, seed = 918L) {
	set.seed(seed)
	n = n_pairs * 2L
	w = rep(c(0, 1), n_pairs)
	pair_id = rep(seq_len(n_pairs), each = 2L)
	u1 = runif(n_pairs)
	v = runif(n_pairs)
	theta = 2.5
	u2 = (v^(-theta / (theta + 1)) * (u1^(-theta) - 1) + 1)^(-1 / theta)
	y_true = exp(0.3 + 0.6 * w + 0.8 * log(as.numeric(rbind(-log(u1), -log(u2)))))
	cens_time = rexp(n, rate = 1 / (3 * median(y_true)))
	list(
		y = pmin(y_true, cens_time), dead = as.integer(y_true <= cens_time),
		X = cbind(w = w), pair_id = pair_id
	)
}

test_that("Clayton objective and gradient share the same upper log-theta bound", {
	source = clayton_optimizer_source()
	skip_if(is.na(source), "native source tree is unavailable")

	expect_match(source, "constexpr double CLAYTON_MAX_LOG_THETA = 6.0", fixed = TRUE)
	expect_match(source, "clamp_clayton_log_theta(log_theta_raw)", fixed = TRUE)
	expect_match(source, "log_theta_raw < CLAYTON_MAX_LOG_THETA ? theta : 0.0", fixed = TRUE)
	expect_false(grepl("std::min(log_theta, 10.0)", source, fixed = TRUE))
	expect_equal(lengths(regmatches(
		source,
		gregexpr("* d_theta_d_log_theta", source, fixed = TRUE)
	)), 4L)
})

test_that("rebuilt Clayton optimizer terminates an unsafe upper-bound start", {
	d = clayton_bound_fixture()
	probe = fast_clayton_weibull_aft_optim_cpp(
		d$X, d$y, d$dead, d$pair_idx, d$singleton_rows, d$start,
		estimate_only = TRUE
	)
	skip_if(is.null(probe$log_theta_at_upper_bound), "requires the rebuilt native library")

	unsafe = as.numeric(probe$params)
	unsafe[length(unsafe)] = 20
	fit = fast_clayton_weibull_aft_optim_cpp(
		d$X, d$y, d$dead, d$pair_idx, d$singleton_rows, unsafe,
		estimate_only = TRUE, maxit = 20L,
		fixed_idx = seq_len(length(unsafe) - 1L),
		fixed_values = unsafe[-length(unsafe)]
	)
	expect_true(fit$converged)
	expect_false(fit$hit_iteration_cap)
	expect_lt(fit$niter, 20L)
	expect_true(fit$log_theta_at_upper_bound)
	expect_identical(as.numeric(tail(fit$params, 1L)), 6)

	score = get_clayton_weibull_aft_score_cpp(
		d$X, d$y, d$dead, d$pair_idx, d$singleton_rows, fit$params
	)
	expect_identical(as.numeric(tail(score, 1L)), 0)
})

test_that("ordinary Clayton fixture remains below the new upper bound", {
	d = clayton_bound_fixture(n_pairs = 60L)
	fit = fast_clayton_weibull_aft_optim_cpp(
		d$X, d$y, d$dead, d$pair_idx, d$singleton_rows, d$start,
		estimate_only = TRUE
	)
	skip_if(is.null(fit$log_theta_at_upper_bound), "requires the rebuilt native library")
	expect_false(fit$log_theta_at_upper_bound)
	expect_lt(tail(fit$params, 1L), 6)
})

test_that("ordinary censored-fit point estimate and standard error retain their golden values", {
	d = clayton_censored_golden_fixture()
	fit = EDI:::.fit_clayton_weibull_aft(
		d$y, d$dead, d$X, d$pair_id, optimization_alg = "lbfgs"
	)

	expect_equal(
		fit$best_par,
		c(0.38234247297251417, 0.72927564468285977,
			-0.25784283213636905, 2.47503512811411941),
		tolerance = 1e-7
	)
	expect_equal(fit$beta, 0.72927564468285977, tolerance = 1e-7)
	expect_equal(fit$ssq, 0.0006922550201495241, tolerance = 1e-7)
	expect_equal(fit$best_fit$value, 81.073240282907307, tolerance = 1e-7)
	expect_lt(tail(fit$best_par, 1L), 6)
})
