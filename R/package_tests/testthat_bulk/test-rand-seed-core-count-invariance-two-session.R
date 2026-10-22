# TODO-112 (release_v1_0_5.md): seeded randomization draws, p-values and CIs
# must not depend on the core count. Each core count runs in its own fresh R
# process (callr), so no RNG state, permutation cache, fork cluster or OpenMP
# thread pool can leak from one run into the other. The child sets the core
# count BEFORE constructing designs/inference objects (both capture
# get_num_cores() at construction).
#
# Set EDI_TODO112_LOAD_ALL=<path to R/EDI> to have the children overlay the
# current R sources on the installed build via
# pkgload::load_all(<path>, compile = FALSE) (never compiles).

todo112_child = function(cores, load_all_path) {
	suppressPackageStartupMessages(library(EDI))
	if (nzchar(load_all_path)) {
		pkgload::load_all(load_all_path, compile = FALSE, quiet = TRUE, export_all = FALSE)
	}
	set_num_cores(cores)
	on.exit(unset_num_cores(), add = TRUE)

	n = 24L
	set.seed(20261022)
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	y0 = rnorm(n)

	make_design = function(cls, seed, extra = list()) {
		d = do.call(cls$new, c(list(response_type = "continuous", n = n, seed = seed, verbose = FALSE), extra))
		d$add_all_subjects_to_experiment(X)
		d$assign_w_to_all_subjects()
		d$add_all_subject_responses(y0 + 0.4 * d$get_w())
		d
	}
	# Perturb the caller's global RNG so only the seeds can make runs agree.
	set.seed(1000L + cores); invisible(runif(7L * cores))

	out = list(get_num_cores = EDI:::get_num_cores())

	# (1) rand p-value seeded only by the design seed
	d_ib = make_design(DesignFixediBCRD, 7L)
	inf_ds = InferenceContinOLS$new(d_ib)
	out$inference_num_cores = inf_ds$num_cores
	out$p_design_seed = inf_ds$compute_rand_two_sided_pval(r = 101L, show_progress = FALSE)

	# (2) rand p-value + CI seeded by Inference$set_seed() (overrides design seed)
	inf_ss = InferenceContinOLS$new(make_design(DesignFixediBCRD, 7L))
	inf_ss$set_seed(3L)
	out$p_set_seed = inf_ss$compute_rand_two_sided_pval(r = 101L, show_progress = FALSE)
	out$ci_set_seed = inf_ss$compute_rand_confidence_interval(r = 51L, show_progress = FALSE)

	# (3) draw_ws_according_to_design() on seeded designs, including the
	# OpenMP-kernel designs from TODO-95 (draw-index seeding)
	draw = function(cls, extra = list()) {
		d = do.call(cls$new, c(list(response_type = "continuous", n = n, seed = 42L, verbose = FALSE), extra))
		d$add_all_subjects_to_experiment(X)
		d$draw_ws_according_to_design(16L)
	}
	out$draws = list(
		iBCRD             = draw(DesignFixediBCRD),
		Greedy            = draw(DesignFixedGreedy),
		BinaryMatch       = draw(DesignFixedBinaryMatch),
		Rerandomization   = draw(DesignFixedRerandomization, list(obj_val_cutoff = 0.1))
	)

	# (4) rand p-value on a seeded OpenMP-kernel design (permutations drawn by
	# the native kernel under the effective seed)
	inf_gr = InferenceContinOLS$new(make_design(DesignFixedGreedy, 11L))
	out$p_greedy_design_seed = inf_gr$compute_rand_two_sided_pval(r = 101L, show_progress = FALSE)

	# (5) R-worker path: InferenceCountPoisson has no fast C++ randomization
	# kernel, so its null statistics go through par_lapply() and, in the 2-core
	# session, the fork cluster. par_lapply is wrapped only to record the core
	# count it was handed, proving the parallel path really ran.
	yc = rpois(n, 3)
	make_count_inf = function(inf_seed) {
		d = DesignFixediBCRD$new(response_type = "count", n = n, seed = 7L, verbose = FALSE)
		d$add_all_subjects_to_experiment(X)
		d$assign_w_to_all_subjects()
		d$add_all_subject_responses(yc + d$get_w())
		inf = InferenceCountPoisson$new(d)
		if (!is.null(inf_seed)) inf$set_seed(inf_seed)
		inf
	}
	par_cores_seen = integer(0)
	instrument = function(inf) {
		pe = inf$.__enclos_env__$private
		orig = pe$par_lapply
		unlockBinding("par_lapply", pe)
		pe$par_lapply = function(X, FUN, ...) {
			nc = list(...)$n_cores
			par_cores_seen <<- c(par_cores_seen, if (is.null(nc)) NA_integer_ else as.integer(nc))
			orig(X, FUN, ...)
		}
		inf
	}
	out$p_worker_design_seed = instrument(make_count_inf(NULL))$compute_rand_two_sided_pval(r = 301L, show_progress = FALSE)
	out$p_worker_set_seed = instrument(make_count_inf(3L))$compute_rand_two_sided_pval(r = 301L, show_progress = FALSE)
	out$par_cores_seen = sort(unique(par_cores_seen))

	# (6) sequential-MC deferred path: draws are made batch by batch from the
	# global RNG seeded with the effective seed, not by generate_permutations().
	inf_smc = make_count_inf(3L)
	inf_smc$.__enclos_env__$private$randomization_mc_control = list(
		mc_enable = TRUE, mc_stop_threshold = 0.05, mc_batch_size = 50L,
		mc_min_draws = 100L, mc_conf_level = 0.99
	)
	out$p_worker_seq_mc = inf_smc$compute_rand_two_sided_pval(r = 301L, show_progress = FALSE)
	out
}

