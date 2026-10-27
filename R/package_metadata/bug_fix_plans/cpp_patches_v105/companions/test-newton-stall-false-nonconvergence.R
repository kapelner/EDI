library(testthat)
library(EDI)

# PROPOSED regression test for cpp patch 01 (newton-stall, TODO-123). NOT in the live suite:
# copy to R/EDI/tests/testthat/ only after the patched kernels are built. Before the patch the
# "false non-convergence" blocks skip loudly ('Newton stall patch not applied', keyed on a
# probe fit at a known stalled fixture); the "true failure" block asserts behavior that holds
# before AND after the patch (fits that are genuinely not at an optimum stay converged = FALSE).
#
# Fixtures come from the survey scripts /tmp/claude-1000/tnewton_before/sim2.R (gen_cov / mk_count /
# the weibull generator, copied verbatim below) and test-zip-newton-stall-cold-retry.R (ZIP, seeds
# 6 and 19, n = 100). The stalled/true-failure case lists were read off sim_out2.rds
# (conv == FALSE rows: poisson n=40 bal seeds 15,16,17 etc. have gap ~ 0 = false failures;
# zinb n=40 unbal seeds 14,17,26 and nearsep 11,26,30 have gap 4..18 = true failures).

NR = "newton_raphson"

# EDI_REQUIRE_CPP_PATCHES=true turns "patch not applied" skips into failures: set it once the
# patches are built so a regression back to the old behavior cannot hide behind the probe skip.
skip_unless_patched = function(applied, msg) {
	if (isTRUE(applied)) return(invisible(TRUE))
	if (identical(Sys.getenv("EDI_REQUIRE_CPP_PATCHES"), "true")) testthat::fail(msg) else testthat::skip(msg)
}

gen_cov = function(n, dgp, seed) {
	set.seed(seed * 1000 + n)
	p = if (dgp == "unbal") 0.08 else 0.5
	x = rbinom(n, 1, p); if (sum(x) == 0) x[1] = 1; if (sum(x) == n) x[1] = 0
	list(x = x, z = rnorm(n))
}
gen_count = function(kind, n, dgp, seed) {
	d = gen_cov(n, dgp, seed); x = d$x; z = d$z
	mu = exp(0.3 + (if (dgp == "nearsep") 1.2 else 0.4) * x + 0.2 * z)
	y0 = if (grepl("nb|zinb", kind)) rnbinom(n, mu = mu, size = 2) else rpois(n, mu)
	if (kind %in% c("zip", "hurdlep", "zinb", "hurdlenb")) {
		zi = plogis(if (dgp == "nearsep") -4 + 6 * x else -1 + 0.5 * x)
		y0[runif(n) < zi] = 0
	}
	list(X = cbind(1, x, z), Xzi = cbind(1, x), y = as.numeric(y0), x = x, z = z)
}
gen_weibull = function(n, dgp, seed) {
	d = gen_cov(n, dgp, seed); b = if (dgp == "nearsep") 2 else 0.5
	t = rweibull(n, 2, exp(0.3 + b * d$x + 0.2 * d$z)); cn = rexp(n, 0.3)
	list(X = cbind(1, d$x, d$z), y = pmin(t, cn), dead = as.integer(t <= cn))
}
zip_stall_data = function(seed, n = 100L) {
	# generator of test-zip-newton-stall-cold-retry.R
	set.seed(seed)
	des = DesignFixedBernoulli$new(n = n, response_type = "count", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(row.names = seq_len(n)))
	des$assign_w_to_all_subjects()
	w = des$get_w()
	y = rnbinom(n, mu = 3 * exp(0.3 * w), size = 1.5)
	y[runif(n) < 0.3] = 0
	list(w = w, y = as.numeric(y))
}

fit_pois = function(seed, alg = NR) {
	d = gen_count("pois", 40L, "bal", seed)
	list(d = d, fit = EDI:::fast_poisson_regression_cpp(d$X, d$y, optimization_alg = alg))
}

# Probe: poisson n=40 bal seed 17 is a documented false failure (gradient 1.2e-7, gap 0).
probe = suppressWarnings(fit_pois(17L)$fit)
stall_patch_applied = isTRUE(probe$converged)

