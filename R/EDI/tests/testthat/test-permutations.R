test_that("Different designs work with continuous response", {
	n <- 20
	designs <- list(
	Bernoulli = DesignSeqOneByOneBernoulli$new(response_type = "continuous", n = n),
	Efron = DesignSeqOneByOneEfron$new(response_type = "continuous", n = n),
	Atkinson = DesignSeqOneByOneAtkinson$new(response_type = "continuous", n = n),
	iBCRD = DesignSeqOneByOneiBCRD$new(response_type = "continuous", n = n),
	KK14 = DesignSeqOneByOneKK14$new(response_type = "continuous", n = n),
	KK21 = DesignSeqOneByOneKK21$new(response_type = "continuous", n = n),
	KK21stepwise = DesignSeqOneByOneKK21stepwise$new(response_type = "continuous", n = n)
	)

	for (name in names(designs)) {
	des <- designs[[name]]
	set.seed(1)
	for (i in 1:n) {
		des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1), x2 = rnorm(1)))
	}
	add_all_subject_responses_seq(des, rnorm(n))

	# Check if we can run a simple inference
	inf <- InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
	expect_true(is.numeric(inf$compute_estimate()), info = paste("Design:", name))
	}
})

test_that("KK14 with Morrison works", {
	n <- 20
	p <- 2
	des <- DesignSeqOneByOneKK14$new(response_type = "continuous", n = n, morrison = TRUE, p = p)
	set.seed(1)
	for (i in 1:n) {
	des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1), x2 = rnorm(1)))
	}
	add_all_subject_responses_seq(des, rnorm(n))

	inf <- InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
	expect_true(is.numeric(inf$compute_estimate()))
})

test_that("Multivariate inference works", {
	n <- 40
	des <- DesignSeqOneByOneBernoulli$new(response_type = "continuous", n = n)
	set.seed(1)
	X <- data.frame(x1 = rnorm(n), x2 = rnorm(n))
	for (i in 1:n) {
	des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	}
	add_all_subject_responses_seq(des, rnorm(n))

	# Continuous MultOLS
	inf_cont <- InferenceContinOLS$new(des, verbose = FALSE)
	expect_true(is.numeric(inf_cont$compute_estimate()))

	# Incidence MultiLogRegr
	des_inc <- DesignSeqOneByOneBernoulli$new(n = n, response_type = "incidence")
	for (i in 1:n) {
	des_inc$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	}
	add_all_subject_responses_seq(des_inc, rbinom(n, 1, 0.5))
	inf_inc <- InferenceIncidLogRegr$new(des_inc, verbose = FALSE)
	expect_true(is.numeric(inf_inc$compute_estimate()))

	# Count MultiNegBinRegr
	des_count <- DesignSeqOneByOneBernoulli$new(n = n, response_type = "count")
	for (i in 1:n) {
	des_count$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	}
	add_all_subject_responses_seq(des_count, rpois(n, 5))
	inf_count <- InferenceCountNegBin$new(des_count, verbose = FALSE)
	expect_true(is.numeric(inf_count$compute_estimate()))
})

test_that("Generated permutations support randomization p-values", {
	n <- 30
	des <- DesignSeqOneByOneBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	set.seed(1)
	for (i in 1:n) {
		des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1), x2 = rnorm(1)))
	}
	add_all_subject_responses_seq(des, rnorm(n))

	inf <- InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
	perms <- inf$.__enclos_env__$private$generate_permutations(64)

	expect_true(is.list(perms))
	expect_true(!is.null(perms$w_mat))

	pval <- inf$compute_rand_two_sided_pval(
		r = 64,
		show_progress = FALSE,
		permutations = perms
	)
	expect_true(is.numeric(pval))
	expect_true(is.finite(pval))
	expect_true(pval >= 0 && pval <= 1)
})

