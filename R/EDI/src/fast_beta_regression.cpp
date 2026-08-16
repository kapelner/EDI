#ifdef EDI_CORE_ONLY
#include "_helper_functions_core.h"
#else
#include "_helper_functions.h"
#include "result_map_rcpp.h"
#include <RcppEigen.h>
#include <Rmath.h>
#endif

#ifndef EDI_CORE_ONLY
using namespace Rcpp;
#endif

namespace {

class BetaRegression {
private:
	const Eigen::Ref<const Eigen::VectorXd> m_y;
	const Eigen::Ref<const Eigen::MatrixXd> m_X;
	const Eigen::VectorXd m_weights;
	const int m_n;
	const int m_p;
	const double m_weight_sum;
	const Eigen::VectorXd m_log_y;
	const Eigen::VectorXd m_log1_y;
	Eigen::VectorXd m_eta;
	Eigen::VectorXd m_mu;
	Eigen::VectorXd m_w_grad;

public:
	BetaRegression(const Eigen::Ref<const Eigen::VectorXd>& y, const Eigen::Ref<const Eigen::MatrixXd>& X) :
		m_y(y), m_X(X), m_weights(Eigen::VectorXd::Ones(X.rows())), m_n(X.rows()), m_p(X.cols()),
		m_weight_sum(static_cast<double>(X.rows())),
		m_log_y(y.array().log().matrix()),
		m_log1_y((1.0 - y.array()).log().matrix()),
		m_eta(X.rows()),
		m_mu(X.rows()),
		m_w_grad(X.rows()) {}

	BetaRegression(const Eigen::Ref<const Eigen::VectorXd>& y, const Eigen::Ref<const Eigen::MatrixXd>& X,
	               const Eigen::Ref<const Eigen::VectorXd>& weights) :
		m_y(y), m_X(X), m_weights(weights), m_n(X.rows()), m_p(X.cols()),
		m_weight_sum(weights.sum()),
		m_log_y(y.array().log().matrix()),
		m_log1_y((1.0 - y.array()).log().matrix()),
		m_eta(X.rows()),
		m_mu(X.rows()),
		m_w_grad(X.rows()) {}

	double operator()(const Eigen::VectorXd& params, Eigen::VectorXd& grad) {
		const auto beta = params.head(m_p);
		const double phi = std::exp(params[m_p]);
		const double lgamma_phi = fast_lgamma(phi);
		const double digamma_phi = fast_digamma(phi);
		const double epsilon = 1e-8;

		m_eta.noalias() = m_X * beta;

		double neg_ll = 0.0;
		double d_neg_ll_d_phi = -m_weight_sum * digamma_phi;
		for (int i = 0; i < m_n; ++i) {
			double mui = 1.0 / (1.0 + std::exp(-m_eta[i]));
			if (mui < epsilon) {
				mui = epsilon;
			} else if (mui > 1.0 - epsilon) {
				mui = 1.0 - epsilon;
			}
			m_mu[i] = mui;

			const double one_minus_mu = 1.0 - mui;
			const double a = mui * phi;
			const double b = one_minus_mu * phi;
			const double log_y = m_log_y[i];
			const double log1_y = m_log1_y[i];
			const double weight = m_weights[i];

			neg_ll += weight * (
				-lgamma_phi +
				fast_lgamma(a) +
				fast_lgamma(b) -
				(a - 1.0) * log_y -
				(b - 1.0) * log1_y
			);

			const double dig_a = fast_digamma(a);
			const double dig_b = fast_digamma(b);
			const double C = dig_a - dig_b - log_y + log1_y;
			const double d_mu_d_eta = mui * one_minus_mu;
			m_w_grad[i] = weight * phi * C * d_mu_d_eta;

			d_neg_ll_d_phi += weight * (
				mui * dig_a +
				one_minus_mu * dig_b -
				mui * log_y -
				one_minus_mu * log1_y
			);
		}

		grad.resize(m_p + 1);
		grad.head(m_p).noalias() = m_X.transpose() * m_w_grad;
		grad[m_p] = d_neg_ll_d_phi * phi;

		return neg_ll;
	}

