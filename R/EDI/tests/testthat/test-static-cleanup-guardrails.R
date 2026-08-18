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
	expected = c(
		"R/EDI/R/inference_count_KK_cond_poisson.R" = 2L,
		"R/EDI/R/inference_incidence_KK_cond_logit.R" = 1L,
		"R/EDI/R/inference_survival_KK_clayton_copula.R" = 1L,
		"R/EDI/R/inference_survival_KK_strat_cox.R" = 1L,
		"R/EDI/R/inference_survival_KK_weibull_frailty.R" = 1L
	)

	expect_identical(static_cleanup_file_counts(matches), expected[sort(names(expected))])
})

test_that("static cleanup guardrail prevents new raw component splicing", {
	skip_if(
		length(static_cleanup_source_files()) == 0L,
		"no readable per-file .R source found from this test's working directory (e.g. covr's --install-tests copy, or a check flavor whose test dir isn't under the source checkout) -- this guardrail can't verify anything without it"
	)
	matches = static_cleanup_matches(
		"\\b(Inference(?:Ext|Mixin)[A-Za-z0-9_]+\\$(public|private)|inference_[A-Za-z0-9_]+_(?:components\\$(?:public|private)|private))\\b"
	)
	# Counts ratcheted down 2026-08-17/18 by the KK/IVWC migrations
	# (fix_inference_hierarchy.md "KK And IVWC Estimators"): each migrated
	# IVWC class's raw mixin splices were replaced by registered-component
	# composition; the remaining counts are the unmigrated OneLik siblings
	# and the compound/abstract bases still awaiting the base-deletion phase.
	expected = c(
		"R/EDI/R/inference_all_abstract_KK_passthrough_compound.R" = 4L,
		"R/EDI/R/inference_all_abstract_asymp_lik.R" = 1L,
		"R/EDI/R/inference_all_abstract_asymp_lik_std_mod_cache.R" = 4L,
		"R/EDI/R/inference_all_abstract_count_likelihood.R" = 3L,
		"R/EDI/R/inference_all_abstract_non_param_boot.R" = 7L,
		"R/EDI/R/inference_all_abstract_param_boot.R" = 1L,
		"R/EDI/R/inference_all_abstract_rand.R" = 1L,
		"R/EDI/R/inference_count_composite_likelihood.R" = 2L,
		"R/EDI/R/inference_count_KK_cond_poisson.R" = 6L,
		"R/EDI/R/inference_incidence_KK_cond_logit.R" = 3L,
		"R/EDI/R/inference_incidence_KK_marginal_abstract.R" = 2L,
		"R/EDI/R/inference_ordinal_KK_combined.R" = 2L,
		"R/EDI/R/inference_survival_KK_clayton_copula.R" = 3L,
		"R/EDI/R/inference_survival_KK_strat_cox.R" = 3L,
		"R/EDI/R/inference_survival_KK_weibull_frailty.R" = 3L
	)

	expect_identical(static_cleanup_file_counts(matches), expected[sort(names(expected))])
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
	expected = c("R/EDI/R/inference_all_abstract_rand.R" = 1L)
	expect_identical(static_cleanup_file_counts(matches), expected)
})

test_that("component redeclarations of root-owned state cannot grow", {
	root_state = names(EDI:::Inference$private_fields)
	actual = lapply(EDI:::EDI_COMPONENT_SPECS, function(spec) {
		sort(intersect(spec$owns_state, root_state))
	})
	actual = actual[lengths(actual) > 0L]
	expected = list(
		# KKQuantileRegrIVWC added at the 2026-08-18 quantile-regr IVWC
		# migration: the merged abstract+leaf source redeclares `m` (KK
		# match-vector) the same way KKPassThrough/KKGEE/KKGLMM already do.
		KKQuantileRegrIVWC = "m",
		# KKLWACoxOneLikPartialLikelihood added at the 2026-08-18 LWA Cox
		# OneLik migration: the merged abstract+leaf source redeclares
		# `optimization_alg` (fixed "lbfgs" for this class) the same way
		# SurvivalKKClaytonCopulaIVWC/KKGLMM already do.
		KKLWACoxOneLikPartialLikelihood = "optimization_alg",
		# Trimmed at the 2026-08-17 WeibullMarginal migration: the spec was
		# reshaped leaf-only (KK state now arrives via the KKPassThrough
		# dependency), leaving only the class-specific VC-parameter cache.
		SurvivalKKWeibullMarginal = "cached_vc_params",
		SurvivalKKClaytonCopulaIVWC = "optimization_alg",
		SurvivalKKClaytonCopulaOneLik = sort(c("m", "y_temp", "dead", "w", "X", "any_censoring", "optimization_alg")),
		SurvivalKKWeibullFrailtyIVWC = sort(c("optimization_alg", "any_censoring", "m")),
		SurvivalKKWeibullFrailtyOneLik = sort(c("m", "y_temp", "dead", "w", "X", "optimization_alg")),
		KKGEE = "m",
		KKGLMM = sort(c("m", "optimization_alg")),
		KKPassThrough = sort(c("m", "y_temp", "dead", "w", "X", "any_censoring", "optimization_alg"))
	)
	expect_identical(actual, expected)
})
