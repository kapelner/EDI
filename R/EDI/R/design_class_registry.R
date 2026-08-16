#' Design Class Metadata Registry
#'
#' The registry is the source of truth for structural metadata used by the future
#' shallow design hierarchy (see \code{fix_design_hierarchy.md}). It is intentionally
#' separated from R6 generator environments so metadata can be validated without
#' instantiating design classes. This file implements only the "Metadata Registry"
#' section of that plan; component registration/resolution (\code{BlockingStructure},
#' \code{MatchingStructure}, etc.) is later work, so \code{direct_components} is always
#' \code{character()} for now.
#'
#' @keywords internal
#' @noRd
EDI_DESIGN_CLASS_REGISTRY = new.env(parent = emptyenv())
EDI_DESIGN_EFFECTIVE_COMPONENTS_CACHE = new.env(parent = emptyenv())
EDI_DESIGN_EFFECTIVE_CAPABILITIES_CACHE = new.env(parent = emptyenv())

EDI_DESIGN_ALLOWED_TIMING_FAMILIES = c("fixed", "sequential")

EDI_DESIGN_ALLOWED_RANDOMIZATION_FAMILIES = c(
	"bernoulli", "complete_randomization", "blocked", "clustered", "blocked_cluster",
	"binary_match", "matching_greedy_pair_switching", "greedy_d_optimal", "greedy",
	"rerandomization", "optimal_blocks", "deterministic_optimal", "factorial",
	"custom_fixed", "kk14", "kk21",
	"kk21_stepwise", "efron", "atkinson", "pocock_simon", "random_block_size", "spbr",
	"urn", "custom_sequential", "none"
)

# The three shared bases that predate the fixed/sequential timing split and therefore
# commit to neither a timing_family nor a randomization_family.
EDI_DESIGN_UNSPLIT_ABSTRACT_CLASS_NAMES = c("Design", "DesignBlocking", "DesignMatching")

# Plus the two timing-family roots themselves, which commit to a timing_family but
# have no single randomization_family (that's the entire point of them being bases).
EDI_DESIGN_ABSTRACT_CLASS_NAMES = c(
	EDI_DESIGN_UNSPLIT_ABSTRACT_CLASS_NAMES,
	"DesignFixed", "DesignSeqOneByOne",
	"DesignFixedCustom", "DesignCustomSequential"
)

# randomization_family is a closed enum naming the *drawing mechanism*, replacing
# is()/inherits() class-name dispatch at inference/simulation call sites (see
# fix_design_hierarchy.md, "Evidence of the Problem" item 5 and "Class-Identity
# Dispatch Replacement" TODOs). Every concrete/extension-base design maps to exactly
# one value; the five unsplit-or-timing-root abstract bases map to NA (no single
# mechanism -- that's what makes them bases).
EDI_DESIGN_RANDOMIZATION_FAMILY_BY_NAME = c(
	DesignFixedBernoulli = "bernoulli",
	DesignFixedBinaryMatch = "binary_match",
	DesignFixedBlockedCluster = "blocked_cluster",
	DesignFixedBlocking = "blocked",
	DesignFixedCluster = "clustered",
	DesignFixedCustom = "custom_fixed",
	DesignFixedFactorial = "factorial",
	DesignFixedGreedy = "greedy",
	DesignFixedGreedyDOptimal = "greedy_d_optimal",
	DesignFixediBCRD = "complete_randomization",
	DesignFixedMatchingGreedyPairSwitching = "matching_greedy_pair_switching",
	# DesignFixedOptimal arrives with design_fixed_optimal.md TODO-9; the mapping
	# is inert until the class exists (populate_design_class_registry() scans the
	# namespace, so an entry with no live class is never read). Capability
	# profile: deterministic single-w* mechanism, so supports_randomization_draw()
	# = FALSE (class-level override, like ObservationalDesign's) but
	# supports_resampling_replay() = TRUE (re-optimize each resample -- the BRT
	# stays eligible, unlike the "none" family, which has no mechanism at all).
	DesignFixedOptimal = "deterministic_optimal",
	DesignFixedOptimalBlocks = "optimal_blocks",
	DesignFixedRerandomization = "rerandomization",
	DesignCustomSequential = "custom_sequential",
	DesignSeqOneByOneKK14 = "kk14",
	DesignSeqOneByOneKK21 = "kk21",
	DesignSeqOneByOneKK21stepwise = "kk21_stepwise",
	DesignSeqOneByOneAtkinson = "atkinson",
	DesignSeqOneByOneBernoulli = "bernoulli",
	DesignSeqOneByOneEfron = "efron",
	DesignSeqOneByOneiBCRD = "complete_randomization",
	DesignSeqOneByOnePocockSimon = "pocock_simon",
	DesignSeqOneByOneRandomBlockSize = "random_block_size",
	DesignSeqOneByOneSPBR = "spbr",
	DesignSeqOneByOneUrn = "urn",
	ObservationalDesign = "none",
	ObservationalDesignBlocks = "none",
	ObservationalDesignMatching = "none"
)

