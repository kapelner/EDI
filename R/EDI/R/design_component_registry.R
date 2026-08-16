#' Design Component Registry
#'
#' Implements the "Component Registry" section of \code{fix_design_hierarchy.md}:
#' \code{DesignComponent()} contracts, registration, dependency resolution, and
#' parser-backed body-reference validation, mirroring \code{InferenceComponent()}
#' (\code{contracts_mixins.R}) but scoped to what the simpler \code{Design} component
#' contract needs -- no lazy loading, no likelihood tiers, no \code{super$} category
#' (Design components are pure state + method bundles, not deep-inheritance mixins).
#'
#' Components registered here are metadata + real method references only; they are
#' not yet wired into any concrete \code{Design} class's \code{inherit=}/component
#' list. That rewiring, and the golden-test verification it requires per class, is
#' "Component Extraction" -- a later, separate TODO section. Registering a component
#' here changes nothing about how \code{DesignBlocking}/\code{DesignMatching} and
#' their descendants behave today.
#'
#' @keywords internal
#' @noRd
EDI_DESIGN_COMPONENTS = new.env(parent = emptyenv())

EDI_DESIGN_COMPONENT_ALLOWED_STATUSES = c("active", "scaffold")

DesignComponent = function(
		name,
		status = c("active", "scaffold"),
		dependencies = character(),
		public = list(),
		private = list(),
		provides_public_methods = names(public),
		provides_private_methods = names(private),
		owns_state = character(),
		requires_state = character(),
		requires_public_methods = character(),
		requires_private_methods = character(),
		optional_public_methods = character(),
		optional_private_methods = character(),
		provides_capabilities = character(),
		conflicts = character(),
		allowed_host_overrides = list(public = character(), private = character())
	) {
	status = match.arg(status)
	if (is.null(provides_public_methods)) provides_public_methods = character()
	if (is.null(provides_private_methods)) provides_private_methods = character()
	component = list(
		name = name,
		status = status,
		dependencies = dependencies,
		public = public,
		private = private,
		provides_public_methods = provides_public_methods,
		provides_private_methods = provides_private_methods,
		owns_state = owns_state,
		requires_state = requires_state,
		requires_public_methods = requires_public_methods,
		requires_private_methods = requires_private_methods,
		optional_public_methods = optional_public_methods,
		optional_private_methods = optional_private_methods,
		provides_capabilities = provides_capabilities,
		conflicts = conflicts,
		allowed_host_overrides = allowed_host_overrides
	)
	validate_design_component(component)
	component
}

validate_design_component = function(component) {
	required = c(
		"name", "status", "dependencies", "public", "private",
		"provides_public_methods", "provides_private_methods",
		"owns_state", "requires_state", "requires_public_methods",
		"requires_private_methods", "optional_public_methods",
		"optional_private_methods", "provides_capabilities", "conflicts",
		"allowed_host_overrides"
	)
	missing = setdiff(required, names(component))
	if (length(missing) > 0L) {
		stop(sprintf(
			"Design component %s is missing required field(s): %s",
			if (is.null(component$name)) "<unknown>" else component$name,
			paste(missing, collapse = ", ")
		), call. = FALSE)
	}
	if (!is.character(component$name) || length(component$name) != 1L || !nzchar(component$name)) {
		stop("Design component field `name` must be a non-empty character scalar.", call. = FALSE)
	}
	if (!(component$status %in% EDI_DESIGN_COMPONENT_ALLOWED_STATUSES)) {
		stop(sprintf("Design component %s has invalid status.", component$name), call. = FALSE)
	}
	if (!is.list(component$public) || !is.list(component$private)) {
		stop(sprintf("Design component %s must provide public/private lists.", component$name), call. = FALSE)
	}
	for (field in setdiff(required, c("public", "private", "allowed_host_overrides"))) {
		if (!is.character(component[[field]])) {
			stop(sprintf("Design component %s has non-character `%s`.", component$name, field), call. = FALSE)
		}
	}
	if (!identical(sort(component$provides_public_methods), sort(design_component_public_names(component)))) {
		stop(sprintf("Design component %s has stale public method metadata.", component$name), call. = FALSE)
	}
	if (!identical(sort(component$provides_private_methods), sort(design_component_private_names(component)))) {
		stop(sprintf("Design component %s has stale private method metadata.", component$name), call. = FALSE)
	}
	if (!is.list(component$allowed_host_overrides) ||
			!identical(sort(names(component$allowed_host_overrides)), c("private", "public"))) {
		stop(sprintf("Design component %s has invalid `allowed_host_overrides`.", component$name), call. = FALSE)
	}
	invisible(TRUE)
}

