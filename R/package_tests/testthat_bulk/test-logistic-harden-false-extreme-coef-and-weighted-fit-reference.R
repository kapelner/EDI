library(testthat)
library(EDI)

# InferenceIncidLogRegr's non-hardened generate_mod() branch (harden = FALSE),
# the is_logistic_fit_reasonable() coefficient-size predicate, the
# extreme-coefficient nonestimable paths (unweighted and weighted), and the
# weighted refit with its model-based SE. Reference: stats::glm(binomial).

logit_fixture <- function(harden, ygen, max_abs = 50, n = 80L, seed = 2L) {
	set.seed(seed)
	x <- rnorm(n)
	u <- runif(n)
	des <- DesignFixediBCRD$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- ygen(w, x, u)
	des$add_all_subject_responses(y)
	inf <- InferenceIncidLogRegr$new(des, harden = harden, max_abs_reasonable_coef = max_abs, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	priv$current_bayesian_bootstrap_context <- list(
		row_to_unit = seq_len(n), unit_group_id = rep(1L, n), n_units = n
	)
	list(inf = inf, priv = priv, w = w, x = x, y = y, n = n)
}

ordinary_y <- function(w, x, u) as.integer(u < plogis(0.3 + 0.8 * w + 0.5 * x))
separated_y <- function(w, x, u) as.integer(w == 1)

test_that("estimate_only and full fits match glm(binomial) with and without hardening", {
	for (harden in c(TRUE, FALSE)) {
		f <- logit_fixture(harden, ordinary_y)
		g <- glm(f$y ~ f$w + f$x, family = binomial())
		sg <- summary(g)$coefficients
		expect_equal(f$inf$compute_estimate(estimate_only = TRUE), unname(coef(g)[2]), tolerance = 1e-6, info = harden)

		f2 <- logit_fixture(harden, ordinary_y)
		expect_equal(f2$inf$compute_estimate(), unname(coef(g)[2]), tolerance = 1e-6, info = harden)
		expect_equal(f2$priv$cached_values$s_beta_hat_T, unname(sg[2, 2]), tolerance = 1e-4, info = harden)
		expect_equal(f2$priv$best_X_colnames, "x", info = harden)
		expect_equal(unname(f2$priv$cached_mod$vcov[2, 2]), unname(sg[2, 2])^2, tolerance = 1e-3, info = harden)
		ctx <- f2$priv$cached_values$likelihood_test_context
		expect_equal(ctx$j_treat, 2L, info = harden)
		expect_equal(as.numeric(ctx$full_neg_loglik), -as.numeric(logLik(g)), tolerance = 1e-5, info = harden)
	}
})

test_that("is_logistic_fit_reasonable enforces presence, finiteness and the coefficient-size cap", {
	f <- logit_fixture(FALSE, ordinary_y)
	ok <- f$priv$is_logistic_fit_reasonable
	expect_false(ok(NULL))
	expect_false(ok(list(b = NULL)))
	expect_false(ok(list(b = 1)))
	expect_true(ok(list(b = c(1, -2))))
	expect_true(ok(list(b = c(50, -50))))
	expect_false(ok(list(b = c(1, 50.01))))
	expect_false(ok(list(b = c(1, NA))))
	expect_false(ok(list(b = c(Inf, 1))))

	f5 <- logit_fixture(FALSE, ordinary_y, max_abs = 5)
	expect_true(f5$priv$is_logistic_fit_reasonable(list(b = c(1, 4.9))))
	expect_false(f5$priv$is_logistic_fit_reasonable(list(b = c(1, 5.1))))
})

test_that("a perfectly separated fit exceeding the coefficient cap is nonestimable (non-hardened path)", {
	f <- logit_fixture(FALSE, separated_y, max_abs = 5)
	f$inf$compute_estimate()
	expect_true(f$inf$is_nonestimable("estimate"))
	expect_null(f$priv$cached_values$likelihood_test_context)

	f2 <- logit_fixture(FALSE, separated_y, max_abs = 5)
	f2$inf$compute_estimate(estimate_only = TRUE)
	expect_true(f2$inf$is_nonestimable("estimate"))

	# The same data under the default cap is still "reasonable" (coefficients < 50).
	f3 <- logit_fixture(FALSE, separated_y)
	expect_true(is.finite(f3$inf$compute_estimate()))
})

test_that("weighted refit matches a weighted glm with model-based SE, and extreme weighted fits are nonestimable", {
	f <- logit_fixture(TRUE, ordinary_y)
	set.seed(6)
	ww <- runif(f$n, 0.3, 2)
	est <- f$inf$compute_estimate_with_bootstrap_weights(ww)
	g <- suppressWarnings(glm(f$y ~ f$w + f$x, family = binomial(), weights = ww))
	expect_equal(est, unname(coef(g)[2]), tolerance = 1e-5)
	expect_equal(f$priv$last_weighted_refit$s_beta_hat_T, unname(summary(g)$coefficients[2, 2]), tolerance = 1e-3)

	f_est_only <- logit_fixture(TRUE, ordinary_y)
	f_est_only$inf$compute_estimate_with_bootstrap_weights(ww, estimate_only = TRUE)
	expect_true(is.na(f_est_only$priv$last_weighted_refit$s_beta_hat_T))

	fs <- logit_fixture(TRUE, separated_y, max_abs = 5)
	expect_true(is.na(fs$inf$compute_estimate_with_bootstrap_weights(rep(1, fs$n))))
	expect_true(fs$priv$weighted_refit_is_nonestimable("estimate"))
	expect_false(fs$inf$is_nonestimable("any"))                       # the ordinary cache is not flagged by the weighted refit
})
