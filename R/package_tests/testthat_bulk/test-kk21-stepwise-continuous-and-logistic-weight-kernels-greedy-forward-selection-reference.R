library(testthat)
library(EDI)

# kk21_stepwise_continuous_weights_cpp(X, y, w) / kk21_stepwise_logistic_weights_cpp(X, y, w): greedy forward stepwise selection. At every step each unused
# covariate x_j is scored inside the model [1, w, already-selected covariates, x_j]; the best-scoring one is selected and RECEIVES that score as its weight
# (later-selected covariates are scored adjusted for earlier ones). Continuous score = |t| of x_j in lm(y ~ w + selected + x_j); logistic score = the score-test
# statistic |x_j'(y - p)| / sqrt(x_j' W x_j - (X_S' W x_j)' (X_S' W X_S)^-1 (X_S' W x_j)) from the reduced logistic fit. References: R re-implementations of exactly
# this greedy rule (lm / glm based). Collinear candidates are never selected (weight NA); when the residual df runs out the remaining weights stay NA.

K <- function(nm) get(nm, envir = asNamespace("EDI"))
set.seed(1); n <- 80L
X <- cbind(x1 = rnorm(n), x2 = rnorm(n), x3 = rnorm(n), x4 = rbinom(n, 1, 0.5))
w <- rep(0:1, length.out = n)

ref_cont <- function(X, y, w) {
	p <- ncol(X); weights <- rep(NA_real_, p); sel <- integer(0)
	for (step in seq_len(p)) {
		stats <- rep(-Inf, p)
		for (j in setdiff(seq_len(p), sel)) {
			d <- data.frame(y = y, w = w, X[, c(sel, j), drop = FALSE])
			cf <- summary(lm(y ~ ., data = d))$coefficients
			stats[j] <- abs(cf[nrow(cf), 3])
		}
		b <- which.max(stats); weights[b] <- stats[b]; sel <- c(sel, b)
	}
	list(weights = weights, order = sel)
}
ref_logit <- function(X, y, w) {
	p <- ncol(X); weights <- rep(NA_real_, p); sel <- integer(0)
	for (step in seq_len(p)) {
		XS <- cbind(1, X[, sel, drop = FALSE], w)
		g <- glm.fit(XS, y, family = binomial(), control = list(epsilon = 1e-12, maxit = 100))
		ph <- g$fitted.values; W <- ph * (1 - ph); r <- y - ph
		XtWX <- crossprod(XS * sqrt(W))
		stats <- rep(-Inf, p)
		for (j in setdiff(seq_len(p), sel)) {
			xj <- X[, j]; v <- sum(W * xj^2) - drop(crossprod(XS, W * xj) |> (\(u) t(u) %*% solve(XtWX, u))())
			stats[j] <- abs(sum(xj * r)) / sqrt(v)
		}
		b <- which.max(stats); weights[b] <- stats[b]; sel <- c(sel, b)
	}
	list(weights = weights, order = sel)
}

test_that("continuous stepwise weights equal the greedy lm-based reference and depend on selection order (not the univariate |t|)", {
	y <- 1 + 0.9 * X[, 1] + 0.5 * X[, 2] + 0.6 * w + rnorm(n)
	got <- K("kk21_stepwise_continuous_weights_cpp")(X, y, w)
	ref <- ref_cont(X, y, w)
	expect_equal(got, ref$weights, tolerance = 1e-7)
	expect_false(anyNA(got))
	expect_equal(which.max(got), ref$order[1])                                          # the first selected covariate has the largest raw score
	uni <- K("kk21_continuous_weights_cpp")(X, y)
	expect_gt(max(abs(got - uni)), 1e-3)
})

test_that("logistic stepwise weights equal the greedy score-test reference", {
	yb <- rbinom(n, 1, plogis(0.4 + 1.1 * X[, 1] - 0.9 * X[, 2] + 0.5 * w))
	got <- K("kk21_stepwise_logistic_weights_cpp")(X, yb, w)
	ref <- ref_logit(X, yb, w)
	expect_equal(got, ref$weights, tolerance = 1e-4)
	expect_false(anyNA(got))
	expect_true(all(got > 0))
})

test_that("a collinear candidate is never selected (NA weight) and the other weights are unaffected by its presence", {
	y <- 1 + 0.9 * X[, 1] + rnorm(n)
	Xc <- cbind(X[, 1:3], dup = X[, 1] * 2)
	got <- K("kk21_stepwise_continuous_weights_cpp")(Xc, y, w)
	expect_equal(sum(is.na(got)), 1L)
	sel <- which(!is.na(got))
	base <- K("kk21_stepwise_continuous_weights_cpp")(X[, 1:3], y, w)
	expect_equal(sort(got[sel]), sort(base[!is.na(base)]) , tolerance = 1e-6)          # same three informative scores (x1 or its duplicate stands in for x1)
})

test_that("empty design returns an NA-filled vector; when residual df runs out the remaining weights stay NA", {
	expect_length(K("kk21_stepwise_continuous_weights_cpp")(matrix(numeric(0), n, 0), rnorm(n), w), 0L)
	m <- 6L; Xs <- matrix(rnorm(m * 5), m, 5); ys <- rnorm(m); ws <- rep(0:1, length.out = m)
	got <- K("kk21_stepwise_continuous_weights_cpp")(Xs, ys, ws)
	expect_length(got, 5L); expect_gt(sum(is.na(got)), 0L); expect_gt(sum(!is.na(got)), 0L)   # df = n - m - 1 hits zero part-way
})
