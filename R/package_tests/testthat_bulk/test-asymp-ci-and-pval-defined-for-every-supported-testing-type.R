library(testthat)
library(EDI)

# v1.0.6-TODO-327: InferenceContinKKOLSOneLik, InferenceCountPoisson,
# InferenceCountKKCondPoissonOneLik and InferenceCountKKHurdlePoissonOneLik
# list the Bartlett likelihood-ratio types in get_supported_testing_types(),
# but their compute_asymp_confidence_interval() / compute_asymp_two_sided_pval()
# switch had no branch for them, so after set_testing_type("lik_ratio_bartlett_*")
# both returned NULL; InferenceCountKKGLMM stopped with "Unsupported
# testing_type". This file sets every supported testing type on every exported
# class (first fixture it builds on) and checks the asymptotic CI is a length-2
# numeric and the p-value a length-1 numeric. An NA result must come with a
# reason: a warning, a recorded non-estimability, or a recorded procedure
# failure.
#
# Runtime: the parametric-bootstrap Bartlett factor (B = 99 refits per null
# value, and the CI inversion visits many) costs minutes per class on the
# GLMM / hurdle / stereotype classes, so for "lik_ratio_bartlett_approx" (and
# v1.0.6-TODO-380's "lik_ratio_bartlett_approx_design_conservative") the
# instance's private get_bartlett_factor_approx() is replaced by a constant 1.
# That keeps the dispatch and CI-inversion path under test (what TODO-327 is
# about) without the bootstrap; the factor itself is covered by
# test-bartlett-lr-approx-smoke-families.R.

asymp_tt_fixtures = local({
	cache = NULL
	function() {
		if (!is.null(cache)) return(cache)
		set.seed(100)
		n = 40L
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

asymp_tt_inference_classes = function() {
	exps = sort(grep("^Inference", getNamespaceExports("EDI"), value = TRUE))
	exps = setdiff(exps, c("InferenceSuite", "InferenceRandCustom"))
	Filter(function(cn) inherits(get(cn, envir = asNamespace("EDI")), "R6ClassGenerator"), exps)
}

# First fixture the class builds on; NULL plus the construction errors otherwise.
asymp_tt_first_fixture = function(gen) {
	msgs = character()
	for (fn in names(asymp_tt_fixtures())) {
		res = tryCatch(suppressWarnings(suppressMessages(gen$new(asymp_tt_fixtures()[[fn]], verbose = FALSE))),
			error = function(e) conditionMessage(e))
		if (!is.character(res)) return(list(fixture = fn, msgs = msgs))
		msgs = c(msgs, res)
	}
	list(fixture = NULL, msgs = msgs)
}

asymp_tt_stub_bartlett_factor = function(inf) {
	pe = inf$.__enclos_env__$private
	if (!exists("get_bartlett_factor_approx", envir = pe, inherits = FALSE)) return(invisible())
	locked = bindingIsLocked("get_bartlett_factor_approx", pe)
	if (locked) unlockBinding("get_bartlett_factor_approx", pe)
	assign("get_bartlett_factor_approx", function(...) 1, envir = pe)
	if (locked) lockBinding("get_bartlett_factor_approx", pe)
	invisible()
}

# Runs expr, returning its value (or the error) and the warnings it raised.
asymp_tt_eval = function(expr) {
	warns = character()
	val = withCallingHandlers(
		tryCatch(expr, error = function(e) e),
		warning = function(w) {
			warns <<- c(warns, conditionMessage(w))
			invokeRestart("muffleWarning")
		}
	)
	list(val = val, warns = warns)
}

asymp_tt_has_reason = function(inf, warns) {
	if (length(warns) > 0L) return(TRUE)
	if (isTRUE(tryCatch(inf$is_nonestimable(), error = function(e) FALSE))) return(TRUE)
	pf = inf$.__enclos_env__$private$cached_values$procedure_failure_reason
	is.list(pf) && length(pf) > 0L
}

test_that("compute_asymp_confidence_interval() and compute_asymp_two_sided_pval() return a numeric for every supported testing type", {
	n_checked = 0L
	n_bartlett = 0L
	skipped = character()
	for (cn in asymp_tt_inference_classes()) {
		gen = get(cn, envir = asNamespace("EDI"))
		first = asymp_tt_first_fixture(gen)
		if (is.null(first$fixture)) {
			# A Suggests package the class needs is not installed (as on the
			# hard-dependencies-only CI runners).
			hits = unlist(regmatches(first$msgs, gregexpr("[Pp]ackage ['`][A-Za-z][A-Za-z0-9.]*['`]", first$msgs)))
			pkgs = unique(gsub("^[Pp]ackage ['`]|['`]$", "", hits))
			pkgs = pkgs[!vapply(pkgs, EDI:::check_package_installed, logical(1))]
			expect_true(length(pkgs) > 0L, info = paste(cn, "has no fixture:", paste(unique(first$msgs), collapse = " | ")))
			if (length(pkgs)) skipped[cn] = paste(pkgs, collapse = ", ")
			next
		}
		d = asymp_tt_fixtures()[[first$fixture]]
		probe = suppressWarnings(suppressMessages(gen$new(d, verbose = FALSE)))
		if (!is.function(probe$get_supported_testing_types) || !is.function(probe$set_testing_type)) next
		for (tt in probe$get_supported_testing_types()) {
			# fresh object per type, so no cached state carries over
			inf = suppressWarnings(suppressMessages(gen$new(d, verbose = FALSE)))
			inf$set_testing_type(tt)
			if (tt %in% c("lik_ratio_bartlett_approx", "lik_ratio_bartlett_approx_design_conservative")) {
				asymp_tt_stub_bartlett_factor(inf)
				n_bartlett = n_bartlett + 1L
			}
			label = paste0(cn, " [", first$fixture, "] testing_type = ", tt)
			ci = asymp_tt_eval(inf$compute_asymp_confidence_interval(alpha = 0.05))
			pv = asymp_tt_eval(inf$compute_asymp_two_sided_pval(delta = 0))
			n_checked = n_checked + 1L
			expect_false(inherits(ci$val, "error"), info = paste(label, "CI:", if (inherits(ci$val, "error")) conditionMessage(ci$val)))
			expect_false(inherits(pv$val, "error"), info = paste(label, "p-value:", if (inherits(pv$val, "error")) conditionMessage(pv$val)))
			if (inherits(ci$val, "error") || inherits(pv$val, "error")) next
			expect_true(is.numeric(ci$val) && length(ci$val) == 2L, info = paste(label, "CI:", paste(format(ci$val), collapse = ", ")))
			expect_true(is.numeric(pv$val) && length(pv$val) == 1L, info = paste(label, "p-value:", paste(format(pv$val), collapse = ", ")))
			if (is.numeric(pv$val) && length(pv$val) == 1L) {
				if (is.finite(pv$val)) {
					expect_true(pv$val >= 0 && pv$val <= 1, info = label)
				} else {
					expect_true(asymp_tt_has_reason(inf, c(ci$warns, pv$warns)), info = paste(label, "p-value is NA with no warning or recorded reason"))
				}
			}
			if (is.numeric(ci$val) && length(ci$val) == 2L && !all(is.finite(ci$val))) {
				expect_true(asymp_tt_has_reason(inf, c(ci$warns, pv$warns)), info = paste(label, "CI has an NA bound with no warning or recorded reason"))
			}
		}
	}
	expect_gt(n_checked, 200L)
	expect_gt(n_bartlett, 30L)
	if (length(skipped)) {
		skip(paste0("Suggests packages not installed: ", paste0(names(skipped), " (", skipped, ")", collapse = "; ")))
	}
})
