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
	rownames(graph_surface) <- rownames(baseline) <- NULL
	expect_identical(nrow(graph_surface), 106L)
	expect_identical(graph_surface, baseline)
})

test_that("source order and active dispatch distinguish aliases, host overrides, and raw-R6 parents", {
	source_ast <- call_graph_helpers$inference_component_source_ast_index(
		file.path(repo_root, "R", "EDI", "R"))
	expect_identical(
		call_graph_helpers$inference_component_source_order(source_ast, "InferenceAllKKMeanDiffIVWC"),
		c("BayesianBootstrap", "Wald", "KKMeanDifferenceIVWC"))

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

	expect_false(has_edge("Wald", "Jackknife"))
	expect_false(has_edge("NonparametricBootstrap", "RandomizationCI"))
	expect_false(has_edge("BayesianBootstrap", "RandomizationBootstrapCI"))
	expect_true(has_edge("RandomizationCI", "RandomizationTest"))
	expect_true(has_edge("RandomizationBootstrap", "NonparametricBootstrap"))
	expect_true(has_edge("RandomizationBootstrapCI", "RandomizationBootstrap"))
	expect_true(has_edge("LikelihoodTests", "Wald"))
	expect_true(has_edge("ParametricLikelihoodBootstrap", "LikelihoodTests"))
	expect_true(has_edge("Jackknife", "NonparametricBootstrap"))
	expect_true(has_edge("NonparametricBootstrap", "Jackknife"))
})
