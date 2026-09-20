library(testthat)
library(EDI)

# Every inference class that supports weighted (Bayesian-bootstrap) refits must leave the
# object's ordinary (unweighted) results untouched: after compute_estimate_with_bootstrap_weights()
# a subsequent compute_estimate(), standard error, asymptotic p-value and CI must equal those of a
# fresh object and of the object before the weighted call. The weighted call's own estimate and SE
# stay available through private$last_weighted_refit. Classes are discovered from each design's
# applicable_inference_class_names(), so new classes are covered automatically.

skip_classes <- function(cls) grepl("IVWC|ZeroOneInflated|Custom", cls)

build_design <- function(kind, response_type, n = 40L, seed = 11L) {
	set.seed(seed)
	x <- data.frame(x1 = rnorm(n), x2 = rnorm(n))
	des <- if (kind == "kk") DesignSeqOneByOneKK14$new(n = n, response_type = response_type, verbose = FALSE)
		else DesignFixediBCRD$new(n = n, response_type = response_type, verbose = FALSE)
	if (kind == "kk") {
		for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(x[i, , drop = FALSE])
	} else {
		des$add_all_subjects_to_experiment(x); des$assign_w_to_all_subjects()
	}
	w <- des$get_w()
	y <- switch(response_type,
		continuous = 0.5 * w + rnorm(n),
		incidence = rbinom(n, 1, plogis(-0.2 + 0.6 * w + 0.3 * x$x1)),
		count = rpois(n, exp(0.3 + 0.4 * w + 0.2 * x$x1)),
		proportion = pmin(pmax(plogis(0.2 + 0.5 * w + 0.3 * x$x1 + rnorm(n, sd = 0.5)), 0.02), 0.98),
		ordinal = as.integer(cut(0.6 * w + 0.4 * x$x1 + rlogis(n), c(-Inf, -0.6, 0.6, Inf), labels = FALSE)),
		survival = rexp(n, exp(0.4 * w + 0.2 * x$x1)))
	if (response_type == "survival") {
		d <- rbinom(n, 1, 0.8)
		des$add_all_subject_responses(ifelse(d == 1, y, NA), ifelse(d == 1, NA, y), ifelse(d == 1, NA, Inf))
	} else des$add_all_subject_responses(y)
	des
}

snapshot_unweighted <- function(inf) {
	p <- inf$.__enclos_env__$private
	est <- suppressWarnings(tryCatch(as.numeric(inf$compute_estimate()), error = function(e) NA_real_))
	pv <- suppressWarnings(tryCatch(as.numeric(inf$compute_asymp_two_sided_pval(0)), error = function(e) NA_real_))
	ci <- suppressWarnings(tryCatch(as.numeric(inf$compute_asymp_confidence_interval(0.1)), error = function(e) c(NA_real_, NA_real_)))
	list(est = est, se = as.numeric(p$cached_values$s_beta_hat_T %||% NA_real_), pv = pv, ci = ci)
}

same <- function(a, b, tol = 1e-8) isTRUE(all.equal(a, b, tolerance = tol))

check_class <- function(cls, des) {
	make <- function() suppressWarnings(tryCatch(get(cls, envir = asNamespace("EDI"))$new(des, verbose = FALSE), error = function(e) NULL))
	inf <- make(); if (is.null(inf)) return(list(status = "skip_construct"))
	if (!is.function(inf$compute_estimate_with_bootstrap_weights)) return(list(status = "skip_no_weighted"))
	base <- snapshot_unweighted(inf)
	if (!is.finite(base$est)) return(list(status = "skip_unfit"))
	p <- inf$.__enclos_env__$private
	ctx <- tryCatch(p$build_bayesian_bootstrap_context(), error = function(e) NULL)
	if (is.null(ctx)) return(list(status = "skip_context"))
	p$current_bayesian_bootstrap_context <- ctx
	set.seed(3)
	wts <- rexp(ctx$n_units) + 0.05
	weighted <- suppressWarnings(tryCatch(as.numeric(inf$compute_estimate_with_bootstrap_weights(wts, estimate_only = FALSE)), error = function(e) NA_real_))
	if (!is.finite(weighted)) return(list(status = "skip_weighted_failed"))
	after <- snapshot_unweighted(inf)
	fresh <- snapshot_unweighted(make())
	lw <- p$last_weighted_refit
	recorded <- !is.null(lw) && same(as.numeric(lw$beta_hat_T)[1L], weighted)
	ok <- same(after$est, base$est) && same(after$se, base$se) && same(after$pv, base$pv) && same(after$ci, base$ci) &&
		same(fresh$est, base$est) && recorded
	list(status = if (ok) "ok" else "leak", recorded = recorded, est_moved = !same(after$est, base$est), se_moved = !same(after$se, base$se),
		pv_moved = !same(after$pv, base$pv), weighted_differs = !same(weighted, base$est, 1e-6))
}

