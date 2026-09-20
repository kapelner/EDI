library(testthat)
library(EDI)

# inference_class_registry.R: the generator-walking infer_*() functions
# (requires_blocking_design / supports_general_censoring / estimand_type), the name-based ones
# (abstract, adjusts_for_covariates), their agreement with every stored registry record,
# design-based capability exclusions, private-owner reporting and the registry / cache
# lifecycle (on a snapshot that is restored).

Z <- function(x) get(x, envir = asNamespace("EDI"))
G <- function(nm) get(nm, envir = asNamespace("EDI"))
reg_env <- function() Z("EDI_INFERENCE_CLASS_REGISTRY")

test_that("generator-walking probes reproduce the known per-class declarations", {
	expect_true(Z("infer_inference_requires_blocking_design")(G("InferenceIncidExtendedRobins")))
	expect_false(Z("infer_inference_requires_blocking_design")(G("InferenceContinOLS")))
	expect_true(Z("infer_inference_supports_general_censoring")(G("InferenceSurvivalCoxPHRegr")))
	expect_false(Z("infer_inference_supports_general_censoring")(G("InferenceContinOLS")))
	expect_equal(Z("infer_inference_estimand_type")(G("InferenceContinOLS")), "mean_difference")
	expect_equal(Z("infer_inference_estimand_type")(G("InferenceIncidExactFisher")), "log_odds_ratio_conditional")
	# An explicit name overrides the generator's own classname (the audit map is consulted by name).
	expect_equal(Z("infer_inference_estimand_type")(G("InferenceContinOLS"), name = "InferenceCountPoisson"), "log_rate_ratio_marginal")
})

test_that("name-based classifiers: abstractness and covariate use", {
	a <- Z("infer_inference_abstract")
	expect_true(a("Inference")); expect_true(a("InferenceAbstractKKOrdinalCLMM")); expect_true(a("SomethingAbstractHere"))
	expect_false(a("InferenceContinOLS"))
	for (nm in Z("EDI_INFERENCE_ABSTRACT_CLASS_NAMES")) expect_true(a(nm), info = nm)
	c1 <- Z("infer_inference_adjusts_for_covariates")
	for (nm in Z("EDI_INFERENCE_CLASSES_IGNORING_COVARIATES")) expect_false(c1(nm), info = nm)
	for (nm in Z("EDI_INFERENCE_CLASSES_USING_COVARIATES")) expect_true(c1(nm), info = nm)
	expect_true(is.na(c1("InferenceNotClassifiedAnywhere")))
})

test_that("every registered class's stored metadata agrees with the infer functions", {
	reg <- Z("inference_class_registry_as_list")()
	expect_gt(length(reg), 100L)
	for (nm in names(reg)) {
		r <- reg[[nm]]
		g <- tryCatch(G(nm), error = function(e) NULL)
		expect_equal(r$abstract, Z("infer_inference_abstract")(nm), info = nm)
		if (!is.null(g) && inherits(g, "R6ClassGenerator")) {
			expect_identical(r$requires_blocking_design, Z("infer_inference_requires_blocking_design")(g), info = nm)
			expect_identical(r$supports_general_censoring, Z("infer_inference_supports_general_censoring")(g), info = nm)
		}
		expect_identical(r$adjusts_for_covariates, Z("infer_inference_adjusts_for_covariates")(nm), info = nm)
	}
})

test_that("design exclusions: nothing for sequential Bernoulli, the table's capabilities for its listed design ancestors", {
	ex <- Z("get_design_excluded_inference_capabilities")
	seq_b <- structure(list(), class = c("DesignSeqOneByOneBernoulli", "DesignSeqOneByOne", "Design"))
	expect_identical(ex(seq_b), character())
	tbl <- Z("EDI_INFERENCE_DESIGN_EXCLUDED_CAPABILITIES")
	expect_gt(length(tbl), 0L)
	for (dc in names(tbl)) {
		obj <- structure(list(), class = c(dc, "Design"))
		expect_setequal(ex(obj), unique(as.character(unlist(tbl[[dc]]))))
	}
	expect_identical(ex(structure(list(), class = "DesignNothingListed")), character())
})

test_that("private owner names map each private member to the closest generator that defines it", {
	owners <- Z("inference_private_owner_names")("InferenceContinOLS")
	expect_true(is.list(owners) || is.character(owners) || is.data.frame(owners))
	expect_error(Z("inference_private_owner_names")("NoSuchInferenceClass"), "No R6 generator found for inference class NoSuchInferenceClass")
	expect_error(Z("inference_private_owner_names")("InferenceContinOLS", generator = list()), "is not an R6 generator")
	expect_identical(Z("inference_private_owner_names")("InferenceContinOLS", generator = G("InferenceContinOLS")), owners)
})

test_that("registry and effective-metadata caches: cleared on demand, and the registry is restorable", {
	env <- reg_env()
	snap <- mget(ls(env), envir = env, inherits = FALSE)
	on.exit({ rm(list = ls(env), envir = env); list2env(snap, envir = env); Z("clear_inference_effective_metadata_cache")() }, add = TRUE)
	Z("get_effective_components")("InferenceContinOLS")
	expect_true(exists("InferenceContinOLS", envir = Z("EDI_INFERENCE_EFFECTIVE_COMPONENTS_CACHE"), inherits = FALSE))
	expect_true(Z("clear_inference_effective_metadata_cache")())
	expect_false(exists("InferenceContinOLS", envir = Z("EDI_INFERENCE_EFFECTIVE_COMPONENTS_CACHE"), inherits = FALSE))
	expect_true(Z("clear_inference_class_registry")())
	expect_length(ls(env), 0L)
	expect_error(Z("get_inference_class_metadata")("InferenceContinOLS"))
})
