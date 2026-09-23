library(testthat)
library(EDI)

# combine_component_slot() (contracts_mixins.R) is the inference-side twin of
# combine_design_component_slot() (design_class_factory.R, already covered by
# test-combine-design-component-slot-merge-order-collisions-and-host-override-rules-reference.R).
# It merges resolved inference components' public/private entries in order (later components win
# only when declared), then layers host entries on top (host overrides only when declared). It has
# 4 distinct undeclared-collision stop() branches -- component/component name collision, a
# method-vs-state KIND collision between components, host-overrides-a-component-member, and a
# host/component KIND mismatch override -- and every registered inference class only ever exercises
# the non-error merge path (any real error here would fail package load), so none of these 4
# branches had a direct test reference anywhere.

Z <- function(x) get(x, envir = asNamespace("EDI"))
combine <- Z("combine_component_slot")
mkc <- function(name, public = list(), private = list(), allowed = list(public = character(), private = character()), deps = character()) {
	Z("InferenceComponent")(
		name = name, file = "test", public = public, private = private,
		allowed_host_overrides = allowed, dependencies = deps
	)
}
reg <- function(...) for (c in list(...)) Z("register_inference_component")(c)
cleanup <- function() Z("populate_inference_component_registry")()

fA <- function() "A"; fB <- function() "B"; fH <- function() "host"

test_that("disjoint components merge in order and keep all entries", {
	withr::defer(cleanup())
	reg(mkc("TmpIC1", public = list(a1 = fA)), mkc("TmpIC2", public = list(b1 = fB)))
	out <- combine("Tgt", c("TmpIC1", "TmpIC2"), "public")
	expect_identical(names(out), c("a1", "b1"))
	expect_identical(out$a1(), "A"); expect_identical(out$b1(), "B")
	expect_identical(combine("Tgt", c("TmpIC1", "TmpIC2"), "private"), list())
})

test_that("component/component name collisions need a declared override; declared ones let the later component win", {
	withr::defer(cleanup())
	reg(mkc("TmpID1", public = list(m = fA)), mkc("TmpID2", public = list(m = fB)))
	expect_error(combine("Tgt", c("TmpID1", "TmpID2"), "public"), "Tgt has undeclared public component collision\\(s\\): m")
	out <- combine("Tgt", c("TmpID1", "TmpID2"), "public", overrides = list(public = "m"))
	expect_identical(out$m(), "B")
	out2 <- combine("Tgt", c("TmpID2", "TmpID1"), "public", overrides = list(public = "m"))
	expect_identical(out2$m(), "A")
})

test_that("a method-vs-state collision between components is reported as a kind collision before the name collision", {
	withr::defer(cleanup())
	reg(mkc("TmpIK1", private = list(x = fA)), mkc("TmpIK2", private = list(x = "not a function")))
	expect_error(combine("Tgt", c("TmpIK1", "TmpIK2"), "private"), "undeclared private method/state collision\\(s\\): x")
	out <- combine("Tgt", c("TmpIK1", "TmpIK2"), "private", overrides = list(private = "x"))
	expect_identical(out$x, "not a function")
})

test_that("host entries are appended; overriding a component member needs a call-level declaration", {
	withr::defer(cleanup())
	reg(mkc("TmpIH1", public = list(m = fA)))
	out <- combine("Tgt", "TmpIH1", "public", host_entries = list(extra = fH))
	expect_identical(names(out), c("m", "extra"))
	expect_error(combine("Tgt", "TmpIH1", "public", host_entries = list(m = fH)),
		"Tgt overrides component public member\\(s\\) without declaration: m")
	expect_identical(combine("Tgt", "TmpIH1", "public", host_entries = list(m = fH), overrides = list(public = "m"))$m(), "host")
	# Note (not a test assertion -- see summary): unlike combine_design_component_slot()'s
	# design-side sibling, this function never reads a component's own allowed_host_overrides
	# field for host-override checks -- only call-level `overrides` counts here, even though
	# InferenceComponent() accepts and stores allowed_host_overrides on every component.
})

test_that("a host overriding a method with state (or vice-versa) is a kind error unless declared", {
	withr::defer(cleanup())
	reg(mkc("TmpIM1", private = list(k = fA)))
	expect_error(combine("Tgt", "TmpIM1", "private", host_entries = list(k = "state"), overrides = list(private = character())),
		"overrides component private member\\(s\\) without declaration: k")
	out <- combine("Tgt", "TmpIM1", "private", host_entries = list(k = "state"), overrides = list(private = "k"))
	expect_identical(out$k, "state")
})

test_that("host-only entries with no components pass straight through", {
	expect_identical(combine("Tgt", character(), "public", host_entries = list(z = fH))$z(), "host")
})

test_that("resolve = FALSE skips dependency expansion", {
	withr::defer(cleanup())
	reg(mkc("TmpIR1", public = list(r1 = fA)), mkc("TmpIR2", public = list(r2 = fB), deps = "TmpIR1"))
	expect_identical(names(combine("Tgt", "TmpIR2", "public", resolve = TRUE)), c("r1", "r2"))
	expect_identical(names(combine("Tgt", "TmpIR2", "public", resolve = FALSE)), "r2")
})