	Eigen::MatrixXd hessian(const Eigen::VectorXd& params) {
		int total_p = m_p + 1;
		Eigen::MatrixXd H = Eigen::MatrixXd::Zero(total_p, total_p);
		Eigen::VectorXd beta = params.head(m_p);
		double phi = std::exp(params[m_p]);
		Eigen::VectorXd eta = m_X * beta;
		Eigen::VectorXd mu = (1.0 / (1.0 + (-eta).array().exp())).matrix();
		double epsilon = 1e-8;
		for (int i = 0; i < m_n; ++i) {
			if (mu[i] < epsilon) mu[i] = epsilon;
			if (mu[i] > 1.0 - epsilon) mu[i] = 1.0 - epsilon;
		}

		Eigen::VectorXd a = mu.array() * phi;
		Eigen::VectorXd b = (1.0 - mu.array()) * phi;
		Eigen::VectorXd dig_a = a.unaryExpr(DigammaFunctor());
		Eigen::VectorXd dig_b = b.unaryExpr(DigammaFunctor());
		Eigen::VectorXd tri_a = fast_trigamma_vec(a.array()).matrix();
		Eigen::VectorXd tri_b = fast_trigamma_vec(b.array()).matrix();

		double* H_data = H.data();
		for (int i = 0; i < m_n; ++i) {
			double mui = mu[i];
			double dmu = mui * (1.0 - mui);
			double d2mu = dmu * (1.0 - 2.0 * mui);
			double C = dig_a[i] - dig_b[i] - m_log_y[i] + m_log1_y[i];
			double B = phi * C;
			double B_mu = phi * phi * (tri_a[i] + tri_b[i]);
			double obs_weight = m_weights[i];
			double w_beta = obs_weight * (B_mu * dmu * dmu + B * d2mu);
			const double* xi = m_X.data() + i;  // xi[j * m_n] == X(i,j)

			for (int c = 0; c < m_p; ++c) {
				const double wxi_c = w_beta * xi[c * m_n];
				for (int r = 0; r <= c; ++r)
					H_data[r + c * total_p] += wxi_c * xi[r * m_n];
			}

			double B_log_phi = obs_weight * phi * (C + a[i] * tri_a[i] - b[i] * tri_b[i]);
			const double s = B_log_phi * dmu;
			for (int r = 0; r < m_p; ++r)
				H_data[r + m_p * total_p] += s * xi[r * m_n];
		}

		double D = -m_weight_sum * fast_digamma(phi);
		double D_phi = -m_weight_sum * fast_trigamma(phi);
		for (int i = 0; i < m_n; ++i) {
			double mui = mu[i];
			double obs_weight = m_weights[i];
			D += obs_weight * (
				mui * dig_a[i] + (1.0 - mui) * dig_b[i] -
				mui * m_log_y[i] - (1.0 - mui) * m_log1_y[i]
			);
			D_phi += obs_weight * (mui * mui * tri_a[i] + (1.0 - mui) * (1.0 - mui) * tri_b[i]);
		}
		H(m_p, m_p) = phi * D + phi * phi * D_phi;
		for (int c = 0; c < total_p; ++c)
			for (int r = 0; r < c; ++r)
				H_data[c + r * total_p] = H_data[r + c * total_p];
		return H;
	}

	Eigen::MatrixXd expected_hessian(const Eigen::VectorXd& params) {
		int total_p = m_p + 1;
		Eigen::MatrixXd H = Eigen::MatrixXd::Zero(total_p, total_p);
		Eigen::VectorXd beta = params.head(m_p);
		double phi = std::exp(params[m_p]);
		Eigen::VectorXd eta = m_X * beta;
		Eigen::VectorXd mu = (1.0 / (1.0 + (-eta).array().exp())).matrix();
		double epsilon = 1e-8;
		for (int i = 0; i < m_n; ++i) {
			if (mu[i] < epsilon) mu[i] = epsilon;
			if (mu[i] > 1.0 - epsilon) mu[i] = 1.0 - epsilon;
		}

		Eigen::VectorXd a = mu.array() * phi;
		Eigen::VectorXd b = (1.0 - mu.array()) * phi;
		Eigen::VectorXd tri_a = fast_trigamma_vec(a.array()).matrix();
		Eigen::VectorXd tri_b = fast_trigamma_vec(b.array()).matrix();

		const double trigamma_phi = fast_trigamma(phi);
		double* H_data = H.data();
		for (int i = 0; i < m_n; ++i) {
			const double mui = mu[i];
			const double obs_weight = m_weights[i];
			const double dmu = mui * (1.0 - mui);
			const double w_beta = obs_weight * phi * phi * (tri_a[i] + tri_b[i]) * dmu * dmu;
			const double cross = obs_weight * phi * (a[i] * tri_a[i] - b[i] * tri_b[i]) * dmu;
			const double* xi = m_X.data() + i;

			for (int c = 0; c < m_p; ++c) {
				const double wxi_c = w_beta * xi[c * m_n];
				for (int r = 0; r <= c; ++r)
					H_data[r + c * total_p] += wxi_c * xi[r * m_n];
			}
			for (int r = 0; r < m_p; ++r)
				H_data[r + m_p * total_p] += cross * xi[r * m_n];
			H(m_p, m_p) += obs_weight * phi * phi * (
				-trigamma_phi + mui * mui * tri_a[i] + (1.0 - mui) * (1.0 - mui) * tri_b[i]
			);
		}

		for (int c = 0; c < total_p; ++c)
			for (int r = 0; r < c; ++r)
				H_data[c + r * total_p] = H_data[r + c * total_p];
		return H;
	}
};

} // namespace

