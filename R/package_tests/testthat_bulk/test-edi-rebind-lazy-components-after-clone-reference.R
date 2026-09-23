library(testthat)
library(EDI)

# contracts_mixins.R's edi_rebind_lazy_components_after_clone() (the private helper duplicate() calls
# right after self$clone(), inference_all_abstract.R's own duplicate = function(...)) had no test
# reference anywhere despite the surrounding lazy-component/clone plumbing being well covered
# elsewhere (test-contracts-lazy-component-stubs-caches-and-root-state-names-reference.R,
# test-design-component-registry-clear-and-restore-reference.R, etc). The function's own header
# comment documents two compounding, already-fixed 2026-08-20 bugs it exists to guard against:
#   (1) the "already installed" marker is stored as an ENVIRONMENT ATTRIBUTE (not a binding) whenever
#       the private env is locked at install time -- true for any ordinary migrated-class instance.
#   (2) self$clone() copies environment BINDINGS but not environment-level ATTRIBUTES, so a raw
#       clone() has nothing of its own to read; the marker must come from the SOURCE's private env,
#       threaded through as `source_private`.
# This file exercises the function directly (EDI:::edi_rebind_lazy_components_after_clone), using the
# real BayesianBootstrap lazy component and a private method that reads per-instance private state
# (expand_subject_or_block_weights_to_row_weights(), which reads private$current_bayesian_bootstrap_
# context) to make the "still bound to the source's environment" failure mode directly observable:
# before the fix is applied, a raw clone's copy of that method still resolves `private` to the
# SOURCE's private env (not the clone's own, freshly-mutated one), so calling it with an argument
# sized for the clone's own context throws (the source's context has a different n_units); after
# edi_rebind_lazy_components_after_clone() is applied, the same call succeeds and returns the
# clone's own row-expansion, matching a hand-computed independent reference.
#   1. Nothing lazy-loaded yet: the function is a documented no-op, returning the object invisibly
#      and leaving no marker behind.
#   2. After loading BayesianBootstrap, the marker is stored as an environment ATTRIBUTE (not a
#      binding) on the source's locked private env -- confirming bug (1)'s premise.
#   3. A raw self$clone() does not carry that attribute forward on its own (bug (2)'s premise), and
#      its copy of a state-reading private method still resolves to the SOURCE's private state until
#      edi_rebind_lazy_components_after_clone() is applied; afterward it resolves to its OWN private
#      state, the marker is re-recorded on the clone, and the row-expansion output matches an
#      independently hand-computed reference for the clone's own context.
#   4. The real production call site (self$duplicate(), which always threads source_private = private)
#      exhibits the fixed behavior end-to-end without calling the helper directly.

edi_ns <- function(x) get(x, envir = asNamespace("EDI"))

