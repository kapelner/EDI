library(testthat)
library(EDI)

# InferenceOrdinalKKGEE$compute_estimate_with_bootstrap_weights() has no
# existing test anywhere in the suite (test-kk-gee-parity.R only exercises
# compute_estimate() and compute_rand_two_sided_pval() on this class). Unlike
# its continuous/count/incidence/proportion KK-GEE siblings, this method does
# NOT delegate to the shared geepack mixin (multgee::ordLORgee does not
# accept weights) -- it falls back to a genuinely different, non-clustered
# weighted proportional-odds fit via fast_ordinal_regression_weighted_cpp,
# per the method's own doc comment.

make_ordinal_kk_gee_fixture <- function(n_pairs = 60L, n_single = 20L, seed = 20260423) {
	set.seed(seed)
	n <- 2L * n_pairs + n_single
	X <- data.frame(x1 = rnorm(n), x2 = rnorm(n))
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "ordinal", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	des$.__enclos_env__$private$m <- c(rep(seq_len(n_pairs), each = 2L), rep(0L, n_single))

	priv0 <- des$.__enclos_env__$private
	w <- priv0$w
	m <- priv0$m
	group_id <- ifelse(m > 0L, m, max(m, 0L) + seq_along(m))
	b <- rnorm(max(group_id), sd = 0.3)
	eta <- 0.3 - 0.4 * w + 0.15 * X$x1 - 0.1 * X$x2 + b[group_id]
	latent <- eta + rnorm(n, sd = 0.8)
	cuts <- stats::quantile(latent, probs = c(0.33, 0.66))
	y <- as.integer(cut(latent, breaks = c(-Inf, cuts, Inf), labels = FALSE, right = TRUE))
	des$add_all_subject_responses(y)
	list(des = des, y = y)
}

install_bb_context <- function(inf) {
	priv <- inf$.__enclos_env__$private
	ctx <- priv$build_bayesian_bootstrap_context()
	priv$current_bayesian_bootstrap_context <- ctx
	ctx
}

test_that("weighted refit matches an independent MASS::polr fit under the row-expanded cluster weights", {
	skip_if_not_installed("multgee")
	skip_if_not_installed("geepack")
	skip_if_not_installed("MASS")
	fx <- make_ordinal_kk_gee_fixture()

	inf <- InferenceOrdinalKKGEE$new(fx$des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	ctx <- install_bb_context(inf)

	set.seed(1)
	weights <- stats::runif(ctx$n_units, 0.3, 2)
	est <- inf$compute_estimate_with_bootstrap_weights(weights)

	row_weights <- weights[ctx$row_to_unit]
	pred_df <- priv$gee_predictors_df()
	dat <- data.frame(y = factor(fx$y, ordered = TRUE), pred_df)
	ref <- suppressWarnings(MASS::polr(y ~ ., data = dat, weights = row_weights, Hess = TRUE))
	est_ref <- unname(stats::coef(ref)["w"])

	expect_equal(est, est_ref, tolerance = 1e-3)

	se_after <- priv$weighted_refit_se()
	expect_true(is.na(se_after))
})

test_that("effectively-constant weights short-circuit to the unweighted multgee estimate", {
	skip_if_not_installed("multgee")
	skip_if_not_installed("geepack")
	fx <- make_ordinal_kk_gee_fixture()

	inf <- InferenceOrdinalKKGEE$new(fx$des, verbose = FALSE)
	ctx <- install_bb_context(inf)

	# The unweighted fit is cached first: the short-circuit returns that cached estimate exactly
	# (the weighted call no longer leaves its own fit behind for compute_estimate() to reuse).
	est_plain <- inf$compute_estimate(estimate_only = TRUE)
	est_unit <- inf$compute_estimate_with_bootstrap_weights(rep(1, ctx$n_units))
	expect_equal(est_unit, as.numeric(est_plain)[1], tolerance = 1e-8)

	est_scaled <- inf$compute_estimate_with_bootstrap_weights(rep(2.5, ctx$n_units))
	expect_equal(est_scaled, as.numeric(est_plain)[1], tolerance = 1e-8)
})

test_that("all-zero weights are treated as effectively constant, not filtered out", {
	# Non-obvious contract, confirmed by reading the source: the short-circuit
	# only checks max(row_weights) - min(row_weights) against a tolerance, so
	# an all-zero weight vector is "effectively constant" too and reuses the
	# unweighted multgee estimate, rather than being caught by the later
	# is.finite(row_weights) & row_weights > 0 filter (which never runs).
	skip_if_not_installed("multgee")
	skip_if_not_installed("geepack")
	fx <- make_ordinal_kk_gee_fixture(n_pairs = 15L, n_single = 5L)

	inf <- InferenceOrdinalKKGEE$new(fx$des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	ctx <- install_bb_context(inf)

	est_plain <- inf$compute_estimate(estimate_only = TRUE)
	est_zero <- inf$compute_estimate_with_bootstrap_weights(rep(0, ctx$n_units))
	expect_equal(est_zero, as.numeric(est_plain)[1], tolerance = 1e-8)
	expect_true(is.na(priv$weighted_refit_se()))
})

test_that("nonfinite weights are rejected by the input validator before reaching the fit", {
	skip_if_not_installed("multgee")
	skip_if_not_installed("geepack")
	fx <- make_ordinal_kk_gee_fixture(n_pairs = 15L, n_single = 5L)

	inf <- InferenceOrdinalKKGEE$new(fx$des, verbose = FALSE)
	ctx <- install_bb_context(inf)

	bad_weights <- rep(1, ctx$n_units)
	bad_weights[1] <- NaN
	expect_error(inf$compute_estimate_with_bootstrap_weights(bad_weights), "missing values")
})
