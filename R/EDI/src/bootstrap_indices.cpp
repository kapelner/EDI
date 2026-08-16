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

// Portable core (EDI_CORE_ONLY-safe): identical logic to bootstrap_indices_cpp
// below, but takes the seed as an explicit parameter instead of drawing it
// from R's RNG internally. The Rcpp wrapper draws one R::unif_rand() value
// and passes it in, so this function itself has zero R/Rcpp dependency and
// can be called from a future Python binding with its own seed -- and,
// since edi_rng::RRng (RNG.h) is a portable re-implementation of R's own
// generator, a given seed produces identical draws in R and Python alike.
Eigen::MatrixXi bootstrap_indices_internal(int n, int B, std::uint32_t seed) {
	edi_rng::RRng rng(seed);
	const std::uint32_t un = static_cast<std::uint32_t>(n);
	Eigen::MatrixXi idx(B, n);
	for (int i = 0; i < B; ++i) {
		for (int j = 0; j < n; ++j) {
			idx(i, j) = 1 + static_cast<int>(bounded_rand(rng, un));
		}
	}
	return idx;
}

#ifndef EDI_CORE_ONLY
//' @note Seeded from one R::unif_rand() draw into edi_rng::RRng (RNG.h), a
//'   portable re-implementation of R's own Mersenne-Twister generator -- a
//'   given seed therefore produces identical draws in R and in any future
//'   binding (e.g. Python) using the same core and the same seed.
// [[Rcpp::export]]
Eigen::MatrixXi bootstrap_indices_cpp(int n, int B) {
	std::uint32_t seed = edi_rng::seed_from_unif01(R::unif_rand());
	return bootstrap_indices_internal(n, B, seed);
}
#endif // EDI_CORE_ONLY
