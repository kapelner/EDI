library(testthat)
library(EDI)

# KK (matched pairs + reservoir) survival classes against survival-package constructions:
# InferenceSurvivalKKStratCoxPHOneLik = coxph(w + x + strata(pair id, reservoir pooled in one stratum)) -- estimate
# and model-based SE; InferenceSurvivalKKLWACoxPHOneLik = the marginal (Lin-Wei-Ying) coxph coefficient with the
# pair-clustered robust SE (coxph + cluster()); InferenceSurvivalKKWeibullMarginal = survreg's AFT coefficient with
# the pair-clustered robust SE. Pairs cluster together; each reservoir subject is its own cluster.

skip_if_not_installed("survival")
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
	d$cl <- ifelse(d$m > 0, d$m, max(d$m) + seq_along(d$m))
	d$s2 <- ifelse(d$m > 0, d$m, 0)
	list(des = des, d = d, S = survival::Surv(y, dead))
}
new_inf <- function(cls, des) K(cls)$new(des, verbose = FALSE)
cached <- function(inf) inf$.__enclos_env__$private$cached_values

test_that("the fixture has pairs and a reservoir", {
	f <- fx()
	expect_gt(max(f$d$m), 20L); expect_gt(sum(f$d$m == 0), 5L)
})

test_that("stratified-Cox one-likelihood class equals coxph with pair strata and one pooled reservoir stratum: estimate and SE", {
	f <- fx()
	ref <- summary(survival::coxph(f$S ~ w + x + strata(s2), data = f$d))$coefficients["w", ]
	inf <- new_inf("InferenceSurvivalKKStratCoxPHOneLik", f$des)
	expect_equal(unname(inf$compute_estimate()), unname(ref["coef"]), tolerance = 1e-6)
	expect_equal(cached(inf)$s_beta_hat_T, unname(ref["se(coef)"]), tolerance = 1e-4)
})

test_that("LWA Cox one-likelihood class equals the marginal coxph coefficient with the cluster-robust SE", {
	f <- fx()
	ref <- summary(survival::coxph(f$S ~ w + x + cluster(cl), data = f$d))$coefficients["w", ]
	inf <- new_inf("InferenceSurvivalKKLWACoxPHOneLik", f$des)
	expect_equal(unname(inf$compute_estimate()), unname(ref["coef"]), tolerance = 1e-6)
	expect_equal(cached(inf)$s_beta_hat_T, unname(ref["robust se"]), tolerance = 1e-4)
})

test_that("KK marginal Weibull class equals survreg's AFT coefficient with the cluster-robust SE", {
	f <- fx()
	tab <- summary(survival::survreg(f$S ~ w + x + cluster(cl), data = f$d))$table["w", ]
	inf <- new_inf("InferenceSurvivalKKWeibullMarginal", f$des)
	expect_equal(unname(inf$compute_estimate()), unname(tab["Value"]), tolerance = 1e-5)
	expect_equal(cached(inf)$s_beta_hat_T, unname(tab["Std. Err"]), tolerance = 1e-3)
})
