library(testthat)
library(EDI)

# inference_indicidence_exact_fisher.R's format_exact_fisher_tables() drops any 2x2 stratum table
# where either arm's row sum is zero (Filter(function(tab) sum(tab[1,]) > 0L && sum(tab[2,]) > 0L,
# ...)) and stop()s "Cannot compute Fisher exact inference: no informative strata are available."
# when every stratum (matched pairs plus the unmatched reservoir) is dropped this way -- i.e. every
# arm-comparison in the whole matched structure is degenerate (one side has zero subjects). Reachable
# via build_exact_fisher_tables_kk() whenever the instance's own treatment-assignment vector has no
# subjects on one of the two arms; not naturally constructible through ordinary balanced-assignment
# data (a real matched-pair design always keeps both arms populated), so exercised the same way this
# session has tested other structurally-real guards: directly overriding the cached private$w vector
# to be entirely one arm on an already-constructed object. Zero test references anywhere.

test_that("build_exact_fisher_tables_kk(): every subject on one arm leaves no informative strata, errors with the documented message", {
	set.seed(1)
	n <- 8L
	des <- DesignFixedBinaryMatch$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rbinom(n, 1, 0.5))
	inf <- InferenceIncidExactFisher$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private

	unlockBinding("w", priv)
	priv$w <- rep(1L, n)
	expect_error(
		priv$build_exact_fisher_tables_kk(),
		"Cannot compute Fisher exact inference: no informative strata are available\\."
	)
})

test_that("build_exact_fisher_tables_kk(): a normal mixed-arm assignment succeeds with informative strata", {
	set.seed(2)
	n <- 8L
	des <- DesignFixedBinaryMatch$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rbinom(n, 1, 0.5))
	inf <- InferenceIncidExactFisher$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private

	res <- priv$build_exact_fisher_tables_kk()
	expect_true(is.list(res) && is.numeric(res$n_strata) && res$n_strata >= 1L)
})
