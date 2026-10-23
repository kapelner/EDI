# TODO-119 regression: the generic randomization CI inverts a logit (proportion),
# log (count) or integer-level additive (ordinal) shift. For a class whose
# estimate is a raw-scale mean difference / rank effect that returned delta
# bounds on a different scale than the estimate (harness T27, T49), so it must
# refuse rather than report them.

make_scale_mismatch_inference = function(cls, response_type, y, n = 40L) {
	des = DesignSeqOneByOneBernoulli$new(response_type = response_type, n = n, verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x = i / n))
	des$add_all_subject_responses(y)
	get(cls, envir = asNamespace("EDI"))$new(des, verbose = FALSE)
}

test_that("registry classifies raw-scale proportion/count/ordinal estimands as scale-mismatched", {
	f = EDI:::inference_randomization_ci_scale_mismatch
	expect_type(f("InferenceAllSimpleAverageDiff", "proportion", FALSE), "character")
	expect_type(f("InferenceAllSimpleAverageDiff", "count", FALSE), "character")
	expect_null(f("InferenceAllSimpleAverageDiff", "continuous", FALSE))
	expect_null(f("InferenceAllSimpleAverageDiff", "ordinal", FALSE))
	# survival: log-time shift vs a raw time-scale estimate (TODO-119 audit)
	expect_type(f("InferenceAllSimpleAverageDiff", "survival", FALSE), "character")
	expect_type(f("InferenceAllSimpleWilcox", "survival", FALSE), "character")
	expect_null(f("InferenceSurvivalWeibullRegr", "survival", FALSE))
	expect_type(f("InferencePropGCompMeanDiff", "proportion", TRUE), "character")
	expect_type(f("InferenceOrdinalRidit", "ordinal", FALSE), "character")
	expect_type(f("InferenceOrdinalJonckheereTerpstraTest", "ordinal", FALSE), "character")
	# model-scale classes whose estimand IS the shift scale stay allowed
	expect_null(f("InferenceCountPoisson", "count", TRUE))
	expect_null(f("InferencePropFractionalLogit", "proportion", TRUE))
	for (cls in EDI:::EDI_RAND_CI_SHIFT_SCALE_MISMATCH_CLASSES) {
		expect_false("randomization_ci" %in% EDI:::get_inference_class_metadata(cls)$capabilities, info = cls)
	}
})

test_that("randomization CI is refused where the shift scale differs from the estimand scale", {
	set.seed(3L)
	n = 40L
	cases = list(
		list("InferenceAllSimpleAverageDiff", "proportion", pmin(0.95, pmax(0.05, runif(n)))),
		list("InferenceAllSimpleAverageDiff", "count", rpois(n, 3)),
		list("InferencePropGCompMeanDiff", "proportion", pmin(0.95, pmax(0.05, runif(n)))),
		list("InferenceOrdinalRidit", "ordinal", sample(1:5, n, TRUE)),
		list("InferenceOrdinalJonckheereTerpstraTest", "ordinal", sample(1:5, n, TRUE))
	)
	for (cs in cases) {
		inf = make_scale_mismatch_inference(cs[[1]], cs[[2]], cs[[3]])
		expect_error(
			inf$compute_rand_confidence_interval(r = 51, show_progress = FALSE),
			"not supported for", info = paste(cs[[1]], cs[[2]])
		)
		# the randomization p-value stays available
		expect_true(is.finite(inf$compute_rand_two_sided_pval(r = 51, show_progress = FALSE)), info = cs[[1]])
	}
})

test_that("randomization CI for a model-scale count class contains its estimate on the estimate's scale", {
	set.seed(4L)
	n = 40L
	inf = make_scale_mismatch_inference("InferenceCountPoisson", "count", rpois(n, 3))
	ci = inf$compute_rand_confidence_interval(r = 101, show_progress = FALSE)
	est = inf$compute_estimate()
	expect_true(ci[1] <= est && est <= ci[2])
})

test_that("TODO-119 sweep: where a randomization CI is returned it contains the estimate on the estimate's scale", {
	skip_on_cran()
	set.seed(21L)
	n = 40L
	pr = pmin(0.95, pmax(0.05, runif(n)))
	cases = list(
		list("InferenceCountPoisson", "count", rpois(n, 3)),
		list("InferencePropBetaRegr", "proportion", pr),
		list("InferencePropQuantileRegr", "proportion", pr),
		list("InferencePropZeroOneInflatedBetaRegr", "proportion", pr), # interior y only; exact 0/1 is a known open issue
		list("InferenceAllSimpleAverageDiff", "ordinal", sample(1:5, n, TRUE)),
		list("InferenceSurvivalWeibullRegr", "survival", rexp(n, 0.2))
	)
	# Drop only the quantreg-backed case when quantreg is absent (sanitizer /
	# valgrind install no Suggests), so the rest of the sweep still runs there.
	if (!requireNamespace("quantreg", quietly = TRUE)) {
		cases = Filter(function(cs) cs[[1]] != "InferencePropQuantileRegr", cases)
	}
	for (cs in cases) {
		inf = make_scale_mismatch_inference(cs[[1]], cs[[2]], cs[[3]])
		est = inf$compute_estimate()
		ci = suppressWarnings(inf$compute_rand_confidence_interval(r = 51, show_progress = FALSE))
		expect_true(ci[1] <= est && est <= ci[2], info = paste(cs[[1]], cs[[2]]))
	}
	# raw time-scale survival estimands are refused, not reported on the log-time axis
	inf = make_scale_mismatch_inference("InferenceAllSimpleAverageDiff", "survival", rexp(n, 0.2))
	expect_error(inf$compute_rand_confidence_interval(r = 51, show_progress = FALSE), "not supported for")
})

