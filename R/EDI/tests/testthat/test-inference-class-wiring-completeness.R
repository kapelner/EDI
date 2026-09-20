library(testthat)
library(EDI)

# Structural wiring audit: every inference class that can be constructed must
# actually have the methods its own component composition and capability set
# promise, and every `private$x()` call inside its methods must resolve to a
# real function. No inference is run -- this only inspects constructed
# instances, so it takes seconds, not simulation hours.
#
# Why this exists (2026-09-19): a raw comprehensive_tests results audit found
# three independent "attempt to apply non-function" bugs that all had the
# same shape -- a public method or private hook a component expects from its
# host was silently `NULL` on the assembled class:
#   * InferenceSurvivalCoxPHRegr/StratCoxPHRegr never composed
#     ParametricLikelihoodBootstrap, so compute_lik_ratio_bootstrap_*() and
#     their whole private machinery were NULL (same family as TODO-13's
#     BayesianBootstrap gap on the same classes).
#   * InferenceContinKKQuantileRegrOneLik/InferencePropKKQuantileRegrOneLik
#     compose QuantileRandomizationCI without any host supplying
#     compute_rand_pval_matched_pairs()/compute_rand_pval_reservoir(), which
#     its bisection calls; the resulting error was swallowed and produced
#     zero-width intervals.
# None of these was caught by any existing test because each only exercised
# methods that DO exist. Three checks per instance:
#   (A) every function in an effective component's public/private slot is a
#       function on the assembled instance;
#   (B) every public method implied by the instance's capabilities is a
#       function on the instance;
#   (C) every unguarded `private$x(...)` call target inside any public or
#       private method resolves to a function in the private env. A call is
#       "guarded" (deliberately optional) when the same function tests it via
#       is.function()/is.null()/exists() on private$x, or via
#       private$has_private_method("x").

wiring_n = 24L
wiring_resp = function(rt) switch(rt,
	continuous = rnorm(wiring_n),
	incidence = rbinom(wiring_n, 1, 0.5),
	proportion = pmin(pmax(rbeta(wiring_n, 2, 2), 0.02), 0.98),
	count = rpois(wiring_n, 2),
	survival = rexp(wiring_n, 0.3),
	ordinal = sample(1:4, wiring_n, TRUE))

wiring_fixed_design = function(rt) {
	d = DesignFixedBernoulli$new(n = wiring_n, response_type = rt, verbose = FALSE)
	d$add_all_subjects_to_experiment(data.frame(x1 = rnorm(wiring_n), x2 = rnorm(wiring_n)))
	d$assign_w_to_all_subjects()
	d$add_all_subject_responses(wiring_resp(rt))
	d
}

wiring_kk_design = function(rt) {
	d = DesignSeqOneByOneKK14$new(n = wiring_n, response_type = rt, verbose = FALSE)
	y = wiring_resp(rt)
	for (i in seq_len(wiring_n)) {
		d$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1), x2 = rnorm(1)))
		d$add_one_subject_response(i, y[i])
	}
	d
}

wiring_unguarded_private_calls = function(f) {
	called = character()
	guarded = character()
	is_private_member = function(x) is.call(x) && identical(x[[1L]], as.name("$")) &&
		identical(x[[2L]], as.name("private")) && is.name(x[[3L]])
	walk = function(e) {
		if (!is.call(e)) return(invisible(NULL))
		fn = e[[1L]]
		if (is_private_member(fn)) called <<- c(called, as.character(fn[[3L]]))
		if (is.name(fn)) {
			fname = as.character(fn)
			if (fname %in% c("is.function", "is.null", "exists") && length(e) >= 2L && is_private_member(e[[2L]])) {
				guarded <<- c(guarded, as.character(e[[2L]][[3L]]))
			}
		}
		if (is_private_member(fn) && identical(as.character(fn[[3L]]), "has_private_method") && length(e) >= 2L && is.character(e[[2L]])) {
			guarded <<- c(guarded, e[[2L]])
		}
		for (i in seq_along(e)) try(walk(e[[i]]), silent = TRUE)
	}
	try(walk(body(f)), silent = TRUE)
	setdiff(unique(called), unique(guarded))
}

