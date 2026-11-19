# v1.0.6-TODO-30 and v1.0.6-TODO-152 (2026-11-19): the zero-inflation part of a
# zero-augmented Poisson fit often has no finite maximum (it runs off along a
# flat ridge, e.g. zero intercept -23.8 and zero treatment +23.8).
# * TODO-30: a replicate warm-started from such a full-data fit cannot move its
#   zero part, so every ZIP randomization replicate differed from a fresh fit on
#   the same data (by up to 0.84), and the bootstrap-randomization reusable worker
#   differed from its slow path (v1.0.6-TODO-208 (3)). A warm start whose zero
#   part is on the ridge is now dropped (cold start).
# * TODO-152: the default start can stop at an interior local maximum; each ZIP
#   fit also runs L-BFGS from pscl::zeroinfl()'s start and keeps the lower
#   negative log-likelihood. A separated zero part is flagged: one classed
#   warning, zero-part rows NA, count-part treatment estimate kept.

za_ridge_design = function(w = NULL, seed = 3L, n = 80L) {
	set.seed(seed)
	x1 = rnorm(n); x2 = rnorm(n); w0 = rep(c(1, 0), length.out = n)
	y = ifelse(rbinom(n, 1L, plogis(-0.8 + 0.3 * w0 - 0.3 * x1)) == 1L, 0L,
		rpois(n, exp(0.3 + 0.2 * w0 + 0.2 * x1 - 0.1 * x2)))
	des = DesignFixedBernoulli$new(n = n, response_type = "count", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = x1, x2 = x2))
	des$overwrite_all_subject_assignments(if (is.null(w)) w0 else w)
	des$add_all_subject_responses(y)
	des
}

za_fresh_estimate = function(cls, des) {
	inf = cls$new(des, model_formula = ~ x1 + x2, verbose = FALSE)
	inf$num_cores = 1L
	suppressWarnings(inf$compute_estimate(estimate_only = TRUE))
}

test_that("a warm start whose zero part is on the ridge is dropped", {
	X = cbind(1, rep(0:1, 5), seq(-1, 1, length.out = 10))
	expect_true(zero_augmented_warm_start_on_ridge(X, c(0, 0.5, 0.1, -23.8, 23.8, 0), n_cond = 3L))
	expect_true(zero_augmented_warm_start_on_ridge(X, c(0, 0.5, 0.1, -234.6, 121, 0), n_cond = 3L))
	expect_false(zero_augmented_warm_start_on_ridge(X, c(0, 0.5, 0.1, -1.2, 0.8, 0.3), n_cond = 3L))
	expect_false(zero_augmented_warm_start_on_ridge(X, NULL, n_cond = 3L))
	expect_true(zero_augmented_warm_start_on_ridge(X, c(0, 0.5, 0.1, -1, NA, 0), n_cond = 3L))
	expect_true(zero_augmented_warm_start_on_ridge(X, c(0, 0.5, 0.1, -1.2, 0.8, 0.3), n_cond = 3L, at_boundary = TRUE))
})

test_that("ZIP / ZINB randomization replicates equal fresh fits when the full-data zero part is on the ridge", {
	skip_on_cran()
	for (cls in list(InferenceCountZeroInflatedPoisson, InferenceCountZeroInflatedNegBin)) {
		inf = cls$new(za_ridge_design(), model_formula = ~ x1 + x2, verbose = FALSE)
		inf$num_cores = 1L
		inf$set_seed(11L)
		suppressWarnings(inf$compute_estimate())
		pv = inf$.__enclos_env__$private
		# The repro's full-data zero part: intercept ~ -23.8, treatment ~ +23.8.
		expect_true(zero_augmented_warm_start_on_ridge(
			pv$cached_values$likelihood_test_context$Xzi, pv$get_fit_warm_start("params"),
			ncol(pv$cached_values$likelihood_test_context$X)))
		r = 30L
		perms = pv$generate_permutations(r)
		rand = suppressWarnings(inf$approximate_randomization_distribution_beta_hat_T(r = r, permutations = perms, show_progress = FALSE))
		fresh = vapply(seq_len(r), function(b) za_fresh_estimate(cls, za_ridge_design(w = perms$w_mat[, b])), numeric(1))
		expect_true(all(is.finite(rand)))
		expect_equal(rand, fresh, tolerance = 1e-6)
	}
})

