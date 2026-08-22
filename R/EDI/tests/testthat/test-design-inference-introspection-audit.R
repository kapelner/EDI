library(testthat)
library(EDI)

# Exhaustive audit: "all methods that are supported are run; only methods
# that are supported are run" (InferenceSuite's core discovery contract).
# Per user request, 2026-08-21 ("make an exhaustive audit"), following the
# targeted test-design-compatibility-reason.R (which spot-checks 4 classes)
# with a systematic sweep: for a representative design fixture on every axis
# `normalize_inference_design_metadata()`/`design_compatibility_reason()`
# actually branch on (response type; KK-matching; blocking, with both a
# compatible and an incompatible block structure; observational vs.
# randomized; general censoring), every exported, non-abstract Inference
# class is checked against the exact biconditional discovery is supposed to
# guarantee:
#
#   nm %in% des$applicable_inference_class_names()  <=>  ClassName$new(des) does not throw
#
# A class listed as applicable that actually throws is a false positive (an
# "only supported methods are run" violation -- discovery lied that this
# would work); a class NOT listed that actually constructs fine is a false
# negative (an "all supported methods are run" violation -- a real class
# missing from every report for no good reason). Both directions matter
# equally and are both asserted for every (fixture, class) pair.

all_exported_inference_classes = function() {
	registry = EDI:::inference_class_registry_as_list()
	Filter(function(nm) isTRUE(registry[[nm]]$exported) && !isTRUE(registry[[nm]]$abstract), names(registry))
}

# For every class in `classes`, assert the applicability <=> constructibility
# biconditional against `des`. `label` identifies the fixture in failure
# messages. Classes are constructed with default arguments only -- a class
# whose *default* configuration is compatible but a non-default argument
# combination is not remains correctly out of scope (documented behavior of
# `applicable_inference_class_names()` itself, see its own roxygen).
# Historical note (2026-08-21): this audit originally surfaced four count-
# family issues it had to allowlist away (InferenceCountHurdlePoisson's
# "unused argument (model_formula_zero = NULL)" and InferenceCountZeroInflated
# NegBin/Poisson's "infinite recursion" at construction -- both artifacts of
# the then-mid-flight InferenceCountZeroAugmentedPoissonAbstract migration,
# resolved by its completion -- and InferenceCountKKHurdlePoissonOneLik
# constructing on non-KK designs despite being registry-inapplicable, a
# missing KK-design guard, since added). All four are now pinned by
# test-count-family-audit-excluded-bugs.R and the allowlist is gone: every
# exported, non-abstract class is swept.
EDI_COUNT_FAMILY_UNRELATED_BUGS_EXCLUDED_FROM_THIS_AUDIT = character(0)

expect_discovery_matches_constructibility = function(des, label) {
	classes = setdiff(all_exported_inference_classes(), EDI_COUNT_FAMILY_UNRELATED_BUGS_EXCLUDED_FROM_THIS_AUDIT)
	applicable = des$applicable_inference_class_names()
	unavailable = names(des$unavailable_inference_classes_due_to_missing_packages())
	for (nm in classes) {
		if (nm %in% unavailable) next # missing optional package -- not this audit's concern
		gen = get(nm, envir = asNamespace("EDI"))
		constructed = tryCatch({ gen$new(des); TRUE }, error = function(e) FALSE)
		if (nm %in% applicable) {
			expect_true(constructed, info = sprintf("%s: %s listed applicable but construction threw", label, nm))
		} else if (!grepl("IVWC", nm, fixed = TRUE)) {
			# IVWC classes are excluded from discovery *by policy* (legacy,
			# deprecated in favor of the OneLik variants -- user decision,
			# 2026-08-19, encoded as the name-based IVWC filter in
			# is_inference_class_compatible_with_design_metadata()), not
			# because they can't construct -- most construct fine. Only the
			# "inapplicable but constructs" direction is skipped for them;
			# an IVWC class that discovery *did* list applicable would still
			# be held to the construction-must-succeed check above.
			expect_false(constructed, info = sprintf("%s: %s listed inapplicable but construction succeeded", label, nm))
		}
	}
}

