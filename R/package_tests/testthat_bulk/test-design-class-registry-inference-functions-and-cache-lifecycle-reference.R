library(testthat)
library(EDI)

# design_class_registry.R: the name-based infer_design_*() functions, their agreement with the
# live registry records, metadata lookup errors, the non-throwing abstract gate, register /
# clear semantics (on a snapshot that is restored), and the effective-metadata caches.

Z <- function(x) get(x, envir = asNamespace("EDI"))
reg_env <- function() Z("EDI_DESIGN_CLASS_REGISTRY")

with_registry_snapshot <- function(code) {
	env <- reg_env()
	snap <- mget(ls(env), envir = env, inherits = FALSE)
	on.exit({ rm(list = ls(env), envir = env); list2env(snap, envir = env); Z("clear_design_effective_metadata_cache")() }, add = TRUE)
	force(code)
}

test_that("randomization family: mapped for concrete classes, NA for abstract ones, an actionable error for unmapped names", {
	f <- Z("infer_design_randomization_family")
	expect_equal(f("DesignFixedBernoulli"), "bernoulli")
	expect_true(is.na(f("DesignFixed")))
	expect_true(is.na(f("DesignSeqOneByOne")))
	expect_error(f("DesignNoSuchClass"), "No randomization_family mapping registered for design class DesignNoSuchClass")
})

test_that("small classifiers: abstractness, seed reproducibility, single-thread flag, batch pregeneration, required packages", {
	expect_true(Z("infer_design_abstract")("Design"))
	expect_false(Z("infer_design_abstract")("DesignFixedBernoulli"))
	sr <- Z("infer_design_seed_reproducible_draw")
	expect_true(is.na(sr("Design")))                                           # abstract: not applicable
	expect_true(sr("DesignFixedBernoulli"))
	for (nm in Z("EDI_DESIGN_NOT_SEED_REPRODUCIBLE_CLASS_NAMES")) if (!nm %in% Z("EDI_DESIGN_ABSTRACT_CLASS_NAMES")) expect_false(sr(nm), info = nm)
	st <- Z("infer_design_seed_reproducible_draw_requires_single_thread")
	for (nm in Z("EDI_DESIGN_SEED_REPRODUCIBLE_SINGLE_THREAD_ONLY_CLASS_NAMES")) expect_true(st(nm), info = nm)
	expect_false(st("DesignFixedBernoulli"))
	bp <- Z("infer_design_supports_batch_w_pregeneration")
	for (nm in Z("EDI_DESIGN_BATCH_W_PREGENERATION_CLASS_NAMES")) expect_true(bp(nm), info = nm)
	expect_false(bp("NoSuchDesign"))
	rp <- Z("infer_design_required_packages")
	expect_identical(rp("DesignFixedBernoulli"), character())
	expect_true(all(c("anticlust", "blockTools", "ompr") %in% rp("DesignFixedOptimalBlocks")))
	expect_identical(rp("NoSuchDesign"), character())
})

test_that("every registered class's stored metadata agrees with the name-based infer functions", {
	reg <- Z("design_class_registry_as_list")()
	expect_gt(length(reg), 15L)
	for (nm in names(reg)) {
		r <- reg[[nm]]
		expect_equal(r$abstract, Z("infer_design_abstract")(nm), info = nm)
		expect_equal(r$supports_batch_w_pregeneration, Z("infer_design_supports_batch_w_pregeneration")(nm), info = nm)
		expect_identical(r$required_packages, Z("infer_design_required_packages")(nm), info = nm)
		expect_equal(r$seed_reproducible_draw, Z("infer_design_seed_reproducible_draw")(nm), info = nm)
		expect_identical(r$randomization_family, tryCatch(Z("infer_design_randomization_family")(nm), error = function(e) r$randomization_family), info = nm)
		if (!isTRUE(r$abstract)) expect_false(is.na(r$randomization_family), info = nm)
		expect_true(is.logical(r$exported) && !is.na(r$exported), info = nm)
	}
})

test_that("metadata lookup errors on unknown names; the abstract gate does not", {
	expect_error(Z("get_design_class_metadata")("NoSuchDesign"), "No design class metadata registered for NoSuchDesign")
	expect_false(Z("is_design_class_abstract")("NoSuchDesign"))                 # unregistered (third-party) classes are instantiable
	expect_true(Z("is_design_class_abstract")("Design"))
	expect_false(Z("is_design_class_abstract")("DesignFixedBernoulli"))
	expect_equal(Z("get_direct_design_components")("DesignFixedBernoulli"), Z("get_design_class_metadata")("DesignFixedBernoulli")$direct_components)
})

test_that("register_design_class fills defaults, rejects duplicates and clears the effective caches; clear empties the registry", {
	with_registry_snapshot({
		before <- length(ls(reg_env()))
		bern <- Z("get_design_class_metadata")("DesignFixedBernoulli")
		rec <- Z("register_design_class")("DesignTestOnlyProbe", parent = "Design",
			metadata = list(abstract = FALSE, timing_family = bern$timing_family, randomization_family = bern$randomization_family,
				seed_reproducible_draw = TRUE))
		expect_equal(length(ls(reg_env())), before + 1L)
		expect_equal(rec$name, "DesignTestOnlyProbe"); expect_equal(rec$parent, "Design")
		expect_identical(rec$required_packages, character()); expect_false(rec$supports_batch_w_pregeneration)
		expect_false(rec$seed_reproducible_draw_requires_single_thread)
		expect_error(Z("register_design_class")("DesignTestOnlyProbe", parent = "Design",
			metadata = list(timing_family = bern$timing_family, randomization_family = bern$randomization_family, seed_reproducible_draw = TRUE)),
			"already registered")
		expect_error(Z("register_design_class")("DesignTestOnlyBad", parent = "Design"), "NA `timing_family`")   # validation runs first
		expect_equal(Z("get_design_class_metadata")("DesignTestOnlyProbe")$parent, "Design")
		# effective metadata caches fill lazily and are emptied by the clear function
		Z("get_effective_design_components")("DesignTestOnlyProbe")
		expect_true(exists("DesignTestOnlyProbe", envir = Z("EDI_DESIGN_EFFECTIVE_COMPONENTS_CACHE"), inherits = FALSE))
		Z("get_effective_design_capabilities")("DesignTestOnlyProbe")
		expect_true(exists("DesignTestOnlyProbe", envir = Z("EDI_DESIGN_EFFECTIVE_CAPABILITIES_CACHE"), inherits = FALSE))
		expect_true(Z("clear_design_effective_metadata_cache")())
		expect_false(exists("DesignTestOnlyProbe", envir = Z("EDI_DESIGN_EFFECTIVE_COMPONENTS_CACHE"), inherits = FALSE))
		expect_false(exists("DesignTestOnlyProbe", envir = Z("EDI_DESIGN_EFFECTIVE_CAPABILITIES_CACHE"), inherits = FALSE))
		expect_true(Z("clear_design_class_registry")())
		expect_length(ls(reg_env()), 0L)
	})
	expect_gt(length(ls(reg_env())), 15L)                                       # snapshot restored
	expect_equal(Z("get_design_class_metadata")("DesignFixedBernoulli")$randomization_family, "bernoulli")
})