register_design_component = function(component) {
	validate_design_component(component)
	if (exists(component$name, envir = EDI_DESIGN_COMPONENTS, inherits = FALSE)) {
		stop(sprintf("Design component already registered for %s.", component$name), call. = FALSE)
	}
	assign(component$name, component, envir = EDI_DESIGN_COMPONENTS)
	invisible(component)
}

clear_design_component_registry = function() {
	rm(list = ls(EDI_DESIGN_COMPONENTS), envir = EDI_DESIGN_COMPONENTS)
	invisible(TRUE)
}

design_component_registry_as_list = function() {
	mget(ls(EDI_DESIGN_COMPONENTS), envir = EDI_DESIGN_COMPONENTS, inherits = FALSE)
}

get_design_component = function(name) {
	if (!exists(name, envir = EDI_DESIGN_COMPONENTS, inherits = FALSE)) {
		stop(sprintf("No design component registered for %s.", name), call. = FALSE)
	}
	get(name, envir = EDI_DESIGN_COMPONENTS, inherits = FALSE)
}

design_component_public_names = function(component) {
	if (is.null(names(component$public))) character() else names(component$public)
}

design_component_private_names = function(component) {
	if (is.null(names(component$private))) character() else names(component$private)
}

# Mirrors resolve_component_dependencies() in contracts_mixins.R, parametrized
# against EDI_DESIGN_COMPONENTS instead of EDI_INFERENCE_COMPONENTS. Kept as a
# separate, parallel implementation rather than a shared/refactored one so this
# work cannot regress the already-shipped, tested Inference component machinery.
resolve_design_component_dependencies = function(component_names, satisfied_components = character()) {
	duplicated_direct = sort(unique(component_names[duplicated(component_names)]))
	if (length(duplicated_direct) > 0L) {
		stop(sprintf(
			"Duplicate direct design component(s): %s",
			paste(duplicated_direct, collapse = ", ")
		), call. = FALSE)
	}
	component_registry_names = ls(EDI_DESIGN_COMPONENTS)
	unknown_components = setdiff(component_names, component_registry_names)
	if (length(unknown_components) > 0L) {
		stop(sprintf(
			"Unknown design component(s): %s",
			paste(unknown_components, collapse = ", ")
		), call. = FALSE)
	}
	scaffold_components = component_names[vapply(component_names, function(component_name) {
		identical(get_design_component(component_name)$status, "scaffold")
	}, logical(1L))]
	if (length(scaffold_components) > 0L) {
		stop(sprintf(
			"Scaffold design component(s) cannot be resolved: %s",
			paste(scaffold_components, collapse = ", ")
		), call. = FALSE)
	}

	direct_dependency_hits = character()
	for (component_name in component_names) {
		deps = get_design_component(component_name)$dependencies
		direct_dependency_hits = c(direct_dependency_hits, intersect(component_names, deps))
	}
	if (length(direct_dependency_hits) > 0L) {
		stop(sprintf(
			"Direct design component list duplicates transitive dependency component(s): %s",
			paste(sort(unique(direct_dependency_hits)), collapse = ", ")
		), call. = FALSE)
	}

	resolved = character()
	visiting = character()

	visit = function(component_name, path = character()) {
		if (component_name %in% satisfied_components) return(invisible(NULL))
		if (component_name %in% resolved) return(invisible(NULL))
		if (component_name %in% visiting) {
			cycle = c(path, component_name)
			stop(sprintf(
				"Design component dependency cycle detected: %s",
				paste(cycle, collapse = " -> ")
			), call. = FALSE)
		}
		if (!(component_name %in% component_registry_names)) {
			stop(sprintf("Unknown design component(s): %s", component_name), call. = FALSE)
		}
		component = get_design_component(component_name)
		if (identical(component$status, "scaffold")) {
			stop(sprintf("Scaffold design component(s) cannot be resolved: %s", component_name), call. = FALSE)
		}
		visiting <<- c(visiting, component_name)
		for (dep in component$dependencies) {
			visit(dep, c(path, component_name))
		}
		visiting <<- setdiff(visiting, component_name)
		resolved <<- c(resolved, component_name)
		invisible(NULL)
	}

	for (component_name in component_names) {
		visit(component_name)
	}

	resolved
}

