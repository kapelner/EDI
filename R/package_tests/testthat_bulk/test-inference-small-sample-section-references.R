library(testthat)

# v1.0.5 TODO-195: every concrete inference class's help page carries a generated
# "Small-sample behaviour" section (roxygen `@eval rd_small_sample_section("<Class>")`,
# R/EDI/R/inference_small_sample_doc.R) rendered from the convergence-rate registry
# (R/EDI/R/inference_procedure_regime.R), and every rate shown is cited with a
# REFERENCES.md key. These tests check that
#   * every citation key in the registry (`reference_key` / `bias_reference_key`)
#     resolves to an entry in R/EDI/REFERENCES.md, and every rate-bearing registry
#     entry has one;
#   * the renderer produces a well-formed section for each of the 88 public
#     (non-legacy-IVWC) classes, with only resolvable keys, honest wording for
#     assumed-default and unknown rates, and a full citation for every key;
#   * each of those classes' roxygen blocks calls the renderer (and no legacy IVWC
#     class does).
# The renderer tests need the package internals: run under
# pkgload::load_all("R/EDI", compile = FALSE) (they skip otherwise).

ss_repo_dir = function() {
	dir = normalizePath(testthat::test_path(), mustWork = FALSE)
	for (i in 1:8) {
		if (file.exists(file.path(dir, "R", "EDI", "REFERENCES.md"))) return(dir)
		dir = dirname(dir)
	}
	NA_character_
}
repo = ss_repo_dir()
skip_if(is.na(repo), "checkout not found")
ss_registry_file = file.path(repo, "R", "EDI", "R", "inference_procedure_regime.R")
ss_refs_md = readLines(file.path(repo, "R", "EDI", "REFERENCES.md"), warn = FALSE)
ss_md_keys = sub("^- \\*\\*\\[([A-Za-z0-9]+)\\]\\*\\*.*$", "\\1", grep("^- \\*\\*\\[[A-Za-z0-9]+\\]\\*\\*", ss_refs_md, value = TRUE))
ss_reg = new.env(parent = baseenv())
sys.source(ss_registry_file, envir = ss_reg)
ss_split = function(x) unique(unlist(strsplit(x[!is.na(x)], ",\\s*"), use.names = FALSE))
ss_has_pkg = function() {
	"EDI" %in% loadedNamespaces() && exists("rd_small_sample_section", envir = asNamespace("EDI"), inherits = FALSE)
}
ss_classes = function() {
	ns = asNamespace("EDI")
	nm = grep("^Inference", getNamespaceExports("EDI"), value = TRUE)
	sort(setdiff(nm[!grepl("IVWC", nm)], c("InferenceSuite", "InferenceRandCustom")))
}

test_that("REFERENCES.md keys are unique", {
	expect_gt(length(ss_md_keys), 100L)
	expect_false(anyDuplicated(ss_md_keys) > 0L)
})

test_that("every registry citation key resolves to REFERENCES.md and every rate-bearing entry has one", {
	d = ss_reg$EDI_CONVERGENCE_PROCEDURE_DEFAULTS
	o = ss_reg$EDI_CONVERGENCE_OVERRIDES
	expect_true(all(c("reference_key", "bias_reference_key") %in% names(d)))
	expect_true("reference_key" %in% names(o))
	# Procedure layer: a key for the size order and one for the bias order, on every row.
	expect_false(anyNA(d$reference_key))
	expect_false(anyNA(d$bias_reference_key))
	# Override layers: every entry that sets an order or a regularity cites a key.
	bearing = !is.na(o$size_order) | o$size_unknown | !is.na(o$bias_order) | o$bias_unknown | !is.na(o$regularity)
	expect_true(any(bearing))
	expect_false(anyNA(o$reference_key[bearing]), info = "a rate-bearing override has no reference_key")
	used = ss_split(c(d$reference_key, d$bias_reference_key, o$reference_key))
	missing = setdiff(used, ss_md_keys)
	expect_identical(missing, character(0), info = paste("registry keys absent from REFERENCES.md:", paste(missing, collapse = ", ")))
	expect_identical(ss_reg$inference_convergence_validate(), character(0))
})

test_that("a resolved triple carries the keys of the layer that supplied each field", {
	r = ss_reg$inference_convergence_expectation(
		c("DesignFixediBCRD", "DesignFixediBCRD", "DesignFixedBlocking", "DesignFixediBCRD"),
		c("InferenceContinLin", "InferenceContinQuantileRegr", "InferenceAllSimpleAverageDiff", "InferenceAllSimpleAverageDiff"),
		c("wald", "wald", "wald", "wald"))
	expect_identical(r$reference_key[1L], "Hall1992")
	expect_identical(r$reference_key[2L], "HallSheather1988, Koenker1994, Koenker2005")
	expect_match(r$reference_key[3L], "BaiRomanoShaikh2021", fixed = TRUE)
	expect_identical(r$bias_reference_key[4L], "Neyman1923, ImbensRubin2015")
	expect_identical(r$bias_reference_key[1L], "CoxSnell1968")
	expect_false(anyNA(r$reference_key))
})

