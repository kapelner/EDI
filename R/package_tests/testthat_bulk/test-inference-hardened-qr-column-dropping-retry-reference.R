library(testthat)
library(EDI)

# Inference's private fit_with_hardened_qr_column_dropping(): the shared
# QR-rank / retry-by-dropping-columns driver behind most hardened fits. Only
# reached indirectly before. Driven here with a recording fit_fun on a real
# private env, and checked against the documented algorithm reconstructed from
# base qr(): keep = required + pivoted rank columns; on failure, drop the
# remaining columns one at a time in reverse pivot order.

harden_priv <- function(harden = TRUE, seed = 2L, n = 40L) {
	set.seed(seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rbinom(n, 1, 0.4))
	inf <- InferenceIncidLogRegr$new(des, harden = harden, verbose = FALSE)
	inf$.__enclos_env__$private
}

design_matrix <- function(collinear = FALSE, n = 30L, seed = 8L) {
	set.seed(seed)
	a <- rnorm(n); b <- rnorm(n)
	X <- cbind(`(Intercept)` = 1, treatment = rep(0:1, length.out = n), a = a, b = b, c = if (collinear) a + b else rnorm(n))
	X
}

recorder <- function(ok_after = 1L) {
	env <- new.env()
	env$calls <- list()
	fit_fun <- function(X_fit, keep) {
		env$calls[[length(env$calls) + 1L]] <- list(cols = colnames(X_fit), keep = keep)
		list(n_fit = length(env$calls))
	}
	fit_ok <- function(mod, X_fit, keep) !is.null(mod) && mod$n_fit >= ok_after
	list(env = env, fit_fun = fit_fun, fit_ok = fit_ok)
}

test_that("a full-rank design is fitted once with every column when the fit is acceptable", {
	priv <- harden_priv()
	X <- design_matrix()
	r <- recorder(1L)
	out <- priv$fit_with_hardened_qr_column_dropping(X, r$fit_fun, r$fit_ok, required_cols = 1:2)
	expect_length(r$env$calls, 1L)
	expect_equal(out$keep, 1:5)
	expect_equal(colnames(out$X), colnames(X))
	expect_equal(out$fit$n_fit, 1L)
})

test_that("a collinear column is dropped up front, following the QR pivot order, and required columns are kept", {
	priv <- harden_priv()
	X <- design_matrix(collinear = TRUE)
	qr_X <- qr(X)
	expected_keep <- sort(unique(c(1:2, qr_X$pivot[seq_len(qr_X$rank)])))
	expect_lt(length(expected_keep), 5L)

	r <- recorder(1L)
	out <- priv$fit_with_hardened_qr_column_dropping(X, r$fit_fun, r$fit_ok, required_cols = 1:2)
	expect_length(r$env$calls, 1L)
	expect_equal(out$keep, expected_keep)
	expect_equal(colnames(out$X), colnames(X)[expected_keep])
	expect_true(all(1:2 %in% out$keep))
})

test_that("failed fits retry with columns dropped in reverse pivot order until acceptable", {
	priv <- harden_priv()
	X <- design_matrix()
	qr_X <- qr(X)
	keep0 <- sort(unique(c(1:2, qr_X$pivot[seq_len(qr_X$rank)])))
	removable <- rev(setdiff(qr_X$pivot[qr_X$pivot %in% keep0], 1:2))
	expected_seq <- c(list(keep0), lapply(seq_along(removable), function(k) sort(setdiff(keep0, removable[seq_len(k)]))))

	r <- recorder(ok_after = 3L)
	out <- priv$fit_with_hardened_qr_column_dropping(X, r$fit_fun, r$fit_ok, required_cols = 1:2)
	expect_length(r$env$calls, 3L)
	for (i in 1:3) expect_equal(r$env$calls[[i]]$keep, expected_seq[[i]], info = i)
	expect_equal(out$keep, expected_seq[[3]])
	expect_equal(out$fit$n_fit, 3L)
	expect_true(all(1:2 %in% out$keep))
})

test_that("when no attempt is acceptable the last (smallest) attempt is returned and only required columns remain", {
	priv <- harden_priv()
	X <- design_matrix()
	r <- recorder(ok_after = 999L)
	out <- priv$fit_with_hardened_qr_column_dropping(X, r$fit_fun, r$fit_ok, required_cols = 1:2)
	# 1 initial attempt + one per removable column (3 non-required columns).
	expect_length(r$env$calls, 4L)
	expect_equal(out$keep, 1:2)
	expect_equal(out$fit$n_fit, 4L)
})

test_that("hardening off, or nothing removable, performs a single attempt with all columns", {
	priv <- harden_priv(harden = FALSE)
	X <- design_matrix(collinear = TRUE)
	r <- recorder(ok_after = 999L)
	out <- priv$fit_with_hardened_qr_column_dropping(X, r$fit_fun, r$fit_ok, required_cols = 1:2)
	expect_length(r$env$calls, 1L)
	expect_equal(out$keep, 1:5)

	priv2 <- harden_priv(harden = TRUE)
	r2 <- recorder(ok_after = 999L)
	out2 <- priv2$fit_with_hardened_qr_column_dropping(X[, 1:2], r2$fit_fun, r2$fit_ok, required_cols = 1:2)
	expect_length(r2$env$calls, 1L)
	expect_equal(out2$keep, 1:2)
})

