library(testthat)
library(EDI)
library(data.table)

# InferenceIncidExactBinomial$compute_exact_two_sided_pval_for_treatment_effect()
# was only ever checked at delta = 0 (R/EDI/tests/testthat/test-incidence-exact-binomial.R,
# the classic McNemar case), never at a nonzero null log-odds-ratio shift, which
# the private zhang_exact_binom_pval_cpp() kernel explicitly accepts as its third
# argument. Under H0: log(OR) = delta_0, the discordant-pair count d_plus follows
# Binomial(d_plus + d_minus, p_0) with p_0 = plogis(delta_0) -- this file verifies
# that shift against an independent stats::binom.test() reference.

make_matched_pair_design <- function(favor_treatment_pairs, favor_control_pairs) {
	n_pairs <- favor_treatment_pairs + favor_control_pairs
	x_dat <- data.table(
		x1 = seq_len(2L * n_pairs) * ifelse(rep(c(TRUE, FALSE), n_pairs), -1, 1),
		x2 = rep(0:1, length.out = 2L * n_pairs)
	)
	des <- DesignFixedBinaryMatch$new(n = nrow(x_dat), response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(x_dat)
	des$assign_w_to_all_subjects()
	des$.__enclos_env__$private$ensure_matching_structure_computed()
	m <- as.integer(des$.__enclos_env__$private$m)
	w <- des$get_w()
	y <- integer(length(w))
	pair_ids <- sort(unique(m[m > 0L]))
	for (k in seq_along(pair_ids)) {
		idx <- which(m == pair_ids[k])
		if (k <= favor_treatment_pairs) {
			y[idx[w[idx] == 1L]] <- 1L
			y[idx[w[idx] == 0L]] <- 0L
		} else {
			y[idx[w[idx] == 1L]] <- 0L
			y[idx[w[idx] == 0L]] <- 1L
		}
	}
	des$add_all_subject_responses(y)
	des
}

test_that("Exact-binomial two-sided p-value at nonzero delta matches an independent binom.test shift reference", {
	skip_if_not_installed("nbpMatching")
	des <- make_matched_pair_design(favor_treatment_pairs = 7L, favor_control_pairs = 2L)
	inf <- InferenceIncidExactBinomial$new(des, verbose = FALSE)
	stats <- inf$.__enclos_env__$private$get_exact_binomial_stats()
	expect_identical(stats$d_plus, 7L)
	expect_identical(stats$d_minus, 2L)

	for (delta in c(0, 0.3, -0.5, 1.1, -1.4)) {
		pval_pkg <- inf$compute_exact_two_sided_pval_for_treatment_effect(delta = delta)
		p0 <- stats::plogis(delta)
		pval_ref <- stats::binom.test(stats$d_plus, stats$d_plus + stats$d_minus, p = p0)$p.value
		expect_equal(pval_pkg, pval_ref, tolerance = 1e-10)
	}
})

test_that("Exact-binomial rejects the p-value/CI computation when there are no discordant pairs (the private pval_exact_binomial() 'return(1)' zero-discordant branch is unreachable via the public API, since assert_exact_inference_params() stops first)", {
	skip_if_not_installed("nbpMatching")
	x_dat <- data.table(x1 = c(-1, 1, -1.01, 1.01), x2 = c(0, 0, 1, 1))
	des <- DesignFixedBinaryMatch$new(n = nrow(x_dat), response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(x_dat)
	des$assign_w_to_all_subjects()
	des$.__enclos_env__$private$ensure_matching_structure_computed()
	m <- as.integer(des$.__enclos_env__$private$m)
	w <- des$get_w()
	y <- rep(1L, length(w))
	des$add_all_subject_responses(y)
	inf <- InferenceIncidExactBinomial$new(des, verbose = FALSE)
	stats <- inf$.__enclos_env__$private$get_exact_binomial_stats()
	expect_identical(stats$d_plus + stats$d_minus, 0L)
	expect_error(
		inf$compute_exact_two_sided_pval_for_treatment_effect(delta = 0.5),
		"at least one discordant matched pair"
	)
	# The unreachable branch itself still behaves as documented when called directly.
	expect_equal(inf$.__enclos_env__$private$pval_exact_binomial(0.5), 1)
})
