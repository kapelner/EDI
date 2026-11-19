# v1.0.6-TODO-186: hurdle / zero-inflated count models learn the count-part
# treatment coefficient from the positive rows only. When those rows do not
# identify it (here a single positive count against a 7-column count design),
# the likelihood is flat along the treatment direction and the optimizer just
# returned its warm start: InferenceCountHurdlePoisson's randomization
# replicates all equalled the observed estimate, and a fresh run gave a
# different constant. Such a fit is now non-estimable, and on identified data
# the replicates respond to the permuted assignment.

zero_aug_identification_design = function(y, X, seed) {
	set.seed(seed)
	n = length(y)
	des = DesignFixediBCRD$new(n = n, response_type = "count")
	des$add_all_subjects_to_experiment(X)
	des$overwrite_all_subject_assignments(sample(rep(c(1, 0), n / 2)))
	des$add_all_subject_responses(y)
	des
}

test_that("count-part treatment identification is decided from the positive rows", {
	X = cbind(1, w = c(1, 0, 1, 0, 1, 0), x = c(0.1, 0.5, -0.3, 0.2, 0.9, -1))
	expect_true(zero_augmented_count_treatment_identified(X, c(1, 2, 0, 3, 2, 0)))
	# one positive row cannot identify intercept + treatment
	expect_false(zero_augmented_count_treatment_identified(X, c(0, 0, 0, 0, 2, 0)))
	# every positive row in the treated arm: treatment collinear with the intercept
	expect_false(zero_augmented_count_treatment_identified(X, c(1, 0, 2, 0, 3, 0)))
	# no positive rows
	expect_false(zero_augmented_count_treatment_identified(X, rep(0, 6)))
	# zero-weight rows do not count
	expect_false(zero_augmented_count_treatment_identified(X, c(1, 2, 0, 3, 2, 0), weights = c(1, 0, 1, 0, 1, 0)))
})

test_that("a single positive count makes every zero-augmented class non-estimable, not a warm-start constant", {
	skip_if_not_installed("MASS")
	data(birthwt, package = "MASS", envir = environment())
	set.seed(1010)
	idx = sample(nrow(birthwt), 16)
	y = birthwt$ptl[idx]
	expect_identical(sum(y > 0), 1L)
	X = birthwt[idx, c("age", "lwt", "smoke", "ht", "ui")]
	for (cls in c("InferenceCountHurdlePoisson", "InferenceCountHurdleNegBin",
				"InferenceCountZeroInflatedPoisson", "InferenceCountZeroInflatedNegBin")) {
		inf = get(cls)$new(zero_aug_identification_design(y, X, 10), verbose = FALSE)
		expect_true(is.na(suppressWarnings(inf$compute_estimate())), info = cls)
		set.seed(5)
		perms = inf$.__enclos_env__$private$generate_permutations(20)
		distr = suppressWarnings(inf$approximate_randomization_distribution_beta_hat_T(
			r = 20, permutations = perms, show_progress = FALSE))
		expect_true(all(is.na(distr)), info = cls)
	}
})

test_that("hurdle Poisson randomization replicates respond to the permuted assignment and equal fresh fits", {
	set.seed(10003)
	n = 24
	x = rnorm(n)
	y = ifelse(runif(n) < plogis(0.4 + 0.3 * x), 1 + rpois(n, exp(0.3 + 0.3 * x)), 0)
	des = zero_aug_identification_design(y, data.frame(x = x), 3)
	inf = InferenceCountHurdlePoisson$new(des, verbose = FALSE)
	est = suppressWarnings(inf$compute_estimate())
	expect_true(is.finite(est))
	set.seed(3)
	perms = inf$.__enclos_env__$private$generate_permutations(30)
	worker = suppressWarnings(inf$approximate_randomization_distribution_beta_hat_T(
		r = 30, permutations = perms, show_progress = FALSE))
	fresh = suppressWarnings(InferenceCountHurdlePoisson$new(des, verbose = FALSE)$approximate_randomization_distribution_beta_hat_T(
		r = 30, permutations = perms, show_progress = FALSE))
	# independent reference: a brand-new object fit on each permuted assignment
	slow = vapply(seq_len(30), function(b) {
		des_b = DesignFixediBCRD$new(n = n, response_type = "count")
		des_b$add_all_subjects_to_experiment(data.frame(x = x))
		des_b$overwrite_all_subject_assignments(perms$w_mat[, b])
		des_b$add_all_subject_responses(y)
		as.numeric(suppressWarnings(InferenceCountHurdlePoisson$new(des_b, verbose = FALSE)$compute_estimate(estimate_only = TRUE)))
	}, numeric(1))
	ok = is.finite(worker)
	expect_gt(sum(ok), 20L)
	expect_gt(sd(worker[ok]), 0.05)
	expect_lt(mean(abs(worker[ok] - est) < 1e-6), 0.2)
	# replicates do not depend on whether the observed fit ran first
	expect_equal(worker, fresh, tolerance = 1e-5)
	expect_equal(worker, slow, tolerance = 1e-5)
})
