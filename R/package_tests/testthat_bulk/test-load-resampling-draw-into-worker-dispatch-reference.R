library(testthat)
library(EDI)

# 2026-10-22 (v1.0.5 TODO-97 decision 2, option (b)): the by-name dispatcher
# load_resampling_draw_into_worker(operation, ...) was removed. It looked up
# private[[contract$loader]] from EDI_RESAMPLING_DRAW_CONTRACTS, a call the
# component call-graph checker cannot see. Each resampling path now calls its own
# loader directly (load_randomization_draw_into_worker,
# load_non_param_bootstrap_draw_into_worker,
# load_bayesian_bootstrap_draw_into_worker). The contract table keeps its
# `loader` field as checked metadata: every name it lists must still be a real
# private method, so the table cannot drift from the code.

fx <- function(seed = 1L, n = 12L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = 1L, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n))
	inf <- InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
	inf$.__enclos_env__$private
}

test_that("the by-name dispatcher is gone", {
	priv <- fx(1L)
	expect_false(exists("load_resampling_draw_into_worker", envir = priv, inherits = FALSE))
})

test_that("every loader named in the resampling draw contracts is a real private method", {
	priv <- fx(2L)
	contracts <- EDI:::EDI_RESAMPLING_DRAW_CONTRACTS
	# Loaders used by AverageDiff's paths must be bound on the instance.
	for (op in c("rand", "non_param_boot", "bayesian_boot", "rand_bootstrap", "m_out_of_n_boot", "subsampling")) {
		loader <- contracts[[op]]$loader
		expect_true(is.character(loader) && nzchar(loader), info = op)
		expect_true(is.function(priv[[loader]]), info = paste(op, loader))
	}
})

test_that("no bound method still calls the removed dispatcher", {
	priv <- fx(3L)
	fns <- Filter(is.function, mget(ls(priv, all.names = TRUE), envir = priv))
	callers <- names(fns)[vapply(fns, function(f) {
		any(grepl("load_resampling_draw_into_worker", deparse(body(f)), fixed = TRUE))
	}, logical(1L))]
	expect_identical(callers, character(0))
})
