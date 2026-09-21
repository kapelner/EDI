library(testthat)
library(EDI)

# Pure C++ kernels: wilson_score_interval_cpp, newcombe_independent_ci_cpp, newcombe_paired_ci_cpp,
# mn_constrained_mle_pc_cpp, mn_z_statistic_cpp (Miettinen-Nurminen) and the distance-matrix
# kernels (squared Euclidean, Manhattan, Mahalanobis, custom function). References: prop.test's
# Wilson interval, Newcombe's hybrid-score formulas written out by hand, a one-dimensional
# constrained binomial MLE via optimize(), and stats::dist / stats::mahalanobis.

K <- function(x) get(x, envir = asNamespace("EDI"))
wilson <- function(x, n, alpha = 0.05) unname(prop.test(x, n, conf.level = 1 - alpha, correct = FALSE)$conf.int[1:2])

test_that("Wilson score interval equals prop.test's uncorrected interval, incl. the 0 and n boundaries; n = 0 is NA", {
	for (a in c(0.05, 0.1)) for (xn in list(c(7, 20), c(1, 30), c(0, 20), c(20, 20), c(50, 100))) {
		expect_equal(K("wilson_score_interval_cpp")(xn[1], xn[2], a), wilson(xn[1], xn[2], a), tolerance = 1e-8, ignore_attr = TRUE)
	}
	expect_true(all(is.na(K("wilson_score_interval_cpp")(0, 0, 0.05))))
})

test_that("Newcombe's independent-proportion interval is the hybrid of the two Wilson intervals", {
	hand <- function(x1, n1, x2, n2, alpha) {
		w1 <- wilson(x1, n1, alpha); w2 <- wilson(x2, n2, alpha); p1 <- x1 / n1; p2 <- x2 / n2
		c(p1 - p2 - sqrt((p1 - w1[1])^2 + (w2[2] - p2)^2), p1 - p2 + sqrt((w1[2] - p1)^2 + (p2 - w2[1])^2))
	}
	for (cs in list(c(15, 40, 9, 50), c(3, 25, 12, 30), c(0, 10, 0, 12), c(10, 10, 4, 20))) {
		expect_equal(K("newcombe_independent_ci_cpp")(cs[1], cs[2], cs[3], cs[4], 0.05), hand(cs[1], cs[2], cs[3], cs[4], 0.05), tolerance = 1e-8, ignore_attr = TRUE)
	}
	ci <- K("newcombe_independent_ci_cpp")(15, 40, 9, 50, 0.1)
	expect_true(ci[1] < 15 / 40 - 9 / 50 && 15 / 40 - 9 / 50 < ci[2])
	# A larger confidence level widens the interval.
	wide <- K("newcombe_independent_ci_cpp")(15, 40, 9, 50, 0.01)
	expect_true(wide[1] < ci[1] && wide[2] > ci[2])
})

test_that("Newcombe's paired interval applies the phi correlation correction to the hybrid Wilson bounds", {
	hand <- function(n11, n10, n01, n00, alpha) {
		N <- n11 + n10 + n01 + n00; p1 <- (n11 + n10) / N; p2 <- (n11 + n01) / N
		A <- (n11 + n10) * (n01 + n00) * (n11 + n01) * (n10 + n00)
		phi <- if (A == 0) 0 else (n11 * n00 - n10 * n01) / sqrt(A)
		w1 <- wilson(n11 + n10, N, alpha); w2 <- wilson(n11 + n01, N, alpha)
		c(p1 - p2 - sqrt((p1 - w1[1])^2 + (w2[2] - p2)^2 - 2 * phi * (p1 - w1[1]) * (w2[2] - p2)),
			p1 - p2 + sqrt((w1[2] - p1)^2 + (p2 - w2[1])^2 - 2 * phi * (w1[2] - p1) * (p2 - w2[1])))
	}
	for (cs in list(c(20, 8, 4, 18), c(10, 5, 5, 10), c(30, 2, 9, 12))) {
		expect_equal(K("newcombe_paired_ci_cpp")(cs[1], cs[2], cs[3], cs[4], 0.05), hand(cs[1], cs[2], cs[3], cs[4], 0.05), tolerance = 1e-8, ignore_attr = TRUE)
	}
	expect_true(all(is.na(K("newcombe_paired_ci_cpp")(0, 0, 0, 0, 0.05))))
})

test_that("the Miettinen-Nurminen constrained MLE maximizes the binomial likelihood under p_T - p_C = delta", {
	for (cs in list(c(15, 40, 9, 50, 0.05), c(15, 40, 9, 50, -0.1), c(6, 20, 11, 25, 0.2))) {
		xt <- cs[1]; nt <- cs[2]; xc <- cs[3]; nc <- cs[4]; d <- cs[5]
		ref <- optimize(function(pc) {
			pt <- pc + d
			if (pt <= 0 || pt >= 1) return(-1e9)
			dbinom(xt, nt, pt, log = TRUE) + dbinom(xc, nc, pc, log = TRUE)
		}, c(max(0, -d), min(1, 1 - d)), maximum = TRUE, tol = 1e-12)$maximum
		expect_equal(K("mn_constrained_mle_pc_cpp")(xt, nt, xc, nc, d), ref, tolerance = 1e-5)
	}
})

test_that("the MN z statistic uses the constrained variance with the N / (N - 1) factor", {
	xt <- 15; nt <- 40; xc <- 9; nc <- 50; d <- 0.05
	pc <- K("mn_constrained_mle_pc_cpp")(xt, nt, xc, nc, d); pt <- pc + d; N <- nt + nc
	ref <- (xt / nt - xc / nc - d) / sqrt((pt * (1 - pt) / nt + pc * (1 - pc) / nc) * N / (N - 1))
	expect_equal(K("mn_z_statistic_cpp")(xt, nt, xc, nc, d, xt / nt, xc / nc), ref, tolerance = 1e-6)
	# Sign follows the observed difference relative to delta.
	expect_lt(K("mn_z_statistic_cpp")(xt, nt, xc, nc, 0.4, xt / nt, xc / nc), 0)
})

test_that("distance-matrix kernels match stats::dist and stats::mahalanobis; the custom kernel applies the supplied function", {
	set.seed(2)
	X <- matrix(rnorm(120), 30, 4)
	expect_equal(unname(K("distance_matrix_euclidean_sq_cpp")(X)), unname(as.matrix(dist(X))^2), tolerance = 1e-10)
	expect_equal(unname(K("distance_matrix_sum_abs_diff_cpp")(X)), unname(as.matrix(dist(X, "manhattan"))), tolerance = 1e-10)
	S <- cov(X)
	md <- outer(1:30, 1:30, Vectorize(function(i, j) mahalanobis(X[i, ], X[j, ], S)))
	D <- K("distance_matrix_mahal_cpp")(X)
	expect_equal(unname(D), md, tolerance = 1e-8)
	expect_equal(unname(D), unname(t(D)))
	expect_equal(unname(diag(D)), rep(0, 30))
	Y <- matrix(c(1, 2, 3, 4, 5, 6), 3, 2)
	cu <- K("distance_matrix_custom_cpp")(Y, function(a, b) sum(abs(a - b)))
	expect_equal(unname(cu), unname(as.matrix(dist(Y, "manhattan"))))
})
