library(testthat)
library(EDI)

# annealing_design_search_cpp (design_optimal_annealing_search.cpp) supports a third numeric
# objective_kind, "ratio" -- objective = (w'M2w + 1) / (n_T - w'M1w) -- in addition to "quadratic"
# and "l1" (both already closed in test-annealing-design-search-kernel-objective-guards-and-
# quadratic-l1-reference.R, along with the kernel's two input guards). "ratio" had no test reference
# anywhere: it is the only one of the three numeric objective kinds that consumes BOTH M1 and M2
# (quadratic/l1 only use M1; M2 is a required-but-unused placeholder for those, confirmed by passing
# matrix(0, 0, 0) for it in the sibling file).

f <- get("annealing_design_search_cpp", envir = asNamespace("EDI"))

test_that("ratio objective: objective_value equals (w'M2w + 1) / (n_T - w'M1w) on the returned allocation, with exactly n_T treated", {
	set.seed(61); n <- 12L; n_T <- 6L
	X <- matrix(rnorm(n * 3), n, 3)
	M1 <- X %*% t(X)          # n x n
	M2 <- diag(n) + 0.1       # n x n

	set.seed(62)
	r <- f("ratio", M1, M2, n_T, 3L, 150L, 1.0, 0.95, NULL)
	w <- as.numeric(r$w)
	expect_length(w, n)
	expect_equal(sum(w), n_T)

	ref <- (as.numeric(t(w) %*% M2 %*% w) + 1) / (n_T - as.numeric(t(w) %*% M1 %*% w))
	expect_equal(r$objective_value, ref, tolerance = 1e-10)
	expect_equal(r$objective_value, min(r$chain_values), tolerance = 1e-10)
})

test_that("ratio objective is reproducible under an identical set.seed()", {
	set.seed(63); n <- 10L; n_T <- 4L
	X <- matrix(rnorm(n * 2), n, 2)
	M1 <- X %*% t(X)
	M2 <- diag(n) + 0.2

	set.seed(64); a <- f("ratio", M1, M2, n_T, 2L, 100L, 1.0, 0.95, NULL)
	set.seed(64); b <- f("ratio", M1, M2, n_T, 2L, 100L, 1.0, 0.95, NULL)
	expect_identical(as.numeric(a$w), as.numeric(b$w))
})
