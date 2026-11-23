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
	# 2026-11-17: 5e-2. With weights the two solvers differ more than without:
	# over 20 seeds of this fixture, |EDI - geepack| was at most 0.035 weighted
	# but at most 0.003 unweighted. The 2e-2 bar only held for the old KK14
	# assignments; the v1.0.6-TODO-45 matching fix changed w and the data here.
	# v1.0.6-TODO-47 (2026-11-24): which side is wrong? Neither. EDI's beta solves the weighted GEE
	# U(beta; alpha) = sum D' V^-1 (W^1/2 r) at its own alpha (|U| = 1.2e-9) and geepack's beta solves the
	# same equation at geepack's alpha (|U| = 4.3e-5, its tolerance). They differ only in the exchangeable
	# alpha moment estimator: EDI 0.027, geepack 0.123 on this draw (the unweighted alpha is -0.061 / -0.058).
	# EDI uses Liang-Zeger's weighted moments with N - p and n_pairs - p; geepack's weighted alpha equation
	# is noisier (over 30 weight draws both average -0.065 / -0.069, SD 0.027 vs 0.058). With alpha fixed
	# at EDI's value (corstr = "fixed") geepack reproduces EDI's beta to 3e-8, checked below on several
	# draws; this looser comparison against geepack's own alpha stays at 5e-2.
	expect_equal(as.numeric(est_pkg), as.numeric(coef(mod_ref)["w"]), tolerance = 5e-2)

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
	expect_true(inf_z$.__enclos_env__$private$weighted_refit_is_nonestimable("estimate"))

	# The documented no-variance contract: SE/df are always left NA/Inf.
	expect_true(is.na(inf$.__enclos_env__$private$weighted_refit_se()))
	expect_equal(inf$.__enclos_env__$private$last_weighted_refit$df, Inf)
})

test_that("KK GEE weighted refit equals geepack with the working correlation fixed at EDI's alpha", {
	# v1.0.6-TODO-47: isolates the beta solver from the alpha moment-estimator convention (see above).
	skip_if_not_installed("geepack")
	for (seed in c(20260918, 1, 2, 3, 4)) {
		set.seed(seed)
		f <- make_kk_gee_design()
		weights <- runif(f$n, 0.3, 2.5)
		inf <- InferencePropKKGEE$new(f$des, use_rcpp = TRUE, verbose = FALSE)
		install_subject_bayesian_bootstrap_context(inf, f$n)
		est_pkg <- inf$compute_estimate_with_bootstrap_weights(weights)
		ord <- order(f$group_id)
		d <- data.frame(y = f$y, w = f$w, x1 = f$x1, x2 = f$x2)[ord, ]
		id <- f$group_id[ord]
		wt <- weights[ord]
		fit_edi <- EDI:::gee_pairs_singletons_weighted_cpp(cbind(1, as.matrix(d[, c("w", "x1", "x2")])),
			as.numeric(d$y), as.integer(id), "binomial", wt)
		expect_equal(as.numeric(est_pkg), as.numeric(fit_edi$beta[2]), tolerance = 1e-8, info = seed)
		n_pairs <- sum(table(id) == 2L)
		mod_fixed <- suppressWarnings(geepack::geeglm(y ~ w + x1 + x2, data = d, id = id, weights = wt,
			family = binomial("logit"), corstr = "fixed", zcor = rep(fit_edi$alpha, n_pairs)))
		expect_equal(as.numeric(coef(mod_fixed)), as.numeric(fit_edi$beta), tolerance = 1e-6, info = seed)
	}
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
