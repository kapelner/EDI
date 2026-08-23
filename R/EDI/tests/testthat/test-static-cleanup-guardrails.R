library(testthat)
library(EDI)

#' Locate the package's flat, per-file .R source (needed to grep for the
#' patterns below). Only resolvable when the *source* tree is reachable from
#' the test's working directory -- true for a local devtools::test()/
#' testthat::test_dir() run and (thanks to R_KEEP_PKG_SOURCE) most R CMD
#' check invocations, but never true for a covr run (tests execute against
#' an --install-tests copy of the package where R CMD INSTALL has already
#' collapsed R/ into a single lazy-load database with no individual .R files
#' on disk) or for check flavors whose test working directory doesn't sit
#' under the checked-out repo at all. Callers must treat an empty result as
#' "can't verify here" (skip), not as "found zero files" -- see the
#' subscript-out-of-bounds / all-checks-vacuously-pass failure modes this
#' guarded against on 2026-08-11.
static_cleanup_source_files = function() {
	candidates = c(file.path("R", "EDI", "R"), file.path("..", "..", "R"))
	existing = candidates[file.exists(candidates)]
	if (length(existing) == 0L) return(character(0))
	list.files(existing[[1L]], pattern = "\\.R$", full.names = TRUE)
}

static_cleanup_matches = function(pattern, files = static_cleanup_source_files()) {
	matches = list()
	for (file in files) {
		lines = readLines(file, warn = FALSE)
		idx = grep(pattern, lines, perl = TRUE)
		idx = idx[!grepl("^\\s*#", lines[idx])]
		if (length(idx) == 0L) next
		rel = file.path("R", "EDI", "R", basename(file))
		matches[[length(matches) + 1L]] = data.frame(
			file = rel,
			line = idx,
			text = trimws(lines[idx]),
			stringsAsFactors = FALSE
		)
	}
	if (length(matches) == 0L) {
		return(data.frame(file = character(), line = integer(), text = character()))
	}
	do.call(rbind, matches)
}

static_cleanup_file_counts = function(matches) {
	if (nrow(matches) == 0L) return(integer())
	counts = table(matches$file)
	counts = counts[sort(names(counts))]
	out = as.integer(counts)
	names(out) = names(counts)
	out
}

test_that("static cleanup guardrail prevents new eval(body(Inference...)) usage", {
	skip_if(
		length(static_cleanup_source_files()) == 0L,
		"no readable per-file .R source found from this test's working directory (e.g. covr's --install-tests copy, or a check flavor whose test dir isn't under the source checkout) -- this guardrail can't verify anything without it"
	)
	matches = static_cleanup_matches("eval\\s*\\(\\s*body\\s*\\(\\s*Inference")
	# Counts ratcheted down 2026-08-17/18 by the KK/IVWC migrations
	# (fix_inference_hierarchy.md "KK And IVWC Estimators"): the IVWC classes
	# in each of these files dropped their eval(body(...)) overrides; the
	# remaining counts are the unmigrated OneLik siblings.
	# inference_survival_KK_strat_cox.R dropped to 0 at the 2026-08-18
	# InferenceSurvivalKKStratCoxPHOneLik migration (its own eval(body(...))
	# restatement was a verified no-op, same as every other KK leaf this
	# stretch) -- entry removed entirely.
	# inference_count_KK_cond_poisson.R dropped to 0 at the 2026-08-19
	# InferenceCountKKCondPoissonOneLik migration (both classes in that file
	# are now migrated) -- entry removed entirely.
	# inference_incidence_KK_cond_logit.R dropped to 0 at the 2026-08-19
	# InferenceIncidKKCondLogitOneLik migration -- entry removed entirely.
	# inference_survival_GLMM_weibull_frailty_loggamma.R and
	# inference_survival_GLMM_weibull_frailty_normal.R both dropped to 0 at 2026-08-19
	# (fix_inference_hierarchy.md "Static Cleanup", "Ban eval(body(Inference...))"):
	# their `approximate_bootstrap_distribution_beta_hat_T` restatements
	# inside the `...LegacyRaw` harvesting classes were verified no-ops
	# (both classes already splice `InferenceMixinKKPassThrough$public`
	# directly, so the raw source's own method was already present) --
	# both entries removed entirely, leaving no eval(body(Inference...))
	# usage anywhere in the tree.
	expected = integer(0)

	expect_identical(static_cleanup_file_counts(matches), expected[sort(names(expected))])
})

