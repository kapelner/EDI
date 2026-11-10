library(testthat)

# v1.0.5 TODO-193: R/EDI/R/inference_procedure_regime.R also holds the
# convergence-rate registry: for every design x inference class x procedure, the
# order of the size / coverage error and of the bias, the effective-n rule, the
# regularity and the basis, composed from procedure / design / class /
# class x design / triple layers by inference_convergence_expectation().
#
# The registry is base R only, so the file is sourced from the checkout. Checks
# that need the package (concrete class names, the applicable triples) use
# EDI internals: run under pkgload::load_all("R/EDI", compile = FALSE), or the
# installed package if it already carries the registry (they skip otherwise).

conv_repo_dir = function() {
	dir = normalizePath(testthat::test_path(), mustWork = FALSE)
	for (i in 1:8) {
		if (file.exists(file.path(dir, "R", "EDI", "R", "inference_procedure_regime.R"))) return(dir)
		dir = dirname(dir)
	}
	NA_character_
}
repo = conv_repo_dir()
skip_if(is.na(repo), "checkout not found")
conv_file = file.path(repo, "R", "EDI", "R", "inference_procedure_regime.R")
load_conv = function() {
	env = new.env(parent = baseenv())
	sys.source(conv_file, envir = env)
	env
}
conv = load_conv()
has_pkg_registry = function() {
	"EDI" %in% loadedNamespaces() && exists("inference_convergence_expectation", envir = asNamespace("EDI"), inherits = FALSE)
}

test_that("the file sources into an empty environment with base R only and is internally consistent", {
	env = new.env(parent = baseenv())
	expect_no_error(sys.source(conv_file, envir = env))
	expect_true(all(c("inference_convergence_expectation", "inference_convergence_validate",
		"EDI_CONVERGENCE_PROCEDURE_DEFAULTS", "EDI_CONVERGENCE_OVERRIDES") %in% ls(env)))
	expect_identical(env$inference_convergence_validate(), character(0))
})

test_that("the procedure layer has one entry per regime label and agrees with the regime", {
	d = conv$EDI_CONVERGENCE_PROCEDURE_DEFAULTS
	expect_setequal(d$procedure, names(conv$EDI_INFERENCE_PROCEDURE_REGIME))
	expect_false(anyDuplicated(d$procedure) > 0L)
	fin = conv$EDI_INFERENCE_PROCEDURE_REGIME[d$procedure] == "finite_sample"
	expect_identical(is.infinite(d$size_order), unname(fin))
	expect_true(all(d$size_order[!fin] >= 0 & is.finite(d$size_order[!fin])))
	# Orders: Bartlett and parametric-bootstrap-calibrated LR beat the first-order tests.
	ord = setNames(d$size_order, d$procedure)
	expect_true(all(ord[c("lik_ratio_bartlett_exact", "lik_ratio_bartlett_approx", "param_boot")] > ord[c("lik_ratio", "lik_ratio", "lik_ratio")]))
})

test_that("the procedure layer covers exactly the run_all_inference() sentinel labels", {
	skip_if(!"EDI" %in% loadedNamespaces() || !exists("EDI_INFERENCE_SUITE_CI_METHOD_PRIORITY", envir = asNamespace("EDI"), inherits = FALSE),
		"EDI internals not available")
	labels = union(
		vapply(EDI:::EDI_INFERENCE_SUITE_CI_METHOD_PRIORITY, `[[`, character(1L), "label"),
		vapply(EDI:::EDI_INFERENCE_SUITE_PVAL_METHOD_PRIORITY, `[[`, character(1L), "label")
	)
	expect_setequal(conv$EDI_CONVERGENCE_PROCEDURE_DEFAULTS$procedure, labels)
})

