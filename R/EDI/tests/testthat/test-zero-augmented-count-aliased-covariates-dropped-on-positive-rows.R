# v1.0.6-TODO-195 item (2), owner decision 2026-11-19: the count-part
# coefficients of the zero-augmented count classes are learned from the rows with
# a positive count, so a count-part covariate that is aliased on those rows
# (constant there, or a linear combination of earlier columns) is not identified.
# Such columns are now dropped before fitting, as glm drops aliased columns, with
# one edi_covariate_dropped_warning naming them; before, the fit wandered along
# the flat direction (arbitrary ZIP estimate, NA standard error). The treatment is
# never dropped: when it is itself aliased the fit stays NA (v1.0.6-TODO-186).

zero_aug_alias_classes = c("InferenceCountHurdlePoisson", "InferenceCountZeroInflatedPoisson",
	"InferenceCountHurdleNegBin", "InferenceCountZeroInflatedNegBin")

zero_aug_alias_design = function(y, X, w) {
	des = DesignFixediBCRD$new(n = length(y), response_type = "count")
	des$add_all_subjects_to_experiment(X)
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(y)
	des
}

zero_aug_alias_inference = function(cls, y, X, w, count_formula, zero_formula = ~ x1) {
	args = list(zero_aug_alias_design(y, X, w), model_formula = count_formula, verbose = FALSE)
	args[[if (grepl("Hurdle", cls)) "model_formula_hurdle" else "model_formula_zero"]] = zero_formula
	do.call(get(cls)$new, args)
}

# x2 = 2 * x1 + 1 on every positive row, unrelated noise on the zero rows; the
# zero/hurdle part uses ~ x1 only, so x2 enters the count part alone.
zero_aug_alias_fixture = function() {
	set.seed(7)
	n = 30
	w = rep(c(1, 0), n / 2)
	x1 = rnorm(n)
	y = ifelse(runif(n) < 0.55, 1 + rpois(n, exp(0.4 + 0.3 * w + 0.2 * x1)), 0)
	x2 = ifelse(y > 0, 2 * x1 + 1, rnorm(n))
	list(y = y, w = w, X = data.frame(x1 = x1, x2 = x2))
}

collect_covariate_dropped_warnings = function(expr) {
	caught = list()
	value = withCallingHandlers(expr, warning = function(cnd) {
		if (inherits(cnd, "edi_covariate_dropped_warning")) caught[[length(caught) + 1L]] <<- cnd
		invokeRestart("muffleWarning")
	})
	list(value = value, warnings = caught)
}

test_that("the aliased-column helper drops covariates aliased on the positive rows and never the treatment", {
	X = cbind("(Intercept)" = 1, w = c(1, 0, 1, 0, 1, 0, 1, 0), x1 = c(0.3, -1, 2, 0.5, -0.7, 1.1, 0.2, -0.4))
	y = c(2, 1, 0, 3, 1, 0, 2, 0)
	pos = y > 0
	X_const = cbind(X, x2 = ifelse(pos, 4, c(9, 9, 1, 9, 9, 2, 9, 3)))
	res = zero_augmented_drop_aliased_count_cols(X_const, y)
	expect_identical(res$dropped, "x2")
	expect_identical(res$keep, 1:3)
	expect_identical(res$X, X_const[, 1:3])
	# a linear combination of earlier columns on the positive rows
	X_lin = cbind(X, x2 = ifelse(pos, 2 * X[, "x1"] - X[, "w"], 5))
	expect_identical(zero_augmented_drop_aliased_count_cols(X_lin, y)$dropped, "x2")
	# a covariate equal to the treatment on the positive rows is dropped, the treatment kept
	X_w = cbind(X[, 1:2], x2 = ifelse(pos, X[, "w"], 0.5), x1 = X[, "x1"])
	res_w = zero_augmented_drop_aliased_count_cols(X_w, y)
	expect_identical(res_w$dropped, "x2")
	expect_identical(colnames(res_w$X), c("(Intercept)", "w", "x1"))
	# full rank on the positive rows: X_fit returned as is
	expect_identical(zero_augmented_drop_aliased_count_cols(X, y)$X, X)
	# treatment aliased (every positive row treated): nothing dropped, left to the TODO-186 guard
	y_t = c(2, 0, 1, 0, 3, 0, 1, 0)
	X_t = cbind(X, x2 = ifelse(y_t > 0, 1, c(0, 2, 0, 3, 0, 4, 0, 5)))
	expect_identical(zero_augmented_drop_aliased_count_cols(X_t, y_t)$X, X_t)
	expect_false(zero_augmented_count_treatment_identified(X_t, y_t))
	# zero-weight rows do not count as positive rows
	wts = c(1, 1, 1, 1, 1, 1, 0, 1)
	X_wt = cbind(X, x2 = ifelse(pos & wts > 0, 4, 7))
	expect_identical(zero_augmented_drop_aliased_count_cols(X_wt, y, weights = wts)$dropped, "x2")
	expect_identical(zero_augmented_drop_aliased_count_cols(X_wt, y)$dropped, character())
})

