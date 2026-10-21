# Split resumed comprehensive rows into rows that are complete and rows that
# represent a timeout which may seed the opt-in timeout cache.
classify_comprehensive_existing_result_rows <- function(results){
	n = nrow(results)
	if (!"status" %in% names(results)) {
		return(list(completed_rows = seq_len(n), confirmed_timeout_rows = integer()))
	}

	status = as.character(results$status)
	ok_rows = !is.na(status) & status == "ok"
	error_message = if ("error_message" %in% names(results)) as.character(results$error_message) else rep(NA_character_, n)
	timeout_pattern = "^Skipped due to timeout after (?:1|60|120) seconds(?: \\(outer safe_call guard\\))?$"
	is_confirmed_timeout = !is.na(error_message) & grepl(timeout_pattern, error_message, perl = TRUE)
	confirmed_timeout_rows = which(ok_rows & is_confirmed_timeout)
	completed_rows = which(ok_rows & !is_confirmed_timeout)

	list(
		completed_rows = completed_rows,
		confirmed_timeout_rows = confirmed_timeout_rows
	)
}
