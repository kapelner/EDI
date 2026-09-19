library(testthat)
library(EDI)
suppressPackageStartupMessages(library(survival))

# ordinal_cond_clogit_shared_multi() (inference_ordinal_KK_cond_logit_abstract.R):
# the adjacent-category stacked conditional-logit driver behind
# InferenceOrdinalKKCondAdjCatLogitRegr. It is a plain function taking a
# private-env, so it is driven here with a mock env: that exposes the stacked
# design it builds (checked against survival::clogit on the same expanded data),
# the |beta| <= 10 / positive-variance fit_ok guard, the too-few-categories and
# fit-unavailable nonestimable branches, and the no-op finite-SE assertion.

adj_cat_trials <- function(y_i, n_alpha) {
	trials <- integer(0)
	if (y_i <= n_alpha) trials <- c(trials, y_i)
	if (y_i > 1) trials <- c(trials, y_i - 1L)
	sort(unique(trials))
}

adj_cat_fixture <- function(seed = 21L, n = 60L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "ordinal", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	y <- as.integer(cut(0.5 * w + 0.4 * X$x1 + rlogis(n), c(-Inf, -0.6, 0.6, Inf), labels = FALSE))
	des$add_all_subject_responses(y)
	inf <- InferenceOrdinalKKCondAdjCatLogitRegr$new(des, verbose = FALSE)
	list(inf = inf, priv = inf$.__enclos_env__$private, n = n)
}

make_mock_env <- function(priv, y = priv$y, mod_override = NULL) {
	e <- new.env()
	e$m <- priv$m
	e$n <- priv$n
	e$y <- y
	e$w <- priv$w
	e$cached_values <- list()
	e$reason <- NULL
	e$captured_X <- NULL
	e$fit_ok_result <- NA
	e$get_X <- function() priv$get_X()
	e$cache_nonestimable_estimate <- function(reason) e$reason <- reason
	e$fit_with_hardened_qr_column_dropping <- function(X_full, required_cols, fit_fun, fit_ok) {
		e$captured_X <- X_full
		e$required_cols <- required_cols
		mod <- if (is.null(mod_override)) fit_fun(X_full) else mod_override
		e$fit_ok_result <- fit_ok(mod, X_full, seq_len(ncol(X_full)))
		list(fit = mod, X = X_full, keep = seq_len(ncol(X_full)))
	}
	e
}

run_shared_multi <- function(e) {
	EDI:::ordinal_cond_clogit_shared_multi(e, EDI:::expand_adjacent_category_data_cpp, adj_cat_trials)
}

test_that("shared_multi stacks adjacent-category rows and reproduces an independent survival::clogit fit", {
	f <- adj_cat_fixture()
	e <- make_mock_env(f$priv)
	run_shared_multi(e)

	setup <- EDI:::ordinal_cond_clogit_compute_setup(f$priv)
	K <- setup$K
	expect_equal(K, 3L)
	expected_rows <- sum(ifelse(setup$y_ord == 1L | setup$y_ord == K, 1L, 2L))
	expect_equal(nrow(e$captured_X), expected_rows)
	expect_equal(colnames(e$captured_X)[1], "treatment")
	expect_equal(e$required_cols, 1L)
	expect_true(isTRUE(e$fit_ok_result))

	ex <- EDI:::expand_adjacent_category_data_cpp(
		as.integer(setup$y_ord), as.integer(f$priv$w), as.integer(setup$strata_ids), as.integer(K)
	)
	df <- data.frame(y = ex$y, tr = ex$w, x1 = e$captured_X[, 2], st = ex$strata)
	ref <- survival::clogit(y ~ tr + x1 + strata(st), data = df)
	expect_equal(e$cached_values$beta_hat_T, unname(coef(ref)["tr"]), tolerance = 1e-3)
	expect_equal(e$cached_values$s_beta_hat_T, unname(sqrt(vcov(ref)["tr", "tr"])), tolerance = 1e-3)

	# The real class caches the same estimate and SE.
	expect_equal(f$inf$compute_estimate(), e$cached_values$beta_hat_T, tolerance = 1e-8)
	expect_equal(f$priv$cached_values$s_beta_hat_T, e$cached_values$s_beta_hat_T, tolerance = 1e-8)
})

test_that("a single response category is nonestimable before any fit is attempted", {
	f <- adj_cat_fixture()
	e <- make_mock_env(f$priv, y = rep(2L, f$n))
	expect_null(run_shared_multi(e))
	expect_equal(e$reason, "ordinal_cond_clogit_too_few_categories")
	expect_length(e$cached_values, 0L)
	expect_null(e$captured_X)
})

test_that("an existing cached estimate short-circuits the fit", {
	f <- adj_cat_fixture()
	e <- make_mock_env(f$priv)
	e$cached_values$beta_hat_T <- 0.5
	run_shared_multi(e)
	expect_null(e$captured_X)
	expect_equal(e$cached_values$beta_hat_T, 0.5)
})

test_that("fit_ok rejects divergent, non-finite and zero-variance conditional-logit fits and the driver reports fit-unavailable", {
	f <- adj_cat_fixture()
	cases <- list(
		usable = list(mod = list(b = c(1.5, 0.2), ssq_b_j = 0.3), ok = TRUE, estimable = TRUE),
		at_ceiling = list(mod = list(b = c(10, 0), ssq_b_j = 1), ok = TRUE, estimable = TRUE),
		divergent = list(mod = list(b = c(10.5, 0), ssq_b_j = 1), ok = FALSE, estimable = TRUE),
		zero_var = list(mod = list(b = c(1, 0), ssq_b_j = 0), ok = FALSE, estimable = FALSE),
		na_var = list(mod = list(b = c(1, 0), ssq_b_j = NA_real_), ok = FALSE, estimable = FALSE),
		na_beta = list(mod = list(b = c(NA_real_, 0), ssq_b_j = 1), ok = FALSE, estimable = FALSE)
	)
	for (nm in names(cases)) {
		e <- make_mock_env(f$priv, mod_override = cases[[nm]]$mod)
		run_shared_multi(e)
		expect_identical(isTRUE(e$fit_ok_result), cases[[nm]]$ok, info = nm)
		if (cases[[nm]]$estimable) {
			expect_equal(e$cached_values$beta_hat_T, cases[[nm]]$mod$b[1], info = nm)
			expect_null(e$reason)
		} else {
			expect_equal(e$reason, "ordinal_cond_clogit_fit_unavailable", info = nm)
			expect_length(e$cached_values, 0L)
		}
	}
})

test_that("ordinal_cond_clogit_assert_finite_se is a no-op for finite and non-finite SEs (source quirk, not fixed)", {
	# SOURCE QUIRK (noted, not fixed): both branches return an invisible NULL and
	# neither stops, warns nor caches a nonestimable state, so the assertion the
	# name promises never fires.
	f <- adj_cat_fixture()
	for (se in list(0.4, NA_real_, Inf)) {
		e <- new.env()
		e$cached_values <- list(s_beta_hat_T = se)
		expect_null(EDI:::ordinal_cond_clogit_assert_finite_se(e, "X"))
		expect_no_warning(EDI:::ordinal_cond_clogit_assert_finite_se(e, "X"))
		expect_identical(e$cached_values$s_beta_hat_T, se)
	}
})
