library(testthat)
library(EDI)

# Every fast-distribution override is exercised on the permutation object made
# by its own dispatcher, then compared with the reusable-worker implementation
# on exactly those assignments. KK OLS-IVWC uses a smaller seeded fixture so
# its treatment estimates stay finite and the parity assertion is non-vacuous.
set.seed(64064)

make_fixed <- function(type = "continuous", n = 40L) {
	d <- DesignFixediBCRD$new(n = n, response_type = type, verbose = FALSE)
	x <- data.frame(x1 = rnorm(n), x2 = runif(n))
	d$add_all_subjects_to_experiment(x)
	d$assign_w_to_all_subjects()
	w <- d$get_w()
	y <- switch(type,
		ordinal = as.integer(cut(0.7 * w + rnorm(n), breaks = c(-Inf, -0.3, 0.4, Inf), labels = FALSE)),
		proportion = pmin(0.99, pmax(0.01, plogis(-0.2 + 0.7 * w + rnorm(n, 0, 0.4)))),
		count = rpois(n, exp(0.3 * w)),
		0.5 * w + rnorm(n)
	)
	d$add_all_subject_responses(y)
	d
}

make_kk <- function(type = "continuous", n = 40L, seed = NULL) {
	if (!is.null(seed)) set.seed(seed)
	d <- DesignSeqOneByOneKK14$new(n = n, response_type = type, verbose = FALSE)
	x <- data.frame(x1 = rnorm(n), x2 = runif(n))
	for (i in seq_len(n)) d$add_one_subject_to_experiment_and_assign(x[i, , drop = FALSE])
	w <- d$get_w()
	y <- switch(type,
		ordinal = as.integer(cut(0.7 * w + rnorm(n), breaks = c(-Inf, -0.3, 0.4, Inf), labels = FALSE)),
		proportion = pmin(0.99, pmax(0.01, plogis(rnorm(n)))),
		count = rpois(n, 2),
		rnorm(n)
	)
	d$add_all_subject_responses(y)
	d
}

make_rand_custom <- function() {
	n <- 40L
	d <- DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	d$add_all_subjects_to_experiment(data.frame(x = seq_len(n)))
	d$overwrite_all_subject_assignments(rep(c(0, 1), each = n / 2L))
	d$add_all_subject_responses(seq_len(n) + rnorm(n))
	welch <- function(y, w, dead) {
		y_t <- y[w == 1]
		y_c <- y[w == 0]
		(mean(y_t) - mean(y_c)) / sqrt(var(y_t) / length(y_t) + var(y_c) / length(y_c))
	}
	InferenceRandCustom$new(d, custom_randomization_statistic_function = welch, verbose = FALSE)
}

ols_ivwc_hc2_component_reference <- function(X, y, j_treat) {
	XtX_inv <- solve(crossprod(X))
	beta <- as.numeric(XtX_inv %*% crossprod(X, y))
	resid <- as.numeric(y - X %*% beta)
	leverage <- rowSums((X %*% XtX_inv) * X)
	meat <- crossprod(X, X * (resid^2 / (1 - leverage)))
	vcov <- XtX_inv %*% meat %*% XtX_inv
	list(beta = beta[j_treat], ssq = vcov[j_treat, j_treat])
}

