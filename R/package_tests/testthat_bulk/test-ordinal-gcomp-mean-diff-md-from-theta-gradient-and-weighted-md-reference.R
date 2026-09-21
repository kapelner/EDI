library(testthat)
library(EDI)
skip_if_not_installed("MASS"); skip_if_not_installed("numDeriv")

# InferenceOrdinalGCompMeanDiff private helpers: compute_md_from_theta (g-computed mean difference of the expected ordinal category
# under treatment 1 vs 0 for a proportional-odds fit; theta = [thresholds, coefficients]), compute_md_gradient (central-difference
# gradient of it), weighted_gcomp_md_from_row_weights (weighted proportional-odds refit) and has_finite_md_se. References: hand
# g-computation from cumulative logits, numDeriv::grad, MASS::polr.

set.seed(6); n <- 120L
d <- DesignFixedBernoulli$new(response_type = "ordinal", n = n, seed = 1L, verbose = FALSE)
X <- data.frame(x1 = rnorm(n)); d$add_all_subjects_to_experiment(X); d$assign_w_to_all_subjects(); w <- d$get_w()
y <- factor(pmin(4, pmax(1, round(rnorm(n, 2.3 + 0.7 * w + 0.4 * X$x1, 1)))), levels = 1:4, ordered = TRUE); d$add_all_subject_responses(y)
inf <- InferenceOrdinalGCompMeanDiff$new(d, verbose = FALSE); p <- inf$.__enclos_env__$private
est <- inf$compute_estimate()
Xf <- p$build_design_matrix(); red <- p$reduce_design_matrix_preserving_treatment(Xf)
Xr <- red$X[, -1, drop = FALSE]; jt <- red$j_treat - 1L
fit <- MASS::polr(y ~ Xr, method = "logistic")
th <- c(fit$zeta, coef(fit)); n_alpha <- length(fit$zeta)
manual_md <- function(theta) {
	z <- theta[seq_len(n_alpha)]; b <- theta[-seq_len(n_alpha)]
	ex <- function(wv) { X1 <- as.matrix(Xr); X1[, jt] <- wv; eta <- as.numeric(X1 %*% b); cum <- sapply(z, function(a) plogis(a - eta)); pr <- cbind(cum, 1) - cbind(0, cum); mean(as.numeric(pr %*% seq_len(n_alpha + 1L))) }
	ex(1) - ex(0)
}

test_that("design reduction places the treatment column at index jt in the covariate matrix", {
	expect_identical(jt, 1L); expect_identical(colnames(Xf)[1:2], c("(Intercept)", "treatment"))
})

test_that("md from theta equals hand g-computation of the expected-category difference, across perturbed parameters", {
	expect_equal(p$compute_md_from_theta(Xr, th, n_alpha, jt), manual_md(th), tolerance = 1e-10)
	for (k in 1:5) { t2 <- th + c(0, 0, 0, 0.1 * k, -0.05 * k); expect_equal(p$compute_md_from_theta(Xr, t2, n_alpha, jt), manual_md(t2), tolerance = 1e-10, info = k) }
	expect_equal(p$compute_md_from_theta(Xr, replace(th, n_alpha + jt, 0), n_alpha, jt), 0, tolerance = 1e-12)     # zero treatment coefficient: no difference
})

test_that("central-difference gradient matches numDeriv and the analytic sign pattern (md rises with the treatment coefficient)", {
	g <- p$compute_md_gradient(Xr, th, n_alpha, jt)
	expect_length(g, length(th))
	expect_equal(g, numDeriv::grad(manual_md, th), tolerance = 1e-5)
	expect_gt(g[n_alpha + jt], 0)
})

test_that("weighted md: unit weights reproduce the class estimate, weights are scale-free up to optimizer tolerance, and it tracks the polr md", {
	expect_equal(p$weighted_gcomp_md_from_row_weights(rep(1, n)), est, tolerance = 1e-6)
	expect_equal(p$weighted_gcomp_md_from_row_weights(rep(3, n)), est, tolerance = 2e-3)
	expect_lt(abs(est - manual_md(th)), 2e-3)
	set.seed(1); rw <- runif(n, 0.3, 2)
	wm <- p$weighted_gcomp_md_from_row_weights(rw)
	expect_true(is.finite(wm)); expect_lt(abs(wm - est), 0.15)
})

test_that("weighted md drops non-positive / non-finite weights and gives NA when too few rows remain", {
	rw <- rep(1, n); rw[1:10] <- 0
	expect_true(is.finite(p$weighted_gcomp_md_from_row_weights(rw)))
	expect_true(is.na(p$weighted_gcomp_md_from_row_weights(rep(0, n))))
	rw2 <- rep(0, n); rw2[1:2] <- 1; expect_true(is.na(p$weighted_gcomp_md_from_row_weights(rw2)))
})

test_that("has_finite_md_se needs a finite positive cached SE", {
	expect_true(p$has_finite_md_se())
	q <- InferenceOrdinalGCompMeanDiff$new(d, verbose = FALSE)$.__enclos_env__$private
	for (v in list(NA_real_, 0, -1, Inf)) { q$cached_values$se_md <- v; expect_false(q$has_finite_md_se()) }
	q$cached_values$se_md <- 0.2; expect_true(q$has_finite_md_se())
})
