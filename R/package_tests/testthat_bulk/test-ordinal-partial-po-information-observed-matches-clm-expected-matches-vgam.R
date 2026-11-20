# v1.0.6-TODO-215 item (3): observed and expected (Fisher) information of the
# partial proportional-odds cumulative-logit model
# (ordinal_partial_po_information(), clm `nominal` parameterization). The
# observed information is the exact negative Hessian of the log-likelihood and
# gives ordinal::clm()'s treatment SE; the expected information gives
# VGAM::vglm()'s (cumulative(), Fisher scoring). With no nonparallel columns it
# reduces to the proportional-odds kernel's Hessian and to
# ordinal_cumlink_expected_information(). Owner decision 2026-11-20
# (option a): the class's Wald SE on the nonparallel (VGAM) path is the
# observed information at VGAM's estimate, like the fast solver and clm; a
# non-positive-definite observed information sends the cascade on to clm.
library(testthat)
library(EDI)

ppo_info = function(...) get("ordinal_partial_po_information", envir = asNamespace("EDI"))(...)

ppo_info_data = function(n = 150L, seed = 3L){
	set.seed(seed)
	w = rbinom(n, 1, 0.5); x1 = rnorm(n); x2 = runif(n, -1, 1)
	Z = outer(rep(1, n), c(-1, 0, 1)) - (0.6 * w + 0.5 * x1) + outer(x2, c(-0.4, 0, 0.4))
	y = 1 + rowSums(runif(n) > plogis(Z))
	data.frame(y = y, yo = ordered(y), treatment = w, x1 = x1, x2 = x2)
}

ppo_info_loglik = function(Xp, Xn, y, th){
	K = length(unique(y)); na = K - 1L; p = ncol(Xp); q = ncol(Xn)
	Z = matrix(th[seq_len(na)], nrow(Xp), na, byrow = TRUE) - as.numeric(Xp %*% th[na + seq_len(p)]) +
		Xn %*% matrix(th[na + p + seq_len(na * q)], q, na)
	Fe = cbind(0, plogis(Z), 1); yi = match(y, sort(unique(y)))
	sum(log(Fe[cbind(seq_along(y), yi + 1L)] - Fe[cbind(seq_along(y), yi)]))
}

test_that("partial-PO observed information is the exact negative Hessian and gives clm's treatment SE", {
	skip_if_not_installed("ordinal")
	skip_if_not_installed("numDeriv")
	d = ppo_info_data()
	m = ordinal::clm(yo ~ treatment + x1, nominal = ~ x2, data = d, link = "logit")
	am = m$alpha.mat
	th = c(am["(Intercept)", ], coef(m)[c("treatment", "x1")], am["x2", ])
	Xp = cbind(d$treatment, d$x1); Xn = cbind(d$x2)
	I_obs = ppo_info(Xp, Xn, d$y, th, "observed")
	H = -numDeriv::hessian(function(t) ppo_info_loglik(Xp, Xn, d$y, t), th)
	expect_lt(max(abs(I_obs - H)) / max(abs(H)), 1e-6)
	jT = ncol(am) + 1L
	expect_equal(sqrt(solve(I_obs)[jT, jT]), sqrt(vcov(m)["treatment", "treatment"]), tolerance = 1e-5)
})

test_that("partial-PO expected information gives VGAM's (Fisher scoring) treatment SE", {
	skip_if_not_installed("VGAM")
	d = ppo_info_data()
	m = suppressWarnings(VGAM::vglm(yo ~ treatment + x1 + x2,
		family = VGAM::cumulative(link = "logitlink", parallel = FALSE ~ x2), data = d))
	cv = VGAM::coef(m)
	# VGAM: logit P(Y <= k) = a_k + b' x + g_k x2, so beta = -b and gamma = g
	th = c(cv[paste0("(Intercept):", 1:3)], -cv[c("treatment", "x1")], cv[paste0("x2:", 1:3)])
	Xp = cbind(d$treatment, d$x1); Xn = cbind(d$x2)
	I_exp = ppo_info(Xp, Xn, d$y, th, "expected")
	I_obs = ppo_info(Xp, Xn, d$y, th, "observed")
	se_vgam = sqrt(VGAM::vcov(m)["treatment", "treatment"])
	expect_equal(sqrt(solve(I_exp)[4, 4]), se_vgam, tolerance = 1e-5)
	# the two sources differ at finite n (the cumulative logit is not canonical)
	expect_gt(abs(sqrt(solve(I_obs)[4, 4]) / se_vgam - 1), 1e-5)
})

test_that("with no nonparallel columns the partial-PO information reduces to the proportional-odds one", {
	d = ppo_info_data()
	X = cbind(treatment = d$treatment, x1 = d$x1)
	y = as.numeric(d$y)
	fit = fast_ordinal_regression_with_var_cpp(X, y)
	th = as.numeric(fit$params)
	I_obs = ppo_info(X, NULL, y, th, "observed")
	H = -get_ordinal_regression_hessian_cpp(X, y, th)
	expect_lt(max(abs(I_obs - H)) / max(abs(H)), 1e-8)
	cumlink_expected = get("ordinal_cumlink_expected_information", envir = asNamespace("EDI"))
	I_exp_po = cumlink_expected(X, y, th, "logit")
	expect_lt(max(abs(ppo_info(X, NULL, y, th, "expected") - I_exp_po)) / max(abs(I_exp_po)), 1e-10)
})

