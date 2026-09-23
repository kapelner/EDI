library(testthat)
library(EDI)

# InferenceOrdinalPropOddsRegr's compute_treatment_estimate_during_randomization_inference()
# (inference_ordinal_proportional_odds.R) had no test reference anywhere -- the same gap pattern
# already closed this session on the sibling cumulative-link classes InferenceOrdinalCloglogRegr and
# InferenceOrdinalCauchitRegr. This class's source comment explicitly documents a past bug: using
# res$b[length(res$b)] (the last covariate's slope) instead of res$b[1] (the treatment slope) fed the
# randomization test the wrong coefficient, producing near-total null rejection whenever the design
# had covariates -- fixed to res$b[1], which this file verifies directly against an independent
# reference on a design WITH covariates (so a regression back to the old bug would be caught).
#   1. The covariate-adjusted refit on the current (and then a permuted) w matches an independent
#      MASS::polr(method = "logistic") fit.
#   2. With no prior column selection (best_X_colnames still NULL), it calls shared() first.
#   3. With no covariates selected (model_formula = ~1), X = as.matrix(w) (treatment-only) rather than
#      including covariate columns.
#   4. A fitter failure (res NULL or non-finite res$b[1]) returns NA.

skip_if_not_installed("MASS")

propodds_fixture <- function(seed = 4L, n = 200L) {
	set.seed(seed)
	x <- rnorm(n)
	des <- DesignFixediBCRD$new(n = n, response_type = "ordinal", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- as.integer(cut(0.9 * w + rlogis(n), c(-Inf, -1, 0.4, 1.5, Inf)))
	des$add_all_subject_responses(y)
	inf <- InferenceOrdinalPropOddsRegr$new(des, verbose = FALSE)
	inf$num_cores <- 1L
	list(inf = inf, priv = inf$.__enclos_env__$private, x = x, y = y, w = w)
}

propodds_no_cov_fixture <- function(seed = 5L, n = 200L) {
	set.seed(seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "ordinal", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- as.integer(cut(0.9 * w + rlogis(n), c(-Inf, -1, 0.4, 1.5, Inf)))
	des$add_all_subject_responses(y)
	inf <- InferenceOrdinalPropOddsRegr$new(des, model_formula = ~1, verbose = FALSE)
	inf$num_cores <- 1L
	list(inf = inf, priv = inf$.__enclos_env__$private, y = y, w = w)
}

test_that("the randomization-time estimate refits the treatment coefficient for a permuted assignment, matching MASS::polr(logistic)", {
	f <- propodds_fixture()
	f$inf$compute_estimate()
	expect_equal(f$priv$best_X_colnames, "x")

	est <- f$priv$compute_treatment_estimate_during_randomization_inference()
	Xd <- data.frame(y = factor(f$y, ordered = TRUE), w = f$w, x = f$x)
	ref <- unname(coef(suppressWarnings(MASS::polr(y ~ w + x, data = Xd, method = "logistic")))["w"])
	expect_gt(est, 0)
	expect_equal(est, ref, tolerance = 5e-3)

	set.seed(9)
	w2 <- sample(f$w)
	f$priv$w <- w2
	est2 <- f$priv$compute_treatment_estimate_during_randomization_inference()
	Xd2 <- data.frame(y = factor(f$y, ordered = TRUE), w = w2, x = f$x)
	ref2 <- unname(coef(suppressWarnings(MASS::polr(y ~ w2 + x, data = Xd2, method = "logistic")))["w2"])
	expect_equal(est2, ref2, tolerance = 5e-3)
	expect_false(isTRUE(all.equal(est, est2, tolerance = 1e-3)))
})

test_that("without prior column selection it calls shared() first", {
	f <- propodds_fixture(seed = 6L)
	expect_null(f$priv$best_X_colnames)
	expect_true(is.finite(f$priv$compute_treatment_estimate_during_randomization_inference()))
	expect_false(is.null(f$priv$best_X_colnames))
})

test_that("with no covariates selected, the refit uses a treatment-only design and matches MASS::polr(y ~ w, logistic)", {
	f <- propodds_no_cov_fixture()
	f$inf$compute_estimate()
	expect_equal(f$priv$best_X_colnames, character(0))

	est <- f$priv$compute_treatment_estimate_during_randomization_inference()
	Xd <- data.frame(y = factor(f$y, ordered = TRUE), w = f$w)
	ref <- unname(coef(suppressWarnings(MASS::polr(y ~ w, data = Xd, method = "logistic")))["w"])
	expect_equal(est, ref, tolerance = 5e-3)
})

test_that("a fitter failure (res NULL or non-finite res$b[1]) returns NA", {
	f <- propodds_fixture(seed = 7L)
	f$inf$compute_estimate()
	local_mocked_bindings(fast_ordinal_regression_cpp = function(...) NULL, .package = "EDI")
	expect_true(is.na(f$priv$compute_treatment_estimate_during_randomization_inference()))

	local_mocked_bindings(
		fast_ordinal_regression_cpp = function(X, ...) list(b = c(NA_real_, 0, 0, 0), params = c(NA_real_, 0, 0, 0)),
		.package = "EDI"
	)
	expect_true(is.na(f$priv$compute_treatment_estimate_during_randomization_inference()))
})
