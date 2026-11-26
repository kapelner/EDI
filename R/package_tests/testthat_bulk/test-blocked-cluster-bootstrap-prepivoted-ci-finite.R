library(testthat)
library(EDI)

# v1.0.6-TODO-189 (docs-scenarios clusters-blocking F7): on this blocked-cluster trial the prepivoted,
# double-bootstrap and calibrated bootstrap CIs returned c(NA, NA) with only "bootstrap_ci_unavailable"
# while the percentile CI was finite. Verified already fixed on HEAD 2026-11-21; this pins the
# prepivoted type (the double-bootstrap and calibrated types share its inner bootstrap and are slower).

test_that("prepivoted bootstrap CI is finite on the unequal blocked-cluster trial", {
	set.seed(424242)
	nsch = c(North = 8, South = 6, East = 6, West = 4)
	sizes = unlist(lapply(nsch, function(k) {
		repeat {
			s = round(rmultinom(1, 168 - 10 * k, rep(1, k))[, 1]) + 10
			if (all(s <= 60)) return(s)
		}
	}))
	G = sum(nsch)
	school = factor(rep(sprintf("S%02d", 1:G), times = sizes))
	district = factor(rep(rep(names(nsch), nsch), times = sizes))
	n = length(school)
	X = data.frame(school = school, district = district, pretest = round(rnorm(n, 50, 10)))
	d = DesignFixedBlockedCluster$new(n = n, response_type = "continuous", strata_cols = "district",
		cluster_col = "school", seed = 7, verbose = FALSE)
	d$add_all_subjects_to_experiment(X)
	d$assign_w_to_all_subjects()
	w = d$get_w()
	y = 60 + 4 * w + 0.5 * (X$pretest - 50) + rnorm(G, sd = 4)[as.integer(school)] + rnorm(n, sd = 8)
	d$add_all_subject_responses(y)
	inf = InferenceContinOLS$new(d, verbose = FALSE)
	inf$set_seed(1)
	ci = suppressWarnings(inf$compute_bootstrap_confidence_interval(B = 21, type = "prepivoted", show_progress = FALSE))
	expect_true(all(is.finite(ci)))
	expect_lt(ci[1], ci[2])
})
