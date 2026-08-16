#ifdef EDI_CORE_ONLY
#include <Eigen/Dense>
#else
#include <RcppEigen.h>
#endif
#include "RNG.h"
#include <cstdint>
#include <limits>

#ifndef EDI_CORE_ONLY
using namespace Rcpp;
#endif

namespace {

// bounded_rand is now defined once in RNG.h (namespace edi_rng); ADL
// resolves the unqualified calls below since rng is edi_rng::RRng&.

} // namespace

// Portable core (EDI_CORE_ONLY-safe): identical logic to
// compute_bootstrapped_weighted_sqd_distances_cpp below, but takes the seed
// as an explicit parameter instead of drawing it from R's RNG internally.
Eigen::VectorXd compute_bootstrapped_weighted_sqd_distances_internal(
	const Eigen::Ref<const Eigen::MatrixXd>& X_all_scaled_col_subset,
	const Eigen::Ref<const Eigen::VectorXd>& covariate_weights,
	int t,
	int B,
	std::uint32_t seed) {

	int d = static_cast<int>(covariate_weights.size());
	Eigen::VectorXd bootstrapped_weighted_sqd_distances(B);

	edi_rng::RRng rng(seed);
	const std::uint32_t ut = static_cast<std::uint32_t>(t);

	for (int b = 0; b < B; ++b) {
		int i1 = static_cast<int>(bounded_rand(rng, ut));
		int i2 = static_cast<int>(bounded_rand(rng, ut));
		if (t > 1) {
			while (i1 == i2) {
				i2 = static_cast<int>(bounded_rand(rng, ut));
			}
		}

		double sqd_weighted_sum = 0.0;
		for (int j = 0; j < d; ++j) {
			double delta = X_all_scaled_col_subset(i1, j) - X_all_scaled_col_subset(i2, j);
			sqd_weighted_sum += delta * delta * covariate_weights[j];
		}

		bootstrapped_weighted_sqd_distances[b] = sqd_weighted_sum;
	}

	return bootstrapped_weighted_sqd_distances;
}

#ifndef EDI_CORE_ONLY
//' @note Seeded from one R::unif_rand() draw into edi_rng::RRng (RNG.h), a
//'   portable re-implementation of R's own Mersenne-Twister generator -- a
//'   given seed therefore produces identical draws in R and in any future
//'   binding (e.g. Python) using the same core and the same seed.
// [[Rcpp::export]]
Eigen::VectorXd compute_bootstrapped_weighted_sqd_distances_cpp(
	const Eigen::Map<Eigen::MatrixXd>& X_all_scaled_col_subset,
	const Eigen::Map<Eigen::VectorXd>& covariate_weights,
	int t, // self$t
	int B) { // private$other_params$num_boot
	std::uint32_t seed = edi_rng::seed_from_unif01(R::unif_rand());
	return compute_bootstrapped_weighted_sqd_distances_internal(
		X_all_scaled_col_subset, covariate_weights, t, B, seed);
}
#endif // EDI_CORE_ONLY
