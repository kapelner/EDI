library(testthat)
library(EDI)

# v1.0.6-TODO-201: the cumulative-link ordinal classes (logit / probit /
# cauchit / cloglog) expose Fisher information. It must be the EXPECTED
# information sum_i sum_k (d pi_ik)(d pi_ik)' / pi_ik, not the observed Hessian
# (which is what the C++ fits' own `fisher_information` field holds). These
# tests check the R implementation against the exact y-expectation of the C++
# kernels' score outer product and negative Hessian, and the class wiring.

ordinal_ei_links <- list(
	logit = list(sgn = -1, cls = "InferenceOrdinalPropOddsRegr",
		score = function(X, y, p) EDI:::get_ordinal_regression_score_cpp(X, y, p),
		hess = function(X, y, p) EDI:::get_ordinal_regression_hessian_cpp(X, y, p)),
	probit = list(sgn = -1, cls = "InferenceOrdinalOrderedProbitRegr",
		score = function(X, y, p) EDI:::get_ordinal_probit_regression_score_cpp(X, y, p),
		hess = function(X, y, p) EDI:::get_ordinal_probit_regression_hessian_cpp(X, y, p)),
	cauchit = list(sgn = -1, cls = "InferenceOrdinalCauchitRegr",
		score = function(X, y, p) EDI:::get_ordinal_cauchit_regression_score_cpp(X, y, p),
		hess = function(X, y, p) EDI:::get_ordinal_cauchit_regression_hessian_cpp(X, y, p)),
	cloglog = list(sgn = 1, cls = "InferenceOrdinalCloglogRegr",
		score = function(X, y, p) EDI:::get_ordinal_cloglog_regression_score_cpp(X, y, p),
		hess = function(X, y, p) EDI:::get_ordinal_cloglog_regression_hessian_cpp(X, y, p))
)

test_that("expected information equals the exact expectation of the C++ score outer product and negative Hessian", {
	set.seed(201)
	n <- 25L
	X <- cbind(treatment = rep(0:1, length.out = n), x1 = rnorm(n), x2 = runif(n, -1, 1))
	alpha <- c(-0.8, 0.2, 1.1)
	beta_pub <- c(0.6, 0.5, -0.4)
	y_base <- rep(1:4, length.out = n)
	for (link in names(ordinal_ei_links)) {
		L <- ordinal_ei_links[[link]]
		cf <- EDI:::ordinal_cumlink_link_cdf_pdf(link)
		par <- c(alpha, if (L$sgn < 0) beta_pub else -beta_pub)
		cum <- cf$cdf(outer(-as.numeric(X %*% beta_pub), alpha, "+"))
		PI <- cbind(cum, 1) - cbind(0, cum)
		# per-observation, per-category contributions by appending one row to a
		# base data set in which every category already occurs (likelihood is additive)
		S0 <- L$score(X, y_base, par)
		H0 <- L$hess(X, y_base, par)
		E_ss <- E_negH <- matrix(0, length(par), length(par))
		for (i in seq_len(n)) for (k in 1:4) {
			Xa <- rbind(X, X[i, ])
			s <- L$score(Xa, c(y_base, k), par) - S0
			E_ss <- E_ss + PI[i, k] * tcrossprod(s)
			E_negH <- E_negH - PI[i, k] * (L$hess(Xa, c(y_base, k), par) - H0)
		}
		info <- EDI:::ordinal_cumlink_expected_information(X, y_base, par, link, eta_sign = L$sgn)
		expect_equal(info, E_ss, tolerance = 1e-10, info = link)
		expect_equal(info, E_negH, tolerance = 1e-10, info = link)
		expect_true(isSymmetric(info), info = link)
		expect_gt(min(eigen(info, symmetric = TRUE, only.values = TRUE)$values), 0)
	}
})

test_that("two-category logit expected information is the logistic-regression X'WX", {
	set.seed(3)
	n <- 40L
	X <- cbind(rnorm(n))
	y <- rbinom(n, 1, 0.5) + 1
	par <- c(0.3, 0.7)
	info <- EDI:::ordinal_cumlink_expected_information(X, y, par, "logit")
	Xd <- cbind(1, -X)
	pr <- as.numeric(plogis(Xd %*% par))
	expect_equal(info, crossprod(Xd, Xd * pr * (1 - pr)), tolerance = 1e-12)
	expect_null(EDI:::ordinal_cumlink_expected_information(X, y, c(0.3, NA), "logit"))
})

ordinal_ei_design <- function(link, n = 80L, seed = 7L) {
	set.seed(seed)
	des <- DesignSeqOneByOneBernoulli$new(n = n, response_type = "ordinal", verbose = FALSE)
	x <- data.frame(x1 = rnorm(n), x2 = runif(n, -1, 1))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(x[i, , drop = FALSE])
	w <- as.integer(des$.__enclos_env__$private$w == 1L)
	cf <- EDI:::ordinal_cumlink_link_cdf_pdf(link)
	cum <- cf$cdf(outer(-(0.3 * w + 0.5 * x$x1 - 0.4 * x$x2), c(-0.8, 0.2, 1.1), "+"))
	PI <- cbind(cum, 1) - cbind(0, cum)
	y <- apply(PI, 1L, function(pr) sample.int(4L, 1L, prob = pr))
	for (i in seq_len(n)) des$add_one_subject_response(i, y = y[i])
	des
}

test_that("cumulative-link classes use expected information as their Fisher source", {
	for (link in names(ordinal_ei_links)) {
		L <- ordinal_ei_links[[link]]
		des <- ordinal_ei_design(link)
		inf <- get(L$cls)$new(des)
		expect_identical(inf$get_supported_information_preferences(), c("auto", "fisher", "observed"), info = link)
		inf$compute_estimate()
		priv <- inf$.__enclos_env__$private
		spec <- priv$get_likelihood_test_spec()
		expected <- EDI:::ordinal_cumlink_expected_information(spec$X, spec$y, spec$full_fit$params, link, eta_sign = L$sgn)
		expect_equal(spec$fisher_information(spec$full_fit), expected, tolerance = 1e-12, info = link)
		observed <- spec$observed_information(spec$full_fit)
		# expected and observed information agree to O(n^-1/2), but are not identical
		expect_false(isTRUE(all.equal(expected, observed, tolerance = 1e-8)), info = link)
		expect_lt(max(abs(expected - observed)) / max(abs(observed)), 0.25)
		# v1.0.6-TODO-215: the score-test information follows the "fisher" default,
		# but the Wald SE (get_standard_error()) always uses the observed information.
		expect_equal(priv$get_score_test_information_matrix(spec, spec$full_fit), expected, tolerance = 1e-12, info = link)
		expect_identical(inf$get_information_source_used(), "fisher", info = link)
		se_wald <- priv$get_standard_error()
		expect_equal(se_wald, sqrt(solve(observed)[spec$j, spec$j]), tolerance = 1e-10, info = link)
		expect_identical(inf$get_information_source_used(), "fisher", info = link)
		# score p-values under both sources are valid and close at this n
		p <- vapply(c("fisher", "observed"), function(src) {
			obj <- get(L$cls)$new(des)
			obj$set_information_preference(src)
			obj$set_testing_type("score")
			obj$compute_asymp_two_sided_pval()
		}, numeric(1))
		expect_true(all(is.finite(p) & p > 0 & p <= 1), info = link)
		expect_lt(abs(p[["fisher"]] - p[["observed"]]), 0.05)
	}
})
