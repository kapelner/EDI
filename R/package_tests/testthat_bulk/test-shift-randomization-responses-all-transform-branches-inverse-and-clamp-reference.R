library(testthat)
library(EDI)

# shift_randomization_responses(y, w, delta, transform_responses, response_type, inverse, zero_one_logit_clamp):
# the sharp-null shift applied to treated rows only. Branches: delta = 0 / no treated (unchanged), "logit"
# (inv_logit(logit(y) + d)), "log" for survival / other (multiplicative exp(d)), "log" for count (multiplicative, rounded to
# integers) and the default additive shift; inverse = TRUE negates delta. Reference: the formulas evaluated in R.

mk <- function() {
	set.seed(1); n <- 20L
	d <- DesignFixedBernoulli$new(response_type = "continuous", n = n, seed = 1L, verbose = FALSE)
	d$add_all_subjects_to_experiment(data.frame(x = rnorm(n))); d$assign_w_to_all_subjects()
	d$add_all_subject_responses(rnorm(n) + d$get_w())
	InferenceContinOLS$new(d, verbose = FALSE)$.__enclos_env__$private
}
p <- mk()
sh <- function(y, w, delta, tr, rt, inverse = FALSE, clamp = .Machine$double.eps) p$shift_randomization_responses(y, w, delta, tr, rt, inverse = inverse, zero_one_logit_clamp = clamp)
logit <- function(x) log(x / (1 - x)); expit <- function(x) 1 / (1 + exp(-x))
w <- rep(c(1L, 0L), 6)

test_that("delta zero and an all-control assignment leave the responses untouched for every transform", {
	y <- seq(0.1, 0.9, length.out = 12)
	for (tr in c("none", "logit", "log")) for (rt in c("continuous", "count", "survival", "proportion")) {
		expect_identical(sh(y, w, 0, tr, rt), y)
		expect_identical(sh(y, rep(0L, 12), 0.7, tr, rt), y)
	}
})

test_that("default transform: additive shift on treated rows only; inverse subtracts", {
	y <- c(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12)
	expect_equal(sh(y, w, 0.5, "none", "continuous"), y + 0.5 * w)
	expect_equal(sh(y, w, 0.5, "none", "continuous", inverse = TRUE), y - 0.5 * w)
	expect_equal(sh(sh(y, w, 0.5, "none", "continuous"), w, 0.5, "none", "continuous", inverse = TRUE), y)
	expect_equal(sh(y, w, -2, "none", "count"), y - 2 * w)                          # no transform: count shifts additively too
})

test_that("logit transform: shift on the log-odds scale for treated rows; inverse round-trips", {
	y <- seq(0.05, 0.95, length.out = 12)
	got <- sh(y, w, 0.8, "logit", "proportion")
	ref <- y; ref[w == 1] <- expit(logit(y[w == 1]) + 0.8)
	expect_equal(got, ref, tolerance = 1e-10)
	expect_identical(got[w == 0], y[w == 0])
	expect_equal(sh(got, w, 0.8, "logit", "proportion", inverse = TRUE), y, tolerance = 1e-8)
	expect_true(all(got > 0 & got < 1))
})

test_that("logit transform clamps boundary responses instead of producing infinities", {
	y <- c(0, 1, 0.5, 0.5); ww <- c(1L, 1L, 1L, 0L)
	got <- sh(y, ww, 1, "logit", "proportion", clamp = 1e-6)
	expect_true(all(is.finite(got))); expect_true(all(got > 0 & got < 1))
	expect_identical(got[4], 0.5)
})

test_that("log transform: multiplicative exp(delta) for survival and other non-count types", {
	y <- seq(1, 12, length.out = 12)
	for (rt in c("survival", "continuous", "proportion", "ordinal")) {
		expect_equal(sh(y, w, 0.3, "log", rt), ifelse(w == 1, y * exp(0.3), y), info = rt)
		expect_equal(sh(y, w, 0.3, "log", rt, inverse = TRUE), ifelse(w == 1, y * exp(-0.3), y), info = rt)
	}
})

test_that("log transform for counts: multiplicative then rounded to integer counts on treated rows", {
	y <- c(0L, 1L, 2L, 3L, 5L, 8L, 13L, 21L, 4L, 6L, 7L, 9L)
	got <- sh(y, w, 0.4, "log", "count")
	expect_equal(got[w == 1], as.integer(round(y[w == 1] * exp(0.4))))
	expect_identical(got[w == 0], as.integer(y[w == 0]) + 0L)
	expect_equal(as.numeric(got), as.numeric(ifelse(w == 1, round(y * exp(0.4)), y)))
	inv <- sh(y, w, 0.4, "log", "count", inverse = TRUE)
	expect_equal(inv[w == 1], as.integer(round(y[w == 1] * exp(-0.4))))
})
