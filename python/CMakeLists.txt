cmake_minimum_required(VERSION 3.18)
project(edi_kernels LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# R/EDI/src is the single source of truth for every model-fitting kernel and
# shared header -- nothing under python/ ever copies a .cpp/.h file from
# there in a live checkout (local builds, and every wheel cibuildwheel
# produces, which always build from a full git checkout where ../R/EDI/src
# exists as a real sibling directory). This include path is what lets
# python/cpp/*.cpp #include headers (and, once a given R/EDI/src/*.cpp has
# been given the EDI_CORE_ONLY treatment, call its *_internal functions)
# directly out of the R package's own source tree.
#
# The one exception is a *source install from the sdist*: an sdist tarball
# only packages python/'s own tree, so ../R/EDI/src does not exist once it's
# extracted standalone (see python_bindings_package_spec.md's TODO-12 for
# the 2026-08-10 discovery -- this shipped broken in 1.0.0, silently, since
# nothing in CI ever installed the sdist it built, only the wheels built
# from a live checkout). pyproject.toml's [tool.scikit-build.sdist.
# force-include] copies R/EDI/src into vendor/EDI_src *inside the sdist
# only* (never onto disk in a live checkout) to close that gap, so prefer
# that vendored copy when present and fall back to the live sibling
# otherwise -- covers both cases with the same variable.
if(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/vendor/EDI_src)
    set(EDI_SRC_DIR ${CMAKE_CURRENT_SOURCE_DIR}/vendor/EDI_src)
else()
    set(EDI_SRC_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../R/EDI/src)
endif()
if(NOT EXISTS ${EDI_SRC_DIR})
    message(FATAL_ERROR
        "EDI_SRC_DIR (${EDI_SRC_DIR}) does not exist. If building from a "
        "live checkout, this repo must be cloned in full (R/EDI/src is a "
        "required sibling of python/, not an optional piece). If building "
        "from an sdist, its [tool.scikit-build.sdist.force-include] step "
        "should have vendored the sources into vendor/EDI_src -- check "
        "that the sdist was built with a pyproject.toml that has that "
        "setting (see python_bindings_package_spec.md TODO-12).")
endif()

find_package(Python 3.9 REQUIRED COMPONENTS Interpreter Development.Module)
find_package(pybind11 CONFIG REQUIRED)
find_package(OpenMP)
# symmetric_crossprod's EDI_CORE_ONLY branch (_helper_functions_core.h) calls
# cblas_dsyrk directly (the ABI-stable CBLAS entry point, not R's raw Fortran
# dsyrk_/F77_CALL convention -- see that header's own comment). Any standard
# BLAS provider (reference libblas, OpenBLAS, MKL) exports this symbol.
#
# Portable-wheel builds (cibuildwheel, see pyproject.toml's
# [tool.cibuildwheel]) don't reliably have a system BLAS: manylinux
# containers have no BLAS preinstalled at all, and Windows has no system
# package manager to provide one. On those platforms this falls back to the
# `scipy-openblas32` PyPI package (a pip-installable OpenBLAS build with a
# CMake package config, used the same way by numpy/scipy/scikit-learn's own
# cibuildwheel configs) -- installed via [tool.cibuildwheel]'s
# `before-build`, never a hard `R/EDI/src` dependency.
find_package(BLAS QUIET)
set(EDI_USING_SCIPY_OPENBLAS FALSE)
if(NOT BLAS_FOUND)
    # scipy_openblas32's actual Python API (see its __init__.py) is
    # get_lib_dir()/get_include_dir()/get_library()/get_pkg_config() --
    # there is no get_cmake_dir() and no CMake package config file at all,
    # so this queries those directly and builds BLAS_LIBRARIES by hand
    # rather than routing through find_package(BLAS).
    execute_process(
        COMMAND ${Python_EXECUTABLE} -c "import scipy_openblas32 as s; print(s.get_lib_dir())"
        OUTPUT_VARIABLE SCIPY_OPENBLAS_LIB_DIR
        OUTPUT_STRIP_TRAILING_WHITESPACE
        RESULT_VARIABLE SCIPY_OPENBLAS_RESULT
        ERROR_QUIET
    )
    if(SCIPY_OPENBLAS_RESULT EQUAL 0 AND SCIPY_OPENBLAS_LIB_DIR)
        execute_process(
            COMMAND ${Python_EXECUTABLE} -c "import scipy_openblas32 as s; print(s.get_include_dir())"
            OUTPUT_VARIABLE SCIPY_OPENBLAS_INCLUDE_DIR
            OUTPUT_STRIP_TRAILING_WHITESPACE
        )
        execute_process(
            COMMAND ${Python_EXECUTABLE} -c "import scipy_openblas32 as s; print(s.get_library(fullname=True))"
            OUTPUT_VARIABLE SCIPY_OPENBLAS_LIB_FILE
            OUTPUT_STRIP_TRAILING_WHITESPACE
        )
        message(STATUS "System BLAS not found; using scipy-openblas32's bundled OpenBLAS (${SCIPY_OPENBLAS_LIB_DIR}/${SCIPY_OPENBLAS_LIB_FILE}).")
        set(BLAS_LIBRARIES "${SCIPY_OPENBLAS_LIB_DIR}/${SCIPY_OPENBLAS_LIB_FILE}")
        set(BLAS_FOUND TRUE)
        set(EDI_USING_SCIPY_OPENBLAS TRUE)
    else()
        message(FATAL_ERROR
            "No BLAS found via find_package(BLAS), and scipy-openblas32 isn't "
            "installed in ${Python_EXECUTABLE} either. Install a system BLAS "
            "(e.g. `dnf install openblas-devel` on manylinux, a system package "
            "on Linux/macOS) or `pip install scipy-openblas32` before "
            "configuring, per this file's comment and pyproject.toml's "
            "[tool.cibuildwheel].")
    endif()
endif()
include(FetchContent)

# Prefer a real Eigen3 CMake package (apt's libeigen3-dev, conda-forge, a
# vendored checkout, etc. -- widely packaged, so this is the common case).
# Falls back to fetching Eigen directly from its own upstream so a from-
# scratch build never needs anything R-specific.
find_package(Eigen3 3.3 QUIET NO_MODULE)
if(NOT Eigen3_FOUND)
    message(STATUS "Eigen3 not found via find_package(); fetching the pinned upstream release archive.")
    FetchContent_Declare(
        eigen
        URL https://gitlab.com/libeigen/eigen/-/archive/3.4.0/eigen-3.4.0.tar.gz
        URL_HASH SHA256=8586084f71f9bde545ee7fa6d00288b264a2b7ac3607b974e54d13e7162c1c72
    )
    set(EIGEN_BUILD_DOC OFF CACHE BOOL "" FORCE)
    set(BUILD_TESTING OFF CACHE BOOL "" FORCE)
    set(EIGEN_BUILD_TESTING OFF CACHE BOOL "" FORCE)
    FetchContent_MakeAvailable(eigen)
endif()

# _helper_functions_core.h pulls in LBFGSpp's <optimization/LBFGS.h>.
# LBFGSpp (github.com/yixuan/LBFGSpp, MIT license) is itself a standalone,
# header-only C++ library with zero R/Rcpp dependency -- RcppNumerical just
# vendors a copy of it for R's use. Prefer a system installation when one is
# available; otherwise fetch LBFGSpp directly from its own upstream. Pin the
# fallback to a tagged release for reproducibility.
#
# LBFGSpp's own CMakeLists.txt unconditionally does add_subdirectory(examples)
# -- confirmed upstream, no BUILD_EXAMPLES-style cache variable exists to
# disable it, so FetchContent_MakeAvailable (which calls add_subdirectory()
# on the fetched content) would build every example-*.exe too, even though
# we only need this header-only library's headers. On Windows this actually
# broke the build: the example projects' deeply nested object/tlog paths
# under scikit-build-core's own already-long build-dir tree exceed Windows'
# MAX_PATH, failing with "FileTracker: could not create the new file
# tracking log file". Calling FetchContent_Populate() directly with the full
# population details (rather than FetchContent_Declare + FetchContent_Populate
# (name), which CMP0169 deprecates) downloads the source without ever calling
# add_subdirectory() on it, so LBFGSpp's own CMakeLists.txt (and its
# examples) never runs -- lbfgspp_SOURCE_DIR is still set exactly as it
# would be by FetchContent_MakeAvailable, and this form remains fully
# supported (not deprecated) per CMP0169's own docs.
find_path(EDI_LBFGSPP_INCLUDE_DIR
    NAMES LBFGS.h
    PATH_SUFFIXES LBFGSpp
    DOC "Directory containing LBFGSpp headers"
)
if(NOT EDI_LBFGSPP_INCLUDE_DIR)
    FetchContent_Populate(
        lbfgspp
        URL https://github.com/yixuan/LBFGSpp/archive/refs/tags/v0.4.0.tar.gz
        URL_HASH SHA256=39c4aaebd8b94ccdc98191d51913a31cddd618cc0869d99f07a4b6da83ca6254
    )
    set(EDI_LBFGSPP_INCLUDE_DIR ${lbfgspp_SOURCE_DIR}/include)
endif()

# R/EDI/src/_helper_functions_core.h does #include <optimization/LBFGS.h> --
# that "optimization/" prefix is RcppNumerical's own vendoring convention
# (inst/include/optimization/LBFGS.h), not upstream LBFGSpp's layout (which
# is just include/LBFGS.h). Rather than touch R/EDI/src to special-case the
# Python build's directory layout, shim it here: a symlink so the same
# #include line resolves against either the system or fetched copy.
set(EDI_LBFGSPP_SHIM_DIR ${CMAKE_BINARY_DIR}/lbfgspp_shim)
file(MAKE_DIRECTORY ${EDI_LBFGSPP_SHIM_DIR})
if(NOT EXISTS ${EDI_LBFGSPP_SHIM_DIR}/optimization)
    file(CREATE_LINK ${EDI_LBFGSPP_INCLUDE_DIR} ${EDI_LBFGSPP_SHIM_DIR}/optimization SYMBOLIC)
endif()

option(EDI_PY_PORTABLE "Drop -march=native for portable/cross-compiled wheels" OFF)

# Building every R/EDI/src kernel with EDI_CORE_ONLY defined swaps out the
# Rcpp/R-specific include branches (RcppEigen.h, Rmath.h, R_ext/BLAS.h) for
# vanilla Eigen + a CBLAS declaration -- see _helper_functions_core.h and
# fast_gamma_functions.h in R/EDI/src. No R installation or Rmath/libRmath
# linkage is required for this build.
add_compile_definitions(EDI_CORE_ONLY)

# R/EDI/src/*.cpp sources compiled directly into this extension (not copied).
# Add one line here per R/EDI/src file whose general *_internal function gets a
# Python binding, in step with the corresponding python/cpp/bindings_*.cpp
# file that declares/calls it.
set(EDI_KERNEL_SOURCES
    ${EDI_SRC_DIR}/fast_poisson_glmm.cpp
    ${EDI_SRC_DIR}/fast_ols.cpp
    ${EDI_SRC_DIR}/fast_robust_regression.cpp
    ${EDI_SRC_DIR}/fast_logistic_regression.cpp
    ${EDI_SRC_DIR}/fast_probit_regression.cpp
    ${EDI_SRC_DIR}/fast_poisson_regression.cpp
    ${EDI_SRC_DIR}/fast_negbin_regression.cpp
    ${EDI_SRC_DIR}/fast_zinb.cpp
    ${EDI_SRC_DIR}/fast_zero_augmented_poisson.cpp
    ${EDI_SRC_DIR}/fast_beta_regression.cpp
    ${EDI_SRC_DIR}/fast_zero_one_inflated_beta.cpp
    ${EDI_SRC_DIR}/fast_adjacent_category_logit.cpp
    ${EDI_SRC_DIR}/fast_continuation_ratio_regression.cpp
    ${EDI_SRC_DIR}/fast_gee.cpp
    ${EDI_SRC_DIR}/fast_coxph_regression.cpp
    ${EDI_SRC_DIR}/fast_weibull_regression.cpp
    ${EDI_SRC_DIR}/fast_gaussian_lmm.cpp
    ${EDI_SRC_DIR}/fast_logistic_glmm.cpp
    ${EDI_SRC_DIR}/fast_ordinal_regression.cpp
    ${EDI_SRC_DIR}/fast_ordinal_probit_regression.cpp
    ${EDI_SRC_DIR}/fast_ordinal_cauchit_regression.cpp
    ${EDI_SRC_DIR}/fast_ordinal_cloglog_regression.cpp
    ${EDI_SRC_DIR}/fast_ordinal_clmm.cpp
    ${EDI_SRC_DIR}/fast_stereotype_logit.cpp
    ${EDI_SRC_DIR}/fast_ordinal_glmm.cpp
    ${EDI_SRC_DIR}/fast_cpoisson_combined.cpp
    ${EDI_SRC_DIR}/fast_weibull_frailty.cpp
    ${EDI_SRC_DIR}/fast_clogit_plus_glmm.cpp
    ${EDI_SRC_DIR}/fast_survival_models_optim.cpp
    ${EDI_SRC_DIR}/fast_hurdle_poisson_glmm.cpp
    ${EDI_SRC_DIR}/fast_hurdle_negbin.cpp
    ${EDI_SRC_DIR}/fast_log_binomial_regression.cpp
    ${EDI_SRC_DIR}/miettinen_nurminen_speedups.cpp
    ${EDI_SRC_DIR}/newcombe_speedups.cpp
    ${EDI_SRC_DIR}/fast_gehan_wilcox.cpp
    ${EDI_SRC_DIR}/fast_logrank.cpp
    ${EDI_SRC_DIR}/fast_wilcox_hl.cpp
    ${EDI_SRC_DIR}/fast_survival_stats.cpp
    ${EDI_SRC_DIR}/fast_ridit_analysis.cpp
    ${EDI_SRC_DIR}/robust_post_fit_speedups.cpp
)

# R/EDI/src's unity-build collision audit and fix pass are complete
# (R/package_metadata/finished_features/unity_build_collision_audit.md) --
# the file-scope helper collisions that would break merging these sources
# into fewer translation units are fixed, verified via a full mega-TU
# -fsyntax-only compile, and the R-side build (R/EDI/configure, EDI_UNITY=1)
# has been wired, built end-to-end (real compile+link+load), and shown to
# produce bit-identical numeric output against the non-unity build (see
# release_v1_0_0.md -> TODO-6). Enabled below (CMake's native UNITY_BUILD,
# available since 3.16) -- a pure build-time win with zero change to the
# compiled kernels' behavior or this module's public API. set_target_
# properties must come after pybind11_add_module creates the _core target,
# not before.

# pybind11_add_module enables LTO by default in Release builds unless this
# variable is explicitly defined. A trailing target-level -fno-lto is not
# sufficient: pybind11's interface target appends -flto afterwards, which is
# exactly what happened on piwheels' post5 ARM builds. Define this before the
# target is created so pybind11 never adds its automatic LTO flags.
set(CMAKE_INTERPROCEDURAL_OPTIMIZATION OFF)

pybind11_add_module(_core
    cpp/bindings_module.cpp
    cpp/bindings_fast_math.cpp
    cpp/bindings_glmm.cpp
    cpp/bindings_continuous.cpp
    cpp/bindings_binary.cpp
    cpp/bindings_count.cpp
    cpp/bindings_proportion.cpp
    cpp/bindings_ordinal.cpp
    cpp/bindings_incidence.cpp
    cpp/bindings_survival.cpp
    ${EDI_KERNEL_SOURCES}
)

# piwheels' 32-bit ARM workers exhausted memory when Ninja compiled six
# ten-source unity translation units concurrently. Keep the normal batch size
# elsewhere, but use smaller translation units and a single-slot Ninja compile
# pool on 32-bit ARM. JOB_POOL_COMPILE is intentionally target-scoped and is
# ignored by generators without job-pool support.
set(EDI_PY_UNITY_BATCH_SIZE 10)
set(EDI_PY_32BIT_ARM FALSE)
if(CMAKE_SIZEOF_VOID_P EQUAL 4 AND CMAKE_SYSTEM_PROCESSOR MATCHES "^[Aa][Rr][Mm]")
    set(EDI_PY_32BIT_ARM TRUE)
    set(EDI_PY_UNITY_BATCH_SIZE 4)
    set_property(GLOBAL APPEND PROPERTY JOB_POOLS edi_arm_compile_pool=1)
    set_property(TARGET _core PROPERTY JOB_POOL_COMPILE edi_arm_compile_pool)
    message(STATUS "32-bit ARM build: serializing compilation and using unity batch size ${EDI_PY_UNITY_BATCH_SIZE}.")
endif()

set_target_properties(_core PROPERTIES
    INTERPROCEDURAL_OPTIMIZATION OFF
    UNITY_BUILD ON
    UNITY_BUILD_BATCH_SIZE ${EDI_PY_UNITY_BATCH_SIZE}
)

target_include_directories(_core PRIVATE ${EDI_SRC_DIR} cpp ${EDI_LBFGSPP_SHIM_DIR} ${lbfgspp_SOURCE_DIR}/include)
if(Eigen3_FOUND)
    target_link_libraries(_core PRIVATE Eigen3::Eigen)
else()
    target_link_libraries(_core PRIVATE eigen)
endif()
if(OpenMP_CXX_FOUND)
    target_link_libraries(_core PRIVATE OpenMP::OpenMP_CXX)
endif()
target_link_libraries(_core PRIVATE ${BLAS_LIBRARIES})

target_compile_definitions(_core PRIVATE NDEBUG EIGEN_NO_DEBUG)
if(MSVC)
    # M_PI (and the other <cmath> M_* constants) is a POSIX/GNU extension --
    # glibc/Apple libc++ expose it unconditionally, but MSVC's CRT only
    # defines it when _USE_MATH_DEFINES is set before <cmath>/<math.h> is
    # first included. R/EDI/src uses M_PI directly in several files (shared
    # via _helper_functions_core.h/_glmm_engine.h, hence a target-wide
    # define here rather than patching each file's include order) -- the R
    # package build never hit this because RcppEigen/R itself always
    # defines M_PI regardless of platform.
    target_compile_definitions(_core PRIVATE _USE_MATH_DEFINES)
endif()
if(EDI_USING_SCIPY_OPENBLAS)
    target_include_directories(_core PRIVATE ${SCIPY_OPENBLAS_INCLUDE_DIR})
    # scipy_openblas32 renames its exported BLAS/CBLAS symbols with a
    # "scipy_" prefix (BLAS_SYMBOL_PREFIX=scipy_, see its get_pkg_config())
    # to avoid clashing with any other OpenBLAS build loaded in the same
    # process -- _helper_functions_core.h's `extern "C" void cblas_dsyrk(...)`
    # declares and calls the un-prefixed name, so without this the linker
    # can't resolve it against scipy_openblas32's library. This #define
    # (via -D) transparently renames every `cblas_dsyrk` token, in both the
    # extern "C" declaration and the call site, to the actual exported
    # symbol -- unnecessary (and unset) when a system/manylinux/Accelerate
    # BLAS provides the un-prefixed name directly.
    target_compile_definitions(_core PRIVATE cblas_dsyrk=scipy_cblas_dsyrk)
    # libscipy_openblas.so lives inside the scipy_openblas32 *package's own*
    # site-packages tree (its get_lib_dir()), never on any system linker
    # search path -- and that package is only guaranteed present in pip's
    # *ephemeral* isolated build environment (see ../pyproject.toml's
    # [build-system] comment), which is deleted once the wheel is built. A
    # cibuildwheel-built wheel doesn't care (auditwheel/delocate/delvewheel
    # repair physically bundles whichever BLAS got linked into the wheel
    # itself), but a plain `pip install` from the sdist has no such repair
    # step -- confirmed the hard way: it built and installed successfully,
    # then failed at `import edi_kernels` with "libscipy_openblas.so: cannot
    # open shared object file" on 2026-08-11, on a stock ubuntu-latest CI
    # runner, in the isolated verification venv the "Verify sdist installs
    # from source" CI step (TODO-12) creates for exactly this class of bug.
    # Fix: an $ORIGIN/@loader_path-relative RPATH, set at build time but
    # only resolved at import time in whatever venv the wheel eventually
    # gets installed into -- valid because scipy_openblas32 is declared as a
    # genuine (not just build-time) runtime dependency in ../pyproject.toml,
    # so it always ends up as a sibling package directory next to
    # edi_kernels/ in that venv's site-packages, regardless of which venv
    # that turns out to be. Windows PE DLL loading has no RPATH equivalent
    # (PATH/DLL-search-order based instead) and isn't handled here -- a
    # from-source build on Windows without delvewheel repair is a separate,
    # not-yet-exercised problem (see "Building portable wheels" in
    # python_bindings_package_spec.md).
    if(APPLE)
        set_target_properties(_core PROPERTIES INSTALL_RPATH "@loader_path/../scipy_openblas32/lib")
    elseif(NOT WIN32)
        set_target_properties(_core PROPERTIES INSTALL_RPATH "$ORIGIN/../scipy_openblas32/lib")
    endif()
    if(NOT WIN32)
        set_target_properties(_core PROPERTIES BUILD_WITH_INSTALL_RPATH TRUE)
    endif()
endif()
# These are GCC/Clang flags; MSVC (Windows wheel builds, see
# [tool.cibuildwheel.windows]) doesn't understand '-' prefixed options like
# this at all -- cl.exe merely warns (D9002) and ignores them rather than
# failing, but there's no reason to pass nonsense flags to it. CMake's own
# default Release flags already include MSVC's /O2 without any help here.
if(NOT MSVC)
    target_compile_options(_core PRIVATE -Wno-ignored-attributes)
    if(NOT EDI_PY_PORTABLE)
        target_compile_options(_core PRIVATE -march=native -mtune=native)
    endif()
    target_compile_options(_core PRIVATE $<$<CONFIG:Release>:-O3>)
endif()

install(TARGETS _core LIBRARY DESTINATION edi_kernels)
