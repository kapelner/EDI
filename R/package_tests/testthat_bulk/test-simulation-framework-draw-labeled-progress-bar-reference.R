library(testthat)
library(EDI)

# SimulationFramework's private .draw_labeled_progress_bar(label, prop) (simulations_framework.R) had
# no test reference anywhere by name (confirmed via zero-hit grep). It is a pure string-rendering
# function -- its only side effect is a single cat() to stderr(), safe to capture and assert on
# directly without any simulation run:
#   - The rendered line is always exactly getOption("width") - 1 characters wide (right-padded with
#     spaces), prefixed with a carriage return so repeated calls overwrite the same terminal line.
#   - It embeds the floor(prop * 100) percentage, centered inside the "[===...===]" bar.
#   - prop = 0 renders an empty bar; prop = 1 renders a completely filled bar; the percentage text
#     always appears even when it would otherwise be a boundary case.

sim_fixture <- function() {
	SimulationFramework$new(
		response_type = "continuous", design_classes_and_params = list(DesignFixedBernoulli),
		inference_classes_and_params = list(InferenceAllSimpleAverageDiff),
		inference_types_and_params = list(asymp_ci = list()),
		n = 20L, p = 1L, Nrep_W = 1L, Nrep_Y_w = 1L, betaT = 0,
		results_filename = tempfile(fileext = ".csv"), continue_from_last_result_row = FALSE,
		verbose = FALSE, turn_off_asserts_for_speed = FALSE)
}

test_that("the rendered line is always exactly width - 1 characters, carriage-return-prefixed", {
	withr::local_options(width = 80L)
	priv <- sim_fixture()$.__enclos_env__$private
	for (prop in c(0, 0.25, 0.5, 0.999, 1)) {
		out <- capture.output(priv$.draw_labeled_progress_bar("Test", prop), type = "message")
		expect_length(out, 1L)
		expect_true(startsWith(out, "\r"), info = prop)
		expect_equal(nchar(sub("^\r", "", out)), 79L, info = prop)                # width (80) - 1
	}
})

test_that("the embedded percentage matches floor(prop * 100) at 0%, an interior value, and 100%", {
	withr::local_options(width = 80L)
	priv <- sim_fixture()$.__enclos_env__$private
	out0 <- capture.output(priv$.draw_labeled_progress_bar("Test", 0), type = "message")
	out50 <- capture.output(priv$.draw_labeled_progress_bar("Test", 0.5), type = "message")
	out100 <- capture.output(priv$.draw_labeled_progress_bar("Test", 1), type = "message")
	expect_match(out0, "0%", fixed = TRUE)
	expect_match(out50, "50%", fixed = TRUE)
	expect_match(out100, "100%", fixed = TRUE)
	expect_false(grepl("=", out0))                                              # empty bar: no fill characters
	expect_true(grepl("\\[={5,}", out100))                                      # full bar: mostly filled with '='
})

test_that("a longer label still produces a valid-width line with the bar shrunk to fit", {
	withr::local_options(width = 80L)
	priv <- sim_fixture()$.__enclos_env__$private
	out <- capture.output(priv$.draw_labeled_progress_bar("A Very Long Progress Label Indeed", 0.3), type = "message")
	expect_equal(nchar(sub("^\r", "", out)), 79L)
	expect_match(out, "30%", fixed = TRUE)
})
