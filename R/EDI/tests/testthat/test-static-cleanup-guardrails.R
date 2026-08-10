library(testthat)
library(EDI)

static_cleanup_source_files = function() {
	candidates = c(file.path("R", "EDI", "R"), file.path("..", "..", "R"))
	source_dir = candidates[file.exists(candidates)][[1L]]
	list.files(source_dir, pattern = "\\.R$", full.names = TRUE)
}

static_cleanup_matches = function(pattern, files = static_cleanup_source_files()) {
	matches = list()
	for (file in files) {
		lines = readLines(file, warn = FALSE)
		idx = grep(pattern, lines, perl = TRUE)
		idx = idx[!grepl("^\\s*#", lines[idx])]
		if (length(idx) == 0L) next
		rel = file.path("R", "EDI", "R", basename(file))
		matches[[length(matches) + 1L]] = data.frame(
			file = rel,
			line = idx,
			text = trimws(lines[idx]),
			stringsAsFactors = FALSE
		)
	}
	if (length(matches) == 0L) {
		return(data.frame(file = character(), line = integer(), text = character()))
	}
	do.call(rbind, matches)
}

static_cleanup_file_counts = function(matches) {
	if (nrow(matches) == 0L) return(integer())
	counts = table(matches$file)
	counts = counts[sort(names(counts))]
	out = as.integer(counts)
	names(out) = names(counts)
	out
}

test_that("static cleanup guardrail prevents new eval(body(Inference...)) usage", {
	matches = static_cleanup_matches("eval\\s*\\(\\s*body\\s*\\(\\s*Inference")
	expected = c(
		"R/EDI/R/inference_all_abstract_KK_passthrough_compound.R" = 1L,
		"R/EDI/R/inference_all_KK_mean_diff_IVWC.R" = 1L,
		"R/EDI/R/inference_all_KK_quantile_regr_ivwc_abstract.R" = 1L,
		"R/EDI/R/inference_all_KK_wilcox_ivwc.R" = 1L,
		"R/EDI/R/inference_continuous_KK_ols_ivwc.R" = 1L,
		"R/EDI/R/inference_count_KK_cond_poisson.R" = 3L,
		"R/EDI/R/inference_incidence_KK_cond_logit.R" = 2L,
		"R/EDI/R/inference_incidence_KK_cond_logit_glmm_abstract.R" = 1L,
		"R/EDI/R/inference_incidence_KK_marginal_abstract.R" = 1L,
		"R/EDI/R/inference_ordinal_KK_clmm_abstract.R" = 1L,
		"R/EDI/R/inference_ordinal_KK_cond_adj_cat_logit.R" = 1L,
		"R/EDI/R/inference_survival_KK_clayton_copula.R" = 2L,
		"R/EDI/R/inference_survival_KK_lwa_cox_ivwc_abstract.R" = 1L,
		"R/EDI/R/inference_survival_KK_lwa_cox_one_lik_abstract.R" = 1L,
		"R/EDI/R/inference_survival_KK_rank_regr_ivwc_abstract.R" = 1L,
		"R/EDI/R/inference_survival_KK_strat_cox.R" = 2L,
		"R/EDI/R/inference_survival_KK_weibull_frailty.R" = 2L,
		"R/EDI/R/inference_survival_KK_weibull_marginal.R" = 1L
	)

	expect_identical(static_cleanup_file_counts(matches), expected[sort(names(expected))])
})

test_that("static cleanup guardrail prevents new raw component splicing", {
	matches = static_cleanup_matches(
		"\\b(Inference(?:Ext|Mixin)[A-Za-z0-9_]+\\$(public|private)|inference_[A-Za-z0-9_]+_(?:components\\$(?:public|private)|private))\\b"
	)
	expected = c(
		"R/EDI/R/inference_all_abstract_KK_passthrough_compound.R" = 5L,
		"R/EDI/R/inference_all_abstract_asymp_lik.R" = 1L,
		"R/EDI/R/inference_all_abstract_asymp_lik_std_mod_cache.R" = 3L,
		"R/EDI/R/inference_all_abstract_count_likelihood.R" = 3L,
		"R/EDI/R/inference_all_abstract_non_param_boot.R" = 7L,
		"R/EDI/R/inference_all_abstract_param_boot.R" = 1L,
		"R/EDI/R/inference_all_abstract_quantile_rand_ci.R" = 2L,
		"R/EDI/R/inference_all_abstract_rand.R" = 1L,
		"R/EDI/R/inference_all_KK_mean_diff_IVWC.R" = 1L,
		"R/EDI/R/inference_all_KK_quantile_regr_ivwc_abstract.R" = 1L,
		"R/EDI/R/inference_all_KK_wilcox_ivwc.R" = 1L,
		"R/EDI/R/inference_continuous_KK_glmm.R" = 2L,
		"R/EDI/R/inference_continuous_KK_ols_ivwc.R" = 1L,
		"R/EDI/R/inference_count_KK_combined.R" = 2L,
		"R/EDI/R/inference_count_KK_cond_poisson.R" = 9L,
		"R/EDI/R/inference_count_KK_gee.R" = 2L,
		"R/EDI/R/inference_incidence_KK_combined.R" = 2L,
		"R/EDI/R/inference_incidence_KK_cond_logit.R" = 4L,
		"R/EDI/R/inference_incidence_KK_cond_logit_glmm_abstract.R" = 3L,
		"R/EDI/R/inference_incidence_KK_marginal_abstract.R" = 3L,
		"R/EDI/R/inference_ordinal_KK_clmm_abstract.R" = 3L,
		"R/EDI/R/inference_ordinal_KK_combined.R" = 4L,
		"R/EDI/R/inference_ordinal_KK_cond_adj_cat_logit.R" = 3L,
		"R/EDI/R/inference_ordinal_paired_sign_test.R" = 2L,
		"R/EDI/R/inference_proportion_KK_combined.R" = 2L,
		"R/EDI/R/inference_survival_KK_clayton_copula.R" = 4L,
		"R/EDI/R/inference_survival_KK_lwa_cox_ivwc_abstract.R" = 1L,
		"R/EDI/R/inference_survival_KK_lwa_cox_one_lik_abstract.R" = 3L,
		"R/EDI/R/inference_survival_KK_rank_regr_ivwc_abstract.R" = 1L,
		"R/EDI/R/inference_survival_KK_strat_cox.R" = 4L,
		"R/EDI/R/inference_survival_KK_weibull_frailty.R" = 4L,
		"R/EDI/R/inference_survival_KK_weibull_marginal.R" = 3L
	)

	expect_identical(static_cleanup_file_counts(matches), expected[sort(names(expected))])
})

test_that("static cleanup guardrail bans R6 generator private member reads", {
	files = c(
		static_cleanup_source_files(),
		list.files(".", pattern = "\\.R$", full.names = TRUE)
	)
	matches = static_cleanup_matches(
		"\\bInference[A-Za-z0-9_]+\\$(private_methods|private_fields)\\b",
		files = files
	)

	expect_equal(nrow(matches), 0L)
})
