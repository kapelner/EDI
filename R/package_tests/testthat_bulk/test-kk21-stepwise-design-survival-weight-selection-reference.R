library(testthat)
library(EDI)

# Completes the DesignSeqOneByOneKK21stepwise compute_weights_KK21stepwise_*
# family started in test-kk21-stepwise-design-generic-weight-selection-reference.R
# (continuous/incidence/proportion) and
# test-kk21-stepwise-design-count-and-ordinal-weight-selection-reference.R
# (count/ordinal). compute_weights_KK21stepwise_survival, reachable via
# compute_weights() for response_type = "survival" (there is no speedup-toggle
# gate for survival, unlike count/proportion/ordinal), had zero test
# references anywhere before this file.

test_that("compute_weights_KK21stepwise_survival matches an independent survival::survreg(dist='weibull') stepwise reference", {
	set.seed(20)
	n <- 60L
	x1 <- rnorm(n)
	w <- rep(0:1, n / 2L)
	lp <- 0.4 * x1
	event_time <- rweibull(n, shape = 1.5, scale = exp(lp))
	cens_time <- rexp(n, rate = 0.05)
	y <- pmin(event_time, cens_time)
	dead <- as.integer(event_time <= cens_time)

	des <- EDI:::DesignSeqOneByOneKK21stepwise$new(n = 6L, response_type = "survival")
	priv <- des$.__enclos_env__$private
	X <- cbind(x1 = x1)
	actual <- priv$compute_weights_KK21stepwise_survival(X, y, w, dead)

	df <- data.frame(X, w = w)
	# Independent reference: fit survival::survreg() directly (bypassing the
	# package's own robust_survreg_with_surv_object warm-start/retry
	# machinery) with default init. With well-conditioned simulated data both
	# converge to the same weibull AFT MLE.
	ref_mod <- survival::survreg(survival::Surv(y, dead) ~ ., data = df, dist = "weibull")
	ref <- abs(summary(ref_mod)$table[2, 3])

	expect_equal(as.numeric(actual), ref, tolerance = 1e-3)
})

test_that("compute_weights_KK21stepwise_survival's non-weibull dist branch matches an independent survreg(dist='lognormal') stepwise reference", {
	set.seed(21)
	n <- 60L
	x1 <- rnorm(n)
	w <- rep(0:1, n / 2L)
	lp <- 0.5 * x1
	event_time <- rlnorm(n, meanlog = lp, sdlog = 0.6)
	cens_time <- rexp(n, rate = 0.03)
	y <- pmin(event_time, cens_time)
	dead <- as.integer(event_time <= cens_time)

	des <- EDI:::DesignSeqOneByOneKK21stepwise$new(n = 6L, response_type = "survival")
	priv <- des$.__enclos_env__$private
	X <- cbind(x1 = x1)

	# compute_weights_KK21stepwise_survival tries dist in c("weibull",
	# "lognormal", "loglogistic") in order per step and keeps the first that
	# yields a valid >= 2-row summary table with no NaNs; call the private
	# per-dist wrapper (robust_survreg_with_surv_object) directly with
	# dist = "lognormal" to check that specific branch's arithmetic, since
	# forcing the overall dispatcher past a successful weibull fit isn't
	# controllable from the public data alone.
	surv_obj <- survival::Surv(y, dead)
	actual_mod <- EDI:::robust_survreg_with_surv_object(surv_obj, X, dist = "lognormal")
	actual <- abs(summary(actual_mod)$table[2, 3])

	df <- data.frame(X, w = w)
	ref_mod <- survival::survreg(survival::Surv(y, dead) ~ x1, data = df, dist = "lognormal")
	ref <- abs(summary(ref_mod)$table[2, 3])

	expect_equal(actual, ref, tolerance = 1e-3)
})
