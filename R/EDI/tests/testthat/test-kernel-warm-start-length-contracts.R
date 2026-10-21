library(testthat)
library(EDI)

# This file protects direct callers of the exported native kernels.  R6
# callers obtain starts through get_fit_warm_start_for_length(), but a short
# direct warm start used to resize an Eigen vector and could corrupt memory.

set.seed(105)
n <- 30L
X <- cbind(1, rnorm(n), rnorm(n))
y_binary <- rbinom(n, 1, plogis(X[, 2] + 0.1 * X[, 3]))
y_count <- rpois(n, exp(0.2 + 0.1 * X[, 2] - 0.1 * X[, 3]))
y_prop <- pmin(pmax(rbeta(n, 2, 3), 1e-4), 1 - 1e-4)
y_time <- rexp(n)
y_dead <- rbinom(n, 1, 0.7)
y_ordinal <- as.integer(cut(seq_len(n), breaks = 3L, labels = FALSE))
group_id <- rep(seq_len(n / 3L), each = 3L)
pair_group_id <- rep(seq_len(n / 2L), each = 2L)
yT_pair <- rep(c(0, 1), length.out = n / 2L)
n_pair <- rep(1, n / 2L)
X_diff_pair <- X[seq_len(n / 2L), 2:3, drop = FALSE]
y_reservoir <- y_count[seq_len(n / 2L)]
w_reservoir <- rep(c(0, 1), length.out = n / 2L)
X_reservoir <- X[seq_len(n / 2L), 2:3, drop = FALSE]

bad_beta_starts <- list(
	numeric(1),
	numeric(ncol(X) - 1L),
	numeric(ncol(X) + 1L)
)

