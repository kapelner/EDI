# On CI only, pin BLAS/OpenMP to a single thread for the whole test session,
# before any test executes a parallel C++ kernel (23 files under src/ use
# `#pragma omp parallel`, and OpenBLAS/libgomp lazily spawn a persistent
# worker-thread pool on first use that stays alive for the rest of the
# process). Without this, by the time test-simulation-framework-extended.R
# makes the suite's first num_cores > 1 call and forks a cluster
# (parallel::makeForkCluster(), globals.R's make_configured_fork_cluster()),
# thousands of preceding tests may already have spun up multi-threaded
# BLAS/OMP via the default thread count. If any of those background threads
# holds a lock at the instant fork() copies the process, the forked child
# inherits a permanently-stuck mutex (only the forking thread survives the
# fork) and deadlocks before completing its handshake back to the parent --
# parallel::makeForkCluster() then blocks forever with no R-level error to
# catch and no console output, exactly the failure mode that hung
# ubuntu-latest (oldrel-1) and R-CMD-check-no-suggests for 4+ hours on
# 2026-08-10 until GitHub Actions' job timeout (see R-CMD-check.yaml's
# timeout-minutes) cut them off. Setting threads to 1 here means no OpenMP
# worker-thread pool ever forms during the ~7800 serial tests that run
# before it, so there is nothing live to deadlock on fork when the
# parallel-cluster tests later call set_num_cores()/set_package_threads()
# themselves.
#
# Local runs are deliberately left alone -- multi-core BLAS/OMP is exactly
# what you want live when testing parallel code paths by hand -- so this
# only fires when the CI env var is set (the convention GitHub Actions,
# GitLab CI, Travis, CircleCI, etc. all set to "true").
if (identical(Sys.getenv("CI"), "true")) {
	EDI:::set_package_threads(1L)
}
