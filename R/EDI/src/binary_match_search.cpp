#include <Rcpp.h>
#include "RNG.h"
#include "omp_policy.h"
#include <cstdint>
#include <cmath>

#ifdef _OPENMP
#include <omp.h>
#endif

// [[Rcpp::plugins(openmp)]]

using namespace Rcpp;

// [[Rcpp::export]]
NumericMatrix draw_binary_match_assignments_cpp(IntegerMatrix indices_pairs, int n, int r, int num_cores) {
    const int num_pairs = indices_pairs.nrow();
    NumericMatrix w_mat(n, r);

    // Draw one seed from R's RNG serially — avoids any unif_rand() inside OpenMP threads.
    // RNGScope ensures GetRNGstate/PutRNGstate are called correctly.
    uint64_t master_seed;
    {
        Rcpp::RNGScope rng_scope;
        // Scaling by an exact power of two preserves the pre-existing stream
        // for R's [0, 1) generator without rounding UINT64_MAX up to 2^64,
        // which would make the floating-point-to-uint64_t conversion
        // out-of-range at the largest valid R draw.
        master_seed = static_cast<uint64_t>(std::ldexp(R::unif_rand(), 64));
    }

    const int* pairs_ptr = indices_pairs.begin();
    double*    w_ptr     = w_mat.begin();

#pragma omp parallel for schedule(static) num_threads(EDI_KERNEL_NUM_THREADS(num_cores))
    for (int j = 0; j < r; j++) {
        // Each column gets its own independent PRNG seeded deterministically
        // from master_seed and its logical draw index.
        edi_rng::RRng rng(edi_rng::seed_for_index(master_seed, static_cast<uint64_t>(j)));

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