test_that("KK21 stepwise randomization draws replay outcome-adaptive matching when not conditioning on ws", {
	set.seed(5301)
	n <- 48L
	x <- data.frame(x1 = rnorm(n))
	y_by_type <- list(
		incidence = rbinom(n, 1, plogis(-0.3 + 0.5 * x$x1)),
		continuous = 0.5 * x$x1 + rnorm(n),
		count = rpois(n, exp(0.2 + 0.3 * x$x1))
	)

	for (response_type in names(y_by_type)) {
		des <- DesignSeqOneByOneKK21stepwise$new(
			n = n, response_type = response_type, num_boot = 20L, verbose = FALSE,
			condition_on_ws_for_rand_tests = FALSE
		)
		for (i in seq_len(n)) {
			des$add_one_subject_to_experiment_and_assign(x[i, , drop = FALSE])
			des$add_one_subject_response(i, y = y_by_type[[response_type]][i])
		}
		priv <- des$.__enclos_env__$private
		state <- list(
			t = priv$t, w = priv$w, m = priv$m, y = priv$y,
			y_L = priv$y_L, y_R = priv$y_R,
			covariate_weights = priv$covariate_weights,
			iteration_weights = priv$iteration_weights
		)
		observed_pairs <- split(which(priv$m > 0), priv$m[priv$m > 0])
		expect_true(any(lengths(observed_pairs) == 2L), info = response_type)

		set.seed(5302)
		draws <- des$draw_ws_according_to_design(40L)
		expect_equal(dim(draws), c(n, 40L), info = response_type)
		expect_true(all(draws %in% 0:1), info = response_type)
		# The inherited KK14 implementation conditioned every draw on the one
		# realized pair structure, forcing each observed pair to remain opposite.
		# KK21 weights depend on earlier outcomes/assignments, so faithful replay
		# must allow at least one realized pair to cease being a pair in another draw.
		pair_opposite_in_every_draw <- vapply(
			observed_pairs[lengths(observed_pairs) == 2L],
			function(ii) all(colSums(draws[ii, , drop = FALSE]) == 1),
			logical(1)
		)
		expect_false(all(pair_opposite_in_every_draw), info = response_type)

		expect_identical(priv$t, state$t, info = response_type)
		expect_identical(priv$w, state$w, info = response_type)
		expect_identical(priv$m, state$m, info = response_type)
		expect_identical(priv$y, state$y, info = response_type)
		expect_identical(priv$y_L, state$y_L, info = response_type)
		expect_identical(priv$y_R, state$y_R, info = response_type)
		expect_identical(priv$covariate_weights, state$covariate_weights, info = response_type)
		expect_identical(priv$iteration_weights, state$iteration_weights, info = response_type)
	}
})

test_that("KK21 randomization draws condition on the realized pairs", {
	set.seed(5303)
	n <- 48L
	x <- data.frame(x1 = rnorm(n))
	y <- 0.5 * x$x1 + rnorm(n)
	des <- DesignSeqOneByOneKK21$new(n = n, response_type = "continuous", num_boot = 20L, verbose = FALSE)
	for (i in seq_len(n)) {
		des$add_one_subject_to_experiment_and_assign(x[i, , drop = FALSE])
		des$add_one_subject_response(i, y = y[i])
	}
	m <- des$.__enclos_env__$private$m
	observed_pairs <- split(which(m > 0), m[m > 0])
	expect_true(length(observed_pairs) > 0L)

	draws <- des$draw_ws_according_to_design(40L)
	expect_equal(dim(draws), c(n, 40L))
	expect_true(all(draws %in% 0:1))
	# KK21's marginal weights do not depend on w, so under the sharp null the
	# realized pairs are invariant and every draw keeps each pair opposite.
	for (ii in observed_pairs) {
		expect_true(all(colSums(draws[ii, , drop = FALSE]) == 1))
	}
	# reservoir subjects are still randomized independently
	expect_true(any(apply(draws[m == 0, , drop = FALSE], 1, function(z) length(unique(z)) > 1)))
})

