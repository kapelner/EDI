# Shared internal machinery for the model-based optimal designs
# (DesignFixedGreedyDOptimal today; DesignFixedOptimal per
# package_metadata/new_feature_plans/design_fixed_optimal.md TODO-1b): the
# objective/interest/prior_precision argument surface and the P/H
# criterion-matrix construction. Non-exported. Extracted verbatim from
# DesignFixedGreedyDOptimal so allocations remain bit-identical
# (golden-locked in tests/testthat/test-design-optimal-shared-golden.R);
# behavior changes here require updating both design classes' documentation.

# Validate the shared constructor surface and resolve `interest` into its kind.
# `allowed_objectives` is the caller's own closed set (the two classes' sets
# differ); `objective_error_message` lets a caller keep its bespoke wording.
# Returns list(interest = possibly-promoted interest, interest_kind =
# "treatment" | "all" | "subset"). All checks are always-on (never
# assert-gated), matching the calling constructors.
validate_optimal_design_objective_args = function(objective, interest, prior_precision, standardize_covariates, allowed_objectives, objective_error_message = NULL){
	if (!is.character(objective) || length(objective) != 1L || !(objective %in% allowed_objectives)) {
		stop(objective_error_message %||% sprintf(
			"objective must be one of: %s.", paste(shQuote(allowed_objectives, type = "cmd"), collapse = ", ")
		))
	}
	# A single character string containing formula operators (e.g.
	# "x1 * x2 + x7") is promoted to a one-sided formula; plain strings are
	# treated as model-matrix column names.
	if (is.character(interest) && length(interest) == 1L && !(interest %in% c("treatment", "all")) &&
			grepl("[ ~+*:^()|-]", interest)) {
		interest = if (grepl("~", interest, fixed = TRUE)) stats::as.formula(interest) else stats::as.formula(paste("~", interest))
	}
	interest_kind = if (is.character(interest) && length(interest) == 1L && interest %in% c("treatment", "all")) {
		interest
	} else if (inherits(interest, "formula")) {
		if (length(interest) != 2L) stop("An interest formula must be one-sided, e.g. ~ x1 + x2.")
		"subset"
	} else if (is.character(interest) && length(interest) >= 1L && !anyNA(interest)) {
		"subset"
	} else if (is.matrix(interest)) {
		stop(paste0(
			"Contrast-matrix interest (general D_A) arrives with Stage 2 of the ",
			"DesignFixedGreedyDOptimal plan (see fix_design_hierarchy.md); currently ",
			'supported: "treatment", "all", a one-sided formula, or covariate names.'
		))
	} else {
		stop('interest must be "treatment", "all", a one-sided formula, or a character vector of covariate names.')
	}
	if (!is.null(prior_precision)) {
		if (is.matrix(prior_precision)) {
			if (!is.numeric(prior_precision) || nrow(prior_precision) != ncol(prior_precision)) {
				stop("A matrix prior_precision must be numeric and square.")
			}
			if (!isSymmetric(unname(prior_precision))) {
				stop("A matrix prior_precision must be symmetric.")
			}
		} else if (!(is.numeric(prior_precision) && length(prior_precision) == 1L &&
					is.finite(prior_precision) && prior_precision > 0)) {
			stop("prior_precision must be NULL, a single positive scalar, or a symmetric numeric matrix.")
		}
	}
	if (!is.logical(standardize_covariates) || length(standardize_covariates) != 1L || is.na(standardize_covariates)) {
		stop("standardize_covariates must be TRUE or FALSE.")
	}
	list(interest = interest, interest_kind = interest_kind)
}