wiring_gaps_for_instance = function(inst, class_name) {
	priv = inst$.__enclos_env__$private
	gaps = character()
	checked = 0L
	components = tryCatch(EDI:::get_effective_components(class_name), error = function(e) character())
	for (cn in components) {
		spec = EDI:::get_inference_component(cn)
		for (m in names(spec$public)) if (is.function(spec$public[[m]])) {
			checked = checked + 1L
			if (!is.function(inst[[m]])) gaps = c(gaps, sprintf("component %s: public::%s missing", cn, m))
		}
		for (m in names(spec$private)) if (is.function(spec$private[[m]])) {
			checked = checked + 1L
			if (!is.function(priv[[m]])) gaps = c(gaps, sprintf("component %s: private::%s missing", cn, m))
		}
	}
	for (m in EDI:::public_methods_required_for_capabilities(inst$capabilities())) {
		checked = checked + 1L
		if (!is.function(inst[[m]])) gaps = c(gaps, sprintf("capability: public::%s missing", m))
	}
	for (env_info in list(list(env = inst, kind = "public"), list(env = priv, kind = "private"))) {
		for (m in ls(env_info$env, all.names = TRUE)) {
			if (m %in% c("clone", ".__enclos_env__")) next
			f = tryCatch(get(m, envir = env_info$env), error = function(e) NULL)
			if (!is.function(f)) next
			for (target in wiring_unguarded_private_calls(f)) {
				checked = checked + 1L
				if (!is.function(priv[[target]])) gaps = c(gaps, sprintf("call: %s::%s -> private$%s missing", env_info$kind, m, target))
			}
		}
	}
	gaps = unique(gaps)
	attr(gaps, "checked") = checked
	gaps
}

wiring_collect_all = function() {
	set.seed(20260919)
	seen = character()
	gaps = list()
	checked = 0L
	for (rt in c("continuous", "incidence", "proportion", "count", "survival", "ordinal")) {
		for (mk in c("wiring_fixed_design", "wiring_kk_design")) {
			des = tryCatch(get(mk)(rt), error = function(e) NULL)
			if (is.null(des)) next
			for (nm in des$applicable_inference_class_names()) {
				if (nm %in% seen) next
				inst = tryCatch(get(nm, envir = asNamespace("EDI"))$new(des), error = function(e) NULL)
				if (is.null(inst)) next
				seen = c(seen, nm)
				g = wiring_gaps_for_instance(inst, nm)
				checked = checked + attr(g, "checked")
				if (length(g)) gaps[[nm]] = as.character(g)
			}
		}
	}
	list(instantiated = seen, gaps = gaps, checked = checked)
}