ols_ivwc_rand_statistic_reference <- function(y, w, m, X) {
	# Independent raw-data oracle for this fixture's estimate-only randomization
	# statistic: the same IVWC combination as the documented public point
	# estimate. Until TODO-124 the randomization refit passed estimate_only
	# through to the component fits, leaving the IVW weights undefined and the
	# statistic silently equal to the matched-only fallback; the components now
	# always compute their variances, so the two estimands agree.
	# There are 3 matched pairs and the matched OLS design has 3 columns
	# (intercept + 2 covariates), so the matched component still takes the
	# implementation's n <= p fallback: the unadjusted mean of the
	# treated-minus-control pair diffs, with var(diffs) / #pairs as its variance.
	# The reservoir component is an HC2 OLS fit on the unmatched subjects.
	y <- as.numeric(y)
	w <- as.integer(w)
	m <- as.integer(m)
	m[is.na(m)] <- 0L
	X <- as.matrix(X)
	matched_ids <- sort(unique(m[m > 0L]))
	matched_y <- numeric()
	matched_X <- matrix(numeric(), nrow = 0L, ncol = ncol(X))
	for (id in matched_ids) {
		i_t <- which(m == id & w == 1L)
		i_c <- which(m == id & w == 0L)
		if (length(i_t) == 1L && length(i_c) == 1L) {
			matched_y <- c(matched_y, y[i_t] - y[i_c])
			matched_X <- rbind(matched_X, X[i_t, , drop = FALSE] - X[i_c, , drop = FALSE])
		}
	}
	if (length(matched_y) == 0L) return(NA_real_)
	matched_design <- cbind(1, matched_X)
	if (nrow(matched_design) > ncol(matched_design) || qr(matched_design)$rank < ncol(matched_design)) {
		stop("seeded OLS-IVWC fixture no longer takes the documented fallback")
	}
	beta_matched <- mean(matched_y)
	ssq_matched <- var(matched_y) / length(matched_y)
	reservoir <- m == 0L
	res <- ols_ivwc_hc2_component_reference(
		cbind(1, w[reservoir], X[reservoir, , drop = FALSE]), y[reservoir], 2L
	)
	matched_ok <- is.finite(beta_matched) && is.finite(ssq_matched) && ssq_matched > 0
	reservoir_ok <- is.finite(res$beta) && is.finite(res$ssq) && res$ssq > 0
	if (matched_ok && reservoir_ok) {
		w_star <- res$ssq / (res$ssq + ssq_matched)
		w_star * beta_matched + (1 - w_star) * res$beta
	} else if (matched_ok) {
		beta_matched
	} else if (reservoir_ok) {
		res$beta
	} else {
		NA_real_
	}
}

cases <- list(
	SimpleAverage = list(InferenceAllSimpleAverageDiff, make_fixed()),
	Bai14 = list(InferenceBaiAdjustedTKK14, make_kk()),
	Bai21 = list(InferenceBaiAdjustedTKK21, make_kk()),
	KKMeanDiffIVWC = list(InferenceAllKKMeanDiffIVWC, make_kk()),
	KKWilcoxIVWC = list(InferenceAllKKWilcoxIVWC, make_kk()),
	SimpleWilcox = list(InferenceAllSimpleWilcox, make_fixed()),
	KKOLSIVWC = list(InferenceContinKKOLSIVWC, make_kk(n = 20L, seed = 1L)),
	KKOLSOneLik = list(InferenceContinKKOLSOneLik, make_kk()),
	KKRobustIVWC = list(InferenceContinKKRobustRegrIVWC, make_kk()),
	KKRobustOneLik = list(InferenceContinKKRobustRegrOneLik, make_kk()),
	ContinLin = list(InferenceContinLin, make_fixed()),
	ContinOLS = list(InferenceContinOLS, make_fixed()),
	ContinQuantile = list(InferenceContinQuantileRegr, make_fixed()),
	ContinRobust = list(InferenceContinRobustRegr, make_fixed()),
	CountKKHurdleIVWC = list(InferenceCountKKHurdlePoissonIVWC, make_kk("count")),
	OrdinalRidit = list(InferenceOrdinalRidit, make_fixed("ordinal")),
	PropQuantile = list(InferencePropQuantileRegr, make_fixed("proportion")),
	RandCustom = list(NULL, make_rand_custom())
)

