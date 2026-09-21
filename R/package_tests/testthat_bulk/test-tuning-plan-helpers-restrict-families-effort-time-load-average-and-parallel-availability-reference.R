library(testthat)
library(EDI)

# local_machine_tuning.R small plan helpers: edi_tuning_restrict_families, edi_tuning_effort_nominal_time,
# edi_tuning_machine_load (vs /proc/loadavg / mocked uptime), edi_tuning_parallel_axis_available (vs base R),
# edi_tuning_quick_warm_start_families (subset + pattern semantics).

Z <- function(x) get(x, envir = asNamespace("EDI"))

test_that("restrict_families: NULL keeps everything; a class list filters rows, keeps columns, ignores unknown names", {
	f <- data.frame(class = c("A", "B", "C", "B"), response_type = c("x", "y", "z", "w"), stringsAsFactors = FALSE)
	r <- Z("edi_tuning_restrict_families")
	expect_identical(r(f, NULL), f)
	out <- r(f, c("B", "Nope"))
	expect_identical(out$class, c("B", "B")); expect_identical(out$response_type, c("y", "w"))
	expect_identical(names(out), names(f))
	expect_identical(nrow(r(f, character(0))), 0L)
	expect_identical(names(r(f, character(0))), names(f))
	expect_identical(r(f, c("A", "B", "C")), f)
})

test_that("effort nominal time strings per tier, 'unknown' otherwise", {
	t <- Z("edi_tuning_effort_nominal_time")
	expect_identical(t("quick"), "roughly 2-5 minutes")
	expect_identical(t("standard"), "roughly 15-30 minutes")
	expect_identical(t("thorough"), "roughly 1-2 hours")
	expect_identical(t("bogus"), "unknown")
	presets <- names(Z("edi_tuning_effort_presets")())
	expect_true(all(vapply(presets, function(p) t(p) != "unknown", NA)))      # every shipped effort tier has a time string
})

test_that("machine load equals /proc/loadavg's first field where available, else numeric-or-NA", {
	l <- Z("edi_tuning_machine_load")()
	expect_true(length(l) == 1L && (is.na(l) || (is.numeric(l) && l >= 0)))
	skip_if_not(file.exists("/proc/loadavg"))
	ref <- as.numeric(strsplit(readLines("/proc/loadavg", n = 1L), "\\s+")[[1]][1])
	expect_lt(abs(l - ref), 5)      # two reads moments apart: the 1-minute average barely moves
})

test_that("parallel axis availability is unix and >= 2 cores, and follows detectCores", {
	a <- Z("edi_tuning_parallel_axis_available")()
	expect_true(is.logical(a) && length(a) == 1L)
	expect_identical(a, identical(.Platform$OS.type, "unix") && isTRUE(parallel::detectCores() >= 2L))
})

test_that("quick warm-start narrowing keeps only classes matching the shipped warm-start table patterns", {
	q <- Z("edi_tuning_quick_warm_start_families")
	pol <- Z("get_warm_start_dispatch_policy")()
	pats <- character()
	for (op in setdiff(names(pol), "default")) {
		pats <- c(pats, names(pol[[op]]$inference_class_overrides))
		pats <- c(pats, vapply(pol[[op]]$n_conditioned_overrides %||% list(), `[[`, "", "pattern"))
	}
	pats <- unique(pats)
	skip_if(length(pats) == 0L)
	all_f <- Z("edi_tuning_live_families")()
	out <- q(all_f)
	expect_lte(nrow(out), nrow(all_f))
	expect_true(all(vapply(out$class, function(cl) any(vapply(pats, grepl, NA, x = cl, perl = TRUE)), NA)))
	dropped <- setdiff(all_f$class, out$class)
	expect_true(!any(vapply(dropped, function(cl) any(vapply(pats, grepl, NA, x = cl, perl = TRUE)), NA)))
	expect_identical(nrow(q(all_f[0, ])), 0L)
})
