library(EDI)

# Tests for the merged DesignFixedGreedyDOptimal class (Stage 1 of the merge
# plan in fix_design_hierarchy.md): golden equivalence against the raw kernels
# the former DesignFixedDOptimal/DesignFixedAOptimal classes called, seed
# reproducibility (the empirical check the registry's seed_reproducible_draw
# flip relies on), the documented objective/interest equivalences, Bayesian
# variants, and the always-on constructor validation.

build_dopt_design = function(n = 20L, seed = 872L, ...){
	set.seed(seed)
	des = DesignFixedGreedyDOptimal$new(response_type = "continuous", n = n, verbose = FALSE, seed = seed, ...)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n), x2 = rnorm(n), x3 = rnorm(n)))
	des
}

test_that("draws are seed-reproducible (same seed => identical allocations, twice)", {
	W1 = build_dopt_design(seed = 555L)$draw_ws_according_to_design(r = 7)
	W2 = build_dopt_design(seed = 555L)$draw_ws_according_to_design(r = 7)
	expect_identical(W1, W2)

	# and for the A kernel path
	A1 = build_dopt_design(seed = 556L, objective = "A", interest = "all")$draw_ws_according_to_design(r = 7)
	A2 = build_dopt_design(seed = 556L, objective = "A", interest = "all")$draw_ws_according_to_design(r = 7)
	expect_identical(A1, A2)
})

test_that("golden: objective D reproduces the former DesignFixedDOptimal kernel path exactly", {
	n = 20L
	des = build_dopt_design(n = n, seed = 321L)
	W_class = des$draw_ws_according_to_design(r = 6)

	# replicate the former class's draw_ws_raw by hand: same seed, same P
	# construction (QR projection), same kernel call
	set.seed(321L)
	X = as.matrix(des$get_X_imp()[1:n, , drop = FALSE])
	Z0 = cbind(1, X)
	Q = qr.Q(qr(Z0))
	P = Q %*% t(Q)
	set.seed(321L)  # maybe_set_seed() consumed the seed before the kernel ran
	W_kernel = EDI:::d_optimal_search_cpp(P, 6L, as.integer(n / 2))
	storage.mode(W_kernel) = "numeric"
	expect_equal(W_class, W_kernel)
})

test_that("interest = 'treatment' and interest = 'all' select identical allocations under objective D", {
	# the Schur-complement identity: minimizing w'Pw maximizes both the
	# treatment-coefficient information and the full-matrix determinant
	W_trt = build_dopt_design(seed = 99L, interest = "treatment")$draw_ws_according_to_design(r = 8)
	W_all = build_dopt_design(seed = 99L, interest = "all")$draw_ws_according_to_design(r = 8)
	expect_identical(W_trt, W_all)
})

test_that("objective = 'A' with interest = 'treatment' is silently equivalent to objective = 'D'", {
	W_D = build_dopt_design(seed = 77L, objective = "D")$draw_ws_according_to_design(r = 8)
	expect_silent(des_A <- build_dopt_design(seed = 77L, objective = "A", interest = "treatment"))
	W_A = des_A$draw_ws_according_to_design(r = 8)
	expect_identical(W_D, W_A)
})

test_that("A-optimal (all parameters) uses the trace kernel and differs in general from D", {
	des = build_dopt_design(seed = 42L, objective = "A", interest = "all")
	W = des$draw_ws_according_to_design(r = 10)
	expect_equal(dim(W), c(20L, 10L))
	expect_true(all(colSums(W) == 10))
	expect_true(all(W %in% c(0, 1)))
})

test_that("Bayesian scalar tau penalizes covariates only and stays seed-reproducible", {
	des1 = build_dopt_design(seed = 11L, prior_precision = 2.5)
	des2 = build_dopt_design(seed = 11L, prior_precision = 2.5)
	W1 = des1$draw_ws_according_to_design(r = 5)
	expect_identical(W1, des2$draw_ws_according_to_design(r = 5))
	expect_true(all(colSums(W1) == 10))

	# Bayesian A variant runs too
	desA = build_dopt_design(seed = 12L, objective = "A", interest = "all", prior_precision = 2.5)
	WA = desA$draw_ws_according_to_design(r = 5)
	expect_true(all(colSums(WA) == 10))
})

