// [[Rcpp::depends(RcppEigen)]]
#include <RcppEigen.h>
#include "fast_gamma_functions.h"
#include "fast_erfc.h"

using namespace Rcpp;

// Vectorized wrappers around EDI's internal scalar fast_* special-function
// kernels (used internally inside the NegBin/Beta/ZINB/Hurdle likelihoods,
// KK21 negative-binomial fitting, and probit cold-start heuristics). Exported
// as standalone utilities because benchmark/benchmark_model_fits.R's "Utility
// / Math Kernel Performance" table shows every one of them is consistently
// faster than its base R equivalent (see R/benchmark/benchmark_model_fits_R.html).

//' Fast Digamma Function, Vectorized (C++ Backend)
//'
//' Computes the digamma function \eqn{\psi(x) = d/dx \log \Gamma(x)} elementwise
//' over \code{x}, via an asymptotic expansion with a recurrence (reflection)
//' shift for small arguments to keep the expansion accurate — the standard
//' technique for evaluating digamma/trigamma to double precision without a
//' lookup table. Used internally inside the package's negative-binomial, beta,
//' zero-inflated/hurdle, and KK21 count-response likelihood, score, and Hessian
//' kernels (wherever a Poisson/NegBin/Beta log-likelihood derivative requires
//' \eqn{\psi}), and exported standalone because it is consistently faster than
//' base R's \code{\link[base]{digamma}} — measured at 6.78x on a length-5000
//' vector (see the
//' \href{https://github.com/kapelner/EDI/blob/main/R/benchmark/benchmark_model_fits_R.html}{"Utility
//' / Math Kernel Performance" benchmark report} for the full methodology and
//' per-kernel results).
//'
//' @param x Numeric vector of arguments (should be finite and, per the digamma
//'   function's domain, not a non-positive integer, where \eqn{\psi} has poles;
//'   no domain validation is performed by this function).
//' @return A numeric vector of \eqn{\psi(x)} values, the same length as \code{x}.
//' @references Abramowitz, M., and Stegun, I. A. (1972). \emph{Handbook of
//'   Mathematical Functions}, Section 6.3, for the asymptotic expansion and
//'   recurrence relation used. See also
//'   \href{https://en.wikipedia.org/wiki/Digamma_function}{digamma function} for
//'   orientation. Analogous Python API:
//'   \href{https://docs.scipy.org/doc/scipy/reference/generated/scipy.special.digamma.html}{SciPy
//'   \code{digamma}}.
//' @export
//' @keywords internal
// [[Rcpp::export]]
NumericVector fast_digamma_vec_cpp(NumericVector x) {
    const int n = x.size();
    NumericVector out(n);
    for (int i = 0; i < n; ++i) out[i] = fast_digamma(x[i]);
    return out;
}

//' Fast Trigamma Function, Vectorized (C++ Backend)
//'
//' Computes \eqn{\psi'(x)}, the trigamma function (the second derivative of
//' \eqn{\log\Gamma(x)}, i.e. the derivative of the digamma function
//' \code{\link{fast_digamma_vec_cpp}}), elementwise over \code{x}, via an
//' asymptotic series expansion combined with the recurrence relation \eqn{\psi'(x)
//' = \psi'(x+1) + 1/x^2} (shifting small arguments up into the expansion's
//' accurate range before applying it) — faster than base R's
//' \code{\link[base]{trigamma}} while matching it to within the approximation's own
//' precision. Used wherever this package's likelihood kernels need the variance of
//' a log-Gamma-based sufficient statistic or a Fisher-information second
//' derivative involving \eqn{\log\Gamma} (e.g. negative-binomial dispersion-parameter
//' curvature), and exported standalone for the same reason as
//' \code{\link{fast_digamma_vec_cpp}} and friends. Benchmarked at roughly
//' \strong{19.3x} the speed of base R's vectorized \code{trigamma()} on this
//' package's benchmark suite; see the
//' \href{https://github.com/kapelner/EDI/blob/main/R/benchmark/benchmark_model_fits_R.html}{"Utility
//' / Math Kernel Performance"} section of the benchmark report for the full
//' methodology and current measured multiple.
//'
//' @param x Numeric vector of arguments (per the trigamma function's domain, should
//'   not be a non-positive integer, where \eqn{\psi'} has poles; no domain
//'   validation is performed by this function).
//' @return A numeric vector of \eqn{\psi'(x)} values, the same length as \code{x}.
//' @seealso \code{\link{fast_digamma_vec_cpp}} for the corresponding first-derivative
//'   kernel this function's recurrence builds on.
//' @references \href{https://en.wikipedia.org/wiki/Trigamma_function}{Trigamma
//'   function} for orientation. Analogous Python API:
//'   \href{https://docs.scipy.org/doc/scipy/reference/generated/scipy.special.polygamma.html}{SciPy
//'   \code{polygamma(1, x)}}.
//' @export
//' @keywords internal
// [[Rcpp::export]]
NumericVector fast_trigamma_vec_cpp(NumericVector x) {
    const int n = x.size();
    NumericVector out(n);
    for (int i = 0; i < n; ++i) out[i] = fast_trigamma(x[i]);
    return out;
}