bad_beta_calls <- list(
	fast_adjacent_category_logit_cpp = function(b) fast_adjacent_category_logit_cpp(X, y_ordinal, warm_start_beta = b),
	fast_adjacent_category_logit_with_var_cpp = function(b) fast_adjacent_category_logit_with_var_cpp(X, y_ordinal, warm_start_beta = b),
	fast_beta_regression_weighted_cpp = function(b) fast_beta_regression_weighted_cpp(X, y_prop, rep(1, n), warm_start_beta = b),
	fast_beta_regression_with_var_cpp = function(b) fast_beta_regression_with_var_cpp(X, y_prop, warm_start_beta = b),
	fast_continuation_ratio_regression_cpp = function(b) fast_continuation_ratio_regression_cpp(X, y_ordinal, warm_start_beta = b),
	fast_continuation_ratio_regression_weighted_cpp = function(b) EDI:::fast_continuation_ratio_regression_weighted_cpp(X, y_ordinal, rep(1, n), warm_start_beta = b),
	fast_continuation_ratio_regression_with_var_cpp = function(b) fast_continuation_ratio_regression_with_var_cpp(X, y_ordinal, warm_start_beta = b),
	fast_log_binomial_regression_cpp = function(b) fast_log_binomial_regression_cpp(X, y_binary, warm_start_beta = b),
	fast_log_binomial_regression_weighted_cpp = function(b) fast_log_binomial_regression_weighted_cpp(X, y_binary, rep(1, n), warm_start_beta = b),
	fast_log_binomial_regression_with_var_cpp = function(b) fast_log_binomial_regression_with_var_cpp(X, y_binary, warm_start_beta = b),
	fast_identity_binomial_regression_cpp = function(b) fast_identity_binomial_regression_cpp(X, y_binary, warm_start_beta = b),
	fast_identity_binomial_regression_weighted_cpp = function(b) fast_identity_binomial_regression_weighted_cpp(X, y_binary, rep(1, n), warm_start_beta = b),
	fast_identity_binomial_regression_with_var_cpp = function(b) fast_identity_binomial_regression_with_var_cpp(X, y_binary, warm_start_beta = b),
	fast_logistic_regression_weighted_cpp = function(b) fast_logistic_regression_weighted_cpp(X, y_binary, rep(1, n), warm_start_beta = b),
	fast_logistic_regression_with_var_cpp = function(b) fast_logistic_regression_with_var_cpp(X, y_binary, warm_start_beta = b),
	fast_poisson_regression_weighted_cpp = function(b) fast_poisson_regression_weighted_cpp(X, y_count, rep(1, n), warm_start_beta = b),
	fast_poisson_regression_with_var_cpp = function(b) fast_poisson_regression_with_var_cpp(X, y_count, warm_start_beta = b),
	fast_quasipoisson_regression_with_var_cpp = function(b) fast_quasipoisson_regression_with_var_cpp(X, y_count, warm_start_beta = b),
	fast_probit_regression_cpp = function(b) fast_probit_regression_cpp(X, y_binary, warm_start_beta = b),
	fast_probit_regression_weighted_cpp = function(b) EDI:::fast_probit_regression_weighted_cpp(X, y_binary, rep(1, n), warm_start_beta = b),
	fast_probit_regression_with_var_cpp = function(b) fast_probit_regression_with_var_cpp(X, y_binary, warm_start_beta = b),
	fast_gaussian_lmm_cpp = function(b) EDI:::fast_gaussian_lmm_cpp(
		X, seq_len(n) / 10, pair_group_id, warm_start_beta = b
	),
	gee_pairs_singletons_cpp = function(b) EDI:::gee_pairs_singletons_cpp(
		X, y_binary, rep(seq_len(n / 2L), each = 2L), "binomial", warm_start_beta = b
	),
	gee_pairs_singletons_weighted_cpp = function(b) EDI:::gee_pairs_singletons_weighted_cpp(
		X, y_binary, rep(seq_len(n / 2L), each = 2L), "binomial", rep(1, n), warm_start_beta = b
	),
	fast_clogit_plus_glmm_cpp = function(b) EDI:::fast_clogit_plus_glmm_cpp(
		X, y_binary, X, y_binary, group_id,
		has_discordant = TRUE, has_concordant = TRUE, warm_start_beta = b
	),
	fast_cpoisson_combined_with_var_cpp = function(b) fast_cpoisson_combined_with_var_cpp(
		yT_pair, n_pair, X_diff_pair, y_reservoir, w_reservoir, X_reservoir,
		maxit = 5L, warm_start_beta = b
	),
	fast_coxph_regression_prebuilt_cpp = function(b) EDI:::fast_coxph_regression_prebuilt_cpp(
		EDI:::build_cox_data_cache_cpp(X, y_time, y_dead), maxit = 5L, warm_start_beta = b
	),
	fast_ordinal_glmm_cpp = function(b) fast_ordinal_glmm_cpp(
		X, y_ordinal, group_id, K = 3L, j_T = 1L, warm_start_beta = b
	),
	fast_stereotype_logit_cpp = function(b) fast_stereotype_logit_cpp(X, y_ordinal, warm_start_beta = b),
	fast_stereotype_logit_with_var_cpp = function(b) fast_stereotype_logit_with_var_cpp(X, y_ordinal, warm_start_beta = b),
	fast_stereotype_profile_loglik_cpp = function(b) fast_stereotype_profile_loglik_cpp(
		X, y_ordinal, beta_fixed = 0.1, warm_start_beta = b
	),
	fast_stratified_coxph_regression_cpp = function(b) EDI:::fast_stratified_coxph_regression_cpp(
		X, y_time, y_dead, rep(seq_len(2L), each = n / 2L), warm_start_beta = b
	),
	fast_weibull_frailty_cpp = function(b) EDI:::fast_weibull_frailty_cpp(
		X, y_time, y_dead, group_id, warm_start_beta = b
	)
)

# A few combined models support both a beta-only vector and a full parameter
# vector through this legacy argument. Pick malformed lengths outside either
# accepted dimension instead of misclassifying those valid forms as errors.
bad_beta_starts_by_call <- list(
	fast_clogit_plus_glmm_cpp = list(numeric(1), numeric(2), numeric(ncol(X) + 2L)),
	fast_cpoisson_combined_with_var_cpp = list(numeric(1), numeric(2), numeric(ncol(X) + 2L))
)

test_that("adjacent GLM and ordinal exports reject malformed coefficient starts", {
	for (name in names(bad_beta_calls)) {
		starts <- if (name %in% names(bad_beta_starts_by_call)) {
			bad_beta_starts_by_call[[name]]
		} else {
			bad_beta_starts
		}
		for (start in starts) {
			expect_error(
				bad_beta_calls[[name]](start),
				"warm_start_beta must have length",
				info = name
			)
		}
	}
})

test_that("continuation-ratio validates coefficient starts for degenerate responses", {
	# With one observed ordinal level n_alpha is zero, so the augmented fit has
	# only the p covariate coefficients. The length contract still applies even
	# though the native routine returns its degenerate-fit result early.
	expect_error(
		fast_continuation_ratio_regression_cpp(
			X, rep(1L, n), warm_start_beta = numeric(ncol(X) - 1L)
		),
		"warm_start_beta must have length"
	)
})

