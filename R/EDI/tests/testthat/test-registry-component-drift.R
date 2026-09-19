library(testthat)
library(EDI)

# Registry-drift audit: the component list each class is *assembled* from
# (the `components=` argument of its define_inference_class() call -- what
# actually determines its methods) must agree with the two hand-maintained
# copies the metadata/capability registry keeps of it:
#   1. infer_inference_direct_components()'s switch (feeds
#      get_inference_class_metadata()$direct_components and the capability
#      registry), and
#   2. EDI_INFERENCE_HIERARCHY_MIGRATION_MANIFEST's target_direct_components.
# Both are independently edited lists with no link to the factory call, and
# have drifted before (see infer_inference_direct_components()'s 2026-09-15
# comment; and 2026-09-19, when adding a missing component to the Cox factory
# calls also required updating the switch, the manifest, and a test snapshot
# by hand). Set-equality, not order: order only matters for the factory call's
# merge semantics and the registry doesn't use it.
#
# Reads R/EDI/R/*.R source, which exists in a repo checkout (the pre-push hook
# and local runs) but not in an installed package or R CMD check tarball --
# skipped there.

drift_src_dir = testthat::test_path("..", "..", "R")

drift_factory_components = function(src_dir) {
	out = list()
	for (f in list.files(src_dir, pattern = "\\.R$", full.names = TRUE)) {
		exprs = tryCatch(parse(f, keep.source = FALSE), error = function(e) NULL)
		walk = function(e) {
			if (!is.call(e)) return(invisible(NULL))
			if (identical(e[[1L]], as.name("define_inference_class"))) {
				args = as.list(e)[-1L]
				nms = names(args)
				cn = if ("classname" %in% nms) args[["classname"]] else NULL
				co = if ("components" %in% nms) args[["components"]] else NULL
				if (is.character(cn) && length(cn) == 1L) {
					vals = NULL
					if (is.character(co)) {
						vals = co
					} else if (is.call(co) && identical(co[[1L]], as.name("c")) &&
							all(vapply(as.list(co)[-1L], is.character, NA))) {
						vals = unlist(as.list(co)[-1L])
					} else if (is.null(co)) {
						vals = character()
					}
					out[[cn]] <<- list(components = vals, file = basename(f))
				}
			}
			for (i in seq_along(e)) try(walk(e[[i]]), silent = TRUE)
		}
		for (ex in exprs) walk(ex)
	}
	out
}

test_that("every factory class's components= argument is statically readable", {
	skip_if_not(dir.exists(drift_src_dir), "R source tree not available (installed-package run)")
	fc = drift_factory_components(drift_src_dir)
	expect_gte(length(fc), 90L)
	unreadable = names(fc)[vapply(fc, function(x) is.null(x$components), NA)]
	expect_identical(unreadable, character(0), info = paste(
		"components= must be a literal character vector so this audit can read it:",
		paste(unreadable, collapse = ", ")))
})

test_that("factory components agree with the registry direct-components switch and the migration manifest", {
	skip_if_not(dir.exists(drift_src_dir), "R source tree not available (installed-package run)")
	fc = drift_factory_components(drift_src_dir)
	EDI:::populate_inference_class_registry()
	manifest = EDI:::inference_hierarchy_migration_manifest_as_list()
	problems = character()
	for (nm in names(fc)) {
		comps = fc[[nm]]$components
		if (is.null(comps)) next
		reg = tryCatch(EDI:::get_inference_class_metadata(nm)$direct_components, error = function(e) NULL)
		if (is.null(reg)) {
			problems = c(problems, sprintf("%s (%s): defined via define_inference_class() but has no registry metadata", nm, fc[[nm]]$file))
			next
		}
		if (!setequal(comps, reg)) {
			problems = c(problems, sprintf(
				"%s (%s): factory components {%s} != registry direct_components {%s} -- update infer_inference_direct_components() in inference_class_registry.R",
				nm, fc[[nm]]$file, paste(comps, collapse = ", "), paste(reg, collapse = ", ")))
		}
		tgt = manifest[[nm]]$target_direct_components
		if (!is.null(tgt) && !setequal(comps, tgt)) {
			problems = c(problems, sprintf(
				"%s (%s): factory components {%s} != migration manifest target_direct_components {%s} -- update the manifest entry in inference_class_registry.R",
				nm, fc[[nm]]$file, paste(comps, collapse = ", "), paste(tgt, collapse = ", ")))
		}
	}
	expect_identical(problems, character(0), info = paste(problems, collapse = "\n  "))
})

test_that("the drift audit detects a mismatch (self-check on a synthetic factory call)", {
	tmp = tempfile("drift_src_")
	dir.create(tmp)
	writeLines(c(
		"SyntheticA = define_inference_class(classname = \"SyntheticA\", inherit = Inference, components = c(\"Wald\", \"Jackknife\"))",
		"SyntheticB = define_inference_class(classname = 'SyntheticB', inherit = Inference)"
	), file.path(tmp, "synthetic.R"))
	fc = drift_factory_components(tmp)
	expect_setequal(fc$SyntheticA$components, c("Wald", "Jackknife"))
	expect_identical(fc$SyntheticB$components, character())
})
