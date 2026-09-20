library(testthat)
library(EDI)

# Adversarial data + fault injection. The comprehensive_tests harness feeds the
# package benign real datasets, so rare branches almost never fire: the count
# bootstrap-fallback bug (2026-09-19) needed a non-finite SE and appeared in 84
# of 328k result rows. Here every cheap inference class is driven through
# pathological inputs (separation, all-zero counts, constant response,
# collinear covariates, heavy right-censoring, tiny n) and through injected
# standard-error faults (NA / NaN / Inf / negative / zero), and each result
# must satisfy output invariants -- a clean error or NA is always acceptable,
# a wrong-looking number never is:
#   * estimate is NA or finite
#   * CI is c(NA, NA) or two finite numbers with lower <= upper
#   * a finite CI contains the estimate (numerical tolerance)
#   * p-value is NA or within [0, 1]
#   * a zero-width finite CI never comes with a finite p-value (a degenerate
#     interval reported as if it were real precision)
#   * no error message is a code defect ("attempt to apply non-function" ...)
# Same tolerated-findings discipline as the wiring audit: EDI_ADVERSARIAL_KNOWN
# lists pre-existing violations, and an entry that stops occurring FAILS until
# deleted so the list cannot rot.

adv_n = 16L
adv_programming_error = paste(sprintf("(%s)", c(
	"attempt to apply non-function", "could not find function",
	"object '[^']+' not found", "subscript out of bounds",
	"argument \"[^\"]+\" is missing, with no default", "unused argument",
	"non-numeric argument to (binary|mathematical) (operator|function)",
	"\\$ operator is invalid for atomic vectors", "is not a function",
	"C stack usage", "evaluation nested too deeply", "infinite recursion")), collapse = "|")

adv_design = function(rt, y, X, w = NULL, n = adv_n, ...) {
	d = DesignFixedBernoulli$new(n = n, response_type = rt, verbose = FALSE)
	d$add_all_subjects_to_experiment(X)
	if (is.null(w)) d$assign_w_to_all_subjects() else d$overwrite_all_subject_assignments(w)
	d$add_all_subject_responses(y, ...)
	d
}

adv_scenarios = function() {
	set.seed(20260919)
	n = adv_n
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	Xc = transform(X, x2 = x1)
	w = rep(0:1, each = n / 2)
	nt = 6L
	Xt = data.frame(x1 = rnorm(nt), x2 = rnorm(nt))
	list(
		zero_count = function() adv_design("count", rep(0, n), X),
		separation_incid = function() adv_design("incidence", w, X, w),
		constant_continuous = function() adv_design("continuous", rep(3, n), X),
		collinear_continuous = function() adv_design("continuous", rnorm(n), Xc),
		collinear_count = function() adv_design("count", rpois(n, 2), Xc),
		collinear_incid = function() adv_design("incidence", rbinom(n, 1, 0.5), Xc),
		heavy_censoring = function() adv_design("survival", c(rexp(2), rep(NA, n - 2L)), X,
			y_Ls = c(rep(NA, 2), rexp(n - 2L)), y_Rs = c(rep(NA, 2), rep(Inf, n - 2L))),
		tiny_n_count = function() adv_design("count", rpois(nt, 2), Xt, n = nt),
		tiny_n_continuous = function() adv_design("continuous", rnorm(nt), Xt, n = nt),
		tiny_n_incid = function() adv_design("incidence", rbinom(nt, 1, 0.5), Xt, n = nt)
	)
}

adv_skip_class = function(nm) grepl("GLMM|Bayes|Exact|GEE|Stan", nm)

adv_violations = function(est, ci, p, tol = 1e-8) {
	v = character()
	if (!is.numeric(est) || length(est) != 1L) return("estimate is not a length-1 numeric")
	if (!is.na(est) && !is.finite(est)) v = c(v, "non-finite (Inf) estimate")
	if (!is.numeric(ci) || length(ci) != 2L) {
		v = c(v, "CI is not a length-2 numeric")
	} else {
		na_ci = is.na(ci)
		if (xor(na_ci[1L], na_ci[2L])) v = c(v, "CI has exactly one NA end")
		if (!any(na_ci)) {
			if (!all(is.finite(ci))) v = c(v, "CI has an infinite end")
			else {
				if (ci[1L] > ci[2L]) v = c(v, "reversed CI")
				if (is.finite(est) && (est < ci[1L] - tol * (1 + abs(est)) || est > ci[2L] + tol * (1 + abs(est)))) v = c(v, "CI excludes its own estimate")
				if (ci[1L] == ci[2L] && is.numeric(p) && length(p) == 1L && is.finite(p)) v = c(v, "zero-width CI with a finite p-value")
			}
		}
	}
	if (!is.numeric(p) || length(p) != 1L) v = c(v, "p-value is not a length-1 numeric")
	else if (!is.na(p) && (!is.finite(p) || p < 0 || p > 1)) v = c(v, "p-value outside [0, 1]")
	v
}

# Runs one inference object's estimate/asymp-CI/asymp-p and returns violations.
adv_run_one = function(inst, prep = NULL) {
	v = character()
	call = function(expr) tryCatch(suppressWarnings(expr), error = function(e) structure(conditionMessage(e), class = "adv_err"))
	# A class whose compute_estimate() cannot survive the injection itself (it
	# re-derives on a non-finite cached SE, so the wrapper recurses) is not
	# applicable to this fault -- not evidence of a defect in the class.
	if (!is.null(prep) && inherits(call(prep(inst)), "adv_err")) return(character())
	est = call(inst$compute_estimate())
	ci = call(inst$compute_asymp_confidence_interval())
	p = call(inst$compute_asymp_two_sided_pval())
	errs = Filter(function(x) inherits(x, "adv_err"), list(est, ci, p))
	for (e in errs) if (grepl(adv_programming_error, e, perl = TRUE)) v = c(v, paste0("code-defect error: ", substr(e, 1L, 60L)))
	if (length(errs)) return(v)
	c(v, adv_violations(est, ci, p))
}

