# v1.0.6-TODO-108: a covariate that makes a type-appropriate transform of y an exact
# linear function of w + X (leakage) is dropped once at construction, with one
# edi_perfect_predictor_warning, and every later fit equals the fit without it. Exact
# fits driven by w alone are never dropped, and small-n saturation is skipped.
context("perfect predictor covariates dropped")

pp_design = function(response_type, n = 80L, seed = 1L, leak = TRUE, y_override = NULL) {
	set.seed(seed)
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	w = rep(c(0, 1), length.out = n)[sample.int(n)]
	eta = 0.5 * w + 0.6 * X$x1
	dead = NULL
	y = switch(response_type,
		continuous = eta + rnorm(n),
		incidence = rbinom(n, 1, plogis(eta)),
		count = rpois(n, exp(eta)),
		proportion = plogis(eta + rnorm(n, 0, 0.5)),
		ordinal = as.integer(cut(eta + rlogis(n), c(-Inf, -1, 0, 1, Inf))),
		survival = {
			t_true = exp(1 + eta + 0.5 * rnorm(n))
			cens = exp(1.5 + rnorm(n))
			dead = as.numeric(t_true <= cens)
			X$t_true_for_leak = t_true
			pmin(t_true, cens)
		}
	)
	if (!is.null(y_override)) y = y_override(w, X)
	if (leak) {
		X$leak = switch(response_type,
			continuous = 3 * y - 2,
			incidence = y,
			count = 2 * log1p(y) + 1,
			proportion = qlogis(y),
			ordinal = y,
			survival = 0.5 * log(X$t_true_for_leak) + 1
		)
	}
	X$t_true_for_leak = NULL
	des = DesignFixedBernoulli$new(n = n, response_type = response_type, verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$overwrite_all_subject_assignments(w)
	if (identical(response_type, "survival")) {
		add_all_subject_responses_seq(des, y, deads = dead)
	} else {
		des$add_all_subject_responses(y)
	}
	des
}

pp_capture = function(expr) {
	warns = list()
	val = withCallingHandlers(expr, warning = function(cnd) {
		if (inherits(cnd, "edi_perfect_predictor_warning")) warns[[length(warns) + 1L]] <<- cnd
		invokeRestart("muffleWarning")
	})
	list(value = val, warns = warns)
}

pp_quiet = function(expr) suppressWarnings(expr)

pp_cases = list(
	list(type = "continuous", cls = "InferenceContinOLS"),
	list(type = "incidence", cls = "InferenceIncidLogRegr"),
	list(type = "count", cls = "InferenceCountPoisson"),
	list(type = "proportion", cls = "InferencePropFractionalLogit"),
	list(type = "ordinal", cls = "InferenceOrdinalPropOddsRegr"),
	list(type = "survival", cls = "InferenceSurvivalWeibullRegr")
)

for (cs in pp_cases) local({
	cs = cs
	test_that(paste0(cs$cls, " (", cs$type, "): a leaked column is dropped with one warning, results equal the fit without it"), {
		des = pp_design(cs$type)
		gen = get(cs$cls)
		cap = pp_capture(gen$new(des, verbose = FALSE))
		inf = cap$value
		expect_length(cap$warns, 1L)
		expect_identical(cap$warns[[1L]]$dropped, "leak")
		expect_match(conditionMessage(cap$warns[[1L]]), "leakage")
		expect_identical(colnames(inf$.__enclos_env__$private$get_X()), c("x1", "x2"))
		expect_false("leak" %in% colnames(inf$get_covariates()))
		# later fits on the same object are silent
		res = pp_capture(list(est = inf$compute_estimate(), ci = inf$compute_asymp_confidence_interval()))
		expect_length(res$warns, 0L)
		# equal to fitting without the leaked column
		ref = pp_quiet(gen$new(des, verbose = FALSE, model_formula = ~ x1 + x2))
		expect_equal(res$value$est, pp_quiet(ref$compute_estimate()), tolerance = 1e-8)
		expect_equal(res$value$ci, pp_quiet(ref$compute_asymp_confidence_interval()), tolerance = 1e-8)
	})
})

test_that("a combination leak (y = x1 + x2 + tau w) drops both columns, never w", {
	set.seed(5); n = 60L
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n), x3 = rnorm(n))
	w = rep(c(0, 1), length.out = n)
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(X$x1 + X$x2 + 2 * w)
	cap = pp_capture(InferenceContinOLS$new(des, verbose = FALSE))
	expect_length(cap$warns, 1L)
	expect_identical(cap$warns[[1L]]$dropped, c("x1", "x2"))
	expect_identical(colnames(cap$value$.__enclos_env__$private$get_X()), "x3")
})

