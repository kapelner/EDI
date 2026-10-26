# Shared core of the two calibration gates (design: R/package_metadata/
# new_feature_plans/calibration_gates.md):
#   * the scheduled CI fast tier (run_calibration_fast_tier.R +
#     analyze_calibration_fast_tier.R, .github/workflows/calibration-fast-tier.yml)
#     -- size and coverage, exact one-sided binomial, Bonferroni 0.01/K;
#   * the pre-push check (prepush_calibration_checks.R) -- per-rep CI/test
#     agreement, CI-endpoint inversion and a large-effect sign check, only for
#     the classes a push touched.
#
# One replicate = synthetic data with n subjects and p = 2 covariates (x1
# continuous, x2 binary). Treatment is assigned by the design BEFORE y is drawn
# and y depends on w only through `effect`. With effect = 0, w is independent of
# (X, y), so the sharp null holds and every estimand -- conditional or
# marginal, difference or ratio -- sits exactly at the class's own null value
# (private$default_null_value(), else 0). No per-class truth is needed.
#
# Each class runs under the cheapest design it supports: iid classes under
# DesignFixedBernoulli, matched-pair classes (applicable to
# DesignFixedBinaryMatch but not to Bernoulli) under DesignFixedBinaryMatch.
# Procedures: the fast analytic ones only (wald, score, lik_ratio, gradient),
# at both `~ 1` and `~ .` for classes that take a model formula. Jackknife is
# excluded: it refits n times (~150 s of a 160 s ordinal replicate at n = 200).
#
# Loads the INSTALLED EDI (like the other pre-push R scripts); internal suite
# helpers are reached with EDI:::.

CAL_RESPONSE_TYPES <- c("continuous", "incidence", "proportion", "count", "ordinal", "survival")
CAL_METHODS <- c("wald", "score", "lik_ratio", "gradient")
CAL_FORMULAS <- list(~ 1, ~ .)
CAL_ALPHA <- 0.05

# Treatment shift used by the sign check, on each family's linear-predictor
# scale. Large enough that every procedure rejects at n = 200 with
# near-certainty; positive means "treatment raises the response" (and, for
# survival, lengthens survival time).
CAL_SIGN_EFFECT <- c(continuous = 1, incidence = 1.5, proportion = 1.5, count = 0.8, ordinal = 1.5, survival = 1)

# Estimands whose sign runs opposite to "treatment raises the response": a
# treatment that lengthens survival LOWERS the hazard. Every other estimand
# (differences, log rate/odds/risk/time ratios, link effects, rank effects)
# moves up with the effect -- confirmed on one large-effect replicate of every
# fast class, 2026-10-26. A new estimand defaults to "up"; if that is wrong the
# pre-push sign check says so and the estimand belongs here.
CAL_DOWNWARD_ESTIMANDS <- c("log_hazard_ratio", "gehan_wilcoxon_statistic", "log_rank_martingale_difference")

cal_expected_direction <- function(inference_class) {
	est <- tryCatch(EDI:::run_all_inference_estimand(inference_class), error = function(e) NA_character_)
	if (!is.na(est) && est %in% CAL_DOWNWARD_ESTIMANDS) -1L else 1L
}

cal_rt_index <- function(response_type) match(response_type, CAL_RESPONSE_TYPES)

cal_gen_X <- function(n) data.frame(x1 = stats::rnorm(n), x2 = stats::rbinom(n, 1L, 0.5))

# y drawn from the response family's own model, so model-based SEs are not
# legitimately wrong because of misspecification.
cal_gen_y <- function(response_type, X, w, effect = 0) {
	n <- nrow(X)
	eta <- 0.5 * X$x1 + 0.5 * X$x2 + effect * w
	switch(response_type,
		continuous = list(ys = 1 + eta + stats::rnorm(n)),
		incidence = list(ys = stats::rbinom(n, 1L, stats::plogis(-0.5 + eta))),
		proportion = {
			mu <- stats::plogis(eta)
			phi <- 10
			list(ys = pmin(pmax(stats::rbeta(n, mu * phi, (1 - mu) * phi), 1e-4), 1 - 1e-4))
		},
		count = list(ys = stats::rpois(n, exp(0.5 + 0.6 * eta))),
		ordinal = {
			lat <- eta + stats::rlogis(n)
			list(ys = factor(cut(lat, c(-Inf, -1, 0, 1, Inf), labels = FALSE), levels = 1:4, ordered = TRUE))
		},
		survival = {
			# Weibull with scale exp(eta / 1.5): proportional hazards in X and w, and a
			# positive effect lengthens survival. Independent exponential censoring.
			t <- stats::rweibull(n, shape = 1.5, scale = exp(eta / 1.5))
			cens <- stats::rexp(n, 0.3)
			ev <- t <= cens
			obs <- pmin(t, cens)
			list(ys = ifelse(ev, obs, NA), y_Ls = ifelse(ev, NA, obs), y_Rs = ifelse(ev, NA, Inf))
		},
		stop("unknown response type: ", response_type, call. = FALSE)
	)
}

cal_new_design <- function(design_name, response_type, n, X) {
	des <- get(design_name, envir = asNamespace("EDI"))$new(n = n, response_type = response_type)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des
}

# Which classes run under which design for one response type: iid classes under
# Bernoulli, matched-pair-only classes under BinaryMatch. Computed from a
# throwaway design pair so it reflects the installed package's own registry.
cal_class_plan <- function(response_type, n = 200L) {
	X <- cal_gen_X(n)
	iid <- EDI:::applicable_inference_class_names_for_design(cal_new_design("DesignFixedBernoulli", response_type, n, X))
	paired <- EDI:::applicable_inference_class_names_for_design(cal_new_design("DesignFixedBinaryMatch", response_type, n, X))
	list(DesignFixedBernoulli = sort(iid), DesignFixedBinaryMatch = sort(setdiff(paired, iid)))
}

