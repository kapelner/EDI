library(testthat)
library(EDI)

# release_v1_0_5.md TODO-125 (2026-10-22). R6's clone() (R6:::remap_func_envs,
# R6 2.6.1) repoints a method's closure environment only when that environment
# is identical() to one of the object's enclosing environments.
# install_lazy_inference_component() used to close every lazily installed method
# over parent.frame() -- the calling stub's frame, a CHILD of the enclosing env --
# so a raw `inf$clone()` skipped those methods and the copy silently read and
# wrote the ORIGINAL object's self/private (14 public + 79 private methods on
# InferenceContinOLS after one bootstrap). Only `duplicate()`, through
# edi_rebind_lazy_components_after_clone(), repaired it. The installer now closes
# installed methods over `self$.__enclos_env__`, so R6's own clone() handles them.
#
# This file pins that: after compute_estimate() plus a small bootstrap (which
# installs lazy components), a raw clone must have no method whose environment
# chain reaches the original, the clone's state must be what the clone's methods
# see, running a state-writing method on the clone must leave the original
# untouched, and the rebind helper (kept for one release) must be a no-op.
# One lazy class per response type, a KK class, and a plain
# `R6::R6Class(inherit = <class>)` user subclass (locked private env, so the
# installed-components marker is stored as an environment attribute, which
# clone() does not copy).

.todo125_enclos_chain = function(obj) {
	envs = list()
	e = obj$.__enclos_env__
	while (is.environment(e)) {
		envs[[length(envs) + 1L]] = e
		sup = get0("super", envir = e, inherits = FALSE)
		e = if (is.environment(sup)) sup$.__enclos_env__ else NULL
	}
	envs
}

# Every binding environment holding methods: public, private, and each super level.
.todo125_binding_envs = function(obj) {
	out = list(public = obj, private = obj$.__enclos_env__$private)
	enc = .todo125_enclos_chain(obj)
	for (k in seq_along(enc)) {
		sup = get0("super", envir = enc[[k]], inherits = FALSE)
		if (is.environment(sup)) out[[paste0("super", k)]] = sup
	}
	out
}

.todo125_functions = function(obj) {
	fns = list()
	envs = .todo125_binding_envs(obj)
	for (slot in names(envs)) {
		env = envs[[slot]]
		if (!is.environment(env)) next
		for (nm in setdiff(ls(env, all.names = TRUE), ".__enclos_env__")) {
			if (bindingIsActive(nm, env)) next
			val = get(nm, envir = env, inherits = FALSE)
			if (is.function(val)) fns[[paste(slot, nm, sep = "$")]] = val
		}
	}
	fns
}

.todo125_reaches = function(f, targets, depth = 6L) {
	e = environment(f)
	for (k in seq_len(depth)) {
		if (!is.environment(e) || identical(e, emptyenv()) || identical(e, globalenv()) ||
				isNamespace(e) || identical(e, baseenv())) return(FALSE)
		for (t in targets) if (identical(e, t)) return(TRUE)
		e = parent.env(e)
	}
	FALSE
}

.todo125_loaded_marker = function(obj) {
	priv = obj$.__enclos_env__$private
	unique(c(
		get0(".__loaded_lazy_components", envir = priv, inherits = FALSE, ifnotfound = character()),
		attr(priv, ".__loaded_lazy_components", exact = TRUE) %||% character()
	))
}

.todo125_is_stub = function(f) !is.null(attr(f, "inference_lazy_component_stub", exact = TRUE))

.todo125_design = function(response_type, n = 40L) {
	set.seed(125)
	pid = rep(seq_len(n / 2L), each = 2L)
	des = DesignFixedBinaryMatch$new(n = n, response_type = response_type, m = pid, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n), x2 = runif(n)))
	des$assign_w_to_all_subjects()
	w = des$get_w()
	lp = 0.5 * w + 0.3 * des$get_X()[, 1L]
	switch(response_type,
		continuous = des$add_all_subject_responses(lp + rnorm(n)),
		incidence = des$add_all_subject_responses(rbinom(n, 1L, stats::plogis(lp))),
		count = des$add_all_subject_responses(rpois(n, exp(0.5 + lp))),
		proportion = des$add_all_subject_responses(stats::plogis(lp + rnorm(n, sd = 0.5))),
		ordinal = des$add_all_subject_responses(as.integer(cut(lp + rlogis(n), c(-Inf, -1, 0.4, 1.5, Inf)))),
		survival = {
			time = rexp(n, rate = exp(-lp))
			dead = rbinom(n, 1L, 0.8)
			des$add_all_subject_responses(ys = ifelse(dead == 1, time, NA),
				y_Ls = ifelse(dead == 1, NA, time), y_Rs = ifelse(dead == 1, NA, Inf))
		}
	)
	des
}

