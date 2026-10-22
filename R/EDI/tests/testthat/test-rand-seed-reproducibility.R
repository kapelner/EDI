# TODO-112: randomization p-values/CIs must follow the design seed and
# Inference$set_seed(), and the design-level permutation cache must be keyed
# on the effective seed.

rand_seed_fixture = function(design_seed, n = 30L) {
	set.seed(42)
	X = data.frame(x1 = rnorm(n))
	y = rnorm(n) + 0.3
	d = DesignFixediBCRD$new(response_type = "continuous", n = n, seed = design_seed, verbose = FALSE)
	d$add_all_subjects_to_experiment(X)
	d$assign_w_to_all_subjects()
	d$add_all_subject_responses(y + 0.5 * d$get_w())
	d
}
rand_p = function(inf) inf$compute_rand_two_sided_pval(r = 151, show_progress = FALSE)

test_that("rand p-value follows the design seed regardless of the global RNG state", {
	d1 = rand_seed_fixture(7L); set.seed(1); runif(3)
	p1 = rand_p(InferenceContinOLS$new(d1))
	d2 = rand_seed_fixture(7L); set.seed(999); runif(11)
	p2 = rand_p(InferenceContinOLS$new(d2))
	expect_identical(p1, p2)
})

test_that("set_seed() overrides the design seed and makes rand p/CI reproducible", {
	run = function(noise) {
		d = rand_seed_fixture(7L); set.seed(noise)
		inf = InferenceContinOLS$new(d); inf$set_seed(3L)
		list(p = rand_p(inf), ci = inf$compute_rand_confidence_interval(r = 101, show_progress = FALSE))
	}
	a = run(1); b = run(2)
	expect_identical(a$p, b$p)
	expect_identical(a$ci, b$ci)
})

test_that("the design permutation cache is keyed on the effective seed", {
	d = rand_seed_fixture(NULL)
	mk = function(s) { i = InferenceContinOLS$new(d); i$set_seed(s); rand_p(i) }
	p_a = mk(1L); p_b = mk(2L); p_c = mk(3L)
	expect_gt(length(unique(c(p_a, p_b, p_c))), 1L)
	expect_identical(mk(1L), p_a)   # same seed -> same (cached) draws
	keys = names(d$.__enclos_env__$private$permutations_cache)
	expect_gte(length(keys), 3L)
})

test_that("global RNG stream is restored by seeded permutation draws and clear_randomization_cache works", {
	d = rand_seed_fixture(5L)
	inf = InferenceContinOLS$new(d)
	set.seed(123); expected = runif(1)
	set.seed(123); rand_p(inf)
	expect_identical(runif(1), expected)
	expect_gt(length(d$.__enclos_env__$private$permutations_cache), 0L)
	inf$clear_randomization_cache()
	expect_length(d$.__enclos_env__$private$permutations_cache, 0L)
})
