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

# Response families. A models or wald row belongs to the family its response
# type names (the report's Response column); `--families=survival,count` runs only
# those rows of the models and wald sections, so the nightly CI times each family
# as its own job and reruns only the families whose code changed. The other
# sections ignore it. The classifiers below are the ones run_one() and
# run_one_wald() use for the Response column (they differ slightly: the models one
# also knows the Sign/Stereotype/CMH/Zhang/Robins/Wald classes).
BENCHMARK_FAMILY_NAMES = c("continuous", "incidence", "count", "proportion", "ordinal", "survival")
BENCHMARK_FAMILY_SECTIONS = c("models", "wald")
# generate_data() family for each response type.
BENCHMARK_DATA_FAMILY = c(continuous = "continuous", incidence = "logistic", count = "poisson",
                          proportion = "beta", ordinal = "ordinal", survival = "cox")

benchmark_models_response = function(cls_name) {
	# Ordinal MUST come before Prop/PropOdds.
	if (grepl("Ordinal|AdjCat|ContRatio|Stereotype|Jonckheere|Ridit|Sign", cls_name)) "ordinal"
	else if (grepl("Incid|Binomial|Wald|CMH|Fisher|Zhang|Robins|Newcombe|Nurminen|logistic_glmm", cls_name)) "incidence"
	else if (grepl("Count|Poisson|NegBin|ZINB|ZAP|Hurdle", cls_name)) "count"
	else if (grepl("Prop|Beta|ZOIB|Fractional", cls_name)) "proportion"
	else if (grepl("Survival|Cox|Weibull|KM|Rank|LogRank|Gehan|RMST|RMDiff|LWACox|Clayton", cls_name)) "survival"
	else "continuous"
}

benchmark_wald_response = function(cls_name) {
	if (grepl("Ordinal|AdjCat|ContRatio|Ridit|Jonckheere", cls_name)) "ordinal"
	else if (grepl("Incid|Binomial|Fisher|Newcombe|Nurminen|logistic_glmm", cls_name)) "incidence"
	else if (grepl("Count|Poisson|NegBin|ZINB|ZAP|Hurdle", cls_name)) "count"
	else if (grepl("Prop|Beta|ZOIB|Fractional", cls_name)) "proportion"
	else if (grepl("Survival|Cox|Weibull|KM|Rank|LogRank|Gehan", cls_name)) "survival"
	else "continuous"
}

parse_benchmark_families = function(args = commandArgs(trailingOnly = TRUE)) {
	inline = sub("^--?families=", "", args[grepl("^--?families=", args)])
	flag = which(args %in% c("--families", "-families"))
	if (length(flag) > 0L && any(flag == length(args))) stop("`--families` requires a comma-separated value")
	if (length(inline) + length(flag) == 0L) return(BENCHMARK_FAMILY_NAMES)
	requested = trimws(unlist(strsplit(c(inline, if (length(flag)) args[flag + 1L]), ",", fixed = TRUE)))
	requested = unique(tolower(requested[nzchar(requested)]))
	if (length(requested) == 0L) stop("`--families` requires a non-empty comma-separated value")
	invalid = setdiff(requested, BENCHMARK_FAMILY_NAMES)
	if (length(invalid)) stop("Unknown benchmark famil(ies): ", paste(invalid, collapse = ", "),
	                          ". Choose from: ", paste(BENCHMARK_FAMILY_NAMES, collapse = ", "))
	BENCHMARK_FAMILY_NAMES[BENCHMARK_FAMILY_NAMES %in% requested]
}

# Indices (into the section's unique specs) of the rows this run times: the rows of
# the requested families, then this shard's contiguous chunk of those.
benchmark_row_indices = function(classes, classify, families, shard) {
	keep = which(vapply(classes, classify, character(1)) %in% families)
	keep[benchmark_shard_indices(length(keep), shard)]
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
	if (any(grepl("^--?(sections|shard|families|save-results)(=|$)", args))) {
		stop("`--from-results` builds a report from saved runs; it cannot be combined with ",
		     "`--sections`, `--shard`, `--families` or `--save-results`")
	}
	missing = paths[!file.exists(paths)]
	if (length(missing)) stop("saved benchmark results not found: ", paste(missing, collapse = ", "))
	paths
}