test_that("an exact fit driven by w alone is not dropped (real treatment effect)", {
	des = pp_design("continuous", leak = FALSE, y_override = function(w, X) 1 + 2 * w)
	cap = pp_capture(InferenceContinOLS$new(des, verbose = FALSE))
	expect_length(cap$warns, 0L)
	expect_identical(colnames(cap$value$.__enclos_env__$private$get_X()), c("x1", "x2"))
	# incidence y == w (complete separation by treatment only): warn elsewhere, never drop
	des2 = pp_design("incidence", leak = FALSE, y_override = function(w, X) w)
	cap2 = pp_capture(InferenceIncidLogRegr$new(des2, verbose = FALSE))
	expect_length(cap2$warns, 0L)
	expect_identical(colnames(cap2$value$.__enclos_env__$private$get_X()), c("x1", "x2"))
})

test_that("covariate-only separation (not an exact linear relation) is not dropped", {
	des = pp_design("incidence", leak = FALSE, y_override = function(w, X) as.numeric(X$x1 > 0))
	cap = pp_capture(InferenceIncidLogRegr$new(des, verbose = FALSE))
	expect_length(cap$warns, 0L)
	expect_identical(colnames(cap$value$.__enclos_env__$private$get_X()), c("x1", "x2"))
})

test_that("small-n saturation is skipped by the residual-df guard", {
	# n = 7 with p = 3 covariates: 7 - 5 = 2 residual df < 5, so no check
	des = pp_design("continuous", n = 7L)
	cap = pp_capture(InferenceContinOLS$new(des, verbose = FALSE))
	expect_length(cap$warns, 0L)
	expect_identical(colnames(cap$value$.__enclos_env__$private$get_X()), c("x1", "x2", "leak"))
})

test_that("bootstrap workers and duplicates inherit the reduced covariates", {
	des = pp_design("continuous")
	inf = pp_quiet(InferenceContinOLS$new(des, verbose = FALSE))
	dup = inf$duplicate()
	expect_identical(colnames(dup$.__enclos_env__$private$get_X()), c("x1", "x2"))
	ref = pp_quiet(InferenceContinOLS$new(des, verbose = FALSE, model_formula = ~ x1 + x2))
	set.seed(9)
	b1 = pp_capture(inf$approximate_bootstrap_distribution_beta_hat_T(B = 41, show_progress = FALSE))
	expect_length(b1$warns, 0L)
	set.seed(9)
	b2 = pp_quiet(ref$approximate_bootstrap_distribution_beta_hat_T(B = 41, show_progress = FALSE))
	expect_equal(b1$value, b2, tolerance = 1e-8)
})

test_that("classes that ignore covariates skip the check", {
	des = pp_design("continuous")
	cap = pp_capture(InferenceAllSimpleAverageDiff$new(des, verbose = FALSE))
	expect_length(cap$warns, 0L)
})

test_that("with too few responses the check is pending and runs lazily once they arrive", {
	set.seed(11); n = 40L
	X = data.frame(x1 = rnorm(n), leak = rnorm(n))
	w = rep(c(0, 1), length.out = n)
	y_full = 2 * X$leak + w
	des = DesignSeqOneByOneBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	for (i in seq_len(n)) w[i] = des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	y_full = 2 * X$leak + w
	for (i in 1:6) des$add_one_subject_response(i, y_full[i])
	old = options(edi.run_asserts = FALSE)
	on.exit(options(old), add = TRUE)
	cap = pp_capture(InferenceContinOLS$new(des, verbose = FALSE))
	expect_length(cap$warns, 0L)
	priv = cap$value$.__enclos_env__$private
	expect_identical(priv$perfect_predictor_state, "pending")
	# no new responses: get_X() leaves the covariates alone
	expect_identical(colnames(pp_capture(priv$get_X())$value), c("x1", "leak"))
	# the responses the object fits on are now complete: the first get_X() runs the check
	priv$y = y_full
	lazy = pp_capture(priv$get_X())
	expect_length(lazy$warns, 1L)
	expect_identical(lazy$warns[[1L]]$dropped, "leak")
	expect_identical(colnames(lazy$value), "x1")
	expect_identical(priv$perfect_predictor_state, "done")
	expect_length(pp_capture(priv$get_X())$warns, 0L)
})
