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
	# inference_survival_KK_clayton_copula.R and
	# inference_survival_KK_weibull_frailty.R both dropped to 0 at 2026-08-19
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
	# inference_survival_KK_strat_cox.R dropped to 0 at the 2026-08-18
	# InferenceSurvivalKKStratCoxPHOneLik migration (its raw
	# InferenceMixinKKPassThrough$public/private splices were replaced by
	# composing the KKPassThrough component via the new
	# SurvivalKKStratCoxOneLikPartialLikelihood component's dependency) --
	# entry removed entirely.
	# inference_count_KK_cond_poisson.R dropped to 0 at the 2026-08-19
	# InferenceCountKKCondPoissonOneLik migration (both classes in that file
	# are now migrated) -- entry removed entirely.
	# inference_incidence_KK_cond_logit.R dropped to 0 at the 2026-08-19
	# InferenceIncidKKCondLogitOneLik migration -- entry removed entirely.
	# inference_ordinal_KK_combined.R dropped to 0 at the 2026-08-19
	# InferenceOrdinalKKGLMM migration (fix_inference_hierarchy.md "KK And
	# IVWC Estimators", "Migrate KK GEE and GLMM classes"): its raw
	# `utils::modifyList(as.list(InferenceMixinKKGLMMShared$public/private),
	# ...)` splices were replaced by composing the registered `KKGLMM`
	# component directly -- entry removed entirely.
	# inference_survival_KK_clayton_copula.R and
	# inference_survival_KK_weibull_frailty.R both dropped 3->2 at
	# 2026-08-19 (fix_inference_hierarchy.md "Static Cleanup", "Ban
	# eval(body(Inference...))"): each file's `...LegacyRaw` class's
	# `eval(body(InferenceMixinKKPassThrough$public$...))` restatement --
	# itself a second, redundant textual reference to
	# `InferenceMixinKKPassThrough$public` beyond the class's own top-level
	# `modifyList(as.list(InferenceMixinKKPassThrough$public), ...)` splice
	# -- was removed as a verified no-op, dropping one match per file. The
	# structural splice itself remains (these `...LegacyRaw` classes are
	# still the harvesting source for the `SurvivalKKClaytonCopulaOneLik`/
	# `SurvivalKKWeibullFrailtyOneLik` components, awaiting the base-
	# deletion phase), so 2 occurrences remain in each file.
	# inference_incidence_KK_marginal_abstract.R dropped to 0 at 2026-08-19
	# (fix_inference_hierarchy.md "Full-Likelihood Estimators", "ModifiedPoisson
	# full-likelihood migration"): InferenceAbstractKKMarginalIncid's raw
	# `utils::modifyList(as.list(InferenceMixinKKPassThrough$public/private),
	# list(...))` splices were replaced by composing the registered
	# `KKPassThrough` component directly -- entry removed entirely.
	expected = c(
		"R/EDI/R/inference_all_abstract_KK_passthrough_compound.R" = 4L,
		"R/EDI/R/inference_all_abstract_asymp_lik.R" = 1L,
		"R/EDI/R/inference_all_abstract_asymp_lik_std_mod_cache.R" = 4L,
		"R/EDI/R/inference_all_abstract_count_likelihood.R" = 3L,
		"R/EDI/R/inference_all_abstract_non_param_boot.R" = 7L,
		"R/EDI/R/inference_all_abstract_param_boot.R" = 1L,
		"R/EDI/R/inference_all_abstract_rand.R" = 1L,
		"R/EDI/R/inference_count_composite_likelihood.R" = 2L,
		"R/EDI/R/inference_survival_KK_clayton_copula.R" = 2L,
		"R/EDI/R/inference_survival_KK_weibull_frailty.R" = 2L
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
		# KKQuantileRegrOneLik added at the 2026-08-18/19 quantile-regr OneLik
		# migration: same shape as the KKQuantileRegrIVWC entry above.
		KKQuantileRegrOneLik = "m",
		# KKLWACoxOneLikPartialLikelihood added at the 2026-08-18 LWA Cox
		# OneLik migration: the merged abstract+leaf source redeclares
		# `optimization_alg` (fixed "lbfgs" for this class) the same way
		# SurvivalKKClaytonCopulaIVWC/KKGLMM already do.
		KKLWACoxOneLikPartialLikelihood = "optimization_alg",
		# CountKKHurdlePoissonOneLikLikelihood added at the 2026-08-19
		# HurdlePoisson OneLik migration: redeclares "m" (of its four
		# owns_state fields -- m, cached_mod, use_rcpp,
		# max_abs_reasonable_coef -- only "m" is root-owned).
		CountKKHurdlePoissonOneLikLikelihood = "m",
		# SurvivalKKStratCoxOneLikPartialLikelihood added at the 2026-08-18
		# StratCox OneLik migration: same shape as KKLWACoxOneLikPartialLikelihood
		# above -- the merged source redeclares `optimization_alg` (fixed
		# "lbfgs" for this class). max_abs_reasonable_coef/best_X_colnames are
		# also owns_state on this component but are NOT root-owned (not in
		# Inference$private_fields), so they don't appear here.
		SurvivalKKStratCoxOneLikPartialLikelihood = "optimization_alg",
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
