#' A Fixed Rerandomization Design (Rejection-Sampled on Covariate Balance)
#'
#' A fixed-sample-size \code{\link[EDI:DesignFixed]{DesignFixed}} implementing
#' rerandomization (Morgan and Rubin, 2012): candidate allocations \eqn{w} are drawn
#' from the design's base randomization law (balanced complete randomization when
#' \code{prob_T = 0.5}, i.i.d. \eqn{\mathrm{Bernoulli}(prob\_T)} draws otherwise — see
#' \code{generate_one_rerandomized_w()}) and only \strong{accepted} if a covariate
#' imbalance criterion \eqn{M(w)} between the treated and control groups falls below a
#' threshold \code{a} (\code{obj_val_cutoff}), i.e. the accepted allocations are drawn
#' from the base randomization distribution truncated to \eqn{\{w : M(w) \le a\}}.
#' Unlike \code{\link[EDI:DesignFixedGreedy]{DesignFixedGreedy}}/
#' \code{\link[EDI:DesignFixedGreedyDOptimal]{DesignFixedGreedyDOptimal}}, which \emph{search} for a
#' single well-balanced allocation, rerandomization instead \emph{filters} the design's
#' own randomization distribution, which is what makes it directly compatible with
#' Fisherian/randomization-based inference (the accepted allocations remain a
#' well-defined — if truncated — randomization distribution, valid for randomization
#' tests/CIs restricted to that truncated support).
#'
#' Two mutually exclusive acceptance modes are supported (specifying both errors):
#' \code{obj_val_cutoff} accepts/rejects each draw against a fixed threshold \code{a};
#' \code{prop_acceptable} instead draws \eqn{r / prop\_acceptable} candidates and keeps
#' the \eqn{r} with the \emph{lowest} \eqn{M(w)} (an empirical top-quantile acceptance
#' region, equivalent in the large-draw limit to an implied cutoff at the
#' \code{prop_acceptable} quantile of \eqn{M(w)}'s distribution under the base
#' randomization law).
#'
#' @details
#' \strong{Objective \eqn{M(w)}.} \code{objective = "mahal_dist"} (default) uses the
#' squared Mahalanobis distance between treated and control covariate means,
#' \eqn{M(w) = (\bar X_T - \bar X_C)^\top S^{-1} (\bar X_T - \bar X_C)}, where \eqn{S} is
#' the sample covariance of all covariates (ridge-regularized by \eqn{10^{-6}I} if
#' \eqn{|\det S| < 10^{-10}}), cached in \code{private$S_inv} and recomputed
#' whenever the covariate matrix changes (e.g. on a bootstrap-randomization replay).
#' \code{objective = "abs_sum_diff"} instead uses the sum of absolute mean differences,
#' \eqn{M(w) = \sum_j |\bar X_{T,j} - \bar X_{C,j}|}, with no correlation adjustment.
#' Only these two objectives are supported; any other value errors at draw time.
#'
#' \strong{Fast path (native C++).} When \code{prob_T = 0.5} and \eqn{n} is even,
#' candidate generation and filtering run via a parallel C++ rejection sampler
#' (\code{rerandomization_search_cpp()}), which internally works with a rescaled
#' objective \eqn{f_{\mathrm{cpp}}}: \eqn{f_{\mathrm{cpp}} = M(w)/4} for
#' \code{"mahal_dist"} and \eqn{f_{\mathrm{cpp}} = M(w)/2} (on a GED-standardized scale)
#' for \code{"abs_sum_diff"}; the user-facing \code{obj_val_cutoff} is converted to this
#' internal scale before being passed to C++, so the accepted-allocation semantics are
#' unaffected, but this rescaling is a backend implementation detail worth knowing when
#' comparing C++-path and pure-R-path acceptance rates for the same nominal cutoff. The
#' sampler draws up to \code{max(r * 1000, 100000)} candidates internally; if fewer than
#' \code{r} allocations are accepted within that budget (an overly tight cutoff), this
#' errors naming how many were actually found -- loosen \code{obj_val_cutoff} or use
#' \code{prop_acceptable} instead. (Earlier versions silently recycled the accepted set
#' to pad out to \code{r}, duplicating some draws; fixed, since that meant some
#' "independent" replicates were literal duplicates of an accepted allocation.)
#'
#' \strong{Seed reproducibility and multi-core parallelism.} The C++ fast path
#' derives each candidate's local RNG stream from its logical draw index, rather
#' than from the OpenMP worker evaluating it. It evaluates deterministic,
#' contiguous candidate blocks in fixed-size waves and returns accepted
#' allocations in draw-index order. Consequently, a fixed \code{seed} returns
#' the same allocations at every configured core count; adding cores changes
#' only which worker evaluates a candidate. The package default is one core,
#' but this reproducibility guarantee also holds after
#' \code{\link{set_num_cores}} or when using a fork cluster/mirai daemons.
#'
#' \strong{\code{prop_acceptable} path.} Uses
#' \code{complete_randomization_forced_balanced_cpp()} (balanced case) or
#' \code{complete_randomization_imbalanced_cpp()} (\code{prob_T != 0.5}) to draw
#' \eqn{n_{\mathrm{draw}} = \mathrm{round}(r / prop\_acceptable)} candidate allocations
#' in one batched call, computes \eqn{M(w)} for all of them via
#' \code{compute_objective_vals_cpp()}, and keeps the \eqn{r} with smallest \eqn{M(w)}.
#'
#' \strong{Pure-R fallback (unbalanced or odd \eqn{n}, \code{obj_val_cutoff} mode
#' only).} Draws candidates in vectorized batches (independent Bernoulli(\code{prob_T})
#' assignments, or a fixed-size random subset when \code{prob_T = 0.5} with odd \eqn{n}),
#' scores each batch at once, and keeps the first \eqn{r} candidates with
#' \eqn{M(w) \le a}. Candidates with an empty arm are rejected. Like the C++ fast path
#' it stops with an error after \code{max(1000 r, 1e5)} candidates if fewer than
#' \eqn{r} are acceptable.
#'
#' @references Morgan, K. L., and Rubin, D. B. (2012). "Rerandomization to improve
#'   covariate balance in experiments." \emph{The Annals of Statistics}, 40(2),
#'   1263-1282, \doi{10.1214/12-AOS1008}, for the rerandomization framework and its
#'   randomization-inference validity. See also
#'   \href{https://en.wikipedia.org/wiki/Mahalanobis_distance}{Mahalanobis distance} for
#'   the default objective.
#' @examples
#' des = DesignFixedRerandomization$new(n = 10, response_type = 'continuous')
#' @export
DesignFixedRerandomization = define_design_class(
	classname = "DesignFixedRerandomization",
	inherit = DesignFixed,
	components = character(),
	public = list(
		#' @description Initialize a rerandomization fixed experimental design.
		#'   Exactly one of \code{obj_val_cutoff}/\code{prop_acceptable} may be
		#'   specified (or neither, which accepts every candidate, i.e. no filtering);
		#'   supplying both raises an error. See class documentation for the exact
		#'   acceptance semantics of each mode and the covariate-imbalance objective.
		#'
		#' @param response_type 	The data type of response values.
		#' @param prob_T  The probability of the treatment assignment.
		#' @param obj_val_cutoff 	The maximum allowable objective value \eqn{a}; a candidate
		#'   allocation is accepted iff \eqn{M(w) \le a}. Cannot be specified together with prop_acceptable.
		#' @param prop_acceptable	The proportion of randomizations to accept (draws r/prop_acceptable total, returns r lowest). Cannot be specified together with obj_val_cutoff.
		#' @param objective 	The covariate-imbalance objective \eqn{M(w)} to filter on:
		#'   either \code{"mahal_dist"} (default, squared Mahalanobis distance) or
		#'   \code{"abs_sum_diff"} (sum of absolute mean differences); see class
		#'   documentation for the exact formulas.
		#' @param include_is_missing_as_a_new_feature  Flag for missingness indicators.
		#' @param n  		The sample size.
		#' @param verbose  Flag for verbosity.
		#' @param missingness_method How to handle missing values in covariates.
		#' @param design_formula A formula object.
		#' @param seed Integer seed for reproducibility.
		#'
		#' @return 			A new `DesignFixedRerandomization` object
		#'
		initialize = function(
				response_type,
				prob_T = 0.5,
				obj_val_cutoff = NULL,
				prop_acceptable = NULL,
				objective = "mahal_dist",
				include_is_missing_as_a_new_feature = TRUE,
				n = NULL,
				verbose = FALSE,
				missingness_method = "impute",
				design_formula = ~ .,
				seed = NULL
			) {
			if (!is.null(obj_val_cutoff) && !is.null(prop_acceptable)) {
				stop("Cannot specify both obj_val_cutoff and prop_acceptable.")
			}
			super$initialize(response_type, prob_T, include_is_missing_as_a_new_feature, n, verbose, missingness_method, design_formula, seed = seed)
			private$obj_val_cutoff = obj_val_cutoff
			private$prop_acceptable = prop_acceptable
			private$objective = objective
			private$uses_covariates = TRUE
			#note: we are not setting private$m as this is not a blocking design
		}
	),
	private = list(
		obj_val_cutoff = NULL,
		prop_acceptable = NULL,
		objective = NULL,
		S_inv = NULL,
		S_inv_source_X = NULL,
		draw_ws_raw = function(r = 100){
			private$maybe_set_seed()
			if (should_run_asserts()) {
				assertCount(r, positive = TRUE)
				self$assert_all_subjects_arrived()
			}
			n = self$get_n()
			private$ensure_model_matrix_current()
			if (is.null(private$X) || ncol(private$X) == 0){
				n_T = round(n * private$prob_T)
				return(replicate(r, sample(c(rep(1, n_T), rep(0, n - n_T)))))
			}
			# prop_acceptable path: draw r/prop_acceptable randomizations, return r with lowest obj vals
			if (!is.null(private$prop_acceptable)) {
				private$ensure_S_inv_current(n)
				X = private$X[1:n, , drop = FALSE]
				n_draw = round(r / private$prop_acceptable)
				ext_seed = if (!is.null(private$seed)) private$seed else sample.int(.Machine$integer.max, 1L)
				if (private$prob_T == 0.5) {
					indicTs = complete_randomization_forced_balanced_cpp(n, n_draw, ext_seed)
				} else {
					n_T = round(n * private$prob_T)
					indicTs = complete_randomization_imbalanced_cpp(n, n_T, n_draw, ext_seed)
				}
				obj_vals = compute_objective_vals_cpp(X, indicTs, private$objective, private$S_inv)
				ord = order(obj_vals)
				# indicTs is n_draw x n; subset rows for best r, then transpose to n x r
				w_mat = t(indicTs[ord[seq_len(r)], , drop = FALSE])
				storage.mode(w_mat) = "numeric"
				return(w_mat)
			}
			# C++ parallel rejection sampler for balanced even-n case
			if (private$prob_T == 0.5 && n %% 2 == 0) {
				X = private$X[1:n, , drop = FALSE]
				cutoff_user = if (is.null(private$obj_val_cutoff)) Inf else private$obj_val_cutoff
				# The C++ function uses the M-matrix objective which is scaled relative to the
				# user-facing objective: mahal_dist → f_cpp = user_mahal/4;
				# abs_sum_diff → f_cpp = GED-standardised/2.
				cutoff_scale = if (private$objective == "mahal_dist") 4.0 else 2.0
				cutoff_cpp   = if (is.infinite(cutoff_user)) Inf else cutoff_user / cutoff_scale
				max_draws = max(r * 1000L, 100000L)
				# Trusted unvalidated (fix_design_hierarchy.md, "AllocationMatrixValidation"):
				# rerandomization_search_cpp only ever generates balanced allocations by
				# construction and returns exactly n x k valid {0,1} columns (k <= r), so
				# the shape/finite/balance checks this class used to run were dead code
				# that never fired. The one real failure mode -- a cutoff tight enough
				# (or max_draws small enough) that fewer than r acceptable draws were
				# found -- now errors instead of silently recycling already-found columns
				# to pad out to r (which would have meant some "independent" replicates
				# were literal duplicates).
				w_mat = rerandomization_search_cpp(
					X_raw     = X,
					r         = as.integer(r),
					objective = private$objective,
					cutoff    = as.double(cutoff_cpp),
					max_draws = as.integer(max_draws)
				)
				if (ncol(w_mat) < r) {
					stop(
						"DesignFixedRerandomization could not find ", r, " acceptable allocation(s) ",
						"within max_draws = ", max_draws, " draws (only ", ncol(w_mat), " found). ",
						"Loosen obj_val_cutoff or increase r's underlying search budget."
					)
				}
				storage.mode(w_mat) = "numeric"
				return(w_mat[, seq_len(r), drop = FALSE])
			}
			# Fallback pure-R for unbalanced or odd-n cases
			private$ensure_S_inv_current(n)
			private$generate_rerandomized_w_batch(r)
		},
		# Bootstrap-randomization replay (2026-10-23, release_v1_0_5.md TODO-131):
		# a duplicated design whose X was replaced by a bootstrap resample kept the
		# ORIGINAL sample's cached S_inv, so the prop_acceptable and unbalanced/odd-n
		# paths scored candidates with a covariance the balanced C++ path (which
		# recomputes from X) does not use. Key the cache on the X it was built from.
		ensure_S_inv_current = function(n){
			if (private$objective != "mahal_dist") return(invisible(NULL))
			X = private$X[1:n, , drop = FALSE]
			if (!is.null(private$S_inv) && identical(private$S_inv_source_X, X)) return(invisible(NULL))
			S = var(X)
			if (abs(det(S)) < 1e-10){
				S = S + diag(1e-6, ncol(X))
			}
			private$S_inv = solve(S)
			private$S_inv_source_X = X
			invisible(NULL)
		},
		# Batched rejection sampler for the unbalanced / odd-n case (TODO-118). Same
		# candidate law as generate_one_rerandomized_w() (fixed n_T = round(n * prob_T)
		# shuffle when prob_T == 0.5, else independent Bernoulli(prob_T)), but candidates
		# are drawn and scored in vectorized batches, and the accepted columns are the
		# first r acceptable candidates in draw order. A candidate with an empty arm has
		# no defined objective and is rejected. Bounded like the C++ path: errors after
		# max(1000 * r, 1e5) candidates instead of looping forever.
		generate_rerandomized_w_batch = function(r){
			n = self$get_n()
			X = private$X[1:n, , drop = FALSE]
			p_T = private$prob_T
			n_T_fixed = round(n * p_T)
			cutoff = if (is.null(private$obj_val_cutoff)) Inf else private$obj_val_cutoff
			col_sums_X = colSums(X)
			max_cand = max(r * 1000, 1e5)
			batch = as.integer(min(max(2L * r, 512L), 20000L, max(1L, floor(2e7 / n))))
			accepted = vector("list", 0L)
			n_found = 0L
			n_tried = 0
			while (n_found < r && n_tried < max_cand){
				B = as.integer(min(batch, ceiling(max_cand - n_tried)))
				if (p_T == 0.5){
					# uniformly random subset of size n_T_fixed per column: rank of iid uniforms
					U = matrix(stats::runif(n * B), n, B)
					W = matrix(0, n, B)
					if (n_T_fixed > 0){
						ord = apply(U, 2L, order)
						idx = ord[seq_len(n_T_fixed), , drop = FALSE] + rep((seq_len(B) - 1L) * n, each = n_T_fixed)
						W[idx] = 1
					}
				} else {
					W = matrix(as.numeric(stats::runif(n * B) < p_T), n, B)
				}
				n_tried = n_tried + B
				nT = colSums(W)
				ok = nT >= 1 & nT <= n - 1
				sum_T = crossprod(X, W)
				diff = sweep(sum_T, 2L, pmax(nT, 1), "/") - sweep(col_sums_X - sum_T, 2L, pmax(n - nT, 1), "/")
				obj = if (private$objective == "mahal_dist"){
					colSums(diff * (private$S_inv %*% diff))
				} else if (private$objective == "abs_sum_diff"){
					colSums(abs(diff))
				} else {
					stop("Unsupported objective")
				}
				keep = which(ok & is.finite(obj) & obj <= cutoff)
				if (length(keep)){
					keep = utils::head(keep, r - n_found)
					accepted[[length(accepted) + 1L]] = W[, keep, drop = FALSE]
					n_found = n_found + length(keep)
				}
			}
			if (n_found < r){
				stop(
					"DesignFixedRerandomization could not find ", r, " acceptable allocation(s) ",
					"within ", format(max_cand, scientific = FALSE), " candidate draws (only ", n_found, " found). ",
					"Loosen obj_val_cutoff."
				)
			}
			do.call(cbind, accepted)
		},
		generate_one_rerandomized_w = function(){
			n = self$get_n()
			X = private$X[1:n, , drop = FALSE]
			n_T = round(n * private$prob_T)
			repeat {
				if (private$prob_T == 0.5){
					w_cand = sample(c(rep(1, n_T), rep(0, n - n_T)))
				} else {
					w_cand = rbinom(n, 1, private$prob_T)
				}
				obj_val = private$compute_obj(X, w_cand)
				if (is.null(private$obj_val_cutoff) || obj_val <= private$obj_val_cutoff){
					return(w_cand)
				}
			}
		},
		compute_obj = function(X, w){
			if (private$objective == "mahal_dist"){
				diff = colMeans(X[w == 1, , drop = FALSE]) - colMeans(X[w == 0, , drop = FALSE])
				return(as.numeric(diff %*% private$S_inv %*% diff))
			} else if (private$objective == "abs_sum_diff"){
				diff = colMeans(X[w == 1, , drop = FALSE]) - colMeans(X[w == 0, , drop = FALSE])
				return(sum(abs(diff)))
			}
			stop("Unsupported objective")
		}
	)
)
