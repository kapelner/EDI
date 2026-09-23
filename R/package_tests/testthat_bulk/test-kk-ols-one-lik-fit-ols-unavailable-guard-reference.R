library(testthat)
library(EDI)

# InferenceContinKKOLSOneLik's private fit_ols() (inference_continuous_KK_ols_one_lik.R) is the OLS
# fitter behind the combined matched/reservoir likelihood: returns NULL if the design is not
# over-determined (nrow(X) <= ncol(X)) or if lm.fit() errors or gives a non-finite/missing treatment
# coefficient. shared() then caches "ols_fit_unavailable" when fit_ols() returns NULL. Neither
# fit_ols()'s own degenerate branches nor this end-to-end wiring had any test reference anywhere.
# Reached via InferenceContinKKOLSOneLik, a non-IVWC concrete host of the shared KK-compound
# machinery (the IVWC compound estimators are out of scope for this suite).

test_that("fit_ols returns NULL when the design isn't over-determined (nrow(X) <= ncol(X))", {
	set.seed(1); n <- 20L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	des$add_all_subject_responses(rnorm(n) + des$get_w())
	p <- InferenceContinKKOLSOneLik$new(des, verbose = FALSE)$.__enclos_env__$private

	Xbad <- matrix(rnorm(6), 2, 3)  # 2 rows, 3 columns
	expect_null(p$fit_ols(Xbad, rnorm(2), j_treat = 1L))
})

test_that("fit_ols returns NULL for a collinear design giving a non-finite treatment coefficient", {
	set.seed(2); n <- 20L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	des$add_all_subject_responses(rnorm(n) + des$get_w())
	p <- InferenceContinKKOLSOneLik$new(des, verbose = FALSE)$.__enclos_env__$private

	Xcoll <- cbind(1, rep(1, 10), rnorm(10))  # column 2 collinear with the intercept
	expect_null(p$fit_ols(Xcoll, rnorm(10), j_treat = 2L))

	# independent reference: lm.fit on the same design aliases (NA) the same coefficient
	fit_ref <- stats::lm.fit(Xcoll, rnorm(10))
	expect_true(is.na(stats::coef(fit_ref)[2]))
})

test_that("shared() caches 'ols_fit_unavailable' end-to-end when fit_ols() fails", {
	set.seed(3); n <- 20L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	des$add_all_subject_responses(rnorm(n) + des$get_w())

	inf <- InferenceContinKKOLSOneLik$new(des, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	unlockBinding("fit_ols", p)
	p$fit_ols <- function(...) NULL

	res <- inf$compute_estimate()
	expect_true(is.na(res))
	expect_identical(inf$get_nonestimable_reason(), "ols_fit_unavailable")
})
