library(testthat)
library(EDI)

# inference_all_abstract_non_param_boot.R's reusable-bootstrap-worker contract has two pure,
# directly callable validation guards: validate_bootstrap_worker_state() ("Reusable bootstrap
# workers must be non-NULL lists containing `worker`.", called from both
# create_reusable_bootstrap_worker() and load_bootstrap_draw_into_worker()) and
# estimate_bootstrap_worker() ("Reusable bootstrap workers must return one numeric treatment
# estimate.", after delegating to the class's own compute_bootstrap_worker_estimate()). Both are
# thin, self-contained contract checks -- exercised directly against a hand-built worker_state (for
# the first) and via stubbing compute_bootstrap_worker_estimate()'s return value (for the second,
# the same private-method-stub pattern this session has used for other structurally-real guards) --
# without touching any of the actual worker-reuse execution/caching machinery. Zero test references
# for either message anywhere.

fx <- function(seed = 1L, n = 20L) {
	set.seed(seed)
	d <- DesignFixedBernoulli$new(response_type = "continuous", n = n, seed = seed, verbose = FALSE)
	d$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n))); d$assign_w_to_all_subjects()
	w <- d$get_w()
	d$add_all_subject_responses(rnorm(n) + w)
	inf <- InferenceContinLin$new(d, verbose = FALSE)
	inf$.__enclos_env__$private
}

test_that("validate_bootstrap_worker_state(): NULL or a list with no `worker` element errors with the documented message", {
	priv <- fx(seed = 1L)
	expect_error(priv$validate_bootstrap_worker_state(NULL), "Reusable bootstrap workers must be non-NULL lists containing `worker`\\.")
	expect_error(priv$validate_bootstrap_worker_state(list(foo = 1)), "Reusable bootstrap workers must be non-NULL lists containing `worker`\\.")
	expect_error(priv$validate_bootstrap_worker_state("not a list"), "Reusable bootstrap workers must be non-NULL lists containing `worker`\\.")
})

test_that("validate_bootstrap_worker_state(): a list containing `worker` passes silently", {
	priv <- fx(seed = 2L)
	expect_silent(res <- priv$validate_bootstrap_worker_state(list(worker = "ok")))
	expect_identical(res$worker, "ok")
})

test_that("estimate_bootstrap_worker(): a non-scalar or non-numeric worker estimate errors with the documented message", {
	priv <- fx(seed = 3L)
	unlockBinding("compute_bootstrap_worker_estimate", priv)

	priv$compute_bootstrap_worker_estimate <- function(worker_state) c(1, 2, 3)
	expect_error(priv$estimate_bootstrap_worker(list(worker = "ok")), "Reusable bootstrap workers must return one numeric treatment estimate\\.")

	priv$compute_bootstrap_worker_estimate <- function(worker_state) "not numeric"
	expect_error(priv$estimate_bootstrap_worker(list(worker = "ok")), "Reusable bootstrap workers must return one numeric treatment estimate\\.")

	priv$compute_bootstrap_worker_estimate <- function(worker_state) 4.2
	expect_identical(priv$estimate_bootstrap_worker(list(worker = "ok")), 4.2)
})
