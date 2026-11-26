# v1.0.6-TODO-219 (ds-save-load-44883784401-f3, ds-save-load-44883784401-f5): sequential designs with a
# fixed n accepted subject n + 1 (t = n + 1, w grew, get_n() stayed n, inference ran on n + 1), and a
# covariate value arriving as text warned once and retyped the stored column for every earlier subject, so
# later assignments changed and the final analysis was NA. Subject n + 1 is now refused, and a type change
# is coerced back to the stored type or refused (naming the column) when the value would be lost, with the
# design left unchanged (the v1.0.6-TODO-196 rollback).

test_that("the (n + 1)th subject is refused and t stays n", {
	set.seed(1)
	n = 30
	X = data.frame(x1 = rnorm(n + 1), x2 = rnorm(n + 1))
	for (cl in c("Bernoulli", "KK14", "KK21")) {
		d = get(paste0("DesignSeqOneByOne", cl), envir = asNamespace("EDI"))$new(response_type = "continuous", n = n, verbose = FALSE)
		for (i in seq_len(n)) {
			d$add_one_subject_to_experiment_and_assign(X[i, ])
			if (cl == "KK21") d$add_one_subject_response(i, rnorm(1))
		}
		w_before = d$get_w()
		expect_error(d$add_one_subject_to_experiment_and_assign(X[n + 1, ]), "subject 31 cannot be enrolled", info = cl)
		expect_equal(d$get_t(), n, info = cl)
		expect_identical(d$get_w(), w_before, info = cl)
	}
})

test_that("a covariate arriving as unconvertible text is refused, naming the column, and the design is unchanged", {
	set.seed(2)
	n = 30
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	d = DesignSeqOneByOneBernoulli$new(response_type = "continuous", n = n, verbose = FALSE)
	for (i in 1:25) d$add_one_subject_to_experiment_and_assign(X[i, ])
	X_before = d$get_X_raw()
	t_before = d$get_t()
	bad = X[26, ]
	bad$x1 = "1.7a"
	expect_error(d$add_one_subject_to_experiment_and_assign(bad), "covariate 'x1' of subject 26")
	expect_identical(d$get_t(), t_before)
	expect_identical(d$get_X_raw(), X_before)
	expect_true(is.numeric(d$get_X_raw()$x1))
	# a convertible value is coerced back to the stored type, never retyping the column
	ok = X[26, ]
	ok$x1 = "1.7"
	d$add_one_subject_to_experiment_and_assign(ok)
	expect_true(is.numeric(d$get_X_raw()$x1))
	expect_equal(d$get_X_raw()$x1[26], 1.7)
	expect_equal(d$get_X_raw()$x1[1:25], X$x1[1:25])
})

test_that("an open-ended design (n = NULL) still accepts any number of subjects", {
	set.seed(3)
	d = DesignSeqOneByOneBernoulli$new(response_type = "continuous", verbose = FALSE)
	for (i in 1:35) d$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	expect_equal(d$get_t(), 35)
})
