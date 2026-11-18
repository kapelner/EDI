# Sweep: call every exported Inference class's compute_*confidence_interval /
# compute_*pval method with alpha, delta or pval_epsilon = NA and record whether
# it errors (good) or returns (an unguarded argument). v1.0.6-TODO-105.
# Run from the repo root:  Rscript R/package_tests/sweep_na_argument_guards.R
# Output CSV: $EDI_NA_SWEEP_OUT (default: a file in tempdir()). Uses
# pkgload::load_all(compile = FALSE); takes a few minutes.
suppressMessages(pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE))
set.seed(7)
n = 24L
X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
ys = list(continuous = rnorm(n), incidence = rbinom(n,1,.5), proportion = runif(n,.05,.95),
          count = rpois(n,3), survival = rexp(n)+0.1, ordinal = sample(1:4, n, TRUE))
mk = function(cls, rt){ d = cls$new(n = n, response_type = rt, verbose = FALSE); d$add_all_subjects_to_experiment(X); d$assign_w_to_all_subjects(); d$add_all_subject_responses(ys[[rt]]); d }
designs = list()
for (rt in names(ys)) { designs[[paste0("bern_",rt)]] = mk(DesignFixedBernoulli, rt); designs[[paste0("match_",rt)]] = suppressWarnings(mk(DesignFixedBinaryMatch, rt)) }
exps = sort(grep("^Inference", getNamespaceExports("EDI"), value = TRUE))
exps = setdiff(exps, c("InferenceSuite","InferenceRandCustom"))
res = list()
for (cn in exps) {
  gen = get(cn, envir = asNamespace("EDI"))
  if (!inherits(gen, "R6ClassGenerator")) next
  inf = NULL
  for (dn in names(designs)) { inf = tryCatch(suppressWarnings(suppressMessages(gen$new(designs[[dn]], verbose = FALSE))), error = function(e) NULL); if (!is.null(inf)) break }
  if (is.null(inf)) { res[[length(res)+1]] = data.frame(cls=cn, method="<no fixture>", arg="", outcome="skip", msg=""); next }
  meths = grep("^compute_.*(confidence_interval|pval)", names(inf), value = TRUE)
  for (m in meths) {
    f = inf[[m]]; if (!is.function(f)) next
    fm = names(formals(f))
    for (a in intersect(c("alpha","delta","pval_epsilon"), fm)) {
      args = setNames(list(NA_real_), a)
      if ("B" %in% fm) args$B = 11L; if ("r" %in% fm) args$r = 11L; if ("show_progress" %in% fm) args$show_progress = FALSE
      t0 = Sys.time()
      out = tryCatch({ v = suppressWarnings(suppressMessages(do.call(f, args))); list("RETURNED", paste(format(v), collapse=" ")) }, error = function(e) list("error", conditionMessage(e)))
      res[[length(res)+1]] = data.frame(cls=cn, method=m, arg=a, outcome=out[[1]], msg=substr(gsub("\n"," ",out[[2]]),1,120), secs=round(as.numeric(Sys.time()-t0),2))
    }
  }
}
r = do.call(rbind, lapply(res, function(x){ if(is.null(x$secs)) x$secs=NA; x}))
out = Sys.getenv("EDI_NA_SWEEP_OUT", file.path(tempdir(), "na_argument_sweep.csv")); write.csv(r, out, row.names = FALSE); cat("wrote", out, "\n")
print(table(r$outcome)); print(table(grepl("missing values", r$msg)))
print(r[r$outcome=="RETURNED",])
print(r[r$outcome=="skip",])
print(sum(r$secs, na.rm=TRUE))
