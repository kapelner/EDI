test_that("custom extension base classes are internal but usable for subclassing", {
	exports = getNamespaceExports("EDI")
	expect_false("InferenceCustomAsymp" %in% exports)
	expect_false("InferenceCustomRand" %in% exports)
	expect_false("InferenceCustomBoot" %in% exports)
	expect_false("DesignCustomSequential" %in% exports)
	expect_false("DesignFixedCustom" %in% exports)

	expect_true(is.environment(getNamespace("EDI")))
	expect_s3_class(getFromNamespace("InferenceCustomAsymp", "EDI"), "R6ClassGenerator")
	expect_s3_class(getFromNamespace("InferenceCustomRand", "EDI"), "R6ClassGenerator")
	expect_s3_class(getFromNamespace("InferenceCustomBoot", "EDI"), "R6ClassGenerator")
	expect_s3_class(getFromNamespace("DesignCustomSequential", "EDI"), "R6ClassGenerator")
	expect_s3_class(getFromNamespace("DesignFixedCustom", "EDI"), "R6ClassGenerator")
})

test_that("custom asymptotic inference works from an external-package-like environment", {
	ext_env = new.env(parent = globalenv())
	ext_env$R6Class = R6::R6Class
	ext_env$InferenceCustomAsymp = getFromNamespace("InferenceCustomAsymp", "EDI")

	evalq({
		ExternalMeanDiff = R6Class(
			"ExternalMeanDiff",
			inherit = InferenceCustomAsymp,
			lock_objects = FALSE,
			public = list(
				fit = function(estimate_only = FALSE) {
					dat = self$get_analysis_data()
					y_t = dat$y[dat$w == 1]
					y_c = dat$y[dat$w == 0]
					est = mean(y_t) - mean(y_c)
					if (estimate_only) return(list(estimate = est))
					se = sqrt(stats::var(y_t) / length(y_t) + stats::var(y_c) / length(y_c))
					df = length(y_t) + length(y_c) - 2
					list(
						estimate = est,
						se = se,
						df = df,
						model = list(n_t = length(y_t), n_c = length(y_c))
					)
				}
			)
		)
	}, envir = ext_env)

	des = DesignFixedBernoulli$new(n = 20, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = seq_len(20)))
	des$overwrite_all_subject_assignments(rep(c(0, 1), each = 10))
	des$add_all_subject_responses(c(1:10, 12:21))

	inf = ext_env$ExternalMeanDiff$new(des, verbose = FALSE)
	expect_s3_class(inf, "ExternalMeanDiff")
	expect_equal(inf$get_response(), c(1:10, 12:21))
	expect_equal(inf$get_treatment(), rep(c(0, 1), each = 10))
	expect_equal(inf$get_response_type(), "continuous")
	expect_identical(inf$get_design_object(), des)
	expect_equal(nrow(inf$get_analysis_data()), 20)
	expect_true("x" %in% names(inf$get_analysis_data()))

	expect_equal(inf$compute_estimate(), 11)
	expect_true(is.finite(inf$compute_asymp_two_sided_pval()))
	expect_length(inf$compute_asymp_confidence_interval(), 2)
	expect_equal(inf$get_mod()$n_t, 10)

	set.seed(20260420)
	boot_p = inf$compute_bootstrap_two_sided_pval(
		B = 21,
		na.rm = TRUE,
		min_number_usable_samples = 5L
	)
	expect_true(is.finite(boot_p))
	expect_true(boot_p >= 0 && boot_p <= 1)
})

test_that("custom randomization inference works from an external-package-like environment", {
	ext_env = new.env(parent = globalenv())
	ext_env$R6Class = R6::R6Class
	ext_env$InferenceCustomRand = getFromNamespace("InferenceCustomRand", "EDI")

	evalq({
		ExternalRandMeanDiff = R6Class(
			"ExternalRandMeanDiff",
			inherit = InferenceCustomRand,
			lock_objects = FALSE,
			public = list(
				fit = function(estimate_only = FALSE) {
					dat = self$get_analysis_data()
					y_t = dat$y[dat$w == 1]
					y_c = dat$y[dat$w == 0]
					list(
						estimate = mean(y_t) - mean(y_c),
						model = list(estimate_only = estimate_only)
					)
				}
			)
		)
	}, envir = ext_env)

	des = DesignFixedBernoulli$new(n = 20, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = seq_len(20)))
	des$overwrite_all_subject_assignments(rep(c(0, 1), each = 10))
	des$add_all_subject_responses(c(1:10, 12:21))

	inf = ext_env$ExternalRandMeanDiff$new(des, verbose = FALSE)
	expect_s3_class(inf, "ExternalRandMeanDiff")
	expect_equal(inf$get_response(), c(1:10, 12:21))
	expect_equal(inf$get_treatment(), rep(c(0, 1), each = 10))
	expect_equal(nrow(inf$get_analysis_data()), 20)
	expect_equal(inf$compute_estimate(), 11)
})

