#' Exact Fisher (Conditional Hypergeometric) Incidence Inference
#'
#' Performs exact conditional inference for binary (incidence) outcomes via
#' Fisher's exact test on one or more 2x2 (treated/control by case/noncase)
#' tables. When the design provides no stratification structure (e.g. an
#' unstructured or iBCRD design), a single overall 2x2 table is built and
#' \code{\link[stats]{fisher.test}} is used directly, giving the conditional
#' MLE odds ratio and its exact confidence interval/p-value. When the design
#' has \strong{blocking structure} (\code{DesignFixedBlocking},
#' \code{DesignSeqOneByOneSPBR}, \code{DesignSeqOneByOneRandomBlockSize}), a
#' separate 2x2 table is built per block-defining covariate stratum. When the
#' design has \strong{matched-pair structure} (KK matching-on-the-fly designs),
#' each matched pair becomes its own 2x2 table, with any reservoir (unmatched)
#' subjects pooled into one additional stratum table. In either stratified
#' case, \code{\link[stats]{mantelhaen.test}} (exact conditional test) is used
#' instead, giving the common odds ratio across strata; stratified inference
#' only supports testing/estimating against a null odds ratio of 1 (log odds
#' ratio 0) — a non-zero null shift is rejected with an error. Strata with no
#' cases or no noncases in either arm are dropped before analysis; if no
#' informative strata remain, this errors rather than returning a degenerate
#' result.
#'
#' @references Fisher, R. A. (1935). "The Logic of Inductive Inference."
#'   \emph{Journal of the Royal Statistical Society}, 98(1), 39-82,
#'   \doi{10.2307/2342435}, for the exact conditional test underlying
#'   \code{\link[stats]{fisher.test}}; Mantel, N., and Haenszel, W. (1959).
#'   "Statistical Aspects of the Analysis of Data from Retrospective Studies
#'   of Disease." \emph{Journal of the National Cancer Institute}, 22(4),
#'   719-748, for the stratified common-odds-ratio test used when the design
#'   provides multiple strata.
#'
#' @examples
#' \dontrun{
#' # Example for InferenceIncidExactFisher
#' }
#' @name InferenceIncidExactFisher
#' @export
ExactFisherIncidenceSource = list(
	public = list(
		#' @description Initialize exact Fisher inference for incidence outcomes.
		#'   Requires an uncensored incidence response; the design's structure
		#'   (unstructured, blocked, or matched) determines the stratification used
		#'   at estimation time (see class documentation).
		#' @param des_obj A completed design object.
		#' @param model_formula   Optional formula for covariate adjustment. If \code{NULL} (default),
		#'   the formula from the design object is used and its pre-computed design matrix is
		#'   reused. If a formula is provided, a new design matrix is constructed from the
		#'   design's imputed covariates.
		#' @param verbose Whether to print progress messages.
		#' @param smart_cold_start_default Whether to use smart cold start values by default.
		#' @return A new \code{InferenceIncidExactFisher} object.
		initialize = function(des_obj, model_formula = NULL,  verbose = FALSE, smart_cold_start_default = NULL){
			if (should_run_asserts()) {
				assertResponseType(des_obj$get_response_type(), "incidence")
			}
			super$initialize(des_obj, verbose = verbose, model_formula = model_formula, smart_cold_start_default = smart_cold_start_default)
			if (should_run_asserts()) {
				assertNoCensoring(private$any_censoring)
			}
		},
		#' @description Computes the log of the (conditional MLE, or common-odds-ratio
		#'   if stratified) odds ratio from \code{\link[stats]{fisher.test}} or
		#'   \code{\link[stats]{mantelhaen.test}} (see class documentation for which
		#'   applies and why).
		#' @param estimate_only Ignored for this estimator (the exact statistic is
		#'   always cheap to compute; there is no separate variance step to skip).
		#' @return The treatment estimate.
		compute_estimate = function(estimate_only = FALSE){
			private$get_exact_fisher_log_or_estimate()
		}
	),
	private = list(
		default_exact_type = "Fisher",
		resolve_exact_type = function(type){
			if (is.null(type)) type = private$default_exact_type
			if (should_run_asserts()) {
				assertChoice(type, c("Fisher"))
			}
			type
		},
		normalize_exact_inference_args = function(type, args_for_type = NULL){
			if (should_run_asserts()) {
				assertChoice(type, c("Fisher"))
				assertList(args_for_type, null.ok = TRUE)
			}
			utils::modifyList(setNames(list(list()), type), if (is.null(args_for_type)) list() else args_for_type)
		},
		assert_exact_inference_params = function(type, args_for_type){
			if (should_run_asserts()) {
				assertChoice(type, c("Fisher"))
				assertList(args_for_type)
				if (!(type %in% names(args_for_type))) stop("args_for_type must contain a list for ", type)
			}
			args = args_for_type[[type]]
			if (should_run_asserts()) {
				assertList(args)
				assertResponseType(private$des_obj$get_response_type(), "incidence")
				assertNoCensoring(private$any_censoring)
			}
			if (should_run_asserts()) {
				if (!private$design_supports_exact_fisher()) {
					stop("Fisher exact inference requires iBCRD, blocking, or matching designs.")
				}
			}
			invisible(args)
		},
		compute_exact_confidence_interval_by_type = function(type, alpha, args_for_type){
			if (should_run_asserts()) {
				assertNumeric(alpha, lower = .Machine$double.xmin, upper = 1 - .Machine$double.xmin)
				private$assert_exact_inference_params(type, args_for_type)
			}
			switch(type,
				Fisher = private$ci_exact_fisher(alpha)
			)
		},
		compute_exact_two_sided_pval_for_treatment_effect_by_type = function(type, delta, args_for_type){
			if (should_run_asserts()) {
				assertNumeric(delta, len = 1)
				private$assert_exact_inference_params(type, args_for_type)
			}
			switch(type,
				Fisher = private$pval_exact_fisher(delta)
			)
		},
		# Mechanical family-membership translation of the same 5 classes previously
		# named by class identity (fix_design_hierarchy.md, "Class-Identity Dispatch
		# Replacement") -- not a new capability, since the underlying eligibility
		# reasons are genuinely heterogeneous (iBCRD designs are eligible *because* they
		# have no stratification at all, using a single overall table; the blocking-
		# family designs are eligible because they *do* have real per-stratum
		# structure), so introducing one shared "exact_fisher_eligible" flag across both
		# groups would paper over that distinction rather than express it.
		design_supports_exact_fisher = function(){
			isTRUE(private$des_obj$randomization_family() %in% c(
				"complete_randomization", "blocked", "spbr", "random_block_size"
			)) || private$has_match_structure
		},
		pval_exact_fisher = function(delta_0){
			as.numeric(private$get_exact_fisher_htest(delta_0 = delta_0)$p.value)
		},
		ci_exact_fisher = function(alpha){
			test = private$get_exact_fisher_htest(alpha = alpha, delta_0 = 0)
			ci = log(as.numeric(test$conf.int))
			names(ci) = paste0(c(alpha / 2, 1 - alpha / 2) * 100, "%")
			ci
		},
		get_exact_fisher_log_or_estimate = function(){
			log(as.numeric(private$get_exact_fisher_htest()$estimate[[1]]))
		},
		get_exact_fisher_htest = function(alpha = 0.05, delta_0 = 0){
			if (should_run_asserts()) {
				assertNumeric(alpha, lower = .Machine$double.xmin, upper = 1 - .Machine$double.xmin)
				assertNumeric(delta_0, len = 1)
			}
			is_default_call = (abs(alpha - 0.05) < .Machine$double.eps && abs(delta_0) < .Machine$double.eps)
			if (is_default_call && !is.null(private$cached_values$incid_exact_fisher_htest)) {
				return(private$cached_values$incid_exact_fisher_htest)
			}
			fisher_tables = private$get_exact_fisher_tables()
			conf_level = 1 - alpha
			result = if (fisher_tables$n_strata == 1L) {
				stats::fisher.test(
					fisher_tables$table,
					alternative = "two.sided",
					or = exp(delta_0),
					conf.level = conf_level
				)
			} else {
				if (should_run_asserts()) {
					if (abs(delta_0) > sqrt(.Machine$double.eps)) {
						stop("Stratified Fisher exact inference only supports delta = 0.")
					}
				}
				stats::mantelhaen.test(
					fisher_tables$array,
					alternative = "two.sided",
					exact = TRUE,
					conf.level = conf_level
				)
			}
			if (is_default_call) {
				private$cached_values$incid_exact_fisher_htest = result
			}
			result
		},
		get_exact_fisher_tables = function(){
			if (!is.null(private$cached_values$incid_exact_fisher_tables)) {
				return(private$cached_values$incid_exact_fisher_tables)
			}
			fisher_tables =
					if (private$has_match_structure) {
					private$build_exact_fisher_tables_kk()
				} else if (isTRUE(private$des_obj$randomization_family() %in% c("blocked", "spbr", "random_block_size"))) {
					private$build_exact_fisher_tables_blocking()
				} else {
					private$format_exact_fisher_tables(list(private$build_exact_fisher_2x2_table(seq_len(private$n))))
				}
			private$cached_values$incid_exact_fisher_tables = fisher_tables
			fisher_tables
		},
		build_exact_fisher_tables_blocking = function(){
			strata_cols = private$des_obj_priv_int$strata_cols
			if (is.null(strata_cols) || length(strata_cols) == 0L) {
				return(private$format_exact_fisher_tables(list(private$build_exact_fisher_2x2_table(seq_len(private$n)))))
			}
			Xraw = private$des_obj_priv_int$Xraw
			strata_keys = vapply(seq_len(private$n), function(i){
				private$get_exact_fisher_strata_key(Xraw[i, ], strata_cols)
			}, character(1))
			strata_indices = split(seq_len(private$n), strata_keys)
			private$format_exact_fisher_tables(lapply(strata_indices, private$build_exact_fisher_2x2_table))
		},
		get_exact_fisher_strata_key = function(x_row, strata_cols){
			paste(vapply(strata_cols, function(col){
				val = x_row[[col]]
				if (is.na(val)) "NA" else as.character(val)
			}, character(1)), collapse = "|")
		},
		build_exact_fisher_tables_kk = function(){
			m_vec = private$des_obj_priv_int$m
			if (should_run_asserts()) {
				if (is.null(m_vec)) {
					stop("Matching structure is unavailable for Fisher exact inference.")
				}
			}
			m_vec = as.integer(m_vec)
			m_vec[is.na(m_vec)] = 0L
			table_list = list()
			matched_ids = sort(unique(m_vec[m_vec > 0L]))
			for (match_id in matched_ids) {
				table_list[[length(table_list) + 1L]] = private$build_exact_fisher_2x2_table(which(m_vec == match_id))
			}
			reservoir_indices = which(m_vec == 0L)
			if (length(reservoir_indices) > 0L) {
				table_list[[length(table_list) + 1L]] = private$build_exact_fisher_2x2_table(reservoir_indices)
			}
			private$format_exact_fisher_tables(table_list)
		},
		build_exact_fisher_2x2_table = function(indices){
			i_t = private$w[indices] == 1L
			i_c = private$w[indices] == 0L
			y_idx = private$y[indices]
			matrix(
				c(
					sum(y_idx[i_t] == 1L, na.rm = TRUE),
					sum(y_idx[i_c] == 1L, na.rm = TRUE),
					sum(y_idx[i_t] == 0L, na.rm = TRUE),
					sum(y_idx[i_c] == 0L, na.rm = TRUE)
				),
				nrow = 2,
				dimnames = list(c("treated", "control"), c("case", "noncase"))
			)
		},
		format_exact_fisher_tables = function(table_list){
			table_list = Filter(function(tab) sum(tab[1, ]) > 0L && sum(tab[2, ]) > 0L, table_list)
			if (length(table_list) == 0L) {
				stop("Cannot compute Fisher exact inference: no informative strata are available.")
			}
			if (length(table_list) == 1L) {
				return(list(n_strata = 1L, table = table_list[[1]]))
			}
			table_array = array(
				0,
				dim = c(2L, 2L, length(table_list)),
				dimnames = c(dimnames(table_list[[1]]), list(NULL))
			)
			for (k in seq_along(table_list)) {
				table_array[, , k] = table_list[[k]]
			}
			list(n_strata = length(table_list), array = table_array)
		}
	)
)

InferenceIncidExactFisher = define_inference_class(
	classname = "InferenceIncidExactFisher",
	inherit = Inference,
	components = "ExactFisherIncidence",
	metadata = list(likelihood_tier = "none"),
	overrides = list(
		private = c(
			"default_exact_type",
			"resolve_exact_type",
			"normalize_exact_inference_args",
			"assert_exact_inference_params",
			"compute_exact_confidence_interval_by_type",
			"compute_exact_two_sided_pval_for_treatment_effect_by_type"
		)
	)
)
