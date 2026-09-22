#' @description Initialize KK inverse-variance combined Wilcoxon inference
#'   and prepare matched/reservoir rank-based components used by
#'   \code{\link[EDI:InferenceAllKKWilcoxIVWC]{InferenceAllKKWilcoxIVWC}}.
#'   Requires \code{des_obj} to be a KK matching-on-the-fly-capable design
#'   (\code{des_obj$is_a_kk_matching_capable()}); errors otherwise. Also
#'   rejects \code{response_type = "incidence"} (a message-and-error
#'   recommends a compound mean-difference or conditional-logistic estimator
#'   instead — rank-based methods are not well suited to binary outcomes)
#'   and rejects censored survival data (recommends a restricted-mean or
#'   Cox-based method instead, since this estimator has no censoring
#'   handling). Legal \code{response_type} values are \code{"continuous"},
#'   \code{"count"}, \code{"proportion"}, \code{"survival"} (uncensored
#'   only), and \code{"ordinal"}.
#' @param des_obj A DesignSeqOneByOne object (must be a KK design).
#' @param verbose Whether to print progress messages.
#' @param model_formula   Optional formula for covariate adjustment. If \code{NULL} (default),
#'   the formula from the design object is used and its pre-computed design matrix is
#'   reused. If a formula is provided, a new design matrix is constructed from the
#'   design's imputed covariates.
#' @param smart_cold_start_default   Whether to use smart cold start values.