test_that("every class and design named in the override layers is a concrete EDI class", {
	skip_if(!has_pkg_registry(), "needs the loaded package with the convergence registry")
	reg = EDI:::inference_class_registry_as_list()
	concrete = names(Filter(function(m) !isTRUE(m$abstract), reg))
	o = conv$EDI_CONVERGENCE_OVERRIDES
	cls = unique(stats::na.omit(o$class))
	expect_true(length(cls) > 0L)
	expect_equal(setdiff(cls, concrete), character(0))
	des = unique(sub("@.*$", "", stats::na.omit(o$design)))
	ns = asNamespace("EDI")
	is_design = vapply(des, function(nm) exists(nm, envir = ns, inherits = FALSE) && inherits(get(nm, envir = ns), "R6ClassGenerator"), logical(1L))
	expect_equal(des[!is_design], character(0))
	# Every design label carrying a suffix is "<Design>@prob_T=<p>" as the calibration study writes it.
	lab = unique(stats::na.omit(o$design))
	lab = lab[grepl("@", lab, fixed = TRUE)]
	expect_true(all(grepl("^Design[A-Za-z0-9]+@prob_T=[0-9.]+$", lab)))
})

test_that("the validator rejects malformed layers", {
	e = conv$edi_convergence_entry
	val = function(extra) conv$inference_convergence_validate(overrides = rbind(conv$EDI_CONVERGENCE_OVERRIDES, extra))
	ok = e("class", class = "InferenceFoo", procedure = "wald", size_order = 2, basis = "theory", reference = "r")
	expect_identical(val(ok), character(0))
	expect_match(paste(val(rbind(ok, ok)), collapse = " "), "duplicate")
	expect_match(paste(val(e("class", class = "X", procedure = "wald", n_eff = "n_bogus")), collapse = " "), "n_eff")
	expect_match(paste(val(e("class", class = "X", procedure = "wald", size_order = 2, basis = "magic", reference = "r")), collapse = " "), "basis")
	expect_match(paste(val(e("class", class = "X", procedure = "wald", size_order = 2)), collapse = " "), "basis and a reference")
	expect_match(paste(val(e("class", class = "X", procedure = "wald", size_order = "unknown", basis = "theory", reference = "r")), collapse = " "), "unknown")
	expect_match(paste(val(e("class", class = "X", procedure = "rand", size_order = 2, basis = "theory", reference = "r")), collapse = " "), "finite-sample")
	expect_match(paste(val(e("class", class = "X", procedure = "no_such", n_eff = "n")), collapse = " "), "sentinel")
	expect_match(paste(val(e("class", class = "X", size_order = 1, basis = "theory", reference = "r")), collapse = " "), "name its procedures")
	expect_match(paste(val(e("design", class = "X", design = "D", n_eff = "n")), collapse = " "), "wrong shape")
	d = conv$EDI_CONVERGENCE_PROCEDURE_DEFAULTS
	expect_match(paste(conv$inference_convergence_validate(defaults = d[d$procedure != "wald", ]), collapse = " "), "cover exactly")
	bad = d; bad$size_order[bad$procedure == "rand"] = 1
	expect_match(paste(conv$inference_convergence_validate(defaults = bad), collapse = " "), "Inf exactly")
})