//' Fast Log-Gamma Function, Vectorized (C++ Backend)
//'
//' Computes \eqn{\log \Gamma(x)} elementwise over \code{x}, via a Lanczos
//' approximation (with a Stirling-series tail for large arguments) — faster
//' than base R's \code{\link[base]{lgamma}} while matching it to within
//' the approximation's own precision. Used pervasively throughout the package's
//' likelihood kernels (beta, negative-binomial, Poisson/count, and other
//' Gamma-function-based densities) wherever a log-factorial-like normalizing
//' term is required, and exported standalone for the same reason as
//' \code{\link{fast_digamma_vec_cpp}} — measured at 2.18x over
//' \code{\link[base]{lgamma}} on a length-5000 vector (see the
//' \href{https://github.com/kapelner/EDI/blob/main/R/benchmark/benchmark_model_fits_R.html}{"Utility
//' / Math Kernel Performance" benchmark report} for the full methodology and
//' per-kernel results).
//'
//' @param x Numeric vector of arguments (should be positive, or a non-positive
//'   non-integer if the reflection formula is supported by the underlying
//'   kernel; not validated by this function — see the package's C++ source for
//'   the exact domain the Lanczos kernel handles).
//' @return A numeric vector of \eqn{\log \Gamma(x)} values, the same length as
//'   \code{x}.
//' @seealso \code{\link{fast_digamma_vec_cpp}}, \code{\link{fast_trigamma_vec_cpp}},
//'   \code{\link{fast_lbeta_vec_cpp}} (built on this function's kernel).
//' @references \href{https://en.wikipedia.org/wiki/Lanczos_approximation}{Lanczos
//'   approximation} and \href{https://en.wikipedia.org/wiki/Stirling\%27s_approximation}{Stirling's
//'   approximation} for the numerical techniques used; see also
//'   \href{https://en.wikipedia.org/wiki/Gamma_function}{Gamma function} for
//'   orientation. Analogous Python API:
//'   \href{https://docs.scipy.org/doc/scipy/reference/generated/scipy.special.gammaln.html}{SciPy
//'   \code{gammaln}}.
//' @export
//' @keywords internal
// [[Rcpp::export]]
NumericVector fast_lgamma_vec_cpp(NumericVector x) {
    const int n = x.size();
    NumericVector out(n);
    for (int i = 0; i < n; ++i) out[i] = fast_lgamma(x[i]);
    return out;
}

//' Fast Log-Beta Function, Vectorized (C++ Backend)
//'
//' Computes the log of the Beta function,
//' \eqn{\log B(a, b) = \log\Gamma(a) + \log\Gamma(b) - \log\Gamma(a+b)},
//' elementwise, via three calls into \code{\link{fast_lgamma_vec_cpp}}'s kernel
//' rather than R's own \code{lgamma} dispatch — faster than base R's
//' \code{\link[base]{lbeta}} — measured at 2.43x on a length-5000 vector (see
//' the
//' \href{https://github.com/kapelner/EDI/blob/main/R/benchmark/benchmark_model_fits_R.html}{"Utility
//' / Math Kernel Performance" benchmark report}) — while returning numerically
//' identical values (up to the Lanczos/Stirling approximation's own
//' precision). Used internally inside the
//' package's beta-regression and beta-distribution-based (zero-one-inflated
//' beta) likelihood, score, and Hessian kernels, wherever a Beta-density
//' normalizing constant is required.
//'
//' @param a Numeric vector of first shape arguments (should be positive; not
//'   validated by this function).
//' @param b Numeric vector of second shape arguments (should be positive; not
//'   validated), recycled against \code{a} elementwise — \strong{must be the
//'   same length as \code{a}}; unlike R's own vectorized arithmetic, this
//'   function does not perform R-style shorter-vector recycling.
//' @return A numeric vector of \eqn{\log B(a, b)} values, the same length as
//'   \code{a}/\code{b}.
//' @seealso \code{\link{fast_lgamma_vec_cpp}}, whose kernel this function calls.
//' @references \href{https://en.wikipedia.org/wiki/Beta_function}{Beta
//'   function} for orientation. Analogous Python API:
//'   \href{https://docs.scipy.org/doc/scipy/reference/generated/scipy.special.betaln.html}{SciPy
//'   \code{betaln}}.
//' @export
//' @keywords internal
// [[Rcpp::export]]
NumericVector fast_lbeta_vec_cpp(NumericVector a, NumericVector b) {
    const int n = a.size();
    NumericVector out(n);
    for (int i = 0; i < n; ++i) out[i] = fast_lbeta(a[i], b[i]);
    return out;
}

