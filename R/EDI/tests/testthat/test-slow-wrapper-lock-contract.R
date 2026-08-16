slow_wrapper_fixture_path = function() {
	filename = "test-bootstrap-reused-worker-asymp-families.R"
	candidates = c(
		file.path("R", "EDI", "tests", "testthat", filename),
		filename,
		file.path("tests", "testthat", filename)
	)
	hits = candidates[file.exists(candidates)]
	if (!length(hits)) return(NULL)
	hits[[1L]]
}

slow_wrapper_r6_blocks = function(lines) {
	starts = grep("^\\s*SlowInference[A-Za-z0-9_]*\\s*=\\s*R6::R6Class\\(", lines, perl = TRUE)
	lapply(starts, function(start) {
		indent = sub("^(\\s*).*", "\\1", lines[[start]], perl = TRUE)
		closing_pattern = paste0("^", indent, "\\)\\s*$")
		end_candidates = which(seq_along(lines) > start & grepl(closing_pattern, lines, perl = TRUE))
		if (!length(end_candidates)) {
			stop("Could not find the end of SlowInference R6 block beginning on line ", start, ".")
		}
		lines[start:end_candidates[[1L]]]
	})
}

test_that("all SlowInference fixtures permit lazy component installation", {
	path = slow_wrapper_fixture_path()
	skip_if(is.null(path), "bootstrap reused-worker fixture source is unavailable")
	blocks = slow_wrapper_r6_blocks(readLines(path, warn = FALSE))
	expect_gt(length(blocks), 0L)
	missing = vapply(blocks, function(block) {
		!any(grepl("\\block_objects\\s*=\\s*FALSE\\b", block, perl = TRUE))
	}, logical(1L))
	expect_false(any(missing), info = "Every SlowInference R6 fixture must set lock_objects = FALSE")
})
