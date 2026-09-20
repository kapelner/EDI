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
	expect_equal(f$priv$strata_level_rows$g, c(a = 1L, b = 2L))
	expect_equal(f$priv$strata_level_rows$h, c(u = 3L, v = 4L, w = 5L))
	expect_equal(f$priv$num_levels_total, 5L)
	expect_false(anyDuplicated(unlist(f$priv$strata_level_rows, use.names = FALSE)) > 0L)

	expect_equal(f$priv$get_subject_levels_idx(list(g = "b", h = "w")), c(g = 2L, h = 5L))
	expect_equal(f$priv$get_subject_levels_idx(list(g = "a", h = "u")), c(g = 1L, h = 3L))
})

test_that("missing covariate values map to the literal 'NA' level", {
	f <- pocock_priv(data.frame(g = c("a", NA, "a", NA), h = c("u", "v", "u", "v"), stringsAsFactors = FALSE))
	f$priv$ensure_factor_metadata()
	expect_setequal(names(f$priv$strata_level_rows$g), c("a", "NA"))
	idx <- f$priv$get_subject_levels_idx(list(g = NA, h = "v"))
	expect_equal(unname(idx["g"]), unname(f$priv$strata_level_rows$g[["NA"]]))
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
	expect_equal(priv$strata_level_rows$g, c(b = 1L, a = 3L))
	expect_equal(priv$strata_level_rows$h, c(v = 2L, w = 4L, u = 5L))
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
