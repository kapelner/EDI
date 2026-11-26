# Derived private fields that can hold a fit or design from a previous draw.
# Keep the reset surface in one place; each loader preserves only fields whose
# inputs are unchanged by its kind of draw. Do not include immutable model data
# or warm-start state here.
EDI_REUSED_WORKER_PRIVATE_CACHE_FIELDS = c(
	"cached_design_matrix", "cached_w_for_design_matrix",
	"cached_harden_for_design_matrix", "cached_hardened_X_cov",
	"cached_reduced_X", "cached_X_full_for_reduced",
	"cached_keep_for_reduced", "cached_j_treat_for_reduced",
	"reduced_design_keep_cache", "fixed_covariate_keep_cache",
	"best_X_colnames", "best_Xmm_colnames", "cached_mod"
)

reset_reused_worker_private_caches = function(worker_priv, changed = c("sample", "assignment", "response"), preserve_fields = character()){
	changed = match.arg(changed)
	preserve = switch(changed,
		# X is fixed under randomization, but w and the fitted model change.
		assignment = c("cached_hardened_X_cov", "fixed_covariate_keep_cache"),
		# Parametric draws change only y; [1 | w | X] and its reductions remain valid.
		response = c("cached_design_matrix", "cached_w_for_design_matrix",
		             "cached_harden_for_design_matrix", "cached_hardened_X_cov",
		             "cached_reduced_X", "cached_X_full_for_reduced",
		             "cached_keep_for_reduced", "cached_j_treat_for_reduced"),
		sample = character()
	)
	# A few class-owned invariants are not derivable from the changed-data kind
	# alone. Callers may opt in to preserving those fields for a specific worker.
	preserve = union(preserve, preserve_fields)
	for (field in setdiff(EDI_REUSED_WORKER_PRIVATE_CACHE_FIELDS, preserve)) {
		if (exists(field, envir = worker_priv, inherits = FALSE)) worker_priv[[field]] = NULL
	}
	invisible(NULL)
}

# v1.0.6-TODO-85: per-subject fields that bootstrap_subset_inference() sets from the
# draw itself; everything else on a subset copy that still has the parent's rows is a
# stale cache.
EDI_SUBSET_COPY_ROW_FIELDS = c("X", "y", "y_temp", "w", "dead", "y_L", "y_R", "m", "cached_values")

# Clears every private field of a subset copy that still holds the parent's n rows: a
# numeric/logical/factor vector, matrix or data frame with NROW(x) == n_parent, or a
# plain list holding one (two levels deep, e.g. bootstrap_qr_rank_certificate$X or
# strat_cox_strata_info_cache$strata_id). duplicate() copies these from the parent and
# nothing rebuilds them for the subset, so they are either keyed caches that would miss
# anyway or unkeyed ones that R would silently recycle or misalign against the subset
# (za_X_cov_all, v1.0.6-TODO-80). Clearing rather than subsetting: a cache may depend on
# the whole sample (centring, weights, fitted values), so only a rebuild is right, and
# every such field is a lazily rebuilt cache (no Inference class stores per-subject
# input outside `keep`). Character vectors are left alone (labels and column names,
# never per-subject data here), as are functions, environments and R6 objects.
# Returns the cleared field names invisibly.
clear_parent_row_private_caches = function(priv, n_parent, keep = EDI_SUBSET_COPY_ROW_FIELDS){
	n_parent = suppressWarnings(as.integer(n_parent)[1L])
	if (is.na(n_parent) || n_parent < 2L) return(invisible(character()))
	holds_parent_rows = function(x, depth = 0L){
		if (is.null(x) || is.function(x) || is.environment(x) || inherits(x, "R6")) return(FALSE)
		if (is.data.frame(x) || is.matrix(x) || is.numeric(x) || is.logical(x) || is.factor(x)) {
			return(!is.character(x) && NROW(x) == n_parent)
		}
		if (is.list(x) && depth < 2L) {
			for (el in x) if (holds_parent_rows(el, depth + 1L)) return(TRUE)
		}
		FALSE
	}
	cleared = character()
	for (field in setdiff(ls(priv, all.names = TRUE), keep)) {
		if (bindingIsActive(field, priv)) next
		x = get(field, envir = priv, inherits = FALSE)
		if (holds_parent_rows(x)) {
			priv[[field]] = NULL
			cleared = c(cleared, field)
		}
	}
	invisible(cleared)
}
