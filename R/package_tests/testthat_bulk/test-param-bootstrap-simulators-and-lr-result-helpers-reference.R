library(testthat)
library(EDI)

# InferenceParamBootstrap's private simulation helpers (Bernoulli / Poisson /
# Gaussian / ordinal / observed-censoring Weibull null-data generators), its
# extremeness predicate, spec / worker-data validators, result constructors,
# the likelihood-ratio-from-spec computation and the retrying replicate driver.
# None had a direct test reference. Simulators are checked against their own
# documented distributions (seeded replays and large-sample moments).

pb_priv <- function(n = 40L, seed = 2L) {
	set.seed(seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rbinom(n, 1, 0.4))
	inf <- InferenceIncidLogRegr$new(des, verbose = FALSE)
	list(inf = inf, priv = inf$.__enclos_env__$private)
}

test_that("Bernoulli simulator clips probabilities to [0, 1] and reproduces rbinom", {
	p <- pb_priv()$priv
	expect_null(p$simulate_param_boot_bernoulli_y(numeric(0)))
	expect_null(p$simulate_param_boot_bernoulli_y(c(0.2, NA)))
	expect_null(p$simulate_param_boot_bernoulli_y(c(0.2, Inf)))
	expect_equal(p$simulate_param_boot_bernoulli_y(c(-3, 5, 0, 1)), c(0, 1, 0, 1))
	set.seed(5); a <- p$simulate_param_boot_bernoulli_y(rep(0.3, 50))
	set.seed(5); expect_equal(a, as.numeric(rbinom(50, 1, 0.3)))
	set.seed(6); big <- p$simulate_param_boot_bernoulli_y(rep(0.3, 20000))
	expect_equal(mean(big), 0.3, tolerance = 0.02)
})

test_that("Poisson and Gaussian simulators validate inputs and reproduce their generators", {
	p <- pb_priv()$priv
	expect_null(p$simulate_param_boot_poisson_y(numeric(0)))
	expect_null(p$simulate_param_boot_poisson_y(c(1, -0.1)))
	expect_null(p$simulate_param_boot_poisson_y(c(1, NaN)))
	set.seed(7); a <- p$simulate_param_boot_poisson_y(c(0.5, 2, 10))
	set.seed(7); expect_equal(a, as.numeric(rpois(3, c(0.5, 2, 10))))
	set.seed(8); expect_equal(mean(p$simulate_param_boot_poisson_y(rep(4, 20000))), 4, tolerance = 0.05)

	expect_null(p$simulate_param_boot_gaussian_y(numeric(0), 1))
	expect_null(p$simulate_param_boot_gaussian_y(c(1, NA), 1))
	expect_null(p$simulate_param_boot_gaussian_y(c(1, 2), 0))
	expect_null(p$simulate_param_boot_gaussian_y(c(1, 2), -1))
	expect_null(p$simulate_param_boot_gaussian_y(c(1, 2), NA_real_))
	set.seed(9); g <- p$simulate_param_boot_gaussian_y(c(1, 2, 3), 4)
	set.seed(9); expect_equal(g, as.numeric(c(1, 2, 3) + rnorm(3, 0, 2)))
	set.seed(10); big <- p$simulate_param_boot_gaussian_y(rep(5, 20000), 9)
	expect_equal(c(mean(big), sd(big)), c(5, 3), tolerance = 0.03)
})

test_that("ordinal simulator draws categories from the cumulative-link probabilities and rejects unusable setups", {
	p <- pb_priv()$priv
	set.seed(11)
	n <- 30000L
	X <- cbind(x = rep(c(-1, 0, 1), length.out = n))
	thresholds <- c(-0.5, 0.7); beta <- 0.8
	y_template <- c(1, 2, 3)
	y_sim <- p$simulate_param_boot_ordinal_y(X, c(thresholds, beta), y_template, stats::plogis)
	expect_length(y_sim, n)
	for (xv in c(-1, 0, 1)) {
		eta <- beta * xv
		cum <- plogis(thresholds - eta)
		ref <- c(cum[1], cum[2] - cum[1], 1 - cum[2])
		obs <- tabulate(y_sim[X[, 1] == xv], nbins = 3) / sum(X[, 1] == xv)
		expect_equal(obs, ref, tolerance = 0.03, info = xv)
	}
	# Category labels follow the template's sorted distinct values.
	y2 <- p$simulate_param_boot_ordinal_y(X, c(thresholds, beta), c(10, 20, 30), stats::plogis)
	expect_setequal(unique(y2), c(10, 20, 30))

	expect_null(p$simulate_param_boot_ordinal_y(X, c(thresholds, beta), y_template, "not a function"))
	expect_null(p$simulate_param_boot_ordinal_y(X, c(thresholds, beta), c(1, 1, 1), stats::plogis))       # K < 2
	expect_null(p$simulate_param_boot_ordinal_y(X, thresholds, y_template, stats::plogis))                 # no beta params
	# A simulated sample missing a category is rejected.
	expect_null(p$simulate_param_boot_ordinal_y(X[1:5, , drop = FALSE], c(-30, -20, 0), y_template, stats::plogis))
})

