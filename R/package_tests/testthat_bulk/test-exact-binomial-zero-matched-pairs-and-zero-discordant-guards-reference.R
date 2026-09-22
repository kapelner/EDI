library(testthat)
library(EDI)
library(data.table)

# InferenceIncidExactBinomial's assert_exact_inference_params() has two guards -- "requires at
# least one matched pair" (stats$m <= 0) and "requires at least one discordant matched pair"
# (stats$d_plus + stats$d_minus <= 0) -- reached only via the PUBLIC dispatch layer
# (compute_exact_confidence_interval()/compute_exact_two_sided_pval_for_treatment_effect(), which
# route through compute_exact_confidence_interval_by_type()/..._by_type() into
# assert_exact_inference_params()). Existing coverage (test-exact-binomial-incidence-private-
# stats-estimate-ci-and-pval-guards-reference.R) calls the lower-level ci_exact_binomial()/
# pval_exact_binomial() DIRECTLY, bypassing assert_exact_inference_params() entirely (those two
# helpers gracefully return NA/1 on zero discordant pairs rather than erroring) -- so neither
# guard had ever actually been triggered anywhere.

mk_discordant_only <- function(n_treat_wins, n_control_wins, n_concordant = 0L) {
	n_pairs <- n_treat_wins + n_control_wins + n_concordant
	x_dat <- data.table(x1 = seq_len(2L * n_pairs) * ifelse(rep(c(TRUE, FALSE), n_pairs), -1, 1), x2 = rep(0:1, length.out = 2L * n_pairs))
	des <- DesignFixedBinaryMatch$new(n = nrow(x_dat), response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(x_dat); des$assign_w_to_all_subjects()
	des$.__enclos_env__$private$ensure_matching_structure_computed()
	m <- as.integer(des$.__enclos_env__$private$m); w <- des$get_w(); y <- integer(length(w))
	ids <- sort(unique(m[m > 0L]))
	for (k in seq_along(ids)) {
		idx <- which(m == ids[k]); tr <- idx[w[idx] == 1L]; ct <- idx[w[idx] == 0L]
		if (k <= n_treat_wins) y[tr] <- 1L
		else if (k <= n_treat_wins + n_control_wins) y[ct] <- 1L
		else { y[tr] <- 1L; y[ct] <- 1L }
	}
	des$add_all_subject_responses(y)
	InferenceIncidExactBinomial$new(des, verbose = FALSE)
}

test_that("all-concordant matched pairs (zero discordant pairs): the public CI/pval methods error with the documented message", {
	inf <- mk_discordant_only(0L, 0L, 4L)
	expect_error(inf$compute_exact_confidence_interval(), "Exact binomial incidence inference requires at least one discordant matched pair\\.")
	expect_error(inf$compute_exact_two_sided_pval_for_treatment_effect(), "Exact binomial incidence inference requires at least one discordant matched pair\\.")
})

test_that("some discordant pairs present: the public CI/pval methods succeed", {
	inf <- mk_discordant_only(3L, 1L, 0L)
	expect_no_error(inf$compute_exact_confidence_interval())
	expect_no_error(inf$compute_exact_two_sided_pval_for_treatment_effect())
})

test_that("zero matched pairs (nothing has matched yet on a KK design): the public CI/pval methods error with the documented message", {
	des <- DesignSeqOneByOneKK14$new(n = 2L, response_type = "incidence", verbose = FALSE)
	des$add_one_subject_to_experiment_and_assign(data.frame(x1 = 0))
	des$add_one_subject_to_experiment_and_assign(data.frame(x1 = 1))
	des$add_all_subject_responses(c(0, 1))
	expect_true(all(as.integer(des$.__enclos_env__$private$m) == 0L))

	inf <- InferenceIncidExactBinomial$new(des, verbose = FALSE)
	expect_error(inf$compute_exact_confidence_interval(), "Exact binomial incidence inference requires at least one matched pair\\.")
	expect_error(inf$compute_exact_two_sided_pval_for_treatment_effect(), "Exact binomial incidence inference requires at least one matched pair\\.")
})
