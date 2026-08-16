"""
EDI kernels (pybind11) -- compiled directly from R/EDI/src, no copies
"""
from __future__ import annotations
import collections.abc
import numpy
import numpy.typing
import typing
__all__: list[str] = ['dnorm_fast', 'fast_adjacent_category_logit', 'fast_atan', 'fast_beta_regression', 'fast_clayton_weibull_aft_optim', 'fast_clogit_plus_glmm', 'fast_continuation_ratio_regression', 'fast_coxph_regression', 'fast_cpoisson_combined', 'fast_dep_cens_transform_optim', 'fast_digamma', 'fast_dnbinom_mu', 'fast_erfc', 'fast_gaussian_lmm', 'fast_gehan_wilcox_stats', 'fast_hurdle_negbin', 'fast_hurdle_poisson_glmm', 'fast_identity_binomial_regression', 'fast_identity_binomial_regression_with_var', 'fast_lbeta', 'fast_lgamma', 'fast_log1pexp', 'fast_log_binomial_regression', 'fast_log_binomial_regression_with_var', 'fast_log_dnorm', 'fast_log_pnorm', 'fast_logistic_glmm', 'fast_logistic_regression', 'fast_logrank_stats', 'fast_neg_bin', 'fast_ols', 'fast_ordinal_cauchit_regression', 'fast_ordinal_clmm', 'fast_ordinal_cloglog_regression', 'fast_ordinal_glmm', 'fast_ordinal_probit_regression', 'fast_ordinal_regression', 'fast_pchisq_upper', 'fast_poisson_glmm', 'fast_poisson_regression', 'fast_probit_regression', 'fast_qnorm', 'fast_ridit_analysis', 'fast_robust_regression', 'fast_stereotype_logit', 'fast_stratified_coxph_regression', 'fast_trigamma', 'fast_truncated_negbin_count', 'fast_weibull_frailty', 'fast_weibull_regression_general', 'fast_zero_augmented_poisson', 'fast_zero_augmented_poisson_with_var', 'fast_zero_one_inflated_beta', 'fast_zinb', 'fast_zinb_with_var', 'gee_pairs_singletons', 'get_survival_stat_diff', 'mn_ci', 'mn_pvalue', 'newcombe_independent_ci', 'ols_hc2_post_fit', 'pnorm_fast', 'wilcox_hl_point_estimate']
def dnorm_fast(x: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"]) -> typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"]:
    """
    Vectorized standard normal PDF (elementwise). Matches scipy.stats.norm.pdf.
    """
def fast_adjacent_category_logit(X: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, n]", "flags.f_contiguous"], y: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], maxit: typing.SupportsInt | typing.SupportsIndex = 100, tol: typing.SupportsFloat | typing.SupportsIndex = 1e-08, smart_cold_start: bool = True, fixed_idx: typing.Annotated[numpy.typing.ArrayLike, numpy.int32, "[m, 1]"] | None = None, fixed_values: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, optimization_alg: str = 'lbfgs', warm_start_fisher_info: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, n]"] | None = None, warm_start_params: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, warm_start_beta: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None) -> dict:
    """
    Fast adjacent-category logit ordinal regression via L-BFGS. Parameters sourced from R/EDI/man/ documentation for fast_adjacent_category_logit_cpp (that function's y/K args are replaced here by a raw y this binding maps to 1..K internally).
    
    Parameters
    ----------
    X : ndarray
        A numeric matrix of predictors.
    y : ndarray
        A numeric vector of responses (categorical, at least 2 distinct observed
        levels); mapped to consecutive integers 1..K internally.
    maxit : int, default 100
        Maximum number of iterations.
    tol : float, default 1e-8
        Convergence tolerance.
    smart_cold_start : bool, default True
        If True, use an initial OLS-based guess when starting from scratch (a
        "cold start") with no prior knowledge. Ignored if a warm start is
        provided.
    fixed_idx : ndarray of int, optional
        Optional indices of fixed parameters.
    fixed_values : ndarray, optional
        Optional values for fixed parameters.
    optimization_alg : str, default "lbfgs"
        Optimization algorithm.
    warm_start_fisher_info : ndarray, optional
        Optional initial Fisher information matrix.
    warm_start_params : ndarray, optional
        Optional starting values for all parameters. If provided,
        smart_cold_start is ignored.
    warm_start_beta : ndarray, optional
        Optional starting values for coefficients. If provided,
        smart_cold_start is ignored.
    """
def fast_atan(x: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"]) -> typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"]:
    """
    Vectorized arctangent (elementwise, Cephes-style minimax approximation). Matches numpy.arctan.
    """
def fast_beta_regression(X: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, n]", "flags.f_contiguous"], y: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], weights: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, warm_start_beta: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, smart_cold_start: bool = True, start_phi: typing.SupportsFloat | typing.SupportsIndex = 10.0, fixed_idx: typing.Annotated[numpy.typing.ArrayLike, numpy.int32, "[m, 1]"] | None = None, fixed_values: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, optimization_alg: str = 'lbfgs', warm_start_fisher_info: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, n]"] | None = None, estimate_only: bool = False) -> dict:
    """
    Fast beta regression via L-BFGS. Returned 'b' is [beta, log_phi]. Parameters sourced from R/EDI/man/ documentation for fast_beta_regression_cpp/fast_beta_regression_weighted_cpp.
    
    Parameters
    ----------
    X : ndarray
        A numeric matrix of predictors.
    y : ndarray
        A numeric vector of responses (in (0, 1)).
    weights : ndarray, optional
        Optional nonnegative row weights; if provided, routes to the weighted
        fit backend.
    warm_start_beta : ndarray, optional
        Optional starting values for coefficients. If provided,
        smart_cold_start is ignored.
    smart_cold_start : bool, default True
        If True, use an initial OLS-based guess when starting from scratch (a
        "cold start") with no prior knowledge. Ignored if a warm start is
        provided.
    start_phi : float, default 10.0
        Optional starting value for the precision parameter phi.
    fixed_idx : ndarray of int, optional
        Optional indices of fixed parameters.
    fixed_values : ndarray, optional
        Optional values for fixed parameters.
    optimization_alg : str, default "lbfgs"
        Optimization algorithm.
    warm_start_fisher_info : ndarray, optional
        Optional initial Fisher information matrix.
    estimate_only : bool, default False
        If True, skip Fisher information / variance calculation.
    """
def fast_clayton_weibull_aft_optim(X: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, n]", "flags.f_contiguous"], y: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], dead: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], pair_idx: typing.Annotated[numpy.typing.NDArray[numpy.int32], "[m, n]", "flags.f_contiguous"], singleton_rows: typing.Annotated[numpy.typing.NDArray[numpy.int32], "[m, 1]"], warm_start_params: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], estimate_only: bool = False, maxit: typing.SupportsInt | typing.SupportsIndex = 2000, reltol: typing.SupportsFloat | typing.SupportsIndex = 1e-09, fixed_idx: typing.Annotated[numpy.typing.ArrayLike, numpy.int32, "[m, 1]"] | None = None, fixed_values: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, optimization_alg: str = 'lbfgs', warm_start_fisher_info: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, n]"] | None = None) -> dict:
    """
    Fast Clayton-copula Weibull AFT regression (matched pairs + singleton reservoir design) via L-BFGS. pair_idx: 0-based (n_pairs x 2) row indices into X/y/dead; singleton_rows: 0-based row indices of reservoir singletons. warm_start_params is required (no default cold start). No R-side roxygen documents this raw kernel directly (fast_survival_models_optim.cpp has none).
    
    Parameters
    ----------
    X : ndarray
        A numeric matrix of predictors.
    y : ndarray
        A numeric vector of survival/censoring times.
    dead : ndarray
        0/1 event indicator (1 = event, 0 = censored).
    pair_idx : ndarray of int
        0-based (n_pairs, 2) matrix of row indices into X/y/dead identifying
        each Clayton-copula-dependent matched pair.
    singleton_rows : ndarray of int
        0-based row indices of reservoir subjects not in any pair (treated as
        independent).
    warm_start_params : ndarray
        Required starting values for all parameters (no default cold start is
        implemented for this kernel).
    estimate_only : bool, default False
        If True, skip variance-covariance computation and return only
        coefficients.
    maxit : int, default 2000
        Maximum number of iterations.
    reltol : float, default 1e-9
        Relative convergence tolerance.
    fixed_idx : ndarray of int, optional
        Optional indices of fixed parameters.
    fixed_values : ndarray, optional
        Optional values for fixed parameters.
    optimization_alg : str, default "lbfgs"
        Optimization algorithm.
    warm_start_fisher_info : ndarray, optional
        Optional initial Fisher information matrix for the first iteration.
    """
def fast_clogit_plus_glmm(X_disc: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, n]", "flags.f_contiguous"], y_disc: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], X_conc: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, n]", "flags.f_contiguous"], y_conc: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], group_conc: typing.Annotated[numpy.typing.NDArray[numpy.int32], "[m, 1]"], has_discordant: bool, has_concordant: bool, warm_start_params: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, warm_start_beta: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, estimate_only: bool = False, max_abs_log_sigma: typing.SupportsFloat | typing.SupportsIndex = 8.0, maxit: typing.SupportsInt | typing.SupportsIndex = 200, eps_g: typing.SupportsFloat | typing.SupportsIndex = 1e-05, fixed_idx: typing.Annotated[numpy.typing.ArrayLike, numpy.int32, "[m, 1]"] | None = None, fixed_values: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, optimization_alg: str = 'lbfgs', warm_start_fisher_info: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, n]"] | None = None, n_gh: typing.SupportsInt | typing.SupportsIndex = 20) -> dict:
    """
    Fit a combined conditional-logit (discordant pairs) + random-intercept-GLMM (concordant pairs) model via Gauss-Hermite quadrature + L-BFGS, for KK matched-pair-plus-reservoir designs. No R-side roxygen documents this raw kernel directly (fast_clogit_plus_glmm.cpp has none); shared parameter meanings are grounded in R/EDI/man/ documentation for the sibling fast_ordinal_glmm_cpp.
    
    Parameters
    ----------
    X_disc : ndarray
        Predictor matrix for the discordant (matched-pair) subjects.
    y_disc : ndarray
        Response vector for the discordant subjects.
    X_conc : ndarray
        Predictor matrix for the concordant (reservoir) subjects.
    y_conc : ndarray
        Response vector for the concordant subjects.
    group_conc : ndarray of int
        Group (random-intercept cluster) identifiers for the concordant subjects.
    has_discordant : bool
        Whether any discordant pairs are present (enables the conditional-logit
        component).
    has_concordant : bool
        Whether any concordant/reservoir subjects are present (enables the
        random-intercept-GLMM component).
    warm_start_params : ndarray, optional
        Optional starting values for all parameters. If provided,
        smart_cold_start is ignored.
    warm_start_beta : ndarray, optional
        Optional starting values for the coefficients only.
    estimate_only : bool, default False
        If True, skip variance-component calculations.
    max_abs_log_sigma : float, default 8.0
        Maximum allowed value for log(sigma) (the random-intercept SD), bounding
        the optimizer away from a degenerate/unbounded variance-component
        estimate.
    maxit : int, default 200
        Maximum number of iterations.
    eps_g : float, default 1e-5
        Convergence tolerance for the gradient.
    fixed_idx : ndarray of int, optional
        Optional indices of fixed parameters.
    fixed_values : ndarray, optional
        Optional values for fixed parameters.
    optimization_alg : str, default "lbfgs"
        Optimization algorithm.
    warm_start_fisher_info : ndarray, optional
        Optional initial Fisher information matrix for the first iteration.
    n_gh : int, default 20
        Number of Gauss-Hermite quadrature nodes used to integrate out the random
        intercept.
    """