test_that("affected exported kernels reject short and long coefficient starts", {

	for (start in bad_beta_starts) {
		expect_error(
			fast_logistic_regression_cpp(X, y_binary, warm_start_beta = start),
			"warm_start_beta must have length"
		)
		expect_error(
			fast_poisson_regression_cpp(X, y_count, warm_start_beta = start),
			"warm_start_beta must have length"
		)
		expect_error(
			fast_robust_regression_cpp(X, y_count, warm_start_beta = start),
			"warm_start_beta must have length"
		)
		expect_error(
			fast_beta_regression_cpp(X, y_prop, warm_start_beta = start),
			"warm_start_beta must have length"
		)
		expect_error(
			fast_coxph_regression_cpp(X, y_time, y_dead, warm_start_beta = start),
			"warm_start_beta must have length"
		)
	}

	# If an old regression writes past an Eigen allocation, this collection is
	# where ASAN/Valgrind detects it; with the boundary checks it is silent.
	expect_silent(gc())
})

test_that("working-weight and Fisher-information starts have the same boundary contract", {
	bad_weight_calls <- list(
		fast_logistic_regression_cpp = function(w) fast_logistic_regression_cpp(X, y_binary, warm_start_weights = w),
		fast_logistic_regression_weighted_cpp = function(w) fast_logistic_regression_weighted_cpp(X, y_binary, rep(1, n), warm_start_weights = w),
		fast_logistic_regression_with_var_cpp = function(w) fast_logistic_regression_with_var_cpp(X, y_binary, warm_start_weights = w),
		fast_poisson_regression_cpp = function(w) fast_poisson_regression_cpp(X, y_count, warm_start_weights = w),
		fast_poisson_regression_weighted_cpp = function(w) fast_poisson_regression_weighted_cpp(X, y_count, rep(1, n), warm_start_weights = w),
		fast_poisson_regression_with_var_cpp = function(w) fast_poisson_regression_with_var_cpp(X, y_count, warm_start_weights = w),
		fast_quasipoisson_regression_with_var_cpp = function(w) fast_quasipoisson_regression_with_var_cpp(X, y_count, warm_start_weights = w),
		fast_log_binomial_regression_weighted_cpp = function(w) fast_log_binomial_regression_weighted_cpp(X, y_binary, rep(1, n), warm_start_weights = w),
		fast_identity_binomial_regression_weighted_cpp = function(w) fast_identity_binomial_regression_weighted_cpp(X, y_binary, rep(1, n), warm_start_weights = w),
		fast_robust_regression_cpp = function(w) fast_robust_regression_cpp(X, y_count, warm_start_weights = w)
	)
	for (name in names(bad_weight_calls)) {
		expect_error(
			bad_weight_calls[[name]](numeric(n - 1L)),
			"warm_start_weights must have length",
			info = name
		)
	}

	# These APIs accept warm_start_weights but do not consume it: the unweighted
	# log/identity-binomial implementation does not read the optional vector, and
	# the probit wrappers document the argument as unused. Pin that no-op
	# contract rather than incorrectly requiring a length error.
	unused_weight_calls <- list(
		fast_log_binomial_regression_cpp = function(w) fast_log_binomial_regression_cpp(
			X, y_binary, maxit = 20L, warm_start_weights = w
		),
		fast_log_binomial_regression_with_var_cpp = function(w) fast_log_binomial_regression_with_var_cpp(
			X, y_binary, j = 2L, maxit = 20L, warm_start_weights = w
		),
		fast_identity_binomial_regression_cpp = function(w) fast_identity_binomial_regression_cpp(
			X, y_binary, maxit = 20L, warm_start_weights = w
		),
		fast_identity_binomial_regression_with_var_cpp = function(w) fast_identity_binomial_regression_with_var_cpp(
			X, y_binary, j = 2L, maxit = 20L, warm_start_weights = w
		),
		fast_probit_regression_cpp = function(w) fast_probit_regression_cpp(
			X, y_binary, maxit = 20L, warm_start_weights = w
		),
		fast_probit_regression_weighted_cpp = function(w) EDI:::fast_probit_regression_weighted_cpp(
			X, y_binary, rep(1, n), maxit = 20L, warm_start_weights = w
		),
		fast_probit_regression_with_var_cpp = function(w) fast_probit_regression_with_var_cpp(
			X, y_binary, j = 2L, warm_start_weights = w
		)
	)
	for (name in names(unused_weight_calls)) {
		expect_identical(
			unused_weight_calls[[name]](numeric(n - 1L)),
			unused_weight_calls[[name]](NULL),
			info = name
		)
	}

	for (fun in list(
		function() fast_logistic_regression_cpp(X, y_binary, warm_start_fisher_info = diag(1, 1L)),
		function() fast_poisson_regression_cpp(
			X, y_count, warm_start_fisher_info = diag(1, ncol(X) + 1L)
		),
		function() fast_robust_regression_cpp(X, y_count, warm_start_fisher_info = diag(1, 1L)),
		function() fast_beta_regression_cpp(X, y_prop, warm_start_fisher_info = diag(1, ncol(X))),
		function() fast_coxph_regression_cpp(X, y_time, y_dead, warm_start_fisher_info = diag(1, 1L)),
		function() fast_coxph_regression_cpp(
			X, y_time, y_dead, optimization_alg = "lbfgs",
			warm_start_fisher_info = diag(1, 1L)
		)
	)) {
		expect_error(fun(), "warm_start_fisher_info must have dimensions")
	}
})

