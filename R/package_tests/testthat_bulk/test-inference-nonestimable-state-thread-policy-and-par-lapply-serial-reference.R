library(testthat)
library(EDI)

# The base Inference class's non-estimability state machine
# (cache_nonestimable_estimate / cache_nonestimable_se / clear_nonestimable_state
# and the public is_nonestimable / get_nonestimable_reason / _stage accessors),
# thread sizing (n_cpp_threads, effective_parallel_cores under a serial policy),
# reduce_treatment_only_design_fast(), and the serial path of par_lapply()
# (ordering, empty input, seeding with RNG restoration, thread-budget override
# restoration, deadline-forced serial execution). None had a direct test
# reference beyond incidental use.

base_priv <- function(n = 20L, seed = 123L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = seed)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(w + rnorm(n, sd = 0.5))
	inf <- InferenceAllSimpleAverageDiff$new(des)
	inf$num_cores <- 1L
	list(inf = inf, priv = inf$.__enclos_env__$private)
}

test_that("estimate-stage and SE-stage non-estimability set the documented cached fields and accessors", {
	f <- base_priv()
	expect_false(f$inf$is_nonestimable())
	expect_null(f$inf$get_nonestimable_reason())

	f$priv$cache_nonestimable_estimate("no_fit")
	cv <- f$priv$cached_values
	expect_true(is.na(cv$beta_hat_T) && is.na(cv$s_beta_hat_T) && is.na(cv$df))
	expect_true(f$inf$is_nonestimable())
	expect_true(f$inf$is_nonestimable("estimate"))
	expect_false(f$inf$is_nonestimable("se"))
	expect_equal(f$inf$get_nonestimable_reason(), "no_fit")
	expect_equal(f$inf$get_nonestimable_stage(), "estimate")

	f$priv$cache_nonestimable_se("se_broke")
	expect_true(f$inf$is_nonestimable("se"))
	expect_false(f$inf$is_nonestimable("estimate"))
	expect_equal(f$inf$get_nonestimable_reason(), "se_broke")
	expect_equal(f$inf$get_nonestimable_stage(), "se")

	expect_error(f$inf$is_nonestimable("bogus"))
	expect_invisible(f$priv$clear_nonestimable_state())
	expect_false(f$inf$is_nonestimable())
	expect_null(f$inf$get_nonestimable_reason())
	expect_null(f$inf$get_nonestimable_stage())
})

test_that("SE-stage non-estimability keeps an existing point estimate and df, estimate-stage overwrites them", {
	f <- base_priv()
	f$priv$cached_values$beta_hat_T <- 0.7
	f$priv$cached_values$df <- 12
	f$priv$cache_nonestimable_se()
	expect_equal(f$priv$cached_values$beta_hat_T, 0.7)
	expect_equal(f$priv$cached_values$df, 12)
	expect_true(is.na(f$priv$cached_values$s_beta_hat_T))
	expect_equal(f$inf$get_nonestimable_reason(), "standard_error_unavailable")

	f$priv$cache_nonestimable_estimate()
	expect_true(is.na(f$priv$cached_values$beta_hat_T))
	expect_equal(f$priv$cached_values$df, 12)                       # an existing df is left alone
	expect_equal(f$inf$get_nonestimable_reason(), "not_estimable")

	g <- base_priv()
	g$priv$cache_nonestimable_se("x")
	expect_true(is.na(g$priv$cached_values$beta_hat_T))              # missing estimate becomes NA
	expect_true(is.na(g$priv$cached_values$df))
	g$priv$cache_nonestimable_estimate(c("first", "second"))
	expect_equal(g$inf$get_nonestimable_reason(), "first")
})

test_that("C++ thread sizing is one thread per ten work items, capped by num_cores and at least one", {
	f <- base_priv()
	f$inf$num_cores <- 8L
	expect_equal(f$priv$n_cpp_threads(5), 1L)
	expect_equal(f$priv$n_cpp_threads(10), 1L)
	expect_equal(f$priv$n_cpp_threads(35), 3L)
	expect_equal(f$priv$n_cpp_threads(1000), 8L)
	f$inf$num_cores <- 2L
	expect_equal(f$priv$n_cpp_threads(1000), 2L)
})