ModelResult fast_beta_regression_internal(const Eigen::Ref<const Eigen::MatrixXd>& X,
                                        const Eigen::Ref<const Eigen::VectorXd>& y,
                                        const Eigen::VectorXd* weights = nullptr,
                                        const Eigen::VectorXd* warm_start_beta = nullptr,
                                        bool smart_cold_start = true,
                                        double start_phi = 10.0,
                                        std::optional<Eigen::VectorXi> fixed_idx = std::nullopt,
                                        std::optional<Eigen::VectorXd> fixed_values = std::nullopt,
                                        std::string optimization_alg = "lbfgs",
                                        std::optional<Eigen::MatrixXd> warm_start_fisher_info = std::nullopt,
                                        bool estimate_only = false) {
    int p = X.cols();
    ModelResult res;
    Eigen::VectorXd params = Eigen::VectorXd::Zero(p + 1);
    if (warm_start_beta) {
        params.head(p) = *warm_start_beta;
    } else if (smart_cold_start) {
        // Smart warm_start_params: OLS on logit(y)
        Eigen::VectorXd y_logit = (y.array() / (1.0 - y.array())).log().matrix();
        // Handle potential INF/NA from 0/1 in y if any (though beta regr assumes (0,1))
        for(int i=0; i<y_logit.size(); ++i) {
            if (!std::isfinite(y_logit[i])) {
                double yi = std::max(1e-4, std::min(1.0 - 1e-4, y[i]));
                y_logit[i] = std::log(yi / (1.0 - yi));
            }
        }
        params.head(p) = safe_ols_solve(X, y_logit);
    } else {
        params.head(p).setZero();
    }
    params[p] = std::log(start_phi);
    FixedParamSpec fixed_spec = make_fixed_param_spec(p + 1, fixed_idx, fixed_values);

    Eigen::VectorXd weights_work = weights == nullptr ? Eigen::VectorXd::Ones(X.rows()) : *weights;
    BetaRegression fun(y, X, weights_work);
    
    Eigen::MatrixXd H_start;
    const Eigen::MatrixXd* h_ptr = nullptr;
    if (warm_start_fisher_info.has_value()) {
        H_start = *warm_start_fisher_info;
        h_ptr = &H_start;
    }

    LikelihoodFitResult fit = optimize_fixed_likelihood(fun, params, fixed_spec, 1000, 1e-6, optimization_alg, "lbfgs", 0, h_ptr);
    params = fit.params;

    res.b = params.head(p);
    res.dispersion = std::exp(params[p]); // phi
    res.XtWX = estimate_only ? Eigen::MatrixXd::Zero(p+1, p+1) : fun.hessian(params);
    res.converged = fit.converged;
    return res;
}

#ifndef EDI_CORE_ONLY
//' @title Compute Beta Regression Score
//' @description Calculates the score vector (gradient of the log-likelihood) for a beta regression model.
//' @param X A numeric matrix of predictors.
//' @param y A numeric vector of responses (in (0, 1)).
//' @param params A numeric vector of parameters [beta, log_phi].
//' @return A numeric vector representing the score.
//' @export
//' @keywords internal
// [[Rcpp::export]]
Eigen::VectorXd get_beta_regression_score_cpp(const Eigen::Map<Eigen::MatrixXd>& X, SEXP y, const Eigen::Map<Eigen::VectorXd>& params) {
	NumericVector y_r_coerced(y); Eigen::Map<const Eigen::VectorXd> y_vec_coerced(y_r_coerced.begin(), y_r_coerced.size());


    

    

    

    BetaRegression fun(y_vec_coerced, X);
    Eigen::VectorXd grad(params.size());
    fun(params, grad);
    return -grad; // Return the actual score (gradient of log-likelihood)
}

