#!/usr/bin/env python3
"""StopFailure hook: when Netskope's 403 ends a turn, prepare a recovered copy of the session and tell the user.

Claude Code ignores this hook's output, so it reports through a macOS notification, the clipboard
(the resume command) and ~/.claude/netskope-recover/latest.txt (the full instructions).
Set NETSKOPE_RECOVER_DRY_RUN=1 to test without writing a copy, notifying or touching the clipboard.
"""
import json
import os
import subprocess
import sys
import time
from pathlib import Path

MARKER = "IT Admin has blocked"
HOME = Path.home() / ".claude" / "netskope-recover"
RECOVER = Path.home() / ".claude" / "skills" / "netskope-recover" / "recover.py"
DRY = os.environ.get("NETSKOPE_RECOVER_DRY_RUN") == "1"


def notify(title: str, message: str) -> None:
    if DRY:
        print(f"[notify] {title}: {message}")
        return
    script = f"display notification {json.dumps(message)} with title {json.dumps(title)}"
    subprocess.run(["osascript", "-e", script], capture_output=True, timeout=10)


def main() -> None:
    event = json.load(sys.stdin)
    HOME.mkdir(parents=True, exist_ok=True)
    with open(HOME / "stop-failures.jsonl", "a") as log:
        log.write(json.dumps({"time": time.strftime("%Y-%m-%dT%H:%M:%S"), "session": event.get("session_id"),
                              "error": event.get("error"),
                              "message": str(event.get("last_assistant_message", ""))[:160]}) + "\n")
    if MARKER not in json.dumps(event):
        return

    cmd = [sys.executable, "-I", str(RECOVER), "--transcript", event["transcript_path"], "--json"]
    if DRY:
        cmd.append("--dry-run")
    for attempt in range(5):
        run = subprocess.run(cmd, capture_output=True, text=True, timeout=90)
        if run.returncode != 0:
            notify("Claude session blocked by Netskope", "Automatic recovery failed; run /netskope-recover from another session.")
            (HOME / "latest.txt").write_text(f"recover.py failed:\n{run.stderr[-2000:]}\n")
            return
        result = json.loads(run.stdout)
        if result["mode"] != "no-block":
            break
        time.sleep(2)
    else:
        notify("Claude session blocked by Netskope", "The 403 isn't in the transcript yet; run /netskope-recover from another session.")
        (HOME / "latest.txt").write_text(f"Netskope 403 reported for {result['session']}, but recover.py found no block in the transcript.\n")
        return
    cwd = event.get("cwd") or os.getcwd()
    dropped = "\n".join(f"  - {x}" for x in result.get("dropped", []))

    if result["mode"] == "recover" and result.get("new_session"):
        command = f"cd {cwd} && {result['resume']}"
        summary = (f"Session {result['session']} was blocked by Netskope.\n"
                   f"Recovered copy: {result['new_session']} (the original is untouched).\n\n"
                   f"1. /exit the stuck session\n2. {command}\n3. paste as the first message:\n\n"
                   f"{result['first_message']}\n\nDropped:\n{dropped}\n")
        if not DRY:
            subprocess.run(["pbcopy"], input=command, text=True, timeout=10)
        message = "Recovered copy ready. /exit, then paste the resume command (on your clipboard). Details: ~/.claude/netskope-recover/latest.txt"
    elif result["mode"] == "recover":
        summary = f"Dry run for {result['session']}: would keep through line {result['cut_after_line']}.\nDropped:\n{dropped}\n"
        message = "Dry run only."
    else:
        summary = (f"Session {result['session']} was blocked by Netskope ({result['mode']}); no copy can help.\n"
                   f"Start a fresh session without the content below.\n\nBlocked request added:\n{dropped}\n")
        message = "Start a fresh session; details in ~/.claude/netskope-recover/latest.txt"
    (HOME / "latest.txt").write_text(summary)
    notify("Claude session blocked by Netskope", message)


if __name__ == "__main__":
    main()
