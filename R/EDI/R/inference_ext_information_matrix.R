#' Extension for Information-Matrix Inference
#'
#' A Pattern-1 file-split extension (plain list with code{$public} and
#' code{$private} slots), spliced into exactly one class
#' (\code{InferenceAsympLik}) -- not a reusable mixin. Provides
#' information-source selection and treatment-coefficient standard errors for
#' likelihood-backed inference. Requires code{get_likelihood_test_spec()} and
#' code{get_default_information_source()} private methods, as well as
#' code{information_preference} and code{information_source_used} private
#' fields, all provided by the host class.
#'
#' Splice into \code{InferenceAsympLik} with
#' code{private = c(InferenceExtInformationMatrix$private, list(...))}.
#'
#' @keywords internal
#' @noRd
InferenceExtInformationMatrix = list(
	public = list(),
	private = list(
		get_information_matrix = function(spec = NULL, fit = NULL){
			if (is.null(spec)) {
				spec = private$get_likelihood_test_spec()
			}
			if (is.null(spec)) return(NULL)
			if (is.null(fit)) {
				fit = spec$full_fit %||% private$cached_mod
			}
			if (is.null(fit)) return(NULL)

			extract_fisher = function(){
				tryCatch({
					if (!is.null(spec$fisher_information)) {
						spec$fisher_information(fit)
					} else if (!is.null(fit$fisher_information)) {
						fit$fisher_information
					} else if (identical(fit$information_type %||% "", "fisher") && !is.null(fit$information)) {
						fit$information
					} else {
						NULL
					}
				}, error = function(e) NULL)
			}

			extract_observed = function(){
				tryCatch({
					if (!is.null(spec$observed_information)) {
						spec$observed_information(fit)
					} else if (!is.null(fit$observed_information)) {
						fit$observed_information
					} else if (identical(fit$information_type %||% "", "observed") && !is.null(fit$information)) {
						fit$information
					} else {
						NULL
					}
				}, error = function(e) NULL)
			}

			extract_legacy = function(){
				tryCatch({
					if (!is.null(spec$information)) {
						spec$information(fit)
					} else {
						fit$information
					}
				}, error = function(e) NULL)
			}

			preference = private$information_preference
			if (identical(preference, "auto")) {
				preference = private$get_default_information_source()
			}
			if (identical(preference, "fisher")) {
				information = extract_fisher()
				if (is.null(information)) {
					stop(class(self)[1], " does not expose Fisher information for information-backed inference.", call. = FALSE)
				}
				private$information_source_used = "fisher"
				return(information)
			}

			if (identical(preference, "observed")) {
				information = extract_observed()
				if (is.null(information)) {
					stop(class(self)[1], " does not expose observed information for information-backed inference.", call. = FALSE)
				}
				private$information_source_used = "observed"
				return(information)
			}

			information = extract_fisher()
			if (!is.null(information)) {
				private$information_source_used = "fisher"
				return(information)
			}
			information = extract_observed()
			if (!is.null(information)) {
				private$information_source_used = "observed"
				return(information)
			}
			information = extract_legacy()
			if (!is.null(information)) {
				private$information_source_used = "legacy"
			}
			information
		},

		compute_variance_from_information_matrix = function(information, j){
			information = as.matrix(information)
			if (!is.matrix(information) || nrow(information) != ncol(information) || length(j) != 1L ||
				!is.finite(j) || j < 1L || j > nrow(information)) {
				return(NA_real_)
			}
			if (nrow(information) == 1L) {
				val = as.numeric(information[1L, 1L])
				return(if (is.finite(val) && val > 0) 1 / val else NA_real_)
			}
			res = tryCatch(eigen_compute_single_entry_on_diagonal_of_inverse_matrix_cpp(information, as.integer(j)), error = function(e) NA_real_)
			if (is.finite(res) && res > 0) return(res)

			vcov = tryCatch(solve(information), error = function(e) NULL)
			if (is.null(vcov) || any(!is.finite(vcov))) {
				vcov = tryCatch(qr.solve(information, diag(nrow(information))), error = function(e) NULL)
			}
			if (is.null(vcov) || any(!is.finite(vcov))) return(NA_real_)
			vcov = (vcov + t(vcov)) / 2
			as.numeric(vcov[j, j])
		},

		compute_standard_error_from_information_matrix = function(spec = NULL, fit = NULL, j = NULL){
			if (is.null(spec)) {
				spec = private$get_likelihood_test_spec()
			}
			if (is.null(spec)) return(NA_real_)
			if (is.null(j)) {
				j = as.integer(spec$j)
			}
			information = tryCatch(private$get_information_matrix(spec = spec, fit = fit), error = function(e) NULL)
			if (is.null(information)) return(NA_real_)
			variance = private$compute_variance_from_information_matrix(information, j)
			if (is.finite(variance) && variance >= 0) sqrt(variance) else NA_real_
		},

		get_score_test_information_matrix = function(spec, fit){
			private$get_information_matrix(spec = spec, fit = fit)
		},

		# Pure-R ridge-regularized fallback for the score test's
		# nuisance-parameter Schur complement, used ONLY when
		# score_test_from_score_information_cpp() already returned a
		# non-finite p-value from the RAW information matrix (this
		# function never runs otherwise, so it cannot change any
		# currently-working score test's answer).
		#
		# Added 2026-09-07 for InferenceContinKKGLMM/InferenceCountKKGLMM:
		# their null-constrained refit's observed information is only
		# positive definite on a minority of replicates (confirmed
		# empirically: ~32% for the Gaussian LMM, near-identical for the
		# Poisson GLMM) because the random-intercept variance component
		# routinely sits near its lower boundary in small matched-pair
		# fits -- this is expected numerical behavior of the likelihood
		# surface there, not a sign the fit itself is bad (the SAME
		# model's unrestricted/Wald-path information is positive
		# definite ~100% of the time on the identical data). Before this
		# fallback, compute_score_two_sided_pval() returned NA on the
		# large majority of calls for these two classes, regardless of
		# whether the true null or a large true effect was being tested
		# (0% Type-I error AND 0% power -- a degenerate test, not merely
		# a miscalibrated one).
		#
		# This adds a small, escalating ridge to the nuisance-parameter
		# block's diagonal (relative to that block's own diagonal scale,
		# not an absolute constant) only until the Schur complement
		# becomes positive, then computes the same chi-square(1) score
		# statistic score[j]^2 / info_eff the C++ path would have. This
		# is a numerical-stability patch, not a validated alternative
		# test: the resulting p-value's exact calibration has not been
		# separately verified by simulation, so treat it as "an honest
		# answer instead of a guaranteed-NA" rather than "provably
		# well-calibrated." Kept generic (not class-specific) since the
		# same Schur-complement degeneracy is generic to any class whose
		# information matrix is evaluated at a null-constrained refit
		# near a variance-component boundary.
		score_test_with_ridge_fallback = function(score, information, j){
			information = tryCatch(as.matrix(information), error = function(e) NULL)
			if (is.null(information) || nrow(information) != ncol(information)) return(NA_real_)
			p = nrow(information)
			if (length(j) != 1L || !is.finite(j) || j < 1L || j > p) return(NA_real_)
			score_j = tryCatch(as.numeric(score)[j], error = function(e) NA_real_)
			if (!is.finite(score_j)) return(NA_real_)

			nuisance_idx = setdiff(seq_len(p), j)
			if (length(nuisance_idx) == 0L) {
				info_eff = as.numeric(information[j, j])
				if (!is.finite(info_eff) || info_eff <= 0) return(NA_real_)
			} else {
				I_nn = information[nuisance_idx, nuisance_idx, drop = FALSE]
				I_nj = information[nuisance_idx, j]
				I_jn = information[j, nuisance_idx]
				scale_ref = mean(abs(diag(I_nn)), na.rm = TRUE)
				if (!is.finite(scale_ref) || scale_ref <= 0) scale_ref = 1
				ridge_multipliers = c(1e-8, 1e-6, 1e-4, 1e-3, 1e-2, 1e-1, 1, 10)
				info_eff = NA_real_
				for (rm in ridge_multipliers) {
					I_nn_ridged = I_nn + diag(rm * scale_ref, nrow(I_nn))
					inv_nn = tryCatch(solve(I_nn_ridged), error = function(e) NULL)
					if (is.null(inv_nn) || any(!is.finite(inv_nn))) next
					candidate = as.numeric(information[j, j]) - as.numeric(I_jn %*% inv_nn %*% I_nj)
					if (is.finite(candidate) && candidate > 0) {
						info_eff = candidate
						break
					}
				}
				if (!is.finite(info_eff) || info_eff <= 0) return(NA_real_)
			}
			statistic = score_j^2 / info_eff
			if (!is.finite(statistic) || statistic < 0) return(NA_real_)
			stats::pchisq(statistic, df = 1, lower.tail = FALSE)
		}
	)
)
