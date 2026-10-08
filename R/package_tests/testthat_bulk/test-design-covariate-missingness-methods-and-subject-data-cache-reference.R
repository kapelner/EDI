library(testthat)
library(EDI)

# Design's private covariate_impute_if_necessary_and_then_create_model_matrix()
# (missingness_method = "error" / "drop_column" / "impute", with and without
# missingness indicators, constant-column dropping) and
# compute_all_subject_data()'s per-t cache with always-fresh w / y slices. No
# existing test reference passed a non-default missingness_method or checked the
# model matrix these branches build.

miss_covariates <- function(n = 30L, seed = 3L) {
	set.seed(seed)
	X <- data.frame(a = rnorm(n), b = rnorm(n), cc = rep(1, n), d = sample(c("u", "v"), n, TRUE))
	X$a[c(2, 5)] <- NA
	X$d[4] <- NA
	X
}

miss_design <- function(method = "impute", indicators = FALSE, X = miss_covariates()) {
	des <- DesignFixedBernoulli$new(
		n = nrow(X), response_type = "continuous", missingness_method = method,
		include_is_missing_as_a_new_feature = indicators, verbose = FALSE
	)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des
}

run_build <- function(des) {
	priv <- des$.__enclos_env__$private
	priv$covariate_impute_if_necessary_and_then_create_model_matrix()
	priv
}

test_that("missingness_method = 'error' names every column with missing values", {
	# Fixed designs build lazily; the first matrix consumer raises the error.
	des_error <- miss_design("error")
	expect_error(des_error$get_X(), "Missing values detected in covariate\\(s\\): a, d")
	clean <- miss_covariates(); clean$a[is.na(clean$a)] <- 0; clean$d[is.na(clean$d)] <- "u"
	des <- miss_design("error", X = clean)
	expect_equal(des$get_missingness_method(), "error")
	expect_false(anyNA(run_build(des)$Ximp))
})

test_that("fixed design model matrices are lazy and preserve draws and inference inputs", {
	n <- 24L
	X <- data.frame(x = seq_len(n), z = factor(rep(c("a", "b"), n / 2L)))
	y <- sin(seq_len(n))

	make_pair <- function(factory) {
		lazy <- factory()
		eager <- factory()
		lazy$add_all_subjects_to_experiment(X)
		eager$add_all_subjects_to_experiment(X)

		lazy_priv <- lazy$.__enclos_env__$private
		expect_true(isTRUE(lazy_priv$model_matrix_stale))
		expect_null(lazy_priv$X)
		expect_null(lazy_priv$Ximp)

		# Reproduce the pre-change timing for the comparison object.
		eager_X <- eager$get_X()
		expect_false(isTRUE(eager$.__enclos_env__$private$model_matrix_stale))
		lazy$assign_w_to_all_subjects()
		eager$assign_w_to_all_subjects()
		expect_identical(lazy$get_w(), eager$get_w())
		expect_identical(lazy$get_X(), eager_X)
		expect_identical(lazy$get_X_imp(), eager$get_X_imp())

		lazy$add_all_subject_responses(y)
		eager$add_all_subject_responses(y)
		list(lazy = lazy, eager = eager)
	}

	pairs <- list(
		make_pair(function() DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = 91L)),
		make_pair(function() DesignFixediBCRD$new(n = n, response_type = "continuous", seed = 92L)),
		make_pair(function() DesignFixedBlocking$new(
			n = n, response_type = "continuous", strata_cols = "z",
			B_target = 2L, equal_block_sizes = TRUE, seed = 93L
		))
	)
	for (p in pairs) {
		fit_lazy <- InferenceContinOLS$new(p$lazy)
		fit_eager <- InferenceContinOLS$new(p$eager)
		expect_identical(fit_lazy$compute_estimate(), fit_eager$compute_estimate())
	}
})

test_that("design version stamps use the session cache without changing the public value", {
	des <- DesignFixedBernoulli$new(n = 4L, response_type = "continuous")
	expect_identical(des$get_edi_version_created(), as.character(utils::packageVersion("EDI")))
	expect_identical(EDI:::edi_env$package_version, des$get_edi_version_created())
})

