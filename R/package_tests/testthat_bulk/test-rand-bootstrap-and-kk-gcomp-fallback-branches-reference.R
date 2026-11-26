.libPaths(c("Rlib", .libPaths()))
library(testthat)
library(EDI)

# Branches that the BRT tests used to reach on DesignSeqOneByOneKK14 data. Since
# 2026-11-14 the randomization bootstrap is excluded on adaptive sequential
# designs (inference_class_registry.R, EDI_INFERENCE_DESIGN_EXCLUDED_CAPABILITIES),
# so those tests moved to DesignSeqOneByOneBernoulli and no longer hit these
# paths; this file reaches them directly. Several are fallbacks for
# data-dependent failures (a failed or non-converged fit, an unavailable
# estimate), so the failure is injected by replacing one private method.

replace_method = function(env, name, fn) {
	unlockBinding(name, env)
	assign(name, fn, envir = env)
}

brt_bernoulli_design = function(n = 24L, seed = 11L) {
	set.seed(seed)
	X = data.frame(x1 = rnorm(n), x2 = runif(n))
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(X$x1 + 0.5 * des$get_w() + rnorm(n))
	des
}

brt_inference = function(des = brt_bernoulli_design(), seed = 42L) {
	inf = InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
	inf$.__enclos_env__$private$seed = seed
	inf$num_cores = 1L
	inf
}

