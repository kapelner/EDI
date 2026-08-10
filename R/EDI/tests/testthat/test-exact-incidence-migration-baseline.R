library(testthat)
library(EDI)

exact_incidence_baseline_public_methods = c(
	"approximate_bayesian_bootstrap_distribution_beta_hat_T",
	"approximate_bootstrap_distribution_beta_hat_T",
	"approximate_jackknife_distribution_beta_hat_T",
	"approximate_m_out_of_n_bootstrap_distribution_beta_hat_T",
	"approximate_rand_bootstrap_distribution_beta_hat_T",
	"approximate_randomization_distribution_beta_hat_T",
	"approximate_subsampling_distribution_beta_hat_T",
	"capabilities",
	"clone",
	"compute_asymp_confidence_interval",
	"compute_asymp_two_sided_pval",
	"compute_bayesian_bootstrap_confidence_interval",
	"compute_bayesian_bootstrap_two_sided_pval",
	"compute_bootstrap_confidence_interval",
	"compute_bootstrap_two_sided_pval",
	"compute_estimate",
	"compute_estimate_with_bootstrap_weights",
	"compute_exact_confidence_interval",
	"compute_exact_two_sided_pval_for_treatment_effect",
	"compute_jackknife_bias_estimate",
	"compute_jackknife_estimate",
	"compute_jackknife_std_error",
	"compute_jackknife_wald_confidence_interval",
	"compute_jackknife_wald_two_sided_pval",
	"compute_m_out_of_n_bootstrap_confidence_interval",
	"compute_m_out_of_n_bootstrap_two_sided_pval",
	"compute_rand_bootstrap_confidence_interval",
	"compute_rand_bootstrap_two_sided_pval",
	"compute_rand_confidence_interval",
	"compute_rand_two_sided_pval",
	"compute_subsampling_confidence_interval",
	"compute_subsampling_sensitivity",
	"compute_subsampling_two_sided_pval",
	"duplicate",
	"get_analysis_data",
	"get_covariates",
	"get_design_object",
	"get_model_formula",
	"get_nonestimable_reason",
	"get_nonestimable_stage",
	"get_optimization_alg",
	"get_response",
	"get_response_type",
	"get_treatment",
	"initialize",
	"is_nonestimable",
	"select_optimal_b_subsampling",
	"select_optimal_m_out_of_n_bootstrap",
	"set_custom_randomization_statistic_cpp",
	"set_custom_randomization_statistic_function",
	"set_optimization_alg",
	"set_seed",
	"supports"
)

exact_incidence_baseline_duplicate_private_owners = c(
	"resolve_exact_type",
	"normalize_exact_inference_args",
	"assert_exact_inference_params",
	"compute_exact_confidence_interval_by_type",
	"compute_exact_two_sided_pval_for_treatment_effect_by_type",
	"default_exact_type",
	"resolve_jackknife_unit",
	"jackknife_block_size_gt_one_unsupported",
	"mark_jackknife_nonestimable_if_block_unsupported"
)

