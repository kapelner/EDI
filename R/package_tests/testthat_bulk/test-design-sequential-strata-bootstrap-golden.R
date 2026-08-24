# Golden tests for the row-by-row sequential blocking bootstrap extracted for
# fix_design_hierarchy.md TODO-23.  The synthetic host deliberately inherits Design
# directly: this tests the component independently of the still-contaminated
# the former deep transition hierarchy.

make_sequential_strata_bootstrap_host = function() {
	EDI:::define_design_class(
		classname = "DesignTemporarySequentialStrataBootstrapHost",
		inherit = Design,
		components = "SequentialStrataBootstrap",
		public = list(
			initialize = function(strata_cols = NULL, whole_group = FALSE, response_type = "continuous") {
				super$initialize(response_type = response_type)
				private$strata_cols = strata_cols
				private$uses_covariates = !is.null(strata_cols)
				private$sequential_bootstrap_whole_group = whole_group
			},
			add_rows = function(X) {
				private$Xraw = data.table::as.data.table(X)
				private$t = nrow(X)
				invisible(self)
			}
		),
		private = list(
			# character() (rather than NULL) keeps the state slot through
			# utils::modifyList(), whose NULL convention deletes an entry.
			strata_cols = character(),
			uses_covariates = FALSE,
			sequential_bootstrap_whole_group = FALSE
		)
	)
}

test_that("SequentialStrataBootstrap reproduces random-block-size bootstrap output", {
	EDI:::populate_design_component_registry()
	on.exit(EDI:::populate_design_component_registry(), add = TRUE)
	Host = make_sequential_strata_bootstrap_host()

	X = data.frame(
		site = factor(c("a", "b", "a", "a", "b", "b", "a", "b")),
		x = seq_len(8)
	)
	des_real = DesignSeqOneByOneRandomBlockSize$new(
		strata_cols = "site", block_sizes = c(2, 4), response_type = "continuous"
	)
	for (i in seq_len(nrow(X))) des_real$add_one_subject(X[i, , drop = FALSE])
	des_new = Host$new(strata_cols = "site", whole_group = FALSE)
	des_new$add_rows(X)

	for (bootstrap_type in list(NULL, "within_blocks", "whole_group")) {
		set.seed(23)
		out_real = des_real$.__enclos_env__$private$draw_bootstrap_indices(bootstrap_type)
		set.seed(23)
		out_new = des_new$.__enclos_env__$private$draw_bootstrap_indices(bootstrap_type)
		expect_identical(out_new, out_real, info = paste("stratified bootstrap_type =", bootstrap_type %||% "NULL"))
	}

	# RandomBlockSize alone also permits simple, unstratified blocking.
	des_real_plain = DesignSeqOneByOneRandomBlockSize$new(
		strata_cols = NULL, block_sizes = c(2, 4), response_type = "continuous"
	)
	for (i in seq_len(nrow(X))) des_real_plain$add_one_subject(X[i, , drop = FALSE])
	des_new_plain = Host$new()
	des_new_plain$add_rows(X)
	for (bootstrap_type in list(NULL, "within_blocks", "whole_group")) {
		set.seed(24)
		out_real = des_real_plain$.__enclos_env__$private$draw_bootstrap_indices(bootstrap_type)
		set.seed(24)
		out_new = des_new_plain$.__enclos_env__$private$draw_bootstrap_indices(bootstrap_type)
		expect_identical(out_new, out_real, info = paste("unstratified bootstrap_type =", bootstrap_type %||% "NULL"))
	}
})

test_that("SequentialStrataBootstrap reproduces SPBR bootstrap output", {
	EDI:::populate_design_component_registry()
	on.exit(EDI:::populate_design_component_registry(), add = TRUE)
	Host = make_sequential_strata_bootstrap_host()

	X = data.frame(
		site = factor(c("a", "b", "a", "a", "b", "b", "a", "b")),
		x = seq_len(8)
	)
	des_real = DesignSeqOneByOneSPBR$new(
		strata_cols = "site", block_size = 4, response_type = "continuous"
	)
	for (i in seq_len(nrow(X))) des_real$add_one_subject(X[i, , drop = FALSE])
	des_new = Host$new(strata_cols = "site", whole_group = TRUE)
	des_new$add_rows(X)

	for (bootstrap_type in list(NULL, "within_blocks", "whole_group")) {
		set.seed(25)
		out_real = des_real$.__enclos_env__$private$draw_bootstrap_indices(bootstrap_type)
		set.seed(25)
		out_new = des_new$.__enclos_env__$private$draw_bootstrap_indices(bootstrap_type)
		expect_identical(out_new, out_real, info = paste("bootstrap_type =", bootstrap_type %||% "NULL"))
	}
})
