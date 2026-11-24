library(testthat)
library(EDI)

# v1.0.6-TODO-425: on Poisson-like positive counts the zero-truncated negative-binomial count
# part of InferenceCountHurdleNegBin can stop at an enormous theta (1e7 to 1e15, depending on
# the platform's floating point) with converged = TRUE but no Poisson-boundary flag. There the
# C++ observed information is numerically meaningless (entries ~1e26, negative definite), the
# treatment variance came back negative, and the fit was rejected: the class fell back silently
# to the treatment-only model and lost the hurdle separation flag. Seen only on the R-devel
# valgrind and ASAN/UBSAN legs of R-CMD-check run 45295584606; reproduced locally by perturbing
# x1 by 1e-12 relative. Here the bad kernel output is injected so every platform runs the path.

hurdle_negbin_limit_fixture = function() {
	old_seed = if (exists(".Random.seed", envir = globalenv())) get(".Random.seed", envir = globalenv()) else NULL
	on.exit(if (!is.null(old_seed)) assign(".Random.seed", old_seed, envir = globalenv()), add = TRUE)
	set.seed(11)
	n = 50
	x1 = rnorm(n)
	w = sample(rep(0:1, n / 2))
	y = ifelse(x1 < 0, 0, 1 + rpois(n, exp(0.3 + 0.2 * w)))
	des = DesignFixediBCRD$new(n = n, response_type = "count", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = x1))
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(y)
	list(des = des, X = cbind(1, w, x1), y = y)
}

# The kernel's output at the platform-dependent failure: same coefficients, theta ~2.5e15 and a
# garbage, negative definite information with a negative treatment variance.
garbage_at_huge_theta = function(mod) {
	mod$theta_hat = 2.45497e15
	mod$dispersion_at_poisson_boundary = FALSE
	k = nrow(mod$observed_information)
	garbage = -1e25 * (diag(k) + 0.5)
	mod$observed_information = garbage
	mod$fisher_information = garbage
	mod$information = garbage
	mod$hessian = -garbage
	mod$ssq_b_j = -3.181548e-26
	mod$ssq_b_2 = -3.181548e-26
	mod
}

test_that("a usable hurdle negative-binomial information is returned unchanged", {
	fx = hurdle_negbin_limit_fixture()
	mod = EDI:::fast_hurdle_negbin_with_var_cpp(fx$X, fx$y, X_hurdle = fx$X, j = 2L)
	expect_identical(EDI:::hurdle_negbin_poisson_limit_information(mod, fx$X, fx$y, 2L), mod)
	mod$theta_hat = 50
	mod$ssq_b_j = -1
	expect_identical(EDI:::hurdle_negbin_poisson_limit_information(mod, fx$X, fx$y, 2L), mod)
})

test_that("at the Poisson limit a broken information is replaced by the zero-truncated Poisson one", {
	fx = hurdle_negbin_limit_fixture()
	mod = garbage_at_huge_theta(EDI:::fast_hurdle_negbin_with_var_cpp(fx$X, fx$y, X_hurdle = fx$X, j = 2L))
	fixed = EDI:::hurdle_negbin_poisson_limit_information(mod, fx$X, fx$y, 2L)
	expect_true(fixed$dispersion_at_poisson_boundary)
	pos = fx$y > 0
	Xp = fx$X[pos, , drop = FALSE]
	mu = exp(drop(Xp %*% mod$b))
	# d^2/d eta^2 of the zero-truncated Poisson log-likelihood, by hand
	v = mu / (1 - exp(-mu)) * (1 - mu * exp(-mu) / (1 - exp(-mu)))
	info_b = crossprod(Xp, Xp * v)
	expect_equal(unname(fixed$observed_information[1:3, 1:3]), unname(info_b), tolerance = 1e-8)
	expect_equal(unname(fixed$observed_information[4, ]), c(0, 0, 0, 1))
	expect_equal(fixed$ssq_b_j, solve(info_b)[2, 2], tolerance = 1e-8)
	expect_identical(fixed$b, mod$b)
	expect_identical(fixed$hurdle_b, mod$hurdle_b)
})

test_that("InferenceCountHurdleNegBin keeps the covariate fit and the hurdle separation flag at a broken huge-theta information", {
	fx = hurdle_negbin_limit_fixture()
	ref = InferenceCountHurdlePoisson$new(fx$des, verbose = FALSE)
	ref_est = suppressWarnings(ref$compute_estimate())
	ref_ci = suppressWarnings(ref$compute_asymp_confidence_interval())
	real_kernel = EDI:::fast_hurdle_negbin_with_var_cpp
	testthat::local_mocked_bindings(
		fast_hurdle_negbin_with_var_cpp = function(...) garbage_at_huge_theta(real_kernel(...)),
		.package = "EDI"
	)
	inf = InferenceCountHurdleNegBin$new(fx$des, verbose = FALSE)
	ws = list()
	est = withCallingHandlers(inf$compute_estimate(),
		warning = function(w) { ws[[length(ws) + 1L]] <<- w; invokeRestart("muffleWarning") })
	sep = Filter(function(w) inherits(w, "edi_zero_part_separation_warning"), ws)
	expect_length(sep, 1L)
	expect_identical(inf$.__enclos_env__$private$cached_values$zero_part_nonestimable_reason, "zero_part_separated")
	# the covariate-adjusted count part, not the treatment-only fallback (-0.028)
	expect_equal(est, ref_est, tolerance = 1e-3)
	# at the Poisson limit the count part is the hurdle-Poisson count part: same Wald interval
	expect_equal(suppressWarnings(inf$compute_asymp_confidence_interval()), ref_ci, tolerance = 1e-3)
})
