# v1.0.6-TODO-350 (ds-save-load-44883784401-f2): clone(deep = TRUE) of DesignSeqOneByOneSPBR,
# DesignSeqOneByOneRandomBlockSize and DesignSeqOneByOnePocockSimon shared per-stratum state with the
# original. SPBR / RandomBlockSize kept their block queues in an environment (copied by reference), and
# PocockSimon's running counts matrix is updated in place by pocock_simon_assign_and_update_cpp(), so
# assignments made on one object moved the other's state. The queues are now a list and PocockSimon copies
# its counts before each in-place update. With a seed every subject's draw comes from (seed, t), so the
# original and the copy must each reproduce an uninterrupted run exactly.

seq_clone_design_classes = c("Atkinson", "Bernoulli", "Efron", "iBCRD", "KK14", "KK21", "KK21stepwise",
	"PocockSimon", "RandomBlockSize", "SPBR", "Urn")

make_seq_clone_design = function(cl, n){
	gen = get(paste0("DesignSeqOneByOne", cl), envir = asNamespace("EDI"))
	args = list(response_type = "continuous", n = n, seed = 11L, verbose = FALSE)
	if (cl %in% c("PocockSimon", "RandomBlockSize", "SPBR")) args$strata_cols = c("a", "b")
	do.call(gen$new, args)
}

test_that("a deep clone of every sequential design and its original each match an uninterrupted run", {
	set.seed(350)
	n = 24
	X = data.frame(a = factor(sample(c("u", "v"), n, TRUE)), b = factor(sample(c("p", "q", "r"), n, TRUE)), x = rnorm(n))
	add = function(d, idx) for (i in idx) d$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	for (cl in seq_clone_design_classes) {
		d0 = make_seq_clone_design(cl, n)
		add(d0, seq_len(n))
		w0 = d0$get_w()
		for (original_first in c(TRUE, FALSE)) {
			d1 = make_seq_clone_design(cl, n)
			add(d1, 1:12)
			d2 = d1$clone(deep = TRUE)
			if (original_first) {
				add(d1, 13:n); add(d2, 13:n)
			} else {
				add(d2, 13:n); add(d1, 13:n)
			}
			info = paste(cl, if (original_first) "original first" else "copy first")
			expect_identical(d1$get_w(), w0, info = info)
			expect_identical(d2$get_w(), w0, info = info)
		}
	}
})

test_that("a deep clone fed different subjects keeps its own covariates and assignments", {
	# PocockSimon preallocates Xraw and fills rows in place (data.table::set), so a clone that shared the
	# table had its rows overwritten by the original's later subjects.
	set.seed(351)
	n = 24
	make_X = function() data.frame(a = factor(sample(c("u", "v"), n, TRUE), levels = c("u", "v")),
		b = factor(sample(c("p", "q", "r"), n, TRUE), levels = c("p", "q", "r")), x = rnorm(n))
	X = make_X()
	X2 = X
	X2[13:n, ] = make_X()[13:n, ]
	add = function(d, XX, idx) for (i in idx) d$add_one_subject_to_experiment_and_assign(XX[i, , drop = FALSE])
	for (cl in seq_clone_design_classes) {
		ref1 = make_seq_clone_design(cl, n); add(ref1, X, seq_len(n))
		ref2 = make_seq_clone_design(cl, n); add(ref2, X2, seq_len(n))
		d1 = make_seq_clone_design(cl, n); add(d1, X, 1:12)
		d2 = d1$clone(deep = TRUE)
		for (i in 13:n) { add(d2, X2, i); add(d1, X, i) }
		expect_identical(d1$get_w(), ref1$get_w(), info = cl)
		expect_identical(d2$get_w(), ref2$get_w(), info = cl)
		expect_equal(as.data.frame(d1$get_X_raw()), as.data.frame(ref1$get_X_raw()), info = cl)
		expect_equal(as.data.frame(d2$get_X_raw()), as.data.frame(ref2$get_X_raw()), info = cl)
	}
})
