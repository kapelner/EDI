// Simulated-annealing single-allocation optimizer for DesignFixedOptimal
// (design_fixed_optimal.md TODO-6) — a dedicated formal method, deliberately
// NOT the greedy engine: greedy accepts only improving swaps and halts at the
// first local optimum (its job is a *distribution* of local optima for
// randomization inference); this kernel's job is ONE allocation with a
// defensible claim toward global optimality (Hajek 1988: SA on a finite state
// space converges in probability to the global optimum under a slow-enough
// schedule; the geometric schedule used here is the standard practical
// relaxation, hence certificate "annealing_converged", never "global").
//
// Neighborhood: single treated/control pairwise exchange (same *structure* as
// the greedy engine, not the same engine or acceptance rule). Acceptance:
// Metropolis — improving moves always; a move worsening by delta with
// probability exp(-delta / T), T_{k+1} = cooling_rate * T_k from initial_temp.
// n_chains independent BCRD-started chains; each chain tracks its best
// *visited* state (dominates the terminal state under any schedule) and the
// cross-chain argmin is returned.
//
// Objectives (selected by objective_kind; incremental O(1)/O(p) move
// evaluation, O(n)/O(p) state update on acceptance):
//   "quadratic": f = w'Qw            M1 = Q (n x n), M2 unused
//   "l1"       : f = sum_j |(A w)_j| M1 = A (p x n), M2 unused
//   "ratio"    : f = (w'Hw + 1)/(n_T - w'Pw)   M1 = P, M2 = H (both n x n);
//                moves with denominator <= 0 are rejected as infeasible
//
// Reproducibility: one edi_rng::RRng seed per CHAIN, drawn from R's RNG
// before the parallel region — results are identical for a given set.seed()
// regardless of the OpenMP thread count (unlike per-thread seeding).
// Chain bests are recomputed from scratch before the cross-chain compare so
// incremental-update drift can never select the wrong winner.

#include <RcppEigen.h>
#include "RNG.h"
#include "user_compiled_fns.h"
#ifdef _OPENMP
#include <omp.h>
#endif
// [[Rcpp::depends(RcppEigen)]]

#include <vector>
#include <numeric>
#include <algorithm>
#include <cmath>
#include <string>
#include <random>
#include <limits>

using Eigen::MatrixXd;
using Eigen::VectorXd;

namespace {

enum class ObjKind { quadratic, l1, ratio, custom };

// Per-chain incremental state for one candidate/current allocation.
struct AnnealState {
	std::vector<int> w;        // 0/1, length n
	std::vector<int> treated;  // indices with w = 1 (size n_T)
	std::vector<int> control;  // indices with w = 0 (size n - n_T)
	// quadratic / ratio caches
	VectorXd gQ;               // Q*w   (quadratic)  |  P*w (ratio)
	VectorXd gH;               // H*w   (ratio only)
	double quad_P = 0.0;       // w'Qw  (quadratic)  |  w'Pw (ratio)
	double quad_H = 0.0;       // w'Hw  (ratio only)
	// l1 cache
	VectorXd v;                // A*w
	// custom cache: the allocation as a double vector, kept in sync with w so
	// candidate evaluation is flip -> call -> (restore on reject); the user
	// objective is a black box with no incremental structure to exploit.
	VectorXd wd;
};

double state_objective(const ObjKind kind, const AnnealState& st, const int n_T,
		const MatrixXd& M1, const edi_design_objective_fn custom_fn){
	switch (kind) {
		case ObjKind::quadratic: return st.quad_P;
		case ObjKind::l1:        return st.v.cwiseAbs().sum();
		case ObjKind::ratio:     return (st.quad_H + 1.0) / (static_cast<double>(n_T) - st.quad_P);
		case ObjKind::custom:    return custom_fn(M1, st.wd);
	}
	return std::numeric_limits<double>::quiet_NaN();
}

// From-scratch exact evaluation of an allocation (drift-proof).
double exact_objective(const ObjKind kind, const std::vector<int>& w,
		const MatrixXd& M1, const MatrixXd& M2, const int n_T,
		const edi_design_objective_fn custom_fn){
	const int n = (kind == ObjKind::custom) ? static_cast<int>(M1.rows()) : static_cast<int>(M1.cols());
	VectorXd wd(n);
	for (int i = 0; i < n; i++) wd[i] = static_cast<double>(w[static_cast<std::size_t>(i)]);
	switch (kind) {
		case ObjKind::quadratic: return wd.dot(M1 * wd);
		case ObjKind::l1:        return (M1 * wd).cwiseAbs().sum();
		case ObjKind::ratio:     return (wd.dot(M2 * wd) + 1.0) / (static_cast<double>(n_T) - wd.dot(M1 * wd));
		case ObjKind::custom:    return custom_fn(M1, wd);
	}
	return std::numeric_limits<double>::quiet_NaN();
}

void init_state(AnnealState& st, const ObjKind kind, const MatrixXd& M1, const MatrixXd& M2,
		const int n, const int n_T, edi_rng::RRng& rng){
	// BCRD start: Fisher-Yates shuffle, first n_T treated.
	std::vector<int> idx(static_cast<std::size_t>(n));
	std::iota(idx.begin(), idx.end(), 0);
	for (int i = n - 1; i > 0; i--)
		std::swap(idx[static_cast<std::size_t>(i)],
		          idx[static_cast<std::size_t>(std::uniform_int_distribution<int>(0, i)(rng))]);
	st.w.assign(static_cast<std::size_t>(n), 0);
	st.treated.assign(idx.begin(), idx.begin() + n_T);
	st.control.assign(idx.begin() + n_T, idx.end());
	for (int i = 0; i < n_T; i++) st.w[static_cast<std::size_t>(st.treated[static_cast<std::size_t>(i)])] = 1;

	VectorXd wd(n);
	for (int i = 0; i < n; i++) wd[i] = static_cast<double>(st.w[static_cast<std::size_t>(i)]);
	if (kind == ObjKind::custom) {
		st.wd = wd;
	} else if (kind == ObjKind::l1) {
		st.v = M1 * wd;
	} else {
		st.gQ = M1 * wd;
		st.quad_P = wd.dot(st.gQ);
		if (kind == ObjKind::ratio) {
			st.gH = M2 * wd;
			st.quad_H = wd.dot(st.gH);
		}
	}
}

} // namespace

