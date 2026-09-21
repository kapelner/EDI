library(testthat)
library(EDI)

# C++ g-computation kernels for logistic regression: gcomp_logistic_point_estimate_cpp and
# gcomp_fractional_logit_point_estimate_cpp (standardized risks under T = 1 / T = 0),
# gcomp_logistic_post_fit_cpp and gcomp_logistic_cluster_post_fit_cpp (HC0 sandwich covariance plus
# delta-method SEs for the risk difference and log risk ratio), against hand-written standardization,
# sandwich::vcovHC / vcovCL and gradient-based delta methods. Also scale_columns_cpp and
# get_column_types_cpp.

skip_if_not_installed("sandwich")
K <- function(x) get(x, envir = asNamespace("EDI"))

fx <- function() {
	set.seed(2)
	n <- 150L
	w <- rbinom(n, 1, 0.5); x <- rnorm(n)
	X <- cbind(1, w, x)
	y <- as.numeric(rbinom(n, 1, plogis(-0.4 + 0.7 * w + 0.5 * x)))
	g <- glm(y ~ w + x, family = binomial())
	list(X = X, y = y, g = g, b = as.numeric(coef(g)), mu = as.numeric(fitted(g)), n = n)
}
risks <- function(f) {
	X1 <- f$X; X1[, 2] <- 1; X0 <- f$X; X0[, 2] <- 0
	p1 <- plogis(X1 %*% f$b); p0 <- plogis(X0 %*% f$b)
	list(X1 = X1, X0 = X0, p1 = as.numeric(p1), p0 = as.numeric(p0))
}
delta_se <- function(grad, V) sqrt(as.numeric(t(grad) %*% V %*% grad))

test_that("point estimates are the standardized mean risks under all-treated / all-control and their difference", {
	f <- fx(); r <- risks(f)
	pe <- K("gcomp_logistic_point_estimate_cpp")(f$X, f$b, 2L)
	expect_equal(pe$mean1, mean(r$p1), tolerance = 1e-10)
	expect_equal(pe$mean0, mean(r$p0), tolerance = 1e-10)
	expect_equal(pe$md, mean(r$p1) - mean(r$p0), tolerance = 1e-10)
	fp <- K("gcomp_fractional_logit_point_estimate_cpp")(f$X, f$b, 2L)
	expect_equal(unlist(fp[c("mean1", "mean0", "md")]), unlist(pe[c("mean1", "mean0", "md")]), tolerance = 1e-10)
})

test_that("post-fit inference: HC0 sandwich covariance and delta-method SEs for the risk difference and log risk ratio", {
	f <- fx(); r <- risks(f)
	V <- sandwich::vcovHC(f$g, type = "HC0")
	out <- K("gcomp_logistic_post_fit_cpp")(f$X, f$y, f$b, f$mu, 2L)
	expect_equal(unname(out$vcov), unname(V), tolerance = 1e-8)
	expect_equal(as.numeric(out$std_err), unname(sqrt(diag(V))), tolerance = 1e-8)
	expect_equal(as.numeric(out$z_vals), unname(f$b / sqrt(diag(V))), tolerance = 1e-8)
	g1 <- colMeans(r$p1 * (1 - r$p1) * r$X1); g0 <- colMeans(r$p0 * (1 - r$p0) * r$X0)
	expect_equal(out$risk1, mean(r$p1), tolerance = 1e-10); expect_equal(out$risk0, mean(r$p0), tolerance = 1e-10)
	expect_equal(out$rd, mean(r$p1) - mean(r$p0), tolerance = 1e-10)
	expect_equal(out$se_rd, delta_se(g1 - g0, V), tolerance = 1e-8)
	expect_equal(out$rr, mean(r$p1) / mean(r$p0), tolerance = 1e-10)
	expect_equal(out$log_rr, log(mean(r$p1) / mean(r$p0)), tolerance = 1e-10)
	expect_equal(out$se_log_rr, delta_se(g1 / mean(r$p1) - g0 / mean(r$p0), V), tolerance = 1e-8)
})

test_that("the clustered version uses the cluster-robust sandwich (HC0, no small-sample adjustment)", {
	f <- fx(); r <- risks(f)
	cl <- rep(1:50, each = 3L)
	Vc <- sandwich::vcovCL(f$g, cluster = cl, type = "HC0", cadjust = FALSE)
	out <- K("gcomp_logistic_cluster_post_fit_cpp")(f$X, f$y, f$b, f$mu, cl, 2L)
	expect_equal(unname(out$vcov), unname(Vc), tolerance = 1e-8)
	g1 <- colMeans(r$p1 * (1 - r$p1) * r$X1); g0 <- colMeans(r$p0 * (1 - r$p0) * r$X0)
	expect_equal(out$se_rd, delta_se(g1 - g0, Vc), tolerance = 1e-8)
	expect_equal(out$se_log_rr, delta_se(g1 / mean(r$p1) - g0 / mean(r$p0), Vc), tolerance = 1e-8)
	# Singleton clusters reproduce the unclustered result.
	one <- K("gcomp_logistic_cluster_post_fit_cpp")(f$X, f$y, f$b, f$mu, seq_len(f$n), 2L)
	expect_equal(one$se_rd, K("gcomp_logistic_post_fit_cpp")(f$X, f$y, f$b, f$mu, 2L)$se_rd, tolerance = 1e-8)
})

test_that("scale_columns_cpp standardizes columns (sd with n - 1) and maps a constant column to zeros", {
	M <- matrix(c(1, 2, 3, 4, 10, 20, 30, 50), 4, 2)
	expect_equal(unname(K("scale_columns_cpp")(M)), unname(scale(M)[, ]), tolerance = 1e-10)
	sc <- K("scale_columns_cpp")(cbind(c(1, 1, 1), c(1, 2, 3)))
	expect_equal(unname(sc[, 1]), rep(0, 3))
	expect_equal(unname(sc[, 2]), c(-1, 0, 1))
})

test_that("get_column_types_cpp reports the R storage type of each column", {
	ty <- K("get_column_types_cpp")(data.frame(a = 1:3, b = c(1.5, 2, 3), c = c("x", "y", "z"), d = factor(c("u", "v", "u")), e = c(TRUE, FALSE, NA)))
	expect_equal(unname(ty), c("integer", "numeric", "character", "factor", "logical"))
	expect_equal(names(ty), letters[1:5])
})
