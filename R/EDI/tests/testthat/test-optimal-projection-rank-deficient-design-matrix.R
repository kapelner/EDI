# v1.0.6-TODO-57: the non-Bayesian D/A criterion matrices built by build_optimal_design_P_H()
# (helper_optimal_shared.R) were wrong when Z0 = cbind(1, X) is rank deficient although the
# covariates alone are not (a covariate collinear with the intercept, e.g. x2 = x1 + 1, or 0/1
# indicators that sum to 1). P = Q Q' used every column of qr.Q(), so it projected onto an extra
# arbitrary direction (trace rank + 1). The subset-interest H also used M from the pivoted R, so
# its columns were in the wrong order when the QR pivoted a column. Full-rank Z0 is unchanged.

hat_matrix = function(Z) Z %*% solve(crossprod(Z)) %*% t(Z)

test_that("P is the hat matrix of [1, X] when a covariate is an affine shift of another", {
	set.seed(1)
	n = 30L
	x1 = rnorm(n)
	X = cbind(x1 = x1, x2 = x1 + 1)
	ph = build_optimal_design_P_H(X, "all", NULL, TRUE, need_H = TRUE)
	expect_equal(sum(diag(ph$P)), 2, tolerance = 1e-8)
	expect_equal(unname(ph$P), unname(hat_matrix(cbind(1, x1))), tolerance = 1e-8)
	expect_equal(ph$P %*% ph$P, ph$P, tolerance = 1e-8)
})

test_that("P is the hat matrix when two indicator covariates sum to one", {
	set.seed(2)
	n = 24L
	g = rbinom(n, 1, 0.5)
	z = rnorm(n)
	X = cbind(gA = g, gB = 1 - g, z = z)
	ph = build_optimal_design_P_H(X, "all", NULL, TRUE, need_H = FALSE)
	expect_equal(sum(diag(ph$P)), 3, tolerance = 1e-8)
	expect_equal(unname(ph$P), unname(hat_matrix(cbind(1, g, z))), tolerance = 1e-8)
})

test_that("a subset-interest H uses Z0's own column order when the QR pivots a column", {
	set.seed(1)
	n = 30L
	x1 = rnorm(n)
	# column a is collinear with [1, b], so qr() pivots it after column c
	X = cbind(a = x1 + 1, b = x1, c = rnorm(n))
	expect_false(identical(qr(cbind(1, X))$pivot, 1:4))
	ph = build_optimal_design_P_H(X, "c", NULL, TRUE, need_H = TRUE)
	Z0 = cbind(1, X)
	M = MASS::ginv(crossprod(Z0))
	expect_equal(sum(diag(ph$P)), 3, tolerance = 1e-8)
	expect_equal(unname(ph$H), unname(tcrossprod((Z0 %*% M)[, 4L, drop = FALSE])), tolerance = 1e-8)
	H_all = build_optimal_design_P_H(X, "all", NULL, TRUE, need_H = TRUE)$H
	expect_equal(unname(H_all), unname(Z0 %*% M %*% M %*% t(Z0)), tolerance = 1e-8)
})

test_that("a full-rank Z0 still gives the classical P and H", {
	set.seed(3)
	X = cbind(a = rnorm(15), b = rnorm(15), c = rbinom(15, 1, 0.5))
	Z0 = cbind(1, X)
	M = solve(crossprod(Z0))
	ph = build_optimal_design_P_H(X, "all", NULL, TRUE, need_H = TRUE)
	expect_equal(unname(ph$P), unname(hat_matrix(Z0)), tolerance = 1e-10)
	expect_equal(unname(ph$H), unname(Z0 %*% M %*% M %*% t(Z0)), tolerance = 1e-8)
})

test_that("the greedy D-optimal design searches with the corrected P on an intercept-collinear covariate", {
	set.seed(1)
	n = 30L
	x1 = rnorm(n)
	des = DesignFixedGreedyDOptimal$new(response_type = "continuous", n = n, verbose = FALSE, seed = 1L)
	des$add_all_subjects_to_experiment(data.frame(x1 = x1, x2 = x1 + 1))
	W = des$draw_ws_according_to_design(r = 2L)
	expect_equal(dim(W), c(n, 2L))
	expect_true(all(colSums(W) == n / 2))
	expect_equal(unname(des$.__enclos_env__$private$P), unname(hat_matrix(cbind(1, x1))), tolerance = 1e-8)
})
