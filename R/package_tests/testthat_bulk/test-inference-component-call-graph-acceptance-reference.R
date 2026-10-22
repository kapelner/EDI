library(testthat)
library(EDI)

find_edi_repo_root <- function(start = getwd()) {
	path <- normalizePath(start, mustWork = TRUE)
	repeat {
		if (file.exists(file.path(path, "R", "package_tests", "inference_component_call_graph_helpers.R"))) {
			return(path)
		}
		parent <- dirname(path)
		if (identical(parent, path)) stop("Could not locate the EDI checkout root.", call. = FALSE)
		path <- parent
	}
}

repo_root <- find_edi_repo_root()
call_graph_helpers <- new.env(parent = environment())
sys.source(file.path(repo_root, "R", "package_tests", "inference_component_call_graph_helpers.R"),
		envir = call_graph_helpers)
component_graph <- call_graph_helpers$inference_component_call_graph(
	file.path(repo_root, "R", "EDI", "R"), ns = asNamespace("EDI"))

test_that("the AST component graph preserves the TODO-1 class/method-owner golden", {
	baseline <- utils::read.csv(
		file.path(repo_root, "R", "package_tests", "testthat_bulk", "fixtures",
			"inference_component_registry_baseline.csv"),
		stringsAsFactors = FALSE, check.names = FALSE)

	graph_surface <- component_graph$surface[order(component_graph$surface$class), , drop = FALSE]
	baseline <- baseline[order(baseline$class), , drop = FALSE]
	# TODO-98 added these private guard methods after TODO-1's frozen baseline.
	# Keep that reviewed additive delta explicit rather than silently rewriting
	# the golden; unrelated method/component drift still fails the comparison.
	weibull_class <- "InferenceSurvivalWeibullRegr"
	weibull_row <- which(baseline$class == weibull_class)
	weibull_methods <- strsplit(baseline$private_methods[[weibull_row]], "|", fixed = TRUE)[[1L]]
	weibull_methods <- c(weibull_methods, paste0(c(
		"param_boot_compute_lik_ratio_bootstrap_confidence_interval",
		"param_boot_compute_lik_ratio_bootstrap_two_sided_pval",
		"stop_weibull_parametric_bootstrap_for_general_censoring"
	), "@", weibull_class))
	baseline$private_methods[[weibull_row]] <- paste(sort(unique(weibull_methods)), collapse = "|")
	# v1.0.5 TODO-57 (2026-10-22) added the NonparametricBootstrap private method
	# finalize_bootstrap_statistics_matrix, bound on the same host as its sibling
	# approximate_bootstrap_statistics_beta_hat_T. Reviewed additive delta.
	baseline$private_methods <- vapply(baseline$private_methods, function(s) {
		x <- strsplit(s, "|", fixed = TRUE)[[1L]]
		anchor <- grep("^approximate_bootstrap_statistics_beta_hat_T@", x, value = TRUE)
		if (!length(anchor)) return(s)
		host <- sub("^[^@]*@", "", anchor[1L])
		paste(sort(unique(c(x, paste0("finalize_bootstrap_statistics_matrix@", host)))), collapse = "|")
	}, character(1L), USE.NAMES = FALSE)
	# v1.0.5 TODO-97 decision 2 (2026-10-22) deleted the dynamic-dispatch
	# helper load_resampling_draw_into_worker(); its five callers call their
	# own loader directly. Reviewed removal delta: the method disappears from
	# every class that had it, on the same host, and nothing else changes.
	baseline$private_methods <- vapply(baseline$private_methods, function(s) {
		x <- strsplit(s, "|", fixed = TRUE)[[1L]]
		paste(x[!startsWith(x, "load_resampling_draw_into_worker@")], collapse = "|")
	}, character(1L), USE.NAMES = FALSE)
	# v1.0.5 TODO-97 Option A (2026-10-22) added the ResamplingCore component
	# (shared resampling cache/contract, jackknife-unit validators, extreme-
	# estimate guard, NULL create_bootstrap_worker_state() default) and
	# rewrote component dependencies to the measured call graph. Reviewed
	# deltas, each asserted exactly below rather than by refreshing the golden:
	# (1) components: ResamplingCore is added to every class that composed any
	#     resampling/Wald component (103 of 106) and to none of the three exact
	#     incidence classes; with it removed, every list equals the old list.
	#     The order is unchanged except for the classes in
	#     `todo97_reordered`, where a declared dependency now forces a
	#     component earlier (e.g. Wald -> NonparametricBootstrap places
	#     NonparametricBootstrap before Wald in the Count composite classes);
	#     there the set is unchanged and a source-loaded before/after dispatch
	#     comparison showed every method still binds the same body (the one
	#     binding that would have changed, InferenceCustomAsymp's four
	#     reusable-worker hooks, is pinned by host overrides with the old
	#     NonparametricBootstrap bodies).
	# (2) methods: the classes that gain ResamplingCore without previously
	#     composing the components its methods came from gain those methods,
	#     on their own host: InferenceCustomRand (and its subclass
	#     InferenceRandCustom) gain the jackknife-unit validators, the extreme
	#     guard and the worker-state default; InferenceCustomBoot gains the two
	#     jackknife-unit validators its NonparametricBootstrap code already
	#     called. No method is removed or rehosted.
	todo97_reordered <- c(
		"InferenceContinKKOLSOneLik", "InferenceContinKKQuantileRegrOneLik",
		"InferenceCountKKCondPoissonOneLik", "InferenceCountKKHurdlePoissonOneLik",
		"InferenceCountPoissonKKGEE", "InferenceCountQuasiPoisson",
		"InferenceCountRobustPoisson", "InferenceCustomAsymp",
		"InferenceIncidKKCondLogitOneLik", "InferenceIncidKKGEE",
		"InferenceOrdinalKKGEE", "InferencePropKKGEE",
		"InferencePropKKQuantileRegrOneLik", "InferenceSurvivalKKLWACoxPHOneLik",
		"InferenceSurvivalKKStratCoxPHOneLik"
	)
	todo97_no_core <- c("InferenceIncidExactBinomial", "InferenceIncidExactFisher", "InferenceIncidExactZhang")
	todo97_added_private <- list(
		InferenceCustomRand = c("assert_jackknife_supported", "bootstrap_estimates_extreme",
			"create_bootstrap_worker_state", "normalize_jackknife_unit"),
		InferenceRandCustom = c("assert_jackknife_supported", "bootstrap_estimates_extreme",
			"create_bootstrap_worker_state", "normalize_jackknife_unit"),
		InferenceCustomBoot = c("assert_jackknife_supported", "normalize_jackknife_unit")
	)
	todo97_host <- c(InferenceCustomRand = "InferenceCustomRand",
		InferenceRandCustom = "InferenceCustomRand", InferenceCustomBoot = "InferenceCustomBoot")
	for (class_name in names(todo97_added_private)) {
		row <- which(baseline$class == class_name)
		x <- strsplit(baseline$private_methods[[row]], "|", fixed = TRUE)[[1L]]
		expect_false(any(paste0(todo97_added_private[[class_name]], "@", todo97_host[[class_name]]) %in% x), info = class_name)
		baseline$private_methods[[row]] <- paste(sort(unique(c(x,
			paste0(todo97_added_private[[class_name]], "@", todo97_host[[class_name]])))), collapse = "|")
	}
	rownames(graph_surface) <- rownames(baseline) <- NULL
	expect_identical(nrow(graph_surface), 106L)
	expect_identical(graph_surface$class, baseline$class)
	new_components <- strsplit(graph_surface$components, "|", fixed = TRUE)
	old_components <- strsplit(baseline$components, "|", fixed = TRUE)
	has_core <- vapply(new_components, function(x) "ResamplingCore" %in% x, logical(1L))
	expect_identical(sum(has_core), 103L)
	expect_identical(sort(graph_surface$class[!has_core]), sort(todo97_no_core))
	without_core <- lapply(new_components, setdiff, "ResamplingCore")
	reordered <- graph_surface$class %in% todo97_reordered
	expect_identical(without_core[!reordered], old_components[!reordered])
	expect_identical(lapply(without_core[reordered], sort), lapply(old_components[reordered], sort))
	expect_false(any(mapply(identical, without_core[reordered], old_components[reordered])),
		info = "a listed reordered class is back in its old order; drop it from todo97_reordered")
	graph_surface$components <- baseline$components <- NULL
	expect_identical(graph_surface, baseline)
})

