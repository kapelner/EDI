#ifdef EDI_CORE_ONLY
#include <Eigen/Dense>
#include <stdexcept>
#else
#include <RcppEigen.h>
#endif
#include "RNG.h"
#include <cstdint>
#include <limits>
#include <vector>

#ifndef EDI_CORE_ONLY
using namespace Rcpp;
#endif

namespace {

// bounded_rand is now defined once in RNG.h (namespace edi_rng); ADL
// resolves the unqualified calls below since rng is edi_rng::RRng&.

} // namespace

// Portable cores (EDI_CORE_ONLY-safe): identical logic to the two exported
// functions below, but each takes the seed as an explicit parameter instead
// of drawing it from R's RNG internally.
Eigen::VectorXi sample_int_replace_internal(int n, int size, std::uint32_t seed) {
	edi_rng::RRng rng(seed);
	const std::uint32_t un = static_cast<std::uint32_t>(n);
	Eigen::VectorXi result(size);
	for (int i = 0; i < size; ++i) {
		result[i] = 1 + static_cast<int>(bounded_rand(rng, un));
	}
	return result;
}

Eigen::VectorXi resample_group_rows_internal(const Eigen::Ref<const Eigen::VectorXi>& group_id, int sample_size, std::uint32_t seed) {
	const int n = static_cast<int>(group_id.size());
	if (sample_size < 0) {
		throw std::invalid_argument("sample_size must be non-negative.");
	}
	if (n == 0 || sample_size == 0) {
		return Eigen::VectorXi(0);
	}

	int max_group = 0;
	for (int i = 0; i < n; ++i) {
		const int g = group_id[i];
		if (g <= 0) {
			throw std::invalid_argument("group_id must contain only positive integers.");
		}
		if (g > max_group) {
			max_group = g;
		}
	}

	std::vector<int> counts(static_cast<std::size_t>(max_group), 0);
	for (int i = 0; i < n; ++i) {
		counts[static_cast<std::size_t>(group_id[i] - 1)]++;
	}
	for (int g = 0; g < max_group; ++g) {
		if (counts[static_cast<std::size_t>(g)] == 0) {
			throw std::invalid_argument("group_id must be consecutive positive integers starting at 1.");
		}
	}

	std::vector<std::vector<int>> rows_by_group(static_cast<std::size_t>(max_group));
	for (int g = 0; g < max_group; ++g) {
		rows_by_group[static_cast<std::size_t>(g)].reserve(static_cast<std::size_t>(counts[static_cast<std::size_t>(g)]));
	}
	for (int i = 0; i < n; ++i) {
		rows_by_group[static_cast<std::size_t>(group_id[i] - 1)].push_back(i + 1);
	}

	edi_rng::RRng rng(seed);
	const std::uint32_t u_mg = static_cast<std::uint32_t>(max_group);

	std::vector<int> sampled_groups(static_cast<std::size_t>(sample_size));
	int out_size = 0;
	for (int draw = 0; draw < sample_size; ++draw) {
		const int sampled_group = 1 + static_cast<int>(bounded_rand(rng, u_mg));
		sampled_groups[static_cast<std::size_t>(draw)] = sampled_group;
		out_size += static_cast<int>(rows_by_group[static_cast<std::size_t>(sampled_group - 1)].size());
	}

	Eigen::VectorXi out(out_size);
	int out_idx = 0;
	for (int draw = 0; draw < sample_size; ++draw) {
		const std::vector<int>& rows = rows_by_group[static_cast<std::size_t>(sampled_groups[static_cast<std::size_t>(draw)] - 1)];
		for (std::size_t j = 0; j < rows.size(); ++j) {
			out[out_idx++] = rows[j];
		}
	}
	return out;
}

#ifndef EDI_CORE_ONLY
//' @note Seeded from one R::unif_rand() draw into edi_rng::RRng (RNG.h), a
//'   portable re-implementation of R's own Mersenne-Twister generator -- a
//'   given seed therefore produces identical draws in R and in any future
//'   binding (e.g. Python) using the same core and the same seed.
// [[Rcpp::export]]
Eigen::VectorXi sample_int_replace_cpp(int n, int size) {
	std::uint32_t seed = edi_rng::seed_from_unif01(R::unif_rand());
	return sample_int_replace_internal(n, size, seed);
}

//' @note Reproducibility notes: see sample_int_replace_cpp.
// [[Rcpp::export]]
Eigen::VectorXi resample_group_rows_cpp(const Eigen::Map<Eigen::VectorXi>& group_id, int sample_size) {
	std::uint32_t seed = edi_rng::seed_from_unif01(R::unif_rand());
	try {
		return resample_group_rows_internal(group_id, sample_size, seed);
	} catch (const std::invalid_argument& e) {
		stop(e.what());
	}
}
#endif // EDI_CORE_ONLY
