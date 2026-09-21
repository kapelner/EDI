library(testthat)
library(EDI)

# InferenceContinKKRobustRegrOneLik private helpers: resolve_rlm_control(X) (maxit / acc defaults by column count and the
# OLS-start flag, user overrides win, integer/double coercion) and is_rlm_nonconvergence_warning(w) (matches MASS::rlm's
# non-convergence warning texts only). Hand-listed default table as the reference.

mk <- function() {
	set.seed(108); n <- 40L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	for (i in seq_len(n)) {
		x <- data.frame(x1 = rnorm(1), x2 = rnorm(1)); w <- des$add_one_subject_to_experiment_and_assign(x)
		des$add_one_subject_response(i, 0.4 * w + rnorm(1))
	}
	inf <- InferenceContinKKRobustRegrOneLik$new(des, verbose = FALSE)
	inf$.__enclos_env__$private
}
p <- mk()
X <- function(k) matrix(0, 5, k)

test_that("OLS-start defaults: maxit 10 / 15 / 20 for p <= 3 / <= 10 / larger, acc 1e-4", {
	p$rlm_start_with_ols <- TRUE; p$rlm_maxit <- NULL; p$rlm_acc <- NULL
	for (cs in list(c(1, 10L), c(3, 10L), c(4, 15L), c(10, 15L), c(11, 20L), c(30, 20L))) {
		ctrl <- p$resolve_rlm_control(X(cs[1]))
		expect_identical(ctrl$maxit, as.integer(cs[2]), info = paste("p =", cs[1])); expect_identical(ctrl$acc, 1e-4)
	}
})

test_that("cold-start defaults (no OLS start): maxit 15 / 20 / 25, acc 1e-3", {
	p$rlm_start_with_ols <- FALSE; p$rlm_maxit <- NULL; p$rlm_acc <- NULL
	for (cs in list(c(2, 15L), c(3, 15L), c(4, 20L), c(10, 20L), c(11, 25L))) {
		ctrl <- p$resolve_rlm_control(X(cs[1]))
		expect_identical(ctrl$maxit, as.integer(cs[2]), info = paste("p =", cs[1])); expect_identical(ctrl$acc, 1e-3)
	}
})

test_that("user-supplied maxit and acc override the defaults independently and are coerced to integer / numeric", {
	p$rlm_start_with_ols <- TRUE
	p$rlm_maxit <- 7; p$rlm_acc <- NULL
	ctrl <- p$resolve_rlm_control(X(30)); expect_identical(ctrl$maxit, 7L); expect_identical(ctrl$acc, 1e-4)
	p$rlm_maxit <- NULL; p$rlm_acc <- 5e-6
	ctrl <- p$resolve_rlm_control(X(30)); expect_identical(ctrl$maxit, 20L); expect_identical(ctrl$acc, 5e-6)
	p$rlm_maxit <- 12L; p$rlm_acc <- 2L
	ctrl <- p$resolve_rlm_control(X(1)); expect_identical(ctrl$maxit, 12L); expect_identical(ctrl$acc, 2)
	expect_type(ctrl$maxit, "integer"); expect_type(ctrl$acc, "double")
	p$rlm_maxit <- NULL; p$rlm_acc <- NULL; p$rlm_start_with_ols <- TRUE
})

test_that("a NULL start flag behaves as not OLS-start (isTRUE semantics)", {
	p$rlm_start_with_ols <- NULL; p$rlm_maxit <- NULL; p$rlm_acc <- NULL
	ctrl <- p$resolve_rlm_control(X(2)); expect_identical(ctrl$maxit, 15L); expect_identical(ctrl$acc, 1e-3)
	p$rlm_start_with_ols <- TRUE
})

test_that("non-convergence predicate matches the two MASS::rlm warning phrasings and nothing else", {
	f <- p$is_rlm_nonconvergence_warning
	expect_true(f(simpleWarning("'rlm' failed to converge in 20 steps")))
	expect_true(f(simpleWarning("some prefix: 'rlm' failed to converge")))
	expect_true(f(simpleWarning("alternation limit reached")))
	expect_true(f(simpleWarning("Warning: alternation limit reached in psi")))
	expect_false(f(simpleWarning("rlm failed to converge")))                       # quotes are part of the fixed pattern
	expect_false(f(simpleWarning("did not converge")))
	expect_false(f(simpleWarning("")))
	expect_false(f(simpleWarning("ALTERNATION LIMIT REACHED")))                    # case-sensitive
})

test_that("the predicate recognises the warning MASS::rlm actually emits when it cannot converge", {
	skip_if_not_installed("MASS")
	set.seed(3); d <- data.frame(y = c(rnorm(30), 50, -60, 80), x = c(rnorm(30), 1, 2, 3))
	w <- tryCatch(MASS::rlm(y ~ x, data = d, maxit = 1), warning = function(w) w)
	expect_s3_class(w, "warning")
	expect_match(conditionMessage(w), "'rlm' failed to converge")
	expect_true(p$is_rlm_nonconvergence_warning(w))
})
