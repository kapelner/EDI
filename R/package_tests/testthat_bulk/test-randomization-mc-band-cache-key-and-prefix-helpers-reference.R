library(testthat)
library(EDI)

# InferenceRandomization's private Monte-Carlo / caching helpers with no direct
# test reference: compute_two_sided_randomization_pval_band() (Clopper-Pearson
# band on the two tail proportions), normalize_delta_for_cache(),
# build_randomization_distribution_cache_key(), subset_permutations(),
# get_randomization_distribution_prefix() (incremental batches + cache reuse),
# the reentrant worker-reuse session counter, and two design-family predicates.
# References: stats::binom.test intervals and hand-built expectations.

rand_priv <- function(n = 20L, seed = 123L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = seed)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(w + rnorm(n, sd = 0.3))
	inf <- InferenceAllSimpleAverageDiff$new(des)
	inf$num_cores <- 1L
	list(inf = inf, priv = inf$.__enclos_env__$private)
}

test_that("the randomization p-value band is twice the smaller Clopper-Pearson tail bound, clipped to [0, 1]", {
	f <- rand_priv()
	band_fn <- f$priv$compute_two_sided_randomization_pval_band
	set.seed(2)
	t0s <- c(rnorm(60), NA, Inf, NaN)
	t <- 0.7
	valid <- t0s[is.finite(t0s)]
	n <- length(valid)
	x_ge <- sum(valid >= t); x_le <- sum(valid <= t)
	cp <- function(x) as.numeric(binom.test(x, n, conf.level = 0.9)$conf.int)
	ref <- pmin(1, pmax(0, c(2 * min(cp(x_ge)[1], cp(x_le)[1]), 2 * min(cp(x_ge)[2], cp(x_le)[2]))))
	expect_equal(band_fn(t0s, t, 0.9), ref, tolerance = 1e-8)
	expect_lte(band_fn(t0s, t, 0.9)[1], band_fn(t0s, t, 0.9)[2])
	# Higher confidence widens the band.
	w99 <- band_fn(t0s, t, 0.99); w80 <- band_fn(t0s, t, 0.8)
	expect_gte(diff(w99), diff(w80))
})

test_that("band edge cases: no finite draws, extreme observed statistics", {
	f <- rand_priv()
	band_fn <- f$priv$compute_two_sided_randomization_pval_band
	expect_equal(band_fn(c(NA, Inf), 0, 0.95), c(NA_real_, NA_real_))
	t0s <- seq(-1, 1, length.out = 50)
	# Observed value far above every draw: x_ge = 0, x_le = n -> lower bound 0, upper clipped by 1.
	hi <- band_fn(t0s, 10, 0.95)
	expect_equal(hi[1], 0)
	expect_true(hi[2] > 0 && hi[2] <= 1)
	lo <- band_fn(t0s, -10, 0.95)
	expect_equal(lo[1], 0)
	# Observed in the middle: both tails ~ half -> band brackets ~1.
	mid <- band_fn(t0s, 0, 0.95)
	expect_equal(mid[2], 1)
})

test_that("normalize_delta_for_cache formats to 17 significant digits, rounds to a resolution, and marks non-finite deltas", {
	f <- rand_priv()
	nd <- f$priv$normalize_delta_for_cache
	expect_equal(nd(0.5), format(0.5, scientific = TRUE, digits = 17))
	expect_equal(nd(NA_real_), "NA")
	expect_equal(nd(Inf), "NA")
	expect_equal(nd(0.1234, resolution = 0.01), format(0.12, scientific = TRUE, digits = 17))
	expect_equal(nd(0.1234, resolution = NULL), format(0.1234, scientific = TRUE, digits = 17))
	expect_equal(nd(0.1234, resolution = 0), format(0.1234, scientific = TRUE, digits = 17))
	expect_equal(nd(0.1234, resolution = 0.01), nd(0.1249, resolution = 0.01))
	expect_false(identical(nd(0.1234, resolution = 0.01), nd(0.1350, resolution = 0.01)))
})

test_that("randomization cache keys depend on r, delta, transform and the permutation content", {
	f <- rand_priv()
	key <- function(...) f$priv$build_randomization_distribution_cache_key(...)
	perms <- list(w_mat = matrix(rep(0:1, 10 * 3), nrow = 20))
	perms2 <- list(w_mat = matrix(rep(1:0, 10 * 3), nrow = 20))
	k1 <- key(500L, 0.25, "none", perms)
	expect_true(is.character(k1) && length(k1) == 1L)
	expect_match(k1, "^500\\|")
	expect_equal(key(500L, 0.25, "none", perms), k1)
	expect_false(identical(key(400L, 0.25, "none", perms), k1))
	expect_false(identical(key(500L, 0.30, "none", perms), k1))
	expect_false(identical(key(500L, 0.25, "log", perms), k1))
	expect_false(identical(key(500L, 0.25, "none", perms2), k1))
	expect_equal(strsplit(k1, "|", fixed = TRUE)[[1]][1:3], c("500", formatC(0.25, digits = 17, format = "fg", flag = "#"), "none"))
})

