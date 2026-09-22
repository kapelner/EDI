library(testthat)
library(EDI)

# exchangeable_resampling_draws_cpp(units, strata_ids, unit_kind, m_vec_full, B, size, replace, stratified, preserve_order, unit_type, size_label): draws B
# resamples of exchangeable units (single subjects, clusters, matched sets). Each draw: unit_ids (1-based units chosen), i_b (their rows concatenated in the chosen
# order, or sorted when preserve_order = TRUE), m_vec_b (match ids of the chosen rows renumbered 1, 2, ... in increasing order of the original ids, 0 kept), unit_type, n_units, and a
# field named size_label holding the number of chosen units. Independent references: recompute i_b / m_vec_b from unit_ids, exact proportional allocation across
# strata, uniqueness without replacement, uniform selection frequencies, and the error guards.

K <- get("exchangeable_resampling_draws_cpp", envir = asNamespace("EDI"))
units <- list(1:2, 3:4, 5L, 6:8, 9L, 10:11)
strata <- c("a", "a", "b", "b", "b", "a")
m_full <- c(1L, 1L, 0L, 2L, 2L, 0L, 0L, 0L, 0L, 3L, 3L)

ref_renumber <- function(m) { ids <- sort(unique(m[m > 0L])); out <- m; for (k in seq_along(ids)) out[m == ids[k]] <- k; out }

test_that("every draw is consistent: rows = concatenated unit rows in draw order, m_vec_b renumbered by rank of the original id, metadata fields present", {
	set.seed(1)
	d <- K(units, strata, NULL, m_full, 40L, 4L, FALSE, TRUE, FALSE, "cluster", "n_clusters")
	expect_length(d, 40L)
	for (x in d) {
		expect_equal(x$i_b, unlist(units[x$unit_ids])); expect_equal(x$m_vec_b, ref_renumber(m_full[x$i_b]))
		expect_identical(x$unit_type, "cluster"); expect_identical(x$n_units, 6L); expect_identical(x$n_clusters, 4L)
		expect_length(x$unit_ids, 4L); expect_false(anyDuplicated(x$unit_ids) > 0L)
	}
	expect_true(any(vapply(d, function(x) any(x$m_vec_b > 0L), NA)))
})

test_that("stratified draws allocate the requested size proportionally across strata (a: 3 units, b: 3 units -> 2 + 2)", {
	set.seed(2)
	d <- K(units, strata, NULL, NULL, 60L, 4L, FALSE, TRUE, FALSE, "cluster", "n_clusters")
	for (x in d) {
		expect_equal(sum(strata[x$unit_ids] == "a"), 2L); expect_equal(sum(strata[x$unit_ids] == "b"), 2L)
	}
	d2 <- K(units, strata, NULL, NULL, 20L, 6L, TRUE, TRUE, FALSE, "cluster", "n_clusters")
	for (x in d2) { expect_equal(sum(strata[x$unit_ids] == "a"), 3L); expect_equal(sum(strata[x$unit_ids] == "b"), 3L) }
	expect_gt(length(unique(unlist(lapply(d2, function(x) list(x$unit_ids))))), 3L)         # with replacement: repeats and varied draws
	expect_true(any(vapply(d2, function(x) anyDuplicated(x$unit_ids) > 0L, NA)))
})

test_that("unstratified draws ignore the strata; selection is uniform over units; without replacement units are unique", {
	set.seed(3)
	d <- K(units, strata, NULL, NULL, 3000L, 2L, FALSE, FALSE, FALSE, "cluster", "n_clusters")
	freq <- tabulate(unlist(lapply(d, function(x) x$unit_ids)), nbins = 6L) / (2 * 3000)
	expect_lt(max(abs(freq - 1 / 6)), 0.02)
	expect_true(all(vapply(d, function(x) !anyDuplicated(x$unit_ids), NA)))
	expect_true(any(vapply(d, function(x) length(unique(strata[x$unit_ids])) == 2L, NA)) && any(vapply(d, function(x) length(unique(strata[x$unit_ids])) == 1L, NA)))
})

test_that("preserve_order = TRUE sorts the rows; identity singleton units and NULL match ids are handled", {
	set.seed(4)
	d <- K(units, NULL, NULL, NULL, 10L, 6L, TRUE, FALSE, TRUE, "cluster", "n_clusters")
	for (x in d) { expect_identical(x$i_b, sort(unlist(units[x$unit_ids]))); expect_null(x$m_vec_b) }
	s <- K(as.list(1:5), NULL, NULL, NULL, 5L, 5L, FALSE, FALSE, FALSE, "subject", "n_subjects")
	for (x in s) { expect_equal(sort(x$i_b), 1:5); expect_equal(x$i_b, x$unit_ids); expect_identical(x$n_subjects, 5L) }
})

test_that("guards: no units, negative B / size, strata or unit_kind of the wrong length, oversized subsample without replacement", {
	expect_error(K(list(), NULL, NULL, NULL, 1L, 1L, TRUE, FALSE, FALSE, "s", "n"), "No exchangeable units")
	expect_error(K(units, NULL, NULL, NULL, -1L, 2L, TRUE, FALSE, FALSE, "s", "n"), "B must be non-negative")
	expect_error(K(units, NULL, NULL, NULL, 1L, -2L, TRUE, FALSE, FALSE, "s", "n"), "size must be non-negative")
	expect_error(K(units, c("a", "b"), NULL, NULL, 1L, 2L, TRUE, TRUE, FALSE, "s", "n"), "strata_ids must have one entry per exchangeable unit")
	expect_error(K(units, NULL, c("x", "y"), NULL, 1L, 2L, TRUE, FALSE, FALSE, "s", "n"), "unit_kind must have one entry per exchangeable unit")
	expect_error(K(units, NULL, NULL, NULL, 1L, 20L, FALSE, FALSE, FALSE, "s", "n"), "too small for the requested subsample size")
	expect_length(K(units, NULL, NULL, NULL, 0L, 2L, TRUE, FALSE, FALSE, "s", "n"), 0L)
})
