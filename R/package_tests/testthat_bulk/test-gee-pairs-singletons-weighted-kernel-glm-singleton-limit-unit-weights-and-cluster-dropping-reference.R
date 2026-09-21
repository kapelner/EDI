library(testthat)
library(EDI)

# gee_pairs_singletons_weighted_cpp(X, y, group_id, family, weights): observation-weighted GEE for clusters of
# size 1-2. Independent references: (a) all-singleton data has no working correlation, so the weighted GEE point
# estimate is the weighted GLM MLE; (b) unit weights equal the unweighted kernel; (c) a zero-weight cluster is the
# same as dropping it; (d) row order is irrelevant; (e) weight-length guard.

E <- asNamespace("EDI")
W <- get("gee_pairs_singletons_weighted_cpp", E); U <- get("gee_pairs_singletons_cpp", E)

set.seed(3)
n1 <- 60L
X1 <- cbind(1, rnorm(n1), rbinom(n1, 1, 0.5))
w1 <- runif(n1, 0.4, 2.5)
g1 <- seq_len(n1)                                     # every subject its own cluster

test_that("all-singleton weighted GEE point estimates equal the weighted GLM fit (gaussian, poisson, binomial)", {
	y <- X1 %*% c(0.5, -0.3, 0.8) + rnorm(n1)
	ref <- coef(lm(y ~ X1[, -1], weights = w1))
	expect_equal(as.numeric(W(X1, as.numeric(y), g1, "gaussian", w1)$beta), unname(ref), tolerance = 1e-6)

	yp <- rpois(n1, exp(0.2 + 0.3 * X1[, 2]))
	refp <- coef(glm(yp ~ X1[, -1], family = poisson, weights = w1))
	expect_equal(as.numeric(W(X1, as.numeric(yp), g1, "poisson", w1)$beta), unname(refp), tolerance = 1e-5)

	yb <- rbinom(n1, 1, plogis(0.1 + 0.6 * X1[, 2]))
	refb <- suppressWarnings(coef(glm(yb ~ X1[, -1], family = binomial, weights = w1)))
	expect_equal(as.numeric(W(X1, as.numeric(yb), g1, "binomial", w1)$beta), unname(refb), tolerance = 1e-5)
})

# mixed pair / singleton layout
gm <- c(rep(1:12, each = 2), 13:(12 + 16)); nm <- length(gm)
Xm <- cbind(1, rnorm(nm), rbinom(nm, 1, 0.5)); ym <- rnorm(nm) + Xm[, 2]; wm <- runif(nm, 0.5, 2)

test_that("unit weights reproduce the unweighted kernel exactly (beta, alpha, vcov)", {
	a <- U(Xm, ym, as.integer(gm), "gaussian"); b <- W(Xm, ym, as.integer(gm), "gaussian", rep(1, nm))
	expect_equal(b$beta, a$beta); expect_equal(b$alpha, a$alpha); expect_equal(b$vcov, a$vcov)
})

test_that("a cluster with zero weight in every row is equivalent to omitting the cluster", {
	w0 <- wm; w0[gm == 3] <- 0
	full <- W(Xm, ym, as.integer(gm), "gaussian", w0)
	keep <- gm != 3
	sub <- W(Xm[keep, ], ym[keep], as.integer(gm[keep]), "gaussian", wm[keep])
	expect_equal(as.numeric(full$beta), as.numeric(sub$beta), tolerance = 1e-6)
})

test_that("results do not depend on row order and the fit converges with the documented fields", {
	a <- W(Xm, ym, as.integer(gm), "gaussian", wm)
	o <- sample(nm)
	b <- W(Xm[o, ], ym[o], as.integer(gm[o]), "gaussian", wm[o])
	expect_equal(as.numeric(b$beta), as.numeric(a$beta), tolerance = 1e-8)
	expect_true(isTRUE(a$converged)); expect_false(isTRUE(a$hit_iteration_cap))
	expect_true(all(c("beta", "alpha", "vcov", "quasi_loglik", "score", "fisher_information", "niter",
		"gradient_norm") %in% names(a)))
	expect_equal(dim(a$vcov), c(3L, 3L)); expect_equal(a$vcov, t(a$vcov), tolerance = 1e-10)
	expect_lt(a$gradient_norm, 1e-5)
})

test_that("non-unit weights change the estimate; scaling all weights by a constant does not", {
	base <- W(Xm, ym, as.integer(gm), "gaussian", wm)
	expect_gt(max(abs(W(Xm, ym, as.integer(gm), "gaussian", rev(wm))$beta - base$beta)), 1e-6)
	expect_equal(as.numeric(W(Xm, ym, as.integer(gm), "gaussian", 5 * wm)$beta), as.numeric(base$beta), tolerance = 1e-6)
})

test_that("weight vector of the wrong length is rejected", {
	expect_error(W(Xm, ym, as.integer(gm), "gaussian", wm[-1]), "weights must have length equal to length\\(y\\)")
})