//' Fast Mean-Parameterized Negative-Binomial Density, Vectorized (C++ Backend)
//'
//' Computes the negative-binomial probability mass function, in its
//' mean/dispersion parameterization,
//' \deqn{f(x; \mathrm{size}, \mu) = \binom{x + \mathrm{size} - 1}{x} \left(\frac{\mathrm{size}}{\mathrm{size} + \mu}\right)^{\mathrm{size}} \left(\frac{\mu}{\mathrm{size} + \mu}\right)^{x},}
//' elementwise over \code{x}, with \eqn{E[X] = \mu} and
//' \eqn{\mathrm{Var}(X) = \mu + \mu^2/\mathrm{size}} (\code{size} is the
//' dispersion/shape parameter; smaller \code{size} means more overdispersion
//' relative to Poisson). This matches \code{R::dnbinom_mu(x, size, mu, give_log)}
//' semantics exactly, but evaluates the three required \code{lgamma} calls per
//' observation via \code{\link{fast_lgamma_vec_cpp}}'s kernel instead of R's own
//' \code{lgamma} dispatch, making it faster than base R's
//' \code{stats::dnbinom(x, size, mu = mu, log = ...)} — measured at 1.35x on
//' a length-5000 vector (see the
//' \href{https://github.com/kapelner/EDI/blob/main/R/benchmark/benchmark_model_fits_R.html}{"Utility
//' / Math Kernel Performance" benchmark report}) — while returning
//' numerically identical values. Used internally inside the package's
//' negative-binomial regression likelihood, score, and Hessian kernels.
//'
//' @param x Numeric vector of non-negative integer counts (non-integer or
//'   negative values are not validated by this function and will produce
//'   incorrect or non-finite results, matching \code{R::dnbinom_mu}'s own lack
//'   of input validation at the C level).
//' @param size Dispersion (shape) parameter \eqn{> 0} (single value, recycled
//'   against every element of \code{x}).
//' @param mu Mean parameter \eqn{> 0} (single value, recycled against every
//'   element of \code{x}).
//' @param return_log Logical. If \code{TRUE}, return the log-density instead of
//'   the density.
//' @return A numeric vector of (log-)density values, the same length as
//'   \code{x}.
//' @seealso \code{\link{fast_lgamma_vec_cpp}}, whose kernel this function calls
//'   three times per observation.
//' @references
//'   \href{https://en.wikipedia.org/wiki/Negative_binomial_distribution}{Negative
//'   binomial distribution} for the mean/dispersion parameterization used here.
//'   Analogous Python API:
//'   \href{https://docs.scipy.org/doc/scipy/reference/stats.html}{SciPy stats
//'   distributions index} (\code{scipy.stats.nbinom}, in its
//'   number-of-successes/probability parameterization — convert via
//'   \eqn{p = \mathrm{size}/(\mathrm{size}+\mu)}).
//' @export
//' @keywords internal
// [[Rcpp::export]]
NumericVector fast_dnbinom_mu_vec_cpp(NumericVector x, double size, double mu, bool return_log) {
    const int n = x.size();
    NumericVector out(n);
    for (int i = 0; i < n; ++i) out[i] = fast_dnbinom_mu(x[i], size, mu, return_log);
    return out;
}

//' Fast Standard Normal Quantile Function, Vectorized (C++ Backend)
//'
//' Computes \eqn{\Phi^{-1}(p)}, the standard normal quantile (inverse CDF),
//' elementwise over \code{p}, via Peter Acklam's rational (minimax) approximation,
//' accurate to within roughly \eqn{1.2 \times 10^{-9}} relative error over the
//' representable range of \code{p} — faster than base R's
//' \code{\link[stats]{qnorm}} while matching it to that approximation precision.
//' Used as the cold-start heuristic in several of this package's ordinal- and
//' binary-response regression fitters (e.g. probit-family threshold
//' initialization) wherever an approximate normal quantile is needed on a hot
//' path, and exported standalone for the same reason as
//' \code{\link{fast_digamma_vec_cpp}} and friends: to let performance-sensitive R
//' or Python callers bypass \code{qnorm}'s per-call dispatch overhead when
//' evaluating many quantiles at once. Benchmarked at roughly \strong{2.33x} the
//' speed of base R's vectorized \code{qnorm()} on this package's benchmark suite;
//' see the \href{https://github.com/kapelner/EDI/blob/main/R/benchmark/benchmark_model_fits_R.html}{"Utility
//' / Math Kernel Performance"} section of the benchmark report for the full
//' methodology and current measured multiple.
//'
//' @param p Numeric vector of probabilities in \verb{(0, 1)}; behavior at exactly
//'   0, 1, or outside that range follows the underlying Acklam approximation's
//'   boundary handling, not necessarily \code{-Inf}/\code{Inf}/\code{NaN} exactly
//'   as base R's \code{qnorm} would return.
//' @return A numeric vector of standard normal quantiles, the same length as \code{p}.
//' @seealso \code{\link{fast_log_pnorm_vec_cpp}} and \code{\link{fast_log_dnorm_vec_cpp}}
//'   for the corresponding forward (CDF/density) kernels.
//' @export
//' @keywords internal
// [[Rcpp::export]]
NumericVector fast_qnorm_vec_cpp(NumericVector p) {
    const int n = p.size();
    NumericVector out(n);
    for (int i = 0; i < n; ++i) out[i] = fast_qnorm(p[i]);
    return out;
}

