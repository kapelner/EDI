#ifndef EDI_NEGBIN_BOUNDARY_CONVERGENCE_H
#define EDI_NEGBIN_BOUNDARY_CONVERGENCE_H

// Family-local convergence handling for the Poisson limit of negative-binomial
// likelihoods.  This deliberately lives outside _helper_functions_core.h: the
// rule is valid only for a final log(theta) coordinate in a NegBin likelihood.

constexpr double kNegBinPoissonBoundaryLogTheta = 9.210340371976184; // log(1e4)

inline bool negbin_parameter_is_free(const FixedParamSpec& fixed_spec, int parameter_index) {
    for (int i = 0; i < fixed_spec.free_idx.size(); ++i) {
        if (fixed_spec.free_idx[i] == parameter_index) return true;
    }
    return false;
}

inline FixedParamSpec negbin_information_spec(const FixedParamSpec& optimization_spec,
                                               int dispersion_index,
                                               bool dispersion_at_poisson_boundary) {
    if (!dispersion_at_poisson_boundary) return optimization_spec;

    FixedParamSpec information_spec = optimization_spec;
    int retained = 0;
    for (int i = 0; i < optimization_spec.free_idx.size(); ++i) {
        if (optimization_spec.free_idx[i] != dispersion_index) ++retained;
    }
    information_spec.free_idx.resize(retained);
    int out = 0;
    for (int i = 0; i < optimization_spec.free_idx.size(); ++i) {
        const int index = optimization_spec.free_idx[i];
        if (index != dispersion_index) information_spec.free_idx[out++] = index;
    }
    information_spec.has_fixed = true;
    return information_spec;
}

template <typename NegBinLikelihood>
inline bool accept_negbin_poisson_boundary_convergence(NegBinLikelihood& fun,
                                                        const FixedParamSpec& fixed_spec,
                                                        int dispersion_index,
                                                        double tol,
                                                        LikelihoodFitResult& fit) {
    if (fit.converged || fit.params.size() <= dispersion_index ||
        !fit.params.allFinite() || !std::isfinite(fit.params[dispersion_index]) ||
        fit.params[dispersion_index] < kNegBinPoissonBoundaryLogTheta ||
        !negbin_parameter_is_free(fixed_spec, dispersion_index)) {
        return false;
    }

    Eigen::VectorXd gradient(fit.params.size());
    const double value = fun(fit.params, gradient);
    if (!std::isfinite(value) || !gradient.allFinite() ||
        !(gradient[dispersion_index] < 0.0)) {
        return false;
    }

    double non_dispersion_gradient_sq = 0.0;
    for (int i = 0; i < fixed_spec.free_idx.size(); ++i) {
        const int index = fixed_spec.free_idx[i];
        if (index != dispersion_index) {
            non_dispersion_gradient_sq += gradient[index] * gradient[index];
        }
    }
    // Preserve the caller's tolerance while allowing only a small absolute
    // numerical floor for likelihood implementations evaluated near the
    // Poisson limit.  This remains far tighter than coefficient-level
    // inference requires and is intentionally not scaled by sample size.
    const double coefficient_tol = std::max(10.0 * tol, 1e-6);
    if (std::sqrt(non_dispersion_gradient_sq) > coefficient_tol) return false;

    // The optimizer exposes only its final iterate.  Probe one further step
    // along +log(theta), and require both the objective and its directional
    // derivative to keep moving toward the Poisson limit.  This rejects a
    // merely large theta at an oscillating or unrelated failed fit.
    Eigen::VectorXd forward_params = fit.params;
    forward_params[dispersion_index] += std::log(2.0);
    Eigen::VectorXd forward_gradient(fit.params.size());
    const double forward_value = fun(forward_params, forward_gradient);
    const double value_slack = 64.0 * std::numeric_limits<double>::epsilon() *
        std::max(1.0, std::fabs(value));
    if (!std::isfinite(forward_value) || !forward_gradient.allFinite() ||
        forward_value > value + value_slack ||
        !(forward_gradient[dispersion_index] <= 0.0)) {
        return false;
    }

    fit.value = value;
    fit.converged = true;
    fit.hit_iteration_cap = false;
    fit.dispersion_at_poisson_boundary = true;
    return true;
}

#endif
