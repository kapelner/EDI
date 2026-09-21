library(testthat)
library(EDI)

# InferenceIncidGCompRiskRatio log-scale helpers: compute_rr_bootstrap_basic_confidence_interval (basic interval on log RR),
# compute_rr_bayesian_bootstrap_log_confidence_interval (wald / basic on log RR) and compute_rr_jackknife_log_se, with the
# resampling distributions stubbed by fixed vectors so the formulas can be compared with hand computation.

set.seed(5); n <- 150L
X <- data.frame(x1 = rnorm(n), x2 = runif(n))
d <- DesignFixedBernoulli$new(response_type = "incidence", n = n, seed = 1L, verbose = FALSE)
d$add_all_subjects_to_experiment(X); d$assign_w_to_all_subjects(); w <- d$get_w()
y <- rbinom(n, 1, plogis(-0.3 + 0.8 * w + 0.5 * X$x1)); d$add_all_subject_responses(y)
mk <- function(boot = NULL, bayes = NULL, jack = NULL) {
	inf <- InferenceIncidGCompRiskRatio$new(d, verbose = FALSE); p <- inf$.__enclos_env__$private
	est <- inf$compute_estimate()
	if (!is.null(boot)) { unlockBinding("approximate_bootstrap_distribution_beta_hat_T", inf); inf$approximate_bootstrap_distribution_beta_hat_T <- function(B, show_progress = FALSE) boot }
	if (!is.null(bayes)) { unlockBinding("approximate_bayesian_bootstrap_distribution_beta_hat_T", inf); inf$approximate_bayesian_bootstrap_distribution_beta_hat_T <- function(B, show_progress = FALSE, weighting_unit_type = NULL) bayes }
	if (!is.null(jack)) { unlockBinding("approximate_jackknife_distribution_beta_hat_T_private", p); p$approximate_jackknife_distribution_beta_hat_T_private <- function(unit = "auto") jack }
	list(inf = inf, p = p, est = est)
}
q8 <- function(x, p) quantile(x, p, names = FALSE, type = 8)
lg <- seq(-0.3, 0.9, length.out = 101)

test_that("bootstrap basic interval is exp(2 log(est) - quantiles of the log bootstrap distribution)", {
	f <- mk(boot = exp(lg))
	ci <- f$p$compute_rr_bootstrap_basic_confidence_interval(0.1, B = 101)
	expect_equal(unname(ci), exp(2 * log(f$est) - q8(lg, c(0.95, 0.05))), tolerance = 1e-10)
	expect_identical(names(ci), c("5%", "95%"))
})

test_that("bootstrap interval filters non-finite / non-positive replicates (na.rm) and reports NA when too few remain or na.rm = FALSE hits a bad value", {
	bad <- c(exp(lg), NA, Inf, 0, -2)
	f <- mk(boot = bad)
	expect_equal(unname(f$p$compute_rr_bootstrap_basic_confidence_interval(0.1, B = 105)), exp(2 * log(f$est) - q8(lg, c(0.95, 0.05))), tolerance = 1e-10)
	expect_true(all(is.na(f$p$compute_rr_bootstrap_basic_confidence_interval(0.1, B = 105, na.rm = FALSE))))
	g <- mk(boot = exp(c(0.1, 0.2, 0.3)))
	expect_true(all(is.na(g$p$compute_rr_bootstrap_basic_confidence_interval(0.1, B = 3, min_number_usable_samples = 5L))))
	expect_false(any(is.na(g$p$compute_rr_bootstrap_basic_confidence_interval(0.1, B = 3, min_number_usable_samples = 3L))))
})

test_that("Bayesian bootstrap: basic matches the same reflection; wald is est * exp(+/- z * sd(log draws))", {
	f <- mk(bayes = exp(lg))
	expect_equal(unname(f$p$compute_rr_bayesian_bootstrap_log_confidence_interval(0.1, B = 101, type = "basic")),
		exp(2 * log(f$est) - q8(lg, c(0.95, 0.05))), tolerance = 1e-10)
	expect_equal(unname(f$p$compute_rr_bayesian_bootstrap_log_confidence_interval(0.1, B = 101, type = "wald")),
		exp(log(f$est) + c(-1, 1) * qnorm(0.95) * sd(lg)), tolerance = 1e-10)
	const <- mk(bayes = rep(1.3, 20))
	expect_true(all(is.na(const$p$compute_rr_bayesian_bootstrap_log_confidence_interval(0.1, B = 20, type = "wald"))))       # zero spread
	few <- mk(bayes = exp(c(0.1, 0.2)))
	expect_true(all(is.na(few$p$compute_rr_bayesian_bootstrap_log_confidence_interval(0.1, B = 2))))
})

test_that("jackknife log SE is sqrt(((k-1)/k) * sum((log j - mean)^2)) over the positive finite jackknife replicates", {
	jack <- exp(rnorm(40, 0.25, 0.1)); lj <- log(jack)
	f <- mk(jack = c(jack, NA, 0, -1))
	expect_equal(f$p$compute_rr_jackknife_log_se(), sqrt((39 / 40) * sum((lj - mean(lj))^2)), tolerance = 1e-10)
})

test_that("jackknife log SE is NA (and flagged) with fewer than two usable replicates or zero spread", {
	one <- mk(jack = c(1.2, NA, 0)); expect_true(is.na(one$p$compute_rr_jackknife_log_se()))
	expect_true(isTRUE(one$inf$is_nonestimable("se")))
	same <- mk(jack = rep(1.4, 10)); expect_true(is.na(same$p$compute_rr_jackknife_log_se()))
	expect_true(isTRUE(same$inf$is_nonestimable("se")))
})

test_that("an unavailable point estimate short-circuits the bootstrap intervals to NA", {
	f <- mk(boot = exp(lg)); f$p$cached_values$rr <- NA_real_; f$p$cached_values$beta_hat_T <- NA_real_
	unlockBinding("compute_estimate", f$inf); f$inf$compute_estimate <- function(estimate_only = FALSE) NA_real_
	expect_true(all(is.na(f$p$compute_rr_bootstrap_basic_confidence_interval(0.1, B = 101))))
})