test_that("an aliased count-part covariate is dropped, giving the fit without it on every path, with one warning", {
	fx = zero_aug_alias_fixture()
	for (cls in zero_aug_alias_classes) {
		inf = zero_aug_alias_inference(cls, fx$y, fx$X, fx$w, ~ x1 + x2)
		ref = zero_aug_alias_inference(cls, fx$y, fx$X, fx$w, ~ x1)
		first = collect_covariate_dropped_warnings(inf$compute_estimate())
		expect_length(first$warnings, 1L)
		expect_identical(first$warnings[[1L]]$dropped, "x2", info = cls)
		expect_identical(first$warnings[[1L]]$reason, "aliased_on_positive_rows", info = cls)
		expect_match(conditionMessage(first$warnings[[1L]]), "as glm does", fixed = TRUE)
		est_ref = suppressWarnings(ref$compute_estimate())
		expect_true(is.finite(first$value), info = cls)
		expect_equal(first$value, est_ref, tolerance = 1e-10, info = cls)
		expect_equal(suppressWarnings(inf$compute_asymp_confidence_interval()),
			suppressWarnings(ref$compute_asymp_confidence_interval()), tolerance = 1e-8, info = cls)
		# once per object
		expect_length(collect_covariate_dropped_warnings(inf$compute_estimate())$warnings, 0L)
		# randomization refit, nonparametric bootstrap (reusable worker), weighted bootstrap
		set.seed(1)
		perms = inf$.__enclos_env__$private$generate_permutations(10)
		rand = collect_covariate_dropped_warnings(inf$approximate_randomization_distribution_beta_hat_T(
			r = 10, permutations = perms, show_progress = FALSE))
		expect_length(rand$warnings, 0L)
		rand_ref = suppressWarnings(ref$approximate_randomization_distribution_beta_hat_T(
			r = 10, permutations = perms, show_progress = FALSE))
		expect_gt(sum(is.finite(rand$value)), 7L)
		expect_equal(rand$value, rand_ref, tolerance = 1e-8, info = cls)
		set.seed(2)
		boot = suppressWarnings(inf$approximate_bootstrap_distribution_beta_hat_T(B = 12, show_progress = FALSE))
		set.seed(2)
		boot_ref = suppressWarnings(ref$approximate_bootstrap_distribution_beta_hat_T(B = 12, show_progress = FALSE))
		expect_gt(sum(is.finite(boot)), 8L)
		expect_equal(boot, boot_ref, tolerance = 1e-8, info = cls)
		# The weighted (Bayesian-bootstrap) refit needs glmmTMB (a Suggests package, absent on
		# the hard-dependency-only valgrind / ASAN legs).
		if (requireNamespace("glmmTMB", quietly = TRUE)) {
			set.seed(3)
			bb = suppressWarnings(inf$approximate_bayesian_bootstrap_distribution_beta_hat_T(B = 6, show_progress = FALSE))
			set.seed(3)
			bb_ref = suppressWarnings(ref$approximate_bayesian_bootstrap_distribution_beta_hat_T(B = 6, show_progress = FALSE))
			expect_true(all(is.finite(bb)), info = cls)
			expect_equal(bb, bb_ref, tolerance = 1e-6, info = cls)
		}
	}
})