# Parser-backed body-reference contract, mirroring component_body_references()/
# component_declared_reference_names()/validate_component_body_references() in
# contracts_mixins.R. Only "private" and "self" receivers are tracked -- Design
# components don't call super$ (they aren't deep-inheritance mixins the way some
# Inference components are), so there's no third receiver category to declare.
design_component_body_references = function(component) {
	refs = list(private = character(), self = character())
	collect_from_expr = function(expr) {
		if (!is.call(expr) && !is.expression(expr)) return(invisible(NULL))
		if (is.call(expr) &&
				identical(as.character(expr[[1L]]), "$") &&
				length(expr) >= 3L &&
				is.symbol(expr[[2L]])) {
			lhs = as.character(expr[[2L]])
			if (lhs %in% names(refs)) {
				refs[[lhs]] <<- c(refs[[lhs]], as.character(expr[[3L]])[1L])
			}
		}
		for (i in seq_along(expr)) {
			collect_from_expr(expr[[i]])
		}
		invisible(NULL)
	}
	for (slot in c("public", "private")) {
		for (fn in component[[slot]]) {
			if (is.function(fn)) collect_from_expr(body(fn))
		}
	}
	lapply(refs, function(x) sort(unique(x)))
}

design_component_declared_reference_names = function(component) {
	list(
		private = sort(unique(c(
			component$provides_private_methods,
			component$owns_state,
			component$requires_state,
			component$requires_private_methods,
			component$optional_private_methods
		))),
		self = sort(unique(c(
			component$provides_public_methods,
			component$requires_public_methods,
			component$optional_public_methods
		)))
	)
}

validate_design_component_body_references = function(component) {
	refs = design_component_body_references(component)
	declared = design_component_declared_reference_names(component)
	offenders = character()
	for (receiver in names(refs)) {
		missing = setdiff(refs[[receiver]], declared[[receiver]])
		if (length(missing) > 0L) {
			offenders = c(offenders, sprintf(
				"%s has undeclared %s reference(s): %s",
				component$name, receiver, paste(missing, collapse = ", ")
			))
		}
	}
	if (length(offenders) > 0L) {
		stop(paste(offenders, collapse = "\n"), call. = FALSE)
	}
	invisible(TRUE)
}

