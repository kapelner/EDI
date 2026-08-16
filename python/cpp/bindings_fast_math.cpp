// Compiles directly against R/EDI/src's portable (EDI_CORE_ONLY-safe) scalar
// math headers -- fast_gamma_functions.h, fast_erfc.h,
// _helper_functions_core.h, ordinal_fixed_link_helpers.h -- via the CMake
// include path set in ../CMakeLists.txt. No file under python/ is a copy of
// anything in R/EDI/src; every function below is a thin vectorizing wrapper
// around an inline scalar function that already lives in one of those
// headers (used elsewhere by EDI's own model-fitting kernels), so there is
// nothing new to validate numerically here -- just the elementwise loop.

#include <pybind11/pybind11.h>
#include <pybind11/eigen.h>
#include "fast_gamma_functions.h"
#include "fast_erfc.h"
#include "_helper_functions_core.h"
#include "ordinal_fixed_link_helpers.h"

namespace py = pybind11;

namespace {

template <typename Func>
Eigen::VectorXd vectorize1(Func f, const Eigen::Ref<const Eigen::VectorXd>& x) {
    Eigen::VectorXd out(x.size());
    for (Eigen::Index i = 0; i < x.size(); ++i) out[i] = f(x[i]);
    return out;
}

} // namespace

void bind_fast_math(py::module_& m) {
    m.def("fast_pchisq_upper", &fast_pchisq_upper,
          py::arg("statistic"), py::arg("df"),
          "Upper-tail chi-squared p-value P(X > statistic) for X ~ chi-squared(df).\n\n"
          "Matches R's pchisq(statistic, df, lower.tail=FALSE) and\n"
          "scipy.stats.chi2.sf(statistic, df) semantics and precision. Used throughout\n"
          "EDI's likelihood-ratio and score-test p-value computations.\n\n"
          "Parameters\n----------\n"
          "statistic : float\n    The chi-squared test statistic (should be >= 0; not validated).\n"
          "df : float\n    Degrees of freedom (should be > 0; not validated).\n\n"
          "Returns\n-------\nfloat\n    The upper-tail probability P(X > statistic).");

    m.def("fast_pchisq_upper", [](const Eigen::Ref<const Eigen::VectorXd>& statistic,
                                   const Eigen::Ref<const Eigen::VectorXd>& df) {
        Eigen::VectorXd out(statistic.size());
        for (Eigen::Index i = 0; i < statistic.size(); ++i) out[i] = fast_pchisq_upper(statistic[i], df[i]);
        return out;
    },
    py::arg("statistic"), py::arg("df"),
    "Vectorized (elementwise) overload of fast_pchisq_upper: statistic and df\n"
    "must be equal-length arrays (no R-style shorter-array recycling); returns\n"
    "an array of upper-tail p-values, one per element.");

    m.def("fast_digamma", [](const Eigen::Ref<const Eigen::VectorXd>& x) {
        return vectorize1([](double v) { return fast_digamma(v); }, x);
    }, py::arg("x"),
    "Digamma function psi(x) = d/dx log(Gamma(x)), evaluated elementwise.\n\n"
    "Computed via an asymptotic expansion with a recurrence (reflection) shift\n"
    "for small arguments, the standard technique for evaluating digamma to double\n"
    "precision without a lookup table. Matches scipy.special.digamma. Used\n"
    "internally inside EDI's negative-binomial, beta, zero-inflated/hurdle, and\n"
    "matched-pair count-response likelihood, score, and Hessian kernels.\n\n"
    "Parameters\n----------\n"
    "x : array_like\n    Arguments; should not be a non-positive integer (a pole of psi);\n"
    "    not validated.\n\n"
    "Returns\n-------\nndarray\n    psi(x), same shape as x.");

    m.def("fast_trigamma", [](const Eigen::Ref<const Eigen::VectorXd>& x) {
        return vectorize1([](double v) { return fast_trigamma(v); }, x);
    }, py::arg("x"),
    "Trigamma function psi'(x), the derivative of the digamma function\n"
    "(fast_digamma), evaluated elementwise via an asymptotic series combined\n"
    "with the recurrence psi'(x) = psi'(x+1) + 1/x^2 (shifting small arguments\n"
    "into the expansion's accurate range first). Matches\n"
    "scipy.special.polygamma(1, x). Used wherever EDI's likelihood kernels need\n"
    "the variance of a log-Gamma-based sufficient statistic or a Fisher-\n"
    "information curvature term involving log(Gamma) (e.g. negative-binomial\n"
    "dispersion-parameter curvature).\n\n"
    "Parameters\n----------\n"
    "x : array_like\n    Arguments; should not be a non-positive integer (a pole of psi');\n"
    "    not validated.\n\n"
    "Returns\n-------\nndarray\n    psi'(x), same shape as x.");

    m.def("fast_lgamma", [](const Eigen::Ref<const Eigen::VectorXd>& x) {
        return vectorize1([](double v) { return fast_lgamma(v); }, x);
    }, py::arg("x"),
    "Log-gamma function log(Gamma(x)), evaluated elementwise via a Lanczos\n"
    "approximation with a Stirling-series tail for large arguments. Matches\n"
    "scipy.special.gammaln. Used pervasively throughout EDI's likelihood\n"
    "kernels (beta, negative-binomial, Poisson/count, and other Gamma-function-\n"
    "based densities) wherever a log-factorial-like normalizing term is needed.\n\n"
    "Parameters\n----------\n"
    "x : array_like\n    Arguments; domain handling for non-positive values follows the\n"
    "    underlying Lanczos kernel and is not separately validated here.\n\n"
    "Returns\n-------\nndarray\n    log(Gamma(x)), same shape as x.");

    m.def("fast_lbeta", [](const Eigen::Ref<const Eigen::VectorXd>& a,
                            const Eigen::Ref<const Eigen::VectorXd>& b) {
        Eigen::VectorXd out(a.size());
        for (Eigen::Index i = 0; i < a.size(); ++i) out[i] = fast_lbeta(a[i], b[i]);
        return out;
    }, py::arg("a"), py::arg("b"),
    "Log-beta function log(B(a, b)) = log(Gamma(a)) + log(Gamma(b)) -\n"
    "log(Gamma(a+b)), evaluated elementwise via three calls into the\n"
    "fast_lgamma kernel. Matches scipy.special.betaln. Used internally inside\n"
    "EDI's beta-regression and zero-one-inflated-beta likelihood, score, and\n"
    "Hessian kernels wherever a Beta-density normalizing constant is required.\n\n"
    "Parameters\n----------\n"
    "a : array_like\n    First shape arguments (should be positive; not validated).\n"
    "b : array_like\n    Second shape arguments (should be positive; not validated), must be\n"
    "    the same length as a -- no R-style shorter-array recycling.\n\n"
    "Returns\n-------\nndarray\n    log(B(a, b)), same shape as a/b.");

    m.def("fast_dnbinom_mu", [](const Eigen::Ref<const Eigen::VectorXd>& x, double size, double mu, bool return_log) {
        Eigen::VectorXd out(x.size());
        for (Eigen::Index i = 0; i < x.size(); ++i) out[i] = fast_dnbinom_mu(x[i], size, mu, return_log);
        return out;
    }, py::arg("x"), py::arg("size"), py::arg("mu"), py::arg("return_log") = false,
    "Mean-parameterized negative-binomial probability mass function,\n"
    "f(x; size, mu) = C(x+size-1, x) * (size/(size+mu))^size * (mu/(size+mu))^x,\n"
    "evaluated elementwise over x with a fixed (size, mu), where E[X] = mu and\n"
    "Var(X) = mu + mu^2/size (size is the dispersion/shape parameter; smaller\n"
    "size means more overdispersion relative to Poisson). Matches R's\n"
    "dnbinom(x, size, mu=mu, log=...) exactly; equivalent to\n"
    "scipy.stats.nbinom.logpmf(x, size, size/(size+mu)) when return_log=True\n"
    "(scipy uses the number-of-successes/probability parameterization, so\n"
    "convert p = size/(size+mu)). Used internally inside EDI's negative-\n"
    "binomial regression likelihood, score, and Hessian kernels.\n\n"
    "Parameters\n----------\n"
    "x : array_like\n    Non-negative integer counts; non-integer/negative values are not\n"
    "    validated and will produce incorrect or non-finite results.\n"
    "size : float\n    Dispersion (shape) parameter > 0, recycled against every element of x.\n"
    "mu : float\n    Mean parameter > 0, recycled against every element of x.\n"
    "return_log : bool, optional\n    If True, return the log-density instead of the density. Default False.\n\n"
    "Returns\n-------\nndarray\n    (Log-)density values, same shape as x.");

    m.def("fast_qnorm", [](const Eigen::Ref<const Eigen::VectorXd>& p) {
        return vectorize1([](double v) { return fast_qnorm(v); }, p);
    }, py::arg("p"),
    "Standard normal quantile function (inverse CDF) Phi^-1(p), evaluated\n"
    "elementwise via Peter Acklam's rational (minimax) approximation, accurate\n"
    "to roughly 1.2e-9 relative error over the representable range of p.\n"
    "Matches scipy.stats.norm.ppf to that approximation precision. Used as the\n"
    "cold-start heuristic in several of EDI's ordinal- and binary-response\n"
    "regression fitters (e.g. probit-family threshold initialization).\n\n"
    "Parameters\n----------\n"
    "p : array_like\n    Probabilities in (0, 1); behavior at exactly 0, 1, or outside that\n"
    "    range follows the Acklam approximation's own boundary handling, not\n"
    "    necessarily -inf/inf/nan exactly as scipy would return.\n\n"
    "Returns\n-------\nndarray\n    Standard normal quantiles, same shape as p.");

    m.def("fast_log_pnorm", [](const Eigen::Ref<const Eigen::VectorXd>& x) {
        return vectorize1([](double v) { return fast_log_pnorm(v); }, x);
    }, py::arg("x"),
    "Log standard normal CDF log(Phi(x)), evaluated elementwise via the\n"
    "complementary error function kernel fast_erfc\n"
    "(Phi(x) = 0.5*erfc(-x/sqrt(2))), in a form stable for large negative x\n"
    "(where Phi(x) underflows in ordinary arithmetic long before the true\n"
    "log-probability does). Matches scipy.stats.norm.logcdf. Used internally\n"
    "inside EDI's probit regression and other likelihood kernels that need a\n"
    "numerically stable normal log-CDF, e.g. for censored/truncated Gaussian\n"
    "contributions.\n\n"
    "Parameters\n----------\nx : array_like\n    Arguments.\n\n"
    "Returns\n-------\nndarray\n    log(Phi(x)), same shape as x.");

    m.def("fast_log_dnorm", [](const Eigen::Ref<const Eigen::VectorXd>& x) {
        return vectorize1([](double v) { return fast_log_dnorm(v); }, x);
    }, py::arg("x"),
    "Log standard normal density log(phi(x)) = -0.5*log(2*pi) - x^2/2,\n"
    "evaluated elementwise via a direct closed-form expression (no series\n"
    "expansion or special-function dispatch is needed). Matches\n"
    "scipy.stats.norm.logpdf. Used internally inside EDI's probit regression\n"
    "and other Gaussian-likelihood kernels wherever a standard normal\n"
    "log-density is required.\n\n"
    "Parameters\n----------\nx : array_like\n    Arguments.\n\n"
    "Returns\n-------\nndarray\n    log(phi(x)), same shape as x.");

    m.def("fast_erfc", [](const Eigen::Ref<const Eigen::VectorXd>& x) {
        return vectorize1([](double v) { return fast_erfc(v); }, x);
    }, py::arg("x"),
    "Complementary error function erfc(x) = 1 - erf(x), evaluated elementwise\n"
    "via a Cephes piecewise rational (minimax) approximation, falling back to\n"
    "the platform libm erfc for |x| > 5.6 to preserve extreme-tail behavior\n"
    "outside the probit fit range. Matches scipy.special.erfc. Used as the\n"
    "building block for pnorm_fast/dnorm_fast and elsewhere probit-link normal\n"
    "tail probabilities are needed.\n\n"
    "Parameters\n----------\nx : array_like\n    Arguments.\n\n"
    "Returns\n-------\nndarray\n    erfc(x), same shape as x.");

    m.def("pnorm_fast", [](const Eigen::Ref<const Eigen::VectorXd>& x) {
        return vectorize1([](double v) { return pnorm_fast(v); }, x);
    }, py::arg("x"),
    "Standard normal CDF Phi(x), evaluated elementwise as\n"
    "0.5*fast_erfc(-x/sqrt(2)), clamped to [6e-16, 1-6e-16] for |x| >= 8 to\n"
    "avoid returning an exact 0 or 1 that could later cause a -inf/nan when\n"
    "log-transformed downstream. Matches scipy.stats.norm.cdf. Used pervasively\n"
    "in EDI's probit-link regression fitters as the mean/link function.\n\n"
    "Parameters\n----------\nx : array_like\n    Arguments.\n\n"
    "Returns\n-------\nndarray\n    Phi(x), same shape as x, clamped away from exact 0/1.");

    m.def("dnorm_fast", [](const Eigen::Ref<const Eigen::VectorXd>& x) {
        return vectorize1([](double v) { return dnorm_fast(v); }, x);
    }, py::arg("x"),
    "Standard normal density phi(x) = exp(-x^2/2) / sqrt(2*pi), evaluated\n"
    "elementwise via a direct closed-form expression. Matches\n"
    "scipy.stats.norm.pdf. Used inside EDI's probit-link regression fitters\n"
    "wherever the normal density (rather than log-density) is needed, e.g. in\n"
    "score/Hessian expressions for the probit link.\n\n"
    "Parameters\n----------\nx : array_like\n    Arguments.\n\n"
    "Returns\n-------\nndarray\n    phi(x), same shape as x.");

    m.def("fast_atan", [](const Eigen::Ref<const Eigen::VectorXd>& x) {
        return vectorize1([](double v) { return edi_ordinal::fast_atan(v); }, x);
    }, py::arg("x"),
    "Arctangent, evaluated elementwise via Cephes-style range reduction\n"
    "followed by a degree-5/5 rational minimax approximation on\n"
    "|x| <= tan(pi/8); dense validation across the finite double range found a\n"
    "maximum absolute error of one ulp against libm atan. Matches numpy.arctan\n"
    "to that precision. Used as the building block of the cauchit link\n"
    "F(z) = 0.5 + atan(z)/pi in EDI's cauchit-link ordinal/binary regression\n"
    "fitters, where atan is evaluated on a very large number of observations\n"
    "per optimizer iteration.\n\n"
    "Parameters\n----------\nx : array_like\n    Arguments.\n\n"
    "Returns\n-------\nndarray\n    atan(x) in radians, same shape as x.");

    m.def("fast_log1pexp", [](const Eigen::Ref<const Eigen::VectorXd>& x) {
        return vectorize1([](double v) { return fast_log1pexp(v); }, x);
    }, py::arg("x"),
    "Numerically stable log(1 + exp(x)) (the softplus function), evaluated\n"
    "elementwise. For |x| <= 37, computed via the atanh series identity\n"
    "log1p(z) = 2*s*(1 + s^2/3 + ... + s^18/19) with s = exp(-|x|)/(2+exp(-|x|))\n"
    "(so s <= 1/3 and a 10-term Horner evaluation has error < 5e-12), avoiding a\n"
    "glibc log1p() dispatch entirely; outside that range the exact asymptotic\n"
    "identity (x itself, or exp(x)) is returned directly to avoid overflow.\n"
    "Matches numpy.logaddexp(0, x). Used inside EDI's logistic/Poisson-family\n"
    "log-likelihood kernels wherever a numerically stable log(1+exp(eta)) term\n"
    "is required (e.g. binomial log-likelihood via the log-sum-exp identity).\n\n"
    "Parameters\n----------\nx : array_like\n    Arguments.\n\n"
    "Returns\n-------\nndarray\n    log(1+exp(x)), same shape as x.");
}
