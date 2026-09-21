library(testthat)
library(EDI)

# compute_robust_rand_bootstrap_parallel_cpp(y0, Xc, i_mat, w_mat, delta, method, noise_mat, num_cores): each column fits an M-estimator of
# y0[i_b] (+ noise) + delta * w_b on [1, w_b, Xc[i_b, ]] and returns the treatment coefficient. method = "M" is Huber (k = 1.345); ANY
# "MM" is the MM estimator; any other string (e.g. "huber" / "bisquare") is rejected with an error (it used to fall through silently to
# MM). References: MASS::rlm(psi.huber) for "M" and
# MASS::rlm(method = "MM") for the rest, exact additive equivariance in delta (coefficient shifts by delta), thread-count invariance,
# no-covariate designs, and NA for a resample with fewer than 2 treated or 2 control rows.

skip_if_not_installed("MASS")
K <- get("compute_robust_rand_bootstrap_parallel_cpp", envir = asNamespace("EDI"))
fast1 <- get("fast_robust_regression_cpp", envir = asNamespace("EDI"))
set.seed(1); n <- 60L; B <- 6L
y0 <- rnorm(n, sd = 2); y0[c(3, 17)] <- y0[c(3, 17)] + 15                     # two outliers so the robust fit differs from OLS
Xc <- cbind(a = rnorm(n), b = rnorm(n))
i_mat <- replicate(B, sample.int(n, n, TRUE)); storage.mode(i_mat) <- "integer"
w_mat <- replicate(B, sample(rep(0:1, length.out = n))); storage.mode(w_mat) <- "integer"

ref_rlm <- function(method, delta = 0, X = Xc) vapply(seq_len(B), function(b) {
	i <- i_mat[, b]; w <- w_mat[, b]
	d <- data.frame(y = y0[i] + delta * w, w = w); if (ncol(X)) d <- cbind(d, as.data.frame(X[i, , drop = FALSE]))
	fit <- if (method == "M") MASS::rlm(y ~ ., data = d, psi = MASS::psi.huber, maxit = 100) else MASS::rlm(y ~ ., data = d, method = "MM", maxit = 100)
	unname(coef(fit)["w"])
}, numeric(1))

test_that("method = 'M' agrees with MASS::rlm Huber, 'MM' with rlm MM; any other method name is rejected", {
	# The kernel's scale is the MAD of the INITIAL OLS residuals, held fixed through the IRLS (single-fit scale 1.81 here); rlm
	# re-estimates the MAD every iteration (1.70). The Huber coefficient therefore agrees with rlm only loosely; the exact checks are
	# against the single-fit kernel on the assembled data and the fixed-scale reference IRLS in the next test.
	oneM <- vapply(seq_len(B), function(b) { i <- i_mat[, b]; w <- w_mat[, b]
		unname(fast1(cbind(1, w, Xc[i, ]), y0[i], method = "M")$coefficients[2]) }, numeric(1))
	expect_equal(K(y0, Xc, i_mat, w_mat, 0, "M", NULL, 1L), oneM, tolerance = 1e-8)
	expect_equal(K(y0, Xc, i_mat, w_mat, 0, "M", NULL, 1L), ref_rlm("M"), tolerance = 0.15, scale = 1)
	mm <- K(y0, Xc, i_mat, w_mat, 0, "MM", NULL, 1L)
	expect_equal(mm, ref_rlm("MM"), tolerance = 5e-2)
	for (bad in c("huber", "bisquare", "m", "", "OLS")) expect_error(K(y0, Xc, i_mat, w_mat, 0, bad, NULL, 1L), "method must be", info = bad)
	expect_error(fast1(cbind(1, w_mat[, 1], Xc), y0, method = "huber"), "method must be")
})