# seed_reproducible_draw: currently no exceptions. The two former exceptions
# (DesignFixedAOptimal/DesignFixedDOptimal, whose kernels used std::random_device)
# were merged into DesignFixedGreedyDOptimal after the RNG migration reseeded
# optimal_design_search.cpp from R's RNG stream (edi_rng::RRng seeded via
# R::unif_rand()), making the draws seed-reproducible -- verified empirically in
# test-greedy-d-optimal-merged.R. NA for the abstract bases, which have no concrete
# draw of their own; TRUE (the register_design_class() default) for everything else.
EDI_DESIGN_NOT_SEED_REPRODUCIBLE_CLASS_NAMES = character(0)

EDI_DESIGN_BATCH_W_PREGENERATION_CLASS_NAMES = c(
	"DesignFixedBinaryMatch", "DesignFixedGreedy",
	"DesignFixedMatchingGreedyPairSwitching", "DesignFixedOptimalBlocks"
)

EDI_DESIGN_REQUIRED_PACKAGES_BY_NAME = list(
	DesignFixedBinaryMatch = "nbpMatching",
	DesignFixedMatchingGreedyPairSwitching = "nbpMatching",
	DesignFixedBlocking = "randomizr",
	DesignFixedCluster = "randomizr",
	DesignFixedBlockedCluster = "randomizr",
	DesignFixedOptimalBlocks = c("anticlust", "blockTools", "ompr", "ompr.roi", "ROI.plugin.glpk", "randomizr"),
	# Needed only when the "ompr" solver path is actually invoked (lazy check at
	# solve time via assert_optimal_roi_solver(); the native annealing solver has
	# no package requirements). Commercial ROI plugins are deliberately NOT
	# listed: see design_fixed_optimal.md's "never Suggests" rule.
	DesignFixedOptimal = c("ompr", "ompr.roi", "ROI.plugin.glpk")
)

is_design_r6_generator = function(obj) {
	if (!inherits(obj, "R6ClassGenerator")) return(FALSE)
	anc = obj
	while (!is.null(anc)) {
		if (identical(anc$classname, "Design")) return(TRUE)
		anc = anc$get_inherit()
	}
	FALSE
}

# Structural, not name-based: walks the real R6 inheritance chain (including the
# class itself) looking for DesignFixed/DesignSeqOneByOne, so a new subclass is
# classified correctly with zero registry maintenance. Returns NA for the three
# bases that predate the timing split (Design, DesignBlocking, DesignMatching).
infer_design_timing_family = function(obj) {
	anc = obj
	while (!is.null(anc)) {
		if (identical(anc$classname, "DesignFixed")) return("fixed")
		if (identical(anc$classname, "DesignSeqOneByOne")) return("sequential")
		anc = anc$get_inherit()
	}
	NA_character_
}