designs <- list(
	list(kind = "fixed", rt = "continuous"), list(kind = "fixed", rt = "incidence"), list(kind = "fixed", rt = "count"),
	list(kind = "fixed", rt = "proportion"), list(kind = "fixed", rt = "ordinal"), list(kind = "fixed", rt = "survival"),
	list(kind = "kk", rt = "continuous"), list(kind = "kk", rt = "incidence"), list(kind = "kk", rt = "count"),
	list(kind = "kk", rt = "ordinal"), list(kind = "kk", rt = "survival"))

results <- new.env()

for (d in designs) {
	test_that(paste("weighted refits leave unweighted results untouched:", d$kind, d$rt), {
		skip_on_cran()
		des <- tryCatch(build_design(d$kind, d$rt), error = function(e) NULL)
		skip_if(is.null(des), "design could not be built")
		classes <- setdiff(des$applicable_inference_class_names(), character(0))
		classes <- classes[!skip_classes(classes)]
		leaks <- character(0); checked <- 0L
		for (cls in classes) {
			r <- check_class(cls, des)
			assign(paste(d$kind, d$rt, cls), r, envir = results)
			if (identical(r$status, "ok")) checked <- checked + 1L
			if (identical(r$status, "leak")) leaks <- c(leaks, cls)
		}
		expect_gt(checked + length(leaks), 0L)
		expect_identical(leaks, character(0))
	})
}

simple_fx <- function(n = 30L, seed = 5L) {
	set.seed(seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n))); des$assign_w_to_all_subjects()
	w <- des$get_w(); des$add_all_subject_responses(0.5 * w + rnorm(n))
	inf <- InferenceAllSimpleAverageDiff$new(des); inf$num_cores <- 1L
	p <- inf$.__enclos_env__$private
	p$current_bayesian_bootstrap_context <- p$build_bayesian_bootstrap_context()
	list(inf = inf, p = p, n = n, K = p$current_bayesian_bootstrap_context$n_units)
}

test_that("the weighted call's own estimate and SE are recorded while the ordinary cache is restored", {
	f <- simple_fx()
	est <- f$inf$compute_estimate(); f$inf$compute_asymp_confidence_interval()
	se <- f$p$cached_values$s_beta_hat_T
	set.seed(2); wts <- rexp(f$K) + 0.05
	b <- f$inf$compute_estimate_with_bootstrap_weights(wts, estimate_only = FALSE)
	lw <- f$p$last_weighted_refit
	expect_equal(lw$beta_hat_T, b)
	expect_true(is.finite(lw$s_beta_hat_T) && lw$s_beta_hat_T > 0)
	expect_equal(f$p$weighted_refit_se(), lw$s_beta_hat_T)
	expect_false(isTRUE(all.equal(b, est, tolerance = 1e-6)))
	expect_equal(f$p$cached_values$beta_hat_T, est)                       # ordinary cache is back
	expect_equal(f$p$cached_values$s_beta_hat_T, se)
	expect_equal(f$inf$compute_estimate(), est)
})

test_that("duplicates carry their own isolation: a weighted call on a duplicate touches neither object's ordinary results", {
	f <- simple_fx()
	est <- f$inf$compute_estimate()
	dup <- f$inf$duplicate()
	dp <- dup$.__enclos_env__$private
	dp$current_bayesian_bootstrap_context <- f$p$current_bayesian_bootstrap_context
	set.seed(3); wts <- rexp(f$K) + 0.05
	b <- dup$compute_estimate_with_bootstrap_weights(wts, estimate_only = FALSE)
	expect_equal(dp$last_weighted_refit$beta_hat_T, b)
	expect_null(f$p$last_weighted_refit)                                  # the original never ran a weighted refit
	expect_equal(f$inf$compute_estimate(), est)
	expect_equal(dup$compute_estimate(), est)                              # duplicate's ordinary fit equals the original's
})

test_that("an error inside the weighted refit restores the cache and leaves the wrapper usable", {
	f <- simple_fx()
	est <- f$inf$compute_estimate()
	set.seed(4); wts <- rexp(f$K) + 0.05
	good <- f$p$weighted_refit_impl
	unlockBinding("weighted_refit_impl", f$p)
	f$p$weighted_refit_impl <- function(...) { f$p$cached_values$beta_hat_T <- 999; stop("boom") }
	expect_error(f$inf$compute_estimate_with_bootstrap_weights(wts), "boom")
	expect_equal(f$p$cached_values$beta_hat_T, est)
	expect_equal(f$p$weighted_refit_depth, 0L)
	f$p$weighted_refit_impl <- good
	expect_true(is.finite(f$inf$compute_estimate_with_bootstrap_weights(wts)))
	expect_equal(f$inf$compute_estimate(), est)
})

