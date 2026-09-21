library(testthat)
library(EDI)

# C++ kernels used by the sequential KK designs: compute_proportional_mahal_distances_cpp (squared
# Mahalanobis distances of reservoir rows to the current subject, given an inverse covariance),
# compute_weighted_sqd_distances_cpp (weighted squared Euclidean distances),
# eigen_compute_single_entry_on_diagonal_of_inverse_matrix_cpp, and compute_all_subject_data_cpp
# (constant-column removal, independent-column selection, and scaling of the subject rows together
# with the current subject's row appended -- so the current row is counted twice in the scaling
# because i_all already contains it). References: stats::mahalanobis, closed forms, scale(), qr().

K <- function(x) get(x, envir = asNamespace("EDI"))

test_that("proportional Mahalanobis distances are (x_i - x_t)' S^-1 (x_i - x_t) for the reservoir rows", {
	set.seed(2)
	X <- matrix(rnorm(40), 10, 4); Xp <- X[1:9, ]; xt <- rnorm(4); res <- c(2L, 5L, 7L)
	S <- cov(Xp)
	got <- K("compute_proportional_mahal_distances_cpp")(xt, Xp, res, solve(S))
	expect_equal(as.numeric(got), vapply(res, function(i) mahalanobis(Xp[i, ], xt, S), 0), tolerance = 1e-10)
	expect_equal(as.numeric(got), vapply(res, function(i) drop(t(Xp[i, ] - xt) %*% solve(S) %*% (Xp[i, ] - xt)), 0), tolerance = 1e-10)
	expect_equal(as.numeric(K("compute_proportional_mahal_distances_cpp")(Xp[2, ], Xp, 2L, solve(S))), 0, tolerance = 1e-12)
})

test_that("weighted squared distances are sum_j w_j (x_ij - x_j)^2 for the reservoir rows", {
	set.seed(2)
	Xp <- matrix(rnorm(36), 9, 4); xt <- rnorm(4); res <- c(2L, 5L, 7L); w <- c(1, 2, 0.5, 3)
	got <- K("compute_weighted_sqd_distances_cpp")(xt, Xp, res, w)
	expect_equal(as.numeric(got), vapply(res, function(i) sum(w * (Xp[i, ] - xt)^2), 0), tolerance = 1e-12)
	expect_equal(as.numeric(K("compute_weighted_sqd_distances_cpp")(xt, Xp, res, rep(1, 4))), vapply(res, function(i) sum((Xp[i, ] - xt)^2), 0), tolerance = 1e-12)
})

test_that("the single diagonal entry of an inverse matrix equals solve(M)[j, j]", {
	set.seed(2)
	M <- crossprod(matrix(rnorm(40), 10, 4))
	for (j in 1:4) expect_equal(K("eigen_compute_single_entry_on_diagonal_of_inverse_matrix_cpp")(M, j), solve(M)[j, j], tolerance = 1e-10)
})

test_that("subject data: prior rows / current row / independent columns, and scaling with the current row appended", {
	set.seed(3)
	t <- 12L
	X <- cbind(a = rnorm(t), b = rnorm(t), c = rep(c(1, 2), 6L))
	X <- cbind(X, e = 2 * X[, "a"])                                     # exact duplicate direction of a
	present <- c(1:6, 8:11)
	r <- K("compute_all_subject_data_cpp")(X, t, as.integer(present))
	# Unscaled pieces: prior rows (first t - 1), the current row, all rows, restricted to the independent columns.
	expect_equal(unname(r$X_prev), unname(X[1:(t - 1), r$cols_prev]))
	expect_equal(unname(r$xt_prev), unname(X[t, r$cols_prev]))
	expect_equal(unname(r$X_all), unname(X[, r$cols_all]))
	expect_equal(length(r$cols_prev), qr(X[1:(t - 1), ])$rank)          # one column of the duplicated pair dropped
	expect_equal(r$rank_prev, qr(X[1:(t - 1), ])$rank)
	# Scaled pieces: scale(rbind(rows, current row)) over the varying columns, then the independent ones.
	Xv <- X[, apply(X, 2, function(v) length(unique(v)) > 1), drop = FALSE]
	A <- scale(rbind(Xv[seq_len(t), ], Xv[t, ]))
	expect_equal(unname(r$X_all_scaled), unname(A[seq_len(t), r$cols_all_scaled]), tolerance = 1e-10)
	expect_equal(unname(r$xt_all_scaled), unname(A[t + 1L, r$cols_all_scaled]), tolerance = 1e-10)
	B <- scale(rbind(Xv[present, ], Xv[t, ]))
	expect_equal(unname(r$X_all_with_y_scaled), unname(B[seq_along(present), r$cols_all_with_y_scaled]), tolerance = 1e-10)
	expect_equal(r$rank_all_with_y_scaled, qr(B)$rank)
})

test_that("constant columns are dropped, and a single-subject start returns empty prior data", {
	set.seed(3)
	X <- cbind(rnorm(12), rnorm(12), 5)
	r <- K("compute_all_subject_data_cpp")(X, 12L, 1:12)
	expect_false(3L %in% r$cols_prev)
	expect_false(3L %in% r$cols_all)
	r1 <- K("compute_all_subject_data_cpp")(X[1, , drop = FALSE], 1L, 1L)
	expect_equal(nrow(r1$X_prev), 0L)
})
