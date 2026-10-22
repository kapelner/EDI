library(testthat)
library(EDI)

# TODO-107 (follow-up): the C++ ordinal solvers' convergence test is not
# scale-aware, so on uncentred covariates (mean 100 / 1e4) they stop early
# while reporting converged = TRUE, with a treatment coefficient off by up to
# ~0.1-0.7. InferenceOrdinalPropOddsRegr / Cauchit / Cloglog / OrderedProbit now
# centre and scale the non-treatment columns (ordinal_fit_scaled()) and map the
# fit back exactly. The treatment estimate is invariant to shifting a covariate,
# so each class must give the same estimate/SE at shift 0, 100 and 1e4.

skip_if_not_installed("ordinal")

uc107_fixture <- function(cls, shift, seed = 1L, n = 200L) {
	set.seed(seed)
	x1 <- rnorm(n) + shift
	des <- DesignFixediBCRD$new(n = n, response_type = "ordinal", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = x1))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	lin <- -1.2 * w + 0.4 * (x1 - shift)
	y <- 1L + rowSums(matrix(runif(n * 3), n, 3) > plogis(outer(lin, c(-1, 0.5, 1.6), "-")))
	des$add_all_subject_responses(y)
	inf <- cls$new(des, model_formula = ~x1, verbose = FALSE)
	list(inf = inf, priv = inf$.__enclos_env__$private, y = y, w = w, x1 = x1,
		dat = data.frame(y = ordered(y), treatment = w, x1 = x1))
}

test_that("PropOdds matches ordinal::clm (estimate, SE) on uncentred covariates", {
	for (shift in c(100, 1e4)) {
		f <- uc107_fixture(InferenceOrdinalPropOddsRegr, shift)
		ref <- suppressWarnings(ordinal::clm(y ~ treatment + x1, data = f$dat))
		est <- f$inf$compute_estimate()
		expect_equal(est, unname(coef(ref)["treatment"]), tolerance = 2e-3)
		expect_equal(f$priv$cached_values$s_beta_hat_T,
			unname(sqrt(vcov(ref)["treatment", "treatment"])), tolerance = 5e-3)
	}
})

test_that("Cauchit / Cloglog / OrderedProbit estimates are invariant to a covariate shift", {
	for (nm in c("InferenceOrdinalCauchitRegr", "InferenceOrdinalCloglogRegr", "InferenceOrdinalOrderedProbitRegr")) {
		cls <- get(nm, envir = asNamespace("EDI"))
		e0 <- suppressWarnings(uc107_fixture(cls, 0)$inf$compute_estimate())
		for (shift in c(100, 1e4)) {
			f <- uc107_fixture(cls, shift)
			expect_equal(suppressWarnings(f$inf$compute_estimate()), e0, tolerance = 5e-3, label = paste(nm, shift))
		}
	}
})

test_that("the weighted (Bayesian-bootstrap) path is shift-invariant", {
	est <- sapply(c(0, 100, 1e4), function(shift) {
		f <- uc107_fixture(InferenceOrdinalPropOddsRegr, shift)
		f$priv$current_bayesian_bootstrap_context <- f$priv$build_bayesian_bootstrap_context()
		set.seed(7)
		f$inf$compute_estimate_with_bootstrap_weights(runif(200, 0.5, 1.5), estimate_only = FALSE)
	})
	expect_equal(est[2], est[1], tolerance = 5e-3)
	expect_equal(est[3], est[1], tolerance = 5e-3)
})

test_that("the randomization-inference estimate path is shift-invariant", {
	est <- sapply(c(0, 1e4), function(shift) {
		f <- uc107_fixture(InferenceOrdinalPropOddsRegr, shift)
		f$inf$compute_estimate()
		f$priv$compute_treatment_estimate_during_randomization_inference(estimate_only = TRUE)
	})
	expect_equal(est[2], est[1], tolerance = 5e-3)
})

test_that("ordinal_fit_scaled maps params, Fisher information and vcov back exactly", {
	fit_scaled <- get("ordinal_fit_scaled", envir = asNamespace("EDI"))
	f <- uc107_fixture(InferenceOrdinalPropOddsRegr, 3)
	X <- cbind(treatment = f$w, x1 = f$x1)
	y <- as.numeric(f$y)
	r <- fit_scaled(fast_ordinal_regression_with_var_cpp, X, y, force = TRUE)
	H <- -get_ordinal_regression_hessian_cpp(X, y, r$params)
	expect_lt(max(abs(H - r$fisher_information)) / max(abs(H)), 1e-8)
	expect_lt(max(abs(solve(H) - r$vcov)) / max(abs(r$vcov)), 1e-8)
	# a warm start given in the original parameterization is mapped forward
	# (not skipped) and reproduces the same optimum
	r2 <- fit_scaled(fast_ordinal_regression_with_var_cpp, X, y, force = TRUE,
		warm_start_params = r$params, warm_start_fisher_info = r$fisher_information)
	expect_equal(r2$params, r$params, tolerance = 2e-3)
	# fixing the treatment coefficient works in the scaled space too
	jt <- length(r$params) - ncol(X) + 1L
	r3 <- fit_scaled(fast_ordinal_regression_cpp, X, y, force = TRUE, fixed_idx = jt, fixed_values = 0.25)
	expect_equal(unname(r3$params[jt]), 0.25, tolerance = 1e-8)
	expect_gte(r3$neg_loglik, r$neg_loglik - 1e-6)
})

test_that("well-scaled covariates are passed through untouched (no behaviour change)", {
	plan <- get("ordinal_center_scale_plan", envir = asNamespace("EDI"))
	set.seed(1)
	X <- cbind(treatment = rep(0:1, 50), x1 = rnorm(100), x2 = rbinom(100, 1, 0.5))
	expect_null(plan(X))
	expect_false(is.null(plan(X, force = TRUE)))
	X[, "x1"] <- X[, "x1"] + 100
	expect_false(is.null(plan(X)))
})
