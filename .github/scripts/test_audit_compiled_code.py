#!/usr/bin/env python3
"""Checks for the compiled-code audit (audits/compiled_code.py): the perf, nm, objdump and
-fopt-info parsers, the loop detectors, the assembly hash, unit selection and the apply rules.
Stdlib only; fixtures are text, nothing is compiled or profiled."""
import datetime as dt
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import audit_common as ac  # noqa: E402
from audits import compiled_code as cc  # noqa: E402

NOW = dt.datetime(2026, 11, 28, 6, tzinfo=dt.timezone.utc)   # fourth Saturday of November

PERF = """# Samples: 162  of event 'cycles:Pu'
#
# Overhead       Samples  Shared Object         Symbol
# ........  ............  ....................  ................................
#
    48.91%            79  libm.so.6             [.] __log1p_fma
    19.20%            32  /tmp/lib/EDI/libs/EDI.so  [.] _Z4workPKdii
     9.00%            15  EDI.so                [.] _ZN5Eigen8internal4gemmEv
     5.00%             8  EDI.so                [.] _Z6helperv
     1.91%             3  EDI.so                [.] log1p@plt
     0.50%             1  EDI.so                [.] 0x0000000000001234
     0.08%             1  ld-linux-x86-64.so.2  [.] _dl_relocate_object_no_relro
"""

OBJDUMP = """
EDI.so:     file format elf64-x86-64

Disassembly of section .text:

0000000000001180 <_Z4workPKdii>:
    1180:\tendbr64
    1184:\tpush   %r15
    1194:\tjle    1286 <_Z4workPKdii+0x106>
    11c0:\tmov    $0x20,%edi
    11c5:\tcall   10b0 <_Znwm@plt>
    11f0:\tmovsd  0x0(%r13),%xmm1
    11f6:\tmovsd  0xe02(%rip),%xmm0        # 2000 <_fini+0xd70>
    120c:\tcall   1080 <exp@plt>
    1210:\tcall   *0x2fd2(%rip)        # 4ff8 <log@GLIBC_2.29>
    1216:\tcall   *%rax
    121a:\tcall   10c0 <Rf_allocVector@plt>
    121e:\tjne    1300 <_Z4workPKdii+0x180>
    1222:\tcall   1090 <R_CheckUserInterrupt@plt>
    1235:\tjne    11f0 <_Z4workPKdii+0x70>
    1262:\tcall   10a0 <_ZdlPvm@plt>
    126c:\tjne    11c0 <_Z4workPKdii+0x40>
    1270:\tcall   10d0 <free@plt>
    1285:\tret
    1286:\tmovq   $0x0,(%rsp)
    1290:\tret
    1300:\tlea    0x10(%rip),%rdi
    1304:\tcall   10e0 <__assert_fail@plt>
"""

NM = """0000000000000000 T _Z4workPKdii\t/build/EDI/src/fast_work.cpp:4
0000000000000040 t _ZL6helperv\t/build/EDI/src/fast_work.cpp:20
0000000000000000 W _ZN5Eigen8internal4gemmEv\t/usr/include/eigen3/Eigen/src/x.h:10
0000000000000000 U exp
0000000000000080 T _Z5nolinev
"""

OPTINFO = """fast_work.cpp:6:21: missed: couldn't vectorize loop
fast_work.cpp:6:21: missed: couldn't vectorize loop
fast_work.cpp:8:48: missed: statement clobbers memory: _6 = exp (_5);
fast_work.cpp:7:55: missed:   will not early inline: work/1 -> vector/2
fast_work.cpp:8:74: missed:   not inlinable: work/1 -> log1p/3, function body not available
fast_work.cpp:40:1: missed: couldn't vectorize loop
/usr/include/eigen3/Eigen/src/Core/x.h:6:1: missed: couldn't vectorize loop
"""

SRC = """#include <cmath>
// a helper
static double helper();
double work(const double* x, int n, int reps) {
  double s = 0;
  for (int r = 0; r < reps; ++r) {
    for (int i = 0; i < n; ++i) { s += std::exp(x[i]); }
    if (s > 1) { s = "}"[0]; }
  }
  return s;
}
"""


