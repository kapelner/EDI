# v1.0.6-TODO-140 (4): the zero-augmented / hurdle count kernels did not check
# their inputs. fast_zero_augmented_poisson_cpp(X, numeric(0), ...) aborted R with
# a segfault, and a short y, an Xzi / X_hurdle / group_id with fewer rows than X,
# a params vector of the wrong length or an out-of-range j_T read past the end of
# a buffer and returned a "converged" fit of garbage. The kernels now stop() with
# a message (C++), and edi_check_count_kernel_inputs() checks the same things in
# R at the call sites, so the guard works before the C++ change is built.
#
# The C++ blocks run only on a build that has the checks (detected from the NULL-y
# message); on an older build the bad inputs below could crash the test process.

zak_X = cbind(1, c(-0.6, 0.2, 1.1, -1.3, 0.4, 0.9, -0.2, 0.05, 1.6, -0.8))
zak_y = c(0, 1, 2, 0, 3, 1, 0, 2, 1, 4)
zak_gid = rep(1:5, each = 2)

zak_kernel_has_checks = function(call) {
	msg = tryCatch({ call; "" }, error = function(e) conditionMessage(e))
	grepl("got NULL", msg, fixed = TRUE)
}

test_that("edi_check_count_kernel_inputs rejects NULL, empty and mismatched inputs", {
	expect_true(edi_check_count_kernel_inputs("k", zak_X, zak_y, zak_X))
	expect_error(edi_check_count_kernel_inputs("k", zak_X, NULL), "got NULL")
	expect_error(edi_check_count_kernel_inputs("k", zak_X, numeric(0)), "at least one row")
	expect_error(edi_check_count_kernel_inputs("k", zak_X[0, , drop = FALSE], numeric(0)), "at least one row")
	expect_error(edi_check_count_kernel_inputs("k", zak_X, zak_y[1:5]), "y has 5 entries but X has 10 rows")
	expect_error(edi_check_count_kernel_inputs("k", zak_X, zak_y, zak_X[1:4, ]), "Xzi has 4 rows")
	expect_error(edi_check_count_kernel_inputs("k", zak_X, zak_y, zak_X[1:4, ], X2_name = "X_hurdle"), "X_hurdle has 4 rows")
	expect_error(edi_check_count_kernel_inputs("k", zak_X, zak_y, group_id = zak_gid[1:3]), "group_id has 3 entries")
	expect_error(edi_check_count_kernel_inputs("k", zak_X, letters[1:10]), "numeric vector")
})

test_that("the guarded zero-augmented fit errors in R instead of reaching the kernel", {
	expect_error(fast_zero_augmented_poisson_cpp_guarded(zak_X, numeric(0), zak_X, is_hurdle = TRUE), "at least one row")
	expect_error(fast_zero_augmented_poisson_cpp_guarded(zak_X, zak_y, zak_X[1:5, ], is_hurdle = FALSE), "Xzi has 5 rows")
})

test_that("fast_zero_augmented_poisson_cpp and its derivatives stop on bad inputs", {
	skip_if_not(zak_kernel_has_checks(fast_zero_augmented_poisson_cpp(zak_X, NULL, zak_X, TRUE)),
		"needs the owner build with the v1.0.6-TODO-140 (4) kernel checks")
	for (hurdle in c(TRUE, FALSE)) {
		expect_error(fast_zero_augmented_poisson_cpp(zak_X, NULL, zak_X, hurdle), "got NULL")
		expect_error(fast_zero_augmented_poisson_cpp(zak_X, numeric(0), zak_X, hurdle), "at least one row")
		expect_error(fast_zero_augmented_poisson_cpp(zak_X[0, , drop = FALSE], numeric(0), zak_X[0, , drop = FALSE], hurdle), "at least one row")
		expect_error(fast_zero_augmented_poisson_cpp(zak_X, zak_y[1:5], zak_X, hurdle), "y has 5 entries but X has 10 rows")
		expect_error(fast_zero_augmented_poisson_cpp(zak_X, zak_y, zak_X[1:5, ], hurdle), "Xzi has 5 rows")
		expect_error(fast_zero_augmented_poisson_cpp(zak_X, -zak_y, zak_X, hurdle), "nonnegative")
	}
	expect_error(get_zero_augmented_poisson_score_cpp(zak_X, numeric(0), zak_X, rep(0, 4), TRUE), "at least one row")
	expect_error(get_zero_augmented_poisson_score_cpp(zak_X, zak_y, zak_X, c(0, 0), TRUE), "params must have length")
	expect_error(get_zero_augmented_poisson_hessian_cpp(zak_X, zak_y[1:3], zak_X, rep(0, 4), FALSE), "y has 3 entries")
	expect_error(get_zero_augmented_poisson_hessian_cpp(zak_X, zak_y, zak_X, 0, FALSE), "params must have length")
	# valid inputs are untouched
	fit = fast_zero_augmented_poisson_cpp(zak_X, zak_y, zak_X, TRUE)
	expect_true(all(is.finite(fit$params)))
})

test_that("the hurdle negative-binomial kernels stop on bad inputs", {
	skip_if_not(zak_kernel_has_checks(fast_hurdle_negbin_cpp(zak_X, NULL, zak_X)),
		"needs the owner build with the v1.0.6-TODO-140 (4) kernel checks")
	expect_error(fast_hurdle_negbin_cpp(zak_X, numeric(0), zak_X), "at least one row")
	expect_error(fast_hurdle_negbin_cpp(zak_X, zak_y, zak_X[1:4, ]), "X_hurdle has 4 rows")
	expect_error(fast_hurdle_negbin_with_var_cpp(zak_X, numeric(0), zak_X), "at least one row")
	expect_error(fast_hurdle_negbin_with_var_cpp(zak_X, zak_y, zak_X[1:4, ]), "X_hurdle has 4 rows")
	expect_error(fast_hurdle_negbin_with_var_cpp(zak_X, zak_y, zak_X, j = 5L), "j must be between")
	expect_error(fast_truncated_negbin_count_cpp(zak_X[0, , drop = FALSE], numeric(0)), "at least one row")
	expect_error(fast_truncated_negbin_count_cpp(zak_X, NULL), "got NULL")
})

test_that("fast_hurdle_poisson_glmm_cpp stops on bad inputs", {
	skip_if_not(zak_kernel_has_checks(fast_hurdle_poisson_glmm_cpp(zak_X, NULL, zak_gid, 1L)),
		"needs the owner build with the v1.0.6-TODO-140 (4) kernel checks")
	expect_error(fast_hurdle_poisson_glmm_cpp(zak_X, numeric(0), zak_gid, 1L), "at least one row")
	expect_error(fast_hurdle_poisson_glmm_cpp(zak_X, zak_y, zak_gid[1:3], 1L), "group_id has 3 entries")
	expect_error(fast_hurdle_poisson_glmm_cpp(zak_X, zak_y, zak_gid, 7L), "j_T")
	expect_error(fast_hurdle_poisson_glmm_cpp(zak_X, zak_y, zak_gid, -1L), "j_T")
})
