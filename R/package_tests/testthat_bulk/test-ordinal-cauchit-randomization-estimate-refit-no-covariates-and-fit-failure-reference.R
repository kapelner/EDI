library(testthat)
library(EDI)

# InferenceOrdinalCauchitRegr's compute_treatment_estimate_during_randomization_inference()
# (inference_ordinal_cauchit.R) had no test reference anywhere -- the same gap pattern already closed
# this session on several sibling classes, including the sign-flipped InferenceOrdinalCloglogRegr
# sibling (this class's own source comment explicitly notes res$b[1] here needs NO negation, unlike
# cloglog's -res$b[1]).
#   1. The covariate-adjusted refit on the current (and then a permuted) w matches an independent
#      MASS::polr(method = "cauchit") fit.
#   2. With no prior column selection (best_X_colnames still NULL), it calls shared() first.
#   3. With no covariates selected (model_formula = ~1), X = matrix(w, ncol = 1, dimnames = list(NULL,
#      "treatment")) rather than including covariate columns.
#   4. A fitter failure (res NULL or non-finite res$b[1]) returns NA.

skip_if_not_installed("MASS")

cauchit_fixture <- function(seed = 4L, n = 200L) {
	set.seed(seed)
	x <- rnorm(n)
	des <- DesignFixediBCRD$new(n = n, response_type = "ordinal", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- as.integer(cut(0.9 * w + rlogis(n), c(-Inf, -1, 0.4, 1.5, Inf)))
	des$add_all_subject_responses(y)
	inf <- InferenceOrdinalCauchitRegr$new(des, verbose = FALSE)
	inf$num_cores <- 1L
	list(inf = inf, priv = inf$.__enclos_env__$private, x = x, y = y, w = w)
}

cauchit_no_cov_fixture <- function(seed = 5L, n = 200L) {
	set.seed(seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "ordinal", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- as.integer(cut(0.9 * w + rlogis(n), c(-Inf, -1, 0.4, 1.5, Inf)))
	des$add_all_subject_responses(y)
	inf <- InferenceOrdinalCauchitRegr$new(des, model_formula = ~1, verbose = FALSE)
	inf$num_cores <- 1L
	list(inf = inf, priv = inf$.__enclos_env__$private, y = y, w = w)
}

test_that("the randomization-time estimate refits the treatment coefficient for a permuted assignment, matching MASS::polr(cauchit)", {
	f <- cauchit_fixture()
	f$inf$compute_estimate()
	expect_equal(f$priv$best_X_colnames, "x")

	est <- f$priv$compute_treatment_estimate_during_randomization_inference()
	Xd <- data.frame(y = factor(f$y, ordered = TRUE), w = f$w, x = f$x)
	ref <- unname(coef(suppressWarnings(MASS::polr(y ~ w + x, data = Xd, method = "cauchit")))["w"])
	expect_gt(est, 0)
	expect_equal(est, ref, tolerance = 2e-2)

	set.seed(9)
	w2 <- sample(f$w)
	f$priv$w <- w2
	est2 <- f$priv$compute_treatment_estimate_during_randomization_inference()
	Xd2 <- data.frame(y = factor(f$y, ordered = TRUE), w = w2, x = f$x)
	ref2 <- unname(coef(suppressWarnings(MASS::polr(y ~ w2 + x, data = Xd2, method = "cauchit")))["w2"])
	expect_equal(est2, ref2, tolerance = 2e-2)
	expect_false(isTRUE(all.equal(est, est2, tolerance = 1e-3)))
})

test_that("without prior column selection it calls shared() first", {
	f <- cauchit_fixture(seed = 6L)
	expect_null(f$priv$best_X_colnames)
	expect_true(is.finite(f$priv$compute_treatment_estimate_during_randomization_inference()))
	expect_false(is.null(f$priv$best_X_colnames))
})

test_that("with no covariates selected, the refit uses a treatment-only design and matches MASS::polr(y ~ w, cauchit)", {
	f <- cauchit_no_cov_fixture()
	f$inf$compute_estimate()
	expect_equal(f$priv$best_X_colnames, character(0))

	est <- f$priv$compute_treatment_estimate_during_randomization_inference()
	Xd <- data.frame(y = factor(f$y, ordered = TRUE), w = f$w)
	ref <- unname(coef(suppressWarnings(MASS::polr(y ~ w, data = Xd, method = "cauchit")))["w"])
	expect_equal(est, ref, tolerance = 2e-2)
})

test_that("a fitter failure (res NULL or non-finite res$b[1]) returns NA", {
	f <- cauchit_fixture(seed = 7L)
	f$inf$compute_estimate()
	local_mocked_bindings(fast_ordinal_cauchit_regression_cpp = function(...) NULL, .package = "EDI")
	expect_true(is.na(f$priv$compute_treatment_estimate_during_randomization_inference()))

	local_mocked_bindings(
		fast_ordinal_cauchit_regression_cpp = function(X, ...) list(b = c(NA_real_, 0, 0, 0), params = c(NA_real_, 0, 0, 0)),
		.package = "EDI"
	)
	expect_true(is.na(f$priv$compute_treatment_estimate_during_randomization_inference()))
})
