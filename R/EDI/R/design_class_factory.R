#' Design Class Factory
#'
#' Implements the "Class Factory Implementation" TODO section of
#' `fix_design_hierarchy.md`: \code{define_design_class()} and its assembly/
#' validation helpers, mirroring \code{define_inference_class()}
#' (\code{contracts_mixins.R}) but scoped down the same way \code{DesignComponent()}
#' was scoped down from \code{InferenceComponent()} -- no lazy loading, no
#' likelihood tiers, no \code{super$} category, and no \code{capability_requires}
#' table (\code{Design}'s capability model has no per-capability required-method
#' table the way \code{Inference}'s does; add one later if a real need for it
#' emerges, don't build it speculatively now).
#'
#' Registration in \code{EDI_DESIGN_CLASS_REGISTRY} is NOT done by this factory --
#' exactly like \code{define_inference_class()}, which also never calls
#' \code{register_inference_class()}. Every \code{Design} generator, however built,
#' is picked up uniformly by \code{populate_design_class_registry()}'s namespace
#' scan at package-load time. Calling \code{register_design_class()} here too would
#' double-register and error.
#'
#' @keywords internal
#' @noRd

design_entry_kinds = function(entries) {
	if (length(entries) == 0L) return(character())
	stats::setNames(
		ifelse(vapply(entries, is.function, logical(1L)), "method", "state"),
		names(entries)
	)
}

normalise_design_overrides = function(overrides = list()) {
	list(
		public = if (is.null(overrides$public)) character() else overrides$public,
		private = if (is.null(overrides$private)) character() else overrides$private,
		public_private = if (is.null(overrides$public_private)) character() else overrides$public_private
	)
}

# Mirrors combine_component_slot() (contracts_mixins.R), parametrized against
# EDI_DESIGN_COMPONENTS instead of EDI_INFERENCE_COMPONENTS, with no lazy-loading
# branch (no Design component is lazy).
combine_design_component_slot = function(target_name, component_names, slot, host_entries = list(), overrides = list(), resolve = TRUE) {
	overrides = normalise_design_overrides(overrides)
	if (isTRUE(resolve)) {
		component_names = resolve_design_component_dependencies(component_names)
	}
	allowed = overrides[[slot]]
	combined = list()
	combined_kinds = character()
	for (component_name in component_names) {
		component = get_design_component(component_name)
		component_entries = as.list(component[[slot]])
		incoming_names = names(component_entries)
		if (is.null(incoming_names)) incoming_names = character()
		incoming_kinds = design_entry_kinds(component_entries)
		collisions = intersect(names(combined), incoming_names)
		kind_collisions = collisions[combined_kinds[collisions] != incoming_kinds[collisions]]
		undeclared_kind_collisions = setdiff(kind_collisions, allowed)
		if (length(undeclared_kind_collisions) > 0L) {
			stop(sprintf(
				"%s has undeclared %s method/state collision(s): %s",
				target_name, slot, paste(undeclared_kind_collisions, collapse = ", ")
			), call. = FALSE)
		}
		undeclared = setdiff(collisions, allowed)
		if (length(undeclared) > 0L) {
			stop(sprintf(
				"%s has undeclared %s component collision(s): %s",
				target_name, slot, paste(undeclared, collapse = ", ")
			), call. = FALSE)
		}
		combined = utils::modifyList(combined, component_entries)
		combined_kinds = design_entry_kinds(combined)
	}
	host_names = names(host_entries)
	if (is.null(host_names)) host_names = character()
	host_collisions = intersect(names(combined), host_names)
	undeclared_host_collisions = setdiff(host_collisions, allowed)
	if (length(undeclared_host_collisions) > 0L) {
		stop(sprintf(
			"%s overrides component %s member(s) without declaration: %s",
			target_name, slot, paste(undeclared_host_collisions, collapse = ", ")
		), call. = FALSE)
	}
	host_kinds = design_entry_kinds(host_entries)
	kind_collisions = host_collisions[combined_kinds[host_collisions] != host_kinds[host_collisions]]
	undeclared_kind_collisions = setdiff(kind_collisions, allowed)
	if (length(undeclared_kind_collisions) > 0L) {
		stop(sprintf(
			"%s overrides component %s method/state member(s) without declaration: %s",
			target_name, slot, paste(undeclared_kind_collisions, collapse = ", ")
		), call. = FALSE)
	}
	utils::modifyList(combined, host_entries)
}

assemble_design_public = function(target_name, component_names = character(), public = list(), overrides = list(), resolve = TRUE) {
	combine_design_component_slot(target_name, component_names, "public", public, overrides, resolve)
}

assemble_design_private = function(target_name, component_names = character(), private = list(), overrides = list(), resolve = TRUE) {
	combine_design_component_slot(target_name, component_names, "private", private, overrides, resolve)
}