class Parsers(unittest.TestCase):
    def test_perf(self):
        rows = cc.parse_perf_report(PERF)
        self.assertEqual(len(rows), 7)
        s = cc.edi_samples(rows)
        self.assertEqual(s, {"_Z4workPKdii": 32, "_ZN5Eigen8internal4gemmEv": 15, "_Z6helperv": 8})

    def test_hot_set(self):
        s = {"a": 50, "b": 30, "c": 15, "d": 5}
        self.assertEqual([h["symbol"] for h in cc.hot_set(s, 0.9)], ["a", "b", "c"])
        self.assertEqual([h["symbol"] for h in cc.hot_set(s, 0.9, max_n=2)], ["a", "b"])
        self.assertEqual(cc.hot_set({}), [])
        self.assertEqual(cc.hot_set(s)[0]["share"], 50.0)

    def test_nm(self):
        n = cc.parse_nm(NM)
        self.assertEqual(n["_Z4workPKdii"], ("T", "/build/EDI/src/fast_work.cpp", 4))
        self.assertEqual(n["_ZL6helperv"][0], "t")
        self.assertEqual(n["_Z5nolinev"], ("T", None, None))
        self.assertNotIn("exp", n)

    def test_objdump_loops_and_detectors(self):
        ins = cc.parse_objdump(OBJDUMP)
        self.assertEqual(ins[0]["addr"], 0x1180)
        self.assertEqual(cc.loops(ins), [(0x11c0, 0x126c), (0x11f0, 0x1235)])
        d = cc.detect(ins)
        self.assertEqual(d["allocation_in_loop"], {"_Znwm@plt": 1, "Rf_allocVector@plt": 1})
        self.assertEqual(d["libm_in_loop"], {"exp@plt": 1, "log": 1})          # PLT and GOT call forms
        self.assertEqual(d["indirect_call_in_loop"], {"call *%rax": 1})
        self.assertEqual(d["r_api_in_loop"], {"R_CheckUserInterrupt@plt": 1})
        self.assertEqual(d["assert_reachable_in_loop"], {"__assert_fail@plt": 1})  # via the jne to 1300
        self.assertNotIn("free@plt", json.dumps(d))                             # after the loop

    def test_hash_ignores_addresses(self):
        ins = cc.parse_objdump(OBJDUMP)
        shifted = "\n".join(
            (f"    {int(l.split(':')[0], 16) + 0x5000:x}:" + l.split(":", 1)[1]) if l.startswith("    1") else l
            for l in OBJDUMP.splitlines())
        for a, b in (("1286 <", "6286 <"), ("10b0 <", "60b0 <"), ("1080 <", "6080 <"), ("10c0 <", "60c0 <"),
                     ("1300 <", "6300 <"), ("1090 <", "6090 <"), ("11f0 <", "61f0 <"), ("10a0 <", "60a0 <"),
                     ("11c0 <", "61c0 <"), ("10d0 <", "60d0 <"), ("10e0 <", "60e0 <"), ("4ff8 <", "9ff8 <"),
                     ("0x2fd2(%rip)", "0x7fd2(%rip)"), ("2000 <", "7000 <")):
            shifted = shifted.replace(a, b)
        ins2 = cc.parse_objdump(shifted)
        self.assertEqual(cc.normalise(ins), cc.normalise(ins2))
        changed = cc.parse_objdump(OBJDUMP.replace("call   1080 <exp@plt>", "call   1080 <log@plt>"))
        self.assertNotEqual(ac.text_hash(cc.normalise(ins)), ac.text_hash(cc.normalise(changed)))

    def test_opt_info(self):
        lines = cc.parse_opt_info(OPTINFO, "fast_work.cpp", 4, 11)
        vec, inl = cc.split_opt_info(lines)
        self.assertEqual(vec, ["fast_work.cpp:6: missed: couldn't vectorize loop",
                               "fast_work.cpp:8: missed: statement clobbers memory: _6 = exp (_5);"])
        self.assertEqual(len(inl), 1)
        self.assertIn("not inlinable", inl[0])

    def test_compile_command(self):
        log = ('* installing *source* package EDI ...\n'
               'g++ -std=gnu++20 -I"/usr/share/R/include" -DNDEBUG -fpic -g -O2 -c fast_work.cpp -o fast_work.o\n'
               'g++ -std=gnu++20 -c fast_work_more.cpp -o fast_work_more.o\n')
        cmd = cc.compile_command(log, "fast_work.cpp")
        self.assertEqual(cmd[-4:], ["-c", "fast_work.cpp", "-o", "fast_work.o"])
        self.assertIn("-I/usr/share/R/include", cmd)
        self.assertIsNone(cc.compile_command(log, "other.cpp"))
        new = cc.with_opt_info(cmd, "/tmp/x.o", "/tmp/info.txt")
        self.assertEqual(new[new.index("-o") + 1], "/tmp/x.o")
        self.assertEqual(new[-1], "-fopt-info-vec-inline-missed=/tmp/info.txt")
        self.assertIn("-Rpass-missed=loop-vectorize", cc.with_opt_info(cmd, "x.o", "i", clang=True))

    def test_brace_end_and_names(self):
        self.assertEqual(cc.brace_end(SRC.splitlines(), 4), 11)     # the "}" in a string does not count
        self.assertEqual(cc.short_name("double ns::work<std::vector<int> >(const double*, int) const"),
                         "double ns::work<std::vector<int> >")
        long = "R/EDI/src/x.cpp::" + "a" * 300
        self.assertLessEqual(len(cc.unit_id("R/EDI/src/x.cpp", "a" * 300 + "(int)")), 160)
        self.assertNotEqual(cc.unit_id("R/EDI/src/x.cpp", "a" * 300 + "b(int)"),
                            cc.unit_id("R/EDI/src/x.cpp", "a" * 300 + "c(int)"), long)