test_that("fit_fun receives keep only when it declares that argument, and thrown errors become a NULL fit", {
	priv <- harden_priv()
	X <- design_matrix()
	seen <- NULL
	out <- priv$fit_with_hardened_qr_column_dropping(
		X, function(X_fit) { seen <<- colnames(X_fit); list(ok = TRUE) },
		function(mod, X_fit, keep) TRUE, required_cols = 1L
	)
	expect_equal(seen, colnames(X))
	expect_true(out$fit$ok)

	out_dots <- priv$fit_with_hardened_qr_column_dropping(
		X, function(X_fit, ...) list(dots = length(list(...))),
		function(mod, X_fit, keep) TRUE, required_cols = 1L
	)
	expect_equal(out_dots$fit$dots, 1L)

	out_err <- priv$fit_with_hardened_qr_column_dropping(
		X, function(X_fit, keep) stop("boom"), function(mod, X_fit, keep) FALSE, required_cols = 1:2
	)
	expect_null(out_err$fit)
	expect_equal(out_err$keep, 1:2)
})

test_that("degenerate inputs: zero-column and vector designs, and out-of-range required columns are ignored", {
	priv <- harden_priv()
	out0 <- priv$fit_with_hardened_qr_column_dropping(matrix(0, 5, 0), function(X_fit) "fitted", function(...) TRUE)
	expect_equal(out0$fit, "fitted")
	expect_equal(out0$keep, integer())

	out_vec <- priv$fit_with_hardened_qr_column_dropping(1:6, function(X_fit) dim(X_fit), function(...) TRUE)
	expect_equal(out_vec$fit, c(6L, 1L))
	expect_equal(out_vec$keep, 1L)

	X <- design_matrix()
	r <- recorder(1L)
	out <- priv$fit_with_hardened_qr_column_dropping(X, r$fit_fun, r$fit_ok, required_cols = c(2L, 99L, 0L, NA, 2L))
	expect_true(2L %in% out$keep)
	expect_true(all(out$keep <= ncol(X)))
})

# Evaluate only the checked-out helper definition, not the checkout package.
# This keeps the regression executable without pkgload/load_all or a native build.
checkout_hardened_fit_helper <- function(){
	source_candidates = c(
		file.path("R", "EDI", "R", "inference_all_abstract.R"),
		file.path("..", "..", "EDI", "R", "inference_all_abstract.R")
	)
	source_file = source_candidates[file.exists(source_candidates)][1L]
	if (is.na(source_file)) stop("Could not locate checkout inference source")
	source_lines = readLines(source_file, warn = FALSE)
	start_line = grep("^\\s*fit_with_hardened_qr_column_dropping\\s*=\\s*function\\s*\\(", source_lines)
	if (!length(start_line)) stop("Could not locate checkout fit helper")
	definition = NULL
	partial = character()
	for (line in source_lines[seq.int(start_line[1L], length(source_lines))]) {
		partial = c(partial, line)
		parsed = tryCatch(parse(text = partial), error = function(e) NULL)
		if (length(parsed) == 1L) {
			assignment = parsed[[1L]]
			if (is.call(assignment) && identical(assignment[[1L]], as.name("=")) &&
					identical(assignment[[2L]], as.name("fit_with_hardened_qr_column_dropping"))) {
				definition = assignment[[3L]]
				break
			}
		}
	}
	if (is.null(definition)) stop("Could not locate checkout fit helper")
	eval_env = new.env(parent = baseenv())
	eval_env$private = new.env(parent = emptyenv())
	eval_env$private$harden = TRUE
	eval_env$qr_calls = 0L
	eval_env$qr = function(...) {
		eval_env$qr_calls = eval_env$qr_calls + 1L
		base::qr(...)
	}
	eval(definition, envir = eval_env)
}

test_that("a checked-out rank certificate avoids the duplicate helper QR", {
	fit_helper = checkout_hardened_fit_helper()
	X = design_matrix(collinear = FALSE)
	priv = environment(fit_helper)$private
	priv$bootstrap_qr_rank_certificate = list(mode = "unweighted", X = X)
	priv$bootstrap_qr_positive_weights = FALSE
	fit_count = 0L
	out = fit_helper(
		X,
		function(X_fit, keep) { fit_count <<- fit_count + 1L; list(ok = TRUE) },
		function(mod, X_fit, keep) isTRUE(mod$ok),
		required_cols = 1:2
	)
	expect_equal(fit_count, 1L)
	expect_equal(environment(fit_helper)$qr_calls, 0L)
	expect_equal(out$keep, seq_len(ncol(X)))
})

