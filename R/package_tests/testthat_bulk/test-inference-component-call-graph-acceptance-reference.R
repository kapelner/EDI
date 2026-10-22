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

	# The reviewed deltas (TODO-98, TODO-57, TODO-97) are listed and asserted in
	# inference_component_expect_reviewed_registry_baseline().
	call_graph_helpers$inference_component_expect_reviewed_registry_baseline(component_graph$surface, baseline)
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