# Findings that predate this audit, each with the reason it is tolerated and
# where the real fix is tracked. The audit fails on any finding NOT listed
# here, AND on any entry here that no longer occurs (so fixed gaps must be
# deleted from this list -- it cannot rot into a blanket exemption).
# Format: "<Class>|<finding text>".
EDI_WIRING_KNOWN_GAPS = c(
	# rand-CI hard-stop()s for these two (2026-09-17 stopgap); real fix is
	# new_feature_plans/fix_KKQuantileRegrOneLik_rand_ci.md (v1.1.0, TODO-25).
	"InferenceContinKKQuantileRegrOneLik|call: private::ci_exact_zhang_combined -> private$compute_rand_pval_matched_pairs missing",
	"InferenceContinKKQuantileRegrOneLik|call: private::ci_exact_zhang_combined -> private$compute_rand_pval_reservoir missing",
	"InferencePropKKQuantileRegrOneLik|call: private::ci_exact_zhang_combined -> private$compute_rand_pval_matched_pairs missing",
	"InferencePropKKQuantileRegrOneLik|call: private::ci_exact_zhang_combined -> private$compute_rand_pval_reservoir missing",
	# Exact-only incidence classes carry a compute_estimate_with_bootstrap_
	# weights() body from a shared base whose bootstrap helpers they never
	# compose. Tolerated because they advertise only exact_test + their own
	# exact_*_incidence capability (no bayesian/nonparametric bootstrap), so
	# discovery and run_all_inference() can never reach the method -- a dead
	# stub, not a live NULL-call hazard. Since Inference$install_weighted_refit_
	# isolation() the stub body is stored in private$weighted_refit_impl behind
	# a wrapper, so the same findings are reported under that member.
	"InferenceIncidExactZhang|call: private::weighted_refit_impl -> private$expand_subject_or_block_weights_to_row_weights missing",
	"InferenceIncidExactZhang|call: private::weighted_refit_impl -> private$bootstrap_subset_inference missing",
	"InferenceIncidExactBinomial|call: private::weighted_refit_impl -> private$expand_subject_or_block_weights_to_row_weights missing",
	"InferenceIncidExactBinomial|call: private::weighted_refit_impl -> private$bootstrap_subset_inference missing",
	"InferenceIncidExactFisher|call: private::weighted_refit_impl -> private$expand_subject_or_block_weights_to_row_weights missing",
	"InferenceIncidExactFisher|call: private::weighted_refit_impl -> private$bootstrap_subset_inference missing",
	# InferenceAllSimpleWilcox has no compute_estimate_with_bootstrap_weights
	# (no bayesian_bootstrap capability), so install_weighted_refit_isolation()
	# returns early, private$weighted_refit_impl stays NULL, and the wrapper
	# that is run_isolated_weighted_refit()'s only caller is never created --
	# structurally unreachable, not a live NULL-call hazard.
	"InferenceAllSimpleWilcox|call: private::run_isolated_weighted_refit -> private$weighted_refit_impl missing"
)

wiring_result = wiring_collect_all()

test_that("wiring audit exercised a meaningful share of the class registry", {
	expect_gte(length(wiring_result$instantiated), 80L)
	expect_gt(wiring_result$checked, 5000L)
})

test_that("no inference class has unresolved component, capability, or private-call wiring", {
	found = unlist(lapply(names(wiring_result$gaps), function(nm) paste0(nm, "|", wiring_result$gaps[[nm]])), use.names = FALSE)
	new_gaps = setdiff(found, EDI_WIRING_KNOWN_GAPS)
	expect_identical(new_gaps, character(0), info = paste(
		"Unlisted wiring gaps (a method a component/capability promises, or a private$x() call, resolves to NULL):",
		paste(new_gaps, collapse = "\n  "), sep = "\n  "))
	stale = setdiff(EDI_WIRING_KNOWN_GAPS, found)
	expect_identical(stale, character(0), info = paste(
		"EDI_WIRING_KNOWN_GAPS entries that no longer occur -- delete them:",
		paste(stale, collapse = "\n  "), sep = "\n  "))
})

test_that("the audit itself detects a removed public method, a removed private method, and a dangling private call", {
	set.seed(1)
	des = wiring_fixed_design("continuous")
	inst = InferenceContinOLS$new(des)
	priv = inst$.__enclos_env__$private
	expect_identical(length(wiring_gaps_for_instance(inst, "InferenceContinOLS")), 0L)

	unlockBinding("compute_wald_confidence_interval", inst)
	inst$compute_wald_confidence_interval = NULL
	g_pub = wiring_gaps_for_instance(inst, "InferenceContinOLS")
	expect_true(any(grepl("public::compute_wald_confidence_interval missing", g_pub)))

	inst2 = InferenceContinOLS$new(des)
	priv2 = inst2$.__enclos_env__$private
	victim = "get_standard_error"
	expect_true(is.function(priv2[[victim]]))
	unlockBinding(victim, priv2)
	priv2[[victim]] = NULL
	g_priv = wiring_gaps_for_instance(inst2, "InferenceContinOLS")
	expect_true(any(grepl(paste0("private\\$", victim, " missing"), g_priv)))
})

test_that("the private-call guard idioms are recognized (optional hooks are not false positives)", {
	f_guarded = function() { if (is.function(private$maybe)) private$maybe(); private$always() }
	f_named = function() { if (private$has_private_method("opt")) private$opt() }
	expect_identical(wiring_unguarded_private_calls(f_guarded), "always")
	expect_true(!("opt" %in% wiring_unguarded_private_calls(f_named)))
})
