library(testthat)
library(EDI)

# annealing_solve_kernel and its quadratic / l1 / ratio wrappers (helper_optimal_annealing.R). On n = 10, n_T = 5
# (252 allocations) the exact optimum is enumerable, so the annealing result is checked against brute force:
# valid allocation, reported objective equals the objective recomputed in R, and it reaches the global minimum.

E <- asNamespace("EDI")
Sq <- get("annealing_solve_quadratic", E); Sl <- get("annealing_solve_l1", E); Sr <- get("annealing_solve_A_ratio", E)

set.seed(2); n <- 10L; nT <- 5L
W <- apply(combn(n, nT), 2, function(i) { w <- numeric(n); w[i] <- 1; w })
B <- matrix(rnorm(n * n), n); Q <- (B + t(B)) / 2
A <- matrix(rnorm(4 * n), 4)
X <- matrix(rnorm(n * 2), n); Pm <- X %*% solve(crossprod(X)) %*% t(X); Hm <- crossprod(t(X)) / 5
fq <- function(w) drop(t(w) %*% Q %*% w)
fl <- function(w) sum(abs(A %*% w))
fr <- function(w) { den <- nT - drop(t(w) %*% Pm %*% w); if (den <= 0) Inf else (drop(t(w) %*% Hm %*% w) + 1) / den }

check_valid <- function(r, f) {
	expect_length(r$w, n); expect_true(all(r$w %in% c(0, 1))); expect_equal(sum(r$w), nT)
	expect_equal(r$objective_value, f(r$w), tolerance = 1e-8)
	expect_equal(min(r$chain_values), r$objective_value, tolerance = 1e-8)
}

test_that("quadratic objective: annealing reaches the brute-force global minimum", {
	set.seed(1); r <- Sq(Q, nT, n_chains = 3L, max_iter = 3000L)
	check_valid(r, fq)
	expect_equal(r$objective_value, min(apply(W, 2, fq)), tolerance = 1e-8)
})

test_that("an asymmetric Q is symmetrised: same objective as its symmetric part", {
	Qa <- Q; Qa[upper.tri(Qa)] <- Qa[upper.tri(Qa)] + 1; Qa[lower.tri(Qa)] <- Qa[lower.tri(Qa)] - 1
	set.seed(1); r <- Sq(Qa, nT, n_chains = 3L, max_iter = 3000L)
	expect_equal(r$objective_value, min(apply(W, 2, fq)), tolerance = 1e-8)
})

test_that("l1 objective: annealing reaches the brute-force global minimum", {
	set.seed(1); r <- Sl(A, nT, n_chains = 3L, max_iter = 3000L)
	check_valid(r, fl)
	expect_equal(r$objective_value, min(apply(W, 2, fl)), tolerance = 1e-8)
})

test_that("ratio objective: annealing reaches the brute-force global minimum", {
	set.seed(1); r <- Sr(Pm, Hm, nT, n_chains = 3L, max_iter = 3000L)
	check_valid(r, fr)
	expect_equal(r$objective_value, min(apply(W, 2, fr)), tolerance = 1e-8)
})

test_that("result metadata reports the certificate, settings, and a cooled final temperature", {
	set.seed(1); r <- Sq(Q, nT, n_chains = 2L, max_iter = 500L, cooling_rate = 0.99)
	expect_identical(r$certificate, "annealing_converged"); expect_identical(r$status, "annealing_converged")
	expect_identical(r$n_chains, 2L); expect_identical(r$max_iter, 500L); expect_equal(r$cooling_rate, 0.99)
	expect_length(r$chain_values, 2L)
	expect_gt(r$initial_temp, 0)
	expect_lt(r$final_temp, r$initial_temp)
	expect_equal(r$final_temp, r$initial_temp * 0.99^500, tolerance = 1e-6)
})

test_that("a user initial_temp is used verbatim; the auto temperature is positive and reproducible under set.seed", {
	expect_equal(Sq(Q, nT, n_chains = 1L, max_iter = 50L, initial_temp = 2)$initial_temp, 2)
	set.seed(5); a <- Sq(Q, nT, n_chains = 1L, max_iter = 50L); set.seed(5); b <- Sq(Q, nT, n_chains = 1L, max_iter = 50L)
	expect_equal(a$initial_temp, b$initial_temp); expect_identical(a$w, b$w)
	expect_gt(a$initial_temp, 0)
})

test_that("same seed gives the same allocation; different seeds may differ", {
	set.seed(1); a <- Sl(A, nT, n_chains = 2L, max_iter = 200L); set.seed(1); b <- Sl(A, nT, n_chains = 2L, max_iter = 200L)
	expect_identical(a$w, b$w); expect_identical(a$chain_values, b$chain_values)
})

test_that("invalid arguments are rejected before any search runs", {
	expect_error(Sq(Q, nT, n_chains = 0L), "n_chains must be a positive integer")
	expect_error(Sq(Q, nT, max_iter = 0L), "max_iter must be a positive integer")
	expect_error(Sq(Q, nT, initial_temp = -1), "initial_temp must be NULL")
	expect_error(Sq(Q, nT, cooling_rate = 1), "cooling_rate must be a single number strictly between 0 and 1")
	expect_error(Sq(Q, n, max_iter = 10L), "n_T must be an integer with 1 <= n_T <= n - 1")
	expect_error(Sq(Q, 0L, max_iter = 10L), "n_T must be an integer")
})
