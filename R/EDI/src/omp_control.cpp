#include <RcppEigen.h>
#include "omp_policy.h"
#ifdef _OPENMP
#include <omp.h>
#endif

// Check for MKL
#ifdef EIGEN_USE_MKL_ALL
#include <mkl.h>
#endif

using namespace Rcpp;

//' Set the number of threads for OpenMP, Eigen, and MKL
//'
//' @param n_threads Integer.
//' @keywords internal
// [[Rcpp::export]]
void set_omp_num_threads_cpp(int n_threads) {
#ifdef _OPENMP
    omp_set_dynamic(0);
    // omp_set_nested(0) is deprecated since OpenMP 5.0; omp_set_max_active_levels(1)
    // is the documented replacement for disabling nested parallel regions.
    omp_set_max_active_levels(1);
    omp_set_num_threads(n_threads);
#endif
    Eigen::setNbThreads(n_threads);
#ifdef EIGEN_USE_MKL_ALL
    mkl_set_num_threads(n_threads);
#endif
}

//' Get the maximum number of threads for OpenMP
//'
//' @return Integer.
//' @keywords internal
// [[Rcpp::export]]
int get_omp_max_threads_cpp() {
#ifdef _OPENMP
    return omp_get_max_threads();
#else
    return 1;
#endif
}

//' Probe the actual OpenMP team size for the package's kernel policy
//'
//' This internal test hook makes thread-count tests independent of timing.
//' In the R build, the package OpenMP maximum is authoritative; in the Python
//' core-only build, the explicit argument is used by EDI_KERNEL_NUM_THREADS.
//'
//' @param num_cores Requested worker count for EDI_CORE_ONLY builds.
//' @return Number of threads that entered the OpenMP region.
//' @keywords internal
// [[Rcpp::export]]
int probe_omp_team_size_cpp(int num_cores) {
    (void)num_cores;
    int team_size = 1;
#ifdef _OPENMP
    #pragma omp parallel num_threads(EDI_KERNEL_NUM_THREADS(num_cores))
    {
        #pragma omp single
        team_size = omp_get_num_threads();
    }
#endif
    return team_size;
}
