inference_policy_override_tables = function() {
	bootstrap = get_bootstrap_dispatch_policy()
	warm = get_warm_start_dispatch_policy()
	tables = list(
		"bootstrap.inference_class_overrides" = bootstrap$inference_class_overrides,
		"optimization.inference_class_overrides" =
			get_optimization_dispatch_policy()$inference_class_overrides,
		"cold_start.inference_class_overrides" =
			get_cold_start_dispatch_policy()$inference_class_overrides
	)
	for (operation in setdiff(names(warm), "default")) {
		tables[[paste0("warm_start.", operation, ".inference_class_overrides")]] =
			warm[[operation]]$inference_class_overrides
		n_conditioned = warm[[operation]]$n_conditioned_overrides
		if (length(n_conditioned) > 0L) {
			patterns = vapply(n_conditioned, function(rule) rule$pattern, character(1))
			tables[[paste0("warm_start.", operation, ".n_conditioned_overrides")]] =
				stats::setNames(vapply(n_conditioned, function(rule) rule$value, logical(1)), patterns)
		}
	}
	for (design_name in names(bootstrap$design_class_overrides)) {
		tables[[paste0("bootstrap.design_class_overrides.", design_name)]] =
			bootstrap$design_class_overrides[[design_name]]
	}
	tables
}

live_canonical_inference_generator_names = function() {
	ns = asNamespace("EDI")
	sort(Filter(function(name) {
		generator = get(name, envir = ns, inherits = FALSE)
		EDI:::is_inference_r6_generator(generator) && identical(generator$classname, name)
	}, ls(ns, all.names = TRUE)))
}

test_that("inference dispatch policy regexes match live canonical generators", {
	live_names = live_canonical_inference_generator_names()
	tables = inference_policy_override_tables()
	expect_gt(length(live_names), 0L)

	for (table_path in names(tables)) {
		overrides = tables[[table_path]]
		expect_true(is.atomic(overrides), info = table_path)
		if (length(overrides) > 0L) {
			expect_false(is.null(names(overrides)), info = table_path)
		}
		for (pattern in names(overrides)) {
			info = paste(table_path, pattern, sep = ": ")
			expect_false(is.na(pattern) || !nzchar(pattern), info = info)
			matches = tryCatch(
				grepl(pattern, live_names, perl = TRUE),
				error = function(e) e
			)
			expect_false(inherits(matches, "error"), info = info)
			if (!inherits(matches, "error")) {
				expect_true(any(matches), info = info)
			}
		}
	}
})