test_that("custom bootstrap inference works from an external-package-like environment", {
	ext_env = new.env(parent = globalenv())
	ext_env$R6Class = R6::R6Class
	ext_env$InferenceCustomBoot = getFromNamespace("InferenceCustomBoot", "EDI")

	evalq({
		ExternalBootMedianDiff = R6Class(
			"ExternalBootMedianDiff",
			inherit = InferenceCustomBoot,
			lock_objects = FALSE,
			public = list(
				fit = function(estimate_only = FALSE) {
					dat = self$get_analysis_data()
					y_t = dat$y[dat$w == 1]
					y_c = dat$y[dat$w == 0]
					list(
						estimate = stats::median(y_t) - stats::median(y_c),
						model = list(estimate_only = estimate_only)
					)
				}
			)
		)
	}, envir = ext_env)

	des = DesignFixedBernoulli$new(n = 20, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = seq_len(20)))
	des$overwrite_all_subject_assignments(rep(c(0, 1), each = 10))
	des$add_all_subject_responses(c(1:10, 12:21))

	inf = ext_env$ExternalBootMedianDiff$new(des, verbose = FALSE)
	expect_s3_class(inf, "ExternalBootMedianDiff")
	expect_identical(inf$get_design_object(), des)
	expect_equal(inf$get_response_type(), "continuous")
	expect_equal(inf$compute_estimate(), 11)
})

test_that("custom design extension bases delegate user assignment rules", {
	CustomFixedBase = getFromNamespace("DesignFixedCustom", "EDI")
	CustomSequentialBase = getFromNamespace("DesignCustomSequential", "EDI")

	AlternatingFixed = R6::R6Class(
		"AlternatingFixed",
		inherit = CustomFixedBase,
		public = list(
			draw_assignments = function(r = 1) {
				matrix(rep(rep(c(0, 1), length.out = self$get_n()), r), nrow = self$get_n(), ncol = r)
			}
		)
	)
	fixed = AlternatingFixed$new(n = 6, response_type = "continuous", verbose = FALSE)
	fixed$add_all_subjects_to_experiment(data.frame(x = 1:6))
	fixed$assign_w_to_all_subjects()
	expect_equal(fixed$get_w(), c(0, 1, 0, 1, 0, 1))
	expect_equal(dim(fixed$draw_ws_according_to_design(3)), c(6, 3))

	ExternalSequential = R6::R6Class(
		"ExternalSequential",
		inherit = CustomSequentialBase,
		public = list(
			assignment_rule = function() {
				as.numeric(self$get_t() %% 2L == 0L)
			}
		)
	)
	seq_des = ExternalSequential$new(n = 4, response_type = "continuous", verbose = FALSE)
	for (i in 1:4) {
		seq_des$add_one_subject_to_experiment_and_assign(data.frame(x = i))
	}
	expect_equal(seq_des$get_w(), c(0, 1, 0, 1))
})

