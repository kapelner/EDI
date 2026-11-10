"""Offline regression checks for the pre-push external-link gate."""
import contextlib
import io
import unittest
import urllib.error
from unittest.mock import patch

import check_doc_links as checker


class ExternalLinkTests(unittest.TestCase):
    url = "https://example.com/document"

    def http_error(self, code):
        error = urllib.error.HTTPError(self.url, code, "fixture", {}, None)
        self.addCleanup(error.close)
        return error

    def check(self, responses):
        output = io.StringIO()
        with patch.object(checker.urllib.request, "urlopen", side_effect=responses) as request, \
                patch.object(checker.time, "sleep"), contextlib.redirect_stderr(output):
            result = checker.check_external(self.url)
        return result, output.getvalue(), request.call_count

    def test_repeated_timeout_warns_after_retry(self):
        result, warning, calls = self.check([TimeoutError("read timed out")] * 2)
        self.assertIsNone(result)
        self.assertIn("non-blocking", warning)
        self.assertIn(self.url, warning)
        self.assertEqual(calls, 2)

    def test_dns_failure_warns_after_retry(self):
        result, warning, calls = self.check([urllib.error.URLError("DNS failure")] * 2)
        self.assertIsNone(result)
        self.assertIn("DNS failure", warning)
        self.assertEqual(calls, 2)

    def test_missing_pages_block_without_retry(self):
        for code in (404, 410):
            with self.subTest(code=code):
                result, warning, calls = self.check([self.http_error(code)])
                self.assertEqual(result, f"HTTP {code}")
                self.assertEqual(warning, "")
                self.assertEqual(calls, 1)

    def test_persistent_server_error_still_blocks(self):
        error = self.http_error(503)
        result, warning, calls = self.check([error, error])
        self.assertEqual(result, "HTTP 503")
        self.assertEqual(warning, "")
        self.assertEqual(calls, 2)

    def test_get_fallback_timeout_warns(self):
        refused = self.http_error(405)
        result, warning, calls = self.check([refused, TimeoutError(), refused, TimeoutError()])
        self.assertIsNone(result)
        self.assertIn("non-blocking", warning)
        self.assertEqual(calls, 4)

    def test_invalid_url_errors_still_block(self):
        result, warning, _ = self.check([ValueError("invalid URL")] * 2)
        self.assertEqual(result, "invalid URL")
        self.assertEqual(warning, "")



class SelfRepoMainLinkTests(unittest.TestCase):
    """Links into this repo's main are checked against HEAD, not GitHub,
    so a file added or moved by the push being verified does not 404."""

    base = "https://github.com/kapelner/EDI"

    def setUp(self):
        patcher = patch.object(checker, "_HEAD_PATHS", {"python", "python/README.md", "R", "R/EDI"})
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_matches_only_this_repos_main(self):
        self.assertTrue(checker.SELF_REPO_MAIN_RE.match(self.base + "/blob/main/python/README.md"))
        self.assertTrue(checker.SELF_REPO_MAIN_RE.match(self.base + "/tree/main/python"))
        self.assertIsNone(checker.SELF_REPO_MAIN_RE.match(self.base + "/blob/v1.0.0/python/README.md"))
        self.assertIsNone(checker.SELF_REPO_MAIN_RE.match(self.base + "/issues/3"))
        self.assertIsNone(checker.SELF_REPO_MAIN_RE.match("https://github.com/other/EDI/blob/main/x"))

    def test_existing_file_and_directory_pass(self):
        self.assertIsNone(checker.check_self_repo_main(self.base + "/blob/main/python/README.md#install"))
        self.assertIsNone(checker.check_self_repo_main(self.base + "/blob/main/python/README.md#L10-L20"))
        self.assertIsNone(checker.check_self_repo_main(self.base + "/tree/main/R/EDI/"))
        self.assertIsNone(checker.check_self_repo_main(self.base + "/tree/main"))

    def test_missing_path_is_reported(self):
        err = checker.check_self_repo_main(self.base + "/blob/main/python/MISSING.md")
        self.assertIn("python/MISSING.md", err)


if __name__ == "__main__":
    unittest.main()
