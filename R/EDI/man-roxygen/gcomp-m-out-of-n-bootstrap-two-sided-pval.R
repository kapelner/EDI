#' @description Computes an m-out-of-n bootstrap two-sided p-value for the treatment effect.
#' @param delta Null treatment effect. Defaults to 0 for RD and 1 for RR.
#' @param B Number of resamples.
#' @param m Resample size. See \code{InferenceNonParamBootstrap$compute_m_out_of_n_bootstrap_two_sided_pval}.
#' @param type P-value type.
#' @param show_progress Whether to show a progress bar.
#' @param min_number_usable_samples Minimum number of finite resampled estimates required.
#' @param bootstrap_type Optional empirical-resampling scheme.
#' @param min_fraction_usable_samples Risk ratio only (ignored for the risk difference):
#'   minimum fraction of the \code{B} resamples that must be usable. A draw is unusable
#'   when it is degenerate (an arm with no events or only events, or a non-converged or
#'   separated logistic fit) or its fit fails. Below this fraction the method returns
#'   \code{NA} with a recorded reason and one \code{edi_procedure_na_warning}; otherwise it
#'   uses the usable draws only. Default 0.8, lower than the bootstrap's 0.95 because degenerate
#'   draws concentrate in the data sets with an extreme estimate (at 0.95 up to 29\% of small
#'   null data sets were \code{NA}). See \strong{Subsampling and
#'   m-out-of-n} in \code{\link[EDI:InferenceIncidGCompRiskRatio]{InferenceIncidGCompRiskRatio}}.
