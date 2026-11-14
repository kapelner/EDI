#!/usr/bin/env Rscript
# Plans one wave of the cloud comprehensive study (.github/workflows/comprehensive-study.yml,
# release_v1_1_0.md TODO-194). Base R plus data.table; no EDI.
#
# Unit of work (a "piece"): one (response type, dataset, design, inference class, beta_T, rep)
# of comprehensive_tests.R. The pieces come from the cost table (build_comprehensive_study_costs.R):
# every (response, dataset, design, class) it lists runs at both beta_T values and every rep; a
# class seen at only one beta_T gets the other's cost. For each (response, dataset, design,
# beta_T) one catch-all call at rep 1 runs every class the table does not list
# (COMPREHENSIVE_INFERENCE_CLASS_EXCLUDE = the listed ones), so a class added since the table
# was built is found; analyze records such classes in discovered.csv (same columns as the cost
# table, measured cost), and --discovered adds them here, so their other reps are planned.
#
# Pieces in the campaign's ledger.csv are done. The rest are grouped into runner calls (one
# Rscript comprehensive_tests.R per call, classes of one case joined in the class-filter regex)
# of at most --call-minutes of estimated work, calls into processes of about --target-minutes,
# and --procs processes into one job; the first --wave-size jobs are this wave. Estimates are
# local seconds x --speed plus --overhead-sec per call.
#
# Usage:
#   plan_comprehensive_study.R --costs costs.csv [--fallback-costs costs.csv] [--discovered discovered.csv] [--ledger ledger.csv] --reps 50 \
#     [--wave-size 256] [--procs 4] [--target-minutes 25] [--call-minutes 20] [--speed 1.5] \
#     [--overhead-sec 75] --out-plan plan.csv --out-matrix matrix.json
# Writes plan.csv (one row per call: job, proc, seq, call_id, response_type, dataset, design,
# beta_T, reps (comma list), n_reps, classes, class_regex, exclude_regex, est_sec) and matrix.json ({"job":[...]}).
# Prints "jobs=<k>" and "remaining_pieces=<m>" for $GITHUB_OUTPUT; jobs=0 means complete.

suppressPackageStartupMessages(library(data.table))

cs_args = function(args = commandArgs(trailingOnly = TRUE)) {
	opt = list(costs = NULL, fallback_costs = "", discovered = "", ledger = "", reps = NA_integer_, wave_size = 256L, procs = 4L, target_minutes = 25,
		call_minutes = 20, speed = 1.5, overhead_sec = 75, out_plan = NULL, out_matrix = NULL)
	i = 1L
	while (i <= length(args)) {
		k = sub("^--", "", args[[i]]); v = if (i < length(args)) args[[i + 1L]] else NA_character_
		k = gsub("-", "_", k)
		if (!k %in% names(opt)) stop("unknown argument --", k)
		opt[[k]] = if (is.numeric(opt[[k]])) as.numeric(v) else v
		i = i + 2L
	}
	if (is.null(opt$costs) || is.na(opt$reps) || is.null(opt$out_plan) || is.null(opt$out_matrix)) stop("--costs, --reps, --out-plan and --out-matrix are required")
	opt
}

cs_class_regex = function(classes) sprintf("^(%s)( |$)", paste(classes, collapse = "|"))

cs_pieces = function(costs, reps) {
	costs = as.data.table(costs)
	both = CJ(beta_T = c(0, 0.5), key_id = unique(costs[, paste(response_type, dataset, design, class, sep = "\r")]))
	known = costs[, .(key_id = paste(response_type, dataset, design, class, sep = "\r"), beta_T, sec_per_rep)]
	p = merge(both, known, by = c("key_id", "beta_T"), all.x = TRUE)
	p[, sec_per_rep := if (all(is.na(sec_per_rep))) 0 else ifelse(is.na(sec_per_rep), max(sec_per_rep, na.rm = TRUE), sec_per_rep), by = key_id]
	p[, c("response_type", "dataset", "design", "class") := tstrsplit(key_id, "\r", fixed = TRUE)]
	p[, key_id := NULL]
	p = p[rep(seq_len(.N), each = reps)][, rep := rep_len(seq_len(reps), .N)]
	other = unique(p[, .(response_type, dataset, design, beta_T)])[, `:=`(class = "__other__", sec_per_rep = 0, rep = 1L)]
	rbind(p, other, use.names = TRUE)
}

