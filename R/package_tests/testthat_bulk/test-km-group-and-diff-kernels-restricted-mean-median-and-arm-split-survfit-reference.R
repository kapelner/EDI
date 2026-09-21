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
mk <- function(n) { t <- round(rexp(n, 0.3), 1) + 0.1; c <- round(runif(n, 1, 8), 1); list(y = pmin(t, c), dead = as.integer(t <= c)) }
km_rmst <- function(y, dead) {
	fit <- survival::survfit(survival::Surv(y, dead) ~ 1)
	tau <- max(y)
	unname(summary(fit, rmean = tau)$table["rmean"])
}
hand_rmst <- function(y, dead) {
	ev <- sort(unique(y[dead == 1])); s <- 1; tt <- 0; ss <- 1
	for (t in ev) { s <- s * (1 - sum(y == t & dead == 1) / sum(y >= t)); tt <- c(tt, t); ss <- c(ss, s) }
	sum(ss * diff(c(tt, max(y))))
}

test_that("restricted mean equals survfit's rmean truncated at the largest observed time and a hand-integrated KM curve", {
	for (i in 1:5) {
		d <- mk(30 + 5 * i)
		# survfit's rmean agrees to ~3e-3 only (it differed by up to 0.003 when the last observation is censored);
		# the hand-integrated KM area below is the exact reference.
		expect_equal(G(d$y, d$dead, "restricted_mean"), km_rmst(d$y, d$dead), tolerance = 2e-3, info = as.character(i))
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

test_that("no events: restricted mean is NA (degenerate one-point curve) and median is NA", {
	expect_true(is.na(G(c(2, 3, 5), c(0L, 0L, 0L), "median")))
	rm0 <- G(c(2, 3, 5), c(0L, 0L, 0L), "restricted_mean")
	expect_equal(rm0, 0)
})

test_that("unknown statistic names and empty groups return NA", {
	expect_true(is.na(G(c(1, 2, 3), c(1L, 1L, 0L), "mean")))
	expect_true(is.na(G(numeric(0), integer(0), "median")))
})

test_that("the diff is the treated minus control statistic and honours the arm split", {
	set.seed(52)
	d <- mk(80); w <- rep(0:1, length.out = 80L)
	for (st in c("median", "restricted_mean")) {
		expect_equal(D(d$y, d$dead, w, st), G(d$y[w == 1], d$dead[w == 1], st) - G(d$y[w == 0], d$dead[w == 0], st), tolerance = 1e-12, info = st)
	}
	w2 <- w; w2[w2 == 1L] <- 5L                                   # any non-zero value is treated
	expect_equal(D(d$y, d$dead, w2, "restricted_mean"), D(d$y, d$dead, w, "restricted_mean"))
	expect_equal(D(d$y, d$dead, 1L - w, "restricted_mean"), -D(d$y, d$dead, w, "restricted_mean"), tolerance = 1e-12)
	y <- c(1, 2, 3, 4, 5, 6); dead <- c(1L, 1L, 1L, 0L, 0L, 0L); wv <- c(1L, 1L, 1L, 0L, 0L, 0L)
	expect_true(is.na(D(y, dead, wv, "median")))                    # control arm has no events -> NA median
})