pod_fixture <- function(seed = 1L, n = 24L) {
	set.seed(seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "ordinal", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- as.integer(cut(0.5 * w + rlogis(n), c(-Inf, -0.5, 0.5, Inf)))
	des$add_all_subject_responses(y)
	InferenceOrdinalPropOddsRegr$new(des, model_formula = ~1, verbose = FALSE)
}

marker_name <- ".__loaded_lazy_components"

test_that("with nothing lazy-loaded yet, the rebind is a no-op: returns the object invisibly, no marker anywhere", {
	set.seed(1L); n <- 20L
	des <- DesignFixediBCRD$new(n = n, response_type = "count", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rpois(n, 3))
	inf <- InferenceCountPoisson$new(des, verbose = FALSE)                # never eagerly loads a lazy component
	priv <- inf$.__enclos_env__$private
	expect_false(exists(marker_name, envir = priv, inherits = FALSE))
	i2 <- inf$clone()

	result <- edi_ns("edi_rebind_lazy_components_after_clone")(i2, source_private = priv)
	expect_identical(result, i2)

	i2_priv <- i2$.__enclos_env__$private
	expect_false(exists(marker_name, envir = i2_priv, inherits = FALSE))
	expect_null(attr(i2_priv, marker_name, exact = TRUE))
})

test_that("loading a lazy component stores the marker as a BINDING on EDI's own migrated classes (lock_objects = FALSE)", {
	inf <- pod_fixture(seed = 2L)
	priv <- inf$.__enclos_env__$private
	expect_false(environmentIsLocked(priv))

	expect_identical(priv$bayesian_bootstrap_cache_key(3L, "default"), "3::default")

	expect_true(exists(marker_name, envir = priv, inherits = FALSE))
	marker <- get(marker_name, envir = priv, inherits = FALSE)
	expect_true("BayesianBootstrap" %in% marker)
	expect_null(attr(priv, marker_name, exact = TRUE))
})

test_that("on a plain user subclass (no lock_objects = FALSE of its own), the private env is locked and the marker is instead stored as an environment ATTRIBUTE (the case bug (1) fixed)", {
	UserSub <- R6::R6Class("UserSubPropOdds", inherit = InferenceOrdinalPropOddsRegr, parent_env = asNamespace("EDI"))
	des <- {
		set.seed(5L); n <- 24L
		d <- DesignFixediBCRD$new(n = n, response_type = "ordinal", verbose = FALSE)
		d$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
		d$assign_w_to_all_subjects()
		d$add_all_subject_responses(as.integer(cut(0.5 * d$get_w() + rlogis(n), c(-Inf, -0.5, 0.5, Inf))))
		d
	}
	inf <- UserSub$new(des, model_formula = ~1, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	expect_true(environmentIsLocked(priv))

	priv$bayesian_bootstrap_cache_key(3L, "default")
	expect_false(exists(marker_name, envir = priv, inherits = FALSE))
	marker <- attr(priv, marker_name, exact = TRUE)
	expect_true("BayesianBootstrap" %in% marker)
})

user_sub_fixture <- function(seed = 5L, n = 24L) {
	UserSub <- R6::R6Class("UserSubPropOdds", inherit = InferenceOrdinalPropOddsRegr, parent_env = asNamespace("EDI"))
	set.seed(seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "ordinal", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(as.integer(cut(0.5 * des$get_w() + rlogis(n), c(-Inf, -0.5, 0.5, Inf))))
	UserSub$new(des, model_formula = ~1, verbose = FALSE)
}

test_that("a raw clone() does not inherit the attribute-stored marker (locked private env) and still resolves state-reading methods to the source's own state until rebound, then to its own state after rebind", {
	src <- user_sub_fixture(seed = 3L, n = 30L)
	src_priv <- src$.__enclos_env__$private
	expect_true(environmentIsLocked(src_priv))
	src_priv$bayesian_bootstrap_cache_key(1L)                          # force-load BayesianBootstrap

	src_ctx <- list(row_to_unit = c(1L, 1L, 2L), unit_group_id = c(1L, 2L), n_units = 2L)
	src_priv$current_bayesian_bootstrap_context <- src_ctx

	raw_clone <- src$clone()
	clone_priv <- raw_clone$.__enclos_env__$private
	expect_null(attr(clone_priv, marker_name, exact = TRUE))            # bug (2): attribute not copied by clone()

	clone_ctx <- list(row_to_unit = c(1L, 2L, 2L, 3L), unit_group_id = c(1L, 2L, 3L), n_units = 3L)
	clone_priv$current_bayesian_bootstrap_context <- clone_ctx

	# Pre-rebind: the clone's copy of the method is still bound to the SOURCE's environment, so it
	# reads src_ctx (n_units = 2), not clone_priv's own clone_ctx (n_units = 3) -- a length-3 weight
	# vector (valid for the clone's own context) is rejected because the function actually validated
	# against the source's n_units = 2.
	expect_error(clone_priv$expand_subject_or_block_weights_to_row_weights(c(1, 1, 1)))
	# A length-2 vector (valid only for the STALE source context) is accepted, proving the read really
	# does come from the source, and reproduces the source's own expansion.
	expect_equal(clone_priv$expand_subject_or_block_weights_to_row_weights(c(5, 9)), c(5, 5, 9))

	result <- edi_ns("edi_rebind_lazy_components_after_clone")(raw_clone, source_private = src_priv)
	expect_identical(result, raw_clone)
	expect_true("BayesianBootstrap" %in% attr(clone_priv, marker_name, exact = TRUE))
	expect_identical(environment(clone_priv$expand_subject_or_block_weights_to_row_weights), raw_clone$.__enclos_env__)

	# Post-rebind: the clone's own context (n_units = 3) is now what's read -- a length-2 vector (only
	# valid pre-rebind) is now rejected, and the correct row-expansion for the clone's own context
	# matches a hand-computed independent reference.
	expect_error(clone_priv$expand_subject_or_block_weights_to_row_weights(c(5, 9)))
	expect_equal(clone_priv$expand_subject_or_block_weights_to_row_weights(c(2, 4, 6)), c(2, 4, 4, 6))
	# The source itself is untouched by any of this.
	expect_equal(src_priv$current_bayesian_bootstrap_context, src_ctx)
})

test_that("the real production call site (self$duplicate()) exhibits the fixed behavior end-to-end, on the locked-private-env user-subclass case", {
	src <- user_sub_fixture(seed = 4L, n = 20L)
	src_priv <- src$.__enclos_env__$private
	src_priv$bayesian_bootstrap_cache_key(1L)                          # force-load BayesianBootstrap
	src_priv$current_bayesian_bootstrap_context <- list(row_to_unit = 1:5, unit_group_id = rep(1L, 5), n_units = 5)

	dup <- src$duplicate()
	dup_priv <- dup$.__enclos_env__$private
	dup_priv$current_bayesian_bootstrap_context <- list(row_to_unit = c(1L, 1L, 2L, 2L), unit_group_id = 1:2, n_units = 2)

	expect_equal(dup_priv$expand_subject_or_block_weights_to_row_weights(c(3, 7)), c(3, 3, 7, 7))
	expect_equal(src_priv$current_bayesian_bootstrap_context$n_units, 5)  # source's own context is unaffected
})
