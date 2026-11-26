# v1.0.6-TODO-172: the robust M fit (method = "M", MAD scale re-estimated each
# iteration) must stop at iteration 1 when its OLS start is an exact fit
# (median |residual| = 0), as MASS::rlm does: rlm returns the start and reports
# convergence. The kernel used to floor the start scale at 1e-10 before the
# exact-fit check, so the check could not fire at iteration 1 and the loop took
# a WLS step with near-zero weights on the nonzero residuals. When the
# zero-residual points do not identify the coefficients on their own (here all
# sit at x = 0), that step moved the slope far from rlm's (1.67 and -1.0 vs 0
# on the two fixtures below).
#
# The fixtures are chosen so that y is exactly orthogonal to the columns of X in
# floating point: both QR solvers (Eigen's and LINPACK's in lm.wfit) return
# exactly zero OLS residuals on the x = 0 points, so the MAD is exactly 0 for
# both. A start whose MAD is a tiny positive number from rounding is a
# different case and is not tested here.
#
# Needs the rebuilt EDI.so: with an installed library older than this fix the
# expectations below fail.

exact_fit_fixtures <- list(
	pattern_1_m2_1 = list(
		X = cbind(1, c(0, 0, 0, 0, 3, 0, 2, 1, 0)),
		y = c(0, 0, 0, 0, 5, 0, -10, 5, 0)
	),
	unbalanced = list(
		X = cbind(1, c(0, 0, 0, 1, 0, 0, 0, 5, 0, 4, 4)),
		y = c(0, 0, 0, -3, 0, 0, 0, -9, 0, -4, 16)
	)
)

test_that("robust M fit with an exact-fit OLS start matches MASS::rlm (coefficients and converged)", {
	skip_if_not_installed("MASS")
	for (nm in names(exact_fit_fixtures)) {
		X <- exact_fit_fixtures[[nm]]$X
		y <- exact_fit_fixtures[[nm]]$y
		# EDI's answer is the OLS start, which is exact here (slope 0). MASS::rlm
		# matches it only when R's own lm.wfit start leaves exactly zero residuals
		# on the x = 0 points. With OpenBLAS (the bulk CI runners) they come out
		# ~1e-16, the MAD is tiny but positive, and rlm takes the WLS step to
		# slope 1.67, the old EDI behavior. So compare to rlm only when its start
		# MAD is exactly 0 on this platform.
		ols <- qr.solve(X, y)
		rlm_start_mad <- median(abs(stats::lm.wfit(X, y, rep(1, length(y)))$residuals))
		fit <- EDI:::fast_robust_regression_cpp(X, y, method = "M")
		expect_equal(unname(fit$coefficients), unname(ols), tolerance = 1e-12, info = nm)
		if (identical(rlm_start_mad, 0)) {
			ref <- MASS::rlm(X, y, method = "M", scale.est = "MAD", maxit = 50)
			expect_true(ref$converged, info = nm)
			expect_equal(unname(fit$coefficients), unname(coef(ref)), tolerance = 1e-12, info = nm)
		}
		expect_true(fit$converged, info = nm)
		expect_identical(as.integer(fit$num_iter), 1L, info = nm)
		expect_false(fit$hit_iteration_cap, info = nm)
		# no WLS step ran: the information matrix is X'X (all weights 1, as rlm's w)
		expect_equal(unname(fit$fisher_information), unname(crossprod(X)), tolerance = 1e-12, info = nm)

		fit_eo <- EDI:::fast_robust_regression_cpp(X, y, method = "M", estimate_only = TRUE)
		expect_equal(unname(fit_eo$coefficients), unname(ols), tolerance = 1e-12, info = nm)
		expect_true(fit_eo$converged, info = nm)
	}
})
