library(testthat)
library(EDI)

# The KKGEE mixin's private helpers on InferenceCountPoissonKKGEE: the
# coefficient extractors (treatment index / usability / estimate / SE for both
# rcpp-style list fits and real geepack::geeglm fits), build_gee_fit_data()
# (reservoir id assignment, exclusion, weights, ordering), gee_warm_start_args(),
# gee_family_str() and the count-specific jackknife-Wald calibration wrappers.

gee_fx <- function(seed = 1L, np = 15L, ns = 6L) {
	set.seed(seed)
	n <- 2L * np + ns
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "count", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	des$.__enclos_env__$private$m <- c(rep(seq_len(np), each = 2L), rep(0L, ns))
	y <- rpois(n, 3)
	des$add_all_subject_responses(y)
	inf <- InferenceCountPoissonKKGEE$new(des, verbose = FALSE)
	list(inf = inf, p = inf$.__enclos_env__$private, n = n, np = np, ns = ns, y = y, X = X)
}

test_that("treatment index prefers the coefficient named w, else the second slot", {
	p <- gee_fx()$p
	expect_equal(p$gee_treatment_index(c("(Intercept)" = 0, x1 = 1, w = 2)), 3L)
	expect_equal(p$gee_treatment_index(c(a = 0, b = 1, c = 2)), 2L)
	expect_equal(p$gee_treatment_index(c(0, 1)), 2L)
	expect_true(is.na(p$gee_treatment_index(5)))
	expect_true(is.na(p$gee_treatment_index(NULL)))
	expect_true(is.na(p$gee_treatment_index(numeric(0))))
})

test_that("coefficient usability: finite and within max_abs_reasonable_coef", {
	p <- gee_fx()$p
	expect_true(p$gee_coefficients_are_usable(c(1, -2)))
	expect_true(p$gee_coefficients_are_usable(c(1e4, 0)))
	expect_false(p$gee_coefficients_are_usable(c(1e4 + 1, 0)))
	expect_false(p$gee_coefficients_are_usable(c(1, NA)))
	expect_false(p$gee_coefficients_are_usable(c(1, Inf)))
	expect_false(p$gee_coefficients_are_usable(numeric(0)))
	p$max_abs_reasonable_coef <- 1
	expect_false(p$gee_coefficients_are_usable(2))
})

test_that("estimate extraction from list fits, NULL, unusable and treatment-less coefficients", {
	p <- gee_fx()$p
	expect_true(is.na(p$extract_gee_treatment_estimate(NULL)))
	expect_equal(p$extract_gee_treatment_estimate(list(beta = c("(Intercept)" = 0.1, w = 0.7))), 0.7)
	expect_equal(p$extract_gee_treatment_estimate(list(beta = c(0.1, 0.9, 3))), 0.9)          # second slot when unnamed
	expect_true(is.na(p$extract_gee_treatment_estimate(list(beta = c(0.1, 1e6)))))
	expect_true(is.na(p$extract_gee_treatment_estimate(list(beta = 0.3))))
	expect_true(is.na(p$extract_gee_treatment_estimate(list(beta = c(0, NA)))))
})

test_that("SE extraction: list fits use vcov[j, j]; invalid variances and shapes give NA", {
	p <- gee_fx()$p
	vc <- matrix(c(1, 0.1, 0.1, 4), 2)
	expect_equal(p$extract_gee_treatment_se(list(beta = c(0, 1), vcov = vc), j_treat = 2L), 2)
	expect_equal(p$extract_gee_treatment_se(list(beta = c(a = 0, w = 1), vcov = vc)), 2)     # index inferred
	expect_true(is.na(p$extract_gee_treatment_se(NULL)))
	expect_true(is.na(p$extract_gee_treatment_se(list(beta = c(0, 1), vcov = matrix(c(1, 0, 0, -4), 2)), 2L)))
	expect_true(is.na(p$extract_gee_treatment_se(list(beta = c(0, 1), vcov = matrix(c(1, 0, 0, 0), 2)), 2L)))
	expect_true(is.na(p$extract_gee_treatment_se(list(beta = c(0, 1), vcov = NULL), 2L)))
	expect_true(is.na(p$extract_gee_treatment_se(list(beta = c(0, 1), vcov = diag(1)), 2L)))  # index beyond the matrix
	expect_true(is.na(p$extract_gee_treatment_se(list(beta = c(0, 1), vcov = vc), 0L)))
})

test_that("SE extraction from a real geeglm uses the summary table's robust SE, falling back to vcov", {
	f <- gee_fx()
	fd <- f$p$build_gee_fit_data()
	dat <- data.frame(y = fd$y_sorted, fd$dat, id = fd$id_sorted)
	mod <- geepack::geeglm(y ~ w + x1, id = id, data = dat, family = poisson(), corstr = "exchangeable")
	ct <- summary(mod)$coefficients
	expect_equal(f$p$extract_gee_treatment_estimate(mod), unname(coef(mod)["w"]))
	expect_equal(f$p$extract_gee_treatment_se(mod, coef_table = ct), ct["w", "Std.err"], tolerance = 1e-10)
	expect_equal(f$p$extract_gee_treatment_se(mod), sqrt(vcov(mod)["w", "w"]), tolerance = 1e-10)
	expect_equal(f$p$extract_gee_treatment_se(mod, j_treat = 2L, coef_table = ct[, "Estimate", drop = FALSE]),
		sqrt(vcov(mod)["w", "w"]), tolerance = 1e-10)           # no SE column -> vcov
})

