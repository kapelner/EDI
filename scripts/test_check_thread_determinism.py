"""Planted-violation tests for scripts/check_thread_determinism.py.

v1.1.0 cross_platform_reproducibility.md TODO-2: the static check must fail on
each planted violation (including a floating-point `parallel for` reduction),
pass the allowed patterns, and keep its allowlist honest. Snippets are written
to a scratch directory under $TMPDIR, never into R/EDI/src.

Run: python3 scripts/test_check_thread_determinism.py
"""
import contextlib
import io
import os
import sys
import tempfile
import textwrap
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import check_thread_determinism as checker  # noqa: E402

HEADER = "file,rule,match,reason\n"


class ThreadDeterminismCheckTests(unittest.TestCase):

    def run_checker(self, source, allowlist=HEADER, name="planted.cpp"):
        with tempfile.TemporaryDirectory(dir=os.environ.get("TMPDIR")) as tmp:
            src = os.path.join(tmp, "src")
            os.mkdir(src)
            with open(os.path.join(src, name), "w") as fh:
                fh.write(textwrap.dedent(source))
            allow = os.path.join(tmp, "allow.csv")
            with open(allow, "w") as fh:
                fh.write(allowlist)
            err = io.StringIO()
            with contextlib.redirect_stderr(err), contextlib.redirect_stdout(io.StringIO()):
                status = checker.main([src, "--allowlist", allow])
            return status, err.getvalue()

    def assert_flags(self, source, rule):
        status, err = self.run_checker(source)
        self.assertEqual(status, 1, "expected [%s] to fail:\n%s" % (rule, source))
        self.assertIn("[%s]" % rule, err)

    def assert_clean(self, source):
        status, err = self.run_checker(source)
        self.assertEqual(status, 0, err)

    # ---- always-banned RNG patterns -------------------------------------
    def test_std_shuffle(self):
        self.assert_flags("void f(std::vector<int>& v, G& g) { std::shuffle(v.begin(), v.end(), g); }\n", "rng-shuffle")

    def test_random_shuffle(self):
        self.assert_flags("void f(std::vector<int>& v) { std::random_shuffle(v.begin(), v.end()); }\n", "rng-shuffle")

    def test_include_random(self):
        self.assert_flags("#include <random>\nint x;\n", "rng-include")

    def test_engine(self):
        self.assert_flags("std::mt19937_64 gen(42);\n", "rng-engine")

    def test_default_random_engine(self):
        self.assert_flags("std::default_random_engine gen;\n", "rng-engine")

    def test_distribution(self):
        self.assert_flags("std::normal_distribution<double> nd(0.0, 1.0);\n", "rng-distribution")

    def test_random_device(self):
        self.assert_flags("std::random_device rd;\n", "rng-random-device")

    def test_c_rand(self):
        self.assert_flags("int f() { return rand() % 6; }\n", "rng-c-rand")

    def test_c_srand(self):
        self.assert_flags("void f() { srand(1); }\n", "rng-c-rand")

    def test_thread_indexed_seed_direct(self):
        self.assert_flags("""
            #pragma omp parallel
            { edi_rng::RRng rng(master_seed + omp_get_thread_num()); }
            """, "rng-thread-seed")

    def test_thread_indexed_seed_via_variable(self):
        self.assert_flags("""
            #pragma omp parallel
            {
                const int tid = omp_get_thread_num();
                edi_rng::RRng rng(edi_rng::seed_for_index(master_seed, tid));
            }
            """, "rng-thread-seed")

    def test_rng_rules_cannot_be_allowlisted(self):
        status, err = self.run_checker(
            "std::mt19937 gen(1);\n",
            HEADER + "planted.cpp,rng-engine,std::mt19937,legacy\n")
        self.assertEqual(status, 1)
        self.assertIn("always banned", err)

    # ---- floating-point combination order -------------------------------
    def test_float_parallel_for_reduction(self):
        self.assert_flags("""
            double f(const double* x, int n) {
                double total = 0.0;
                #pragma omp parallel for reduction(+:total)
                for (int i = 0; i < n; ++i) total += x[i];
                return total;
            }
            """, "float-reduction")

    def test_float_reduction_with_schedule_and_continuation(self):
        self.assert_flags("""
            double f(const double* x, int n) {
                double s = 0.0;
                #pragma omp parallel for schedule(static) \\
                    num_threads(4) reduction(+:s)
                for (int i = 0; i < n; ++i) s += x[i];
                return s;
            }
            """, "float-reduction")

    def test_float_worksharing_for_reduction(self):
        self.assert_flags("""
            void f(const double* x, int n, double& out) {
                double acc = 0;
                #pragma omp parallel
                {
                    #pragma omp for reduction(+:acc)
                    for (int i = 0; i < n; ++i) acc += x[i];
                }
                out = acc;
            }
            """, "float-reduction")

    def test_parallel_for_simd_reduction_is_still_across_threads(self):
        self.assert_flags("""
            float f(const float* x, int n) {
                float s = 0;
                #pragma omp parallel for simd reduction(+:s)
                for (int i = 0; i < n; ++i) s += x[i];
                return s;
            }
            """, "float-reduction")

    def test_pragma_operator_reduction(self):
        self.assert_flags("""
            double f(const double* x, int n) {
                double s = 0;
                _Pragma("omp parallel for reduction(+:s)")
                for (int i = 0; i < n; ++i) s += x[i];
                return s;
            }
            """, "float-reduction")

    def test_unknown_type_reduction_is_flagged(self):
        self.assert_flags("""
            #pragma omp parallel for reduction(+:mystery)
            for (int i = 0; i < n; ++i) mystery += g(i);
            """, "float-reduction")

    def test_integer_parallel_reduction_is_allowed(self):
        self.assert_clean("""
            int f(const int* x, int n) {
                int count = 0;
                #pragma omp parallel for reduction(+:count)
                for (int i = 0; i < n; ++i) count += x[i] > 0;
                return count;
            }
            """)

    def test_simd_reduction_is_allowed(self):
        self.assert_clean("""
            double f(const double* x, int n) {
                double s = 0.0;
                #pragma omp simd reduction(+:s)
                for (int i = 0; i < n; ++i) s += x[i];
                EDI_SIMD_REDUCTION(+:s)
                for (int i = 0; i < n; ++i) s += x[i];
                return s;
            }
            """)

    def test_float_atomic(self):
        self.assert_flags("""
            double total = 0.0;
            #pragma omp parallel for
            for (int i = 0; i < n; ++i) {
                #pragma omp atomic
                total += x[i];
            }
            """, "float-atomic")

    def test_integer_atomic_is_allowed(self):
        self.assert_clean("""
            int hits = 0;
            #pragma omp parallel for
            for (int i = 0; i < n; ++i) {
                #pragma omp atomic
                hits += 1;
            }
            """)

    def test_std_atomic_double(self):
        self.assert_flags("std::atomic<double> acc{0.0};\n", "float-atomic")

    def test_float_critical(self):
        self.assert_flags("""
            double best = 0.0;
            #pragma omp parallel
            {
                double local = work();
                #pragma omp critical
                { best += local; }
            }
            """, "float-critical")

    def test_thread_indexed_partials(self):
        self.assert_flags("""
            std::vector<double> part(64, 0.0);
            #pragma omp parallel
            {
                int tid = omp_get_thread_num();
                #pragma omp for
                for (int i = 0; i < n; ++i) part[tid] += x[i];
            }
            double total = 0; for (double p : part) total += p;
            """, "thread-partials")

    def test_float_container_sized_by_thread_count(self):
        self.assert_flags("""
            const int nt = omp_get_max_threads();
            std::vector<double> partial(nt, 0.0);
            """, "thread-partials")

    def test_interrupt_check_on_thread_zero_is_allowed(self):
        self.assert_clean("""
            inline void check() {
                if (omp_get_thread_num() != 0) return;
                R_CheckUserInterrupt();
            }
            """)

    def test_comments_and_strings_are_ignored(self):
        self.assert_clean("""
            // not std::shuffle: implementation-defined. Not #include <random>.
            /* std::mt19937 gen; #pragma omp parallel for reduction(+:s) */
            const char* msg = "rand() and std::random_device are banned";
            void g(std::vector<int>& v, edi_rng::RRng& rng) {
                edi_rng::fisher_yates_shuffle(v.begin(), v.end(), rng);
                double u = unif_rand(); (void)u;
                unsigned k = edi_rng::bounded_rand(rng, 3U); (void)k;
            }
            """)

    # ---- allowlist ------------------------------------------------------
    REDUCTION = """
        double f(const double* x, int n) {
            double total = 0.0;
            #pragma omp parallel for reduction(+:total)
            for (int i = 0; i < n; ++i) total += x[i];
            return total;
        }
        """

    def test_allowlist_with_reason_excuses_hit(self):
        status, err = self.run_checker(
            self.REDUCTION,
            HEADER + 'planted.cpp,float-reduction,reduction(+:total),"pending fix: per-index partials"\n')
        self.assertEqual(status, 0, err)

    def test_allowlist_without_reason_fails(self):
        status, err = self.run_checker(
            self.REDUCTION, HEADER + "planted.cpp,float-reduction,reduction(+:total),\n")
        self.assertEqual(status, 1)
        self.assertIn("reason is required", err)

    def test_stale_allowlist_entry_fails(self):
        status, err = self.run_checker(
            "int x;\n", HEADER + "planted.cpp,float-reduction,reduction(+:gone),old reason\n")
        self.assertEqual(status, 1)
        self.assertIn("matches nothing", err)

    # ---- the real source tree -------------------------------------------
    def test_real_src_passes(self):
        err = io.StringIO()
        with contextlib.redirect_stderr(err), contextlib.redirect_stdout(io.StringIO()):
            status = checker.main([])
        self.assertEqual(status, 0, err.getvalue())


if __name__ == "__main__":
    unittest.main()
