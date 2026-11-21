#' Combine Zhang Exact Component P-Values
#'
#' @description Internal method.
#' Combines the matched-pairs and reservoir component p-values used by Zhang
#' (2026) exact test-inversion inference into one p-value.
#'
#' @name zhang_combine_exact_pvals
#' @param p_M Matched p-value.
#' @param p_R Reservoir p-value.
#' @param m Number of matches.
#' @param nRT Number of treated in reservoir.
#' @param nRC Number of control in reservoir.
#' @param method Combination method: \code{"Fisher"}, \code{"Stouffer"} or \code{"min_p"}
#'   (\eqn{1 - (1 - \min(p_M, p_R))^2}).
#' @return A single p-value. A component is usable when its sample is non-empty
#'   (\code{m > 0}, or \code{nRT > 0} and \code{nRC > 0}) and its p-value is finite
#'   and positive. If both are usable they are combined by \code{method}; if only
#'   one is, its p-value is returned unchanged; if neither is, \code{NA_real_}.
#' @keywords internal
zhang_combine_exact_pvals = function(p_M, p_R, m, nRT, nRC, method){
	has_M = m > 0              && is.finite(p_M) && p_M > 0
	has_R = nRT > 0 && nRC > 0 && is.finite(p_R) && p_R > 0

	if (has_M && has_R){
		switch(method,
			Fisher = {
				stats::pchisq(-2 * (base::log(p_M) + base::log(p_R)), df = 4, lower.tail = FALSE)
			},
			Stouffer = {
				z_M = stats::qnorm(1 - p_M / 2)
				z_R = stats::qnorm(1 - p_R / 2)
				z_combined = (z_M + z_R) / base::sqrt(2)
				2 * stats::pnorm(-base::abs(z_combined))
			},
			min_p = {
				1 - (1 - base::min(p_M, p_R))^2
			}
		)
	} else if (has_M){
		p_M
	} else if (has_R){
		p_R
	} else {
		NA_real_
	}
}

# zhang_combine_exact_pvals() elementwise over vectors p_M, p_R (same values, one
# call instead of one per delta; v1.0.6-TODO-285).
zhang_combine_exact_pvals_vec = function(p_M, p_R, m, nRT, nRC, method){
	has_M = m > 0              & is.finite(p_M) & p_M > 0
	has_R = nRT > 0 & nRC > 0  & is.finite(p_R) & p_R > 0
	out = rep(NA_real_, length(p_M))
	only_M = has_M & !has_R
	only_R = has_R & !has_M
	out[only_M] = p_M[only_M]
	out[only_R] = p_R[only_R]
	both = has_M & has_R
	if (any(both)){
		pM = p_M[both]
		pR = p_R[both]
		out[both] = switch(method,
			Fisher = stats::pchisq(-2 * (base::log(pM) + base::log(pR)), df = 4, lower.tail = FALSE),
			Stouffer = 2 * stats::pnorm(-base::abs((stats::qnorm(1 - pM / 2) + stats::qnorm(1 - pR / 2)) / base::sqrt(2))),
			min_p = 1 - (1 - base::pmin(pM, pR))^2,
			stop("unknown combination method: ", method)
		)
	}
	out
}

zhang_bisect_ci_boundary = function(p_fn, inside, outside, pval_th, tol){
	# A finite Wald-derived initial endpoint is merely a starting scale, not a
	# valid inversion bracket.  Exact zero-cell tables in particular can have an
	# infinite endpoint, so expand toward the requested tail until it rejects;
	# if even the numerically safe log-odds cap remains inside, that endpoint is
	# genuinely unbounded on this scale.
	p_at = function(delta){
		p = tryCatch(p_fn(delta), error = function(e) NA_real_)
		if (is.na(p) || !is.finite(p)) 0 else p
	}
	direction = sign(outside - inside)
	if (!is.finite(direction) || direction == 0) direction = 1
	max_abs_delta = log(.Machine$double.xmax) / 2
	step = max(abs(outside - inside), 1)
	outside = inside + direction * step
	p_outside = p_at(outside)
	while (p_outside > pval_th && abs(outside) < max_abs_delta){
		step = min(2 * step, max_abs_delta + abs(inside))
		outside = inside + direction * step
		if (abs(outside) > max_abs_delta) outside = direction * max_abs_delta
		p_outside = p_at(outside)
	}
	if (p_outside > pval_th) return(direction * Inf)

	zhang_bisect_bracket(p_at, inside, outside, pval_th, zhang_ci_width_tol(tol))
}

# `pval_epsilon` historically controlled a very loose p-value residual (0.005 by
# default). Endpoint accuracy instead follows the parameter-scale bracket; cap a
# legacy caller's value at 1e-6 for a stable exact CI.
zhang_ci_width_tol = function(tol) min(max(as.numeric(tol)[1L], 1e-12), 1e-6)