def fast_continuation_ratio_regression(X: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, n]", "flags.f_contiguous"], y: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], maxit: typing.SupportsInt | typing.SupportsIndex = 100, tol: typing.SupportsFloat | typing.SupportsIndex = 1e-08, warm_start_beta: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, smart_cold_start: bool = True, fixed_idx: typing.Annotated[numpy.typing.ArrayLike, numpy.int32, "[m, 1]"] | None = None, fixed_values: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, optimization_alg: str = 'lbfgs', warm_start_fisher_info: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, n]"] | None = None) -> dict:
    """
    Fast continuation-ratio ordinal logit regression via L-BFGS. Parameters sourced from R/EDI/man/ documentation for fast_continuation_ratio_regression_cpp.
    
    Parameters
    ----------
    X : ndarray
        A numeric matrix of predictors (no intercept column; threshold
        intercepts are estimated internally).
    y : ndarray
        A numeric vector of ordinal responses.
    maxit : int, default 100
        Maximum number of iterations.
    tol : float, default 1e-8
        Convergence tolerance.
    warm_start_beta : ndarray, optional
        Optional starting values for coefficients.
    smart_cold_start : bool, default True
        If True, use an initial OLS-based guess when no warm start is provided.
    fixed_idx : ndarray of int, optional
        Optional indices of fixed parameters.
    fixed_values : ndarray, optional
        Optional values for fixed parameters.
    optimization_alg : str, default "lbfgs"
        Optimization algorithm.
    warm_start_fisher_info : ndarray, optional
        Optional initial Fisher information matrix.
    """
def fast_coxph_regression(X: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, n]", "flags.f_contiguous"], y: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], dead: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], warm_start_beta: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, smart_cold_start: bool = True, estimate_only: bool = False, maxit: typing.SupportsInt | typing.SupportsIndex = 20, tol: typing.SupportsFloat | typing.SupportsIndex = 1e-09, fixed_idx: typing.Annotated[numpy.typing.ArrayLike, numpy.int32, "[m, 1]"] | None = None, fixed_values: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, optimization_alg: str = 'newton_raphson', warm_start_fisher_info: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, n]"] | None = None) -> dict:
    """
    Fast Cox proportional-hazards regression via Newton-Raphson (unstratified, no cluster-robust vcov). No R-side roxygen documents this raw kernel directly (fast_coxph_regression.cpp's roxygen documents a bootstrap helper, not this fit function); parameters follow the same conventions used throughout this module.
    
    Parameters
    ----------
    X : ndarray
        Numeric matrix of predictors (no intercept column -- Cox regression is
        fit on the partial likelihood, which has none).
    y : ndarray
        Numeric vector of survival/censoring times.
    dead : ndarray
        0/1 event indicator (1 = event, 0 = censored), same length as y.
    warm_start_beta : ndarray, optional
        Optional starting values for coefficients. If provided,
        smart_cold_start is ignored.
    smart_cold_start : bool, default True
        If True, use an initial OLS-based guess when starting from scratch. Ignored
        if a warm start is provided.
    estimate_only : bool, default False
        If True, skip variance-covariance computation and return only
        coefficients.
    maxit : int, default 20
        Maximum number of Newton-Raphson iterations.
    tol : float, default 1e-9
        Convergence tolerance.
    fixed_idx : ndarray of int, optional
        Optional indices of fixed parameters.
    fixed_values : ndarray, optional
        Optional values for fixed parameters.
    optimization_alg : str, default "newton_raphson"
        Optimization algorithm.
    warm_start_fisher_info : ndarray, optional
        Optional initial Fisher information matrix for the first iteration.
    """
def fast_cpoisson_combined(yT_v: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], n_k_v: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], X_diff_v: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, n]", "flags.f_contiguous"], y_r: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], w_r: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], X_r: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, n]", "flags.f_contiguous"], maxit: typing.SupportsInt | typing.SupportsIndex = 100, tol: typing.SupportsFloat | typing.SupportsIndex = 1e-08, fixed_idx: typing.Annotated[numpy.typing.ArrayLike, numpy.int32, "[m, 1]"] | None = None, fixed_values: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, warm_start_fisher_info: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, n]"] | None = None, warm_start_params: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, warm_start_beta: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, estimate_only: bool = False) -> dict:
    """
    Fast combined conditional-Poisson (matched valid pairs) + Poisson (reservoir singletons) regression via Newton's method for KK designs. No R-side roxygen documents this raw fit kernel directly (fast_cpoisson_combined.cpp's roxygen documents the Hessian helper get_cpoisson_combined_hessian_cpp, whose argument names/meanings match the ones below).
    
    Parameters
    ----------
    yT_v : ndarray
        Treated-subject counts, one per matched pair.
    n_k_v : ndarray
        Total (treated + control) counts, one per matched pair.
    X_diff_v : ndarray
        Matrix of covariate differences between the treated and control member of
        each matched pair.
    y_r : ndarray
        Outcome counts for the unmatched reservoir subjects.
    w_r : ndarray
        0/1 treatment indicators for the reservoir subjects.
    X_r : ndarray
        Covariate matrix for the reservoir subjects.
    maxit : int, default 100
        Maximum number of Newton iterations.
    tol : float, default 1e-8
        Convergence tolerance.
    fixed_idx : ndarray of int, optional
        Optional indices of fixed parameters.
    fixed_values : ndarray, optional
        Optional values for fixed parameters.
    warm_start_fisher_info : ndarray, optional
        Optional initial Fisher information matrix for the first iteration.
    warm_start_params : ndarray, optional
        Optional starting values for all parameters.
    warm_start_beta : ndarray, optional
        Optional starting values for coefficients only.
    estimate_only : bool, default False
        If True, skip variance-covariance computation and return only
        coefficients.
    """
def fast_dep_cens_transform_optim(X: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, n]", "flags.f_contiguous"], y: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], dead: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], warm_start_params: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, smart_cold_start: bool = True, estimate_only: bool = False, maxit: typing.SupportsInt | typing.SupportsIndex = 2000, reltol: typing.SupportsFloat | typing.SupportsIndex = 1e-09, fixed_idx: typing.Annotated[numpy.typing.ArrayLike, numpy.int32, "[m, 1]"] | None = None, fixed_values: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, optimization_alg: str = 'lbfgs', warm_start_fisher_info: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, n]"] | None = None) -> dict:
    """
    Fast dependent-censoring transformation-model regression via L-BFGS. No R-side roxygen documents this raw kernel directly (fast_survival_models_optim.cpp has none); parameters follow the same conventions used throughout this module.
    
    Parameters
    ----------
    X : ndarray
        A numeric matrix of predictors.
    y : ndarray
        A numeric vector of survival/censoring times.
    dead : ndarray
        0/1 event indicator (1 = event, 0 = censored).
    warm_start_params : ndarray, optional
        Optional starting values for all parameters. If provided,
        smart_cold_start is ignored.
    smart_cold_start : bool, default True
        If True, use an initial OLS-based guess when starting from scratch. Ignored
        if a warm start is provided.
    estimate_only : bool, default False
        If True, skip variance-covariance computation and return only
        coefficients.
    maxit : int, default 2000
        Maximum number of iterations.
    reltol : float, default 1e-9
        Relative convergence tolerance.
    fixed_idx : ndarray of int, optional
        Optional indices of fixed parameters.
    fixed_values : ndarray, optional
        Optional values for fixed parameters.
    optimization_alg : str, default "lbfgs"
        Optimization algorithm.
    warm_start_fisher_info : ndarray, optional
        Optional initial Fisher information matrix for the first iteration.
    """
def fast_digamma(x: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"]) -> typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"]:
    """
    Vectorized digamma (elementwise). Matches scipy.special.digamma.
    """
def fast_dnbinom_mu(x: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], size: typing.SupportsFloat | typing.SupportsIndex, mu: typing.SupportsFloat | typing.SupportsIndex, return_log: bool = False) -> typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"]:
    """
    Vectorized (elementwise, fixed size/mu) mean-parameterized negative-binomial density. Matches scipy.stats.nbinom.logpmf(x, size, size/(size+mu)) when return_log=True.
    """
def fast_erfc(x: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"]) -> typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"]:
    """
    Vectorized complementary error function (elementwise). Matches scipy.special.erfc.
    """
def fast_gaussian_lmm(X: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, n]", "flags.f_contiguous"], y: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], group_id: typing.Annotated[numpy.typing.NDArray[numpy.int32], "[m, 1]"], warm_start_params: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, warm_start_beta: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, estimate_only: bool = False, maxit: typing.SupportsInt | typing.SupportsIndex = 300, eps_g: typing.SupportsFloat | typing.SupportsIndex = 1e-06, fixed_idx: typing.Annotated[numpy.typing.ArrayLike, numpy.int32, "[m, 1]"] | None = None, fixed_values: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, optimization_alg: str = 'lbfgs', warm_start_fisher_info: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, n]"] | None = None, weights: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None) -> dict:
    """
    Fit a Gaussian LMM with a random intercept via L-BFGS. Returned 'b' is [beta, log_sigma_e, log_sigma_b] (plain array, not R's named vector). No R-side roxygen documents this raw kernel directly (fast_gaussian_lmm.cpp has none); shared parameter meanings are grounded in R/EDI/man/ documentation for the sibling fast_ordinal_glmm_cpp.
    
    Parameters
    ----------
    X : ndarray
        Numeric matrix of predictors (no intercept column).
    y : ndarray
        Numeric vector of continuous responses.
    group_id : ndarray of int
        Group (random-intercept cluster) identifiers, one per row of X/y.
    warm_start_params : ndarray, optional
        Optional starting values for all parameters [beta, log_sigma_e,
        log_sigma_b].
    warm_start_beta : ndarray, optional
        Optional starting values for the fixed-effect coefficients only.
    estimate_only : bool, default False
        If True, skip variance-component calculations.
    maxit : int, default 300
        Maximum number of iterations.
    eps_g : float, default 1e-6
        Convergence tolerance for the gradient.
    fixed_idx : ndarray of int, optional
        Optional indices of fixed parameters.
    fixed_values : ndarray, optional
        Optional values for fixed parameters.
    optimization_alg : str, default "lbfgs"
        Optimization algorithm.
    warm_start_fisher_info : ndarray, optional
        Optional initial Fisher information matrix for the first iteration.
    weights : ndarray, optional
        Optional nonnegative row weights for a weighted fit.
    """
def fast_gehan_wilcox_stats(time: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], dead: collections.abc.Sequence[typing.SupportsInt | typing.SupportsIndex], w: collections.abc.Sequence[typing.SupportsInt | typing.SupportsIndex]) -> dict:
    """
    Peto-Prentice (Gehan-Wilcoxon, rho=1) two-sample survival test. dead/w are 0/1 vectors (event indicator / treatment indicator). Returns score, var_score (Peto-Prentice-weighted logrank score/variance), beta_hat (treatment-minus-control mean of Peto-Prentice-weighted martingale residuals -- the point estimate), se_beta_hat, n_treat, n_control. No R-side roxygen documents this raw kernel directly (fast_gehan_wilcox.cpp has none).
    
    Parameters
    ----------
    time : ndarray
        Numeric vector of survival/censoring times.
    dead : list of int
        0/1 event indicator (1 = event, 0 = censored), same length as time.
    w : list of int
        0/1 treatment indicator, same length as time.
    """
