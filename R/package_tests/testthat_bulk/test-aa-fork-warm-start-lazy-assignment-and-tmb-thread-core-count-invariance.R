library(testthat)
library(EDI)

# v1.0.6-TODO-53, -61, -62 and -64 (thread and random-number review audit,
# 2026-11-17): four seeded results that changed with set_num_cores().
#   - TODO-53: compute_rand_bootstrap_two_sided_pval(type = "smoothed") drew
#     each replicate's fresh assignment lazily from the executing process's RNG
#     stream (a fork worker's L'Ecuyer-CMRG stream at 2 cores). Every draw now
#     carries its own w_seed and RNG kind and replays it.
#   - TODO-61: the reused-worker randomization path chained warm starts within
#     each of num_cores chunks, so each null fit's start depended on the
#     chunking. Every permutation now starts from the full-data fit.
#   - TODO-62 / TODO-64: glmmTMB fits passed glmmTMBControl(parallel =
#     num_cores), so TMB's thread-split likelihood sums changed the hurdle
#     negbin and zero-augmented Poisson coefficients. They now use one thread.
# Named test-aa-* so it runs before any test that starts mirai (a fork cluster
# cannot be started after mirai in the same session).

skip_fork_core_count_invariance = function() {
	skip_on_cran()
	skip_if_not(identical(Sys.info()[["sysname"]], "Linux"), "fork worker invariance is tested on Linux")
	skip_if(identical(Sys.getenv("R_COVR"), "true"), "avoid spawning a real fork cluster under covr")
	skip_if(isTRUE(EDI:::edi_env$mirai_has_been_used),
		"fork clusters cannot be started safely after mirai has been used in this R session")
	available = parallel::detectCores(logical = TRUE)
	skip_if(is.na(available) || available < 2L, "fewer than 2 logical cores available")
}

# Wraps the instance's par_lapply so the test fails rather than passing
# vacuously if the 2-core run never dispatches to workers.
record_par_lapply_cores = function(inf) {
	priv = inf$.__enclos_env__$private
	original = priv$par_lapply
	env = new.env()
	env$used = integer()
	unlockBinding("par_lapply", priv)
	priv$par_lapply = function(..., n_cores = 1L) {
		env$used = c(env$used, as.integer(n_cores))
		original(..., n_cores = n_cores)
	}
	lockBinding("par_lapply", priv)
	env
}

core_count_count_design = function(n, lambda, design_seed = NULL) {
	set.seed(20261117)
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	yc = rpois(n, lambda)
	d = DesignFixediBCRD$new(response_type = "count", n = n, seed = design_seed, verbose = FALSE)
	d$add_all_subjects_to_experiment(X)
	d$assign_w_to_all_subjects()
	d$add_all_subject_responses(yc + d$get_w())
	d
}

test_that("smoothed bootstrap-randomization p-value and lazily drawn assignments do not depend on the core count (v1.0.6-TODO-53)", {
	skip_fork_core_count_invariance()
	run = function(cores) {
		set_num_cores(cores)
		on.exit(unset_num_cores(), add = TRUE)
		# Unseeded design: the lazy assignment draw used to take the worker's stream.
		d = core_count_count_design(40L, 4)
		inf = InferenceCountPoisson$new(d)
		inf$set_seed(3L)
		rec = record_par_lapply_cores(inf)
		set.seed(1000L + cores)
		invisible(runif(7L * cores))
		p = inf$compute_rand_bootstrap_two_sided_pval(B = 99L, show_progress = FALSE, type = "smoothed")
		priv = inf$.__enclos_env__$private
		set.seed(11L)
		draws = priv$generate_rand_bootstrap_draws(60L, materialize_w = FALSE)
		t0 = inf$approximate_rand_bootstrap_distribution_beta_hat_T(B = 60L, show_progress = FALSE, rand_bootstrap_draws = draws)
		list(p = p, t0 = as.numeric(t0), used = rec$used)
	}
	r1 = run(1L)
	r2 = run(2L)
	expect_true(any(r2$used == 2L), info = "rand bootstrap never dispatched to 2 fork workers")
	expect_true(is.finite(r1$p))
	expect_true(all(is.finite(r1$t0)))
	expect_identical(r2$t0, r1$t0)
	expect_identical(r2$p, r1$p)
})