# Plain bisection of a bracket whose `inside` end is accepted (p > pval_th) and
# whose `outside` end is rejected; returns the midpoint of the final bracket.
zhang_bisect_bracket = function(p_at, inside, outside, pval_th, width_tol){
	for (iter in seq_len(100L)){
		mid   = (inside + outside) / 2
		p_mid = p_at(mid)

		# A small p-value residual does not imply a precise endpoint when the
		# exact p-value curve is locally flat.  Converge on the parameter-scale
		# bracket promised by this helper instead.
		# An exact threshold value is already a valid boundary.  In particular,
		# treating equality as the rejected side would walk a flat p == alpha
		# segment all the way back to `inside`, despite the midpoint itself
		# satisfying the inversion equation.
		if (isTRUE(p_mid == pval_th)) return(mid)
		if (abs(outside - inside) < width_tol) break

		if (p_mid > pval_th){
			inside  = mid
		} else {
			outside = mid
		}
	}
	(inside + outside) / 2
}

# Breakpoints of the combined exact p-value in delta (v1.0.6-TODO-233). Both
# components are two-sided "minimum likelihood" p-values: the probability, under
# log odds ratio delta, of every outcome j no more likely than the observed x. For
# the matched-pair binomial and the reservoir's noncentral hypergeometric alike,
# log P(j) - log P(x) = c(j) - c(x) + (j - x) * delta, so outcome j changes sides
# exactly at delta = (c(x) - c(j)) / (j - x), where it ties with x. These are the
# only points where a component jumps; at a breakpoint the tie is counted (within
# the kernels' 1e-7 relative tolerance), so the p-value there is at least its
# limit from either side. Beyond the outermost breakpoint on either side every
# comparison is fixed, the p-value is a one-sided tail probability, and it falls
# monotonically away from the data, so nothing farther out can be accepted.
zhang_exact_pval_breakpoints = function(exact_stats, comps = zhang_exact_pval_components(exact_stats)){
	bp = function(comp){
		j = seq_along(comp$cj) - 1L
		x = comp$x - 1L
		keep = j != x
		(comp$cj[x + 1L] - comp$cj[keep]) / (j[keep] - x)
	}
	out = numeric(0)
	if (!is.null(comps$M)) out = c(out, bp(comps$M))
	if (!is.null(comps$R)) out = c(out, bp(comps$R))
	# The values are distinct after unique(), so the quicksort gives sort()'s result.
	sort.int(unique(out[is.finite(out)]), method = "quick")
}

# One endpoint of the convex hull of the exact confidence set (v1.0.6-TODO-233).
# The combined exact p-value is not monotone in delta: each component jumps at its
# breakpoints, so the set of accepted log odds ratios can have gaps. Following the
# usual convention for inverting such tests (Blaker 2000; Fay 2010), the interval
# reported is the smallest one containing every accepted delta. The bisection from
# `inside` (unchanged from before) gives a first endpoint `r`; then the stretch
# from `r` out to just past the outermost breakpoint is scanned (the breakpoints
# themselves plus an even grid), since beyond it nothing more is accepted. If the
# scan finds an accepted point the endpoint moves out to the farthest one, refined
# by bisection against the next scan point. So where the accepted set has no gap
# the endpoint is the old one. Last, an endpoint that sits on a jump is moved onto
# the breakpoint itself: there the tie is counted and the test accepts, so the
# closed endpoint is the breakpoint (at p0 = 0.5 the binomial's tie with its mirror
# outcome put endpoints at about -1e-7 where the test accepts delta = 0).
zhang_ci_hull_endpoint = function(p_fn, inside, outside, pval_th, tol, breakpoints, p_vec = NULL, n_grid = 200L, p_bound = NULL){
	p_at = function(delta){
		p = tryCatch(p_fn(delta), error = function(e) NA_real_)
		if (is.na(p) || !is.finite(p)) 0 else p
	}
	direction = sign(outside - inside)
	if (!is.finite(direction) || direction == 0) direction = 1
	width_tol = zhang_ci_width_tol(tol)
	r = zhang_bisect_ci_boundary(p_fn, inside = inside, outside = outside, pval_th = pval_th, tol = tol)
	if (!is.finite(r)) return(r)
	beyond = breakpoints[direction * (breakpoints - r) > 0]
	if (length(beyond) > 0L) {
		# Just past the outermost breakpoint (and its tolerance window) the
		# p-value only falls further out.
		t_far = beyond[which.max(direction * beyond)] + direction * 1e-6
		# p_bound is an upper bound on the p-value, so where it is below pval_th
		# t_far is rejected without the scalar evaluation (v1.0.6-TODO-285).
		b_far = if (is.null(p_bound)) NULL else p_bound(t_far, direction)
		if ((is.null(b_far) || b_far >= pval_th) && p_at(t_far) >= pval_th) {
			return(zhang_snap_endpoint(p_at,
				zhang_bisect_ci_boundary(p_fn, inside = t_far, outside = t_far + direction, pval_th = pval_th, tol = tol),
				direction, pval_th, breakpoints, p_vec = p_vec))
		}
		# The scan need not reach t_far: past t_cut an upper bound on the p-value
		# (zhang_pval_exact_tail_bound()) is already below pval_th, and that bound only
		# falls further out, so nothing there is accepted. Typically t_cut is a few
		# standard errors past r, while the outermost breakpoint can be much farther
		# (an 8.6x slower nightly benchmark row at n = 1000 without the cut). The points
		# kept are the full scan's own points up to t_cut, plus t_cut, so the scan finds
		# the same farthest accepted point and the endpoint does not change.
		scan = c(beyond, zhang_seq_length_out(r, t_far, n_grid + 1L)[-1L])
		if (!is.null(p_bound)) {
			t_cut = zhang_hull_scan_cut(p_bound, r, t_far, direction, pval_th, b_far = b_far)
			scan = c(scan[direction * (scan - t_cut) < 0], t_cut)
		}
		p_scan = if (is.null(p_vec)) vapply(scan, p_at, numeric(1)) else p_vec(scan)
		acc = p_scan >= pval_th
		if (any(acc)) {
			# The farthest accepted scan point and the next scan point out from it (the
			# scan in outward order, without sorting it: v1.0.6-TODO-285). The last scan
			# point (t_far, or t_cut whose bound rejects) is rejected, so normally there is
			# a next point; if rounding says otherwise, bracket with t_far.
			out_pos = direction * scan
			a_pos = max(out_pos[acc])
			further = out_pos > a_pos
			r = zhang_bisect_bracket(p_at, direction * a_pos,
				if (any(further)) direction * min(out_pos[further]) else t_far, pval_th, width_tol)
		}
	}
	zhang_snap_endpoint(p_at, r, direction, pval_th, breakpoints, p_vec = p_vec)
}

