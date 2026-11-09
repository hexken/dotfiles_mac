#!/usr/bin/env python3
"""PreToolUse hook: deny MCP tool calls that return images. Netskope blocks every request carrying an
image, and the image then stays in the conversation, so the whole session is lost."""
import json
import re
import sys

IMAGE_MODES = {"screenshot", "zoom"}
ALWAYS_IMAGES = re.compile(r"^mcp__(computer-use__|remote-devices__computer)")


def modes(tool_input: dict) -> set[str]:
    found = set()
    for container in (tool_input, tool_input.get("payload") if isinstance(tool_input.get("payload"), dict) else {}):
        for key in ("action", "kind", "type"):
            value = container.get(key)
            if isinstance(value, str):
                found.add(value.lower())
    return found


def main() -> None:
    event = json.load(sys.stdin)
    name = event.get("tool_name", "")
    tool_input = event.get("tool_input") or {}
    if not (ALWAYS_IMAGES.match(name) or "screenshot" in name.lower() or modes(tool_input) & IMAGE_MODES):
        return
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": (
            "Blocked: this call returns an image, and the corporate proxy rejects every request "
            "carrying an image, which breaks the session for good. Get the information as text instead: "
            "for web pages run `page-text <url>` (see the web-ui-text skill); otherwise read the document "
            "text, DOM, logs or test output, or ask the user to look."),
    }}))


if __name__ == "__main__":
    main()
