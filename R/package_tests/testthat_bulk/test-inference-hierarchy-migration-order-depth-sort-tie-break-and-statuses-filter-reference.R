library(testthat)
library(EDI)

# inference_hierarchy_migration_order(manifest, statuses): topological order of non-abstract, status-filtered manifest
# records by DESCENDANT DEPTH ascending (leaves first, deepest-nested-child last), depth computed as
# 0 for a childless record and 1 + max(child depth) otherwise, with ties broken alphabetically by class name.
# Already exercised end-to-end on a 3-level linear chain in test-inference-class-registry.R; this file targets the
# untested branches: multi-child (non-linear) depth computation, alphabetical tie-break among equal-depth siblings,
# an abstract record excluded from the order even when other records name it as their parent, the statuses= filter,
# an empty manifest, and the real production default manifest's full shape.

ns <- asNamespace("EDI")
order_fn <- get("inference_hierarchy_migration_order", envir = ns)
manifest_fn <- get("inference_hierarchy_migration_manifest_as_list", envir = ns)

mk <- function(name, parent = NA_character_, abstract = FALSE, status = "pending") {
	list(name = name, current_parent = parent, current_abstract = abstract, migration_status = status)
}

# independent-reference depth computation, written from scratch (no shared code with the source's closures)
ref_order <- function(manifest, statuses = c("pending", "migrated")) {
	records <- Filter(function(r) !isTRUE(r$current_abstract) && r$migration_status %in% statuses, manifest)
	if (length(records) == 0L) return(character())
	nms <- names(records)
	parent_of <- vapply(records, function(r) r$current_parent %||% NA_character_, character(1L))
	depth_of <- function(nm) {
		kids <- nms[!is.na(parent_of) & parent_of == nm]
		if (length(kids) == 0L) return(0L)
		1L + max(vapply(kids, depth_of, integer(1L)))
	}
	depths <- vapply(nms, depth_of, integer(1L))
	nms[order(depths, nms)]
}

test_that("non-linear tree: depth is 1 + max(child depth), a deep branch outranks a shallow sibling", {
	# Root -> {A, B}; A -> A1 -> A1a; B is a leaf. depth: A1a=0, B=0, A1=1, A=2, Root=3
	m <- list(Root = mk("Root"), A = mk("A", "Root"), B = mk("B", "Root"), A1 = mk("A1", "A"), A1a = mk("A1a", "A1"))
	ord <- order_fn(m)
	expect_identical(ord, ref_order(m))
	expect_identical(ord, c("A1a", "B", "A1", "A", "Root"))
	expect_true(match("A1a", ord) < match("A1", ord))
	expect_true(match("A1", ord) < match("A", ord))
	expect_true(match("A", ord) < match("Root", ord))
	expect_true(match("B", ord) < match("Root", ord))
})

test_that("equal-depth siblings are tie-broken alphabetically by class name, not manifest insertion order", {
	m <- list(P = mk("P"), Zed = mk("Zed", "P"), Alpha = mk("Alpha", "P"))
	ord <- order_fn(m)
	expect_identical(ord, ref_order(m))
	expect_identical(ord, c("Alpha", "Zed", "P"))
})

test_that("an abstract record is excluded from the order even though a concrete record names it as current_parent", {
	m <- list(AbsRoot = mk("AbsRoot", abstract = TRUE), Leaf = mk("Leaf", "AbsRoot"))
	ord <- order_fn(m)
	expect_identical(ord, ref_order(m))
	expect_identical(ord, "Leaf")
	expect_false("AbsRoot" %in% ord)
})

test_that("statuses= filters which records participate; default excludes anything not pending/migrated", {
	m <- list(X = mk("X", status = "migrated_out"), Y = mk("Y"))
	expect_identical(order_fn(m), "Y")
	expect_identical(order_fn(m, statuses = c("pending", "migrated", "migrated_out")), ref_order(m, c("pending", "migrated", "migrated_out")))
	expect_identical(order_fn(m, statuses = c("pending", "migrated", "migrated_out")), c("X", "Y"))
})

test_that("an empty manifest returns character(0) without error", {
	expect_identical(order_fn(list()), character())
})

test_that("the real production default manifest: no duplicates, exact match to the independently-filtered name set, self-consistent chain ordering", {
	m <- manifest_fn()
	ord <- order_fn(m)
	expect_false(anyDuplicated(ord) > 0L)
	nonabstract_pending_migrated <- Filter(function(r) !isTRUE(r$current_abstract) && r$migration_status %in% c("pending", "migrated"), m)
	expect_setequal(ord, names(nonabstract_pending_migrated))
	expect_identical(ord, ref_order(m))
	# every record's own parent (when present and in the returned order) must precede it in reverse -- i.e. the
	# record itself comes BEFORE its parent, since order is leaves-first
	for (nm in ord) {
		parent <- m[[nm]]$current_parent
		if (!is.null(parent) && !is.na(parent) && parent %in% ord) {
			expect_true(match(nm, ord) < match(parent, ord), info = nm)
		}
	}
})