BENCHMARK_RESULT_FIELDS = c("results", "wald_results", "utility_results", "dt_proc", "dt_design")

# The rows one saved run timed, as labels: "designs", "wald 2/2", "models (survival)".
# Runs saved before --families existed have no `families` field and mean every family.
benchmark_run_units = function(s) {
	fams = if (is.null(s$families)) BENCHMARK_FAMILY_NAMES else s$families
	vapply(s$sections, function(sec) {
		lab = sec
		if (sec %in% BENCHMARK_SHARDED_SECTIONS && s$shard[["n"]] > 1L) lab = sprintf("%s %d/%d", lab, s$shard[["k"]], s$shard[["n"]])
		if (sec %in% BENCHMARK_FAMILY_SECTIONS && !setequal(fams, BENCHMARK_FAMILY_NAMES)) lab = sprintf("%s (%s)", lab, paste(fams, collapse = ", "))
		lab
	}, character(1), USE.NAMES = FALSE)
}

# Where a run's rows came from: the commit and time it timed them (the nightly CI
# reuses a part's saved rows on nights when nothing it depends on changed).
benchmark_git_commit = function() {
	sha = Sys.getenv("GITHUB_SHA")
	if (!nzchar(sha)) sha = tryCatch(suppressWarnings(system2("git", c("rev-parse", "HEAD"), stdout = TRUE, stderr = FALSE)),
	                                 error = function(e) character(0))
	if (length(sha) == 1L && grepl("^[0-9a-f]{40}$", sha)) sha else NA_character_
}

# Concatenate the rows of several saved runs. Two runs that both timed the same
# rows would put them in the report twice: refused.
merge_benchmark_results = function(saved) {
	unit_lists = lapply(saved, benchmark_run_units)
	runs = vapply(unit_lists, paste, character(1), collapse = ", ")
	units = unlist(unit_lists)
	if (anyDuplicated(units)) stop("two saved runs timed the same rows: ", paste(unique(units[duplicated(units)]), collapse = ", "))
	# A family-split run and a run of every family of the same section also overlap.
	for (sec in BENCHMARK_FAMILY_SECTIONS) {
		whole = units[units == sec | grepl(paste0("^", sec, " [0-9]+/[0-9]+$"), units)]
		split = units[startsWith(units, paste0(sec, " ("))]
		if (length(whole) && length(split)) stop("two saved runs timed the same rows: ", whole[[1L]], " and ", split[[1L]])
	}
	sections = BENCHMARK_SECTION_NAMES[BENCHMARK_SECTION_NAMES %in% unlist(lapply(saved, `[[`, "sections"))]
	provenance = data.frame(
		part = runs,
		commit = vapply(saved, function(s) if (is.null(s$commit)) NA_character_ else s$commit, character(1)),
		timed = vapply(saved, function(s) if (is.null(s$generated)) NA_character_ else format(s$generated, "%Y-%m-%d %H:%M UTC", tz = "UTC"), character(1)),
		stringsAsFactors = FALSE)
	# The compilation context of the newest run: the build tonight's report was assembled with.
	when = vapply(saved, function(s) if (is.null(s$generated)) -Inf else as.numeric(s$generated), numeric(1))
	out = list(sections = sections, runs = runs, provenance = provenance,
	           compile_context = saved[[which.max(when)]]$compile_context)
	for (f in BENCHMARK_RESULT_FIELDS) {
		parts = lapply(saved, `[[`, f)
		out[[f]] = if (f %in% c("dt_proc", "dt_design")) {
			parts = Filter(Negate(is.null), parts)
			if (length(parts)) data.table::rbindlist(parts) else NULL
		} else do.call(c, unname(parts))
	}
	out
}
