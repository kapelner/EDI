library(testthat)
library(EDI)

test_that("design component descriptors validate metadata consistency", {
  component <- EDI:::DesignComponent(
    name = "EphemeralTestComponent",
    public = list(ping = function() TRUE),
    private = list(counter = 0L),
    owns_state = "counter"
  )
  expect_identical(component$status, "active")
  expect_identical(EDI:::design_component_public_names(component), "ping")
  expect_identical(EDI:::design_component_private_names(component), character())

  stale <- component
  stale$provides_public_methods <- "missing"
  expect_error(EDI:::validate_design_component(stale), "stale public method metadata")
  missing_state <- component
  missing_state$owns_state <- "absent"
  expect_error(EDI:::validate_design_component(missing_state), "does not provide owned private state")
  expect_error(EDI:::get_design_component("DefinitelyMissingComponent"), "No design component registered")
})

test_that("component dependency resolver rejects duplicate, unknown, and scaffold inputs", {
  expect_error(EDI:::resolve_design_component_dependencies(c("BlockingStructure", "BlockingStructure")),
               "Duplicate direct")
  expect_error(EDI:::resolve_design_component_dependencies("DefinitelyMissingComponent"), "Unknown design component")
  resolved <- EDI:::resolve_design_component_dependencies("MatchingStructure")
  expect_true("MatchingStructure" %in% resolved)
  expect_false(anyDuplicated(resolved) > 0L)
})

test_that("design factory helpers classify entries and enforce unlocked generators", {
  entries <- list(method = function() NULL, state = 1)
  expect_identical(EDI:::design_entry_kinds(entries), c(method = "method", state = "state"))
  expect_identical(EDI:::design_entry_kinds(list()), character())
  normalized <- EDI:::normalise_design_overrides(list(public = "x"))
  expect_identical(normalized$public, "x")
  expect_identical(normalized$private, character())
  expect_identical(normalized$public_private, character())
  expect_error(EDI:::define_design_class("LockedTestDesign", lock_objects = TRUE),
               "lock_objects = FALSE")
})

test_that("package-load registries expose coherent design metadata", {
  registry <- EDI:::design_class_registry_as_list()
  expect_true(all(c("DesignFixedCluster", "ObservationalDesign", "DesignSeqOneByOneKK21") %in% names(registry)))
  observational <- EDI:::get_design_class_metadata("ObservationalDesign")
  expect_identical(observational$randomization_family, "none")
  expect_identical(observational$timing_family, "fixed")
  expect_error(EDI:::get_design_class_metadata("DefinitelyMissingDesign"), "No design class metadata")
  expect_true(EDI:::is_design_class_abstract("DesignFixedCustom"))
  expect_false(EDI:::is_design_class_abstract("DesignFixedCluster"))
})

test_that("global scalar helpers recognize separation, control conditions, and constant weights", {
  expect_false(EDI:::is_separated_coefficient_magnitude(c(NA, Inf)))
  expect_true(EDI:::is_separated_coefficient_magnitude(c(0, 100), threshold = 20))
  expect_false(EDI:::is_separated_coefficient_magnitude(c(-2, 3), threshold = 20))
  expect_true(EDI:::is_edi_control_condition(simpleError("reached elapsed time limit")))
  expect_false(EDI:::is_edi_control_condition(simpleError("ordinary fit failure")))
  expect_true(EDI:::weights_are_effectively_constant(c(1, 1 + 1e-12)))
  expect_false(EDI:::weights_are_effectively_constant(c(1, 1 + 1e-12, NA)))
  expect_false(EDI:::weights_are_effectively_constant(c(1, 2)))
  expect_false(EDI:::weights_are_effectively_constant(c(NA, Inf)))
})

test_that("design compatibility helper uses reason codes as message keys", {
  expect_null(EDI:::stop_if_design_incompatible(function(x) NA_character_, NULL,
                                                 list(bad = "not compatible")))
  expect_error(EDI:::stop_if_design_incompatible(function(x) "bad", NULL,
                                                  list(bad = "not compatible")),
               "not compatible")
})

test_that("custom fixed designs validate extension output shape and values", {
  GoodCustom <- R6::R6Class(
    "GoodCustom", inherit = EDI:::DesignFixedCustom,
    public = list(draw_assignments = function(r = 1) {
      matrix(rep(rep(c(0, 1), length.out = self$get_n()), r), nrow = self$get_n(), ncol = r)
    })
  )
  good <- GoodCustom$new(response_type = "continuous", n = 6)
  good$add_all_subjects_to_experiment(data.frame(x = 1:6))
  good$assign_w_to_all_subjects()
  expect_equal(good$get_w(), rep(c(0, 1), 3))

  BadShape <- R6::R6Class("BadShape", inherit = EDI:::DesignFixedCustom,
    public = list(draw_assignments = function(r = 1) matrix(0, 1, 1)))
  bad_shape <- BadShape$new(response_type = "continuous", n = 4)
  bad_shape$add_all_subjects_to_experiment(data.frame(x = 1:4))
  expect_error(bad_shape$assign_w_to_all_subjects(), "n x r")

  BadValues <- R6::R6Class("BadValues", inherit = EDI:::DesignFixedCustom,
    public = list(draw_assignments = function(r = 1) matrix(2, self$get_n(), r)))
  bad_values <- BadValues$new(response_type = "continuous", n = 4)
  bad_values$add_all_subjects_to_experiment(data.frame(x = 1:4))
  expect_error(bad_values$assign_w_to_all_subjects(), "only 0/1")
})

test_that("custom sequential designs validate assignment rules", {
  CoinCustom <- R6::R6Class("CoinCustom", inherit = EDI:::DesignCustomSequential,
    public = list(assignment_rule = function() 1))
  good <- CoinCustom$new(response_type = "continuous", n = 1)
  expect_equal(good$add_one_subject_to_experiment_and_assign(data.frame(x = 1)), 1)

  BadCustom <- R6::R6Class("BadCustom", inherit = EDI:::DesignCustomSequential,
    public = list(assignment_rule = function() 2))
  bad <- BadCustom$new(response_type = "continuous", n = 1)
  expect_error(bad$add_one_subject_to_experiment_and_assign(data.frame(x = 1)), "Must be element")
})

test_that("observational design advertises no randomization but accepts imbalance", {
  des <- ObservationalDesign$new(response_type = "continuous", n = 6)
  expect_false(des$supports_randomization_draw())
  expect_false(des$supports_resampling_replay())
  des$add_all_subjects_to_experiment(data.frame(x = 1:6))
  des$assign_w_to_all_subjects(w_precomputed = c(1, 1, 1, 1, 1, 0))
  expect_null(des$assert_even_allocation())
  expect_error(des$draw_ws_according_to_design(), "not supported")
})
