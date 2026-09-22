#' @description Computes the randomization distribution of the treatment effect estimate under the sharp null.
#'
#' @param r  					Number of randomization vectors. Default 501.
#' @param delta  				The null difference. Default 0.
#' @param transform_responses  Type of transformation. Default "none".
#' @param show_progress  		Show progress bar. Default TRUE.
#' @param permutations  		Pre-computed permutations. Default NULL.
#' @param debug  				If \code{TRUE}, return a list with the distribution values and
#'   per-iteration diagnostics including error messages, warning messages, counts of each,
#'   and summary proportions for iterations with errors, warnings, and illegal (non-finite)
#'   values. Runs serially. Default \code{FALSE}.
#' @return 	When \code{debug = FALSE} (default), a numeric vector of length \code{r}. When
#'   \code{debug = TRUE}, a list with: \code{values}, \code{errors} (list of character
#'   vectors, one per iteration), \code{warnings} (list of character vectors, one per
#'   iteration), \code{num_errors}, \code{num_warnings},
#'   \code{prop_iterations_with_errors}, \code{prop_iterations_with_warnings}, and
#'   \code{prop_illegal_values}.
#' @param zero_one_logit_clamp The clamping amount for exact 0 and 1 values when logging
