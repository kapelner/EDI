#!/usr/bin/env Rscript
# v1.0.5 TODO-198: renders the tables of the vignette "Which procedure can I
# trust at my sample size?" (R/EDI/vignettes/procedure-trust.Rmd) from the
# regime / convergence-rate registry (R/EDI/R/inference_procedure_regime.R).
#
# The vignette is eval = FALSE and must build on CRAN without the calibration
# scripts, so its tables are static text between marker comments:
#
#   <!-- BEGIN GENERATED registry -->  ...  <!-- END GENERATED registry -->
#   <!-- BEGIN GENERATED counts -->    ...  <!-- END GENERATED counts -->
#
# This script is the only thing that writes between the markers, and
# testthat_bulk/test-procedure-trust-vignette-tables.R fails when the vignette
# differs from what this script renders. Regenerate with
#
#   Rscript R/package_tests/render_procedure_trust_tables.R --write
#
# run from the repo root. The `registry` block needs only the registry file
# (base R). The `counts` block counts the applicable (design, class, procedure)
# triples exactly as the calibration planner enumerates them, which needs the
# package loaded with pkgload::load_all("R/EDI", compile = FALSE) (never a
# compile) and the calibration scripts; without them `--write` leaves the
# counts block as it is.
#
# Legacy IVWC classes are never listed or counted.

# ---- citation keys (R/EDI/REFERENCES.md) ------------------------------------
# The registry's `reference` column is free text. These maps give the
# REFERENCES.md key of each work it cites, per procedure and per regularity.
# A test checks every key here exists in REFERENCES.md.
TRUST_PROCEDURE_KEYS = list(
	exact = character(0),
	rand = c("Fisher1935", "LehmannRomano2005"),
	wald = c("Hall1992", "CoxSnell1968"),
	jackknife = c("ShaoTu1995"),
	score = c("BarndorffNielsenCox1994"),
	lik_ratio = c("BarndorffNielsenCox1994"),
	gradient = c("Terrell2002", "Lemonte2016"),
	lik_ratio_bartlett_approx = c("Lawley1956", "BarndorffNielsenHall1988"),
	lik_ratio_bartlett_exact = c("Lawley1956", "BarndorffNielsenHall1988"),
	param_boot = c("Beran1988", "DiCiccioMartinStern2001"),
	param_boot_direct = c("Hall1992"),
	bootstrap = c("Hall1992"),
	bayes_boot = c("Rubin1981", "Lo1987"),
	rand_bootstrap = character(0)
)
TRUST_REGULARITY_KEYS = list(
	boundary = c("SelfLiang1987"),
	variance_component = c("SelfLiang1987", "StramLee1994"),
	mixture = c("SelfLiang1987"),
	nonparametric_rate = c("HallSheather1988", "Koenker2005", "Powell1991"),
	design_mismatch = c("BaiRomanoShaikh2021", "BugniCanayShaikh2018", "LiDingRubin2018"),
	other = c("Davies1977", "Huber1981")
)
TRUST_REGULARITY_WHY = c(
	boundary = "The estimate can sit on the edge of the parameter space (a fitted probability at 0 or 1), where the usual limit does not apply.",
	variance_component = "A random-effect variance near zero is on the boundary, and the likelihood limit for it is not chi-square.",
	mixture = "The inflation probability can be on the boundary, where the information is singular.",
	nonparametric_rate = "The standard error needs an estimate of the density at the quantile (the sparsity), which converges slower than n^-1/2.",
	design_mismatch = "The variance formula ignores the covariate balancing of the design, so the interval stays conservative as n grows.",
	other = "Non-standard limit: unidentified nuisance parameters under the null, or an estimated scale."
)
TRUST_NEFF_RULE = c(
	n = "number of subjects",
	n_pairs = "number of matched pairs",
	n_pairs_plus_reservoir = "matched pairs plus unmatched subjects",
	n_min_arm = "size of the smaller arm",
	n_events = "number of events (failures, or incident cases)",
	n_nonzero = "number of nonzero counts",
	n_clusters = "number of clusters",
	n_strata = "number of strata"
)