test_that("remaining exported kernels reject malformed Fisher-information dimensions", {
	bad_fisher <- diag(1, 1L)
	y_count_positive <- pmax(1L, as.integer(y_count))
	y_exact <- seq_len(n) / 10 + 1
	y_lower <- rep(NA_real_, n)
	y_upper <- rep(NA_real_, n)
	pair_idx <- matrix(integer(), nrow = 0L, ncol = 2L)
	singleton_rows <- seq_len(n) - 1L

	bad_calls <- list(
		function() fast_ordinal_cauchit_regression_cpp(X, y_ordinal, warm_start_fisher_info = bad_fisher),
		function() fast_stereotype_logit_cpp(X, y_ordinal, warm_start_fisher_info = bad_fisher),
		function() fast_continuation_ratio_regression_cpp(X, y_ordinal, warm_start_fisher_info = bad_fisher),
		function() fast_adjacent_category_logit_cpp(X, y_ordinal, warm_start_fisher_info = bad_fisher),
		function() fast_weibull_regression_cpp(X, y_time, y_dead, warm_start_fisher_info = bad_fisher),
		function() fast_weibull_regression_general_cpp(
			X, y_exact, y_lower, y_upper, warm_start_fisher_info = bad_fisher
		),
		function() fast_ordinal_probit_regression_cpp(X, y_ordinal, warm_start_fisher_info = bad_fisher),
		function() EDI:::fast_ordinal_clmm_cpp(
			X, y_ordinal, group_id, K = 3L, j_T = 1L,
			warm_start_fisher_info = bad_fisher
		),
		function() fast_ordinal_regression_cpp(X, y_ordinal, warm_start_fisher_info = bad_fisher),
		function() fast_zinb_cpp(X, X, y_count, warm_start_fisher_info = bad_fisher),
		function() EDI:::fast_clogit_plus_glmm_cpp(
			X, y_binary, X, y_binary, group_id,
			has_discordant = TRUE, has_concordant = TRUE,
			warm_start_fisher_info = bad_fisher
		),
		function() EDI:::fast_clayton_weibull_aft_optim_cpp(
			X, y_time, y_dead, pair_idx, singleton_rows,
			warm_start_params = numeric(ncol(X) + 2L),
			warm_start_fisher_info = bad_fisher
		),
		function() EDI:::fast_dep_cens_transform_optim_cpp(
			X, y_time, y_dead, warm_start_fisher_info = bad_fisher
		),
		function() fast_neg_bin_cpp(X, y_count, warm_start_fisher_info = bad_fisher)
	)

	for (call in bad_calls) {
		expect_error(call(), "warm_start_fisher_info")
	}

	additional_bad_fisher_calls <- list(
		fast_adjacent_category_logit_with_var_cpp = function() fast_adjacent_category_logit_with_var_cpp(
			X, y_ordinal, warm_start_fisher_info = bad_fisher
		),
		fast_beta_regression_weighted_cpp = function() fast_beta_regression_weighted_cpp(
			X, y_prop, rep(1, n), warm_start_fisher_info = bad_fisher
		),
		fast_beta_regression_with_var_cpp = function() fast_beta_regression_with_var_cpp(
			X, y_prop, warm_start_fisher_info = bad_fisher
		),
		fast_coxph_regression_prebuilt_cpp = function() EDI:::fast_coxph_regression_prebuilt_cpp(
			EDI:::build_cox_data_cache_cpp(X, y_time, y_dead),
			warm_start_fisher_info = bad_fisher
		),
		fast_stratified_coxph_regression_cpp = function() EDI:::fast_stratified_coxph_regression_cpp(
			X, y_time, y_dead, rep(seq_len(2L), each = n / 2L),
			warm_start_fisher_info = bad_fisher
		),
		fast_cpoisson_combined_with_var_cpp = function() fast_cpoisson_combined_with_var_cpp(
			yT_pair, n_pair, X_diff_pair, y_reservoir, w_reservoir, X_reservoir,
			maxit = 5L, warm_start_fisher_info = bad_fisher
		),
		fast_gaussian_lmm_cpp = function() EDI:::fast_gaussian_lmm_cpp(
			X, seq_len(n) / 10, pair_group_id,
			warm_start_fisher_info = bad_fisher
		),
		fast_log_binomial_regression_cpp = function() fast_log_binomial_regression_cpp(
			X, y_binary, warm_start_fisher_info = bad_fisher
		),
		fast_log_binomial_regression_with_var_cpp = function() fast_log_binomial_regression_with_var_cpp(
			X, y_binary, j = 2L, warm_start_fisher_info = bad_fisher
		),
		fast_identity_binomial_regression_cpp = function() fast_identity_binomial_regression_cpp(
			X, y_binary, warm_start_fisher_info = bad_fisher
		),
		fast_identity_binomial_regression_with_var_cpp = function() fast_identity_binomial_regression_with_var_cpp(
			X, y_binary, j = 2L, warm_start_fisher_info = bad_fisher
		),
		fast_hurdle_negbin_cpp = function() EDI:::fast_hurdle_negbin_cpp(
			X, y_count, X, warm_start_fisher_info = bad_fisher
		),
		fast_hurdle_negbin_with_var_cpp = function() fast_hurdle_negbin_with_var_cpp(
			X, y_count, X, j = 2L, warm_start_fisher_info = bad_fisher
		),
		fast_truncated_negbin_count_cpp = function() EDI:::fast_truncated_negbin_count_cpp(
			X, y_count_positive, warm_start_fisher_info = bad_fisher
		),
		fast_hurdle_poisson_glmm_cpp = function() EDI:::fast_hurdle_poisson_glmm_cpp(
			X, y_count, as.integer(group_id), j_T = 1L,
			warm_start_fisher_info = bad_fisher
		),
		fast_logistic_glmm_cpp = function() EDI:::fast_logistic_glmm_cpp(
			X, y_binary, as.integer(group_id), j_T = 1L,
			warm_start_fisher_info = bad_fisher
		),
		fast_logistic_regression_weighted_cpp = function() fast_logistic_regression_weighted_cpp(
			X, y_binary, rep(1, n), warm_start_fisher_info = bad_fisher
		),
		fast_logistic_regression_with_var_cpp = function() fast_logistic_regression_with_var_cpp(
			X, y_binary, j = 2L, warm_start_fisher_info = bad_fisher
		),
		fast_continuation_ratio_regression_weighted_cpp = function() EDI:::fast_continuation_ratio_regression_weighted_cpp(
			X, y_ordinal, rep(1, n), warm_start_fisher_info = bad_fisher
		),
		fast_continuation_ratio_regression_with_var_cpp = function() fast_continuation_ratio_regression_with_var_cpp(
			X, y_ordinal, warm_start_fisher_info = bad_fisher
		),
		fast_neg_bin_with_var_cpp = function() fast_neg_bin_with_var_cpp(
			X, y_count, warm_start_fisher_info = bad_fisher
		),
		fast_neg_bin_weighted_cpp = function() fast_neg_bin_weighted_cpp(
			X, y_count, rep(1, n), warm_start_fisher_info = bad_fisher
		),
		fast_ordinal_cauchit_regression_with_var_cpp = function() fast_ordinal_cauchit_regression_with_var_cpp(
			X, y_ordinal, warm_start_fisher_info = bad_fisher
		),
		fast_ordinal_cloglog_regression_cpp = function() fast_ordinal_cloglog_regression_cpp(
			X, y_ordinal, warm_start_fisher_info = bad_fisher
		),
		fast_ordinal_cloglog_regression_with_var_cpp = function() fast_ordinal_cloglog_regression_with_var_cpp(
			X, y_ordinal, warm_start_fisher_info = bad_fisher
		),
		fast_ordinal_probit_regression_with_var_cpp = function() fast_ordinal_probit_regression_with_var_cpp(
			X, y_ordinal, warm_start_fisher_info = bad_fisher
		),
		fast_probit_regression_cpp_IRLS = function() fast_probit_regression_cpp(
			X, y_binary, optimization_alg = "irls",
			warm_start_fisher_info = bad_fisher
		),
		fast_probit_regression_weighted_cpp_IRLS = function() EDI:::fast_probit_regression_weighted_cpp(
			X, y_binary, rep(1, n), optimization_alg = "irls",
			warm_start_fisher_info = bad_fisher
		),
		fast_probit_regression_with_var_cpp_IRLS = function() fast_probit_regression_with_var_cpp(
			X, y_binary, j = 2L, optimization_alg = "irls",
			warm_start_fisher_info = bad_fisher
		),
		fast_ordinal_regression_weighted_cpp = function() fast_ordinal_regression_weighted_cpp(
			X, y_ordinal, rep(1, n), warm_start_fisher_info = bad_fisher
		),
		fast_ordinal_regression_with_var_cpp = function() fast_ordinal_regression_with_var_cpp(
			X, y_ordinal, warm_start_fisher_info = bad_fisher
		),
		fast_ordinal_glmm_cpp = function() EDI:::fast_ordinal_glmm_cpp(
			X, y_ordinal, as.integer(group_id), K = 3L, j_T = 1L,
			warm_start_fisher_info = bad_fisher
		),
		fast_poisson_glmm_cpp = function() EDI:::fast_poisson_glmm_cpp(
			X, y_count, as.integer(group_id), j_T = 1L,
			warm_start_fisher_info = bad_fisher
		),
		fast_poisson_regression_weighted_cpp = function() fast_poisson_regression_weighted_cpp(
			X, y_count, rep(1, n), warm_start_fisher_info = bad_fisher
		),
		fast_poisson_regression_with_var_cpp = function() fast_poisson_regression_with_var_cpp(
			X, y_count, j = 2L, warm_start_fisher_info = bad_fisher
		),
		fast_quasipoisson_regression_with_var_cpp = function() fast_quasipoisson_regression_with_var_cpp(
			X, y_count, j = 2L, warm_start_fisher_info = bad_fisher
		),
		fast_stereotype_logit_with_var_cpp = function() fast_stereotype_logit_with_var_cpp(
			X, y_ordinal, warm_start_fisher_info = bad_fisher
		),
		fast_weibull_frailty_cpp = function() EDI:::fast_weibull_frailty_cpp(
			X, y_time, y_dead, group_id, warm_start_fisher_info = bad_fisher
		),
		fast_zero_augmented_poisson_cpp = function() fast_zero_augmented_poisson_cpp(
			X, y_count, X, is_hurdle = FALSE,
			warm_start_fisher_info = bad_fisher
		),
		fast_zero_one_inflated_beta_cpp = function() fast_zero_one_inflated_beta_cpp(
			X, X, y_prop, warm_start_fisher_info = bad_fisher
		)
	)
	for (name in names(additional_bad_fisher_calls)) {
		expect_error(
			additional_bad_fisher_calls[[name]](),
			"warm_start_fisher_info",
			info = name
		)
	}

	# GEE and constrained-binomial fits share internal implementations across
	# their weighted/unweighted or link-specific wrappers; exercise each wrapper
	# that forwards the matrix so none can silently treat a malformed supplied
	# matrix as an absent start.
	for (call in list(
		function() EDI:::gee_pairs_singletons_cpp(
			X, y_binary, rep(seq_len(n / 2L), each = 2L), "binomial",
			warm_start_fisher_info = bad_fisher
		),
		function() EDI:::gee_pairs_singletons_weighted_cpp(
			X, y_binary, rep(seq_len(n / 2L), each = 2L), "binomial", rep(1, n),
			warm_start_fisher_info = bad_fisher
		),
		function() fast_log_binomial_regression_weighted_cpp(
			X, y_binary, rep(1, n), warm_start_fisher_info = bad_fisher
		),
		function() fast_identity_binomial_regression_weighted_cpp(
			X, y_binary, rep(1, n), warm_start_fisher_info = bad_fisher
		)
	)) {
		expect_error(call(), "warm_start_fisher_info")
	}

	# The ordinary probit wrappers consume Fisher starts on IRLS, but explicitly
	# bypass them under L-BFGS. Preserve that documented no-op path separately.
	for (call in list(
		function(info) fast_probit_regression_cpp(
			X, y_binary, optimization_alg = "lbfgs", warm_start_fisher_info = info
		),
		function(info) EDI:::fast_probit_regression_weighted_cpp(
			X, y_binary, rep(1, n), optimization_alg = "lbfgs",
			warm_start_fisher_info = info
		),
		function(info) fast_probit_regression_with_var_cpp(
			X, y_binary, j = 2L, optimization_alg = "lbfgs",
			warm_start_fisher_info = info
		)
	)) {
		expect_identical(call(bad_fisher), call(NULL))
	}
})

