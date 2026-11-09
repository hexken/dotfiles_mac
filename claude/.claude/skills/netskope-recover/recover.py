#!/usr/bin/env python3
"""Recover a Claude Code session stuck on Netskope's "Your IT Admin has blocked this request" 403.

Writes a copy of the session under a new ID that ends on the last request the proxy accepted.
The original transcript is never modified. Dropped content is described, never printed: printing
it would put it back into whichever conversation reads this output.
"""
import argparse
import glob
import json
import os
import re
import sys
import uuid
from pathlib import Path

MARKER = "IT Admin has blocked"
PROJECTS = Path.home() / ".claude" / "projects"
STATE = Path.home() / ".claude" / "netskope-recover" / "state.json"


def load(path: Path) -> list[dict]:
    return [json.loads(line) for line in path.read_text().splitlines() if line.strip()]


def is_block(d: dict) -> bool:
    if d.get("isSidechain"):
        return False
    if d.get("type") == "assistant" and d.get("isApiErrorMessage"):
        return MARKER in json.dumps(d.get("message"))
    return d.get("type") == "system" and MARKER in str(d.get("content", ""))


def is_good_reply(d: dict) -> bool:
    return d.get("type") == "assistant" and not d.get("isApiErrorMessage") and not d.get("isSidechain")


def find_transcript(args: argparse.Namespace) -> Path:
    if args.transcript:
        return Path(args.transcript).expanduser()
    if args.session:
        hits = glob.glob(str(PROJECTS / "*" / f"{args.session}*.jsonl"))
        if len(hits) != 1:
            sys.exit(f"expected one transcript for session {args.session}, found {len(hits)}")
        return Path(hits[0])
    project = PROJECTS / re.sub(r"[^A-Za-z0-9]", "-", os.getcwd())
    for path in sorted(project.glob("*.jsonl"), key=lambda p: p.stat().st_mtime, reverse=True):
        entries = load(path)
        last = next((d for d in reversed(entries) if d.get("type") in ("assistant", "system") and not d.get("isSidechain")), None)
        if last and is_block(last):
            return path
    sys.exit(f"no session in {project} ends in the Netskope 403; pass --session or --transcript")


def describe(entries: list[dict]) -> list[str]:
    out = []
    for d in entries:
        t = d.get("type")
        if t == "assistant" and not d.get("isApiErrorMessage"):
            for b in d["message"].get("content", []):
                if b.get("type") == "tool_use":
                    inp = b.get("input", {})
                    payload = inp.get("payload") if isinstance(inp.get("payload"), dict) else {}
                    mode = inp.get("action") or payload.get("kind") or ""
                    what = inp.get("description") or inp.get("file_path") or inp.get("pattern") or ""
                    label = ", ".join(str(x)[:100] for x in (mode, what) if x and isinstance(x, str))
                    out.append(f"tool call {b['name']}: {label}" if label else f"tool call {b['name']}")
        elif t == "user":
            c = d["message"].get("content")
            if isinstance(c, str):
                if not c.startswith("<") and not d.get("isMeta"):
                    out.append(f"your prompt ({len(c)} chars)")
            else:
                for b in c:
                    if b.get("type") == "tool_result":
                        cc = b.get("content")
                        kinds = sorted({x.get("type", "?") for x in cc}) if isinstance(cc, list) else ["text"]
                        out.append(f"tool result ({'+'.join(kinds)}, {len(json.dumps(cc))} chars)")
                    elif b.get("type") in ("image", "document"):
                        out.append(f"{b['type']} block")
        elif t == "attachment" and d["attachment"].get("type") in ("file", "compact_file_reference"):
            a = d["attachment"]
            out.append(f"attached file {a.get('filename', '?')}")
        elif t == "system" and d.get("subtype") == "compact_boundary":
            out.append("a /compact")
    return out


def plan(entries: list[dict]) -> dict:
    first_block = next((i for i, d in enumerate(entries) if is_block(d)), None)
    if first_block is None:
        return {"mode": "no-block"}
    good = [i for i in range(first_block) if is_good_reply(entries[i])]
    if not good:
        return {"mode": "first-request", "block": first_block,
                "dropped": describe(entries[:first_block])}
    last_good = good[-1]
    reply_id = entries[last_good]["message"].get("id")
    reply = [i for i in good if entries[i]["message"].get("id") == reply_id]
    between = entries[reply[0]:first_block]
    if any(d.get("subtype") == "compact_boundary" for d in between):
        return {"mode": "after-compact", "block": first_block, "dropped": describe(between)}
    ends_in_tool_use = any(b.get("type") == "tool_use"
                           for i in reply for b in entries[i]["message"].get("content", []))
    cut = reply[0] if ends_in_tool_use else last_good + 1
    leaf = next(d["uuid"] for d in reversed(entries[:cut])
                if d.get("type") in ("user", "assistant") and not d.get("isSidechain"))
    return {"mode": "recover", "block": first_block, "cut": cut, "leaf": leaf,
            "dropped": describe(entries[cut:first_block])}


