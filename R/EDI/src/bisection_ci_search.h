#ifndef EDI_BISECTION_CI_SEARCH_H
#define EDI_BISECTION_CI_SEARCH_H

#include <functional>

namespace edi {

// R callbacks run on the main thread. Both tails return the outside endpoint;
// missing midpoint p-values are treated as rejections, as in the R search.
// Defined in bisection_ci.cpp so incremental installs rebuild policy changes.
double bisection_ci_search(const std::function<double(double)>& pvalue,
                          double l, double u, double cutoff, double tol, bool lower);

} // namespace edi
#endif
