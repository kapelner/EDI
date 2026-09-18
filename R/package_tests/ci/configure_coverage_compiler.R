# Keep Eigen kernels optimized while collecting native execution counters.
configure_coverage_compiler = function() {
	if (!requireNamespace("covr", quietly = TRUE)) stop("Coverage requires covr.")
	flags = getOption("covr.flags")
	compiler_flags = grepl("^(C|CXX.*|F|FC)FLAGS$", names(flags))
	flags[compiler_flags] = paste(
		trimws(gsub("(^|[[:space:]])-O([0-9]+|fast|g|s|z)(?=[[:space:]]|$)",
			"", flags[compiler_flags], perl = TRUE)), "-O2")
	options(covr.flags = flags)
	invisible(flags)
}
