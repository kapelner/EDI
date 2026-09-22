#' @description Creates the Bayesian-bootstrap distribution of the treatment
#'   estimate using Dirichlet weights.
#'
#' @param B Number of Bayesian-bootstrap replicates. The default is 501.
#' @param show_progress A flag indicating whether a progress bar should be displayed.
#' @param debug If \code{TRUE}, return a list with the distribution values and
#'   per-iteration diagnostics including error messages, warning messages,
#'   counts of each, and summary proportions for iterations with errors,
#'   warnings, and illegal (non-finite) values. Runs serially. Default
#'   \code{FALSE}.
#' @param weighting_unit_type Optional Bayesian-bootstrap weighting-unit
#'   scheme. Legal public values are:
#'   \describe{
#'     \item{\code{NULL}}{Use the design's default weighting-unit logic. For
#'       ordinary non-blocking designs this is the usual subject-level
#'       Bayesian bootstrap. For certain blocking designs, \code{NULL} maps
#'       to the same behavior as \code{"within_blocks"}.}
#'     \item{\code{"within_blocks"}}{Only legal for blocking-style designs
#'       that support block-aware weighting:
#'       \code{DesignFixedBlocking}, \code{DesignFixedOptimalBlocks},
#'       \code{DesignSeqOneByOneSPBR}, and
#'       \code{DesignFixedBlockedCluster}. Draws Dirichlet weights on
#'       observational units within each observed block/stratum. For blocked
#'       cluster designs this means cluster-within-stratum weights.}
#'     \item{\code{"resample_blocks"}}{Only legal for the same
#'       blocking-style designs as \code{"within_blocks"}. Draws Dirichlet
#'       weights on whole observed blocks/strata rather than on units within
#'       each block.}
#'   }
#'   Any non-\code{NULL} value is rejected for designs outside that blocking
#'   family.
#'
#' @return When \code{debug = FALSE} (default), a numeric vector of length
#'   \code{B} containing the Bayesian-bootstrap estimates. When
#'   \code{debug = TRUE}, a list with: \code{values}, \code{errors} (list of
#'   character vectors, one per iteration), \code{warnings} (list of
#'   character vectors, one per iteration), \code{num_errors},
#'   \code{num_warnings}, \code{prop_iterations_with_errors},
#'   \code{prop_iterations_with_warnings}, and
#'   \code{prop_illegal_values}.
