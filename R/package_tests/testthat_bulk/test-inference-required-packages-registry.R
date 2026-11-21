library(testthat)
library(EDI)

# The inference registry's `required_packages` field (EDI_INFERENCE_REQUIRED_PACKAGES
# in inference_class_registry.R) names the Suggests packages without which a class
# cannot be constructed and fitted at its default arguments. InferenceSuite and
# Design discovery exclude a class whose package is missing. Until 2026-11-21 the
# field was character() for every class, so nothing was ever excluded and such a
# class came back as a construction-error row instead.
#
# These tests keep the field in step with the classes' own guards:
# (1) every package an inference guard checks is either some class's required
#     package or listed in EDI_INFERENCE_OPTIONAL_PATH_PACKAGES (a non-default path);
# (2) with the guarded packages reported absent, every exported class constructs
#     and fits unless it lists a required package, and a class that lists one fails
#     naming it;
# (3) InferenceSuite reports such a class as unavailable instead of running it.

ns = asNamespace("EDI")
req_map = EDI:::EDI_INFERENCE_REQUIRED_PACKAGES
opt_map = EDI:::EDI_INFERENCE_OPTIONAL_PATH_PACKAGES

edi_desc_field_packages = function(field) {
	desc = read.dcf(system.file("DESCRIPTION", package = "EDI"), fields = field)[1, 1]
	pk = trimws(strsplit(gsub("\\([^)]*\\)", "", desc), ",")[[1]])
	pk[nzchar(pk)]
}

exported_concrete_inference_classes = function() {
	reg = EDI:::inference_class_registry_as_list()
	sort(names(Filter(function(m) isTRUE(m$exported) && !isTRUE(m$abstract), reg)))
}

test_that("required_packages in the registry is read from EDI_INFERENCE_REQUIRED_PACKAGES", {
	classes = exported_concrete_inference_classes()
	expect_true(all(names(req_map) %in% classes), info = paste(setdiff(names(req_map), classes), collapse = ", "))
	for (cn in classes) {
		expect_identical(EDI:::get_inference_class_metadata(cn)$required_packages,
			req_map[[cn]] %||% character(), info = cn)
	}
	suggests = edi_desc_field_packages("Suggests")
	imports = edi_desc_field_packages("Imports")
	all_req = unique(unlist(req_map))
	# only Suggests packages can be missing from a working install
	expect_true(all(all_req %in% suggests), info = paste(setdiff(all_req, suggests), collapse = ", "))
	expect_false(any(all_req %in% imports))
	expect_true(all(names(opt_map) %in% suggests), info = paste(setdiff(names(opt_map), suggests), collapse = ", "))
})

# Text of every function the namespace holds, including R6 generators' methods and
# the component source lists (lists of public/private functions), without
# comments, so only live guards are scanned.
edi_namespace_function_texts = function() {
	texts = character()
	walk = function(x, depth = 0L) {
		if (depth > 4L) return(invisible())
		if (is.function(x)) {
			texts <<- c(texts, paste(deparse(x, control = c("keepNA", "keepInteger")), collapse = "\n"))
		} else if (inherits(x, "R6ClassGenerator")) {
			for (f in c(x$public_methods, x$private_methods, x$active)) walk(f, depth + 1L)
		} else if (is.list(x) && !is.data.frame(x)) {
			for (el in x) walk(el, depth + 1L)
		}
	}
	for (nm in ls(ns, all.names = TRUE)) walk(get(nm, envir = ns))
	texts
}

guard_packages_in = function(texts) {
	pats = c(
		"check_package_installed\\(\"([A-Za-z][A-Za-z0-9.]*)\"\\)",
		"requireNamespace\\(\"([A-Za-z][A-Za-z0-9.]*)\"",
		"[Pp]ackage '([A-Za-z][A-Za-z0-9.]*)' is required",
		"requires package '([A-Za-z][A-Za-z0-9.]*)'"
	)
	unique(unlist(lapply(pats, function(p) {
		m = regmatches(texts, gregexpr(p, texts))
		sub(p, "\\1", unlist(m))
	})))
}

test_that("every Suggests package an inference guard checks is a required or an optional-path package", {
	found = guard_packages_in(edi_namespace_function_texts())
	suggests = edi_desc_field_packages("Suggests")
	found = intersect(found, suggests)
	# the scan sees the guards it is meant to see
	expect_true(all(c("quantreg", "multgee", "geepack", "aftgee", "glmmTMB") %in% found))
	design_pkgs = unique(unlist(EDI:::EDI_DESIGN_REQUIRED_PACKAGES_BY_NAME))
	# Checked outside inference classes: designs, InferenceSuite reporting and
	# parallel setup, and user-compiled objectives. None gates an inference fit.
	not_inference = c(design_pkgs, "ggplot2", "qpdf", "jsonlite", "fixest", "mirai",
		"doParallel", "RcppXPtrUtils", "anticlust", "blockTools", "dplyr", "knitr", "rmarkdown", "testthat", "withr")
	unaccounted = setdiff(found, c(unlist(req_map), names(opt_map), not_inference))
	expect_identical(unaccounted, character(),
		info = paste("guarded Suggests package(s) in neither EDI_INFERENCE_REQUIRED_PACKAGES nor",
			"EDI_INFERENCE_OPTIONAL_PATH_PACKAGES:", paste(unaccounted, collapse = ", ")))
})

