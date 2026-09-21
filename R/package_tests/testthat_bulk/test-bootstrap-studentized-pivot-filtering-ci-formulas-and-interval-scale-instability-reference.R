library(testthat)
library(EDI)

# helper_bootstrap_ci.R studentized helpers: bootstrap_studentized_pivots (se floor, non-finite filtering, symmetric abs,
# too-few and unstable-pivot guards), bootstrap_ci_studentized / bootstrap_ci_symmetric_studentized (type-8 quantile
# formulas), bootstrap_ci_from_distribution (percentile / basic) and bootstrap_studentized_interval_scale_unstable
# (ci path, pivot path, short-sample and invalid-input branches). References: hand-computed quantile formulas.

Z <- function(x) get(x, envir = asNamespace("EDI"))
piv <- Z("bootstrap_studentized_pivots")
q8 <- function(x, p) stats::quantile(x, p, names = FALSE, type = 8)

set.seed(1); B <- 200L
theta <- rnorm(B, 1, 0.5); se <- runif(B, 0.3, 0.7); est <- 1.1; se_hat <- 0.5

test_that("pivots are (theta - est) / se for usable replicates, in order", {
	expect_equal(piv(theta, se, est, se_hat), (theta - est) / se)
	expect_equal(piv(theta, se, est, se_hat, symmetric = TRUE), abs((theta - est) / se))
})

test_that("non-finite theta / se and se below the floor are dropped", {
	th <- theta; s <- se
	th[1] <- NA; s[2] <- NA; s[3] <- Inf; th[4] <- Inf; s[5] <- 1e-12; s[6] <- 0; s[7] <- -1
	p <- piv(th, s, est, se_hat)
	keep <- setdiff(seq_len(B), 1:7)
	expect_equal(p, (th[keep] - est) / s[keep])
	# floor = max(eps, 1e-6 * se_hat, 1e-6 * median(se_pos)): se equal to the floor is dropped (strict >)
	ref_floor <- max(.Machine$double.eps, 1e-6 * se_hat, 1e-6 * median(s[is.finite(s) & s > 0]))
	s2 <- se; s2[10] <- ref_floor; expect_length(piv(theta, s2, est, se_hat), B - 1L)
})

test_that("guards: no positive se / bad se_hat, too few usable samples, unstable pivots", {
	expect_error(piv(theta, rep(0, B), est, se_hat), "finite positive standard errors")
	expect_error(piv(theta, se, est, 0), "finite positive standard errors")
	expect_error(piv(theta, se, est, NA_real_), "finite positive standard errors")
	th <- theta; th[10:B] <- NA
	expect_error(piv(th, se, est, se_hat), "too few stable standard errors")
	expect_length(piv(th, se, est, se_hat, min_number_usable_samples = 5L), 9L)
	# 97.5% |pivot| above 50 -> unstable
	expect_error(piv(theta * 1000, se, est, se_hat), "numerically unstable")
})

test_that("studentized CI = est - q_{1-a/2, a/2}(pivots) * se_hat; symmetric CI = est -/+ q_{1-a}(|pivots|) * se_hat", {
	boot <- list(theta = theta, se = se); p <- (theta - est) / se
	for (a in c(0.1, 0.05, 0.01)) {
		ci <- Z("bootstrap_ci_studentized")(boot, a, est, se_hat)
		expect_equal(ci, c(est - q8(p, 1 - a / 2) * se_hat, est - q8(p, a / 2) * se_hat))
		sy <- Z("bootstrap_ci_symmetric_studentized")(boot, a, est, se_hat)
		w <- q8(abs(p), 1 - a) * se_hat
		expect_equal(sy, c(est - w, est + w))
		expect_lt(ci[1], ci[2])
	}
})

test_that("percentile and basic bootstrap intervals use type-8 quantiles; basic needs an estimate", {
	f <- Z("bootstrap_ci_from_distribution")
	expect_equal(f(theta, 0.05, "percentile"), q8(theta, c(0.025, 0.975)))
	expect_equal(f(theta, 0.1, "PERCENTILE"), q8(theta, c(0.05, 0.95)))
	expect_equal(f(theta, 0.05, "basic", est = est), 2 * est - q8(theta, c(0.975, 0.025)))
	expect_error(f(theta, 0.05, "basic"), "require an estimate")
})

test_that("interval scale instability: ci path compares width with max_width_ratio * theta spread", {
	u <- Z("bootstrap_studentized_interval_scale_unstable")
	w <- diff(q8(theta, c(0.025, 0.975)))
	expect_false(u(theta, ci = c(1 - w, 1 + w)))                       # width 2w < 5w
	expect_true(u(theta, ci = c(1 - 4 * w, 1 + 4 * w)))                # width 8w > 5w
	expect_true(u(theta, ci = c(1 - 2 * w, 1 + 2 * w), max_width_ratio = 3))
	expect_false(u(theta, ci = c(NA, 1)))                              # non-finite ci -> not flagged
	expect_false(u(theta, ci = 1))                                     # too short
	expect_false(u(theta[1:4], ci = c(-100, 100)))                      # fewer than 5 finite theta
	expect_false(u(c(theta[1:4], NA, NA), ci = c(-100, 100)))
})

test_that("interval scale instability: pivot path uses 2 * q_{1-a/2}(|pivots|) * se_hat and validates inputs", {
	u <- Z("bootstrap_studentized_interval_scale_unstable")
	p <- (theta - est) / se
	scale_ref <- max(diff(q8(theta, c(0.025, 0.975))), 1e-8, 1e-3 * max(1, abs(est)))
	width <- 2 * q8(abs(p), 0.975) * se_hat
	expect_identical(u(theta, pivots = p, se_hat = se_hat, est = est), width > 5 * scale_ref)
	expect_true(u(theta, pivots = p * 100, se_hat = se_hat, est = est))
	expect_false(u(theta, pivots = NULL, se_hat = se_hat))
	expect_false(u(theta, pivots = p, se_hat = 0))
	expect_false(u(theta, pivots = p[1:4], se_hat = se_hat))
})

test_that("a degenerate (constant) theta uses the 1e-8 / est-scaled reference and still returns a logical", {
	u <- Z("bootstrap_studentized_interval_scale_unstable")
	expect_true(u(rep(2, 20), ci = c(0, 4)))       # width 4 > 5 * max(1e-8, 1e-3 * 2)
	expect_false(u(rep(2, 20), ci = c(2, 2.005)))
})