make_exact_binomial_migration_design = function() {
	x_dat = data.frame(
		x1 = c(-2.00, -2.01, -1.00, -1.01, 1.00, 1.01, 2.00, 2.01),
		x2 = c(0, 0, 1, 1, 0, 0, 1, 1)
	)
	des = DesignFixedBinaryMatch$new(n = nrow(x_dat), response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(x_dat)
	des$assign_w_to_all_subjects()
	des$.__enclos_env__$private$ensure_matching_structure_computed()
	m = as.integer(des$.__enclos_env__$private$m)
	w = des$get_w()
	y = integer(length(w))
	for (pair_id in sort(unique(m[m > 0L]))) {
		idx = which(m == pair_id)
		if (pair_id <= 3L) {
			y[idx[w[idx] == 1L]] = 1L
			y[idx[w[idx] == 0L]] = 0L
		} else {
			y[idx[w[idx] == 1L]] = 0L
			y[idx[w[idx] == 0L]] = 1L
		}
	}
	des$add_all_subject_responses(y)
	des
}

make_exact_fisher_migration_design = function() {
	set.seed(2026)
	n = 20L
	des = DesignSeqOneByOneiBCRD$new(n = n, response_type = "incidence", verbose = FALSE)
	for (i in seq_len(n)) {
		des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	}
	w = des$.__enclos_env__$private$w
	y = rbinom(n, 1, plogis(-0.3 + 0.7 * w))
	add_all_subject_responses_seq(des, y)
	des
}

make_exact_zhang_migration_design = function() {
	set.seed(321)
	n = 24L
	des = DesignSeqOneByOneBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	for (i in seq_len(n)) {
		des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1), x2 = rnorm(1)))
	}
	treatment = des$.__enclos_env__$private$w
	prob = plogis(-0.2 + 0.8 * treatment)
	add_all_subject_responses_seq(des, rbinom(n, 1, prob))
	des
}

expect_exact_incidence_current_snapshot = function(class_name, extra_duplicate_private_owners = character()) {
	method_snapshot = inference_migration_method_snapshot(class_name)
	duplicate_private_owner_names = names(inference_migration_duplicate_private_owners(class_name))

	expect_identical(method_snapshot$public_methods, exact_incidence_baseline_public_methods)
	expect_identical(
		duplicate_private_owner_names,
		c(extra_duplicate_private_owners, exact_incidence_baseline_duplicate_private_owners)
	)
}

test_that("exact incidence migration baseline pins current golden outputs", {
	specs = list(
		InferenceIncidExactBinomial = list(
			generator = InferenceIncidExactBinomial,
			design = make_exact_binomial_migration_design(),
			alpha = 0.05,
			pval_epsilon = NULL,
			estimate = 0.847297860387204,
			pval = 0.625,
			ci = c(-1.42345544898852, 5.05937522382816)
		),
		InferenceIncidExactFisher = list(
			generator = InferenceIncidExactFisher,
			design = make_exact_fisher_migration_design(),
			alpha = 0.10,
			pval_epsilon = NULL,
			estimate = 0.385034429779156,
			pval = 1,
			ci = c(-1.40296790485226, 2.22290783523223)
		),
		InferenceIncidenceExactZhang = list(
			generator = InferenceIncidenceExactZhang,
			design = make_exact_zhang_migration_design(),
			alpha = 0.10,
			pval_epsilon = 0.01,
			estimate = 1.80191184069207,
			pval = 0.0648822319302868,
			ci = c(0.235551994035931, 3.55040655323846)
		)
	)

	for (class_name in names(specs)) {
		spec = specs[[class_name]]
		inf = spec$generator$new(spec$design, verbose = FALSE)
		ci = if (is.null(spec$pval_epsilon)) {
			inf$compute_exact_confidence_interval(alpha = spec$alpha)
		} else {
			inf$compute_exact_confidence_interval(alpha = spec$alpha, pval_epsilon = spec$pval_epsilon)
		}

		expect_equal(inf$compute_estimate(), spec$estimate, tolerance = 1e-12, info = class_name)
		expect_equal(
			inf$compute_exact_two_sided_pval_for_treatment_effect(delta = 0),
			spec$pval,
			tolerance = 1e-12,
			info = class_name
		)
		expect_equal(as.numeric(ci), spec$ci, tolerance = 1e-12, info = class_name)
	}
})

test_that("exact incidence migration baseline pins method and private-state snapshots", {
	for (class_name in c("InferenceIncidExactBinomial", "InferenceIncidExactFisher")) {
		expect_exact_incidence_current_snapshot(class_name)
	}
	expect_exact_incidence_current_snapshot(
		"InferenceIncidenceExactZhang",
		extra_duplicate_private_owners = "supports_bayesian_bootstrap"
	)
})