TODO125_CASES = list(
	list(cls = "InferenceContinOLS", rt = "continuous"),
	list(cls = "InferenceContinKKOLSOneLik", rt = "continuous"),
	list(cls = "InferenceIncidLogRegr", rt = "incidence"),
	list(cls = "InferenceCountPoisson", rt = "count"),
	list(cls = "InferencePropBetaRegr", rt = "proportion"),
	list(cls = "InferenceOrdinalPropOddsRegr", rt = "ordinal"),
	list(cls = "InferenceSurvivalWeibullRegr", rt = "survival")
)

.todo125_check_clone = function(inf, label) {
	priv = inf$.__enclos_env__$private
	loaded = .todo125_loaded_marker(inf)
	expect_true(length(loaded) > 0L, info = paste(label, "installed no lazy component; the test would not exercise the fix"))

	# Source-level fix: every installed (non-stub) component method on the
	# ORIGINAL is closed directly over one of its own enclosing environments,
	# never over a child frame (that is the shape R6's clone() cannot remap).
	orig_enc = .todo125_enclos_chain(inf)
	specs = EDI:::EDI_COMPONENT_SPECS
	installed_names = list(public = character(), private = character())
	for (comp in loaded) {
		spec = specs[[comp]]
		if (is.null(spec)) next
		installed_names$public = c(installed_names$public, spec$provides_public_methods %||% character())
		installed_names$private = c(installed_names$private, spec$provides_private_methods %||% character())
	}
	n_installed = 0L
	for (slot in c("public", "private")) {
		env = if (slot == "public") inf else priv
		for (nm in unique(installed_names[[slot]])) {
			f = get0(nm, envir = env, inherits = FALSE)
			if (!is.function(f) || .todo125_is_stub(f)) next
			n_installed = n_installed + 1L
			closed_over_enclos = any(vapply(orig_enc, function(e) identical(environment(f), e), logical(1L)))
			expect_true(closed_over_enclos, info = sprintf("%s: installed %s method `%s` is not closed over an enclosing env", label, slot, nm))
		}
	}
	expect_true(n_installed > 0L, info = paste(label, "has no installed component method to check"))

	cl = inf$clone()
	cl_priv = cl$.__enclos_env__$private
	expect_false(identical(cl_priv, priv))

	# (a) no method anywhere on the clone reaches the original's enclosing envs
	cl_fns = .todo125_functions(cl)
	stale = names(Filter(function(f) .todo125_reaches(f, orig_enc), cl_fns))
	expect_identical(stale, character(0), info = paste(label, "raw clone() methods still reaching the original"))

	# (b) state set on the clone is what the clone's methods see, not the original's
	cl_priv$cached_values$todo125_probe = "clone"
	expect_null(priv$cached_values$todo125_probe)
	probe = quote(private$cached_values$todo125_probe)
	for (nm in names(cl_fns)) {
		e = environment(cl_fns[[nm]])
		if (!is.environment(e) || !exists("private", envir = e)) next
		expect_identical(eval(probe, e), "clone", info = sprintf("%s: clone method %s reads someone else's private", label, nm))
	}
	for (nm in names(.todo125_functions(inf))) {
		e = environment(.todo125_functions(inf)[[nm]])
		if (!is.environment(e) || !exists("private", envir = e)) next
		expect_null(eval(probe, e), info = sprintf("%s: original method %s sees the clone's state", label, nm))
	}
	cl_priv$cached_values$todo125_probe = NULL

	# (c) running state-writing (lazily installed) methods on the clone leaves
	# the original untouched
	snap_values = priv$cached_values
	cl_priv$cached_values = list()
	set.seed(1)
	cl_est = cl$compute_estimate()
	invisible(suppressWarnings(tryCatch(cl$compute_bootstrap_confidence_interval(B = 21), error = function(e) NULL)))
	expect_identical(priv$cached_values, snap_values, info = paste(label, "clone's methods wrote into the original's cached_values"))
	expect_true(length(cl_priv$cached_values) > 0L, info = paste(label, "clone's own cached_values were not written"))
	expect_equal(cl_est, inf$compute_estimate(), tolerance = 1e-5, info = label)

	# (d) the rebind helper kept for this release is now a no-op on a raw clone
	cl2 = inf$clone()
	before = .todo125_functions(cl2)
	EDI:::edi_rebind_lazy_components_after_clone(cl2, source_private = priv)
	after = .todo125_functions(cl2)
	expect_identical(sort(names(after)), sort(names(before)))
	for (nm in names(before)) {
		expect_true(identical(environment(after[[nm]]), environment(before[[nm]])),
			info = sprintf("%s: rebind helper changed the environment of %s", label, nm))
	}
	invisible(cl)
}