test_that("observed-censoring Weibull simulator keeps observed censoring times and flags events", {
	p <- pb_priv()$priv
	n <- 12L
	X <- cbind(1, rep(0:1, length.out = n))
	b <- c(0.5, -0.3); log_sigma <- log(0.8)
	y_obs <- seq(1, 12); dead_obs <- rep(c(1, 0, 0), length.out = n)

	set.seed(12)
	out <- p$simulate_param_boot_weibull_observed(X, b, log_sigma, y_obs, dead_obs)
	set.seed(12)
	T_sim <- rweibull(n, shape = 1 / 0.8, scale = exp(as.numeric(X %*% b)))
	C_i <- ifelse(dead_obs == 0, y_obs, Inf)
	expect_equal(out$y, pmin(T_sim, C_i))
	expect_equal(out$dead, as.numeric(T_sim <= C_i))
	# Subjects with dead_obs == 1 are never censored.
	expect_true(all(out$dead[dead_obs == 1] == 1))
	expect_true(all(out$y[out$dead == 0] == y_obs[out$dead == 0]))

	expect_null(p$simulate_param_boot_weibull_observed(X, b, Inf, y_obs, dead_obs))
	expect_null(p$simulate_param_boot_weibull_observed(X, b, NA, y_obs, dead_obs))
	expect_null(suppressWarnings(p$simulate_param_boot_weibull_observed(X, c(1e6, 0), log_sigma, y_obs, dead_obs)))   # non-finite draws
})

test_that("extreme-LR predicate is vectorized and falls back to the separation threshold", {
	p <- pb_priv()$priv
	expect_equal(p$param_bootstrap_lr_extreme(c(1, 5e6, -5e6, NA, Inf)), c(FALSE, TRUE, TRUE, FALSE, FALSE))
	expect_equal(p$param_bootstrap_lr_extreme(c(1, 50), max_abs = 10), c(FALSE, TRUE))
	expect_equal(p$param_bootstrap_lr_extreme(c(1, 50), max_abs = -1), c(FALSE, FALSE))
	expect_equal(p$param_bootstrap_lr_extreme(5e6, max_abs = NA), TRUE)
})

