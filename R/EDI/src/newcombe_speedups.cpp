#ifdef EDI_CORE_ONLY
#include "na_real_core.h"
#else
#include <Rcpp.h>
using namespace Rcpp;
#endif
#include <cmath>
#include <algorithm>
#include "fast_erfc.h"

struct WilsonCIBounds {
    double lower;
    double upper;
};

// Portable (EDI_CORE_ONLY-safe) core of wilson_score_interval_cpp below --
// identical logic, plain struct instead of Rcpp::NumericVector, so a
// separate Python binding translation unit (and newcombe_independent_ci_
// internal below, in the same TU) can call it directly.
WilsonCIBounds wilson_score_interval_internal(double x, double n, double alpha) {
    if (n <= 0) return WilsonCIBounds{NA_REAL, NA_REAL};
    double p = x / n;
    double z = fast_qnorm(1.0 - alpha / 2.0);
    double z2 = z * z;

    double denom = 2.0 * (n + z2);
    double term1 = 2.0 * n * p + z2;
    double term2 = z * std::sqrt(z2 + 4.0 * n * p * (1.0 - p));

    double lower = (term1 - term2) / denom;
    double upper = (term1 + term2) / denom;

    return WilsonCIBounds{std::max(0.0, lower), std::min(1.0, upper)};
}

#ifndef EDI_CORE_ONLY
//' Wilson Score Interval for a Single Proportion
//' @keywords internal
// [[Rcpp::export]]
NumericVector wilson_score_interval_cpp(double x, double n, double alpha) {
    WilsonCIBounds r = wilson_score_interval_internal(x, n, alpha);
    return NumericVector::create(r.lower, r.upper);
}
#endif

struct NewcombeCIBounds {
    double lower;
    double upper;
};

// Portable (EDI_CORE_ONLY-safe) core of newcombe_independent_ci_cpp below.
NewcombeCIBounds newcombe_independent_ci_internal(double x1, double n1, double x2, double n2, double alpha) {
    if (n1 <= 0 || n2 <= 0) return NewcombeCIBounds{NA_REAL, NA_REAL};

    double p1 = x1 / n1;
    double p2 = x2 / n2;
    double diff = p1 - p2;

    WilsonCIBounds ci1 = wilson_score_interval_internal(x1, n1, alpha);
    WilsonCIBounds ci2 = wilson_score_interval_internal(x2, n2, alpha);

    double l1 = ci1.lower, u1 = ci1.upper;
    double l2 = ci2.lower, u2 = ci2.upper;

    double lower = diff - std::sqrt(std::pow(p1 - l1, 2) + std::pow(u2 - p2, 2));
    double upper = diff + std::sqrt(std::pow(u1 - p1, 2) + std::pow(p2 - l2, 2));

    return NewcombeCIBounds{std::max(-1.0, lower), std::min(1.0, upper)};
}

#ifndef EDI_CORE_ONLY
//' Newcombe Hybrid Score Interval for Independent Proportions (Method 10)
//'
//' Computes Newcombe's "Method 10" hybrid confidence interval for the
//' difference between two \strong{independent} proportions \eqn{p_1 - p_2}
//' (see
//' \code{\link[EDI:InferenceIncidNewcombeRiskDiff]{InferenceIncidNewcombeRiskDiff}}
//' for the class that consumes this function). Separate Wilson score intervals
//' \eqn{[\ell_1, u_1]} and \eqn{[\ell_2, u_2]} are computed for each proportion
//' individually (via \code{\link{wilson_score_interval_cpp}}), then combined as
//' \deqn{\left[\,(p_1-p_2) - \sqrt{(p_1-\ell_1)^2 + (u_2-p_2)^2},\ \ (p_1-p_2) +
//'   \sqrt{(u_1-p_1)^2 + (p_2-\ell_2)^2}\,\right],}
//' clamped to \eqn{[-1, 1]}. This avoids the boundary/coverage problems of the
//' naive normal-approximation (Wald) interval on a risk difference while
//' remaining closed-form (no iterative score-test inversion). Returns
//' \code{c(NA, NA)} if either sample size is non-positive.
//'
//' @param x1 Number of events in group 1.
//' @param n1 Number of subjects in group 1.
//' @param x2 Number of events in group 2.
//' @param n2 Number of subjects in group 2.
//' @param alpha The confidence level is \eqn{1-\alpha}.
//' @return A length-2 numeric vector containing the lower and upper CI bounds
//'   for \eqn{p_1 - p_2}.
//' @references Newcombe, R. G. (1998). "Interval Estimation for the Difference
//'   Between Independent Proportions: Comparison of Eleven Methods."
//'   \emph{Statistics in Medicine}, 17(8), 873-890,
//'   \doi{10.1002/(SICI)1097-0258(19980430)17:8<873::AID-SIM779>3.0.CO;2-I}.
//' @seealso \code{\link{newcombe_paired_ci_cpp}} for the matched-pair
//'   generalization of this same hybrid-score method.
//' @keywords internal
// [[Rcpp::export]]
NumericVector newcombe_independent_ci_cpp(double x1, double n1, double x2, double n2, double alpha) {
    NewcombeCIBounds r = newcombe_independent_ci_internal(x1, n1, x2, n2, alpha);
    return NumericVector::create(r.lower, r.upper);
}
#endif

#ifndef EDI_CORE_ONLY
//' Newcombe Hybrid Score Interval for Paired Proportions
//' @keywords internal
// [[Rcpp::export]]
NumericVector newcombe_paired_ci_cpp(double n11, double n10, double n01, double n00, double alpha) {
    double n = n11 + n10 + n01 + n00;
    if (n <= 0) return NumericVector::create(NA_REAL, NA_REAL);

    double p1 = (n11 + n10) / n;
    double p2 = (n11 + n01) / n;
    double diff = p1 - p2;

    NumericVector ci1 = wilson_score_interval_cpp(n11 + n10, n, alpha);
    NumericVector ci2 = wilson_score_interval_cpp(n11 + n01, n, alpha);

    double l1 = ci1[0], u1 = ci1[1];
    double l2 = ci2[0], u2 = ci2[1];

    // Pearson correlation for 2x2 paired table
    double denom_phi = std::sqrt((n11 + n10) * (n01 + n00) * (n11 + n01) * (n10 + n00));
    double phi = (denom_phi > 0) ? (n11 * n00 - n10 * n01) / denom_phi : 0.0;

    // Newcombe's paired formula (Method 10 for paired data)
    double d_l = std::pow(p1 - l1, 2) - 2.0 * phi * (p1 - l1) * (u2 - p2) + std::pow(u2 - p2, 2);
    double d_u = std::pow(u1 - p1, 2) - 2.0 * phi * (u1 - p1) * (p2 - l2) + std::pow(p2 - l2, 2);

    double lower = diff - std::sqrt(std::max(0.0, d_l));
    double upper = diff + std::sqrt(std::max(0.0, d_u));

    return NumericVector::create(std::max(-1.0, lower), std::min(1.0, upper));
}
#endif
