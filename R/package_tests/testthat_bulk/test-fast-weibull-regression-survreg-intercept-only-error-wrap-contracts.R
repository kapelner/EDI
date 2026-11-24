# Untested-code audit, 2026-11-24: covers R/EDI/R/helper_glm_fit.R:1085-1087
# (fast_weibull_regression; region unt-525e539e9c6e).
# Reference: survival::survreg(Surv(y, dead) ~ 1, dist = 'weibull') raises its own error on the same
# data; the wrapper's documented message is that text prefixed with 'Weibull regression (survreg)
# failed: '.
# Verified on commit f52f53392559 under pkgload::load_all(compile = FALSE): passed; executed 3 of 3
# target lines (5.6 s).

library(testthat)
library(EDI)

test_that("survreg-path intercept-only Weibull fit re-raises survreg's error with the documented prefix", {
	y = c(0, 1.2, 0.7, 2.5, 3.1, 0.4, 1.9, 2.2)
	dead = rep(1, length(y))
	# Independent reference: survival::survreg's own error on the same intercept-only data.
	ref_msg = tryCatch({
		survival::survreg(survival::Surv(y, dead) ~ 1, dist = "weibull")
		NA_character_
	}, error = function(e) conditionMessage(e))
	expect_false(is.na(ref_msg))
	expect_false(grepl("converge", ref_msg, ignore.case = TRUE))
	err = tryCatch(
		EDI:::fast_weibull_regression(y, dead, matrix(numeric(0), nrow = length(y), ncol = 0), use_rcpp = FALSE),
		error = function(e) e
	)
	expect_s3_class(err, "error")
	expect_identical(conditionMessage(err), paste0("Weibull regression (survreg) failed: ", ref_msg))
})
