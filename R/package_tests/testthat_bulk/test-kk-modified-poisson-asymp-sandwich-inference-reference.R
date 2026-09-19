library(testthat)
library(EDI)

# InferenceIncidKKModifiedPoisson's full asymptotic inference path
# (compute_estimate/compute_asymp_confidence_interval/compute_asymp_two_sided_pval),
# which fits the modified-Poisson working model and cluster-robust-sandwiches
# the SE by treating matched pairs as 2-member clusters and reservoir subjects
# as singletons. Existing coverage (migration-golden, weighted-refit reference)
# only checks legacy-vs-migrated equivalence or the weighted-bootstrap
# estimate_only path -- never an independent reference for the full asymptotic
# fit. Verified here against an independent glm(family=poisson) fit combined
# with sandwich::vcovCL clustered on the same pair/singleton structure.

make_kk_modpois_fixture <- function(seed = 20260919L, n = 80L){
	set.seed(seed)
	x1 <- rnorm(n)
	x2 <- rnorm(n)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
	for (i in seq_len(n)) {
		w_i <- des$add_one_subject_to_experiment_and_assign(data.frame(x1 = x1[i], x2 = x2[i]))
		y_i <- rbinom(1L, 1L, plogis(-0.30 + 0.55 * w_i + 0.25 * x1[i] - 0.15 * x2[i]))
		des$add_one_subject_response(i, y_i)
	}
	des
}

test_that("compute_estimate/asymp CI/pval match an independent modified-Poisson + cluster-sandwich reference", {
	des <- make_kk_modpois_fixture()
	inf <- InferenceIncidKKModifiedPoisson$new(des, model_formula = ~ x1 + x2, verbose = FALSE)
	priv <- inf$.__enclos_env__$private

	# Trigger the full (non-estimate-only) fit to populate the design/cluster
	# structure the class actually used.
	inf$compute_asymp_confidence_interval()

	X <- as.matrix(priv$build_design_matrix())
	y <- as.numeric(priv$y)
	cluster_id <- priv$get_cluster_ids()
	stopifnot(nrow(X) == length(y), length(cluster_id) == length(y))

	# Fit a real glm() (via a data.frame built directly from X, dropping its
	# own intercept column) so sandwich::vcovCL's model.matrix()/terms()
	# machinery works -- a completely separate implementation from the
	# package's own glm_cluster_sandwich_post_fit_cpp().
	df_fit <- as.data.frame(X[, setdiff(colnames(X), "(Intercept)"), drop = FALSE])
	df_fit$y <- y
	ref_fit <- glm(y ~ ., data = df_fit, family = poisson())
	ref_beta <- unname(coef(ref_fit))
	names(ref_beta) <- names(coef(ref_fit))

	# cadjust=FALSE, cluster.type="HC0": the package's own cluster_meat_robust()
	# applies no finite-cluster or df small-sample correction factor at all
	# (plain sum_g score_g %*% t(score_g)), so match that exactly here.
	vcov_ref <- sandwich::vcovCL(ref_fit, cluster = cluster_id, type = "HC0", cadjust = FALSE)
	se_ref <- sqrt(diag(vcov_ref))["treatment"]

	expect_equal(unname(priv$cached_values$beta_hat_T), unname(ref_beta["treatment"]), tolerance = 1e-4)
	expect_equal(unname(priv$cached_values$s_beta_hat_T), unname(se_ref), tolerance = 1e-3)

	# CI/p-value are then plain z-based off that cached estimate/SE -- verify
	# the public methods reproduce the from-scratch z-formula exactly (not
	# re-deriving the SE, which is already checked above).
	alpha <- 0.05
	ci <- inf$compute_asymp_confidence_interval(alpha)
	df <- priv$cached_values$df
	crit <- qt(1 - alpha / 2, df)
	expect_equal(as.numeric(ci), priv$cached_values$beta_hat_T + c(-1, 1) * crit * priv$cached_values$s_beta_hat_T, tolerance = 1e-8)

	pval <- inf$compute_asymp_two_sided_pval(delta = 0)
	t_stat <- priv$cached_values$beta_hat_T / priv$cached_values$s_beta_hat_T
	expect_equal(pval, 2 * pt(-abs(t_stat), df), tolerance = 1e-8)

	# Wald identity at delta = 0: p < alpha iff 0 is outside the CI.
	expect_equal(pval < alpha, !(ci[1] <= 0 && 0 <= ci[2]))
})

test_that("compute_estimate(estimate_only=TRUE) matches an independent unweighted glm.fit point estimate", {
	des <- make_kk_modpois_fixture(seed = 20260920L)
	inf <- InferenceIncidKKModifiedPoisson$new(des, model_formula = ~ x1 + x2, verbose = FALSE)
	priv <- inf$.__enclos_env__$private

	est <- as.numeric(inf$compute_estimate(estimate_only = TRUE))[1]
	# estimate_only never populates SE.
	expect_true(is.na(priv$cached_values$s_beta_hat_T) || is.null(priv$cached_values$s_beta_hat_T))

	X <- as.matrix(priv$build_design_matrix())
	y <- as.numeric(priv$y)
	ref_fit <- glm.fit(X, y, family = poisson())
	expect_equal(est, unname(ref_fit$coefficients[2L]), tolerance = 1e-4)
})

test_that("get_degrees_of_freedom() reports n - ncol(X) after a full fit", {
	des <- make_kk_modpois_fixture(seed = 20260921L)
	inf <- InferenceIncidKKModifiedPoisson$new(des, model_formula = ~ x1 + x2, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	inf$compute_asymp_confidence_interval()
	X <- as.matrix(priv$build_design_matrix())
	expect_equal(priv$get_degrees_of_freedom(), nrow(X) - ncol(X))
})
