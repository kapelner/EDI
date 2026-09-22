#' @description Initialize simple Wilcoxon inference and prepare the
#'   rank-based treatment statistic used by
#'   \code{\link[EDI:InferenceAllSimpleWilcox]{InferenceAllSimpleWilcox}}.
#'   Rejects \code{response_type = "incidence"} (Hodges-Lehmann degenerates
#'   on binary data) and rejects censored survival data at construction; see
#'   the class-level documentation for recommended alternatives in both
#'   cases. Legal \code{response_type} values are \code{"continuous"},
#'   \code{"count"}, \code{"proportion"}, \code{"survival"} (uncensored
#'   only), and \code{"ordinal"}.
#' @param des_obj  A completed \code{DesignSeqOneByOne} object.
#' @param model_formula   Optional formula for covariate adjustment. If \code{NULL} (default),
#'   the formula from the design object is used and its pre-computed design matrix is
#'   reused. If a formula is provided, a new design matrix is constructed from the
#'   design's imputed covariates.
#' @param verbose      Whether to print progress messages. Default \code{FALSE}.
#' @param max_resample_attempts Maximum number of times a single bootstrap replicate
#'   may be redrawn when the drawn sample fails validity screening. If all attempts
#'   fail the replicate is recorded as \code{NA}, silently reducing the effective \code{B}.
#'   Must be a positive integer. Default \code{50L}.
#' @param smart_cold_start_default Flag for consistent API.