// [[Rcpp::export]]
Rcpp::List annealing_design_search_cpp(
	const std::string&                objective_kind,
	const Eigen::Map<Eigen::MatrixXd> M1,
	const Eigen::Map<Eigen::MatrixXd> M2,
	const int                         n_T,
	const int                         n_chains,
	const int                         max_iter,
	const double                      initial_temp,
	const double                      cooling_rate,
	SEXP                              custom_objective
) {
	const ObjKind kind =
		objective_kind == "quadratic" ? ObjKind::quadratic :
		objective_kind == "l1"        ? ObjKind::l1 :
		objective_kind == "ratio"     ? ObjKind::ratio :
		objective_kind == "custom"    ? ObjKind::custom :
		throw std::invalid_argument("objective_kind must be 'quadratic', 'l1', 'ratio', or 'custom'");
	// custom: M1 is the n x p model matrix X; all other kinds carry an
	// (anything) x n matrix, so n sits in .cols().
	const int n  = (kind == ObjKind::custom) ? static_cast<int>(M1.rows()) : static_cast<int>(M1.cols());
	const int nc = n - n_T;
	edi_design_objective_fn custom_fn = nullptr;
	if (kind == ObjKind::custom) {
		if (custom_objective == R_NilValue) throw std::invalid_argument("objective_kind 'custom' requires a custom_objective XPtr");
		custom_fn = *Rcpp::XPtr<edi_design_objective_fn>(custom_objective);
	}
	// User compiled code carries no thread-safety guarantee (it may touch the
	// R API despite the Eigen-only signature), so custom chains run serially.
	const bool parallel_ok = (kind != ObjKind::custom);

	// One seed per chain (not per thread): reproducible under any thread count.
	std::vector<uint32_t> seeds(static_cast<std::size_t>(n_chains));
	GetRNGstate();
	for (int c = 0; c < n_chains; c++)
		seeds[static_cast<std::size_t>(c)] = edi_rng::seed_from_unif01(::unif_rand());
	PutRNGstate();

	std::vector<std::vector<int>> best_w(static_cast<std::size_t>(n_chains));
	std::vector<double>           best_f(static_cast<std::size_t>(n_chains),
	                                     std::numeric_limits<double>::infinity());

#pragma omp parallel for schedule(static) if(parallel_ok)
	for (int c = 0; c < n_chains; c++) {
		edi_rng::RRng rng(seeds[static_cast<std::size_t>(c)]);
		std::uniform_int_distribution<int>     pick_t(0, n_T - 1);
		std::uniform_int_distribution<int>     pick_c(0, nc - 1);
		std::uniform_real_distribution<double> unif01(0.0, 1.0);

		AnnealState st;
		init_state(st, kind, M1, M2, n, n_T, rng);
		double f_cur = state_objective(kind, st, n_T, M1, custom_fn);
		std::vector<int> chain_best_w = st.w;
		double           chain_best_f = f_cur;

		double T = initial_temp;
		VectorXd v_new;  // l1 scratch
		for (int k = 0; k < max_iter; k++) {
			const int ti = pick_t(rng), ci = pick_c(rng);
			const int a = st.treated[static_cast<std::size_t>(ti)];   // leaves treatment
			const int b = st.control[static_cast<std::size_t>(ci)];   // enters treatment
			double f_new;
			double dP = 0.0, dH = 0.0;
			bool feasible = true;
			if (kind == ObjKind::custom) {
				// Flip, evaluate, and restore below if rejected.
				st.wd[a] = 0.0; st.wd[b] = 1.0;
				f_new = custom_fn(M1, st.wd);
			} else if (kind == ObjKind::l1) {
				v_new = st.v + M1.col(b) - M1.col(a);
				f_new = v_new.cwiseAbs().sum();
			} else {
				// w' = w - e_a + e_b:  w''Qw' = w'Qw + 2(g_b - g_a) + Q_bb + Q_aa - 2Q_ab
				dP = 2.0 * (st.gQ[b] - st.gQ[a]) + M1(b, b) + M1(a, a) - 2.0 * M1(a, b);
				if (kind == ObjKind::quadratic) {
					f_new = st.quad_P + dP;
				} else {
					dH = 2.0 * (st.gH[b] - st.gH[a]) + M2(b, b) + M2(a, a) - 2.0 * M2(a, b);
					const double den = static_cast<double>(n_T) - (st.quad_P + dP);
					if (den <= 1e-12) { feasible = false; f_new = f_cur; }
					else f_new = (st.quad_H + dH + 1.0) / den;
				}
			}
			if (feasible) {
				const double delta = f_new - f_cur;
				if (delta < 0.0 || unif01(rng) < std::exp(-delta / T)) {
					// Accept: swap a <-> b and update caches (custom's wd is
					// already flipped from the evaluation above).
					st.treated[static_cast<std::size_t>(ti)] = b;
					st.control[static_cast<std::size_t>(ci)] = a;
					st.w[static_cast<std::size_t>(a)] = 0;
					st.w[static_cast<std::size_t>(b)] = 1;
					if (kind == ObjKind::l1) {
						st.v = v_new;
					} else if (kind != ObjKind::custom) {
						st.gQ += M1.col(b) - M1.col(a);
						st.quad_P += dP;
						if (kind == ObjKind::ratio) {
							st.gH += M2.col(b) - M2.col(a);
							st.quad_H += dH;
						}
					}
					f_cur = f_new;
					if (f_cur < chain_best_f) {
						chain_best_f = f_cur;
						chain_best_w = st.w;
					}
				} else if (kind == ObjKind::custom) {
					// Reject: undo the evaluation flip.
					st.wd[a] = 1.0; st.wd[b] = 0.0;
				}
			}
			T *= cooling_rate;
		}
		// Drift-proof: recompute the chain best exactly before comparing chains.
		best_f[static_cast<std::size_t>(c)] = exact_objective(kind, chain_best_w, M1, M2, n_T, custom_fn);
		best_w[static_cast<std::size_t>(c)] = chain_best_w;
	}

	int argmin = 0;
	for (int c = 1; c < n_chains; c++)
		if (best_f[static_cast<std::size_t>(c)] < best_f[static_cast<std::size_t>(argmin)]) argmin = c;

	Rcpp::IntegerVector w_out(n);
	for (int i = 0; i < n; i++) w_out[i] = best_w[static_cast<std::size_t>(argmin)][static_cast<std::size_t>(i)];
	return Rcpp::List::create(
		Rcpp::Named("w")               = w_out,
		Rcpp::Named("objective_value") = best_f[static_cast<std::size_t>(argmin)],
		Rcpp::Named("chain_values")    = Rcpp::NumericVector(best_f.begin(), best_f.end()),
		Rcpp::Named("final_temp")      = initial_temp * std::pow(cooling_rate, static_cast<double>(max_iter))
	);
}
