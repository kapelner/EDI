# TODO-119 capability audit (2026-10-22): a (class, response type) pair whose
# randomization CI is refused statically -- incidence, or a shift-scale mismatch
# per inference_randomization_ci_scale_mismatch() -- must not advertise the
# `randomization_ci` capability through get_effective_capabilities(name, des_obj),
# $capabilities()/$supports(), or the InferenceSuite discovery helpers. The
# data-dependent exact-0/1 refusal cannot be decided from (class, response type)
# and stays advertised (documented in inference_response_type_excluded_capabilities()).

make_cap_design = function(response_type, y, n = 40L) {
	des = DesignSeqOneByOneBernoulli$new(response_type = response_type, n = n, verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x = i / n))
	des$add_all_subject_responses(y)
	des
}

cap_response_draws = function(n = 40L) {
	set.seed(119L)
	list(
		continuous = rnorm(n),
		proportion = pmin(0.95, pmax(0.05, runif(n))),
		count = rpois(n, 3),
		incidence = rep(c(0, 1), length.out = n),
		ordinal = sample(1:5, n, TRUE),
		survival = rexp(n, 0.2)
	)
}

# Every (concrete class, registry response type) pair whose class-level
# capabilities include randomization_ci, with the static refusal decision.
rand_ci_static_pairs = function() {
	ns = asNamespace("EDI")
	ns$populate_inference_class_registry()
	reg = ns$inference_class_registry_as_list()
	out = list()
	for (nm in sort(names(reg))) {
		m = ns$get_inference_class_metadata(nm)
		if (isTRUE(m$abstract)) next
		caps = ns$get_effective_capabilities(nm)
		if (!("randomization_ci" %in% caps)) next
		lineage = ns$inference_registered_class_lineage(nm)
		model_scale = ns$inference_model_scale_randomization_transform_for(lineage, caps)
		for (rt in m$response_types) {
			refused = identical(rt, "incidence") ||
				!is.null(ns$inference_randomization_ci_scale_mismatch(lineage, rt, model_scale))
			out[[length(out) + 1L]] = list(class = nm, response_type = rt, refused = refused)
		}
	}
	out
}

test_that("refused (class, response type) pairs do not advertise randomization_ci; served pairs do", {
	pairs = rand_ci_static_pairs()
	expect_gt(length(pairs), 0L)
	expect_true(any(vapply(pairs, `[[`, logical(1), "refused")))
	for (p in pairs) {
		advertised = "randomization_ci" %in% EDI:::get_effective_capabilities_for_response_type(p$class, p$response_type)
		expect_identical(advertised, !p$refused, info = paste(p$class, p$response_type))
	}
})

test_that("pinned refused pairs (TODO-119 scale mismatch, survival raw scale, incidence)", {
	f = function(cls, rt) "randomization_ci" %in% EDI:::get_effective_capabilities_for_response_type(cls, rt)
	for (cls in c("InferenceAllSimpleAverageDiff", "InferenceAllSimpleMeanDiffPooledVar",
			"InferenceAllKKMeanDiffIVWC", "InferenceAllSimpleWilcox", "InferenceAllKKWilcoxIVWC")) {
		for (rt in c("proportion", "count", "survival")) expect_false(f(cls, rt), info = paste(cls, rt))
		expect_true(f(cls, "continuous"), info = cls)
	}
	expect_false(f("InferenceAllSimpleAverageDiff", "incidence"))
	# ordinal generic classes use a same-scale additive shift (TODO-119 audit)
	expect_true(f("InferenceAllSimpleAverageDiff", "ordinal"))
	expect_false(f("InferenceCountQuasiPoisson", "count"))
	expect_false(f("InferenceCountRobustPoisson", "count"))
	expect_false(f("InferenceIncidLogRegr", "incidence"))
	# model-scale classes whose estimand is the shift scale keep it
	expect_true(f("InferenceCountPoisson", "count"))
	expect_true(f("InferencePropFractionalLogit", "proportion"))
	expect_true(f("InferenceSurvivalWeibullRegr", "survival"))
	# class-level exclusions: hard-listed scale-mismatch classes and survival classes
	# whose own compute_rand_confidence_interval() override always refuses
	for (cls in c(EDI:::EDI_RAND_CI_SHIFT_SCALE_MISMATCH_CLASSES, EDI:::EDI_RAND_CI_CLASS_OVERRIDE_REFUSING_CLASSES,
			EDI:::EDI_LOG_HAZARD_RATIO_INFERENCE_CLASSES)) {
		expect_false("randomization_ci" %in% EDI:::get_effective_capabilities(cls), info = cls)
	}
	# the name-only lookup keeps the class-level union (no response type known)
	expect_true("randomization_ci" %in% EDI:::get_effective_capabilities("InferenceAllSimpleAverageDiff"))
})