test_that("the reduced fit matches pscl without the aliased column", {
	skip_if_not_installed("pscl")
	fx = zero_aug_alias_fixture()
	dat = data.frame(y = fx$y, w = fx$w, fx$X)
	ref = suppressWarnings(list(
		InferenceCountHurdlePoisson = pscl::hurdle(y ~ w + x1 | w + x1, data = dat),
		InferenceCountZeroInflatedPoisson = pscl::zeroinfl(y ~ w + x1 | w + x1, data = dat),
		InferenceCountHurdleNegBin = pscl::hurdle(y ~ w + x1 | w + x1, data = dat, dist = "negbin"),
		InferenceCountZeroInflatedNegBin = pscl::zeroinfl(y ~ w + x1 | w + x1, data = dat, dist = "negbin")
	))
	for (cls in zero_aug_alias_classes) {
		est = suppressWarnings(zero_aug_alias_inference(cls, fx$y, fx$X, fx$w, ~ x1 + x2)$compute_estimate())
		expect_equal(est, unname(suppressWarnings(stats::coef(ref[[cls]]))["count_w"]), tolerance = 1e-3, info = cls)
	}
})

test_that("an aliased treatment is still non-estimable", {
	set.seed(11)
	n = 24
	w = rep(c(1, 0), n / 2)
	x1 = rnorm(n)
	# every positive count is in the treated arm; x2 is also aliased there
	y = ifelse(w == 1 & runif(n) < 0.7, 1 + rpois(n, 1.5), 0)
	x2 = ifelse(y > 0, 3, rnorm(n))
	X = data.frame(x1 = x1, x2 = x2)
	for (cls in zero_aug_alias_classes) {
		inf = zero_aug_alias_inference(cls, y, X, w, ~ x1 + x2)
		expect_true(is.na(suppressWarnings(inf$compute_estimate())), info = cls)
	}
})

test_that("full-rank data give bit-identical results to the fit without the alias step", {
	no_drop = function(X_fit, y, j_treat = 2L, weights = NULL) {
		X_fit = as.matrix(X_fit)
		list(X = X_fit, keep = seq_len(ncol(X_fit)), dropped = character())
	}
	run_all = function(cls, y, X, w) {
		inf = zero_aug_alias_inference(cls, y, X, w, ~ x1 + x2, ~ x1 + x2)
		set.seed(1)
		perms = inf$.__enclos_env__$private$generate_permutations(6)
		suppressWarnings(list(
			est = inf$compute_estimate(),
			ci = inf$compute_asymp_confidence_interval(),
			rand = inf$approximate_randomization_distribution_beta_hat_T(r = 6, permutations = perms, show_progress = FALSE),
			boot = {set.seed(2); inf$approximate_bootstrap_distribution_beta_hat_T(B = 6, show_progress = FALSE)},
			bb = {set.seed(3); inf$approximate_bayesian_bootstrap_distribution_beta_hat_T(B = 4, show_progress = FALSE)}
		))
	}
	# the mock reaches the fit paths: with it, the aliased fixture drops nothing
	fx = zero_aug_alias_fixture()
	local({
		testthat::local_mocked_bindings(zero_augmented_drop_aliased_count_cols = no_drop)
		inf = zero_aug_alias_inference("InferenceCountHurdlePoisson", fx$y, fx$X, fx$w, ~ x1 + x2)
		expect_length(collect_covariate_dropped_warnings(inf$compute_estimate())$warnings, 0L)
	})
	for (s in 1:2) {
		set.seed(100 + s)
		n = 24
		w = rep(c(1, 0), n / 2)
		X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
		y = ifelse(runif(n) < 0.6, 1 + rpois(n, exp(0.3 + 0.3 * w + 0.2 * X$x1)), 0)
		for (cls in zero_aug_alias_classes) {
			after = run_all(cls, y, X, w)
			before = local({
				testthat::local_mocked_bindings(zero_augmented_drop_aliased_count_cols = no_drop)
				run_all(cls, y, X, w)
			})
			expect_identical(after, before, info = paste(cls, s))
		}
	}
})
