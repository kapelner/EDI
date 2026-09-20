library(testthat)
library(EDI)

# local_machine_tuning_persistence.R's edi_tuning_build_policy_diffs() (the
# assembler that turns every axis's raw deviations into one setter-shaped diff
# list) and edi_tuning_skip_requested() (the env-var opt-out for load-time
# import). The per-axis converters it delegates to were already tested one by
# one; the assembly wiring and the env-var parsing had no direct reference.
# Expected structures are written out by hand from the documented rules.

dev_cs <- function(cls, n, to) list(class = cls, n = n, to = to)

test_that("no axis results (or empty axes) give an all-NULL diff list", {
	empty <- EDI:::edi_tuning_build_policy_diffs(list())
	expect_named(empty, c("cold_start", "warm_start", "optimizer", "parallel"))
	expect_true(all(vapply(empty, is.null, logical(1))))

	none <- EDI:::edi_tuning_build_policy_diffs(list(
		cold_start = list(deviations = list(), n_grid = c(100, 200)),
		warm_start = list(deviations = list(), n_grid = c(100, 200)),
		optimizer = list(deviations = list(), n_grid = c(100, 200)),
		parallel = list(deviations = list())
	))
	expect_true(all(vapply(none, is.null, logical(1))))
})

test_that("cold-start and optimizer diffs keep only classes that won at every tested n with one target value", {
	grid <- c(100, 200)
	cold <- list(
		dev_cs("ClassA", 100, TRUE), dev_cs("ClassA", 200, TRUE),   # wins everywhere -> kept
		dev_cs("ClassB", 100, TRUE)                                # only one n -> dropped
	)
	opt <- list(
		dev_cs("ClassC", 100, "lbfgs"), dev_cs("ClassC", 200, "lbfgs"),  # kept
		dev_cs("ClassD", 100, "lbfgs"), dev_cs("ClassD", 200, "irls")    # disagreeing targets -> dropped
	)
	d <- EDI:::edi_tuning_build_policy_diffs(list(
		cold_start = list(deviations = cold, n_grid = grid),
		optimizer = list(deviations = opt, n_grid = grid)
	))
	expect_identical(d$cold_start, list(inference_class_overrides = c("^ClassA$" = TRUE)))
	expect_identical(d$optimizer, list(inference_class_overrides = c("^ClassC$" = "lbfgs")))
	expect_null(d$warm_start)
	expect_null(d$parallel)

	# An axis whose deviations all fail the rule collapses to NULL, not an empty list.
	d2 <- EDI:::edi_tuning_build_policy_diffs(list(
		cold_start = list(deviations = list(dev_cs("ClassB", 100, TRUE)), n_grid = grid)
	))
	expect_null(d2$cold_start)
})

test_that("warm-start deviations become half-open n-conditioned rules keyed by operation", {
	grid <- c(100, 200, 400)
	ws <- list(
		fit = list(dev_cs("ClassX", 100, TRUE), dev_cs("ClassY", 400, FALSE)),
		refit = list(dev_cs("ClassX", 200, TRUE)),
		unused = list()
	)
	d <- EDI:::edi_tuning_build_policy_diffs(list(warm_start = list(deviations = ws, n_grid = grid)))
	expect_named(d$warm_start, c("fit", "refit"))
	expect_equal(d$warm_start$fit$n_conditioned_overrides, list(
		list(pattern = "^ClassX$", value = TRUE, n_min = 100L, n_max = 200L),
		list(pattern = "^ClassY$", value = FALSE, n_min = 400L, n_max = Inf)
	))
	expect_equal(d$warm_start$refit$n_conditioned_overrides, list(
		list(pattern = "^ClassX$", value = TRUE, n_min = 200L, n_max = 400L)
	))
})

test_that("parallel diff records crossovers and prefers the core count with the best mean gain (ties -> fewer cores)", {
	par_dev <- function(cores, gain, cls = "ClassP") {
		list(class = cls, response_type = "continuous", operation = "boot", num_cores = cores,
			crossover_n = 500L, rel_improvement = gain)
	}
	d <- EDI:::edi_tuning_build_policy_diffs(list(
		parallel = list(deviations = list(par_dev(2L, 0.10), par_dev(4L, 0.30), par_dev(4L, 0.20), par_dev(8L, 0.25)))
	))
	expect_equal(d$parallel$preferred_num_cores, 4L)          # mean 0.25 ties with 8 cores' 0.25 -> fewer cores
	expect_length(d$parallel$crossover, 4L)
	expect_equal(d$parallel$crossover[[2]], list(class = "ClassP", response_type = "continuous",
		operation = "boot", num_cores = 4L, crossover_n = 500L, rel_improvement = 0.30))

	d2 <- EDI:::edi_tuning_build_policy_diffs(list(parallel = list(deviations = list(par_dev(2L, 0.5), par_dev(8L, 0.1)))))
	expect_equal(d2$parallel$preferred_num_cores, 2L)
})

test_that("all four axes assemble together without interfering", {
	d <- EDI:::edi_tuning_build_policy_diffs(list(
		cold_start = list(deviations = list(dev_cs("A", 100, TRUE)), n_grid = 100),
		warm_start = list(deviations = list(fit = list(dev_cs("A", 100, TRUE))), n_grid = 100),
		optimizer = list(deviations = list(dev_cs("B", 100, "lbfgs")), n_grid = 100),
		parallel = list(deviations = list(list(class = "A", response_type = "count", operation = "rand",
			num_cores = 2L, crossover_n = 50L, rel_improvement = 0.2)))
	))
	expect_false(any(vapply(d, is.null, logical(1))))
	expect_equal(names(d$cold_start$inference_class_overrides), "^A$")
	expect_equal(d$warm_start$fit$n_conditioned_overrides[[1]]$n_max, Inf)
	expect_equal(names(d$optimizer$inference_class_overrides), "^B$")
	expect_equal(d$parallel$preferred_num_cores, 2L)
})

test_that("edi_tuning_skip_requested parses the opt-out env var (unset/0/false/no are off, other non-empty values on)", {
	var <- EDI:::EDI_TUNING_SKIP_ENV_VAR
	expect_true(is.character(var) && length(var) == 1L && nzchar(var))
	withr::with_envvar(stats::setNames(list(NA), var), expect_false(EDI:::edi_tuning_skip_requested()))
	for (off in c("", "0", "false", "FALSE", "no", "No", "  no  ", " 0 ")) {
		withr::with_envvar(stats::setNames(list(off), var), expect_false(EDI:::edi_tuning_skip_requested(), info = off))
	}
	for (on in c("1", "true", "TRUE", "yes", "anything")) {
		withr::with_envvar(stats::setNames(list(on), var), expect_true(EDI:::edi_tuning_skip_requested(), info = on))
	}
})