def fast_hurdle_negbin(X: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, n]", "flags.f_contiguous"], y: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], X_hurdle: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, n]", "flags.f_contiguous"], warm_start_params: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, smart_cold_start: bool = True, maxit: typing.SupportsInt | typing.SupportsIndex = 1000, tol: typing.SupportsFloat | typing.SupportsIndex = 1e-08, fixed_idx: typing.Annotated[numpy.typing.ArrayLike, numpy.int32, "[m, 1]"] | None = None, fixed_values: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, optimization_alg: str = 'lbfgs', warm_start_fisher_info: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, n]"] | None = None, warm_start_hurdle_fisher_info: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, n]"] | None = None, estimate_only: bool = False, j: typing.SupportsInt | typing.SupportsIndex = 2) -> dict:
    """
    Fast hurdle negative binomial regression via L-BFGS (count part + logistic hurdle part). Unifies the plain-fit and with-variance R exports: vcov/ssq_b_j (for parameter index j) are always computed when !estimate_only. Parameters sourced from R/EDI/man/ documentation for fast_hurdle_negbin_with_var_cpp (X_r/y_r/X_hurdle_r there correspond to X/y/X_hurdle here).
    
    Parameters
    ----------
    X : ndarray
        Matrix of predictors for the count component.
    y : ndarray
        Vector of count responses.
    X_hurdle : ndarray
        Matrix of predictors for the hurdle (zero/positive) component.
    warm_start_params : ndarray, optional
        Optional starting values for count parameters. If provided,
        smart_cold_start is ignored.
    smart_cold_start : bool, default True
        If True, use an initial OLS-based guess when starting from scratch (a
        "cold start") with no prior knowledge. Ignored if a warm start is
        provided.
    maxit : int, default 1000
        Maximum number of iterations.
    tol : float, default 1e-8
        Convergence tolerance.
    fixed_idx : ndarray of int, optional
        Optional indices of fixed parameters.
    fixed_values : ndarray, optional
        Optional values for fixed parameters.
    optimization_alg : str, default "lbfgs"
        Optimization algorithm.
    warm_start_fisher_info : ndarray, optional
        Optional initial Fisher information matrix for the count component's first
        iteration.
    warm_start_hurdle_fisher_info : ndarray, optional
        Optional initial Fisher information matrix for the hurdle component's
        first iteration.
    estimate_only : bool, default False
        If True, skip variance-covariance computation and return only
        coefficients.
    j : int, default 2
        1-based index of the count-component coefficient whose individual
        variance (ssq_b_j) is returned.
    """
def fast_hurdle_poisson_glmm(X: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, n]", "flags.f_contiguous"], y: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], group_id: typing.Annotated[numpy.typing.NDArray[numpy.int32], "[m, 1]"], j_T: typing.SupportsInt | typing.SupportsIndex, warm_start_params: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, smart_cold_start: bool = True, estimate_only: bool = False, n_gh: typing.SupportsInt | typing.SupportsIndex = 7, maxit: typing.SupportsInt | typing.SupportsIndex = 300, eps_g: typing.SupportsFloat | typing.SupportsIndex = 1e-06, optimization_alg: str = 'lbfgs', fixed_idx: typing.Annotated[numpy.typing.ArrayLike, numpy.int32, "[m, 1]"] | None = None, fixed_values: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, warm_start_fisher_info: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, n]"] | None = None) -> dict:
    """
    Fit a Hurdle-Poisson GLMM with a random intercept via Gauss-Hermite quadrature + L-BFGS. No R-side roxygen documents this raw kernel directly (fast_hurdle_poisson_glmm.cpp has none); parameter meanings are grounded in R/EDI/man/ documentation for the sibling fast_ordinal_glmm_cpp, which uses the same GLMM engine.
    
    Parameters
    ----------
    X : ndarray
        Numeric matrix of predictors (no intercept column).
    y : ndarray
        Numeric vector of count responses.
    group_id : ndarray of int
        Group (random-intercept cluster) identifiers, one per row of X/y.
    j_T : int
        0-based index of the treatment effect in the beta vector.
    warm_start_params : ndarray, optional
        Optional starting values for all parameters. If provided,
        smart_cold_start is ignored.
    smart_cold_start : bool, default True
        If True, use an initial OLS-based guess when starting from scratch. Ignored
        if a warm start is provided.
    estimate_only : bool, default False
        If True, skip variance-component calculations.
    n_gh : int, default 7
        Number of Gauss-Hermite quadrature nodes used to integrate out the random
        intercept.
    maxit : int, default 300
        Maximum number of iterations.
    eps_g : float, default 1e-6
        Convergence tolerance for the gradient.
    optimization_alg : str, default "lbfgs"
        Optimization algorithm.
    fixed_idx : ndarray of int, optional
        Optional indices of fixed parameters.
    fixed_values : ndarray, optional
        Optional values for fixed parameters.
    warm_start_fisher_info : ndarray, optional
        Optional initial Fisher information matrix for the first iteration.
    """
def fast_identity_binomial_regression(X: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, n]", "flags.f_contiguous"], y: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], weights: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, maxit: typing.SupportsInt | typing.SupportsIndex = 100, tol: typing.SupportsFloat | typing.SupportsIndex = 1e-06, fixed_idx: typing.Annotated[numpy.typing.ArrayLike, numpy.int32, "[m, 1]"] | None = None, fixed_values: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, warm_start_beta: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, smart_cold_start: bool = True, warm_start_weights: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, warm_start_fisher_info: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, n]"] | None = None, estimate_only: bool = False) -> dict:
    """
    Fast identity-link (risk-difference) binomial regression via Fisher scoring. Pass weights to fit the weighted variant.
    
    Parameters
    ----------
    X : ndarray
        Numeric matrix of predictors (including intercept column).
    y : ndarray
        Numeric vector of binary (0/1) responses.
    weights : ndarray, optional
        Optional nonnegative row weights; if provided, routes to the weighted
        fit backend.
    maxit : int, default 100
        Maximum number of iterations.
    tol : float, default 1e-6
        Convergence tolerance.
    fixed_idx : ndarray of int, optional
        Optional indices of coefficients to hold fixed at fixed_values rather
        than estimate.
    fixed_values : ndarray, optional
        Optional values for the fixed_idx coefficients.
    warm_start_beta : ndarray, optional
        Optional starting values for coefficients. If provided,
        smart_cold_start is ignored.
    smart_cold_start : bool, default True
        If True, use an initial OLS-based guess when starting from scratch.
        Ignored if a warm start is provided.
    warm_start_weights : ndarray, optional
        Optional initial working weights for the first iteration.
    warm_start_fisher_info : ndarray, optional
        Optional initial Fisher information matrix for the first iteration.
    estimate_only : bool, default False
        If True, skip variance-component calculations and return only the
        point estimate.
    """
def fast_identity_binomial_regression_with_var(X: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, n]", "flags.f_contiguous"], y: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], j: typing.SupportsInt | typing.SupportsIndex = 2, maxit: typing.SupportsInt | typing.SupportsIndex = 100, tol: typing.SupportsFloat | typing.SupportsIndex = 1e-06, fixed_idx: typing.Annotated[numpy.typing.ArrayLike, numpy.int32, "[m, 1]"] | None = None, fixed_values: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, warm_start_beta: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, smart_cold_start: bool = True, warm_start_weights: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, warm_start_fisher_info: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, n]"] | None = None) -> dict:
    """
    Fast identity-link binomial regression with full variance-covariance matrix (ssq_b_j is the variance of parameter index j).
    
    Parameters
    ----------
    X : ndarray
        Numeric matrix of predictors (including intercept column).
    y : ndarray
        Numeric vector of binary (0/1) responses.
    j : int, default 2
        1-based index of the coefficient whose individual variance (ssq_b_j)
        is returned.
    maxit : int, default 100
        Maximum number of iterations.
    tol : float, default 1e-6
        Convergence tolerance.
    fixed_idx : ndarray of int, optional
        Optional indices of coefficients to hold fixed at fixed_values rather
        than estimate.
    fixed_values : ndarray, optional
        Optional values for the fixed_idx coefficients.
    warm_start_beta : ndarray, optional
        Optional starting values for coefficients. If provided,
        smart_cold_start is ignored.
    smart_cold_start : bool, default True
        If True, use an initial OLS-based guess when starting from scratch.
        Ignored if a warm start is provided.
    warm_start_weights : ndarray, optional
        Optional initial working weights for the first iteration.
    warm_start_fisher_info : ndarray, optional
        Optional initial Fisher information matrix for the first iteration.
    """
def fast_lbeta(a: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], b: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"]) -> typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"]:
    """
    Vectorized (elementwise) log-beta. Matches scipy.special.betaln.
    """
def fast_lgamma(x: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"]) -> typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"]:
    """
    Vectorized log-gamma (elementwise). Matches scipy.special.gammaln.
    """
def fast_log1pexp(x: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"]) -> typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"]:
    """
    Vectorized log(1+exp(x)) (elementwise). Matches numpy.logaddexp(0, x).
    """
def fast_log_binomial_regression(X: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, n]", "flags.f_contiguous"], y: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], weights: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, maxit: typing.SupportsInt | typing.SupportsIndex = 100, tol: typing.SupportsFloat | typing.SupportsIndex = 1e-06, fixed_idx: typing.Annotated[numpy.typing.ArrayLike, numpy.int32, "[m, 1]"] | None = None, fixed_values: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, warm_start_beta: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, smart_cold_start: bool = True, warm_start_weights: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, warm_start_fisher_info: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, n]"] | None = None, estimate_only: bool = False) -> dict:
    """
    Fast log-binomial (relative-risk) regression via Fisher scoring. Pass weights to fit the weighted variant.
    
    Parameters
    ----------
    X : ndarray
        Numeric matrix of predictors (including intercept column).
    y : ndarray
        Numeric vector of binary (0/1) responses.
    weights : ndarray, optional
        Optional nonnegative row weights; if provided, routes to the weighted
        fit backend.
    maxit : int, default 100
        Maximum number of iterations.
    tol : float, default 1e-6
        Convergence tolerance.
    fixed_idx : ndarray of int, optional
        Optional indices of coefficients to hold fixed at fixed_values rather
        than estimate.
    fixed_values : ndarray, optional
        Optional values for the fixed_idx coefficients.
    warm_start_beta : ndarray, optional
        Optional starting values for coefficients. If provided,
        smart_cold_start is ignored.
    smart_cold_start : bool, default True
        If True, use an initial OLS-based guess when starting from scratch.
        Ignored if a warm start is provided.
    warm_start_weights : ndarray, optional
        Optional initial working weights for the first iteration.
    warm_start_fisher_info : ndarray, optional
        Optional initial Fisher information matrix for the first iteration.
    estimate_only : bool, default False
        If True, skip variance-component calculations and return only the
        point estimate.
    """
def fast_log_binomial_regression_with_var(X: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, n]", "flags.f_contiguous"], y: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], j: typing.SupportsInt | typing.SupportsIndex = 2, maxit: typing.SupportsInt | typing.SupportsIndex = 100, tol: typing.SupportsFloat | typing.SupportsIndex = 1e-06, fixed_idx: typing.Annotated[numpy.typing.ArrayLike, numpy.int32, "[m, 1]"] | None = None, fixed_values: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, warm_start_beta: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, smart_cold_start: bool = True, warm_start_weights: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, warm_start_fisher_info: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, n]"] | None = None) -> dict:
    """
    Fast log-binomial regression with full variance-covariance matrix (ssq_b_j is the variance of parameter index j).
    
    Parameters
    ----------
    X : ndarray
        Numeric matrix of predictors (including intercept column).
    y : ndarray
        Numeric vector of binary (0/1) responses.
    j : int, default 2
        1-based index of the coefficient whose individual variance (ssq_b_j)
        is returned.
    maxit : int, default 100
        Maximum number of iterations.
    tol : float, default 1e-6
        Convergence tolerance.
    fixed_idx : ndarray of int, optional
        Optional indices of coefficients to hold fixed at fixed_values rather
        than estimate.
    fixed_values : ndarray, optional
        Optional values for the fixed_idx coefficients.
    warm_start_beta : ndarray, optional
        Optional starting values for coefficients. If provided,
        smart_cold_start is ignored.
    smart_cold_start : bool, default True
        If True, use an initial OLS-based guess when starting from scratch.
        Ignored if a warm start is provided.
    warm_start_weights : ndarray, optional
        Optional initial working weights for the first iteration.
    warm_start_fisher_info : ndarray, optional
        Optional initial Fisher information matrix for the first iteration.
    """
def fast_log_dnorm(x: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"]) -> typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"]:
    """
    Vectorized log standard normal PDF (elementwise). Matches scipy.stats.norm.logpdf.
    """
def fast_log_pnorm(x: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"]) -> typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"]:
    """
    Vectorized log standard normal CDF (elementwise). Matches scipy.stats.norm.logcdf.
    """
