library(testthat)

# v1.0.5 TODO-197: user-callable validity lookup. The public method
# Inference$get_procedure_validity() and the exported function
# get_inference_procedure_validity() read the convergence registry
# (inference_procedure_regime.R, TODO-192/193) and the realised effective n
# (inference_validity_n_eff.R). Needs the package internals: run under
# pkgload::load_all("R/EDI", compile = FALSE); skipped against an installed EDI
# that predates the lookup.

skip_if_not(exists("get_inference_procedure_validity", envir = asNamespace("EDI"), inherits = FALSE),
	"installed EDI predates get_inference_procedure_validity()")
validity_fn = get("get_inference_procedure_validity", envir = asNamespace("EDI"))

validity_cols = c("design", "class", "procedure", "supported", "regime", "size_order",
	"size_order_label", "bias_order", "n_eff_rule", "n_eff", "regularity", "basis",
	"reference", "bias_basis", "bias_reference", "size_layer", "bias_layer",
	"n_eff_layer", "regularity_layer")

make_validity_bernoulli = function(n = 40L, prob_T = 0.5) {
	set.seed(11)
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	des = EDI::DesignFixedBernoulli$new(n = n, response_type = "continuous", prob_T = prob_T, verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n) + des$get_w())
	des
}

test_that("function form: shape, no data, measured hook is NULL with a note", {
	v = validity_fn("DesignFixedBernoulli", "InferenceContinLin")
	expect_named(v, c("expectation", "measured", "measured_note"))
	expect_identical(names(v$expectation), validity_cols)
	expect_null(v$measured)
	expect_true(is.character(v$measured_note) && nzchar(v$measured_note))
	e = v$expectation
	expect_true(all(e$supported))
	expect_true(all(is.na(e$n_eff)))
	expect_true(all(c("wald", "rand") %in% e$procedure))
	expect_identical(e$regime[e$procedure == "rand"], "finite_sample")
	expect_identical(e$size_order_label[e$procedure == "rand"], "exact")
	expect_identical(e$regime[e$procedure == "wald"], "asymptotic")
	# Every value is the registry's own resolution.
	reg = EDI:::inference_convergence_expectation("DesignFixedBernoulli", "InferenceContinLin", e$procedure)
	expect_identical(e$size_order, reg$size_order)
	expect_identical(e$n_eff_rule, reg$n_eff)
	expect_identical(e$basis, reg$basis)
	expect_identical(e$reference, reg$reference)
})

test_that("function form: explicit procedure, unequal allocation label, errors", {
	w = validity_fn("DesignFixedBernoulli@prob_T=0.2", "InferenceContinLin", "wald")$expectation
	expect_identical(nrow(w), 1L)
	expect_identical(w$n_eff_rule, "n_min_arm")
	expect_identical(validity_fn("DesignFixedBernoulli", "InferenceContinLin", "wald")$expectation$n_eff_rule, "n")
	two = validity_fn("DesignFixedBernoulli", "InferenceContinLin", c("wald", "rand", "wald"))$expectation
	expect_identical(two$procedure, c("wald", "rand"))
	expect_error(validity_fn("DesignFixedBernoulli", "InferenceContinLin", "nope"), "Unknown procedure")
	expect_error(validity_fn("DesignFixedBernoulli", "InferenceNotAClass"), "not a registered")
	expect_error(validity_fn("DesignNotADesign", "InferenceContinLin"), "not a registered")
	expect_error(validity_fn("DesignFixedBernoulli", "InferenceAbstractKKCondLogitGLMM"), "abstract")
	expect_error(validity_fn(1, "InferenceContinLin"), "design")
	# An unsupported procedure still resolves, flagged.
	u = validity_fn("DesignFixedBernoulli", "InferenceContinLin", "exact")$expectation
	expect_false(u$supported)
	expect_identical(u$regime, "finite_sample")
})

test_that("default procedure set matches run_all_inference's applicability", {
	for (cls in c("InferenceContinLin", "InferenceIncidExactFisher", "InferenceSurvivalCoxPHRegr")) {
		got = validity_fn("DesignFixedBernoulli", cls)$expectation$procedure
		expect_identical(got, EDI:::run_all_inference_class_applicable_methods(cls, EDI:::EDI_INFERENCE_SUITE_METHOD_SENTINELS), info = cls)
		expect_true(length(got) > 0L, info = cls)
	}
})

test_that("method form: realised n_eff, procedure subset, same rows as the function form", {
	des = make_validity_bernoulli(40L)
	inf = EDI::InferenceContinLin$new(des)
	r = inf$get_procedure_validity()
	expect_named(r, c("expectation", "measured", "measured_note"))
	expect_identical(names(r$expectation), validity_cols)
	expect_null(r$measured)
	expect_true(all(r$expectation$supported))
	expect_true(all(r$expectation$n_eff == 40))
	expect_identical(r$expectation$class, rep("InferenceContinLin", nrow(r$expectation)))
	fn = validity_fn("DesignFixedBernoulli", "InferenceContinLin")$expectation
	# A live object may rule procedures out, never add any.
	expect_true(all(r$expectation$procedure %in% fn$procedure))
	cols = setdiff(validity_cols, c("n_eff", "supported"))
	same = fn[fn$procedure %in% r$expectation$procedure, cols]
	rownames(same) = NULL
	expect_identical(r$expectation[, cols], same)
	# Function form given the design object fills n_eff too.
	expect_true(all(validity_fn(des, "InferenceContinLin")$expectation$n_eff == 40))
	one = inf$get_procedure_validity("wald")$expectation
	expect_identical(one$procedure, "wald")
	expect_equal(one$n_eff, 40)
	expect_error(inf$get_procedure_validity("nope"), "Unknown procedure")
	expect_error(inf$get_procedure_validity(1L), "procedure")
})

test_that("method form: unequal allocation uses n_min_arm with the smaller arm's size", {
	des = make_validity_bernoulli(60L, prob_T = 0.2)
	inf = EDI::InferenceContinLin$new(des)
	w = inf$get_procedure_validity("wald")$expectation
	expect_identical(w$design, "DesignFixedBernoulli@prob_T=0.2")
	expect_identical(w$n_eff_rule, "n_min_arm")
	expect_equal(w$n_eff, min(sum(des$get_w() == 1), sum(des$get_w() == 0)))
})

test_that("method form: matched design reports n_pairs-based n_eff", {
	set.seed(5)
	n = 30L
	X = data.frame(x1 = rnorm(n))
	des = EDI::DesignFixedBinaryMatch$new(response_type = "continuous", n = n, verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n) + des$get_w())
	cls = "InferenceContinKKOLSOneLik"
	skip_if_not(exists(cls, envir = asNamespace("EDI"), inherits = FALSE))
	inf = get(cls, envir = asNamespace("EDI"))$new(des)
	w = inf$get_procedure_validity("wald")$expectation
	expect_identical(w$n_eff_rule, "n_pairs_plus_reservoir")
	expect_equal(w$n_eff, n / 2)
})
