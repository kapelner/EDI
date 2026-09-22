library(testthat)
library(EDI)

# inference_all_abstract_rand.R's load_resampling_draw_into_worker(operation, worker_state, draw)
# looks up the operation's loader method name via get_resampling_draw_contract()/
# resampling_draw_contract() (contracts_resampling_draws.R's EDI_RESAMPLING_DRAW_CONTRACTS) and
# stop()s "No resampling draw loader named \`<loader>\` for operation \`<operation>\`." if that method
# isn't a function on this instance. The sibling contract-lookup guards on the SAME underlying
# resampling_draw_contract() helper -- "Unknown resampling operation: " and "operation must be one
# resampling operation name." -- are already covered (test-abstract-inference-contract-helpers.R,
# test-resampling-draw-contracts.R), but this loader-existence guard had zero test references
# anywhere. Every known contract operation's loader method is in practice always spliced onto every
# concrete class regardless of which extension it logically composes (the component system's
# source_name full-splicing behavior noted elsewhere in this test suite), so the guard is never
# naturally reachable through any current class -- exercised the same way this session has tested
# other structurally-real-but-not-naturally-reachable guards: directly nulling the loader method on
# an already-constructed object.

fx <- function(seed = 1L, n = 20L) {
	set.seed(seed)
	d <- DesignFixedBernoulli$new(response_type = "continuous", n = n, seed = seed, verbose = FALSE)
	d$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n))); d$assign_w_to_all_subjects()
	w <- d$get_w()
	d$add_all_subject_responses(rnorm(n) + w)
	inf <- InferenceContinLin$new(d, verbose = FALSE)
	inf$.__enclos_env__$private
}

test_that("load_resampling_draw_into_worker(): every known operation's loader is normally present as a function", {
	priv <- fx(seed = 1L)
	for (loader in c("load_randomization_draw_into_worker", "load_non_param_bootstrap_draw_into_worker",
	                  "load_m_out_of_n_bootstrap_draw_into_worker", "load_subsampling_draw_into_worker")) {
		expect_true(is.function(priv[[loader]]), info = loader)
	}
})

test_that("load_resampling_draw_into_worker(): a missing loader method errors with the documented message", {
	priv <- fx(seed = 2L)
	unlockBinding("load_subsampling_draw_into_worker", priv)
	priv$load_subsampling_draw_into_worker <- NULL

	expect_error(
		priv$load_resampling_draw_into_worker("subsampling", worker_state = list(), draw = list()),
		"No resampling draw loader named `load_subsampling_draw_into_worker` for operation `subsampling`\\."
	)
})