def fast_logistic_glmm(X: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, n]", "flags.f_contiguous"], y: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], group_id: typing.Annotated[numpy.typing.NDArray[numpy.int32], "[m, 1]"], j_T: typing.SupportsInt | typing.SupportsIndex, warm_start_params: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, smart_cold_start: bool = True, estimate_only: bool = False, n_gh: typing.SupportsInt | typing.SupportsIndex = 20, maxit: typing.SupportsInt | typing.SupportsIndex = 300, eps_g: typing.SupportsFloat | typing.SupportsIndex = 1e-06, optimization_alg: str = 'lbfgs', fixed_idx: typing.Annotated[numpy.typing.ArrayLike, numpy.int32, "[m, 1]"] | None = None, fixed_values: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, warm_start_fisher_info: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, n]"] | None = None) -> dict:
    """
    Fit a Logistic GLMM with a random intercept via Gauss-Hermite quadrature + L-BFGS. No R-side roxygen documents this raw kernel directly (fast_logistic_glmm.cpp has none) -- and unlike every other kernel in this module, this one currently has no R6 consumer class in R/EDI/R either (bound and working, but nothing in the R package calls it yet); parameter meanings are grounded in R/EDI/man/ documentation for the sibling fast_ordinal_glmm_cpp, which uses the same GLMM engine.
    
    Parameters
    ----------
    X : ndarray
        Numeric matrix of predictors (no intercept column).
    y : ndarray
        Numeric vector of binary (0/1) responses.
    group_id : ndarray of int
        Group (random-intercept cluster) identifiers, one per row of X/y.
    j_T : int
        0-based index of the treatment effect in the beta vector.
    warm_start_params : ndarray, optional
        Optional starting values for all parameters [beta, log_sigma]. If
        provided, smart_cold_start is ignored.
    smart_cold_start : bool, default True
        If True, use an initial OLS-based guess when starting from scratch. Ignored
        if a warm start is provided.
    estimate_only : bool, default False
        If True, skip variance-component calculations.
    n_gh : int, default 20
        Number of Gauss-Hermite quadrature nodes used to integrate out the random
        intercept.
    maxit : int, default 300
        Maximum number of iterations.
    eps_g : float, default 1e-6
        Convergence tolerance for the gradient.
    optimization_alg : str, default "lbfgs"
        Optimization algorithm.
    fixed_idx : ndarray of int, optional
        Optional indices of fixed parameters.
    fixed_values : ndarray, optional
        Optional values for fixed parameters.
    warm_start_fisher_info : ndarray, optional
        Optional initial Fisher information matrix for the first iteration.
    """
def fast_logistic_regression(X: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, n]", "flags.f_contiguous"], y: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], weights: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, warm_start_beta: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, smart_cold_start: bool = False, maxit: typing.SupportsInt | typing.SupportsIndex = 100, tol: typing.SupportsFloat | typing.SupportsIndex = 1e-08, fixed_idx: typing.Annotated[numpy.typing.ArrayLike, numpy.int32, "[m, 1]"] | None = None, fixed_values: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, optimization_alg: str = 'irls', warm_start_weights: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, warm_start_fisher_info: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, n]"] | None = None, estimate_only: bool = False) -> dict:
    """
    Fast logistic regression via IRLS or L-BFGS. No R-side roxygen documents this raw kernel directly (fast_logistic_regression.cpp has none); parameter meanings are grounded in R/EDI/man/ documentation for the sibling fast_probit_regression_cpp, which shares the same argument list and IRLS/L-BFGS machinery.
    
    Parameters
    ----------
    X : ndarray
        Numeric matrix of predictors (including intercept column).
    y : ndarray
        Numeric vector of binary (0/1) responses.
    weights : ndarray, optional
        Optional nonnegative row weights for a weighted fit.
    warm_start_beta : ndarray, optional
        Optional starting values for coefficients.
    smart_cold_start : bool, default False
        If True, use an OLS-based initial guess when no warm start is provided.
    maxit : int, default 100
        Maximum number of iterations.
    tol : float, default 1e-8
        Convergence tolerance.
    fixed_idx : ndarray of int, optional
        Optional indices of fixed parameters.
    fixed_values : ndarray, optional
        Optional values for fixed parameters.
    optimization_alg : str, default "irls"
        Optimization algorithm ("irls" or "lbfgs").
    warm_start_weights : ndarray, optional
        Optional initial IRLS working weights.
    warm_start_fisher_info : ndarray, optional
        Optional initial Fisher information matrix.
    estimate_only : bool, default False
        If True, skip variance computation and return only coefficients.
    """
def fast_logrank_stats(time: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], dead: collections.abc.Sequence[typing.SupportsInt | typing.SupportsIndex], w: collections.abc.Sequence[typing.SupportsInt | typing.SupportsIndex]) -> dict:
    """
    Standard (rho=0) two-sample log-rank test. dead/w are 0/1 vectors (event indicator / treatment indicator). Returns score, var_score, beta_hat (treatment-minus-control mean of martingale residuals -- the point estimate), se_beta_hat, n_treat, n_control. No R-side roxygen documents this raw kernel directly (fast_logrank.cpp has none).
    
    Parameters
    ----------
    time : ndarray
        Numeric vector of survival/censoring times.
    dead : list of int
        0/1 event indicator (1 = event, 0 = censored), same length as time.
    w : list of int
        0/1 treatment indicator, same length as time.
    """
def fast_neg_bin(X: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, n]", "flags.f_contiguous"], y: typing.Annotated[numpy.typing.NDArray[numpy.int32], "[m, 1]"], warm_start_params: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, smart_cold_start: bool = False, maxit: typing.SupportsInt | typing.SupportsIndex = 1000, eps_g: typing.SupportsFloat | typing.SupportsIndex = 1e-06, fixed_idx: typing.Annotated[numpy.typing.ArrayLike, numpy.int32, "[m, 1]"] | None = None, fixed_values: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, optimization_alg: str = 'lbfgs', warm_start_fisher_info: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, n]"] | None = None, estimate_only: bool = False, weights: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None) -> dict:
    """
    Fast negative binomial regression via L-BFGS. Parameters sourced from R/EDI/man/fast_neg_bin_cpp.Rd.
    
    Parameters
    ----------
    X : ndarray
        Numeric matrix of predictors.
    y : ndarray of int
        Numeric vector of non-negative integer count responses.
    warm_start_params : ndarray, optional
        Optional starting values for coefficients and dispersion (log_theta). If
        provided, smart_cold_start is ignored.
    smart_cold_start : bool, default False
        If True, use an initial OLS-based guess when starting from scratch (a
        "cold start") with no prior knowledge. Ignored if a warm start is
        provided.
    maxit : int, default 1000
        Maximum number of iterations.
    eps_g : float, default 1e-6
        Convergence tolerance for the gradient.
    fixed_idx : ndarray of int, optional
        Optional indices of fixed parameters.
    fixed_values : ndarray, optional
        Optional values for fixed parameters.
    optimization_alg : str, default "lbfgs"
        Optimization algorithm.
    warm_start_fisher_info : ndarray, optional
        Optional initial Fisher information matrix for the first iteration.
    estimate_only : bool, default False
        If True, skip variance computation and return only coefficients.
    weights : ndarray, optional
        Optional nonnegative row weights for a weighted fit (routes to the
        R-side fast_neg_bin_weighted_cpp backend when provided).
    """
def fast_ols(X: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, n]", "flags.f_contiguous"], y: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], fixed_idx: typing.Annotated[numpy.typing.ArrayLike, numpy.int32, "[m, 1]"] | None = None, fixed_values: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, estimate_only: bool = True) -> dict:
    """
    Fast closed-form OLS regression (coefficients only unless estimate_only=False, which also returns XtWX). No R-side roxygen documents this raw kernel directly (fast_ols_cpp has none); parameters follow the same fixed_idx/fixed_values convention used throughout this module.
    
    Parameters
    ----------
    X : ndarray
        Numeric design matrix of predictors (including an intercept column if one
        is wanted -- this kernel does not add one implicitly).
    y : ndarray
        Numeric vector of continuous responses.
    fixed_idx : ndarray of int, optional
        0-based indices of coefficients to hold fixed at fixed_values rather than
        estimate, instead of dropping those columns from X entirely. Must be paired
        with fixed_values (both or neither).
    fixed_values : ndarray, optional
        Values to hold the fixed_idx coefficients at; y is adjusted for their
        contribution before the remaining (free) coefficients are estimated.
    estimate_only : bool, default True
        If True, skip computing XtWX (the crossproduct needed for standard errors)
        and return only the coefficient vector -- faster when only a point estimate
        is needed.
    """
def fast_ordinal_cauchit_regression(X: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, n]", "flags.f_contiguous"], y: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], warm_start_params: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, smart_cold_start: bool = True, maxit: typing.SupportsInt | typing.SupportsIndex = 100, tol: typing.SupportsFloat | typing.SupportsIndex = 1e-06, optimization_alg: str = 'lbfgs', fixed_idx: typing.Annotated[numpy.typing.ArrayLike, numpy.int32, "[m, 1]"] | None = None, fixed_values: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, warm_start_fisher_info: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, n]"] | None = None, estimate_only: bool = False) -> dict:
    """
    Fast proportional-odds (cauchit link) ordinal regression via Newton-Raphson/L-BFGS. Returns an empty dict if the outcome has fewer than 2 observed categories. Parameters sourced from R/EDI/man/ documentation for fast_ordinal_cauchit_regression_cpp.
    
    Parameters
    ----------
    X : ndarray
        A numeric matrix of predictors.
    y : ndarray
        A numeric vector of responses.
    warm_start_params : ndarray, optional
        Optional starting values for [alpha, beta]. If provided,
        smart_cold_start is ignored.
    smart_cold_start : bool, default True
        If True, use an initial OLS-based guess when starting from scratch. Ignored
        if a warm start is provided.
    maxit : int, default 100
        Maximum number of iterations.
    tol : float, default 1e-6
        Convergence tolerance.
    optimization_alg : str, default "lbfgs"
        Optimization algorithm.
    fixed_idx : ndarray of int, optional
        Optional indices of fixed parameters.
    fixed_values : ndarray, optional
        Optional values for fixed parameters.
    warm_start_fisher_info : ndarray, optional
        Optional initial Fisher information matrix for the first IRLS iteration.
    estimate_only : bool, default False
        If True, skip variance-component calculations.
    """
def fast_ordinal_clmm(X: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, n]", "flags.f_contiguous"], y: typing.Annotated[numpy.typing.NDArray[numpy.int32], "[m, 1]"], group_id: typing.Annotated[numpy.typing.NDArray[numpy.int32], "[m, 1]"], K: typing.SupportsInt | typing.SupportsIndex, j_T: typing.SupportsInt | typing.SupportsIndex, link: str = 'logit', estimate_only: bool = False, n_gh: typing.SupportsInt | typing.SupportsIndex = 20, max_abs_log_sigma: typing.SupportsFloat | typing.SupportsIndex = 8.0, maxit: typing.SupportsInt | typing.SupportsIndex = 300, eps_g: typing.SupportsFloat | typing.SupportsIndex = 1e-06, warm_start_params: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, optimization_alg: str = 'lbfgs', fixed_idx: typing.Annotated[numpy.typing.ArrayLike, numpy.int32, "[m, 1]"] | None = None, fixed_values: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, warm_start_fisher_info: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, n]"] | None = None) -> dict:
    """
    Fast proportional-odds ordinal GLMM (random intercept, Gauss-Hermite quadrature) via L-BFGS. link is one of 'logit', 'probit', 'cauchit', 'cloglog'. No R-side roxygen documents this raw kernel directly (fast_ordinal_clmm.cpp has none); shared parameter meanings are grounded in R/EDI/man/ documentation for the sibling fast_ordinal_glmm_cpp (same engine, fixed to the logit link).
    
    Parameters
    ----------
    X : ndarray
        A numeric matrix of predictors (no intercept).
    y : ndarray of int
        A numeric vector of ordinal responses (1, 2, ...).
    group_id : ndarray of int
        A numeric vector of group (random-intercept cluster) identifiers.
    K : int
        Number of ordinal levels.
    j_T : int
        0-based index of the treatment effect in the beta vector.
    link : str, default "logit"
        Cumulative link function: one of "logit", "probit", "cauchit",
        "cloglog".
    estimate_only : bool, default False
        If True, skip variance-component calculations.
    n_gh : int, default 20
        Number of Gauss-Hermite quadrature nodes used to integrate out the random
        intercept.
    max_abs_log_sigma : float, default 8.0
        Maximum allowed value for log(sigma).
    maxit : int, default 300
        Maximum number of iterations.
    eps_g : float, default 1e-6
        Convergence tolerance for the gradient.
    warm_start_params : ndarray, optional
        Optional starting values for all parameters [alpha, beta, log_sigma]. If
        provided, smart_cold_start is ignored.
    optimization_alg : str, default "lbfgs"
        Optimization algorithm.
    fixed_idx : ndarray of int, optional
        Optional indices of fixed parameters.
    fixed_values : ndarray, optional
        Optional values for fixed parameters.
    warm_start_fisher_info : ndarray, optional
        Optional initial Fisher information matrix for the first iteration.
    """
