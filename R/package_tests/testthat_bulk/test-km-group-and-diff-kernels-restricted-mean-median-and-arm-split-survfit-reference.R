library(testthat)
library(EDI)

# get_survival_stat_for_group(y, dead, stat) / get_survival_stat_diff(y, dead, w, stat): Kaplan-Meier median and
# restricted mean (truncated at the group's largest observed time, censored or not). References: survival::survfit
# (median from the KM curve, rmean via summary(rmean = tau)) and a hand-integrated KM step function. The diff is
# treated minus control with w == 0 control and any other value treated; NA when either arm's statistic is NA;
# unknown stat names and empty groups give NA.

skip_if_not_installed("survival")
G <- get("get_survival_stat_for_group", envir = asNamespace("EDI"))
D <- get("get_survival_stat_diff", envir = asNamespace("EDI"))
set.seed(51)
# times are integer multiples of 0.1 built as k / 10 so that ties are bit-identical (survfit merges times within a
# floating-point tolerance, the kernel compares exact doubles; round(x, 1) + 0.1 produced 1.9 vs 1.9000000000000001)
mk <- function(n) { t <- (round(rexp(n, 0.3) * 10) + 1) / 10; c <- round(runif(n, 10, 80)) / 10; list(y = pmin(t, c), dead = as.integer(t <= c)) }
km_rmst <- function(y, dead, tau = max(y)) {
	fit <- survival::survfit(survival::Surv(y, dead) ~ 1)
	unname(summary(fit, rmean = tau)$table["rmean"])
}
hand_rmst <- function(y, dead, tau = max(y)) {
	ev <- sort(unique(y[dead == 1 & y < tau])); s <- 1; tt <- 0; ss <- 1
	for (t in ev) { s <- s * (1 - sum(y == t & dead == 1) / sum(y >= t)); tt <- c(tt, t); ss <- c(ss, s) }
	sum(ss * diff(c(tt, tau)))
}

test_that("restricted mean equals survfit's rmean truncated at the largest observed time and a hand-integrated KM curve", {
	for (i in 1:5) {
		d <- mk(30 + 5 * i)
		expect_equal(G(d$y, d$dead, "restricted_mean"), km_rmst(d$y, d$dead), tolerance = 1e-9, info = as.character(i))
		expect_equal(G(d$y, d$dead, "restricted_mean"), hand_rmst(d$y, d$dead), tolerance = 1e-10, info = as.character(i))
	}
})

test_that("median equals the first time the KM curve reaches 0.5 (survfit median), NA when it never does", {
	d <- mk(60)
	sf <- survival::survfit(survival::Surv(d$y, d$dead) ~ 1)
	s <- summary(sf)
	first <- s$time[which(s$surv <= 0.5)[1]]
	expect_equal(G(d$y, d$dead, "median"), first, tolerance = 1e-12)
	expect_true(is.na(G(c(1, 2, 3, 4), c(1L, 0L, 0L, 0L), "median")))         # S(t) stays above 0.5
})

test_that("no events: restricted mean equals the horizon itself (S stays at 1 throughout) and median is NA", {
	expect_true(is.na(G(c(2, 3, 5), c(0L, 0L, 0L), "median")))
	# 2026-10-08: unique_times/survival_probs are always seeded with the
	# initial (0, S=1) point before the event loop runs; with zero events
	# that point is the only one, so rmst_from_km() correctly integrates
	# S=1 across the full [0, tau) horizon, returning tau (= max(y) = 5)
	# -- not 0. The old restricted_mean branch's loop bounds (`i < size-1`
	# with a single-element unique_times) never executed, silently
	# returning the untouched 0.0 initializer -- a pre-existing bug fixed
	# by consolidating through the shared rmst_from_km() helper (commit
	# 288e6643), not a behavior this test should keep pinning.
	rm0 <- G(c(2, 3, 5), c(0L, 0L, 0L), "restricted_mean")
	expect_equal(rm0, 5)
})

test_that("unknown statistic names and empty groups return NA", {
	expect_true(is.na(G(c(1, 2, 3), c(1L, 1L, 0L), "mean")))
	expect_true(is.na(G(numeric(0), integer(0), "median")))
})

test_that("the diff is the treated minus control statistic and honours the arm split", {
	set.seed(52)
	d <- mk(80); w <- rep(0:1, length.out = 80L)
	# 2026-10-08: D's restricted_mean now truncates both arms at one shared
	# horizon (the smaller of their own maxima), while G keeps its own-
	# horizon-only contract -- see fast_survival_stats.cpp's shared_tau
	# plumbing (commit 288e6643). So D(..., "restricted_mean") is no longer
	# simply G(treated) - G(control); it must be independently recomputed
	# at the shared horizon via hand_rmst(), not via G at all.
	expect_equal(D(d$y, d$dead, w, "median"), G(d$y[w == 1], d$dead[w == 1], "median") - G(d$y[w == 0], d$dead[w == 0], "median"), tolerance = 1e-12)
	shared_tau <- min(max(d$y[w == 1]), max(d$y[w == 0]))
	expect_equal(
		D(d$y, d$dead, w, "restricted_mean"),
		hand_rmst(d$y[w == 1], d$dead[w == 1], shared_tau) - hand_rmst(d$y[w == 0], d$dead[w == 0], shared_tau),
		tolerance = 1e-9
	)
	w2 <- w; w2[w2 == 1L] <- 5L                                   # any non-zero value is treated
	expect_equal(D(d$y, d$dead, w2, "restricted_mean"), D(d$y, d$dead, w, "restricted_mean"))
	expect_equal(D(d$y, d$dead, 1L - w, "restricted_mean"), -D(d$y, d$dead, w, "restricted_mean"), tolerance = 1e-12)
	y <- c(1, 2, 3, 4, 5, 6); dead <- c(1L, 1L, 1L, 0L, 0L, 0L); wv <- c(1L, 1L, 1L, 0L, 0L, 0L)
	expect_true(is.na(D(y, dead, wv, "median")))                    # control arm has no events -> NA median
})
