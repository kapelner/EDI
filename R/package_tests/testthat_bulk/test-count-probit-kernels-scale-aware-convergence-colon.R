# v1.0.6-TODO-169 / v1.0.6-TODO-170: on the colon design with a large-scale or
# offset covariate (age x 1000, age + 1e5) the L-BFGS wrapper declared
# convergence at LBFGSpp's early relative-decrease stop (NegBin treatment 0,
# probit -0.149) and IRLS / Newton reported a correct fit as not converged
# (absolute gradient tolerance). The shared scale-aware rule (Newton decrement
# within glm()'s relative deviance tolerance, _helper_functions_core.h) now
# finishes L-BFGS with damped Newton steps and accepts IRLS / Newton fits at the
# optimum. Estimates must match the R reference fitters on every variant.

colon_scaling_design = function(variant, drop_nodes = FALSE) {
	d = subset(survival::colon, etype == 2 & rx %in% c("Obs", "Lev+5FU"))
	covs = c("age", "sex", "obstruct", "perfor", "adhere", "nodes", "differ", "extent", "surg")
	d = d[stats::complete.cases(d[, c("status", "rx", covs)]), ]
	Z = as.matrix(d[, covs])
	if (variant == "x1000") Z[, "age"] = Z[, "age"] * 1000
	if (variant == "plus1e5") Z[, "age"] = Z[, "age"] + 1e5
	if (drop_nodes) Z = Z[, colnames(Z) != "nodes"]
	if (variant == "scaled") Z = scale(Z)
	X = cbind(1, as.numeric(d$rx == "Lev+5FU"), Z)
	dimnames(X) = NULL
	list(X = X, y_count = pmax(d$nodes - 1L, 0L), y_bin = d$status)
}

scaling_variants = c("raw", "scaled", "x1000", "plus1e5")

test_that("NegBin L-BFGS and Newton reach the glm.nb MLE on rescaled colon covariates", {
	skip_if_not_installed("survival")
	skip_if_not_installed("MASS")
	for (v in scaling_variants) {
		z = colon_scaling_design(v, drop_nodes = TRUE)
		ref = unname(stats::coef(MASS::glm.nb(z$y_count ~ z$X - 1))[2])
		for (alg in c("lbfgs", "newton_raphson")) for (scs in c(FALSE, TRUE)) {
			# smart_cold_start = TRUE is the class default (InferenceCountNegBin); its start on
			# age x 1000 / age + 1e5 sent L-BFGS to NaN before the Newton finish from the start.
			fit = fast_neg_bin_cpp(z$X, z$y_count, smart_cold_start = scs, optimization_alg = alg)
			expect_true(isTRUE(fit$converged), info = paste(v, alg, scs))
			expect_equal(fit$b[2], ref, tolerance = 2e-3, info = paste(v, alg, scs))
		}
	}
})

test_that("Poisson IRLS, L-BFGS and Newton reach the glm MLE and report convergence on rescaled colon covariates", {
	skip_if_not_installed("survival")
	for (v in scaling_variants) {
		z = colon_scaling_design(v, drop_nodes = TRUE)
		ref = unname(stats::coef(stats::glm(z$y_count ~ z$X - 1, family = stats::poisson()))[2])
		for (alg in c("irls", "lbfgs", "newton_raphson")) {
			# maxit = 1000 for all: an L-BFGS run that hits the default 100-iteration cap on the raw
			# design is judged by the rule without extra steps and stays converged = FALSE.
			fit = fast_poisson_regression_cpp(z$X, z$y_count, optimization_alg = alg, maxit = 1000L)
			expect_true(isTRUE(fit$converged), info = paste(v, alg))
			expect_equal(fit$b[2], ref, tolerance = 1e-4, info = paste(v, alg))
		}
	}
})

test_that("probit IRLS and L-BFGS reach the glm MLE and report convergence on rescaled colon covariates", {
	skip_if_not_installed("survival")
	for (v in scaling_variants) {
		z = colon_scaling_design(v)
		ref = unname(stats::coef(stats::glm(z$y_bin ~ z$X - 1, family = stats::binomial("probit"),
			control = stats::glm.control(epsilon = 1e-12, maxit = 100)))[2])
		for (alg in c("irls", "lbfgs")) {
			fit = fast_probit_regression_cpp(z$X, z$y_bin, optimization_alg = alg, maxit = 1000L)
			expect_true(isTRUE(fit$converged), info = paste(v, alg))
			expect_equal(fit$b[2], ref, tolerance = 1e-3, info = paste(v, alg))
		}
	}
})