def fast_ordinal_cloglog_regression(X: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, n]", "flags.f_contiguous"], y: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], warm_start_params: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, smart_cold_start: bool = True, maxit: typing.SupportsInt | typing.SupportsIndex = 100, tol: typing.SupportsFloat | typing.SupportsIndex = 1e-06, optimization_alg: str = 'lbfgs', fixed_idx: typing.Annotated[numpy.typing.ArrayLike, numpy.int32, "[m, 1]"] | None = None, fixed_values: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, warm_start_fisher_info: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, n]"] | None = None, estimate_only: bool = False) -> dict:
    """
    Fast proportional-odds (cloglog link) ordinal regression via Newton-Raphson/L-BFGS. Returns an empty dict if the outcome has fewer than 2 observed categories. Parameters sourced from R/EDI/man/ documentation for fast_ordinal_cloglog_regression_cpp.
    
    Parameters
    ----------
    X : ndarray
        A numeric matrix of predictors.
    y : ndarray
        A numeric vector of responses.
    warm_start_params : ndarray, optional
        Optional starting values for [alpha, beta]. If provided,
        smart_cold_start is ignored.
    smart_cold_start : bool, default True
        If True, use an initial OLS-based guess when starting from scratch. Ignored
        if a warm start is provided.
    maxit : int, default 100
        Maximum number of iterations.
    tol : float, default 1e-6
        Convergence tolerance.
    optimization_alg : str, default "lbfgs"
        Optimization algorithm.
    fixed_idx : ndarray of int, optional
        Optional indices of fixed parameters.
    fixed_values : ndarray, optional
        Optional values for fixed parameters.
    warm_start_fisher_info : ndarray, optional
        Optional initial Fisher information matrix for the first IRLS iteration.
    estimate_only : bool, default False
        If True, skip variance-component calculations.
    """
def fast_ordinal_glmm(X: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, n]", "flags.f_contiguous"], y: typing.Annotated[numpy.typing.NDArray[numpy.int32], "[m, 1]"], group_id: typing.Annotated[numpy.typing.NDArray[numpy.int32], "[m, 1]"], K: typing.SupportsInt | typing.SupportsIndex, j_T: typing.SupportsInt | typing.SupportsIndex, smart_cold_start: bool = True, estimate_only: bool = False, n_gh: typing.SupportsInt | typing.SupportsIndex = 20, max_abs_log_sigma: typing.SupportsFloat | typing.SupportsIndex = 8.0, maxit: typing.SupportsInt | typing.SupportsIndex = 300, eps_g: typing.SupportsFloat | typing.SupportsIndex = 1e-06, warm_start_params: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, warm_start_beta: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, optimization_alg: str = 'lbfgs', fixed_idx: typing.Annotated[numpy.typing.ArrayLike, numpy.int32, "[m, 1]"] | None = None, fixed_values: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, warm_start_fisher_info: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, n]"] | None = None) -> dict:
    """
    Fast proportional-odds (logit link) ordinal GLMM with a random intercept via Gauss-Hermite quadrature + L-BFGS. X must NOT include an intercept column. Parameters sourced from R/EDI/man/ documentation for fast_ordinal_glmm_cpp.
    
    Parameters
    ----------
    X : ndarray
        A numeric matrix of predictors (no intercept).
    y : ndarray of int
        A numeric vector of ordinal responses (1, 2, ...).
    group_id : ndarray of int
        A numeric vector of group identifiers.
    K : int
        Number of ordinal levels.
    j_T : int
        0-based index of the treatment effect in the beta vector.
    smart_cold_start : bool, default True
        If True, use an initial OLS-based guess when starting from scratch (a
        "cold start") with no prior knowledge. Ignored if a warm start is
        provided.
    estimate_only : bool, default False
        If True, skip variance-component calculations.
    n_gh : int, default 20
        Number of Gauss-Hermite nodes.
    max_abs_log_sigma : float, default 8.0
        Maximum allowed value for log(sigma).
    maxit : int, default 300
        Maximum number of iterations.
    eps_g : float, default 1e-6
        Convergence tolerance.
    warm_start_params : ndarray, optional
        Optional starting values for all parameters [alpha, beta, log_sigma]. If
        provided, smart_cold_start is ignored.
    warm_start_beta : ndarray, optional
        Optional starting values for coefficients. If provided (and
        warm_start_params is not), smart_cold_start is ignored.
    optimization_alg : str, default "lbfgs"
        Optimization algorithm.
    fixed_idx : ndarray of int, optional
        Optional indices of fixed parameters.
    fixed_values : ndarray, optional
        Optional values for fixed parameters.
    warm_start_fisher_info : ndarray, optional
        Optional initial Fisher information matrix for the first iteration.
    """
def fast_ordinal_probit_regression(X: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, n]", "flags.f_contiguous"], y: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], warm_start_params: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, smart_cold_start: bool = True, maxit: typing.SupportsInt | typing.SupportsIndex = 100, tol: typing.SupportsFloat | typing.SupportsIndex = 1e-06, optimization_alg: str = 'lbfgs', fixed_idx: typing.Annotated[numpy.typing.ArrayLike, numpy.int32, "[m, 1]"] | None = None, fixed_values: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, warm_start_fisher_info: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, n]"] | None = None, estimate_only: bool = False) -> dict:
    """
    Fast proportional-odds (probit link) ordinal regression via Newton-Raphson/L-BFGS. Parameters sourced from R/EDI/man/ documentation for fast_ordinal_probit_regression_cpp.
    
    Parameters
    ----------
    X : ndarray
        A numeric matrix of predictors.
    y : ndarray
        A numeric vector of responses.
    warm_start_params : ndarray, optional
        Optional starting values for [alpha, beta]. If provided,
        smart_cold_start is ignored.
    smart_cold_start : bool, default True
        If True, use an initial OLS-based guess when starting from scratch. Ignored
        if a warm start is provided.
    maxit : int, default 100
        Maximum number of iterations.
    tol : float, default 1e-6
        Convergence tolerance.
    optimization_alg : str, default "lbfgs"
        Optimization algorithm.
    fixed_idx : ndarray of int, optional
        Optional indices of fixed parameters.
    fixed_values : ndarray, optional
        Optional values for fixed parameters.
    warm_start_fisher_info : ndarray, optional
        Optional initial Fisher information matrix for the first IRLS iteration.
    estimate_only : bool, default False
        If True, skip variance-component calculations.
    """
def fast_ordinal_regression(X: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, n]", "flags.f_contiguous"], y: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], weights: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, warm_start_params: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, smart_cold_start: bool = True, maxit: typing.SupportsInt | typing.SupportsIndex = 100, tol: typing.SupportsFloat | typing.SupportsIndex = 1e-06, fixed_idx: typing.Annotated[numpy.typing.ArrayLike, numpy.int32, "[m, 1]"] | None = None, fixed_values: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, optimization_alg: str = 'lbfgs', warm_start_fisher_info: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, n]"] | None = None, estimate_only: bool = False) -> dict:
    """
    Fast proportional-odds (logit link) ordinal regression via Newton-Raphson/L-BFGS. Returns vcov/ssq_b_j (variance of the first covariate after the alphas) whenever the Hessian is invertible and !estimate_only. Parameters sourced from R/EDI/man/ documentation for fast_ordinal_regression_cpp/fast_ordinal_regression_weighted_cpp.
    
    Parameters
    ----------
    X : ndarray
        A numeric matrix of predictors.
    y : ndarray
        A numeric vector of responses (ordinal categories 1, 2, ...).
    weights : ndarray, optional
        Optional nonnegative observation weights; if provided, routes to the
        weighted fit backend.
    warm_start_params : ndarray, optional
        Optional starting values for [alpha, beta]. If provided,
        smart_cold_start is ignored.
    smart_cold_start : bool, default True
        If True, use an initial OLS-based guess when starting from scratch (a
        "cold start") with no prior knowledge. Ignored if a warm start is
        provided.
    maxit : int, default 100
        Maximum number of iterations.
    tol : float, default 1e-6
        Convergence tolerance.
    fixed_idx : ndarray of int, optional
        Optional indices of fixed parameters.
    fixed_values : ndarray, optional
        Optional values for fixed parameters.
    optimization_alg : str, default "lbfgs"
        Optimization algorithm.
    warm_start_fisher_info : ndarray, optional
        Optional initial Fisher information matrix for the first IRLS iteration.
    estimate_only : bool, default False
        If True, skip variance-component calculations.
    """
@typing.overload
def fast_pchisq_upper(statistic: typing.SupportsFloat | typing.SupportsIndex, df: typing.SupportsFloat | typing.SupportsIndex) -> float:
    """
    Upper-tail chi-squared p-value P(X > statistic) for X ~ chi-squared(df). Matches R's pchisq(statistic, df, lower.tail=FALSE) / scipy.stats.chi2.sf(statistic, df).
    """
@typing.overload
def fast_pchisq_upper(statistic: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], df: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"]) -> typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"]:
    """
    Vectorized (elementwise) overload of fast_pchisq_upper.
    """
def fast_poisson_glmm(X: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, n]", "flags.f_contiguous"], y: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], group_id: typing.Annotated[numpy.typing.NDArray[numpy.int32], "[m, 1]"], j_T: typing.SupportsInt | typing.SupportsIndex, warm_start_params: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, smart_cold_start: bool = True, estimate_only: bool = False, n_gh: typing.SupportsInt | typing.SupportsIndex = 20, maxit: typing.SupportsInt | typing.SupportsIndex = 300, eps_g: typing.SupportsFloat | typing.SupportsIndex = 1e-06, fixed_idx: typing.Annotated[numpy.typing.ArrayLike, numpy.int32, "[m, 1]"] | None = None, fixed_values: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, optimization_alg: str = 'lbfgs', warm_start_fisher_info: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, n]"] | None = None, row_weights: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None) -> dict:
    """
    Fit a Poisson GLMM with a random intercept via Gauss-Hermite quadrature + L-BFGS. No R-side roxygen documents this raw kernel directly (fast_poisson_glmm.cpp has none); shared adaptive-quadrature parameter meanings (group_id/j_T/n_gh/etc.) are grounded in R/EDI/man/ documentation for the sibling fast_ordinal_glmm_cpp, which uses the same GLMM engine.
    
    Parameters
    ----------
    X : ndarray
        Numeric matrix of predictors (no intercept column).
    y : ndarray
        Numeric vector of count responses.
    group_id : ndarray of int
        Group (random-intercept cluster) identifiers, one per row of X/y.
    j_T : int
        0-based index of the treatment effect in the beta vector.
    warm_start_params : ndarray, optional
        Optional starting values for all parameters [beta, log_sigma]. If
        provided, smart_cold_start is ignored.
    smart_cold_start : bool, default True
        If True, use an initial OLS-based guess when starting from scratch. Ignored
        if a warm start is provided.
    estimate_only : bool, default False
        If True, skip variance-component calculations.
    n_gh : int, default 20
        Number of Gauss-Hermite quadrature nodes used to integrate out the random
        intercept.
    maxit : int, default 300
        Maximum number of iterations.
    eps_g : float, default 1e-6
        Convergence tolerance for the gradient.
    fixed_idx : ndarray of int, optional
        Optional indices of fixed parameters.
    fixed_values : ndarray, optional
        Optional values for fixed parameters.
    optimization_alg : str, default "lbfgs"
        Optimization algorithm.
    warm_start_fisher_info : ndarray, optional
        Optional initial Fisher information matrix for the first iteration.
    row_weights : ndarray, optional
        Optional nonnegative row weights for a weighted fit.
    """
