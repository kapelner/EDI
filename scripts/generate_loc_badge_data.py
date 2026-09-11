#!/usr/bin/env python3
"""Generates the lines-of-code badge JSON + full-table HTML page that
scripts/publish_loc_badge_gist.py pushes to a Gist on every push to main
(see .github/workflows/loc-badge.yml). Runs cloc itself and does the JSON
parsing + HTML rendering in one place, rather than splitting cloc-invocation
(bash) from parsing (something else).

This replaced README.md's own inline cloc table (and the pre-push
auto-commit that used to keep it fresh) -- see git history for
scripts/update_readme_cloc.sh, which this supersedes. README.md now carries
a static badge that fetches this data live; it is never edited by CI.

Safe to run manually from anywhere in the repo:
    python3 scripts/generate_loc_badge_data.py <badge-json-out> <html-out>
"""
import json
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

CLOC_CMD = (
    "cloc --vcs=git --include-lang=\"R,Python,C,C++,C/C++ Header\" "
    "--exclude-ext=\"Rd,rd\" ."
)
CLOC_ARGS = [
    "cloc", "--json", "--quiet", "--vcs=git",
    "--include-lang=R,Python,C,C++,C/C++ Header",
    "--exclude-ext=Rd,rd",
    ".",
]


def repo_root() -> Path:
    out = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        check=True, capture_output=True, text=True,
    )
    return Path(out.stdout.strip())


def format_count(n: int) -> str:
    # "45.2k" rather than exact digits: fits shields.io's compact pill next
    # to this repo's other short badges (build/coverage/license).
    if n < 1000:
        return str(n)
    return f"{n / 1000:.1f}k"


def render_html(languages, sums, generated_at: str) -> str:
    rows = "\n".join(
        f"    <tr><td>{lang}</td><td>{s['nFiles']}</td><td>{s['blank']}</td>"
        f"<td>{s['comment']}</td><td>{s['code']}</td></tr>"
        for lang, s in languages
    )
    sum_row = (
        f"    <tr><th>SUM</th><th>{sums['nFiles']}</th><th>{sums['blank']}</th>"
        f"<th>{sums['comment']}</th><th>{sums['code']}</th></tr>"
    )
    return f"""<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>EDI lines of code</title>
<style>
  body {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; margin: 2rem; color: #1a1a1a; }}
  table {{ border-collapse: collapse; }}
  td, th {{ padding: 0.3rem 0.9rem; text-align: right; border-bottom: 1px solid #ddd; }}
  td:first-child, th:first-child {{ text-align: left; }}
  tbody tr:last-child th {{ border-top: 2px solid #333; border-bottom: none; }}
  code {{ background: #f2f2f2; padding: 0.1rem 0.3rem; border-radius: 3px; }}
</style>
</head>
<body>
  <h1>EDI &mdash; Lines of Code</h1>
  <table>
    <thead><tr><th>Language</th><th>files</th><th>blank</th><th>comment</th><th>code</th></tr></thead>
    <tbody>
{rows}
{sum_row}
    </tbody>
  </table>
  <p>Generated {generated_at} by <code>{CLOC_CMD}</code> on every push to
  <a href="https://github.com/kapelner/EDI">kapelner/EDI</a>'s main branch
  (<code>--vcs=git</code> counts only git-tracked files, so local artifacts
  such as <code>python/.venv</code> don't skew the numbers).</p>
</body>
</html>
"""


def main() -> int:
    if len(sys.argv) != 3:
        print(f"usage: {sys.argv[0]} <badge-json-out> <html-out>", file=sys.stderr)
        return 1
    badge_out, html_out = Path(sys.argv[1]), Path(sys.argv[2])

    if shutil.which("cloc") is None:
        print("generate_loc_badge_data.py: cloc is not installed.", file=sys.stderr)
        return 1

    result = subprocess.run(CLOC_ARGS, cwd=repo_root(), check=True, capture_output=True, text=True)
    data = json.loads(result.stdout)

    languages = [(lang, stats) for lang, stats in data.items() if lang not in ("header", "SUM")]
    sums = data["SUM"]

    badge = {
        "schemaVersion": 1,
        "label": "lines of code",
        "message": format_count(sums["code"]),
        "color": "blue",
    }
    badge_out.write_text(json.dumps(badge) + "\n")

    generated_at = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    html_out.write_text(render_html(languages, sums, generated_at))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
