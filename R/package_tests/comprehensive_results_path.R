# Resolve the comprehensive harness result path without changing its default.
# Set EDI_COMPREHENSIVE_RESULTS_DIR to an existing directory for isolated runs;
# the canonical filename (including filters) is preserved within that directory.
resolve_comprehensive_results_file <- function(
  default_path,
  output_dir = Sys.getenv("EDI_COMPREHENSIVE_RESULTS_DIR", unset = "")
) {
  if (length(default_path) != 1L || is.na(default_path) || !nzchar(default_path)) {
    stop("default_path must be one nonempty path.", call. = FALSE)
  }
  if (length(output_dir) != 1L || is.na(output_dir)) {
    stop("EDI_COMPREHENSIVE_RESULTS_DIR must be one directory path.", call. = FALSE)
  }
  if (!nzchar(output_dir)) return(default_path)
  if (!dir.exists(output_dir)) {
    stop("EDI_COMPREHENSIVE_RESULTS_DIR is not an existing directory: ", output_dir, call. = FALSE)
  }
  file.path(normalizePath(output_dir, winslash = "/", mustWork = TRUE), basename(default_path))
}