# seq(from, to, length.out = n) without seq.default()'s overhead: its own
# arithmetic for non-integer-valued from != to (the hull scan's case), else seq().
zhang_seq_length_out = function(from, to, n){
	if (n > 2L && is.finite(from) && is.finite(to) && from != to && from != floor(from) && to != floor(to)) {
		c(from, from + seq_len(n - 2L) * ((to - from) / (n - 1L)), to)
	} else {
		seq(from, to, length.out = n)
	}
}

# The combined exact p-value at many deltas at once, for the hull scan of
# zhang_ci_hull_endpoint(): the same minimum-likelihood sums as
# zhang_exact_binom_pval_cpp() / zhang_exact_fisher_pval_cpp() (including their
# 1e-7 relative tie tolerance), per component from zhang_minlike_pval_vec_cpp()
# (O(K) per delta; it replaced an outcomes x deltas matrix in R, v1.0.6-TODO-285,
# with bit-identical values). It only decides which scan points are accepted;
# every endpoint is still refined with the scalar kernels. A non-finite value
# counts as 0 (rejected), as in p_at().
zhang_pval_exact_combined_vec = function(exact_stats, deltas, combination_method, comps = zhang_exact_pval_components(exact_stats)){
	nd = length(deltas)
	p_M = if (!is.null(comps$M)) zhang_minlike_pval_vec_cpp(comps$M$cj, comps$M$x, deltas) else rep(NA_real_, nd)
	p_R = if (!is.null(comps$R)) zhang_minlike_pval_vec_cpp(comps$R$cj, comps$R$x, deltas) else rep(NA_real_, nd)
	p = zhang_combine_exact_pvals_vec(p_M, p_R, exact_stats$m, exact_stats$nRT, exact_stats$nRC, combination_method)
	p[!is.finite(p)] = 0
	attr(p, "rel_err") = zhang_pval_exact_vec_rel_err(exact_stats, comps, deltas, p_M, p_R)
	p
}

# A bound on |p_vec - p_scalar| / p at each delta, where p_vec is
# zhang_pval_exact_combined_vec() and p_scalar the scalar kernels combined (p_fn()),
# for zhang_accepts_certified(). Both sum the same outcome probabilities. The
# reservoir and vector kernels build log weights from log-gamma values, accurate to a
# few ulps of values up to about N log N (N the number of subjects), so each
# probability is off by a relative 64 u N log(N + 2) at most (u = machine epsilon),
# plus 1e-10 for the sums' rounding. The scalar binomial kernel works with
# p0 = plogis(delta) and 1 - p0 rounded to doubles, which moves each probability by
# up to k u (1/p0 + 1/(1 - p0)), i.e. k u (2 + 2 cosh(delta)); 8x that is used. The
# combination methods change a relative error by a small factor near the threshold
# (at most 1 for Fisher); 100 is used. Observed differences are below 2e-10 even at
# k = 3000 and |delta| = 8, against a margin of at least 1e-6. Where a component is
# near underflow (below 1e-280) the combination's fallback to the other component
# makes the two discontinuous, so the bound is Inf there and p_at() decides.
zhang_pval_exact_vec_rel_err = function(exact_stats, comps, deltas, p_M, p_R){
	u = .Machine$double.eps
	N = 2 * exact_stats$m + exact_stats$nRT + exact_stats$nRC
	err = rep(1e-10 + 64 * u * N * log(N + 2), length(deltas))
	if (!is.null(comps$M)) {
		k = length(comps$M$cj) - 1L
		err = err + 8 * k * u * (2 + 2 * cosh(deltas))
	}
	err = 100 * err
	tiny = (!is.null(comps$M) & !(p_M >= 1e-280)) | (!is.null(comps$R) & !(p_R >= 1e-280))
	err[tiny | !is.finite(err)] = Inf
	err
}