test_that("ZIP bootstrap replicates equal fresh fits on the ridge repro", {
	skip_on_cran()
	inf = InferenceCountZeroInflatedPoisson$new(za_ridge_design(), model_formula = ~ x1 + x2, verbose = FALSE)
	inf$num_cores = 1L
	inf$set_seed(11L)
	suppressWarnings(inf$compute_estimate())
	pv = inf$.__enclos_env__$private
	B = 20L
	boot = suppressWarnings(inf$approximate_bootstrap_distribution_beta_hat_T(B = B, show_progress = FALSE))
	set.seed(pv$seed)
	draws = replicate(B, pv$bootstrap_sample_indices(pv$n, NULL), simplify = FALSE)
	set.seed(3L)
	n = 80L; x1 = rnorm(n); x2 = rnorm(n); w0 = rep(c(1, 0), length.out = n)
	y = ifelse(rbinom(n, 1L, plogis(-0.8 + 0.3 * w0 - 0.3 * x1)) == 1L, 0L,
		rpois(n, exp(0.3 + 0.2 * w0 + 0.2 * x1 - 0.1 * x2)))
	fresh = vapply(draws, function(d) {
		i = d$i_b
		des = DesignFixedBernoulli$new(n = length(i), response_type = "count", verbose = FALSE)
		des$add_all_subjects_to_experiment(data.frame(x1 = x1[i], x2 = x2[i]))
		des$overwrite_all_subject_assignments(w0[i])
		des$add_all_subject_responses(y[i])
		za_fresh_estimate(InferenceCountZeroInflatedPoisson, des)
	}, numeric(1))
	expect_equal(boot, fresh, tolerance = 1e-6)
})

test_that("ZIP bootstrap-randomization reusable worker equals the slow path when the zero part is saturated", {
	skip_on_cran()
	# v1.0.6-TODO-208 (3) repro: plain Poisson data, so the full-data zero part
	# is saturated (zero intercept ~ -234.6).
	for (estimand in c("conditional", "marginal_mean_diff")) {
		n = 80L
		set.seed(1)
		X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
		des = DesignFixedBernoulli$new(n = n, response_type = "count", verbose = FALSE)
		des$add_all_subjects_to_experiment(X)
		des$assign_w_to_all_subjects()
		des$add_all_subject_responses(rpois(n, exp(0.5 + 0.4 * X$x1 + 0.5 * des$get_w())))
		inf = InferenceCountZeroInflatedPoisson$new(des, verbose = FALSE)
		inf$num_cores = 1L
		inf$set_seed(1L)
		if (estimand != "conditional") inf$set_estimand(estimand)
		suppressWarnings(inf$compute_estimate())
		pv = inf$.__enclos_env__$private
		set.seed(5)
		draws = pv$generate_rand_bootstrap_draws(10L, materialize_w = TRUE)
		worker = suppressWarnings(inf$approximate_rand_bootstrap_distribution_beta_hat_T(
			B = 10L, delta = 0, transform_responses = "log", rand_bootstrap_draws = draws, show_progress = FALSE))
		slow = vapply(draws, function(d) {
			sub_inf = pv$bootstrap_subset_inference(list(i_b = d$i_b, m_vec_b = d$m_vec_b), smooth = FALSE)
			sp = sub_inf$.__enclos_env__$private
			sp$des_obj_priv_int$w = as.numeric(d$w_b)
			sp$des_obj_priv_int$y = pv$y[d$i_b]
			pv$sync_randomization_worker_state(sp$des_obj, sub_inf)
			suppressWarnings(sp$compute_treatment_estimate_during_randomization_inference(TRUE))
		}, numeric(1))
		expect_true(all(is.finite(worker)))
		expect_equal(worker, slow, tolerance = 1e-6)
	}
})