test_that("source order and active dispatch distinguish aliases, host overrides, and raw-R6 parents", {
	source_ast <- call_graph_helpers$inference_component_source_ast_index(
		file.path(repo_root, "R", "EDI", "R"))
	expect_identical(
		call_graph_helpers$inference_component_source_order(source_ast, "InferenceAllKKMeanDiffIVWC"),
		c("RandomizationCI", "RandomizationBootstrapCI", "BayesianBootstrap", "Jackknife", "Wald", "KKMeanDifferenceIVWC"))

	alias <- component_graph$methods[
		component_graph$methods$class == "InferenceAllKKMeanDiffIVWC" &
			component_graph$methods$method == "compute_rand_two_sided_pval", , drop = FALSE]
	expect_identical(nrow(alias), 1L)
	expect_identical(alias$dispatch_owner, "InferenceAllKKMeanDiffIVWC")
	expect_identical(alias$body_origin, "RandomizationTest")

	clmm_link <- component_graph$methods[
		component_graph$methods$class == "InferenceOrdinalKKCLMMCauchit" &
			component_graph$methods$method == "clmm_link", , drop = FALSE]
	expect_identical(nrow(clmm_link), 1L)
	expect_identical(clmm_link$dispatch_owner, "InferenceOrdinalKKCLMMCauchit")
	expect_identical(clmm_link$body_origin, "<host>InferenceOrdinalKKCLMMCauchit")
	parent_clmm_methods <- strsplit(
		component_graph$surface$private_methods[
			component_graph$surface$class == "InferenceOrdinalKKCLMMCauchit"],
		"|", fixed = TRUE)[[1L]]
	expect_true("clmm_link@InferenceAbstractKKOrdinalCLMM" %in% parent_clmm_methods)

	raw_bridge <- component_graph$methods[
		component_graph$methods$class == "InferenceIncidKKModifiedPoisson" &
			component_graph$methods$method == "compute_rand_two_sided_pval", , drop = FALSE]
	expect_identical(nrow(raw_bridge), 1L)
	expect_identical(raw_bridge$dispatch_owner, "InferenceAbstractKKMarginalIncid")
	expect_identical(raw_bridge$body_origin, "RandomizationCI")
})

