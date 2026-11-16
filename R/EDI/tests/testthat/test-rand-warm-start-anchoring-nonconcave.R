# Randomization replicates chain warm starts (each permutation's fit starts from
# the previous one's) only for classes whose registry `likelihood_concave` is
# TRUE. A nonconcave likelihood restarts every permutation from the full-data
# MLE, so its randomization distribution cannot depend on permutation order. With
# chaining, zero-inflated Poisson replicates drifted into another optimum and
# moved by up to 0.44 when the same permutations were run in reverse.

rand_anchor_zip_design = function(seed = 3L, n = 80L) {
	set.seed(seed)
	x1 = rnorm(n); x2 = rnorm(n); w = rep(c(1, 0), length.out = n)
	y = ifelse(rbinom(n, 1L, plogis(-0.8 + 0.3 * w - 0.3 * x1)) == 1L, 0L,
		rpois(n, exp(0.3 + 0.2 * w + 0.2 * x1 - 0.1 * x2)))
	des = DesignFixedBernoulli$new(n = n, response_type = "count", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = x1, x2 = x2))
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(y)
	des
}

test_that("chaining is gated on the registry's likelihood_concave", {
	des = rand_anchor_zip_design()
	zip = InferenceCountZeroInflatedPoisson$new(des, model_formula = ~ x1 + x2, verbose = FALSE)
	hurdle = InferenceCountHurdlePoisson$new(des, model_formula = ~ x1 + x2, verbose = FALSE)
	expect_true(zip$.__enclos_env__$private$rand_likelihood_is_nonconcave())
	expect_false(hurdle$.__enclos_env__$private$rand_likelihood_is_nonconcave())
})

test_that("nonconcave randomization distribution does not depend on permutation order", {
	skip_on_cran()
	des = rand_anchor_zip_design()
	inf = InferenceCountZeroInflatedPoisson$new(des, model_formula = ~ x1 + x2, verbose = FALSE)
	inf$num_cores = 1L
	inf$set_seed(11L)
	inf$compute_estimate()
	pv = inf$.__enclos_env__$private
	r = 30L
	perms = pv$generate_permutations(r)
	perms_rev = perms
	perms_rev$w_mat = perms$w_mat[, r:1L, drop = FALSE]
	if (!is.null(perms$m_mat)) perms_rev$m_mat = perms$m_mat[, r:1L, drop = FALSE]
	fwd = inf$approximate_randomization_distribution_beta_hat_T(r = r, permutations = perms, show_progress = FALSE)
	bwd = inf$approximate_randomization_distribution_beta_hat_T(r = r, permutations = perms_rev, show_progress = FALSE)
	expect_identical(fwd, rev(bwd))
})
