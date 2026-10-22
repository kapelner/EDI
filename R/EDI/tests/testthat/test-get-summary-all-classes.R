library(testthat)
library(EDI)

# TODO-114: get_summary() used to print "No model available" / a raw internal
# list / error with "attempt to apply non-function" (no method) depending on the
# class, and always returned NULL. It must now, for every class, print a
# coefficient table and return it invisibly as a numeric matrix, degrading to NA
# (never erroring) when a piece such as the Wald SE is unavailable.

gs_design = function(rt, y, n = 30L, seed = 114L) {
	set.seed(seed)
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	d = DesignFixedBernoulli$new(n = n, response_type = rt, verbose = FALSE)
	d$add_all_subjects_to_experiment(X)
	d$assign_w_to_all_subjects()
	d$add_all_subject_responses(y)
	d
}

gs_check_table = function(tab, label) {
	expect_true(is.matrix(tab) && is.numeric(tab), info = label)
	expect_gte(nrow(tab), 1L)
	expect_equal(ncol(tab), 4L, info = label)
	expect_true("treatment" %in% rownames(tab) || nrow(tab) >= 1L, info = label)
}

test_that("get_summary returns a coefficient table for representative classes", {
	set.seed(1)
	n = 30L
	cases = list(
		OLS = InferenceContinOLS$new(gs_design("continuous", rnorm(n))),
		Logit = InferenceIncidLogRegr$new(gs_design("incidence", rbinom(n, 1, 0.5))),
		Pois = InferenceCountPoisson$new(gs_design("count", rpois(n, 2))),
		Cox = InferenceSurvivalCoxPHRegr$new(gs_design("survival", rexp(n))),
		Ord = InferenceOrdinalPropOddsRegr$new(gs_design("ordinal", sample(1:4, n, TRUE)))
	)
	for (nm in names(cases)) {
		out = capture.output(tab <- cases[[nm]]$get_summary())
		gs_check_table(tab, nm)
		expect_false(any(grepl("No model available|^\\$b$|XtX", out)), info = nm)
		expect_true("treatment" %in% rownames(tab), info = nm)
		expect_equal(unname(tab["treatment", 1]), cases[[nm]]$compute_estimate(), tolerance = 1e-8, info = nm)
		expect_true(is.finite(tab["treatment", 2]) && tab["treatment", 2] > 0, info = nm)
		expect_true(tab["treatment", 4] >= 0 && tab["treatment", 4] <= 1, info = nm)
	}
})

test_that("get_summary works for a class with no asymptotic inference or model (InferenceRandCustom)", {
	set.seed(2)
	d = gs_design("continuous", rnorm(30))
	inf = InferenceRandCustom$new(d, custom_randomization_statistic_function = function(...) 1)
	expect_true(is.function(inf$get_summary))
	out = capture.output(tab <- inf$get_summary())
	gs_check_table(tab, "RandCustom")
	expect_equal(rownames(tab), "treatment")
	expect_true(is.finite(tab[1, 1]))
	expect_true(is.na(tab[1, 2]))
	expect_gt(length(out), 0L)
})

test_that("get_summary does not trigger the cluster-independence warning more than once", {
	set.seed(3)
	inf = InferenceContinOLS$new(gs_design("continuous", rnorm(30)))
	w = character()
	withCallingHandlers(
		{ capture.output(inf$get_summary()); capture.output(inf$get_summary()) },
		warning = function(cnd) { w <<- c(w, conditionMessage(cnd)); invokeRestart("muffleWarning") })
	expect_false(any(grepl("independen", w, ignore.case = TRUE)))
})

test_that("get_summary survives a missing SE without erroring", {
	set.seed(4)
	inf = InferenceContinOLS$new(gs_design("continuous", rnorm(30)))
	inf$compute_estimate()
	priv = inf$.__enclos_env__$private
	priv$cached_values$s_beta_hat_T = NA_real_
	out = capture.output(tab <- inf$get_summary())
	expect_true(is.na(tab["treatment", 2]))
	expect_true(is.finite(tab["treatment", 1]))
})

test_that("get_summary sweep: every applicable class on cheap designs prints a table and never errors", {
	set.seed(5)
	n = 30L
	designs = list(
		continuous = gs_design("continuous", rnorm(n)),
		incidence = gs_design("incidence", rbinom(n, 1, 0.5)),
		count = gs_design("count", rpois(n, 2)),
		survival = gs_design("survival", rexp(n)),
		ordinal = gs_design("ordinal", sample(1:4, n, TRUE))
	)
	skip_re = "GLMM|Bayes|Exact|GEE|Stan|IVWC"
	failures = character()
	tested = 0L
	for (rt in names(designs)) {
		for (cls in designs[[rt]]$applicable_inference_class_names()) {
			if (grepl(skip_re, cls)) next
			inf = tryCatch(get(cls, envir = asNamespace("EDI"))$new(designs[[rt]]), error = function(e) NULL)
			if (is.null(inf)) next
			tested = tested + 1L
			res = tryCatch({
				out = utils::capture.output(tab <- suppressWarnings(inf$get_summary()))
				if (!(is.matrix(tab) && is.numeric(tab) && nrow(tab) >= 1L && ncol(tab) >= 4L)) "did not return a numeric table"
				else if (any(grepl("No model available", out))) "printed 'No model available'"
				else NA_character_
			}, error = function(e) paste("error:", conditionMessage(e)))
			if (!is.na(res)) failures = c(failures, paste(rt, cls, res, sep = " | "))
		}
	}
	expect_gt(tested, 40L)
	expect_equal(failures, character(0))
})
