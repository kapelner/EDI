library(testthat)
library(EDI)

# complete_component_reference_contract(component): every private$/self$/super$ reference in a component body that is
# not declared is added to optional_private_methods / optional_public_methods / requires_super_methods (sorted, unique,
# existing declarations kept) and the result re-validated; idempotent. find_inference_component_source_file(file):
# existing path first, then R/, EDI/R/, R/EDI/R/ relative candidates, else NA. References: hand-listed expectations.

Z <- function(x) get(x, envir = asNamespace("EDI"))
C <- Z("complete_component_reference_contract")
mk <- function(...) Z("InferenceComponent")(name = "TmpCompleteC", file = "tmp.R", ...)

test_that("undeclared references become optional/super requirements; declared ones are left alone", {
	comp <- mk(public = list(run = function() { self$helper(); private$x; private$y; super$base(); self$run() }),
		private = list(y = NULL), owns_state = "y")
	r <- C(comp)
	expect_identical(r$optional_private_methods, "x")           # y is owned state, x is not declared
	expect_identical(r$optional_public_methods, "helper")       # `run` is provided by the component itself
	expect_identical(r$requires_super_methods, "base")
	expect_identical(r$public, comp$public); expect_identical(r$owns_state, "y")
})

test_that("existing optional / super declarations are merged, sorted and de-duplicated", {
	comp <- mk(public = list(run = function() { private$zeta; private$alpha; self$pub_b; super$s2 }),
		optional_private_methods = c("mid", "alpha"), optional_public_methods = "pub_a", requires_super_methods = "s1")
	r <- C(comp)
	expect_identical(r$optional_private_methods, c("alpha", "mid", "zeta"))
	expect_identical(r$optional_public_methods, c("pub_a", "pub_b"))
	expect_identical(r$requires_super_methods, c("s1", "s2"))
})

test_that("references made from private bodies are found too; required-method declarations count as declared", {
	comp <- mk(private = list(helper = function() { private$needed; self$other_pub }),
		requires_private_methods = "needed")
	r <- C(comp)
	expect_identical(r$optional_private_methods, character(0))
	expect_identical(r$optional_public_methods, "other_pub")
})

test_that("a component with no references is unchanged apart from normalisation; completion is idempotent", {
	comp <- mk(public = list(f = function() 1))
	r <- C(comp)
	expect_identical(r$optional_private_methods, character(0)); expect_identical(r$requires_super_methods, character(0))
	comp2 <- mk(public = list(run = function() { private$q; self$r; super$s }))
	expect_identical(C(C(comp2)), C(comp2))
})

test_that("forbidden references in the body are not silently completed away (they stay declared as forbidden)", {
	comp <- mk(public = list(run = function() private$bad), forbidden_refs = list(private = "bad", self = character(), super = character()))
	r <- C(comp)
	expect_identical(r$optional_private_methods, character(0))      # forbidden_refs count as declared names in the declared-name collector
	expect_identical(r$forbidden_refs$private, "bad")
})

test_that("source-file lookup: existing path is normalised; unknown names give NA", {
	find <- Z("find_inference_component_source_file")
	d <- withr::local_tempdir(); f <- file.path(d, "src_a.R"); writeLines("x <- 1", f)
	expect_identical(find(f), normalizePath(f))
	expect_true(is.na(find(file.path(d, "does_not_exist.R"))))
	expect_true(is.na(find("zzz_definitely_missing_source_file.R")))
})

test_that("source-file lookup resolves R/, EDI/R/ and R/EDI/R/ relative candidates in that order", {
	find <- Z("find_inference_component_source_file")
	for (rel in list(c("R"), c("EDI", "R"), c("R", "EDI", "R"))) {
		d <- withr::local_tempdir(); dir.create(do.call(file.path, c(list(d), as.list(rel))), recursive = TRUE)
		target <- file.path(d, do.call(file.path, as.list(rel)), "comp.R"); writeLines("1", target)
		withr::with_dir(d, expect_identical(find("comp.R"), normalizePath(target), info = paste(rel, collapse = "/")))
	}
	d <- withr::local_tempdir(); dir.create(file.path(d, "R")); dir.create(file.path(d, "EDI", "R"), recursive = TRUE)
	writeLines("1", file.path(d, "R", "both.R")); writeLines("2", file.path(d, "EDI", "R", "both.R"))
	withr::with_dir(d, expect_identical(find("both.R"), normalizePath(file.path(d, "R", "both.R"))))
})