def fast_poisson_regression(X: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, n]", "flags.f_contiguous"], y: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], weights: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, warm_start_beta: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, smart_cold_start: bool = False, maxit: typing.SupportsInt | typing.SupportsIndex = 100, tol: typing.SupportsFloat | typing.SupportsIndex = 1e-08, fixed_idx: typing.Annotated[numpy.typing.ArrayLike, numpy.int32, "[m, 1]"] | None = None, fixed_values: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, optimization_alg: str = 'irls', warm_start_weights: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, warm_start_fisher_info: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, n]"] | None = None, estimate_only: bool = False) -> dict:
    """
    Fast Poisson regression via IRLS or L-BFGS. No R-side roxygen documents this raw kernel directly (fast_poisson_regression.cpp has none); parameters follow the same conventions used throughout this module.
    
    Parameters
    ----------
    X : ndarray
        Numeric matrix of predictors (including intercept column where wanted).
    y : ndarray
        Numeric vector of non-negative integer count responses.
    weights : ndarray, optional
        Optional nonnegative row weights for a weighted fit.
    warm_start_beta : ndarray, optional
        Optional starting values for coefficients. If provided, smart_cold_start
        is ignored.
    smart_cold_start : bool, default False
        If True, use an initial OLS-based guess when starting from scratch. Ignored
        if a warm start is provided.
    maxit : int, default 100
        Maximum number of iterations.
    tol : float, default 1e-8
        Convergence tolerance.
    fixed_idx : ndarray of int, optional
        Optional indices of coefficients to hold fixed at fixed_values rather than
        estimate.
    fixed_values : ndarray, optional
        Optional values for the fixed_idx coefficients.
    optimization_alg : str, default "irls"
        Optimization algorithm ("irls" or "lbfgs").
    warm_start_weights : ndarray, optional
        Optional initial IRLS working weights for the first iteration.
    warm_start_fisher_info : ndarray, optional
        Optional initial Fisher information matrix for the first iteration.
    estimate_only : bool, default False
        If True, skip variance-component calculations and return only the point
        estimate.
    """
def fast_probit_regression(X: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, n]", "flags.f_contiguous"], y: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], weights: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, warm_start_beta: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, smart_cold_start: bool = True, maxit: typing.SupportsInt | typing.SupportsIndex = 100, tol: typing.SupportsFloat | typing.SupportsIndex = 1e-08, fixed_idx: typing.Annotated[numpy.typing.ArrayLike, numpy.int32, "[m, 1]"] | None = None, fixed_values: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, optimization_alg: str = 'irls', warm_start_weights: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, warm_start_fisher_info: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, n]"] | None = None, estimate_only: bool = False) -> dict:
    """
    Fast probit regression via IRLS or L-BFGS. Parameters sourced from R/EDI/man/ documentation for fast_probit_regression_cpp.
    
    Parameters
    ----------
    X : ndarray
        A numeric matrix of predictors (including intercept column).
    y : ndarray
        A numeric vector of binary responses (0/1).
    weights : ndarray, optional
        Optional nonnegative row weights for a weighted fit.
    warm_start_beta : ndarray, optional
        Optional starting values for coefficients.
    smart_cold_start : bool, default True
        If True, use an OLS-based initial guess when no warm start is provided.
    maxit : int, default 100
        Maximum number of iterations.
    tol : float, default 1e-8
        Convergence tolerance.
    fixed_idx : ndarray of int, optional
        Optional indices of fixed parameters.
    fixed_values : ndarray, optional
        Optional values for fixed parameters.
    optimization_alg : str, default "irls"
        Optimization algorithm ("irls" or "lbfgs").
    warm_start_weights : ndarray, optional
        Optional initial IRLS working weights.
    warm_start_fisher_info : ndarray, optional
        Optional initial Fisher information matrix.
    estimate_only : bool, default False
        If True, skip variance computation and return only coefficients.
    """
def fast_qnorm(p: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"]) -> typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"]:
    """
    Vectorized standard normal quantile (elementwise). Matches scipy.stats.norm.ppf.
    """
def fast_ridit_analysis(w: typing.Annotated[numpy.typing.NDArray[numpy.int32], "[m, 1]"], y: typing.Annotated[numpy.typing.NDArray[numpy.int32], "[m, 1]"], reference: str = 'control') -> dict:
    """
    Ridit analysis (Bross 1958): assigns each subject a ridit score relative to the empirical distribution of the reference group ('control', 'treatment', or 'pooled'), then compares treatment/control mean ridits. estimate = mean_ridit_t - 0.5 (centered at 0 under the null); se is the sample-variance-based SE of the treatment-arm mean ridit. No R-side roxygen documents this raw kernel directly (fast_ridit_analysis.cpp has none); parameters are named for their role in the algorithm above.
    
    Parameters
    ----------
    w : ndarray of int
        0/1 treatment indicator, one per subject.
    y : ndarray of int
        Ordinal category (1, 2, ...) for each subject.
    reference : str, default "control"
        Which group's empirical distribution defines the ridit scores: "control", "treatment", or "pooled".
    """
def fast_robust_regression(X: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, n]", "flags.f_contiguous"], y: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], warm_start_beta: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, smart_cold_start: bool = True, method: str = 'MM', j: typing.SupportsInt | typing.SupportsIndex = 2, c: typing.SupportsFloat | typing.SupportsIndex = 1.345, maxit: typing.SupportsInt | typing.SupportsIndex = 50, tol: typing.SupportsFloat | typing.SupportsIndex = 1e-07, fixed_idx: typing.Annotated[numpy.typing.ArrayLike, numpy.int32, "[m, 1]"] | None = None, fixed_values: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, warm_start_weights: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, warm_start_fisher_info: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, n]"] | None = None, estimate_only: bool = False) -> dict:
    """
    Robust regression via IRLS (Huber M or Huber-then-Tukey-bisquare MM-estimation). Parameters sourced from R/EDI/man/ documentation for fast_robust_regression_cpp.
    
    Parameters
    ----------
    X : ndarray
        Numeric matrix of predictors.
    y : ndarray
        Numeric vector of responses.
    warm_start_beta : ndarray, optional
        Optional starting values for coefficients. If provided, smart_cold_start is
        ignored.
    smart_cold_start : bool, default True
        If True, use an initial OLS-based guess when starting from scratch (a "cold
        start") with no prior knowledge. Ignored if a warm start is provided.
    method : str, default "MM"
        Robust estimation method: "M" (single-stage Huber M-estimation) or "MM"
        (S-then-M two-stage estimation, more resistant to high-leverage outliers).
    j : int, default 2
        1-based index of the coefficient for which to return an individual variance
        (ssq_b_j in the result).
    c : float, default 1.345
        Huber tuning constant (used for the M-step; the Tukey bisquare tuning
        constant for the MM-step's S-estimator is fixed internally at 4.685).
    maxit : int, default 50
        Maximum number of IRLS iterations.
    tol : float, default 1e-7
        Convergence tolerance.
    fixed_idx : ndarray of int, optional
        Optional 0-based indices of coefficients to hold fixed at fixed_values
        rather than estimate.
    fixed_values : ndarray, optional
        Optional values for the fixed_idx coefficients.
    warm_start_weights : ndarray, optional
        Optional initial IRLS working weights for the first iteration.
    warm_start_fisher_info : ndarray, optional
        Optional initial Fisher information matrix for the first IRLS iteration.
    estimate_only : bool, default False
        If True, skip variance-component calculations and return only the point
        estimate.
    """
def fast_stereotype_logit(X: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, n]", "flags.f_contiguous"], y: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], maxit: typing.SupportsInt | typing.SupportsIndex = 100, tol: typing.SupportsFloat | typing.SupportsIndex = 1e-08, smart_cold_start: bool = True, fixed_idx: typing.Annotated[numpy.typing.ArrayLike, numpy.int32, "[m, 1]"] | None = None, fixed_values: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, optimization_alg: str = 'newton_raphson', warm_start_fisher_info: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, n]"] | None = None, warm_start_params: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, warm_start_beta: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, estimate_only: bool = False) -> dict:
    """
    Fast stereotype logit ordinal regression via Newton-Raphson. Returns ssq_b_1/ssq_b_j (variance of the first beta) via a profile-likelihood fallback when the Fisher-information diagonal entry isn't directly invertible; vcov is always None (not computed by this kernel). Parameters sourced from R/EDI/man/ documentation for fast_stereotype_logit_cpp/fast_stereotype_logit_with_var_cpp (this binding unifies both R exports).
    
    Parameters
    ----------
    X : ndarray
        A numeric matrix of predictors.
    y : ndarray
        A numeric vector of responses.
    maxit : int, default 100
        Maximum number of iterations.
    tol : float, default 1e-8
        Convergence tolerance.
    smart_cold_start : bool, default True
        If True, use an initial OLS-based guess when starting from scratch (a
        "cold start") with no prior knowledge. Ignored if a warm start is
        provided.
    fixed_idx : ndarray of int, optional
        Optional indices of fixed parameters.
    fixed_values : ndarray, optional
        Optional values for fixed parameters.
    optimization_alg : str, default "newton_raphson"
        Optimization algorithm.
    warm_start_fisher_info : ndarray, optional
        Optional initial Fisher information matrix for the first IRLS iteration.
    warm_start_params : ndarray, optional
        Optional starting values for all parameters. If provided,
        smart_cold_start is ignored.
    warm_start_beta : ndarray, optional
        Optional starting values for coefficients. If provided,
        smart_cold_start is ignored.
    estimate_only : bool, default False
        If True, skip variance-related computation and return only the point
        estimate.
    """
def fast_stratified_coxph_regression(X: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, n]", "flags.f_contiguous"], y: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], dead: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], strata: typing.Annotated[numpy.typing.NDArray[numpy.int32], "[m, 1]"], warm_start_beta: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, smart_cold_start: bool = True, estimate_only: bool = False, maxit: typing.SupportsInt | typing.SupportsIndex = 20, tol: typing.SupportsFloat | typing.SupportsIndex = 1e-09, fixed_idx: typing.Annotated[numpy.typing.ArrayLike, numpy.int32, "[m, 1]"] | None = None, fixed_values: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, optimization_alg: str = 'newton_raphson', warm_start_fisher_info: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, n]"] | None = None) -> dict:
    """
    Fast stratified Cox proportional-hazards regression via Newton-Raphson: one shared beta fit jointly across strata-specific baseline hazards. strata: integer group labels, any values (grouped internally, not required to be 0-based/contiguous). No R-side roxygen documents this raw kernel directly (fast_coxph_regression.cpp's roxygen documents a bootstrap helper, not this fit function); other parameters follow fast_coxph_regression's conventions (see its docstring).
    
    Parameters
    ----------
    X : ndarray
        Numeric matrix of predictors (no intercept column).
    y : ndarray
        Numeric vector of survival/censoring times.
    dead : ndarray
        0/1 event indicator (1 = event, 0 = censored), same length as y.
    strata : ndarray of int
        Stratum label for each subject; each stratum gets its own baseline
        hazard while sharing one beta across all strata.
    warm_start_beta : ndarray, optional
        Optional starting values for coefficients. If provided,
        smart_cold_start is ignored.
    smart_cold_start : bool, default True
        If True, use an initial OLS-based guess when starting from scratch. Ignored
        if a warm start is provided.
    estimate_only : bool, default False
        If True, skip variance-covariance computation and return only
        coefficients.
    maxit : int, default 20
        Maximum number of Newton-Raphson iterations.
    tol : float, default 1e-9
        Convergence tolerance.
    fixed_idx : ndarray of int, optional
        Optional indices of fixed parameters.
    fixed_values : ndarray, optional
        Optional values for fixed parameters.
    optimization_alg : str, default "newton_raphson"
        Optimization algorithm.
    warm_start_fisher_info : ndarray, optional
        Optional initial Fisher information matrix for the first iteration.
    """