test_that("partial-PO information returns NULL on one category, a length mismatch or non-finite parameters", {
	d = ppo_info_data(n = 30L)
	Xp = cbind(d$treatment); Xn = cbind(d$x2)
	expect_null(ppo_info(Xp, Xn, rep(1, 30), c(0.1), "expected"))
	expect_null(ppo_info(Xp, Xn, d$y, rep(0, 4), "observed"))
	expect_null(ppo_info(Xp, Xn, d$y, c(-1, 0, 1, NA, 0, 0, 0), "observed"))
	expect_equal(dim(ppo_info(Xp, Xn, d$y, c(-1, 0, 1, 0.5, 0, 0, 0), "expected")), c(7L, 7L))
})

ppo_info_design = function(d){
	des = DesignFixediBCRD$new(n = nrow(d), response_type = "ordinal", verbose = FALSE)
	des$add_all_subjects_to_experiment(d[, c("x1", "x2")])
	des$overwrite_all_subject_assignments(d$treatment)
	des$add_all_subject_responses(d$y)
	des
}

test_that("the class's VGAM-path Wald SE is the observed information at VGAM's estimate (matches clm)", {
	skip_if_not_installed("VGAM")
	skip_if_not_installed("ordinal")
	d = ppo_info_data()
	inf = InferenceOrdinalPartialProportionalOddsRegr$new(ppo_info_design(d), nonparallel = "x2", verbose = FALSE)
	m = suppressWarnings(VGAM::vglm(yo ~ treatment + x1 + x2,
		family = VGAM::cumulative(link = "logitlink", parallel = FALSE ~ x2), data = d))
	cv = VGAM::coef(m)
	# the estimate is still VGAM's
	expect_equal(inf$compute_estimate(), -unname(cv["treatment"]), tolerance = 1e-12)
	th = c(cv[paste0("(Intercept):", 1:3)], -cv[c("treatment", "x1")], cv[paste0("x2:", 1:3)])
	se_obs = sqrt(solve(ppo_info(cbind(d$treatment, d$x1), cbind(d$x2), d$y, th, "observed"))[4, 4])
	se_class = inf$.__enclos_env__$private$get_standard_error()
	expect_equal(se_class, se_obs, tolerance = 1e-10)
	mc = ordinal::clm(yo ~ treatment + x1, nominal = ~ x2, data = d, link = "logit")
	expect_equal(se_class, sqrt(vcov(mc)["treatment", "treatment"]), tolerance = 1e-4)
	expect_gt(abs(se_class / sqrt(VGAM::vcov(m)["treatment", "treatment"]) - 1), 1e-5)
	# the Wald CI and p-value use the same SE
	ci = inf$compute_asymp_confidence_interval(0.05)
	df = nrow(d) - 1
	expect_equal(unname(ci), inf$compute_estimate() + c(-1, 1) * qt(0.975, df) * se_class, tolerance = 1e-12)
	expect_equal(inf$compute_asymp_two_sided_pval(), 2 * pt(-abs(inf$compute_estimate() / se_class), df), tolerance = 1e-12)
	expect_equal(unname(inf$compute_wald_confidence_interval(0.05)), unname(ci))
})

test_that("a non-positive-definite observed information at VGAM's estimate gives NA, and the class falls back to clm", {
	skip_if_not_installed("VGAM")
	skip_if_not_installed("ordinal")
	d = ppo_info_data()
	m = suppressWarnings(VGAM::vglm(yo ~ treatment + x1 + x2,
		family = VGAM::cumulative(link = "logitlink", parallel = FALSE ~ x2), data = d))
	vgam_se = get("ordinal_partial_po_vgam_observed_se", envir = asNamespace("EDI"))
	expect_true(is.finite(vgam_se(m, d, c("treatment", "x1", "x2"), "x2")))
	local_mocked_bindings(ordinal_partial_po_information = function(...) -diag(8), .package = "EDI")
	expect_identical(vgam_se(m, d, c("treatment", "x1", "x2"), "x2"), NA_real_)
	inf = InferenceOrdinalPartialProportionalOddsRegr$new(ppo_info_design(d), nonparallel = "x2", verbose = FALSE)
	mc = ordinal::clm(yo ~ treatment + x1, nominal = ~ x2, data = d, link = "logit")
	expect_equal(inf$compute_estimate(), unname(coef(mc)["treatment"]), tolerance = 1e-8)
	expect_equal(inf$.__enclos_env__$private$get_standard_error(), sqrt(vcov(mc)["treatment", "treatment"]), tolerance = 1e-8)
})
