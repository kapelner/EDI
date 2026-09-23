library(testthat)
library(EDI)

# InferenceOrdinalAdjCatLogitRegr's compute_treatment_estimate_during_randomization_inference()
# (inference_ordinal_adj_cat_logit.R) had no test reference anywhere -- the same gap pattern already
# closed this session on the cumulative-link ordinal siblings, extended here to the adjacent-category
# logit family (independent reference is VGAM::vglm(acat), the same reference already used for this
# class's compute_estimate() in test-ordinal-adjacent-category-continuation-ratio-and-gcomp-classes-
# match-vgam-and-polr-references.R). This class's source comment documents a past real bug: using
# res$b[length(res$b)] (the last covariate's slope) instead of res$b[1] (the treatment slope) fed the
# randomization test the wrong coefficient, confirmed via near-total null rejection whenever the
# design had covariates -- fixed to res$b[1], which this file verifies directly against an
# independent reference on a design WITH covariates.
#   1. The covariate-adjusted refit on the current (and then a permuted) w matches an independent
#      VGAM::vglm(family = acat(parallel = TRUE, reverse = FALSE)) fit.
#   2. With no prior column selection (best_Xmm_colnames still NULL), it calls shared() first.
#   3. With no covariates selected (model_formula = ~1), X = as.matrix(w) (treatment-only) rather than
#      including covariate columns.
#   4. A fitter failure/non-finite or extreme res$b[1] returns NA.

skip_if_not_installed("VGAM")

adjcat_fixture <- function(seed = 4L, n = 200L) {
	set.seed(seed)
	x <- rnorm(n)
	des <- DesignFixediBCRD$new(n = n, response_type = "ordinal", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- as.integer(cut(0.9 * w + rlogis(n), c(-Inf, -1, 0.4, 1.5, Inf)))
	des$add_all_subject_responses(y)
	inf <- InferenceOrdinalAdjCatLogitRegr$new(des, verbose = FALSE)
	inf$num_cores <- 1L
	list(inf = inf, priv = inf$.__enclos_env__$private, x = x, y = y, w = w)
}

adjcat_no_cov_fixture <- function(seed = 5L, n = 200L) {
	set.seed(seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "ordinal", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- as.integer(cut(0.9 * w + rlogis(n), c(-Inf, -1, 0.4, 1.5, Inf)))
	des$add_all_subject_responses(y)
	inf <- InferenceOrdinalAdjCatLogitRegr$new(des, model_formula = ~1, verbose = FALSE)
	inf$num_cores <- 1L
	list(inf = inf, priv = inf$.__enclos_env__$private, y = y, w = w)
}

test_that("the randomization-time estimate refits the treatment coefficient for a permuted assignment, matching vglm(acat)", {
	f <- adjcat_fixture()
	f$inf$compute_estimate()
	expect_equal(f$priv$best_Xmm_colnames, "x")
	y <- f$y; w <- f$w; x <- f$x

	est <- f$priv$compute_treatment_estimate_during_randomization_inference()
	d <- data.frame(y = factor(y, ordered = TRUE), w = w, x = x)
	fit <- VGAM::vglm(y ~ w + x, family = VGAM::acat(parallel = TRUE, reverse = FALSE), data = d)
	ref <- unname(VGAM::coef(fit)["w"])
	expect_equal(est, ref, tolerance = 1e-3)

	set.seed(9)
	w2 <- sample(w)
	f$priv$w <- w2
	est2 <- f$priv$compute_treatment_estimate_during_randomization_inference()
	d2 <- data.frame(y = factor(y, ordered = TRUE), w = w2, x = x)
	fit2 <- VGAM::vglm(y ~ w + x, family = VGAM::acat(parallel = TRUE, reverse = FALSE), data = d2)
	ref2 <- unname(VGAM::coef(fit2)["w"])
	expect_equal(est2, ref2, tolerance = 1e-3)
	expect_false(isTRUE(all.equal(est, est2, tolerance = 1e-3)))
})

test_that("without prior column selection it calls shared() first", {
	f <- adjcat_fixture(seed = 6L)
	expect_null(f$priv$best_Xmm_colnames)
	expect_true(is.finite(f$priv$compute_treatment_estimate_during_randomization_inference()))
	expect_false(is.null(f$priv$best_Xmm_colnames))
})

test_that("with no covariates selected, the refit uses a treatment-only design and matches vglm(y ~ w, acat)", {
	f <- adjcat_no_cov_fixture()
	f$inf$compute_estimate()
	expect_equal(f$priv$best_Xmm_colnames, character(0))
	y <- f$y; w <- f$w

	est <- f$priv$compute_treatment_estimate_during_randomization_inference()
	d <- data.frame(y = factor(y, ordered = TRUE), w = w)
	fit <- VGAM::vglm(y ~ w, family = VGAM::acat(parallel = TRUE, reverse = FALSE), data = d)
	ref <- unname(VGAM::coef(fit)["w"])
	expect_equal(est, ref, tolerance = 1e-3)
})

test_that("a fitter failure/non-finite or extreme res$b[1] returns NA", {
	f <- adjcat_fixture(seed = 7L)
	f$inf$compute_estimate()
	local_mocked_bindings(fast_adjacent_category_logit_cpp = function(...) NULL, .package = "EDI")
	expect_true(is.na(f$priv$compute_treatment_estimate_during_randomization_inference()))

	local_mocked_bindings(
		fast_adjacent_category_logit_cpp = function(X, ...) list(b = c(NA_real_, 0, 0, 0), params = c(NA_real_, 0, 0, 0)),
		.package = "EDI"
	)
	expect_true(is.na(f$priv$compute_treatment_estimate_during_randomization_inference()))

	local_mocked_bindings(
		fast_adjacent_category_logit_cpp = function(X, ...) list(b = c(1e5, 0, 0, 0), params = c(1e5, 0, 0, 0)),
		.package = "EDI"
	)
	expect_true(is.na(f$priv$compute_treatment_estimate_during_randomization_inference()))
})
