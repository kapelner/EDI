library(testthat)
library(EDI)

# DesignSeqOneByOnePocockSimon's private stratum-level bookkeeping
# (ensure_factor_metadata / get_subject_levels_idx) and
# DesignFixedBinaryMatch's set_binary_match_structure_from_m(). None had a
# direct test reference. Expectations are written out by hand from the
# documented level-to-row mapping and pair definition.

pocock_priv <- function(X, n = 20L) {
	des <- DesignSeqOneByOnePocockSimon$new(strata_cols = c("g", "h"), response_type = "continuous", n = n, verbose = FALSE)
	priv <- des$.__enclos_env__$private
	priv$Xraw <- data.table::as.data.table(X)
	priv$t <- nrow(X)
	list(des = des, priv = priv)
}

test_that("with every level visible at once, levels get consecutive unique rows across columns", {
	f <- pocock_priv(data.frame(g = c("a", "b", "a", "b"), h = c("u", "v", "w", "u")))
	f$priv$ensure_factor_metadata()
	expect_equal(unname(f$priv$strata_level_rows$g), c(1L, 2L))
	expect_equal(unname(f$priv$strata_level_rows$h), c(3L, 4L, 5L))
	expect_equal(f$priv$num_levels_total, 5L)
	expect_false(anyDuplicated(unlist(f$priv$strata_level_rows, use.names = FALSE)) > 0L)

	expect_equal(f$priv$get_subject_levels_idx(list(g = "b", h = "w")), c(g = 2L, h = 5L))
	expect_equal(f$priv$get_subject_levels_idx(list(g = "a", h = "u")), c(g = 1L, h = 3L))
})

test_that("missing covariate values have a level distinct from a literal NA category", {
	f <- pocock_priv(data.frame(g = c("a", NA, "NA", NA), h = c("u", "v", "u", "v"), stringsAsFactors = FALSE))
	f$priv$ensure_factor_metadata()
	missing_idx <- f$priv$get_subject_levels_idx(list(g = NA, h = "v"))
	literal_idx <- f$priv$get_subject_levels_idx(list(g = "NA", h = "v"))
	expect_false(identical(unname(missing_idx["g"]), unname(literal_idx["g"])))
	expect_equal(length(f$priv$strata_level_rows$g), 3L)
})

test_that("a first-arrival missing stratum is retained and differs from a literal NA level", {
	des <- DesignSeqOneByOnePocockSimon$new(
		strata_cols = c("g", "h"), response_type = "continuous", n = 2L,
		seed = 603L, verbose = FALSE
	)
	priv <- des$.__enclos_env__$private
	expect_silent(des$add_one_subject_to_experiment_and_assign(data.frame(
		g = factor(NA, levels = c("a", "NA")),
		h = factor("u", levels = c("u", "v"))
	)))
	expect_silent(des$add_one_subject_to_experiment_and_assign(data.frame(
		g = factor("NA", levels = c("a", "NA")),
		h = factor("v", levels = c("u", "v"))
	)))
	expect_equal(nrow(des$get_X_raw()), 2L)
	expect_true(is.na(des$get_X_raw()$g[[1L]]))
	expect_identical(as.character(des$get_X_raw()$g[[2L]]), "NA")
	expect_false(identical(
		unname(priv$get_subject_levels_idx(1L)["g"]),
		unname(priv$get_subject_levels_idx(2L)["g"])
	))
})

test_that("an existing counts matrix is expanded (not reset) when new levels appear", {
	f <- pocock_priv(data.frame(g = c("a", "b"), h = c("u", "v")))
	f$priv$counts <- matrix(c(1, 2, 3, 4), nrow = 2)
	f$priv$ensure_factor_metadata()
	expect_equal(f$priv$num_levels_total, 4L)
	expect_equal(dim(f$priv$counts), c(4L, 2L))
	expect_equal(f$priv$counts[1:2, ], matrix(c(1, 2, 3, 4), nrow = 2))
	expect_true(all(f$priv$counts[3:4, ] == 0))
})

test_that("an unseen level raises the friendly unknown-level error", {
	f <- pocock_priv(data.frame(g = c("a", "b"), h = c("u", "v")))
	expect_error(f$priv$get_subject_levels_idx(list(g = "zz", h = "u")), "Unknown strata level encountered for Pocock-Simon column g: zz")
	expect_error(f$priv$get_subject_levels_idx(list(g = "a", h = "nope")), "column h: nope")
})

test_that("sequential arrival gives every level of every column its own stable counts row", {
	des <- DesignSeqOneByOnePocockSimon$new(strata_cols = c("g", "h"), response_type = "continuous", n = 20L, verbose = FALSE)
	priv <- des$.__enclos_env__$private
	seen <- list()
	for (i in 1:6) {
		des$add_one_subject_to_experiment_and_assign(
			data.frame(g = c("a", "b")[1 + (i %% 2)], h = c("u", "v", "w")[1 + (i %% 3)])
		)
		seen[[i]] <- priv$strata_level_rows
	}
	expect_equal(priv$num_levels_total, 5L)
	expect_equal(dim(priv$counts), c(5L, 2L))
	expect_equal(unname(priv$strata_level_rows$g), c(1L, 3L))
	expect_equal(unname(priv$strata_level_rows$h), c(2L, 4L, 5L))
	expect_false(anyDuplicated(unlist(priv$strata_level_rows, use.names = FALSE)) > 0L)
	# Rows assigned earlier never move when later levels are discovered.
	for (i in 2:6) for (col in c("g", "h")) {
		old <- seen[[i - 1]][[col]]
		expect_equal(seen[[i]][[col]][names(old)], old)
	}
	# Counts total one entry per subject per column, spread over the per-level rows.
	expect_equal(sum(priv$counts), 12)
	expect_equal(sum(priv$counts[c(1, 3), ]), 6)
	expect_equal(sum(priv$counts[c(2, 4, 5), ]), 6)
})