test_that("survival and ordinal CLMM kernels reject malformed parameter starts", {
	# A wrong-length optional start previously fell through to cold-start logic
	# in these two kernels, silently ignoring the caller's supplied vector.
	# CLMM has (K - 1) thresholds + p fixed effects + one log-SD; the
	# dependent-censoring model has two p-vectors plus three scale parameters.
	expect_error(
		EDI:::fast_ordinal_clmm_cpp(
			X, y_ordinal, group_id, K = 3L, j_T = 1L,
			warm_start_params = numeric((3L - 1L) + ncol(X) + 1L - 1L)
		),
		"warm_start_params must have length"
	)
	expect_error(
		EDI:::fast_ordinal_clmm_cpp(
			X, y_ordinal, group_id, K = 3L, j_T = 1L,
			warm_start_params = numeric((3L - 1L) + ncol(X) + 1L + 1L)
		),
		"warm_start_params must have length"
	)

	expect_error(
		EDI:::fast_dep_cens_transform_optim_cpp(
			X, y_time, y_dead, warm_start_params = numeric(2L * ncol(X) + 2L)
		),
		"warm_start_params must have length"
	)
	expect_error(
		EDI:::fast_dep_cens_transform_optim_cpp(
			X, y_time, y_dead, warm_start_params = numeric(2L * ncol(X) + 4L)
		),
		"warm_start_params must have length"
	)
})

