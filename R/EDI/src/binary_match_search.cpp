#include <Rcpp.h>
#include "RNG.h"
#include <cstdint>
#include <limits>

#ifdef _OPENMP
#include <omp.h>
#endif

// [[Rcpp::plugins(openmp)]]

using namespace Rcpp;

namespace {

// SplitMix64 bijection: maps integer → well-distributed 64-bit value, then
// truncated to 32 bits to seed edi_rng::RRng (RNG.h's portable
// re-implementation of R's own Mersenne-Twister -- R's Int32 state is
// genuinely 32-bit, unlike the arbitrary-width std::mt19937_64 this
// replaces). Ensures independent RRng streams when seeded with consecutive
// j values.
inline std::uint32_t splitmix64_seed(std::uint64_t x) {
    x += 0x9e3779b97f4a7c15ULL;
    x  = (x ^ (x >> 30)) * 0xbf58476d1ce4e5b9ULL;
    x  = (x ^ (x >> 27)) * 0x94d049bb133111ebULL;
    x  = x ^ (x >> 31);
    return static_cast<std::uint32_t>(x);
}

} // namespace

// [[Rcpp::export]]
NumericMatrix draw_binary_match_assignments_cpp(IntegerMatrix indices_pairs, int n, int r, int num_cores) {
    const int num_pairs = indices_pairs.nrow();
    NumericMatrix w_mat(n, r);

    // Draw one seed from R's RNG serially — avoids any unif_rand() inside OpenMP threads.
    // RNGScope ensures GetRNGstate/PutRNGstate are called correctly.
    uint64_t master_seed;
    {
        Rcpp::RNGScope rng_scope;
        master_seed = static_cast<uint64_t>(
            R::unif_rand() * static_cast<double>(std::numeric_limits<uint64_t>::max()));
    }

    const int* pairs_ptr = indices_pairs.begin();
    double*    w_ptr     = w_mat.begin();

#ifdef _OPENMP
    omp_set_num_threads(num_cores);
#endif

#pragma omp parallel for schedule(static)
    for (int j = 0; j < r; j++) {
        // Each column gets its own independent PRNG seeded deterministically from master_seed.
        // splitmix64_seed(master_seed + j) distributes consecutive j values into uncorrelated seeds.
        edi_rng::RRng rng(splitmix64_seed(master_seed + static_cast<uint64_t>(j)));

        double* w_col = w_ptr + static_cast<size_t>(j) * n;

        for (int i = 0; i < num_pairs; i++) {
            const int idx1 = pairs_ptr[i]             - 1;  // Col 0, Row i (column-major)
            const int idx2 = pairs_ptr[i + num_pairs] - 1;  // Col 1, Row i

            // Fast coin flip: test MSB of a 32-bit random word (no FP conversion or division)
            if (rng() >> 31) {
                w_col[idx1] = 1.0;
                w_col[idx2] = 0.0;
            } else {
                w_col[idx1] = 0.0;
                w_col[idx2] = 1.0;
            }
        }
    }

    return w_mat;
}
