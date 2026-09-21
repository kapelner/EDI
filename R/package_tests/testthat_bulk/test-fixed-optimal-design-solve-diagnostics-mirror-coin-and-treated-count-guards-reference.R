library(testthat)
library(EDI)

# DesignFixedOptimal end-to-end solve (annealing, mahal_dist objective, n = 10): treated count equals round(n * prob_T), the diagnostics
# record the solve, the mirror coin flips w -> 1 - w only among tied optima (objective invariant), construction getters echo settings,
# results are reproducible under the seed, and impossible treated counts are rejected. Objective symmetry is checked by brute force over
# all 252 allocations of the same quadratic-free statistic (Mahalanobis distance between treated and control covariate means).

set.seed(2); n <- 10L
X <- data.frame(x1 = rnorm(n), x2 = rnorm(n))
mk <- function(mirror = TRUE, seed = 1L, prob_T = 0.5, solver = "annealing") {
	d <- DesignFixedOptimal$new(response_type = "continuous", n = n, objective = "mahal_dist", solver = solver, mirror_coin = mirror,
		prob_T = prob_T, seed = seed, verbose = FALSE)
	d$add_all_subjects_to_experiment(X)
	d
}

test_that("getters echo the construction settings", {
	d <- mk(mirror = FALSE)
	expect_identical(d$get_objective(), "mahal_dist"); expect_identical(d$get_solver(), "annealing"); expect_false(d$get_mirror_coin())
	expect_null(d$get_optimization_diagnostics())                                       # nothing solved yet
})

test_that("the solved allocation has exactly n_T treated subjects and the diagnostics describe the solve", {
	d <- mk(); d$assign_w_to_all_subjects(); w <- d$get_w()
	expect_true(all(w %in% c(0, 1))); expect_equal(sum(w), 5)
	dg <- d$get_optimization_diagnostics()
	expect_identical(dg$objective, "mahal_dist"); expect_identical(dg$solver, "annealing"); expect_identical(dg$n, n); expect_identical(dg$n_T, 5L)
	expect_identical(dg$optimum_certificate, "annealing_converged"); expect_true(is.finite(dg$objective_value)); expect_gte(dg$elapsed_sec, 0)
	expect_length(dg$chain_values, dg$n_chains); expect_equal(min(dg$chain_values), dg$objective_value, tolerance = 1e-10)
	expect_true(all(c("mirror_coin", "mirror_feasible", "mirror_tied", "mirror_flipped") %in% names(dg)))
})

test_that("the optimum is symmetric under swapping arms: complement has the same Mahalanobis mean-difference statistic", {
	Xs <- scale(as.matrix(X)); S <- cov(Xs)
	stat <- function(w) { dm <- colMeans(Xs[w == 1, , drop = FALSE]) - colMeans(Xs[w == 0, , drop = FALSE]); drop(t(dm) %*% solve(S) %*% dm) }
	combs <- combn(n, 5); all_stats <- apply(combs, 2, function(i) { w <- numeric(n); w[i] <- 1; stat(w) })
	d <- mk(mirror = FALSE); d$assign_w_to_all_subjects(); w <- d$get_w()
	expect_equal(stat(w), stat(1 - w), tolerance = 1e-10)
	expect_equal(stat(w), min(all_stats), tolerance = 1e-8)                                # annealing finds the global minimum on this small problem
	expect_equal(sum(abs(all_stats - min(all_stats)) < 1e-9), 2)                             # the optimum and its mirror image are the only minimisers
})

test_that("mirror coin: with mirror off w is the raw optimum; with mirror on w is the raw optimum or its complement", {
	off <- mk(mirror = FALSE, seed = 1L); off$assign_w_to_all_subjects()
	w_off <- off$get_w()
	for (s in 1:6) {
		on <- mk(mirror = TRUE, seed = s); on$assign_w_to_all_subjects()
		expect_true(all(on$get_w() == w_off) || all(on$get_w() == 1 - w_off), info = s)
		dg <- on$get_optimization_diagnostics()
		expect_true(is.logical(dg$mirror_flipped)); expect_true(isTRUE(dg$mirror_feasible)); expect_true(isTRUE(dg$mirror_tied))
	}
	expect_false(isTRUE(off$get_optimization_diagnostics()$mirror_flipped))
})

test_that("results are reproducible under the design seed", {
	a <- mk(seed = 7L); a$assign_w_to_all_subjects(); b <- mk(seed = 7L); b$assign_w_to_all_subjects()
	expect_identical(a$get_w(), b$get_w())
})

test_that("a prob_T that leaves no treated or no control subject is rejected with the treated count in the message", {
	d <- mk(prob_T = 0.02)
	expect_error(d$assign_w_to_all_subjects(), "yields a treated count of 0")
	e <- mk(prob_T = 0.99)
	expect_error(e$assign_w_to_all_subjects(), "yields a treated count of 10")
})

test_that("an unequal allocation solves to the rounded treated count", {
	d <- mk(prob_T = 0.3, mirror = FALSE); d$assign_w_to_all_subjects()
	expect_equal(sum(d$get_w()), 3)
	expect_identical(d$get_optimization_diagnostics()$n_T, 3L)
})
