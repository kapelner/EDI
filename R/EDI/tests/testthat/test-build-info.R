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
