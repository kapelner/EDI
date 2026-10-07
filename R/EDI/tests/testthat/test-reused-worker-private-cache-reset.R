library(testthat)
library(EDI)

test_that("private fit-cache reset preserves only inputs unchanged by each draw", {
	fields <- EDI:::EDI_REUSED_WORKER_PRIVATE_CACHE_FIELDS
	expect_setequal(fields, c(
		"cached_design_matrix", "cached_w_for_design_matrix",
		"cached_harden_for_design_matrix", "cached_hardened_X_cov",
		"cached_reduced_X", "cached_X_full_for_reduced",
		"cached_keep_for_reduced", "cached_j_treat_for_reduced",
		"reduced_design_keep_cache", "fixed_covariate_keep_cache",
		"best_X_colnames", "best_Xmm_colnames", "cached_mod"
	))
	preserved <- list(
		sample = character(),
		assignment = c("cached_hardened_X_cov", "fixed_covariate_keep_cache"),
		response = c(
			"cached_design_matrix", "cached_w_for_design_matrix",
			"cached_harden_for_design_matrix", "cached_hardened_X_cov",
			"cached_reduced_X", "cached_X_full_for_reduced",
			"cached_keep_for_reduced", "cached_j_treat_for_reduced"
		)
	)
	for (changed in names(preserved)) {
		priv <- new.env(parent = emptyenv())
		for (field in fields) priv[[field]] <- paste0("old_", field)
		priv$best_par <- "warm_start_untouched"
		priv$X <- matrix(1:4, 2)
		EDI:::reset_reused_worker_private_caches(priv, changed = changed)
		for (field in fields) {
			if (field %in% preserved[[changed]]) {
				expect_identical(priv[[field]], paste0("old_", field), info = paste(changed, field))
			} else {
				expect_null(priv[[field]], info = paste(changed, field))
			}
		}
		expect_identical(priv$best_par, "warm_start_untouched")
		expect_identical(priv$X, matrix(1:4, 2))
	}
})

private_cache_worker_fixture <- function(){
	set.seed(20261007L)
	n <- 30L
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	x <- rnorm(n)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(0.6 * w + 0.4 * x + rnorm(n, sd = 0.5))
	inf <- InferenceContinOLS$new(des, verbose = FALSE)
	list(inf = inf, priv = inf$.__enclos_env__$private, w = w, y = des$get_y(), n = n)
}

test_that("two reused randomization draws clear cached_mod and match a fresh second draw", {
	f <- private_cache_worker_fixture()
	state <- f$priv$create_bootstrap_worker_state()
	template <- f$priv$setup_randomization_template_and_shifts(0, "none")
	w_a <- c(rep(0, f$n / 2), rep(1, f$n / 2))
	w_b <- rev(w_a)
	load <- function(state, w) f$priv$load_randomization_perm_into_worker(
		state, w, 0, "none", template$y_delta,
		template$base_template_y, template$base_template_dead
	)
	load(state, w_a)
	state$worker$compute_estimate(estimate_only = TRUE)
	state$worker_priv$cached_mod <- list(stale = TRUE)
	load(state, w_b)
	expect_null(state$worker_priv$cached_mod)
	got <- state$worker$compute_estimate(estimate_only = TRUE)
	fresh <- f$priv$create_bootstrap_worker_state()
	load(fresh, w_b)
	ref <- fresh$worker$compute_estimate(estimate_only = TRUE)
	expect_true(is.finite(got))
	expect_equal(got, ref, tolerance = 1e-10)
})

test_that("two reused bootstrap samples clear cached_mod and match a fresh second draw", {
	f <- private_cache_worker_fixture()
	state <- f$priv$create_bootstrap_worker_state()
	idx_a <- seq_len(f$n)
	set.seed(45L)
	idx_b <- sample.int(f$n, f$n, replace = TRUE)
	f$priv$load_bootstrap_sample_into_worker(state, idx_a)
	state$worker$compute_estimate(estimate_only = TRUE)
	state$worker_priv$cached_mod <- list(stale = TRUE)
	f$priv$load_bootstrap_sample_into_worker(state, idx_b)
	expect_null(state$worker_priv$cached_mod)
	got <- state$worker$compute_estimate(estimate_only = TRUE)
	fresh <- f$priv$create_bootstrap_worker_state()
	f$priv$load_bootstrap_sample_into_worker(fresh, idx_b)
	ref <- fresh$worker$compute_estimate(estimate_only = TRUE)
	expect_true(is.finite(got))
	expect_equal(got, ref, tolerance = 1e-10)
})

test_that("two reused randomization-bootstrap draws clear cached_mod and match a fresh second draw", {
	f <- private_cache_worker_fixture()
	state <- f$priv$create_bootstrap_worker_state()
	set.seed(46L)
	idx_a <- sample.int(f$n, f$n, replace = TRUE)
	idx_b <- sample.int(f$n, f$n, replace = TRUE)
	w_a <- f$w[idx_a]
	w_b <- f$w[idx_b]
	draw_a <- list(i_b = idx_a, m_vec_b = NULL, w_b = w_a)
	draw_b <- list(i_b = idx_b, m_vec_b = NULL, w_b = w_b)
	load <- function(state, draw) f$priv$load_rand_bootstrap_draw_into_worker(
		state, draw, delta = 0, transform_responses = "none", y0_full = f$y
	)
	load(state, draw_a)
	state$worker$compute_estimate(estimate_only = TRUE)
	state$worker_priv$cached_mod <- list(stale = TRUE)
	load(state, draw_b)
	expect_null(state$worker_priv$cached_mod)
	got <- state$worker$compute_estimate(estimate_only = TRUE)
	fresh <- f$priv$create_bootstrap_worker_state()
	load(fresh, draw_b)
	ref <- fresh$worker$compute_estimate(estimate_only = TRUE)
	expect_true(is.finite(got))
	expect_equal(got, ref, tolerance = 1e-10)
})