# The two exact components as outcome distributions in delta: unnormalised log
# weights cj + (j - 1) * delta over outcomes j = 1..K (the matched-pair binomial
# over d_plus, the reservoir's noncentral hypergeometric over n11; a constant shift
# of the outcome index cancels on normalising) and the observed outcome's index x.
# NULL for a component that is absent, as in zhang_pval_exact_combined_vec().
zhang_exact_pval_components = function(exact_stats){
	out = list(M = NULL, R = NULL)
	k = exact_stats$d_plus + exact_stats$d_minus
	if (exact_stats$m > 0L && k > 0L) {
		out$M = list(cj = lchoose(k, 0:k), x = exact_stats$d_plus + 1L)
	}
	if (exact_stats$nRT > 0L && exact_stats$nRC > 0L &&
		exact_stats$n11 + exact_stats$n01 > 0L && exact_stats$n10 + exact_stats$n00 > 0L) {
		row1 = exact_stats$n11 + exact_stats$n01
		row2 = exact_stats$n10 + exact_stats$n00
		col1 = exact_stats$n11 + exact_stats$n10
		xs = max(0L, col1 - row2):min(row1, col1)
		out$R = list(cj = lchoose(row1, xs) + lchoose(row2, col1 - xs), x = exact_stats$n11 - xs[1L] + 1L)
	}
	out
}

# An upper bound on the combined exact p-value at delta, valid going outward in
# `direction` (+1 right, -1 left) and nonincreasing that way. Each component's
# weights are log-concave in the outcome (binomial and hypergeometric
# coefficients are), so once the mode at delta is on the far side of x (mode >= x
# going right) every outcome on x's own side is less likely than x and counted,
# and each of the other K - x outcomes counted is at most P(x) (1 + 1e-7) <= the
# tail P(J <= x); the minimum-likelihood p-value is then at most
# P(J <= x) (1 + (K - x) (1 + 1e-7)). Before that the bound is 1. The mode only
# moves outward with delta and the tail only shrinks (monotone likelihood ratio),
# so the bound is nonincreasing. The combination methods are increasing in each
# component; the max with the single components covers the fallback of
# zhang_combine_exact_pvals() to the other component when one underflows to 0.
# In C++ (zhang_pval_exact_tail_bound_cpp(), v1.0.6-TODO-285), with the same
# arithmetic as the R version it replaced (zhang_combine_exact_pvals() of the two
# component bounds, then the max with each).
zhang_pval_exact_tail_bound = function(comps, delta, direction, exact_stats, combination_method){
	a = zhang_tail_bound_cpp_args(comps)
	zhang_pval_exact_tail_bound_cpp(a$cjM, a$xM, a$cjR, a$xR, delta, direction, zhang_combination_method_code(combination_method))
}

# Components as the C++ bound kernels take them: an absent one as an empty cj.
zhang_tail_bound_cpp_args = function(comps){
	list(cjM = if (is.null(comps$M)) numeric(0) else comps$M$cj, xM = if (is.null(comps$M)) 0L else comps$M$x,
		cjR = if (is.null(comps$R)) numeric(0) else comps$R$cj, xR = if (is.null(comps$R)) 0L else comps$R$x)
}

zhang_combination_method_code = function(combination_method){
	code = match(combination_method, c("Fisher", "Stouffer", "min_p")) - 1L
	if (is.na(code)) stop("unknown combination method: ", combination_method)
	code
}

# Where the hull scan can stop: a point t_cut between r and t_far (r excluded)
# whose p_bound is below pval_th, found by bisection on the nonincreasing bound;
# t_far itself when the bound there still reaches pval_th. `b_far`, if given, is
# p_bound(t_far, direction), already computed by the caller. A p_bound from
# zhang_pval_exact_tail_bound_fn() carries a "scan_cut" attribute that does the
# same bisection in one C++ call (v1.0.6-TODO-285).
zhang_hull_scan_cut = function(p_bound, r, t_far, direction, pval_th, n_iter = 12L, b_far = NULL){
	scan_cut = attr(p_bound, "scan_cut")
	if (!is.null(scan_cut)) return(scan_cut(r, t_far, direction, pval_th, n_iter, b_far))
	if (is.null(b_far)) b_far = p_bound(t_far, direction)
	if (b_far >= pval_th) return(t_far)
	lo = r
	hi = t_far
	for (iter in seq_len(n_iter)){
		mid = (lo + hi) / 2
		if (p_bound(mid, direction) >= pval_th) lo = mid else hi = mid
	}
	hi
}

