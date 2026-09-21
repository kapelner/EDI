library(testthat)
library(EDI)

# edi_tuning_apply_policy_diffs(diffs): applies tuner-proposed policy diffs to the live dispatch policies. cold_start and
# optimizer diffs merge inference_class_overrides (new entries win, untouched entries survive); warm_start diffs prepend the
# new n-conditioned rules and convert a conflicting unconditional override for the same pattern into an all-n catch-all rule
# placed after the new rules but before the existing ones. Returns the applied section names invisibly. Policies are
# reset to their defaults on exit.

Z <- function(x) get(x, envir = asNamespace("EDI"))
apply_diffs <- Z("edi_tuning_apply_policy_diffs")
env <- Z("edi_env")
reset_all <- function() { set_cold_start_dispatch_policy(reset = TRUE); set_optimization_dispatch_policy(reset = TRUE); set_warm_start_dispatch_policy(reset = TRUE) }
withr::defer(reset_all(), teardown_env())

test_that("input must be a named list; an empty list applies nothing", {
	reset_all()
	expect_error(apply_diffs(list(1)))
	expect_error(apply_diffs("x"))
	r <- withVisible(apply_diffs(list()))
	expect_false(r$visible); expect_identical(r$value, character(0))
})

test_that("cold-start diff: new overrides win, existing overrides survive, section reported", {
	reset_all()
	base <- get_cold_start_dispatch_policy()$inference_class_overrides
	existing <- names(base)[1]
	new <- stats::setNames(c(!base[[existing]], TRUE), c(existing, "^InferenceTmpColdClass$"))
	r <- withVisible(apply_diffs(list(cold_start = list(inference_class_overrides = new))))
	expect_false(r$visible); expect_identical(r$value, "cold_start")
	cur <- env$cold_start_dispatch_policy_config$inference_class_overrides
	expect_identical(cur[[existing]], !base[[existing]])
	expect_true(cur[["^InferenceTmpColdClass$"]])
	expect_setequal(names(cur), union(names(base), "^InferenceTmpColdClass$"))
	expect_identical(names(cur)[1:2], names(new))                                   # new entries are placed first
	reset_all()
	expect_identical(env$cold_start_dispatch_policy_config$inference_class_overrides, base)
})

test_that("optimizer diff merges the same way", {
	reset_all()
	base <- get_optimization_dispatch_policy()$inference_class_overrides
	new <- c("^InferenceTmpOptClass$" = "irls")
	expect_identical(apply_diffs(list(optimizer = list(inference_class_overrides = new))), "optimizer")
	cur <- env$optimization_dispatch_policy_config$inference_class_overrides
	expect_identical(cur[["^InferenceTmpOptClass$"]], "irls")
	expect_true(all(names(base) %in% names(cur)))
	expect_identical(Z("edi_optimization_dispatch_policy")("InferenceTmpOptClass"), "irls")
})

test_that("warm-start diff: new n-conditioned rules come first; an unconditional override for the same pattern becomes a catch-all after them", {
	reset_all()
	op <- "rand"
	cur0 <- env$warm_start_dispatch_policy_config[[op]]
	patt <- names(cur0$inference_class_overrides)[1]
	old_value <- isTRUE(cur0$inference_class_overrides[[patt]])
	new_rules <- list(list(pattern = patt, value = !old_value, n_min = 10, n_max = 50),
		list(pattern = "^InferenceTmpWarm$", value = TRUE, n_min = 1, n_max = 5))
	r <- apply_diffs(list(warm_start = stats::setNames(list(list(n_conditioned_overrides = new_rules)), op)))
	expect_identical(r, "warm_start")
	cur <- env$warm_start_dispatch_policy_config[[op]]
	expect_false(patt %in% names(cur$inference_class_overrides))                     # conflicting unconditional entry removed
	expect_setequal(names(cur$inference_class_overrides), setdiff(names(cur0$inference_class_overrides), patt))
	rules <- cur$n_conditioned_overrides
	expect_length(rules, length(cur0$n_conditioned_overrides) + 3L)                  # 2 new + 1 catch-all + old ones
	expect_identical(rules[[1]]$pattern, patt); expect_identical(rules[[1]]$n_min, 10)
	expect_identical(rules[[2]]$pattern, "^InferenceTmpWarm$")
	catch <- rules[[3]]
	expect_identical(catch$pattern, patt); expect_identical(catch$value, old_value)
	expect_identical(catch$n_min, -Inf); expect_identical(catch$n_max, Inf)
	expect_identical(rules[[4]], cur0$n_conditioned_overrides[[1]])                 # old rules follow, unchanged
})

test_that("warm-start diff with an empty rule list is skipped but the section is still reported; multiple sections compose", {
	reset_all()
	before <- env$warm_start_dispatch_policy_config
	expect_identical(apply_diffs(list(warm_start = list(rand = list(n_conditioned_overrides = list())))), "warm_start")
	expect_identical(env$warm_start_dispatch_policy_config, before)
	both <- apply_diffs(list(cold_start = list(inference_class_overrides = c("^InferenceTmpC2$" = FALSE)),
		optimizer = list(inference_class_overrides = c("^InferenceTmpO2$" = "lbfgs"))))
	expect_identical(both, c("cold_start", "optimizer"))
})