infer_design_randomization_family = function(name) {
	if (name %in% EDI_DESIGN_UNSPLIT_ABSTRACT_CLASS_NAMES || name %in% c("DesignFixed", "DesignSeqOneByOne")) {
		return(NA_character_)
	}
	family = unname(EDI_DESIGN_RANDOMIZATION_FAMILY_BY_NAME[name])
	if (is.na(family)) {
		stop(sprintf(
			"No randomization_family mapping registered for design class %s. Add one to EDI_DESIGN_RANDOMIZATION_FAMILY_BY_NAME.",
			name
		), call. = FALSE)
	}
	family
}

infer_design_abstract = function(name) {
	name %in% EDI_DESIGN_ABSTRACT_CLASS_NAMES
}

infer_design_seed_reproducible_draw = function(name) {
	if (name %in% EDI_DESIGN_ABSTRACT_CLASS_NAMES) return(NA)
	!(name %in% EDI_DESIGN_NOT_SEED_REPRODUCIBLE_CLASS_NAMES)
}

infer_design_supports_batch_w_pregeneration = function(name) {
	name %in% EDI_DESIGN_BATCH_W_PREGENERATION_CLASS_NAMES
}

infer_design_required_packages = function(name) {
	pkgs = EDI_DESIGN_REQUIRED_PACKAGES_BY_NAME[[name]]
	if (is.null(pkgs)) character() else pkgs
}

validate_design_class_metadata = function(metadata) {
	required = c(
		"name", "parent", "abstract", "exported", "timing_family",
		"randomization_family", "seed_reproducible_draw", "direct_components",
		"supports_batch_w_pregeneration", "required_packages"
	)
	missing = setdiff(required, names(metadata))
	if (length(missing) > 0L) {
		stop(sprintf(
			"Design metadata for %s is missing required field(s): %s",
			if (is.null(metadata$name)) "<unknown>" else metadata$name,
			paste(missing, collapse = ", ")
		), call. = FALSE)
	}
	if (!is.character(metadata$name) || length(metadata$name) != 1L || !nzchar(metadata$name)) {
		stop("Design metadata field `name` must be a non-empty character scalar.", call. = FALSE)
	}
	if (!(is.null(metadata$parent) || (is.character(metadata$parent) && length(metadata$parent) == 1L && nzchar(metadata$parent)))) {
		stop(sprintf("Design metadata for %s has invalid `parent`.", metadata$name), call. = FALSE)
	}
	if (!is.logical(metadata$abstract) || length(metadata$abstract) != 1L || is.na(metadata$abstract)) {
		stop(sprintf("Design metadata for %s has invalid `abstract`.", metadata$name), call. = FALSE)
	}
	# NA is a valid, deliberate sentinel here (unlike most other logical metadata
	# fields): it means "not yet resolved against the live namespace", resolved
	# lazily by get_design_class_metadata()/design_class_registry_as_list() -- see
	# the notes there for why eager resolution at populate-time is unreliable.
	if (!is.logical(metadata$exported) || length(metadata$exported) != 1L) {
		stop(sprintf("Design metadata for %s has invalid `exported`.", metadata$name), call. = FALSE)
	}
	if (!is.character(metadata$timing_family) || length(metadata$timing_family) != 1L) {
		stop(sprintf("Design metadata for %s has invalid `timing_family`.", metadata$name), call. = FALSE)
	}
	timing_family_ok = is.na(metadata$timing_family) || metadata$timing_family %in% EDI_DESIGN_ALLOWED_TIMING_FAMILIES
	if (!timing_family_ok) {
		stop(sprintf(
			"Design metadata for %s has invalid `timing_family`: %s",
			metadata$name, metadata$timing_family
		), call. = FALSE)
	}
	if (isTRUE(is.na(metadata$timing_family)) && !(metadata$name %in% EDI_DESIGN_UNSPLIT_ABSTRACT_CLASS_NAMES)) {
		stop(sprintf(
			"Design metadata for %s has NA `timing_family`, but only %s may leave it unset.",
			metadata$name, paste(EDI_DESIGN_UNSPLIT_ABSTRACT_CLASS_NAMES, collapse = ", ")
		), call. = FALSE)
	}
	if (!is.character(metadata$randomization_family) || length(metadata$randomization_family) != 1L) {
		stop(sprintf("Design metadata for %s has invalid `randomization_family`.", metadata$name), call. = FALSE)
	}
	randomization_family_ok = is.na(metadata$randomization_family) ||
		metadata$randomization_family %in% EDI_DESIGN_ALLOWED_RANDOMIZATION_FAMILIES
	if (!randomization_family_ok) {
		stop(sprintf(
			"Design metadata for %s has invalid `randomization_family`: %s",
			metadata$name, metadata$randomization_family
		), call. = FALSE)
	}
	if (isTRUE(is.na(metadata$randomization_family)) &&
			!(metadata$name %in% EDI_DESIGN_UNSPLIT_ABSTRACT_CLASS_NAMES) &&
			!(metadata$name %in% c("DesignFixed", "DesignSeqOneByOne"))) {
		stop(sprintf(
			"Design metadata for %s has NA `randomization_family`, but only the unsplit/timing-root bases may leave it unset.",
			metadata$name
		), call. = FALSE)
	}
	if (!is.logical(metadata$seed_reproducible_draw) || length(metadata$seed_reproducible_draw) != 1L) {
		stop(sprintf("Design metadata for %s has invalid `seed_reproducible_draw`.", metadata$name), call. = FALSE)
	}
	if (!is.character(metadata$direct_components)) {
		stop(sprintf("Design metadata for %s has invalid `direct_components`.", metadata$name), call. = FALSE)
	}
	if (!is.logical(metadata$supports_batch_w_pregeneration) || length(metadata$supports_batch_w_pregeneration) != 1L || is.na(metadata$supports_batch_w_pregeneration)) {
		stop(sprintf("Design metadata for %s has invalid `supports_batch_w_pregeneration`.", metadata$name), call. = FALSE)
	}
	if (!is.character(metadata$required_packages)) {
		stop(sprintf("Design metadata for %s has invalid `required_packages`.", metadata$name), call. = FALSE)
	}
	invisible(TRUE)
}

