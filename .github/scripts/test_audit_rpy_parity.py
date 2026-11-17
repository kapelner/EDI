#!/usr/bin/env python3
"""Checks for the R <-> Python parity audit (audits/rpy_parity.py). Stdlib only."""
import datetime as dt
import re
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import audit_common as ac  # noqa: E402
from audits import _rotation as rot  # noqa: E402
from audits import rpy_parity as rp  # noqa: E402

NOW = dt.datetime(2026, 12, 19, 6, tzinfo=dt.timezone.utc)
REPO = Path(__file__).resolve().parents[2]

BIND = r'''ModelResult fast_foo_internal(const Eigen::MatrixXd& X, double tol, int maxit);

static void bind_pair(py::module_& m, const char* name, const char* doc) {
    m.def(name, [](double x) { return fast_foo_internal(x, 1e-8, 10); }, py::arg("x"), doc);
}

void bind_foo(py::module_& m) {
    // m.def("commented_out", ...) is not a binding
    m.def("fast_foo", [](const Eigen::MatrixXd& X, double tol, int maxit, bool verbose) {
        // fast_bar_internal is only named in this comment
        ModelResult res = fast_foo_internal(X, tol, maxit);
        return res.b;
    },
    py::arg("X"), py::arg("tol") = 1e-8, py::arg("maxit") = 20, py::arg("verbose") = false,
    "Fast foo regression (see fast_bar_internal).\n\n"
    "Parameters\n"
    "----------\n"
    "maxit : int, default 20\n"
    "    Maximum number of \"Newton\" iterations.");
    bind_pair(m, "fast_pair_a", "doc a");
}
'''
SRC = '''#include "x.h"
ModelResult fast_foo_internal(const Eigen::MatrixXd& X, double tol, int maxit) {
    return ModelResult();
}

// [[Rcpp::export]]
List fast_foo_cpp(const Eigen::Map<Eigen::MatrixXd>& X, double tol = 1e-8, int maxit = 100,
                  bool verbose = false, Rcpp::Nullable<Rcpp::NumericVector> w = R_NilValue) {
    return wrap(fast_foo_internal(X, tol, maxit));
}

ModelResult fast_bar_internal(double x) {
    return ModelResult();
}
'''
STUB = '''from __future__ import annotations
def fast_foo(X: numpy.ndarray, tol: float = 1e-08, maxit: int = 20, verbose: bool = False) -> dict:
    """
    Fast foo regression (see fast_bar_internal).

    Parameters
    ----------
    maxit : int, default 20
        Maximum number of "Newton" iterations.
    """
'''
R_CALL = "f = function(X) fast_foo_cpp(X, tol = 1e-6)\n"


class Parsing(unittest.TestCase):
    def test_bindings(self):
        b = rp.bindings(BIND)
        self.assertEqual([(x["name"], x["literal"]) for x in b],
                         [("name", False), ("fast_foo", True)])
        foo = b[1]
        self.assertTrue(foo["text"].endswith('iterations.")'))
        self.assertEqual(rp.py_args(foo["text"]),
                         [("X", ""), ("tol", "1e-8"), ("maxit", "20"), ("verbose", "false")])
        self.assertEqual(rp.helper_names(BIND, b[0]["offset"]), ["fast_pair_a"])

    def test_code_only_hides_docstring_names(self):
        code = rp.code_only(rp.bindings(BIND)[1]["text"])
        self.assertIn("fast_foo_internal", code)
        self.assertNotIn("fast_bar_internal", code)

    def test_defaults(self):
        sig = "List f(const Eigen::Map<Eigen::MatrixXd>& X, double tol = 1e-8, std::string m = \"a,b\", " \
              "Rcpp::Nullable<Rcpp::NumericVector> w = R_NilValue)"
        self.assertEqual(rp.cpp_defaults(sig), {"tol": "1e-8", "m": '"a,b"', "w": "R_NilValue"})
        self.assertEqual(rp.norm_default("1e-8"), rp.norm_default("1e-08"))
        self.assertEqual(rp.norm_default("true"), ("bool", True))
        self.assertEqual(rp.norm_default("py::none()"), rp.norm_default("R_NilValue"))
        self.assertIsNone(rp.norm_default("some_constant"))
        self.assertEqual(rp.norm_default("50L"), ("num", 50.0))

    def test_stub_blocks(self):
        s = rp.stub_blocks(STUB + "@typing.overload\ndef g(x: int) -> int:\n    ...\n")
        self.assertEqual(sorted(s), ["fast_foo", "g"])
        self.assertIn("Newton", s["fast_foo"])

    def test_exports_reaching(self):
        bodies = rp.function_bodies({"a.cpp": SRC})
        self.assertEqual(rp.exports_reaching("fast_foo_internal", bodies, {"fast_foo_cpp"}), ["fast_foo_cpp"])
        self.assertEqual(rp.exports_reaching("fast_bar_internal", bodies, {"fast_foo_cpp"}), [])