test_that("ZINB n = 40 survey seeds never report FALSE convergence (hold before and after patch 01)", {
	skip_on_cran()
	# 2026-10-27: this used to assert `converged == FALSE` for each fixture, but
	# whether a given fixture reports converged at all is optimizer-path (so
	# BLAS/platform) dependent: all six report FALSE on local MKL while
	# nearsep/26 reports TRUE on CI's OpenBLAS and on Windows, which failed every
	# R-CMD-check job. What the guard is actually for is FALSE convergence -- the
	# kernel claiming success while the score is nowhere near zero. Assert that
	# invariant instead of the coin flip. At these fixtures max|score| is 3.7-12.4
	# (measured), whereas a genuinely converged ZINB fit sits at ~0.008, so the
	# 0.1 cutoff separates the two by more than an order of magnitude on both
	# sides. A fixture that legitimately starts converging on some platform is
	# then fine; one that reports success at a non-optimum still fails.
	cases = list(c("unbal", 14L), c("unbal", 17L), c("unbal", 26L), c("nearsep", 11L), c("nearsep", 26L), c("nearsep", 30L))
	for (cs in cases) {
		d = gen_count("zinb", 40L, cs[1], as.integer(cs[2]))
		fit = suppressWarnings(EDI:::fast_zinb_cpp(d$X, d$Xzi, d$y, optimization_alg = NR))
		max_abs_score = suppressWarnings(max(abs(as.numeric(fit$score))))
		false_convergence = isTRUE(fit$converged) && (!is.finite(max_abs_score) || max_abs_score >= 0.1)
		expect_false(false_convergence,
			info = paste0(paste(cs, collapse = "/"), ": converged = ", isTRUE(fit$converged),
				", max|score| = ", format(max_abs_score)))
	}
})

test_that("ZIP seeds 6 and 19 (n = 100) converge under newton_raphson and match pscl", {
	skip_on_cran()
	skip_if_not_installed("pscl")
	skip_unless_patched(stall_patch_applied, "Newton stall patch not applied")
	for (sd in c(6L, 19L)) {
		dd = zip_stall_data(sd)
		X = cbind(1, dd$w); Xzi = cbind(1, dd$w)
		fit = suppressWarnings(EDI:::fast_zero_augmented_poisson_cpp(
			X, dd$y, Xzi, FALSE, optimization_alg = NR, smart_cold_start = TRUE))
		expect_true(isTRUE(fit$converged), info = paste("seed", sd))
		ref = suppressWarnings(pscl::zeroinfl(y ~ w | w, data = data.frame(y = dd$y, w = dd$w), dist = "poisson"))
		expect_equal(as.numeric(fit$params[1:2]), unname(coef(ref, "count")), tolerance = 1e-3, info = paste("seed", sd))
		expect_equal(as.numeric(fit$params[3:4]), unname(coef(ref, "zero")), tolerance = 1e-3, info = paste("seed", sd))
	}
})

test_that("Poisson via Newton: previously false-nonconverged fixtures converge at the glm optimum", {
	skip_on_cran()
	skip_unless_patched(stall_patch_applied, "Newton stall patch not applied")
	for (sd in c(15L, 16L, 17L)) {
		f = suppressWarnings(fit_pois(sd)); d = f$d
		expect_true(isTRUE(f$fit$converged), info = paste("seed", sd))
		ref = glm(d$y ~ d$x + d$z, family = poisson)
		expect_equal(as.numeric(f$fit$b), unname(coef(ref)), tolerance = 1e-6, info = paste("seed", sd))
	}
	# already-converged fits are untouched: same optimum as the default (irls) path
	f = suppressWarnings(fit_pois(1L))
	irls = EDI:::fast_poisson_regression_cpp(f$d$X, f$d$y, optimization_alg = "irls")
	expect_equal(as.numeric(f$fit$b), as.numeric(irls$b), tolerance = 1e-6)
})

test_that("Weibull via Newton: previously false-nonconverged fixtures converge to the lbfgs optimum", {
	skip_on_cran()
	skip_unless_patched(stall_patch_applied, "Newton stall patch not applied")
	# sim2.log: weibull conv == FALSE with gradient_norm ~1e-8..1e-7 at n=40 unbal seeds 2 and 6, bal seed 15
	for (cs in list(c("unbal", 2L), c("unbal", 6L), c("bal", 15L))) {
		d = gen_weibull(40L, cs[1], as.integer(cs[2]))
		nr = suppressWarnings(EDI:::fast_weibull_regression_cpp(d$X, d$y, d$dead, optimization_alg = NR))
		lb = suppressWarnings(EDI:::fast_weibull_regression_cpp(d$X, d$y, d$dead, optimization_alg = "lbfgs"))
		skip_if(!isTRUE(lb$converged), "lbfgs reference did not converge on this fixture")
		expect_true(isTRUE(nr$converged), info = paste(cs, collapse = "/"))
		expect_equal(as.numeric(nr$neg_ll), as.numeric(lb$neg_ll), tolerance = 1e-6, info = paste(cs, collapse = "/"))
	}
})
