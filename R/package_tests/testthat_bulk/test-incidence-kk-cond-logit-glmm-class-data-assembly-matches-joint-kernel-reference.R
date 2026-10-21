library(testthat)
library(EDI)

# InferenceIncidKKCondLogitGLMMOneLik: the joint conditional-logit (discordant pairs) + random-intercept
# logistic GLMM (concordant pairs and reservoir subjects) estimator. The class' data assembly is checked by
# building the same three blocks independently from the design (discordant pair differences, concordant pair
# members grouped by pair, reservoir singletons) and fitting fast_clogit_plus_glmm_cpp directly: the treatment
# coefficients agree across simulated datasets, the class uses L-BFGS (so no Newton sigma collapse), and the
# fitted random-effect scale is finite and moderate.

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
		c(y = as.numeric(t1$y > t0$y), tw = 1, dx = t1$x - t0$x)
	}))
	cd <- d[d$m %in% ids[!is_disc] | d$m == 0, ]
	gid <- as.integer(factor(ifelse(cd$m > 0, paste0("p", cd$m), paste0("s", seq_len(nrow(cd))))))
	list(des = des, disc = disc, cd = cd, gid = gid, n_disc = sum(is_disc), n_conc = sum(!is_disc))
}
joint <- function(f, model_formula = ~ ., include_reservoir = TRUE) {
	include_x <- length(all.vars(model_formula)) > 0L
	cd <- if (include_reservoir) f$cd else f$cd[f$cd$m > 0L, , drop = FALSE]
	gid <- if (include_reservoir) f$gid else as.integer(factor(cd$m))
	X_disc <- if (include_x) cbind(f$disc[, "tw"], f$disc[, "dx"]) else matrix(f$disc[, "tw"], ncol = 1L)
	X_conc <- if (include_x) cbind(1, cd$w, cd$x) else cbind(1, cd$w)
	K("fast_clogit_plus_glmm_cpp")(X_disc, as.numeric(f$disc[, "y"]),
		X_conc, as.numeric(cd$y), gid, nrow(f$disc) > 0L, nrow(cd) > 0L)
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
			dx = x[treated] - x[control])
	}))
	concordant_rows <- which(m %in% pair_ids[!is_discordant])
	cd <- data.frame(y = y[concordant_rows], w = w[concordant_rows],
		x = x[concordant_rows], m = m[concordant_rows])
	gid <- as.integer(factor(cd$m))
	list(des = des, disc = disc, cd = cd, gid = gid,
		n_disc = sum(is_discordant), n_conc = sum(!is_discordant))
}

test_that("the fixtures have discordant pairs, concordant pairs and a reservoir", {
	f <- fx(901L)
	expect_gt(f$n_disc, 20L); expect_gt(f$n_conc, 20L); expect_gt(sum(f$cd$m == 0), 0L)
})

test_that("the class treatment coefficient agrees with the joint kernel fitted on independently assembled blocks", {
	for (s in 901:906) {
		f <- fx(s)
		r <- joint(f)
		inf <- K("InferenceIncidKKCondLogitGLMMOneLik")$new(f$des, verbose = FALSE)
		expect_true(r$converged, info = as.character(s))
		expect_equal(unname(inf$compute_estimate()), as.numeric(r$params)[2], tolerance = 3e-2, scale = 1, info = as.character(s))
		expect_identical(inf$.__enclos_env__$private$optimization_alg, "lbfgs")
	}
})

test_that("neither the kernel nor the class collapses the random-effect scale to the lower boundary", {
	f <- fx(902L)
	r <- joint(f)
	expect_gt(as.numeric(r$params)[4], -2.5)
	inf <- K("InferenceIncidKKCondLogitGLMMOneLik")$new(f$des, verbose = FALSE)
	inf$compute_estimate()
	expect_gt(as.numeric(inf$.__enclos_env__$private$cached_mod$params)[4], -2.5)
})

