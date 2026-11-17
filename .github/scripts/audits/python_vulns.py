"""Python dependency vulnerabilities (weekly, issue, no Claude).

Plan: R/package_metadata/new_feature_plans/v1_0_6/audit_jobs_framework.md (Part 4, "Python
dependency vulnerabilities"; audit_jobs_framework.md TODO-12).

Collects the Python package's declared dependencies (python/pyproject.toml: [project]
dependencies, every [project.optional-dependencies] group and [build-system] requires, plus
any tracked requirements*.txt under python/), writes them to one requirements file in the
work dir, and runs `pip-audit -r <file> --format json`. pip-audit resolves the versions pip
would install today, so a finding means "a fresh install gets a vulnerable version" or "a
lower bound admits one". One finding per vulnerable package with its advisory ids and fixed
versions. pip-audit failing to run is a finding, never clean. The caller installs pip-audit
with `python_packages`. Report: ONE issue (label `python-vulnerabilities`), closed when clean.
"""
import json
import re
import subprocess

import audit_common as ac

PYPROJECT = "python/pyproject.toml"

SPEC = {
    "name": "python-vulns",
    "title": "Python dependency vulnerabilities",
    "report": "issue",
    "label": "python-vulnerabilities",       # the plan's label (Part 4)
    "claude": False,
}


# ---------------------------------------------------------------- dependencies

def _toml_load(text):
    try:
        import tomllib  # Python 3.11+
        return tomllib.loads(text)
    except ImportError:
        return None


def _string_array(text, key):
    """Fallback for Python < 3.11: the strings of `key = [ ... ]` (first occurrence)."""
    m = re.search(rf"(?ms)^\s*{re.escape(key)}\s*=\s*\[(.*?)\]", text)
    return re.findall(r'"([^"]+)"', m.group(1)) if m else []


def pyproject_requirements(text):
    """Requirement strings from a pyproject.toml, in a stable order, without duplicates."""
    reqs = []
    data = _toml_load(text)
    if data is not None:
        reqs += data.get("build-system", {}).get("requires", [])
        proj = data.get("project", {})
        reqs += proj.get("dependencies", [])
        for group in sorted(proj.get("optional-dependencies", {})):
            reqs += proj["optional-dependencies"][group]
    else:
        reqs += _string_array(text, "requires") + _string_array(text, "dependencies")
        m = re.search(r"(?ms)^\[project\.optional-dependencies\](.*?)(^\[|\Z)", text)
        if m:
            for line in m.group(1).splitlines():
                if "=" in line and "[" in line:
                    reqs += re.findall(r'"([^"]+)"', line)
    seen, out = set(), []
    for r in reqs:
        r = r.strip()
        if r and r not in seen:
            seen.add(r)
            out.append(r)
    return out


def requirements_files(ctx):
    return [f for f in ac.tracked_files("python", cwd=ctx.repo)
            if re.search(r"(^|/)requirements[^/]*\.(txt|in)$", f) and "/.venv/" not in f]


def collect(ctx):
    """(requirement lines, [source files])."""
    lines, sources = [], []
    text = ctx.read(PYPROJECT)
    if text is not None:
        lines += pyproject_requirements(text)
        sources.append(PYPROJECT)
    for f in requirements_files(ctx):
        for l in (ctx.read(f) or "").splitlines():
            l = l.split("#", 1)[0].strip()
            if l and not l.startswith(("-e", "-r", "-c", "--", ".")):
                lines.append(l)
        sources.append(f)
    seen, out = set(), []
    for l in lines:
        if l not in seen:
            seen.add(l)
            out.append(l)
    return out, sources


# ---------------------------------------------------------------- pip-audit

def run_pip_audit(req_file):
    """(returncode, stdout, stderr). Exit 1 means vulnerabilities were found."""
    try:
        r = subprocess.run(["pip-audit", "-r", str(req_file), "--format", "json", "--progress-spinner", "off"],
                           capture_output=True, text=True, timeout=1200)
    except FileNotFoundError:
        try:
            r = subprocess.run(["python3", "-m", "pip_audit", "-r", str(req_file), "--format", "json",
                                "--progress-spinner", "off"], capture_output=True, text=True, timeout=1200)
        except (OSError, subprocess.TimeoutExpired) as e:
            return 127, "", str(e)
    except subprocess.TimeoutExpired as e:
        return 124, "", f"timed out: {e}"
    return r.returncode, r.stdout, r.stderr


def parse_pip_audit(text):
    """pip-audit JSON -> [{"name", "version", "vulns": [{"id", "aliases", "fix_versions"}]}].
    Accepts the current {"dependencies": [...]} layout and the older bare list."""
    data = json.loads(text)
    deps = data.get("dependencies", []) if isinstance(data, dict) else data
    out = []
    for d in deps:
        vulns = [v for v in d.get("vulns", []) or []]
        if vulns:
            out.append({"name": d.get("name", "?"), "version": d.get("version", "?"),
                        "vulns": [{"id": v.get("id", "?"), "aliases": sorted(v.get("aliases") or []),
                                   "fix_versions": list(v.get("fix_versions") or [])} for v in vulns]})
    return sorted(out, key=lambda d: d["name"].lower())


def findings_from_audit(vulnerable):
    out = []
    for d in vulnerable:
        ids = []
        fixes = set()
        for v in d["vulns"]:
            alias = f" ({', '.join(v['aliases'])})" if v["aliases"] else ""
            ids.append(f"{v['id']}{alias}")
            fixes.update(v["fix_versions"])
        fix = ", ".join(sorted(fixes)) if fixes else "none published"
        out.append({"unit": d["name"], "kind": "vulnerable",
                    "text": f"`{d['name']}` {d['version']}: {'; '.join(ids)}. Fixed in: {fix}."})
    return out


def mechanical(ctx):
    reqs, sources = collect(ctx)
    if not reqs:
        return [{"unit": PYPROJECT, "kind": "no-dependencies",
                 "text": f"No Python dependencies found ({PYPROJECT} missing or empty); nothing was audited."}]
    ctx.workdir.mkdir(parents=True, exist_ok=True)
    req = ctx.workdir / "python_requirements.txt"
    req.write_text("\n".join(reqs) + "\n")
    code, stdout, stderr = run_pip_audit(req)
    if code not in (0, 1) or not stdout.strip():
        tail = " ".join((stderr or "").strip().splitlines()[-3:])[:600]
        return [{"unit": "pip-audit", "kind": "not-run",
                 "text": f"pip-audit did not run (exit {code}): {tail or 'no output'}"}]
    try:
        vulnerable = parse_pip_audit(stdout)
    except ValueError as e:
        return [{"unit": "pip-audit", "kind": "not-run", "text": f"pip-audit output was not JSON: {e}"}]
    return findings_from_audit(vulnerable)


def apply(ctx, results, mech):
    vul = [f for f in mech if f["kind"] == "vulnerable"]
    summary = (f"{len(vul)} vulnerable Python package(s) in the dependencies of `{PYPROJECT}`."
               if vul else ("" if not mech else "The vulnerability check did not complete."))
    return {"summary": summary, "mechanical": [f["text"] for f in mech]}
