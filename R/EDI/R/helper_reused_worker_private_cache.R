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

reset_reused_worker_private_caches = function(worker_priv, changed = c("sample", "assignment", "response")){
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
	for (field in setdiff(EDI_REUSED_WORKER_PRIVATE_CACHE_FIELDS, preserve)) {
		if (exists(field, envir = worker_priv, inherits = FALSE)) worker_priv[[field]] = NULL
	}
	invisible(NULL)
}
