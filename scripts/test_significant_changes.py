"""Checks for significant_changes.py: comment/whitespace-only edits are not code changes.

Run: python3 scripts/test_significant_changes.py
"""
import os
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import significant_changes as sc  # noqa: E402


class RTests(unittest.TestCase):
    def same(self, a, b):
        return sc.same_code("x.R", a, b)

    def test_comments_and_roxygen_ignored(self):
        self.assertTrue(self.same("f <- function(x) x + 1\n",
                                  "#' Adds one\n#' @export\nf <- function(x) x + 1  # trailing\n"))

    def test_reindent_and_blank_lines_ignored(self):
        self.assertTrue(self.same("f = function(x){\n  y = x+1\n  y\n}\n",
                                  "f = function(x) {\n\n        y = x + 1\n\n    y\n}\n"))

    def test_rewrapped_call_ignored(self):
        self.assertTrue(self.same("g(a, b, c = 2)\n", "g(\n  a,\n  b,\n  c = 2\n)\n"))
        self.assertTrue(self.same("z = a +\n  b\n", "z = a + b\n"))

    def test_hash_inside_string_is_code(self):
        self.assertFalse(self.same('x = "a # b"\n', 'x = "a # c"\n'))
        self.assertFalse(self.same('x = "a  b"\n', 'x = "a b"\n'))
        self.assertFalse(self.same('x = r"(a # b)"\n', 'x = r"(a # c)"\n'))

    def test_real_change_detected(self):
        self.assertFalse(self.same("x <- 1\n", "x <- 2\n"))
        self.assertFalse(self.same("x <- a\ny <- b\n", "x <- a y <- b\n"))
        self.assertFalse(self.same("x <- - 1\n", "x <-- 1\n"))
        self.assertFalse(self.same("return(x)\n", "returnx\n"))

    def test_statement_split_detected(self):
        # top-level newline ends a statement: `x <- 1\n-2` is two statements
        self.assertFalse(self.same("x <- 1 - 2\n", "x <- 1\n- 2\n"))


class CppTests(unittest.TestCase):
    def same(self, a, b):
        return sc.same_code("x.cpp", a, b)

    def test_comments_ignored(self):
        self.assertTrue(self.same("int f(int x) { return x + 1; }\n",
                                  "/* doc\n * block */\nint f(int x) {  // why\n    return x+1;\n}\n"))

    def test_comment_is_a_separator(self):
        self.assertTrue(self.same("int x;", "int/*c*/x;"))

    def test_rcpp_attribute_is_code(self):
        self.assertFalse(self.same("// [[Rcpp::export]]\nint f();\n", "int f();\n"))
        self.assertFalse(self.same("// [[Rcpp::export]]\nint f();\n", "// [[Rcpp::export(name = \"g\")]]\nint f();\n"))
        self.assertTrue(self.same("// [[Rcpp::export]]\nint f();\n", "//   [[Rcpp::export]]\n\nint  f();\n"))

    def test_strings_and_chars_verbatim(self):
        self.assertFalse(self.same('const char* s = "a // b";', 'const char* s = "a // c";'))
        self.assertFalse(self.same("char c = ' ';", "char c = '\t';"))
        self.assertFalse(self.same('auto s = R"x(a /* b */)x";', 'auto s = R"x(a /* c */)x";'))
        self.assertTrue(self.same("int n = 1'000;", "int n = 1'000; // thousand"))

    def test_preprocessor_line_end_kept(self):
        self.assertFalse(self.same("#define A 1\nint y;\n", "#define A 1 int y;\n"))
        self.assertTrue(self.same("#include <x>\n\n\nint y;\n", "#include <x>  // note\nint y;\n"))

    def test_real_change_detected(self):
        self.assertFalse(self.same("x = a - -b;", "x = a --b;"))
        self.assertFalse(self.same("*p = 3;", "p = 3;"))
        self.assertFalse(self.same("unsigned int x;", "unsignedint x;"))


class PythonTests(unittest.TestCase):
    def same(self, a, b):
        return sc.same_code("x.py", a, b)

    def test_comments_ignored(self):
        self.assertTrue(self.same("def f(x):\n    return x+1\n",
                                  "# header\ndef f(x):  # note\n\n        return x + 1\n"))

    def test_indentation_structure_counts(self):
        self.assertFalse(self.same("if a:\n    b()\nc()\n", "if a:\n    b()\n    c()\n"))


class OtherFilesTests(unittest.TestCase):
    def test_non_source_always_counts(self):
        self.assertFalse(sc.same_code("README.md", "a\n", "a \n"))
        self.assertFalse(sc.same_code("man/x.Rd", "% c\n", "% d\n"))

    def test_added_or_deleted_counts(self):
        self.assertFalse(sc.same_code("x.R", None, "# only a comment\n"))
        self.assertFalse(sc.same_code("x.R", "# only a comment\n", None))


class GitTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.repo = self.tmp.name
        self.git("init", "-q")
        self.git("config", "user.email", "t@example.com")
        self.git("config", "user.name", "t")

    def git(self, *args):
        return subprocess.run(["git", "-C", self.repo, *args], check=True, capture_output=True, text=True).stdout

    def write(self, path, text):
        full = os.path.join(self.repo, path)
        os.makedirs(os.path.dirname(full), exist_ok=True)
        with open(full, "w") as fh:
            fh.write(text)

    def commit(self):
        self.git("add", "-A")
        self.git("commit", "-q", "-m", "c")
        return self.git("rev-parse", "HEAD").strip()

    def test_end_to_end(self):
        self.write("R/a.R", "f <- function(x) x\n")
        self.write("src/b.cpp", "int g() { return 1; }\n")
        self.write("src/c.cpp", "int h() { return 1; }\n")
        self.write("README.md", "hi\n")
        base = self.commit()
        self.write("R/a.R", "# comment\nf <- function(x)   x\n")
        self.write("src/b.cpp", "int g() { return 2; }\n")
        self.write("src/c.cpp", "// note\nint h() {\n  return 1;\n}\n")
        self.write("README.md", "hi there\n")
        self.write("src/new.cpp", "// only a comment\n")
        # work tree vs base
        sig, ign = sc.significant_changes(self.repo, base, None, with_ignored=True)
        self.assertEqual(sorted(sig), ["README.md", "src/b.cpp"])  # untracked new.cpp not in git diff
        self.assertEqual(sorted(ign), ["R/a.R", "src/c.cpp"])
        head = self.commit()
        self.assertEqual(sorted(sc.significant_changes(self.repo, base, head)),
                         ["README.md", "src/b.cpp", "src/new.cpp"])
        self.assertEqual(sc.significant_changes(self.repo, base, head, ["R"]), [])
        self.assertEqual(sc.significant_changes(self.repo, f"{base}...{head}", None, ["src/c.cpp"]), [])
        self.assertFalse(sc.is_functional_change(base, head, "R/a.R", repo=self.repo))
        self.assertTrue(sc.is_functional_change(base, head, "src/b.cpp", repo=self.repo))

    def test_cli_exit_codes(self):
        self.write("a.R", "x <- 1\n")
        base = self.commit()
        script = os.path.join(os.path.dirname(os.path.abspath(__file__)), "significant_changes.py")
        r = subprocess.run([sys.executable, script, "-C", self.repo, base, "HEAD"], capture_output=True, text=True)
        self.assertEqual((r.returncode, r.stdout), (0, ""))
        r = subprocess.run([sys.executable, script, "-C", self.repo, "no-such-rev"], capture_output=True, text=True)
        self.assertEqual(r.returncode, 2)


if __name__ == "__main__":
    unittest.main()
