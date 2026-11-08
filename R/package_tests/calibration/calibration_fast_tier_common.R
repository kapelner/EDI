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
# legitimately wrong because of misspecification. `dgp` picks a variant within
# the response type for classes whose model plain data would put on the edge of
# its parameter space (see cal_class_dgp()).
cal_gen_y <- function(response_type, X, w, effect = 0, dgp = "default") {
	n <- nrow(X)
	eta <- 0.5 * X$x1 + 0.5 * X$x2 + effect * w
	if (!identical(dgp, "default")) return(cal_gen_y_variant(dgp, X, eta))
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

# Zero-inflated mixture classes (InferenceCountZeroInflatedPoisson/NegBin) fit
# P(structural zero) = plogis(Xzi gamma) by default with the same formula as the
# count part. On plain Poisson counts the true pi is 0, i.e. gamma = -Inf: the MLE
# does not exist, the zi logits drift along a flat ridge and the nuisance
# information is numerically singular, so the score test depends on where the
# optimizer stopped (TODO-185, 2026-11-03). That is the boundary case, not the
# class's intended use, so these classes get data that ARE zero-inflated:
# structural zeros with pi = plogis(-1 + 0.5 x1) (about 0.28, independent of w,
# so the sharp null still holds and the count-part treatment effect is the
# only treatment effect) mixed with the class's own count family (Poisson, or
# NB with size 2). Hurdle classes are not listed: their zero part is a plain
# binary model of P(y = 0), which Poisson data identify.
CAL_DGP_BY_CLASS <- c(
	InferenceCountZeroInflatedPoisson = "count_zip",
	InferenceCountZeroInflatedNegBin = "count_zinb"
)

# Large-effect (sign-check) multiplier per dgp. CAL_SIGN_EFFECT is sized for the
# default data. Under count_zip/count_zinb about 28% of subjects are structural
# zeros (mean plogis(-1 + 0.5 x1) = 0.279), which carry no information about
# the count-part treatment effect, and the zi part adds nuisance parameters. The
# effect is scaled up by 1.25 >= 1 / sqrt(1 - 0.28) = 1.18 to restore the
# default's signal-to-noise, the same equal-information idea the pre-push check
# applies to prob_T via n. Without it the ZIP ~. replicate at prob_T = 0.2
# missed (CI [-0.01, 0.38]) on a fixed seed although ZIP is unbiased there
# (2026-11-06). Null replicates (effect = 0) are unaffected.
CAL_DGP_SIGN_EFFECT_SCALE <- c(count_zip = 1.25, count_zinb = 1.25)

cal_dgp_effect <- function(effect, dgp) {
	s <- unname(CAL_DGP_SIGN_EFFECT_SCALE[dgp])
	if (is.na(s)) effect else effect * s
}

cal_class_dgp <- function(inference_class) {
	d <- unname(CAL_DGP_BY_CLASS[inference_class])
	d[is.na(d)] <- "default"
	d
}

cal_gen_y_variant <- function(dgp, X, eta) {
	n <- nrow(X)
	mu <- exp(0.5 + 0.6 * eta)
	structural_zero <- stats::rbinom(n, 1L, stats::plogis(-1 + 0.5 * X$x1)) == 1L
	counts <- switch(dgp,
		count_zip = stats::rpois(n, mu),
		count_zinb = stats::rnbinom(n, size = 2, mu = mu),
		stop("unknown calibration dgp: ", dgp, call. = FALSE)
	)
	list(ys = ifelse(structural_zero, 0L, counts))
}

# Unequal-arm allocation (release_v1_0_5.md TODO-184): the scheduled fast tier
# also runs the iid classes under DesignFixedBernoulli at prob_T = CAL_UNEQUAL_PROB_T
# (Bernoulli has the design registry's supports_unequal_allocation capability). A
# plan entry named "<Design>@prob_T=<p>" runs that design at <p>; rows record the
# bare design name plus a prob_T column. Both the fast tier and the pre-push check
# include the cell.
CAL_UNEQUAL_PROB_T <- 0.2

# Canonical text form of prob_T for keys ("0.5", "0.2"); NA/missing means 0.5.
cal_prob_T_label <- function(x) {
	p <- suppressWarnings(as.numeric(x))
	if (!length(p)) return(character())
	p[is.na(p)] <- 0.5
	format(p, trim = TRUE)
}

cal_plan_entry <- function(label) {
	parts <- strsplit(label, "@prob_T=", fixed = TRUE)[[1L]]
	list(design = parts[[1L]], prob_T = if (length(parts) > 1L) as.numeric(parts[[2L]]) else 0.5)
}

cal_new_design <- function(design_name, response_type, n, X, prob_T = 0.5) {
	gen <- get(design_name, envir = asNamespace("EDI"))
	des <- if (isTRUE(prob_T == 0.5)) gen$new(n = n, response_type = response_type) else gen$new(n = n, response_type = response_type, prob_T = prob_T)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des
}

# Which classes run under which design for one response type: iid classes under
# Bernoulli, matched-pair-only classes under BinaryMatch. Computed from a
# throwaway design pair so it reflects the installed package's own registry.
cal_class_plan <- function(response_type, n = 200L, unequal = FALSE) {
	X <- cal_gen_X(n)
	iid <- EDI:::applicable_inference_class_names_for_design(cal_new_design("DesignFixedBernoulli", response_type, n, X))
	paired <- EDI:::applicable_inference_class_names_for_design(cal_new_design("DesignFixedBinaryMatch", response_type, n, X))
	plan <- list(DesignFixedBernoulli = sort(iid), DesignFixedBinaryMatch = sort(setdiff(paired, iid)))
	if (isTRUE(unequal)) {
		# Discovery at prob_T != 0.5 drops classes with requires_even_allocation.
		iid_unequal <- EDI:::applicable_inference_class_names_for_design(
			cal_new_design("DesignFixedBernoulli", response_type, n, X, prob_T = CAL_UNEQUAL_PROB_T))
		plan[[paste0("DesignFixedBernoulli@prob_T=", CAL_UNEQUAL_PROB_T)]] <- sort(iid_unequal)
	}
	plan
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
# method takes no `delta` or fails. A method whose formals are `...` (several
# likelihood-test wrappers) is called with `delta` too: it is forwarded to the
# test, and a wrapper that drops it shows up as an endpoint failure.
cal_pval_at <- function(inf_obj, method, delta) {
	nm <- cal_pval_method_name(method)
	if (is.na(nm) || !is.finite(delta)) return(NA_real_)
	f <- inf_obj[[nm]]
	if (!is.function(f) || !any(c("delta", "...") %in% names(formals(f)))) return(NA_real_)
	args <- list(delta = delta)
	if ("show_progress" %in% names(formals(f))) args$show_progress <- FALSE
	p <- tryCatch(suppressWarnings(do.call(f, args)), error = function(e) NA_real_)
	if (length(p) == 1L && is.finite(p)) as.numeric(p) else NA_real_
}

# TRUE when the class's CI for `method` is not the inversion of its own test:
# finalize_inverted_ci() returned the Wald interval because the inversion failed
# (recorded in cached_values$ci_fallback_reason, keyed by testing type). The
# endpoint check must not compare the method's p-value against those endpoints.
cal_ci_fell_back <- function(inf_obj, method) {
	if (identical(method, "wald")) return(FALSE)
	rec <- tryCatch(inf_obj$.__enclos_env__$private$cached_values$ci_fallback_reason, error = function(e) NULL)
	!is.null(rec) && method %in% names(rec)
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
		if (isTRUE(endpoints)) row$ci_fallback <- FALSE
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
			if (isTRUE(endpoints)) row$ci_fallback <- cal_ci_fell_back(inf_obj, task$method)
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
	for (plan_label in names(plan)) {
		entry <- cal_plan_entry(plan_label)
		design_name <- entry$design
		classes <- plan[[plan_label]]
		if (!is.null(keep)) classes <- intersect(classes, keep)
		if (!length(classes)) next
		# One design per data-generating process: the same seed rebuilds the same X
		# and w, so classes with a variant dgp see the same subjects and
		# assignment, and the default stream is unchanged by their presence.
		dgps <- cal_class_dgp(classes)
		tab <- NULL
		for (dgp in unique(c("default", dgps))) {
			dgp_classes <- classes[dgps == dgp]
			if (!length(dgp_classes)) next
			set.seed(1e6 * cal_rt_index(response_type) + 1e4 * (effect != 0) + 7L * n + rep)
			X <- cal_gen_X(n)
			des <- cal_new_design(design_name, response_type, n, X, prob_T = entry$prob_T)
			do.call(des$add_all_subject_responses, cal_gen_y(response_type, X, des$get_w(), cal_dgp_effect(effect, dgp), dgp = dgp))
			tab <- rbind(tab, cal_run_tasks(des, dgp_classes, alpha = alpha, endpoints = endpoints))
		}
		if (is.null(tab)) next
		tab$response_type <- response_type
		tab$design <- design_name
		tab$prob_T <- entry$prob_T
		tab$n <- n
		tab$rep <- rep
		tab$effect <- effect
		out[[length(out) + 1L]] <- tab
	}
	if (!length(out)) return(NULL)
	do.call(rbind, out)
}