register_design_class = function(name, parent = NULL, metadata = list(), direct_components = character()) {
	record = utils::modifyList(
		list(
			name = name,
			parent = parent,
			abstract = FALSE,
			exported = FALSE,
			timing_family = NA_character_,
			randomization_family = NA_character_,
			seed_reproducible_draw = NA,
			direct_components = direct_components,
			supports_batch_w_pregeneration = FALSE,
			required_packages = character()
		),
		metadata
	)
	record$name = name
	record["parent"] = list(parent)
	record$direct_components = direct_components
	validate_design_class_metadata(record)
	if (exists(name, envir = EDI_DESIGN_CLASS_REGISTRY, inherits = FALSE)) {
		stop(sprintf("Design class metadata already registered for %s.", name), call. = FALSE)
	}
	assign(name, record, envir = EDI_DESIGN_CLASS_REGISTRY)
	clear_design_effective_metadata_cache()
	invisible(record)
}

design_class_registry_as_list = function() {
	records = mget(ls(EDI_DESIGN_CLASS_REGISTRY), envir = EDI_DESIGN_CLASS_REGISTRY, inherits = FALSE)
	unresolved = vapply(records, function(r) is.na(r$exported), logical(1))
	if (any(unresolved)) {
		live_exports = tryCatch(getNamespaceExports("EDI"), error = function(e) character())
		for (name in names(records)[unresolved]) {
			records[[name]]$exported = name %in% live_exports
		}
	}
	records
}

