#' @description Initialize a simple mean-difference inference object.
#' @param des_obj A DesignSeqOneByOne object whose entire n subjects are assigned
#'   and response y is recorded within.
#' @param model_formula   Optional formula for covariate adjustment. If \code{NULL} (default),
#'   the formula from the design object is used and its pre-computed design matrix is
#'   reused. If a formula is provided, a new design matrix is constructed from the
#'   design's imputed covariates.
#' @param verbose Whether to print progress messages. Default \code{FALSE}.
#' @param max_resample_attempts Maximum number of times a single bootstrap replicate
#'   may be redrawn when the drawn sample fails validity screening. If all attempts
#'   fail the replicate is recorded as \code{NA}, silently reducing the effective \code{B}.
#'   Must be a positive integer. Default \code{50L}.
#' @param smart_cold_start_default Whether to use smart cold start values.