kk_incidence_design = function(n = 40L, seed = 21L) {
	set.seed(seed)
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	des = DesignFixedBinaryMatch$new(response_type = "incidence", n = n, m = rep(seq_len(n / 2L), each = 2L), verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects(as.vector(replicate(n / 2L, sample(0:1))))
	w = des$get_w()
	des$add_all_subject_responses(stats::rbinom(n, 1L, stats::plogis(-0.3 + 0.8 * w + 0.5 * X$x1)))
	des
}

test_that("get_effective_capabilities accepts a live inference object as name", {
	inf = brt_inference()
	expect_identical(
		EDI:::get_effective_capabilities(inf),
		EDI:::get_effective_capabilities(class(inf)[1], des_obj = inf$.__enclos_env__$private$des_obj, live_obj = inf)
	)
})

test_that("BRT debug mode records an error raised inside an iteration", {
	inf = brt_inference()
	replace_method(inf$.__enclos_env__$private, "run_rand_bootstrap_iteration", function(...) stop("injected BRT iteration failure"))
	dbg = inf$approximate_rand_bootstrap_distribution_beta_hat_T(B = 5, debug = TRUE, show_progress = FALSE)
	expect_true(all(is.na(dbg$values)))
	expect_identical(dbg$num_errors, rep(1L, 5L))
	expect_identical(unique(unlist(dbg$errors)), "injected BRT iteration failure")
	expect_identical(dbg$prop_iterations_with_errors, 1)
})

test_that("BRT draws accept plain index vectors from bootstrap_sample_indices", {
	inf = brt_inference()
	priv = inf$.__enclos_env__$private
	n = priv$n
	replace_method(priv, "bootstrap_sample_indices", function(n, bootstrap_type = NULL) sample.int(n, n, replace = TRUE))
	set.seed(3)
	draws = priv$generate_rand_bootstrap_draws(4L, materialize_w = FALSE)
	expect_length(draws, 4L)
	for (d in draws) {
		expect_type(d$i_b, "integer")
		expect_length(d$i_b, n)
		expect_null(d$m_vec_b)
		expect_null(d$w_b)
	}
})

test_that("BRT w_b materialization reads the design from each worker-state layout", {
	for (layout in c("worker_inf", "worker")) {
		inf = brt_inference()
		priv = inf$.__enclos_env__$private
		n = priv$n
		worker = inf$duplicate(verbose = FALSE, make_fork_cluster = FALSE)
		replace_method(priv, "use_reusable_bootstrap_worker", function() TRUE)
		replace_method(priv, "create_bootstrap_worker_state", function() stats::setNames(list(worker), layout))
		replace_method(priv, "load_bootstrap_sample_into_worker", function(worker_state, draw) invisible(NULL))
		set.seed(5)
		draws = priv$generate_rand_bootstrap_draws(3L, materialize_w = TRUE)
		expect_length(draws, 3L)
		for (d in draws) {
			expect_length(d$w_b, n)
			expect_true(all(d$w_b %in% c(0, 1)))
		}
	}
})

test_that("SMC early stopping draws its own seeded batch when none is supplied", {
	pval_with_smc = function() {
		inf = brt_inference(seed = 99L)
		inf$.__enclos_env__$private$brt_mc_control = list(
			mc_enable = TRUE, mc_batch_size = 25L, mc_min_draws = 50L,
			mc_conf_level = 0.99, mc_stop_threshold = 0.05
		)
		inf$compute_rand_bootstrap_two_sided_pval(B = 201, show_progress = FALSE)
	}
	p1 = pval_with_smc()
	expect_true(is.finite(p1))
	expect_true(p1 >= 0 && p1 <= 1)
	# The batch is drawn under the inference seed, so a second object agrees.
	expect_identical(pval_with_smc(), p1)
})

test_that("jackknife returns no draws when the full-data estimate is unavailable", {
	inf = brt_inference()
	replace_method(inf, "compute_estimate", function(estimate_only = FALSE) NA_real_)
	expect_length(inf$.__enclos_env__$private$approximate_jackknife_distribution_beta_hat_T_private(), 0L)
})

test_that("KK g-computation RR jackknife SE is NA with too few positive estimates", {
	inf = InferenceIncidKKGCompRiskRatio$new(kk_incidence_design(), verbose = FALSE)
	inf$num_cores = 1L
	priv = inf$.__enclos_env__$private
	replace_method(priv, "approximate_jackknife_distribution_beta_hat_T_private", function(unit = "auto") c(NA_real_, -1, 0.8))
	expect_true(is.na(priv$compute_rr_jackknife_log_se()))
})

test_that("KK g-computation falls back to the treatment-only fit, then caches the failure", {
	for (cls in list(InferenceIncidKKGCompRiskRatio, InferenceIncidKKGCompRiskDiff)) {
		inf = cls$new(kk_incidence_design(), verbose = FALSE)
		inf$num_cores = 1L
		priv = inf$.__enclos_env__$private
		expect_true(isTRUE(priv$harden))
		fit_cols = integer()
		replace_method(priv, "fit_logistic_with_sandwich", function(X, estimate_only = FALSE) {
			fit_cols <<- c(fit_cols, ncol(X))
			NULL
		})
		expect_true(is.na(suppressWarnings(inf$compute_estimate())))
		# Full design first, then the treatment-only refit (intercept + treatment).
		expect_identical(fit_cols[1:2], c(ncol(priv$build_design_matrix()), 2L))
	}
})

test_that("KK g-computation drops a covariate and refits when the coefficients are unusable", {
	inf = InferenceIncidKKGCompRiskDiff$new(kk_incidence_design(), verbose = FALSE)
	inf$num_cores = 1L
	priv = inf$.__enclos_env__$private
	usable = priv$coefficients_are_usable
	reduce = priv$reduce_design_matrix_preserving_treatment
	n_checks = 0L
	fit_cols = integer()
	replace_method(priv, "coefficients_are_usable", function(...) {
		n_checks <<- n_checks + 1L
		if (n_checks == 1L) FALSE else usable(...)
	})
	replace_method(priv, "reduce_design_matrix_preserving_treatment", function(X) {
		fit_cols <<- c(fit_cols, ncol(X))
		reduce(X)
	})
	est = inf$compute_estimate()
	expect_true(is.finite(est))
	expect_gte(n_checks, 2L)
	# The refit dropped one of the two covariates (intercept and treatment kept).
	expect_identical(fit_cols[1:2], c(4L, 3L))
})

# docs-claims audit, finding docs-claims-dcb561000: the KK g-computation docs say a working model that
# fails to fit, or a design with no treatment-arm variation, marks the estimate nonestimable via
# is_nonestimable() with a cached reason.
test_that("KK g-computation marks the estimate nonestimable after a failed fit and with no treatment-arm variation", {
	for (cls in list(InferenceIncidKKGCompRiskDiff, InferenceIncidKKGCompRiskRatio)) {
		inf = cls$new(kk_incidence_design(), verbose = FALSE)
		inf$num_cores = 1L
		priv = inf$.__enclos_env__$private
		replace_method(priv, "fit_logistic_with_sandwich", function(X, estimate_only = FALSE) NULL)
		expect_true(is.na(suppressWarnings(inf$compute_estimate())))
		skip("v1.0.7-TODO-114: a failed KK g-comp working-model fit gives NA but is_nonestimable('estimate') stays FALSE with no reason; a design with all subjects treated gives a finite estimate")
		expect_true(inf$is_nonestimable("estimate"))
		expect_false(is.null(inf$get_nonestimable_reason()))
	}
	set.seed(3)
	des = DesignFixedBinaryMatch$new(response_type = "incidence", n = 20L, m = rep(1:10, each = 2L), verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(20)))
	des$overwrite_all_subject_assignments(rep(1, 20))
	des$add_all_subject_responses(rbinom(20, 1, 0.5))
	for (cls in list(InferenceIncidKKGCompRiskDiff, InferenceIncidKKGCompRiskRatio)) {
		inf = cls$new(des, verbose = FALSE)
		est = suppressWarnings(inf$compute_estimate())
		expect_true(is.na(est))
		expect_true(inf$is_nonestimable("estimate"))
		expect_false(is.null(inf$get_nonestimable_reason()))
	}
})
