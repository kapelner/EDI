"""CRAN check-results watcher (daily, issue, no Claude).

Plan: R/package_metadata/new_feature_plans/v1_0_6/audit_jobs_framework.md (Part 4, "CRAN
check-results watcher"; audit_jobs_framework.md TODO-9).

Reads CRAN's check page for EDI and reports one finding per flavor whose status is not OK
(NOTE, WARN/WARNING, ERROR, FAIL), with the first lines of the check details CRAN lists for
that flavor, plus one finding per "Additional issues" entry and one for a CRAN deadline
note. The framework's issue mode opens or updates ONE issue (label `cran-check`)
and closes it when the page is clean. A page that cannot be read is a finding, never clean.
Stdlib only.
"""
import html
import re
import time
import urllib.request

PACKAGE = "EDI"
CHECK_URL = f"https://cran.r-project.org/web/checks/check_results_{PACKAGE}.html"
PACKAGE_URL = f"https://cran.r-project.org/web/packages/{PACKAGE}/index.html"
USER_AGENT = "Mozilla/5.0 (compatible; scheduled-audit; python-urllib)"
DETAIL_LINES = 6

SPEC = {
    "name": "cran-watcher",
    "title": "CRAN check results",
    "report": "issue",
    "label": "cran-check",       # the plan's label (Part 4)
    "claude": False,
}


def fetch(url, tries=3, timeout=60):
    last = None
    for i in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return r.read().decode("utf-8", "replace")
        except Exception as e:  # noqa: BLE001 - any failure is reported, never treated as clean
            last = e
            if i + 1 < tries:
                time.sleep(5 * (i + 1))
    raise RuntimeError(f"{url}: {last}")


def _text(fragment):
    """HTML fragment -> plain text, keeping line breaks."""
    s = re.sub(r"(?i)<br\s*/?>", "\n", fragment)
    s = re.sub(r"<[^>]+>", "", s)
    return html.unescape(s)


def parse_flavors(page):
    """[(flavor, status)] from the results table."""
    rows = []
    for tr in re.findall(r"(?is)<tr>(.*?)</tr>", page):
        cells = re.findall(r"(?is)<td[^>]*>(.*?)</td>", tr)
        if len(cells) < 6:
            continue
        flavor = _text(cells[0]).strip()
        status = _text(cells[5]).strip().upper()
        if flavor and status:
            rows.append((flavor, status))
    return rows


def parse_details(page):
    """Check Details blocks: [{"check", "result", "detail": [lines], "flavors": [names]}]."""
    m = re.search(r"(?is)<h3>\s*Check Details\s*</h3>(.*)", page)
    if not m:
        return []
    out = []
    for block in re.findall(r"(?is)<p>(.*?)</p>", m.group(1)):
        if "Result:" not in block:
            continue
        flavors = [_text(x).strip() for x in re.findall(r"(?is)<span[^>]*>(.*?)</span>",
                                                        block.split("Flavors:", 1)[-1])] \
            if "Flavors:" in block else []
        pre = re.search(r"(?is)<span[^>]*white-space:\s*pre[^>]*>(.*?)</span>", block)
        detail = [l.rstrip() for l in _text(pre.group(1)).splitlines() if l.strip()] if pre else []
        head = _text(block.split("Flavors:", 1)[0] if not pre else block[:pre.start()])
        check = re.search(r"Check:\s*(.+)", head)
        result = re.search(r"Result:\s*(\S+)", head)
        out.append({"check": check.group(1).strip() if check else "",
                    "result": result.group(1).strip() if result else "",
                    "detail": detail, "flavors": flavors})
    return out


def parse_additional(page):
    """Names listed under "Additional issues" (e.g. clang-UBSAN, valgrind, rchk)."""
    m = re.search(r"(?is)Additional issues:?(.*?)(</p>|<h3|$)", page)
    if not m:
        return []
    names = [_text(x).strip() for x in re.findall(r"(?is)<a[^>]*>(.*?)</a>", m.group(1))]
    return [n for n in names if n]


def parse_deadline(page):
    """The sentence of a CRAN deadline note, or None."""
    text = re.sub(r"\s+", " ", _text(page))
    m = re.search(r"[^.]*(Please correct before|Deadline)[^.]*(\.\d[^.]*)*\.?", text)
    return m.group(0).strip() if m else None


def findings_from_page(page, url=CHECK_URL):
    out = []
    flavors = parse_flavors(page)
    if not flavors:
        return [{"unit": "check page", "kind": "unreadable",
                 "text": f"No results table found on {url}; the page layout may have changed."}]
    details = parse_details(page)
    for flavor, status in flavors:
        if status == "OK":
            continue
        lines = []
        for d in details:
            if flavor in d["flavors"]:
                lines.append(f"{d['result']}: {d['check']}")
                lines += ["    " + l.strip() for l in d["detail"][:DETAIL_LINES]]
        detail = ("\n  " + "\n  ".join(lines)) if lines else " (no check details listed for this flavor)"
        out.append({"unit": flavor, "kind": status.lower(),
                    "text": f"`{flavor}`: {status}.{detail}"})
    for name in parse_additional(page):
        out.append({"unit": f"additional:{name}", "kind": "additional-issue",
                    "text": f"Additional issue `{name}` is listed on {url}."})
    return out


def mechanical(ctx):
    try:
        page = fetch(CHECK_URL)
    except RuntimeError as e:
        return [{"unit": "check page", "kind": "unreadable", "text": f"Could not read the CRAN check page: {e}"}]
    out = findings_from_page(page)
    note = parse_deadline(page)
    if not note:
        try:
            note = parse_deadline(fetch(PACKAGE_URL))
        except RuntimeError:
            note = None
    if note:
        out.insert(0, {"unit": "deadline", "kind": "deadline", "text": f"CRAN deadline: {note}"})
    return out


def apply(ctx, results, mech):
    flavors = [f for f in mech if f["kind"] not in ("deadline", "unreadable", "additional-issue")]
    summary = (f"{len(flavors)} CRAN flavor(s) not OK for {PACKAGE}. Page: {CHECK_URL}"
               if mech else f"All CRAN flavors OK for {PACKAGE}.")
    return {"summary": summary, "mechanical": [f["text"] for f in mech]}
