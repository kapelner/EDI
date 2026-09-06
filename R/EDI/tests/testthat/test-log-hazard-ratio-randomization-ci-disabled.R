library(testthat)
library(EDI)

# The generic randomization CI inverts an accelerated-failure-time sharp null
# (treated times multiplied by exp(delta)), so its delta axis is a log *time*
# ratio. Classes whose estimand is a log *hazard* ratio (the Cox family) have
# no shape parameter linking the two axes; seeding the search from their
# estimate produced bounds that were not a CI for anything
# (randomization_ci_construction_audit.md, section A; verified 2026-09-04 on a
# Weibull DGP: Cox estimate -1.702 (log HR), rand CI [-1.702, -1.264], while
# p(delta) peaked at the true log time-ratio 0.8). Decision 2026-09-06: refuse,
# as InferenceSurvivalStratCoxPHRegr already did, and stop advertising the
# capability so InferenceSuite never offers it -- mirroring the ordinal
# model-coefficient precedent (test-ordinal-model-coefficient-randomization-ci-disabled.R).
# The randomization p-value and the randomization-bootstrap CI (a percentile
# interval on the estimate's own scale) are deliberately untouched.

make_survival_bernoulli_fixture = function(seed = 7L, n = 60L) {
	set.seed(seed)
	des = DesignSeqOneByOneBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.table::data.table(x1 = rnorm(1)))
	w = as.numeric(des$.__enclos_env__$private$w)
	y = rweibull(n, shape = 2, scale = 1) * exp(0.8 * w)
	cens = runif(n, 0.5, 4)
	EDI:::add_all_subject_responses_seq(des, pmin(y, cens), deads = as.numeric(y <= cens))
	des
}

test_that("the log-hazard-ratio class list agrees with the estimand tag table", {
	classes = EDI:::EDI_LOG_HAZARD_RATIO_INFERENCE_CLASSES
	expect_length(classes, 6L)
	expect_true(all(vapply(classes, EDI:::inference_is_log_hazard_ratio_class, logical(1))))
	tags = EDI:::EDI_INFERENCE_ESTIMAND_TAGS
	tagged = sort(names(tags)[vapply(tags, function(t) identical(t, "log_hazard_ratio"), logical(1))])
	expect_identical(sort(classes), tagged)
	# nothing outside the list is a log-HR class
	expect_false(EDI:::inference_is_log_hazard_ratio_class("InferenceSurvivalWeibullRegr"))
})

test_that("log-hazard-ratio classes do not advertise the randomization CI but keep the p-value and rand-bootstrap CI", {
	for (class_name in EDI:::EDI_LOG_HAZARD_RATIO_INFERENCE_CLASSES) {
		metadata = EDI:::get_inference_class_metadata(class_name)
		capabilities = EDI:::get_effective_capabilities(class_name)
		expect_identical(metadata$response_types, "survival", info = class_name)
		expect_false("randomization_ci" %in% capabilities, info = class_name)
		expect_true("randomization_ci" %in% metadata$excluded_capabilities, info = class_name)
		# Only the plain randomization CI is disabled. Whatever else the class
		# composes must still be advertised -- in particular the randomization
		# p-value and the randomization-bootstrap CI.
		raw_capabilities = unique(c(
			metadata$capabilities,
			unlist(lapply(EDI:::get_effective_components(class_name), function(component_name) {
				EDI:::get_inference_component(component_name)$provides_capabilities
			}), use.names = FALSE)
		))
		for (kept in c("randomization_test", "randomization_bootstrap", "randomization_bootstrap_ci")) {
			if (kept %in% raw_capabilities) expect_true(kept %in% capabilities, info = paste(class_name, kept))
		}
	}
})

test_that("a direct compute_rand_confidence_interval() call on a Cox class refuses with the scale explanation", {
	des = make_survival_bernoulli_fixture()
	for (class_name in c("InferenceSurvivalCoxPHRegr", "InferenceSurvivalStratCoxPHRegr")) {
		inf = get(class_name)$new(des, verbose = FALSE)
		expect_error(
			inf$compute_rand_confidence_interval(alpha = 0.05, r = 51, show_progress = FALSE),
			regexp = "Log-Hazard Ratio",
			info = class_name
		)
		# the estimate itself is unaffected by the refusal
		expect_true(is.finite(inf$compute_estimate()), info = class_name)
	}
})

test_that("the refusal does not touch the Cox randomization p-value or rand-bootstrap CI", {
	des = make_survival_bernoulli_fixture()
	inf = InferenceSurvivalCoxPHRegr$new(des, verbose = FALSE)
	p = inf$compute_rand_two_sided_pval(r = 51, show_progress = FALSE)
	expect_true(is.finite(p) && p >= 0 && p <= 1)
	brt = suppressMessages(inf$compute_rand_bootstrap_confidence_interval(alpha = 0.05, B = 51, pval_epsilon = 0.05, show_progress = FALSE))
	expect_length(brt, 2L)
	expect_true(all(is.finite(brt)))
	est = inf$compute_estimate()
	expect_true(brt[1] <= est && est <= brt[2])
})

test_that("an AFT-scale survival class still advertises and computes the randomization CI", {
	expect_true("randomization_ci" %in% EDI:::get_effective_capabilities("InferenceSurvivalWeibullRegr"))
	des = make_survival_bernoulli_fixture()
	inf = InferenceSurvivalWeibullRegr$new(des, verbose = FALSE)
	ci = suppressMessages(inf$compute_rand_confidence_interval(alpha = 0.05, r = 51, pval_epsilon = 0.05, show_progress = FALSE))
	expect_length(ci, 2L)
	expect_true(all(is.finite(ci)))
	est = inf$compute_estimate()
	expect_true(ci[1] <= est && est <= ci[2])   # the estimate is on the CI's own (log time-ratio) scale
})
