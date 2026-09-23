library(testthat)
library(EDI)

# design_class_registry.R's register_design_class() and inference_class_registry.R's
# register_inference_class() each guard against double-registering the same class name --
# "Design/Inference class metadata already registered for <name>." -- reached when the name already
# exists as a binding in the module-level registry environment (EDI_DESIGN_CLASS_REGISTRY /
# EDI_INFERENCE_CLASS_REGISTRY). Neither guard had any test references anywhere, likely because
# every real call site in the package registers a distinct name exactly once at load time. Exercised
# here by registering a throwaway class under a name guaranteed not to collide with any real
# registered class, then registering it again; the throwaway binding is always removed via on.exit,
# regardless of test outcome, so this test never leaves the shared global registry environment
# polluted for later tests in the same session.

test_that("register_design_class(): registering the same name twice errors with the documented message", {
	valid <- EDI:::get_design_class_metadata("DesignFixedBernoulli")
	meta <- valid; meta$name <- NULL
	name <- "DesignFixedBernoulliTestOnlyDuplicateProbe"
	on.exit(
		if (exists(name, envir = EDI:::EDI_DESIGN_CLASS_REGISTRY, inherits = FALSE)) {
			rm(list = name, envir = EDI:::EDI_DESIGN_CLASS_REGISTRY)
		},
		add = TRUE
	)

	expect_false(exists(name, envir = EDI:::EDI_DESIGN_CLASS_REGISTRY, inherits = FALSE))
	EDI:::register_design_class(name, parent = valid$parent, metadata = meta)
	expect_true(exists(name, envir = EDI:::EDI_DESIGN_CLASS_REGISTRY, inherits = FALSE))

	expect_error(
		EDI:::register_design_class(name, parent = valid$parent, metadata = meta),
		"Design class metadata already registered for DesignFixedBernoulliTestOnlyDuplicateProbe\\."
	)
})

test_that("register_inference_class(): registering the same name twice errors with the documented message", {
	valid <- EDI:::get_inference_class_metadata("InferenceContinLin")
	meta <- valid; meta$name <- NULL
	name <- "InferenceContinLinTestOnlyDuplicateProbe"
	on.exit(
		if (exists(name, envir = EDI:::EDI_INFERENCE_CLASS_REGISTRY, inherits = FALSE)) {
			rm(list = name, envir = EDI:::EDI_INFERENCE_CLASS_REGISTRY)
		},
		add = TRUE
	)

	expect_false(exists(name, envir = EDI:::EDI_INFERENCE_CLASS_REGISTRY, inherits = FALSE))
	EDI:::register_inference_class(name, parent = valid$parent, metadata = meta)
	expect_true(exists(name, envir = EDI:::EDI_INFERENCE_CLASS_REGISTRY, inherits = FALSE))

	expect_error(
		EDI:::register_inference_class(name, parent = valid$parent, metadata = meta),
		"Inference class metadata already registered for InferenceContinLinTestOnlyDuplicateProbe\\."
	)
})
