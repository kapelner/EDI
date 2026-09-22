library(testthat)
library(EDI)
library(data.table)

# Two sibling defensive guards, one in InferenceIncidExactBinomial's get_exact_binomial_stats()
# ("Matching structure is unavailable for exact binomial incidence inference."), the other in
# InferenceIncidExactFisher's build_exact_fisher_tables_kk() ("Matching structure is unavailable
# for Fisher exact inference.") -- both fire when the design's own private$m match-vector field is
# NULL. Not reachable through any normal data-driven construction on a DesignFixedBinaryMatch (its
# ensure_matching_structure_computed() unconditionally populates m before either guard's caller
# runs), so exercised the same way this session has tested other structurally-defensive-but-
# real guards: directly nulling the design's private$m field on an already-constructed object.
# Zero test references anywhere for either message.

make_exact_fixture <- function(cls_name, seed = 1L, n = 8L) {
	set.seed(seed)
	x_dat <- data.table(x1 = rnorm(n))
	des <- DesignFixedBinaryMatch$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(x_dat); des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rbinom(n, 1, 0.5))
	inf <- get(cls_name, envir = asNamespace("EDI"))$new(des, verbose = FALSE)
	list(inf = inf, priv = inf$.__enclos_env__$private)
}

test_that("InferenceIncidExactBinomial$get_exact_binomial_stats() errors when the design's match vector is NULL", {
	f <- make_exact_fixture("InferenceIncidExactBinomial")
	expect_true(!is.null(f$priv$des_obj_priv_int$m))                            # sanity: normally populated
	f$priv$des_obj_priv_int$m <- NULL
	expect_error(f$priv$get_exact_binomial_stats(), "Matching structure is unavailable for exact binomial incidence inference\\.")
})

test_that("InferenceIncidExactFisher$build_exact_fisher_tables_kk() errors when the design's match vector is NULL", {
	f <- make_exact_fixture("InferenceIncidExactFisher", seed = 2L)
	expect_true(!is.null(f$priv$des_obj_priv_int$m))
	f$priv$des_obj_priv_int$m <- NULL
	expect_error(f$priv$build_exact_fisher_tables_kk(), "Matching structure is unavailable for Fisher exact inference\\.")
})
