#' An Abstract Experimental Design
#'
#' @name Design
#' @description Internal method.
#' An abstract R6 Class encapsulating the data and functionality for an experimental design.
#' This class takes care of data storage and response handling.
#'
#' @details
#' Throughout the package, treatment assignment vectors \eqn{w} use the
#' \eqn{\{0, 1\}} encoding: \eqn{1} indicates a treated subject and \eqn{0}
#' a control subject.  All public methods that return or accept \eqn{w}
#' (e.g. \code{get_w()}, \code{draw_ws_according_to_design()}) use this
#' convention. A handful of variance estimators (e.g. \code{InferenceIncidCMH},
#' \code{InferenceIncidExtendedRobins}) recode to a signed \eqn{\{-1,+1\}}
#' contrast internally where their formulas require it; that recoding is
#' local to those classes and does not affect this public convention.
#'
#' @section Saving and loading:
#' \code{Design} (and its \code{DesignSeqOneByOne} subclasses) is the unit of
#' persistence for a trial. Persist a \code{des_obj} with base R's
#' \code{saveRDS()}/\code{readRDS()} -- there is no dedicated
#' \code{save_edi_design()}/\code{load_edi_design()} wrapper, and none is
#' planned: the audit behind this section found nothing that needs
#' transformation on load beyond what is documented here. \code{Inference*}
#' objects are disposable, cheaply reconstructed from a \code{Design} object
#' on demand (see each class's \code{$new()}), and must \strong{never} be
#' \code{saveRDS()}'d directly -- nothing currently prevents it (they
#' serialize "successfully" like any R6 object), but the result is a frozen
#' snapshot a user could easily mistake for something that stays live against
#' the design, and re-running inference from a reloaded \code{Design} is both
#' cheap and the only tested path.
#'
#' \strong{Worked example} (mirrors the round-trip tests in
#' \code{R/EDI/tests/testthat/test-save-load-design.R}):
#' \preformatted{
#' des_obj = DesignSeqOneByOneBernoulli$new(n = 20, response_type = "continuous")
#' for (i in 1:10) {
#'   des_obj$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
#'   des_obj$add_one_subject_response(i, y = rnorm(1))
#' }
#' saveRDS(des_obj, "trial.rds", version = 2)
#'
#' # ...new R session...
#' des_obj = readRDS("trial.rds")
#' for (i in 11:20) {
#'   des_obj$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
#'   des_obj$add_one_subject_response(i, y = rnorm(1))
#' }
#' inf_obj = InferenceContinOLS$new(des_obj) # reconstructed fresh, never persisted
#' inf_obj$compute_estimate()
#' }
#' Passing \code{version = 2} to \code{saveRDS()} is recommended, matching the
#' one existing internal precedent for RDS serialization in this package
#' (\code{SimulationFramework}'s replication cache); it is not required for a
#' same-R-version round trip.
#'
#' \strong{Version stamp.} Every \code{Design} object records the package
#' version it was constructed under (\code{get_edi_version_created()}). This
#' is stamped once at construction and is \emph{not} refreshed by
#' \code{readRDS()} -- it reflects the version that originally built the
#' object, not whatever version is currently loaded. The first "resume the
#' trial" call after a reload (\code{draw_ws_according_to_design()} for fixed
#' designs, \code{add_one_subject_to_experiment_and_assign()} for sequential
#' designs) compares the stamped version's major component against the
#' currently loaded package's major component and emits a one-time
#' \code{warning()} on a mismatch; minor/patch differences are silent, since
#' most field additions are additive under this class's
#' \code{lock_objects = FALSE} R6 fields and do not warrant nagging on every
#' routine upgrade. Objects saved before this field existed self-initialize
#' it to the currently loaded version the first time it is read, rather than
#' erroring on the missing field.
#'
#' \strong{RNG/reproducibility caveat.} \code{private$seed} is consumed only
#' once, inside \code{maybe_set_seed()} at construction time, and is
#' \emph{not} re-applied on \code{readRDS()}. Continuing to enroll subjects
#' after a reload therefore draws from whatever the global
#' \code{.Random.seed} happens to be in the new session, not a deterministic
#' continuation of the original stream. This is almost certainly the right
#' behavior for a real trial (bit-for-bit-reproducible continuation across a
#' process restart is not a property a production trial should have), but it
#' means a same-seed reload-and-continue is \emph{not} expected to reproduce
#' the same draws as an uninterrupted run with that seed -- do not rely on
#' that for testing.
#'
#' \strong{Known non-serializable case.} A \code{DesignFixedOptimal}
#' constructed with \code{objective = "custom"} from a raw
#' \code{RcppXPtrUtils::cppXPtr()} external pointer (rather than a C++ source
#' string) cannot be safely reloaded: compiled function pointers do not
#' survive a \code{saveRDS()}/\code{readRDS()} round trip, and there is no
#' retained source to recompile from. This is detected on first use after
#' reload and raises a clear error rather than failing silently; supply
#' \code{custom_objective} as a C++ source string instead of a pre-built
#' \code{cppXPtr()} object if you need this design to survive a save/reload
#' cycle -- that form recompiles itself automatically the first time it is
#' used post-reload. Every other audited private cache on \code{Design} and
#' its components (\code{all_subject_data_cache}, \code{permutations_cache},
#' \code{lin_centered_covariates}, matching/blocking/cluster component state
#' such as \code{m}, \code{xm_structural}, \code{boot_pair_rows}) was traced
#' to its originating C++ return type and confirmed to hold only plain
#' R matrices/vectors/lists, not external pointers or other
#' non-serializable values.
#'
#' @keywords internal
#' @examples
#' \dontrun{
#' # Design is abstract and cannot be instantiated directly; construct a
#' # concrete subclass instead, e.g.:
#' seq_des = DesignSeqOneByOneBernoulli$new(n = 6, response_type = 'continuous')
#' seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
#' }
Design = R6::R6Class("Design",
	lock_objects = FALSE,
	public = list(
		#' @description Check whether this design currently has blocking structure.
		#'
		#' The base implementation returns \code{FALSE}. Designs that compose
		#' \code{BlockingStructure} override this method with the structural check.
		#' @return \code{FALSE} for designs without \code{BlockingStructure}.
		is_blocking_design = function() FALSE,
		#' @description Check whether this design currently has matching structure.
		#'
		#' The base implementation returns \code{FALSE}. Designs that compose
		#' \code{MatchingStructure} override this method with the structural check.
		#' @return \code{FALSE} for designs without \code{MatchingStructure}.
		is_matching_design = function() FALSE,
		#' @description Characterization: is this a KK matching-on-the-fly-capable
		#'   design (sequential KK or its fixed binary-match equivalent)? Default
		#'   \code{FALSE}; overridden to \code{TRUE} on
		#'   \code{DesignSeqOneByOneKK14} and \code{DesignFixedBinaryMatch}.
		is_a_kk_matching_capable = function() FALSE,
		#' @description Characterization: is this a cluster-structured design?
		#'   Default \code{FALSE}; overridden to \code{TRUE} on
		#'   \code{DesignFixedCluster} and \code{DesignFixedBlockedCluster}.
		is_a_cluster_capable = function() FALSE,
		#' @description Characterization: is this a Bernoulli-randomized design?
		#'   Default \code{FALSE}; overridden to \code{TRUE} on
		#'   \code{DesignSeqOneByOneBernoulli} and \code{DesignFixedBernoulli}.
		is_a_bernoulli_capable = function() FALSE,
		#' @description Initialize an experimental design
		#'
		#' @param response_type   "continuous", "incidence", "proportion", "count", "survival", or
		#'   "ordinal".
		#' @param prob_T    Probability of treatment assignment.
		#' @param include_is_missing_as_a_new_feature    Flag for missingness indicators.
		#' @param n            The sample size (if fixed).
		#' @param verbose    Flag for verbosity.
		#' @param missingness_method How to handle missing values in covariates when building the
		#'   model matrix for inference. One of:
		#'   \describe{
		#'     \item{\code{"impute"} (default)}{Missing values are filled in using random-forest
		#'       imputation (\code{missRanger}, falling back to \code{missForest} on failure).
		#'       The response vector is included as an auxiliary predictor when available.
		#'       This preserves all covariates and all subjects but introduces imputed values
		#'       that influence inference.}
		#'     \item{\code{"drop_column"}}{Any covariate column that contains at least one
		#'       missing value is dropped entirely from the model matrix before inference.
		#'       No values are invented; the remaining complete columns are used as-is.
		#'       This is conservative but transparent.}
		#'     \item{\code{"error"}}{An error is thrown as soon as any missing value is
		#'       detected in the covariate matrix. Use this when you want to guarantee that
		#'       inference runs on exactly the data you supplied, with no silent modification.}
		#'   }
		#' @param design_formula A formula object used to create the design matrix from
		#'   covariates. Default is \code{~ .}.
		#' @param ordinal_levels If the response type is "ordinal", the labels for the levels.
		#' @param seed Integer seed for reproducibility.
		#'
		#' @return 			A new `Design` object
		initialize = function(
				response_type,
				prob_T = 0.5,
				include_is_missing_as_a_new_feature = FALSE,
				n = NULL,
				verbose = FALSE,
				missingness_method = "impute",
				design_formula = ~ .,
				ordinal_levels = NULL,
				seed = NULL
			) {
			leaf_class = class(self)[1L]
			if (is_design_class_abstract(leaf_class)) {
				stop(
					leaf_class, " is an abstract Design base class and cannot be instantiated directly. ",
					"Use a concrete subclass instead.",
					call. = FALSE
				)
			}
			if (should_run_asserts()) {
				assertChoice(response_type, c("continuous", "incidence", "proportion", "count", "survival", "ordinal"))
				assertNumeric(prob_T, lower = .Machine$double.eps, upper = 1 - .Machine$double.eps)
				assertFlag(include_is_missing_as_a_new_feature)
				assertFlag(verbose)
				assertCount(n, null.ok = TRUE)
				assertCount(seed, null.ok = TRUE)
				assertChoice(missingness_method, c("impute", "drop_column", "error"))
				assertFormula(design_formula)
				if (response_type == "ordinal" && !is.null(ordinal_levels)) {
					assertCharacter(ordinal_levels, min.len = 2, any.missing = FALSE)
				}
			}
			if (is.null(n)){
				private$fixed_sample = FALSE
			} else {
				n = as.integer(n)
				private$n = n
				private$fixed_sample = TRUE
			}
			private$prob_T = prob_T
			private$response_type = response_type
			private$response_type_original = response_type
			private$ordinal_levels = ordinal_levels
			private$original_ordinal_levels = ordinal_levels
			private$include_is_missing_as_a_new_feature = include_is_missing_as_a_new_feature
			private$missingness_method = missingness_method
			private$design_formula = design_formula
			# Ensure budget is respected among openmp and other packages
			private$verbose = verbose
			if (private$fixed_sample){
				private$y = 	     rep(NA_real_, n)
				private$y_original = rep(NA_real_, n)
				private$w = 	     rep(NA_real_, n)
				private$y_L =        rep(NA_real_, n)
				private$y_R =        rep(NA_real_, n)
			}
			if (private$verbose){
				cat(paste0("Initialized a ",
				class(self)[1],
				" experiment with response type ",
				response_type,
				" and ",
				ifelse(private$fixed_sample, "fixed sample", "not fixed sample"),
				 ".\n"))
			}
			private$seed = seed
			private$edi_version_created = as.character(utils::packageVersion("EDI"))
		},
		#' @description For CARA designs, add a single subject response.
		#'
		#' @param t The subject index.
		#' @param y The exact response value. Supply this XOR both \code{y_L}
		#'   and \code{y_R} -- never together, never just one of the two.
		#' @param y_L For a censored survival response, the lower bound of the
		#'   event-time interval. Right-censored: the last known event-free
		#'   time (pair with \code{y_R = Inf}). Left-censored: \code{0},
		#'   which must be stated explicitly rather than defaulted.
		#'   Interval-censored: the interval's lower bound. Storage accepts
		#'   any well-formed left-/interval-censored value; whether a given
		#'   \code{Inference} class can actually consume it depends on that
		#'   class (most survival \code{Inference} classes still only accept
		#'   exact/right-censored data and will reject construction with a
		#'   clear error otherwise -- see individual class docs).
		#' @param y_R For a censored survival response, the upper bound of the
		#'   event-time interval. Right-censored: \code{Inf}. Left-/
		#'   interval-censored: the confirmed-by time / interval upper bound.
		add_one_subject_response = function(t, y = NULL, y_L = NULL, y_R = NULL) {
			if (should_run_asserts()) {
				assertNumeric(t, len = 1)
				assertCount(t, positive = TRUE)
				if (t > private$t){
					stop(paste("You cannot add response for subject", t, "when the most recent subjects' record added is", private$t))
				}
				assertNumeric(y, len = 1, null.ok = TRUE)
				assertNumeric(y_L, len = 1, null.ok = TRUE)
				assertNumeric(y_R, len = 1, null.ok = TRUE)
			}
			has_y = !is.null(y)
			has_bounds = !is.null(y_L) && !is.null(y_R)
			# Always enforced, never gated behind should_run_asserts(): unlike
			# the type/range checks above (which fail loud-but-cheaply-skippable
			# when disabled), a left-/interval-censored row that slips past this
			# gate is stored silently and later misread by get_effective_time()/
			# get_effective_dead() as ordinary right-censoring -- silently wrong
			# numbers, not a cryptic error -- so this must hold even with
			# assertions off (e.g. SimulationFramework's default
			# turn_off_asserts_for_speed = TRUE). See TODO-1a/TODO-2 in
			# interval_censored_survival_response.md.
			if (!is.null(y_L) && is.null(y_R)){
				stop("y_L was supplied without y_R -- both bounds are required together for a censored response.")
			}
			if (is.null(y_L) && !is.null(y_R)){
				stop("y_R was supplied without y_L -- both bounds are required together for a censored response.")
			}
			if (has_y && has_bounds){
				stop("Supply either y (exact response) or both y_L and y_R (censored response), not both.")
			}
			if (!has_y && !has_bounds){
				stop("You must supply either y (exact response) or both y_L and y_R (censored response).")
			}
			if (has_bounds && private$response_type != "survival"){
				stop("censored observations are only available for survival response types")
			}
			if (length(private$y) >= t & !(is.na(private$y[t]) && is.na(private$y_L[t]) && is.na(private$y_R[t]))){
				warning(paste("Overwriting previous response for t =", t))
			}
			if (has_y){
				if (private$response_type == "ordinal" && is.factor(y)){
					if (should_run_asserts()) {
						assertFactor(y, ordered = TRUE, any.missing = FALSE)
					}
					levs = levels(y)
					private$ordinal_levels = levs
					if (private$response_type_original == "ordinal" && is.null(private$original_ordinal_levels)){
						private$original_ordinal_levels = levs
					}
					y = as.integer(y)
				}
				private$assert_y(y, private$response_type)
				if (private$response_type == "survival" && y == 0){
					warning("0 survival responses not allowed --- recording .Machine$double.eps as its value instead")
					y = .Machine$double.eps
				}
			} else {
				# Always enforced -- see the note above add_one_subject_response's
				# earlier shape checks.
				if (!is.finite(y_L) || y_L < 0){
					stop("y_L must be finite and >= 0.")
				}
				if (!(y_R > y_L)){
					stop("y_R must be strictly greater than y_L.")
				}
			}
			if (private$fixed_sample | t <= length(private$y)){
				private$y[t] = if (has_y) y else NA_real_
				private$y_original[t] = if (has_y) y else NA_real_
				private$y_L[t] = if (has_y) NA_real_ else y_L
				private$y_R[t] = if (has_y) NA_real_ else y_R
			} else if (t == length(private$y) + 1){
				private$y = c(private$y, if (has_y) y else NA_real_)
				private$y_original = c(private$y_original, if (has_y) y else NA_real_)
				private$y_L = c(private$y_L, if (has_y) NA_real_ else y_L)
				private$y_R = c(private$y_R, if (has_y) NA_real_ else y_R)
			} else {
				if (should_run_asserts()) {
					stop("You cannot add a response for a subject that has not yet arrived when the sample size is not fixed in advance.")
				}
			}
			private$y_i_t_i[[t]] = private$t
		},
		#' @description For non-CARA designs, add all subject responses.
		#'
		#' @param ys The exact responses as a numeric vector, \code{NA} for any
		#'   subject whose response is censored (supply \code{y_Ls}/\code{y_Rs}
		#'   for those instead).
		#' @param y_Ls The censored-response lower bounds, \code{NA} for any
		#'   subject with an exact response in \code{ys}. Right-censored:
		#'   the last known event-free time (pair with \code{y_Rs = Inf}).
		#'   Left-censored: \code{0}, stated explicitly. Interval-censored:
		#'   the interval's lower bound. Storage accepts any well-formed
		#'   left-/interval-censored value; whether a given \code{Inference}
		#'   class can actually consume it depends on that class (most
		#'   survival \code{Inference} classes still only accept exact/
		#'   right-censored data and will reject construction with a clear
		#'   error otherwise -- see individual class docs).
		#' @param y_Rs The censored-response upper bounds, \code{NA} for any
		#'   subject with an exact response in \code{ys}. Right-censored:
		#'   \code{Inf}. Left-/interval-censored: the confirmed-by time /
		#'   interval upper bound.
		add_all_subject_responses = function(ys = NULL, y_Ls = NULL, y_Rs = NULL) {
			if (is.null(ys)) ys = rep(NA_real_, private$t)
			if (is.null(y_Ls)) y_Ls = rep(NA_real_, private$t)
			if (is.null(y_Rs)) y_Rs = rep(NA_real_, private$t)
			if (should_run_asserts()) {
				if (private$response_type == "ordinal" && is.factor(ys)){
					assertFactor(ys, len = private$t, ordered = TRUE, any.missing = FALSE)
				} else {
					assertNumeric(ys, len = private$t)
				}
				assertNumeric(y_Ls, len = private$t)
				assertNumeric(y_Rs, len = private$t)
			}
			has_y = if (is.factor(ys)) !is.na(as.integer(ys)) else !is.na(ys)
			has_bounds = !is.na(y_Ls) & !is.na(y_Rs)
			# Always enforced, never gated behind should_run_asserts() -- see the
			# note above add_one_subject_response's equivalent checks: a left-/
			# interval-censored row that slips past this gate is stored silently
			# and later misread by get_effective_time()/get_effective_dead() as
			# ordinary right-censoring, not a cryptic error.
			partial_bounds = xor(is.na(y_Ls), is.na(y_Rs))
			if (any(partial_bounds)){
				stop("y_Ls and y_Rs must be supplied together (both or neither) for every subject.")
			}
			if (any(has_y & has_bounds)){
				stop("Supply either ys or (y_Ls, y_Rs) for each subject, not both.")
			}
			if (any(!has_y & !has_bounds)){
				stop("Each subject needs either ys or both y_Ls and y_Rs.")
			}
			if (any(has_bounds) && private$response_type != "survival"){
				stop("censored observations are only available for survival response types")
			}
			if (any(has_bounds)){
				if (any(!is.finite(y_Ls[has_bounds]) | y_Ls[has_bounds] < 0)){
					stop("y_L must be finite and >= 0 for every censored subject.")
				}
				if (any(!(y_Rs[has_bounds] > y_Ls[has_bounds]))){
					stop("y_R must be strictly greater than y_L for every censored subject.")
				}
			}
			if (should_run_asserts()) {
				private$assert_y(ys[has_y], private$response_type)
			}

			if (private$response_type == "ordinal" && is.factor(ys)){
				levs = levels(ys)
				private$ordinal_levels = levs
				if (private$response_type_original == "ordinal" && is.null(private$original_ordinal_levels)){
					private$original_ordinal_levels = levs
				}
				ys = as.integer(ys)
			}
			private$y = as.numeric(ys)
			private$y_original = as.numeric(ys)
			private$y_L = as.numeric(y_Ls)
			private$y_R = as.numeric(y_Rs)
			private$y_i_t_i = as.list(seq_len(private$t))
		},
		#' @description For analysis on already-completed experimental data
		#'
		#' @param w A \{0,1\} vector of subject assignments (1 = treated, 0 = control).
		overwrite_all_subject_assignments = function(w) {
			if (should_run_asserts()) {
				assertIntegerish(w, lower = 0, upper = 1, any.missing = FALSE, len = private$t)
				if (any(!(w %in% c(0L, 1L)))) {
					stop("overwrite_all_subject_assignments: w must contain only 0 (control) or 1 (treated).")
				}
			}
			private$w = as.numeric(w)
		},
		#' @description Check if this design was initialized with a fixed sample size n
		#'
		#' @return TRUE if fixed.
		is_fixed_sample_size = function(){
			private$fixed_sample
		},
		#' @description Asserts if all subjects arrived.
		assert_all_subjects_arrived = function(){
			if (should_run_asserts()) {
				if (private$fixed_sample & private$t < private$n){
					stop("This experiment is incomplete as all n subjects haven't arrived yet.")
				}
			}
		},
		#' @description Asserts if all responses are recorded.
		assert_all_responses_recorded = function(){
			if (should_run_asserts()) {
				self$assert_all_subjects_arrived()
				if (sum(!(is.na(private$y) & is.na(private$y_L) & is.na(private$y_R))) != length(private$w)){
					stop("This experiment is incomplete as all responses aren't recorded yet.")
				}
			}
		},
		#' @description Checks if the experiment is completed.
		#'
		#' @return  \code{TRUE} if experiment is complete, \code{FALSE} otherwise.
		check_experiment_completed = function(){
			if (private$fixed_sample & private$t < private$n){
				FALSE
			} else if (sum(!(is.na(private$y) & is.na(private$y_L) & is.na(private$y_R))) != length(private$w)){
				FALSE
			} else {
				TRUE
			}
		},
		#' @description Checks if the experiment has a 50-50 allocation.
		assert_even_allocation = function(){
			if (should_run_asserts()) {
				if (private$prob_T != 0.5){
					stop("This type of design currently only works with even treatment allocation, i.e. you must set prob_T = 0.5 upon initialization")
				}
			}
		},
		#' @description Checks if the experiment has a fixed sample size.
		assert_fixed_sample = function(){
			if (should_run_asserts()) {
				if (!private$fixed_sample){
					stop("This type of design currently only works with fixed sample, i.e., you must specify n upon initialization")
				}
			}
		},
		#' @description Checks if the experiment has any censored responses
		#'
		#' @return  \code{TRUE} if any censored.
		any_censoring = function(){
			any(is.na(private$y))
		},
		#' @description Checks if the experiment has any left- or
		#'   interval-censored survival responses -- i.e. any subject whose
		#'   \code{y_R} is finite (right-censored subjects have
		#'   \code{y_R = Inf}, which is excluded). Most survival
		#'   \code{Inference} classes cannot yet consume this shape of data
		#'   (see \code{get_effective_time()}/\code{get_effective_dead()});
		#'   this is the check \code{Inference$initialize()} uses to reject
		#'   construction cleanly for those classes.
		#'
		#' @return  \code{TRUE} if any subject is left- or interval-censored.
		has_general_censoring = function(){
			any(is.finite(private$y_R))
		},
		#' @description Get t
		#'
		#' @return 			The current number of subjects.
		get_t = function(){
			private$t
		},
		#' @description Get raw X information
		#'
		#' @return 			A data frame of subject data.
		get_X_raw = function(){
			private$Xraw
		},
		#' @description Get imputed X information
		#'
		#' @return 		Same as \code{Xraw} except with imputations.
		get_X_imp = function(){
			private$Ximp
		},
		#' @description Get X matrix
		#'
		#' @return 			A numeric matrix of subject data.
		get_X = function(){
			private$X
		},
		#' @description Get y
		#'
		#' @return 			A numeric vector of subject responses.
		get_y = function(){
			private$y
		},
		#' @description Get y_original
		#'
		#' @return 			A numeric vector of the original subject responses.
		get_y_original = function(){
			private$y_original
		},
		#' @description Get w
		#'
		#' @return 			A \{0,1\} vector of subject assignments (1 = treated, 0 = control).
		get_w = function(){
			private$w
		},
		#' @description Draw treatment assignment vectors according to the design.
		#'
		#' @param r Number of vectors to draw. Default is 1.
		#' @return A matrix of size n x r with \{0,1\} entries (1 = treated, 0 = control).
		draw_ws_according_to_design = function(r = 1L){
			private$check_version_compat()
			private$draw_ws_raw(r)
		},
		#' @description Returns the capabilities this design \strong{instance} exposes
		#'   (see \code{fix_design_hierarchy.md}, "Capability Model").
		#'
		#'   Deliberately instance-level, not a class-registry read (fix_design_hierarchy.md,
		#'   TODO-28): \code{is_blocking_design()}/\code{is_matching_design()} depend on
		#'   real construction-time state (e.g. \code{private$m}/\code{private$blocking_capable}),
		#'   not just which components a class composes -- \code{DesignFixediBCRD}
		#'   constructed with an unknown \code{n}, for instance, composes
		#'   \code{BlockingStructure} but is \emph{not} blocking-capable for that particular
		#'   instance. A class-registry-only answer (this function briefly unioned in
		#'   \code{get_effective_design_capabilities()}, a purely class-level, component-
		#'   composition-based check) would silently report "blocking" for every instance
		#'   of such a class regardless of its actual construction state -- confirmed as a
		#'   real, reproducible false positive during this TODO's implementation, not a
		#'   hypothetical. \code{get_effective_design_capabilities()}/
		#'   \code{design_class_registry.R}'s \code{direct_components} still exist and are
		#'   correct -- they're the right tool for a \strong{generator}-only query with no
		#'   instance in hand (see \code{design_class_generator_supports_batch_w_pregeneration()}),
		#'   just not for this instance-level method.
		#' @return A character vector of capability names.
		capabilities = function(){
			caps = character()
			if (isTRUE(tryCatch(self$is_blocking_design(), error = function(e) FALSE))) {
				caps = c(caps, "blocking")
			}
			if (isTRUE(tryCatch(self$is_matching_design(), error = function(e) FALSE))) {
				caps = c(caps, "matching")
			}
			if (isTRUE(tryCatch(self$is_a_cluster_capable(), error = function(e) FALSE))) {
				caps = c(caps, "cluster")
			}
			if (isTRUE(tryCatch(self$supports_batch_w_pregeneration(), error = function(e) FALSE))) {
				caps = c(caps, "batch_w_pregeneration")
			}
			if (isTRUE(tryCatch(self$supports_resampling(), error = function(e) FALSE))) {
				caps = c(caps, "resampling")
			}
			if (isTRUE(tryCatch(self$supports_randomization_draw(), error = function(e) FALSE))) {
				caps = c(caps, "randomization_draw")
			}
			if (isTRUE(tryCatch(self$supports_resampling_replay(), error = function(e) FALSE))) {
				caps = c(caps, "resampling_replay")
			}
			unique(caps)
		},
		#' @description Returns whether this design object supports a capability.
		#'   See \code{capabilities()}.
		#' @param capability A capability name, e.g. \code{"blocking"},
		#'   \code{"matching"}, or \code{"batch_w_pregeneration"}.
		#' @return \code{TRUE} if the capability is present, \code{FALSE} otherwise.
		supports = function(capability){
			capability %in% self$capabilities()
		},
		#' @description Returns the sorted character vector of concrete, exported
		#'   \code{Inference} class names legal for this design object under
		#'   default constructor arguments, derived purely from this design's own
		#'   normalized metadata (response type, KK-matching capability, blocking,
		#'   and both censoring axes) filtered through the registry's
		#'   compatibility predicates -- the same normalization and predicate
		#'   logic \code{\link[EDI:InferenceSuite]{InferenceSuite}} uses for
		#'   discovery (see \code{normalize_inference_design_metadata()} and
		#'   \code{is_inference_class_compatible_with_design_metadata()} in
		#'   \code{inference_suite.R}). No candidate class is constructed to
		#'   determine applicability, so this has no side effects and cannot be
		#'   influenced by a constructor failure or a missing optional package
		#'   (see \code{unavailable_inference_classes_due_to_missing_packages()}
		#'   for that case, reported separately). A class whose censoring
		#'   tolerance depends on non-default constructor arguments (e.g.
		#'   \code{InferenceSurvivalCoxPHRegr} only tolerates general censoring
		#'   with \code{testing_type = "wald"}) is listed here when its
		#'   \strong{default} configuration is compatible; a construction-time
		#'   error for an incompatible non-default argument combination remains
		#'   the documented behavior of that class's \code{initialize()}.
		#' @return A sorted character vector of applicable \code{Inference} class
		#'   names.
		applicable_inference_class_names = function(){
			applicable_inference_class_names_for_design(self)
		},
		#' @description Companion to \code{applicable_inference_class_names()}:
		#'   returns the subset of otherwise design-compatible \code{Inference}
		#'   classes that are excluded solely because a registered
		#'   \code{required_packages} entry is not installed, as a named list
		#'   (class name -> character vector of missing package names) -- kept
		#'   separate from plain design incompatibility so callers can tell "not
		#'   applicable to this design" apart from "applicable, but an optional
		#'   dependency isn't installed."
		#' @return A named list, class name -> missing package names; empty list
		#'   if none.
		unavailable_inference_classes_due_to_missing_packages = function(){
			unavailable_inference_classes_due_to_missing_packages_for_design(self)
		},
		#' @description Companion to \code{applicable_inference_class_names()}:
		#'   returns the subset of otherwise design-compatible \code{Inference}
		#'   classes that are excluded because they declared a
		#'   \code{design_compatibility_reason} predicate (a design-*structure*
		#'   requirement, e.g. even treatment allocation or equal block sizes,
		#'   beyond what response type/KK/blocking/censoring metadata alone can
		#'   express) and this design object fails it, as a named list (class
		#'   name -> one-line reason string) -- kept separate from plain design
		#'   incompatibility and from a missing package for the same reason
		#'   \code{unavailable_inference_classes_due_to_missing_packages()} is
		#'   kept separate: so callers can tell exactly why a class is missing
		#'   from \code{applicable_inference_class_names()} instead of only
		#'   discovering it as a construction-time error.
		#' @return A named list, class name -> reason string; empty list if none.
		incompatible_inference_classes_due_to_design_structure = function(){
			incompatible_inference_classes_due_to_design_structure_for_design(self)
		},
		#' @description Returns this design object's registry-backed randomization
		#'   family (see \code{fix_design_hierarchy.md}, "Class Metadata"), e.g.
		#'   \code{"kk14"}, \code{"bernoulli"}, \code{"rerandomization"}. Replaces
		#'   class-identity (\code{inherits()}/\code{is()}) dispatch at call sites that
		#'   need to distinguish design variants (see "Class-Identity Dispatch
		#'   Replacement"). Returns \code{NA_character_} if the class is not registered
		#'   or is one of the unsplit/timing-root abstract bases.
		#' @return A single character string (or \code{NA_character_}).
		randomization_family = function(){
			class_name = class(self)[1L]
			tryCatch(get_design_class_metadata(class_name)$randomization_family, error = function(e) NA_character_)
		},
		#' @description Check if the design supports resampling at all -- \code{FALSE}
		#'   only for the abstract timing-family bases themselves (\code{DesignFixed},
		#'   \code{DesignSeqOneByOne}, and their custom-extension abstract bases)
		#'   instantiated directly; \code{TRUE} for every concrete subclass,
		#'   \strong{including} \code{ObservationalDesign}. This is the general check
		#'   for resampling methods that never need the design's own randomization
		#'   mechanism -- plain nonparametric bootstrap, Bayesian bootstrap,
		#'   m-out-of-n bootstrap, PRW subsampling -- which only resample already-observed
		#'   units/rows and their fixed, observed assignment, so they remain valid and
		#'   available even for a design with no randomization mechanism at all (see
		#'   \code{ObservationalDesign}'s class documentation: "resampling subjects with
		#'   their observed, fixed assignment does not require a known randomization
		#'   probability"). Contrast with \code{supports_randomization_draw()}/
		#'   \code{supports_resampling_replay()} below, which gate the narrower set of
		#'   methods that actually do need to invoke the design's mechanism (a plain
		#'   randomization test/CI, or a bootstrap randomization test that re-randomizes
		#'   resampled data) and are therefore \code{FALSE} for \code{ObservationalDesign}
		#'   specifically -- see \code{fix_design_hierarchy.md}, "Observational Design
		#'   Migration" for the live bug that split fixes.
		#'
		#' @return 	TRUE if supported.
		supports_resampling = function(){
			private$supports_resampling_by_registry_abstract_check()
		},
		#' @description Check if this design can draw a fresh treatment assignment
		#'   from its own randomization mechanism -- the eligibility condition for
		#'   permutation-style randomization tests/CIs (\code{compute_rand_two_sided_pval()}
		#'   and friends), which redraw \eqn{w} directly. \code{FALSE} for the abstract
		#'   timing-family bases themselves (same as \code{supports_resampling()}) and,
		#'   unlike \code{supports_resampling()}, also \code{FALSE} for
		#'   \code{ObservationalDesign} (no draw mechanism at all -- \eqn{w} is supplied
		#'   by the user, so there is nothing to redraw); \code{TRUE} for every other
		#'   concrete subclass. See \code{supports_resampling()}'s documentation for why
		#'   this is a narrower, separate capability rather than reusing that one, and
		#'   "Observational Design Migration" for the live bug this fixes
		#'   (\code{ObservationalDesign} previously answered the old, unsplit
		#'   \code{supports_resampling()} \code{TRUE}, silently passing the
		#'   randomization-test eligibility assert before failing later and deeper,
		#'   inside \code{draw_ws_raw()}'s throwing stub).
		#'
		#' @return 	TRUE if a fresh randomization draw is supported.
		supports_randomization_draw = function(){
			private$supports_resampling_by_registry_abstract_check()
		},
		#' @description Check if this design's mechanism can be faithfully replayed
		#'   against resampled data -- the eligibility condition specifically for the
		#'   bootstrap \emph{randomization test} (BRT), which resamples units and then
		#'   re-randomizes each resample using the design's own mechanism (see
		#'   \code{inference_all_abstract_rand_bootstrap.R}'s repeated
		#'   \code{draw_ws_according_to_design()} calls). \strong{Not} the eligibility
		#'   condition for plain nonparametric/Bayesian/m-out-of-n/PRW-subsampling
		#'   bootstrap -- those never redraw \eqn{w} at all (they resample already-observed
		#'   units and their fixed, observed assignment) and are gated by the broader
		#'   \code{supports_resampling()} instead, which stays \code{TRUE} for
		#'   \code{ObservationalDesign}. \code{FALSE} for the same abstract timing-family
		#'   bases as \code{supports_randomization_draw()} and for
		#'   \code{ObservationalDesign} (no randomization mechanism to replay); \code{TRUE}
		#'   for every other concrete subclass. See \code{supports_randomization_draw()}'s
		#'   documentation for why this is a separate capability rather than the same flag
		#'   reused.
		#'
		#' @return 	TRUE if bootstrap-randomization-test-style replay is supported.
		supports_resampling_replay = function(){
			private$supports_resampling_by_registry_abstract_check()
		},
		#' @description Hook invoked by the bootstrap-randomization-test machinery
		#'   on a design object whose assignment mechanism is about to be replayed
		#'   against resampled data (once per replicate draw site, ahead of
		#'   \code{draw_ws_according_to_design(1L)}). The base implementation is a
		#'   no-op; designs whose replay is a full re-optimization
		#'   (\code{DesignFixedOptimal}) override it to switch to their
		#'   per-replicate solver profile (\code{solver_args$brt_*}). Idempotent.
		#' @return \code{invisible(NULL)}.
		prepare_for_resampling_replay = function(){
			invisible(NULL)
		},
		#' @description Warm the per-subject assignment-data cache, when this
		#'   design uses covariates. This is an internal optimization hook for
		#'   randomization inference; it keeps cache mutation inside the Design
		#'   object instead of exposing its private environment to callers.
		#' @return \code{TRUE} invisibly when a cache warm-up was attempted, or
		#'   \code{FALSE} invisibly when the design does not use covariates.
		warm_all_subject_data_cache = function(){
			if (!isTRUE(private$uses_covariates)) return(invisible(FALSE))
			old_t = private$t
			on.exit({ private$t = old_t }, add = TRUE)
			if (is.null(private$all_subject_data_cache)) private$all_subject_data_cache = list()
			n_subjects = self$get_n()
			for (t_temp in seq_len(n_subjects)) {
				private$t = t_temp
				private$compute_all_subject_data()
			}
			invisible(TRUE)
		},
		#' @description Get n, the sample size
		#'
		#' @return 			The number of subjects.
		get_n = function(){
			ifelse(private$fixed_sample, private$n, private$t)
		},
		#' @description Get y_L
		#'
		#' @return 			A numeric vector of censored-response lower bounds
		#'   (\code{NA} for exact-response subjects).
		get_y_L = function(){
			private$y_L
		},
		#' @description Get y_R
		#'
		#' @return 			A numeric vector of censored-response upper bounds
		#'   (\code{NA} for exact-response subjects).
		get_y_R = function(){
			private$y_R
		},
		#' @description Get the effective response time per subject: the exact
		#'   value \code{y} where recorded, or the lower bound \code{y_L}
		#'   for a censored subject. This reconstructs "the one informative
		#'   number" every response type other than left-/interval-censored
		#'   survival data has always had, for code that needs a single
		#'   numeric value per subject rather than the \code{y}/\code{y_L}/
		#'   \code{y_R} triple directly.
		#'
		#' @return 			A numeric vector, one value per subject.
		get_effective_time = function(){
			ifelse(is.na(private$y), private$y_L, private$y)
		},
		#' @description Get the effective event indicator per subject: \code{1}
		#'   for an exact response, \code{0} for a censored one. This
		#'   reconstructs today's \code{dead} semantics for right-censored
		#'   survival data (and is trivially all-\code{1} for every other
		#'   response type, which never has censoring). It is only valid
		#'   for exact/right-censored data -- a left- or interval-censored
		#'   subject also returns \code{0} here, which is not meaningful
		#'   right-censoring status, so callers must confirm (e.g. via
		#'   \code{any_censoring()} plus their own censoring-shape checks)
		#'   that no such rows are present before relying on this value.
		#'
		#' @return 			An integer vector, one value per subject.
		get_effective_dead = function(){
			as.integer(!is.na(private$y))
		},
		#' @description Get probability of treatment
		#'
		#' @return 			The specified probability.
		get_prob_T = function(){
			private$prob_T
		},
		#' @description Get response type
		#'
		#' @return 			The specified response type.
		get_response_type = function(){
			private$response_type
		},
		#' @description Get the original response type
		#'
		#' @return 			The original specified response type.
		get_response_type_original = function(){
			private$response_type_original
		},
		#' @description Get ordinal levels
		#'
		#' @return 			The levels of the ordinal response.
		get_ordinal_levels = function(){
			private$ordinal_levels
		},
		#' @description Get original ordinal levels
		#'
		#' @return 			The labels for the levels of the original ordinal response.
		get_original_ordinal_levels = function(){
			private$original_ordinal_levels
		},
		#' @description Get the missingness method
		#'
		#' @return 			The missingness handling method: \code{"impute"}, \code{"drop_column"},
		#'   or \code{"error"}.
		get_missingness_method = function(){
			private$missingness_method
		},
		#' @description Get the EDI package version this object was created under.
		#'
		#'   Stamped once, at construction time, from
		#'   \code{utils::packageVersion("EDI")}; never re-stamped on
		#'   \code{readRDS()} reload, so it reflects the version that originally
		#'   built the object rather than whatever version is currently loaded.
		#'   Objects saved before this field existed self-initialize it to the
		#'   \emph{currently loaded} version the first time it is read (there is
		#'   no way to recover the true original version for those objects),
		#'   rather than erroring on the missing field.
		#' @return 			A character string, e.g. \code{"1.0.0"}.
		get_edi_version_created = function(){
			if (is.null(private$edi_version_created)) {
				private$edi_version_created = as.character(utils::packageVersion("EDI"))
			}
			private$edi_version_created
		},
		#' @description Transform the response vector y
		#'
		#' @param transform_fun A function that takes y_original and returns a new y.
		#' @param transformed_response_type The response type of the transformed y.
		#' @param ordinal_levels If the transformed response type is "ordinal", the labels for the levels.
		transform_y = function(transform_fun, transformed_response_type, ordinal_levels = NULL) {
			if (should_run_asserts()) {
				assertFunction(transform_fun)
				if (!identical(names(formals(transform_fun))[1], "y_original")) {
					stop("transform_fun must have its first argument named 'y_original'")
				}
				assertChoice(transformed_response_type, c("continuous", "incidence", "proportion", "count", "survival", "ordinal"))
				if (transformed_response_type == "ordinal" && !is.null(ordinal_levels)) {
					assertCharacter(ordinal_levels, min.len = 2, any.missing = FALSE)
				}
			}
			y_temp = transform_fun(y_original = private$y_original)
			if (should_run_asserts()) {
				assertNumeric(y_temp, len = length(private$y_original))
				private$assert_y(y_temp, transformed_response_type)
			}
			private$y = as.numeric(y_temp)
			private$response_type = transformed_response_type
			private$ordinal_levels = ordinal_levels
			invisible(private$y)
		},
		#' @description Get the model formula
		#'
		#' @return 			The model formula.
		get_design_formula = function(){
			private$design_formula
		},
		#' @description Duplicate this design object
		#'
		#' @param verbose 	A flag for verbosity.
		#' @return 			A new `Design` object with the same data
		duplicate = function(verbose = FALSE){
			if (should_run_asserts()) {
				self$assert_all_responses_recorded() #can't duplicate without the experiment being done
			}
			# Use the built-in R6 clone method (shallow by default) to bypass $new() logic.
			d = self$clone()
			d$.__enclos_env__$private$seed = NULL
			d$.__enclos_env__$private$verbose = verbose
			d
		}
	),
	active = list(
		#' @field num_cores Current number of cores in the global budget.
		num_cores = function() get_num_cores()
	),
	private = list(
		edi_version_created = NULL,
		version_mismatch_checked = FALSE,
		# See TODO "Decide version-mismatch behavior" in save_load_api.md:
		# warn once, on the first post-reload call to a "resume the trial"
		# entry point (draw_ws_according_to_design() for fixed designs,
		# add_one_subject_to_experiment_and_assign() for sequential designs),
		# only when the *major* component of the stamped version differs from
		# the currently loaded package's major version. Silent on
		# minor/patch differences, since routine additive upgrades (the
		# common case under this package's `lock_objects = FALSE` R6
		# fields) should not nag every user on every reload. A freshly
		# constructed object always stamps the current version, so this is a
		# no-op until an object is actually reloaded under a different major
		# version. Uses get_edi_version_created() rather than reading the
		# private field directly so pre-stamp objects (saved before this
		# field existed) self-initialize instead of comparing against NULL.
		check_version_compat = function(){
			if (private$version_mismatch_checked) return(invisible(NULL))
			private$version_mismatch_checked = TRUE
			stamped_major = as.integer(unlist(strsplit(self$get_edi_version_created(), "\\."))[1])
			current_major = as.integer(unlist(strsplit(as.character(utils::packageVersion("EDI")), "\\."))[1])
			if (!is.na(stamped_major) && !is.na(current_major) && stamped_major != current_major) {
				warning(
					"This ", class(self)[1L], " object was created under EDI version ",
					self$get_edi_version_created(), " but EDI version ",
					as.character(utils::packageVersion("EDI")), " is currently loaded. ",
					"Major-version differences may include breaking schema changes; ",
					"verify this object still behaves as expected before continuing.",
					call. = FALSE
				)
			}
			invisible(NULL)
		},
		# Shared by supports_randomization_draw()/supports_resampling_replay(): both
		# default to the same "is this a real concrete class, not an abstract
		# timing-family base" check; ObservationalDesign overrides both public methods
		# directly to FALSE rather than this shared helper, since it needs to diverge
		# from the default for a different reason (no draw/replay mechanism at all, not
		# abstractness).
		supports_resampling_by_registry_abstract_check = function(){
			class_name = class(self)[1L]
			# Unregistered (e.g. a third-party subclass never scanned by
			# populate_design_class_registry()) defaults to `abstract = FALSE`, not
			# TRUE: the pre-split supports_resampling() returned TRUE for any subclass
			# other than the abstract bases themselves, so an unknown-to-the-registry
			# class should fail open (supports resampling) to match that, not fail
			# closed.
			!isTRUE(tryCatch(get_design_class_metadata(class_name)$abstract, error = function(e) FALSE))
		},
		seed = NULL,
		all_subject_data_cache = list(),
		t = 0L,
		n = NULL,
		Xraw = data.table(),
		Ximp = data.table(),
		X = NULL,
		p_raw_t = NULL,
		w = numeric(),
		y = numeric(),
		y_original = numeric(),
		y_L = numeric(),
		y_R = numeric(),
		permutations_cache   = list(),
		lin_centered_covariates = NULL,
		draw_bootstrap_indices = function(bootstrap_type = NULL){
			list(i_b = sample_int_replace_cpp(private$n, private$n), m_vec_b = NULL)
		},
		prob_T = NULL,
		response_type = NULL,
		response_type_original = NULL,
		ordinal_levels = NULL,
		original_ordinal_levels = NULL,
		fixed_sample = NULL,
		include_is_missing_as_a_new_feature = NULL,
		missingness_method = "impute",
		design_formula = NULL,
		verbose = NULL,
		y_i_t_i = list(),	 #at what point during the experiment are the subjects recorded?
		uses_covariates = FALSE, #does this design use the covariates to make assignments? The default is FALSE
		resample_assignment = function(){
			n = private$n
			i_b = sample_int_replace_cpp(n, n)
			private$w    = private$w[i_b]
			private$y    = private$y[i_b]
			private$y_original = private$y_original[i_b]
			private$y_L  = private$y_L[i_b]
			private$y_R  = private$y_R[i_b]
			invisible(self)
		},
		assert_y = function(y, response_type) {
			if (should_run_asserts()) {
				if (response_type == "incidence") {
					assertIntegerish(y, lower = 0, upper = 1, any.missing = FALSE)
				} else if (response_type == "proportion") {
					assertNumeric(y, lower = 0, upper = 1, any.missing = FALSE)
				} else if (response_type == "count") {
					assertIntegerish(y, lower = 0, any.missing = FALSE)
				} else if (response_type == "survival") {
					assertNumeric(y, lower = 0, any.missing = FALSE)
				} else if (response_type == "ordinal") {
					assertIntegerish(y, lower = 1, any.missing = FALSE)
				}
			}
		},
		covariate_impute_if_necessary_and_then_create_model_matrix = function(){
			#make a copy... sometimes the raw will be the same as the imputed if there are no imputations
			#(as.data.table rather than copy: the reusable-bootstrap-worker machinery
			#deliberately stores the worker design's Xraw as a plain data.frame --
			#see bootstrap_subset_source() in inference_all_abstract_non_param_boot.R --
			#and this function's data.table `..` syntax below requires a data.table;
			#as.data.table copies either way, so behavior is unchanged for the
			#ordinary data.table path)
			private$Ximp = as.data.table(private$Xraw)
			column_has_missingness = columns_have_missingness_cpp(private$Xraw)
			if (any(column_has_missingness)){
				if (private$missingness_method == "error"){
					if (should_run_asserts()) {
						missing_names = names(private$Xraw)[column_has_missingness]
						stop("Missing values detected in covariate(s): ",
							paste(missing_names, collapse = ", "),
							". Set missingness_method = \"impute\" or \"drop_column\" to handle missing data automatically.")
					}
				} else if (private$missingness_method == "drop_column"){
					cols_to_keep = which(!column_has_missingness)
					private$Ximp = private$Ximp[, ..cols_to_keep]
				} else {
					# "impute": random-forest imputation (missRanger with missForest fallback)
					#deal with include_is_missing_as_a_new_feature here
					if (private$include_is_missing_as_a_new_feature){
						missing_cols_idx = which(column_has_missingness)
						if (length(missing_cols_idx) > 0){
							# Use C++ function to create missingness indicators efficiently
							missingness_indicators = create_missingness_indicators_cpp(private$Ximp, missing_cols_idx)
							# Add the new columns to Ximp
							for (col_name in names(missingness_indicators)) {
								private$Ximp[[col_name]] = missingness_indicators[[col_name]]
							}
						}
					}
					#we need to convert characters into factor for the imputation to work
					col_types = get_column_types_cpp(private$Ximp)
					idx_cols_to_convert_to_factor = which(col_types == "character")
					private$Ximp[, (idx_cols_to_convert_to_factor) := lapply(.SD, as.factor), .SDcols = idx_cols_to_convert_to_factor]
					#now do the imputation here by using missRanger (fast but fragile) and if that fails, use missForest (slow but more robust)
					y_eff_for_impute = self$get_effective_time()
					private$Ximp = tryCatch({
											if (any(!is.na(y_eff_for_impute))){
												suppressWarnings(missRanger(cbind(private$Ximp, y_eff_for_impute[1 : nrow(private$Ximp)]), verbose = FALSE, num.threads = self$num_cores)[, 1 : ncol(private$Ximp)])
											} else {
												suppressWarnings(missRanger(private$Ximp, verbose = FALSE, num.threads = self$num_cores))
											}
										}, error = function(e){
											if (any(!is.na(y_eff_for_impute))){
												suppressWarnings(missForest(cbind(private$Ximp, y_eff_for_impute[1 : nrow(private$Ximp)]), num.threads = self$num_cores)$ximp[, 1 : ncol(private$Ximp)])
											} else {
												suppressWarnings(missForest(private$Ximp, num.threads = self$num_cores)$ximp)
											}
										}
									)
				}
			}
			analysis_col_names = names(private$Ximp)[!startsWith(names(private$Ximp), ".assignment_only_")]
			Ximp_for_model = if (length(analysis_col_names)) {
				private$Ximp[, ..analysis_col_names]
			} else {
				private$Ximp[, .SD, .SDcols = integer(0)]
			}
			#now let's drop any columns that don't have any variation
			num_unique_values_per_column = count_unique_values_cpp(Ximp_for_model)
			Ximp_for_model = Ximp_for_model[, .SD, .SDcols = which(num_unique_values_per_column > 1)]
			# now we need to update the numeric model matrix which may have expanded due to new factors, new missingness cols, etc
			private$X = create_model_matrix_from_features(private$design_formula, Ximp_for_model)
			# Ensure it is a numeric matrix (not character)
			if (should_run_asserts()) {
				if (ncol(private$X) > 0 && is.character(private$X)){
					stop("model.matrix returned a character matrix - this should not happen.")
				}
			}
			if (ncol(private$X) > 0){
				if (should_run_asserts()) {
					if (nrow(private$X) != nrow(private$Xraw) | nrow(private$X) != nrow(private$Ximp) | nrow(private$Ximp) != nrow(private$Xraw)){
						stop("improper sizing for the internal X representation")
					}
				}
			}
		},
		compute_all_subject_data = function(){
			i_present_y = which(!(is.na(private$y) & is.na(private$y_L) & is.na(private$y_R)))
			i_all = 1 : private$t
			i_all_y_present = intersect(i_all, i_present_y)
			
			# Cache lookup
			# Since covariates are fixed and NA positions in y are fixed during randomization,
			# the set of subjects with responses up to t is constant for a given t.
			cache_key = as.character(private$t)
			if (!is.null(private$all_subject_data_cache[[cache_key]])) {
				cpp_result = private$all_subject_data_cache[[cache_key]]
			} else {
				# Call consolidated C++ function for all matrix computations
				cpp_result = compute_all_subject_data_cpp(
					as.matrix(private$X[1:private$t, , drop = FALSE]),
					private$t,
					as.integer(i_all_y_present)
				)
				# Restore column names
				X_names = colnames(private$X)
				if (length(cpp_result$cols_prev) > 0) {
					nms = X_names[cpp_result$cols_prev]
					colnames(cpp_result$X_prev) = nms
					names(cpp_result$xt_prev) = nms
				}
				if (length(cpp_result$cols_all) > 0) {
					colnames(cpp_result$X_all) = X_names[cpp_result$cols_all]
				}
				if (length(cpp_result$cols_all_scaled) > 0) {
					nms = X_names[cpp_result$cols_all_scaled]
					colnames(cpp_result$X_all_scaled) = nms
					names(cpp_result$xt_all_scaled) = nms
				}
				if (length(cpp_result$cols_all_with_y_scaled) > 0) {
					colnames(cpp_result$X_all_with_y_scaled) = X_names[cpp_result$cols_all_with_y_scaled]
				}
				
				if (is.null(private$all_subject_data_cache)) private$all_subject_data_cache = list()
				private$all_subject_data_cache[[cache_key]] = cpp_result
			}
			# Add the simple array slices that don't need C++ optimization
			# These MUST NOT be cached because w and y change during randomization!
			cpp_result$w_all_with_y_scaled = private$w[i_all_y_present]
			cpp_result$y_all = self$get_effective_time()[i_all_y_present]
			cpp_result$dead_all = self$get_effective_dead()[i_all_y_present]
			cpp_result
		},
		assign_wt_Bernoulli = function(){
			rbinom(1, 1, private$prob_T)
		},
		has_private_method = function(method_name) {
			exists(method_name, envir = self$.__enclos_env__$private, inherits = FALSE)
		},
		maybe_set_seed = function() { if (!is.null(private$seed)) set.seed(private$seed) }
	)
)