test_that("the studentized Bayesian bootstrap statistics equal a manual loop over duplicates reading last_weighted_refit", {
	f <- simple_fx()
	f$inf$compute_estimate()
	B <- 12L
	set.seed(8); got <- f$p$approximate_bayesian_bootstrap_statistics_beta_hat_T(B = B, show_progress = FALSE, require_se = TRUE, na.rm = FALSE)
	set.seed(8)
	ref_theta <- ref_se <- numeric(B)
	dup <- f$inf$duplicate(); dup$num_cores <- 1L
	for (b in seq_len(B)) {
		draw <- f$p$bayesian_bootstrap_sample_weights()
		dup$.__enclos_env__$private$current_bayesian_bootstrap_context <- draw$context
		ref_theta[b] <- dup$compute_estimate_with_bootstrap_weights(draw$subject_or_block_weights, estimate_only = FALSE)
		ref_se[b] <- dup$.__enclos_env__$private$last_weighted_refit$s_beta_hat_T
	}
	expect_equal(got$theta, ref_theta)
	expect_equal(got$se, ref_se)
	expect_true(all(is.finite(got$se) & got$se > 0))
})

test_that("a nonestimable weighted refit is reported through the worker estimate as NA without flagging the object", {
	set.seed(6); n <- 60L
	des <- DesignFixediBCRD$new(n = n, response_type = "survival", verbose = FALSE)
	x <- rnorm(n)
	des$add_all_subjects_to_experiment(data.frame(x = x)); des$assign_w_to_all_subjects()
	w <- des$get_w(); t <- rexp(n, exp(0.5 * w + 0.3 * x)); d <- rbinom(n, 1, 0.8)
	des$add_all_subject_responses(ifelse(d == 1, t, NA), ifelse(d == 1, NA, t), ifelse(d == 1, NA, Inf))
	inf <- InferenceSurvivalCoxPHRegr$new(des, verbose = FALSE); p <- inf$.__enclos_env__$private
	est <- inf$compute_estimate()
	dup <- inf$duplicate(); dp <- dup$.__enclos_env__$private
	dp$current_bayesian_bootstrap_context <- p$build_bayesian_bootstrap_context()
	dp$cox_extreme_coef_threshold <- 1e-6                                          # every weighted coefficient is "extreme"
	set.seed(7)
	dp$current_bayesian_bootstrap_subject_or_block_weights <- rexp(n) + 0.05
	expect_true(is.na(p$compute_bayesian_bootstrap_worker_estimate(list(worker = dup))))
	expect_true(dp$weighted_refit_is_nonestimable("estimate"))
	expect_identical(dp$last_weighted_refit$nonestimable_reason, "coxph_weighted_extreme_coefficients")
	expect_false(dup$is_nonestimable("any"))                                       # the ordinary cache is not flagged
	expect_false(inf$is_nonestimable("any"))
	expect_equal(inf$compute_estimate(), est)
	expect_false(dp$weighted_refit_is_nonestimable("se"))                          # stage-specific
}) 

test_that("lazy-component classes: bootstrap workers (clones) run the weighted refit against their own state", {
	set.seed(7001); n <- 150L; x <- rnorm(n)
	des <- DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x)); des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rbinom(n, 1, pmin(plogis(-1 + 0.5 * x), 0.9)))
	inf <- InferenceIncidLogBinomial$new(des, model_formula = ~x, verbose = FALSE)
	d <- inf$approximate_bayesian_bootstrap_distribution_beta_hat_T(B = 4, show_progress = FALSE, debug = TRUE)
	expect_true(all(is.finite(d$values)))
	expect_equal(lengths(d$errors), rep(0L, 4L))
	dup <- inf$duplicate()
	expect_false(identical(dup$.__enclos_env__$private$weighted_refit_impl, inf$.__enclos_env__$private$weighted_refit_impl))
})

test_that("a class that declares no cached_mod does not gain one from a weighted refit", {
	set.seed(9); n <- 60L
	des <- DesignFixediBCRD$new(n = n, response_type = "proportion", verbose = FALSE)
	x <- rnorm(n); des$add_all_subjects_to_experiment(data.frame(x = x)); des$assign_w_to_all_subjects()
	w <- des$get_w(); des$add_all_subject_responses(pmin(pmax(plogis(0.3 * w + 0.4 * x + rnorm(n, sd = 0.4)), 0.02), 0.98))
	inf <- InferencePropFractionalLogit$new(des, verbose = FALSE); p <- inf$.__enclos_env__$private
	inf$compute_estimate()
	had <- exists("cached_mod", envir = p, inherits = FALSE)
	p$current_bayesian_bootstrap_context <- p$build_bayesian_bootstrap_context()
	set.seed(3); inf$compute_estimate_with_bootstrap_weights(rexp(n) + 0.05, estimate_only = FALSE)
	expect_identical(exists("cached_mod", envir = p, inherits = FALSE), had)
	expect_true(is.list(p$last_weighted_refit$cached_values))
})