def fast_trigamma(x: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"]) -> typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"]:
    """
    Vectorized trigamma (elementwise). Matches scipy.special.polygamma(1, x).
    """
def fast_truncated_negbin_count(X: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, n]", "flags.f_contiguous"], y: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], warm_start_params: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, smart_cold_start: bool = True, estimate_only: bool = False, maxit: typing.SupportsInt | typing.SupportsIndex = 1000, tol: typing.SupportsFloat | typing.SupportsIndex = 1e-08, fixed_idx: typing.Annotated[numpy.typing.ArrayLike, numpy.int32, "[m, 1]"] | None = None, fixed_values: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, optimization_alg: str = 'lbfgs', warm_start_fisher_info: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, n]"] | None = None) -> dict:
    """
    Fast zero-truncated negative binomial count regression via L-BFGS (the count-component fit used inside fast_hurdle_negbin, also exposed standalone). No R-side roxygen documents this raw kernel directly (fast_hurdle_negbin.cpp's roxygen documents the hurdle export, not this truncated-count-only one); parameters follow the same conventions used
    throughout this module.
    
    Parameters
    ----------
    X : ndarray
        Matrix of predictors.
    y : ndarray
        Vector of positive (zero-truncated) count responses.
    warm_start_params : ndarray, optional
        Optional starting values for coefficients and dispersion. If provided,
        smart_cold_start is ignored.
    smart_cold_start : bool, default True
        If True, use an initial OLS-based guess when starting from scratch. Ignored
        if a warm start is provided.
    estimate_only : bool, default False
        If True, skip variance-covariance computation and return only
        coefficients.
    maxit : int, default 1000
        Maximum number of iterations.
    tol : float, default 1e-8
        Convergence tolerance.
    fixed_idx : ndarray of int, optional
        Optional indices of fixed parameters.
    fixed_values : ndarray, optional
        Optional values for fixed parameters.
    optimization_alg : str, default "lbfgs"
        Optimization algorithm.
    warm_start_fisher_info : ndarray, optional
        Optional initial Fisher information matrix for the first iteration.
    """
def fast_weibull_frailty(X: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, n]", "flags.f_contiguous"], y: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], dead: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], group_id: typing.Annotated[numpy.typing.NDArray[numpy.int32], "[m, 1]"], warm_start_params: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, warm_start_beta: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, estimate_only: bool = False, n_gh: typing.SupportsInt | typing.SupportsIndex = 20, max_abs_log_sigma: typing.SupportsFloat | typing.SupportsIndex = 8.0, maxit: typing.SupportsInt | typing.SupportsIndex = 300, eps_g: typing.SupportsFloat | typing.SupportsIndex = 1e-06, fixed_idx: typing.Annotated[numpy.typing.ArrayLike, numpy.int32, "[m, 1]"] | None = None, fixed_values: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, optimization_alg: str = 'lbfgs', warm_start_fisher_info: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, n]"] | None = None) -> dict:
    """
    Fast Weibull AFT frailty regression (random intercept, Gauss-Hermite quadrature) via L-BFGS. No R-side roxygen documents this raw kernel directly (fast_weibull_frailty.cpp has none); shared adaptive-quadrature parameter meanings (n_gh/max_abs_log_sigma/etc.) are grounded in R/EDI/man/ documentation for the GLMM-engine sibling fast_ordinal_glmm_cpp.
    
    Parameters
    ----------
    X : ndarray
        A numeric matrix of predictors.
    y : ndarray
        A numeric vector of survival times.
    dead : ndarray
        0/1 event indicator (1 = event, 0 = censored).
    group_id : ndarray of int
        Group (shared-frailty cluster) identifiers, one per row of X/y.
    warm_start_params : ndarray, optional
        Optional starting values for all parameters [beta, log_sigma_shape,
        log_sigma_frailty].
    warm_start_beta : ndarray, optional
        Optional starting values for the coefficients only.
    estimate_only : bool, default False
        If True, skip variance-component calculations.
    n_gh : int, default 20
        Number of Gauss-Hermite quadrature nodes used to integrate out the
        shared frailty term.
    max_abs_log_sigma : float, default 8.0
        Maximum allowed value for log(sigma) (the frailty SD).
    maxit : int, default 300
        Maximum number of iterations.
    eps_g : float, default 1e-6
        Convergence tolerance for the gradient.
    fixed_idx : ndarray of int, optional
        Optional indices of fixed parameters.
    fixed_values : ndarray, optional
        Optional values for fixed parameters.
    optimization_alg : str, default "lbfgs"
        Optimization algorithm.
    warm_start_fisher_info : ndarray, optional
        Optional initial Fisher information matrix for the first iteration.
    """
def fast_weibull_regression_general(X: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, n]", "flags.f_contiguous"], y: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], y_L: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], y_R: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], warm_start_params: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, smart_cold_start: bool = True, estimate_only: bool = False, maxit: typing.SupportsInt | typing.SupportsIndex = 100, tol: typing.SupportsFloat | typing.SupportsIndex = 1e-08, fixed_idx: typing.Annotated[numpy.typing.ArrayLike, numpy.int32, "[m, 1]"] | None = None, fixed_values: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, optimization_alg: str = 'lbfgs', warm_start_fisher_info: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, n]"] | None = None) -> dict:
    """
    Fast Weibull AFT regression with general censoring via L-BFGS. Returned 'params' = [beta, log_sigma].
    
    Parameters
    ----------
    X : ndarray
        A numeric matrix of predictors.
    y : ndarray
        Exact survival times; NaN for censored observations.
    y_L : ndarray
        Lower censoring bounds; NaN for exact observations and 0 for left censoring.
    y_R : ndarray
        Upper censoring bounds; NaN for exact observations and inf for right censoring.
    warm_start_params : ndarray, optional
        Optional starting values for coefficients.
    smart_cold_start : bool, default True
        If True, use an initial OLS-based guess.
    estimate_only : bool, default False
        If True, do not compute the variance-covariance matrix.
    maxit : int, default 100
        Maximum number of iterations.
    tol : float, default 1e-8
        Convergence tolerance.
    fixed_idx : ndarray of int, optional
        Optional indices of fixed parameters.
    fixed_values : ndarray, optional
        Optional values for fixed parameters.
    optimization_alg : str, default "lbfgs"
        Optimization algorithm.
    warm_start_fisher_info : ndarray, optional
        Optional initial Fisher information matrix.
    """
def fast_zero_augmented_poisson(X: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, n]", "flags.f_contiguous"], y: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], Xzi: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, n]", "flags.f_contiguous"], is_hurdle: bool, warm_start_params: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, smart_cold_start: bool = True, maxit: typing.SupportsInt | typing.SupportsIndex = 1000, tol: typing.SupportsFloat | typing.SupportsIndex = 1e-08, fixed_idx: typing.Annotated[numpy.typing.ArrayLike, numpy.int32, "[m, 1]"] | None = None, fixed_values: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, optimization_alg: str = 'lbfgs', warm_start_fisher_info: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, n]"] | None = None) -> dict:
    """
    Fast zero-inflated (is_hurdle=False) or hurdle (is_hurdle=True) Poisson regression via L-BFGS. Returns 'params' = [beta_cond, beta_zi]; split into components on the Python side. Parameters sourced from R/EDI/man/ documentation for fast_zero_augmented_poisson_cpp.
    
    Parameters
    ----------
    X : ndarray
        Matrix of predictors for the conditional (count) component.
    y : ndarray
        Vector of count responses.
    Xzi : ndarray
        Matrix of predictors for the zero-inflation/hurdle component.
    is_hurdle : bool
        If True, fit a hurdle model; if False, fit a zero-inflated model.
    warm_start_params : ndarray, optional
        Optional starting values for all parameters. If provided,
        smart_cold_start is ignored.
    smart_cold_start : bool, default True
        If True, use an initial OLS-based guess when starting from scratch (a
        "cold start") with no prior knowledge. Ignored if a warm start is
        provided.
    maxit : int, default 1000
        Maximum number of iterations.
    tol : float, default 1e-8
        Convergence tolerance.
    fixed_idx : ndarray of int, optional
        Optional indices of fixed parameters.
    fixed_values : ndarray, optional
        Optional values for fixed parameters.
    optimization_alg : str, default "lbfgs"
        Optimization algorithm.
    warm_start_fisher_info : ndarray, optional
        Optional initial Fisher information matrix for the first iteration.
    """
def fast_zero_augmented_poisson_with_var(X: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, n]", "flags.f_contiguous"], y: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], Xzi: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, n]", "flags.f_contiguous"], is_hurdle: bool, warm_start_params: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, smart_cold_start: bool = True, maxit: typing.SupportsInt | typing.SupportsIndex = 1000, tol: typing.SupportsFloat | typing.SupportsIndex = 1e-08, fixed_idx: typing.Annotated[numpy.typing.ArrayLike, numpy.int32, "[m, 1]"] | None = None, fixed_values: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, optimization_alg: str = 'lbfgs', warm_start_fisher_info: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, n]"] | None = None) -> dict:
    """
    Fast zero-inflated (is_hurdle=False) or hurdle (is_hurdle=True) Poisson regression with full vcov (params order: [beta_cond, beta_zi]). Always computes the variance -- fast_zero_augmented_poisson is the dedicated point-estimate-only backend. Same argument meanings as fast_zero_augmented_poisson (see its docstring).
    
    Parameters
    ----------
    X : ndarray
        Matrix of predictors for the conditional (count) component.
    y : ndarray
        Vector of count responses.
    Xzi : ndarray
        Matrix of predictors for the zero-inflation/hurdle component.
    is_hurdle : bool
        If True, fit a hurdle model; if False, fit a zero-inflated model.
    warm_start_params : ndarray, optional
        Optional starting values for all parameters. If provided,
        smart_cold_start is ignored.
    smart_cold_start : bool, default True
        If True, use an initial OLS-based guess when starting from scratch. Ignored
        if a warm start is provided.
    maxit : int, default 1000
        Maximum number of iterations.
    tol : float, default 1e-8
        Convergence tolerance.
    fixed_idx : ndarray of int, optional
        Optional indices of fixed parameters.
    fixed_values : ndarray, optional
        Optional values for fixed parameters.
    optimization_alg : str, default "lbfgs"
        Optimization algorithm.
    warm_start_fisher_info : ndarray, optional
        Optional initial Fisher information matrix for the first iteration.
    """
def fast_zero_one_inflated_beta(X: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, n]", "flags.f_contiguous"], X_zero_one: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, n]", "flags.f_contiguous"], y: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], warm_start_params: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, smart_cold_start: bool = True, fixed_idx: typing.Annotated[numpy.typing.ArrayLike, numpy.int32, "[m, 1]"] | None = None, fixed_values: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, optimization_alg: str = 'lbfgs', warm_start_fisher_info: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, n]"] | None = None) -> dict:
    """
    Fast zero-one-inflated beta regression via L-BFGS. Returned 'params' packs [beta, log_phi, zero_one_inflation_params]; see R/EDI/src/fast_zero_one_inflated_beta.cpp. Parameters sourced from R/EDI/man/ documentation for fast_zero_one_inflated_beta_cpp.
    
    Parameters
    ----------
    X : ndarray
        Matrix of predictors for the beta component.
    X_zero_one : ndarray
        Matrix of predictors for the zero- and one-inflation components.
    y : ndarray
        Vector of responses in [0, 1].
    warm_start_params : ndarray, optional
        Optional starting values for all parameters. If provided,
        smart_cold_start is ignored.
    smart_cold_start : bool, default True
        If True, use an initial OLS-based guess when starting from scratch (a
        "cold start") with no prior knowledge. Ignored if a warm start is
        provided.
    fixed_idx : ndarray of int, optional
        Optional indices of fixed parameters.
    fixed_values : ndarray, optional
        Optional values for fixed parameters.
    optimization_alg : str, default "lbfgs"
        Optimization algorithm.
    warm_start_fisher_info : ndarray, optional
        Optional initial Fisher information matrix for the first iteration.
    """
