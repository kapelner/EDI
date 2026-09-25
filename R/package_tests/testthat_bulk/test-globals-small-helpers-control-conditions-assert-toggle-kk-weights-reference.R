library(testthat)
library(EDI)

# Small internal helpers in globals.R with no (or only partial) direct tests:
# is_edi_control_condition() (all four recognised conditions), the two
# "Bayesian bootstrap not implemented" stoppers, the assertion switch
# (toggle_asserts() / should_run_asserts() / the internal .assert_manager flag),
# kk_pair_and_reservoir_bootstrap_weights() edge cases against a hand-written
# split, weights_are_effectively_constant() thresholds.

E <- function(x) get(x, envir = asNamespace("EDI"))

test_that("control conditions: timeout/interrupt classes and the two time-limit messages, nothing else", {
	f <- E("is_edi_control_condition")
	expect_true(f(structure(class = c("TimeoutException", "error", "condition"), list(message = "x", call = NULL))))
	expect_true(f(structure(class = c("interrupt", "condition"), list(message = "", call = NULL))))
	expect_true(f(simpleError("Step reached elapsed time limit of 5s")))
	expect_true(f(simpleError("fit reached CPU time limit")))
	expect_false(f(simpleError("reached ELAPSED time limit")))          # case-sensitive, fixed match
	expect_false(f(simpleError("singular matrix")))
	expect_false(f(simpleCondition("plain condition")))
})

test_that("the Bayesian-bootstrap stoppers name the calling class, or a generic label without one", {
	ivwc <- E("stop_bayesian_bootstrap_for_ivwc"); bai <- E("stop_bayesian_bootstrap_for_bai")
	expect_error(ivwc(), "^This IVWC class does not support this Bayesian bootstrap operation\\. Implementation is missing for this IVWC path\\.$")
	expect_error(bai(), "^This Bai-adjusted KK class does not support this Bayesian bootstrap operation\\. Implementation is missing for this Bai path\\.$")
	obj <- structure(list(), class = c("MyFancyClass", "Other"))
	expect_error(ivwc(obj), "^MyFancyClass does not support")
	expect_error(bai(obj), "^MyFancyClass does not support")
	expect_error(bai(obj), "Bai path")
})

test_that("assert switching needs both the option and the internal flag", {
	old <- options(edi.run_asserts = NULL); on.exit(options(old), add = TRUE)
	sra <- E("should_run_asserts")
	expect_true(sra())                                                # option unset -> default TRUE
	expect_false(toggle_asserts(FALSE))
	expect_null(getOption("edi.run_asserts"))                         # CRAN: user's options untouched
	expect_false(sra())
	expect_true(toggle_asserts(TRUE))
	expect_true(sra())
	expect_false(toggle_asserts("yes"))                               # only exact TRUE enables
	expect_false(sra())
	toggle_asserts(TRUE)
	expect_identical(withVisible(toggle_asserts(TRUE))$visible, FALSE)

	mgr <- E(".assert_manager")
	options(edi.run_asserts = TRUE)
	on.exit(mgr$toggle(TRUE), add = TRUE)
	expect_false(mgr$toggle(FALSE))
	expect_false(sra())                                               # internal flag off although the option is on
	expect_true(mgr$toggle(TRUE))
	expect_true(sra())
})

test_that("kk_pair_and_reservoir_bootstrap_weights splits pairs (mean weight) from reservoir rows", {
	f <- E("kk_pair_and_reservoir_bootstrap_weights")
	w <- c(1, 3, 2, 6, 10, 20, 7)
	r <- f(list(m = c(2L, 2L, 1L, 1L, NA, 0L, 3L)), w)
	expect_equal(r$pair_ids, c(1L, 2L, 3L))
	expect_equal(r$pair_weights, c(mean(c(2, 6)), mean(c(1, 3)), 7))
	expect_equal(r$reservoir_idx, c(5L, 6L))
	expect_equal(r$reservoir_weights, c(10, 20))

	r0 <- f(list(m = NULL), c(1, 2, 3))                                # no matching info: everything is reservoir
	expect_length(r0$pair_ids, 0L); expect_length(r0$pair_weights, 0L)
	expect_equal(r0$reservoir_idx, 1:3); expect_equal(r0$reservoir_weights, c(1, 2, 3))

	rs <- f(list(m = c(1L, 1L)), c(5, 7, 9, 11))                       # short m is recycled to length n
	expect_equal(rs$pair_ids, 1L)
	expect_equal(rs$pair_weights, mean(c(5, 7, 9, 11)))
	expect_length(rs$reservoir_idx, 0L)

	rn <- f(list(m = c(1L, 1L, NA)), c(1, 3, 100))                     # NA weight mean uses na.rm within a pair
	expect_equal(f(list(m = c(1L, 1L)), c(NA, 4))$pair_weights, 4)
	expect_equal(rn$reservoir_weights, 100)
})

test_that("weights_are_effectively_constant is a relative, positive-finite-only test", {
	f <- E("weights_are_effectively_constant")
	expect_true(f(rep(2, 5)))
	expect_true(f(c(1, 1 + 1e-12)))
	expect_true(f(1e9 * c(1, 1 + 1e-12)))                              # relative, not absolute
	expect_false(f(c(1, 1.001)))
	expect_false(f(c(1, 1.001), tol = 1e-4))
	expect_true(f(c(1, 1.001), tol = 1e-2))
	expect_false(f(c(1, 0)))                                            # zero weight never "constant"
	expect_false(f(c(1, -1)))
	expect_false(f(c(1, NA)))
	expect_false(f(c(1, Inf)))
	expect_false(f(numeric(0)))
	expect_true(f(3))                                                   # a single positive weight
})
