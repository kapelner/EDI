library(testthat)
library(EDI)

# InferenceIncidKKCondLogitGLMMOneLik / ...IVWC since v1.0.5 (TODO-173): conditional logit on the
# discordant matched pairs plus, for OneLik only, an ordinary logistic regression on the reservoir
# (unmatched) subjects, sharing beta_T and beta_x. Concordant pairs carry no information under a free
# pair effect and are not used. The class is checked against a reference assembled independently from
# the raw design data (pair differences for discordant pairs, raw rows for the reservoir) and fitted with
# stats::glm() as one logistic regression on the stacked rows, and IVWC is checked against
# survival's exact conditional logit on all matched pairs (concordant pairs included, which drop out on
# their own).

K <- function(x) get(x, envir = asNamespace("EDI"))

fx <- function(seed, design_formula = ~ .) {
	set.seed(seed)
	n <- 240L
	des <- DesignSeqOneByOneKK14$new(response_type = "incidence", n = n,
		design_formula = design_formula, verbose = FALSE)
	X <- data.frame(x = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	m <- des$.__enclos_env__$private$m[seq_len(n)]
	u <- ifelse(m > 0, rnorm(max(m))[pmax(m, 1)], 0) * 0.9
	y <- as.numeric(rbinom(n, 1, plogis(-0.3 + 0.8 * w + 0.4 * X$x + u)))
	des$add_all_subject_responses(y)
	d <- data.frame(y = y, w = w, x = X$x, m = m)
	pr <- d[d$m > 0, ]
	ids <- sort(unique(pr$m))
	is_disc <- vapply(ids, function(k) length(unique(pr$y[pr$m == k])) == 2L, logical(1))
	disc <- do.call(rbind, lapply(ids[is_disc], function(k) {
		a <- pr[pr$m == k, ]; t1 <- a[a$w == 1, ]; t0 <- a[a$w == 0, ]
		c(y = as.numeric(t1$y > t0$y), tw = 1, dx = t1$x - t0$x, m = k)
	}))
	cd <- d[d$m %in% ids[!is_disc] | d$m == 0, ]
	gid <- as.integer(factor(ifelse(cd$m > 0, paste0("p", cd$m), paste0("s", seq_len(nrow(cd))))))
	# Pair members adjacent (2026-11-03, TODO-173): the joint kernel forms its
	# random-intercept groups from runs of equal group id, so subject order split
	# most pairs into one-row groups (the bug this reference used to reproduce).
	ord <- order(gid, method = "radix")
	cd <- cd[ord, , drop = FALSE]
	gid <- gid[ord]
	list(des = des, d = d, disc = disc, cd = cd, gid = gid, n_disc = sum(is_disc), n_conc = sum(!is_disc))
}
# Independent reference: one logistic regression on stacked rows built from the raw data. A discordant
# pair is a row (no intercept, treatment 1, covariate difference) whose response is "the treated member
# is the success", weighted by the mean of its members' bootstrap weights; a reservoir subject is a row
# (intercept, w, x). Reservoir rows enter only when their outcomes vary (otherwise the intercept MLE is
# infinite and the reservoir carries no information about the coefficients).
ref_fit <- function(f, model_formula = ~ ., include_reservoir = TRUE, row_w = NULL) {
	include_x <- length(all.vars(model_formula)) > 0L
	d <- f$d
	if (is.null(row_w)) row_w <- rep(1, nrow(d))
	disc <- as.data.frame(f$disc)
	w_disc <- vapply(disc$m, function(k) mean(row_w[d$m == k]), numeric(1))
	rows <- data.frame(int = 0, tr = 1, x = disc$dx, y = disc$y, wt = w_disc)
	res <- d$m == 0 & row_w > 0
	use_res <- include_reservoir && any(res) && length(unique(d$y[res])) > 1L
	if (use_res) rows <- rbind(rows, data.frame(int = 1, tr = d$w[res], x = d$x[res], y = d$y[res], wt = row_w[res]))
	rows <- rows[rows$wt > 0, , drop = FALSE]
	rhs <- c("0", "tr", if (use_res) "int", if (include_x) "x")
	g <- suppressWarnings(glm(as.formula(paste("y ~", paste(rhs, collapse = " + "))), family = binomial(), data = rows, weights = wt))
	list(converged = isTRUE(g$converged), beta_T = unname(coef(g)[["tr"]]), se_T = sqrt(vcov(g)[["tr", "tr"]]), use_res = use_res)
}

fixed_intercept_match_fx <- function() {
	set.seed(7701L)
	n <- 80L
	m <- rep(seq_len(n / 2L), each = 2L)
	x <- rnorm(n)
	des <- DesignFixedBinaryMatch$new(
		response_type = "incidence", n = n, m = m,
		design_formula = ~ 1, verbose = FALSE
	)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	w <- rep(c(0, 1), n / 2L)
	des$assign_w_to_all_subjects(w_precomputed = w)

	# The first 20 pairs are discordant (12 favor treatment, 8 favor control);
	# the next 10 are concordant successes and the final 10 concordant failures.
	# All rows are explicitly paired, so this fixture has no zero-match/reservoir
	# fallback and exercises design_formula = ~1 with real matched observations.
	y <- numeric(n)
	for (pair in seq_len(n / 2L)) {
		rows <- which(m == pair)
		if (pair <= 20L) {
			y[rows] <- if (pair <= 12L) c(0, 1) else c(1, 0)
		} else if (pair <= 30L) {
			y[rows] <- 1
		}
	}
	des$add_all_subject_responses(y)

	pair_ids <- sort(unique(m))
	is_discordant <- vapply(pair_ids, function(pair) {
		length(unique(y[m == pair])) == 2L
	}, logical(1L))
	disc <- do.call(rbind, lapply(pair_ids[is_discordant], function(pair) {
		rows <- which(m == pair)
		treated <- rows[w[rows] == 1L]
		control <- rows[w[rows] == 0L]
		data.frame(y = as.numeric(y[treated] > y[control]), tw = 1,
			dx = x[treated] - x[control], m = pair)
	}))
	concordant_rows <- which(m %in% pair_ids[!is_discordant])
	# Members grouped by pair (2026-11-03, TODO-173): the joint kernel forms its
	# random-intercept groups from runs of equal group id, so a pair's rows must
	# be adjacent. Subject order split most pairs into one-row groups.
	concordant_rows <- concordant_rows[order(m[concordant_rows], method = "radix")]
	cd <- data.frame(y = y[concordant_rows], w = w[concordant_rows],
		x = x[concordant_rows], m = m[concordant_rows])
	gid <- as.integer(factor(cd$m))
	list(des = des, d = data.frame(y = y, w = w, x = x, m = m), disc = disc, cd = cd, gid = gid,
		n_disc = sum(is_discordant), n_conc = sum(!is_discordant))
}

test_that("the fixtures have discordant pairs, concordant pairs and a reservoir", {
	f <- fx(901L)
	expect_gt(f$n_disc, 20L); expect_gt(f$n_conc, 20L); expect_gt(sum(f$d$m == 0), 0L)
})

test_that("OneLik's estimate and standard error match the independent stacked logistic reference", {
	for (s in 901:906) {
		f <- fx(s)
		r <- ref_fit(f)
		inf <- K("InferenceIncidKKCondLogitGLMMOneLik")$new(f$des, verbose = FALSE)
		expect_true(r$converged, info = as.character(s))
		expect_true(r$use_res, info = as.character(s))
		expect_equal(unname(inf$compute_estimate()), r$beta_T, tolerance = 1e-6, info = as.character(s))
		expect_equal(inf$.__enclos_env__$private$get_standard_error(), r$se_T, tolerance = 1e-5, info = as.character(s))
	}
})

test_that("IVWC equals survival's exact conditional logit on all matched pairs (concordant pairs carry no information)", {
	skip_if_not_installed("survival")
	for (s in 901:903) {
		f <- fx(s)
		pr <- f$d[f$d$m > 0, ]
		# clogit()'s own exact conditional likelihood, called namespace-qualified (clogit()
		# evaluates an unqualified coxph() call, which fails unless survival is attached).
		cl <- survival::coxph(survival::Surv(rep(1, nrow(pr)), y) ~ w + x + survival::strata(m), data = pr, method = "exact")
		inf <- K("InferenceIncidKKCondLogitGLMMIVWC")$new(f$des, verbose = FALSE)
		expect_equal(unname(inf$compute_estimate()), unname(coef(cl)[["w"]]), tolerance = 1e-6, info = as.character(s))
		expect_equal(inf$.__enclos_env__$private$get_standard_error(), sqrt(vcov(cl)[["w", "w"]]), tolerance = 1e-5, info = as.character(s))
	}
})

test_that("the OneLik Bayesian bootstrap refits the same weighted likelihood", {
	f <- fx(903L)
	inf <- K("InferenceIncidKKCondLogitGLMMOneLik")$new(f$des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	priv$current_bayesian_bootstrap_context <- priv$build_bayesian_bootstrap_context()
	set.seed(9031L)
	block_w <- runif(priv$current_bayesian_bootstrap_context$n_units, 0.25, 2.5)
	row_w <- priv$expand_subject_or_block_weights_to_row_weights(block_w)
	actual <- inf$compute_estimate_with_bootstrap_weights(block_w, estimate_only = TRUE)
	r <- ref_fit(f, row_w = row_w)
	expect_true(r$converged)
	expect_equal(actual, r$beta_T, tolerance = 1e-6)
})

test_that("the IVWC Bayesian bootstrap matches the weighted reference and excludes reservoir rows", {
	f <- fx(903L)
	inf <- K("InferenceIncidKKCondLogitGLMMIVWC")$new(f$des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	priv$current_bayesian_bootstrap_context <- priv$build_bayesian_bootstrap_context()
	set.seed(9031L)
	block_w <- runif(priv$current_bayesian_bootstrap_context$n_units, 0.25, 2.5)
	row_w <- priv$expand_subject_or_block_weights_to_row_weights(block_w)
	dat <- priv$prepare_clogit_reservoir_logit_data()
	expect_gt(sum(f$d$m == 0L), 0L)
	expect_length(dat$i_res, 0L)
	actual <- inf$compute_estimate_with_bootstrap_weights(block_w, estimate_only = TRUE)
	r <- ref_fit(f, include_reservoir = FALSE, row_w = row_w)
	expect_true(is.finite(actual))
	expect_equal(actual, r$beta_T, tolerance = 1e-6)
})

test_that("OneLik and IVWC estimates match the independent reference across model formulas", {
	formula_pairs <- list(
		list(model_formula = ~ 1, design_formula = ~ .),
		list(model_formula = ~ ., design_formula = ~ .)
	)
	for (pair in formula_pairs) {
		f <- fx(907L, design_formula = pair$design_formula)
		for (class_name in c("InferenceIncidKKCondLogitGLMMOneLik", "InferenceIncidKKCondLogitGLMMIVWC")) {
			inf <- K(class_name)$new(f$des, model_formula = pair$model_formula, verbose = FALSE)
			r <- ref_fit(f, model_formula = pair$model_formula,
				include_reservoir = identical(class_name, "InferenceIncidKKCondLogitGLMMOneLik"))
			info <- paste(deparse(pair$model_formula), deparse(pair$design_formula), class_name)
			expect_true(r$converged, info = info)
			expect_equal(unname(inf$compute_estimate()), r$beta_T, tolerance = 1e-6, info = info)
		}
	}
})

test_that("OneLik and IVWC retain nonempty ~1-design matched-pair formula cases", {
	f <- fixed_intercept_match_fx()
	expect_equal(f$n_disc, 20L)
	expect_equal(f$n_conc, 20L)
	expect_gt(sd(f$disc[, "dx"]), 0)

	# `m` is explicit, so DesignFixedBinaryMatch does not call its matching
	# optimizer; every subject is paired, so there is no reservoir and both
	# classes reduce to conditional logit on the 20 discordant pairs.
	for (model_formula in list(~ 1, ~ .)) {
		for (class_name in c("InferenceIncidKKCondLogitGLMMOneLik", "InferenceIncidKKCondLogitGLMMIVWC")) {
			inf <- K(class_name)$new(f$des, model_formula = model_formula, verbose = FALSE)
			prepared <- inf$.__enclos_env__$private$prepare_clogit_reservoir_logit_data()
			expect_equal(nrow(prepared$X_disc), 20L)
			expect_length(prepared$y_res, 0L)
			if (length(all.vars(model_formula)) > 0L) expect_equal(ncol(prepared$X_disc), 2L)
			reference <- ref_fit(f, model_formula = model_formula,
				include_reservoir = identical(class_name, "InferenceIncidKKCondLogitGLMMOneLik"))
			info <- paste("model_formula", deparse(model_formula), "design_formula=~1", class_name)
			expect_true(reference$converged, info = info)
			expect_equal(unname(inf$compute_estimate()), reference$beta_T, tolerance = 1e-6, info = info)
		}
	}
})

test_that("the public Bayesian bootstrap distribution refits the weighted likelihood for every draw", {
	f <- fx(908L)
	seed <- 9081L
	inf <- K("InferenceIncidKKCondLogitGLMMOneLik")$new(f$des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	priv$seed <- seed

	# Recreate the public driver's seeded exchangeable-unit draws, then evaluate
	# each against the independent weighted reference rather than the class hook.
	had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
	if (had_seed) old_seed <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
	on.exit(if (had_seed) assign(".Random.seed", old_seed, envir = .GlobalEnv) else rm(".Random.seed", envir = .GlobalEnv), add = TRUE)
	set.seed(seed)
	draws <- priv$bayesian_bootstrap_sample_weight_draws(B = 2L)
	expected <- vapply(draws, function(draw) {
		priv$current_bayesian_bootstrap_context <- draw$context
		row_w <- priv$expand_subject_or_block_weights_to_row_weights(draw$subject_or_block_weights)
		r <- ref_fit(f, row_w = row_w)
		expect_true(r$converged)
		r$beta_T
	}, numeric(1))
	expect_true(all(vapply(draws, function(draw) {
		length(unique(draw$subject_or_block_weights)) > 1L
	}, logical(1))))

	actual_debug <- inf$approximate_bayesian_bootstrap_distribution_beta_hat_T(
		B = 2L, show_progress = FALSE, debug = TRUE
	)
	expect_equal(length(actual_debug$values), 2L)
	expect_identical(actual_debug$num_errors, c(0L, 0L))
	expect_equal(actual_debug$values, expected, tolerance = 1e-6)

	# A fresh object avoids returning the debug result from the shared distribution
	# cache; this call exercises the ordinary public distribution driver.
	inf_standard <- K("InferenceIncidKKCondLogitGLMMOneLik")$new(f$des, verbose = FALSE)
	inf_standard$.__enclos_env__$private$seed <- seed
	actual_standard <- inf_standard$approximate_bayesian_bootstrap_distribution_beta_hat_T(
		B = 2L, show_progress = FALSE, debug = FALSE
	)
	expect_equal(length(actual_standard), 2L)
	expect_true(all(is.finite(actual_standard)))
	expect_equal(actual_standard, expected, tolerance = 1e-6)
})
