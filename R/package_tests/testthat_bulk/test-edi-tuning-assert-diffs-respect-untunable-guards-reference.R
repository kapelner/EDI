library(testthat)
library(EDI)

# edi_tuning_assert_diffs_respect_untunable() (local_machine_tuning_persistence.R:441-459), part of
# the local-machine tuning-policy persistence layer, has two distinct validation guards on a
# proposed policy `diffs` object:
#   1. Any top-level diff name outside c("cold_start", "warm_start", "optimizer", "parallel") is
#      rejected -- "Tuner produced a diff for untunable/unknown policy surface(s): <names>. Only
#      <known> may be tuned."
#   2. Within diffs$parallel$crossover, each entry's `operation` must be a key in the shipped
#      parallel-dispatch policy (get_parallel_dispatch_policy()) -- "Parallel diff names unknown
#      operation `<op>`."
# A codebase-wide grep confirmed both exact messages had zero test references anywhere. Exercised
# via a direct namespace call with a hand-built `diffs` list, no tuning-run fixture needed --
# deliberately lightweight, avoiding this file's known-expensive real benchmark machinery.

test_that("a diff naming an untunable/unknown policy surface is rejected", {
	f <- getFromNamespace("edi_tuning_assert_diffs_respect_untunable", "EDI")
	expect_error(
		f(list(bogus_surface = list())),
		"Tuner produced a diff for untunable/unknown policy surface\\(s\\): bogus_surface\\. Only cold_start, warm_start, optimizer, parallel may be tuned\\.",
	)
})

test_that("a parallel crossover diff naming an operation absent from the shipped dispatch policy is rejected", {
	f <- getFromNamespace("edi_tuning_assert_diffs_respect_untunable", "EDI")
	expect_error(
		f(list(parallel = list(crossover = list(list(operation = "bogus_op"))))),
		"Parallel diff names unknown operation `bogus_op`\\.",
	)
})

test_that("an empty diffs list passes silently (returns TRUE)", {
	f <- getFromNamespace("edi_tuning_assert_diffs_respect_untunable", "EDI")
	expect_true(f(list()))
})
