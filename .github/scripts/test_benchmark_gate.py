#!/usr/bin/env python3
"""Checks for benchmark_gate.py (stdlib only). The file-rule checks are pure;
the decision checks build a throwaway git repository."""
import datetime as dt
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import benchmark_gate as g  # noqa: E402

REPO = Path(__file__).resolve().parents[2]


class FileRules(unittest.TestCase):
    def t(self, path):
        return g.r_targets(path)

    def test_family_r_files(self):
        self.assertEqual(self.t("R/EDI/R/inference_survival_cox.R"),
                         {"models-survival", "wald-survival", "procedures"})
        self.assertEqual(self.t("R/EDI/R/inference_count_negbin.R"), {"models-count", "wald-count"})
        self.assertEqual(self.t("R/EDI/R/inference_indicidence_x.R"),
                         {"models-incidence", "wald-incidence", "procedures"})

    def test_shared_inference_files_rerun_every_family(self):
        t = self.t("R/EDI/R/inference_all_abstract.R")
        self.assertTrue({f"models-{f}" for f in g.FAMILIES} <= t)
        self.assertIn("procedures", t)
        self.assertNotIn("designs", t)
        self.assertNotIn("utility", t)

    def test_cpp_keywords(self):
        self.assertEqual(self.t("R/EDI/src/fast_coxph_regression.cpp"),
                         {"models-survival", "wald-survival", "procedures"})
        self.assertEqual(self.t("R/EDI/src/fast_ordinal_probit_regression.cpp"),
                         {"models-ordinal", "wald-ordinal"})
        self.assertEqual(self.t("R/EDI/src/zero_one_logit_transform.h"),
                         {"models-proportion", "wald-proportion"})

    def test_designs_resampling_utility(self):
        self.assertEqual(self.t("R/EDI/R/design_seq_one_by_one_kk21.R"), {"designs", "procedures"})
        self.assertEqual(self.t("R/EDI/src/kk21_weights.cpp"), {"designs", "procedures"})
        self.assertEqual(self.t("R/EDI/src/randomization_loop.cpp"), {"procedures"})
        self.assertEqual(self.t("R/EDI/src/fast_math_utils.cpp"), {"utility"})
        self.assertEqual(self.t("R/EDI/src/fast_gamma_functions.h"), set(g.R_JOBS))

    def test_unclaimed_code_reruns_everything_and_non_code_nothing(self):
        self.assertEqual(self.t("R/EDI/src/_helper_functions_core.h"), set(g.R_JOBS))
        self.assertEqual(self.t("R/EDI/R/helper_glm_fit.R"), set(g.R_JOBS))
        self.assertEqual(self.t("R/EDI/DESCRIPTION"), set(g.R_JOBS))
        self.assertEqual(self.t("R/benchmark/benchmark_sections.R"), set(g.R_JOBS))
        self.assertEqual(self.t("R/EDI/src/RcppExports.cpp"), set())
        self.assertEqual(self.t("R/EDI/man/foo.Rd"), set())
        self.assertEqual(self.t("README.md"), set())

    def test_every_tracked_source_file_maps_to_known_jobs(self):
        files = subprocess.run(["git", "-C", str(REPO), "ls-files", "R/EDI/R", "R/EDI/src"],
                               capture_output=True, text=True, check=True).stdout.split()
        for p in files:
            self.assertLessEqual(g.r_targets(p), set(g.R_JOBS), p)

    def test_python_targets(self):
        k = {"fast_ols.cpp"}
        self.assertTrue(g.python_target("R/EDI/src/fast_ols.cpp", k))
        self.assertFalse(g.python_target("R/EDI/src/kk21_weights.cpp", k))
        self.assertTrue(g.python_target("R/EDI/src/_helper_functions_core.h", k))
        self.assertTrue(g.python_target("python/cpp/bindings_glm.cpp", k))
        self.assertTrue(g.python_target("python/CMakeLists.txt", k))
        self.assertTrue(g.python_target("R/benchmark/benchmark_model_fits_python.py", k))
        self.assertFalse(g.python_target("R/EDI/R/inference_count_negbin.R", k))
        self.assertFalse(g.python_target("python/README.md", k))

    def test_kernel_sources_parse_from_this_repo(self):
        os.chdir(REPO)
        srcs = g.python_kernel_sources("HEAD")
        self.assertIn("fast_ols.cpp", srcs)


