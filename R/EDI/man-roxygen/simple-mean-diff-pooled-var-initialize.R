#' @description Initialize simple pooled-variance mean-difference inference
#'   for continuous responses and prepare the pooled standard-error
#'   calculation used by
#'   \code{\link[EDI:InferenceAllSimpleMeanDiffPooledVar]{InferenceAllSimpleMeanDiffPooledVar}}.
#'   Disables warm starts (closed-form estimator) and asserts
#'   \code{des_obj} has no censored observations (unsupported by this
#'   class).
#' @param des_obj A completed design object.
#' @param model_formula   Optional covariate formula. It is accepted for interface
#'   consistency but does not change the estimate or standard error, which use only
#'   the responses and treatment assignments (no covariate adjustment). If \code{NULL}
#'   (default), the formula from the design object is used.
#' @param verbose Whether to print progress messages.
#' @param smart_cold_start_default Whether to use smart cold start values.
#' @return A new \code{InferenceAllSimpleMeanDiffPooledVar} object.