test_that("a failed certified fit retains the hardened rank-deficient fallback", {
	fit_helper = checkout_hardened_fit_helper()
	X = design_matrix(collinear = FALSE)
	priv = environment(fit_helper)$private
	priv$bootstrap_qr_rank_certificate = list(mode = "unweighted", X = X)
	priv$bootstrap_qr_positive_weights = FALSE
	fit_count = 0L
	out = fit_helper(
		X,
		function(X_fit, keep) { fit_count <<- fit_count + 1L; list(ok = fit_count > 1L) },
		function(mod, X_fit, keep) isTRUE(mod$ok),
		required_cols = 1:2
	)
	expect_equal(fit_count, 2L)
	expect_equal(environment(fit_helper)$qr_calls, 1L)
	expect_equal(out$keep, seq_len(ncol(X)))

	X_deficient = design_matrix(collinear = TRUE)
	# A stale certificate from another matrix must not suppress this QR/fallback.
	priv$bootstrap_qr_rank_certificate = list(mode = "unweighted", X = X)
	out_deficient = fit_helper(
		X_deficient,
		function(X_fit, keep) list(ok = TRUE),
		function(mod, X_fit, keep) isTRUE(mod$ok),
		required_cols = 1:2
	)
	expect_lt(length(out_deficient$keep), ncol(X_deficient))
	expect_true(environment(fit_helper)$qr_calls >= 2L)
})

test_that("strictly positive bootstrap weights use one rank QR and preserve the lm.wfit solution", {
	fit_helper = checkout_hardened_fit_helper()
	X = design_matrix(collinear = FALSE)
	y = as.numeric(0.8 * X[, 1L] - 0.35 * X[, 2L] + 0.7 * X[, 3L] + sin(seq_len(nrow(X))))
	weights = seq(0.4, 1.6, length.out = nrow(X))
	stopifnot(all(weights > 0))
	ref = stats::lm.wfit(x = X, y = y, w = weights)
	fit_count = 0L
	fit_fun = function(X_fit, keep) {
		fit_count <<- fit_count + 1L
		WX = sweep(X_fit, 1L, weights, `*`)
		list(coefficients = as.numeric(solve(crossprod(X_fit, WX), crossprod(X_fit, weights * y))), ok = TRUE)
	}
	priv = environment(fit_helper)$private
	priv$bootstrap_qr_rank_certificate = NULL
	priv$bootstrap_qr_positive_weights = TRUE
	out = fit_helper(
		X, fit_fun,
		function(mod, X_fit, keep) isTRUE(mod$ok) && all(is.finite(mod$coefficients)),
		required_cols = 1:2
	)

	# The helper's QR wrapper counts only its own rank check; lm.wfit above is
	# the independent weighted-least-squares reference for the preserved fit.
	expect_equal(environment(fit_helper)$qr_calls, 1L)
	expect_equal(fit_count, 1L)
	expect_identical(priv$bootstrap_qr_rank_certificate$mode, "weighted_positive")
	expect_identical(unname(priv$bootstrap_qr_rank_certificate$X), unname(X))
	expect_equal(out$keep, seq_len(ncol(X)))
	expect_equal(out$fit$coefficients, unname(ref$coefficients), tolerance = 1e-10)
})

test_that("an unusable positive-weight certified fit falls back through QR retries", {
	fit_helper = checkout_hardened_fit_helper()
	X = design_matrix(collinear = FALSE)
	y = as.numeric(0.2 * X[, 1L] + 0.5 * X[, 2L] - 0.6 * X[, 3L] + cos(seq_len(nrow(X))))
	weights = seq(0.7, 1.3, length.out = nrow(X))
	stopifnot(all(weights > 0))
	fit_count = 0L
	keeps = list()
	fit_fun = function(X_fit, keep) {
		fit_count <<- fit_count + 1L
		keeps[[fit_count]] <<- keep
		WX = sweep(X_fit, 1L, weights, `*`)
		coefficients = as.numeric(solve(crossprod(X_fit, WX), crossprod(X_fit, weights * y)))
		# Model an unusable first full-column attempt; the retry policy should
		# drop a non-required column and accept the next fit.
		list(coefficients = coefficients, ok = fit_count >= 3L)
	}
	priv = environment(fit_helper)$private
	priv$bootstrap_qr_rank_certificate = NULL
	priv$bootstrap_qr_positive_weights = TRUE
	out = fit_helper(
		X, fit_fun,
		function(mod, X_fit, keep) isTRUE(mod$ok) && all(is.finite(mod$coefficients)),
		required_cols = 1:2
	)
	ref = stats::lm.wfit(x = out$X, y = y, w = weights)

	expect_equal(environment(fit_helper)$qr_calls, 1L)
	expect_equal(fit_count, 3L)
	expect_equal(keeps[[1L]], seq_len(ncol(X)))
	expect_equal(keeps[[2L]], seq_len(ncol(X)))
	expect_lt(length(out$keep), ncol(X))
	expect_true(all(1:2 %in% out$keep))
	expect_equal(out$keep, keeps[[3L]])
	expect_equal(out$fit$coefficients, unname(ref$coefficients), tolerance = 1e-10)
})
