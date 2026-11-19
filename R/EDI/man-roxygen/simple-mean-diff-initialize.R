#' @description Initialize a simple mean-difference inference object.
#' @param des_obj A DesignSeqOneByOne object whose entire n subjects are assigned
#'   and response y is recorded within.
#' @param model_formula   Optional covariate formula. It is accepted for interface
#'   consistency but does not change the estimate or standard error, which use only
#'   the responses and treatment assignments (no covariate adjustment). If \code{NULL}
#'   (default), the formula from the design object is used.
#' @param verbose Whether to print progress messages. Default \code{FALSE}.
#' @param max_resample_attempts Maximum number of times a single bootstrap replicate
#'   may be redrawn when the drawn sample fails validity screening. If all attempts
#'   fail the replicate is recorded as \code{NA}, silently reducing the effective \code{B}.
#'   Must be a positive integer. Default \code{50L}.
#' @param smart_cold_start_default Whether to use smart cold start values.
