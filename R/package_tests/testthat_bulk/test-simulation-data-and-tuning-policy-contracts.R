library(testthat)
library(EDI)

test_that("simulation covariate generation honors supplied matrices and signal normalization", {
	X <- matrix(seq(-1, 1, length.out = 24), nrow = 6L, ncol = 4L)
	out <- generate_covariate_dataset(
		n = 6L, p = 4L, X_mat = X, cov_draw_method = NULL,
		cond_exp_func_model = "linear", norm_sq_beta_vec = 2
	)
	expect_s3_class(out$X, "data.table")
	expect_equal(as.matrix(out$X), `colnames<-`(X, paste0("x", 1:4)))
	beta <- seq(1, -1, length.out = 4L)
	beta <- beta * sqrt(2 / sum(beta^2))
	expect_equal(out$y_cont, as.numeric(X %*% beta))

	expect_error(generate_covariate_dataset(6L, 4L, X_mat = X), "exactly one")
	expect_error(generate_covariate_dataset(6L, 4L, X_mat = NULL, cov_draw_method = NULL), "must be non-NULL")
	expect_error(generate_covariate_dataset(6L, 4L, X_mat = X, cov_draw_method = NULL,
		cond_exp_func_model = "nonlinear"), "p >= 5")
})

test_that("latent-response transformations satisfy every response-scale contract", {
	y <- c(-2, -1, 0, 1, 2)
	expect_equal(mean(transform_cont_y_based_on_response_type(y, "continuous")), 0)
	incidence <- transform_cont_y_based_on_response_type(y, "incidence")
	expect_true(all(incidence > 0 & incidence < 1))
	proportion <- transform_cont_y_based_on_response_type(y, "proportion")
	expect_true(all(proportion > 0 & proportion < 1))
	count <- transform_cont_y_based_on_response_type(y, "count", count_min_rate = 2L, count_shift = 1)
	expect_true(all(count >= 2 & count == round(count)))
	survival <- transform_cont_y_based_on_response_type(y, "survival", survival_min_time = 0.25)
	expect_gte(min(survival), 0.25)
	ordinal <- transform_cont_y_based_on_response_type(seq_len(20), "ordinal", n_ordinal_levels = 4L)
	expect_setequal(unique(ordinal), 1:4)
	expect_error(transform_cont_y_based_on_response_type(y, "unknown"), "Unknown response_type")
})

test_that("survival event indicators map exactly onto design response bounds", {
	bounds <- EDI:::dead_to_response_bounds(c(2, 4, 6, 8), c(1, 0, 1, 0))
	expect_equal(bounds$y, c(2, NA, 6, NA))
	expect_equal(bounds$y_L, c(NA, 4, NA, 8))
	expect_equal(bounds$y_R, c(NA, Inf, NA, Inf))
})

test_that("tuning override merges preserve first-match precedence", {
	current <- c("^A$" = FALSE, "^B$" = TRUE, "^C$" = FALSE)
	new <- c("^B$" = FALSE, "^D$" = TRUE)
	expect_identical(EDI:::edi_tuning_merge_override_vector(current, new),
		c("^B$" = FALSE, "^D$" = TRUE, "^A$" = FALSE, "^C$" = FALSE))
	expect_identical(EDI:::edi_tuning_merge_override_vector(current, NULL), current)
	expect_identical(EDI:::edi_tuning_merge_override_vector(NULL, new), new)
})

test_that("per-class tuning overrides require consistent wins at every sample size", {
	dev <- function(class, n, to) list(class = class, n = n, to = to)
	deviations <- list(
		dev("Complete", 50L, TRUE), dev("Complete", 100L, TRUE),
		dev("Partial", 50L, FALSE),
		dev("Conflict", 50L, TRUE), dev("Conflict", 100L, FALSE)
	)
	out <- EDI:::edi_tuning_per_class_override_from_deviations(deviations, c(50L, 100L))
	expect_identical(out, c("^Complete$" = TRUE))
	expect_null(EDI:::edi_tuning_per_class_override_from_deviations(list(), c(50L, 100L)))
})

test_that("warm-start and parallel deviations become setter-shaped policy diffs", {
	warm <- EDI:::edi_tuning_warm_start_diff_from_deviations(
		list(jackknife = list(
			list(class = "A", n = 50L, to = TRUE),
			list(class = "A", n = 100L, to = FALSE)
		)), c(50L, 100L)
	)
	rules <- warm$jackknife$n_conditioned_overrides
	expect_identical(rules[[1]], list(pattern = "^A$", value = TRUE, n_min = 50L, n_max = 100L))
	expect_identical(rules[[2]], list(pattern = "^A$", value = FALSE, n_min = 100L, n_max = Inf))

	parallel <- EDI:::edi_tuning_parallel_diff_from_deviations(list(
		list(class = "A", response_type = "count", operation = "bootstrap", num_cores = 2L, crossover_n = 100L, rel_improvement = 0.2),
		list(class = "B", response_type = "continuous", operation = "bootstrap", num_cores = 4L, crossover_n = 200L, rel_improvement = 0.1)
	))
	expect_identical(parallel$preferred_num_cores, 2L)
	expect_length(parallel$crossover, 2L)
})

test_that("comprehensive slow-path validation rejects malformed exact keys", {
	rules <- EDI_COMPREHENSIVE_SLOW_PATHS
	rules$exact_operations <- c(rules$exact_operations, "bad-response||InferenceContinOLS||method")
	expect_error(EDI:::validate_comprehensive_slow_path_rules(rules), "Invalid comprehensive exact-operation")

	rules <- EDI_COMPREHENSIVE_SLOW_PATHS
	rules$bootstrap <- c(rules$bootstrap, rules$bootstrap[[1]])
	expect_error(EDI:::validate_comprehensive_slow_path_rules(rules), "unique nonempty strings")
})