test_that("ZIP escapes an interior local maximum via the pscl-start candidate", {
	# Unseparated data where the default start stops at a local maximum
	# (treatment 1.138, nll 32.147); pscl::zeroinfl gives -0.466097 (nll 31.991).
	set.seed(98)
	n = sample(c(24, 30, 40), 1); x1 = rnorm(n); x2 = rnorm(n); w = sample(rep(0:1, n / 2))
	a = runif(1, -3, 0.5)
	y = ifelse(rbinom(n, 1, plogis(a + 1.5 * w - x1)) == 1, 0L, rpois(n, exp(0.4 + 0.3 * w + 0.3 * x1)))
	des = DesignFixedBernoulli$new(n = n, response_type = "count", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = x1, x2 = x2))
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(y)
	inf = InferenceCountZeroInflatedPoisson$new(des, model_formula = ~ x1 + x2, verbose = FALSE)
	separated = FALSE
	est = withCallingHandlers(inf$compute_estimate(),
		edi_zero_part_separation_warning = function(w) { separated <<- TRUE; invokeRestart("muffleWarning") })
	expect_false(separated)
	expect_equal(est, -0.466097, tolerance = 1e-4)
	pv = inf$.__enclos_env__$private
	ctx = pv$cached_values$likelihood_test_context
	old = fast_zero_augmented_poisson_cpp(ctx$X, as.numeric(y), ctx$Xzi, FALSE,
		smart_cold_start = pv$smart_cold_start_default, estimate_only = TRUE, optimization_alg = pv$optimization_alg)
	expect_gt(zip_neg_loglik_r(old$params, ctx$X, ctx$Xzi, y), zip_neg_loglik_r(pv$cached_mod$mod$params, ctx$X, ctx$Xzi, y) + 0.1)
	if (requireNamespace("pscl", quietly = TRUE)) {
		m = suppressWarnings(pscl::zeroinfl(y ~ w + x1 + x2, data = data.frame(y, w, x1, x2)))
		expect_equal(est, unname(suppressWarnings(coef(m))[2]), tolerance = 1e-4)
	}
})

test_that("a separated zero part is flagged, the count-part treatment estimate is kept", {
	for (cls in list(InferenceCountZeroInflatedPoisson, InferenceCountZeroInflatedNegBin)) {
		inf = cls$new(za_ridge_design(), model_formula = ~ x1 + x2, verbose = FALSE)
		ws = list()
		est = withCallingHandlers(inf$compute_estimate(),
			warning = function(w) { ws[[length(ws) + 1L]] <<- w; invokeRestart("muffleWarning") })
		sep = Filter(function(w) inherits(w, "edi_zero_part_separation_warning"), ws)
		expect_length(sep, 1L)
		expect_s3_class(sep[[1]], "edi_logistic_separation_warning")
		expect_identical(sep[[1]]$component, "zero")
		expect_true(is.finite(est))
		pv = inf$.__enclos_env__$private
		expect_identical(pv$cached_values$zero_part_nonestimable_reason, "zero_part_separated")
		st = pv$cached_values$summary_table
		expect_true(all(is.na(st[startsWith(rownames(st), "zero:"), ])))
		expect_true(all(is.finite(st[startsWith(rownames(st), "conditional:"), 1L])))
		# once per object
		expect_no_warning(inf$compute_estimate(), class = "edi_zero_part_separation_warning")
	}
	# ZIP count-part treatment estimate equals pscl::zeroinfl's 0.80589.
	inf = InferenceCountZeroInflatedPoisson$new(za_ridge_design(), model_formula = ~ x1 + x2, verbose = FALSE)
	expect_equal(suppressWarnings(inf$compute_estimate()), 0.80589, tolerance = 1e-4)
	# The hurdle part of the same data is not separated: no warning.
	hurdle = InferenceCountHurdlePoisson$new(za_ridge_design(), model_formula = ~ x1 + x2, verbose = FALSE)
	flagged = FALSE
	withCallingHandlers(hurdle$compute_estimate(),
		edi_zero_part_separation_warning = function(w) { flagged <<- TRUE; invokeRestart("muffleWarning") })
	expect_false(flagged)
})

test_that("on data with a well-identified zero part the guarded fit is the unguarded fit, bit for bit", {
	set.seed(21)
	n = 120L; x1 = rnorm(n); x2 = rnorm(n); w = rep(0:1, length.out = n)
	y = ifelse(rbinom(n, 1, plogis(-0.5 + 0.3 * w - 0.4 * x1)) == 1, 0L, rpois(n, exp(0.8 + 0.3 * w + 0.3 * x1 - 0.2 * x2)))
	des = DesignFixedBernoulli$new(n = n, response_type = "count", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = x1, x2 = x2))
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(y)
	inf = InferenceCountZeroInflatedPoisson$new(des, model_formula = ~ x1 + x2, verbose = FALSE)
	flagged = FALSE
	est = withCallingHandlers(inf$compute_estimate(),
		edi_zero_part_separation_warning = function(w) { flagged <<- TRUE; invokeRestart("muffleWarning") })
	expect_false(flagged)
	pv = inf$.__enclos_env__$private
	ctx = pv$cached_values$likelihood_test_context
	plain = fast_zero_augmented_poisson_cpp(ctx$X, as.numeric(y), ctx$Xzi, FALSE,
		smart_cold_start = pv$smart_cold_start_default, estimate_only = FALSE, optimization_alg = pv$optimization_alg)
	expect_identical(est, as.numeric(plain$params[2]))
	expect_identical(as.numeric(pv$cached_mod$mod$params), as.numeric(plain$params))
	expect_false(zero_augmented_warm_start_on_ridge(ctx$Xzi, plain$params, ncol(ctx$X)))
})

