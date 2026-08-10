suppressPackageStartupMessages(library(EDI))

`%||%` = function(x, y) if (is.null(x)) y else x

target_package_load_ms = 3000
target_inference_suite_discovery_ms = 500
target_lazy_registry_body_count = 0

time_expr_ms = function(expr) {
	gc()
	as.numeric(system.time(force(expr))[["elapsed"]]) * 1000
}

fresh_package_load_ms = function() {
	code = "suppressPackageStartupMessages(library(EDI)); cat('ok\\n')"
	cmd = file.path(R.home("bin"), "Rscript")
	as.numeric(system.time(system2(cmd, c("-e", shQuote(code)), stdout = FALSE, stderr = FALSE))[["elapsed"]]) * 1000
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

package_load_ms = fresh_package_load_ms()
des = make_suite_design()
suite_discovery_ms = time_expr_ms(InferenceSuite$new(des))

EDI:::clear_inference_component_implementation_cache()
lazy_names = lazy_component_names()
metadata_body_count = sum(vapply(lazy_names, function(name) {
	component = EDI:::get_inference_component(name)
	length(component$public) + length(component$private)
}, integer(1)))
for (name in lazy_names) {
	EDI:::get_lazy_component_dispatch(name, class_name = "LazyBenchmarkForced")
}
forced_body_count = loaded_cache_object_count("LazyBenchmarkForced")
forced_dispatch_count = dispatch_cache_component_count("LazyBenchmarkForced")

results = data.frame(
	metric = c(
		"fresh_package_load_ms",
		"inference_suite_discovery_ms",
		"lazy_registry_body_count",
		"forced_lazy_body_count",
		"forced_lazy_dispatch_count"
	),
	value = c(
		package_load_ms,
		suite_discovery_ms,
		metadata_body_count,
		forced_body_count,
		forced_dispatch_count
	),
	target = c(
		target_package_load_ms,
		target_inference_suite_discovery_ms,
		target_lazy_registry_body_count,
		NA_real_,
		NA_real_
	),
	pass = c(
		package_load_ms <= target_package_load_ms,
		suite_discovery_ms <= target_inference_suite_discovery_ms,
		metadata_body_count <= target_lazy_registry_body_count,
		NA,
		NA
	)
)

print(results, row.names = FALSE)
