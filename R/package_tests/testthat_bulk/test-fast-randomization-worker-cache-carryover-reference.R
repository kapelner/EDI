library(testthat)
library(EDI)

# build_fast_randomization_worker_cache(): what survives between randomization
# draws on a reused worker. Always kept: m_cache, t0s_rand; plus caller-named
# keys; the per-draw rand_distr_cache is always reset to an empty list.

fx <- function() {
	set.seed(1)
	des <- DesignFixedBernoulli$new(n = 12L, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(12)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(12))
	InferenceAllSimpleAverageDiff$new(des)$.__enclos_env__$private
}

test_that("no previous cache yields just an empty rand_distr_cache", {
	p <- fx()
	expect_identical(p$build_fast_randomization_worker_cache(NULL), list(rand_distr_cache = list()))
})

test_that("only m_cache, t0s_rand and preserved keys carry over; rand_distr_cache is reset", {
	p <- fx()
	prev <- list(m_cache = 1:3, t0s_rand = c(0.1, 0.2), rand_distr_cache = list(a = 1),
		extra = "x", other = 9, beta_hat_T = 5)
	out <- p$build_fast_randomization_worker_cache(prev)
	expect_setequal(names(out), c("m_cache", "t0s_rand", "rand_distr_cache"))
	expect_identical(out$m_cache, 1:3)
	expect_identical(out$t0s_rand, c(0.1, 0.2))
	expect_identical(out$rand_distr_cache, list())

	out2 <- p$build_fast_randomization_worker_cache(prev, preserve_cache_keys = c("extra", "absent", "m_cache"))
	expect_setequal(names(out2), c("m_cache", "t0s_rand", "extra", "rand_distr_cache"))
	expect_identical(out2$extra, "x")
	expect_null(out2$other)
})

test_that("missing or NULL entries in the previous cache are skipped, and an empty list gives only the reset slot", {
	p <- fx()
	out <- p$build_fast_randomization_worker_cache(list(m_cache = NULL, t0s_rand = 2))
	expect_setequal(names(out), c("t0s_rand", "rand_distr_cache"))
	expect_identical(p$build_fast_randomization_worker_cache(list()), list(rand_distr_cache = list()))
})
