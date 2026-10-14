#ifndef EDI_OMP_POLICY_H
#define EDI_OMP_POLICY_H

#ifdef _OPENMP
#include <omp.h>
#endif

// The R package has separate controls for R workers and native OpenMP
// threads. Python callers retain the explicit num_cores kernel argument.
#if defined(_OPENMP) && !defined(EDI_CORE_ONLY)
#define EDI_KERNEL_NUM_THREADS(num_cores) omp_get_max_threads()
#else
#define EDI_KERNEL_NUM_THREADS(num_cores) (num_cores)
#endif

#endif
