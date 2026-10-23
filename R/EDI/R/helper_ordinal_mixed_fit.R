# Session cache for ordinal_clmm_link_name(): one probe result per installed
# ordinal version.
EDI_ORDINAL_CLMM_LINK_NAME_CACHE = new.env(parent = emptyenv())

# v1.0.5 TODO-31 (bug_fix_plans/clmm_sigma_collapse_false_convergence.md,
# TODO-1, owner decision G6 #45 (ii)(a), 2026-10-22). ordinal::clmm (verified
# in ordinal 2026.7.26) fits the log-log model when asked for
# link = "cloglog" and the cloglog model when asked for link = "loglog";
# ordinal::clm is correct. EDI's "cloglog" is P(Y <= k) = 1 - exp(-exp(z)).
# This probe fits both clmm names on a fixed deterministic dataset (no RNG
# use) and evaluates the true-cloglog integrated likelihood at each fit with
# an independent stats::integrate() oracle. The clmm name whose -logLik
# matches the oracle (within 1e-3) is the name that really fits cloglog.
# Returns list(name, neg_loglik, oracle_nll); name is NA_character_ when the
# probe cannot decide (ordinal missing, a fit fails, or neither/both match).
ordinal_clmm_cloglog_link_probe = function(){
	out = list(name = NA_character_, neg_loglik = c(cloglog = NA_real_, loglog = NA_real_),
		oracle_nll = c(cloglog = NA_real_, loglog = NA_real_))
	if (!check_package_installed("ordinal")) return(out)
	G = 40L; m = 5L; n = G * m
	g = rep(seq_len(G), each = m)
	# Deterministic, RNG-free: normal-quantile random intercepts (sigma 1.5)
	# in a fixed scrambled order, golden-ratio "uniforms" for the response.
	b_g = 1.5 * stats::qnorm((seq_len(G) - 0.5) / G)[order((seq_len(G) * 0.6180339887498949) %% 1)]
	w = rep(c(0, 1, 0, 1, 0), G)
	x = sin(seq_len(n) * 1.3)
	u = (seq_len(n) * 0.7548776662466927 + 0.1) %% 1
	F_cloglog = function(z) -expm1(-exp(z))
	eta = 0.6 * w + 0.4 * x + b_g[g]
	cum = vapply(c(-1, 0, 1), function(t) F_cloglog(t - eta), numeric(n))
	y = 1L + rowSums(u > cum)
	dat = data.frame(y = ordered(y), w = w, x = x, g = factor(g))
	K = length(levels(dat$y))
	oracle = function(fit){
		cf = stats::coef(fit)
		th = unname(cf[seq_len(K - 1L)])
		eta_fit = drop(cbind(w, x) %*% unname(cf[c("w", "x")]))
		sig = fit$ST[[1L]][1L]
		if (!all(is.finite(c(th, eta_fit, sig))) || sig <= 0) return(NA_real_)
		up = c(th, Inf)[as.integer(dat$y)]; lo = c(-Inf, th)[as.integer(dat$y)]
		tot = 0
		for (gg in seq_len(G)) {
			ii = which(g == gg)
			f = function(bb) vapply(bb, function(b1) prod(
				F_cloglog(up[ii] - eta_fit[ii] - b1) - F_cloglog(lo[ii] - eta_fit[ii] - b1)
			), numeric(1L)) * stats::dnorm(bb, 0, sig)
			val = tryCatch(stats::integrate(f, -10 * sig, 10 * sig, rel.tol = 1e-10)$value, error = function(e) NA_real_)
			if (!is.finite(val) || val <= 0) return(NA_real_)
			tot = tot + log(val)
		}
		-tot
	}
	for (nm in c("cloglog", "loglog")) {
		fit = tryCatch({
			utils::capture.output(f <- suppressMessages(suppressWarnings(
				ordinal::clmm(y ~ w + x + (1 | g), data = dat, link = nm, nAGQ = 10L)
			)))
			f
		}, error = function(e) NULL)
		if (is.null(fit)) return(out)
		out$neg_loglik[[nm]] = -as.numeric(stats::logLik(fit))
		out$oracle_nll[[nm]] = oracle(fit)
	}
	match = is.finite(out$oracle_nll) & is.finite(out$neg_loglik) & abs(out$oracle_nll - out$neg_loglik) <= 1e-3
	if (sum(match) == 1L) out$name = names(out$oracle_nll)[match]
	out
}

# ordinal::clmm link name that fits the same model as EDI's `link`. Identity
# for logit/probit/cauchit (and any other link); for cloglog, the probed name
# (see ordinal_clmm_cloglog_link_probe), cached once per session and ordinal
# version so an upstream fix flips the mapping back automatically. NA for
# cloglog when the probe cannot decide; callers must then refuse rather than
# fit a mislabelled model.
ordinal_clmm_link_name = function(link){
	if (!identical(link, "cloglog")) return(link)
	ver = tryCatch(as.character(utils::packageVersion("ordinal")), error = function(e) "none")
	key = paste0("cloglog@", ver)
	if (!exists(key, envir = EDI_ORDINAL_CLMM_LINK_NAME_CACHE, inherits = FALSE)) {
		assign(key, ordinal_clmm_cloglog_link_probe()$name, envir = EDI_ORDINAL_CLMM_LINK_NAME_CACHE)
	}
	get(key, envir = EDI_ORDINAL_CLMM_LINK_NAME_CACHE, inherits = FALSE)
}

