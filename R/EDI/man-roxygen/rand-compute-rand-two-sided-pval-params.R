#' @description Computes a randomization-based p-value.
#' @param r  	Number of randomization vectors.
#' @param delta  				Null difference.
#' @param transform_responses  Transformation.
#' @param na.rm 				Remove NAs.
#' @param show_progress  	Show progress.
#' @param permutations  	Pre-computed permutations.
#' @param zero_one_logit_clamp The clamping amount for exact 0 and 1 values when logging
#' @return 	Randomization p-value.
