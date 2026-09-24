library(testthat)
library(EDI)

# helper_optimal_annealing.R's estimate_annealing_initial_temp() -- the RNG-driven probe that
# auto-calibrates simulated annealing's starting temperature by sampling random BCRD allocations plus
# one swap each, scaling to 10x the typical |objective delta| -- only had its POSITIVITY and
# seed-reproducibility checked (test-design-core-helper-contracts.R), never its exact numeric value
# against an independent computation replicating the same probe sequence by hand.
#   1. The returned value exactly matches an independent replication of the same probe loop (same
#      seed, same RNG consumption order: sample.int() for the allocation, then two more sample()
#      calls for the swap indices, per probe) -- 10 * mean(|f1 - f0|) over the probes.
#   2. When every probe delta is exactly zero (a constant objective), the result is the documented
#      floor, 1e-8, not 0 or NaN from a zero-mean.

test_that("the returned value exactly matches an independent replication of the same probe sequence", {
	objective <- function(w) sum((seq_along(w) * w)^2)
	n <- 8L; n_T <- 4L; n_probe <- 8L

	set.seed(202L)
	actual <- EDI:::estimate_annealing_initial_temp(objective, n = n, n_T = n_T, n_probe = n_probe)

	set.seed(202L)
	deltas <- numeric(0)
	for (k in seq_len(n_probe)) {
		w <- numeric(n)
		w[sample.int(n, n_T)] <- 1
		f0 <- objective(w)
		a <- sample(which(w == 1), 1L); b <- sample(which(w == 0), 1L)
		w[a] <- 0; w[b] <- 1
		f1 <- objective(w)
		if (is.finite(f0) && is.finite(f1)) deltas <- c(deltas, abs(f1 - f0))
	}
	ref <- max(10 * mean(deltas), 1e-8)
	expect_equal(actual, ref, tolerance = 1e-12)
})

test_that("when every probe delta is exactly zero (a constant objective), the result is the documented floor 1e-8", {
	constant_objective <- function(w) 5
	set.seed(303L)
	actual <- EDI:::estimate_annealing_initial_temp(constant_objective, n = 8L, n_T = 4L, n_probe = 8L)
	expect_equal(actual, 1e-8)
})