test_that("all fast randomization paths agree with reused-worker results on 50 generated permutations", {
	results <- lapply(names(cases), function(name) {
		class_and_design <- cases[[name]]
		inf <- if (is.null(class_and_design[[1]])) class_and_design[[2]] else
			class_and_design[[1]]$new(class_and_design[[2]], verbose = FALSE)
		inf$num_cores <- 1L
		p <- inf$.__enclos_env__$private
		if (name == "KKOLSIVWC") set.seed(1L)
		perms <- p$generate_permutations(50L)
		fast <- p$compute_fast_randomization_distr(p$y, perms, 0, "none")
		worker <- p$compute_fast_randomization_distr_via_reused_worker(p$y, perms, 0, "none")
		result <- list(name = name, fast = fast, worker = worker)
		if (name == "KKOLSIVWC") {
			# KK permutation objects intentionally omit m_mat: matching structure is
			# fixed by the design. The wrapper must consequently preserve both
			# shape-keyed OLS column reductions while refreshing per-draw estimates.
			expect_null(perms$m_mat)
			expect_setequal(
				p$reused_worker_preserved_cache_keys(),
				c("kk_ols_ivwc_matched_reduced_design", "kk_ols_ivwc_reservoir_reduced_design")
			)
			w_mat <- as.matrix(perms$w_mat)
			assignment_signatures <- apply(w_mat, 2L, paste, collapse = "")
			expect_gt(length(unique(assignment_signatures)), 1L)
			expect_equal(length(unique(p$m[p$m > 0L])), 3L)
			expect_equal(ncol(p$get_X()), 2L)

			# Independent execution reference: recompute each assignment on its own
			# duplicated inference object with an empty cache, so neither the fast
			# wrapper nor a prior draw can reuse a reduction decision or estimate.
			fresh_draw_reference <- vapply(seq_len(ncol(w_mat)), function(j) {
				fresh <- inf$duplicate(verbose = FALSE)
				fresh_priv <- fresh$.__enclos_env__$private
				fresh_priv$w <- as.integer(w_mat[, j])
				fresh_priv$cached_values <- list()
				as.numeric(fresh_priv$compute_treatment_estimate_during_randomization_inference(
					estimate_only = TRUE
				))[1L]
			}, numeric(1L))
			result$fresh_draw_reference <- fresh_draw_reference
			result$formula_reference <- vapply(seq_len(ncol(w_mat)), function(j) {
				ols_ivwc_rand_statistic_reference(
					y = p$y,
					w = w_mat[, j],
					m = p$m,
					X = p$get_X()
				)
			}, numeric(1L))
		}
		result
	})

	for (result in results) {
		expect_equal(length(result$fast), 50L, info = result$name)
		expect_equal(length(result$worker), 50L, info = result$name)
		expect_equal(result$fast, result$worker, tolerance = 1e-10, info = result$name)
		expect_true(all(is.finite(result$fast)), info = result$name)
		if (result$name == "KKOLSIVWC") {
			expect_equal(result$fast, result$fresh_draw_reference, tolerance = 1e-10)
			expect_true(all(is.finite(result$fresh_draw_reference)))
			expect_true(all(is.finite(result$formula_reference)))
			expect_equal(result$fast, result$formula_reference, tolerance = 1e-8)
		}
	}
})

