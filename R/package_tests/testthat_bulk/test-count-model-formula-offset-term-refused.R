# v1.0.6-TODO-217 (ds-count-44883784401-f1): an offset() term in a count model formula was accepted,
# echoed by get_model_formula() and silently dropped, so Poisson / NegBin / ZIP fits "with" an offset
# equalled the fits without it. No class honours offsets yet (v1.1.0-TODO-17a), so every class now
# refuses them at $new(), whether or not assertions are on, for model_formula and for the
# zero-inflation / hurdle formulas.

make_count_design_with_followup = function(){
	set.seed(347)
	n = 60
	X = data.frame(x1 = rnorm(n), log_fu = log(runif(n, 0.5, 2)))
	des = DesignFixediBCRD$new(n = n, response_type = "count", verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	y = stats::rpois(n, exp(0.3 + 0.4 * des$get_w() + 0.2 * X$x1 + X$log_fu))
	y[seq(1, n, by = 7)] = 0L
	des$add_all_subject_responses(y)
	des
}

count_classes_for_offset_check = c(
	"InferenceCountPoisson", "InferenceCountQuasiPoisson", "InferenceCountRobustPoisson",
	"InferenceCountNegBin", "InferenceCountZeroInflatedPoisson", "InferenceCountZeroInflatedNegBin",
	"InferenceCountHurdlePoisson", "InferenceCountHurdleNegBin"
)

test_that("an offset() term in model_formula is refused by every count class", {
	des = make_count_design_with_followup()
	for (cl in count_classes_for_offset_check) {
		gen = get(cl, envir = asNamespace("EDI"))
		expect_error(gen$new(des, model_formula = ~ x1 + offset(log_fu), verbose = FALSE),
			"offset", info = cl)
		# the same formula without the offset still constructs
		expect_no_error(gen$new(des, model_formula = ~ x1, verbose = FALSE))
	}
})

test_that("an offset() term is refused even when assertions are turned off", {
	des = make_count_design_with_followup()
	old = toggle_asserts(FALSE)
	on.exit(toggle_asserts(TRUE), add = TRUE)
	expect_error(InferenceCountPoisson$new(des, model_formula = ~ x1 + offset(log_fu), verbose = FALSE), "offset")
	expect_error(InferenceCountNegBin$new(des, model_formula = ~ offset(log_fu), verbose = FALSE), "offset")
})

test_that("an offset() term in the zero-inflation or hurdle formula is refused", {
	des = make_count_design_with_followup()
	expect_error(InferenceCountZeroInflatedPoisson$new(des, model_formula = ~ x1,
		model_formula_zero = ~ offset(log_fu), verbose = FALSE), "model_formula_zero contains an offset")
	expect_error(InferenceCountZeroInflatedNegBin$new(des, model_formula = ~ x1,
		model_formula_zero = ~ offset(log_fu), verbose = FALSE), "model_formula_zero contains an offset")
	expect_error(InferenceCountHurdlePoisson$new(des, model_formula = ~ x1,
		model_formula_hurdle = ~ offset(log_fu), verbose = FALSE), "offset")
	expect_error(InferenceCountHurdleNegBin$new(des, model_formula = ~ x1,
		model_formula_hurdle = ~ offset(log_fu), verbose = FALSE), "model_formula_hurdle contains an offset")
})

test_that("a dot formula is still accepted and a dot formula with an offset is refused", {
	des = make_count_design_with_followup()
	expect_no_error(InferenceCountPoisson$new(des, model_formula = ~ ., verbose = FALSE))
	expect_error(InferenceCountPoisson$new(des, model_formula = ~ . + offset(log_fu), verbose = FALSE), "offset")
})
