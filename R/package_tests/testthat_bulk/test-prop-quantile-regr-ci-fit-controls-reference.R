library(testthat)
library(EDI)
skip_if_not_installed("quantreg")

# get_ci_fit_controls() (flags derived from private$randomization_mc_control: warm_start,
# reuse_factorizations, both strict-TRUE-only) is defined identically across three quantile/robust
# regression classes: InferenceContinQuantileRegr, InferenceContinRobustRegr, and
# InferencePropQuantileRegr. Only the first two have direct test coverage
# (test-quantile-regr-private-fit-wrapper-design-reduction-warm-keep-and-ci-controls-reference.R,
# test-robust-regr-private-fit-rlm-model-backends-ci-controls-and-failed-cache-reference.R);
# InferencePropQuantileRegr's own copy (inference_proportion_quantile_regr.R) had zero test
# references anywhere.

set.seed(2); n <- 40L
X <- data.frame(x1 = rnorm(n))
d <- DesignFixedBernoulli$new(response_type = "proportion", n = n, seed = 1L, verbose = FALSE)
d$add_all_subjects_to_experiment(X); d$assign_w_to_all_subjects()
w <- d$get_w()
y <- plogis(0.5 * w + 0.3 * X$x1 + rnorm(n, sd = 0.1))
d$add_all_subject_responses(y)
mk <- function(tau = 0.5) {
	inf <- InferencePropQuantileRegr$new(d, tau = tau, verbose = FALSE)
	list(inf = inf, p = inf$.__enclos_env__$private)
}

test_that("CI fit controls default to FALSE and follow the randomization MC control flags", {
	g <- mk()
	expect_identical(g$p$get_ci_fit_controls(), list(warm_start = FALSE, reuse_factorizations = FALSE))
	g$p$randomization_mc_control <- list(fit_warm_start_enable = TRUE)
	expect_identical(g$p$get_ci_fit_controls(), list(warm_start = TRUE, reuse_factorizations = FALSE))
	g$p$randomization_mc_control <- list(fit_warm_start_enable = FALSE, fit_reuse_factorizations = TRUE)
	expect_identical(g$p$get_ci_fit_controls(), list(warm_start = FALSE, reuse_factorizations = TRUE))
	g$p$randomization_mc_control <- list(fit_warm_start_enable = "yes", fit_reuse_factorizations = 1)     # only strict TRUE counts
	expect_identical(g$p$get_ci_fit_controls(), list(warm_start = FALSE, reuse_factorizations = FALSE))
})
