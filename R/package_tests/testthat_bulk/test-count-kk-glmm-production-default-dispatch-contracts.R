library(testthat)
library(EDI)

with_builtin_glmm_dispatch_policies <- function(code) {
	edi_env <- get("edi_env", envir = asNamespace("EDI"))
	old_cold <- edi_env$cold_start_dispatch_policy_config
	old_optimization <- edi_env$optimization_dispatch_policy_config
	on.exit({
		assign("cold_start_dispatch_policy_config", old_cold, envir = edi_env)
		assign("optimization_dispatch_policy_config", old_optimization, envir = edi_env)
	}, add = TRUE)
	EDI:::set_cold_start_dispatch_policy(reset = TRUE)
	EDI:::set_optimization_dispatch_policy(reset = TRUE)
	force(code)
}

test_that("default Count KK GLMM routes to the Poisson kernel with shipped settings", {
	with_builtin_glmm_dispatch_policies({
		cpp_wrapper <- get("fast_poisson_glmm_cpp", envir = asNamespace("EDI"))
		default_n_gh <- eval(formals(cpp_wrapper)$n_gh, envir = environment(cpp_wrapper))
		expect_identical(default_n_gh, 60L) # 20 -> 60 in v1.0.5 (G4-C R8 node-count scan)

		seen <- new.env(parent = emptyenv())
		local_mocked_bindings(
			fast_poisson_glmm_cpp = function(...) {
				seen$args <- list(...)
				b <- numeric(ncol(seen$args$X))
				b[[seen$args$j_T + 1L]] <- 0.375
				list(converged = TRUE, b = b, log_sigma = 0, fisher_information = NULL)
			},
			.package = "EDI"
		)

		des <- DesignSeqOneByOneKK14$new(
			response_type = "count", n = 4L, seed = 31031L, verbose = FALSE
		)
		X <- data.frame(x = c(-1, 1, -1, 1))
		for (i in seq_len(nrow(X))) {
			des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
		}
		des$add_all_subject_responses(c(0, 1, 2, 1))

		inf <- InferenceCountKKGLMM$new(des, verbose = FALSE)
		estimate <- inf$compute_estimate(estimate_only = TRUE)

		expect_identical(unname(estimate), 0.375)
		expect_identical(seen$args$optimization_alg, "newton_raphson")
		expect_identical(seen$args$smart_cold_start, TRUE)
		expect_identical(seen$args$estimate_only, TRUE)
		# The production call leaves n_gh unspecified; the real Rcpp wrapper's
		# default above supplies the shipped 60-node quadrature setting.
		expect_false("n_gh" %in% names(seen$args))
	})
})