test_that("the Bayesian bootstrap refits the weighted joint likelihood, not an all-row Laplace GLMM", {
	f <- fx(903L)
	inf <- K("InferenceIncidKKCondLogitGLMMOneLik")$new(f$des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	priv$current_bayesian_bootstrap_context <- priv$build_bayesian_bootstrap_context()
	set.seed(9031L)
	block_w <- runif(priv$current_bayesian_bootstrap_context$n_units, 0.25, 2.5)
	row_w <- priv$expand_subject_or_block_weights_to_row_weights(block_w)

	actual <- inf$compute_estimate_with_bootstrap_weights(block_w, estimate_only = TRUE)
	d <- priv$prepare_clogit_plus_glmm_data()
	m <- priv$m
	disc_w <- vapply(d$i_m_disc, function(pair_id) mean(row_w[m == pair_id]), numeric(1))
	conc_w <- row_w[d$i_glmm]
	expected <- K("fast_clogit_plus_glmm_cpp")(
		d$X_disc, d$y_disc, d$X_conc, d$y_conc, d$group_conc,
		d$has_discordant, d$has_concordant,
		estimate_only = TRUE, weights_disc = disc_w, weights_conc = conc_w
	)
	expect_true(expected$converged)
	expect_equal(actual, as.numeric(expected$params)[2L], tolerance = 1e-8)
})

test_that("the IVWC Bayesian bootstrap matches the weighted joint kernel and excludes reservoir rows", {
	f <- fx(903L)
	inf <- K("InferenceIncidKKCondLogitGLMMIVWC")$new(f$des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	priv$current_bayesian_bootstrap_context <- priv$build_bayesian_bootstrap_context()
	set.seed(9031L)
	block_w <- runif(priv$current_bayesian_bootstrap_context$n_units, 0.25, 2.5)
	row_w <- priv$expand_subject_or_block_weights_to_row_weights(block_w)

	d <- priv$prepare_clogit_plus_glmm_data()
	m <- priv$m
	expect_gt(sum(m == 0L), 0L)
	expect_gt(length(d$i_glmm), 0L)
	expect_true(all(m[d$i_glmm] > 0L))
	disc_w <- vapply(d$i_m_disc, function(pair_id) mean(row_w[m == pair_id]), numeric(1))
	conc_w <- row_w[d$i_glmm]
	expected <- K("fast_clogit_plus_glmm_cpp")(
		d$X_disc, d$y_disc, d$X_conc, d$y_conc, d$group_conc,
		d$has_discordant, d$has_concordant,
		estimate_only = TRUE, weights_disc = disc_w, weights_conc = conc_w
	)
	actual <- inf$compute_estimate_with_bootstrap_weights(block_w, estimate_only = TRUE)

	expect_true(expected$converged)
	expect_true(is.finite(actual))
	expect_equal(actual, as.numeric(expected$params)[2L], tolerance = 1e-8)
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
			r <- joint(f, model_formula = pair$model_formula,
				include_reservoir = identical(class_name, "InferenceIncidKKCondLogitGLMMOneLik"))
			actual <- inf$compute_estimate()
			info <- paste(deparse(pair$model_formula), deparse(pair$design_formula), class_name)

			expect_true(r$converged, info = info)
			expect_equal(unname(actual), as.numeric(r$params)[2L], tolerance = 3e-2,
				info = paste(deparse(pair$model_formula), deparse(pair$design_formula), class_name))
		}
	}
})

