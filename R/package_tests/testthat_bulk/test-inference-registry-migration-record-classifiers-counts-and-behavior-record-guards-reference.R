library(testthat)
library(EDI)

# Pure classification / counting helpers of the inference class registry
# (inference_no_likelihood_group, is_kk_inference_migration_record,
# count_inference_migration_records_by) and the guard + shape contract of the
# build_*_behavior_record builders. None had a direct test reference.

ns <- function(x) get(x, envir = asNamespace("EDI"))

test_that("inference_no_likelihood_group applies its priority order exact > randomization > jackknife/asymptotic > pure", {
	g <- ns("inference_no_likelihood_group")
	expect_equal(g(list(name = "Foo", target_capabilities = "exact_test")), "exact")
	expect_equal(g(list(name = "InferenceIncidExactFisher")), "exact")          # name match alone
	expect_equal(g(list(name = "Foo", target_capabilities = c("randomization_test", "exact_test"))), "exact")
	expect_equal(g(list(name = "Foo", target_capabilities = "randomization_test")), "randomization")
	expect_equal(g(list(name = "Foo", current_ancestors = c("InferenceRand", "InferenceAsymp"))), "randomization")
	expect_equal(g(list(name = "Foo", target_capabilities = "jackknife")), "jackknife_asymptotic")
	expect_equal(g(list(name = "Foo", target_capabilities = "wald")), "jackknife_asymptotic")
	expect_equal(g(list(name = "Foo", current_ancestors = "InferenceJackknife")), "jackknife_asymptotic")
	expect_equal(g(list(name = "Foo", current_ancestors = "InferenceAsymp")), "jackknife_asymptotic")
	expect_equal(g(list(name = "Foo")), "pure_estimator")
	expect_equal(g(list(name = "Foo", target_capabilities = "bayesian_bootstrap", current_ancestors = "Other")), "pure_estimator")
})

test_that("is_kk_inference_migration_record matches KK/IVWC by name, ancestor or target component prefix", {
	k <- ns("is_kk_inference_migration_record")
	expect_true(k(list(name = "InferenceContinKKOls", current_ancestors = character(), target_components = character())))
	expect_true(k(list(name = "InferenceFooIVWC", current_ancestors = character(), target_components = character())))
	expect_true(k(list(name = "Foo", current_ancestors = c("A", "InferenceKKBase"), target_components = character())))
	expect_true(k(list(name = "Foo", current_ancestors = "A", target_components = c("Wald", "KKMatching"))))
	expect_false(k(list(name = "Foo", current_ancestors = "A", target_components = c("Wald", "NotKK"))))   # ^KK is anchored
	expect_false(k(list(name = "Foo", current_ancestors = character(), target_components = character())))
})

test_that("count_inference_migration_records_by tallies values in decreasing frequency and handles no values", {
	cnt <- ns("count_inference_migration_records_by")
	recs <- list(list(g = c("a", "b")), list(g = "a"), list(g = c("a", "c", "b")))
	out <- cnt(recs, function(r) r$g, "grp")
	expect_s3_class(out, "data.frame")
	expect_equal(names(out), c("metric", "value", "n"))
	expect_equal(out$value, c("a", "b", "c"))
	expect_equal(out$n, c(3L, 2L, 1L))
	expect_true(all(out$metric == "grp"))
	expect_type(out$n, "integer")

	empty <- cnt(list(list(g = character()), list(g = NULL)), function(r) r$g, "grp")
	expect_equal(nrow(empty), 0L)
	expect_equal(names(empty), c("metric", "value", "n"))
	expect_equal(nrow(cnt(list(), function(r) r$g, "grp")), 0L)
})

test_that("behavior-record builders reject unregistered class names", {
	expect_error(ns("build_exact_incidence_behavior_record")("NotAClass"), "not a registered exact incidence class")
	expect_error(ns("build_simple_estimator_behavior_record")("NotAClass"), "not a registered simple estimator migration target")
})

test_that("an exact-incidence behavior record is internally consistent with its registered target", {
	nm <- ns("EDI_EXACT_INCIDENCE_CLASS_NAMES")[1]
	rec <- ns("build_exact_incidence_behavior_record")(nm)
	expect_equal(rec$name, nm)
	tgt <- ns("EDI_EXACT_INCIDENCE_TARGETS")[[nm]]
	expect_equal(rec$intentional_capabilities, tgt$intentional_capabilities)
	expect_equal(rec$target_components, tgt$target_components)
	expect_equal(rec$legacy_optional_surface, setdiff(rec$current_public_optional_methods, rec$intentional_public_methods))
	expect_identical(rec$current_public_optional_methods, sort(unique(rec$current_public_optional_methods)))
	expect_true(all(rec$current_public_optional_methods %in% ns("inference_public_method_names")(nm)))

	man <- ns("exact_incidence_behavior_manifest")()
	expect_equal(names(man), ns("EDI_EXACT_INCIDENCE_CLASS_NAMES"))
	expect_equal(man[[nm]], rec)
})