# ---- helpers ----------------------------------------------------------------
trust_is_ivwc = function(x) grepl("IVWC", x, fixed = TRUE)

trust_render_order = function(x) {
	vapply(x, function(v) {
		if (is.na(v)) return("unknown")
		if (is.infinite(v)) return("exact")
		if (v == 0) return("O(1)")
		for (den in 1:6) {
			num = v * den
			if (abs(num - round(num)) < 1e-9) {
				ex = if (den == 1L) sprintf("%d", round(num)) else sprintf("%d/%d", round(num), den)
				return(sprintf("O(n^-%s)", ex))
			}
		}
		sprintf("O(n^-%.2f)", v)
	}, "")
}

trust_keys = function(keys) if (length(keys)) paste0("[", keys, "]", collapse = " ") else "none"

trust_table = function(header, rows) {
	esc = function(x) gsub("|", "\\|", x, fixed = TRUE)
	c(paste0("| ", paste(header, collapse = " | "), " |"),
		paste0("|", paste(rep("---", length(header)), collapse = "|"), "|"),
		vapply(rows, function(r) paste0("| ", paste(esc(r), collapse = " | "), " |"), ""))
}

trust_load_registry = function(repo) {
	env = new.env(parent = baseenv())
	sys.source(file.path(repo, "R", "EDI", "R", "inference_procedure_regime.R"), envir = env)
	env
}

# ---- block 1: registry-only tables --------------------------------------------
trust_render_registry_block = function(reg) {
	d = reg$EDI_CONVERGENCE_PROCEDURE_DEFAULTS
	regime = reg$EDI_INFERENCE_PROCEDURE_REGIME
	ov = reg$EDI_CONVERGENCE_OVERRIDES
	ov = ov[is.na(ov$class) | !trust_is_ivwc(ov$class), , drop = FALSE]

	# Table 1: procedures.
	t1 = trust_table(
		c("Procedure", "Regime", "Size error in a regular model", "Basis of that rate", "Citations"),
		lapply(seq_len(nrow(d)), function(i) {
			p = d$procedure[i]
			c(sprintf("`%s`", p), gsub("_", " ", regime[[p]]), trust_render_order(d$size_order[i]),
				gsub("_", " ", d$basis[i]),
				trust_keys(TRUST_PROCEDURE_KEYS[[p]]))
		}))

	# Table 2: effective-n rules other than the default n.
	cls_n = ov[ov$layer == "class" & !is.na(ov$n_eff), c("class", "n_eff")]
	cls_n = unique(cls_n)
	rule_rows = lapply(setdiff(reg$EDI_CONVERGENCE_N_EFF, "n"), function(r) {
		cl = sort(unique(cls_n$class[cls_n$n_eff == r]))
		des = sort(unique(ov$design[ov$layer == "design" & !is.na(ov$n_eff) & ov$n_eff == r]))
		who = c(if (length(cl)) sprintf("%d classes", length(cl)),
			if (length(des)) paste("designs", paste0("`", des, "`", collapse = ", ")))
		if (!length(who)) who = "none registered"
		if (length(cl) && length(cl) <= 3L) who[1L] = paste0("`", cl, "`", collapse = ", ")
		c(sprintf("`%s`", r), TRUST_NEFF_RULE[[r]], paste(who, collapse = "; "))
	})
	t2 = trust_table(c("Effective n", "Meaning", "Applies to"),
		c(list(c("`n`", TRUST_NEFF_RULE[["n"]], "every other class and design")), rule_rows))

	# Table 3: non-regular classes.
	reg_rows = ov[!is.na(ov$regularity), , drop = FALSE]
	t3_rows = lapply(setdiff(reg$EDI_CONVERGENCE_REGULARITY, "regular"), function(g) {
		r = reg_rows[reg_rows$regularity == g, , drop = FALSE]
		if (!nrow(r)) return(NULL)
		cl = sort(unique(r$class))
		sz = ifelse(r$size_unknown, NA_real_, r$size_order)
		order_txt = paste(unique(trust_render_order(sz)), collapse = ", ")
		c(gsub("_", " ", g), sprintf("%d", length(cl)), order_txt, TRUST_REGULARITY_WHY[[g]],
			trust_keys(TRUST_REGULARITY_KEYS[[g]]))
	})
	t3 = trust_table(c("Kind", "Classes", "Size error", "Why", "Citations"), Filter(Negate(is.null), t3_rows))

	# Per-class list of the unknown-order classes, by kind.
	unk = reg_rows[reg_rows$size_unknown, , drop = FALSE]
	t4_rows = lapply(sort(unique(unk$regularity)), function(g) {
		cl = sort(unique(unk$class[unk$regularity == g]))
		c(gsub("_", " ", g), paste0("`", cl, "`", collapse = ", "))
	})
	t4 = trust_table(c("Kind", "Classes whose rate is not known"), t4_rows)

	c("<!-- BEGIN GENERATED registry -->",
		"<!-- Generated by R/package_tests/render_procedure_trust_tables.R from the registry. Do not edit by hand. -->",
		"", "**Procedures.**", "", t1, "",
		"**Effective-n rules** (every rule other than `n`).", "", t2, "",
		"**Non-regular cases.** Classes counted once per kind.", "", t3, "",
		"**Classes whose rate is not known.**", "", t4, "",
		"<!-- END GENERATED registry -->")
}

