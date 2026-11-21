library(testthat)
library(EDI)

# v1.0.6-TODO-300 (docs-scenarios clusters-blocking F4): assign_w_to_all_subjects(w_precomputed = )
# stored as.numeric(w_precomputed) unchecked, so a 1/2-coded vector was kept and
# InferenceAllSimpleAverageDiff returned NA. v1.0.6-TODO-301 (clusters-blocking F6): the cluster
# designs accepted an assignment that varies within clusters.

wpre_cluster_design = function(cls = "DesignFixedCluster", seed = 1) {
	set.seed(seed)
	school = factor(rep(sprintf("S%02d", 1:8), each = 5))
	district = factor(rep(c("A", "B"), each = 20))
	X = data.frame(school = school, district = district, x = rnorm(40))
	d = if (cls == "DesignFixedCluster") {
		DesignFixedCluster$new(n = 40, response_type = "continuous", cluster_col = "school", verbose = FALSE)
	} else {
		DesignFixedBlockedCluster$new(n = 40, response_type = "continuous", strata_cols = "district",
			cluster_col = "school", verbose = FALSE)
	}
	d$add_all_subjects_to_experiment(X)
	list(d = d, X = X, wcl = as.numeric(school %in% c("S01", "S03", "S05", "S07")))
}

test_that("invalid w_precomputed vectors error with a message naming the rule", {
	f = wpre_cluster_design()
	expect_error(f$d$assign_w_to_all_subjects(w_precomputed = f$wcl + 1), "only 0 \\(control\\) and 1")
	expect_error(f$d$assign_w_to_all_subjects(w_precomputed = f$wcl[-1]), "length n = 40")
	w_na = f$wcl; w_na[3] = NA
	expect_error(f$d$assign_w_to_all_subjects(w_precomputed = w_na), "must not contain NA")
	expect_error(f$d$assign_w_to_all_subjects(w_precomputed = rep(1, 40)), "each arm")
	expect_error(f$d$assign_w_to_all_subjects(w_precomputed = factor(f$wcl)), "numeric or logical")
	expect_error(f$d$assign_w_to_all_subjects(w_precomputed = as.character(f$wcl)), "numeric or logical")

	set.seed(2)
	b = DesignFixedBernoulli$new(n = 10, response_type = "continuous", verbose = FALSE)
	b$add_all_subjects_to_experiment(data.frame(x = rnorm(10)))
	expect_error(b$assign_w_to_all_subjects(w_precomputed = c(1, 2, 1, 2, 1, 2, 1, 2, 1, 2)), "only 0")
	b$assign_w_to_all_subjects(w_precomputed = c(TRUE, FALSE, TRUE, FALSE, TRUE, FALSE, TRUE, FALSE, TRUE, FALSE))
	expect_identical(b$get_w(), rep(c(1, 0), 5))
})

test_that("cluster designs refuse an assignment that varies within clusters and accept a cluster-constant one", {
	for (cls in c("DesignFixedCluster", "DesignFixedBlockedCluster")) {
		f = wpre_cluster_design(cls)
		set.seed(3)
		w_mixed = f$wcl
		w_mixed[c(1, 7)] = 1 - w_mixed[c(1, 7)]
		expect_error(f$d$assign_w_to_all_subjects(w_precomputed = w_mixed), "varies within 2 cluster", info = cls)
		f$d$assign_w_to_all_subjects(w_precomputed = f$wcl)
		expect_identical(as.numeric(f$d$get_w()), f$wcl, info = cls)
	}
})