required_pkgs_fixtures = local({
	cache = NULL
	function() {
		if (!is.null(cache)) return(cache)
		set.seed(100)
		n = 24L
		X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
		ys = list(
			continuous = rnorm(n), incidence = rbinom(n, 1, 0.5), proportion = runif(n, 0.05, 0.95),
			count = c(rep(0L, 8L), rpois(n - 8L, 3)), survival = rexp(n) + 0.1, ordinal = sample(1:4, n, TRUE)
		)
		mk = function(gen, rt) {
			d = gen$new(n = n, response_type = rt, verbose = FALSE)
			d$add_all_subjects_to_experiment(X)
			d$assign_w_to_all_subjects()
			d$add_all_subject_responses(ys[[rt]])
			d
		}
		out = list()
		for (rt in names(ys)) {
			out[[paste0("bern_", rt)]] = mk(DesignFixedBernoulli, rt)
			out[[paste0("match_", rt)]] = suppressWarnings(mk(DesignFixedBinaryMatch, rt))
		}
		cache <<- out
		out
	}
})

# Constructs `cn` on the first fixture it accepts and fits it. Returns "ok", or the
# error messages from every fixture.
construct_and_fit = function(cn) {
	gen = get(cn, envir = ns)
	msgs = character()
	for (d in required_pkgs_fixtures()) {
		inf = tryCatch(suppressWarnings(suppressMessages(gen$new(d, verbose = FALSE))),
			error = function(e) { msgs <<- c(msgs, conditionMessage(e)); NULL })
		if (is.null(inf)) next
		err = tryCatch({
			utils::capture.output(suppressWarnings(suppressMessages(inf$compute_estimate())))
			NULL
		}, error = function(e) conditionMessage(e))
		if (is.null(err)) return("ok")
		msgs = c(msgs, err)
	}
	msgs
}

test_that("with the guarded packages absent, only classes listing a required package fail, naming it", {
	skip_on_cran() # constructs and fits every exported class (about 40 s)
	skip_if_not_installed("nbpMatching") # the matched-pair fixtures need it
	absent = unique(c(unlist(req_map), names(opt_map)))
	testthat::local_mocked_bindings(
		check_package_installed = function(package_name) !(package_name %in% absent),
		.package = "EDI"
	)
	# InferenceRandCustom needs a user statistic, so it has no default fit.
	for (cn in setdiff(exported_concrete_inference_classes(), "InferenceRandCustom")) {
		res = construct_and_fit(cn)
		req = req_map[[cn]] %||% character()
		if (length(req) == 0L) {
			expect_identical(res[1L], "ok", info = paste(cn, "failed without the optional packages:", paste(unique(res), collapse = " || ")))
		} else {
			expect_false(identical(res[1L], "ok"), info = paste(cn, "fitted although its required package is absent"))
			named = unique(sub("^.*[Pp]ackage '([A-Za-z0-9.]+)'.*$", "\\1",
				grep("[Pp]ackage '[A-Za-z0-9.]+'", res, value = TRUE)))
			expect_true(length(named) > 0L && all(named %in% req),
				info = paste(cn, "named", paste(named, collapse = ", "), "not in", paste(req, collapse = ", ")))
		}
		expect_identical(EDI:::missing_required_packages_for_inference_class(cn), req, info = cn)
	}
})

test_that("InferenceSuite excludes a class whose required package is missing and reports it", {
	d = required_pkgs_fixtures()[["bern_continuous"]]
	testthat::local_mocked_bindings(
		check_package_installed = function(package_name) !identical(package_name, "quantreg"),
		.package = "EDI"
	)
	suite = InferenceSuite$new(d)
	expect_false("InferenceContinQuantileRegr" %in% suite$applicable_design_classes)
	expect_identical(suite$unavailable_due_to_missing_packages[["InferenceContinQuantileRegr"]], "quantreg")
	expect_identical(d$unavailable_inference_classes_due_to_missing_packages(), suite$unavailable_due_to_missing_packages)
	expect_true("InferenceContinOLS" %in% suite$applicable_design_classes)
	expect_match(EDI:::run_all_inference_unavailable_footer_lines(suite$unavailable_due_to_missing_packages),
		"InferenceContinQuantileRegr - requires install.packages(\"quantreg\")", fixed = TRUE, all = FALSE)
	expect_error(InferenceSuite$new(d, inference_params = list(InferenceContinQuantileRegr = list(tau = 0.25))),
		"not applicable")
})

test_that("InferenceSuite keeps the class when its required package is installed", {
	skip_if_not_installed("quantreg")
	d = required_pkgs_fixtures()[["bern_continuous"]]
	suite = InferenceSuite$new(d)
	expect_true("InferenceContinQuantileRegr" %in% suite$applicable_design_classes)
	expect_false("InferenceContinQuantileRegr" %in% names(suite$unavailable_due_to_missing_packages))
})
