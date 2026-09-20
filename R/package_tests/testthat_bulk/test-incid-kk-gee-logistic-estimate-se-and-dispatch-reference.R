library(testthat)
library(EDI)

# InferenceIncidKKGEE (KK logistic GEE, exchangeable working correlation on matched
# pairs with reservoir singletons): estimate, robust SE, p-value and CI against
# geepack::geeglm, agreement of the Rcpp solver with the geepack backend, the
# family/response descriptors, the shared() -> shared_gee_default() dispatch, and
# the absence of the count-only jackknife-Wald calibration.

kk_fx <- function(seed = 4L, np = 40L, ns = 20L, ...) {
	set.seed(seed)
	n <- 2L * np + ns
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	des$.__enclos_env__$private$m <- c(rep(seq_len(np), each = 2L), rep(0L, ns))
	w <- des$get_w()
	g <- c(rep(seq_len(np), each = 2L), np + seq_len(ns))
	u <- rnorm(max(g), 0, 0.7)
	y <- rbinom(n, 1, plogis(-0.3 + 0.8 * w + 0.4 * X$x1 + u[g]))
	des$add_all_subject_responses(y)
	inf <- InferenceIncidKKGEE$new(des, verbose = FALSE, ...)
	list(inf = inf, p = inf$.__enclos_env__$private, w = w, x1 = X$x1, y = y, g = g, n = n)
}

ref_gee <- function(f) {
	dat <- data.frame(y = f$y, w = f$w, x1 = f$x1, id = f$g)[order(f$g), ]
	m <- geepack::geeglm(y ~ w + x1, id = id, data = dat, family = binomial(), corstr = "exchangeable")
	list(b = unname(coef(m)["w"]), se = summary(m)$coefficients["w", "Std.err"])
}

test_that("Rcpp GEE estimate and robust SE match geepack::geeglm", {
	skip_if_not_installed("geepack")
	f <- kk_fx(); r <- ref_gee(f)
	est <- f$inf$compute_estimate()
	f$inf$compute_asymp_two_sided_pval(0)
	se <- f$p$cached_values$s_beta_hat_T
	expect_equal(est, r$b, tolerance = 1e-3)
	expect_equal(se, r$se, tolerance = 1e-3)
	z <- est / se
	expect_equal(f$inf$compute_asymp_two_sided_pval(0), 2 * pnorm(-abs(z)), tolerance = 1e-6)
	expect_equal(as.numeric(f$inf$compute_asymp_confidence_interval(0.1)), est + c(-1, 1) * qnorm(0.95) * se, tolerance = 1e-6)
})

test_that("the geepack backend (use_rcpp = FALSE) agrees with the Rcpp solver", {
	skip_if_not_installed("geepack")
	a <- kk_fx(); b <- kk_fx(use_rcpp = FALSE)
	expect_equal(b$inf$compute_estimate(), a$inf$compute_estimate(), tolerance = 1e-3)
	a$inf$compute_asymp_two_sided_pval(0); b$inf$compute_asymp_two_sided_pval(0)
	expect_equal(b$p$cached_values$s_beta_hat_T, a$p$cached_values$s_beta_hat_T, tolerance = 5e-3)
	r <- ref_gee(b)
	expect_equal(b$inf$compute_estimate(), r$b, tolerance = 1e-6)
})

test_that("descriptors and dispatch: binomial logit family, incidence response, no jackknife-Wald calibration", {
	f <- kk_fx()
	expect_equal(f$p$gee_response_type(), "incidence")
	expect_equal(f$p$gee_family()$family, "binomial")
	expect_equal(f$p$gee_family()$link, "logit")
	expect_equal(f$p$gee_family_str(), "binomial")
	expect_true(f$p$is_a_gee_family())
	expect_false(f$p$use_kk_gee_jackknife_wald_calibration())                     # the calibration is count-only
	# shared() forwards to the class's dispatch hook, which runs the default GEE fit.
	calls <- character(0)
	unlockBinding("shared_gee_default", f$p)
	f$p$shared_gee_default <- function(estimate_only = FALSE) { calls <<- c(calls, paste0("default:", estimate_only)); invisible(NULL) }
	f$p$shared(TRUE); f$p$shared(FALSE)
	expect_equal(calls, c("default:TRUE", "default:FALSE"))
})

test_that("estimate_only skips the SE; a full request then computes it", {
	f <- kk_fx()
	f$inf$compute_estimate(estimate_only = TRUE)
	est <- f$p$cached_values$beta_hat_T
	expect_true(is.finite(est))
	expect_true(is.finite(f$inf$compute_asymp_two_sided_pval(0)))
	expect_true(is.finite(f$p$cached_values$s_beta_hat_T) && f$p$cached_values$s_beta_hat_T > 0)
	expect_equal(f$p$cached_values$beta_hat_T, est, tolerance = 1e-8)
})

test_that("the reservoir-inclusive fit data uses one id per matched pair and unique ids for reservoir subjects", {
	f <- kk_fx()
	fd <- f$p$build_gee_fit_data()
	expect_equal(fd$id_sorted, f$g)
	expect_equal(fd$y_sorted, f$y)
	expect_equal(colnames(fd$dat), c("w", "x1"))
	expect_true(f$p$gee_has_reservoir())
	expect_false(kk_fx(ns = 0L)$p$gee_has_reservoir())
})