# TODO-119 / G6: exact 0/1 proportions cannot be shifted on the logit scale, so the
# randomization CI is refused for logit-shift classes when any response is 0 or 1.
test_that("exact 0/1 proportions: helper is data dependent and only fires for the logit shift", {
	f = EDI:::inference_randomization_ci_exact_zero_one_refusal
	expect_true(f("proportion", TRUE, c(0, 0.3, 0.5)))
	expect_true(f("proportion", TRUE, c(0.2, 1)))
	expect_false(f("proportion", TRUE, c(0.01, 0.5, 0.99)))
	expect_false(f("proportion", FALSE, c(0, 0.5, 1)))
	expect_false(f("continuous", TRUE, c(0, 1)))
	expect_false(f("count", TRUE, c(0, 1, 2)))
})

test_that("randomization CI is refused on exact 0/1 proportions for logit-shift classes and names alternatives", {
	set.seed(7L)
	n = 40L
	y = pmin(0.95, pmax(0.05, runif(n))); y[1:3] = 0; y[4:5] = 1
	for (cls in c("InferencePropZeroOneInflatedBetaRegr", "InferencePropFractionalLogit")) {
		inf = make_scale_mismatch_inference(cls, "proportion", y)
		err = tryCatch(inf$compute_rand_confidence_interval(r = 51, show_progress = FALSE), error = function(e) e)
		expect_s3_class(err, "edi_rand_ci_exact_zero_one_refused")
		msg = conditionMessage(err)
		expect_match(msg, "exact 0 or 1", info = cls)
		expect_match(msg, "score", info = cls)
		expect_match(msg, "bartlett", ignore.case = TRUE, info = cls)
		expect_match(msg, "asymp", info = cls)
		expect_match(msg, "bootstrap", info = cls)
	}
})

test_that("randomization CI is not refused on strictly interior proportions; non-logit classes unaffected", {
	set.seed(8L)
	n = 40L
	pr = pmin(0.95, pmax(0.05, runif(n)))
	inf = make_scale_mismatch_inference("InferencePropFractionalLogit", "proportion", pr)
	ci = inf$compute_rand_confidence_interval(r = 51, show_progress = FALSE)
	expect_length(ci, 2L)
	# continuous responses with 0/1 values are not proportion responses
	yc = rnorm(n); yc[1:2] = c(0, 1)
	infc = make_scale_mismatch_inference("InferenceContinOLS", "continuous", yc)
	expect_error(infc$compute_rand_confidence_interval(r = 51, show_progress = FALSE), NA)
	# count classes with 0/1 values are not affected by the logit rule
	infn = make_scale_mismatch_inference("InferenceCountPoisson", "count", rpois(n, 1))
	expect_error(infn$compute_rand_confidence_interval(r = 51, show_progress = FALSE), NA)
	# scale-mismatched classes keep their own refusal message
	y01 = pr; y01[1:2] = 0
	infg = make_scale_mismatch_inference("InferencePropGCompMeanDiff", "proportion", y01)
	expect_error(infg$compute_rand_confidence_interval(r = 51, show_progress = FALSE), "not supported for")
})

test_that("Zhang-combined quantile rand CI (KK quantile IVWC) also refuses exact 0/1 proportions", {
	# The quantile classes refuse to initialize without quantreg, and the
	# sanitizer / valgrind jobs install no Suggests.
	skip_if_not_installed("quantreg")
	gen = tryCatch(get("InferencePropKKQuantileRegrIVWC"), error = function(e) NULL)
	skip_if(is.null(gen), "InferencePropKKQuantileRegrIVWC not available")
	make_kk_prop = function(y_fun) {
		set.seed(1); n = 60
		X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
		des = DesignSeqOneByOneKK14$new(n = n, response_type = "proportion", verbose = FALSE)
		for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, ])
		des$add_all_subject_responses(y_fun(n, des$get_w()))
		des
	}
	y01 = function(n, w) { y = plogis(0.4 * w + rnorm(n)); y[1:4] = 0; y[5:8] = 1; y }
	yin = function(n, w) plogis(0.4 * w + rnorm(n))
	err = tryCatch(gen$new(make_kk_prop(y01))$compute_rand_confidence_interval(r = 51), error = function(e) e)
	expect_s3_class(err, "edi_rand_ci_exact_zero_one_refused")
	expect_match(conditionMessage(err), "compute_asymp_confidence_interval")
	ci = gen$new(make_kk_prop(yin))$compute_rand_confidence_interval(r = 51)
	expect_length(ci, 2L)
})
