#' @description Computes a PRW subsampling confidence interval for the treatment effect.
#' @param alpha Significance level. Default 0.05.
#' @param B Number of subsamples.
#' @param b Subsample size. See \code{InferenceNonParamBootstrap$compute_subsampling_confidence_interval}.
#' @param type Confidence-interval type.
#' @param show_progress Whether to show a progress bar.
#' @param min_number_usable_samples Minimum number of finite subsampled estimates required.
#' @param subsampling_type Optional empirical-resampling scheme.
#' @param min_fraction_usable_samples Risk ratio only (ignored for the risk difference):
#'   minimum fraction of the \code{B} subsamples that must be usable. A draw is unusable
#'   when it is degenerate (an arm with no events or only events, or a non-converged or
#'   separated logistic fit) or its fit fails. Below this fraction the method returns
#'   \code{NA} with a recorded reason and one \code{edi_procedure_na_warning}; otherwise it
#'   uses the usable draws only. Default 0.8, lower than the bootstrap's 0.95 because degenerate
#'   draws concentrate in the data sets with an extreme estimate (at 0.95 up to 29\% of small
#'   null data sets were \code{NA}). See \strong{Subsampling and
#'   m-out-of-n} in \code{\link[EDI:InferenceIncidGCompRiskRatio]{InferenceIncidGCompRiskRatio}}.
#' @param reimpute_missing_vals_each_resample Missing covariate values in the resamples: \code{FALSE}
#'   (default) keeps the design's original imputation in every resample; \code{TRUE} re-runs
#'   the missing-data step on each resample. See
#'   \code{InferenceNonParamBootstrap$compute_bootstrap_confidence_interval}.
