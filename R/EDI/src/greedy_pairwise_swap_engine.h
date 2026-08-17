#ifndef EDI_GREEDY_PAIRWISE_SWAP_ENGINE_H
#define EDI_GREEDY_PAIRWISE_SWAP_ENGINE_H

// Shared exhaustive best-improvement pairwise-swap local search engine
// (fix_design_hierarchy.md, TODO-31), extracted from three previously
// near-duplicate hand-rolled implementations: greedy_design_search_cpp's
// non-pair-mode exhaustive loop (design_fixed_greedy.cpp), and
// d_optimal_search_cpp/a_optimal_search_cpp's near-identical sorted-scan
// pruned loops (optimal_design_search.cpp).
//
// Two variants are provided, not one, because they are not behaviorally
// interchangeable:
//   - exhaustive_best_improvement_search(): the plain O(nt*nc)-per-round
//     scan every objective can use.
//   - exhaustive_best_improvement_search_pruned(): the sorted-scan
//     early-termination variant, which is only a VALID optimization for
//     objectives whose per-pair delta decomposes as
//     delta(i,j) >= outer_bound(i) + inner_bound(j) - prune_offset()
//     (true for the P/H quadratic-form objectives D-/A-optimal use; NOT
//     established for DesignFixedGreedy's Mahalanobis/abs-sum-diff
//     objectives, so greedy intentionally still uses the unpruned variant --
//     porting pruning there would need its own numerical derivation and
//     proof, not a mechanical refactor, and a wrong bound would silently
//     prune away real improving swaps rather than erroring).
//
// Both variants converge to the identical local optimum a full unpruned
// scan would (pruning only skips pairs provably no better than the current
// best, never an unexplored better one), so this refactor changes running
// time, not the objective value reached for a fixed initial allocation.
// RNG streams for the *initial* allocation are unaffected either way, since
// this header only implements the post-initialization swap search.

#include <vector>
#include <algorithm>
#ifdef _OPENMP
#include <omp.h>
#endif
#include "RNG.h"