test_that("a lazily drawn assignment replays its seed and leaves the caller's RNG kind and stream alone (v1.0.6-TODO-53)", {
	d = core_count_count_design(20L, 3)
	draw = list(w_seed = 12345L, w_rng_kind = c("Mersenne-Twister", "Inversion", "Rejection"))
	expected = EDI:::rand_bootstrap_lazy_draw_w(d, draw)
	old_kind = RNGkind()
	on.exit(do.call(RNGkind, as.list(old_kind)), add = TRUE)
	RNGkind("L'Ecuyer-CMRG")
	set.seed(1L)
	before = get(".Random.seed", envir = globalenv())
	got = EDI:::rand_bootstrap_lazy_draw_w(d, draw)
	expect_identical(got, expected)
	expect_identical(RNGkind()[1L], "L'Ecuyer-CMRG")
	expect_identical(get(".Random.seed", envir = globalenv()), before)
})

test_that("randomization distribution of a warm-started fit does not depend on the core count (v1.0.6-TODO-61)", {
	skip_fork_core_count_invariance()
	run = function(cls, cores) {
		set_num_cores(cores)
		on.exit(unset_num_cores(), add = TRUE)
		d = core_count_count_design(40L, 3, design_seed = 7L)
		inf = get(cls, envir = asNamespace("EDI"))$new(d)
		inf$set_seed(3L)
		rec = record_par_lapply_cores(inf)
		set.seed(1000L + cores)
		invisible(runif(7L * cores))
		t0 = inf$approximate_randomization_distribution_beta_hat_T(r = 60L, show_progress = FALSE)
		list(t0 = as.numeric(t0), used = rec$used)
	}
	# Poisson differed in the last bits; HurdlePoisson by up to 3e-6 before the fix.
	for (cls in c("InferenceCountPoisson", "InferenceCountHurdlePoisson")) {
		r1 = run(cls, 1L)
		r2 = run(cls, 2L)
		expect_true(any(r2$used == 2L), info = paste(cls, "randomization never dispatched to 2 fork workers"))
		expect_identical(length(r1$t0), 60L)
		expect_identical(r2$t0, r1$t0, info = cls)
	}
})

core_count_hurdle_weighted_estimates = function(cls, cores) {
	n = 200L
	set.seed(20261117)
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	set.seed(99)
	W = lapply(1:4, function(b) { g = stats::rgamma(n, shape = 1, rate = 1); g / sum(g) * n })
	set_num_cores(cores)
	on.exit(unset_num_cores(), add = TRUE)
	d = DesignFixediBCRD$new(response_type = "count", n = n, seed = 7L, verbose = FALSE)
	d$add_all_subjects_to_experiment(X)
	d$assign_w_to_all_subjects()
	w = d$get_w()
	set.seed(123)
	zero = runif(n) < stats::plogis(-0.2 + 0.4 * w + 0.3 * X$x1)
	y = ifelse(zero, 0, 1 + stats::rnbinom(n, mu = exp(0.6 + 0.3 * w + 0.2 * X$x2), size = 2))
	d$add_all_subject_responses(y)
	inf = get(cls, envir = asNamespace("EDI"))$new(d, model_formula = ~ x1 + x2)
	inf$compute_estimate()
	priv = inf$.__enclos_env__$private
	priv$current_bayesian_bootstrap_context = priv$build_bayesian_bootstrap_context()
	est = vapply(W, function(wt) as.numeric(inf$compute_estimate_with_bootstrap_weights(wt, estimate_only = TRUE))[1L], numeric(1))
	list(nc = as.integer(inf$num_cores), est = est)
}

test_that("hurdle negbin and hurdle Poisson bootstrap-weighted glmmTMB fits do not depend on the core count (v1.0.6-TODO-62, -64)", {
	skip_on_cran()
	skip_if_not_installed("glmmTMB")
	# Before the fix the estimates differed by up to 3e-11 between 1 and 2 TMB threads.
	for (cls in c("InferenceCountHurdleNegBin", "InferenceCountHurdlePoisson")) {
		r1 = core_count_hurdle_weighted_estimates(cls, 1L)
		r2 = core_count_hurdle_weighted_estimates(cls, 2L)
		expect_identical(r1$nc, 1L)
		expect_identical(r2$nc, 2L)
		expect_true(all(is.finite(r1$est)), info = cls)
		expect_identical(r2$est, r1$est, info = cls)
	}
})