test_that("mixed-model kernels reject short and long model-parameter starts", {
	# These seven kernels previously consumed caller starts before checking their
	# dimensions, causing out-of-bounds access or silently accepting a malformed
	# vector. Keep both sides of the length contract in the shipped, fast suite;
	# every call fails at the input guard, before optimization.
	bad_param_calls <- list(
		fast_gaussian_lmm_cpp = list(
			call = function(z) EDI:::fast_gaussian_lmm_cpp(
				X, seq_len(n) / 10, pair_group_id, warm_start_params = z
			),
			n_params = ncol(X) + 2L
		),
		fast_hurdle_negbin_cpp = list(
			call = function(z) EDI:::fast_hurdle_negbin_cpp(
				X, y_count, X, warm_start_params = z
			),
			n_params = ncol(X) + 1L
		),
		fast_hurdle_poisson_glmm_cpp = list(
			call = function(z) EDI:::fast_hurdle_poisson_glmm_cpp(
				X, y_count, group_id, j_T = 1L, warm_start_params = z
			),
			n_params = ncol(X) + 1L
		),
		fast_logistic_glmm_cpp = list(
			call = function(z) EDI:::fast_logistic_glmm_cpp(
				X, y_binary, group_id, j_T = 1L, warm_start_params = z
			),
			n_params = ncol(X) + 1L
		),
		fast_ordinal_glmm_cpp = list(
			call = function(z) EDI:::fast_ordinal_glmm_cpp(
				X, y_ordinal, group_id, K = 3L, j_T = 1L,
				warm_start_params = z
			),
			n_params = (3L - 1L) + ncol(X) + 1L
		),
		fast_poisson_glmm_cpp = list(
			call = function(z) EDI:::fast_poisson_glmm_cpp(
				X, y_count, group_id, j_T = 1L, warm_start_params = z
			),
			n_params = ncol(X) + 1L
		),
		fast_weibull_frailty_cpp = list(
			call = function(z) EDI:::fast_weibull_frailty_cpp(
				X, y_time, y_dead, group_id, warm_start_params = z
			),
			n_params = ncol(X) + 2L
		)
	)

	for (name in names(bad_param_calls)) {
		case <- bad_param_calls[[name]]
		expect_error(
			case$call(numeric(case$n_params - 1L)),
			"warm_start_params must have length",
			info = paste(name, "short")
		)
		expect_error(
			case$call(numeric(case$n_params + 1L)),
			"warm_start_params must have length",
			info = paste(name, "long")
		)
		# Keep non-finite starts on the shipped sanitizer/Valgrind test path;
		# these fail at the native argument guard before fitting begins.
		for (bad_value in list(NaN, Inf)) {
			bad_start <- numeric(case$n_params)
			bad_start[[1L]] <- bad_value
			expect_error(
				case$call(bad_start),
				"warm_start_params must contain only finite values",
				info = paste(name, "non-finite", bad_value)
			)
		}
	}

	# The zero-augmented Poisson wrapper has its own public error contract for
	# malformed argument shapes; unlike optimizer failures, this guard throws.
	expect_error(
		fast_zero_augmented_poisson_cpp(
			X, y_count, X, is_hurdle = FALSE,
			warm_start_params = numeric(2L * ncol(X) - 1L)
		),
		"warm_start_params must have length"
	)
	expect_error(
		fast_zero_augmented_poisson_cpp(
			X, y_count, X, is_hurdle = FALSE,
			warm_start_params = numeric(2L * ncol(X) + 1L)
		),
		"warm_start_params must have length"
	)

	# Keep finite-value Fisher guards on the shipped sanitizer/Valgrind path.
	# Each matrix has the exact expected dimensions so the finite-value guard,
	# not a shape guard, is the behavior under test.
	bad_fisher_calls <- list(
		fast_gaussian_lmm_cpp = list(
			call = function(H) EDI:::fast_gaussian_lmm_cpp(
				X, seq_len(n) / 10, pair_group_id, warm_start_fisher_info = H
			),
			n_params = ncol(X) + 2L
		),
		fast_hurdle_negbin_cpp = list(
			call = function(H) EDI:::fast_hurdle_negbin_cpp(
				X, y_count, X, warm_start_fisher_info = H
			),
			n_params = ncol(X) + 1L
		),
		fast_hurdle_poisson_glmm_cpp = list(
			call = function(H) EDI:::fast_hurdle_poisson_glmm_cpp(
				X, y_count, group_id, j_T = 1L, warm_start_fisher_info = H
			),
			n_params = ncol(X) + 1L
		),
		fast_logistic_glmm_cpp = list(
			call = function(H) EDI:::fast_logistic_glmm_cpp(
				X, y_binary, group_id, j_T = 1L, warm_start_fisher_info = H
			),
			n_params = ncol(X) + 1L
		),
		fast_ordinal_glmm_cpp = list(
			call = function(H) EDI:::fast_ordinal_glmm_cpp(
				X, y_ordinal, group_id, K = 3L, j_T = 1L,
				warm_start_fisher_info = H
			),
			n_params = (3L - 1L) + ncol(X) + 1L
		),
		fast_poisson_glmm_cpp = list(
			call = function(H) EDI:::fast_poisson_glmm_cpp(
				X, y_count, group_id, j_T = 1L, warm_start_fisher_info = H
			),
			n_params = ncol(X) + 1L
		),
		fast_weibull_frailty_cpp = list(
			call = function(H) EDI:::fast_weibull_frailty_cpp(
				X, y_time, y_dead, group_id, warm_start_fisher_info = H
			),
			n_params = ncol(X) + 2L
		)
	)
	for (name in names(bad_fisher_calls)) {
		case <- bad_fisher_calls[[name]]
		bad_fisher <- diag(case$n_params)
		bad_fisher[[1L, 1L]] <- Inf
		expect_error(
			case$call(bad_fisher),
			"warm_start_fisher_info must contain only finite values",
			info = name
		)
	}

	# The ZAP wrapper returns a diagnostic result for native finite-value
	# failures instead of throwing, so assert its established message contract.
	bad_zap_start <- numeric(2L * ncol(X))
	bad_zap_start[[1L]] <- NaN
	zap_fit <- fast_zero_augmented_poisson_cpp(
		X, y_count, X, is_hurdle = FALSE,
		warm_start_params = bad_zap_start
	)
	expect_match(
		zap_fit$exception_message,
		"warm_start_params must contain only finite values"
	)
	bad_zap_fisher <- diag(2L * ncol(X))
	bad_zap_fisher[[1L, 1L]] <- Inf
	zap_fit <- fast_zero_augmented_poisson_cpp(
		X, y_count, X, is_hurdle = FALSE,
		warm_start_fisher_info = bad_zap_fisher
	)
	expect_match(
		zap_fit$exception_message,
		"warm_start_fisher_info must contain only finite values"
	)
})
