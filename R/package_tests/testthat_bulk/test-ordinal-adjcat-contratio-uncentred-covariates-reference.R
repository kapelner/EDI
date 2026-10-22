library(testthat)
library(EDI)

# TODO-107 (follow-up 2): InferenceOrdinalAdjCatLogitRegr and
# InferenceOrdinalContRatioRegr call fast_adjacent_category_logit_* /
# fast_continuation_ratio_regression_* whose convergence test is not
# scale-aware: with a covariate of mean 100 / 1e4 they stopped early with
# converged = TRUE and a treatment estimate off by up to ~0.5 (n = 200: AdjCat
# 0.897 / 0.827 / 0.490, ContRatio 1.130 / 1.041 / 0.637 at shift 0 / 100 / 1e4).
# Both now go through ordinal_fit_scaled() (adjacent-category: linpred_sign -1,
# continuation-ratio: linpred_sign +1 and warm_arg = "warm_start_beta").
# The treatment estimate and SE are invariant to shifting a covariate.

skip_if_not_installed("VGAM")
K <- function(x) get(x, envir = asNamespace("EDI"))

uc107c_fixture <- function(cls, shift, seed = 1L, n = 200L) {
	set.seed(seed)
	x1 <- rnorm(n) + shift
	des <- DesignFixediBCRD$new(n = n, response_type = "ordinal", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = x1))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	lin <- -1.2 * w + 0.4 * (x1 - shift)
	y <- 1L + rowSums(matrix(runif(n * 3), n, 3) > plogis(outer(lin, c(-1, 0.5, 1.6), "-")))
	des$add_all_subject_responses(y)
	inf <- K(cls)$new(des, model_formula = ~x1, verbose = FALSE)
	list(inf = inf, priv = inf$.__enclos_env__$private, y = y, w = w, x1 = x1,
		dat = data.frame(y = ordered(y), w = w, x1 = x1 - shift))
}

classes <- list(
	InferenceOrdinalAdjCatLogitRegr = function() VGAM::acat(parallel = TRUE, reverse = FALSE),
	InferenceOrdinalContRatioRegr = function() VGAM::cratio(parallel = TRUE)
)

test_that("AdjCat / ContRatio estimate and SE match vglm and are shift-invariant", {
	for (nm in names(classes)) {
		ref <- VGAM::vglm(y ~ w + x1, family = classes[[nm]](), data = uc107c_fixture(nm, 0)$dat)
		b <- unname(VGAM::coef(ref)["w"])
		se <- unname(sqrt(VGAM::vcov(ref)["w", "w"]))
		for (shift in c(0, 100, 1e4)) {
			f <- uc107c_fixture(nm, shift)
			est <- suppressWarnings(f$inf$compute_estimate())
			expect_equal(est, b, tolerance = 2e-3, label = paste(nm, shift, "estimate"))
			expect_equal(f$priv$cached_values$s_beta_hat_T, se, tolerance = 5e-3, label = paste(nm, shift, "SE"))
		}
	}
})

test_that("weighted bootstrap, randomization and lik-test null refit paths are shift-invariant", {
	for (nm in names(classes)) {
		res <- sapply(c(0, 1e4), function(shift) {
			f <- uc107c_fixture(nm, shift)
			suppressWarnings(f$inf$compute_estimate())
			re <- f$priv$compute_treatment_estimate_during_randomization_inference(estimate_only = TRUE)
			f$priv$current_bayesian_bootstrap_context <- f$priv$build_bayesian_bootstrap_context()
			set.seed(7)
			wb <- f$inf$compute_estimate_with_bootstrap_weights(runif(200, 0.5, 1.5), estimate_only = FALSE)
			spec <- f$priv$get_likelihood_test_spec()
			nl <- spec$fit_null(0)$neg_loglik
			c(re = re, wb = wb, nl = nl)
		})
		expect_equal(res[, 2], res[, 1], tolerance = 5e-3, label = nm)
	}
})

test_that("ordinal_fit_scaled maps params, Fisher information and vcov back exactly for both solvers", {
	fit_scaled <- K("ordinal_fit_scaled")
	hess <- list(
		InferenceOrdinalAdjCatLogitRegr = K("get_adjacent_category_logit_hessian_cpp"),
		InferenceOrdinalContRatioRegr = K("get_continuation_ratio_regression_hessian_cpp"))
	for (nm in names(classes)) {
		f <- uc107c_fixture(nm, 3)
		X <- cbind(treatment = f$w, x1 = f$x1)
		y <- as.numeric(f$y)
		if (nm == "InferenceOrdinalAdjCatLogitRegr") {
			r <- fit_scaled(K("fast_adjacent_category_logit_with_var_cpp"), X, y, force = TRUE, linpred_sign = -1)
			r0 <- K("fast_adjacent_category_logit_with_var_cpp")(X, y)
			r2 <- fit_scaled(K("fast_adjacent_category_logit_with_var_cpp"), X, y, force = TRUE, linpred_sign = -1,
				warm_start_params = r$params, warm_start_fisher_info = r$fisher_information)
		} else {
			r <- fit_scaled(K("fast_continuation_ratio_regression_with_var_cpp"), X, y, force = TRUE,
				linpred_sign = 1, warm_arg = "warm_start_beta")
			r0 <- K("fast_continuation_ratio_regression_with_var_cpp")(X, y)
			r2 <- fit_scaled(K("fast_continuation_ratio_regression_with_var_cpp"), X, y, force = TRUE,
				linpred_sign = 1, warm_arg = "warm_start_beta",
				warm_start_beta = r$params, warm_start_fisher_info = r$fisher_information)
		}
		# agrees with the unscaled fit on well-conditioned data and is a true optimum of the ORIGINAL likelihood
		expect_equal(r$params, r0$params, tolerance = 2e-3, label = nm)
		expect_equal(r$neg_loglik, r0$neg_loglik, tolerance = 1e-6, label = nm)
		H <- -hess[[nm]](X, y, r$params)
		expect_lt(max(abs(H - r$fisher_information)) / max(abs(H)), 1e-6)
		expect_lt(max(abs(solve(H) - r$vcov)) / max(abs(r$vcov)), 1e-6)
		expect_equal(r2$params, r$params, tolerance = 2e-3, label = nm)
	}
})

test_that("well-scaled data are passed through bit-identically (AdjCat, ContRatio)", {
	fit_scaled <- K("ordinal_fit_scaled")
	set.seed(1)
	X <- cbind(treatment = rep(0:1, 50), x1 = rnorm(100))
	y <- sample(1:4, 100, TRUE)
	expect_identical(fit_scaled(K("fast_adjacent_category_logit_cpp"), X, y, linpred_sign = -1),
		K("fast_adjacent_category_logit_cpp")(X, y))
	expect_identical(fit_scaled(K("fast_continuation_ratio_regression_cpp"), X, y, linpred_sign = 1, warm_arg = "warm_start_beta"),
		K("fast_continuation_ratio_regression_cpp")(X, y))
})
