#ifndef EDI_BISECTION_CI_SEARCH_H
#define EDI_BISECTION_CI_SEARCH_H

#include <Rcpp.h>
#include <cmath>

namespace edi {

// R callbacks run on the main thread. Both tails return the outside endpoint;
// missing midpoint p-values are treated as rejections, as in the R search.
template <typename PValue>
inline double bisection_ci_search(PValue pvalue, double l, double u,
                                  double cutoff, double tol, bool lower) {
    if (!std::isfinite(l) || !std::isfinite(u) || l > u)
        Rcpp::stop("Bisection bounds must be finite and ordered.");
    if (!std::isfinite(tol) || tol <= 0)
        Rcpp::stop("Bisection tolerance must be finite and positive.");
    if (!std::isfinite(cutoff))
        Rcpp::stop("Bisection p-value threshold must be finite.");

    Rcpp::checkUserInterrupt();
    double p_l = pvalue(l);
    Rcpp::checkUserInterrupt();
    double p_u = pvalue(u);

    for (int iter = 0; iter < 2048; ++iter) {
        Rcpp::checkUserInterrupt();
        const double gap = lower ? p_u - p_l : p_l - p_u;
        if (!std::isfinite(p_l) || !std::isfinite(p_u) || gap <= tol) break;
        const double midpoint = 0.5 * l + 0.5 * u;
        // Discontinuous or missing p-values need not converge in p-value space.
        // Stop when the delta interval cannot shrink in floating-point space.
        // An absolute width cutoff would prematurely stop tiny response scales.
        if (midpoint <= l || midpoint >= u) break;
        double p_mid = pvalue(midpoint);
        if (!std::isfinite(p_mid)) p_mid = 0;
        if ((p_mid >= cutoff) == lower) {
            u = midpoint;
            p_u = p_mid;
        } else {
            l = midpoint;
            p_l = p_mid;
        }
    }
    return lower ? l : u;
}

} // namespace edi
#endif
