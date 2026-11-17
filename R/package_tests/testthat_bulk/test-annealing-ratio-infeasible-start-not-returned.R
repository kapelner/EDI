# Numerical-robustness review audit, 2026-11-17: For the A-optimal "ratio" objective, the annealing
# kernel scores each chain's random starting allocation as (w'Hw+1)/(n_T-w'Pw) without checking that
# the denominator is positive. A start with n_T-w'Pw <= 0 (or a denominator that is ~0 but slightly
# negative from rounding, as when w lies in the column span of the design so w'Pw = n_T) gets a
# negative or -huge objective. That value becomes the chain's best and beats every feasible
# allocation. annealing_solve_A_ratio then returns an infeasible allocation with a negative
# objective_value, even though its own f_exact (helper_optimal_annealing.R:88) scores that allocation
# as Inf.
# Where: R/EDI/src/design_optimal_annealing_search.cpp:77 (kind: near_zero_division).
# On commit 4fc58cd063bc this test failed with: Expected `den` > 0. Actual comparison: -0.50 <= 0.00
# Difference: -0.50 <= 0
# Remove the skip() once a release TODO covers this finding, and cite that TODO here
# (v<version>-TODO-<n>).

test_that("ratio annealing never returns an infeasible allocation with a non-positive denominator", {
	skip("open a release TODO for this")
		set.seed(1)
		n = 10L
		n_T = 5L
		# w'Pw = 2.5 + k, where k = number treated among units 1..5: allocations with
		# k <= 2 are feasible (n_T - w'Pw > 0); k >= 3 makes the denominator negative.
		P = diag(c(rep(1.5, 5), rep(0.5, 5)))
		H = matrix(0, n, n)
		res = EDI:::annealing_solve_A_ratio(P, H, n_T, n_chains = 8L, max_iter = 500L)
		w = as.numeric(res$w)
		expect_equal(sum(w), n_T)
		den = n_T - drop(t(w) %*% P %*% w)
		expect_gt(den, 0)
		expect_gt(res$objective_value, 0)
})
