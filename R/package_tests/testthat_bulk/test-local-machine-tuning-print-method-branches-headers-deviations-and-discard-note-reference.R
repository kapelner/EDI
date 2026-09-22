library(testthat)
library(EDI)

# print.EDILocalMachineTuning: the printed report for synthetic tuning objects. Checks (against hand-written expected lines) the header (dry-run tag, run
# time, EDI version, effort, cell count and formatted elapsed time), the machine line ("?" placeholders for missing fingerprint fields), the File line
# (only for saved runs), each deviation family (cold start, optimizer, warm start with n-range, parallel crossover + preferred core count), the "(none ...)"
# note when there are no deviations, and the plural / singular correctness-gate discard note. The method returns its argument invisibly.

mk <- function(...) {
	base <- list(timestamp = as.POSIXct("2026-09-22 10:11:12", tz = "UTC"), edi_version = "1.0.1", effort = "standard", n_cells = 12L,
		elapsed_secs_total = 125, hardware_fingerprint = list(cpu_model = "TestCPU", logical_cores = 8L, physical_cores = 4L, blas = "MKL"),
		config_path = "/tmp/edi-config/tuning.rds", dry_run = FALSE, policy_diffs = list(), n_discarded_by_correctness_gate = 0L)
	x <- utils::modifyList(base, list(...), keep.null = TRUE)
	class(x) <- "EDILocalMachineTuning"
	x
}
out <- function(x) paste(capture.output(res <- print(x)), collapse = "\n")

test_that("header, machine and file lines; no deviations prints the (none ...) note; returns its argument invisibly", {
	x <- mk()
	txt <- out(x)
	expect_match(txt, "EDI local machine tuning", fixed = TRUE)
	expect_false(grepl("dry run", txt))
	expect_match(txt, "Run: 2026-09-22 10:11:12 | EDI 1.0.1 | effort = standard | 12 cells in 2min 5s", fixed = TRUE)
	expect_match(txt, "Machine: TestCPU | 8 logical / 4 physical cores | BLAS: MKL", fixed = TRUE)
	expect_match(txt, "File: /tmp/edi-config/tuning.rds", fixed = TRUE)
	expect_match(txt, "Deviations from shipped defaults:", fixed = TRUE)
	expect_match(txt, "(none -- the shipped defaults already win on this machine)", fixed = TRUE)
	expect_identical(withVisible(print(x))$visible, FALSE)
	invisible(capture.output(expect_identical(print(x), x)))
})

test_that("dry runs are tagged and have no File line; missing fingerprint fields and version print as '?'", {
	txt <- out(mk(dry_run = TRUE, edi_version = NULL, hardware_fingerprint = list(cpu_model = NULL, logical_cores = NULL, physical_cores = NULL, blas = NULL), elapsed_secs_total = 42))
	expect_match(txt, "(dry run -- not saved, not applied)", fixed = TRUE)
	expect_false(grepl("File:", txt, fixed = TRUE))
	expect_match(txt, "EDI ? | effort", fixed = TRUE)
	expect_match(txt, "Machine: ? | ? logical / ? physical cores | BLAS: ?", fixed = TRUE)
	expect_match(txt, "12 cells in 42s", fixed = TRUE)
	expect_false(grepl("Machine:", out(mk(hardware_fingerprint = NULL)), fixed = TRUE))
})

test_that("every deviation family prints its own line format", {
	d <- list(
		cold_start = list(inference_class_overrides = list(InferenceCountPoisson = FALSE, InferenceIncidLogRegr = TRUE)),
		optimizer = list(inference_class_overrides = list(InferenceOrdinalPropOddsRegr = "lbfgs")),
		warm_start = list(bootstrap = list(n_conditioned_overrides = list(list(pattern = "InferenceContin.*", value = FALSE, n_min = 50, n_max = 400)))),
		parallel = list(crossover = list(list(class = "InferenceContinOLS", operation = "bootstrap", num_cores = 4L, crossover_n = 500L, rel_improvement = 0.234)),
			preferred_num_cores = 4L))
	txt <- out(mk(policy_diffs = d))
	expect_false(grepl("(none --", txt, fixed = TRUE))
	expect_match(txt, "cold start : InferenceCountPoisson", fixed = TRUE); expect_match(txt, "smart_cold_start = FALSE", fixed = TRUE)
	expect_match(txt, "cold start : InferenceIncidLogRegr", fixed = TRUE); expect_match(txt, "smart_cold_start = TRUE", fixed = TRUE)
	expect_match(txt, "optimizer  : InferenceOrdinalPropOddsRegr", fixed = TRUE); expect_match(txt, "algorithm = lbfgs", fixed = TRUE)
	expect_match(txt, "warm start : InferenceContin.*", fixed = TRUE); expect_match(txt, "(bootstrap)", fixed = TRUE)
	expect_match(txt, "warm_start = FALSE for n in [50, 400)", fixed = TRUE)
	expect_match(txt, "parallel   : InferenceContinOLS", fixed = TRUE); expect_match(txt, "(bootstrap)", fixed = TRUE)
	expect_match(txt, "4 cores beat serial from n = 500 (23% faster)", fixed = TRUE)
	expect_match(txt, "preferred core count = 4 (recorded only; opt in via set_num_cores())", fixed = TRUE)
})

test_that("the correctness-gate discard note is pluralised and hidden at zero", {
	expect_false(grepl("discarded by the correctness gate", out(mk()), fixed = TRUE))
	expect_match(out(mk(n_discarded_by_correctness_gate = 1L)), "(1 timing win discarded by the correctness gate", fixed = TRUE)
	expect_match(out(mk(n_discarded_by_correctness_gate = 3L)), "(3 timing wins discarded by the correctness gate", fixed = TRUE)
})