test_that("subset_permutations selects columns of w_mat/m_mat or elements of a permutation list", {
	f <- rand_priv()
	sp <- f$priv$subset_permutations
	expect_null(sp(NULL, 1:2))
	w <- matrix(1:12, nrow = 3); m <- matrix(101:112, nrow = 3)
	out <- sp(list(w_mat = w, m_mat = m), c(2, 4))
	expect_equal(out$w_mat, w[, c(2, 4)])
	expect_equal(out$m_mat, m[, c(2, 4)])
	expect_null(sp(list(w_mat = w), 1)$m_mat)
	expect_equal(dim(sp(list(w_mat = w), 3)$w_mat), c(3L, 1L))
	lst <- list(list(w = 1), list(w = 2), list(w = 3))
	expect_equal(sp(lst, c(1, 3)), lst[c(1, 3)])
})

test_that("get_randomization_distribution_prefix fills the cache in batches and never recomputes cached draws", {
	f <- rand_priv()
	calls <- list()
	unlockBinding("approximate_randomization_distribution_beta_hat_T", f$inf)
	f$inf$approximate_randomization_distribution_beta_hat_T <- function(r, delta, transform_responses, show_progress, permutations, zero_one_logit_clamp, ...) {
		calls[[length(calls) + 1L]] <<- list(r = r, perm = permutations)
		start <- 1000 * length(calls)
		start + seq_len(r)
	}
	perms <- list(w_mat = matrix(0L, nrow = 20, ncol = 50), m_mat = NULL)
	get_prefix <- function(r, batch_size = NULL, key = "k") {
		f$priv$get_randomization_distribution_prefix(r = r, delta = 0, transform_responses = "none",
			show_progress = FALSE, permutations = perms, cache_key = key, batch_size = batch_size)
	}

	p1 <- get_prefix(50, batch_size = 10)
	expect_equal(p1, 1000 + 1:10)
	expect_equal(calls[[1]]$r, 10L)
	expect_equal(ncol(calls[[1]]$perm$w_mat), 10L)

	p2 <- get_prefix(50, batch_size = 10)
	expect_equal(length(p2), 20L)
	expect_equal(p2[1:10], p1)
	expect_equal(p2[11:20], 2000 + 1:10)

	# Asking for fewer than already cached returns a prefix without computing.
	n_calls <- length(calls)
	p3 <- get_prefix(15)
	expect_equal(p3, p2[1:15])
	expect_length(calls, n_calls)

	# No batch size: fill straight to r.
	p4 <- get_prefix(50)
	expect_length(p4, 50L)
	expect_equal(calls[[length(calls)]]$r, 30L)

	# A different key has its own cache; a NULL key never caches.
	expect_length(get_prefix(5, key = "other"), 5L)
	n_calls <- length(calls)
	get_prefix(5, key = NULL); get_prefix(5, key = NULL)
	expect_length(calls, n_calls + 2L)
})

test_that("an all-non-finite cached distribution is discarded and recomputed", {
	f <- rand_priv()
	n_calls <- 0L
	unlockBinding("approximate_randomization_distribution_beta_hat_T", f$inf)
	f$inf$approximate_randomization_distribution_beta_hat_T <- function(r, ...) { n_calls <<- n_calls + 1L; rep(0.5, r) }
	f$priv$ensure_resampling_distribution_cache("rand")
	f$priv$set_cached_resampling_distribution("rand", "bad", c(NA_real_, NaN, Inf))
	out <- f$priv$get_randomization_distribution_prefix(r = 4, delta = 0, transform_responses = "none",
		show_progress = FALSE, permutations = list(w_mat = matrix(0L, 20, 4)), cache_key = "bad")
	expect_equal(out, rep(0.5, 4))
	expect_equal(n_calls, 1L)
})

test_that("the worker-reuse session counter clears the cached worker only at the outermost boundary", {
	f <- rand_priv()
	cv <- function() f$priv$cached_values
	f$priv$cached_values$reusable_rand_worker <- "stale"
	f$priv$begin_rand_worker_reuse_session()
	expect_null(cv()$reusable_rand_worker)
	expect_equal(cv()$rand_worker_reuse_depth, 1L)

	f$priv$cached_values$reusable_rand_worker <- "live"
	f$priv$begin_rand_worker_reuse_session()           # nested: must not clear
	expect_equal(cv()$rand_worker_reuse_depth, 2L)
	expect_equal(cv()$reusable_rand_worker, "live")
	f$priv$end_rand_worker_reuse_session()             # inner exit: must not clear
	expect_equal(cv()$rand_worker_reuse_depth, 1L)
	expect_equal(cv()$reusable_rand_worker, "live")
	f$priv$end_rand_worker_reuse_session()             # outermost exit clears
	expect_equal(cv()$rand_worker_reuse_depth, 0L)
	expect_null(cv()$reusable_rand_worker)
	f$priv$end_rand_worker_reuse_session()             # over-ending stays at zero
	expect_equal(cv()$rand_worker_reuse_depth, 0L)
})

test_that("design-family predicates follow the design", {
	f <- rand_priv()
	expect_true(f$priv$is_bernoulli_design())
	expect_false(f$priv$should_use_design_randomization_for_incidence())
})