HOT = {"hot": [
    {"symbol": "_Z4workPKdii", "samples": 32, "share": 58.2, "function": "work(double const*, int, int)",
     "source_file": "R/EDI/src/fast_work.cpp", "start_line": 4, "end_line": 11, "object": "fast_work.o",
     "n_instructions": 21, "n_loops": 2, "asm_hash": "abc", "detectors": {"libm_in_loop": {"exp@plt": 1}},
     "vec_missed": ["fast_work.cpp:6: missed: couldn't vectorize loop"], "inline_missed": [],
     "loop_disassembly": ["11f0: movsd 0x0(%r13),%xmm1"], "compiler": "g++ 14"},
    {"symbol": "_Z5cleanv", "samples": 10, "share": 18.0, "function": "clean()",
     "source_file": "R/EDI/src/fast_work.cpp", "start_line": 20, "end_line": 30, "object": "fast_work.o",
     "n_instructions": 5, "n_loops": 0, "asm_hash": "def", "detectors": {}, "vec_missed": [],
     "inline_missed": [], "loop_disassembly": [], "compiler": "g++ 14"},
    {"symbol": "_Z4lostv", "samples": 5, "share": 9.0, "function": "lost()", "skip": "no object file"},
], "notes": ["models --families=continuous --shard=1/2: 40 EDI.so samples"], "errors": [], "library_share": 12.5}


