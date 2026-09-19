library(testthat)
library(EDI)

# .extract_se_from_rq_fit() (helper_matching.R) extracts a quantreg standard
# error, preferring se="nid" and falling back to se="iid" when the nid result
# is non-finite, non-positive, or exceeds EDI_SEPARATION_THRESHOLD; returns
# NA_real_ if both are unusable or the coefficient name isn't present. Zero
# prior test references anywhere -- confirmed via repo-wide grep.

test_that(".extract_se_from_rq_fit reproduces quantreg's own nid SE on a well-conditioned fit", {
	set.seed(1)
	n <- 60L
	x <- rnorm(n)
	y <- 1 + 2 * x + rnorm(n, sd = 0.5)
	fit <- quantreg::rq(y ~ x, tau = 0.5)

	ref <- summary(fit, se = "nid")$coefficients["x", "Std. Error"]
	expect_equal(EDI:::.extract_se_from_rq_fit(fit, "x"), ref, tolerance = 1e-10)
})

test_that(".extract_se_from_rq_fit returns NA_real_ when the coefficient name is absent", {
	set.seed(2)
	n <- 40L
	x <- rnorm(n)
	y <- rnorm(n)
	fit <- quantreg::rq(y ~ x, tau = 0.5)

	expect_identical(EDI:::.extract_se_from_rq_fit(fit, "nonexistent_coef"), NA_real_)
})

test_that(".extract_se_from_rq_fit falls back to se='iid' when the nid SE is non-finite, non-positive, or beyond the separation threshold", {
	# summary.fakerq_bad is dispatched generically by .extract_se_from_rq_fit's
	# own summary(fit, se=...) call -- no package internals are touched, this
	# exercises the real fallback branching via S3 dispatch on a stand-in object.
	make_fake_fit <- function(nid_se) {
		structure(list(nid_se = nid_se), class = "fakerq_bad")
	}
	summary.fakerq_bad <<- function(object, se = "nid", ...) {
		val <- if (se == "nid") object$nid_se else 0.3
		list(coefficients = matrix(c(1, val), nrow = 1, dimnames = list("x", c("Value", "Std. Error"))))
	}
	on.exit(rm(summary.fakerq_bad, envir = .GlobalEnv), add = TRUE)

	# non-finite nid SE
	expect_equal(EDI:::.extract_se_from_rq_fit(make_fake_fit(NaN), "x"), 0.3)
	expect_equal(EDI:::.extract_se_from_rq_fit(make_fake_fit(Inf), "x"), 0.3)
	# non-positive nid SE
	expect_equal(EDI:::.extract_se_from_rq_fit(make_fake_fit(-1), "x"), 0.3)
	expect_equal(EDI:::.extract_se_from_rq_fit(make_fake_fit(0), "x"), 0.3)
	# beyond EDI_SEPARATION_THRESHOLD (1e6)
	expect_equal(EDI:::.extract_se_from_rq_fit(make_fake_fit(2e6), "x"), 0.3)
	# a normal nid SE is NOT overridden by the iid fallback
	expect_equal(EDI:::.extract_se_from_rq_fit(make_fake_fit(0.15), "x"), 0.15)
})

test_that(".extract_se_from_rq_fit returns NA_real_ when both nid and iid SEs are unusable", {
	summary.fakerq_both_bad <<- function(object, se = "nid", ...) {
		list(coefficients = matrix(c(1, NaN), nrow = 1, dimnames = list("x", c("Value", "Std. Error"))))
	}
	on.exit(rm(summary.fakerq_both_bad, envir = .GlobalEnv), add = TRUE)
	fit <- structure(list(), class = "fakerq_both_bad")

	expect_identical(EDI:::.extract_se_from_rq_fit(fit, "x"), NA_real_)
})

test_that(".extract_se_from_rq_fit returns NA_real_ when summary() itself errors on both attempts", {
	summary.fakerq_erroring <<- function(object, se = "nid", ...) stop("boom")
	on.exit(rm(summary.fakerq_erroring, envir = .GlobalEnv), add = TRUE)
	fit <- structure(list(), class = "fakerq_erroring")

	expect_identical(EDI:::.extract_se_from_rq_fit(fit, "x"), NA_real_)
})