test_that("Pocock-Simon preallocates rows, registers levels incrementally, and defers the model matrix", {
	X <- data.frame(
		g = factor(c("a", "a", "b", "a", NA, "c", "b", "c"), levels = c("a", "b", "c")),
		h = factor(c("u", "v", "u", "v", "u", "w", NA, "w"), levels = c("u", "v", "w"))
	)
	des <- DesignSeqOneByOnePocockSimon$new(
		strata_cols = c("g", "h"), weights = c(1, 2), p_best = 0.8,
		response_type = "continuous", n = nrow(X), seed = 601L
	)
	priv <- des$.__enclos_env__$private
	w <- numeric(nrow(X))
	for (i in seq_len(nrow(X))) {
		w[i] <- des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
		if (i == 1L) {
			expect_equal(nrow(priv$Xraw), nrow(X))
			expect_equal(nrow(des$get_X_raw()), 1L)
			expect_true(isTRUE(priv$Xraw_preallocated))
		}
	}
	expect_identical(w, c(1, 0, 0, 1, 0, 1, 0, 0))
	expect_equal(des$get_X_raw(), data.table::as.data.table(X))
	expect_equal(unname(priv$strata_level_rows$g), c(1L, 4L, 5L, 6L))
	expect_equal(unname(priv$strata_level_rows$h), c(2L, 3L, 7L, 8L))
	expect_equal(
		unname(priv$get_subject_levels_idx(list(g = NA, h = NA))),
		c(5L, 8L)
	)
	expect_true(isTRUE(priv$model_matrix_stale))
	expect_null(priv$X)
	expect_equal(nrow(des$get_X()), nrow(X))
	expect_false(isTRUE(priv$model_matrix_stale))
})

test_that("inference construction refreshes a stale Pocock-Simon model matrix", {
	X <- data.frame(
		g = factor(c("a", "b", "a", "b", "a", "b", "a", "b")),
		h = factor(c("u", "u", "v", "v", "u", "u", "v", "v"))
	)
	des <- DesignSeqOneByOnePocockSimon$new(
		strata_cols = c("g", "h"), response_type = "continuous",
		n = nrow(X), design_formula = ~ 1, seed = 602L, verbose = FALSE
	)
	for (i in seq_len(4L)) {
		des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	}
	# Materialize a prefix, then finish enrollment.  Pocock-Simon deliberately
	# does not rebuild this analysis matrix while assigning later subjects.
	expect_equal(nrow(des$get_X()), 4L)
	for (i in 5:nrow(X)) {
		des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	}
	priv <- des$.__enclos_env__$private
	expect_true(isTRUE(priv$model_matrix_stale))
	expect_equal(nrow(priv$X), 4L)
	w <- des$get_w()
	expect_setequal(w, c(0, 1))
	y <- 1.5 * w + seq_len(nrow(X)) / 10
	des$add_all_subject_responses(y)

	inf <- InferenceContinOLS$new(des, verbose = FALSE)
	expect_equal(nrow(inf$.__enclos_env__$private$X), nrow(X))
	expect_false(isTRUE(priv$model_matrix_stale))
	reference <- unname(stats::lm.fit(cbind(1, w, inf$.__enclos_env__$private$X), y)$coefficients[2L])
	expect_equal(inf$compute_estimate(estimate_only = TRUE), reference, tolerance = 1e-10)
})

binary_match_priv <- function(n = 20L) {
	set.seed(4)
	des <- DesignFixedBinaryMatch$new(response_type = "continuous", n = n, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n), x2 = rnorm(n)))
	list(des = des, priv = des$.__enclos_env__$private)
}

test_that("set_binary_match_structure_from_m builds a pair matrix ordered by pair id with ascending rows", {
	f <- binary_match_priv()
	f$priv$set_binary_match_structure_from_m(rep(1:10, each = 2))
	expect_equal(f$priv$bms$indicies_pairs, matrix(1:20, ncol = 2, byrow = TRUE))

	f$priv$set_binary_match_structure_from_m(c(3, 1, 2, 3, 1, 2, rep(4:10, each = 2)))
	expect_equal(f$priv$bms$indicies_pairs[1:3, ], rbind(c(2, 5), c(3, 6), c(1, 4)))
	expect_equal(nrow(f$priv$bms$indicies_pairs), 10L)
})

test_that("set_binary_match_structure_from_m rejects non-pair, non-positive and wrong-length match vectors and clears caches", {
	f <- binary_match_priv()
	msg <- "must define matched pairs only"
	expect_error(f$priv$set_binary_match_structure_from_m(rep(1:5, each = 4)), msg)
	expect_error(f$priv$set_binary_match_structure_from_m(c(rep(1:9, each = 2), 1, 2)), msg)
	expect_error(f$priv$set_binary_match_structure_from_m(c(0, rep(1:9, each = 2), 1)), "not >= 1")
	expect_error(f$priv$set_binary_match_structure_from_m(rep(1:5, each = 2)))              # length != n

	f$priv$cluster_id <- rep(9L, 20L)
	f$priv$set_binary_match_structure_from_m(rep(1:10, each = 2))
	expect_null(f$priv$cluster_id)
	expect_invisible(f$priv$set_binary_match_structure_from_m(rep(1:10, each = 2)))

	old <- options(edi.run_asserts = FALSE); on.exit(options(old), add = TRUE)
	expect_silent(f$priv$set_binary_match_structure_from_m(rep(1:10, each = 2)))
})