# p_bound(delta, direction) for zhang_ci_hull_endpoint(), over this table's
# components, with its C++ scan cut (zhang_hull_scan_cut_cpp()) attached.
zhang_pval_exact_tail_bound_fn = function(exact_stats, combination_method, comps = zhang_exact_pval_components(exact_stats)){
	a = zhang_tail_bound_cpp_args(comps)
	code = zhang_combination_method_code(combination_method)
	f = function(delta, direction) zhang_pval_exact_tail_bound_cpp(a$cjM, a$xM, a$cjR, a$xR, delta, direction, code)
	attr(f, "scan_cut") = function(r, t_far, direction, pval_th, n_iter, b_far)
		zhang_hull_scan_cut_cpp(a$cjM, a$xM, a$cjR, a$xR, r, t_far, direction, pval_th, code, n_iter,
			if (is.null(b_far)) NA_real_ else b_far)
	f
}

# An endpoint within 1e-6 of a breakpoint the test accepts, with the test rejecting
# just past that breakpoint, lies on the jump there: return the breakpoint itself.
# The decisions p_at(.) >= pval_th come from zhang_accepts_certified(), which only
# calls p_at() where the vectorised p-value cannot settle them (v1.0.6-TODO-285).
zhang_snap_endpoint = function(p_at, r, direction, pval_th, breakpoints, eps = 1e-6, p_vec = NULL){
	if (!is.finite(r) || length(breakpoints) == 0L) return(r)
	near = breakpoints[abs(breakpoints - r) <= eps]
	if (length(near) == 0L) return(r)
	nn = length(near)
	if (nn > 1L) near = near[order(-direction * near)]
	acc = zhang_accepts_certified(p_at, p_vec, c(near, near + direction * eps), pval_th)
	for (i in seq_len(nn)){
		if (acc[i] && !acc[nn + i]) return(near[i])
	}
	r
}

# p_at(d) >= pval_th at each d, without calling p_at() where the vectorised p-value
# settles it. p_vec(d) carries a "rel_err" attribute bounding its relative
# difference from p_at() (zhang_pval_exact_vec_rel_err()); where |p_vec - pval_th|
# exceeds that, with a floor of 1e-6, times pval_th, both are on the same side, so
# the decision is p_vec's; elsewhere p_at() decides. With p_vec NULL, p_at() decides
# everywhere.
zhang_accepts_certified = function(p_at, p_vec, d, pval_th){
	if (is.null(p_vec)) return(vapply(d, function(z) p_at(z) >= pval_th, logical(1)))
	pv = p_vec(d)
	rel_err = attr(pv, "rel_err")
	if (is.null(rel_err)) rel_err = Inf
	unsure = !(abs(pv - pval_th) > pmax(1e-6, rel_err) * pval_th)
	out = pv >= pval_th
	for (i in which(unsure)) out[i] = p_at(d[i]) >= pval_th
	out
}

# Haldane-Anscombe log odds ratio of a 2x2 table (n11, n10, n01, n00). Applied to the
# pooled table it is the point estimate; applied to zhang_get_exact_stats() (the
# reservoir table under matching) it is the reservoir component's estimate used to
# seed the CI search.
zhang_incid_treatment_estimate = function(stats){
	n11 = stats$n11
	n10 = stats$n10
	n01 = stats$n01
	n00 = stats$n00
	# Sample Odds Ratio (with continuity correction)
	log((n11 + 0.5) * (n00 + 0.5) / ((n10 + 0.5) * (n01 + 0.5)))
}

# The pooled 2x2 table over all subjects (matched and reservoir together): each
# subject counted once by its own treatment and outcome. This is the table the
# point estimate uses (v1.0.6-TODO-147). The exact test and its CI search instead
# use zhang_get_exact_stats(), whose n11..n00 are the reservoir only when there is a
# match structure: the matched pairs enter the exact test through the discordant
# pairs, so a pooled table there would count them twice. Not cached: it is O(n) and
# always reflects the current y and w (bootstrap / randomization draws included).
zhang_get_pooled_table = function(inf_obj){
	private = inf_obj$.__enclos_env__$private
	y = private$y
	w = private$w
	ok = !is.na(y) & !is.na(w)
	y = y[ok]
	w = w[ok]
	nT = sum(w == 1L)
	nC = sum(w == 0L)
	n11 = sum(y[w == 1L])
	n01 = sum(y[w == 0L])
	list(n11 = n11, n10 = nT - n11, n01 = n01, n00 = nC - n01)
}

# Computes the MLE-based CI used for bisection search bounds
zhang_incid_mle_ci = function(stats, alpha){
	n11 = stats$n11
	n10 = stats$n10
	n01 = stats$n01
	n00 = stats$n00
	est = log((n11 + 0.5) * (n00 + 0.5) / ((n10 + 0.5) * (n01 + 0.5)))
	se  = sqrt(1/(n11+0.5) + 1/(n10+0.5) + 1/(n01+0.5) + 1/(n00+0.5))
	z = stats::qnorm(1 - alpha/2)
	c(est - z * se, est + z * se)
}

