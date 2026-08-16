test_that("inference factory validation sees the full R6 ancestor chain", {
	Root = R6::R6Class(
		"TransitiveInferenceFactoryRoot",
		lock_objects = FALSE,
		public = list(root_public_method = function() TRUE),
		active = list(root_active_binding = function(value) {
			if (!missing(value)) stop("read-only")
			TRUE
		}),
		private = list(
			root_private_method = function() TRUE,
			root_private_state = NULL
		)
	)
	Middle = R6::R6Class(
		"TransitiveInferenceFactoryMiddle",
		lock_objects = FALSE,
		inherit = Root,
		public = list(middle_public_method = function() TRUE),
		private = list(middle_private_method = function() TRUE)
	)
	LeafParent = R6::R6Class(
		"TransitiveInferenceFactoryLeafParent",
		lock_objects = FALSE,
		inherit = Middle
	)

	public_names = EDI:::r6_inherited_public_names(LeafParent)
	private_names = EDI:::r6_inherited_private_names(LeafParent)

	expect_setequal(
		intersect(public_names, c("root_public_method", "root_active_binding", "middle_public_method")),
		c("root_public_method", "root_active_binding", "middle_public_method")
	)
	expect_setequal(
		intersect(private_names, c("root_private_method", "root_private_state", "middle_private_method")),
		c("root_private_method", "root_private_state", "middle_private_method")
	)

	component_name = "TransitiveInferenceFactoryRequirementProbe"
	component = EDI:::InferenceComponent(
		name = component_name,
		file = "synthetic-transitive-inheritance-probe.R",
		requires_public_methods = c("root_public_method", "root_active_binding"),
		requires_private_methods = "root_private_method",
		requires_state = "root_private_state"
	)
	assign(component_name, component, envir = EDI:::EDI_INFERENCE_COMPONENTS)
	on.exit(rm(list = component_name, envir = EDI:::EDI_INFERENCE_COMPONENTS), add = TRUE)

	expect_silent(EDI:::validate_inference_class_definition(
		classname = "TransitiveInferenceFactoryProbe",
		inherit = LeafParent,
		component_names = component_name
	))
})

test_that("inference ancestor inspection tolerates a not-yet-loaded lazy parent", {
	lazy_env = new.env(parent = globalenv())
	LazyChild = eval(quote(R6::R6Class(
		"LazyInferenceFactoryChild",
		lock_objects = FALSE,
		inherit = LazyInferenceFactoryParent,
		public = list(child_public_method = function() TRUE),
		private = list(child_private_method = function() TRUE)
	)), envir = lazy_env)

	expect_true("child_public_method" %in% EDI:::r6_inherited_public_names(LazyChild))
	expect_true("child_private_method" %in% EDI:::r6_inherited_private_names(LazyChild))
})