def verify_chain(entries: list[dict], leaf: str) -> int:
    by_uuid = {d["uuid"]: d for d in entries if "uuid" in d}
    n, u = 0, leaf
    while u:
        if u not in by_uuid:
            sys.exit(f"broken parent chain at {u}; nothing written")
        n += 1
        u = by_uuid[u].get("parentUuid")
    return n


def write_copy(src: Path, entries: list[dict], p: dict) -> tuple[str, str]:
    old = src.stem
    new = str(uuid.uuid4())
    kept = entries[:p["cut"]]
    titles = [d["customTitle"] for d in kept if d.get("type") == "custom-title"]
    title = (titles[-1] if titles else f"session {old[:8]}") + " (recovered)"
    lines = []
    for d in kept:
        if d.get("sessionId") == old:
            d["sessionId"] = new
        if d.get("type") == "custom-title":
            d["customTitle"] = title
        if d.get("type") == "agent-name":
            d["agentName"] = title
        lines.append(json.dumps(d, ensure_ascii=False, separators=(",", ":")))
    last_prompt = next((d.get("lastPrompt") for d in reversed(kept) if d.get("type") == "last-prompt"), "")
    lines.append(json.dumps({"type": "last-prompt", "lastPrompt": last_prompt, "leafUuid": p["leaf"], "sessionId": new}, separators=(",", ":")))
    lines.append(json.dumps({"type": "custom-title", "customTitle": title, "sessionId": new}, separators=(",", ":")))
    dst = src.with_name(new + ".jsonl")
    with open(dst, "x") as f:
        f.write("\n".join(lines) + "\n")
    os.chmod(dst, 0o600)
    companion = src.with_name(new)
    companion.mkdir()
    (companion / "custom-title.json").write_text(json.dumps({"customTitle": title}))
    return new, title


def first_message(dropped: list[str]) -> str:
    items = "; ".join(dropped) or "nothing identifiable"
    return ("This session was recovered after the corporate proxy blocked a request "
            "(403 \"Your IT Admin has blocked this request\"). I cut the blocked content out. "
            f"It was: {items}. Don't repeat those calls or re-read that content into the "
            "conversation; find another way to get what you needed, or ask me. Never read "
            "images or PDFs. Continue where you left off.")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--session", help="session ID (or prefix)")
    ap.add_argument("--transcript", help="path to the session's .jsonl")
    ap.add_argument("--dry-run", action="store_true", help="report the plan, write nothing")
    ap.add_argument("--json", action="store_true", help="machine-readable output (used by the hook)")
    args = ap.parse_args()

    src = find_transcript(args)
    entries = load(src)
    p = plan(entries)
    result = {"source": str(src), "session": src.stem, "mode": p["mode"], "dropped": p.get("dropped", [])}

    if p["mode"] == "recover":
        result["chain_length"] = verify_chain(entries[:p["cut"]], p["leaf"])
        key = f"{src.stem}:{entries[p['block']]['uuid']}"
        state = json.loads(STATE.read_text()) if STATE.exists() else {}
        existing = state.get(key)
        if existing and src.with_name(existing + ".jsonl").exists():
            result.update(new_session=existing, reused=True)
        elif not args.dry_run:
            new, title = write_copy(src, entries, p)
            STATE.parent.mkdir(parents=True, exist_ok=True)
            state[key] = new
            STATE.write_text(json.dumps(state, indent=1))
            result.update(new_session=new, title=title, reused=False)
        result.update(cut_after_line=p["cut"], leaf=p["leaf"], first_message=first_message(p["dropped"]))
        if result.get("new_session"):
            result["resume"] = f"claude --resume {result['new_session']}"

    if args.json:
        print(json.dumps(result))
        return
    print(f"session {result['session']}: {p['mode']}")
    if p["mode"] == "no-block":
        print("no Netskope 403 in this transcript; nothing to do")
    elif p["mode"] == "first-request":
        print("the very first request was blocked, so there is nothing to keep. Start a new session without:")
    elif p["mode"] == "after-compact":
        print("the first request after a /compact was blocked; the last accepted state is the full "
              "pre-compact conversation, so no copy was written. Start a fresh session instead, and don't "
              "re-attach the files listed below. Blocked request added:")
    else:
        print(f"keeps lines 1-{p['cut']} ({result['chain_length']} messages in the chain); dropped:")
    for item in result["dropped"]:
        print(f"  - {item}")
    if p["mode"] == "recover":
        if args.dry_run and not result.get("new_session"):
            print("\n(dry run: nothing written)")
        else:
            print(f"\n{'reused existing copy' if result.get('reused') else 'wrote'} {result['new_session']}")
            cwd = next((d["cwd"] for d in entries if d.get("cwd")), "the same directory")
            print(f"1. quit the stuck session (/exit)\n2. cd {cwd} && {result['resume']}")
            print(f"3. paste as the first message:\n\n{result['first_message']}")


if __name__ == "__main__":
    main()
