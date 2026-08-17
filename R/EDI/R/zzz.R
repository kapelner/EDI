#' @importFrom randomizr block_ra block_and_cluster_ra cluster_ra
NULL

.onLoad = function(libname, pkgname) {
	if (is.null(getOption("datatable.quiet"))) {
		options(datatable.quiet = TRUE)
	}

	# Set default for assertion execution
	if (is.null(getOption("edi.run_asserts"))) {
		options(edi.run_asserts = TRUE)
	}

	# Pin OpenMP/BLAS threads to 1 at load time so the package is actually
	# single-threaded by default, matching get_num_cores()'s own default belief
	# (fix_design_hierarchy.md, TODO-29). Without this, the OpenMP runtime falls
	# back to its own default (typically every detected logical core) the moment
	# any Rcpp kernel with a `#pragma omp parallel` region runs, regardless of
	# get_num_cores() -- confirmed empirically: get_num_cores() reports 1L on a
	# fresh session while RhpcBLASctl::omp_get_max_threads() reported the
	# machine's full core count. This silently made every OpenMP-parallel kernel
	# multi-threaded by default (a real, previously-unnoticed resource-usage
	# surprise for anyone who never explicitly calls set_num_cores()), and made
	# DesignFixedRerandomization's work-stealing rejection sampler
	# (rerandomization_search_cpp) non-seed-reproducible even in the "default"
	# case its own metadata claimed was safe. set_package_threads() is the same
	# function set_num_cores(N) uses to apply N; calling it here with 1L at load
	# time keeps the R-level default (get_num_cores() == 1) and the actual
	# OpenMP/BLAS thread count in sync from the start, until/unless the user
	# explicitly opts into more via set_num_cores().
	set_package_threads(1L)
}

.onAttach = function(libname, pkgname){
	version <- tryCatch(
		as.character(utils::packageDescription(pkgname, lib.loc = libname, fields = "Version")),
		error = function(e) NA_character_
	)
	if (!is.character(version) || length(version) != 1L || is.na(version) || version == "") {
		version <- "unknown"
	}
	packageStartupMessage(
			paste("Welcome to EDI v", version, sep = "")
	)
}