test_that("seeded rand draws, p-values and CIs are identical in separate 1-core and 2-core R sessions", {
	skip_on_cran()
	skip_if_not_installed("callr")
	skip_if_prepush_no_parallel()
	if (parallel::detectCores(logical = TRUE) < 2L) skip("fewer than 2 logical cores available")
	load_all_path = Sys.getenv("EDI_TODO112_LOAD_ALL", "")
	if (nzchar(load_all_path)) skip_if_not_installed("pkgload")

	run = function(cores) callr::r(
		todo112_child,
		args = list(cores = cores, load_all_path = load_all_path),
		env = c(callr::rcmd_safe_env(), NOT_CRAN = "true", EDI_UNITY = "0"),
		timeout = 600
	)
	r1 = run(1L)
	r2 = run(2L)

	# The 2-core session really ran with 2 cores.
	expect_identical(r1$get_num_cores, 1L)
	expect_identical(r2$get_num_cores, 2L)
	expect_identical(as.integer(r2$inference_num_cores), 2L)

	expect_true(is.finite(r1$p_design_seed))
	expect_identical(r1$p_design_seed, r2$p_design_seed)
	expect_identical(r1$p_set_seed, r2$p_set_seed)
	expect_identical(r1$ci_set_seed, r2$ci_set_seed)
	expect_identical(r1$p_greedy_design_seed, r2$p_greedy_design_seed)
	# R-worker path: really dispatched to 2 cores in the 2-core session.
	expect_true(2L %in% r2$par_cores_seen)
	expect_true(is.finite(r1$p_worker_design_seed))
	expect_identical(r1$p_worker_design_seed, r2$p_worker_design_seed)
	expect_identical(r1$p_worker_set_seed, r2$p_worker_set_seed)
	expect_identical(r1$p_worker_seq_mc, r2$p_worker_seq_mc)
	for (nm in names(r1$draws)) {
		expect_identical(r1$draws[[nm]], r2$draws[[nm]], info = nm)
	}
})