class Stages(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.root = self.tmp / "repo"
        (self.root / "R/EDI/src").mkdir(parents=True)
        (self.root / "R/EDI/src/fast_work.cpp").write_text(SRC)
        subprocess.run(["git", "init", "-q"], cwd=self.root, check=True)
        subprocess.run(["git", "-c", "user.email=t@t", "-c", "user.name=t", "add", "-A"], cwd=self.root, check=True)
        subprocess.run(["git", "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-qm", "x"],
                       cwd=self.root, check=True)
        self.notes = ac.Notes(self.tmp / "notes", "compiled-code")
        self.work = self.tmp / "work"
        self.ctx = ac.Context(ac.spec_of(cc), self.root, self.notes, self.work, now=NOW, sha="feedbeef")
        (self.work / cc.WORK_SUB).mkdir(parents=True)
        (self.work / cc.WORK_SUB / "hot.json").write_text(json.dumps(HOT))

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def test_units_only_flagged_and_never_rotated(self):
        u = cc.units(self.ctx)
        self.assertEqual(list(u), ["R/EDI/src/fast_work.cpp::work"])
        self.assertEqual(u["R/EDI/src/fast_work.cpp::work"]["hash"], "abc")
        manifest = {"units": {"R/EDI/src/fast_work.cpp::work": {"hash": "abc"}}}
        for w in range(12):   # an unchanged assembly is never re-read
            self.assertEqual(ac.select_units(u, manifest, "auto", 1, NOW + dt.timedelta(weeks=4 * w),
                                             period="month")[0], [])
        self.assertEqual(ac.select_units(u, {"units": {"R/EDI/src/fast_work.cpp::work": {"hash": "old"}}},
                                         "auto", 1, NOW)[1], {"R/EDI/src/fast_work.cpp::work": "changed"})

    def test_mechanical_reports_failures_and_new_hot_functions(self):
        orig = cc.stage12
        try:
            cc.stage12 = lambda ctx: {"hot": [], "notes": [], "errors": ["perf is not available"], "library_share": 0}
            out = cc.mechanical(self.ctx)
            self.assertEqual([f["kind"] for f in out], ["stage_failed"])
            (self.notes.dir / "profile.json").write_text(json.dumps({"shares": {"clean()": 20.0}}))
            cc.stage12 = lambda ctx: HOT
            out = cc.mechanical(self.ctx)
            self.assertEqual(sorted(f["unit"] for f in out if f["kind"] == "became_hot"),
                             ["lost()", "work(double const*, int, int)"])
            self.assertIn("work(double const*, int, int)",
                          json.loads((self.notes.dir / "profile.json").read_text())["shares"])
        finally:
            cc.stage12 = orig

    def results(self):
        return [{"units_checked": ["R/EDI/src/fast_work.cpp::work"], "notes": "", "_batch": "b001",
                 "_units": ["R/EDI/src/fast_work.cpp::work"], "findings": [
                     {"unit": "R/EDI/src/fast_work.cpp::work", "kind": "proposal", "text": "hoist exp",
                      "file": "R/EDI/src/fast_work.cpp", "old_code": "s += std::exp(x[i]);",
                      "new_code": "s += ex[i];", "removes": "libm_in_loop exp@plt",
                      "expected_effect": "no call in the inner loop", "risk_to_results": "none"}]}]

    def test_apply_puts_the_change_in_the_tree_and_writes_the_followup(self):
        r = self.results()
        r[0]["findings"][0]["bench_code"] = "bench_setup = function() 1\nbench_run = function(d) d\n"
        parts = cc.apply(self.ctx, r, [])
        self.assertEqual(len(parts["applied"]), 1)
        self.assertIn("Benchmark check pending", parts["applied"][0])
        self.assertEqual(parts["human"], [])
        self.assertIn("draft PR", parts["summary"])
        src = (self.root / "R/EDI/src/fast_work.cpp").read_text()
        self.assertIn("s += ex[i];", src)
        self.assertNotIn("s += std::exp(x[i]);", src)
        (p,) = parts["proposed"]
        self.assertEqual(p["applied_file"], "R/EDI/src/fast_work.cpp")
        self.assertIn(p["applied_text"], src)                          # a merged PR is recognised as fixed
        fu = json.loads((self.work / cc.FOLLOWUP_SUB / "proposals.json").read_text())
        self.assertEqual([x["id"] for x in fu], ["p1"])
        self.assertEqual(fu[0]["old_code"], "s += std::exp(x[i]);")
        self.assertIn("bench_run", fu[0]["bench_code"])
        self.assertTrue(cc.SPEC["pr_draft"])

    def test_unit_with_a_pending_proposal_is_not_reread(self):
        self.assertIn("R/EDI/src/fast_work.cpp::work", cc.units(self.ctx))
        self.notes.save_findings([{"id": "x", "unit": "R/EDI/src/fast_work.cpp::work", "status": "proposed"}])
        self.assertNotIn("R/EDI/src/fast_work.cpp::work", cc.units(self.ctx))
        self.notes.save_findings([{"id": "x", "unit": "R/EDI/src/fast_work.cpp::work", "status": "rejected"}])
        self.assertIn("R/EDI/src/fast_work.cpp::work", cc.units(self.ctx))

    def test_applied_marker_is_new_text(self):
        self.assertEqual(cc.applied_marker("a;\nb;", "a;\nc_longer;", "a;\nb;"), "c_longer;")
        self.assertEqual(cc.applied_marker("b;", "a;", "a;\nb;"), "a;")

    def test_detector_findings_listed_once(self):
        parts = cc.apply(self.ctx, [], [])
        self.assertEqual(len(parts["human"]), 1)
        self.assertIn("Detector findings in `work`", parts["human"][0])
        self.assertEqual(cc.apply(self.ctx, [], [])["human"], [])  # unchanged: not listed again
        hot = json.loads(json.dumps(HOT))
        hot["hot"][0]["detectors"]["allocation_in_loop"] = {"_Znwm@plt": 1}
        (self.work / cc.WORK_SUB / "hot.json").write_text(json.dumps(hot))
        self.assertEqual(len(cc.apply(self.ctx, [], [])["human"]), 1)  # changed: listed again

    def test_proposal_that_does_not_apply(self):
        r = self.results()
        r[0]["findings"][0]["old_code"] = "not in the file"
        self.assertIn("occurs 0 times", cc.apply(self.ctx, r, [])["human"][0])
        r[0]["findings"][0]["file"] = "python/cpp/x.cpp"
        parts = cc.apply(self.ctx, r, [])
        self.assertIn("not under R/EDI/src", parts["human"][0])
        self.assertEqual(parts["proposed"], [])
        self.assertFalse((self.work / cc.FOLLOWUP_SUB / "proposals.json").exists())


if __name__ == "__main__":
    unittest.main(verbosity=1)