zhang_normalize_exact_inference_args = function(type, args_for_type = NULL, pval_epsilon = NULL){
	if (should_run_asserts()) {
		assertChoice(type, c("Zhang"))
		assertList(args_for_type, null.ok = TRUE)
	}
	default_args = list(combination_method = "Fisher")
	if (!is.null(pval_epsilon)) default_args$pval_epsilon = pval_epsilon
	utils::modifyList(setNames(list(default_args), type), if (is.null(args_for_type)) list() else args_for_type)
}

zhang_assert_exact_inference_params = function(inf_obj, type, args_for_type){
	private = inf_obj$.__enclos_env__$private
	if (should_run_asserts()) {
		assertChoice(type, c("Zhang"))
		assertList(args_for_type)
		if (!(type %in% names(args_for_type))) stop("args_for_type must contain a list for ", type)
	}
	args = args_for_type[[type]]
	if (should_run_asserts()) {
		assertList(args)
	}
	is_bernoulli = private$des_obj$is_a_bernoulli_capable()
	if (should_run_asserts()) {
		if (!is_bernoulli && !private$has_match_structure) stop("Zhang incidence inference requires Bernoulli or matching designs.")
		assertResponseType(private$des_obj$get_response_type(), "incidence")
		assertNoCensoring(private$any_censoring)
		assertChoice(args$combination_method, c("Fisher", "Stouffer", "min_p"))
		if (!is.null(args$pval_epsilon)) assertNumeric(args$pval_epsilon, len = 1, lower = .Machine$double.xmin, upper = 1, any.missing = FALSE)
	}
	invisible(args)
}

zhang_get_exact_stats = function(inf_obj){
	private = inf_obj$.__enclos_env__$private
	if (!is.null(private$cached_values$incid_exact_zhang_stats)) return(private$cached_values$incid_exact_zhang_stats)
	if (private$has_match_structure){
		if (is.null(private$cached_values$KKstats)){
			private$m = private$des_obj_priv_int$m
			m_vec = if (is.null(private$m)) rep(0, private$n) else private$m
			m_vec[is.na(m_vec)] = 0
			private$cached_values$KKstats = compute_zhang_match_data_cpp(private$get_X(), private$y, private$w, m_vec)
		}
		KKstats = private$cached_values$KKstats
		exact_stats = list(
			m = as.integer(KKstats$m),
			nRT = as.integer(KKstats$nRT),
			nRC = as.integer(KKstats$nRC),
			d_plus = as.integer(KKstats$d_plus),
			d_minus = as.integer(KKstats$d_minus),
			n11 = as.integer(KKstats$n11),
			n10 = as.integer(KKstats$n10),
			n01 = as.integer(KKstats$n01),
			n00 = as.integer(KKstats$n00)
		)
	} else {
		nRT = sum(private$w == 1L, na.rm = TRUE)
		nRC = sum(private$w == 0L, na.rm = TRUE)
		n11 = sum(private$y[private$w == 1L])
		n01 = sum(private$y[private$w == 0L])
		exact_stats = list(
			m = 0L,
			nRT = as.integer(nRT),
			nRC = as.integer(nRC),
			d_plus = 0L,
			d_minus = 0L,
			n11 = as.integer(n11),
			n10 = as.integer(nRT - n11),
			n01 = as.integer(n01),
			n00 = as.integer(nRC - n01)
		)
	}
	private$cached_values$incid_exact_zhang_stats = exact_stats
	exact_stats
}

zhang_compute_exact_pval_matched_pairs = function(inf_obj, delta_0) {
	private = inf_obj$.__enclos_env__$private
	if (!private$has_match_structure) return(NA_real_)
	exact_stats = zhang_get_exact_stats(inf_obj)
	if (exact_stats$m == 0L || exact_stats$d_plus + exact_stats$d_minus == 0L) return(NA_real_)
	zhang_exact_binom_pval_cpp(exact_stats$d_plus, exact_stats$d_minus, delta_0)
}

zhang_compute_exact_pval_reservoir = function(inf_obj, delta_0){
	exact_stats = zhang_get_exact_stats(inf_obj)
	if (exact_stats$nRT == 0L || exact_stats$nRC == 0L) return(NA_real_)
	if (exact_stats$n11 + exact_stats$n01 == 0L || exact_stats$n10 + exact_stats$n00 == 0L) return(NA_real_)
	zhang_exact_fisher_pval_cpp(exact_stats$n11, exact_stats$n10, exact_stats$n01, exact_stats$n00, delta_0)
}

zhang_pval_exact_combined = function(inf_obj, delta_0, combination_method = "Fisher"){
	exact_stats = zhang_get_exact_stats(inf_obj)
	p_M = if (exact_stats$m > 0) zhang_compute_exact_pval_matched_pairs(inf_obj, delta_0) else NA_real_
	p_R = if (exact_stats$nRT > 0 && exact_stats$nRC > 0) zhang_compute_exact_pval_reservoir(inf_obj, delta_0) else NA_real_
	zhang_combine_exact_pvals(p_M, p_R, exact_stats$m, exact_stats$nRT, exact_stats$nRC, combination_method)
}

