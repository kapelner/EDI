library(testthat)
library(EDI)

# KK (matched pairs + reservoir) incidence classes against independent constructions:
# InferenceIncidKKCondLogitOneLik = ONE logistic regression on the stacked rows [discordant pair differences:
# (0, 1, x_T - x_C) with outcome 1{y_T > y_C}] over [reservoir rows: (1, w, x)] -- estimate and (model-based) SE;
# InferenceIncidKKGEE = geepack::geeglm(binomial, exchangeable) clustered by pair (singletons alone);
# InferenceIncidKKModifiedPoisson = the Poisson-link glm coefficient; a KK design that ignores the pairing
# (InferenceIncidLogRegr) equals the plain logistic glm.

skip_if_not_installed("geepack")
K <- function(x) get(x, envir = asNamespace("EDI"))

fx <- function() {
	set.seed(6)
	n <- 120L
	des <- DesignSeqOneByOneKK14$new(response_type = "incidence", n = n, verbose = FALSE)
	X <- data.frame(x = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	m <- des$.__enclos_env__$private$m[seq_len(n)]
	u <- ifelse(m > 0, rnorm(max(m))[pmax(m, 1)], 0) * 0.8
	y <- as.numeric(rbinom(n, 1, plogis(-0.3 + 0.8 * w + 0.4 * X$x + u)))
	des$add_all_subject_responses(y)
	d <- data.frame(y = y, w = w, x = X$x, m = m)
	d$g <- ifelse(d$m > 0, paste0("p", d$m), paste0("s", seq_along(d$m)))
	list(des = des, d = d)
}
new_inf <- function(cls, des) K(cls)$new(des, verbose = FALSE)
stacked <- function(d) {
	pr <- d[d$m > 0, ]
	rows <- lapply(sort(unique(pr$m)), function(k) {
		a <- pr[pr$m == k, ]
		if (length(unique(a$y)) < 2L) return(NULL)
		t1 <- a[a$w == 1, ]; t0 <- a[a$w == 0, ]
		c(y = as.numeric(t1$y > t0$y), tw = 1, dx = t1$x - t0$x)
	})
	dd <- do.call(rbind, rows)
	res <- d[d$m == 0, ]
	list(X = rbind(cbind(0, dd[, "tw"], dd[, "dx"]), cbind(1, res$w, res$x)), y = c(dd[, "y"], res$y), n_disc = nrow(dd))
}

test_that("the fixture has discordant pairs and reservoir subjects", {
	f <- fx()
	s <- stacked(f$d)
	expect_gt(s$n_disc, 10L)
	expect_gt(sum(f$d$m == 0), 5L)
})

test_that("conditional-logit one-likelihood class equals the stacked logistic fit: estimate and model-based SE", {
	f <- fx()
	s <- stacked(f$d)
	g <- glm(s$y ~ s$X - 1, family = binomial())
	inf <- new_inf("InferenceIncidKKCondLogitOneLik", f$des)
	expect_equal(unname(inf$compute_estimate()), unname(coef(g)[2]), tolerance = 1e-5)
	expect_equal(inf$.__enclos_env__$private$cached_values$s_beta_hat_T, unname(summary(g)$coefficients[2, 2]), tolerance = 1e-4)
})

test_that("KK GEE class equals geeglm with an exchangeable working correlation clustered by pair", {
	f <- fx()
	o <- f$d[order(f$d$g), ]
	gee <- geepack::geeglm(y ~ w + x, id = factor(g), data = o, family = binomial, corstr = "exchangeable")
	expect_equal(unname(new_inf("InferenceIncidKKGEE", f$des)$compute_estimate()), unname(coef(gee)["w"]), tolerance = 2e-3)
})

test_that("KK modified-Poisson class equals the Poisson-link glm coefficient; ignoring the pairing gives the plain logistic glm", {
	f <- fx()
	expect_equal(unname(new_inf("InferenceIncidKKModifiedPoisson", f$des)$compute_estimate()),
		unname(coef(suppressWarnings(glm(y ~ w + x, family = poisson, data = f$d)))["w"]), tolerance = 1e-5)
	expect_equal(unname(new_inf("InferenceIncidLogRegr", f$des)$compute_estimate()),
		unname(coef(glm(y ~ w + x, family = binomial, data = f$d))["w"]), tolerance = 1e-6)
})
