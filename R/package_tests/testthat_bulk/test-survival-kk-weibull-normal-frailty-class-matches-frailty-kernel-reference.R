library(testthat)
library(EDI)

# InferenceSurvivalGLMMWeibullFrailtyNormalOneLik: Weibull AFT with a normal frailty per pair (each reservoir
# subject its own cluster). The class' treatment coefficient is compared with fast_weibull_frailty_cpp (whose
# marginal likelihood is validated against a hand integral elsewhere) fed independently assembled data (treatment
# first, then intercept and covariates, cluster = pair id / singleton id): they agree to ~1% (the class and the
# kernel use different quadrature orders), the class uses L-BFGS with a finite, non-collapsed frailty scale, and its sign follows
# survreg's AFT convention (treatment shortens survival times in the fixture => a NEGATIVE coefficient).

K <- function(x) get(x, envir = asNamespace("EDI"))

fx <- function() {
	set.seed(11)
	n <- 160L
	des <- DesignSeqOneByOneKK14$new(response_type = "survival", n = n, verbose = FALSE)
	X <- data.frame(x = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	m <- des$.__enclos_env__$private$m[seq_len(n)]
	fr <- ifelse(m > 0, rnorm(max(m))[pmax(m, 1)], 0) * 0.5
	t <- rweibull(n, 1.5, exp(1 - 0.5 * w + 0.3 * X$x + fr)); cens <- runif(n, 0, quantile(t, 0.85))
	y <- pmin(t, cens); dead <- as.numeric(t <= cens)
	des$add_all_subject_responses(ifelse(dead == 1, y, NA), ifelse(dead == 0, y, NA), ifelse(dead == 0, Inf, NA))
	d <- data.frame(y = y, dead = dead, w = w, x = X$x, m = m)
	d$cl <- as.integer(factor(ifelse(d$m > 0, d$m, max(d$m) + seq_along(d$m))))
	list(des = des, d = d)
}

test_that("the class' treatment coefficient agrees with the frailty kernel on independently assembled data", {
	f <- fx()
	Xw <- cbind(w = f$d$w, 1, x = f$d$x)
	ker <- K("fast_weibull_frailty_cpp")(Xw, f$d$y, f$d$dead, f$d$cl, n_gh = 40L)
	inf <- K("InferenceSurvivalGLMMWeibullFrailtyNormalOneLik")$new(f$des, verbose = FALSE)
	expect_true(ker$converged)
	expect_equal(unname(inf$compute_estimate()), as.numeric(ker$b)[1], tolerance = 2e-2, scale = 1)
	expect_identical(inf$.__enclos_env__$private$optimization_alg, "lbfgs")
})

test_that("the class' fitted frailty scale is finite and not collapsed; sign follows the AFT convention", {
	f <- fx()
	inf <- K("InferenceSurvivalGLMMWeibullFrailtyNormalOneLik")$new(f$des, verbose = FALSE)
	e <- inf$compute_estimate()
	mod <- inf$.__enclos_env__$private$cached_mod
	expect_true(is.finite(as.numeric(mod$log_sigma_u)) && as.numeric(mod$log_sigma_u) > -2.5)
	expect_lt(e, 0)                                                # treatment shortens survival time here (AFT coefficient < 0)
	expect_lt(unname(coef(survival::survreg(survival::Surv(y, dead) ~ w + x, data = f$d))["w"]), 0)
	expect_equal(e, unname(coef(survival::survreg(survival::Surv(y, dead) ~ w + x, data = f$d))["w"]), tolerance = 0.15, scale = 1)
})
