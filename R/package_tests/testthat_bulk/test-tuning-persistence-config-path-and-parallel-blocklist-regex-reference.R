library(testthat)
library(EDI)

# local_machine_tuning_persistence.R: edi_tuning_config_dir()/edi_tuning_config_path()
# (override vs the per-user config dir) and the pattern semantics of the parallel
# blocklist check inside edi_tuning_assert_diffs_respect_untunable(): PCRE class
# patterns incl. the negative lookahead that exempts KK survival classes, the
# response-type rule, multi-entry diffs, and checking against the SHIPPED
# (not the live, user-modified) policy.

Z <- function(x) get(x, envir = asNamespace("EDI"))

par_diff <- function(...) {
	entries <- lapply(list(...), function(e) c(list(num_cores = 2L, crossover_n = 200L, rel_improvement = 0.3), e))
	list(parallel = list(crossover = entries, preferred_num_cores = 2L))
}

test_that("config dir is the override when set, else the R user config dir; the path appends the file name", {
	env <- Z("edi_env")
	old <- env$tuning_config_dir_override
	on.exit(env$tuning_config_dir_override <- old, add = TRUE)
	env$tuning_config_dir_override <- NULL
	expect_equal(Z("edi_tuning_config_dir")(), tools::R_user_dir("EDI", which = "config"))
	expect_equal(Z("edi_tuning_config_path")(), file.path(tools::R_user_dir("EDI", which = "config"), "machine_policies.rds"))
	tmp <- file.path(tempdir(), "edi-cfg-override")
	env$tuning_config_dir_override <- tmp
	expect_equal(Z("edi_tuning_config_dir")(), tmp)
	expect_equal(Z("edi_tuning_config_path")(), file.path(tmp, Z("EDI_TUNING_CONFIG_FILENAME")))
})

test_that("blocklist patterns are PCRE: KK survival classes escape the bootstrap serial rule, non-KK ones do not", {
	chk <- Z("edi_tuning_assert_diffs_respect_untunable")
	blocked <- function(cls, rt, op) tryCatch({ chk(par_diff(list(class = cls, response_type = rt, operation = op))); FALSE },
		error = function(e) grepl("parallel-SAFETY", conditionMessage(e)))
	expect_true(blocked("InferenceSurvivalCoxPHRegr", "survival", "bootstrap"))
	expect_true(blocked("InferenceSurvivalWeibullRegr", "survival", "bootstrap"))
	expect_false(blocked("InferenceSurvivalKKCoxOneLik", "survival", "bootstrap"))     # (?!.*KK) exempts it
	expect_true(blocked("InferenceAllKKWilcoxIVWC", "continuous", "bootstrap"))        # anchored exact-name rule
	expect_false(blocked("InferenceAllKKWilcoxIVWCExtra", "continuous", "bootstrap"))  # ^...$ does not match a longer name
	expect_true(blocked("InferenceIncidFoo", "continuous", "rand_ci"))                 # class prefix rule
	expect_true(blocked("SomeCustomClass", "incidence", "rand_ci"))                    # response-type rule alone
	expect_false(blocked("InferenceCountPoisson", "count", "bootstrap"))
	expect_false(blocked("InferenceSurvivalCoxPHRegr", "survival", "rand_ci"))         # only blocklisted for bootstrap
})

test_that("every entry of a multi-entry diff is checked, in order, and a clean list passes", {
	chk <- Z("edi_tuning_assert_diffs_respect_untunable")
	ok <- list(class = "InferenceCountPoisson", response_type = "count", operation = "bootstrap")
	bad <- list(class = "InferenceIncidLogRegr", response_type = "incidence", operation = "rand_ci")
	expect_true(chk(par_diff(ok, ok)))
	expect_error(chk(par_diff(ok, bad)), "InferenceIncidLogRegr \\(incidence, operation `rand_ci`\\)")
	expect_error(chk(par_diff(bad, ok)), "parallel-SAFETY")
	# A parallel section with no crossover entries, or an empty list, never trips the check.
	expect_true(chk(list(parallel = list(crossover = list(), preferred_num_cores = 2L))))
	expect_true(chk(list()))
	expect_error(chk(list(1, 2)))                                                       # must be a named list
})

test_that("the check uses the shipped policy even if the live blocklist was loosened", {
	chk <- Z("edi_tuning_assert_diffs_respect_untunable")
	env <- Z("edi_env")
	old <- env$parallel_dispatch_policy_config
	on.exit(env$parallel_dispatch_policy_config <- old, add = TRUE)
	suppressWarnings(try(set_parallel_dispatch_policy(list(bootstrap = list(serial_inference_class_patterns = character(0),
		serial_response_types = character(0)))), silent = TRUE))
	expect_error(chk(par_diff(list(class = "InferenceIncidLogRegr", response_type = "incidence", operation = "bootstrap"))), "parallel-SAFETY")
})