test_that("effective_parallel_cores forces serial execution only when the dispatch policy says so", {
	f <- base_priv()
	unlockBinding("parallel_dispatch_policy", f$priv)
	f$priv$parallel_dispatch_policy <- function(operation) list(force_serial = identical(operation, "serial_only"))
	expect_equal(f$priv$effective_parallel_cores("serial_only", 6L), 1L)
	expect_equal(f$priv$effective_parallel_cores("free", 6L), 6L)
	expect_equal(f$priv$effective_parallel_cores("free", 0L), 1L)
	expect_equal(f$priv$effective_parallel_cores("serial_only", 1L), 1L)
	f$inf$num_cores <- 3L
	expect_equal(f$priv$effective_parallel_cores("free"), 3L)
	expect_equal(f$priv$effective_parallel_cores("serial_only"), 1L)
})

test_that("reduce_treatment_only_design_fast classifies intercept + treatment designs", {
	f <- base_priv()
	fast <- f$priv$reduce_treatment_only_design_fast
	varying <- cbind(1, c(0, 1, 0, 1))
	out <- fast(varying)
	expect_equal(out$keep, c(1L, 2L))
	expect_equal(out$j_treat, 2L)
	expect_equal(out$X, varying)
	expect_equal(f$priv$reduced_design_keep_cache, c(1L, 2L))

	constant_treatment <- fast(cbind(1, c(1, 1, 1)))
	expect_null(constant_treatment$X)
	expect_equal(constant_treatment$keep, 1L)
	expect_true(is.na(constant_treatment$j_treat))

	expect_null(fast(cbind(1, c(0, 1), 3)))                       # wrong width
	expect_null(fast(matrix(numeric(0), 0, 2)))                   # no rows
	expect_null(fast(cbind(c(1, 2, 1), c(0, 1, 0))))              # non-constant "intercept"
	expect_null(fast(cbind(1, c(0, NA, 1))))                      # non-finite
	expect_null(fast(1:4))                                        # no dim
})

test_that("serial par_lapply preserves order, handles empty input and returns plain list results", {
	f <- base_priv()
	expect_equal(f$priv$par_lapply(list(), function(x) x), list())
	out <- f$priv$par_lapply(1:7, function(i) i^2, n_cores = 1L)
	expect_equal(out, as.list((1:7)^2))
	expect_equal(f$priv$par_lapply(list(a = 1, b = 2), function(x) x + 1, n_cores = 1L), list(a = 2, b = 3))   # serial path keeps input names
	expect_error(f$priv$par_lapply(1:3, function(i) if (i == 2) stop("worker failed") else i, n_cores = 1L), "worker failed")
})

test_that("serial par_lapply seeds from the object's seed, restores the caller's RNG state, and restores the thread budget", {
	f <- base_priv()
	f$priv$seed <- 99L
	set.seed(1)
	before <- .Random.seed
	a <- unlist(f$priv$par_lapply(1:4, function(i) runif(1), n_cores = 1L))
	expect_identical(.Random.seed, before)                              # caller's stream untouched
	b <- unlist(f$priv$par_lapply(1:4, function(i) runif(1), n_cores = 1L))
	expect_equal(a, b)                                                  # same seed -> same draws
	set.seed(99)
	expect_equal(a, runif(4))

	edi_env <- asNamespace("EDI")$edi_env
	prev <- edi_env$num_cores_override
	seen <- NULL
	f$priv$par_lapply(1:2, function(i) { seen <<- get("num_cores_override", envir = edi_env); i }, n_cores = 1L, budget = 3L)
	expect_equal(seen, 3L)
	expect_identical(edi_env$num_cores_override, prev)
})

test_that("a global CI deadline forces serial execution and aborts once it has passed", {
	f <- base_priv()
	now <- unname(proc.time()[["elapsed"]])
	withr::local_options(list(EDI.ci_timeout_deadline = now + 1000))
	expect_equal(unlist(f$priv$par_lapply(1:5, function(i) i * 2, n_cores = 4L)), (1:5) * 2)
	withr::local_options(list(EDI.ci_timeout_deadline = now - 1))
	expect_error(f$priv$par_lapply(1:3, function(i) i, n_cores = 4L), "Parallel task reached elapsed time limit")
})
