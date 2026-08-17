# Golden tests for the generalized ClusterStructure$draw_bootstrap_indices()
# (fix_design_hierarchy.md, "Follow-Ups From Implementation" -- "Author the
# generalized ClusterStructure").
#
# ClusterStructure is now actually wired into both DesignFixedCluster and
# DesignFixedBlockedCluster (design_fixed_cluster.R, design_fixed_blocked_cluster.R,
# "Timing-Family Split" concrete-class rewiring), so these tests compare the real
# classes' output against a synthetic reference host built independently from the
# same component.
#
# The shallow hierarchy makes `has_private_method("get_strata_keys")` a structural
# probe: it is true exactly when BlockingStructure is composed. These hosts pin both
# sides of that dispatch without any inherited structural base or surrogate flag.

test_that("ClusterStructure's generalized draw_bootstrap_indices reproduces DesignFixedCluster exactly (no stratification)", {
	EDI:::populate_design_component_registry()
	DesignTemporaryClusterOnlyHost = EDI:::define_design_class(
		classname = "DesignTemporaryClusterOnlyHost",
		inherit = Design,
		components = "ClusterStructure",
		public = list(
			initialize = function(cluster_col, response_type, n, ...) {
				super$initialize(response_type = response_type, n = n, ...)
				private$fixed_sample = TRUE
				private$t = n
				private$cluster_col = cluster_col
				private$uses_covariates = TRUE
			},
			add_all_subjects_to_experiment = function(X_all) {
				private$Xraw = data.table::as.data.table(X_all)
				private$Ximp = data.table::copy(private$Xraw)
				private$t = nrow(X_all)
				invisible(self)
			},
			draw_ws_according_to_design = function(r = 1L) matrix(1, nrow = self$get_n(), ncol = r),
			get_w = function() private$w
		)
	)
	on.exit(EDI:::populate_design_component_registry(), add = TRUE)

	h = DesignTemporaryClusterOnlyHost$new(cluster_col = "cl", response_type = "continuous", n = 20)
	expect_false(h$.__enclos_env__$private$has_private_method("get_strata_keys"))

	set.seed(42)
	X = data.frame(x = rnorm(20), cl = factor(rep(1:5, each = 4)))

	des_real = DesignFixedCluster$new(n = 20, response_type = "continuous", cluster_col = "cl")
	des_real$add_all_subjects_to_experiment(X)
	des_real$assign_w_to_all_subjects()
	h$add_all_subjects_to_experiment(X)

	set.seed(7)
	out_real = des_real$.__enclos_env__$private$draw_bootstrap_indices(NULL)
	set.seed(7)
	out_new = h$.__enclos_env__$private$draw_bootstrap_indices(NULL)
	expect_identical(out_real, out_new)
})

test_that("ClusterStructure's generalized draw_bootstrap_indices reproduces DesignFixedBlockedCluster exactly (with stratification)", {
	EDI:::populate_design_component_registry()
	DesignTemporaryBlockedClusterHost = EDI:::define_design_class(
		classname = "DesignTemporaryBlockedClusterHost",
		inherit = Design,
		components = c("BlockingStructure", "ClusterStructure"),
		public = list(
			initialize = function(strata_cols, cluster_col, response_type, n, ...) {
				super$initialize(response_type = response_type, n = n, ...)
				private$fixed_sample = TRUE
				private$t = n
				private$blocking_capable = TRUE
				private$strata_cols = strata_cols
				private$cluster_col = cluster_col
				private$uses_covariates = TRUE
			},
			add_all_subjects_to_experiment = function(X_all) {
				private$Xraw = data.table::as.data.table(X_all)
				private$Ximp = data.table::copy(private$Xraw)
				private$t = nrow(X_all)
				invisible(self)
			},
			draw_ws_according_to_design = function(r = 1L) matrix(1, nrow = self$get_n(), ncol = r),
			get_w = function() private$w
		),
		# ClusterStructure's strata-aware draw_bootstrap_indices must win over
		# BlockingStructure's plain block-based one; both now provide the method
		# since BlockingStructure's own generalization landed alongside this one.
		overrides = list(private = "draw_bootstrap_indices")
	)
	on.exit(EDI:::populate_design_component_registry(), add = TRUE)

	set.seed(99)
	X2 = data.frame(strat = factor(rep(c("a", "b"), each = 10)), cl = factor(rep(1:10, each = 2)))

	des_real = DesignFixedBlockedCluster$new(n = 20, response_type = "continuous", strata_cols = "strat", cluster_col = "cl")
	des_real$add_all_subjects_to_experiment(X2)
	des_real$assign_w_to_all_subjects()

	des_new = DesignTemporaryBlockedClusterHost$new(strata_cols = "strat", cluster_col = "cl", response_type = "continuous", n = 20)
	des_new$add_all_subjects_to_experiment(X2)

	for (bootstrap_type in list(NULL, "within_blocks", "whole_group")) {
		set.seed(13)
		out_real = des_real$.__enclos_env__$private$draw_bootstrap_indices(bootstrap_type)
		set.seed(13)
		out_new = des_new$.__enclos_env__$private$draw_bootstrap_indices(bootstrap_type)
		expect_identical(out_real, out_new, info = paste("bootstrap_type =", bootstrap_type %||% "NULL"))
	}
})