//' Fast Log Standard Normal CDF, Vectorized (C++ Backend)
//'
//' Computes \eqn{\log \Phi(x)}, the log of the standard normal cumulative
//' distribution function, elementwise over \code{x}, via the complementary
//' error function kernel \code{fast_erfc} (\eqn{\Phi(x) = \tfrac{1}{2}
//' \mathrm{erfc}(-x/\sqrt{2})}, evaluated in a form stable for large negative
//' \code{x}, where \eqn{\Phi(x)} underflows in ordinary (non-log) arithmetic
//' long before the true log-probability does), avoiding R's own
//' \code{\link[stats]{pnorm}} dispatch overhead. Faster than base R's
//' \code{\link[stats]{pnorm}(x, log.p = TRUE)} — measured at 2.49x on a
//' length-5000 vector (see the
//' \href{https://github.com/kapelner/EDI/blob/main/R/benchmark/benchmark_model_fits_R.html}{"Utility
//' / Math Kernel Performance" benchmark report}). Used internally inside the
//' package's probit regression and other likelihood kernels that need a
//' numerically stable normal log-CDF, e.g. for censored/truncated Gaussian
//' contributions.
//'
//' @param x Numeric vector of arguments.
//' @return A numeric vector of \eqn{\log \Phi(x)} values, the same length as
//'   \code{x}.
//' @seealso \code{\link{fast_log_dnorm_vec_cpp}} for the corresponding
//'   log-density kernel; \code{\link{fast_qnorm_vec_cpp}} for the standard
//'   normal quantile function.
//' @references \href{https://en.wikipedia.org/wiki/Normal_distribution}{Normal
//'   distribution} for orientation. Analogous Python API:
//'   \href{https://docs.scipy.org/doc/scipy/reference/stats.html}{SciPy stats
//'   distributions index} (\code{scipy.stats.norm.logcdf}).
//' @export
//' @keywords internal
// [[Rcpp::export]]
NumericVector fast_log_pnorm_vec_cpp(NumericVector x) {
    const int n = x.size();
    NumericVector out(n);
    for (int i = 0; i < n; ++i) out[i] = fast_log_pnorm(x[i]);
    return out;
}

//' Fast Log Standard Normal Density, Vectorized (C++ Backend)
//'
//' Computes \eqn{\log \phi(x) = -\tfrac{1}{2}\log(2\pi) - x^2/2}, the log-density
//' of the standard normal distribution, elementwise over \code{x}, via a
//' direct closed-form evaluation — no series expansion or special-function
//' dispatch is needed since the standard normal log-density has an exact
//' elementary closed form. Faster than base R's
//' \code{\link[stats]{dnorm}(x, log = TRUE)} — measured at 5x on a
//' length-5000 vector (see the
//' \href{https://github.com/kapelner/EDI/blob/main/R/benchmark/benchmark_model_fits_R.html}{"Utility
//' / Math Kernel Performance" benchmark report}) — while returning
//' numerically identical values. Used internally inside the package's probit
//' regression and other Gaussian-likelihood kernels wherever a standard normal
//' log-density is required.
//'
//' @param x Numeric vector of arguments.
//' @return A numeric vector of \eqn{\log \phi(x)} values, the same length as
//'   \code{x}.
//' @seealso \code{\link{fast_log_pnorm_vec_cpp}} for the corresponding log-CDF
//'   kernel; \code{\link{fast_qnorm_vec_cpp}} for the standard normal quantile
//'   function.
//' @references \href{https://en.wikipedia.org/wiki/Normal_distribution}{Normal
//'   distribution} for orientation. Analogous Python API:
//'   \href{https://docs.scipy.org/doc/scipy/reference/stats.html}{SciPy stats
//'   distributions index} (\code{scipy.stats.norm.logpdf}).
//' @export
//' @keywords internal
// [[Rcpp::export]]
NumericVector fast_log_dnorm_vec_cpp(NumericVector x) {
    const int n = x.size();
    NumericVector out(n);
    for (int i = 0; i < n; ++i) out[i] = fast_log_dnorm(x[i]);
    return out;
}
