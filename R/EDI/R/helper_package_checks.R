# Suggests-package availability checks (memoized) and misc small utilities used across design/inference classes to guard optional dependencies.

# Package installation cache
package_cache = new.env(parent = emptyenv())

#' Check Whether a Suggested Package Is Installed (Memoized)
#'
#' Tests whether \code{package_name} is installed via
#' \code{\link[base]{requireNamespace}} and memoizes the result in a
#' package-level environment (\code{package_cache}), so that repeated checks
#' for the same package within an R session pay the namespace-lookup cost
#' only once. EDI uses this to guard optional code paths that depend on
#' Suggests-only packages (e.g. \pkg{quantreg}, \pkg{betareg},
#' \pkg{nbpMatching}, \pkg{geepack}, \pkg{icenReg}) that are not installed
#' automatically with the package, issuing an informative
#' \code{stop()}/\code{warning()} and falling back to an internal
#' implementation when the dependency is absent, rather than failing with an
#' opaque "could not find function" error.
#'
#' @details
#' \strong{Caching / mutation semantics.} This function has a side effect:
#' on the first call for a given \code{package_name} in the current R
#' session, it assigns the boolean result of \code{requireNamespace()} into
#' the package-global environment \code{package_cache}, keyed by
#' \code{package_name}. All subsequent calls for the same
#' \code{package_name} (from anywhere in the package, or from user code)
#' read the cached value directly and do not re-query the namespace
#' registry. This means the result reflects whether the package was
#' installed \emph{at the time of the first call}; installing or removing
#' \code{package_name} later in the same R session will not be picked up.
#' The cache is a plain environment (not an R6 object) shared by all
#' callers within the process and is not reset between calls; it is,
#' however, re-initialized fresh in each new R session.
#'
#' \strong{Determinism.} For a fixed installed-package state,
#' \code{check_package_installed()} is deterministic and side-effect-free
#' beyond the memoization described above; it does not consume random
#' number generator state and involves no numerical computation.
#'
#' \strong{Lifecycle.} Internal utility (exported for reuse within the
#' package's own R6 classes across files, not intended as a general-purpose
#' user-facing API); prefer \code{requireNamespace()} directly for
#' one-off checks in user code.
#'
#' @param package_name Character scalar. The name of the package to check
#'   (as passed to \code{requireNamespace()}).
#' @return Logical scalar. \code{TRUE} if the package is installed and its
#'   namespace can be loaded, \code{FALSE} otherwise.
#' @seealso \code{\link[base]{requireNamespace}}, on which this function is
#'   a thin memoizing wrapper.
#' @keywords internal
#' @export
check_package_installed = function(package_name) {
	if (!exists(package_name, envir = package_cache, inherits = FALSE)) {
		res = requireNamespace(package_name, quietly = TRUE)
		assign(package_name, res, envir = package_cache)
	}
	get(package_name, envir = package_cache)
}

# Helper for parallel progress bars
print_progress = function(pb, i, total) {
	if (!is.null(pb)) {
		utils::setTxtProgressBar(pb, i)
	}
}

assert_nbpmatching_installed = function(caller) {
	if (!requireNamespace("nbpMatching", quietly = TRUE)) {
		stop("Package 'nbpMatching' is required for ", caller, ".")
	}
}

assert_optimal_blocks_libraries_installed = function(caller) {
	required_pkgs = c("ompr", "ompr.roi", "ROI.plugin.glpk", "randomizr")
	missing_pkgs = required_pkgs[!vapply(required_pkgs, check_package_installed, logical(1))]
	if (length(missing_pkgs) > 0L) {
		stop("Packages ", paste(missing_pkgs, collapse = ", "), " are required for ", caller, ".")
	}
}

assert_blocktools_installed = function(caller) {
	if (!check_package_installed("blockTools"))
		stop("Package 'blockTools' is required for ", caller, ".")
}

assert_anticlust_installed = function(caller) {
	if (!check_package_installed("anticlust"))
		stop("Package 'anticlust' is required for ", caller, ".")
}

assert_icenreg_installed = function(caller) {
	if (!check_package_installed("icenReg"))
		stop("Package 'icenReg' is required for ", caller, ". Please install it with install.packages(\"icenReg\").")
}

# 'interval' depends on Bioconductor's 'Icens', which install.packages()
# cannot resolve on its own -- it must be installed via BiocManager first,
# or install.packages("interval") fails with "dependency 'Icens' is not
# available for package 'interval'".
assert_interval_installed = function(caller) {
	if (!check_package_installed("interval")) {
		stop(
			"Package 'interval' is required for ", caller, ". It depends on ",
			"Bioconductor's 'Icens' package, which install.packages() cannot ",
			"resolve directly. Please install it with:\n",
			"  if (!requireNamespace(\"BiocManager\", quietly = TRUE)) install.packages(\"BiocManager\")\n",
			"  BiocManager::install(\"Icens\")\n",
			"  install.packages(\"interval\")"
		)
	}
}