//' Beta Regression Hessian, Standalone (C++)
//'
//' Computes the Hessian matrix (second derivatives with respect to
//' \eqn{[\beta, \log\phi]}) of the log-likelihood of the mean-precision Beta
//' regression model documented in full at \code{\link{fast_beta_regression_cpp}},
//' at arbitrary caller-supplied parameters \code{params} (not necessarily the
//' MLE). Exported standalone — independent of any optimizer run — for direct
//' numerical diagnostics (e.g. checking curvature or building a custom variance
//' estimate at a specific parameter value) and for use by
//' \code{\link{get_beta_regression_score_cpp}}'s sibling relationship in
//' optimizer/inference code that needs both quantities at the same point.
//'
//' @param X A numeric matrix of predictors, as used to fit the model.
//' @param y A numeric vector of responses in \verb{(0, 1)}.
//' @param params A numeric vector \eqn{[\beta, \log\phi]}: the mean-model
//'   coefficients followed by the log-precision parameter.
//' @return The \eqn{(p+1) \times (p+1)} Hessian matrix of the log-likelihood
//'   (i.e. the negative of the observed information) at \code{params}.
//' @seealso \code{\link{get_beta_regression_score_cpp}} for the corresponding
//'   gradient at the same point; \code{\link{fast_beta_regression_cpp}} for the
//'   full mean-precision Beta regression model documentation.
//' @export
//' @keywords internal
// [[Rcpp::export]]
Eigen::MatrixXd get_beta_regression_hessian_cpp(const Eigen::Map<Eigen::MatrixXd>& X, SEXP y, const Eigen::Map<Eigen::VectorXd>& params) {
	NumericVector y_r_coerced(y); Eigen::Map<const Eigen::VectorXd> y_vec_coerced(y_r_coerced.begin(), y_r_coerced.size());


    

    

    

    BetaRegression fun(y_vec_coerced, X);
    return -fun.hessian(params); // Return the actual Hessian of log-likelihood (Fisher Information is -Hessian)
}

