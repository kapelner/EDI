library(testthat)
library(EDI)

# InferencePropKKGEE (and its siblings via inference_mixin_kk_gee_shared.R:
# InferenceIncidKKGEE, InferenceCountPoissonKKGEE, InferenceOrdinalKKGEE)
# compute_estimate_with_bootstrap_weights() only ever appeared as a
# name-existence check (test-marginal-gcomp-helper-contracts.R) or a
# unit-weight-only smoke check (R/EDI/tests/testthat/test-bayesian-bootstrap.R)
# -- never called with genuinely varying weights against an independent
# reference. Exercised here via the proportion-response class.

make_kk_gee_design <- function(n_pairs = 60L, n_single = 30L) {
	n <- 2L * n_pairs + n_single
	X <- data.frame(x1 = rnorm(n), x2 = rnorm(n))
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "proportion", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	priv <- des$.__enclos_env__$private
	priv$m <- c(rep(seq_len(n_pairs), each = 2L), rep(0L, n_single))
	w <- priv$w
	Xd <- as.data.frame(priv$X)
	m <- priv$m
	group_id <- ifelse(m > 0L, m, max(m, 0L) + seq_along(m))
	b <- rnorm(max(group_id), sd = 0.3)
	eta <- 0.2 - 0.35 * w + 0.15 * Xd[[1]] - 0.1 * Xd[[2]] + b[group_id]
	y <- rbinom(n, 1L, plogis(eta))
	des$add_all_subject_responses(as.numeric(y))
	list(des = des, w = w, x1 = Xd[[1]], x2 = Xd[[2]], y = y, group_id = group_id, n = n)
}

install_subject_bayesian_bootstrap_context <- function(inf, n) {
	inf$.__enclos_env__$private$current_bayesian_bootstrap_context <- list(
		row_to_unit = seq_len(n), unit_group_id = rep(1L, n), n_units = n
	)
	invisible(inf)
}

test_that("KK GEE weighted-bootstrap refit (use_rcpp=TRUE) matches an independent weighted geepack fit", {
	skip_if_not_installed("geepack")
	set.seed(20260918)
	f <- make_kk_gee_design()

	inf <- InferencePropKKGEE$new(f$des, use_rcpp = TRUE, verbose = FALSE)
	install_subject_bayesian_bootstrap_context(inf, f$n)
	weights <- runif(f$n, 0.3, 2.5)
	est_pkg <- inf$compute_estimate_with_bootstrap_weights(weights)

	df <- data.frame(y = f$y, w = f$w, x1 = f$x1, x2 = f$x2)
	suppressWarnings({
		mod_ref <- geepack::geeglm(
			y ~ w + x1 + x2, data = df, id = f$group_id, weights = weights,
			family = binomial("logit"), corstr = "exchangeable", std.err = "san.se"
		)
	})
	# The internal Rcpp solver and geepack are two independently-implemented
	# GEE solvers (different working-correlation estimation details), so a
	# loose tolerance is appropriate -- matching test-kk-gee-parity.R's own
	# unweighted proportion tolerance (2e-2) for this class.
	expect_equal(as.numeric(est_pkg), as.numeric(coef(mod_ref)["w"]), tolerance = 2e-2)

	# Unit weights reproduce the unweighted estimate.
	inf_u <- InferencePropKKGEE$new(f$des, use_rcpp = TRUE, verbose = FALSE)
	est_unweighted <- inf_u$compute_estimate()
	install_subject_bayesian_bootstrap_context(inf_u, f$n)
	est_unit <- inf_u$compute_estimate_with_bootstrap_weights(rep(1, f$n))
	expect_equal(as.numeric(est_unit), as.numeric(est_unweighted), tolerance = 1e-5)

	# Scale-invariance: multiplying every weight by a positive constant does
	# not change the treatment coefficient (only the working correlation's
	# effective dispersion changes, not beta).
	inf_a <- InferencePropKKGEE$new(f$des, use_rcpp = TRUE, verbose = FALSE)
	install_subject_bayesian_bootstrap_context(inf_a, f$n)
	est_a <- inf_a$compute_estimate_with_bootstrap_weights(weights)
	inf_b <- InferencePropKKGEE$new(f$des, use_rcpp = TRUE, verbose = FALSE)
	install_subject_bayesian_bootstrap_context(inf_b, f$n)
	est_b <- inf_b$compute_estimate_with_bootstrap_weights(7 * weights)
	expect_equal(as.numeric(est_a), as.numeric(est_b), tolerance = 1e-6)

	# All-zero weights are nonestimable.
	inf_z <- InferencePropKKGEE$new(f$des, use_rcpp = TRUE, verbose = FALSE)
	install_subject_bayesian_bootstrap_context(inf_z, f$n)
	est_z <- inf_z$compute_estimate_with_bootstrap_weights(rep(0, f$n))
	expect_true(is.na(est_z))
	expect_true(inf_z$is_nonestimable("estimate"))

	# The documented no-variance contract: SE/df are always left NA/Inf.
	expect_true(is.na(inf$.__enclos_env__$private$cached_values$s_beta_hat_T))
	expect_equal(inf$.__enclos_env__$private$cached_values$df, Inf)
})

test_that("KK GEE weighted-bootstrap refit's use_rcpp=FALSE geepack fallback now matches an independent weighted geepack fit (bug fixed)", {
	# Previously: private$fit_weighted_gee_on_data() (inference_mixin_kk_gee_shared.R)
	# called geepack::geeglm(..., std.err = "none") on the weighted path.
	# geepack::geeglm only accepts std.err %in% c("san.se", "jack", "j1s", "fij")
	# -- internally it does `if (std.err == "jack") ...` unconditionally, and
	# "none" made an unrelated downstream comparison receive a value of the
	# wrong length, raising "the condition has length > 1". That error was
	# silently swallowed by fit_weighted_gee_on_data()'s own
	# tryCatch(..., error = private$kk_gee_error_to_null), so every
	# use_rcpp=FALSE weighted-bootstrap-weights call on any class composing
	# this shared GEE mixin (proportion/incidence/count/ordinal KK GEE)
	# silently returned a nonestimable NA instead of a real geepack-backed
	# weighted estimate. Fixed by passing std.err = "san.se" (matching the
	# unweighted fallback's own default at fit_gee_on_data()).
	skip_if_not_installed("geepack")
	set.seed(20260918)
	f <- make_kk_gee_design()
	weights <- runif(f$n, 0.3, 2.5)

	inf <- InferencePropKKGEE$new(f$des, use_rcpp = FALSE, verbose = FALSE)
	install_subject_bayesian_bootstrap_context(inf, f$n)
	est <- inf$compute_estimate_with_bootstrap_weights(weights)

	df <- data.frame(y = f$y, w = f$w, x1 = f$x1, x2 = f$x2)
	suppressWarnings({
		mod_ref <- geepack::geeglm(
			y ~ w + x1 + x2, data = df, id = f$group_id, weights = weights,
			family = binomial("logit"), corstr = "exchangeable", std.err = "san.se"
		)
	})
	expect_equal(as.numeric(est), as.numeric(coef(mod_ref)["w"]), tolerance = 1e-8)
})