class Decisions(unittest.TestCase):
    def setUp(self):
        self.old = os.getcwd()
        self.dir = tempfile.mkdtemp()
        os.chdir(self.dir)
        run = lambda *a: subprocess.run(["git", *a], check=True, capture_output=True)
        run("init", "-q", "-b", "main")
        run("config", "user.email", "t@t"); run("config", "user.name", "t")
        os.makedirs("R/EDI/R"); os.makedirs("R/EDI/src"); os.makedirs("python")
        Path("python/CMakeLists.txt").write_text("set(S ${EDI_SRC_DIR}/fast_coxph_regression.cpp)\n")
        Path("R/EDI/R/inference_survival_cox.R").write_text("f = function() 1\n")
        Path("R/EDI/src/fast_coxph_regression.cpp").write_text("int f() { return 1; }\n")
        run("add", "-A"); run("commit", "-qm", "base")
        self.base = subprocess.run(["git", "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()
        self.run = run
        self.now = dt.datetime(2026, 11, 17, tzinfo=dt.timezone.utc)

    def tearDown(self):
        os.chdir(self.old)

    def manifest(self, days_old=1):
        t = (self.now - dt.timedelta(days=days_old)).isoformat()
        e = {"commit": self.base, "timed_at": t}
        return {"jobs": {j: dict(e) for j in g.R_JOBS}, "python": dict(e)}

    def commit(self, path, text):
        Path(path).write_text(text)
        self.run("add", "-A"); self.run("commit", "-qm", "x")
        return subprocess.run(["git", "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()

    def test_comment_only_change_runs_nothing(self):
        head = self.commit("R/EDI/R/inference_survival_cox.R", "# a comment\nf = function() 1\n")
        d = g.decide(self.manifest(), head, "auto", 14, self.now)
        self.assertFalse(any(run for run, _ in d.values()), d)

    def test_functional_change_runs_only_its_jobs(self):
        head = self.commit("R/EDI/R/inference_survival_cox.R", "f = function() 2\n")
        d = g.decide(self.manifest(), head, "auto", 14, self.now)
        ran = {j for j, (run, _) in d.items() if run}
        self.assertEqual(ran, {"models-survival", "wald-survival", "procedures"})

    def test_kernel_change_also_runs_python(self):
        head = self.commit("R/EDI/src/fast_coxph_regression.cpp", "int f() { return 2; }\n")
        d = g.decide(self.manifest(), head, "auto", 14, self.now)
        self.assertTrue(d["python"][0])

    def test_missing_old_and_unknown_rows_run(self):
        head = self.base
        m = self.manifest()
        del m["jobs"]["utility"]
        m["jobs"]["designs"]["commit"] = "0" * 40
        m["jobs"]["procedures"]["timed_at"] = (self.now - dt.timedelta(days=20)).isoformat()
        d = g.decide(m, head, "auto", 14, self.now)
        self.assertEqual({j for j, (run, _) in d.items() if run}, {"utility", "designs", "procedures"})
        self.assertIn("no saved rows", d["utility"][1])
        self.assertIn("20 days old", d["procedures"][1])

    def test_failed_verdict_reruns(self):
        m = self.manifest()
        m["jobs"]["wald-count"]["verdict"] = "failure"
        m["jobs"]["wald-ordinal"]["verdict"] = "success"
        d = g.decide(m, self.base, "auto", 14, self.now)
        self.assertEqual({j for j, (run, _) in d.items() if run}, {"wald-count"})
        self.assertIn("regression", d["wald-count"][1])

    def test_no_manifest_runs_everything_and_modes(self):
        d = g.decide({}, self.base, "auto", 14, self.now)
        self.assertTrue(all(run for run, _ in d.values()))
        self.assertTrue(all(run for run, _ in g.decide(self.manifest(), self.base, "all", 14, self.now).values()))
        self.assertFalse(any(run for run, _ in g.decide({}, self.base, "none", 14, self.now).values()))

    def test_cli_outputs_matrix(self):
        Path("m.json").write_text(json.dumps(self.manifest()))
        self.commit("R/EDI/R/inference_count_negbin.R", "g = function() 1\n")
        out = Path("out.txt")
        g.main(["--manifest", "m.json", "--now", self.now.isoformat(), "--github-output", str(out)])
        kv = dict(line.split("=", 1) for line in out.read_text().splitlines())
        self.assertEqual(kv["bench"], "true")
        self.assertEqual(kv["python"], "false")
        inc = json.loads(kv["bench_matrix"])["include"]
        self.assertEqual({e["id"] for e in inc}, {"models-count", "wald-count"})
        self.assertEqual(inc[0]["section"], "models")
        self.assertEqual(inc[0]["families"], "count")


if __name__ == "__main__":
    unittest.main(verbosity=1)