test_that("spec / worker-data validators and result constructors follow their contracts", {
	p <- pb_priv()$priv
	good <- list(full_fit = 1, fit_null = function(d) 1, neg_loglik = function(f) 1)
	expect_true(p$validate_param_bootstrap_spec(good))
	expect_false(p$validate_param_bootstrap_spec(NULL))
	expect_false(p$validate_param_bootstrap_spec("x"))
	expect_false(p$validate_param_bootstrap_spec(modifyList(good, list(full_fit = NULL))))
	expect_false(p$validate_param_bootstrap_spec(modifyList(good, list(fit_null = 1))))
	expect_false(p$validate_param_bootstrap_spec(modifyList(good, list(neg_loglik = NULL))))

	ws <- list(n = 3L)
	expect_true(p$validate_param_bootstrap_worker_data(ws, list(y = c(1, 2, 3))))
	expect_true(p$validate_param_bootstrap_worker_data(ws, list(y = c(1, 2, 3), dead = c(1, 0, 1))))
	expect_false(p$validate_param_bootstrap_worker_data(NULL, list(y = 1:3)))
	expect_false(p$validate_param_bootstrap_worker_data(ws, NULL))
	expect_false(p$validate_param_bootstrap_worker_data(ws, list(y = c(1, 2))))
	expect_false(p$validate_param_bootstrap_worker_data(ws, list(y = c(1, NA, 3))))
	expect_false(p$validate_param_bootstrap_worker_data(ws, list(y = c("a", "b", "c"))))
	expect_false(p$validate_param_bootstrap_worker_data(ws, list(y = c(1, 2, 3), dead = c(1, 0))))
	expect_false(p$validate_param_bootstrap_worker_data(ws, list(y = c(1, 2, 3), dead = c(1, 0, NA))))

	expect_equal(p$extract_param_bootstrap_failure_reason(NULL), "simulated_data_failure")
	expect_equal(p$extract_param_bootstrap_failure_reason(list(failure_reason = "why")), "why")
	tagged <- structure(list(), edi_param_boot_failure_reason = "tagged")
	expect_equal(p$extract_param_bootstrap_failure_reason(tagged), "tagged")
	expect_equal(p$extract_param_bootstrap_failure_reason(list(failure_reason = 5), default = "dflt"), "dflt")

	fail <- p$param_boot_failure_result(c("r1", "r2"), attempts = 3.9, details = "d")
	expect_equal(fail, list(success = FALSE, lr = NA_real_, reason = "r1", attempts = 3L, details = "d"))
	ok <- p$param_boot_success_result(c(2.5, 9), attempts = 2L)
	expect_equal(ok, list(success = TRUE, lr = 2.5, reason = "success", attempts = 2L, details = NULL))
})

test_that("compute_param_bootstrap_lr_from_boot_spec returns 2 * (null - full) or the specific failure reason", {
	p <- pb_priv()$priv
	spec <- function(full = 3, null = 5, fit_null = function(d) list(v = null)) {
		list(full_fit = list(v = full), fit_null = fit_null, neg_loglik = function(fit) fit$v)
	}
	r <- p$compute_param_bootstrap_lr_from_boot_spec(spec(3, 5), 0)
	expect_true(r$success)
	expect_equal(r$lr, 2 * (5 - 3))
	expect_equal(p$compute_param_bootstrap_lr_from_boot_spec(NULL, 0)$reason, "simulated_data_failure")
	expect_equal(p$compute_param_bootstrap_lr_from_boot_spec(list(failure_reason = "custom"), 0)$reason, "custom")
	expect_equal(p$compute_param_bootstrap_lr_from_boot_spec(list(), 0)$reason, "full_refit_failure")
	expect_equal(p$compute_param_bootstrap_lr_from_boot_spec(spec(NA, 5), 0)$reason, "full_refit_failure")
	expect_equal(p$compute_param_bootstrap_lr_from_boot_spec(spec(fit_null = function(d) NULL), 0)$reason, "null_refit_failure")
	expect_equal(p$compute_param_bootstrap_lr_from_boot_spec(spec(fit_null = function(d) stop("x")), 0)$reason, "null_refit_failure")
	expect_equal(p$compute_param_bootstrap_lr_from_boot_spec(spec(null = NA_real_), 0)$reason, "non_finite_lr")
	expect_equal(p$compute_param_bootstrap_lr_from_boot_spec(spec(3, Inf), 0)$reason, "non_finite_lr")
})

test_that("compute_param_bootstrap_lr_impl retries failed simulations up to the attempt limit and records the attempt count", {
	f <- pb_priv()
	calls <- 0L
	unlockBinding("simulate_under_lik_null", f$priv)
	f$priv$simulate_under_lik_null <- function(spec, delta, null_fit) {
		calls <<- calls + 1L
		if (calls < 3L) return(NULL)
		list(full_fit = list(v = 1), fit_null = function(d) list(v = 4), neg_loglik = function(fit) fit$v)
	}
	res <- f$priv$compute_param_bootstrap_lr_impl(spec = NULL, delta = 0, null_fit = NULL, max_attempts_per_replicate = 5L)
	expect_true(res$success)
	expect_equal(res$lr, 6)
	expect_equal(res$attempts, 3L)
	expect_equal(calls, 3L)

	calls <- 0L
	res2 <- f$priv$compute_param_bootstrap_lr_impl(spec = NULL, delta = 0, null_fit = NULL, max_attempts_per_replicate = 2L)
	expect_false(res2$success)
	expect_equal(res2$attempts, 2L)
	expect_equal(res2$reason, "simulated_data_failure")
	expect_equal(calls, 2L)
})
