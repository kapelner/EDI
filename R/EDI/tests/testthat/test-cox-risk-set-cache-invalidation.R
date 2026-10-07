make_cox_cache_fixture <- function(stratified = FALSE, seed = 20261007L) {
	set.seed(seed)
	n <- 120L
	x <- data.frame(x1 = rnorm(n), stratum = rep(0:1, each = n / 2L))
	des <- DesignFixedBernoulli$new(n = n, response_type = "survival", seed = seed, verbose = FALSE)
	des$add_all_subjects_to_experiment(x)
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	t_event <- rexp(n, rate = exp(0.4 * w + 0.2 * x$x1))
	t_censor <- rexp(n, rate = 0.12)
	EDI:::add_all_subject_responses_seq(des, pmin(t_event, t_censor), deads = as.numeric(t_event <= t_censor))
	generator <- if (stratified) InferenceSurvivalStratCoxPHRegr else InferenceSurvivalCoxPHRegr
	inf <- generator$new(des, model_formula = ~ x1 + stratum, use_rcpp = TRUE, verbose = FALSE)
	list(inf = inf, priv = inf$.__enclos_env__$private)
}

cox_cache_ptr <- function(priv, stratified) {
	if (stratified) priv$strat_cox_data_cache else priv$cox_data_cache
}

cox_cache_estimate <- function(priv) {
	fit <- priv$generate_mod(estimate_only = TRUE)
	as.numeric(if (!is.null(fit$beta_hat_T)) fit$beta_hat_T else fit$b[2L])[1L]
}

mutate_cox_input <- function(priv, input) {
	n <- length(priv$y)
	switch(input,
		y = { priv$y <- rev(priv$y) },
		dead = { priv$dead[seq(2L, n, by = 5L)] <- 1 - priv$dead[seq(2L, n, by = 5L)] },
		X = { priv$X <- priv$X[rev(seq_len(n)), , drop = FALSE] },
		strata = {
			idx_0 <- seq_len(n %/% 6L)
			idx_1 <- n %/% 2L + idx_0
			priv$X[idx_0, "stratum"] <- 1
			priv$X[idx_1, "stratum"] <- 0
		}
	)
}

test_that("Cox risk-set caches rebuild for y, dead, and X changes at fixed treatment", {
	for (stratified in c(FALSE, TRUE)) {
		inputs <- if (stratified) c("y", "dead", "X", "strata") else c("y", "dead", "X")
		for (input in inputs) {
			f <- make_cox_cache_fixture(stratified)
			before <- cox_cache_estimate(f$priv)
			ptr_before <- cox_cache_ptr(f$priv, stratified)
			expect_true(is.finite(before), info = paste(stratified, input, "initial fit"))
			expect_false(is.null(ptr_before), info = paste(stratified, input, "initial cache"))
			w_before <- f$priv$w

			mutate_cox_input(f$priv, input)
			if (identical(input, "strata")) expect_identical(f$priv$get_X(), f$priv$X)
			f$priv$clear_fit_warm_start()
			after <- cox_cache_estimate(f$priv)
			ptr_after <- cox_cache_ptr(f$priv, stratified)
			expect_identical(f$priv$w, w_before)
			expect_false(identical(ptr_after, ptr_before), info = paste(stratified, input, "cache rebuilt"))

			fresh <- make_cox_cache_fixture(stratified)
			mutate_cox_input(fresh$priv, input)
			ref <- cox_cache_estimate(fresh$priv)
			expect_true(is.finite(ref), info = paste(stratified, input, "fresh fit"))
			expect_equal(after, ref, tolerance = 1e-5, info = paste(stratified, input, "fresh estimate"))
		}
	}
})

test_that("Cox risk-set caches are reused for identical inputs", {
	cox_calls <- 0L
	strat_calls <- 0L
	original_cox_builder <- EDI:::build_cox_data_cache_cpp
	original_strat_builder <- EDI:::build_stratified_cox_data_cache_cpp
	testthat::local_mocked_bindings(
		build_cox_data_cache_cpp = function(...) {
			cox_calls <<- cox_calls + 1L
			original_cox_builder(...)
		},
		build_stratified_cox_data_cache_cpp = function(...) {
			strat_calls <<- strat_calls + 1L
			original_strat_builder(...)
		},
		.package = "EDI"
	)
	for (stratified in c(FALSE, TRUE)) {
		f <- make_cox_cache_fixture(stratified)
		calls_before <- cox_calls + strat_calls
		first <- cox_cache_estimate(f$priv)
		ptr <- cox_cache_ptr(f$priv, stratified)
		second <- cox_cache_estimate(f$priv)
		expect_equal(cox_calls + strat_calls - calls_before, 1L)
		expect_identical(cox_cache_ptr(f$priv, stratified), ptr)
		expect_equal(second, first, tolerance = 1e-8)
	}
})

