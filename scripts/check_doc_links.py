#!/usr/bin/env python3
"""Pre-push doc-link checker.

Scans the USER-FACING docs only -- the ones that ship somewhere a reader
outside this repo sees them: the READMEs (repo root, R/, python/, PyPI),
python/CHANGELOG.md, R/EDI/REFERENCES.md, and the roxygen comments in
R/EDI/R/*.R (which become the package's rendered help pages). Internal
plan/working documents (R/package_metadata/**, R/package_tests/**, graft/,
CLAUDE.md, ...) are deliberately NOT checked: a stale link in a planning
note costs nothing, and their sheer volume made every push noisy.

For each link found it verifies the target is alive:
  - internal (relative/absolute repo paths, markdown files only): the file
    exists on disk.
  - external (http(s)://): a HEAD/GET request returns a non-error status.
    Roxygen comments contribute external links only ([text](url), \\url{},
    \\href{}); Rd cross-references like \\link[pkg]{fn} are not checked.

Runs over the whole corpus above (not just the diff) because a link can be
broken by a change on the OTHER end -- e.g. renaming/moving the file a doc
links to breaks every link pointing at the old path, none of which show up
in a diff of the doc file itself. .githooks/pre-push gates whether to run
this at all on "did any checked file change", not on narrowing which links
get checked once it does run.

Known limitations (acceptable for a fast pre-push gate, not a general link
linter): only markdown inline-link syntax [text](target) is parsed (no
reference-style [text][ref] links); a leading "#fragment" target is treated
as a same-page anchor and skipped rather than verified against headings;
GitHub-style "#L123"/"#L123-L456" and repo-convention ":123"/":123-456"
line-reference suffixes are stripped before checking a source-file target
exists, but the line number itself is not verified to be in range.
"""
import concurrent.futures
import re
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path

REPO_ROOT = Path(
    subprocess.run(
        ["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True, check=True
    ).stdout.strip()
)

LINK_RE = re.compile(r"!?\[[^\]]*\]\(([^)]+)\)")
LINE_SUFFIX_RE = re.compile(r"(#L\d+(?:-L?\d+)?|:\d+(?:-\d+)?)$")
FENCED_CODE_RE = re.compile(r"```.*?```", re.DOTALL)
INLINE_CODE_RE = re.compile(r"`[^`\n]*`")
EXTERNAL_TIMEOUT_SECS = 10
EXTERNAL_MAX_WORKERS = 16


def strip_code(text: str) -> str:
    # A C++ lambda capture like "[auto&& v](...)" inside a fenced code block
    # parses as valid markdown link syntax otherwise -- strip code first so
    # only prose links are scanned.
    text = FENCED_CODE_RE.sub("", text)
    return INLINE_CODE_RE.sub("", text)


def is_user_facing_md(rel_path: str) -> bool:
    # See module docstring: only docs a reader outside this repo sees.
    return (
        rel_path == "R/EDI/REFERENCES.md"
        or rel_path == "python/CHANGELOG.md"
        or Path(rel_path).name in ("README.md", "README_PYPI.md")
    )


def md_files():
    out = subprocess.run(
        ["git", "ls-files", "*.md"], capture_output=True, text=True, check=True, cwd=REPO_ROOT
    )
    return [REPO_ROOT / p for p in out.stdout.splitlines() if p and is_user_facing_md(p)]


ROXY_LINE_RE = re.compile(r"^\s*#'(.*)$")
ROXY_TEX_URL_RE = re.compile(r"\\(?:url|href)\{(https?://[^}]+)\}")


def roxygen_files():
    out = subprocess.run(
        ["git", "ls-files", "R/EDI/R/*.R"],
        capture_output=True,
        text=True,
        check=True,
        cwd=REPO_ROOT,
    )
    return [REPO_ROOT / p for p in out.stdout.splitlines() if p]


def roxygen_external_urls(r_file: Path) -> list[str]:
    """External http(s) links in a file's roxygen (#') comment lines."""
    try:
        text = r_file.read_text(encoding="utf-8")
    except (UnicodeDecodeError, OSError):
        return []
    roxy_text = "\n".join(m.group(1) for m in map(ROXY_LINE_RE.match, text.splitlines()) if m)
    urls = [u for u in ROXY_TEX_URL_RE.findall(roxy_text)]
    urls += [
        t.strip()
        for t in LINK_RE.findall(roxy_text)
        if t.strip().startswith(("http://", "https://"))
    ]
    return urls


def strip_line_suffix(target: str) -> str:
    return LINE_SUFFIX_RE.sub("", target)


def check_internal(md_file: Path, target: str) -> str | None:
    """Return an error string if broken, else None."""
    path_part = target.split("#", 1)[0] if not target.startswith("#") else None
    if path_part is None:
        return None  # same-page anchor, not verified (see module docstring)
    if not path_part:
        return None  # e.g. "#foo" already excluded above; empty path is a bare fragment too
    path_part = strip_line_suffix(path_part)
    if path_part.startswith("/"):
        candidate = Path(path_part)
        if not candidate.exists():
            # Also try repo-root-relative, in case the "/" was meant as
            # repo-root rather than filesystem-root (seen in this repo).
            candidate = REPO_ROOT / path_part.lstrip("/")
    else:
        candidate = (md_file.parent / path_part).resolve()
    if not candidate.exists():
        return f"missing target: {target}"
    return None


# A plain-python User-Agent gets a blanket 403 from academic publishers
# (ScienceDirect, ACS, ResearchGate, ...) regardless of whether the page
# exists -- impersonate a browser so a 403 carries more signal.
EXTERNAL_UA = (
    "Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0"
)


def check_external(url: str) -> str | None:
    req = urllib.request.Request(url, method="HEAD", headers={"User-Agent": EXTERNAL_UA})
    try:
        with urllib.request.urlopen(req, timeout=EXTERNAL_TIMEOUT_SECS) as resp:
            if resp.status >= 400:
                return f"HTTP {resp.status}"
        return None
    except urllib.error.HTTPError as e:
        if e.code in (403, 405):
            # Some sites reject HEAD; retry with GET before giving up.
            try:
                req2 = urllib.request.Request(
                    url, method="GET", headers={"User-Agent": EXTERNAL_UA}
                )
                with urllib.request.urlopen(req2, timeout=EXTERNAL_TIMEOUT_SECS) as resp:
                    if resp.status >= 400:
                        return f"HTTP {resp.status}"
                return None
            except urllib.error.HTTPError as e2:
                if e2.code == 403:
                    # Still 403 on a browser-UA GET: the site is up but
                    # refuses automated clients (TLS/bot fingerprinting).
                    # That says nothing about whether the page exists -- a
                    # genuinely dead page returns 404/410 -- so don't
                    # report it as broken.
                    return None
                return f"HTTP {e2.code}"
            except Exception as e2:
                return f"{e2}"
        return f"HTTP {e.code}"
    except Exception as e:
        return f"{e}"


BASELINE_PATH = REPO_ROOT / "scripts" / "check_doc_links_baseline.csv"


def load_baseline() -> set[tuple[str, str]]:
    if not BASELINE_PATH.exists():
        return set()
    out = set()
    for line in BASELINE_PATH.read_text(encoding="utf-8").splitlines()[1:]:  # skip header
        if not line.strip():
            continue
        file_rel, target = line.split("\t", 1)
        out.add((file_rel, target))
    return out


def write_baseline(internal_broken: list[tuple[Path, str, str]]) -> None:
    lines = ["file\ttarget"]
    for md_file, target, _err in sorted(internal_broken, key=lambda t: (str(t[0]), t[1])):
        lines.append(f"{md_file.relative_to(REPO_ROOT)}\t{target}")
    BASELINE_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"check_doc_links: wrote {len(internal_broken)} baseline entries to {BASELINE_PATH}.")