def fast_zinb(Xc: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, n]", "flags.f_contiguous"], Xz: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, n]", "flags.f_contiguous"], y: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], warm_start_params: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, maxit: typing.SupportsInt | typing.SupportsIndex = 1000, tol: typing.SupportsFloat | typing.SupportsIndex = 1e-08, fixed_idx: typing.Annotated[numpy.typing.ArrayLike, numpy.int32, "[m, 1]"] | None = None, fixed_values: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, optimization_alg: str = 'lbfgs', smart_cold_start: bool = True, warm_start_fisher_info: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, n]"] | None = None) -> dict:
    """
    Fast zero-inflated negative binomial regression via L-BFGS. Returns 'params' = [beta_cond, beta_zi, log_theta]; split into components on the Python side. Parameters sourced from R/EDI/man/ documentation for fast_zinb_cpp (Xc/Xz here correspond to that function's X/Xzi).
    
    Parameters
    ----------
    Xc : ndarray
        Numeric matrix of predictors for the count component (including
        intercept).
    Xz : ndarray
        Numeric matrix of predictors for the zero-inflation component (including
        intercept).
    y : ndarray
        Numeric vector of non-negative integer count responses.
    warm_start_params : ndarray, optional
        Optional starting values for all parameters ([beta_cond, beta_zi,
        log_theta]).
    maxit : int, default 1000
        Maximum number of iterations.
    tol : float, default 1e-8
        Convergence tolerance.
    fixed_idx : ndarray of int, optional
        Optional indices of fixed parameters.
    fixed_values : ndarray, optional
        Optional values for fixed parameters.
    optimization_alg : str, default "lbfgs"
        Optimization algorithm.
    smart_cold_start : bool, default True
        If True, use a heuristic initial guess when no warm start is provided.
    warm_start_fisher_info : ndarray, optional
        Optional initial Fisher information matrix.
    """
def fast_zinb_with_var(Xc: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, n]", "flags.f_contiguous"], Xz: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, n]", "flags.f_contiguous"], y: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], warm_start_params: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, maxit: typing.SupportsInt | typing.SupportsIndex = 1000, tol: typing.SupportsFloat | typing.SupportsIndex = 1e-08, fixed_idx: typing.Annotated[numpy.typing.ArrayLike, numpy.int32, "[m, 1]"] | None = None, fixed_values: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, optimization_alg: str = 'lbfgs', smart_cold_start: bool = True, warm_start_fisher_info: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, n]"] | None = None) -> dict:
    """
    Fast zero-inflated negative binomial regression with full vcov (params order: [beta_cond, beta_zi, log_theta]). Always computes the variance -- fast_zinb is the dedicated point-estimate-only backend. Same argument meanings as fast_zinb (see its docstring); Xc/Xz correspond to R/EDI/man/'s fast_zinb_cpp X/Xzi.
    
    Parameters
    ----------
    Xc : ndarray
        Numeric matrix of predictors for the count component (including
        intercept).
    Xz : ndarray
        Numeric matrix of predictors for the zero-inflation component (including
        intercept).
    y : ndarray
        Numeric vector of non-negative integer count responses.
    warm_start_params : ndarray, optional
        Optional starting values for all parameters ([beta_cond, beta_zi,
        log_theta]).
    maxit : int, default 1000
        Maximum number of iterations.
    tol : float, default 1e-8
        Convergence tolerance.
    fixed_idx : ndarray of int, optional
        Optional indices of fixed parameters.
    fixed_values : ndarray, optional
        Optional values for fixed parameters.
    optimization_alg : str, default "lbfgs"
        Optimization algorithm.
    smart_cold_start : bool, default True
        If True, use a heuristic initial guess when no warm start is provided.
    warm_start_fisher_info : ndarray, optional
        Optional initial Fisher information matrix.
    """
def gee_pairs_singletons(X: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, n]", "flags.f_contiguous"], y: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], group_id: typing.Annotated[numpy.typing.NDArray[numpy.int32], "[m, 1]"], family: str, warm_start_beta: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, 1]"] | None = None, warm_start_fisher_info: typing.Annotated[numpy.typing.ArrayLike, numpy.float64, "[m, n]"] | None = None, maxit: typing.SupportsInt | typing.SupportsIndex = 100, tol: typing.SupportsFloat | typing.SupportsIndex = 1e-08) -> dict:
    """
    Fast GEE (singleton/pair clusters only) via Fisher scoring. family is one of 'gaussian', 'binomial', 'poisson'. No R-side roxygen documents this raw kernel directly (fast_gee.cpp has none); parameters follow the same conventions used throughout this module.
    
    Parameters
    ----------
    X : ndarray
        Numeric matrix of predictors (including intercept column where wanted).
    y : ndarray
        Numeric vector of responses, matching family's distribution.
    group_id : ndarray of int
        Cluster identifiers, one per row of X/y; every cluster here must be a
        singleton (size 1) or a pair (size 2) -- this is the specialized
        fast path, not a general GEE solver.
    family : str
        One of "gaussian", "binomial", "poisson" -- the GEE working
        variance/link family.
    warm_start_beta : ndarray, optional
        Optional starting values for coefficients.
    warm_start_fisher_info : ndarray, optional
        Optional initial Fisher information matrix for the first iteration.
    maxit : int, default 100
        Maximum number of Fisher-scoring iterations.
    tol : float, default 1e-8
        Convergence tolerance.
    """
def get_survival_stat_diff(y: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], dead: typing.Annotated[numpy.typing.NDArray[numpy.int32], "[m, 1]"], w: typing.Annotated[numpy.typing.NDArray[numpy.int32], "[m, 1]"], requested_stat: str = 'median') -> float:
    """
    Difference (treatment minus control) in a per-group Kaplan-Meier statistic. requested_stat is 'median' (KM median survival time, matching survival::quantile.survfit's step-function semantics) or 'restricted_mean'. dead/w are 0/1 vectors (event indicator / treatment indicator). Parameters sourced from R/EDI/man/ documentation for this same-named function in R/EDI/src/fast_survival_stats.cpp.
    
    Parameters
    ----------
    y : ndarray
        Numeric vector of survival times.
    dead : ndarray of int
        Event indicator (1=event, 0=censored).
    w : ndarray of int
        Treatment assignment (1=treatment, 0=control).
    requested_stat : str, default "median"
        Either "median" or "restricted_mean".
    """
def mn_ci(x_t: typing.SupportsFloat | typing.SupportsIndex, n_t: typing.SupportsFloat | typing.SupportsIndex, x_c: typing.SupportsFloat | typing.SupportsIndex, n_c: typing.SupportsFloat | typing.SupportsIndex, p_t_obs: typing.SupportsFloat | typing.SupportsIndex, p_c_obs: typing.SupportsFloat | typing.SupportsIndex, alpha: typing.SupportsFloat | typing.SupportsIndex = 0.05, pval_epsilon: typing.SupportsFloat | typing.SupportsIndex = 1e-07) -> tuple:
    """
    Miettinen-Nurminen score confidence interval for a risk difference (inverts the constrained score test via bisection). Returns (lower, upper). Shared x_t/n_t/x_c/n_c/p_t_obs/p_c_obs argument meanings sourced from R/EDI/man/ documentation for the sibling mn_pvalue_cpp/mn_z_statistic_cpp (same file); alpha/pval_epsilon are this CI-inversion wrapper's own arguments, undocumented on the R side.
    
    Parameters
    ----------
    x_t : float
        Number of events in the treatment arm.
    n_t : float
        Number of subjects in the treatment arm.
    x_c : float
        Number of events in the control arm.
    n_c : float
        Number of subjects in the control arm.
    p_t_obs : float
        Observed treatment-arm risk (typically x_t / n_t).
    p_c_obs : float
        Observed control-arm risk (typically x_c / n_c).
    alpha : float, default 0.05
        Significance level; the returned interval has nominal coverage
        1 - alpha.
    pval_epsilon : float, default 1e-7
        Numerical tolerance for the bisection search that inverts the score
        test to find each bound.
    """
def mn_pvalue(x_t: typing.SupportsFloat | typing.SupportsIndex, n_t: typing.SupportsFloat | typing.SupportsIndex, x_c: typing.SupportsFloat | typing.SupportsIndex, n_c: typing.SupportsFloat | typing.SupportsIndex, delta: typing.SupportsFloat | typing.SupportsIndex, p_t_obs: typing.SupportsFloat | typing.SupportsIndex, p_c_obs: typing.SupportsFloat | typing.SupportsIndex) -> float:
    """
    Miettinen-Nurminen two-sided score p-value for testing risk difference = delta. Parameters sourced from R/EDI/man/ documentation for mn_pvalue_cpp.
    
    Parameters
    ----------
    x_t : float
        Number of events in the treatment arm.
    n_t : float
        Number of subjects in the treatment arm.
    x_c : float
        Number of events in the control arm.
    n_c : float
        Number of subjects in the control arm.
    delta : float
        Null risk difference to test against.
    p_t_obs : float
        Observed treatment-arm risk (typically x_t / n_t).
    p_c_obs : float
        Observed control-arm risk (typically x_c / n_c).
    """
def newcombe_independent_ci(x1: typing.SupportsFloat | typing.SupportsIndex, n1: typing.SupportsFloat | typing.SupportsIndex, x2: typing.SupportsFloat | typing.SupportsIndex, n2: typing.SupportsFloat | typing.SupportsIndex, alpha: typing.SupportsFloat | typing.SupportsIndex = 0.05) -> tuple:
    """
    Newcombe hybrid score confidence interval for independent proportions (Method 10). Returns (lower, upper). R/EDI/src/newcombe_speedups.cpp's roxygen for this exact function has only an (untagged) title, no @param entries; argument meanings below follow directly from the two-independent-proportions parameterization the title names, and match the sibling newcombe_paired_ci_cpp's x/n naming in the same file.
    
    Parameters
    ----------
    x1 : float
        Number of events in group 1.
    n1 : float
        Number of subjects in group 1.
    x2 : float
        Number of events in group 2.
    n2 : float
        Number of subjects in group 2.
    alpha : float, default 0.05
        Significance level; the returned interval has nominal coverage
        1 - alpha.
    """
def ols_hc2_post_fit(X_fit: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, n]", "flags.f_contiguous"], y: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], coef_hat: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], j_treat: typing.SupportsInt | typing.SupportsIndex = 2) -> dict:
    """
    HC2 heteroskedasticity-robust (sandwich) standard errors for an already-fitted OLS coefficient vector. No R-side roxygen documents this raw kernel directly (robust_post_fit_speedups.cpp has none).
    
    Parameters
    ----------
    X_fit : ndarray
        The fitting design matrix (e.g. Lin's intercept+treatment+centered-
        covariates+treatment×covariate design) -- must match the matrix the
        supplied coef_hat was actually fit against.
    y : ndarray
        Numeric response vector used in the original fit.
    coef_hat : ndarray
        The already-fitted OLS coefficient vector to compute post-fit HC2
        standard errors for.
    j_treat : int, default 2
        1-based column of X_fit/coef_hat whose SE/z-value is highlighted as
        beta_hat/se in the result (std_err/z_vals cover every column
        regardless).
    """
def pnorm_fast(x: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"]) -> typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"]:
    """
    Vectorized standard normal CDF (elementwise). Matches scipy.stats.norm.cdf.
    """
def wilcox_hl_point_estimate(y: typing.Annotated[numpy.typing.NDArray[numpy.float64], "[m, 1]"], w: typing.Annotated[numpy.typing.NDArray[numpy.int32], "[m, 1]"]) -> float:
    """
    Hodges-Lehmann point estimate (median of all pairwise treatment-minus-control differences, exact for small n or via bisection selection for large n) for the two-sample Wilcoxon rank-sum problem. w is a 0/1 treatment indicator; non-finite y entries are dropped. No R-side roxygen documents this exact raw kernel (fast_wilcox_hl.cpp's roxygen documents a different, permutation-batch export in the same file); parameters are named for their role in the algorithm above.
    
    Parameters
    ----------
    y : ndarray
        Numeric response vector.
    w : ndarray of int
        0/1 treatment indicator, same length as y.
    """
