library(testthat)
library(EDI)

# InferenceOrdinalPartialProportionalOddsRegr's individual private backend fit
# methods (fit_clm, fit_clm_weighted, fit_polr, fit_polr_weighted), the
# extract_common_treatment_fit() helper they share, ppo_covariate_matrix(), and
# the public benchmark_asymp_two_sided_pval_breakdown() diagnostic. Sibling
# files cover the VGAM primary path and the whole-cascade MASS fallback; none
# calls these backend methods directly against independent ordinal::clm /
# MASS::polr fits.

ppo_direct_fixture <- function(seed = 7L, n = 120L) {
	skip_if_not_installed("ordinal")
	set.seed(seed)
	x1 <- rnorm(n)
	des <- DesignFixediBCRD$new(n = n, response_type = "ordinal", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = x1))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	lin <- 0.5 * w + 0.4 * x1
	y <- 1L + rowSums(matrix(runif(n), n, 3) > plogis(outer(lin, c(-1, 0.5, 1.6), "-")))
	des$add_all_subject_responses(y)
	inf <- InferenceOrdinalPartialProportionalOddsRegr$new(des, model_formula = ~x1, verbose = FALSE)
	dat <- data.frame(y = ordered(y), treatment = w, x1 = x1)
	list(inf = inf, priv = inf$.__enclos_env__$private, dat = dat, n = n)
}

test_that("fit_clm and fit_polr match independent ordinal::clm / MASS::polr treatment fits", {
	f <- ppo_direct_fixture()
	ref_clm <- ordinal::clm(y ~ treatment + x1, data = f$dat, link = "logit")
	got <- f$priv$fit_clm(f$dat, "x1", character(0))
	expect_equal(got$beta, unname(coef(ref_clm)["treatment"]), tolerance = 1e-8)
	expect_equal(got$se, unname(sqrt(vcov(ref_clm)["treatment", "treatment"])), tolerance = 1e-8)

	ref_polr <- suppressWarnings(MASS::polr(y ~ treatment + x1, data = f$dat, method = "logistic", Hess = TRUE))
	got_polr <- f$priv$fit_polr(f$dat, "x1", character(0))
	expect_equal(got_polr$beta, unname(coef(ref_polr)["treatment"]), tolerance = 1e-4)
	expect_true(is.finite(got_polr$se) && got_polr$se > 0)
})

test_that("weighted polr backend matches an independent weighted fit and drops the SE", {
	f <- ppo_direct_fixture()
	set.seed(11)
	dat <- f$dat
	dat$.bootstrap_weight__ <- runif(f$n, 0.3, 2)
	ref_polr <- suppressWarnings(MASS::polr(y ~ treatment + x1, data = dat, weights = .bootstrap_weight__,
		method = "logistic", Hess = FALSE, control = list(reltol = 1e-10)))
	got_polr <- f$priv$fit_polr_weighted(dat, "x1", character(0))
	expect_equal(got_polr$beta, unname(coef(ref_polr)["treatment"]), tolerance = 1e-6)
	expect_true(is.na(got_polr$se))
})

test_that("fit_clm_weighted silently returns NULL unless a global `dat` happens to exist (real source bug, not fixed)", {
	# SOURCE BUG (noted, not fixed): fit_clm_weighted() passes
	# `weights = dat$.bootstrap_weight__` to ordinal::clm(). clm evaluates
	# `weights` via model.frame() in the data/formula environment, not the
	# calling frame, so the method-local `dat` is invisible and clm errors with
	# "object 'dat' not found". The method's tryCatch swallows that and returns
	# NULL, so in real use (no global `dat`) the weighted clm backend never
	# succeeds and the weighted cascade always falls through to polr. It only
	# "works" when some unrelated global object named `dat` exists. fit_polr_weighted
	# avoids this by naming the column (`weights = .bootstrap_weight__`).
	skip_if(exists("dat", envir = globalenv()), "a global `dat` masks the bug")
	f <- ppo_direct_fixture()
	dat <- f$dat
	dat$.bootstrap_weight__ <- rep(1, f$n)
	expect_null(f$priv$fit_clm_weighted(dat, "x1", character(0)))
	expect_null(f$priv$fit_clm_weighted(dat, character(0), "x1"))

	# The clm error is real and independent of the wrapper: naming the weight
	# column (the fit_polr_weighted convention) fits fine.
	ref <- ordinal::clm(y ~ treatment + x1, data = dat, weights = .bootstrap_weight__, link = "logit")
	expect_true(is.finite(unname(coef(ref)["treatment"])))
})