zhang_compute_ci_bounds_parallel = function(inf_obj, inside, lo_bound, hi_bound, alpha, pval_epsilon, combination_method){
	private = inf_obj$.__enclos_env__$private
	bound_specs = list(list(inside = inside, outside = lo_bound), list(inside = inside, outside = hi_bound))
	n_cores_ci = min(2L, inf_obj$num_cores)
	child_budget = max(1L, as.integer(floor(inf_obj$num_cores / n_cores_ci)))
	inf_template = inf_obj$duplicate()
	results = private$par_lapply(bound_specs, function(spec){
		worker_inf = inf_template$duplicate(make_fork_cluster = FALSE)
		exact_stats = zhang_get_exact_stats(worker_inf)
		p_fn = function(delta_0){
			p_M = if (exact_stats$m > 0) zhang_compute_exact_pval_matched_pairs(worker_inf, delta_0) else NA_real_
			p_R = if (exact_stats$nRT > 0 && exact_stats$nRC > 0) zhang_compute_exact_pval_reservoir(worker_inf, delta_0) else NA_real_
			zhang_combine_exact_pvals(p_M, p_R, exact_stats$m, exact_stats$nRT, exact_stats$nRC, combination_method)
		}
		comps = zhang_exact_pval_components(exact_stats)
		zhang_ci_hull_endpoint(p_fn, inside = spec$inside, outside = spec$outside, pval_th = alpha, tol = pval_epsilon,
			breakpoints = zhang_exact_pval_breakpoints(exact_stats, comps),
			p_vec = function(d) zhang_pval_exact_combined_vec(exact_stats, d, combination_method, comps),
			p_bound = zhang_pval_exact_tail_bound_fn(exact_stats, combination_method, comps))
	}, n_cores = n_cores_ci, budget = child_budget,
	export_list = list(
		inf_template = inf_template,
		combination_method = combination_method,
		alpha = alpha,
		pval_epsilon = pval_epsilon
	))
	c(results[[1]], results[[2]])
}

# A point the combined test accepts (p > alpha), to start both endpoint searches from.
# The reservoir log odds ratio alone is not one: with no reservoir (every subject
# matched, e.g. DesignFixedBinaryMatch) it is always 0, so the interval always held 0
# even when the test rejected; with a small reservoir (KK designs at large n) it is
# noise the matched pairs outweigh, and a start the test rejects sent the bisection to
# a wrong endpoint (calibration campaign 2026-11-15-e36c7710: coverage 0.85-0.88 at
# KK21 n = 1000, 1.00 on BinaryMatch, while the test's size was 0.02-0.05).
# Candidates: the reservoir estimate, the matched-pairs conditional MLE and their
# inverse-variance combination; if none is accepted, the maximiser of the combined
# p-value over the search range; if that is rejected too, a dense grid search with
# local refinement (zhang_ci_inside_point_grid()). If no accepted point is found the
# confidence set is empty and NA_real_ is returned, with the largest combined p-value
# found as attribute "max_pval" (v1.0.6-TODO-216: before, the rejected maximiser was
# returned and both bisections collapsed onto it, giving a "CI" of width ~1e-6).
zhang_ci_inside_point = function(p_fn, exact_stats, lo_bound, hi_bound, alpha){
	p_at = function(delta){
		p = tryCatch(p_fn(delta), error = function(e) NA_real_)
		if (is.na(p) || !is.finite(p)) 0 else p
	}
	est_R = zhang_incid_treatment_estimate(exact_stats)
	var_R = 1/(exact_stats$n11 + 0.5) + 1/(exact_stats$n10 + 0.5) + 1/(exact_stats$n01 + 0.5) + 1/(exact_stats$n00 + 0.5)
	has_R = exact_stats$nRT > 0L && exact_stats$nRC > 0L
	k = exact_stats$d_plus + exact_stats$d_minus
	cands = if (has_R) est_R else numeric(0)
	if (exact_stats$m > 0L && k > 0L) {
		est_M = log((exact_stats$d_plus + 0.5) / (exact_stats$d_minus + 0.5))
		var_M = 1/(exact_stats$d_plus + 0.5) + 1/(exact_stats$d_minus + 0.5)
		cands = c(cands, est_M)
		if (has_R) cands = c(cands, (est_R / var_R + est_M / var_M) / (1 / var_R + 1 / var_M))
	}
	if (length(cands) == 0L) cands = est_R
	p_c = vapply(cands, p_at, numeric(1))
	if (max(p_c) > alpha) return(cands[which.max(p_c)])
	rng = range(c(lo_bound, hi_bound, cands))
	opt = stats::optimize(function(d) -p_at(d), interval = rng)
	if (-opt$objective > alpha) return(opt$minimum)
	zhang_ci_inside_point_grid(p_at, c(rng, opt$minimum), alpha, max(-opt$objective, p_c))
}