#' The generators that may still be assembled by hand from lists: the retained
#' legacy inheritance ladder (fix_inference_hierarchy.md "Base Deletion": the
#' algorithmic-compatibility bases plus InferenceParamBootstrap and the two
#' StandardModelCache bases), kept purely as internal component sources and as
#' `inherit =` targets for the migration golden tests' legacy generators. This
#' is the registry's own abstract-class list minus the root -- a package-level
#' constant, not a per-file count table -- so the allowance is enumerated, and
#' test-inference-class-registry.R separately proves none of them has a
#' concrete descendant.
static_cleanup_retained_legacy_generator_files = function(files = static_cleanup_source_files()) {
	generators = setdiff(EDI:::EDI_INFERENCE_ABSTRACT_CLASS_NAMES, "Inference")
	pattern = paste0("^\\s*(", paste(generators, collapse = "|"), ")\\s*=\\s*(R6::R6Class|define_inference_class)\\(")
	defining = vapply(files, function(file) {
		any(grepl(pattern, readLines(file, warn = FALSE), perl = TRUE))
	}, logical(1L))
	file.path("R", "EDI", "R", basename(files[defining]))
}

test_that("static cleanup guardrail bans raw component splicing", {
	skip_if(
		length(static_cleanup_source_files()) == 0L,
		"no readable per-file .R source found from this test's working directory (e.g. covr's --install-tests copy, or a check flavor whose test dir isn't under the source checkout) -- this guardrail can't verify anything without it"
	)
	# Closed 2026-08-23 (fix_inference_hierarchy.md "Static Cleanup", "Ban raw
	# component splicing outside define_inference_class()"). Until then this
	# test froze a per-file count table (20 files at its last ratchet). Every
	# remaining occurrence was eliminated: the 11 hoisted
	# `inference_<x>_public/_private` list objects were inlined into their
	# one `*Source` literal; the two `...LegacyRaw` survival KK generators
	# became plain leaf-only sources depending on `KKPassThrough`; the
	# classic `InferenceCountLikelihood` generator (zero inheritors) was
	# deleted and CountLikelihoodPlumbingSource became one literal; the two
	# StandardModelCache bases are mounted from their own canonical Source;
	# and the two KK compound bases are assembled through
	# define_inference_class() instead of compose_inference_mixins() +
	# `$public`/`$private` splicing. What remains is a structural invariant
	# with no counts in it, in three parts:

	# (1) Mixin components, legacy mixin compositions, and hoisted private
	#     lists: never spliced anywhere, full stop.
	matches = static_cleanup_matches(
		"\\b(InferenceMixin[A-Za-z0-9_]+\\$(public|private)|inference_[A-Za-z0-9_]+_(?:components\\$(?:public|private)|private))\\b"
	)
	expect_identical(static_cleanup_file_counts(matches), integer(0))

	# (2) `InferenceExt*` lists are single-host file-splits of a retained
	#     legacy ladder generator (contracts_mixins.R's header: "file-splits,
	#     not components"): each one may be spliced into exactly one file,
	#     and only a file that defines a retained legacy generator.
	ext_matches = static_cleanup_matches("\\bInferenceExt[A-Za-z0-9_]+\\$(public|private)\\b")
	retained_files = static_cleanup_retained_legacy_generator_files()
	expect_gt(length(retained_files), 0L)
	expect_identical(setdiff(unique(ext_matches$file), retained_files), character(0))
	ext_names = regmatches(ext_matches$text, gregexpr("InferenceExt[A-Za-z0-9_]+(?=\\$(public|private))", ext_matches$text, perl = TRUE))
	ext_hosts = split(rep(ext_matches$file, lengths(ext_names)), unlist(ext_names))
	multi_host = names(Filter(function(files) length(unique(files)) > 1L, ext_hosts))
	expect_identical(multi_host, character(0))

	# (3) A component `*Source` is consumed only by the factory (through the
	#     component registry) or by its own defining file (a retained legacy
	#     generator mounted from its canonical Source, or a Source trimming
	#     itself); no other file may reach into `XSource$public`/`$private`.
	source_matches = static_cleanup_matches("\\b[A-Za-z0-9_]+Source\\$(public|private)\\b")
	if (nrow(source_matches) > 0L) {
		source_names = regmatches(source_matches$text, gregexpr("[A-Za-z0-9_]+Source(?=\\$(public|private))", source_matches$text, perl = TRUE))
		uses = data.frame(
			file = rep(source_matches$file, lengths(source_names)),
			source = unlist(source_names),
			stringsAsFactors = FALSE
		)
		all_lines = lapply(static_cleanup_source_files(), readLines, warn = FALSE)
		names(all_lines) = file.path("R", "EDI", "R", basename(static_cleanup_source_files()))
		defines = function(file, source_name) {
			any(grepl(paste0("^\\s*", source_name, "\\s*=\\s*"), all_lines[[file]], perl = TRUE))
		}
		foreign = uses[!mapply(defines, uses$file, uses$source), , drop = FALSE]
		expect_identical(nrow(foreign), 0L, info = paste(unique(paste(foreign$file, foreign$source)), collapse = "; "))
	}
})

