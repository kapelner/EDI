library(testthat)
library(EDI)

source(test_path("..", "..", "benchmark", "benchmark_sections.R"), local = TRUE)

test_that("benchmark section selection supports defaults and both CLI forms", {
	expect_identical(
		parse_benchmark_sections(character()),
		c("models", "wald", "utility", "procedures", "designs")
	)
	expect_identical(parse_benchmark_sections("--sections=procedures,designs"),
	                 c("procedures", "designs"))
	expect_identical(parse_benchmark_sections(c("--sections", "procedures,designs")),
	                 c("procedures", "designs"))
	expect_identical(parse_benchmark_sections("--sections=all"),
	                 c("models", "wald", "utility", "procedures", "designs"))
})

test_that("an explicit empty benchmark section filter fails closed", {
	expect_error(parse_benchmark_sections("--sections="), "non-empty")
	expect_error(parse_benchmark_sections("--sections= , "), "non-empty")
	expect_error(parse_benchmark_sections(c("--sections", "")), "non-empty")
	expect_error(parse_benchmark_sections("--sections"), "requires a comma-separated value")
})

test_that("unknown benchmark sections are rejected", {
	expect_error(parse_benchmark_sections("--sections=procedure"), "Unknown benchmark section")
	expect_error(parse_benchmark_sections("--sections=all,modles"), "Unknown benchmark section")
	expect_identical(parse_benchmark_sections("--sections=all,models"),
	                 c("models", "wald", "utility", "procedures", "designs"))
})

test_that("model-fit benchmark metadata binds the loaded EDI R-layer payload", {
	benchmark_script = file.path("..", "..", "benchmark", "benchmark_model_fits.R")
	expressions = parse(benchmark_script)
	definition = function(name) {
		matches = Filter(function(expr) {
			is.call(expr) && identical(expr[[1L]], as.name("=")) &&
				identical(expr[[2L]], as.name(name))
		}, expressions)
		expect_length(matches, 1L)
		matches[[1L]]
	}
	helper_env = new.env(parent = globalenv())
	eval(definition("benchmark_edi_sha256_file"), envir = helper_env)
	eval(definition("benchmark_edi_r_layer_identity"), envir = helper_env)
	eval(definition("benchmark_edi_r_layer_report_lines"), envir = helper_env)
	eval(definition("compile_context_lines"), envir = helper_env)

	installed = helper_env$benchmark_edi_r_layer_identity()
	expect_true(dir.exists(installed$path))
	expect_gte(installed$file_count, 1L)
	expect_match(installed$manifest_sha256, "^[[:xdigit:]]{64}$")
	lines = helper_env$benchmark_edi_r_layer_report_lines(installed)
	expect_true(any(grepl(installed$path, lines, fixed = TRUE)))
	expect_true(any(grepl(installed$manifest_sha256, lines, fixed = TRUE)))
	helper_env$benchmark_edi_r_layer = installed
	helper_env$edi_build_info_cpp = function() as.list(setNames(rep("test", 18L), c(
		"capture_method", "build_timestamp", "build_host", "r_version", "r_cxx20", "r_cxx20std",
		"r_cxx20flags", "r_shlib_openmp_cxxflags", "env_edi_portable", "env_edi_disable_vectorization",
		"env_edi_native_speed", "env_edi_native_lto", "pkg_cppflags", "pkg_cxxflags", "pkg_libs",
		"compiler", "compiler_optimize_macro", "compiler_fast_math_macro"
	)))
	helper_env$edi_build_info_cpp = local({
		build_info = helper_env$edi_build_info_cpp()
		build_info$eigen_dont_vectorize_macro = "test"
		function() build_info
	})
	generated_context = helper_env$compile_context_lines()
	expect_true(any(grepl(installed$path, generated_context, fixed = TRUE)))
	expect_true(any(grepl(installed$manifest_sha256, generated_context, fixed = TRUE)))
	helper_env$edi_build_info_cpp = function() NULL
	helper_env$env_flag = function(var, default) default
	helper_env$cmd_config = function(var) "test-config"
	generated_fallback_context = helper_env$compile_context_lines()
	expect_true(any(grepl(installed$path, generated_fallback_context, fixed = TRUE)))
	expect_true(any(grepl(installed$manifest_sha256, generated_fallback_context, fixed = TRUE)))

	namespace_dir = tempfile("edi-model-fit-r-layer-")
	dir.create(file.path(namespace_dir, "R"), recursive = TRUE)
	payload = file.path(namespace_dir, "R", "EDI.rdb")
	writeBin(charToRaw("payload-before"), payload)
	before = helper_env$benchmark_edi_r_layer_identity(namespace_dir)
	writeBin(charToRaw("payload-after"), payload)
	after = helper_env$benchmark_edi_r_layer_identity(namespace_dir)
	expect_false(identical(before$manifest_sha256, after$manifest_sha256))
	expect_identical(before$file_count, 1L)
})