test_that("the robust estimate differs from OLS on outlier data (so the reference is discriminating)", {
	ols <- vapply(seq_len(B), function(b) unname(coef(lm(y0[i_mat[, b]] ~ w_mat[, b] + Xc[i_mat[, b], ]))[2]), numeric(1))
	expect_gt(max(abs(K(y0, Xc, i_mat, w_mat, 0, "M", NULL, 1L) - ols)), 0.05)
})

test_that("delta shifts the treatment coefficient additively and exactly", {
	base <- K(y0, Xc, i_mat, w_mat, 0, "M", NULL, 1L)
	expect_equal(K(y0, Xc, i_mat, w_mat, 0.7, "M", NULL, 1L) - base, rep(0.7, B), tolerance = 1e-6)
	expect_equal(K(y0, Xc, i_mat, w_mat, -1.3, "M", NULL, 1L) - base, rep(-1.3, B), tolerance = 1e-6)
})

test_that("no-covariate design works and thread count does not change the result", {
	X0 <- matrix(numeric(0), n, 0)
	out <- K(y0, X0, i_mat, w_mat, 0, "M", NULL, 1L)
	expect_equal(out, ref_rlm("M", X = matrix(numeric(0), n, 0)), tolerance = 0.15, scale = 1)
	expect_equal(K(y0, Xc, i_mat, w_mat, 0.2, "M", NULL, 2L), K(y0, Xc, i_mat, w_mat, 0.2, "M", NULL, 1L), tolerance = 1e-12)
})

test_that("resamples with fewer than two treated or two control rows return NA", {
	w2 <- w_mat; w2[, 1] <- 0L; w2[1, 1] <- 1L                       # one treated
	w2[, 2] <- 1L; w2[1, 2] <- 0L                                    # one control
	out <- K(y0, Xc, i_mat, w2, 0, "M", NULL, 1L)
	expect_true(is.na(out[1])); expect_true(is.na(out[2])); expect_true(all(is.finite(out[-(1:2)])))
})

test_that("investigation: kernel M is Huber IRLS with the scale FIXED at the OLS-residual MAD; kernel MM is bisquare IRLS from the OLS start with that same fixed scale", {
	i <- i_mat[, 1]; w <- w_mat[, 1]; X <- cbind(1, w, Xc[i, ]); y <- y0[i]
	b_ols <- qr.solve(X, y); s0 <- median(abs(y - X %*% b_ols)) / 0.6745
	irls <- function(wfun, it = 1000) { b <- b_ols; for (k in seq_len(it)) { u <- abs(as.numeric(y - X %*% b)) / s0; wt <- wfun(u)
		b <- solve(crossprod(X, X * wt), crossprod(X, y * wt)) }; as.numeric(b) }
	kM <- fast1(X, y, method = "M", tol = 1e-12, maxit = 1000L)
	expect_equal(kM$scale, s0, tolerance = 1e-12)
	expect_equal(as.numeric(kM$coefficients), irls(function(u) ifelse(u <= 1.345, 1, 1.345 / u)), tolerance = 1e-7)
	kMM <- fast1(X, y, method = "MM", tol = 1e-12, maxit = 1000L)
	expect_equal(as.numeric(kMM$coefficients), irls(function(u) ifelse(u <= 4.685, (1 - (u / 4.685)^2)^2, 0)), tolerance = 1e-6)
	# rlm re-estimates the scale each iteration; a reference that does so reproduces rlm exactly, so the loose agreement above is
	# entirely the fixed-vs-re-estimated scale.
	b <- b_ols; for (k in 1:1000) { r <- as.numeric(y - X %*% b); sc <- median(abs(r)) / 0.6745; u <- abs(r) / sc; wt <- ifelse(u <= 1.345, 1, 1.345 / u)
		b <- solve(crossprod(X, X * wt), crossprod(X, y * wt)) }
	ref <- MASS::rlm(y ~ X - 1, psi = MASS::psi.huber, maxit = 500, acc = 1e-10)
	expect_equal(as.numeric(b), unname(coef(ref)), tolerance = 1e-6)
})
