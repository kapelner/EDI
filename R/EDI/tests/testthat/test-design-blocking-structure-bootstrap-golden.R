# Golden tests for the generalized BlockingStructure$draw_bootstrap_indices()
# (fix_design_hierarchy.md, "Follow-Ups From Implementation" -- "Author the
# generalized stratified draw_bootstrap_indices() for BlockingStructure").
#
# BlockingStructure is registered (design_component_registry.R) but NOT wired into
# DesignFixedBlocking/DesignFixedOptimalBlocks/ObservationalDesignBlocks yet -- these
# tests prove the generalized logic (self$get_block_ids() -> group_id -> either
# stratified_bootstrap_indices_cpp() or resample_group_rows_cpp()) is correct in
# isolation, via synthetic hosts, before any real class is rewired to use it (the
# actual rewiring is "Timing-Family Split" work).
#
# Scope note: the original TODO text named 5 classes. Investigation found that only
# 3 reduce to this one generalization via self$get_block_ids(): DesignFixedBlocking,
# DesignFixedOptimalBlocks (via its leaf-only get_or_compute_block_ids() private
# method), and ObservationalDesignBlocks (m supplied directly by the user). The other
# 2 -- DesignSeqOneByOneRandomBlockSize and DesignSeqOneByOneSPBR -- use a
# fundamentally different, separately-duplicated-between-themselves row-by-row
# private$get_strata_key(x_row) mechanism against a growing private$Xraw, not
# BlockingStructure's matrix-based get_strata_keys()/get_block_ids(). They are out of
# scope here and tracked as their own follow-up.
#
# Synthetic hosts use `inherit = Design` (the root class), not `inherit = DesignFixed`,
# for the same reason documented at length in
# test-design-cluster-structure-golden.R: DesignFixed still (pre "Timing-Family
# Split") inherits transitively through DesignMatching -> DesignBlocking, which
# contaminates private$has_private_method() existence checks against ancestor-level
# methods. Using `inherit = Design` directly sidesteps that contamination.

test_that("BlockingStructure's generalized draw_bootstrap_indices reproduces DesignFixedBlocking exactly", {
	EDI:::populate_design_component_registry()
	DesignTemporaryBlockingHost = EDI:::define_design_class(
		classname = "DesignTemporaryBlockingHost",
		inherit = Design,
		components = "BlockingStructure",
		public = list(
			initialize = function(strata_cols, response_type, n, ...) {
				super$initialize(response_type = response_type, n = n, ...)
				private$fixed_sample = TRUE
				private$t = n
				private$blocking_capable = TRUE
				private$strata_cols = strata_cols
				private$equal_block_sizes = FALSE
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

	set.seed(1)
	X = data.frame(x1 = rnorm(12), x2 = sample(c("a", "b"), 12, TRUE))

	des_real = DesignFixedBlocking$new(n = 12, response_type = "continuous", strata_cols = "x2", equal_block_sizes = FALSE)
	des_real$add_all_subjects_to_experiment(X)
	des_real$assign_w_to_all_subjects()

	des_new = DesignTemporaryBlockingHost$new(strata_cols = "x2", response_type = "continuous", n = 12)
	des_new$add_all_subjects_to_experiment(X)

	for (bootstrap_type in list(NULL, "within_blocks", "whole_group")) {
		set.seed(3)
		out_real = des_real$.__enclos_env__$private$draw_bootstrap_indices(bootstrap_type)
		set.seed(3)
		out_new = des_new$.__enclos_env__$private$draw_bootstrap_indices(bootstrap_type)
		expect_identical(out_real, out_new, info = paste("bootstrap_type =", bootstrap_type %||% "NULL"))
	}
})

test_that("BlockingStructure's generalized draw_bootstrap_indices reproduces DesignFixedOptimalBlocks exactly", {
	EDI:::populate_design_component_registry()
	DesignTemporaryOptimalBlocksHost = EDI:::define_design_class(
		classname = "DesignTemporaryOptimalBlocksHost",
		inherit = Design,
		components = "BlockingStructure",
		public = list(
			initialize = function(response_type, n, ...) {
				super$initialize(response_type = response_type, n = n, ...)
				private$fixed_sample = TRUE
				private$t = n
				private$blocking_capable = TRUE
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

	set.seed(1)
	X = data.frame(x1 = rnorm(12), x2 = sample(c("a", "b"), 12, TRUE))

	des_real = DesignFixedOptimalBlocks$new(n = 12, response_type = "continuous", B = 2)
	des_real$add_all_subjects_to_experiment(X)
	des_real$assign_w_to_all_subjects()
	# DesignFixedOptimalBlocks's own draw_bootstrap_indices calls
	# private$get_or_compute_block_ids() directly and never populates private$m; force
	# it via the public dispatcher so the synthetic host can be seeded identically.
	m_real = des_real$get_block_ids()

	des_new = DesignTemporaryOptimalBlocksHost$new(response_type = "continuous", n = 12)
	des_new$add_all_subjects_to_experiment(X)
	des_new$.__enclos_env__$private$m = m_real

	for (bootstrap_type in list(NULL, "within_blocks", "whole_group")) {
		set.seed(3)
		out_real = des_real$.__enclos_env__$private$draw_bootstrap_indices(bootstrap_type)
		set.seed(3)
		out_new = des_new$.__enclos_env__$private$draw_bootstrap_indices(bootstrap_type)
		expect_identical(out_real, out_new, info = paste("bootstrap_type =", bootstrap_type %||% "NULL"))
	}
})

test_that("BlockingStructure's generalized draw_bootstrap_indices reproduces ObservationalDesignBlocks exactly", {
	EDI:::populate_design_component_registry()
	DesignTemporaryObservationalBlocksHost = EDI:::define_design_class(
		classname = "DesignTemporaryObservationalBlocksHost",
		inherit = Design,
		components = "BlockingStructure",
		public = list(
			initialize = function(response_type, n, ...) {
				super$initialize(response_type = response_type, n = n, ...)
				private$fixed_sample = TRUE
				private$t = n
				private$blocking_capable = TRUE
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

	set.seed(1)
	X = data.frame(x1 = rnorm(12), x2 = sample(c("a", "b"), 12, TRUE))
	m = rep(1:4, each = 3)

	des_real = ObservationalDesignBlocks$new(response_type = "continuous", m = m)
	des_real$add_all_subjects_to_experiment(X)
	des_real$assign_w_to_all_subjects(w_precomputed = sample(c(0, 1), 12, TRUE))

	des_new = DesignTemporaryObservationalBlocksHost$new(response_type = "continuous", n = 12)
	des_new$add_all_subjects_to_experiment(X)
	des_new$.__enclos_env__$private$m = m

	for (bootstrap_type in list(NULL, "within_blocks", "whole_group")) {
		set.seed(3)
		out_real = des_real$.__enclos_env__$private$draw_bootstrap_indices(bootstrap_type)
		set.seed(3)
		out_new = des_new$.__enclos_env__$private$draw_bootstrap_indices(bootstrap_type)
		expect_identical(out_real, out_new, info = paste("bootstrap_type =", bootstrap_type %||% "NULL"))
	}
})