test_that("build_gee_fit_data: reservoir singletons get fresh ids after the largest pair id, sorted by group", {
	f <- gee_fx()
	fd <- f$p$build_gee_fit_data()
	expect_equal(nrow(fd$dat), f$n)
	expect_equal(fd$id_sorted, c(rep(seq_len(f$np), each = 2L), f$np + seq_len(f$ns)))
	expect_equal(fd$y_sorted, f$y)                          # already in group order
	expect_equal(colnames(fd$dat), c("w", "x1"))
	expect_null(fd$weights_sorted)

	no_res <- f$p$build_gee_fit_data(include_reservoir = FALSE)
	expect_equal(nrow(no_res$dat), 2L * f$np)
	expect_equal(no_res$id_sorted, rep(seq_len(f$np), each = 2L))

	# Row weights are carried along, in sorted order, and stay out of the predictors.
	wts <- seq_len(f$n) / 10
	fw <- f$p$build_gee_fit_data(row_weights = wts)
	expect_equal(fw$weights_sorted, wts)
	expect_false(".bootstrap_weight" %in% colnames(fw$dat))
	fw2 <- f$p$build_gee_fit_data(include_reservoir = FALSE, row_weights = wts)
	expect_equal(fw2$weights_sorted, wts[seq_len(2L * f$np)])

	# Out-of-order pair ids are sorted by group id with y following.
	f$p$m <- c(rev(rep(seq_len(f$np), each = 2L)), rep(0L, f$ns))
	fo <- f$p$build_gee_fit_data(include_reservoir = FALSE)
	expect_equal(fo$id_sorted, rep(seq_len(f$np), each = 2L))
	expect_equal(sort(fo$y_sorted), sort(f$y[seq_len(2L * f$np)]))
})

test_that("build_gee_fit_data with no matches: reservoir-only ids start at 1; excluding reservoir yields NULL; NA m counts as reservoir", {
	f <- gee_fx()
	f$p$m <- rep(NA_integer_, f$n)
	fd <- f$p$build_gee_fit_data()
	expect_equal(fd$id_sorted, seq_len(f$n))
	expect_null(f$p$build_gee_fit_data(include_reservoir = FALSE))
	f$p$m <- NULL
	expect_equal(f$p$build_gee_fit_data()$id_sorted, seq_len(f$n))
})

test_that("gee_warm_start_args returns nothing until a warm start exists, then length/dimension-gated pieces", {
	f <- gee_fx()
	a <- f$p$gee_warm_start_args(2L)
	expect_null(a$start_beta); expect_null(a$warm_start_beta); expect_null(a$start_params)
	expect_setequal(names(a), c("start_beta", "warm_start_beta", "start_params", "warm_start_weights", "warm_start_fisher_info"))
	f$p$set_fit_warm_start(c(0.1, 0.2), "beta")
	a <- f$p$gee_warm_start_args(2L)
	expect_equal(a$start_beta, c(0.1, 0.2)); expect_identical(a$warm_start_beta, a$start_beta)
	expect_null(f$p$gee_warm_start_args(3L)$start_beta)          # wrong length is dropped
})

test_that("family string maps poisson; the count leaf uses the jackknife-Wald calibration", {
	p <- gee_fx()$p
	expect_equal(p$gee_family_str(), "poisson")
	expect_true(p$is_a_gee_family())
	expect_equal(p$get_complexity_tier(), "medium")
	expect_true(p$use_kk_gee_jackknife_wald_calibration())
})

test_that("jackknife-Wald wrappers pass valid results and otherwise cache an unavailable-calibration reason", {
	f <- gee_fx()
	unlockBinding("compute_jackknife_wald_two_sided_pval", f$inf)
	unlockBinding("compute_jackknife_wald_confidence_interval", f$inf)
	f$inf$compute_jackknife_wald_two_sided_pval <- function(delta = 0) 0.25
	expect_equal(f$p$compute_kk_gee_jackknife_wald_two_sided_pval(0), 0.25)
	expect_false(isTRUE(f$inf$is_nonestimable("se")))
	for (bad in list(NA_real_, 1.5, -0.1)) {
		g <- gee_fx()
		unlockBinding("compute_jackknife_wald_two_sided_pval", g$inf)
		g$inf$compute_jackknife_wald_two_sided_pval <- local({ b <- bad; function(delta = 0) b })
		expect_true(is.na(g$p$compute_kk_gee_jackknife_wald_two_sided_pval(0)))
		expect_identical(g$inf$get_nonestimable_reason(), "kk_count_gee_jackknife_wald_calibration_unavailable")
	}
	h <- gee_fx()
	unlockBinding("compute_jackknife_wald_two_sided_pval", h$inf)
	h$inf$compute_jackknife_wald_two_sided_pval <- function(delta = 0) stop("boom")
	expect_true(is.na(h$p$compute_kk_gee_jackknife_wald_two_sided_pval(0)))
	expect_true(h$inf$is_nonestimable("se"))

	f$inf$compute_jackknife_wald_confidence_interval <- function(alpha = 0.05) c("2.5%" = -1, "97.5%" = 2)
	expect_equal(f$p$compute_kk_gee_jackknife_wald_confidence_interval(0.05), c("2.5%" = -1, "97.5%" = 2))
	for (bad in list(c(1, -1), c(NA_real_, 1), 3)) {
		g <- gee_fx()
		unlockBinding("compute_jackknife_wald_confidence_interval", g$inf)
		g$inf$compute_jackknife_wald_confidence_interval <- local({ b <- bad; function(alpha = 0.05) b })
		ci <- g$p$compute_kk_gee_jackknife_wald_confidence_interval(0.1)
		expect_true(all(is.na(ci)))
		expect_equal(names(ci), c("5%", "95%"))
		expect_true(g$inf$is_nonestimable("se"))
	}
})