test_that("des_obj-aware and live capability lookups agree with the refusal the CI itself raises", {
	skip_on_cran()
	ys = cap_response_draws()
	designs = lapply(ys, function(y) NULL)
	pairs = rand_ci_static_pairs()
	n_live = 0L
	for (p in pairs) {
		rt = p$response_type
		if (is.null(designs[[rt]])) designs[[rt]] = make_cap_design(rt, ys[[rt]])
		des = designs[[rt]]
		expect_identical("randomization_ci" %in% EDI:::get_effective_capabilities(p$class, des), !p$refused,
			info = paste("des_obj", p$class, rt))
		inf = tryCatch(suppressWarnings(get(p$class, envir = asNamespace("EDI"))$new(des, verbose = FALSE)),
			error = function(e) NULL)
		if (is.null(inf)) next # e.g. KK-matching or blocking-only classes on a Bernoulli design
		n_live = n_live + 1L
		expect_identical(unname(inf$supports("randomization_ci")), !p$refused, info = paste("live", p$class, rt))
		if (p$refused) {
			# the dropped capability is a real refusal, not a lost working CI
			out = tryCatch(suppressWarnings(inf$compute_rand_confidence_interval(r = 21, show_progress = FALSE)),
				error = function(e) "refused")
			expect_true(identical(out, "refused") || all(is.na(out)), info = paste("refusal", p$class, rt))
		}
	}
	expect_gt(n_live, 10L)
})

test_that("exact 0/1 proportions: data-dependent refusal leaves randomization_ci advertised", {
	n = 40L
	set.seed(5L)
	y = pmin(0.95, pmax(0.05, runif(n))); y[1:2] = 0; y[3] = 1
	inf = get("InferencePropFractionalLogit", envir = asNamespace("EDI"))$new(make_cap_design("proportion", y, n), verbose = FALSE)
	expect_true(unname(inf$supports("randomization_ci")))
	err = tryCatch(inf$compute_rand_confidence_interval(r = 21, show_progress = FALSE), error = function(e) e)
	expect_s3_class(err, "edi_rand_ci_exact_zero_one_refused")
})

test_that("InferenceSuite: refused rand CI is not scheduled as a CI and is reported as NA, not an error", {
	ys = cap_response_draws()
	des = make_cap_design("count", ys$count)
	# the rand sentinel stays applicable through the randomization p-value ...
	expect_true(EDI:::inference_class_has_method("InferenceAllSimpleAverageDiff", "rand", des))
	expect_true("rand" %in% EDI:::run_all_inference_class_applicable_methods(
		"InferenceAllSimpleAverageDiff", "rand", des_obj = des))
	# ... but the CI side reports NA bounds without calling the refusing method
	inf = InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
	ci = tryCatch(EDI:::run_all_inference_call_ci_for_method(inf, 0.05, "rand"), error = function(e) e)
	expect_false(inherits(ci, "error"))
	expect_true(is.na(ci$lower) && is.na(ci$upper))
	# a served pair still schedules the CI
	des_c = make_cap_design("continuous", ys$continuous)
	expect_true("randomization_ci" %in% EDI:::get_effective_capabilities("InferenceAllSimpleAverageDiff", des_c))
})
