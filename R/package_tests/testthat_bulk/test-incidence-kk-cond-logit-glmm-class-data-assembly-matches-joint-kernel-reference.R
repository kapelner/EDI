library(testthat)
library(EDI)

# InferenceIncidKKCondLogitGLMMOneLik: the joint conditional-logit (discordant pairs) + random-intercept
# logistic GLMM (concordant pairs and reservoir subjects) estimator. The class' data assembly is checked by
# building the same three blocks independently from the design (discordant pair differences, concordant pair
# members grouped by pair, reservoir singletons) and fitting fast_clogit_plus_glmm_cpp directly: the treatment
# coefficients agree across simulated datasets, the class uses L-BFGS (so no Newton sigma collapse), and the
# fitted random-effect scale is finite and moderate.

K <- function(x) get(x, envir = asNamespace("EDI"))

fx <- function(seed) {
	set.seed(seed)
	n <- 240L
	des <- DesignSeqOneByOneKK14$new(response_type = "incidence", n = n, verbose = FALSE)
	X <- data.frame(x = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	m <- des$.__enclos_env__$private$m[seq_len(n)]
	u <- ifelse(m > 0, rnorm(max(m))[pmax(m, 1)], 0) * 0.9
	y <- as.numeric(rbinom(n, 1, plogis(-0.3 + 0.8 * w + 0.4 * X$x + u)))
	des$add_all_subject_responses(y)
	d <- data.frame(y = y, w = w, x = X$x, m = m)
	pr <- d[d$m > 0, ]
	ids <- sort(unique(pr$m))
	is_disc <- vapply(ids, function(k) length(unique(pr$y[pr$m == k])) == 2L, logical(1))
	disc <- do.call(rbind, lapply(ids[is_disc], function(k) {
		a <- pr[pr$m == k, ]; t1 <- a[a$w == 1, ]; t0 <- a[a$w == 0, ]
		c(y = as.numeric(t1$y > t0$y), tw = 1, dx = t1$x - t0$x)
	}))
	cd <- d[d$m %in% ids[!is_disc] | d$m == 0, ]
	gid <- as.integer(factor(ifelse(cd$m > 0, paste0("p", cd$m), paste0("s", seq_len(nrow(cd))))))
	list(des = des, disc = disc, cd = cd, gid = gid, n_disc = sum(is_disc), n_conc = sum(!is_disc))
}
joint <- function(f) {
	K("fast_clogit_plus_glmm_cpp")(cbind(f$disc[, "tw"], f$disc[, "dx"]), as.numeric(f$disc[, "y"]),
		cbind(1, f$cd$w, f$cd$x), as.numeric(f$cd$y), f$gid, TRUE, TRUE)
}

test_that("the fixtures have discordant pairs, concordant pairs and a reservoir", {
	f <- fx(901L)
	expect_gt(f$n_disc, 20L); expect_gt(f$n_conc, 20L); expect_gt(sum(f$cd$m == 0), 0L)
})

test_that("the class treatment coefficient agrees with the joint kernel fitted on independently assembled blocks", {
	for (s in 901:906) {
		f <- fx(s)
		r <- joint(f)
		inf <- K("InferenceIncidKKCondLogitGLMMOneLik")$new(f$des, verbose = FALSE)
		expect_true(r$converged, info = as.character(s))
		expect_equal(unname(inf$compute_estimate()), as.numeric(r$params)[2], tolerance = 3e-2, scale = 1, info = as.character(s))
		expect_identical(inf$.__enclos_env__$private$optimization_alg, "lbfgs")
	}
})

test_that("neither the kernel nor the class collapses the random-effect scale to the lower boundary", {
	f <- fx(902L)
	r <- joint(f)
	expect_gt(as.numeric(r$params)[4], -2.5)
	inf <- K("InferenceIncidKKCondLogitGLMMOneLik")$new(f$des, verbose = FALSE)
	inf$compute_estimate()
	expect_gt(as.numeric(inf$.__enclos_env__$private$cached_mod$params)[4], -2.5)
})