# ---- applicable triples (as the calibration planner enumerates them) -----------
trust_applicable_triples = function(repo) {
	if (!requireNamespace("EDI", quietly = TRUE)) return(NULL)
	ns = asNamespace("EDI")
	if (!exists("inference_class_registry_as_list", envir = ns, inherits = FALSE) ||
		!exists("inference_convergence_expectation", envir = ns, inherits = FALSE)) return(NULL)
	cal = file.path(repo, "R", "package_tests", "calibration")
	if (!file.exists(file.path(cal, "calibration_study_common.R"))) return(NULL)
	env = new.env(parent = ns)
	assign("script_dir", cal, envir = env)
	assign("source", function(file, ...) sys.source(file, envir = env), envir = env)
	ok = tryCatch({
		suppressWarnings(suppressMessages(sys.source(file.path(cal, "calibration_study_common.R"), envir = env)))
		TRUE
	}, error = function(e) FALSE)
	if (!ok) return(NULL)
	spec = c(ns$EDI_INFERENCE_SUITE_CI_METHOD_PRIORITY, ns$EDI_INFERENCE_SUITE_PVAL_METHOD_PRIORITY)
	cap = vapply(spec, `[[`, "", "capability")
	lab = vapply(spec, `[[`, "", "label")
	cache = new.env()
	procs = function(cl) {
		if (is.null(cache[[cl]])) cache[[cl]] = sort(unique(lab[cap %in% ns$get_effective_capabilities(cl)]))
		cache[[cl]]
	}
	rows = list()
	for (d in env$cal_study_designs()) for (rt in env$CAL_RESPONSE_TYPES) {
		cls = tryCatch(suppressWarnings(suppressMessages(env$cal_study_classes(rt, d, 50L))), error = function(e) character(0))
		for (cl in cls) rows[[length(rows) + 1L]] = data.frame(design = d, class = cl, procedure = procs(cl), stringsAsFactors = FALSE)
	}
	tr = unique(do.call(rbind, rows))
	tr[!trust_is_ivwc(tr$class), , drop = FALSE]
}