# Registers components using either reference-identical methods from the still-live
# generators or generalized implementations protected by matched-seed golden tests.
# Concrete classes consume some of these components already; the remaining rewiring
# is deliberately staged behind the Timing-Family Split. There is no
# AllocationMatrixValidation component: its four originally-duplicated
# validate_allocation_matrix() implementations were deleted outright rather than
# reconciled into a shared component, after confirming each was dead defensive code
# (the underlying C++ search kernels each guarantee valid, correctly-shaped, balanced
# output by construction) except for DesignFixedRerandomization's one real "found
# fewer than r acceptable draws" case, which now errors directly in that class instead
# of being routed through a shared validator.
populate_design_component_registry = function(ns = environment(populate_design_component_registry)) {
	clear_design_component_registry()

	blocking = get("DesignBlocking", envir = ns)
	register_design_component(DesignComponent(
		name = "BlockingStructure",
		status = "active",
		dependencies = character(),
		public = blocking$public_methods[c(
			"is_blocking_design", "assert_blocking_design", "is_complete_blocking_design",
			"assert_equal_block_sizes", "add_all_subject_matched_pair_ids", "set_m",
			"get_block_ids", "summarize_blocks", "inject_cmh_se_w_mat", "get_cmh_se_w_mat"
		)],
		private = c(
			blocking$private_methods[c("assert_min_block_size", "get_strata_keys")],
			list(
				# Generalizes the stratified/whole-block resample duplicated identically
				# (down to variable names) across DesignFixedBlocking,
				# DesignFixedOptimalBlocks, and ObservationalDesignBlocks -- each of
				# those already routes through self$get_block_ids() as its single
				# source of block membership (directly, or via get_or_compute_block_ids/
				# get_strata_keys internally), so this one implementation reproduces all
				# three exactly (golden-verified, matched seeds, byte-identical --
				# fix_design_hierarchy.md, "Follow-Ups From Implementation"). Does NOT
				# cover DesignSeqOneByOneRandomBlockSize/DesignSeqOneByOneSPBR: those
				# sequential designs compute strata keys row-by-row via their own
				# (separately duplicated between the two of them) get_strata_key()
				# helper against growing private$Xraw, not against BlockingStructure's
				# matrix-based get_strata_keys() -- a genuinely different data model,
				# tracked as its own separate follow-up rather than forced into this
				# same generalization.
				draw_bootstrap_indices = function(bootstrap_type = NULL) {
					block_ids = self$get_block_ids()
					group_id = match(block_ids, unique(block_ids))
					if (is.null(bootstrap_type) || bootstrap_type == "within_blocks") {
						list(i_b = stratified_bootstrap_indices_cpp(as.integer(group_id)), m_vec_b = NULL)
					} else {
						i_b = resample_group_rows_cpp(as.integer(group_id), length(unique(group_id)))
						list(i_b = as.integer(i_b), m_vec_b = NULL)
					}
				}
			)
		),
		owns_state = c(
			"m", "strata_cols", "preferred_num_bins_for_continuous_covariate",
			"B_target", "exact_num_blocks", "equal_block_sizes",
			"blocking_capable", "cmh_se_w_mat"
		),
		requires_state = c("t", "Xraw", "y"),
		requires_public_methods = "get_X_raw",
		requires_private_methods = "has_private_method",
		optional_private_methods = "get_or_compute_block_ids",
		provides_capabilities = "blocking"
	))

	matching = get("DesignMatching", envir = ns)
	register_design_component(DesignComponent(
		name = "MatchingStructure",
		status = "active",
		dependencies = "BlockingStructure",
		public = matching$public_methods[c("is_matching_design", "assert_matching_design", "get_matching_cluster_ids")],
		private = matching$private_methods[c(
			"ensure_matching_structure_computed", "reset_matching_caches",
			"init_matching_bootstrap_structure", "draw_matching_bootstrap_indices",
			"compute_matching_cluster_ids", "draw_bootstrap_indices"
		)],
		owns_state = c(
			"matching_capable", "boot_i_reservoir", "boot_n_reservoir", "boot_pair_rows",
			"cluster_id", "cluster_id_m_vec", "lin_xm_m_vec", "lin_xm_structural",
			"xm_m_vec", "xm_structural"
		),
		requires_state = c("m", "n"),
		requires_public_methods = "get_n",
		provides_capabilities = "matching"
	))

	register_design_component(DesignComponent(
		name = "ClusterStructure",
		status = "active",
		private = list(
			# Generalizes DesignFixedCluster's single-level cluster resample and
			# DesignFixedBlockedCluster's two-level strata-then-cluster resample into one
			# implementation. When BlockingStructure was not actually composed alongside
			# this component, `strata_keys` collapses to a single implicit stratum
			# containing every subject, at which point the "within_blocks" branch below
			# reduces algebraically to exactly DesignFixedCluster's own computation
			# (verified both by hand and by a matched-seed golden test against
			# DesignFixedCluster's real output -- fix_design_hierarchy.md, "Follow-Ups
			# From Implementation").
			#
			# Dispatches on `private$blocking_capable` rather than
			# `has_private_method("get_strata_keys")`: the latter was tried first and
			# broke real DesignFixedCluster once it was actually wired to this component
			# (design_fixed_cluster.R), because DesignFixed still (pre "Timing-Family
			# Split") inherits transitively through DesignMatching -> DesignBlocking, so
			# `get_strata_keys` is present on *every* current DesignFixed subclass
			# regardless of whether BlockingStructure was composed -- confirmed via the
			# exact same class of failure documented for BlockingStructure's own
			# `get_or_compute_block_ids` hook family. `blocking_capable` is an explicit
			# capability flag, not an inherited-method probe, so it stays correct
			# (FALSE for DesignFixedCluster, TRUE for DesignFixedBlockedCluster) both
			# before and after the eventual inherit flip -- and is exactly the kind of
			# check this whole migration is moving *toward*.
			draw_bootstrap_indices = function(bootstrap_type = NULL) {
				n = private$t
				cluster_ids = as.character(private$Xraw[1:n, ][[private$cluster_col]])
				strata_keys = if (isTRUE(private$blocking_capable)) {
					private$get_strata_keys()
				} else {
					rep("1", n)
				}
				if (is.null(bootstrap_type) || bootstrap_type == "within_blocks") {
					unique_strata = unique(strata_keys)
					i_b = unlist(lapply(unique_strata, function(stratum) {
						stratum_idx = which(strata_keys == stratum)
						stratum_group_id = match(cluster_ids[stratum_idx], unique(cluster_ids[stratum_idx]))
						stratum_idx[resample_group_rows_cpp(as.integer(stratum_group_id), length(unique(stratum_group_id)))]
					}), use.names = FALSE)
				} else {
					strata_group_id = match(strata_keys, unique(strata_keys))
					i_b = resample_group_rows_cpp(as.integer(strata_group_id), length(unique(strata_group_id)))
				}
				list(i_b = as.integer(i_b), m_vec_b = NULL)
			}
		),
		owns_state = "cluster_col",
		requires_state = c("t", "Xraw", "blocking_capable"),
		optional_private_methods = "get_strata_keys",
		provides_capabilities = "cluster"
	))

	register_design_component(DesignComponent(
		name = "SequentialStrataBootstrap",
		status = "active",
		private = list(
			# Sequential blocking designs cannot use BlockingStructure's matrix-level
			# get_strata_keys()/get_block_ids() path: their strata are formed one row at
			# a time while Xraw grows.  Keep that data model explicit and share the two
			# classes' formerly duplicated row-key/bootstrap implementation here.
			get_strata_key = function(x_row) {
				vals = vapply(private$strata_cols, function(col) {
					val = x_row[[col]]
					if (is.na(val)) "NA" else as.character(val)
				}, character(1))
				paste(vals, collapse = "|")
			},
			draw_bootstrap_indices = function(bootstrap_type = NULL) {
				i_b = if (!isTRUE(private$uses_covariates)) {
					sample_int_replace_cpp(private$t, private$t)
				} else {
					strata_keys = vapply(seq_len(private$t), function(i) {
						private$get_strata_key(private$Xraw[i, ])
					}, character(1))
					group_id = match(strata_keys, unique(strata_keys))
					if (is.null(bootstrap_type) || bootstrap_type == "within_blocks" ||
							!isTRUE(private$sequential_bootstrap_whole_group)) {
						stratified_bootstrap_indices_cpp(as.integer(group_id))
					} else {
						as.integer(resample_group_rows_cpp(
							as.integer(group_id), length(unique(group_id))
						))
					}
				}
				list(i_b = i_b, m_vec_b = NULL)
			}
		),
		# This policy bit preserves the existing difference between the two hosts:
		# SPBR supports whole-stratum resampling; RandomBlockSize has always treated
		# every bootstrap_type as within-stratum (and also supports no strata).
		owns_state = "sequential_bootstrap_whole_group",
		requires_state = c("strata_cols", "uses_covariates", "t", "Xraw")
	))

	greedy = get("DesignFixedGreedy", envir = ns)
	register_design_component(DesignComponent(
		name = "BatchWPregeneration",
		status = "active",
		public = greedy$public_methods["supports_batch_w_pregeneration"],
		provides_capabilities = "batch_w_pregeneration"
	))

	for (component in design_component_registry_as_list()) {
		if (identical(component$status, "scaffold")) next
		validate_design_component_body_references(component)
	}

	invisible(EDI_DESIGN_COMPONENTS)
}

# Invoked here (rather than alongside populate_design_class_registry() in
# design_class_registry.R) so the component registry is populated immediately after
# this file sources -- Collate positions this file right after DesignBlocking/
# DesignMatching/DesignFixedGreedy (the concrete generators its registrations pull
# real references from) and before design_class_factory.R, so that any concrete
# design_*.R file using define_design_class(components = ...) later in the Collate
# order finds a fully-populated component registry to resolve against.
populate_design_component_registry()