validate_design_class_registry = function(registry = design_class_registry_as_list()) {
	if (!is.list(registry)) {
		stop("Design class registry must be a list of metadata records.", call. = FALSE)
	}
	for (name in names(registry)) {
		validate_design_class_metadata(registry[[name]])
		if (!identical(registry[[name]]$name, name)) {
			stop(sprintf("Design metadata name mismatch for registry key %s.", name), call. = FALSE)
		}
		parent = registry[[name]]$parent
		if (!is.null(parent) && !(parent %in% names(registry))) {
			stop(sprintf("Design metadata for %s has unregistered parent %s.", name, parent), call. = FALSE)
		}
	}
	invisible(TRUE)
}

get_design_class_metadata = function(name) {
	if (!exists(name, envir = EDI_DESIGN_CLASS_REGISTRY, inherits = FALSE)) {
		stop(sprintf("No design class metadata registered for %s.", name), call. = FALSE)
	}
	record = get(name, envir = EDI_DESIGN_CLASS_REGISTRY, inherits = FALSE)
	# `exported = NA` is a populate-time sentinel (see populate_design_class_registry())
	# meaning "not yet resolved against the live namespace" -- resolved here instead of
	# at populate-time because, under devtools::load_all(), NAMESPACE exports aren't
	# attached until after this file's top-level populate_design_class_registry() call
	# runs (confirmed empirically -- even inside .onLoad() -- so getNamespaceExports("EDI")
	# returns everything as unexported at populate-time regardless of ordering within the
	# R/ sourcing sequence; read-time is late enough that exports are always attached by
	# then). A non-NA value means the record was registered explicitly (e.g. a test's
	# register_design_class() call) and is trusted as-is, not overwritten.
	if (is.na(record$exported)) {
		record$exported = name %in% tryCatch(getNamespaceExports("EDI"), error = function(e) character())
	}
	record
}

get_direct_design_components = function(name) {
	get_design_class_metadata(name)$direct_components
}

clear_design_effective_metadata_cache = function() {
	rm(list = ls(EDI_DESIGN_EFFECTIVE_COMPONENTS_CACHE), envir = EDI_DESIGN_EFFECTIVE_COMPONENTS_CACHE)
	rm(list = ls(EDI_DESIGN_EFFECTIVE_CAPABILITIES_CACHE), envir = EDI_DESIGN_EFFECTIVE_CAPABILITIES_CACHE)
	invisible(TRUE)
}

# No DesignComponent registry exists yet (see fix_design_hierarchy.md's "Component
# Registry"/"Component Extraction" TODOs, not yet implemented) -- direct_components is
# always character() today, so this just walks the metadata chain for a future-proof
# shape. Once components exist, this gets the same dependency-resolution treatment as
# resolve_inference_components().
resolve_design_components = function(name) {
	metadata = get_design_class_metadata(name)
	parent_components = if (is.null(metadata$parent)) {
		character()
	} else {
		resolve_design_components(metadata$parent)
	}
	duplicate_components = intersect(parent_components, metadata$direct_components)
	if (length(duplicate_components) > 0L) {
		stop(sprintf(
			"%s re-lists inherited component(s): %s",
			name, paste(duplicate_components, collapse = ", ")
		), call. = FALSE)
	}
	direct_components = tryCatch(
		resolve_design_component_dependencies(
			metadata$direct_components,
			satisfied_components = parent_components
		),
		error = function(e) {
			stop(sprintf("%s: %s", name, conditionMessage(e)), call. = FALSE)
		}
	)
	duplicate_transitive = intersect(parent_components, direct_components)
	if (length(duplicate_transitive) > 0L) {
		stop(sprintf(
			"%s duplicates inherited transitive component(s): %s",
			name, paste(duplicate_transitive, collapse = ", ")
		), call. = FALSE)
	}
	c(parent_components, direct_components)
}

get_effective_design_components = function(name) {
	if (exists(name, envir = EDI_DESIGN_EFFECTIVE_COMPONENTS_CACHE, inherits = FALSE)) {
		return(get(name, envir = EDI_DESIGN_EFFECTIVE_COMPONENTS_CACHE, inherits = FALSE))
	}
	components = resolve_design_components(name)
	assign(name, components, envir = EDI_DESIGN_EFFECTIVE_COMPONENTS_CACHE)
	components
}