make_randomized_fixed = function(n, response_type, prob_T = 0.5, ...) {
	des = DesignFixedBernoulli$new(n = n, response_type = response_type, prob_T = prob_T, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects(...)
	des
}

add_response = function(des, response_type, n, w) {
	switch(response_type,
		continuous = des$add_all_subject_responses(rnorm(n)),
		incidence = des$add_all_subject_responses(rbinom(n, 1, plogis(0.3 * w))),
		count = des$add_all_subject_responses(rpois(n, exp(0.2 * w + 0.5))),
		proportion = {
			mu = plogis(0.3 * w); phi = 20
			y = rbeta(n, mu * phi, (1 - mu) * phi)
			des$add_all_subject_responses(pmax(pmin(y, 1 - 1e-6), 1e-6))
		},
		ordinal = {
			y_cont = 0.4 * w + rnorm(n)
			des$add_all_subject_responses(as.numeric(cut(y_cont, breaks = c(-Inf, -0.5, 0.5, Inf), labels = FALSE)))
		},
		survival = {
			y = rexp(n, 0.1 * exp(0.2 * w))
			dead = rbinom(n, 1, 0.8)
			y_exact = ifelse(dead == 1, y, NA_real_)
			y_L = ifelse(dead == 1, NA_real_, y)
			y_R = ifelse(dead == 1, NA_real_, Inf)
			des$add_all_subject_responses(y_exact, y_L, y_R)
		}
	)
	invisible(des)
}

for (rt in c("continuous", "incidence", "count", "proportion", "ordinal", "survival")) {
	local({
		rt = rt
		test_that(sprintf("discovery matches constructibility: non-blocking, non-KK, randomized, %s", rt), {
			set.seed(1000L)
			n = 24L
			des = make_randomized_fixed(n, rt)
			add_response(des, rt, n, des$get_w())
			expect_discovery_matches_constructibility(des, sprintf("randomized/%s", rt))
		})
	})
}

test_that("discovery matches constructibility: KK-matching, continuous", {
	set.seed(1001L)
	n = 24L
	des = DesignSeqOneByOneKK21$new(n = n, response_type = "continuous", verbose = FALSE)
	X = as.data.frame(matrix(rnorm(n * 3), nrow = n))
	colnames(X) = paste0("x", 1:3)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	des$add_all_subject_responses(rnorm(n))
	expect_discovery_matches_constructibility(des, "KK/continuous")
})

test_that("discovery matches constructibility: KK-matching, incidence", {
	set.seed(1002L)
	n = 24L
	des = DesignSeqOneByOneKK21$new(n = n, response_type = "incidence", verbose = FALSE)
	X = as.data.frame(matrix(rnorm(n * 3), nrow = n))
	colnames(X) = paste0("x", 1:3)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	des$add_all_subject_responses(rbinom(n, 1, plogis(0.3 * des$get_w())))
	expect_discovery_matches_constructibility(des, "KK/incidence")
})

test_that("discovery matches constructibility: blocking, incidence, compatible structure (equal blocks, prob_T = 0.5)", {
	set.seed(1003L)
	n = 20L
	des = DesignFixedBlocking$new(n = n, response_type = "incidence", strata_cols = "x2", equal_block_sizes = TRUE)
	X = data.frame(x1 = rnorm(n), x2 = rep(c("a", "b"), n / 2L))
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rbinom(n, 1, plogis(0.3 * des$get_w())))
	expect_discovery_matches_constructibility(des, "blocking/incidence/compatible")
})

test_that("discovery matches constructibility: blocking, incidence, INcompatible structure (unequal blocks)", {
	# Unequal block sizes: CMH/ExtendedRobins declare a design_compatibility_
	# reason for this, so they must be excluded here despite otherwise
	# matching response-type/blocking metadata -- the case this whole file
	# exists to guard, not just the response-type-only filters.
	set.seed(1004L)
	n = 20L
	des = DesignFixedBlocking$new(n = n, response_type = "incidence", m = c(rep(1L, 6L), rep(2L, 14L)))
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rbinom(n, 1, plogis(0.3 * des$get_w())))
	expect_discovery_matches_constructibility(des, "blocking/incidence/incompatible")
	expect_false("InferenceIncidCMH" %in% des$applicable_inference_class_names())
	expect_false("InferenceIncidExtendedRobins" %in% des$applicable_inference_class_names())
})