test_that("the AST graph reproduces the audited packaging-only and real dependency edges", {
	has_edge <- function(from, to) any(component_graph$edges$from == from & component_graph$edges$to == to)

	# The three audited packaging-only edges stay call-free and are no longer
	# declared (v1.0.5 TODO-97, 2026-10-22).
	expect_false(has_edge("Wald", "Jackknife"))
	expect_false(has_edge("NonparametricBootstrap", "RandomizationCI"))
	expect_false(has_edge("BayesianBootstrap", "RandomizationBootstrapCI"))
	expect_true(has_edge("RandomizationCI", "RandomizationTest"))
	expect_true(has_edge("RandomizationBootstrap", "NonparametricBootstrap"))
	expect_true(has_edge("RandomizationBootstrap", "RandomizationTest"))
	expect_true(has_edge("RandomizationBootstrapCI", "RandomizationBootstrap"))
	expect_true(has_edge("LikelihoodTests", "Wald"))
	expect_true(has_edge("ParametricLikelihoodBootstrap", "LikelihoodTests"))
	expect_true(has_edge("Jackknife", "NonparametricBootstrap"))
	expect_true(has_edge("BayesianBootstrap", "NonparametricBootstrap"))
	expect_true(has_edge("Wald", "NonparametricBootstrap"))
	expect_true(has_edge("RandomizationTest", "ResamplingCore"))
	expect_true(has_edge("NonparametricBootstrap", "ResamplingCore"))
	# The old Jackknife <-> NonparametricBootstrap cycle is broken: the
	# helpers NonparametricBootstrap called moved to ResamplingCore.
	expect_false(has_edge("NonparametricBootstrap", "Jackknife"))
	# ResamplingCore calls no other component.
	expect_false(any(component_graph$edges$from == "ResamplingCore" &
		component_graph$edges$to != "ResamplingCore"))
})