# Until real DesignComponent()s exist, effective capabilities are just the
# class-owned scalars restated as named booleans/strings so callers have one query
# surface (design_obj$supports("blocking")/randomization_family()/etc. get built on
# top of this once the public Design$capabilities()/supports() API lands -- that's a
# later TODO section, not this one).
get_effective_design_capabilities = function(name) {
	if (exists(name, envir = EDI_DESIGN_EFFECTIVE_CAPABILITIES_CACHE, inherits = FALSE)) {
		return(get(name, envir = EDI_DESIGN_EFFECTIVE_CAPABILITIES_CACHE, inherits = FALSE))
	}
	component_capabilities = as.character(unlist(lapply(get_effective_design_components(name), function(component_name) {
		get_design_component(component_name)$provides_capabilities
	}), use.names = FALSE))
	capabilities = unique(component_capabilities)
	assign(name, capabilities, envir = EDI_DESIGN_EFFECTIVE_CAPABILITIES_CACHE)
	capabilities
}

clear_design_class_registry = function() {
	rm(list = ls(EDI_DESIGN_CLASS_REGISTRY), envir = EDI_DESIGN_CLASS_REGISTRY)
	clear_design_effective_metadata_cache()
	invisible(TRUE)
}

populate_design_class_registry = function(ns = environment(populate_design_class_registry)) {
	clear_design_class_registry()
	all_names = sort(ls(ns))
	for (name in all_names) {
		obj = get(name, envir = ns)
		if (!is_design_r6_generator(obj)) next
		if (!identical(obj$classname, name)) next
		parent_gen = obj$get_inherit()
		parent_name = if (is.null(parent_gen)) NULL else parent_gen$classname
		register_design_class(
			name = name,
			parent = parent_name,
			metadata = list(
				abstract = infer_design_abstract(name),
				# NA sentinel: getNamespaceExports("EDI") is unreliable this early in the
				# sourcing sequence (see get_design_class_metadata()'s note); resolved
				# lazily on read instead of computed here.
				exported = NA,
				timing_family = infer_design_timing_family(obj),
				randomization_family = infer_design_randomization_family(name),
				seed_reproducible_draw = infer_design_seed_reproducible_draw(name),
				supports_batch_w_pregeneration = infer_design_supports_batch_w_pregeneration(name),
				required_packages = infer_design_required_packages(name)
			),
			direct_components = character()
		)
	}
	validate_design_class_registry()
	invisible(EDI_DESIGN_CLASS_REGISTRY)
}

# Class/generator-level (not instance-level) capability read, for call sites that
# only have an R6ClassGenerator in hand (e.g. SimulationFramework's private
# `design_classes` list of generators, not instances) -- replaces the
# generator-shape-sniffing pattern `!is.null(dc$public_methods$supports_batch_w_pregeneration)`
# (fix_design_hierarchy.md, "Evidence of the Problem" item 6) with a real metadata
# read. Falls back to the old shape-sniffing check for any generator not in the
# registry (e.g. a user-defined third-party Design subclass never scanned by
# populate_design_class_registry(), which only walks the EDI package namespace),
# so custom/extension designs are not silently misclassified.
design_class_generator_supports_batch_w_pregeneration = function(dc) {
	metadata = tryCatch(get_design_class_metadata(dc$classname), error = function(e) NULL)
	if (!is.null(metadata)) return(isTRUE(metadata$supports_batch_w_pregeneration))
	!is.null(dc$public_methods$supports_batch_w_pregeneration)
}

# populate_design_component_registry() now lives in design_component_registry.R
# itself (Collate positions it early, right after DesignBlocking/DesignMatching/
# DesignFixedGreedy, so concrete design_*.R files can compose components via
# define_design_class() as they source). This file's own populate call must stay
# late (this file's Collate position is last among the design_*.R files) since it
# does a full namespace scan that needs every Design generator -- abstract and
# concrete -- already defined.
populate_design_class_registry()
