library(testthat)
library(EDI)

# get_restricted_mean_se_for_group(y, dead) equals survival::survfit's se(rmean) truncated at the group's own
# maximum time; get_restricted_mean_se_diff adds the two groups' SEs in quadrature (per-group truncation).

G <- get("get_restricted_mean_se_for_group", envir = asNamespace("EDI"))
D <- get("get_restricted_mean_se_diff", envir = asNamespace("EDI"))
sf_se <- function(y, d) summary(survival::survfit(survival::Surv(y, d) ~ 1), rmean = max(y))$table[["se(rmean)"]]

test_that("group SE equals survfit se(rmean) at tau = max time across random censored samples, including ties", {
	set.seed(1)
	for (i in 1:25) {
		n <- sample(8:40, 1); y <- round(rexp(n), sample(1:2, 1)) + 0.1; d <- rbinom(n, 1, 0.7)
		if (sum(d) == 0L) d[1] <- 1L
		expect_equal(G(y, as.integer(d)), sf_se(y, d), tolerance = 1e-9, info = i)
	}
})

test_that("degenerate groups: empty is NA, no events is zero variance, all-events single subject is zero", {
	expect_true(is.na(G(numeric(0), integer(0))))
	expect_equal(G(c(1, 2, 3), c(0L, 0L, 0L)), 0)
	expect_equal(G(5, 1L), 0)
})

test_that("the SE is invariant to input order and to a common time rescale (scales linearly)", {
	set.seed(2); y <- rexp(20) + 0.05; d <- rbinom(20, 1, 0.6); d[1] <- 1L
	base <- G(y, as.integer(d)); o <- sample(20)
	expect_equal(G(y[o], as.integer(d[o])), base)
	expect_equal(G(3 * y, as.integer(d)), 3 * base, tolerance = 1e-10)
})

test_that("NaN times are rejected", {
	expect_error(G(c(1, NaN, 2), c(1L, 1L, 0L)), "NA/NaN event times")
})

test_that("difference SE is the quadrature sum of the per-arm SEs, invariant to row order", {
	set.seed(3)
	for (i in 1:10) {
		n <- 40; w <- rep(0:1, length.out = n); y <- rexp(n) + 0.05; d <- rbinom(n, 1, 0.7); d[1:2] <- 1L
		ref <- sqrt(sf_se(y[w == 1], d[w == 1])^2 + sf_se(y[w == 0], d[w == 0])^2)
		expect_equal(D(y, as.integer(d), as.integer(w)), ref, tolerance = 1e-9)
		o <- sample(n); expect_equal(D(y[o], as.integer(d[o]), as.integer(w[o])), ref, tolerance = 1e-9)
	}
})

test_that("an empty arm makes the difference SE NA", {
	expect_true(is.na(D(c(1, 2, 3), c(1L, 1L, 0L), c(1L, 1L, 1L))))
})
