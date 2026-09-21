library(testthat)
library(EDI)

# design_r6_inherited_public_names / design_r6_inherited_private_names (full get_inherit() chain walk incl. active
# bindings and private fields), design_entry_kinds (method vs state), and assemble_design_public / _private (thin
# slot-selecting wrappers of combine_design_component_slot). Hand-built R6 chains; temporary components repopulated.

Z <- function(x) get(x, envir = asNamespace("EDI"))
f <- function() 1
Root <- R6::R6Class("TmpWalkRoot", public = list(root_pub = f), private = list(root_priv = f, root_state = NULL),
	active = list(root_active = function(v) 1))
Mid <- R6::R6Class("TmpWalkMid", inherit = Root, public = list(mid_pub = f, root_pub = f), private = list(mid_priv = f, mid_state = 0))
Leaf <- R6::R6Class("TmpWalkLeaf", inherit = Mid, public = list(leaf_pub = f), private = list(leaf_priv = f),
	active = list(leaf_active = function(v) 2))

test_that("public walker collects methods and active bindings up the whole chain, unique, nearest class first", {
	w <- Z("design_r6_inherited_public_names")
	expect_setequal(w(Leaf), c("leaf_pub", "clone", "leaf_active", "mid_pub", "root_pub", "root_active"))
	expect_false(anyDuplicated(w(Leaf)) > 0)                              # root_pub defined twice, listed once
	expect_identical(w(Leaf)[1], "leaf_pub")                               # nearest class first (R6 adds `clone` to every generator)
	expect_setequal(w(Mid), c("mid_pub", "root_pub", "clone", "root_active"))
	expect_setequal(w(Root), c("root_pub", "clone", "root_active"))
})

test_that("private walker collects private methods and private fields up the whole chain", {
	w <- Z("design_r6_inherited_private_names")
	expect_setequal(w(Leaf), c("leaf_priv", "mid_priv", "mid_state", "root_priv", "root_state"))
	expect_setequal(w(Mid), c("mid_priv", "mid_state", "root_priv", "root_state"))
	expect_false(any(c("leaf_pub", "root_pub") %in% w(Leaf)))
})

test_that("NULL / classless inputs give empty results; a base with no members contributes nothing", {
	expect_identical(Z("design_r6_inherited_public_names")(NULL), character())
	expect_identical(Z("design_r6_inherited_private_names")(NULL), character())
	Empty <- R6::R6Class("TmpWalkEmpty")
	expect_identical(Z("design_r6_inherited_public_names")(Empty), "clone")       # only R6's own clone()
	expect_identical(Z("design_r6_inherited_private_names")(Empty), character())
})

test_that("design_entry_kinds labels functions 'method' and everything else 'state', preserving names", {
	k <- Z("design_entry_kinds")
	expect_identical(k(list(a = f, b = NULL, c = 3, d = "x", e = function(x) x)),
		c(a = "method", b = "state", c = "state", d = "state", e = "method"))
	expect_identical(k(list()), character())
	expect_identical(k(NULL), character())
})

test_that("assemble_design_public / assemble_design_private select the right slot of the same combiner", {
	withr::defer(Z("populate_design_component_registry")())
	Z("register_design_component")(Z("DesignComponent")(name = "TmpAsmC", public = list(p1 = f), private = list(q1 = f)))
	pub <- Z("assemble_design_public")("Tgt", "TmpAsmC", list(hp = f))
	prv <- Z("assemble_design_private")("Tgt", "TmpAsmC", list(hq = f))
	expect_identical(names(pub), c("p1", "hp")); expect_identical(names(prv), c("q1", "hq"))
	expect_identical(pub, Z("combine_design_component_slot")("Tgt", "TmpAsmC", "public", list(hp = f)))
	expect_identical(prv, Z("combine_design_component_slot")("Tgt", "TmpAsmC", "private", list(hq = f)))
	expect_identical(names(Z("assemble_design_public")("Tgt")), NULL)
	expect_identical(Z("assemble_design_public")("Tgt", public = list(only = f))$only(), 1)
	expect_error(Z("assemble_design_public")("Tgt", "TmpAsmC", list(p1 = f)), "overrides component public member\\(s\\) without declaration: p1")
	expect_identical(Z("assemble_design_public")("Tgt", "TmpAsmC", list(p1 = function() 9), overrides = list(public = "p1"))$p1(), 9)
})