# Resolve a subset `interest` (one-sided formula or character vector of
# model-matrix column names) into Z0 = cbind(1, X) column indices for the
# selected covariates (the treatment coefficient is always in the interest
# set but is not a Z0 column; the intercept is never in the interest set).
resolve_optimal_interest_z0_columns = function(X, interest){
	x_names = colnames(X)
	if (is.null(x_names)) {
		stop("The design's model matrix has no column names; cannot resolve a subset interest.")
	}
	wanted = if (inherits(interest, "formula")) {
		mm = stats::model.matrix(interest, data = as.data.frame(X))
		setdiff(colnames(mm), "(Intercept)")
	} else {
		interest
	}
	if (length(wanted) == 0L) {
		stop("A subset interest must select at least one covariate column.")
	}
	unmatched = setdiff(wanted, x_names)
	if (length(unmatched) > 0L) {
		stop(sprintf(
			"interest column(s) not found in the design's model matrix: %s. Available columns: %s. (Factor covariates must be referred to by their expanded model-matrix column names.)",
			paste(unmatched, collapse = ", "), paste(x_names, collapse = ", ")
		))
	}
	# +1: Z0's first column is the intercept
	match(wanted, x_names) + 1L
}

# Build the criterion matrices for the D/A objective family over the model
# matrix X: P = Z0 (Z0'Z0)^-1 Z0' (or its ridge-regularized Bayesian
# counterpart P_B), and, when need_H, the trace-kernel H / subset H_S /
# Bayesian H_B selected by `interest` ("all" => full H; anything else is
# treated as a subset interest resolved against X's column names).
# Returns list(P = matrix, H = matrix or NULL).
build_optimal_design_P_H = function(X, interest, prior_precision, standardize_covariates, need_H){
	subset_interest = need_H && !(is.character(interest) && length(interest) == 1L && interest == "all")
	H = NULL
	if (is.null(prior_precision)) {
		# Non-Bayesian: identical construction to the former
		# DesignFixedDOptimal/DesignFixedAOptimal classes (QR-based, so
		# allocations are bit-identical to the pre-merge classes).
		Z0 = cbind(1, X)
		Z0_qr = qr(Z0)
		Q = qr.Q(Z0_qr)
		# P = Z0 (Z0'Z0)^-1 Z0'
		P = Q %*% t(Q)
		if (need_H) {
			R = qr.R(Z0_qr)
			M = tryCatch(solve(t(R) %*% R), error = function(e) MASS::ginv(t(R) %*% R))
			if (subset_interest) {
				# A_s: H_S = (Z0 V S)(Z0 V S)' over the selected columns
				ZV = Z0 %*% M
				idx0 = resolve_optimal_interest_z0_columns(X, interest)
				H = tcrossprod(ZV[, idx0, drop = FALSE])
			} else {
				# H = Z0 (Z0'Z0)^-2 Z0'
				H = Z0 %*% (M %*% M) %*% t(Z0)
			}
		}
	} else {
		# Bayesian D_B/A_B: ridge-regularized inverse. Scalar tau penalizes
		# covariates only (intercept and treatment unpenalized).
		scalar_tau = !is.matrix(prior_precision)
		if (scalar_tau && isTRUE(standardize_covariates)) {
			X = scale(X)
			X[!is.finite(X)] = 0  # constant columns scale to NaN; drop their influence
		}
		Z0 = cbind(1, X)
		pz = ncol(Z0)
		R0 = if (scalar_tau) {
			diag(c(0, rep(as.numeric(prior_precision), pz - 1L)), nrow = pz)
		} else {
			if (nrow(prior_precision) != pz) {
				stop(sprintf("prior_precision matrix must be %d x %d ([intercept, covariates] over the design's model matrix).", pz, pz))
			}
			prior_precision
		}
		V_B = solve(crossprod(Z0) + R0)
		P = Z0 %*% V_B %*% t(Z0)
		if (need_H) {
			if (subset_interest) {
				ZV = Z0 %*% V_B
				idx0 = resolve_optimal_interest_z0_columns(X, interest)
				H = tcrossprod(ZV[, idx0, drop = FALSE])
			} else {
				H = Z0 %*% V_B %*% V_B %*% t(Z0)
			}
		}
	}
	list(P = P, H = H)
}
