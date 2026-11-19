#!/usr/bin/env python3
"""Why a Claude agent step produced no output, read from its transcript.

claude-code-action (and `claude -p --output-format stream-json`) end with a `result` message. When
the API refuses the request, e.g. 429 `usage_limit_reached` once the token's weekly quota is spent,
that message has `is_error: true`, `api_error`, and the CLI's text in `result` ("You've hit your
weekly limit · resets ..."), while the step outcome only says "failure". Found 2026-11-19: 54 of
90 research agents and 8 audit batches of the 2026-11-18 campaign were refused this way and the
runs still showed green. Stdlib only.

    python3 agent_failure.py <transcript> [--outcome <step outcome>]

prints one line for a `.notrun` file. Exit 0 always.
"""
import json
import sys
from pathlib import Path

# Prefix of every reason for an API refusal (quota, rate limit, billing, overload). A run with any
# such batch fails at its end (audit_run.py check-notrun), after its partial results are saved.
QUOTA_MARK = "API refused the request"


def messages(path):
    """The transcript's messages: a JSON array (claude-code-action) or JSON lines (stream-json)."""
    try:
        text = Path(path).read_text(errors="replace")
    except OSError:
        return []
    try:
        data = json.loads(text)
        return data if isinstance(data, list) else [data]
    except ValueError:
        out = []
        for line in text.splitlines():
            try:
                m = json.loads(line)
            except ValueError:
                continue
            if isinstance(m, dict):
                out.append(m)
        return out


def api_error(msgs):
    """(status, error, text) of the last API error in the transcript, or None."""
    found = None
    for m in msgs:
        if not isinstance(m, dict):
            continue
        err = m.get("api_error") or m.get("api_error_type") or (m.get("error") if m.get("is_api_error_message") else None)
        if err or (m.get("type") == "result" and m.get("is_error") and m.get("terminal_reason") == "api_error"):
            text = m.get("result")
            if not text:
                content = (m.get("message") or {}).get("content") or []
                text = " ".join(c.get("text", "") for c in content if isinstance(c, dict))
            found = (m.get("api_error_status"), err or "api_error", (text or "").strip())
    return found


def reason(path, outcome=""):
    """One line saying why the agent produced no structured output."""
    msgs = messages(path) if path else []
    err = api_error(msgs)
    if err:
        status, code, text = err
        head = f"{QUOTA_MARK} ({status} {code})" if status else f"{QUOTA_MARK} ({code})"
        return f"{head}: {text}" if text else head
    for m in reversed(msgs):
        if isinstance(m, dict) and m.get("type") == "result" and m.get("is_error"):
            text = str(m.get("result") or m.get("subtype") or "").strip()
            return f"agent ended with an error: {text}"[:500]
    return f"agent produced no structured output (step outcome: {outcome or 'unknown'})"


def refused_by_quota(reasons):
    """The reasons among `reasons` that are API refusals (quota, rate limit, billing)."""
    return [r for r in reasons if r.startswith(QUOTA_MARK)]


def main(argv=None):
    argv = list(sys.argv[1:] if argv is None else argv)
    outcome = ""
    if "--outcome" in argv:
        i = argv.index("--outcome")
        outcome = argv[i + 1] if i + 1 < len(argv) else ""
        del argv[i:i + 2]
    print(reason(argv[0] if argv else "", outcome))
    return 0


if __name__ == "__main__":
    sys.exit(main())
