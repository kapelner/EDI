library(testthat)

# v1.0.5 TODO-198: the tables of the vignette "Which procedure can I trust at my
# sample size?" (R/EDI/vignettes/procedure-trust.Rmd) are static text rendered
# from the regime / convergence-rate registry by
# R/package_tests/render_procedure_trust_tables.R. The vignette is eval = FALSE
# and builds without the calibration scripts, so this test is what keeps the
# static tables in sync with the registry. Regenerate with
#   Rscript R/package_tests/render_procedure_trust_tables.R --write
# The `counts` block needs pkgload::load_all("R/EDI", compile = FALSE) (or an
# installed EDI that carries the registry) and the calibration scripts; it skips
# otherwise.

trust_repo_dir = function() {
	dir = normalizePath(testthat::test_path(), mustWork = FALSE)
	for (i in 1:8) {
		if (file.exists(file.path(dir, "R", "package_tests", "render_procedure_trust_tables.R"))) return(dir)
		dir = dirname(dir)
	}
	NA_character_
}
repo = trust_repo_dir()
skip_if(is.na(repo), "checkout not found")

gen = new.env(parent = globalenv())
sys.source(file.path(repo, "R", "package_tests", "render_procedure_trust_tables.R"), envir = gen)
reg = gen$trust_load_registry(repo)
vignette_lines = readLines(gen$trust_vignette_path(repo), warn = FALSE)

test_that("the registry tables in the vignette match the registry", {
	expect_identical(gen$trust_extract_block(vignette_lines, "registry"), gen$trust_render_registry_block(reg))
})

test_that("the count tables in the vignette match the registry", {
	tr = tryCatch(gen$trust_applicable_triples(repo), error = function(e) NULL)
	skip_if(is.null(tr), "needs load_all(compile = FALSE) and the calibration scripts")
	expect_identical(gen$trust_extract_block(vignette_lines, "counts"), gen$trust_render_counts_block(reg, tr))
})

test_that("the vignette never names a legacy IVWC class", {
	expect_false(any(grepl("IVWC", vignette_lines, fixed = TRUE)))
	expect_false(any(grepl("IVWC", gen$trust_render_registry_block(reg), fixed = TRUE)))
})

test_that("every citation key the tables use is defined in REFERENCES.md", {
	refs = readLines(file.path(repo, "R", "EDI", "REFERENCES.md"), warn = FALSE)
	defined = unique(sub("^- \\*\\*\\[([^]]+)\\]\\*\\*.*$", "\\1", grep("^- \\*\\*\\[", refs, value = TRUE)))
	used = unique(c(unlist(gen$TRUST_PROCEDURE_KEYS), unlist(gen$TRUST_REGULARITY_KEYS)))
	# The prose cites keys too.
	prose = unlist(regmatches(vignette_lines, gregexpr("\\[[A-Z][A-Za-z]+[0-9]{4}[A-Za-z]*\\]", vignette_lines)))
	used = unique(c(used, gsub("[][]", "", prose)))
	missing = setdiff(used, defined)
	expect_length(missing, 0L)
	if (length(missing)) message("keys missing from REFERENCES.md: ", paste(missing, collapse = ", "))
})

test_that("the vignette is listed in pkgdown and the vignette has a unique index entry", {
	pk = readLines(file.path(repo, "R", "EDI", "_pkgdown.yml"), warn = FALSE)
	expect_true(any(trimws(pk) == "- procedure-trust"))
	entries = unlist(lapply(list.files(file.path(repo, "R", "EDI", "vignettes"), pattern = "\\.Rmd$", full.names = TRUE),
		function(f) grep("VignetteIndexEntry", readLines(f, n = 10L, warn = FALSE), value = TRUE)))
	expect_false(anyDuplicated(entries) > 0L)
})
