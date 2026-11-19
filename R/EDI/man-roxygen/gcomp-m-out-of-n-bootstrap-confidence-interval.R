#' @description Computes an m-out-of-n bootstrap confidence interval for the treatment effect.
#' @param alpha Significance level. Default 0.05.
#' @param B Number of resamples.
#' @param m Resample size. See \code{InferenceNonParamBootstrap$compute_m_out_of_n_bootstrap_confidence_interval}.
#' @param type Confidence-interval type.
#' @param show_progress Whether to show a progress bar.
#' @param min_number_usable_samples Minimum number of finite resampled estimates required.
#' @param bootstrap_type Optional empirical-resampling scheme.
#' @param min_fraction_usable_samples Risk ratio only (ignored for the risk difference):
#'   minimum fraction of the \code{B} resamples that must be usable. A draw is unusable
#'   when it is degenerate (an arm with no events or only events, or a non-converged or
#'   separated logistic fit) or its fit fails. Below this fraction the method returns
#'   \code{NA} with a recorded reason and one \code{edi_procedure_na_warning}; otherwise it
#'   uses the usable draws only. Default 0.95. See \strong{Subsampling and
#'   m-out-of-n} in \code{\link[EDI:InferenceIncidGCompRiskRatio]{InferenceIncidGCompRiskRatio}}.