test_that("discovery matches constructibility: non-blocking, incidence, INcompatible allocation (prob_T != 0.5)", {
	set.seed(1005L)
	n = 20L
	des = make_randomized_fixed(n, "incidence", prob_T = 0.3)
	add_response(des, "incidence", n, des$get_w())
	expect_discovery_matches_constructibility(des, "non-blocking/incidence/uneven-allocation")
	expect_false("InferenceIncidCMH" %in% des$applicable_inference_class_names())
})

test_that("discovery matches constructibility: observational, incidence", {
	set.seed(1006L)
	n = 20L
	des = ObservationalDesign$new(response_type = "incidence", n = n, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects(w_precomputed = rbinom(n, 1, 0.5))
	des$add_all_subject_responses(rbinom(n, 1, 0.4))
	expect_discovery_matches_constructibility(des, "observational/incidence")
})

test_that("discovery matches constructibility: survival with general (left/interval) censoring", {
	set.seed(1007L)
	n = 24L
	des = make_randomized_fixed(n, "survival")
	w = des$get_w()
	y = rexp(n, 0.1 * exp(0.2 * w))
	# Mix of exact, right-, left-, and interval-censored observations so
	# `any_censoring()`/`has_general_censoring()` are both TRUE -- exercises
	# the `supports_general_censoring` axis `is_inference_class_compatible_
	# with_design_metadata()` gates on, which the plain-right-censoring-only
	# survival fixture above never triggers.
	kind = sample(c("exact", "right", "left", "interval"), n, replace = TRUE)
	y_exact = ifelse(kind == "exact", y, NA_real_)
	y_L = ifelse(kind == "right", y, ifelse(kind == "left", 0, ifelse(kind == "interval", y, NA_real_)))
	y_R = ifelse(kind == "right", Inf, ifelse(kind == "left", y, ifelse(kind == "interval", y + 1, NA_real_)))
	des$add_all_subject_responses(y_exact, y_L, y_R)
	expect_discovery_matches_constructibility(des, "survival/general-censoring")
})

test_that("run_all_inference(): randomization-dependent sentinels are never fanned out for an observational design", {
	# Companion to the class-level discovery sweep above, at the sentinel
	# level: EDI_INFERENCE_SUITE_RANDOMIZATION_DEPENDENT_SENTINELS (derived
	# from the capability-priority tables, not hand-typed -- see that
	# constant's own docs) must exclude "rand"/"rand_bootstrap" from every
	# task built against a design that doesn't support randomization draws.
	set.seed(1008L)
	n = 20L
	des = ObservationalDesign$new(response_type = "continuous", n = n, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects(w_precomputed = rbinom(n, 1, 0.5))
	des$add_all_subject_responses(rnorm(n))
	expect_false(des$supports_randomization_draw())

	suite = InferenceSuite$new(des)
	res = suite$run_all_inference(screen = TRUE, html = FALSE, plots = FALSE, pdf = FALSE, classes = "InferenceAllSimpleMeanDiff")
	expect_false(any(res$results_table$method %in% c("rand", "rand_bootstrap")))
})

# Compute-level layer (per user request, 2026-08-21): the construction-only
# sweep above cannot catch a class whose design-structure incompatibility is
# only enforced at *compute* time (construction always succeeds) -- exactly
# the shape both the "rand"-pval-for-incidence bug and the
# InferenceIncidExactFisher bug had, neither of which a construction-only
# check would ever flag. Restricted to the fast closed-form sentinels
# (wald/exact/rand) on a representative subset of fixtures, not the full
# sweep, to keep runtime bounded -- a full methods = NULL fan-out across
# every applicable class here was observed to run past a 280s budget.
expect_no_silently_masked_capability = function(des, label, methods = c("wald", "exact", "rand")) {
	suite = InferenceSuite$new(des)
	res = suite$run_all_inference(screen = TRUE, html = FALSE, plots = FALSE, pdf = FALSE, methods = methods)
	tbl = res$results_table
	ok = tbl[tbl$status == "ok", , drop = FALSE]
	if (nrow(ok) > 0L) {
		expect_true(all(is.finite(ok$estimate)), info = sprintf("%s: status = 'ok' row(s) with a non-finite estimate", label))
	}
	# A row whose `method` names a real requested sentinel and whose
	# estimate computed fine, yet which produced neither a finite CI bound
	# nor a p-value, is the signature of a capability that was attempted
	# and silently degraded (a compute-time stop() swallowed by the suite's
	# tryCatch) rather than either succeeding or being recognized as
	# inapplicable up front -- the InferenceIncidExactZhang shape
	# (2026-08-21: est = 2.17, everything else NA, status "ok").
	# Deliberately keyed on the *values* (ci_a/ci_b/pval), not on
	# `ci_method`/`pval_method` being NA: the suite's attempted-label
	# convention reports the sentinel label in those columns even when the
	# call itself failed, so a label-based filter misses exactly these rows
	# (it missed Zhang's, which said ci_method = "exact" with NA bounds).
	suspicious = tbl[
		!is.na(tbl$method) & tbl$status == "ok" & is.finite(tbl$estimate) &
			!is.finite(tbl$ci_a) & !is.finite(tbl$ci_b) & !is.finite(tbl$pval),
		, drop = FALSE
	]
	expect_identical(
		nrow(suspicious), 0L,
		info = sprintf(
			"%s: %d row(s) attempted a sentinel that produced neither a CI nor a p-value while still status = 'ok' (%s)",
			label, nrow(suspicious), paste(unique(suspicious$inference_class), collapse = ", ")
		)
	)
}

test_that("compute-level: no silently masked capability for randomized/incidence", {
	set.seed(2000L)
	n = 20L
	des = make_randomized_fixed(n, "incidence")
	add_response(des, "incidence", n, des$get_w())
	expect_no_silently_masked_capability(des, "randomized/incidence")
})

test_that("compute-level: no silently masked capability for KK/incidence", {
	set.seed(2001L)
	n = 20L
	des = DesignSeqOneByOneKK21$new(n = n, response_type = "incidence", verbose = FALSE)
	X = as.data.frame(matrix(rnorm(n * 2), nrow = n))
	colnames(X) = paste0("x", 1:2)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	des$add_all_subject_responses(rbinom(n, 1, plogis(0.3 * des$get_w())))
	expect_no_silently_masked_capability(des, "KK/incidence")
})

# Registry-style completeness invariant (per user request, 2026-08-21: "is
# this auditable in a registry though?"), same discipline as test-capability-
# tables.R's "public_methods_for_capability catalogs every compute_*..."
# test -- converts what was, twice this session, a one-off manual grep that
# found a new gap each time (Wilcox/CMH/ExtendedRobins, then separately
# ExactBinomial/ExactFisher) into a permanent, automatically-re-run check:
# every `initialize()` body across every `inference_*.R` source file that
# tests a design-*structure* predicate (`is_blocking_design()`,
# `get_prob_T()`, `get_block_ids()`, `randomization_family()`,
# `is_a_kk_matching_capable()`) on `des_obj` must also define
# `design_compatibility_reason` somewhere in that same file, mirroring the
# `stop_if_design_incompatible()` pattern all five currently-known classes
# (Wilcox/KKWilcoxIVWC/CMH/ExtendedRobins/ExactBinomial/ExactFisher) already
# use. Scoped to `initialize()` specifically (not every `stop()` in the
# file) -- construction-time is the one category with a single canonical
# predicate name discovery can rely on; compute-time-only gates (the
# `rand`-pval-for-incidence shape) are structurally more heterogeneous
# (different predicate names per class) and not covered by this test, a
# known, documented scope limit rather than a silent gap.
test_that("Every initialize() that tests a design-structure predicate on des_obj also defines design_compatibility_reason", {
	# Installed packages don't ship their original .R text files (only the
	# lazy-load database), so this needs the checked-out repo's own source
	# tree. testthat runs with tests/testthat/ as the working directory
	# (test_check()/test_dir()'s own convention), so "../../R" is EDI/R/ --
	# deliberately not testthat::test_path(), which requires an active
	# testthat run scope and errors when this file is merely source()'d for
	# a quick manual check.
	src_dir = "../../R"
	if (!dir.exists(src_dir)) skip("Repo source tree (../../R relative to tests/testthat) not found -- source-level audit needs it.")
	files = list.files(src_dir, pattern = "^inference_.*\\.R$", full.names = TRUE)
	structural_predicate_pattern = paste(
		c("is_blocking_design\\s*\\(", "get_prob_T\\s*\\(", "get_block_ids\\s*\\(",
			"randomization_family\\s*\\(", "is_a_kk_matching_capable\\s*\\("),
		collapse = "|"
	)
	violations = character()
	for (f in files) {
		# The root Inference$initialize() (inference_all_abstract.R) reads
		# several structural predicates purely to *store* them as instance
		# fields (is_KK, has_match_structure, supports_design_randomization_
		# draw, ...) -- field setup, not compatibility gating; its only
		# structure-conditional stop() (general censoring) is already a
		# registry metadata axis (supports_general_censoring) discovery
		# filters on. Exempted by name, with this reason.
		if (identical(basename(f), "inference_all_abstract.R")) next
		lines = readLines(f, warn = FALSE)
		init_starts = grep("initialize\\s*=\\s*function\\s*\\(\\s*des_obj", lines)
		if (length(init_starts) == 0L) next
		has_reason = any(grepl("design_compatibility_reason", lines, fixed = TRUE))
		for (start in init_starts) {
			# Approximate the initialize() body as everything from its own
			# line up to the next public-method-sibling definition (a line
			# at the same 2-tab indent matching `<name> = function`), capped
			# at 80 lines as a sane backstop -- exact brace-matching isn't
			# worth it for a heuristic audit test, and this codebase's
			# consistent tab-indent style makes the sibling-line heuristic
			# reliable in practice.
			end = length(lines)
			for (i in seq.int(start + 1L, min(start + 80L, length(lines)))) {
				if (grepl("^\\t\\t[A-Za-z_][A-Za-z0-9_.]*\\s*=\\s*function", lines[i])) {
					end = i - 1L
					break
				}
			}
			body = lines[start:end]
			predicate_hits = grep(structural_predicate_pattern, body, value = TRUE)
			if (length(predicate_hits) == 0L || has_reason) next
			# A predicate read with no stop() anywhere in the same body is
			# field setup/configuration, not a gate -- only gating uses need
			# a matching discovery predicate.
			if (!any(grepl("stop\\(", body))) next
			# KK gates in KK-named files are already covered by discovery's
			# name-based requires_kk filter (`grepl("KK", nm)` in
			# inference_class_compatibility_metadata()) -- the per-class
			# stop() is defense-in-depth, not a discovery gap; verified by
			# this file's own KK fixture sweeps. Only exempts files whose
			# *sole* structural predicate is is_a_kk_matching_capable().
			only_kk_predicate = all(grepl("is_a_kk_matching_capable", predicate_hits))
			if (only_kk_predicate && grepl("KK", basename(f), fixed = TRUE)) next
			violations = c(violations, sprintf("%s:%d", basename(f), start))
		}
	}
	expect_identical(
		violations, character(),
		info = paste0(
			"initialize() tests a design-structure predicate but the file defines no ",
			"design_compatibility_reason -- either add one (see InferenceAllSimpleWilcox/",
			"InferenceIncidCMH/InferenceIncidExtendedRobins/InferenceIncidExactBinomial/",
			"InferenceIncidExactFisher for the pattern) or, if this predicate use is not ",
			"actually a design-compatibility gate, explain why in a comment near it: ",
			paste(violations, collapse = ", ")
		)
	)
})

test_that("compute-level: no silently masked capability for blocking, incidence, compatible structure", {
	set.seed(2002L)
	n = 20L
	des = DesignFixedBlocking$new(n = n, response_type = "incidence", strata_cols = "x2", equal_block_sizes = TRUE)
	X = data.frame(x1 = rnorm(n), x2 = rep(c("a", "b"), n / 2L))
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rbinom(n, 1, plogis(0.3 * des$get_w())))
	expect_no_silently_masked_capability(des, "blocking/incidence/compatible")
})

test_that("compute-level: no silently masked capability for observational blocks, incidence", {
	# The fixture that would have caught InferenceIncidExactZhang's
	# compute-time-only design gate (2026-08-21, user-reported: constructed
	# and estimated fine on ObservationalDesignBlocks, but every exact
	# CI/p-value silently degraded to NA with status = "ok") -- none of the
	# three compute-level fixtures above is observational, which is exactly
	# why the audit missed it. Zhang requires Bernoulli-capable or
	# KK-matching designs; observational-with-blocks is neither.
	set.seed(2003L)
	n = 20L
	m = rep(1:4, each = 5L)
	des = ObservationalDesignBlocks$new(response_type = "incidence", m = m, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects(w_precomputed = rbinom(n, 1, 0.5))
	des$add_all_subject_responses(rbinom(n, 1, 0.4))
	expect_no_silently_masked_capability(des, "observational-blocks/incidence")
})
