library(testthat)
library(EDI)

# InferenceIncidKKCondLogitIVWC's private shared() (inference_incidence_KK_cond_logit.R) combines two
# independently-fit conditional-likelihood pieces -- clogit_for_matched_pairs() (conditional logistic
# regression on the matched pairs, via the package-level conditional_logit_fit_matched_pairs()) and
# logistic_for_reservoir() (ordinary logistic regression on the reservoir, via conditional_logit_fit_
# reservoir()) -- into an inverse-variance-weighted combination, with 4 distinct branches depending on
# which piece(s) succeed:
#   1. both succeed: IVWC combination, beta_hat_T = w_star*beta_m + (1-w_star)*beta_r with
#      w_star = ssq_r/(ssq_r+ssq_m), s_beta_hat_T = sqrt(ssq_m*ssq_r/(ssq_m+ssq_r)).
#   2. only the matched-pairs piece succeeds: beta_hat_T = beta_m, s_beta_hat_T = sqrt(ssq_m).
#   3. only the reservoir piece succeeds: beta_hat_T = beta_r, s_beta_hat_T = sqrt(ssq_r).
#   4. both fail (or return non-converged): beta_hat_T = s_beta_hat_T = NA_real_.
# The only existing reference for this class (test-partial-likelihood-migration-baseline.R) is a
# golden-parity migration test exercising only the ordinary happy path where both pieces succeed on
# real data -- none of these 4 branches (nor clogit_for_matched_pairs()/logistic_for_reservoir()'s own
# NA-caching on a NULL/non-converged fit) had a direct test reference anywhere. Reached by mocking the
# two package-level fitter functions (conditional_logit_fit_matched_pairs/conditional_logit_fit_
# reservoir), independent of the real conditional-logit/logistic-regression machinery (already tested
# elsewhere), to deterministically control which piece succeeds and with what point estimate/variance.

mk_fixture <- function(seed, n = 30L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	y <- rbinom(n, 1, plogis(-0.3 + 0.9 * w + 0.4 * X$x1))
	des$add_all_subject_responses(y)
	InferenceIncidKKCondLogitIVWC$new(des, verbose = FALSE)
}

fake_matched_ok <- list(converged = TRUE, b = c(1.5), ssq_b_j = 0.3)
fake_reservoir_ok <- list(converged = TRUE, b = c(0, 0.8), ssq_b_j = 0.5)

test_that("only the matched-pairs piece succeeds: beta_hat_T = beta_m, s_beta_hat_T = sqrt(ssq_m)", {
	inf <- mk_fixture(1L)
	priv <- inf$.__enclos_env__$private
	local_mocked_bindings(conditional_logit_fit_matched_pairs = function(...) fake_matched_ok, .package = "EDI")
	local_mocked_bindings(conditional_logit_fit_reservoir = function(...) NULL, .package = "EDI")
	est <- inf$compute_estimate()
	expect_equal(est, 1.5)
	expect_equal(priv$cached_values$s_beta_hat_T, sqrt(0.3))
})

test_that("only the reservoir piece succeeds: beta_hat_T = beta_r, s_beta_hat_T = sqrt(ssq_r)", {
	inf <- mk_fixture(2L)
	priv <- inf$.__enclos_env__$private
	local_mocked_bindings(conditional_logit_fit_matched_pairs = function(...) NULL, .package = "EDI")
	local_mocked_bindings(conditional_logit_fit_reservoir = function(...) fake_reservoir_ok, .package = "EDI")
	est <- inf$compute_estimate()
	expect_equal(est, 0.8)
	expect_equal(priv$cached_values$s_beta_hat_T, sqrt(0.5))
})

test_that("both pieces succeed: the IVWC combination matches the closed-form weighted formula exactly", {
	inf <- mk_fixture(3L)
	priv <- inf$.__enclos_env__$private
	local_mocked_bindings(conditional_logit_fit_matched_pairs = function(...) fake_matched_ok, .package = "EDI")
	local_mocked_bindings(conditional_logit_fit_reservoir = function(...) fake_reservoir_ok, .package = "EDI")
	est <- inf$compute_estimate()
	w_star <- 0.5 / (0.5 + 0.3)
	expect_equal(est, w_star * 1.5 + (1 - w_star) * 0.8)
	expect_equal(priv$cached_values$s_beta_hat_T, sqrt(0.3 * 0.5 / (0.3 + 0.5)))
})

test_that("both pieces fail (or return non-converged): beta_hat_T and s_beta_hat_T are NA_real_", {
	inf <- mk_fixture(4L)
	local_mocked_bindings(conditional_logit_fit_matched_pairs = function(...) NULL, .package = "EDI")
	local_mocked_bindings(conditional_logit_fit_reservoir = function(...) list(converged = FALSE), .package = "EDI")
	est <- inf$compute_estimate()
	expect_true(is.na(est))
})

# docs-claims audit, finding docs-claims-d4609a785: on real data the matched-pair piece is exact
# conditional logit (survival's exact conditional likelihood) and the reservoir piece is ordinary
# logistic regression (glm binomial); the cached components and their variances match both.
test_that("KK CondLogit IVWC matched and reservoir components equal survival's conditional logit and glm(binomial)", {
	skip_if_not_installed("survival")
	set.seed(31)
	n <- 120
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n), x2 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	y <- rbinom(n, 1, plogis(-0.2 + 0.7 * w + 0.5 * X$x1))
	des$add_all_subject_responses(y)
	m <- des$.__enclos_env__$private$m[seq_len(n)]
	inf <- InferenceIncidKKCondLogitIVWC$new(des, verbose = FALSE)
	inf$compute_estimate()
	inf$compute_asymp_confidence_interval()
	cv <- inf$.__enclos_env__$private$cached_values
	d <- data.frame(y = y, w = w, X, m = m)
	pr <- d[d$m > 0, ]
	cl <- survival::coxph(survival::Surv(rep(1, nrow(pr)), y) ~ w + x1 + x2 + survival::strata(m), data = pr, method = "exact")
	expect_equal(cv$beta_T_matched, unname(coef(cl)[["w"]]), tolerance = 1e-6)
	expect_equal(cv$ssq_beta_T_matched, vcov(cl)[["w", "w"]], tolerance = 1e-5)
	rs <- d[d$m == 0, ]
	expect_gt(nrow(rs), 5L)
	g <- glm(y ~ w + x1 + x2, family = binomial(), data = rs, control = glm.control(epsilon = 1e-14, maxit = 100))
	expect_equal(cv$beta_T_reservoir, unname(coef(g)[["w"]]), tolerance = 1e-6)
	expect_equal(cv$ssq_beta_T_reservoir, vcov(g)[["w", "w"]], tolerance = 1e-5)
})
