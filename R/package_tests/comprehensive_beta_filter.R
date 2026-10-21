# An explicit beta_T CLI filter selects the requested value, even when it is
# outside the runner's default sweep. This keeps filtered diagnostic runs from
# silently completing zero replicates.
parse_comprehensive_beta_filter <- function(value){
	if (length(value) == 0L || identical(as.character(value), "NA")) return(NA_real_)
	parsed = suppressWarnings(as.numeric(value))
	if (length(parsed) != 1L || is.na(parsed) || !is.finite(parsed)) {
		stop("beta_T filter must be NA or one finite number", call. = FALSE)
	}
	parsed
}

resolve_comprehensive_beta_values <- function(default_values, beta_filter){
	if (length(beta_filter) != 1L || is.na(beta_filter)) return(default_values)
	beta_filter = as.numeric(beta_filter)
	if (length(beta_filter) != 1L || !is.finite(beta_filter)) {
		stop("beta_T filter must be one finite number", call. = FALSE)
	}
	beta_filter
}
