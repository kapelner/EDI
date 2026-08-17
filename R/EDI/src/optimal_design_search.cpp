// D-/A-optimal design search — native C++ (RcppEigen), now OpenMP-parallel
// over independent replicates and routed through the shared sorted-scan
// pruned pairwise-swap engine (greedy_pairwise_swap_engine.h,
// fix_design_hierarchy.md TODO-31), which used to be duplicated almost
// verbatim between d_optimal_search_cpp and a_optimal_search_cpp.
//
// D-optimal objective: minimize w'Pw directly (delta(i,j) is exactly
// additive: Ai + Bj - 2P[j,i]), so its pruning bound is adaptive -- provably
// safe to tighten using the round's live best-delta-so-far, not just the
// round's starting point. See DOptimalPruneObjective::prune_threshold().
//
// A-optimal objective: minimize the ratio (w'Hw + 1)/(n_T - w'Pw), which is
// NOT additive. Its pruning bound (Ci = A_H[i] + obj_curr*A_P[i], etc.) is
// only proven safe against the round's *starting* obj_curr, not against a
// live-improving best-delta -- so, unlike D, its threshold intentionally
// ignores the engine's `best_delta` parameter and stays fixed for the whole
// round. See AOptimalPruneObjective::prune_threshold() and the engine
// header's own comment for why these two are not the same rule.
//
// Both objectives are still seeded the same way greedy_design_search_cpp
// is: one RRng per OpenMP thread, seeded serially from R's own RNG state
// before the parallel region begins, so a given R seed reproduces identical
// draws independent of the thread count in use.

#include <RcppEigen.h>
#include "RNG.h"
#include "greedy_pairwise_swap_engine.h"
#include <algorithm>
#include <vector>
#include <limits>
#ifdef _OPENMP
#include <omp.h>
#endif

// [[Rcpp::depends(RcppEigen)]]

using namespace Rcpp;

namespace {

struct DOptimalPruneObjective {
	const Eigen::Map<Eigen::MatrixXd>& P;
	const double*          p_ptr;
	const Eigen::VectorXd& p_diag;
	double                  max_P;
	int                     n;
	Eigen::VectorXd         Pw;

	double outer_bound(int i) const { return -2.0 * Pw[i] + p_diag[i]; }
	double inner_bound(int j) const { return  2.0 * Pw[j] + p_diag[j]; }
	// Adaptive: provably safe to tighten with the round's live best_delta
	// (delta(i,j) is exactly additive, unlike A-optimal's ratio objective).
	double prune_threshold(double best_delta) const { return best_delta + 2.0 * max_P; }

	double delta(int i, int j) const {
		return outer_bound(i) + inner_bound(j) - 2.0 * p_ptr[static_cast<std::size_t>(j) * n + i];
	}
	void apply_swap(int i, int j) {
		Pw -= P.col(i);
		Pw += P.col(j);
	}
};

struct AOptimalPruneObjective {
	const Eigen::Map<Eigen::MatrixXd>& P;
	const Eigen::Map<Eigen::MatrixXd>& H;
	const double*          p_ptr;
	const double*          h_ptr;
	const Eigen::VectorXd& p_diag;
	const Eigen::VectorXd& h_diag;
	double                  max_P, max_H;
	int                     n, n_T;
	Eigen::VectorXd         Pw, Hw;
	double                  wPw, wHw, obj_curr;

	double outer_bound(int i) const {
		return (-2.0 * Hw[i] + h_diag[i]) + obj_curr * (-2.0 * Pw[i] + p_diag[i]);
	}
	double inner_bound(int j) const {
		return (2.0 * Hw[j] + h_diag[j]) + obj_curr * (2.0 * Pw[j] + p_diag[j]);
	}
	// Fixed for the whole round: only proven safe against this round's
	// starting obj_curr, not against a live-tightening best_delta (see file
	// banner comment) -- best_delta is deliberately unused here.
	double prune_threshold(double /*best_delta*/) const {
		return 2.0 * (max_H + obj_curr * max_P);
	}

	double delta(int i, int j) const {
		const double delta_wPw = -2.0 * Pw[i] + 2.0 * Pw[j] + p_diag[i] + p_diag[j]
			- 2.0 * p_ptr[static_cast<std::size_t>(j) * n + i];
		const double delta_wHw = -2.0 * Hw[i] + 2.0 * Hw[j] + h_diag[i] + h_diag[j]
			- 2.0 * h_ptr[static_cast<std::size_t>(j) * n + i];
		const double denom = n_T - (wPw + delta_wPw);
		if (denom <= 1e-10) return std::numeric_limits<double>::infinity();
		const double next_obj = (wHw + delta_wHw + 1.0) / denom;
		return next_obj - obj_curr;
	}
	void apply_swap(int i, int j) {
		const double delta_wPw = -2.0 * Pw[i] + 2.0 * Pw[j] + p_diag[i] + p_diag[j]
			- 2.0 * p_ptr[static_cast<std::size_t>(j) * n + i];
		const double delta_wHw = -2.0 * Hw[i] + 2.0 * Hw[j] + h_diag[i] + h_diag[j]
			- 2.0 * h_ptr[static_cast<std::size_t>(j) * n + i];
		wPw += delta_wPw;
		wHw += delta_wHw;
		obj_curr = (wHw + 1.0) / (n_T - wPw);
		Pw -= P.col(i); Pw += P.col(j);
		Hw -= H.col(i); Hw += H.col(j);
	}
};

// Shared random-balanced-init + treated/control bookkeeping: Fisher-Yates
// shuffle the index vector, first n_T become treated (w=1), rest control.
inline void random_balanced_init(
	edi_rng::RRng& rng, int n, int n_T,
	std::vector<int>& indices, Eigen::VectorXd& w,
	std::vector<int>& t_idxs, std::vector<int>& c_idxs
) {
	std::shuffle(indices.begin(), indices.end(), rng);
	w.setZero();
	t_idxs.clear();
	c_idxs.clear();
	for (int i = 0; i < n; ++i) {
		if (i < n_T) { w(indices[static_cast<std::size_t>(i)]) = 1.0; t_idxs.push_back(indices[static_cast<std::size_t>(i)]); }
		else         { c_idxs.push_back(indices[static_cast<std::size_t>(i)]); }
	}
}

} // namespace