test_that("KK21 stepwise randomization draws condition on the realized pairs by default", {
	set.seed(5304)
	n <- 48L
	x <- data.frame(x1 = rnorm(n))
	y <- 0.5 * x$x1 + rnorm(n)
	des <- DesignSeqOneByOneKK21stepwise$new(n = n, response_type = "continuous", num_boot = 20L, verbose = FALSE)
	for (i in seq_len(n)) {
		des$add_one_subject_to_experiment_and_assign(x[i, , drop = FALSE])
		des$add_one_subject_response(i, y = y[i])
	}
	m <- des$.__enclos_env__$private$m
	observed_pairs <- split(which(m > 0), m[m > 0])
	expect_true(length(observed_pairs) > 0L)

	draws <- des$draw_ws_according_to_design(40L)
	expect_equal(dim(draws), c(n, 40L))
	expect_true(all(draws %in% 0:1))
	for (ii in observed_pairs) {
		expect_true(all(colSums(draws[ii, , drop = FALSE]) == 1))
	}
	expect_true(any(apply(draws[m == 0, , drop = FALSE], 1, function(z) length(unique(z)) > 1)))
	expect_identical(des$.__enclos_env__$private$m, m)
})

test_that("KK designs with KK inference work", {
	n <- 30
	designs <- list(
	KK14 = DesignSeqOneByOneKK14$new(response_type = "continuous", n = n),
	KK21 = DesignSeqOneByOneKK21$new(response_type = "continuous", n = n),
	KK21stepwise = DesignSeqOneByOneKK21stepwise$new(response_type = "continuous", n = n)
	)

	inf_classes <- list(
	KK14 = InferenceBaiAdjustedTKK14,
	KK21 = InferenceBaiAdjustedTKK21,
	KK21stepwise = InferenceBaiAdjustedTKK21
	)

	for (name in names(designs)) {
	des <- designs[[name]]
	set.seed(1)
	for (i in 1:n) {
		des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1), x2 = rnorm(1)))
	}
	add_all_subject_responses_seq(des, rnorm(n))

	inf <- inf_classes[[name]]$new(des, verbose = FALSE)
	expect_true(is.numeric(inf$compute_estimate()), info = paste("KK Design/Inf:", name))
	}
})

test_that("Debug randomization does not poison the cached p-value path", {
	n <- 24
	des <- DesignSeqOneByOneBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	set.seed(11)
	for (i in 1:n) {
		des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1), x2 = rnorm(1)))
	}
	add_all_subject_responses_seq(des, rnorm(n))

	inf <- InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
	perms <- inf$.__enclos_env__$private$generate_permutations(32)

	debug_rand <- inf$approximate_randomization_distribution_beta_hat_T(
		r = 32,
		show_progress = FALSE,
		permutations = perms,
		debug = TRUE
	)
	pval_after_debug <- inf$compute_rand_two_sided_pval(
		r = 32,
		show_progress = FALSE,
		permutations = perms
	)

	inf_fresh <- InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
	pval_fresh <- inf_fresh$compute_rand_two_sided_pval(
		r = 32,
		show_progress = FALSE,
		permutations = perms
	)

	expect_true(is.list(debug_rand))
	expect_true(all(is.finite(debug_rand$values)))
	expect_true(is.numeric(pval_after_debug))
	expect_true(is.finite(pval_after_debug))
	expect_true(pval_after_debug >= 0 && pval_after_debug <= 1)
	expect_equal(pval_after_debug, pval_fresh, tolerance = 1e-12)
})



test_that("Fast randomization worker does not mutate shared proportion design state", {
	skip_if_not_installed("betareg")
	n <- 30
	des <- DesignSeqOneByOneBernoulli$new(n = n, response_type = "proportion", verbose = FALSE)
	set.seed(19)
	X <- data.frame(x1 = rnorm(n), x2 = rnorm(n))
	for (i in 1:n) {
		des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	}
	y <- pmin(0.98, pmax(0.02, plogis(0.5 * X$x1 - 0.3 * X$x2 + rnorm(n, sd = 0.2))))
	add_all_subject_responses_seq(des, y)

	inf <- InferencePropBetaRegr$new(des, verbose = FALSE)
	perms <- inf$.__enclos_env__$private$generate_permutations(19)
	y_before <- des$.__enclos_env__$private$y

	pval <- inf$compute_rand_two_sided_pval(
		r = 19,
		delta = 0.5,
		transform_responses = "logit",
		show_progress = FALSE,
		permutations = perms
	)
	y_after <- des$.__enclos_env__$private$y

	expect_true(is.numeric(pval))
	expect_true(is.finite(pval))
	expect_equal(as.numeric(y_after), as.numeric(y_before), tolerance = 0)
	expect_true(all(y_after >= 0 & y_after <= 1))
})