test_that("direct C++ calls in fast randomization methods have Rcpp wrappers", {
	# Parse the checked-out R sources and limit this source-contract audit to
	# direct `_cpp()` calls nested under each fast-distribution method.
	root <- normalizePath(getwd(), mustWork = TRUE)
	while (!file.exists(file.path(root, "R", "EDI", "R"))) {
		parent <- dirname(root)
		if (identical(parent, root)) stop("could not locate the EDI checkout from the test working directory")
		root <- parent
	}
	r_sources <- list.files(file.path(root, "R", "EDI", "R"), pattern = "\\.R$", full.names = TRUE)
	exports_path <- file.path(root, "R", "EDI", "R", "RcppExports.R")
	exports_lines <- readLines(exports_path, warn = FALSE)
	exports_exprs <- parse(file = exports_path, keep.source = FALSE)
	wrapper_lines <- grep("^[[:space:]]*[[:alnum:]_.]+_cpp[[:space:]]*<-[[:space:]]*function", exports_lines, value = TRUE)
	wrapper_names <- sub("^[[:space:]]*([[:alnum:]_.]+_cpp)[[:space:]]*<-[[:space:]]*function.*$", "\\1", wrapper_lines)

	find_call_symbols <- function(expr, call_name) {
		if (!is.call(expr)) return(character())
		out <- character()
		if (identical(expr[[1L]], as.name(call_name)) && length(expr) >= 2L && is.symbol(expr[[2L]])) {
			out <- c(out, as.character(expr[[2L]]))
		}
		for (i in seq_along(expr)) out <- c(out, find_call_symbols(expr[[i]], call_name))
		unique(out)
	}
	wrapper_native_symbols <- setNames(lapply(exports_exprs, function(expr) {
		if (!is.call(expr) || length(expr) < 3L || !identical(expr[[1L]], as.name("<-")) ||
				!is.symbol(expr[[2L]]) || !is.call(expr[[3L]]) ||
				!identical(expr[[3L]][[1L]], as.name("function"))) return(character())
		find_call_symbols(expr[[3L]], ".Call")
	}), vapply(exports_exprs, function(expr) {
		if (is.call(expr) && length(expr) >= 2L && identical(expr[[1L]], as.name("<-")) && is.symbol(expr[[2L]])) {
			as.character(expr[[2L]])
		} else ""
	}, character(1L)))

	fast_calls_for_file <- function(path) {
		pd <- getParseData(parse(file = path, keep.source = TRUE))
		if (is.null(pd)) return(character())
		method_ids <- pd$id[pd$text == "compute_fast_randomization_distr" & pd$token == "SYMBOL_SUB"]
		cpp_rows <- pd[pd$token == "SYMBOL_FUNCTION_CALL" & grepl("_cpp$", pd$text), , drop = FALSE]
		is_within <- function(id, ancestor) {
			parent_id <- pd$parent[match(id, pd$id)]
			while (length(parent_id) == 1L && !is.na(parent_id) && parent_id != 0L) {
				if (parent_id == ancestor) return(TRUE)
				parent_id <- pd$parent[match(parent_id, pd$id)]
			}
			FALSE
		}
		unique(unlist(lapply(method_ids, function(method_id) {
			method_parent <- pd$parent[match(method_id, pd$id)]
			cpp_rows$text[vapply(cpp_rows$id, is_within, logical(1), ancestor = method_parent)]
		}), use.names = FALSE))
	}
	cpp_calls <- unique(unlist(lapply(r_sources, fast_calls_for_file), use.names = FALSE))
	missing_wrappers <- setdiff(cpp_calls, wrapper_names)
	native_registration_path <- file.path(root, "R", "EDI", "src", "RcppExports.cpp")
	native_registration_lines <- readLines(native_registration_path, warn = FALSE)
	expect_true(length(cpp_calls) > 0L, info = "source scan found no direct C++ calls")
	expect_true(length(missing_wrappers) == 0L,
		info = paste("missing RcppExports wrappers:", paste(missing_wrappers, collapse = ", ")))
	for (cpp_call in cpp_calls) {
		native_symbols <- wrapper_native_symbols[[cpp_call]]
		expect_true(length(native_symbols) == 1L,
			info = paste("expected one .Call symbol in wrapper", cpp_call))
		if (length(native_symbols) == 1L) {
			registered <- grepl(
				paste0('"', native_symbols, '"[[:space:]]*,[[:space:]]*\\(DL_FUNC\\)[[:space:]]*&', native_symbols, '[[:space:]]*,'),
				native_registration_lines
			)
			expect_true(any(registered), info = paste("missing native registration for", cpp_call, "->", native_symbols))
		}
	}
})

test_that("Simple-Wilcoxon R6 p-value agrees with its kernel at n = r = 1000", {
	# This explicitly exercises the dispatcher-scale case that exposed the
	# double-to-integer kernel boundary. At this size the bulk-tier kernel is
	# practical, while a plain-R all-pairs reference would dominate the shard.
	set.seed(641001L)
	n <- 1000L
	d <- DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = 641001L, verbose = FALSE)
	d$add_all_subjects_to_experiment(data.frame(x = seq_len(n)))
	d$assign_w_to_all_subjects()
	w <- d$get_w()
	d$add_all_subject_responses(0.4 * w + rnorm(n))
	inf <- InferenceAllSimpleWilcox$new(d, verbose = FALSE)
	inf$num_cores <- 1L
	p <- inf$.__enclos_env__$private
	set.seed(641002L)
	perms <- p$generate_permutations(1000L)
	pval_r6 <- inf$compute_rand_two_sided_pval(
		r = 1000L, delta = 0, show_progress = FALSE, permutations = perms
	)
	t_obs <- inf$compute_estimate(estimate_only = TRUE)
	t_kernel <- p$compute_fast_randomization_distr(p$y, perms, 0, "none")
	n_valid <- sum(is.finite(t_kernel))
	pval_kernel <- min(1, max(2 / n_valid, 2 * min(
		sum(t_kernel >= t_obs, na.rm = TRUE) / n_valid,
		sum(t_kernel <= t_obs, na.rm = TRUE) / n_valid
	)))
	ratio <- max(pval_r6, pval_kernel) / min(pval_r6, pval_kernel)
	expect_equal(length(t_kernel), 1000L)
	expect_equal(n_valid, 1000L)
	expect_true(is.finite(pval_r6) && is.finite(pval_kernel))
	expect_equal(pval_r6, pval_kernel, tolerance = 1e-12)
	expect_lte(ratio, 1.1)
})