// [[Rcpp::export]]
IntegerMatrix d_optimal_search_cpp( const Eigen::Map<Eigen::MatrixXd>& P,
		int nsim,
		int n_T) {

	const int n = static_cast<int>(P.rows());
	const double* p_ptr = P.data();
	const Eigen::VectorXd p_diag = P.diagonal();
	const double max_P = P.cwiseAbs().maxCoeff();
	IntegerMatrix w_mat(n, nsim);

	int nthreads = edi_search::omp_max_threads();
	std::vector<std::uint32_t> seeds = edi_search::seed_per_thread_rngs_from_r(nthreads);

#pragma omp parallel
	{
		const int tid = edi_search::omp_this_thread();
		edi_rng::RRng rng(seeds[static_cast<std::size_t>(tid)]);

		std::vector<int> indices(n);
		for (int i = 0; i < n; ++i) indices[static_cast<std::size_t>(i)] = i;
		Eigen::VectorXd w(n);
		std::vector<int> t_idxs, c_idxs;
		t_idxs.reserve(static_cast<std::size_t>(n_T));
		c_idxs.reserve(static_cast<std::size_t>(n - n_T));

#pragma omp for schedule(static)
		for (int s = 0; s < nsim; ++s) {
			random_balanced_init(rng, n, n_T, indices, w, t_idxs, c_idxs);

			DOptimalPruneObjective obj{P, p_ptr, p_diag, max_P, n, P * w};
			edi_search::exhaustive_best_improvement_search_pruned(obj, t_idxs, c_idxs, 1e-10);

			// w itself is never mutated by the search (only t_idxs/c_idxs and
			// obj.Pw are) -- reconstruct it from the final partition.
			for (int i = 0; i < n; ++i) w_mat(i, s) = 0;
			for (int t : t_idxs) w_mat(t, s) = 1;
		}
	}

	return w_mat;
}

// [[Rcpp::export]]
IntegerMatrix a_optimal_search_cpp( const Eigen::Map<Eigen::MatrixXd>& P,
		const Eigen::Map<Eigen::MatrixXd>& H,
		int nsim,
		int n_T) {

	const int n = static_cast<int>(P.rows());
	const double* p_ptr = P.data();
	const double* h_ptr = H.data();
	const Eigen::VectorXd p_diag = P.diagonal();
	const Eigen::VectorXd h_diag = H.diagonal();
	const double max_P = P.cwiseAbs().maxCoeff();
	const double max_H = H.cwiseAbs().maxCoeff();
	IntegerMatrix w_mat(n, nsim);

	int nthreads = edi_search::omp_max_threads();
	std::vector<std::uint32_t> seeds = edi_search::seed_per_thread_rngs_from_r(nthreads);

#pragma omp parallel
	{
		const int tid = edi_search::omp_this_thread();
		edi_rng::RRng rng(seeds[static_cast<std::size_t>(tid)]);

		std::vector<int> indices(n);
		for (int i = 0; i < n; ++i) indices[static_cast<std::size_t>(i)] = i;
		Eigen::VectorXd w(n);
		std::vector<int> t_idxs, c_idxs;
		t_idxs.reserve(static_cast<std::size_t>(n_T));
		c_idxs.reserve(static_cast<std::size_t>(n - n_T));

#pragma omp for schedule(static)
		for (int s = 0; s < nsim; ++s) {
			random_balanced_init(rng, n, n_T, indices, w, t_idxs, c_idxs);

			Eigen::VectorXd Pw = P * w;
			Eigen::VectorXd Hw = H * w;
			const double wPw = w.dot(Pw);
			const double wHw = w.dot(Hw);

			AOptimalPruneObjective obj{
				P, H, p_ptr, h_ptr, p_diag, h_diag, max_P, max_H, n, n_T,
				Pw, Hw, wPw, wHw, (wHw + 1.0) / (n_T - wPw)
			};
			edi_search::exhaustive_best_improvement_search_pruned(obj, t_idxs, c_idxs, 1e-12);

			for (int i = 0; i < n; ++i) w_mat(i, s) = 0;
			for (int t : t_idxs) w_mat(t, s) = 1;
		}
	}

	return w_mat;
}