# 2026-08-23 (extending-edi-r6.md, "Subclassing Rules And Capability
# Detection", rewritten for the finished shallow hierarchy): pin the exact
# promises that document makes to external authors about capability queries
# and discovery for UNREGISTERED subclasses -- an external class is never in
# the package registries, so `capabilities()` must resolve through the nearest
# registered ancestor, added methods are not capabilities, and registry-driven
# discovery must not list the class.
test_that("external inference subclasses resolve capabilities through the nearest registered ancestor and are never discovered", {
	shells = list(
		asymp = getFromNamespace("InferenceCustomAsymp", "EDI"),
		rand = getFromNamespace("InferenceCustomRand", "EDI"),
		boot = getFromNamespace("InferenceCustomBoot", "EDI")
	)
	set.seed(20260823)
	des = DesignFixedBernoulli$new(n = 20, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = seq_len(20)))
	des$overwrite_all_subject_assignments(rep(c(0, 1), each = 10))
	des$add_all_subject_responses(rnorm(20))

	for (shell_name in names(shells)) {
		shell = shells[[shell_name]]
		Ext = R6::R6Class(
			paste0("ExternalCaps", shell_name),
			inherit = shell,
			lock_objects = FALSE,
			public = list(
				fit = function(estimate_only = FALSE) {
					dat = self$get_analysis_data()
					list(estimate = mean(dat$y[dat$w == 1]) - mean(dat$y[dat$w == 0]), se = 1, df = NA_real_)
				},
				# An added public method is an ordinary R6 method, not a capability.
				my_extra_summary = function() "extra"
			)
		)
		inf = Ext$new(des)
		# Not registered: the leaf name is absent from the class registry ...
		expect_false(exists(Ext$classname, envir = EDI:::EDI_INFERENCE_CLASS_REGISTRY, inherits = FALSE))
		# ... so capabilities are the registered shell's effective capabilities.
		expect_identical(inf$capabilities(), EDI:::get_effective_capabilities(shell$classname))
		expect_gt(length(inf$capabilities()), 0L)
		expect_identical(unname(inf$supports(inf$capabilities()[1L])), TRUE)
		expect_identical(unname(inf$supports("my_extra_summary")), FALSE)
		expect_identical(inf$my_extra_summary(), "extra")
		# Registry-driven discovery never lists an external class.
		expect_false(Ext$classname %in% des$applicable_inference_class_names())
		expect_false(Ext$classname %in% EDI:::discover_applicable_inference_classes(des))
	}
	# The Wald shell's descendants really do report the Wald/bootstrap family.
	ExtAsymp = R6::R6Class("ExternalCapsWald", inherit = shells$asymp, lock_objects = FALSE,
		public = list(fit = function(estimate_only = FALSE) list(estimate = 0, se = 1, df = NA_real_)))
	expect_true(all(c("wald", "nonparametric_bootstrap") %in% ExtAsymp$new(des)$capabilities()))
	# And the documented `lock_objects = FALSE` requirement is real: a locked
	# subclass constructs but fails at first use of a lazily installed component.
	Locked = R6::R6Class("ExternalLockedAsymp", inherit = shells$asymp,
		public = list(fit = function(estimate_only = FALSE) list(estimate = 0, se = 1, df = NA_real_)))
	locked = Locked$new(des)
	expect_error(locked$compute_bootstrap_two_sided_pval(B = 11), "locked")
})

test_that("external design subclasses get instance capabilities and the documented registry fallbacks", {
	CustomFixedBase = getFromNamespace("DesignFixedCustom", "EDI")
	ExternalAlternating = R6::R6Class(
		"ExternalAlternatingDesign",
		inherit = CustomFixedBase,
		lock_objects = FALSE,
		public = list(
			draw_assignments = function(r = 1) {
				n = self$get_n()
				matrix(rep_len(c(0, 1), n), nrow = n, ncol = r)
			}
		)
	)
	des = ExternalAlternating$new(n = 10, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = 1:10))
	des$assign_w_to_all_subjects()
	expect_equal(des$get_w(), rep(c(0, 1), 5))
	# Not registered, yet fully usable: instance-level capability queries work,
	# the abstract guard treats unregistered names as concrete, and the one
	# generator-level read falls back to the generator's public methods.
	expect_false(exists("ExternalAlternatingDesign", envir = EDI:::EDI_DESIGN_CLASS_REGISTRY, inherits = FALSE))
	expect_true(all(c("resampling", "randomization_draw") %in% des$capabilities()))
	expect_true(des$supports("randomization_draw"))
	expect_false(des$supports("blocking"))
	expect_false(EDI:::is_design_class_abstract("ExternalAlternatingDesign"))
	expect_false(EDI:::design_class_generator_supports_batch_w_pregeneration(ExternalAlternating))
	# Registered package classes are discoverable on a custom design exactly as
	# on a package design (discovery keys on design metadata, not design class).
	des$add_all_subject_responses(rnorm(10))
	expect_true("InferenceContinOLS" %in% des$applicable_inference_class_names())
	# Draw validation documented for draw_assignments(r): non-0/1 output is rejected.
	Bad = R6::R6Class("ExternalBadDesign", inherit = CustomFixedBase, lock_objects = FALSE,
		public = list(draw_assignments = function(r = 1) matrix(2, nrow = self$get_n(), ncol = r)))
	bad = Bad$new(n = 4, response_type = "continuous", verbose = FALSE)
	bad$add_all_subjects_to_experiment(data.frame(x = 1:4))
	expect_error(bad$assign_w_to_all_subjects(), "0/1")
})
