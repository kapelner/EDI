# Untested-code audit, 2026-11-24: covers R/EDI/R/helper_glm_fit.R:1071-1073
# (fast_weibull_regression; region unt-64dacec1a245).
# Reference: survival::survreg's own error on the same data, and the documented contract at
# helper_glm_fit.R:1071-1073: a message that does not mention converging is re-raised as 'Weibull
# regression (survreg) failed: <survreg message>'.
# Verified on commit f52f53392559 under pkgload::load_all(compile = FALSE): passed; executed 3 of 3
# target lines (5.7 s).

library(testthat)
library(EDI)

test_that("survreg fallback re-raises a non-convergence survreg error with the '(survreg) failed:' prefix and survreg's own message", {
	set.seed(11L)
	n = 40L
	X = cbind(w = rep(0:1, n / 2L), x1 = rnorm(n))
	y = rexp(n, 0.2)
	y[1L] = 0  # log(0) = -Inf under the Weibull transform: survreg rejects the times
	dead = rep(1, n)

	# Independent reference: survreg's own error on the same data
	df = data.frame(w = X[, "w"], x1 = X[, "x1"], y = y, dead = dead)
	ref_msg = tryCatch({
		survival::survreg(survival::Surv(y, dead) ~ w + x1, data = df, dist = "weibull")
		NA_character_
	}, error = function(e) conditionMessage(e))
	expect_false(is.na(ref_msg))
	expect_false(grepl("converge", ref_msg, ignore.case = TRUE))

	edi_msg = tryCatch({
		EDI:::fast_weibull_regression(y, dead, X, use_rcpp = FALSE)
		NA_character_
	}, error = function(e) conditionMessage(e))
	expect_identical(edi_msg, paste0("Weibull regression (survreg) failed: ", ref_msg))
	expect_error(EDI:::fast_weibull_regression(y, dead, X, use_rcpp = FALSE),
		regexp = "Weibull regression \\(survreg\\) failed: ")
})
