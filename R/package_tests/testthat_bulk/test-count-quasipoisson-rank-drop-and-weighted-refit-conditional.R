library(testthat)
library(EDI)

# docs-claims audit, finding docs-claims-d3256db66 (InferenceCountQuasiPoisson,
# R/EDI/R/inference_count_quasipoisson.R class docs):
#   - rank-deficient covariate columns are dropped automatically before fitting;
#   - the Bayesian-bootstrap weighted refit is not estimand-aware: it always targets the conditional coefficient.

qp_fixture <- function(seed = 5L, n = 120L) {
	set.seed(seed)
	d <- DesignFixedBernoulli$new(response_type = "count", n = n, seed = 1L, verbose = FALSE)
	d$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n), x2 = runif(n)))
	d$assign_w_to_all_subjects()
	w <- d$get_w()
	d$add_all_subject_responses(rnbinom(n, mu = exp(0.3 + 0.4 * w + 0.2 * d$get_X_raw()$x1), size = 2))
	list(des = d, dat = data.frame(y = d$get_y(), w = w, d$get_X_raw()))
}

test_that("a duplicated covariate column is dropped and the fit equals glm(quasipoisson) on the reduced design", {
	f <- qp_fixture()
	q <- InferenceCountQuasiPoisson$new(f$des, verbose = FALSE)
	p <- q$.__enclos_env__$private
	orig_build <- p$build_design_matrix
	# the design itself already removes collinear covariates, so inject the duplicate at the class's own
	# design-matrix step (the input to the hardened QR column dropping)
	unlockBinding("build_design_matrix", p)
	p$build_design_matrix <- function() { X <- orig_build(); cbind(X, x1_dup = X[, "x1"]) }
	expect_equal(qr(p$build_design_matrix())$rank, ncol(p$build_design_matrix()) - 1L)
	est <- q$compute_estimate()
	g <- glm(y ~ w + x1 + x2, data = f$dat, family = quasipoisson)
	expect_equal(est, unname(coef(g)["w"]), tolerance = 1e-6)
	expect_equal(p$get_standard_error(), unname(sqrt(vcov(g)["w", "w"])), tolerance = 1e-5)
	expect_equal(ncol(p$cached_mod$X), 4L)
})

test_that("under a marginal estimand the weighted refit still returns the weighted conditional coefficient", {
	f <- qp_fixture()
	q <- InferenceCountQuasiPoisson$new(f$des, verbose = FALSE)
	q$set_estimand("marginal_mean_diff")
	p <- q$.__enclos_env__$private
	marg <- q$compute_estimate()
	p$current_bayesian_bootstrap_context <- p$build_bayesian_bootstrap_context()
	set.seed(2); wt <- rexp(nrow(f$dat))
	est <- q$compute_estimate_with_bootstrap_weights(wt)
	ref <- unname(coef(suppressWarnings(glm(y ~ w + x1 + x2, data = f$dat, family = poisson, weights = wt)))["w"])
	expect_equal(est, ref, tolerance = 1e-6)
	expect_gt(abs(est - marg), 0.01)
	# the unweighted state is restored afterwards: still the marginal estimand and value
	expect_identical(q$get_estimand(), "marginal_mean_diff")
	expect_equal(q$compute_estimate(), marg, tolerance = 1e-10)
})
