library(testthat)
library(EDI)

# The CountCompositeLikelihood component (InferenceCountQuasiPoisson /
# InferenceCountRobustPoisson): unsupported likelihood-test outputs stop with the
# class name, the capability flags and supported testing types, shared()'s
# caching state machine (driven by a stubbed generate_mod), warm-start plumbing,
# and simulate_under_lik_null()'s Poisson null simulator against closed forms.

cc_fx <- function(cls = "InferenceCountQuasiPoisson", seed = 5L, n = 80L) {
	set.seed(seed)
	x <- rnorm(n)
	des <- DesignFixediBCRD$new(n = n, response_type = "count", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- rpois(n, exp(0.3 + 0.4 * w + 0.2 * x))
	des$add_all_subject_responses(y)
	inf <- get(cls)$new(des, verbose = FALSE)
	list(inf = inf, p = inf$.__enclos_env__$private, w = w, x = x, y = y, n = n)
}

stub_gen <- function(f, out) {
	unlockBinding("generate_mod", f$p)
	f$p$generate_mod <- function(estimate_only = FALSE) out
	f
}

for (cls in c("InferenceCountQuasiPoisson", "InferenceCountRobustPoisson")) {
	test_that(paste(cls, "advertises Wald-only testing and refuses score / gradient / likelihood-ratio outputs by name"), {
		f <- cc_fx(cls)
		expect_true(f$p$is_a_count_composite_likelihood())
		expect_false(f$p$supports_likelihood_tests())
		expect_false(f$p$supports_lik_ratio_param_bootstrap())
		expect_equal(f$p$get_supported_testing_types_impl(), "wald")
		expect_null(f$p$get_likelihood_test_spec())
		for (what in c("score", "gradient")) {
			expect_error(f$p[[paste0("compute_", what, "_two_sided_pval_impl")]](0), paste0(cls, " does not support ", what, " p-values"))
			expect_error(f$p[[paste0("compute_", what, "_confidence_interval_impl")]](0.05), paste0(cls, " does not support ", what, " confidence intervals"))
		}
		expect_error(f$p$compute_lik_ratio_two_sided_pval_impl(0), "does not support likelihood-ratio p-values")
		expect_error(f$p$compute_lik_ratio_confidence_interval_impl(0.05), "does not support likelihood-ratio confidence intervals")
	})
}

test_that("shared(): a fit with b and ssq caches estimate, SE and df, stores the beta warm start with its information", {
	f <- cc_fx()
	stub_gen(f, list(b = c(0.3, 0.4, 0.2), ssq_b_j = 0.04, XtWX = diag(3) * 5, df = 42))
	f$p$shared(FALSE)
	expect_equal(f$p$cached_values$beta_hat_T, 0.4)
	expect_equal(f$p$cached_values$s_beta_hat_T, 0.2)
	expect_equal(f$p$cached_values$df, 42)
	expect_equal(f$p$get_fit_warm_start("beta"), c(0.3, 0.4, 0.2))
	expect_equal(f$p$get_fit_warm_start_fisher(3L), diag(3) * 5)
	expect_null(f$p$get_fit_warm_start_fisher(2L))                           # wrong dimension
	expect_equal(f$p$get_standard_error(), 0.2)
	expect_equal(f$p$get_degrees_of_freedom(), 42)
	g <- cc_fx()                                                              # cached: the second request does not refit
	stub_gen(g, list(b = c(1, 2), ssq_b_2 = 0.25))
	g$p$shared(FALSE)
	unlockBinding("generate_mod", g$p); g$p$generate_mod <- function(estimate_only = FALSE) stop("must not refit")
	expect_silent(g$p$shared(FALSE))
	expect_equal(g$p$cached_values$s_beta_hat_T, 0.5)                        # ssq_b_2 fallback name
	expect_equal(g$p$cached_values$df, Inf)                                  # default df
})

test_that("shared(): explicit beta_hat_T wins over b[2]; estimate_only skips SE/df; bad variances give NA SE", {
	f <- cc_fx(); stub_gen(f, list(beta_hat_T = 7, b = c(0, 1), ssq_b_j = 0.09))
	f$p$shared(TRUE)
	expect_equal(f$p$cached_values$beta_hat_T, 7)
	expect_null(f$p$cached_values$s_beta_hat_T)
	expect_null(f$p$cached_values$df)
	for (bad in list(0, -1, NA_real_, Inf)) {
		g <- cc_fx(); stub_gen(g, list(b = c(0, 1), ssq_b_j = bad))
		g$p$shared(FALSE)
		expect_true(is.na(g$p$cached_values$s_beta_hat_T))
	}
	h <- cc_fx(); stub_gen(h, list(b = c(0, 1)))                              # no variance reported
	h$p$shared(FALSE)
	expect_true(is.na(h$p$cached_values$s_beta_hat_T))
})

test_that("shared(): a NULL model marks estimate, SE and df all NA; generate_mod is abstract on the raw component", {
	f <- cc_fx(); stub_gen(f, NULL)
	f$p$shared(FALSE)
	expect_true(all(is.na(c(f$p$cached_values$beta_hat_T, f$p$cached_values$s_beta_hat_T, f$p$cached_values$df))))
	comp <- get("CountCompositeLikelihoodSource", envir = asNamespace("EDI"), inherits = FALSE)
	env <- new.env(); env$self <- structure(list(), class = "LeafX")
	gm <- comp$private$generate_mod; environment(gm) <- env
	expect_error(gm(), "LeafX must implement generate_mod\\(\\)")
})

test_that("get_backend_warm_start_args delegates to the optimal warm-start configuration", {
	f <- cc_fx()
	expect_equal(f$p$get_backend_warm_start_args(3L), f$p$get_optimal_warm_start_config(3L))
	f$p$set_fit_warm_start(c(0.1, 0.2, 0.3), "beta")
	expect_equal(f$p$get_backend_warm_start_args(3L), f$p$get_optimal_warm_start_config(3L, 3L))
	expect_equal(f$p$get_backend_warm_start_args(3L, 2L), f$p$get_optimal_warm_start_config(3L, 2L))
})

test_that("simulate_under_lik_null draws Poisson responses at exp(X b_null) and returns a working null-fit closure", {
	f <- cc_fx()
	X <- cbind(1, f$w, f$x)
	b_null <- c(0.3, 0, 0.2)
	spec <- list(X = X, j = 2L)
	set.seed(10)
	sim <- f$p$simulate_under_lik_null(spec, 0, list(b = b_null))
	skip_if(is.null(sim))
	expect_length(sim$worker_data$y, f$n)
	expect_true(all(sim$worker_data$y >= 0 & sim$worker_data$y == round(sim$worker_data$y)))
	# Same seed reproduces the draw exactly and it is rpois at the null mean.
	set.seed(10)
	mu <- exp(drop(X %*% b_null))
	expect_equal(sim$worker_data$y, as.numeric(rpois(f$n, mu)))
	# The replicate's null likelihood closure equals the Poisson log-likelihood.
	y <- sim$worker_data$y
	fit <- list(b = c(0.3, 0.1, 0.2))
	eta <- drop(X %*% fit$b)
	expect_equal(sim$neg_loglik(fit), -sum(dpois(y, exp(eta), log = TRUE)), tolerance = 1e-10)
	# The constrained fit fixes coordinate j at the requested value.
	n1 <- sim$fit_null(0.25)
	if (!is.null(n1)) expect_equal(unname(n1$b[2]), 0.25, tolerance = 1e-8)
	# The full fit is the Poisson MLE for the simulated data.
	ref <- coef(glm(y ~ f$w + f$x, family = poisson()))
	expect_equal(as.numeric(sim$full_fit$b), unname(ref), tolerance = 1e-5)
})
