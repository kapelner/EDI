library(testthat)
library(EDI)

# inference_class_ancestor_names(name, registry), target_inference_parent(name), target_inference_components(name):
# the small helpers behind the hierarchy-migration records. The ancestor walker is pure over a supplied registry;
# the target helpers are checked against the live registry (abstract classes keep their parent, concrete classes
# target the root "Inference"; components equal the effective components).
# Source note: target_inference_components() has identical return branches for abstract and concrete classes.

Z <- function(x) get(x, envir = asNamespace("EDI"))
anc <- Z("inference_class_ancestor_names")
live <- Z("inference_class_registry_as_list")()
abstract_names <- setdiff(names(live)[vapply(live, function(r) isTRUE(r$abstract), NA)], "Inference")
concrete_names <- names(live)[vapply(live, function(r) !isTRUE(r$abstract), NA)]

test_that("ancestor walker returns the parent chain nearest-first over a supplied registry", {
	reg <- list(A = list(parent = NULL), B = list(parent = "A"), C = list(parent = "B"), D = list(parent = "C"))
	expect_identical(anc("D", reg), c("C", "B", "A"))
	expect_identical(anc("B", reg), "A")
	expect_identical(anc("A", reg), character())
})

test_that("unknown names and a chain ending at an unregistered parent terminate cleanly", {
	expect_identical(anc("Zzz", list()), character())
	reg <- list(X = list(parent = "MissingParent"))
	expect_identical(anc("X", reg), "MissingParent")
})

test_that("live registry: every class's ancestor chain ends at Inference and has no repeats", {
	for (nm in setdiff(names(live), "Inference")) {
		a <- anc(nm)
		expect_identical(a[length(a)], "Inference", info = nm)
		expect_false(anyDuplicated(a) > 0, info = nm)
		expect_identical(a[1], live[[nm]]$parent, info = nm)
	}
	expect_identical(anc("Inference"), character())
})

test_that("target parent: root has none, abstract classes keep their registered parent, concrete classes target Inference", {
	tp <- Z("target_inference_parent")
	expect_null(tp("Inference"))
	expect_gt(length(abstract_names), 3L)
	for (nm in abstract_names) expect_identical(tp(nm), live[[nm]]$parent, info = nm)
	for (nm in concrete_names) expect_identical(tp(nm), "Inference", info = nm)
	expect_identical(tp("InferenceCountPoisson"), "Inference")
})

test_that("target components: none for the root, otherwise exactly the effective components", {
	tc <- Z("target_inference_components"); eff <- Z("get_effective_components")
	expect_identical(tc("Inference"), character())
	for (nm in c(abstract_names[1:3], "InferenceCountPoisson", "InferenceIncidLogRegr"))
		if (nm %in% names(live)) expect_identical(tc(nm), eff(nm), info = nm)
	expect_true("Wald" %in% tc("InferenceCountPoisson"))
})

test_that("unknown class names error from both target helpers", {
	expect_error(Z("target_inference_parent")("NoSuchInferenceClassQq"), "No inference class metadata registered")
	expect_error(Z("target_inference_components")("NoSuchInferenceClassQq"), "No inference class metadata registered")
})
