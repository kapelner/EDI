library(testthat)
library(EDI)

# combine_design_component_slot(target, component_names, slot, host_entries, overrides, resolve): merges component
# slots in order (later components override earlier ones only when declared), then applies host entries (host
# overrides only when declared by overrides or the component's allowed_host_overrides). Reference: hand-listed merges.
# Temporary components are registered and the registry is repopulated on exit.

Z <- function(x) get(x, envir = asNamespace("EDI"))
combine <- Z("combine_design_component_slot")
mkc <- function(name, public = list(), private = list(), owns_state = character(), allowed = list(public = character(), private = character()), deps = character()) {
	Z("DesignComponent")(name = name, public = public, private = private, owns_state = owns_state,
		allowed_host_overrides = allowed, dependencies = deps)
}
reg <- function(...) for (c in list(...)) Z("register_design_component")(c)
cleanup <- function() Z("populate_design_component_registry")()

fA <- function() "A"; fB <- function() "B"; fH <- function() "host"

test_that("disjoint components merge in dependency-resolved order and keep all entries", {
	withr::defer(cleanup())
	reg(mkc("TmpC1", public = list(a1 = fA)), mkc("TmpC2", public = list(b1 = fB)))
	out <- combine("Tgt", c("TmpC1", "TmpC2"), "public")
	expect_identical(names(out), c("a1", "b1"))
	expect_identical(out$a1(), "A"); expect_identical(out$b1(), "B")
	expect_identical(combine("Tgt", c("TmpC1", "TmpC2"), "private"), list())
})

test_that("component/component name collisions need a declared override; declared ones let the later component win", {
	withr::defer(cleanup())
	reg(mkc("TmpD1", public = list(m = fA)), mkc("TmpD2", public = list(m = fB)))
	expect_error(combine("Tgt", c("TmpD1", "TmpD2"), "public"), "Tgt has undeclared public component collision\\(s\\): m")
	out <- combine("Tgt", c("TmpD1", "TmpD2"), "public", overrides = list(public = "m"))
	expect_identical(out$m(), "B")
	# order matters: reversing the components reverses the winner
	out2 <- combine("Tgt", c("TmpD2", "TmpD1"), "public", overrides = list(public = "m"))
	expect_identical(out2$m(), "A")
})

test_that("a method-vs-state collision between components is reported as a kind collision before the name collision", {
	withr::defer(cleanup())
	reg(mkc("TmpK1", private = list(x = fA)), mkc("TmpK2", private = list(x = NULL), owns_state = "x"))
	expect_error(combine("Tgt", c("TmpK1", "TmpK2"), "private"), "undeclared private method/state collision\\(s\\): x")
	out <- combine("Tgt", c("TmpK1", "TmpK2"), "private", overrides = list(private = "x"))
	expect_true("x" %in% names(out)); expect_null(out$x)
})

test_that("host entries are appended; overriding a component member needs a declaration (call-level or component-level)", {
	withr::defer(cleanup())
	reg(mkc("TmpH1", public = list(m = fA)), mkc("TmpH2", public = list(n = fB), allowed = list(public = "n", private = character())))
	out <- combine("Tgt", "TmpH1", "public", host_entries = list(extra = fH))
	expect_identical(names(out), c("m", "extra"))
	expect_error(combine("Tgt", "TmpH1", "public", host_entries = list(m = fH)),
		"Tgt overrides component public member\\(s\\) without declaration: m")
	expect_identical(combine("Tgt", "TmpH1", "public", host_entries = list(m = fH), overrides = list(public = "m"))$m(), "host")
	# the component's own allowed_host_overrides also permits the host override
	expect_identical(combine("Tgt", "TmpH2", "public", host_entries = list(n = fH))$n(), "host")
})

test_that("a host overriding a method with state (or vice-versa) is a kind error unless declared", {
	withr::defer(cleanup())
	reg(mkc("TmpM1", private = list(k = fA)))
	expect_error(combine("Tgt", "TmpM1", "private", host_entries = list(k = "state"), overrides = list(private = character())),
		"overrides component private member\\(s\\) without declaration: k")
	out <- combine("Tgt", "TmpM1", "private", host_entries = list(k = "state"), overrides = list(private = "k"))
	expect_identical(out$k, "state")
})

test_that("host-only entries with no components pass straight through; unknown and duplicate components error", {
	expect_identical(combine("Tgt", character(), "public", host_entries = list(z = fH))$z(), "host")
	expect_error(combine("Tgt", "NoSuchDesignComponentXyz", "public"), "Unknown design component")
	withr::defer(cleanup())
	reg(mkc("TmpU1", public = list(u = fA)))
	expect_error(combine("Tgt", c("TmpU1", "TmpU1"), "public"), "Duplicate direct design component")
})

test_that("resolve = FALSE skips dependency expansion", {
	withr::defer(cleanup())
	reg(mkc("TmpR1", public = list(r1 = fA)), mkc("TmpR2", public = list(r2 = fB), deps = "TmpR1"))
	expect_identical(names(combine("Tgt", "TmpR2", "public", resolve = TRUE)), c("r1", "r2"))
	expect_identical(names(combine("Tgt", "TmpR2", "public", resolve = FALSE)), "r2")
})