test_that("OneLik and IVWC retain nonempty ~1-design matched-pair formula cases", {
	f <- fixed_intercept_match_fx()
	expect_equal(f$n_disc, 20L)
	expect_equal(f$n_conc, 20L)
	expect_equal(nrow(f$cd), 40L)
	expect_true(all(table(f$cd$m) == 2L))
	expect_gt(sd(f$disc[, "dx"]), 0)

	# `m` is explicit, so DesignFixedBinaryMatch does not call its matching
	# optimizer. Confirm both class-specific blocks are nonempty before fitting;
	# this guard keeps the known zero-match native path out of this regression.
	for (model_formula in list(~ 1, ~ .)) {
		for (class_name in c("InferenceIncidKKCondLogitGLMMOneLik", "InferenceIncidKKCondLogitGLMMIVWC")) {
			inf <- K(class_name)$new(f$des, model_formula = model_formula, verbose = FALSE)
			prepared <- inf$.__enclos_env__$private$prepare_clogit_plus_glmm_data()
			expect_equal(nrow(prepared$X_disc), 20L)
			expect_equal(nrow(prepared$X_conc), 40L)
			if (length(all.vars(model_formula)) > 0L) {
				expect_equal(ncol(prepared$X_disc), 2L)
				expect_equal(ncol(prepared$X_conc), 3L)
			}

			reference <- joint(f, model_formula = model_formula,
				include_reservoir = identical(class_name, "InferenceIncidKKCondLogitGLMMOneLik"))
			actual <- inf$compute_estimate()
			info <- paste("model_formula", deparse(model_formula), "design_formula=~1", class_name)
			expect_true(reference$converged, info = info)
			expect_equal(unname(actual), as.numeric(reference$params)[2L],
				tolerance = 3e-2, info = info)
		}
	}
})

test_that("the public Bayesian bootstrap distribution uses the weighted joint kernel for every draw", {
	f <- fx(908L)
	seed <- 9081L
	inf <- K("InferenceIncidKKCondLogitGLMMOneLik")$new(f$des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	priv$seed <- seed

	# Recreate the public driver's seeded exchangeable-unit draws, then evaluate
	# each against the weighted joint native kernel rather than the class hook.
	had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
	if (had_seed) old_seed <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
	on.exit(if (had_seed) assign(".Random.seed", old_seed, envir = .GlobalEnv) else rm(".Random.seed", envir = .GlobalEnv), add = TRUE)
	set.seed(seed)
	draws <- priv$bayesian_bootstrap_sample_weight_draws(B = 2L)
	d <- priv$prepare_clogit_plus_glmm_data()
	m <- priv$m
	expected <- vapply(draws, function(draw) {
		priv$current_bayesian_bootstrap_context <- draw$context
		row_w <- priv$expand_subject_or_block_weights_to_row_weights(draw$subject_or_block_weights)
		disc_w <- vapply(d$i_m_disc, function(pair_id) mean(row_w[m == pair_id]), numeric(1))
		conc_w <- row_w[d$i_glmm]
		r <- K("fast_clogit_plus_glmm_cpp")(
			d$X_disc, d$y_disc, d$X_conc, d$y_conc, d$group_conc,
			d$has_discordant, d$has_concordant,
			estimate_only = TRUE, weights_disc = disc_w, weights_conc = conc_w
		)
		expect_true(r$converged)
		as.numeric(r$params)[2L]
	}, numeric(1))
	expect_gt(length(d$i_m_disc), 0L)
	expect_gt(length(d$i_glmm), 0L)
	expect_true(all(vapply(draws, function(draw) {
		length(unique(draw$subject_or_block_weights)) > 1L
	}, logical(1))))

	actual_debug <- inf$approximate_bayesian_bootstrap_distribution_beta_hat_T(
		B = 2L, show_progress = FALSE, debug = TRUE
	)
	expect_equal(length(actual_debug$values), 2L)
	expect_identical(actual_debug$num_errors, c(0L, 0L))
	expect_equal(actual_debug$values, expected, tolerance = 1e-8)

	# A fresh object avoids returning the debug result from the shared distribution
	# cache; this call exercises the ordinary public distribution driver.
	inf_standard <- K("InferenceIncidKKCondLogitGLMMOneLik")$new(f$des, verbose = FALSE)
	inf_standard$.__enclos_env__$private$seed <- seed
	actual_standard <- inf_standard$approximate_bayesian_bootstrap_distribution_beta_hat_T(
		B = 2L, show_progress = FALSE, debug = FALSE
	)
	expect_equal(length(actual_standard), 2L)
	expect_true(all(is.finite(actual_standard)))
	expect_equal(actual_standard, expected, tolerance = 1e-8)
})
