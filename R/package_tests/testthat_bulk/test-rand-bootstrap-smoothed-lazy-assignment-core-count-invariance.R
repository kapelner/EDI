# Thread and random-number review audit, 2026-11-17: compute_rand_bootstrap_two_sided_pval(type =
# "smoothed") builds its draws with materialize_w = FALSE, so no per-draw w_seed is recorded. The
# fresh assignment for each bootstrap draw is then drawn lazily inside the worker loop
# (des_obj$draw_ws_according_to_design) from whatever R RNG stream the executing process holds. With
# 1 core that is the parent's stream, seeded once by set.seed(private$seed). With 2 or more cores
# each fork or mirai worker has its own stream (clusterSetRNGStream / seed + chunk id). The
# assignments, the null distribution and the seeded p-value therefore change with set_num_cores()
# whenever the design itself is unseeded. The same lazy draw is taken on the default percentile path
# for classes whose supports_reusable_bootstrap_worker() is FALSE and that have no fast kernel (line
# 279 materializes only when has_fast_kernel || supports_reusable_bootstrap_worker()). Those draws go
# through par_lapply at line 378.
# Where: R/EDI/R/inference_all_abstract_rand_bootstrap.R:579 (kind: core_count_dependence).
# On commit 4fc58cd063bc this test failed with: Expected `r1$t0` to be identical to `r2$t0`.
# Differences: 120/120 mismatches (average diff: 0.181) [1] 0.3594 - -0.15705 == 0.5165 [2] 0.0355 -
# 0.12276 == -0.0873 [3] 0.0208 - -0.06887 == 0.0896 [4] 0.0426 - -0.02693 == 0.0696 [5] -0.1281 -
# -0.16200 == 0.0339 [6] 0.1538 - -0.00920 == 0.16
# Remove the skip() once a release TODO covers this finding, and cite that TODO here
# (v<version>-TODO-<n>).

test_that("seeded smoothed bootstrap-randomization p-value and lazily drawn assignments are identical with 1 and 2 cores", {
	skip("open a release TODO for this")
		child = function(cores) {
			suppressPackageStartupMessages(library(EDI))
			set_num_cores(cores)
			on.exit(unset_num_cores(), add = TRUE)
			n = 40L
			set.seed(20261117)
			X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
			yc = rpois(n, 4)
			d = DesignFixediBCRD$new(response_type = "count", n = n, verbose = FALSE)
			d$add_all_subjects_to_experiment(X)
			d$assign_w_to_all_subjects()
			d$add_all_subject_responses(yc + d$get_w())
			inf = InferenceCountPoisson$new(d)
			inf$set_seed(3L)
			set.seed(1000L + cores)
			invisible(runif(7L * cores))
			p = inf$compute_rand_bootstrap_two_sided_pval(B = 199L, show_progress = FALSE, type = "smoothed")
			priv = inf$.__enclos_env__$private
			set.seed(11L)
			draws = priv$generate_rand_bootstrap_draws(120L, materialize_w = FALSE)
			t0 = inf$approximate_rand_bootstrap_distribution_beta_hat_T(B = 120L, show_progress = FALSE, rand_bootstrap_draws = draws)
			list(inf_cores = as.integer(inf$num_cores), p = p, t0 = as.numeric(t0))
		}
		run = function(cores) callr::r(
			child,
			args = list(cores = cores),
			env = c(callr::rcmd_safe_env(), NOT_CRAN = "true"),
			timeout = 280
		)
		r1 = run(1L)
		r2 = run(2L)
		expect_identical(r2$inf_cores, 2L)
		expect_true(is.finite(r1$p))
		expect_identical(r1$t0, r2$t0)
		expect_identical(r1$p, r2$p)
})