namespace edi_search {

// Seeds one edi_rng::RRng generator per OpenMP thread from R's own RNG
// state, consumed serially (single-threaded, via GetRNGstate()/unif_rand())
// before any parallel region begins -- so a given R seed produces identical
// per-thread streams regardless of how many OpenMP threads actually run,
// matching the pattern greedy_design_search_cpp originated
// (design_fixed_greedy.cpp) and now shared with the optimal-design kernels.
inline std::vector<std::uint32_t> seed_per_thread_rngs_from_r(int nthreads) {
	std::vector<std::uint32_t> seeds(static_cast<std::size_t>(nthreads));
	GetRNGstate();
	for (int t = 0; t < nthreads; t++) {
		seeds[static_cast<std::size_t>(t)] = edi_rng::seed_from_unif01(::unif_rand());
	}
	PutRNGstate();
	return seeds;
}

inline int omp_max_threads() {
#ifdef _OPENMP
	return omp_get_max_threads();
#else
	return 1;
#endif
}

inline int omp_this_thread() {
#ifdef _OPENMP
	return omp_get_thread_num();
#else
	return 0;
#endif
}

// Runs Objective's swap search to a strict local optimum: each round scans
// every (treated, control) pair, applies the single globally best improving
// swap (delta < -epsilon), and repeats until no swap improves. `treated`/
// `control` are updated in place to reflect the final allocation's index
// partition.
//
// Objective must expose:
//   double delta(int i, int j) const   -- f(swap i<->j) - f(current);
//                                          negative means improving
//   void   apply_swap(int i, int j)    -- commit the swap, update any
//                                          internal incremental state
template <typename Objective>
inline void exhaustive_best_improvement_search(
	Objective& obj,
	std::vector<int>& treated,
	std::vector<int>& control,
	double epsilon = 0.0
) {
	bool improved = true;
	while (improved) {
		improved = false;
		double best_delta = -epsilon;
		int best_ti = -1, best_ci = -1;
		for (int ti = 0; ti < static_cast<int>(treated.size()); ti++) {
			const int i = treated[static_cast<std::size_t>(ti)];
			for (int ci = 0; ci < static_cast<int>(control.size()); ci++) {
				const int j = control[static_cast<std::size_t>(ci)];
				const double d = obj.delta(i, j);
				if (d < best_delta) {
					best_delta = d;
					best_ti = ti;
					best_ci = ci;
					improved = true;
				}
			}
		}
		if (improved) {
			const int i = treated[static_cast<std::size_t>(best_ti)];
			const int j = control[static_cast<std::size_t>(best_ci)];
			obj.apply_swap(i, j);
			treated[static_cast<std::size_t>(best_ti)] = j;
			control[static_cast<std::size_t>(best_ci)] = i;
		}
	}
}

// Sorted-scan pruned variant of the same search, valid only when Objective
// additionally exposes a decomposable lower bound on delta(i,j):
//   double outer_bound(int i) const           -- "A[i]"
//   double inner_bound(int j) const           -- "B[j]"
//   double prune_threshold(double best_delta) const
//     -- such that delta(i,j) >= outer_bound(i) + inner_bound(j) -
//        prune_threshold(best_delta) is a VALID lower bound given the
//        current round's best delta found so far.
// `prune_threshold` takes the live best_delta rather than being a single
// fixed number because the two objectives already extracted here are not
// proven-safe under the same rule: D-optimal's bound is adaptive (provably
// safe to tighten as `best_delta` improves mid-round -- see
// d_optimal_search_cpp's derivation, ported verbatim into
// DOptimalPruneObjective), while A-optimal's bound is only proven against
// the round's *starting* objective value (a fixed threshold each round,
// ignoring `best_delta` entirely -- see a_optimal_search_cpp's derivation,
// ported verbatim into AOptimalPruneObjective in optimal_design_search.cpp).
// Applying D's adaptive rule to A's objective (or vice versa) would be an
// unproven bound -- silently pruning away a real improving swap is exactly
// the failure mode this split avoids. Each Objective's `prune_threshold`
// implementation encodes which rule is actually proven for its own math;
// the engine itself makes no assumption about which.
//
// Sorting treated/control ascending by outer_bound/inner_bound each round
// makes outer_bound(i) + inner_bound(j) non-decreasing along each axis,
// enabling the same early-termination structure d_optimal_search_cpp/
// a_optimal_search_cpp used independently before this extraction. Reaches
// the identical local optimum as the unpruned variant, just faster.
template <typename Objective>
inline void exhaustive_best_improvement_search_pruned(
	Objective& obj,
	std::vector<int>& treated,
	std::vector<int>& control,
	double epsilon = 0.0
) {
	bool improved = true;
	while (improved) {
		improved = false;
		double best_delta = -epsilon;
		int best_ti = -1, best_ci = -1;

		std::sort(treated.begin(), treated.end(), [&](int a, int b) {
			return obj.outer_bound(a) < obj.outer_bound(b);
		});
		std::sort(control.begin(), control.end(), [&](int a, int b) {
			return obj.inner_bound(a) < obj.inner_bound(b);
		});

		const double inner_bound_min = obj.inner_bound(control.front());

		for (int ti = 0; ti < static_cast<int>(treated.size()); ti++) {
			const int i = treated[static_cast<std::size_t>(ti)];
			const double outer_i = obj.outer_bound(i);
			if (outer_i + inner_bound_min >= obj.prune_threshold(best_delta)) break;

			for (int ci = 0; ci < static_cast<int>(control.size()); ci++) {
				const int j = control[static_cast<std::size_t>(ci)];
				const double inner_j = obj.inner_bound(j);
				if (outer_i + inner_j >= obj.prune_threshold(best_delta)) break;

				const double d = obj.delta(i, j);
				if (d < best_delta) {
					best_delta = d;
					best_ti = ti;
					best_ci = ci;
					improved = true;
				}
			}
		}

		if (improved) {
			const int i = treated[static_cast<std::size_t>(best_ti)];
			const int j = control[static_cast<std::size_t>(best_ci)];
			obj.apply_swap(i, j);
			treated[static_cast<std::size_t>(best_ti)] = j;
			control[static_cast<std::size_t>(best_ci)] = i;
		}
	}
}

} // namespace edi_search

#endif // EDI_GREEDY_PAIRWISE_SWAP_ENGINE_H