# R6 generator $public_methods/$private_methods only ever list what THAT specific
# class defines directly, never what it inherits transitively -- confirmed
# empirically (DesignFixedBlocking$public_methods$is_blocking_design is NULL, since
# is_blocking_design is defined on the ancestor DesignBlocking, not redefined on
# DesignFixedBlocking itself). contracts_mixins.R's equivalent helpers
# (r6_inherited_public_names()/r6_inherited_private_names()) only walk one level,
# which is sufficient there because every currently-migrated Inference class
# inherits `Inference` directly (zero intermediate levels). Design's target
# architecture explicitly keeps multi-level family bases legitimate (the KK
# sequential-matching family: DesignSeqOneByOneKK14 -> DesignSeqOneByOneKK21 ->
# DesignSeqOneByOneKK21stepwise, plus DesignFixed/DesignSeqOneByOne -> Design
# themselves during the transition before "Timing-Family Split" lands), so a
# component requiring a root Design method (e.g. BlockingStructure's requires_
# public_methods = "get_X_raw") several hops up the chain must still be found --
# confirmed by direct testing: a one-level lookup missed `get_X_raw` for a class
# declared `inherit = DesignFixed` while DesignFixed still (pre-split) sits three
# hops below Design. These two helpers walk the full `get_inherit()` chain instead.
design_r6_inherited_public_names = function(inherit) {
	collected = character()
	gen = inherit
	while (!is.null(gen)) {
		nm = names(gen$public_methods)
		nm2 = names(gen$active)
		collected = c(collected, if (is.null(nm)) character() else nm, if (is.null(nm2)) character() else nm2)
		gen = gen$get_inherit()
	}
	unique(collected)
}

design_r6_inherited_private_names = function(inherit) {
	collected = character()
	gen = inherit
	while (!is.null(gen)) {
		nm = names(gen$private_methods)
		nm2 = names(gen$private_fields)
		collected = c(collected, if (is.null(nm)) character() else nm, if (is.null(nm2)) character() else nm2)
		gen = gen$get_inherit()
	}
	unique(collected)
}

validate_design_class_definition = function(
		classname,
		inherit = NULL,
		component_names = character(),
		public = list(),
		private = list(),
		active = NULL,
		overrides = list(),
		resolve_components = TRUE
	) {
	overrides = normalise_design_overrides(overrides)
	if (isTRUE(resolve_components)) {
		component_names = resolve_design_component_dependencies(component_names)
	}
	components = lapply(component_names, get_design_component)

	public_names = unique(c(
		design_r6_inherited_public_names(inherit),
		names(public), names(active)
	))
	private_names = unique(c(design_r6_inherited_private_names(inherit), names(private)))

	public_private_overlap = intersect(public_names, private_names)
	undeclared_overlap = setdiff(public_private_overlap, overrides$public_private)
	if (length(undeclared_overlap) > 0L) {
		stop(sprintf(
			"%s has undeclared public/private name duplication: %s",
			classname, paste(undeclared_overlap, collapse = ", ")
		), call. = FALSE)
	}

	for (component in components) {
		missing_public = setdiff(component$requires_public_methods, public_names)
		if (length(missing_public) > 0L) {
			stop(sprintf(
				"%s is missing public method(s) required by %s: %s",
				classname, component$name, paste(missing_public, collapse = ", ")
			), call. = FALSE)
		}
		missing_private = setdiff(component$requires_private_methods, private_names)
		if (length(missing_private) > 0L) {
			stop(sprintf(
				"%s is missing private method(s) required by %s: %s",
				classname, component$name, paste(missing_private, collapse = ", ")
			), call. = FALSE)
		}
		missing_state = setdiff(component$requires_state, private_names)
		if (length(missing_state) > 0L) {
			stop(sprintf(
				"%s is missing private state required by %s: %s",
				classname, component$name, paste(missing_state, collapse = ", ")
			), call. = FALSE)
		}
	}
	invisible(TRUE)
}

define_design_class = function(
		classname,
		inherit = NULL,
		components = character(),
		public = list(),
		private = list(),
		active = NULL,
		overrides = list(),
		lock_objects = FALSE,
		...
	) {
	if (!identical(lock_objects, FALSE)) {
		stop("define_design_class() must keep `lock_objects = FALSE` until the R6 tree is stable.", call. = FALSE)
	}
	component_names = resolve_design_component_dependencies(components)
	assembled_public = assemble_design_public(classname, component_names, public, overrides, resolve = FALSE)
	assembled_private = assemble_design_private(classname, component_names, private, overrides, resolve = FALSE)
	validate_design_class_definition(
		classname = classname,
		inherit = inherit,
		component_names = component_names,
		public = assembled_public,
		private = assembled_private,
		active = active,
		overrides = overrides,
		resolve_components = FALSE
	)
	R6::R6Class(
		classname = classname,
		lock_objects = FALSE,
		inherit = inherit,
		public = assembled_public,
		private = assembled_private,
		active = active,
		...
	)
}
