#' @description Initialize exact matched-pair binomial inference for
#'   incidence outcomes. Requires \code{des_obj} to be
#'   \code{DesignFixedBinaryMatch} or a KK matching-on-the-fly-capable
#'   design; errors otherwise. Requires an uncensored incidence response.
#' @param des_obj A completed design object.
#' @param model_formula   Optional formula for covariate adjustment. If \code{NULL} (default),
#'   the formula from the design object is used and its pre-computed design matrix is
#'   reused. If a formula is provided, a new design matrix is constructed from the
#'   design's imputed covariates.
#' @param verbose Whether to print progress messages.
#' @param smart_cold_start_default Whether to use smart cold start values by default.
#' @return A new \code{InferenceIncidExactBinomial} object.
