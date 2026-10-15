library(testthat)
library(EDI)

test_that("build metadata accessor returns a stable, well-formed record", {
	info = edi_build_info_cpp()

	expected_character_fields = c(
		"capture_method", "build_timestamp", "build_host", "r_home",
		"r_version", "r_cxx20", "r_cxx20std", "r_cxx20flags",
		"r_shlib_openmp_cxxflags", "env_edi_portable",
		"env_edi_disable_vectorization", "env_edi_native_speed",
		"env_edi_native_lto", "pkg_cppflags", "pkg_cxxflags", "pkg_libs",
		"compiler"
	)
	expected_logical_fields = c(
		"compiler_optimize_macro", "compiler_fast_math_macro",
		"eigen_dont_vectorize_macro"
	)

	expect_named(info, c(expected_character_fields, expected_logical_fields))
	expect_true(all(vapply(info[expected_character_fields], is.character, logical(1))))
	expect_true(all(lengths(info[expected_character_fields]) == 1L))
	expect_true(all(vapply(info[expected_logical_fields], is.logical, logical(1))))
	expect_true(all(lengths(info[expected_logical_fields]) == 1L))
	expect_false(anyNA(info))
})

test_that("build metadata matches the current configure run", {
	info = edi_build_info_cpp()
	makeconf = file.path(R.home(), paste0("etc", Sys.getenv("R_ARCH")), "Makeconf")
	skip_if_not(file.exists(makeconf), "R Makeconf is unavailable")
	makeconf_lines = readLines(makeconf, warn = FALSE)
	openmp_line = grep("^SHLIB_OPENMP_CXXFLAGS[[:space:]]*=", makeconf_lines, value = TRUE)
	if (length(openmp_line)) {
		expected_openmp_flags = trimws(sub(
			"^SHLIB_OPENMP_CXXFLAGS[[:space:]]*=[[:space:]]*", "", openmp_line[[1L]]
		))
		# An empty assignment (e.g. macOS R) means no OpenMP; configure reports it as below.
		if (!nzchar(expected_openmp_flags)) expected_openmp_flags = "none (R built without OpenMP)"
	} else {
		expected_openmp_flags = "none (R built without OpenMP)"
	}
	expect_identical(info$r_shlib_openmp_cxxflags, expected_openmp_flags)

	# The portable build never carries -march=native. A mismatch means
	# build_info.o survived an incremental install and reports an older build.
	if (identical(info$env_edi_portable, "1")) {
		expect_false(grepl("-march=native", info$pkg_cxxflags, fixed = TRUE))
	}
})
