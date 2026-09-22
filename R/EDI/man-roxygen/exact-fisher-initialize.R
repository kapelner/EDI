#' @description Initialize exact Fisher inference for incidence outcomes.
#'   Requires an uncensored incidence response; the design's structure
#'   (unstructured, blocked, or matched) determines the stratification used
#'   at estimation time (see class documentation).
#' @param des_obj A completed design object.
#' @param model_formula   Optional formula for covariate adjustment. If \code{NULL} (default),
#'   the formula from the design object is used and its pre-computed design matrix is
#'   reused. If a formula is provided, a new design matrix is constructed from the
#'   design's imputed covariates.
#' @param verbose Whether to print progress messages.
#' @param smart_cold_start_default Whether to use smart cold start values by default.
#' @return A new \code{InferenceIncidExactFisher} object.