warn_ordinal_clmm_link_unverified = function(link){
	warning(structure(class = c("edi_clmm_link_unverified", "warning", "condition"), list(
		message = paste0("Could not verify which ordinal::clmm link name fits the '", link,
			"' model (see ordinal_clmm_link_name()); skipping the ordinal::clmm fit rather than ",
			"fitting a possibly mislabelled model."),
		call = NULL
	)))
}

# Internal weighted cumulative-link mixed-model refit shared by the ordinal
# KKGLMM and KKCLMM Bayesian-bootstrap paths.  The native ordinal kernels do
# not yet accept row weights; ordinal::clmm provides the matching conditional
# random-intercept estimand and supports all four links used by the CLMM family.
weighted_ordinal_random_intercept_fit = function(y, predictors_df, group_id,
		row_weights, link = "logit", nAGQ = 20L, estimate_only = TRUE){
	if (!check_package_installed("ordinal")) {
		return(list(beta = NA_real_, se = NA_real_, variance = NA_real_))
	}
	predictors_df = as.data.frame(predictors_df)
	ok = is.finite(row_weights) & row_weights > 0 & is.finite(as.numeric(y))
	if (!any(ok)) return(list(beta = NA_real_, se = NA_real_, variance = NA_real_))
	levels_y = sort(unique(y[ok]))
	if (length(levels_y) < 2L || !("w" %in% colnames(predictors_df))) {
		return(list(beta = NA_real_, se = NA_real_, variance = NA_real_))
	}
	dat = data.frame(
		y = ordered(y[ok], levels = levels_y),
		predictors_df[ok, , drop = FALSE],
		group_id = factor(group_id[ok]),
		.bootstrap_weight__ = as.numeric(row_weights[ok])
	)
	fixed_terms = setdiff(colnames(dat), c("y", "group_id", ".bootstrap_weight__"))
	# TODO-31 / G6 #45 (ii)(a): clmm's own name for this model (cloglog is
	# swapped upstream); the clm fallback below keeps EDI's name (clm is correct).
	clmm_link = ordinal_clmm_link_name(link)
	if (is.na(clmm_link)) {
		warn_ordinal_clmm_link_unverified(link)
		return(list(beta = NA_real_, se = NA_real_, variance = NA_real_))
	}
	form = stats::as.formula(paste(
		"y ~", paste(c(fixed_terms, "(1 | group_id)"), collapse = " + ")
	))
	fit_clmm = function(start = NULL, nAGQ_use = nAGQ){
		tryCatch({
			args = list(
				formula = form,
				data = dat,
				weights = dat$.bootstrap_weight__,
				link = clmm_link,
				nAGQ = as.integer(nAGQ_use),
				Hess = !estimate_only
			)
			if (!is.null(start)) args$start = start
			utils::capture.output(fit <- suppressMessages(suppressWarnings(
				do.call(ordinal::clmm, args)
			)))
			fit
		}, error = function(e) NULL)
	}
	mod = fit_clmm()
	if (is.null(mod)) {
		fixed_form = stats::as.formula(paste("y ~", paste(fixed_terms, collapse = " + ")))
		fixed_fit = tryCatch({
			utils::capture.output(fit <- suppressMessages(suppressWarnings(
				ordinal::clm(
					fixed_form, data = dat, weights = dat$.bootstrap_weight__,
					link = link, Hess = FALSE
				)
			)))
			fit
		}, error = function(e) NULL)
		if (!is.null(fixed_fit)) {
			candidates = lapply(c(-5, -3, -1, 0, 1), function(log_sigma){
				fit_clmm(c(stats::coef(fixed_fit), log_sigma))
			})
			candidates = Filter(Negate(is.null), candidates)
			if (length(candidates) > 0L) {
				loglik = vapply(candidates, function(fit){
					as.numeric(tryCatch(stats::logLik(fit), error = function(e) NA_real_))
				}, numeric(1L))
				if (any(is.finite(loglik))) mod = candidates[[which.max(loglik)]]
			}
		}
	}
	if (is.null(mod)) return(list(beta = NA_real_, se = NA_real_, variance = NA_real_))
	beta = suppressWarnings(as.numeric(stats::coef(mod)["w"]))
	if (!is.finite(beta)) return(list(beta = NA_real_, se = NA_real_, variance = NA_real_))
	get_variance = function(fit) tryCatch({
		v = stats::vcov(fit)["w", "w"]
		if (is.finite(v) && v > 0) as.numeric(v) else NA_real_
	}, error = function(e) NA_real_)
	variance = if (estimate_only) NA_real_ else get_variance(mod)
	if (!estimate_only && !is.finite(variance)) {
		# The point estimate converged, but the quadrature-based Hessian at
		# nAGQ=20 can be singular/ill-conditioned for some bootstrap-weight
		# draws. A coarser or finer quadrature grid, refit from the converged
		# coefficients, often yields a well-conditioned Hessian without
		# changing the point estimate; try a few before giving up.
		start = suppressWarnings(as.numeric(stats::coef(mod)))
		if (!any(is.finite(start))) start = NULL
		for (alt_nAGQ in c(7L, 11L, 15L, 1L)) {
			cand = fit_clmm(start = start, nAGQ_use = alt_nAGQ)
			if (is.null(cand)) next
			v = get_variance(cand)
			if (is.finite(v)) { variance = v; break }
		}
	}
	list(beta = beta, se = sqrt(variance), variance = variance)
}
