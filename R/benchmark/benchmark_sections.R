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

# `--shard=k/n` (or `--shard k/n`) runs only the k-th of n contiguous chunks of
# the rows of the sharded sections (BENCHMARK_SHARDED_SECTIONS), so one long
# section can be timed on several CI runners at once. Every row seeds its own
# data from its class name, so a row times the same in any shard. The other
# sections ignore the shard and run all their rows. Default 1/1 (every row).
BENCHMARK_SHARDED_SECTIONS = c("models", "wald")

parse_benchmark_shard = function(args = commandArgs(trailingOnly = TRUE)) {
	inline = sub("^--?shard=", "", args[grepl("^--?shard=", args)])
	flag = which(args %in% c("--shard", "-shard"))
	if (length(flag) > 0L && any(flag == length(args))) stop("`--shard` requires a value k/n")
	value = c(inline, if (length(flag) > 0L) args[flag + 1L])
	if (length(value) == 0L) return(c(k = 1L, n = 1L))
	if (length(value) > 1L) stop("`--shard` given more than once")
	m = regmatches(value, regexec("^\\s*([0-9]+)\\s*/\\s*([0-9]+)\\s*$", value))[[1L]]
	if (length(m) != 3L) stop("`--shard` must look like k/n (e.g. 1/2), got: ", value)
	k = as.integer(m[[2L]]); n = as.integer(m[[3L]])
	if (n < 1L || k < 1L || k > n) stop("`--shard` needs 1 <= k <= n, got: ", value)
	c(k = k, n = n)
}

# Indices of the rows (out of n_rows) that shard k of n runs: contiguous chunks
# whose sizes differ by at most one, e.g. 56 rows in 2 shards -> 1:28 and 29:56.
benchmark_shard_indices = function(n_rows, shard) {
	k = shard[["k"]]; n = shard[["n"]]
	bounds = floor(seq(0, n_rows, length.out = n + 1L))
	if (bounds[k + 1L] <= bounds[k]) return(integer(0))
	seq.int(bounds[k] + 1L, bounds[k + 1L])
}

# Saving and merging timing results, so one report can be built from several
# runs (the nightly CI times each section, or half of one, on its own runner).
#   --save-results=FILE      after timing, save this run's raw result rows to FILE (.rds)
#   --from-results=F1,F2,... time nothing: load the rows saved by those runs and build the
#                            report from all of them (its sections are those the runs timed)
parse_benchmark_path_arg = function(name, args = commandArgs(trailingOnly = TRUE)) {
	pattern = paste0("^--?", name, "=")
	inline = sub(pattern, "", args[grepl(pattern, args)])
	flag = which(args %in% paste0(c("--", "-"), name))
	if (length(flag) > 0L && any(flag == length(args))) stop("`--", name, "` requires a value")
	value = c(inline, if (length(flag) > 0L) args[flag + 1L])
	if (length(value) == 0L) return(NULL)
	if (length(value) > 1L) stop("`--", name, "` given more than once")
	paths = trimws(strsplit(value, ",", fixed = TRUE)[[1L]])
	paths = paths[nzchar(paths)]
	if (length(paths) == 0L) stop("`--", name, "` requires a non-empty value")
	paths
}

parse_benchmark_save_results = function(args = commandArgs(trailingOnly = TRUE)) {
	path = parse_benchmark_path_arg("save-results", args)
	if (length(path) > 1L) stop("`--save-results` takes one file")
	path
}

parse_benchmark_from_results = function(args = commandArgs(trailingOnly = TRUE)) {
	paths = parse_benchmark_path_arg("from-results", args)
	if (is.null(paths)) return(NULL)
	if (any(grepl("^--?(sections|shard|save-results)(=|$)", args))) {
		stop("`--from-results` builds a report from saved runs; it cannot be combined with ",
		     "`--sections`, `--shard` or `--save-results`")
	}
	missing = paths[!file.exists(paths)]
	if (length(missing)) stop("saved benchmark results not found: ", paste(missing, collapse = ", "))
	paths
}

BENCHMARK_RESULT_FIELDS = c("results", "wald_results", "utility_results", "dt_proc", "dt_design")

# Concatenate the rows of several saved runs. Two runs that both timed the same
# section and shard would put that section's rows in the report twice: refused.
merge_benchmark_results = function(saved) {
	runs = vapply(saved, function(s) {
		paste(vapply(s$sections, function(sec) {
			if (sec %in% BENCHMARK_SHARDED_SECTIONS) sprintf("%s %d/%d", sec, s$shard[["k"]], s$shard[["n"]]) else sec
		}, character(1)), collapse = ", ")
	}, character(1))
	units = unlist(strsplit(runs, ", ", fixed = TRUE))
	if (anyDuplicated(units)) stop("two saved runs timed the same rows: ", paste(unique(units[duplicated(units)]), collapse = ", "))
	sections = BENCHMARK_SECTION_NAMES[BENCHMARK_SECTION_NAMES %in% unlist(lapply(saved, `[[`, "sections"))]
	out = list(sections = sections, runs = runs, compile_context = saved[[1L]]$compile_context)
	for (f in BENCHMARK_RESULT_FIELDS) {
		parts = lapply(saved, `[[`, f)
		out[[f]] = if (f %in% c("dt_proc", "dt_design")) {
			parts = Filter(Negate(is.null), parts)
			if (length(parts)) data.table::rbindlist(parts) else NULL
		} else do.call(c, unname(parts))
	}
	out
}