//' Fast Beta Regression, Estimate Only (C++ Backend)
//'
//' Fits the beta regression model of Ferrari and Cribari-Neto (2004) for a
//' continuous response strictly between 0 and 1 (proportions, rates, and similar
//' bounded outcomes), via direct maximum likelihood on the reparameterized beta
//' density
//' \deqn{f(y_i; \mu_i, \phi) = \frac{\Gamma(\phi)}{\Gamma(\mu_i \phi)\Gamma((1-\mu_i)\phi)} y_i^{\mu_i \phi - 1} (1 - y_i)^{(1-\mu_i)\phi - 1}, \quad 0 < y_i < 1,}
//' with mean \eqn{E[Y_i] = \mu_i} and variance
//' \eqn{\mathrm{Var}(Y_i) = \mu_i(1-\mu_i) / (1 + \phi)}, where \eqn{\phi > 0} is a
//' single (constant-across-observations) precision parameter and the mean is linked
//' to the covariates via the logit link \eqn{\mathrm{logit}(\mu_i) = x_i^\top \beta}
//' (fixed; no alternative link functions are supported by this backend).
//'
//' @details
//' \strong{Parameterization and optimization.} The optimizer's parameter vector is
//' \code{c(beta, log(phi))} — \eqn{\phi} is optimized on the log scale to keep it
//' unconstrained (\eqn{\phi > 0} enforced automatically by exponentiating back),
//' initialized from \code{start_phi} (or a value derived from it via
//' \code{smart_cold_start}). \eqn{\mu_i} is clipped to \eqn{[10^{-8}, 1 - 10^{-8}]}
//' internally during likelihood/gradient/Hessian evaluation to avoid boundary blowup
//' when \eqn{x_i^\top \beta} is extreme; this affects only numerical evaluation, not
//' the returned \eqn{\hat\beta} itself. Optimized via \code{optimization_alg}
//' (\code{"lbfgs"} default; see \code{\link{.normalize_optimizer_algorithm}}); when
//' no \code{warm_start_beta} is supplied, \code{smart_cold_start = TRUE} (default)
//' seeds \eqn{\beta} from an OLS-based initial guess.
//' \code{fixed_idx}/\code{fixed_values} allow holding specific parameters (by index
//' into the \code{c(beta, log(phi))} layout) fixed rather than estimated.
//' \code{compute_std_errs} is a legacy/deprecated argument with no effect in this
//' estimate-only entry point; use \code{\link{fast_beta_regression_with_var_cpp}} to
//' obtain standard errors.
//'
//' \strong{Reported likelihood and information.} \code{neg_loglik} is the exact beta
//' negative log-likelihood re-evaluated at the fitted parameters (not merely the
//' optimizer's internal objective trace); \code{fisher_information} is the
//' \eqn{X^\top W X}-style working-weights curvature matrix from the fit
//' (\code{fit.XtWX}) — the same expected-information approximation classical IRLS
//' uses for GLM standard errors, and exactly what
//' \code{\link{fast_beta_regression_with_var_cpp}} inverts to produce \code{vcov} —
//' rather than a fresh evaluation of the exact observed-information Hessian from
//' \code{\link{get_beta_regression_hessian_cpp}}. It is also suitable for
//' warm-starting a subsequent fit via \code{warm_start_fisher_info}.
//'
//' @param X A numeric matrix of predictors, \eqn{n \times p}; include an explicit
//'   intercept column if desired (the model has no implicit intercept).
//' @param y A numeric vector of responses, strictly in \eqn{(0, 1)} (values at or
//'   beyond the boundary are not valid beta-distributed outcomes; see
//'   \code{\link{fast_beta_regression}} for boundary-handling guidance at the R
//'   wrapper level).
//' @param warm_start_beta Optional starting values for coefficients \eqn{\beta}. If provided, \code{smart_cold_start} is ignored.
//' @param smart_cold_start Logical. If TRUE, use an initial OLS-based guess when starting from scratch (a "cold start") with no prior knowledge. This is ignored if a warm start is provided.
//' @param start_phi Starting value for the precision parameter \eqn{\phi} (on its
//'   natural, not log, scale).
//' @param compute_std_errs Deprecated; has no effect on this estimate-only entry
//'   point. Use \code{\link{fast_beta_regression_with_var_cpp}} for standard errors.
//' @param fixed_idx Optional integer indices (into the \code{c(beta, log(phi))}
//'   parameter layout) of parameters to hold fixed rather than estimate.
//' @param fixed_values Optional values to fix the parameters named by
//'   \code{fixed_idx} at; must be the same length as \code{fixed_idx}.
//' @param optimization_alg Optimization algorithm; see Details.
//' @param warm_start_fisher_info Optional initial Fisher Information matrix (over
//'   \code{c(beta, log(phi))}) to warm-start curvature information for the first
//'   optimizer iteration.
//' @param estimate_only Logical; if \code{TRUE}, may skip work not needed to produce
//'   point estimates (kept in sync with the package's other \code{fast_*} estimate-
//'   vs-inference split).
//' @return A list with components \code{coefficients} (\eqn{\hat\beta}, length
//'   \code{p}), \code{phi} (\eqn{\hat\phi}, on its natural scale), \code{neg_loglik}
//'   (the exact beta negative log-likelihood at the fitted parameters),
//'   \code{converged} (logical), and \code{fisher_information} (an approximate
//'   working curvature matrix; see Details).
//' @seealso \code{\link{fast_beta_regression_weighted_cpp}} for the row-weighted
//'   variant; \code{\link{fast_beta_regression_with_var_cpp}} for the
//'   variance-augmented variant; \code{\link{fast_beta_regression}} for the R-level
//'   wrapper with \pkg{betareg} fallback; \code{\link{get_beta_regression_score_cpp}}/
//'   \code{\link{get_beta_regression_hessian_cpp}} for standalone score/Hessian
//'   evaluation at arbitrary parameter values.
//' @references Ferrari, S., and Cribari-Neto, F. (2004). "Beta regression for
//'   modelling rates and proportions." \emph{Journal of Applied Statistics}, 31(7),
//'   799-815, \doi{10.1080/0266476042000214501}. Analogous Python API:
//'   \href{https://www.statsmodels.org/stable/glm.html}{statsmodels GLM} (via the
//'   \code{Beta} family, \code{statsmodels.othermod.betareg}).
//' @export
//' @keywords internal
//' @examples
//' X = matrix(rnorm(100), 10, 10)
//' y = runif(10)
//' fast_beta_regression_cpp(X, y)
// [[Rcpp::export]]
List fast_beta_regression_cpp(const Eigen::Map<Eigen::MatrixXd>& X, SEXP y, Nullable<NumericVector> warm_start_beta = R_NilValue, bool smart_cold_start = true, double start_phi = 10.0, bool compute_std_errs = false, Rcpp::Nullable<Rcpp::IntegerVector> fixed_idx = R_NilValue, Rcpp::Nullable<Rcpp::NumericVector> fixed_values = R_NilValue, std::string optimization_alg = "lbfgs", Rcpp::Nullable<Rcpp::NumericMatrix> warm_start_fisher_info = R_NilValue, bool estimate_only = false) {
	NumericVector y_r_coerced(y); Eigen::Map<const Eigen::VectorXd> y_vec_coerced(y_r_coerced.begin(), y_r_coerced.size());


    

    

    Eigen::VectorXd sb;
    Eigen::VectorXd* sb_ptr = nullptr;
    std::optional<Eigen::VectorXd> warm_start_beta_opt = nullable_to_optional<Eigen::VectorXd>(warm_start_beta);
    if (warm_start_beta_opt.has_value()) {
        sb = *warm_start_beta_opt;
        sb_ptr = &sb;
    }

    ModelResult fit = fast_beta_regression_internal(
        X, y_vec_coerced, nullptr, sb_ptr, smart_cold_start, start_phi,
        nullable_to_optional<Eigen::VectorXi>(fixed_idx),
        nullable_to_optional<Eigen::VectorXd>(fixed_values),
        optimization_alg,
        nullable_to_optional<Eigen::MatrixXd>(warm_start_fisher_info),
        estimate_only);

    Eigen::VectorXd params_full(fit.b.size() + 1);
    params_full.head(fit.b.size()) = fit.b;
    params_full[fit.b.size()] = std::log(fit.dispersion);
    BetaRegression fun_neg_ll(y_vec_coerced, X);
    Eigen::VectorXd dummy_grad(params_full.size());
    double neg_loglik = fun_neg_ll(params_full, dummy_grad);

	return edi::to_rcpp_list(edi::ResultMap()
		.set("coefficients", fit.b)
		.set("phi", fit.dispersion)
		.set("neg_loglik", neg_loglik)
		.set("converged", fit.converged)
		.set("fisher_information", fit.XtWX));
}