test_that("precedence is triple > class_design > class > design > procedure", {
	d = conv$EDI_CONVERGENCE_PROCEDURE_DEFAULTS
	e = conv$edi_convergence_entry
	mk = function(...) {
		o = do.call(rbind, list(...))
		expect_identical(conv$inference_convergence_validate(overrides = o), character(0))
		conv$inference_convergence_expectation("DesA", "ClsA", "wald", defaults = d, overrides = o)
	}
	row = function(layer, n_eff, ...) e(layer, n_eff = n_eff, ...)
	lay = list(
		design = row("design", "n_clusters", design = "DesA"),
		class = row("class", "n_events", class = "ClsA"),
		class_design = row("class_design", "n_pairs", design = "DesA", class = "ClsA"),
		triple = row("triple", "n_strata", design = "DesA", class = "ClsA", procedure = "wald")
	)
	expect_identical(mk()$n_eff, "n")
	expect_identical(mk()$n_eff_layer, "procedure")
	expect_identical(mk(lay$design)$n_eff, "n_clusters")
	expect_identical(mk(lay$design, lay$class)$n_eff, "n_events")
	expect_identical(mk(lay$design, lay$class, lay$class_design)$n_eff, "n_pairs")
	r = mk(lay$design, lay$class, lay$class_design, lay$triple)
	expect_identical(r$n_eff, "n_strata"); expect_identical(r$n_eff_layer, "triple")
	# Order of the rows does not matter.
	expect_identical(mk(lay$triple, lay$class_design, lay$class, lay$design)$n_eff, "n_strata")
	# A procedure-restricted entry beats an unrestricted one in the same layer.
	r = mk(row("class", "n_events", class = "ClsA"), row("class", "n_nonzero", class = "ClsA", procedure = "wald"))
	expect_identical(r$n_eff, "n_nonzero")
	# Fields resolve independently: an entry that sets only n_eff leaves the orders alone.
	r = mk(lay$triple)
	expect_equal(r$size_order, 1); expect_identical(r$size_layer, "procedure")
	# A design label beats the bare design class in the same layer; the bare class matches labels.
	o = rbind(row("design", "n_clusters", design = "DesA"), row("design", "n_min_arm", design = "DesA@prob_T=0.2"))
	expect_identical(conv$inference_convergence_expectation("DesA@prob_T=0.2", "ClsA", "wald", defaults = d, overrides = o)$n_eff, "n_min_arm")
	expect_identical(conv$inference_convergence_expectation("DesA@prob_T=0.3", "ClsA", "wald", defaults = d, overrides = o)$n_eff, "n_clusters")
	# Orders come with the basis of the layer that supplied them.
	o = e("class_design", design = "DesA", class = "ClsA", procedure = "wald", size_order = 0, regularity = "design_mismatch", basis = "literature", reference = "ref")
	r = conv$inference_convergence_expectation("DesA", "ClsA", "wald", defaults = d, overrides = o)
	expect_equal(r$size_order, 0); expect_identical(r$basis, "literature"); expect_identical(r$regularity, "design_mismatch")
	expect_identical(r$bias_basis, "assumed_default")
})

test_that("resolver basics: vectorised, recycled, honest about defaults and unknowns", {
	f = conv$inference_convergence_expectation
	expect_equal(nrow(f(character(0), character(0), character(0))), 0L)
	r = f("DesignFixedBernoulli", "InferenceContinOLS", c("wald", "rand", "exact", "lik_ratio_bartlett_exact"))
	expect_identical(r$regime, c("asymptotic", "finite_sample", "finite_sample", "asymptotic"))
	expect_equal(r$size_order, c(1, Inf, Inf, 2))
	# Untouched class + asymptotic procedure: visible as an assumed default; exact procedures are theory.
	expect_identical(r$basis, c("assumed_default", "theory", "theory", "assumed_default"))
	expect_error(f("DesignFixedBernoulli", "InferenceContinOLS", "mystery"), "mystery")
	# Explicit unknowns.
	u = f("DesignFixedBernoulli", "InferenceCountZeroInflatedPoisson", c("wald", "rand"))
	expect_true(is.na(u$size_order[1L])); expect_identical(u$basis[1L], "unknown"); expect_identical(u$regularity[1L], "mixture")
	expect_identical(u$size_order[2L], Inf)
	# Effective-n rules.
	expect_identical(f("DesignFixedBernoulli@prob_T=0.2", "InferenceContinOLS", c("wald", "rand"))$n_eff[1L], "n_min_arm")
	expect_identical(f("DesignSeqOneByOneKK14", "InferenceContinKKOLSOneLik", "wald")$n_eff, "n_pairs_plus_reservoir")
	expect_identical(f("DesignFixedBernoulli", "InferenceSurvivalCoxPHRegr", "wald")$n_eff, "n_events")
	expect_identical(f("DesignFixedBernoulli", "InferenceCountHurdlePoisson", "wald")$n_eff, "n_nonzero")
	# Design mismatch is an O(1) error (order 0), only for the unadjusted two-sample classes.
	m = f(c("DesignFixedBlocking", "DesignFixedBernoulli", "DesignFixedBlocking"),
		c("InferenceAllSimpleMeanDiffPooledVar", "InferenceAllSimpleMeanDiffPooledVar", "InferenceContinOLS"), "wald")
	expect_equal(m$size_order, c(0, 1, 1))
	expect_identical(m$regularity, c("design_mismatch", "regular", "regular"))
	# Density-based Wald is slower than n^-1.
	expect_lt(f("DesignFixedBernoulli", "InferenceContinQuantileRegr", "wald")$size_order, 1)
})

# ---- completeness over the applicable triples --------------------------------

