library(testthat)
library(EDI)

# The count-likelihood plumbing shared by InferenceCountPoisson & co.
# (inference_all_abstract_count_likelihood.R): shared() caching, information-
# matrix SE, Wald / score / gradient / likelihood-ratio p-values against
# classical glm() statistics, the block-size guard
# (count_likelihood_block_asymp_unsupported / mark_..._nonestimable) and the
# missing-CI helper. Also checks that the dedicated *_confidence_interval methods
# invert their own test. References: stats::glm(family = poisson()) and its offset-based null fits.

pois_fixture <- function(n = 80L, seed = 3L) {
	set.seed(seed)
	x <- rnorm(n)
	des <- DesignFixediBCRD$new(n = n, response_type = "count", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- rpois(n, exp(0.4 + 0.3 * w + 0.2 * x))
	des$add_all_subject_responses(y)
	inf <- InferenceCountPoisson$new(des, verbose = FALSE)
	list(inf = inf, priv = inf$.__enclos_env__$private, w = w, x = x, y = y)
}

ref_stats <- function(f) {
	g <- glm(f$y ~ f$w + f$x, family = poisson())
	null_fit <- function(d) glm(f$y ~ f$x + offset(d * f$w), family = poisson())
	list(
		g = g, bhat = unname(coef(g)[2]), se = summary(g)$coefficients[2, 2],
		lr = function(d) 2 * (as.numeric(logLik(g)) - as.numeric(logLik(null_fit(d)))),
		score = function(d) {
			m <- null_fit(d); mu <- fitted(m); X <- cbind(1, f$x, f$w)
			U <- sum(f$w * (f$y - mu)); I <- crossprod(X * sqrt(mu))
			U^2 / as.numeric(I[3, 3] - I[3, 1:2] %*% solve(I[1:2, 1:2]) %*% I[1:2, 3])
		},
		gradient = function(d) {
			m <- null_fit(d)
			abs(sum(f$w * (f$y - fitted(m))) * (unname(coef(g)[2]) - d))
		}
	)
}

test_that("estimate, SE (information-matrix based) and df match glm(poisson)", {
	f <- pois_fixture(); r <- ref_stats(f)
	expect_equal(f$inf$compute_estimate(), r$bhat, tolerance = 1e-6)
	expect_equal(f$priv$get_standard_error(), r$se, tolerance = 1e-5)
	expect_equal(f$priv$cached_values$s_beta_hat_T, r$se, tolerance = 1e-5)
	expect_equal(f$priv$get_degrees_of_freedom(), Inf)

	e <- pois_fixture()
	e$inf$compute_estimate(estimate_only = TRUE)
	expect_equal(e$priv$cached_values$beta_hat_T, r$bhat, tolerance = 1e-6)
	expect_null(e$priv$cached_values$s_beta_hat_T)                 # SE not computed for estimate_only
})

test_that("a missing model leaves NA estimate, SE and df", {
	f <- pois_fixture()
	unlockBinding("generate_mod", f$priv)
	f$priv$generate_mod <- function(estimate_only = FALSE) NULL
	f$priv$shared()
	expect_true(all(is.na(c(f$priv$cached_values$beta_hat_T, f$priv$cached_values$s_beta_hat_T, f$priv$cached_values$df))))
})

test_that("Wald interval and p-value are the normal-theory formulas", {
	f <- pois_fixture(); r <- ref_stats(f)
	ci <- f$inf$compute_wald_confidence_interval(alpha = 0.1)
	expect_equal(as.numeric(ci), r$bhat + c(-1, 1) * qnorm(0.95) * r$se, tolerance = 1e-5)
	expect_equal(f$inf$compute_wald_two_sided_pval(0.2), 2 * pnorm(-abs((r$bhat - 0.2) / r$se)), tolerance = 1e-5)
	# The default (wald) asymptotic entry points agree.
	expect_equal(as.numeric(f$inf$compute_asymp_confidence_interval(alpha = 0.1)), as.numeric(ci), tolerance = 1e-10)
	expect_equal(f$inf$compute_asymp_two_sided_pval(0.2), f$inf$compute_wald_two_sided_pval(0.2), tolerance = 1e-10)
})

test_that("score, gradient and likelihood-ratio p-values match the classical chi-square statistics", {
	f <- pois_fixture(); r <- ref_stats(f)
	for (delta in c(0, 0.2, 0.9)) {
		expect_equal(f$inf$compute_lik_ratio_two_sided_pval(delta), pchisq(r$lr(delta), 1, lower.tail = FALSE), tolerance = 1e-3, info = delta)
		expect_equal(f$inf$compute_score_two_sided_pval(delta), pchisq(r$score(delta), 1, lower.tail = FALSE), tolerance = 1e-3, info = delta)
		expect_equal(f$inf$compute_gradient_two_sided_pval(delta), pchisq(r$gradient(delta), 1, lower.tail = FALSE), tolerance = 1e-3, info = delta)
	}
})

test_that("with the configured test set explicitly, the asymptotic interval is the matching inverted interval", {
	f <- pois_fixture(); r <- ref_stats(f)
	cr <- qchisq(0.95, 1)
	roots <- function(stat) c(uniroot(function(d) stat(d) - cr, c(r$bhat - 6 * r$se, r$bhat), tol = 1e-9)$root,
		uniroot(function(d) stat(d) - cr, c(r$bhat, r$bhat + 6 * r$se), tol = 1e-9)$root)
	for (tt in c("lik_ratio", "score", "gradient")) {
		f$inf$set_testing_type(tt)
		expect_equal(as.numeric(f$inf$compute_asymp_confidence_interval(alpha = 0.05)), roots(r[[if (tt == "lik_ratio") "lr" else tt]]),
			tolerance = 3e-3, info = tt)
	}
})

test_that("dedicated *_confidence_interval methods invert the test they are named for, regardless of the configured type", {
	f <- pois_fixture(); r <- ref_stats(f)
	expect_equal(f$inf$get_testing_type(), "wald")
	cr <- qchisq(0.95, 1)
	roots <- function(stat) c(uniroot(function(d) stat(d) - cr, c(r$bhat - 6 * r$se, r$bhat), tol = 1e-9)$root,
		uniroot(function(d) stat(d) - cr, c(r$bhat, r$bhat + 6 * r$se), tol = 1e-9)$root)
	wald <- as.numeric(f$inf$compute_wald_confidence_interval(alpha = 0.05))
	for (spec in list(c("compute_score_confidence_interval", "score"), c("compute_gradient_confidence_interval", "gradient"),
			c("compute_lik_ratio_confidence_interval", "lr"))) {
		ci <- as.numeric(f$inf[[spec[1]]](alpha = 0.05))
		expect_equal(ci, roots(r[[spec[2]]]), tolerance = 3e-3, info = spec[1])
		expect_false(isTRUE(all.equal(ci, wald, tolerance = 1e-5)), info = spec[1])
	}
	# The configured type no longer leaks into the dedicated methods.
	f$inf$set_testing_type("score")
	expect_equal(as.numeric(f$inf$compute_lik_ratio_confidence_interval(alpha = 0.05)), roots(r$lr), tolerance = 3e-3)
})

test_that("the block-size guard makes every asymptotic output unavailable and records why", {
	f <- pois_fixture()
	expect_false(f$priv$count_likelihood_block_asymp_unsupported())
	expect_false(f$priv$mark_count_likelihood_block_asymp_nonestimable())
	expect_false(f$inf$is_nonestimable("se"))

	unlockBinding("count_likelihood_block_asymp_unsupported", f$priv)
	f$priv$count_likelihood_block_asymp_unsupported <- function() TRUE
	expect_true(f$priv$mark_count_likelihood_block_asymp_nonestimable())
	expect_true(f$inf$is_nonestimable("se"))
	expect_equal(f$inf$get_nonestimable_reason(), "count_likelihood_asymp_block_size_gt_one_not_supported")
	expect_true(is.finite(f$priv$cached_values$beta_hat_T) || is.na(f$priv$cached_values$beta_hat_T))

	expect_true(is.na(f$priv$get_standard_error()))
	for (m in c("compute_wald_confidence_interval", "compute_score_confidence_interval",
		"compute_gradient_confidence_interval", "compute_lik_ratio_confidence_interval", "compute_asymp_confidence_interval")) {
		ci <- f$inf[[m]](alpha = 0.1)
		expect_true(all(is.na(ci)), info = m)
		expect_equal(names(ci), c("5%", "95%"), info = m)
	}
	for (m in c("compute_wald_two_sided_pval", "compute_score_two_sided_pval", "compute_gradient_two_sided_pval",
		"compute_lik_ratio_two_sided_pval", "compute_asymp_two_sided_pval")) {
		expect_true(is.na(f$inf[[m]](0)), info = m)
	}
	expect_equal(f$priv$count_likelihood_missing_ci(0.2), c("10%" = NA_real_, "90%" = NA_real_))
})