# v1.0.6-TODO-218 (1), owner 2026-11-19: data with no excess zeros push the
# zero-inflation part only toward "no inflation"; that is reported with a
# message of class edi_no_zero_inflation_message, not the separation warning.
za_conditions = function(expr) {
	got = character(0)
	value = withCallingHandlers(expr,
		edi_no_zero_inflation_message = function(m) { got <<- c(got, "message"); invokeRestart("muffleMessage") },
		edi_zero_part_separation_warning = function(w) { got <<- c(got, "warning"); invokeRestart("muffleWarning") })
	list(value = value, got = got)
}

test_that("no excess zeros gives the no-zero-inflation message, not the separation warning", {
	# ZIP on plain Poisson data: one arm's inflation probability is driven to 0,
	# the other's stays below 1%.
	set.seed(3)
	n = 100; x1 = rnorm(n); w = rep(0:1, length.out = n)
	y = rpois(n, exp(0.7 + 0.3 * w + 0.2 * x1))
	des = DesignFixedBernoulli$new(n = n, response_type = "count", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = x1))
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(y)
	inf = InferenceCountZeroInflatedPoisson$new(des, model_formula = ~ x1, verbose = FALSE)
	msgs = list()
	est = withCallingHandlers(inf$compute_estimate(),
		edi_no_zero_inflation_message = function(m) { msgs[[length(msgs) + 1L]] <<- m; invokeRestart("muffleMessage") },
		edi_zero_part_separation_warning = function(w) stop("unexpected separation warning"))
	expect_length(msgs, 1L)
	expect_s3_class(msgs[[1]], "message")
	expect_false(inherits(msgs[[1]], "warning"))
	expect_match(conditionMessage(msgs[[1]]), "no evidence of zero inflation: the fitted zero-inflation probability is essentially 0 for every subject")
	expect_match(conditionMessage(msgs[[1]]), "a plain Poisson model fits these data", fixed = TRUE)
	expect_true(is.finite(est))
	pv = inf$.__enclos_env__$private
	expect_identical(pv$cached_values$zero_part_nonestimable_reason, "no_zero_inflation")
	st = pv$cached_values$summary_table
	expect_true(all(is.na(st[startsWith(rownames(st), "zero:"), ])))
	# once per object, silent inside resampling
	expect_no_message(inf$compute_estimate(), class = "edi_no_zero_inflation_message")
	expect_no_message(suppressWarnings(inf$approximate_randomization_distribution_beta_hat_T(r = 5L, show_progress = FALSE)),
		class = "edi_no_zero_inflation_message")

	# ZINB on plain negative-binomial data, zero part ~ 1: one arm driven to 0,
	# the other at 3.7%.
	set.seed(7)
	n = 500L
	des = DesignFixedBernoulli$new(n = n, response_type = "count", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(MASS::rnegbin(n, mu = exp(0.5 + 0.3 * des$get_w()), theta = 3))
	zinb = InferenceCountZeroInflatedNegBin$new(des, model_formula_zero = ~1, verbose = FALSE)
	msgs = list()
	withCallingHandlers(zinb$compute_estimate(),
		edi_no_zero_inflation_message = function(m) { msgs[[length(msgs) + 1L]] <<- m; invokeRestart("muffleMessage") },
		edi_zero_part_separation_warning = function(w) stop("unexpected separation warning"))
	expect_length(msgs, 1L)
	expect_match(conditionMessage(msgs[[1]]), "driven to 0 for 247 of 500 subjects (at most 3.7% for the rest)", fixed = TRUE)
	expect_equal(msgs[[1]]$n_to_zero, 247L)
})

