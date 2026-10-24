# Keep Eigen kernels optimized while collecting native execution counters.
configure_coverage_compiler = function() {
	if (!requireNamespace("covr", quietly = TRUE)) stop("Coverage requires covr.")
	flags = getOption("covr.flags")
	compiler_flags = grepl("^(C|CXX.*|F|FC)FLAGS$", names(flags))
	# -Wno-ignored-attributes: src/Makevars already passes this for the ordinary
	# build; covr builds with its own flags and so does not inherit it. Without
	# it every Eigen/RcppEigen template instantiation warns, which buried a
	# shard's log under ~50 MB of warnings in under 8 minutes -- past the point
	# where GitHub's log API truncates, so the per-file "[coverage] <file>"
	# progress markers were unreachable when a shard had to be diagnosed.
	flags[compiler_flags] = paste(
		trimws(gsub("(^|[[:space:]])-O([0-9]+|fast|g|s|z)(?=[[:space:]]|$)",
			"", flags[compiler_flags], perl = TRUE)), "-O2 -Wno-ignored-attributes")
	options(covr.flags = flags)
	invisible(flags)
}
