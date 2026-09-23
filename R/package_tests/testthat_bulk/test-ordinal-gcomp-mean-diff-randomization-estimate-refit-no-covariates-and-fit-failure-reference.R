library(testthat)
library(EDI)

# InferenceOrdinalGCompMeanDiff's compute_treatment_estimate_during_randomization_inference()
# (inference_ordinal_gcomp.R) had no test reference anywhere -- the same gap pattern already closed
# this session on several sibling ordinal classes. Independent reference is the standardized
# difference of expected category scores (1..K) from a MASS::polr(proportional-odds) fit -- the same
# reference already established for this class's compute_estimate() in test-ordinal-adjacent-
# category-continuation-ratio-and-gcomp-classes-match-vgam-and-polr-references.R.
#   1. The covariate-adjusted refit on the current (and then a permuted) w matches the independent
#      g-computation reference built on MASS::polr(y ~ w + x).
#   2. With no prior column selection (best_X_colnames still NULL), it calls shared() first.
#   3. With no covariates selected (model_formula = ~1), X_fit = matrix(w, ..., "treatment") rather
#      than including covariate columns.
#   4. A fitter failure/malformed fit (res NULL, empty b, or NULL alpha) returns NA.

skip_if_not_installed("MASS")

polr_gcomp_ref <- function(y, w_vec, x_vec) {
	d <- data.frame(y = factor(y, ordered = TRUE), w = w_vec, x = x_vec)
	po <- MASS::polr(y ~ w + x, data = d)
	p1 <- predict(po, data.frame(w = 1, x = x_vec), type = "probs")
	p0 <- predict(po, data.frame(w = 0, x = x_vec), type = "probs")
	K <- ncol(p1)
	mean(p1 %*% seq_len(K)) - mean(p0 %*% seq_len(K))
}

gcomp_fixture <- function(seed = 4L, n = 200L) {
	set.seed(seed)
	x <- rnorm(n)
	des <- DesignFixediBCRD$new(n = n, response_type = "ordinal", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- as.integer(cut(0.9 * w + rlogis(n), c(-Inf, -1, 0.4, 1.5, Inf)))
	des$add_all_subject_responses(y)
	inf <- InferenceOrdinalGCompMeanDiff$new(des, verbose = FALSE)
	inf$num_cores <- 1L
	list(inf = inf, priv = inf$.__enclos_env__$private, x = x, y = y, w = w)
}

gcomp_no_cov_fixture <- function(seed = 5L, n = 200L) {
	set.seed(seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "ordinal", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- as.integer(cut(0.9 * w + rlogis(n), c(-Inf, -1, 0.4, 1.5, Inf)))
	des$add_all_subject_responses(y)
	inf <- InferenceOrdinalGCompMeanDiff$new(des, model_formula = ~1, verbose = FALSE)
	inf$num_cores <- 1L
	list(inf = inf, priv = inf$.__enclos_env__$private, y = y, w = w)
}

test_that("the randomization-time estimate refits on a permuted assignment, matching the polr g-computation reference", {
	f <- gcomp_fixture()
	f$inf$compute_estimate()
	expect_equal(f$priv$best_X_colnames, "x")

	est <- f$priv$compute_treatment_estimate_during_randomization_inference()
	ref <- polr_gcomp_ref(f$y, f$w, f$x)
	expect_equal(est, ref, tolerance = 5e-3)

	set.seed(9)
	w2 <- sample(f$w)
	f$priv$w <- w2
	est2 <- f$priv$compute_treatment_estimate_during_randomization_inference()
	ref2 <- polr_gcomp_ref(f$y, w2, f$x)
	expect_equal(est2, ref2, tolerance = 5e-3)
	expect_false(isTRUE(all.equal(est, est2, tolerance = 1e-3)))
})

test_that("without prior column selection it calls shared() first", {
	f <- gcomp_fixture(seed = 6L)
	expect_null(f$priv$best_X_colnames)
	expect_true(is.finite(f$priv$compute_treatment_estimate_during_randomization_inference()))
	expect_false(is.null(f$priv$best_X_colnames))
})

test_that("with no covariates selected, the refit uses a treatment-only design and matches the polr(y ~ w) g-computation reference", {
	f <- gcomp_no_cov_fixture()
	f$inf$compute_estimate()
	expect_equal(f$priv$best_X_colnames, character(0))

	est <- f$priv$compute_treatment_estimate_during_randomization_inference()
	d <- data.frame(y = factor(f$y, ordered = TRUE), w = f$w)
	po <- MASS::polr(y ~ w, data = d)
	p1 <- predict(po, data.frame(w = 1), type = "probs")
	p0 <- predict(po, data.frame(w = 0), type = "probs")
	K <- length(p1)
	ref <- sum(p1 * seq_len(K)) - sum(p0 * seq_len(K))
	expect_equal(est, ref, tolerance = 5e-3)
})

test_that("a fitter failure/malformed fit (res NULL, empty b, or NULL alpha) returns NA", {
	f <- gcomp_fixture(seed = 7L)
	f$inf$compute_estimate()
	local_mocked_bindings(fast_ordinal_regression_cpp = function(...) NULL, .package = "EDI")
	expect_true(is.na(f$priv$compute_treatment_estimate_during_randomization_inference()))

	local_mocked_bindings(
		fast_ordinal_regression_cpp = function(...) list(b = numeric(0), alpha = c(0, 1, 2)),
		.package = "EDI"
	)
	expect_true(is.na(f$priv$compute_treatment_estimate_during_randomization_inference()))

	local_mocked_bindings(
		fast_ordinal_regression_cpp = function(X, ...) list(b = c(0.5, rep(0, ncol(X) - 1L)), alpha = NULL),
		.package = "EDI"
	)
	expect_true(is.na(f$priv$compute_treatment_estimate_during_randomization_inference()))
})
