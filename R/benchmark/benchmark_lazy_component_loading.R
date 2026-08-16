suppressPackageStartupMessages(library(EDI))

`%||%` = function(x, y) if (is.null(x)) y else x

target_package_load_ms = 3000
target_inference_suite_discovery_ms = 500
target_lazy_registry_body_count = 0
target_discovery_loaded_body_count = 0
target_forced_lazy_body_count_min = 1

time_expr_ms = function(expr) {
	gc()
	as.numeric(system.time(force(expr))[["elapsed"]]) * 1000
}

fresh_package_load_ms = function() {
	code = "suppressPackageStartupMessages(library(EDI)); cat('ok\\n')"
	cmd = file.path(R.home("bin"), "Rscript")
	exit_status = NA_integer_
	elapsed = system.time({
		exit_status = system2(cmd, c("-e", shQuote(code)), stdout = FALSE, stderr = FALSE)
	})[["elapsed"]]
	if (!identical(as.integer(exit_status), 0L)) {
		stop("Fresh-process EDI package load failed; refusing to record its failure time as a passing benchmark.", call. = FALSE)
	}
	as.numeric(elapsed) * 1000
}

make_suite_design = function() {
	des = EDI:::DesignFixed$new(n = 12, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = seq_len(12)))
	des$add_all_subject_responses(c(1, 0, 1, 0, 1, 0, 1, 0, 0, 1, 0, 1))
	des
}

lazy_component_names = function() {
	names(Filter(function(component) {
		identical(component$component_loader$load_policy %||% "eager", "lazy")
	}, EDI:::inference_component_registry_as_list()))
}

loaded_cache_object_count = function(class_name) {
	cache = EDI:::get_inference_component_cache_env(class_name)
	sum(vapply(ls(cache), function(name) {
		component = get(name, envir = cache, inherits = FALSE)
		length(component$public) + length(component$private)
	}, integer(1)))
}

dispatch_cache_component_count = function(class_name) {
	length(ls(EDI:::get_inference_component_dispatch_cache_env(class_name)))
}

total_loaded_cache_object_count = function(class_names) {
	sum(vapply(class_names, loaded_cache_object_count, integer(1L)))
}

package_load_ms = fresh_package_load_ms()
registered_class_names = names(EDI:::inference_class_registry_as_list())
EDI:::clear_inference_component_implementation_cache()
loaded_body_count_before_discovery = total_loaded_cache_object_count(registered_class_names)
des = make_suite_design()
suite_discovery_ms = time_expr_ms(InferenceSuite$new(des))
loaded_body_count_after_discovery = total_loaded_cache_object_count(registered_class_names)

lazy_names = lazy_component_names()
metadata_body_count = sum(vapply(lazy_names, function(name) {
	component = EDI:::get_inference_component(name)
	length(component$public) + length(component$private)
}, integer(1)))
forced_load_errors = character()
for (name in lazy_names) {
	tryCatch(
		EDI:::get_lazy_component_dispatch(name, class_name = "LazyBenchmarkForced"),
		error = function(e) {
			forced_load_errors[[name]] <<- conditionMessage(e)
		}
	)
}
forced_body_count = loaded_cache_object_count("LazyBenchmarkForced")
forced_dispatch_count = dispatch_cache_component_count("LazyBenchmarkForced")
suite_discovery_after_forced_load_ms = time_expr_ms(InferenceSuite$new(des))

results = data.frame(
	metric = c(
		"fresh_package_load_ms",
		"inference_suite_discovery_ms",
		"discovery_loaded_body_count_before",
		"discovery_loaded_body_count_after",
		"lazy_registry_body_count",
		"forced_lazy_body_count",
		"forced_lazy_dispatch_count",
		"forced_lazy_load_error_count",
		"inference_suite_discovery_after_forced_load_ms"
	),
	value = c(
		package_load_ms,
		suite_discovery_ms,
		loaded_body_count_before_discovery,
		loaded_body_count_after_discovery,
		metadata_body_count,
		forced_body_count,
		forced_dispatch_count,
		length(forced_load_errors),
		suite_discovery_after_forced_load_ms
	),
	target = c(
		target_package_load_ms,
		target_inference_suite_discovery_ms,
		target_discovery_loaded_body_count,
		target_discovery_loaded_body_count,
		target_lazy_registry_body_count,
		target_forced_lazy_body_count_min,
		length(lazy_names),
		0,
		target_inference_suite_discovery_ms
	),
	pass = c(
		package_load_ms <= target_package_load_ms,
		suite_discovery_ms <= target_inference_suite_discovery_ms,
		loaded_body_count_before_discovery == target_discovery_loaded_body_count,
		loaded_body_count_after_discovery == target_discovery_loaded_body_count,
		metadata_body_count <= target_lazy_registry_body_count,
		forced_body_count >= target_forced_lazy_body_count_min,
		forced_dispatch_count == length(lazy_names),
		length(forced_load_errors) == 0L,
		suite_discovery_after_forced_load_ms <= target_inference_suite_discovery_ms
	)
)

print(results, row.names = FALSE)

failed_metrics = results$metric[!is.na(results$pass) & !results$pass]
if (length(forced_load_errors) > 0L) {
	message("Lazy component load failures:")
	for (name in names(forced_load_errors)) {
		message("- ", name, ": ", forced_load_errors[[name]])
	}
}
if (length(failed_metrics) > 0L) {
	stop(
		"Lazy-loading performance gate failed: ",
		paste(failed_metrics, collapse = ", "),
		call. = FALSE
	)
}