applicable_triples = local({
	if (!has_pkg_registry() || !exists("inference_class_registry_as_list", envir = asNamespace("EDI"), inherits = FALSE)) return(NULL)
	cal = file.path(repo, "R", "package_tests", "calibration")
	if (!file.exists(file.path(cal, "calibration_study_common.R"))) return(NULL)
	env = new.env(parent = asNamespace("EDI"))
	assign("script_dir", cal, envir = env)
	# The calibration scripts call source() (global env); keep them out of it.
	assign("source", function(file, ...) sys.source(file, envir = env), envir = env)
	ok = tryCatch({
		suppressWarnings(suppressMessages(sys.source(file.path(cal, "calibration_study_common.R"), envir = env)))
		TRUE
	}, error = function(e) FALSE)
	if (!ok) return(NULL)
	spec = c(EDI:::EDI_INFERENCE_SUITE_CI_METHOD_PRIORITY, EDI:::EDI_INFERENCE_SUITE_PVAL_METHOD_PRIORITY)
	cap = vapply(spec, `[[`, "", "capability")
	lab = vapply(spec, `[[`, "", "label")
	procs_cache = new.env()
	procs = function(cl) {
		if (is.null(procs_cache[[cl]])) {
			procs_cache[[cl]] = sort(unique(lab[cap %in% EDI:::get_effective_capabilities(cl)]))
		}
		procs_cache[[cl]]
	}
	rows = list()
	# The calibration planner's own pairing: classes applicable to a constructed
	# design, per response type (cal_study_classes()).
	for (d in env$CAL_STUDY_DESIGNS) for (rt in env$CAL_RESPONSE_TYPES) {
		cls = tryCatch(suppressWarnings(suppressMessages(env$cal_study_classes(rt, d, 50L))), error = function(e) character(0))
		for (cl in cls) rows[[length(rows) + 1L]] = data.frame(design = d, class = cl, procedure = procs(cl), stringsAsFactors = FALSE)
	}
	unique(do.call(rbind, rows))
})

test_that("every applicable triple resolves to exactly one complete record", {
	skip_if(is.null(applicable_triples), "needs load_all(compile = FALSE) and the calibration scripts")
	tr = applicable_triples
	expect_gt(nrow(tr), 5000L)
	r = EDI:::inference_convergence_expectation(tr$design, tr$class, tr$procedure)
	expect_equal(nrow(r), nrow(tr))
	expect_identical(r$design, tr$design); expect_identical(r$class, tr$class); expect_identical(r$procedure, tr$procedure)
	for (f in c("regime", "n_eff", "regularity", "basis", "reference", "bias_basis", "bias_reference", "size_layer", "bias_layer", "n_eff_layer", "regularity_layer")) {
		expect_false(anyNA(r[[f]]), info = f)
	}
	expect_true(all(r$n_eff %in% EDI:::EDI_CONVERGENCE_N_EFF))
	expect_true(all(r$regularity %in% EDI:::EDI_CONVERGENCE_REGULARITY))
	expect_true(all(r$basis %in% EDI:::EDI_CONVERGENCE_BASIS))
	expect_true(all(r$bias_basis %in% EDI:::EDI_CONVERGENCE_BASIS))
	# Unknowns are explicit: an NA order always carries basis "unknown", and only then.
	expect_identical(is.na(r$size_order), r$basis == "unknown")
	expect_identical(is.na(r$bias_order), r$bias_basis == "unknown")
	expect_true(all(r$size_order[!is.na(r$size_order)] >= 0))
	# Regime and size order agree: finite-sample procedures have no error.
	expect_identical(r$regime == "finite_sample", is.infinite(r$size_order))
	# A triple that resolves only through the procedure default is flagged, not silent.
	expect_true(all(r$basis[r$size_layer == "procedure" & r$regime == "asymptotic"] == "assumed_default"))
})

test_that("the package copy of the registry equals the checkout file", {
	skip_if(!has_pkg_registry(), "needs the loaded package with the convergence registry")
	expect_identical(EDI:::EDI_CONVERGENCE_PROCEDURE_DEFAULTS, conv$EDI_CONVERGENCE_PROCEDURE_DEFAULTS)
	expect_identical(EDI:::EDI_CONVERGENCE_OVERRIDES, conv$EDI_CONVERGENCE_OVERRIDES)
})
