library(testthat)
library(EDI)

# InferencePropFractionalLogit's harden = FALSE branches (compute_estimate()'s
# estimate_only glm.fit shortcut and generate_mod()'s non-hardened branch) and
# compute_estimate_with_bootstrap_weights()'s empty-weight early return.
# Independent reference: stats::glm(family = quasibinomial()), whose Pearson
# dispersion-scaled standard error is what the class's Papke-Wooldridge
# correction reproduces.

frac_fixture <- function(harden, seed = 3L, n = 80L) {
	set.seed(seed)
	x <- rnorm(n)
	des <- DesignFixediBCRD$new(n = n, response_type = "proportion", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- pmin(pmax(plogis(0.3 * w + 0.5 * x + rnorm(n, sd = 0.5)), 0.02), 0.98)
	des$add_all_subject_responses(y)
	inf <- InferencePropFractionalLogit$new(des, harden = harden, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	priv$current_bayesian_bootstrap_context <- list(
		row_to_unit = seq_len(n), unit_group_id = rep(1L, n), n_units = n
	)
	list(inf = inf, priv = priv, w = w, x = x, y = y, n = n)
}

test_that("estimate_only and full fits match glm(quasibinomial) with and without hardening", {
	for (harden in c(TRUE, FALSE)) {
		f <- frac_fixture(harden)
		g <- glm(f$y ~ f$w + f$x, family = quasibinomial())
		sg <- summary(g)$coefficients

		expect_equal(f$inf$compute_estimate(estimate_only = TRUE), unname(coef(g)[2]), tolerance = 1e-6, info = harden)
		expect_equal(f$priv$best_X_colnames, "x", info = harden)

		f2 <- frac_fixture(harden)
		expect_equal(f2$inf$compute_estimate(), unname(coef(g)[2]), tolerance = 1e-6, info = harden)
		expect_equal(f2$priv$cached_values$s_beta_hat_T, unname(sg[2, 2]), tolerance = 1e-4, info = harden)
		expect_equal(f2$priv$cached_mod$dispersion, summary(g)$dispersion, tolerance = 1e-4, info = harden)
		z <- unname(coef(g)[2]) / unname(sg[2, 2])
		expect_equal(f2$inf$compute_asymp_two_sided_pval(), 2 * pnorm(-abs(z)), tolerance = 1e-3, info = harden)
	}
})

test_that("harden = FALSE estimate_only caches the value and reuses it", {
	f <- frac_fixture(FALSE)
	est <- f$inf$compute_estimate(estimate_only = TRUE)
	expect_equal(f$priv$cached_values$beta_hat_T, est)
	f$priv$cached_values$beta_hat_T <- 42
	expect_equal(f$inf$compute_estimate(estimate_only = TRUE), 42)
})

test_that("weighted refit: all-zero weights give NA and clear the cached model; zero weights drop rows", {
	f <- frac_fixture(TRUE)
	f$inf$compute_estimate()
	expect_false(is.null(f$priv$cached_mod))
	expect_true(is.na(f$inf$compute_estimate_with_bootstrap_weights(rep(0, f$n))))
	expect_null(f$priv$cached_mod)
	expect_true(is.na(f$priv$cached_values$beta_hat_T))
	expect_true(is.na(f$priv$cached_values$s_beta_hat_T))

	f2 <- frac_fixture(TRUE)
	set.seed(5)
	ww <- runif(f2$n, 0.3, 2)
	ww[1:3] <- 0
	est <- f2$inf$compute_estimate_with_bootstrap_weights(ww)
	ref <- unname(coef(suppressWarnings(glm(f2$y ~ f2$w + f2$x, family = quasibinomial(), weights = ww / max(ww))))[2])
	expect_equal(est, ref, tolerance = 1e-5)
	expect_true(is.na(f2$priv$cached_values$s_beta_hat_T))
})
