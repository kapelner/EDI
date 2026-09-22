#' @description Creates the bootstrap distribution of the estimate for the treatment effect.
#'   The resampling unit is design-specific (rows, within-strata rows, matched pairs plus
#'   reservoir, or clusters); see the class-level section \emph{Design-specific validity
#'   caveats for the nonparametric bootstrap} for the conservativeness and asymptotics of
#'   each concrete design.
#'
#' @param B  					Number of bootstrap samples. The default is 501.
#' @param show_progress  		A flag indicating whether a progress bar should be displayed.
#' @param debug  				If \code{TRUE}, return a list with the distribution values and
#'   per-iteration diagnostics including error messages, warning messages, counts of each,
#'   and summary proportions for iterations with errors, warnings, and illegal (non-finite)
#'   values. Runs serially. Default \code{FALSE}.
#' @return 	When \code{debug = FALSE} (default), a numeric vector of length \code{B}
#'   containing the bootstrap estimates. When \code{debug = TRUE}, a list with: \code{values},
#'   \code{errors} (list of character vectors, one per iteration), \code{warnings} (list of
#'   character vectors, one per iteration), \code{num_errors}, \code{num_warnings},
#'   \code{prop_iterations_with_errors}, \code{prop_iterations_with_warnings}, and
#'   \code{prop_illegal_values}.
#' @param bootstrap_type Optional bootstrap-resampling scheme. Legal public values are:
#'   \describe{
#'     \item{\code{NULL}}{Use the design's default row-resampling bootstrap. For ordinary
#'       non-blocking designs this is the usual subject-level resample-with-replacement
#'       bootstrap. For certain blocking designs, \code{NULL} maps to the same behavior
#'       as \code{"within_blocks"}.}
#'     \item{\code{"within_blocks"}}{Only legal for blocking-style designs that support
#'       block-aware bootstrap resampling:
#'       \code{DesignFixedBlocking}, \code{DesignFixedOptimalBlocks},
#'       \code{DesignSeqOneByOneSPBR}, and \code{DesignFixedBlockedCluster}.
#'       Resamples observational units within each observed block/stratum. For blocked
#'       cluster designs this means resampling clusters within strata.}
#'     \item{\code{"resample_blocks"}}{Only legal for the same blocking-style designs as
#'       \code{"within_blocks"}. Resamples entire observed blocks/strata with replacement
#'       rather than resampling units within each block.}
#'   }
#'   Any non-\code{NULL} value is rejected for designs outside that blocking family.
