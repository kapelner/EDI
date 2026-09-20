library(testthat)
library(EDI)

# InferenceCountPoissonKKGEE (via inference_mixin_kk_gee_shared.R, same
# shared base as InferencePropKKGEE/InferenceIncidKKGEE/InferenceOrdinalKKGEE)
# compute_estimate_with_bootstrap_weights() was only ever unit-weight-checked
# in R/EDI/tests/testthat/test-bayesian-bootstrap.R -- never called with
# genuinely varying weights against an independent reference. The
# proportion-response sibling was closed out in
# test-kk-gee-weighted-refit-reference.R (which also documents the shared
# use_rcpp=FALSE geepack std.err="none" bug -- not repeated here); this file
# closes the count/Poisson sibling's use_rcpp=TRUE Rcpp-solver path.

make_kk_gee_count_design <- function(n_pairs = 60L, n_single = 30L) {
	n <- 2L * n_pairs + n_single
	X <- data.frame(x1 = rnorm(n), x2 = rnorm(n))
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "count", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	priv <- des$.__enclos_env__$private
	priv$m <- c(rep(seq_len(n_pairs), each = 2L), rep(0L, n_single))
	w <- priv$w
	Xd <- as.data.frame(priv$X)
	m <- priv$m
	group_id <- ifelse(m > 0L, m, max(m, 0L) + seq_along(m))
	b <- rnorm(max(group_id), sd = 0.25)
	eta <- 0.3 - 0.25 * w + 0.1 * Xd[[1]] - 0.08 * Xd[[2]] + b[group_id]
	y <- rpois(n, lambda = exp(pmin(eta, 4)))
	des$add_all_subject_responses(as.numeric(y))
	list(des = des, w = w, x1 = Xd[[1]], x2 = Xd[[2]], y = y, group_id = group_id, n = n)
}

install_subject_bayesian_bootstrap_context <- function(inf, n) {
	inf$.__enclos_env__$private$current_bayesian_bootstrap_context <- list(
		row_to_unit = seq_len(n), unit_group_id = rep(1L, n), n_units = n
	)
	invisible(inf)
}

test_that("count KK GEE weighted-bootstrap refit (use_rcpp=TRUE) matches an independent weighted geepack fit", {
	skip_if_not_installed("geepack")
	set.seed(20260918)
	f <- make_kk_gee_count_design()

	inf <- InferenceCountPoissonKKGEE$new(f$des, use_rcpp = TRUE, verbose = FALSE)
	install_subject_bayesian_bootstrap_context(inf, f$n)
	weights <- runif(f$n, 0.3, 2.5)
	est_pkg <- inf$compute_estimate_with_bootstrap_weights(weights)

	df <- data.frame(y = f$y, w = f$w, x1 = f$x1, x2 = f$x2)
	suppressWarnings({
		mod_ref <- geepack::geeglm(
			y ~ w + x1 + x2, data = df, id = f$group_id, weights = weights,
			family = poisson("log"), corstr = "exchangeable", std.err = "san.se"
		)
	})
	# Two independently-implemented GEE solvers; loose tolerance matches
	# test-kk-gee-parity.R's own unweighted count tolerance (2e-2) for this class.
	expect_equal(as.numeric(est_pkg), as.numeric(coef(mod_ref)["w"]), tolerance = 2e-2)

	# Unit weights reproduce the unweighted estimate.
	inf_u <- InferenceCountPoissonKKGEE$new(f$des, use_rcpp = TRUE, verbose = FALSE)
	est_unweighted <- inf_u$compute_estimate()
	install_subject_bayesian_bootstrap_context(inf_u, f$n)
	est_unit <- inf_u$compute_estimate_with_bootstrap_weights(rep(1, f$n))
	expect_equal(as.numeric(est_unit), as.numeric(est_unweighted), tolerance = 1e-5)

	# Scale-invariance to a common positive weight multiplier.
	inf_a <- InferenceCountPoissonKKGEE$new(f$des, use_rcpp = TRUE, verbose = FALSE)
	install_subject_bayesian_bootstrap_context(inf_a, f$n)
	est_a <- inf_a$compute_estimate_with_bootstrap_weights(weights)
	inf_b <- InferenceCountPoissonKKGEE$new(f$des, use_rcpp = TRUE, verbose = FALSE)
	install_subject_bayesian_bootstrap_context(inf_b, f$n)
	est_b <- inf_b$compute_estimate_with_bootstrap_weights(7 * weights)
	expect_equal(as.numeric(est_a), as.numeric(est_b), tolerance = 1e-6)

	# All-zero weights are nonestimable.
	inf_z <- InferenceCountPoissonKKGEE$new(f$des, use_rcpp = TRUE, verbose = FALSE)
	install_subject_bayesian_bootstrap_context(inf_z, f$n)
	est_z <- inf_z$compute_estimate_with_bootstrap_weights(rep(0, f$n))
	expect_true(is.na(est_z))
	expect_true(inf_z$.__enclos_env__$private$weighted_refit_is_nonestimable("estimate"))
	expect_false(inf_z$is_nonestimable("any"))                  # the ordinary state is not flagged

	# The documented no-variance contract: SE/df are always left NA/Inf.
	expect_true(is.na(inf$.__enclos_env__$private$last_weighted_refit$s_beta_hat_T))
	expect_equal(inf$.__enclos_env__$private$last_weighted_refit$df, Inf)
})
