library(testthat)
library(EDI)

# PROPOSED probe-gated test for cpp patch 08 (Cox Newton descent guard + maxit 20 -> 100, Survey 2).
# NOT in the live suite: copy to R/EDI/tests/testthat/ after the patched kernel is built.
# Fixture: n = 40, DGP 2, seed 15 from /tmp/claude-1000/tsurvey2/run_cox.R (cox_data copied below);
# pre-patch cold Newton reports converged = TRUE at bT = 166.03 while coxph/LBFGS give 3.385873.

# EDI_REQUIRE_CPP_PATCHES=true turns "patch not applied" skips into failures: set it once the
# patches are built so a regression back to the old behavior cannot hide behind the probe skip.
skip_unless_patched = function(applied, msg) {
	if (isTRUE(applied)) return(invisible(TRUE))
	if (identical(Sys.getenv("EDI_REQUIRE_CPP_PATCHES"), "true")) testthat::fail(msg) else testthat::skip(msg)
}

cox_data = function(n, dgp, seed){
	set.seed(seed * 977 + n + dgp)
	if (dgp == 1) {
		w = rbinom(n, 1, .5); x1 = rnorm(n); x2 = rnorm(n); lp = .5 * w + .3 * x1 - .2 * x2
		t = rweibull(n, 1.5, exp(-lp / 1.5)); cen = rexp(n, .35)
	} else {
		w = rbinom(n, 1, .1); x1 = exp(rnorm(n, 0, 1.5)); x2 = rnorm(n); lp = 2.5 * w + .3 * log(x1) - .2 * x2
		t = rweibull(n, 1, exp(-lp)); cen = rexp(n, 1.2); t = round(t, 1) + 0.1; cen = round(cen, 1) + 0.1
	}
	list(X = cbind(w, x1, x2), y = pmin(t, cen), dead = as.numeric(t <= cen))
}

test_that("cold Newton Cox never reports converged = TRUE at a divergent iterate (patch 08)", {
	skip_on_cran()
	d = cox_data(40L, 2L, 15L)
	nr = suppressWarnings(EDI:::fast_coxph_regression_cpp(d$X, d$y, d$dead, smart_cold_start = FALSE, optimization_alg = "newton_raphson"))
	diverged_converged = isTRUE(nr$converged) && abs(nr$coefficients[1L]) > 100
	skip_unless_patched(!diverged_converged, "Cox Newton descent guard not applied (converged = TRUE at bT = 166)")
	truth = 3.385873  # survival::coxph(ties = "breslow") and the LBFGS kernel agree on this fixture
	expect_false(isTRUE(nr$converged) && abs(nr$coefficients[1L] - truth) > 1e-3)
	# well-behaved fixtures follow their previous path (guard accepts candidates within tol)
	d1 = cox_data(40L, 1L, 1L)
	ok = EDI:::fast_coxph_regression_cpp(d1$X, d1$y, d1$dead, smart_cold_start = FALSE, optimization_alg = "newton_raphson")
	expect_true(isTRUE(ok$converged))
	expect_equal(ok$coefficients[1L], 0.682037781466304, tolerance = 1e-8)
})

test_that("Cox kernels default maxit is 100 (patch 08b)", {
	f = EDI:::fast_coxph_regression_cpp
	skip_unless_patched(identical(as.numeric(formals(f)$maxit), 100), "Cox maxit 20 -> 100 default not applied")
	expect_identical(as.numeric(formals(EDI:::fast_stratified_coxph_regression_cpp)$maxit), 100)
})
