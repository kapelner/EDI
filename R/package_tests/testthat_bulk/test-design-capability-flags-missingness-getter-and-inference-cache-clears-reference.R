library(testthat)
library(EDI)

# Small characterisation methods: Design$is_a_cluster_capable() across design families,
# Design$get_missingness_method() reflecting the constructor argument, and the Inference
# private helpers get_or_create_fork_cluster() (asserts vs no asserts) and
# clear_likelihood_null_warm_cache() / set_likelihood_null_warm_state() semantics.

mk_design <- function(cls, ...) {
	n <- 12L
	des <- get(cls)$new(response_type = "continuous", n = n, verbose = FALSE, ...)
	des
}

test_that("cluster capability is TRUE only for the cluster design families", {
	expect_true(DesignFixedCluster$new(cluster_col = "cl", response_type = "continuous", n = 12L, verbose = FALSE)$is_a_cluster_capable())
	expect_true(DesignFixedBlockedCluster$new(cluster_col = "cl", strata_cols = "g", response_type = "continuous", n = 12L, verbose = FALSE)$is_a_cluster_capable())
	for (cls in c("DesignFixedBernoulli", "DesignFixediBCRD")) expect_false(mk_design(cls)$is_a_cluster_capable(), info = cls)
	expect_false(DesignSeqOneByOneBernoulli$new(response_type = "continuous", n = 12L, verbose = FALSE)$is_a_cluster_capable())
	expect_false(DesignSeqOneByOneKK14$new(response_type = "continuous", n = 12L, verbose = FALSE)$is_a_cluster_capable())
})

test_that("the missingness getter reports the constructor's method, defaulting to impute", {
	expect_equal(mk_design("DesignFixedBernoulli")$get_missingness_method(), "impute")
	for (m in c("impute", "drop_column", "error")) {
		des <- DesignFixedBernoulli$new(response_type = "continuous", n = 12L, missingness_method = m, verbose = FALSE)
		expect_equal(des$get_missingness_method(), m, info = m)
	}
	expect_error(DesignFixedBernoulli$new(response_type = "continuous", n = 12L, missingness_method = "bogus", verbose = FALSE))
})

infer_fx <- function(n = 20L) {
	set.seed(1)
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n))); des$assign_w_to_all_subjects()
	des$add_all_subject_responses(des$get_w() + rnorm(n))
	inf <- InferenceAllSimpleAverageDiff$new(des); list(inf = inf, p = inf$.__enclos_env__$private)
}

test_that("get_or_create_fork_cluster returns the global cluster and, with assertions on, errors when none exists", {
	env <- get("edi_env", envir = asNamespace("EDI"))
	old <- env$global_fork_cluster
	on.exit(env$global_fork_cluster <- old, add = TRUE)
	f <- infer_fx()
	env$global_fork_cluster <- NULL
	expect_error(f$p$get_or_create_fork_cluster(), "No global fork cluster is initialized")
	withr::local_options(edi.run_asserts = FALSE)
	expect_null(f$p$get_or_create_fork_cluster())                                   # unchecked when assertions are off
	options(edi.run_asserts = TRUE)
	sentinel <- structure(list(1, 2), class = "fake_cluster")
	env$global_fork_cluster <- sentinel
	expect_identical(f$p$get_or_create_fork_cluster(), sentinel)
})

test_that("null-fit warm state: stored only when enabled, replaced per key, and emptied by the clear method", {
	f <- infer_fx(); p <- f$p
	p$null_fit_warm_start_enabled <- FALSE
	expect_null(p$set_likelihood_null_warm_state("k", 0.3, c(1, 2)))
	expect_null(p$get_likelihood_null_warm_state("k"))
	p$null_fit_warm_start_enabled <- TRUE
	p$set_likelihood_null_warm_state("k", 0.3, c(1, 2))
	p$set_likelihood_null_warm_state("j", c(0.7, 9), c(3))                       # only the first delta is kept
	expect_equal(p$get_likelihood_null_warm_state("k"), list(delta = 0.3, start = c(1, 2)))
	expect_equal(p$get_likelihood_null_warm_state("j")$delta, 0.7)
	p$set_likelihood_null_warm_state("k", 0.5, c(4))
	expect_equal(p$get_likelihood_null_warm_state("k"), list(delta = 0.5, start = 4))
	expect_null(p$get_likelihood_null_warm_state("missing"))
	expect_null(p$clear_likelihood_null_warm_cache())
	expect_null(p$get_likelihood_null_warm_state("k"))
	expect_equal(length(p$likelihood_null_warm_cache), 0L)
})