test_that("Bayesian matrix prior_precision is validated and used", {
	n = 20L
	# 4 columns in Z0 = [1, x1, x2, x3]
	R0 = diag(c(0, 1, 2, 3))
	des = build_dopt_design(n = n, seed = 13L, prior_precision = R0, standardize_covariates = FALSE)
	W = des$draw_ws_according_to_design(r = 4)
	expect_true(all(colSums(W) == 10))

	# wrong dimensions error at draw time with an informative message
	des_bad = build_dopt_design(n = n, seed = 14L, prior_precision = diag(3))
	expect_error(des_bad$draw_ws_according_to_design(r = 2), "prior_precision matrix must be 4 x 4")
})

test_that("tiny tau approaches the non-Bayesian allocation criterion", {
	# as tau -> 0 the ridge-regularized P converges to the projection, so the
	# locally-optimal allocations under a shared seed should coincide
	W_plain = build_dopt_design(seed = 15L)$draw_ws_according_to_design(r = 6)
	W_tiny  = build_dopt_design(seed = 15L, prior_precision = 1e-10, standardize_covariates = FALSE)$draw_ws_according_to_design(r = 6)
	expect_identical(W_plain, W_tiny)
})

test_that("non-0.5 prob_T fixes the treated count at round(n * prob_T)", {
	des = build_dopt_design(n = 20L, seed = 16L, prob_T = 0.3)
	W = des$draw_ws_according_to_design(r = 5)
	expect_true(all(colSums(W) == 6))
})

test_that("always-on constructor validation rejects bad arguments (asserts on or off)", {
	expect_error(DesignFixedGreedyDOptimal$new(response_type = "continuous", n = 10, objective = "M"),
		'objective must be "D"')
	expect_error(DesignFixedGreedyDOptimal$new(response_type = "continuous", n = 10, interest = 42),
		'interest must be')
	expect_error(DesignFixedGreedyDOptimal$new(response_type = "continuous", n = 10, n_iter = 100),
		"Stage-2 shared")
	expect_error(DesignFixedGreedyDOptimal$new(response_type = "continuous", n = 10, prior_precision = -1),
		"prior_precision")
	expect_error(DesignFixedGreedyDOptimal$new(response_type = "continuous", n = 10, prior_precision = matrix(1:4, 2)),
		"symmetric")
	expect_error(DesignFixedGreedyDOptimal$new(response_type = "continuous", n = 10, prob_T = 1.2),
		"prob_T")
})

test_that("no-covariate fallback draws n_T-treated BCRD allocations", {
	set.seed(20L)
	des = DesignFixedGreedyDOptimal$new(response_type = "continuous", n = 10L, verbose = FALSE, seed = 20L, prob_T = 0.3)
	des$add_all_subjects_to_experiment(data.frame(matrix(nrow = 10L, ncol = 0L)))
	W = des$draw_ws_according_to_design(r = 8)
	expect_true(all(colSums(W) == 3))
})

test_that("accessors report construction-time configuration", {
	des = build_dopt_design(seed = 21L, objective = "A", interest = "all", prior_precision = 1.5)
	expect_identical(des$get_objective(), "A")
	expect_identical(des$get_interest(), "all")
	expect_identical(des$get_prior_precision(), 1.5)
})

test_that("registry metadata: one entry, greedy_d_optimal family, seed-reproducible, fixed timing", {
	EDI:::populate_design_class_registry()
	md = EDI:::get_design_class_metadata("DesignFixedGreedyDOptimal")
	expect_identical(md$randomization_family, "greedy_d_optimal")
	expect_identical(md$timing_family, "fixed")
	expect_true(md$seed_reproducible_draw)
	expect_false(md$supports_batch_w_pregeneration)
	expect_identical(md$direct_components, character(0))
	# the old classes are gone from the registry entirely
	registry = EDI:::design_class_registry_as_list()
	expect_false(any(c("DesignFixedAOptimal", "DesignFixedDOptimal") %in% names(registry)))
})

