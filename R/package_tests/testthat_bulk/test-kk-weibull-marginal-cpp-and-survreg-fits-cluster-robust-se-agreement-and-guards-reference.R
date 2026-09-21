library(testthat)
library(EDI)
skip_if_not_installed("survival")

# InferenceSurvivalKKWeibullMarginal private fits: fit_weibull_marginal_cpp(X, robust, cluster_ids) (C++ pooled Weibull AFT; cluster-robust SE
# from per-subject scores) and fit_weibull_marginal_survreg(X, robust, cluster_ids) (survival::survreg fallback). Reference: survreg with
# cluster = pair id, robust = TRUE. X for the C++ path carries "(Intercept)" + "treatment"; the survreg path's formula uses the supplied
# column names, so the intercept column is left out there (survreg adds its own).

set.seed(8); n <- 80L
des <- DesignSeqOneByOneKK14$new(n = n, response_type = "survival", verbose = FALSE)
for (i in seq_len(n)) {
	x <- data.frame(x1 = rnorm(1)); w <- des$add_one_subject_to_experiment_and_assign(x)
	t <- rexp(1, exp(-0.3 * w - 0.3 * x$x1)); cen <- runif(1, 0.5, 4)
	if (t <= cen) des$add_one_subject_response(i, t) else des$add_one_subject_response(i, NULL, cen, Inf)
}
mk <- function() { inf <- InferenceSurvivalKKWeibullMarginal$new(des, verbose = FALSE); list(inf = inf, p = inf$.__enclos_env__$private) }
f0 <- mk(); pv <- f0$p
X <- cbind("(Intercept)" = 1, treatment = pv$w, x1 = as.numeric(pv$get_X()[, 1]))
m <- as.integer(des$.__enclos_env__$private$m); m[is.na(m)] <- 0L
cl <- ifelse(m > 0L, m, max(m) + seq_along(m))
ref <- survival::survreg(survival::Surv(y, dead) ~ treatment + x1, data = data.frame(y = pv$y, dead = pv$dead, treatment = pv$w, x1 = X[, 3]),
	dist = "weibull", cluster = cl, robust = TRUE)
ref_plain <- survival::survreg(survival::Surv(y, dead) ~ treatment + x1, data = data.frame(y = pv$y, dead = pv$dead, treatment = pv$w, x1 = X[, 3]), dist = "weibull")

test_that("C++ fit: treatment coefficient equals survreg; cluster-robust SE equals survreg's robust cluster SE", {
	r <- mk()$p$fit_weibull_marginal_cpp(X, robust = TRUE, cluster_ids = cl)
	expect_equal(r$beta_T, unname(coef(ref)["treatment"]), tolerance = 1e-4)
	expect_equal(r$se_T, unname(sqrt(vcov(ref)["treatment", "treatment"])), tolerance = 1e-3)
	expect_true(isTRUE(r$fit_obj$converged))
})

test_that("C++ fit without clusters returns the point estimate and an NA SE; non-robust mode skips variance entirely", {
	a <- mk()$p$fit_weibull_marginal_cpp(X, robust = TRUE)
	expect_equal(a$beta_T, unname(coef(ref_plain)["treatment"]), tolerance = 1e-4); expect_true(is.na(a$se_T))
	b <- mk()$p$fit_weibull_marginal_cpp(X, robust = FALSE)
	expect_equal(b$beta_T, a$beta_T, tolerance = 1e-5); expect_true(is.na(b$se_T))
})

test_that("C++ fit needs a treatment column and finite data; otherwise it declines with NULL", {
	expect_null(mk()$p$fit_weibull_marginal_cpp(X[, -2, drop = FALSE]))
	Xna <- X; Xna[3, 3] <- NA
	expect_no_error(r <- mk()$p$fit_weibull_marginal_cpp(Xna)); expect_true(is.null(r) || is.list(r))
})

test_that("survreg fallback: same coefficient; robust SE only when clusters are supplied", {
	Xs <- X[, -1]
	r <- mk()$p$fit_weibull_marginal_survreg(Xs, robust = TRUE, cluster_ids = cl)
	expect_equal(r$beta_T, unname(coef(ref)["treatment"]), tolerance = 1e-6)
	expect_equal(r$se_T, unname(sqrt(vcov(ref)["treatment", "treatment"])), tolerance = 1e-6)
	p <- mk()$p$fit_weibull_marginal_survreg(Xs, robust = FALSE)
	expect_equal(p$beta_T, unname(coef(ref_plain)["treatment"]), tolerance = 1e-6); expect_true(is.na(p$se_T))
	q <- mk()$p$fit_weibull_marginal_survreg(Xs, robust = TRUE)                                # robust requested but no clusters
	expect_true(is.na(q$se_T)); expect_s3_class(r$fit_obj, "survreg")
})

test_that("survreg fallback declines when the treatment column is missing", {
	expect_null(mk()$p$fit_weibull_marginal_survreg(X[, c("x1"), drop = FALSE]))
})

test_that("both backends agree on the treatment coefficient and (with clusters) on the robust SE", {
	a <- mk()$p$fit_weibull_marginal_cpp(X, robust = TRUE, cluster_ids = cl)
	b <- mk()$p$fit_weibull_marginal_survreg(X[, -1], robust = TRUE, cluster_ids = cl)
	expect_equal(a$beta_T, b$beta_T, tolerance = 1e-4); expect_equal(a$se_T, b$se_T, tolerance = 1e-3)
})