class Repo(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp())
        files = {"python/cpp/bindings_foo.cpp": BIND, "R/EDI/src/fast_foo.cpp": SRC,
                 "python/src/edi_kernels/_core.pyi": STUB,
                 "python/src/edi_kernels/__init__.py": "from ._core import (\n    fast_foo,\n)\n",
                 "R/EDI/R/foo.R": R_CALL, "python/tests/test_fast_foo.py": "\n",
                 "R/EDI/man/fast_foo_cpp.Rd": "\\name{fast_foo_cpp}\n"}
        for rel, text in files.items():
            p = self.root / rel
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text(text)

    def tearDown(self):
        shutil.rmtree(self.root, ignore_errors=True)

    def ctx(self, event="schedule"):
        return ac.Context(ac.spec_of(rp), self.root, ac.Notes(self.root / "notes", "rpy-parity"),
                          self.root / "work", now=NOW, event=event)

    def test_units(self):
        u = rp.units(self.ctx())
        self.assertEqual(sorted(u), ["python/cpp/bindings_foo.cpp::<name>", "python/cpp/bindings_foo.cpp::fast_foo"])
        c = u["python/cpp/bindings_foo.cpp::fast_foo"]["context"]
        self.assertEqual(c["kernel_functions"], [{"function": "fast_foo_internal", "file": "R/EDI/src/fast_foo.cpp"}])
        self.assertEqual([(e["export"], e["relation"], e["rd"]) for e in c["r_exports"]],
                         [("fast_foo_cpp", "same name", "R/EDI/man/fast_foo_cpp.Rd")])
        self.assertEqual(c["r_callers"][0]["file"], "R/EDI/R/foo.R")
        self.assertEqual(c["python_tests"], ["python/tests/test_fast_foo.py"])
        self.assertIn("Newton", c["stub"])
        self.assertEqual(u["python/cpp/bindings_foo.cpp::<name>"]["context"]["python_names"], ["fast_pair_a"])

    def test_scheduled_units_rotate_push_units_do_not(self):
        self.assertEqual({v["cycle_weeks"] for v in rp.units(self.ctx()).values()}, {6})

    def test_push_reads_no_rotation_slice(self):
        for event in ("push", "workflow_run"):   # a push arrives as workflow_run in CI
            cycles = {v["cycle_weeks"] for v in rp.units(self.ctx(event)).values()}
            self.assertEqual(cycles, {rot.NEVER}, event)
        cycles = {v["cycle_weeks"] for v in rp.units(self.ctx("workflow_dispatch")).values()}
        self.assertEqual(cycles, {6})

    def test_mechanical(self):
        found = rp.mechanical(self.ctx())
        kinds = sorted(f["kind"] for f in found)
        self.assertEqual(kinds, ["default_mismatch", "not_exported", "stub_missing"])
        dm = next(f for f in found if f["kind"] == "default_mismatch")
        self.assertIn("maxit = 20", dm["text"])
        self.assertIn("maxit = 100", dm["text"])
        self.assertTrue(all("fast_pair_a" in f["text"] for f in found if f["kind"] != "default_mismatch"))

    def test_check_fix(self):
        t = BIND
        ok = rp.check_fix(t, "python/cpp/bindings_foo.cpp", "Maximum number of", "Maximum count of")
        self.assertIsNone(ok)
        self.assertIn("2 times", rp.check_fix(t + "\n// Maximum number of\n", "python/cpp/bindings_foo.cpp",
                                              "Maximum number of", "x"))
        self.assertIn("string literal", rp.check_fix(t, "python/cpp/bindings_foo.cpp",
                                                     "iterations.", 'iterations." + x + "'))
        self.assertIn("not inside", rp.check_fix(t, "python/cpp/bindings_foo.cpp", "ModelResult res", "X res"))
        self.assertIn("one string literal", rp.check_fix(t, "python/cpp/bindings_foo.cpp",
                                                         'Parameters\\n"\n    "----', "P"))
        self.assertIsNone(rp.check_fix(STUB, rp.STUB, "Maximum number of", "Maximum count of"))
        self.assertIn("not inside", rp.check_fix(STUB, rp.STUB, "maxit: int = 20", "maxit: int = 100"))
        self.assertIn("only .cpp", rp.check_fix("x", "python/CMakeLists.txt", "x", "y"))

    def test_apply(self):
        ctx = self.ctx()
        res = [{"units_checked": ["python/cpp/bindings_foo.cpp::fast_foo"], "_batch": "b001", "_units": [], "findings": [
            {"unit": "python/cpp/bindings_foo.cpp::fast_foo", "kind": "docstring",
             "text": "the docstring says maxit 20 is Newton", "python_location": "", "r_location": "",
             "suggestion": "", "fix": {"file": "python/cpp/bindings_foo.cpp",
                                       "old_text": "Maximum number of", "new_text": "Maximum count of"}},
            {"unit": "python/cpp/bindings_foo.cpp::fast_foo", "kind": "default_mismatch",
             "text": "maxit differs", "python_location": "", "r_location": "",
             "suggestion": "raise to 100", "fix": {"file": "", "old_text": "", "new_text": ""}},
            {"unit": "python/cpp/bindings_foo.cpp::fast_foo", "kind": "docstring", "text": "outside",
             "python_location": "", "r_location": "", "suggestion": "",
             "fix": {"file": "R/EDI/R/foo.R", "old_text": "f =", "new_text": "g ="}},
        ]}]
        parts = rp.apply(ctx, res, [])
        self.assertEqual(len(parts["applied"]), 1)
        self.assertIn("Maximum count of", (self.root / "python/cpp/bindings_foo.cpp").read_text())
        self.assertIn("Maximum count of", (self.root / rp.STUB).read_text())      # stub kept in step
        self.assertIn("same change in", parts["applied"][0])
        self.assertEqual(len(ac.texts(parts["human"])), 2)
        self.assertIn("raise to 100", ac.texts(parts["human"])[0])
        self.assertIn("outside python/", ac.texts(parts["human"])[1])
        self.assertEqual((self.root / "R/EDI/R/foo.R").read_text(), R_CALL)
        applied = [p for p in parts["proposed"] if p.get("applied_file")]
        self.assertEqual([(p["applied_file"], p["applied_text"]) for p in applied],
                         [("python/cpp/bindings_foo.cpp", "Maximum count of")])