test_that("TODO-125: raw clone() of a lazy-component inference object is fully isolated, per response type", {
	set_num_cores(1)
	for (case in TODO125_CASES) {
		des = .todo125_design(case$rt)
		gen = get(case$cls, envir = asNamespace("EDI"))
		inf = gen$new(des, verbose = FALSE)
		set.seed(2)
		inf$compute_estimate()
		invisible(suppressWarnings(tryCatch(inf$compute_bootstrap_confidence_interval(B = 21), error = function(e) NULL)))
		.todo125_check_clone(inf, case$cls)
	}
})

test_that("TODO-125: a plain R6 user subclass (locked private env, attribute marker) clones correctly", {
	set_num_cores(1)
	UserOLS = R6::R6Class("UserOLS", inherit = InferenceContinOLS)
	des = .todo125_design("continuous")
	inf = UserOLS$new(des, verbose = FALSE)
	expect_true(environmentIsLocked(inf$.__enclos_env__$private))
	set.seed(2)
	inf$compute_estimate()
	invisible(suppressWarnings(inf$compute_bootstrap_confidence_interval(B = 21)))
	priv = inf$.__enclos_env__$private
	# The marker lives on the attribute fallback, which clone() does not copy.
	expect_false(exists(".__loaded_lazy_components", envir = priv, inherits = FALSE))
	expect_true(length(attr(priv, ".__loaded_lazy_components", exact = TRUE)) > 0L)
	# UserOLS defines no methods, so every method (stub or installed) is
	# inherited and R6 closes it over the defining level's enclosing env, whose
	# `super` differs from the leaf's. Installed component methods must stay on
	# that level (closing them over the leaf env would change `super$...`).
	leaf = inf$.__enclos_env__
	for (comp in .todo125_loaded_marker(inf)) {
		spec = EDI:::EDI_COMPONENT_SPECS[[comp]]
		for (nm in spec$provides_public_methods %||% character()) {
			f = get0(nm, envir = inf, inherits = FALSE)
			if (is.function(f) && !.todo125_is_stub(f))
				expect_false(identical(environment(f), leaf), info = paste("UserOLS installed public method on leaf env:", nm))
		}
		for (nm in spec$provides_private_methods %||% character()) {
			f = get0(nm, envir = priv, inherits = FALSE)
			if (is.function(f) && !.todo125_is_stub(f))
				expect_false(identical(environment(f), leaf), info = paste("UserOLS installed private method on leaf env:", nm))
		}
	}
	cl = .todo125_check_clone(inf, "UserOLS")
	expect_null(attr(cl$.__enclos_env__$private, ".__loaded_lazy_components", exact = TRUE))
	# A clone that lost the marker still installs further components cleanly
	# (the installer re-runs as a no-op for already-real methods).
	expect_no_error(suppressWarnings(cl$compute_bayesian_bootstrap_confidence_interval(B = 21)))
	expect_identical(.todo125_functions(cl) |> Filter(f = function(f) .todo125_reaches(f, .todo125_enclos_chain(inf))) |> names(),
		character(0))
})
