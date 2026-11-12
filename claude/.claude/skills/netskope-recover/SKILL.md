---
name: netskope-recover
description: Recover a Claude Code session stuck on "API Error: 403 Your IT Admin has blocked this request" (a corporate Netskope proxy). Use when the user says a session is stuck, blocked, or hit that 403, or asks to recover one. Writes a copy of the session that ends on the last request the proxy accepted.
allowed-tools: Bash(python3 -I ${CLAUDE_SKILL_DIR}/recover.py *)
---

# Recover a session blocked by Netskope

Netskope decrypts every request to api.anthropic.com. When it classifies a request as a file upload, it returns this 403. Claude Code resends the whole conversation on every turn, and `/compact` does too, so once blocked content is in the history the session can't make another request. Claude Code's "Please run /login" hint is wrong; logging in doesn't help.

The fix is a copy of the transcript that stops before the blocked content. `recover.py` writes it under a new session ID and never modifies the original.

Site-specific details (the employer, the proxy rule's name, where blocks are logged locally) are in `~/.claude/netskope-recover/LOCAL.md` when it exists. Read it if the user needs them, e.g. to report a block to IT. Never copy them into this skill: the dotfiles repo is public. (Its description names them only in this local copy; `git scrub` swaps them for stand-ins when the file is committed.)

## Steps

1. Find the session. If the user gave an ID, use it. Otherwise ask, or let the script find the newest session in the current directory whose last reply is the 403.
2. Dry run first and show the user the plan:
   `python3 -I ${CLAUDE_SKILL_DIR}/recover.py --session <id> --dry-run`
3. If the mode is `recover`, run it again without `--dry-run`. It prints the new ID, the resume command and a first message to paste. A StopFailure hook may already have made the copy; the script then reuses it.
4. Tell the user: quit the stuck session (`/exit`), run the resume command from the same directory, and paste the first message, which tells the model what not to repeat. They don't need to `/compact` first.

Other modes:
- `first-request`: the session's first request was blocked, so there's nothing to keep. Tell the user to start a new session without the listed attachments.
- `after-compact`: the first request after a `/compact` was blocked. Recommend a fresh session that doesn't re-attach the listed files.

The stuck session can also run the script itself: `! python3 -I ~/.claude/skills/netskope-recover/recover.py`. A `!` command runs locally and makes no API call.

## Rules

- Never print, read or quote the dropped content. It's exactly what the proxy blocks, so it would get this session stuck too. The script describes it by tool, file name and size only.
- Never kill the stuck session's process or edit its transcript; the user quits it.
- Never read images or PDFs into the conversation. Netskope has blocked every one sent from this machine.
- Netskope logs each block under the user's name. Don't test the proxy to see what it blocks.
