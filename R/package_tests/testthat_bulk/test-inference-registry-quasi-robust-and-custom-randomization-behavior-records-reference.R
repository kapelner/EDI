library(testthat)
library(EDI)

# Registry behavior-record builders for quasi/robust estimators and custom
# randomization hosts, their group/manifest wrappers and guards.

ns <- function(x) get(x, envir = asNamespace("EDI"))

test_that("quasi/robust records mirror their registered targets and fixed target tier/parent", {
	nm <- ns("EDI_QUASI_ROBUST_CLASS_NAMES")[1]
	tgt <- ns("EDI_QUASI_ROBUST_TARGETS")[[nm]]
	rec <- ns("build_quasi_robust_behavior_record")(nm)
	expect_equal(rec$name, nm)
	expect_equal(rec$estimator_family, tgt$estimator_family)
	expect_equal(rec$behavior, tgt$behavior)
	expect_equal(rec$target_parent, "Inference")
	expect_equal(rec$target_likelihood_tier, "quasi")
	expect_equal(rec$composite_likelihood_tests_component, isTRUE(tgt$composite_likelihood_tests_component))
	expect_equal(rec$composite_likelihood_public_methods, tgt$composite_likelihood_public_methods %||% character())
	expect_equal(rec$current_effective_components, ns("get_effective_components")(nm))
	expect_equal(rec$current_effective_capabilities, ns("get_effective_capabilities")(nm))
	expect_error(ns("build_quasi_robust_behavior_record")("NotAClass"), "not a registered quasi/robust migration target")
})

test_that("quasi/robust behavior groups partition class names by behavior, sorted, and reject unknown classes", {
	grp <- ns("quasi_robust_behavior_groups")()
	tg <- ns("EDI_QUASI_ROBUST_TARGETS")
	all_beh <- sort(unique(unlist(lapply(tg[ns("EDI_QUASI_ROBUST_CLASS_NAMES")], `[[`, "behavior"))))
	expect_equal(names(grp), all_beh)
	for (b in names(grp)) {
		expected <- sort(names(Filter(function(t) b %in% t$behavior, tg[ns("EDI_QUASI_ROBUST_CLASS_NAMES")])))
		expect_equal(grp[[b]], expected, info = b)
	}
	expect_error(ns("quasi_robust_behavior_groups")(c(ns("EDI_QUASI_ROBUST_CLASS_NAMES")[1], "Bogus")),
		"missing target metadata: Bogus")
})

test_that("custom randomization records: guard, merged capabilities, default status, legacy surface", {
	b <- ns("build_custom_randomization_behavior_record")
	expect_error(b("NotAClass"), "not a registered custom randomization host")
	hosts <- ns("custom_randomization_host_names")()
	expect_gt(length(hosts), 0L)
	nm <- hosts[1]
	tgt <- ns("EDI_CUSTOM_RANDOMIZATION_TARGETS")[[nm]]
	rec <- b(nm)
	expect_equal(rec$name, nm)
	expect_equal(rec$host_kind, tgt$host_kind)
	expect_equal(rec$intentional_capabilities, unique(c(tgt$intentional_capabilities, tgt$class_owned_capabilities)))
	expect_equal(rec$migration_status, tgt$migration_status %||% "pending")
	expect_equal(rec$migration_evidence, tgt$migration_evidence %||% character())
	expect_equal(rec$legacy_optional_surface, setdiff(rec$current_public_optional_methods, rec$intentional_public_methods))
	expect_identical(rec$current_public_optional_methods, sort(unique(rec$current_public_optional_methods)))
	man <- ns("custom_randomization_behavior_manifest")()
	expect_equal(names(man), hosts)
	expect_equal(man[[nm]], rec)
})
