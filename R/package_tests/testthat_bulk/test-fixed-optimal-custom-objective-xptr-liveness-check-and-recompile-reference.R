library(testthat)
library(EDI)

# DesignFixedOptimal$ensure_custom_objective_xptr_live(): a one-time probe of the custom
# objective's external pointer (evaluated on a w vector with the first n_T entries set),
# rethrowing unrelated errors, explaining the saveRDS()/readRDS() failure when no C++
# source is retained, and recompiling from retained source. Driven with mocked
# eval_custom_design_objective_cpp / RcppXPtrUtils::cppXPtr so nothing is compiled.
# Also prepare_for_resampling_replay() and the trivial getters.

mk <- function() {
	des <- DesignFixedOptimal$new(response_type = "continuous", n = 8L, objective = "mahal_dist",
		solver = "ompr", verbose = FALSE, seed = 1L)
	list(des = des, p = des$.__enclos_env__$private)
}
X8 <- matrix(seq_len(16), 8, 2)

test_that("a live pointer is probed once, with the first n_T entries of w set, and is never re-probed", {
	f <- mk()
	f$p$custom_objective_normalized <- list(xptr = "PTR", src = "SRC")
	seen <- list()
	local_mocked_bindings(eval_custom_design_objective_cpp = function(xptr, X, w) {
		seen[[length(seen) + 1L]] <<- list(xptr = xptr, X = X, w = w); 0
	}, .package = "EDI")
	expect_null(f$p$ensure_custom_objective_xptr_live(X8, 3L))
	expect_length(seen, 1L)
	expect_equal(seen[[1]]$xptr, "PTR")
	expect_equal(seen[[1]]$X, X8)
	expect_equal(seen[[1]]$w, c(1, 1, 1, 0, 0, 0, 0, 0))
	expect_true(f$p$custom_objective_checked)
	f$p$ensure_custom_objective_xptr_live(X8, 3L)
	expect_length(seen, 1L)
})

test_that("errors unrelated to a dead pointer propagate", {
	f <- mk()
	f$p$custom_objective_normalized <- list(xptr = "PTR", src = "SRC")
	local_mocked_bindings(eval_custom_design_objective_cpp = function(...) stop("dimension mismatch"), .package = "EDI")
	expect_error(f$p$ensure_custom_objective_xptr_live(X8, 3L), "dimension mismatch")
})

test_that("a dead pointer with no retained source gives the save/load explanation", {
	f <- mk()
	f$p$custom_objective_normalized <- list(xptr = "PTR", src = NULL)
	local_mocked_bindings(eval_custom_design_objective_cpp = function(...) stop("external pointer is not valid"), .package = "EDI")
	expect_error(f$p$ensure_custom_objective_xptr_live(X8, 3L), "saveRDS\\(\\)/readRDS\\(\\)'d across R sessions")
	expect_error({ f$p$custom_objective_checked <- FALSE; f$p$ensure_custom_objective_xptr_live(X8, 3L) }, "fresh cppXPtr\\(\\) call")
})

test_that("a dead pointer with retained source is recompiled with RcppEigen and stored", {
	skip_if_not_installed("RcppXPtrUtils")
	f <- mk()
	f$p$custom_objective_normalized <- list(xptr = "OLD", src = "double f() { return 0; }")
	local_mocked_bindings(eval_custom_design_objective_cpp = function(...) stop("External pointer is not valid"), .package = "EDI")
	args <- NULL
	local_mocked_bindings(cppXPtr = function(code, depends, ...) { args <<- list(code = code, depends = depends); "NEW" }, .package = "RcppXPtrUtils")
	f$p$ensure_custom_objective_xptr_live(X8, 2L)
	expect_equal(args$code, "double f() { return 0; }")
	expect_equal(args$depends, "RcppEigen")
	expect_equal(f$p$custom_objective_normalized$xptr, "NEW")
	expect_equal(f$p$custom_objective_normalized$src, "double f() { return 0; }")
})

test_that("prepare_for_resampling_replay switches on the replicate mode; getters expose the constructor arguments", {
	f <- mk()
	expect_false(f$p$brt_replicate_mode)
	expect_null(f$des$prepare_for_resampling_replay())
	expect_true(f$p$brt_replicate_mode)
	expect_equal(f$des$get_solver(), "ompr")
	expect_equal(f$des$get_objective(), "mahal_dist")
	expect_identical(f$des$get_mirror_coin(), f$p$mirror_coin)
	expect_false(f$des$supports_randomization_draw())
})