WF = REPO / ".github/workflows"
# Events anthropics/claude-code-action@v1 accepts (src/github/context.ts parseGitHubContext);
# any other event makes it fail with "Unsupported event type: <event>" before the agent starts.
CLAUDE_ACTION_EVENTS = {"workflow_dispatch", "repository_dispatch", "schedule", "workflow_run",
                        "issues", "issue_comment", "pull_request", "pull_request_target",
                        "pull_request_review", "pull_request_review_comment"}


def triggers(text):
    """The event names under a workflow's top-level `on:` block."""
    m = re.search(r"^on:[ \t]*\n((?:[ \t]+.*\n|[ \t]*\n)*)", text, re.M)
    return set(re.findall(r"^  ([a-z_]+):", m.group(1), re.M)) if m else set()


class Workflow(unittest.TestCase):
    def test_push_paths_match_cmake_kernel_sources(self):
        wf = (WF / "rpy-parity-push.yml").read_text()
        listed = set(re.findall(r'"R/EDI/src/([A-Za-z0-9_]+\.cpp)"', wf))
        cmake = set(rp.kernel_sources((REPO / rp.CMAKE).read_text()))
        self.assertTrue(cmake)
        self.assertEqual(listed, cmake, "update the push paths in rpy-parity-push.yml")
        for p in ("python/cpp/**", "python/src/**", "python/CMakeLists.txt"):
            self.assertIn(f'"{p}"', wf)

    def test_push_reaches_the_audit_through_workflow_run(self):
        relay = (WF / "rpy-parity-push.yml").read_text()
        caller = (WF / "audit-rpy-parity.yml").read_text()
        self.assertEqual(triggers(relay), {"push"})
        self.assertIn("workflow_run", triggers(caller))
        name = re.search(r"^name:\s*(.+)$", relay, re.M).group(1).strip()
        self.assertIn(f'workflows: ["{name}"]', caller, "workflow_run must name the relay workflow")
        self.assertIn("github.event.workflow_run.conclusion == 'success'", caller)

    def test_claude_audits_use_events_the_action_accepts(self):
        # Runs 44065338574 and 44072918994: a `push` trigger on the rpy-parity caller made every
        # Claude batch fail with "Unsupported event type: push" (reported as NOT RUN).
        for p in sorted(WF.glob("audit-*.yml")):
            text = p.read_text()
            audit = re.search(r"^[ \t]+audit:[ \t]*([\w-]+)[ \t]*$", text, re.M)
            if "uses: ./.github/workflows/audit.yml" not in text or not audit:
                continue
            if not ac.spec_of(ac.load_audit(audit.group(1))).get("claude"):
                continue
            bad = triggers(text) - CLAUDE_ACTION_EVENTS
            self.assertFalse(bad, f"{p.name} triggers on {sorted(bad)}, which claude-code-action rejects")


if __name__ == "__main__":
    unittest.main(verbosity=1)