cal_null_value <- function(inf_obj) {
	priv <- inf_obj$.__enclos_env__$private
	if (is.function(priv$default_null_value)) {
		v <- tryCatch(as.numeric(priv$default_null_value()), error = function(e) NA_real_)
		if (length(v) == 1L && is.finite(v)) return(v)
	}
	0
}

cal_pval_method_name <- function(method) {
	entry <- Find(function(e) identical(e$label, method), EDI:::EDI_INFERENCE_SUITE_PVAL_METHOD_PRIORITY)
	if (is.null(entry)) NA_character_ else entry$method
}

# p-value of the class's own test of H0: estimand = delta, or NA when the
# method takes no `delta` or fails.
cal_pval_at <- function(inf_obj, method, delta) {
	nm <- cal_pval_method_name(method)
	if (is.na(nm) || !is.finite(delta)) return(NA_real_)
	f <- inf_obj[[nm]]
	if (!is.function(f) || !("delta" %in% names(formals(f)))) return(NA_real_)
	args <- list(delta = delta)
	if ("show_progress" %in% names(formals(f))) args$show_progress <- FALSE
	p <- tryCatch(suppressWarnings(do.call(f, args)), error = function(e) NA_real_)
	if (length(p) == 1L && is.finite(p)) as.numeric(p) else NA_real_
}

cal_clean_msg <- function(x) {
	if (is.null(x) || !length(x) || is.na(x)) return(NA_character_)
	substr(gsub("[\r\n\t,]+", " ", x), 1L, 300L)
}

# Runs every (class, formula, method) task for `classes` on one design. Returns
# one row per task. `endpoints = TRUE` adds the p-values of the same test at the
# two CI endpoints (pre-push only; the CI tier does not need them).
cal_run_tasks <- function(des, classes, alpha = CAL_ALPHA, endpoints = FALSE) {
	if (!length(classes)) return(NULL)
	tasks <- EDI:::run_all_inference_build_tasks(classes, CAL_FORMULAS, CAL_METHODS, des_obj = des)
	rows <- lapply(tasks, function(task) {
		if (is.na(task$method)) return(NULL)
		t0 <- proc.time()[["elapsed"]]
		row <- list(inference_class = task$cls_name, method = task$method,
			formula = if (is.null(task$model_formula)) "" else deparse1(task$model_formula),
			estimate = NA_real_, ci_a = NA_real_, ci_b = NA_real_, pval = NA_real_, null_value = NA_real_,
			p_at_ci_a = NA_real_, p_at_ci_b = NA_real_, fit_secs = NA_real_, status = "error", message = NA_character_)
		res <- tryCatch(suppressWarnings({
			params <- if (is.null(task$model_formula)) list() else list(model_formula = task$model_formula)
			inf_obj <- do.call(get(task$cls_name, envir = asNamespace("EDI"))$new, c(list(des_obj = des), params))
			row$estimate <- as.numeric(inf_obj$compute_estimate())[1L]
			row$null_value <- cal_null_value(inf_obj)
			ci <- EDI:::run_all_inference_call_ci_for_method(inf_obj, alpha, task$method)
			pv <- EDI:::run_all_inference_call_pval_for_method(inf_obj, task$method)
			row$ci_a <- ci$lower
			row$ci_b <- ci$upper
			row$pval <- pv$pval
			if (isTRUE(endpoints) && is.finite(ci$lower) && is.finite(ci$upper)) {
				row$p_at_ci_a <- cal_pval_at(inf_obj, task$method, ci$lower)
				row$p_at_ci_b <- cal_pval_at(inf_obj, task$method, ci$upper)
			}
			row$status <- if (is.finite(row$pval) || (is.finite(row$ci_a) && is.finite(row$ci_b))) "ok" else "nonestimable"
			row$message <- cal_clean_msg(ci$error %||% pv$error)
			row
		}), error = function(e) {
			row$message <- cal_clean_msg(conditionMessage(e))
			row
		})
		res$fit_secs <- round(proc.time()[["elapsed"]] - t0, 3L)
		res
	})
	rows <- Filter(Negate(is.null), rows)
	if (!length(rows)) return(NULL)
	do.call(rbind, lapply(rows, as.data.frame, stringsAsFactors = FALSE))
}

`%||%` <- function(a, b) if (is.null(a)) b else a

# One replicate for one response type: fresh X and w per design, y after w.
# `plan` comes from cal_class_plan(); `keep` (optional) restricts it to a class
# set. The seed covers (response type, n, rep, effect) so shards never collide.
cal_run_rep <- function(response_type, n, rep, plan, keep = NULL, effect = 0, endpoints = FALSE, alpha = CAL_ALPHA) {
	out <- list()
	for (design_name in names(plan)) {
		classes <- plan[[design_name]]
		if (!is.null(keep)) classes <- intersect(classes, keep)
		if (!length(classes)) next
		set.seed(1e6 * cal_rt_index(response_type) + 1e4 * (effect != 0) + 7L * n + rep)
		X <- cal_gen_X(n)
		des <- cal_new_design(design_name, response_type, n, X)
		do.call(des$add_all_subject_responses, cal_gen_y(response_type, X, des$get_w(), effect))
		tab <- cal_run_tasks(des, classes, alpha = alpha, endpoints = endpoints)
		if (is.null(tab)) next
		tab$response_type <- response_type
		tab$design <- design_name
		tab$n <- n
		tab$rep <- rep
		tab$effect <- effect
		out[[length(out) + 1L]] <- tab
	}
	if (!length(out)) return(NULL)
	do.call(rbind, out)
}