//' Fast Weighted Beta Regression, Estimate Only (C++ Backend)
//'
//' Fits the same beta regression model as
//' \code{\link{fast_beta_regression_cpp}} (see that page for the full model,
//' parameterization, and optimizer contract), with each observation's contribution
//' to the log-likelihood, score, and Hessian multiplied by a nonnegative row weight
//' \code{weights[i]}. Setting all weights to 1 recovers
//' \code{\link{fast_beta_regression_cpp}} exactly; this is the backend the package's
//' \code{Inference} classes use whenever the beta regression must be fit on
//' bootstrap-reweighted or otherwise weighted data (e.g. Bayesian bootstrap weights)
//' without physically resampling rows.
//'
//' @details
//' \strong{Input validation.} \code{weights} must have length \code{nrow(X)}, be
//' finite and non-negative, and sum to a strictly positive value; violating any of
//' these raises an error immediately rather than producing a degenerate fit. A
//' weight of 0 for a given row contributes nothing to the likelihood (effectively
//' excludes that row) without changing \eqn{n} in downstream index bookkeeping.
//'
//' @param X A numeric matrix of predictors, \eqn{n \times p}.
//' @param y A numeric vector of responses, strictly in \eqn{(0, 1)}.
//' @param weights A nonnegative, finite numeric vector of length \code{nrow(X)}
//'   giving each row's weight; must sum to a positive value (see Details).
//' @param warm_start_beta Optional starting values for coefficients \eqn{\beta}. If provided, \code{smart_cold_start} is ignored.
//' @param smart_cold_start Logical. If TRUE, use an initial OLS-based guess when no warm start is provided.
//' @param start_phi Starting value for the precision parameter \eqn{\phi} (natural scale).
//' @param compute_std_errs Deprecated; has no effect on this estimate-only entry
//'   point.
//' @param fixed_idx Optional integer indices (into the \code{c(beta, log(phi))}
//'   parameter layout) of parameters to hold fixed rather than estimate.
//' @param fixed_values Optional values to fix the parameters named by
//'   \code{fixed_idx} at.
//' @param optimization_alg Optimization algorithm; see
//'   \code{\link{fast_beta_regression_cpp}}.
//' @param warm_start_fisher_info Optional initial Fisher Information matrix to
//'   warm-start curvature information.
//' @param estimate_only If TRUE, skip Fisher information calculation.
//' @return A list with the same components as
//'   \code{\link{fast_beta_regression_cpp}}: \code{coefficients}, \code{phi},
//'   \code{neg_loglik} (the weighted negative log-likelihood), \code{converged}, and
//'   \code{fisher_information}.
//' @seealso \code{\link{fast_beta_regression_cpp}} for the unweighted model and full
//'   parameterization documentation; \code{\link{fast_beta_regression_with_var_cpp}}
//'   for the (unweighted) variance-augmented variant.
//' @export
//' @keywords internal
// [[Rcpp::export]]
List fast_beta_regression_weighted_cpp(const Eigen::Map<Eigen::MatrixXd>& X, SEXP y, SEXP weights, Nullable<NumericVector> warm_start_beta = R_NilValue, bool smart_cold_start = true, double start_phi = 10.0, bool compute_std_errs = false, Rcpp::Nullable<Rcpp::IntegerVector> fixed_idx = R_NilValue, Rcpp::Nullable<Rcpp::NumericVector> fixed_values = R_NilValue, std::string optimization_alg = "lbfgs", Rcpp::Nullable<Rcpp::NumericMatrix> warm_start_fisher_info = R_NilValue, bool estimate_only = false) {
	NumericVector weights_r_coerced(weights); Eigen::Map<const Eigen::VectorXd> weights_vec_coerced(weights_r_coerced.begin(), weights_r_coerced.size());
	NumericVector y_r_coerced(y); Eigen::Map<const Eigen::VectorXd> y_vec_coerced(y_r_coerced.begin(), y_r_coerced.size());


    if (weights_vec_coerced.size() != X.rows()) {
        stop("weights_vec_coerced length must equal nrow(X)");
    }
    if ((weights_vec_coerced.array() < 0.0).any() || !weights_vec_coerced.allFinite() || weights_vec_coerced.sum() <= 0.0) {
        stop("weights_vec_coerced must be finite, nonnegative, and have positive sum");
    }
    Eigen::VectorXd weights_vec = weights_vec_coerced;

    Eigen::VectorXd sb;
    Eigen::VectorXd* sb_ptr = nullptr;
    std::optional<Eigen::VectorXd> warm_start_beta_opt = nullable_to_optional<Eigen::VectorXd>(warm_start_beta);
    if (warm_start_beta_opt.has_value()) {
        sb = *warm_start_beta_opt;
        sb_ptr = &sb;
    }

    ModelResult fit = fast_beta_regression_internal(
        X, y_vec_coerced, &weights_vec, sb_ptr, smart_cold_start, start_phi,
        nullable_to_optional<Eigen::VectorXi>(fixed_idx),
        nullable_to_optional<Eigen::VectorXd>(fixed_values),
        optimization_alg,
        nullable_to_optional<Eigen::MatrixXd>(warm_start_fisher_info),
        estimate_only);

    Eigen::VectorXd params_full(fit.b.size() + 1);
    params_full.head(fit.b.size()) = fit.b;
    params_full[fit.b.size()] = std::log(fit.dispersion);
    BetaRegression fun_neg_ll(y_vec_coerced, X, weights_vec);
    Eigen::VectorXd dummy_grad(params_full.size());
    double neg_loglik = fun_neg_ll(params_full, dummy_grad);

	return edi::to_rcpp_list(edi::ResultMap()
		.set("coefficients", fit.b)
		.set("phi", fit.dispersion)
		.set("neg_loglik", neg_loglik)
		.set("converged", fit.converged)
		.set("fisher_information", fit.XtWX));
}