def main() -> int:
    if "--write-baseline" in sys.argv:
        internal_broken, _ = collect(report_external=False)
        write_baseline(internal_broken)
        return 0

    internal_broken, external_broken = collect(report_external=True)

    baseline = load_baseline()
    new_internal = [
        (f, t, e)
        for f, t, e in internal_broken
        if (str(f.relative_to(REPO_ROOT)), t) not in baseline
    ]
    already_known = len(internal_broken) - len(new_internal)

    if not new_internal and not external_broken:
        msg = (
            f"check_doc_links: no new broken links ({len(md_files())} doc files + "
            f"{len(roxygen_files())} roxygen sources checked)"
        )
        if already_known:
            msg += f"; {already_known} pre-existing broken internal link(s) still tracked in the baseline (not blocking)"
        print(msg + ".")
        return 0

    # External link failures block the push too. check_external() already
    # tolerates the one systematic false positive (publishers that 403 every
    # automated client regardless of whether the page exists), so anything
    # reported here is a real 4xx/5xx or an unreachable host -- worth
    # stopping on rather than scrolling past.
    if external_broken:
        print(f"check_doc_links: {len(external_broken)} external link(s) did not respond (blocking):")
        for md_file, target, err in sorted(external_broken, key=lambda t: str(t[0])):
            print(f"  {md_file.relative_to(REPO_ROOT)}: {target} -- {err}")

    if new_internal:
        print(f"check_doc_links: {len(new_internal)} NEW broken internal link(s) (blocking):")
        for md_file, target, err in sorted(new_internal, key=lambda t: str(t[0])):
            print(f"  {md_file.relative_to(REPO_ROOT)}: {target} -- {err}")
        print(
            f"check_doc_links: fix the link(s) above, or if this is pre-existing debt being "
            f"newly discovered rather than something you just broke, add it to {BASELINE_PATH} "
            f"(re-run with --write-baseline to regenerate)."
        )

    return 1


def collect(report_external: bool):
    internal_broken: list[tuple[Path, str, str]] = []
    external_targets: dict[str, list[tuple[Path, str]]] = {}

    for md_file in md_files():
        try:
            text = strip_code(md_file.read_text(encoding="utf-8"))
        except (UnicodeDecodeError, OSError):
            continue
        for m in LINK_RE.finditer(text):
            target = m.group(1).strip()
            if not target or target.startswith("mailto:"):
                continue
            if target.startswith("http://") or target.startswith("https://"):
                external_targets.setdefault(target, []).append((md_file, target))
                continue
            err = check_internal(md_file, target)
            if err:
                internal_broken.append((md_file, target, err))

    for r_file in roxygen_files():
        for url in roxygen_external_urls(r_file):
            external_targets.setdefault(url, []).append((r_file, url))

    external_broken: list[tuple[Path, str, str]] = []
    if report_external and external_targets:
        with concurrent.futures.ThreadPoolExecutor(max_workers=EXTERNAL_MAX_WORKERS) as pool:
            future_to_url = {pool.submit(check_external, url): url for url in external_targets}
            for future in concurrent.futures.as_completed(future_to_url):
                url = future_to_url[future]
                err = future.result()
                if err:
                    for md_file, target in external_targets[url]:
                        external_broken.append((md_file, target, err))

    return internal_broken, external_broken


if __name__ == "__main__":
    sys.exit(main())
