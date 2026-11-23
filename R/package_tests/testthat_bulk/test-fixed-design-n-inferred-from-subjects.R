# v1.0.6-TODO-298 (ds-fixed-designs-44358267779-f6, ds-clusters-blocking-44358267779-f5,
# ds-observational-44883784401-f1): every fixed design accepted the default n = NULL and then
# add_all_subjects_to_experiment() stopped with "you must specify n upon initialization", although X_all
# gives n; assigning before adding subjects failed with "replacement has length zero" / "argument is of
# length zero". Owner ruling DECISION-v1.0.6-TODO-298 (2026-11-23): with n = NULL, n = nrow(X_all); a
# mismatch keeps the error (owner wording "X_all must have exactly n = <n> rows"); assigning before adding
# subjects with n unknown errors "pass n to $new() or add the subjects first".

fixed_design_n_specs = list(
	DesignFixedBernoulli = list(),
	DesignFixediBCRD = list(),
	DesignFixedRerandomization = list(prop_acceptable = 0.1),
	DesignFixedGreedy = list(n_iter = 5),
	DesignFixedGreedyDOptimal = list(),
	DesignFixedBinaryMatch = list(),
	DesignFixedOptimal = list(),
	DesignFixedBlocking = list(strata_cols = "s"),
	DesignFixedCluster = list(cluster_col = "cl"),
	DesignFixedBlockedCluster = list(strata_cols = "s", cluster_col = "cl"),
	ObservationalDesign = list()
)

make_fixed_n_X = function(n){
	set.seed(298)
	data.frame(x1 = rnorm(n), x2 = rnorm(n), s = factor(rep(c("a", "b"), each = n / 2)), cl = factor(rep(seq_len(n / 3), each = 3)))
}

assign_fixed_n = function(d, cl, n){
	if (cl == "ObservationalDesign") d$assign_w_to_all_subjects(w_precomputed = rep(0:1, n / 2)) else d$assign_w_to_all_subjects()
}

test_that("every fixed design built without n takes n from X_all and gives the allocation of n = nrow(X_all)", {
	n = 24L
	X = make_fixed_n_X(n)
	for (cl in names(fixed_design_n_specs)) {
		gen = get(cl, envir = asNamespace("EDI"))
		args = c(list(response_type = "continuous", seed = 5L, verbose = FALSE), fixed_design_n_specs[[cl]])
		d_null = suppressMessages(do.call(gen$new, args))
		d_null$add_all_subjects_to_experiment(X)
		expect_equal(d_null$get_n(), n, info = cl)
		suppressMessages(assign_fixed_n(d_null, cl, n))
		d_n = suppressMessages(do.call(gen$new, c(args, list(n = n))))
		d_n$add_all_subjects_to_experiment(X)
		suppressMessages(assign_fixed_n(d_n, cl, n))
		expect_identical(d_null$get_w(), d_n$get_w(), info = cl)
		expect_false(anyNA(d_null$get_w()), info = cl)
	}
})

test_that("a row count that disagrees with n keeps the error", {
	X = make_fixed_n_X(24L)
	for (cl in names(fixed_design_n_specs)) {
		gen = get(cl, envir = asNamespace("EDI"))
		args = c(list(response_type = "continuous", n = 30L, verbose = FALSE), fixed_design_n_specs[[cl]])
		d = suppressMessages(do.call(gen$new, args))
		expect_error(d$add_all_subjects_to_experiment(X), "X_all must have exactly n = 30 rows", fixed = TRUE, info = cl)
	}
})

test_that("assigning before adding subjects with n unknown gives a clear error", {
	for (cl in names(fixed_design_n_specs)) {
		gen = get(cl, envir = asNamespace("EDI"))
		args = c(list(response_type = "continuous", verbose = FALSE), fixed_design_n_specs[[cl]])
		d = suppressMessages(do.call(gen$new, args))
		expect_error(d$assign_w_to_all_subjects(), "pass n to $new() or add the subjects first", fixed = TRUE, info = cl)
		expect_error(d$assign_w_to_all_subjects(w_precomputed = rep(0:1, 12L)), "pass n to $new() or add the subjects first", fixed = TRUE, info = cl)
	}
})

test_that("covariate-free iBCRD and Bernoulli with n still assign without X", {
	for (cl in c("DesignFixediBCRD", "DesignFixedBernoulli")) {
		d = get(cl, envir = asNamespace("EDI"))$new(response_type = "continuous", n = 20L, seed = 3L, verbose = FALSE)
		d$assign_w_to_all_subjects()
		w = d$get_w()
		expect_length(w, 20L)
		expect_true(all(w %in% c(0, 1)), info = cl)
	}
})
