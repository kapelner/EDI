library(testthat)
library(EDI)

# KK (matched pairs + reservoir) continuous classes against independent constructions:
# InferenceContinKKOLSOneLik = ONE unweighted OLS on the stacked rows [pair differences: (0, 1, x_T - x_C) with
# response y_T - y_C] over [reservoir rows: (1, w, x) with response y]; InferenceContinKKQuantileRegrOneLik =
# median regression (quantreg::rq) on the same stack; InferenceContinKKRobustRegrOneLik is within 1% of
# MASS::rlm(MM) on it; InferenceContinKKGLMM equals lme4::lmer(REML = FALSE) with a random intercept per pair
# (singletons get their own level).

skip_if_not_installed("quantreg")
skip_if_not_installed("MASS")
K <- function(x) get(x, envir = asNamespace("EDI"))

fx <- function() {
	set.seed(4)
	n <- 60L
	des <- DesignSeqOneByOneKK14$new(response_type = "continuous", n = n, verbose = FALSE)
	X <- data.frame(x = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	m <- des$.__enclos_env__$private$m[seq_len(n)]
	y <- 1 + 0.7 * w + 0.4 * X$x + rnorm(n, 0, 0.5) + ifelse(m > 0, rnorm(max(m))[pmax(m, 1)], 0)
	des$add_all_subject_responses(y)
	d <- data.frame(y = y, w = w, x = X$x, m = m)
	pr <- d[d$m > 0, ]
	ids <- sort(unique(pr$m))
	dd <- t(vapply(ids, function(k) { a <- pr[pr$m == k, ]; t1 <- a[a$w == 1, ]; t0 <- a[a$w == 0, ]; c(t1$y - t0$y, t1$x - t0$x) }, numeric(2)))
	res <- d[d$m == 0, ]
	list(des = des, d = d, Xs = rbind(cbind(0, 1, dd[, 2]), cbind(1, res$w, res$x)), ys = c(dd[, 1], res$y),
		npairs = length(ids), nres = nrow(res))
}
new_inf <- function(cls, des) K(cls)$new(des, verbose = FALSE)

test_that("the fixture has both matched pairs and reservoir subjects with both arms", {
	f <- fx()
	expect_gt(f$npairs, 10L); expect_gt(f$nres, 5L)
	expect_true(all(c(0, 1) %in% f$d$w[f$d$m == 0]))
})

test_that("OLS one-likelihood class equals one unweighted OLS on the stacked pair-difference + reservoir design", {
	f <- fx()
	ref <- unname(coef(lm(f$ys ~ f$Xs - 1))[2])
	inf <- new_inf("InferenceContinKKOLSOneLik", f$des)
	expect_equal(unname(inf$compute_estimate()), ref, tolerance = 1e-8)
})

test_that("OLS one-likelihood SE is the HC2 sandwich SE of the stacked fit, with n - p residual degrees of freedom", {
	skip_if_not_installed("sandwich")
	f <- fx()
	st <- lm(f$ys ~ f$Xs - 1)
	inf <- new_inf("InferenceContinKKOLSOneLik", f$des)
	inf$compute_estimate(estimate_only = FALSE)
	pv <- inf$.__enclos_env__$private$cached_values
	expect_equal(pv$s_beta_hat_T, sqrt(sandwich::vcovHC(st, type = "HC2")[2, 2]), tolerance = 1e-8)
	expect_equal(pv$df, nrow(f$Xs) - ncol(f$Xs))
	# ... which differs from the classical homoskedastic SE.
	expect_gt(abs(pv$s_beta_hat_T - summary(st)$coefficients[2, 2]), 0.003)
})

test_that("quantile one-likelihood class equals median regression on the same stack; robust one-likelihood is close to rlm(MM)", {
	f <- fx()
	expect_equal(unname(new_inf("InferenceContinKKQuantileRegrOneLik", f$des)$compute_estimate()),
		unname(suppressWarnings(coef(quantreg::rq(f$ys ~ f$Xs - 1, tau = 0.5))[2])), tolerance = 1e-5)
	expect_equal(unname(new_inf("InferenceContinKKRobustRegrOneLik", f$des)$compute_estimate()),
		unname(coef(MASS::rlm(f$ys ~ f$Xs - 1, method = "MM"))[2]), tolerance = 1e-2)
})

test_that("KK GLMM class equals lmer with a random intercept per pair (singletons on their own level)", {
	skip_if_not_installed("lme4")
	f <- fx()
	d <- f$d
	d$g <- ifelse(d$m > 0, paste0("p", d$m), paste0("s", seq_along(d$m)))
	fit <- suppressMessages(lme4::lmer(y ~ w + x + (1 | g), data = d, REML = FALSE))
	expect_equal(unname(new_inf("InferenceContinKKGLMM", f$des)$compute_estimate()), unname(lme4::fixef(fit)["w"]), tolerance = 2e-3)
})