test_that("static cleanup guardrail bans R6 generator private member reads", {
	skip_if(
		length(static_cleanup_source_files()) == 0L,
		"no readable per-file .R source found from this test's working directory (e.g. covr's --install-tests copy, or a check flavor whose test dir isn't under the source checkout) -- this test would otherwise silently pass on a false-negative empty file list rather than actually checking anything"
	)
	files = c(
		static_cleanup_source_files(),
		list.files(".", pattern = "\\.R$", full.names = TRUE)
	)
	matches = static_cleanup_matches(
		"\\bInference[A-Za-z0-9_]+\\$(private_methods|private_fields)\\b",
		files = files
	)

	expect_equal(nrow(matches), 0L)
})

test_that("semantic classification through private is_a method probes cannot grow", {
	skip_if(
		length(static_cleanup_source_files()) == 0L,
		"no readable per-file .R source found from this test's working directory"
	)
	matches = static_cleanup_matches(
		"(has_private_method|object_has_private_method)\\s*\\(\\s*\"is_a_[A-Za-z0-9_]+\""
	)
	# Ratcheted 2 -> 1 when the rand-CI seed gate moved from an is_a probe to
	# an is.function(compute_asymp_confidence_interval) check (2026-08-17
	# rand-CI seed fix, fix_inference_hierarchy.md Follow-Ups).
	# Ratcheted 1 -> 0 (2026-08-19, fix_inference_hierarchy.md "Static
	# Cleanup", "Ban semantic classification through private method-name
	# sniffing"): the last remaining probe (is_a_kk_quantile_regr_ivwc /
	# is_a_kk_quantile_regr_one_lik in compute_treatment_estimate_during_
	# randomization_inference()) was replaced with a "kk_quantile_regr_ivwc"
	# capability check; the is_a_kk_quantile_regr_one_lik half was dead code
	# (KKQuantileRegrOneLik always overrides that whole method), so no
	# replacement capability was needed for it. Zero probes remain anywhere
	# in the package.
	expected = integer(0)
	expect_identical(static_cleanup_file_counts(matches), expected)
})

test_that("no component redeclares root-owned state", {
	# Closed 2026-08-23 (fix_inference_hierarchy.md "Static Cleanup", "Ban
	# component redeclaration of root-owned state" / Source Invariant 15).
	# Until then this test froze a per-component table of tolerated
	# redeclarations (16 components at its last ratchet: `m`,
	# `optimization_alg`, `cached_vc_params`, and the KK pass-through
	# family's y_temp/dead/w/X/any_censoring). Every one was removed from its
	# component source and moved from `owns_state` to `requires_state`; the
	# historical `optimization_alg = "lbfgs"` private-list default the KK
	# pass-through/GLMM components carried is now established through the
	# root setter in init_kk_passthrough()/init_kk_glmm_shared(). The
	# invariant is also enforced at class-definition time by
	# validate_inference_class_definition() (second block below).
	root_state = names(EDI:::Inference$private_fields)
	actual = lapply(EDI:::EDI_COMPONENT_SPECS, function(spec) {
		sort(intersect(spec$owns_state, root_state))
	})
	actual = actual[lengths(actual) > 0L]
	expect_length(actual, 0L)

	# Every mutable field has one owner: the root's private fields are never
	# declared by a lazy component source either (owns_state mirrors the
	# source's non-function private entries for lazy components).
	ns = asNamespace("EDI")
	for (component_name in names(EDI:::EDI_COMPONENT_SPECS)) {
		spec = EDI:::EDI_COMPONENT_SPECS[[component_name]]
		source = get(spec$source_name %||% component_name, envir = ns, inherits = TRUE)
		private = EDI:::inference_component_source_parts(source)$private
		fields = names(private)[!vapply(private, is.function, logical(1L))]
		expect_true(
			length(intersect(fields, root_state)) == 0L,
			info = paste(component_name, "redeclares root-owned state:", paste(intersect(fields, root_state), collapse = ", "))
		)
	}

	# And the factory refuses a component that tries.
	on.exit(EDI:::populate_inference_component_registry(), add = TRUE)
	EDI:::register_inference_component(EDI:::InferenceComponent(
		name = "InferenceTemporaryRedeclaresRootState",
		status = "active",
		file = "test",
		private = list(m = NULL),
		owns_state = "m"
	))
	expect_error(
		EDI:::define_inference_class(
			classname = "InferenceTemporaryRootStateHost",
			inherit = EDI:::Inference,
			components = "InferenceTemporaryRedeclaresRootState"
		),
		"redeclares root-owned state"
	)
})
