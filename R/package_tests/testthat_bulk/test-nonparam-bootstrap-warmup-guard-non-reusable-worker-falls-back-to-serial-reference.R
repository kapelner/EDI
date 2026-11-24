# Untested-code audit, 2026-11-24: covers R/EDI/R/inference_all_abstract_non_param_boot.R:677-696
# (approximate_bootstrap_distribution_beta_hat_T; region unt-769833065f3d).
# Reference: A plain-R treated-minus-control mean difference on each recorded bootstrap row set
# (closed form). Also the documented warm-up-guard fallback to n_cores = 1, and equality with the
# num_cores = 1 result as contract section 4.3 requires.
# Verified on commit f52f53392559 under pkgload::load_all(compile = FALSE): passed; executed 16 of 16
# target lines (7.4 s).

library(testthat)
library(EDI)

test_that("bootstrap warm-up guard at num_cores = 2 times the non-reusable replicate, falls back to one core, and returns the per-draw mean differences", {
		# Gate crossed: the object's num_cores override is 2 (> 1), so the warm-up
		# guard at non_param_boot.R:676 runs. B = 4 and no fork cluster means the
		# guard keeps 2 cores only if one replicate takes over 0.3 * 2 / 4 = 0.15 s.
		# A 20-row mean difference takes a few ms, so the guard must fall back to
		# 1 core (a margin of well over 10x).
		CustomBoot = getFromNamespace("InferenceCustomBoot", "EDI")
		MeanDiffBoot = R6::R6Class(
			"AuditWarmupMeanDiffBoot",
			inherit = CustomBoot,
			lock_objects = FALSE,
			public = list(
				fit = function(estimate_only = FALSE) {
					dat = self$get_analysis_data()
					list(estimate = mean(dat$y[dat$w == 1]) - mean(dat$y[dat$w == 0]))
				}
			)
		)
		n = 20L
		B = 4L
		w = rep(c(0, 1), each = n / 2L)
		set.seed(20261124)
		y = round(rnorm(n) + w, 3)
		make_des = function() {
			des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
			des$add_all_subjects_to_experiment(data.frame(x = rep(c(4, 1, 7, 2, 9, 3, 8, 5, 10, 6), 2)))
			des$overwrite_all_subject_assignments(w)
			des$add_all_subject_responses(y)
			des
		}
		# No global fork cluster, so the guard uses the 0.3 s lazy-creation overhead.
		unset_num_cores()
		run = function(cores) {
			inf = MeanDiffBoot$new(make_des(), verbose = FALSE)
			inf$set_seed(5L)
			# A first call (cache key B = 1) installs the lazily loaded bootstrap
			# component, so the wrappers below are not replaced by the install.
			invisible(inf$approximate_bootstrap_distribution_beta_hat_T(B = 1L, show_progress = FALSE))
			priv = inf$.__enclos_env__$private
			rec = new.env()
			rec$draws = list()
			rec$cores = integer()
			orig_draw = priv$bootstrap_sample_indices
			orig_par = priv$par_lapply
			unlockBinding("bootstrap_sample_indices", priv)
			priv$bootstrap_sample_indices = function(n, bootstrap_type = NULL) {
				d = orig_draw(n, bootstrap_type)
				rec$draws[[length(rec$draws) + 1L]] = d
				d
			}
			unlockBinding("par_lapply", priv)
			priv$par_lapply = function(..., n_cores = 1L) {
				rec$cores = c(rec$cores, as.integer(n_cores))
				orig_par(..., n_cores = n_cores)
			}
			if (cores > 1L) inf$num_cores = cores
			expect_false(isTRUE(priv$use_reusable_bootstrap_worker()))
			vals = inf$approximate_bootstrap_distribution_beta_hat_T(B = B, show_progress = FALSE)
			list(vals = as.numeric(vals), draws = rec$draws, cores = rec$cores)
		}
		r1 = run(1L)
		r2 = run(2L)
		expect_length(r2$draws, B)
		# Plain-R definition: the treated-minus-control mean on each resampled row set.
		ref = vapply(r2$draws, function(d) {
			i = if (is.list(d)) as.integer(d$i_b) else as.integer(d)
			yb = y[i]
			wb = w[i]
			mean(yb[wb == 1]) - mean(yb[wb == 0])
		}, numeric(1))
		# Closed-form arithmetic on the same rows: only floating-point rounding differs.
		expect_equal(r2$vals, ref, tolerance = 1e-12)
		# The warm-up guard demoted the replicate loop to one core.
		expect_identical(r2$cores, 1L)
		# The num_cores = 2 request gives the same seeded distribution as num_cores = 1.
		expect_identical(r2$vals, r1$vals)
})