adv_faults = list(se_na = NA_real_, se_nan = NaN, se_inf = Inf, se_negative = -1, se_zero = 0)

# compute_estimate() re-runs inside every CI/p-value call and would overwrite a
# one-off write to the cache, so wrap it on the instance: the real fit runs,
# then the fault replaces the standard error every time.
adv_inject = function(fault) function(inst) {
	priv = inst$.__enclos_env__$private
	orig = inst$compute_estimate
	busy = FALSE
	if (bindingIsLocked("compute_estimate", inst)) unlockBinding("compute_estimate", inst)
	inst$compute_estimate = function(...) {
		if (busy) return(orig(...))
		busy <<- TRUE
		on.exit(busy <<- FALSE)
		r = orig(...)
		cv = priv$cached_values
		cv$s_beta_hat_T = fault
		priv$cached_values = cv
		r
	}
	inst$compute_estimate()
}

adv_collect = function() {
	found = character()
	tested = 0L
	effective = 0L
	for (nm_s in names(adv_scenarios())) {
		des = tryCatch(adv_scenarios()[[nm_s]](), error = function(e) NULL)
		if (is.null(des)) next
		for (cls in des$applicable_inference_class_names()) {
			if (adv_skip_class(cls)) next
			gen = get(cls, envir = asNamespace("EDI"))
			inst = tryCatch(gen$new(des), error = function(e) NULL)
			if (is.null(inst)) next
			tested = tested + 1L
			for (v in adv_run_one(inst)) found = c(found, sprintf("%s|data:%s|%s", cls, nm_s, v))
		}
	}
	# Fault injection on benign data, one representative design per response type.
	set.seed(20260920)
	n = adv_n
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	benign = list(
		count = function() adv_design("count", rpois(n, 2), X),
		continuous = function() adv_design("continuous", rnorm(n), X),
		incidence = function() adv_design("incidence", rbinom(n, 1, 0.5), X),
		survival = function() adv_design("survival", rexp(n, 0.3), X)
	)
	for (rt in names(benign)) {
		des = benign[[rt]]()
		for (cls in des$applicable_inference_class_names()) {
			if (adv_skip_class(cls)) next
			gen = get(cls, envir = asNamespace("EDI"))
			for (fn in names(adv_faults)) {
				inst = tryCatch(gen$new(des), error = function(e) NULL)
				if (is.null(inst)) next
				base_ci = tryCatch(suppressWarnings(gen$new(des)$compute_asymp_confidence_interval()), error = function(e) NULL)
				tested = tested + 1L
				for (v in adv_run_one(inst, prep = adv_inject(adv_faults[[fn]]))) found = c(found, sprintf("%s|fault:%s|%s", cls, fn, v))
				fault_ci = tryCatch(suppressWarnings(inst$compute_asymp_confidence_interval()), error = function(e) NULL)
				if (!is.null(base_ci) && !isTRUE(all.equal(as.numeric(base_ci), as.numeric(fault_ci)))) effective = effective + 1L
			}
		}
	}
	list(found = unique(found), tested = tested, effective = effective)
}

# Pre-existing findings. Each is a real defect (or a documented limitation)
# that this test surfaced when it was written; fix it and delete the entry.
EDI_ADVERSARIAL_KNOWN = character()

adv_result = adv_collect()

test_that("adversarial-data and fault-injection sweep exercised a meaningful number of runs", {
	expect_gt(adv_result$tested, 150L)
})

test_that("the SE injection actually reaches CI construction for a meaningful number of class x fault pairs", {
	expect_gt(adv_result$effective, 20L)
})

test_that("no inference class returns a wrong-looking number, or a code-defect error, on pathological data or an injected SE fault", {
	new = setdiff(adv_result$found, EDI_ADVERSARIAL_KNOWN)
	if (length(new)) cat("\nNew adversarial findings:\n", paste0("  ", new, collapse = "\n"), "\n")
	expect_equal(new, character())
})

test_that("EDI_ADVERSARIAL_KNOWN holds no stale entries", {
	stale = setdiff(EDI_ADVERSARIAL_KNOWN, adv_result$found)
	if (length(stale)) cat("\nStale (no longer occurring) entries -- delete them:\n", paste0("  ", stale, collapse = "\n"), "\n")
	expect_equal(stale, character())
})

test_that("the invariant checker itself flags each class of wrong-looking output", {
	expect_true("reversed CI" %in% adv_violations(0, c(2, 1), 0.5))
	expect_true("CI excludes its own estimate" %in% adv_violations(5, c(0, 1), 0.5))
	expect_true("zero-width CI with a finite p-value" %in% adv_violations(1, c(1, 1), 0))
	expect_true("p-value outside [0, 1]" %in% adv_violations(0, c(-1, 1), 1.5))
	expect_true("CI has exactly one NA end" %in% adv_violations(0, c(NA, 1), NA_real_))
	expect_true("non-finite (Inf) estimate" %in% adv_violations(Inf, c(NA_real_, NA_real_), NA_real_))
	expect_length(adv_violations(0.3, c(-1, 1), 0.4), 0L)
	expect_length(adv_violations(NA_real_, c(NA_real_, NA_real_), NA_real_), 0L)
})
