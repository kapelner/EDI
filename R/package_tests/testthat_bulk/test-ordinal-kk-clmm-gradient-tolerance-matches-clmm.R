library(testthat)
library(EDI)

# The KK CLMM classes used to call fast_ordinal_clmm_cpp(eps_g = 1e-3).  With the LBFGS criterion
# `gnorm < tol || niter < maxit` that reports converged = TRUE while the treatment coefficient is still
# ~0.03-0.08 log-odds from the maximum (optimize_likelihood_newton_false_nonconvergence.md, Survey 2:
# median error 0.05-0.07 at 1e-3 vs 2e-4 at 1e-6).  The class now uses private$clmm_eps_g = 1e-6, so
# its estimate must sit within 2e-3 of ordinal::clmm(nAGQ = 20) on this fixture
# (before: 6e-3, 3.8e-2, 3.2e-2 on seeds 302, 303, 305; after: <= 5.2e-4).

skip_if_not_installed("ordinal")

fx <- function(seed, n = 200L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(response_type = "ordinal", n = n, verbose = FALSE)
	X <- data.frame(x = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	m <- des$.__enclos_env__$private$m[seq_len(n)]
	u <- ifelse(m > 0, rnorm(max(m))[pmax(m, 1)], 0) * 0.9
	y <- as.integer(cut(0.7 * w + 0.4 * X$x + u + rlogis(n), c(-Inf, -1, 0.5, Inf)))
	des$add_all_subject_responses(y)
	d <- data.frame(y = factor(y, ordered = TRUE), w = w, x = X$x,
		g = factor(ifelse(m > 0, paste0("p", m), paste0("s", seq_along(m)))))
	list(des = des, d = d)
}

test_that("KK CLMM class treatment estimate is within 2e-3 of ordinal::clmm(nAGQ = 20)", {
	for (s in c(302L, 303L, 305L)) {
		f <- fx(s)
		mm <- suppressWarnings(ordinal::clmm(y ~ w + x + (1 | g), data = f$d, link = "logit", nAGQ = 20))
		inf <- InferenceOrdinalKKCLMM$new(f$des, verbose = FALSE)
		expect_equal(inf$.__enclos_env__$private$clmm_eps_g, 1e-6)
		expect_equal(unname(inf$compute_estimate()), unname(coef(mm)["w"]), tolerance = 2e-3, scale = 1, info = as.character(s))
	}
})