test_that("Cox bootstrap workers rebuild risk sets when resamples share treatment values", {
	for (stratified in c(FALSE, TRUE)) {
		f <- make_cox_cache_fixture(stratified)
		state <- f$priv$create_bootstrap_worker_state()
		idx_a <- seq_along(state$base_w)
		idx_b <- idx_a
		for (arm in unique(state$base_w)) {
			arm_rows <- which(state$base_w == arm)
			idx_b[arm_rows] <- rev(arm_rows)
		}
		expect_identical(state$base_w[idx_a], state$base_w[idx_b])
		expect_false(identical(state$base_y[idx_a], state$base_y[idx_b]))

		f$priv$load_bootstrap_sample_into_worker(state, idx_a)
		cox_cache_estimate(state$worker_priv)
		ptr_a <- cox_cache_ptr(state$worker_priv, stratified)
		f$priv$load_bootstrap_sample_into_worker(state, idx_b)
		got <- cox_cache_estimate(state$worker_priv)
		expect_false(identical(cox_cache_ptr(state$worker_priv, stratified), ptr_a))

		fresh_state <- f$priv$create_bootstrap_worker_state()
		f$priv$load_bootstrap_sample_into_worker(fresh_state, idx_b)
		ref <- cox_cache_estimate(fresh_state$worker_priv)
		expect_equal(got, ref, tolerance = 1e-5)
	}
})

test_that("Cox slow randomization fits agree across deltas on a reused worker", {
	reused <- make_cox_cache_fixture()$inf
	reused$num_cores <- 1L
	priv <- reused$.__enclos_env__$private
	w <- priv$w
	permutations <- list(w_mat = cbind(w, rev(w), w))
	priv$begin_rand_worker_reuse_session()
	on.exit(priv$end_rand_worker_reuse_session(), add = TRUE)
	# A nonzero delta with the additive transform selects the public slow path.
	reused$approximate_randomization_distribution_beta_hat_T(
		r = 3L, delta = 0.01, transform_responses = "none",
		permutations = permutations, show_progress = FALSE
	)
	worker <- priv$cached_values$reusable_rand_worker$state$worker_priv
	expect_false(is.null(worker))
	got <- reused$approximate_randomization_distribution_beta_hat_T(
		r = 3L, delta = 0.02, transform_responses = "none",
		permutations = permutations, show_progress = FALSE
	)
	expect_identical(priv$cached_values$reusable_rand_worker$state$worker_priv, worker)

	fresh <- make_cox_cache_fixture()$inf
	fresh$num_cores <- 1L
	ref <- fresh$approximate_randomization_distribution_beta_hat_T(
		r = 3L, delta = 0.02, transform_responses = "none",
		permutations = permutations, show_progress = FALSE
	)
	expect_true(all(is.finite(got)))
	expect_equal(got, ref, tolerance = 1e-5)
})

test_that("Cox likelihood-ratio bootstrap agrees with fresh workers across simulated responses", {
	for (stratified in c(FALSE, TRUE)) {
		reused <- make_cox_cache_fixture(stratified)$inf
		fresh <- make_cox_cache_fixture(stratified)$inf
		reused$set_seed(404L)
		fresh$set_seed(404L)
		reused$num_cores <- 1L
		fresh$num_cores <- 1L
		fresh$.__enclos_env__$private$reusable_bootstrap_worker_enabled <- FALSE

		p_reused <- reused$compute_lik_ratio_bootstrap_two_sided_pval(B = 9L, show_progress = FALSE)
		p_fresh <- fresh$compute_lik_ratio_bootstrap_two_sided_pval(B = 9L, show_progress = FALSE)
		diag_reused <- reused$get_last_param_bootstrap_diagnostics()
		diag_fresh <- fresh$get_last_param_bootstrap_diagnostics()
		expect_true(isTRUE(diag_reused$used_reusable_worker))
		expect_false(isTRUE(diag_fresh$used_reusable_worker))
		expect_gte(diag_reused$n_success, 2L)
		expect_equal(diag_reused$n_success, diag_fresh$n_success)
		expect_equal(
			vapply(diag_reused$replicate_results, function(x) x$lr, numeric(1)),
			vapply(diag_fresh$replicate_results, function(x) x$lr, numeric(1)),
			tolerance = 1e-8
		)
		expect_equal(p_reused, p_fresh, tolerance = 1e-8)
	}
})
