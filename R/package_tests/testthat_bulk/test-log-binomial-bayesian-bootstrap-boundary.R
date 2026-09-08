library(testthat)
library(EDI)

test_that("InferenceIncidLogBinomial Bayesian bootstrap does not discard boundary-hitting weighted replicates", {
	# Regression for the 2026-09-06 comprehensive-results investigation:
	# is_log_binomial_fit_reasonable() rejected any Dirichlet-weighted
	# refit whose fitted linear predictor exceeded the log-link's
	# probability-1 boundary (eta > 1e-6), discarding that replicate
	# entirely. Under Dirichlet reweighting, replicates that push a
	# high-p0 subject's fitted probability over 1 are disproportionately
	# the EXTREME TAIL of the resampling distribution -- exactly the
	# replicates needed to represent true sampling variability. Discarding
	# them shrank the empirical bootstrap spread, producing simultaneously
	# too-narrow CIs (56-70% coverage vs. nominal 95%) and too-small
	# p-values (15-36% Type-I error vs. nominal 5%), plus NA rates up to
	# 85% when too few replicates survived min_number_usable_samples.
	# Fixed by skipping the probability-boundary check specifically for the
	# weighted-refit path (check_probability_boundary = FALSE), while
	# keeping it for the primary (unweighted) fit.
	n <- 150L
	na_count <- 0L
	reject <- 0L
	R <- 30L
	for (r in seq_len(R)) {
		set.seed(7000L + r)
		x <- rnorm(n)
		des <- DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
		des$add_all_subjects_to_experiment(data.frame(x = x))
		des$assign_w_to_all_subjects()
		p0 <- plogis(-1 + 0.5 * x)
		eta <- log(pmin(p0, 0.9))
		y <- rbinom(n, 1, exp(eta))
		des$add_all_subject_responses(y)
		inf <- InferenceIncidLogBinomial$new(des, model_formula = ~ x, verbose = FALSE)
		p <- inf$compute_bayesian_bootstrap_two_sided_pval(B = 150, show_progress = FALSE)
		if (is.na(p)) {
			na_count <- na_count + 1L
		} else if (p < 0.05) {
			reject <- reject + 1L
		}
	}
	expect_equal(na_count, 0L)
	expect_lt(reject / R, 0.20)
})
