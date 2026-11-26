# v1.1.0-TODO-272: paired-override rules, the pre-push half of the class-architecture audit
# (R/package_metadata/new_feature_plans/v1_1_0/class_architecture_audit.md; owner ruling
# DECISION-v1.1.0-TODO-272, 2026-11-26).
#
# Some methods are coupled: when a class redefines the first (the "statistic" method), the
# second must compute the same thing. The 2026-10-12 KK Wilcox bug was this shape: the class
# redefined its randomization statistic but inherited a bootstrap-worker hook that computed a
# different one (BRT p 0.02 against rand 0.31).
#
# Rule, per row of class_architecture_paired_overrides.csv: for every R6 class in the namespace,
# if the nearest definition of `statistic_method` sits on a lower level of the inheritance chain
# than the nearest definition of `coupled_method`, then that inherited `coupled_method` must call
# `statistic_method` (or one of `delegate_helpers`, which do) in its code. Component and mixin
# methods count as defined on the class that splices them in. Inspects generators only; builds no
# objects. Costs about 2-3 s, nearly all of it forcing the namespace's lazy-loaded generators.
#
# A new row goes in the CSV whenever a bug of this shape is found. The weekly class-architecture
# audit reads the same file.

paired_override_rules = function() {
	rules = utils::read.csv(test_path("class_architecture_paired_overrides.csv"), stringsAsFactors = FALSE)
	rules$delegate_helpers[is.na(rules$delegate_helpers)] = ""
	rules
}

paired_override_called_names = function(f) {
	called = character()
	walk = function(e) {
		if (!is.call(e)) return(invisible(NULL))
		fn = e[[1L]]
		if (is.name(fn)) {
			called <<- c(called, as.character(fn))
		} else if (is.call(fn) && (identical(fn[[1L]], as.name("$")) || identical(fn[[1L]], as.name("[["))) && length(fn) >= 3L) {
			nm = fn[[3L]]
			if (is.name(nm) || is.character(nm)) called <<- c(called, as.character(nm))
		}
		for (part in as.list(e)) walk(part)
		invisible(NULL)
	}
	walk(body(f))
	unique(called)
}

paired_override_nearest = function(gen, method) {
	depth = 0L
	g = gen
	while (!is.null(g)) {
		f = g$private_methods[[method]]
		if (is.null(f)) f = g$public_methods[[method]]
		if (is.function(f)) return(list(classname = g$classname, depth = depth, f = f))
		depth = depth + 1L
		g = g$get_inherit()
	}
	NULL
}

paired_override_violations = function(generators, rules) {
	out = character()
	for (i in seq_len(nrow(rules))) {
		stat = rules$statistic_method[i]
		coupled = rules$coupled_method[i]
		accepted = c(stat, Filter(nzchar, trimws(strsplit(rules$delegate_helpers[i], ";", fixed = TRUE)[[1L]])))
		for (gen in generators) {
			a = paired_override_nearest(gen, stat)
			b = paired_override_nearest(gen, coupled)
			if (is.null(a) || is.null(b) || a$depth >= b$depth) next
			if (any(accepted %in% paired_override_called_names(b$f))) next
			out = c(out, sprintf("%s: %s comes from %s, but %s is inherited from %s and does not call %s",
				gen$classname, stat, a$classname, coupled, b$classname, paste(accepted, collapse = " or ")))
		}
	}
	unique(out)
}

test_that("every inherited coupled method computes the statistic its class redefines", {
	ns = asNamespace("EDI")
	nms = grep("^(Inference|Design)", ls(ns, all.names = TRUE), value = TRUE)
	generators = Filter(function(x) inherits(x, "R6ClassGenerator"), mget(nms, envir = ns))
	expect_gt(length(generators), 100L)
	rules = paired_override_rules()
	expect_gt(nrow(rules), 0L)
	for (i in seq_len(nrow(rules))) {
		defined_anywhere = any(vapply(generators, function(g) !is.null(paired_override_nearest(g, rules$statistic_method[i])), logical(1)))
		expect_true(defined_anywhere, info = sprintf("rule %d names a method no class defines: %s", i, rules$statistic_method[i]))
	}
	violations = paired_override_violations(generators, rules)
	expect_identical(violations, character(), info = paste(violations, collapse = "\n"))
})

test_that("the paired-override check flags an inherited coupled method that ignores the statistic", {
	Base = R6::R6Class("PairedOverrideFixtureBase", private = list(
		stat = function() 1,
		worker = function() 2,
		worker_via = function() private$stat()
	))
	Delegating = R6::R6Class("PairedOverrideFixtureDelegating", inherit = Base, private = list(
		worker = function() private$worker_via()
	))
	BadChild = R6::R6Class("PairedOverrideFixtureBadChild", inherit = Base, private = list(stat = function() 3))
	GoodChild = R6::R6Class("PairedOverrideFixtureGoodChild", inherit = Delegating, private = list(stat = function() 3))
	BothChild = R6::R6Class("PairedOverrideFixtureBothChild", inherit = Base, private = list(
		stat = function() 3,
		worker = function() 4
	))
	rules = data.frame(statistic_method = "stat", coupled_method = "worker", delegate_helpers = "worker_via",
		stringsAsFactors = FALSE)
	violations = paired_override_violations(list(Base, Delegating, BadChild, GoodChild, BothChild), rules)
	expect_length(violations, 1L)
	expect_match(violations, "^PairedOverrideFixtureBadChild: ")
})