test_that("a subject pushed to a structural zero keeps the separation warning", {
	# Plain Poisson data where the ZIP MLE sends the zeros at extreme x1 to
	# inflation probability ~1 alongside subjects driven to 0: mixed directions.
	set.seed(1)
	n = 100; x1 = rnorm(n); w = rep(0:1, length.out = n)
	y = rpois(n, exp(0.7 + 0.3 * w + 0.2 * x1))
	des = DesignFixedBernoulli$new(n = n, response_type = "count", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = x1))
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(y)
	got = za_conditions(InferenceCountZeroInflatedPoisson$new(des, model_formula = ~ x1, verbose = FALSE)$compute_estimate())$got
	expect_identical(got, "warning")
	# TODO-30 repro (one arm driven to 0, the other with ~50% inflation): warning.
	got = za_conditions(InferenceCountZeroInflatedPoisson$new(za_ridge_design(), model_formula = ~ x1 + x2, verbose = FALSE)$compute_estimate())$got
	expect_identical(got, "warning")
	# The hurdle part has no "no inflation" case: a saturated hurdle part warns.
	expect_false(zero_augmented_zero_part_separation(
		list(params = c(0.5, 0.2, -30, 0)), cbind(1, rep(0:1, 5)), rep(1, 10), cbind(1, rep(0:1, 5)), is_hurdle = TRUE)$no_inflation)
	expect_true(zero_augmented_zero_part_separation(
		list(params = c(0.5, 0.2, -30, 0)), cbind(1, rep(0:1, 5)), rep(1, 10), cbind(1, rep(0:1, 5)))$no_inflation)
	expect_false(zero_augmented_zero_part_separation(
		list(params = c(0.5, 0.2, -30, 32)), cbind(1, rep(0:1, 5)), rep(1, 10), cbind(1, rep(0:1, 5)))$no_inflation)
})

test_that("InferenceCountHurdleNegBin flags a separated hurdle part like InferenceCountHurdlePoisson", {
	# v1.0.6-TODO-218 (2): HurdleNegBin fits its hurdle part separately (own C++
	# path) and had no separation flag. Zeros exactly where x1 < 0: the hurdle
	# logistic part is separated; both hurdle classes warn (never the
	# no-zero-inflation message) and keep the count-part treatment estimate.
	set.seed(11)
	n = 50
	x1 = rnorm(n)
	w = sample(rep(0:1, n / 2))
	y = ifelse(x1 < 0, 0, 1 + rpois(n, exp(0.3 + 0.2 * w)))
	des = DesignFixediBCRD$new(n = n, response_type = "count")
	des$add_all_subjects_to_experiment(data.frame(x1 = x1))
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(y)
	ests = c()
	for (cls in c("InferenceCountHurdlePoisson", "InferenceCountHurdleNegBin")) {
		inf = get(cls)$new(des, verbose = FALSE)
		ws = list()
		ms = list()
		est = withCallingHandlers(inf$compute_estimate(),
			warning = function(w) { ws[[length(ws) + 1L]] <<- w; invokeRestart("muffleWarning") },
			message = function(m) { ms[[length(ms) + 1L]] <<- m; invokeRestart("muffleMessage") })
		sep = Filter(function(w) inherits(w, "edi_zero_part_separation_warning"), ws)
		expect_length(sep, 1L)
		expect_identical(sep[[1]]$component, "hurdle")
		expect_length(Filter(function(m) inherits(m, "edi_no_zero_inflation_message"), ms), 0L)
		expect_identical(inf$.__enclos_env__$private$cached_values$zero_part_nonestimable_reason, "zero_part_separated", info = cls)
		expect_true(is.finite(est), info = cls)
		expect_no_warning(inf$compute_estimate(), class = "edi_zero_part_separation_warning")
		ests[cls] = est
	}
	# the count parts are the same zero-truncated fit up to the NB dispersion
	expect_equal(ests[["InferenceCountHurdleNegBin"]], ests[["InferenceCountHurdlePoisson"]], tolerance = 1e-3)
	# a well-identified hurdle part is not flagged
	set.seed(12)
	y2 = ifelse(runif(n) < plogis(0.2 - 0.5 * x1), 0, 1 + rpois(n, exp(0.3 + 0.2 * w)))
	des2 = DesignFixediBCRD$new(n = n, response_type = "count")
	des2$add_all_subjects_to_experiment(data.frame(x1 = x1))
	des2$overwrite_all_subject_assignments(w)
	des2$add_all_subject_responses(y2)
	inf2 = InferenceCountHurdleNegBin$new(des2, verbose = FALSE)
	expect_no_warning(inf2$compute_estimate(), class = "edi_zero_part_separation_warning")
	expect_null(inf2$.__enclos_env__$private$cached_values$zero_part_nonestimable_reason)
})