test_that("nonparallel covariates make both polr backends decline", {
	f <- ppo_direct_fixture()
	dat <- f$dat
	dat$.bootstrap_weight__ <- rep(1, f$n)
	expect_null(f$priv$fit_polr(dat, character(0), "x1"))
	expect_null(f$priv$fit_polr_weighted(dat, character(0), "x1"))
})

test_that("extract_common_treatment_fit handles a missing treatment coefficient, throwing getters and unusable variances", {
	f <- ppo_direct_fixture()
	ex <- f$priv$extract_common_treatment_fit
	mod <- list()
	cf <- c(treatment = 0.7, x1 = 0.1)

	ok <- ex(mod, function(m) cf, function(m) matrix(c(4, 0, 0, 1), 2, 2, dimnames = list(names(cf), names(cf))))
	expect_equal(ok, list(beta = 0.7, se = 2))
	expect_null(ex(mod, function(m) c(x1 = 0.1), function(m) diag(1)))
	expect_null(ex(mod, function(m) stop("boom"), function(m) diag(2)))
	expect_null(ex(mod, function(m) NULL, function(m) diag(2)))
	expect_true(is.na(ex(mod, function(m) cf, function(m) stop("no vcov"))$se))
	zero_var <- matrix(c(0, 0, 0, 1), 2, 2, dimnames = list(names(cf), names(cf)))
	expect_true(is.na(ex(mod, function(m) cf, function(m) zero_var)$se))
	nan_var <- matrix(c(NaN, 0, 0, 1), 2, 2, dimnames = list(names(cf), names(cf)))
	expect_true(is.na(ex(mod, function(m) cf, function(m) nan_var)$se))
})

test_that("ppo_covariate_matrix returns the design's covariates as an n-row matrix", {
	f <- ppo_direct_fixture()
	m <- f$priv$ppo_covariate_matrix()
	expect_true(is.matrix(m))
	expect_equal(dim(m), c(f$n, 1L))
	expect_equal(as.numeric(m[, 1]), as.numeric(f$dat$x1), tolerance = 1e-12)
})

test_that("benchmark_asymp_two_sided_pval_breakdown agrees with the asymptotic p-value and reports NA timings on failure", {
	f <- ppo_direct_fixture()
	b <- f$inf$benchmark_asymp_two_sided_pval_breakdown()
	expect_named(b, c("fit_time", "cache_time", "pval_math_time", "total_time", "pval", "beta_hat_T", "s_beta_hat_T"))
	expect_equal(b$total_time, round(b$fit_time + b$cache_time + b$pval_math_time, 6))
	expect_true(all(c(b$fit_time, b$cache_time, b$pval_math_time) >= 0))

	f2 <- ppo_direct_fixture()
	expect_equal(b$pval, f2$inf$compute_asymp_two_sided_pval(), tolerance = 1e-10)
	expect_equal(b$beta_hat_T, f2$inf$compute_estimate(), tolerance = 1e-10)
	# With a nonzero null, the p-value is the two-sided test against that value.
	bd <- ppo_direct_fixture()$inf$benchmark_asymp_two_sided_pval_breakdown(delta = b$beta_hat_T)
	expect_equal(bd$pval, 1, tolerance = 1e-8)

	f3 <- ppo_direct_fixture()
	unlockBinding("fit_partial_proportional_odds", f3$priv)
	f3$priv$fit_partial_proportional_odds <- function(require_se = FALSE) NULL
	bf <- f3$inf$benchmark_asymp_two_sided_pval_breakdown()
	expect_true(is.finite(bf$fit_time))
	expect_equal(bf$total_time, bf$fit_time)
	expect_true(all(is.na(c(bf$cache_time, bf$pval_math_time, bf$pval, bf$beta_hat_T, bf$s_beta_hat_T))))
})