# Last-resort search for a point the combined test accepts, used only when the
# candidates and optimize() over the search range are all rejected. The combined
# p-value is a product of two discrete, non-smooth exact p-values whose modes sit
# near the reservoir and matched-pair estimates, so optimize() can stop at a local
# maximum; scan a dense grid one unit beyond the search range, then refine around
# the best grid points. Returns an accepted point, or NA_real_ (attribute
# "max_pval": the largest p-value seen) when the acceptance set is empty.
zhang_ci_inside_point_grid = function(p_at, pts, alpha, p_best, n_grid = 2001L, n_refine = 5L){
	rng = range(pts) + c(-1, 1)
	grid = seq(rng[1L], rng[2L], length.out = n_grid)
	p_grid = vapply(grid, p_at, numeric(1))
	i_max = which.max(p_grid)
	if (p_grid[i_max] > alpha) return(grid[i_max])
	p_best = max(p_best, p_grid[i_max])
	step = grid[2L] - grid[1L]
	for (i in utils::head(order(p_grid, decreasing = TRUE), n_refine)){
		opt = stats::optimize(function(d) -p_at(d), interval = grid[i] + c(-1, 1) * step)
		if (-opt$objective > alpha) return(opt$minimum)
		p_best = max(p_best, -opt$objective)
	}
	structure(NA_real_, max_pval = p_best)
}

zhang_ci_exact_combined = function(inf_obj, alpha, pval_epsilon, combination_method = "Fisher"){
	exact_stats = zhang_get_exact_stats(inf_obj)
	# The search works on the exact test's own tables, not the pooled table the point
	# estimate uses (v1.0.6-TODO-147): `exact_stats` holds the reservoir table under
	# matching. zhang_ci_inside_point() combines the reservoir and matched-pair
	# estimates by inverse variance, which needs the two to be disjoint (a pooled table
	# would count the pairs twice), and the Wald bracket below is only a starting scale
	# that zhang_bisect_ci_boundary() expands as needed. This also keeps the interval,
	# the inversion of the unchanged exact test, identical to before.
	est = zhang_incid_treatment_estimate(exact_stats)
	if (should_run_asserts()) {
		if (!is.finite(est)) stop("Cannot compute exact CI: point estimate is not finite.")
	}
	mle_ci = zhang_incid_mle_ci(exact_stats, alpha * 2)
	ci_width = mle_ci[2] - mle_ci[1]
	lo_bound = mle_ci[1] - 0.5 * ci_width
	hi_bound = mle_ci[2] + 0.5 * ci_width
	p_fn = function(delta_0){
		p_M = if (exact_stats$m > 0) zhang_compute_exact_pval_matched_pairs(inf_obj, delta_0) else NA_real_
		p_R = if (exact_stats$nRT > 0 && exact_stats$nRC > 0) zhang_compute_exact_pval_reservoir(inf_obj, delta_0) else NA_real_
		zhang_combine_exact_pvals(p_M, p_R, exact_stats$m, exact_stats$nRT, exact_stats$nRC, combination_method)
	}
	inside = zhang_ci_inside_point(p_fn, exact_stats, lo_bound, hi_bound, alpha)
	procedure = "compute_exact_confidence_interval"
	if (is.na(inside)) {
		# v1.0.6-TODO-216: the combined test rejects every log odds ratio, so the
		# inverted confidence set is empty; there is no interval to report.
		private = inf_obj$.__enclos_env__$private
		reason = "exact_ci_empty_acceptance_set"
		private$cache_procedure_failure(procedure, reason)
		edi_warn_procedure_na(inf_obj, private, procedure = procedure, reason = reason, detail = paste0(
			"The combined (", combination_method, ") exact test rejects every log odds ratio at alpha = ", format(alpha),
			" (largest combined p-value found: ", format(signif(attr(inside, "max_pval"), 3)), "): the matched-pair and ",
			"reservoir components point to incompatible effects, so the inverted confidence set is empty."))
		return(c(NA_real_, NA_real_))
	}
	edi_clear_procedure_failure(inf_obj$.__enclos_env__$private, procedure)
	# The bounds are only starting scales for the bisection, but each must lie on its own side of `inside`.
	lo_bound = min(lo_bound, inside - 1)
	hi_bound = max(hi_bound, inside + 1)
	if (inf_obj$num_cores > 1L) {
		zhang_compute_ci_bounds_parallel(inf_obj, inside, lo_bound, hi_bound, alpha, pval_epsilon, combination_method)
	} else {
		comps = zhang_exact_pval_components(exact_stats)
		breakpoints = zhang_exact_pval_breakpoints(exact_stats, comps)
		p_vec = function(d) zhang_pval_exact_combined_vec(exact_stats, d, combination_method, comps)
		p_bound = zhang_pval_exact_tail_bound_fn(exact_stats, combination_method, comps)
		c(
			zhang_ci_hull_endpoint(p_fn, inside = inside, outside = lo_bound, pval_th = alpha, tol = pval_epsilon, breakpoints = breakpoints, p_vec = p_vec, p_bound = p_bound),
			zhang_ci_hull_endpoint(p_fn, inside = inside, outside = hi_bound, pval_th = alpha, tol = pval_epsilon, breakpoints = breakpoints, p_vec = p_vec, p_bound = p_bound)
		)
	}
}