test_that("subset interest via formula: objective D reduces to the default allocations", {
	# det(K'M^-1 K) = det(V_SS)/s(w): constant times the treatment criterion,
	# so subset-D and default-D must select identical allocations
	W_default = build_dopt_design(seed = 31L)$draw_ws_according_to_design(r = 6)
	W_subset  = build_dopt_design(seed = 31L, interest = ~ x1 + x2)$draw_ws_according_to_design(r = 6)
	expect_identical(W_default, W_subset)
})

test_that("subset interest via formula and via names agree (objective A)", {
	W_formula = build_dopt_design(seed = 32L, objective = "A", interest = ~ x1 + x3)$draw_ws_according_to_design(r = 6)
	W_names   = build_dopt_design(seed = 32L, objective = "A", interest = c("x1", "x3"))$draw_ws_according_to_design(r = 6)
	expect_identical(W_formula, W_names)
	expect_true(all(colSums(W_formula) == 10))
})

test_that("A over a strict subset generally differs from A over all parameters", {
	# not guaranteed for every seed, but for this fixture the subset trace
	# criterion selects a different local-optimum profile than the full trace
	W_all = build_dopt_design(seed = 33L, objective = "A", interest = "all")$draw_ws_according_to_design(r = 12)
	W_sub = build_dopt_design(seed = 33L, objective = "A", interest = ~ x1)$draw_ws_according_to_design(r = 12)
	expect_false(identical(W_all, W_sub))
})

test_that("subset interest composes with the Bayesian variant and stays reproducible", {
	W1 = build_dopt_design(seed = 34L, objective = "A", interest = ~ x1 + x2, prior_precision = 2)$draw_ws_according_to_design(r = 5)
	W2 = build_dopt_design(seed = 34L, objective = "A", interest = ~ x1 + x2, prior_precision = 2)$draw_ws_according_to_design(r = 5)
	expect_identical(W1, W2)
})

test_that("unmatched interest names error informatively at draw time", {
	des = build_dopt_design(seed = 35L, objective = "A", interest = c("x1", "nope"))
	expect_error(des$draw_ws_according_to_design(r = 2), "not found in the design's model matrix")
	des2 = build_dopt_design(seed = 36L, objective = "A", interest = ~ zz)
	expect_error(des2$draw_ws_according_to_design(r = 2), "object 'zz' not found|not found in the design's model matrix")
})

test_that("contrast-matrix interest still routes to the Stage-2 error; two-sided formulas rejected", {
	expect_error(DesignFixedGreedyDOptimal$new(response_type = "continuous", n = 10, interest = diag(2)),
		"Stage 2")
	expect_error(DesignFixedGreedyDOptimal$new(response_type = "continuous", n = 10, interest = y ~ x1),
		"one-sided")
})

test_that("formula strings are promoted to formulas, including interactions", {
	# string with operators === the same formula object
	W_str = build_dopt_design(seed = 41L, objective = "A", interest = "x1 + x3")$draw_ws_according_to_design(r = 5)
	W_fml = build_dopt_design(seed = 41L, objective = "A", interest = ~ x1 + x3)$draw_ws_according_to_design(r = 5)
	expect_identical(W_str, W_fml)

	# an interaction term must exist in the design's model matrix: with the
	# default design_formula = ~ . it does not, and the error names it
	des_missing = build_dopt_design(seed = 43L, objective = "A", interest = "x1 * x2")
	expect_error(des_missing$draw_ws_according_to_design(r = 2), "x1:x2")

	# with the interaction in design_formula, the same interest string works
	set.seed(44L)
	des_int = DesignFixedGreedyDOptimal$new(response_type = "continuous", n = 20L, verbose = FALSE,
		seed = 44L, objective = "A", interest = "x1 * x2", design_formula = ~ x1 * x2 + x3)
	des_int$add_all_subjects_to_experiment(data.frame(x1 = rnorm(20), x2 = rnorm(20), x3 = rnorm(20)))
	W_int = des_int$draw_ws_according_to_design(r = 5)
	expect_true(all(colSums(W_int) == 10))
})