test_that("drop_column removes exactly the columns with missing values, then constant columns leave the model matrix", {
	priv <- run_build(miss_design("drop_column"))
	expect_equal(names(priv$Ximp), c("b", "cc"))
	expect_false(anyNA(priv$Ximp))
	expect_equal(colnames(priv$X), "b")
	expect_equal(unname(priv$X[, "b"]), miss_covariates()$b, tolerance = 1e-12)
})

test_that("impute fills every NA, preserves observed values, and drops constant columns from the model matrix", {
	X <- miss_covariates()
	priv <- run_build(miss_design("impute", indicators = FALSE))
	expect_equal(names(priv$Ximp), c("a", "b", "cc", "d"))
	expect_false(anyNA(priv$Ximp))
	obs_a <- !is.na(X$a)
	expect_equal(priv$Ximp$a[obs_a], X$a[obs_a], tolerance = 1e-12)
	expect_equal(priv$Ximp$b, X$b, tolerance = 1e-12)
	obs_d <- !is.na(X$d)
	expect_equal(as.character(priv$Ximp$d[obs_d]), X$d[obs_d])
	expect_true(as.character(priv$Ximp$d[4]) %in% c("u", "v"))
	# Constant column `cc` stays in Ximp but is dropped from the numeric model
	# matrix; the two-level factor `d` becomes a single dummy column.
	expect_equal(colnames(priv$X), c("a", "b", "dv"))
	expect_equal(nrow(priv$X), nrow(X))
	expect_true(all(priv$X[, "dv"] %in% c(0, 1)))
})

test_that("missingness indicators are added only for columns that had missing values", {
	X <- miss_covariates()
	priv <- run_build(miss_design("impute", indicators = TRUE))
	expect_true(all(c("a_is_missing", "d_is_missing") %in% names(priv$Ximp)))
	expect_false(any(c("b_is_missing", "cc_is_missing") %in% names(priv$Ximp)))
	expect_equal(as.integer(priv$Ximp$a_is_missing), as.integer(is.na(X$a)))
	expect_equal(as.integer(priv$Ximp$d_is_missing), as.integer(is.na(X$d)))
	expect_true(all(c("a_is_missing", "d_is_missing") %in% colnames(priv$X)))
})

test_that("with no missing values the imputation path is skipped and Ximp equals the raw covariates", {
	X <- miss_covariates()
	X$a[is.na(X$a)] <- 0
	X$d[is.na(X$d)] <- "u"
	priv <- run_build(miss_design("impute", indicators = TRUE, X = X))
	expect_equal(as.data.frame(priv$Ximp), as.data.frame(priv$Xraw), ignore_attr = TRUE)
	expect_false(any(grepl("_is_missing", names(priv$Ximp))))
	expect_equal(colnames(priv$X), c("a", "b", "dv"))
})

test_that("compute_all_subject_data caches the matrix work per t but always returns fresh w and y slices", {
	set.seed(9)
	n <- 12L
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n), x2 = rnorm(n)))
	des$assign_w_to_all_subjects()
	y <- rnorm(n)
	des$add_all_subject_responses(y)
	priv <- des$.__enclos_env__$private

	d1 <- priv$compute_all_subject_data()
	expect_equal(as.numeric(d1$w_all_with_y_scaled), as.numeric(priv$w))
	expect_equal(as.numeric(d1$y_all), y)
	expect_true(!is.null(priv$all_subject_data_cache[[as.character(priv$t)]]))

	# Change w and y: the cached matrices are reused, the slices are not.
	priv$w <- rev(priv$w)
	des$add_all_subject_responses(y * 10)
	d2 <- priv$compute_all_subject_data()
	expect_equal(as.numeric(d2$w_all_with_y_scaled), as.numeric(priv$w))
	expect_equal(as.numeric(d2$y_all), y * 10)
	expect_identical(d2$X_all, d1$X_all)
	expect_identical(d2$X_all_scaled, d1$X_all_scaled)
})
