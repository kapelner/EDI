make_sequential_bootstrap_policy_design = function(name, response_type = "continuous") {
	set.seed(911)
	n = 24L
	X = data.frame(x = sin(seq_len(n)), stratum = rep(c("a", "b"), n / 2L))
	args = list(n = n, response_type = response_type)
	if (name %in% c("DesignSeqOneByOnePocockSimon", "DesignSeqOneByOneSPBR")) {
		args$strata_cols = "stratum"
	}
	des = do.call(getExportedValue("EDI", name)$new, args)
	for (i in seq_len(n)) {
		w = des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
		y = if (response_type == "incidence") as.numeric(i %% 3L == 0L) else cos(i) + 0.3 * w
		des$add_one_subject_response(i, y)
	}
	des
}

test_that("all sequential allocation families reject nonparametric bootstrap", {
	for (name in c(
		"DesignSeqOneByOneBernoulli", "DesignSeqOneByOneiBCRD",
		"DesignSeqOneByOneEfron", "DesignSeqOneByOneUrn",
		"DesignSeqOneByOneAtkinson", "DesignSeqOneByOnePocockSimon",
		"DesignSeqOneByOneRandomBlockSize", "DesignSeqOneByOneSPBR",
		"DesignSeqOneByOneKK14", "DesignSeqOneByOneKK21", "DesignSeqOneByOneKK21stepwise"
	)) {
		des = make_sequential_bootstrap_policy_design(name)
		inf = InferenceContinOLS$new(des)
		inf$num_cores = 1L
		expect_false(unname(inf$supports("nonparametric_bootstrap")), info = name)
		expect_false("nonparametric_bootstrap" %in% inf$capabilities(), info = name)
		expect_true(is.finite(inf$compute_estimate()), info = name)
		for (method in EDI:::public_methods_for_capability$nonparametric_bootstrap) {
			expect_error(inf[[method]](), "This method is not supported", info = paste(name, method))
		}
		expect_identical(EDI:::run_all_inference_class_applicable_methods(
			"InferenceContinOLS", c("bootstrap", "m_out_of_n_bootstrap", "subsampling"), des
		), character())
		expect_identical(EDI:::run_all_inference_probe_supported_types(
			"InferenceContinOLS", des, list(), "bootstrap", "ci"
		), character())
	}
})

test_that("sequential restrictions survive aliases, lazy loading, and clones", {
	des = make_sequential_bootstrap_policy_design("DesignSeqOneByOneKK14", "incidence")
	inf = InferenceIncidKKGCompRiskRatio$new(des)
	inf$num_cores = 1L
	for (method in c("compute_bootstrap_confidence_interval",
		"compute_bootstrap_confidence_interval_generic",
		"approximate_bootstrap_distribution_beta_hat_T")) {
		expect_error(inf[[method]](), "This method is not supported")
	}
	# Other methods can still load shared resampling code. That must not restore
	# any unsupported public bootstrap entry point.
	expect_true(length(inf$get_supported_rand_bootstrap_pval_types()) > 0L)
	for (copy in list(inf, inf$clone(deep = TRUE), inf$duplicate(make_fork_cluster = FALSE))) {
		expect_false(unname(copy$supports("nonparametric_bootstrap")))
		expect_error(copy$compute_bootstrap_confidence_interval_generic(), "This method is not supported")
		expect_error(copy$approximate_bootstrap_distribution_beta_hat_T(), "This method is not supported")
		expect_true(bindingIsLocked("compute_bootstrap_confidence_interval", copy))
	}
})

test_that("fixed-design support and class metadata are not contaminated by sequential queries", {
	set.seed(123)
	des = DesignFixedBernoulli$new(n = 24L, response_type = "continuous")
	des$add_all_subjects_to_experiment(data.frame(x = sin(1:24)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(cos(1:24) + des$get_w())
	seq_des = make_sequential_bootstrap_policy_design("DesignSeqOneByOneBernoulli")
	class_caps = EDI:::get_effective_capabilities("InferenceContinOLS")
	expect_true("nonparametric_bootstrap" %in% class_caps)
	expect_false("nonparametric_bootstrap" %in% EDI:::get_effective_capabilities("InferenceContinOLS", seq_des))
	expect_identical(EDI:::get_effective_capabilities("InferenceContinOLS", des), class_caps)
	expect_identical(EDI:::get_effective_capabilities("InferenceContinOLS"), class_caps)
	inf = InferenceContinOLS$new(des)
	inf$num_cores = 1L
	expect_true(unname(inf$supports("nonparametric_bootstrap")))
	expect_length(inf$approximate_bootstrap_distribution_beta_hat_T(B = 5L, show_progress = FALSE), 5L)
	expect_true("bootstrap" %in% EDI:::run_all_inference_class_applicable_methods("InferenceContinOLS", "bootstrap", des))
})

test_that("unregistered subclasses inherit the sequential restriction", {
	ExternalSequentialDesign = R6::R6Class("ExternalSequentialDesign",
		inherit = DesignSeqOneByOneBernoulli, lock_objects = FALSE)
	des = ExternalSequentialDesign$new(n = 12L, response_type = "continuous")
	for (i in 1:12) des$add_one_subject_to_experiment_and_assign(data.frame(x = sin(i)))
	des$add_all_subject_responses(cos(1:12))
	inf = InferenceContinOLS$new(des)
	expect_false(unname(inf$supports("nonparametric_bootstrap")))
	expect_error(inf$compute_bootstrap_two_sided_pval(), "This method is not supported")
})
