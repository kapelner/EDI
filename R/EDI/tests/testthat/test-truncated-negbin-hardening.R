test_that("fast_truncated_negbin_count_cpp rejects invalid warm starts and inputs", {
	set.seed(101)
	X_cov <- matrix(rnorm(120), ncol = 2)
	X <- cbind(1, X_cov)
	lambda <- exp(0.3 + X_cov[, 1] * 0.2 - X_cov[, 2] * 0.1)
	y <- pmax(rnbinom(nrow(X), mu = lambda, size = 3), 1)

	expect_error(
		EDI:::fast_truncated_negbin_count_cpp(X, y, warm_start_params = rep(0, ncol(X))),
		"warm_start_params"
	)
	expect_error(
		EDI:::fast_truncated_negbin_count_cpp(X, y, warm_start_fisher_info = diag(ncol(X))),
		"warm_start_fisher_info"
	)
	expect_error(
		EDI:::fast_truncated_negbin_count_cpp(X, c(y[-1], 1.5)),
		"integer-valued counts"
	)
	expect_error(
		EDI:::fast_truncated_negbin_count_cpp(X, replace(y, 1, 0)),
		"positive counts"
	)
	expect_error(
		EDI:::fast_truncated_negbin_count_cpp(
			X, y,
			warm_start_params = c(rep(0, ncol(X)), 25)
		),
		"log-theta"
	)
})

test_that("fast_truncated_negbin_count_cpp survives repeated stale bootstrap-style warm starts", {
	set.seed(202)
	prev_params <- NULL
	prev_info <- NULL
	statuses <- character(40)

	for (iter in seq_along(statuses)) {
		p_cov <- sample(1:4, 1)
		n <- sample(80:120, 1)
		X_cov <- matrix(rnorm(n * p_cov), ncol = p_cov)
		X <- cbind(1, X_cov)
		beta <- c(0.4, seq(-0.2, 0.2, length.out = p_cov))
		mu <- exp(drop(X %*% beta))
		y <- pmax(rnbinom(n, mu = mu, size = runif(1, 1.5, 5)), 1)

		res <- tryCatch(
			suppressWarnings(
				EDI:::fast_truncated_negbin_count_cpp(
					X = X,
					y = y,
					warm_start_params = prev_params,
					warm_start_fisher_info = prev_info,
					estimate_only = FALSE
				)
			),
			error = function(e) e
		)

		if (inherits(res, "error")) {
			statuses[[iter]] <- "error"
			expect_match(
				conditionMessage(res),
				"warm_start_params|warm_start_fisher_info|log-theta|positive counts|integer-valued counts|compatible dimensions"
			)
			prev_params <- rnorm(sample(2:8, 1))
			prev_info <- diag(runif(sample(2:8, 1), 0.5, 2))
		} else {
			statuses[[iter]] <- "ok"
			expect_type(res$converged, "logical")
			expect_length(res$params, ncol(X) + 1L)
			prev_params <- as.numeric(res$params)
			prev_info <- as.matrix(res$fisher_information)
		}

		if (runif(1) < 0.7) {
			prev_params <- rnorm(sample(2:8, 1))
		}
		if (runif(1) < 0.7) {
			k <- sample(2:8, 1)
			prev_info <- diag(runif(k, 0.5, 2))
		}
	}

	expect_true(all(statuses %in% c("ok", "error")))
	expect_true(any(statuses == "ok"))
	expect_true(any(statuses == "error"))
})

test_that("get_hurdle_negbin_count_score_cpp/_hessian_cpp reject mismatched X/y/params instead of reading out of bounds", {
	# TODO-1 (bootstrap_calibrated_lr_report.md): unlike fast_truncated_negbin_count_cpp's
	# own entry point, these getter-style siblings never validated their inputs -- a
	# too-short `params` made TruncatedNegBinCount::operator() read past the end of the
	# Eigen::Map'd params buffer (params.head(m_p)), a heap-buffer-overflow confirmed via
	# a standalone ASan build of this exact call path. Same bug class as TODO-16's
	# get_poisson_glmm_score_cpp/_hessian_cpp fix.
	set.seed(303)
	X_cov <- matrix(rnorm(80), ncol = 2)
	X <- cbind(1, X_cov)
	lambda <- exp(0.3 + X_cov[, 1] * 0.2)
	y <- pmax(rnbinom(nrow(X), mu = lambda, size = 3), 1)
	params_ok <- c(0.3, 0.2, -0.1, log(3))

	expect_error(
		EDI:::get_hurdle_negbin_count_score_cpp(X, y[-1], params_ok),
		"Dimension mismatch"
	)
	expect_error(
		EDI:::get_hurdle_negbin_count_score_cpp(X, y, params_ok[1:2]),
		"params must have length"
	)
	expect_error(
		EDI:::get_hurdle_negbin_count_hessian_cpp(X, y[-1], params_ok),
		"Dimension mismatch"
	)
	expect_error(
		EDI:::get_hurdle_negbin_count_hessian_cpp(X, y, params_ok[1:2]),
		"params must have length"
	)

	# Valid, dimension-consistent calls still work.
	score <- EDI:::get_hurdle_negbin_count_score_cpp(X, y, params_ok)
	hess <- EDI:::get_hurdle_negbin_count_hessian_cpp(X, y, params_ok)
	expect_length(score, ncol(X) + 1)
	expect_equal(dim(hess), c(ncol(X) + 1, ncol(X) + 1))
})