cs_plan = function(costs, ledger, reps, wave_size = 256L, procs = 4L, target_minutes = 25, call_minutes = 20, speed = 1.5, overhead_sec = 75) {
	p = cs_pieces(costs, reps)
	if (!is.null(ledger) && nrow(ledger)) {
		done = unique(as.data.table(ledger)[, .(response_type, dataset, design, class, beta_T = as.numeric(beta_T), rep = as.integer(rep))])
		p = p[!done, on = .(response_type, dataset, design, class, beta_T, rep)]
	}
	remaining = nrow(p)
	if (!remaining) return(list(plan = data.table(), jobs = 0L, remaining = 0L))
	p[, est := sec_per_rep * speed]
	cap = call_minutes * 60
	all_known = as.data.table(costs)[, .(known_all = list(sort(unique(class)))), by = .(response_type, dataset, design)]
	# Calls. Within one (response, dataset, design, beta_T): classes are split into sets whose
	# per-rep cost fits `cap`; each set runs its remaining reps in chunks of as many reps as fit
	# `cap` (one call per chunk, reps given to the runner as a list). A set re-runs a piece that is
	# already done only when its classes have different reps left; analyze keeps the newest row
	# per id, so such duplicates are harmless. The catch-all runs alone at rep 1.
	grp = c("response_type", "dataset", "design", "beta_T")
	main = p[class != "__other__"]
	cls = main[, .(est = max(est), reps_left = list(sort(unique(rep)))), by = c(grp, "class")]
	setorderv(cls, c(grp, "est"), c(1L, 1L, 1L, 1L, -1L))
	cls[, set := {
		n = integer(.N); acc = 0; cur = 1L
		for (i in seq_len(.N)) { if (acc > 0 && acc + est[i] > cap) { cur = cur + 1L; acc = 0 }; n[i] = cur; acc = acc + est[i] }
		n
	}, by = grp]
	sets = cls[, .(classes = paste(class, collapse = ";"), set_est = sum(est), reps_left = list(sort(unique(unlist(reps_left))))), by = c(grp, "set")]
	calls = sets[, {
		r = reps_left[[1L]]; k = max(1L, floor(cap / max(set_est, 1)))
		chunks = split(r, ceiling(seq_along(r) / k))
		.(chunk = seq_along(chunks), reps = vapply(chunks, paste, "", collapse = ","),
		  n_reps = lengths(chunks), est_sec = set_est * lengths(chunks) + overhead_sec, classes = classes)
	}, by = c(grp, "set")]
	other = p[class == "__other__", c(grp, "rep"), with = FALSE][, `:=`(set = 0L, chunk = 1L, reps = as.character(rep),
		n_reps = 1L, est_sec = overhead_sec, classes = "__other__")][, rep := NULL]
	calls = rbind(calls, other, use.names = TRUE)
	calls = merge(calls, all_known, by = c("response_type", "dataset", "design"), all.x = TRUE)
	calls[, class_regex := ifelse(classes == "__other__", "NA", vapply(strsplit(classes, ";", fixed = TRUE), cs_class_regex, ""))]
	calls[, exclude_regex := ifelse(classes == "__other__", vapply(known_all, function(k) if (length(k)) cs_class_regex(k) else "", ""), "")]
	calls[, known_all := NULL]
	calls[, call_id := sprintf("%s-%s-%s-b%s-%s", response_type, dataset, design, format(beta_T),
		ifelse(classes == "__other__", "other", sprintf("s%d-c%d", set, chunk)))]
	# Processes: first-fit decreasing to target_minutes; a call above it gets a process to itself.
	setorder(calls, -est_sec)
	tgt = target_minutes * 60
	loads = numeric(0); proc_of = integer(nrow(calls))
	for (i in seq_len(nrow(calls))) {
		fit = which(loads + calls$est_sec[i] <= tgt)
		if (length(fit)) { j = fit[1L]; loads[j] = loads[j] + calls$est_sec[i] } else { loads = c(loads, calls$est_sec[i]); j = length(loads) }
		proc_of[i] = j
	}
	calls[, proc_global := proc_of]
	# Jobs: processes sorted by load, dealt in groups of `procs`, so a job's processes take similar time.
	ord = order(-loads)
	job_of_proc = integer(length(loads)); proc_in_job = integer(length(loads))
	job_of_proc[ord] = (seq_along(ord) - 1L) %/% procs + 1L
	proc_in_job[ord] = (seq_along(ord) - 1L) %% procs
	calls[, `:=`(job = job_of_proc[proc_global], proc = proc_in_job[proc_global])]
	calls = calls[job <= wave_size]
	setorder(calls, job, proc, -est_sec)
	calls[, seq := seq_len(.N), by = .(job, proc)]
	plan = calls[, .(job, proc, seq, call_id, response_type, dataset, design, beta_T, reps, n_reps, classes,
		class_regex, exclude_regex, est_sec = round(est_sec))]
	list(plan = plan, jobs = if (nrow(plan)) max(plan$job) else 0L, remaining = remaining)
}

if (sys.nframe() == 0L) {
	opt = cs_args()
	costs = fread(opt$costs)
	# --fallback-costs: pieces the main table (the previous campaign's measured costs) lacks,
	# e.g. a (response, dataset, design) that campaign did not run, come from this one.
	if (nzchar(opt$fallback_costs) && file.exists(opt$fallback_costs)) {
		fb = fread(opt$fallback_costs)
		costs = unique(rbind(costs, fb[, names(costs), with = FALSE]), by = c("response_type", "dataset", "design", "class", "beta_T"))
	}
	if (nzchar(opt$discovered) && file.exists(opt$discovered)) {
		disc = fread(opt$discovered)
		if (nrow(disc)) costs = unique(rbind(costs, disc[, names(costs), with = FALSE]), by = c("response_type", "dataset", "design", "class", "beta_T"))
	}
	ledger = if (nzchar(opt$ledger) && file.exists(opt$ledger)) fread(opt$ledger) else NULL
	res = cs_plan(costs, ledger, as.integer(opt$reps), as.integer(opt$wave_size), as.integer(opt$procs),
		opt$target_minutes, opt$call_minutes, opt$speed, opt$overhead_sec)
	fwrite(res$plan, opt$out_plan)
	writeLines(sprintf('{"job":[%s]}', paste(seq_len(res$jobs), collapse = ",")), opt$out_matrix)
	cat(sprintf("jobs=%d\nremaining_pieces=%d\n", res$jobs, res$remaining))
	if (res$jobs > 0L) {
		cat(sprintf("# %d calls in %d jobs; estimated %.1f job-hours this wave (longest job %.0f min)\n",
			nrow(res$plan), res$jobs, sum(res$plan$est_sec) / 3600 / as.integer(opt$procs),
			max(res$plan[, .(t = sum(est_sec)), by = .(job, proc)]$t) / 60), file = stderr())
	}
}