# v1.0.5 TODO-97 (plan TODO-6/TODO-7): the resampling/Wald/likelihood family's
# declared dependencies must match the measured call graph and stay acyclic.
todo97_family <- c(
	"ResamplingCore", "RandomizationTest", "RandomizationCI", "NonparametricBootstrap",
	"RandomizationBootstrap", "RandomizationBootstrapCI", "BayesianBootstrap",
	"Jackknife", "Wald", "LikelihoodTests", "ParametricLikelihoodBootstrap"
)

test_that("component dependencies are acyclic", {
	specs <- get("EDI_COMPONENT_SPECS", envir = asNamespace("EDI"))
	deps <- lapply(specs, function(spec) spec$dependencies %||% character())
	unknown <- setdiff(unlist(deps, use.names = FALSE), names(specs))
	expect_identical(unknown, character())
	# Kahn's algorithm: every component must be removable in dependency order.
	remaining <- names(deps)
	repeat {
		ready <- remaining[vapply(remaining, function(name) !any(deps[[name]] %in% remaining), logical(1L))]
		if (!length(ready)) break
		remaining <- setdiff(remaining, ready)
	}
	expect_identical(remaining, character(), info = "component dependency cycle")
	resolve <- get("resolve_component_dependencies", envir = asNamespace("EDI"))
	for (name in names(specs)[!vapply(specs, function(spec) identical(spec$status, "scaffold"), logical(1L))]) {
		expect_silent(resolve(name))
	}
})

test_that("family component dependencies are exactly the measured, non-hook calls", {
	specs <- get("EDI_COMPONENT_SPECS", envir = asNamespace("EDI"))
	deps <- lapply(specs, function(spec) spec$dependencies %||% character())
	closure <- function(name) {
		out <- character()
		visit <- function(x) for (d in deps[[x]]) if (!(d %in% out)) { out <<- c(out, d); visit(d) }
		visit(name)
		out
	}
	methods <- component_graph$methods
	provides <- lapply(stats::setNames(todo97_family, todo97_family), function(component) {
		unique(methods$method[methods$body_origin == component])
	})
	edges <- unique(component_graph$edges[
		component_graph$edges$from %in% todo97_family &
			component_graph$edges$to %in% todo97_family &
			component_graph$edges$from != component_graph$edges$to,
		c("from", "to", "target_method")])
	# A virtual-hook edge is not a static dependency: either the caller
	# defines the same-named method itself (it calls its own hook and a later
	# component overrides it), or the target is outside the caller's closure
	# but the hook's base is inside it (e.g. a call that dispatches to Wald's
	# create_bootstrap_worker_state() override of ResamplingCore's default).
	self_hook <- mapply(function(from, method) method %in% provides[[from]], edges$from, edges$target_method)
	base_hook <- mapply(function(from, to, method) {
		!(to %in% closure(from)) && any(vapply(closure(from), function(component) {
			method %in% (provides[[component]] %||% character())
		}, logical(1L)))
	}, edges$from, edges$to, edges$target_method)
	declared <- mapply(function(from, to) to %in% closure(from), edges$from, edges$to)
	undeclared <- edges[!declared & !self_hook & !base_hook, , drop = FALSE]
	expect_identical(nrow(undeclared), 0L,
		info = paste(sprintf("%s -> %s (%s)", undeclared$from, undeclared$to, undeclared$target_method), collapse = "; "))
	for (from in todo97_family) {
		for (to in deps[[from]]) {
			expect_true(any(edges$from == from & edges$to == to & !self_hook),
				info = sprintf("declared dependency %s -> %s has no measured call", from, to))
		}
	}
	expect_identical(deps[todo97_family], list(
		ResamplingCore = character(),
		RandomizationTest = "ResamplingCore",
		RandomizationCI = "RandomizationTest",
		NonparametricBootstrap = "ResamplingCore",
		RandomizationBootstrap = c("NonparametricBootstrap", "RandomizationTest"),
		RandomizationBootstrapCI = "RandomizationBootstrap",
		BayesianBootstrap = "NonparametricBootstrap",
		Jackknife = "NonparametricBootstrap",
		Wald = "NonparametricBootstrap",
		LikelihoodTests = "Wald",
		ParametricLikelihoodBootstrap = "LikelihoodTests"
	))
})