test_that("the section renders for every public class with resolvable keys and full citations", {
	skip_if_not(ss_has_pkg(), "needs pkgload::load_all('R/EDI', compile = FALSE)")
	ns = asNamespace("EDI")
	classes = ss_classes()
	expect_length(classes, 88L)
	old = setwd(file.path(repo, "R"))
	on.exit(setwd(old), add = TRUE)
	for (cl in classes) {
		x = ns$rd_small_sample_section(cl)
		expect_identical(x[1L], "@section Small-sample behaviour:", info = cl)
		expect_true("@references" %in% x, info = cl)
		body = x[seq_len(which(x == "@references") - 1L)]
		cited = unique(unlist(regmatches(body, gregexpr("\\[[A-Za-z]+[0-9]{4}\\]", body))))
		cited = gsub("[][]", "", cited)
		expect_gt(length(cited), 0L)
		expect_identical(setdiff(cited, ss_md_keys), character(0), info = cl)
		refs = x[(which(x == "@references") + 1L):length(x)]
		refs = refs[nzchar(refs)]
		# one full citation per cited key, none left as a bare "[Key]"
		expect_identical(sort(sub("^\\[([A-Za-z0-9]+)\\].*$", "\\1", refs)), sort(cited), info = cl)
		expect_false(any(grepl("^\\[[A-Za-z0-9]+\\]$", refs)), info = cl)
		expect_false(any(grepl("Used by", x, fixed = TRUE)), info = cl)
	}
})

test_that("assumed-default, unknown and exact-only rows are labelled honestly", {
	skip_if_not(ss_has_pkg(), "needs pkgload::load_all('R/EDI', compile = FALSE)")
	ns = asNamespace("EDI")
	old = setwd(file.path(repo, "R"))
	on.exit(setwd(old), add = TRUE)
	lin = paste(ns$rd_small_sample_section("InferenceContinLin"), collapse = "\n")
	expect_match(lin, "assumed default", fixed = TRUE)
	expect_match(lin, "[Hall1992]", fixed = TRUE)
	expect_match(lin, "smaller arm", fixed = TRUE)
	zi = paste(ns$rd_small_sample_section("InferenceCountZeroInflatedPoisson"), collapse = "\n")
	expect_match(zi, "unknown", fixed = TRUE)
	expect_match(zi, "no rate is known", fixed = TRUE)
	expect_match(zi, "[SelfLiang1987]", fixed = TRUE)
	qr = paste(ns$rd_small_sample_section("InferenceContinQuantileRegr"), collapse = "\n")
	expect_match(qr, "n_{eff}^{-2/3}", fixed = TRUE)
	expect_match(qr, "[HallSheather1988]", fixed = TRUE)
	sm = paste(ns$rd_small_sample_section("InferenceAllSimpleAverageDiff"), collapse = "\n")
	expect_match(sm, "unbiased under randomization", fixed = TRUE)
	expect_match(sm, "design mismatch", fixed = TRUE)
	ex = paste(ns$rd_small_sample_section("InferenceIncidExactFisher"), collapse = "\n")
	expect_false(grepl("bias is of order", ex, fixed = TRUE))
	expect_error(ns$rd_small_sample_section("NotAClass"))
})

test_that("each public class calls the renderer once in its roxygen block; legacy IVWC classes never do", {
	skip_if_not(ss_has_pkg(), "needs pkgload::load_all('R/EDI', compile = FALSE)")
	src_dir = file.path(repo, "R", "EDI", "R")
	lines = unlist(lapply(list.files(src_dir, pattern = "^inference_.*\\.R$", full.names = TRUE), readLines, warn = FALSE))
	calls = sub("^#' @eval rd_small_sample_section\\(\"([A-Za-z0-9]+)\"\\)\\s*$", "\\1", grep("^#' @eval rd_small_sample_section\\(", lines, value = TRUE))
	classes = ss_classes()
	expect_identical(sort(calls), classes)
	expect_false(any(grepl("IVWC", calls)))
})

test_that("the hand-written ContinLin small-sample prose reports the measurement, not the old figure", {
	txt = paste(readLines(file.path(repo, "R", "EDI", "R", "inference_continuous_lin.R"), warn = FALSE), collapse = "\n")
	expect_false(grepl("10.5", txt, fixed = TRUE))
	expect_match(txt, "17\\\\% of the time", perl = TRUE)
	expect_match(txt, "2026-11-09-8c32d060", fixed = TRUE)
})
