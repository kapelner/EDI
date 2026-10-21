BENCHMARK_SECTION_NAMES = c("models", "wald", "utility", "procedures", "designs")

parse_benchmark_sections = function(args = commandArgs(trailingOnly = TRUE)) {
	inline = sub("^--?sections=", "", args[grepl("^--?sections=", args)])
	flag = which(args %in% c("--sections", "-sections"))
	if (length(flag) > 0L && any(flag == length(args))) {
		stop("`--sections` requires a comma-separated value")
	}
	explicit_filter = length(inline) > 0L || length(flag) > 0L
	separate = if (length(flag) > 0L) args[flag + 1L] else character(0)
	requested = trimws(unlist(strsplit(c(inline, separate), ",", fixed = TRUE)))
	requested = requested[nzchar(requested)]
	if (length(requested) == 0L) {
		if (explicit_filter) stop("`--sections` requires a non-empty comma-separated value")
		return(BENCHMARK_SECTION_NAMES)
	}
	requested = unique(tolower(requested))
	all_requested = "all" %in% requested
	sections_to_validate = setdiff(requested, "all")
	invalid = setdiff(sections_to_validate, BENCHMARK_SECTION_NAMES)
	if (length(invalid) > 0L) {
		stop("Unknown benchmark section(s): ", paste(invalid, collapse = ", "),
		     ". Choose from: ", paste(c("all", BENCHMARK_SECTION_NAMES), collapse = ", "))
	}
	if (all_requested) {
		return(BENCHMARK_SECTION_NAMES)
	}
	requested
}