# ---- block 2: counts -----------------------------------------------------------
trust_render_counts_block = function(reg, triples) {
	r = reg$inference_convergence_expectation(triples$design, triples$class, triples$procedure)
	bases = c("theory", "literature", "empirical", "assumed_default", "unknown")
	regimes = c("finite_sample", "asymptotic")
	cell = function(rg, b) sum(r$regime == rg & r$basis == b)
	t1 = trust_table(c("Regime", "Triples", paste(gsub("_", " ", bases))),
		c(lapply(regimes, function(rg) c(gsub("_", " ", rg), format(sum(r$regime == rg), big.mark = ","),
			trimws(format(vapply(bases, function(b) cell(rg, b), 0L), big.mark = ",", trim = TRUE)))),
			list(c("**all**", format(nrow(r), big.mark = ","), format(vapply(bases, function(b) sum(r$basis == b), 0L), big.mark = ",", trim = TRUE)))))
	a = r[r$regime == "asymptotic", , drop = FALSE]
	regs = reg$EDI_CONVERGENCE_REGULARITY
	t2 = trust_table(c("Regularity (asymptotic procedures)", "Triples", "Share"),
		lapply(regs[regs %in% a$regularity], function(g) {
			n = sum(a$regularity == g)
			c(gsub("_", " ", g), format(n, big.mark = ","), sprintf("%.1f%%", 100 * n / nrow(a)))
		}))
	nu = sum(a$basis == "unknown"); nd = sum(a$basis == "assumed_default")
	c("<!-- BEGIN GENERATED counts -->",
		"<!-- Generated by R/package_tests/render_procedure_trust_tables.R from the registry. Do not edit by hand. -->",
		"",
		sprintf("Scope: %d designs, %d inference classes, %s (design, class, procedure) triples, the ones the calibration study runs.",
			length(unique(triples$design)), length(unique(triples$class)), format(nrow(r), big.mark = ",")),
		"",
		t1, "", t2, "",
		sprintf("Of the %s asymptotic triples, %.1f%% rest on an assumed default and %.1f%% have an unknown rate.",
			format(nrow(a), big.mark = ","), 100 * nd / nrow(a), 100 * nu / nrow(a)),
		"",
		"<!-- END GENERATED counts -->")
}

# ---- splice into the vignette ----------------------------------------------------
trust_extract_block = function(lines, id) {
	b = grep(sprintf("^<!-- BEGIN GENERATED %s -->$", id), lines)
	e = grep(sprintf("^<!-- END GENERATED %s -->$", id), lines)
	if (length(b) != 1L || length(e) != 1L || e < b) return(NULL)
	lines[b:e]
}

trust_splice_block = function(lines, id, block) {
	b = grep(sprintf("^<!-- BEGIN GENERATED %s -->$", id), lines)
	e = grep(sprintf("^<!-- END GENERATED %s -->$", id), lines)
	stopifnot(length(b) == 1L, length(e) == 1L, e > b)
	c(lines[seq_len(b - 1L)], block, lines[-seq_len(e)])
}

trust_vignette_path = function(repo) file.path(repo, "R", "EDI", "vignettes", "procedure-trust.Rmd")

if (sys.nframe() == 0L && "--write" %in% commandArgs(TRUE)) {
	args = commandArgs(FALSE)
	here = dirname(sub("^--file=", "", grep("^--file=", args, value = TRUE)[1]))
	repo = normalizePath(file.path(here, "..", ".."))
	reg = trust_load_registry(repo)
	path = trust_vignette_path(repo)
	lines = readLines(path, warn = FALSE)
	lines = trust_splice_block(lines, "registry", trust_render_registry_block(reg))
	tr = NULL
	if (requireNamespace("pkgload", quietly = TRUE)) {
		# Never compiles: compile = FALSE is explicit (project CLAUDE.md).
		suppressMessages(pkgload::load_all(file.path(repo, "R", "EDI"), compile = FALSE, quiet = TRUE))
		tr = trust_applicable_triples(repo)
	}
	if (is.null(tr)) {
		message("counts block left unchanged: needs load_all(compile = FALSE) and the calibration scripts")
	} else {
		lines = trust_splice_block(lines, "counts", trust_render_counts_block(reg, tr))
	}
	writeLines(lines, path)
	message("wrote ", path)
}
