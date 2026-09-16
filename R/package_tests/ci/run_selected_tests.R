# Runs against an already loaded package; never loads or compiles source.
run_selected_tests = function(root, shard_file, tier, timing_file) {
	shard = jsonlite::fromJSON(shard_file)
	dir.create(dirname(timing_file), recursive = TRUE, showWarnings = FALSE)
	timings = data.frame(test_file = character(), runtime_tier = character(),
		elapsed_seconds = numeric(), status = character())
	failed = FALSE
	for (file in shard$test_files) {
		cat(sprintf("\n[%s] %s\n", tier, file))
		# Record an in-progress row before execution so a timeout identifies its culprit.
		row = data.frame(test_file = file, runtime_tier = tier, elapsed_seconds = NA_real_, status = "running")
		write.csv(rbind(timings, row), timing_file, row.names = FALSE)
		start = proc.time()[["elapsed"]]
		stem = sub("\\.R$", "", sub("^test-", "", basename(file)))
		pattern = paste0("^", gsub(".", "\\.", stem, fixed = TRUE), "$")
		tryCatch({
			results = testthat::test_dir(file.path(root, dirname(file)), filter = pattern,
				reporter = Sys.getenv("EDI_BULK_TESTS_REPORTER", "summary"), stop_on_failure = FALSE)
			df = as.data.frame(results)
			if (!nrow(df)) stop("Selected file produced no tests: ", file)
			failed = failed || any(df$failed > 0 | df$error, na.rm = TRUE)
			row$status = "complete"
		}, error = function(e) {
			message(conditionMessage(e))
			failed <<- TRUE
			row$status <<- "error"
		})
		row$elapsed_seconds = proc.time()[["elapsed"]] - start
		timings = rbind(timings, row)
		write.csv(timings, timing_file, row.names = FALSE)
	}
	if (failed) {
		if (tier == "correctness") stop("Shard contained test failures or errors; see test output above.")
		warning("Coverage shard contained test failures or errors; correctness is gated separately.")
	}
	invisible(timings)
}
