library(testthat)
library(EDI)

# Small predicates / derivations behind the inference suite and the zero-augmented count models:
#  * inference_class_split_caps_run: greedy left-to-right split of an all-caps run into the known class acronyms (longest table order), single letters otherwise
#  * run_all_inference_derive_method_priority: passes valid sentinel specs through unchanged, errors naming the stale sentinel otherwise
#  * zero_augmented_data_has_no_mle: TRUE only for HURDLE fits whose positive counts are all exactly 1 (NA / non-positive values ignored)
#  * inference_class_accepts_model_formula: SUSPECTED SOURCE BUG (pinned, not fixed) -- it inspects formals(<R6 generator>$new), which is just `...`, so it is FALSE
#    for every class even when the class's initialize() takes model_formula.

ns <- asNamespace("EDI"); G <- function(nm) get(nm, envir = ns)

test_that("split_caps_run splits an all-caps run into the known acronyms in table order and single letters otherwise", {
	f <- G("inference_class_split_caps_run")
	expect_identical(f("KKCLMM"), c("KK", "CLMM"))
	expect_identical(f("IVWCKKGLMM"), c("IVWC", "KK", "GLMM"))
	expect_identical(f("GEE"), "GEE"); expect_identical(f("KK21"), "KK21"); expect_identical(f("KK14"), "KK14")
	expect_identical(f("XYZ"), c("X", "Y", "Z"))
	expect_identical(f("OLSRDRR"), c("OLS", "RD", "RR"))
	expect_identical(f(""), character(0))
	expect_identical(f("KKPHKMT"), c("KK", "PH", "KM", "T"))
	expect_true(all(nchar(G("EDI_INFERENCE_CLASS_ACRONYMS")) >= 1L))
})

test_that("derive_method_priority returns valid specs unchanged and names the stale sentinel in its error", {
	f <- G("run_all_inference_derive_method_priority")
	for (nm in c("EDI_INFERENCE_SUITE_CI_METHOD_PRIORITY", "EDI_INFERENCE_SUITE_PVAL_METHOD_PRIORITY")) {
		spec <- G(nm)
		expect_identical(f(spec), spec)
		expect_true(all(vapply(spec, function(e) all(c("capability", "method", "label") %in% names(e)), NA)))
	}
	bad <- list(list(label = "stale_label", method = "no_such_method", capability = "wald"))
	expect_error(f(bad), "sentinel 'stale_label' expects method 'no_such_method' registered under capability 'wald'")
	expect_error(f(list(list(label = "x", method = "compute_wald_confidence_interval", capability = "not_a_capability"))), "sentinel 'x'")
	expect_identical(f(list()), list())
})

test_that("zero_augmented_data_has_no_mle: hurdle fits whose positive counts are all one have no MLE; everything else does", {
	f <- G("zero_augmented_data_has_no_mle")
	expect_true(f(c(0, 1, 1, 0, 1), TRUE))
	expect_true(f(c(1, 1), TRUE))
	expect_false(f(c(0, 1, 2), TRUE))                                  # a count above 1 gives the truncated Poisson a finite MLE
	expect_false(f(c(1, 1, 1), FALSE))                                 # not a hurdle model
	expect_false(f(c(0, 0, 0), TRUE))                                  # no positives at all is a different degenerate case
	expect_false(f(numeric(0), TRUE))
	expect_true(f(c(NA, 1, 1, -3, 0), TRUE))                           # NA and non-positive values are ignored
	expect_false(f(c(1, 1, 2.5), TRUE))
})

test_that("SUSPECTED BUG (pinned): inference_class_accepts_model_formula is FALSE for every class, including those whose initialize() has model_formula", {
	f <- G("inference_class_accepts_model_formula")
	for (nm in c("InferenceContinOLS", "InferenceCountPoisson", "InferenceAllSimpleWilcox", "InferenceIncidLogRegr")) {
		gen <- G(nm)
		expect_identical(names(formals(gen$new)), "...")                                       # root cause: the generator's `new` has only `...`
		expect_false(f(nm), info = nm)                                                         # actual behaviour
	}
	has_formal <- vapply(c("InferenceCountPoisson", "InferenceAllSimpleWilcox"), function(nm) "model_formula" %in% names(formals(G(nm)$public_methods$initialize)), NA)
	expect_true(all(has_formal))                                                               # the intended answer is TRUE for these
})