//' Fast Beta Regression with Variance (C++ Backend)
//'
//' Fits the same beta regression model as \code{\link{fast_beta_regression_cpp}}
//' (see that page for the full model, parameterization, and optimizer contract) and
//' additionally computes the variance-covariance matrix and standard errors of the
//' fitted parameters, via the same working-weights (\eqn{X^\top W X}) curvature
//' matrix documented there.
//'
//' @details
//' \strong{Variance computation.} The fit's working-information matrix
//' (\code{fit.XtWX}, over all \code{p + 1} parameters \code{c(beta, log(phi))}) is
//' restricted to the free (non-\code{fixed_idx}) parameters and inverted via a
//' \strong{plain matrix inverse} (\code{.inverse()}, not a rank-aware pseudo-inverse
//' as used by, e.g., \code{\link{fast_adjacent_category_logit_with_var_cpp}}) before
//' being expanded back to the full \code{(p + 1) x (p + 1)} size as \code{vcov};
//' \code{std_errs} is \code{sqrt(diag(vcov))}. Because this uses a plain inverse, a
//' rank-deficient or near-singular \code{X} (after restricting to free parameters)
//' will produce numerically unstable or \code{NaN} standard errors rather than a
//' graceful fallback — callers should ensure \code{X} is full rank on the free
//' parameters (e.g. via the package's shared \code{drop_linearly_dependent_cols()}
//' preprocessing) before calling this function if that is not already guaranteed.
//'
//' @param X A numeric matrix of predictors, \eqn{n \times p}.
//' @param y A numeric vector of responses, strictly in \eqn{(0, 1)}.
//' @param warm_start_beta Optional starting values for coefficients. If provided, \code{smart_cold_start} is ignored.
//' @param smart_cold_start Logical. If TRUE, use an initial OLS-based guess when starting from scratch (a "cold start") with no prior knowledge. This is ignored if a warm start is provided.
//' @param start_phi Starting value for the precision parameter \eqn{\phi} (natural scale).
//' @param compute_std_errs Deprecated; standard errors are always computed by this
//'   entry point regardless of this argument's value.
//' @param fixed_idx Optional integer indices (into the \code{c(beta, log(phi))}
//'   parameter layout) of parameters to hold fixed rather than estimate.
//' @param fixed_values Optional values to fix the parameters named by
//'   \code{fixed_idx} at.
//' @param optimization_alg Optimization algorithm; see
//'   \code{\link{fast_beta_regression_cpp}}.
//' @return A list with components \code{coefficients} (\eqn{\hat\beta}),
//'   \code{phi} (\eqn{\hat\phi}), \code{neg_loglik}, \code{vcov} (the full
//'   \code{(p + 1) x (p + 1)} parameter variance-covariance matrix), \code{std_errs}
//'   (\code{sqrt(diag(vcov))}), \code{converged} (logical), and
//'   \code{fisher_information} (the working-weights curvature matrix \code{vcov} was
//'   inverted from).
//' @seealso \code{\link{fast_beta_regression_cpp}} for the estimate-only variant and
//'   the full model/parameterization documentation;
//'   \code{\link{fast_beta_regression_weighted_cpp}} for the row-weighted
//'   estimate-only variant.
//' @export
//' @keywords internal
//' @examples
//' X = matrix(rnorm(100), 10, 10)
//' y = runif(10)
//' fast_beta_regression_with_var_cpp(X, y)
// [[Rcpp::export]]
List fast_beta_regression_with_var_cpp(const Eigen::Map<Eigen::MatrixXd>& X, SEXP y, Nullable<NumericVector> warm_start_beta = R_NilValue, bool smart_cold_start = true, double start_phi = 10.0, bool compute_std_errs = true, Rcpp::Nullable<Rcpp::IntegerVector> fixed_idx = R_NilValue, Rcpp::Nullable<Rcpp::NumericVector> fixed_values = R_NilValue, std::string optimization_alg = "lbfgs", Rcpp::Nullable<Rcpp::NumericMatrix> warm_start_fisher_info = R_NilValue) {
	NumericVector y_r_coerced(y); Eigen::Map<const Eigen::VectorXd> y_vec_coerced(y_r_coerced.begin(), y_r_coerced.size());


    

    

    Eigen::VectorXd sb;
    Eigen::VectorXd* sb_ptr = nullptr;
    std::optional<Eigen::VectorXd> warm_start_beta_opt = nullable_to_optional<Eigen::VectorXd>(warm_start_beta);
    if (warm_start_beta_opt.has_value()) {
        sb = *warm_start_beta_opt;
        sb_ptr = &sb;
    }

    ModelResult fit = fast_beta_regression_internal(
        X, y_vec_coerced, nullptr, sb_ptr, smart_cold_start, start_phi,
        nullable_to_optional<Eigen::VectorXi>(fixed_idx),
        nullable_to_optional<Eigen::VectorXd>(fixed_values),
        optimization_alg,
        nullable_to_optional<Eigen::MatrixXd>(warm_start_fisher_info));
    FixedParamSpec fixed_spec = make_fixed_param_spec(
        X.cols() + 1,
        nullable_to_optional<Eigen::VectorXi>(fixed_idx),
        nullable_to_optional<Eigen::VectorXd>(fixed_values));
    Eigen::MatrixXd H_free = subset_matrix(fit.XtWX, fixed_spec.free_idx, fixed_spec.free_idx);
	Eigen::MatrixXd cov_free = H_free.inverse();
    Eigen::MatrixXd cov_mat = expand_free_covariance(X.cols() + 1, fixed_spec, cov_free, true);
    Eigen::VectorXd se = cov_mat.diagonal().array().sqrt();

    Eigen::VectorXd params_full(fit.b.size() + 1);
    params_full.head(fit.b.size()) = fit.b;
    params_full[fit.b.size()] = std::log(fit.dispersion);
    BetaRegression fun_neg_ll(y_vec_coerced, X);
    Eigen::VectorXd dummy_grad(params_full.size());
    double neg_loglik = fun_neg_ll(params_full, dummy_grad);

	return edi::to_rcpp_list(edi::ResultMap()
		.set("coefficients", fit.b)
		.set("phi", fit.dispersion)
		.set("neg_loglik", neg_loglik)
		.set("vcov", cov_mat)
		.set("std_errs", se)
		.set("converged", fit.converged)
		.set("fisher_information", fit.XtWX));
	}
#endif // EDI_CORE_ONLY
