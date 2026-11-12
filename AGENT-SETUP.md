# Coding-agent setup

How the coding agents on this machine are set up, and why: Claude Code, Antigravity (`agy`, Google's agent harness) and Herdr, the terminal multiplexer that runs them side by side. Each project's own details (lanes, briefs, scripts, permission lists) live in that project, usually in `.claude/plans/`. This file is the cross-project picture.

## The corporate proxy

The corporate proxy refuses any model request that carries a file (image, PDF, document), whichever vendor it goes to. Tested both ways:
- **Anthropic:** a Claude Code session that reads an image gets "API Error: 403", and every later request re-sends the file, so the session is stuck. The `netskope-recover` skill (`claude/.claude/skills/`) writes a copy of the session that ends before the file.
- **Google:** an `agy -p` session asked to open a PNG or a PDF got `403` with an HTML page, "Noncompliant action". Text-only requests to the same endpoint pass.

So:
- No agent reads images, screenshots or PDFs.
- Claude Code's user settings deny `Read` on image and PDF extensions.
- Both harnesses carry the rule in their global instructions.
- UIs are checked by text (accessibility snapshot, inner text, bounding boxes; the `web-ui-text` skill).
- Screenshots are saved to disk for a person to open.
- To read a PDF, extract its text first.

## Claude Code

| What | Where |
|---|---|
| Global instructions | `~/.claude/CLAUDE.md` (tracked: `claude/.claude/CLAUDE.md`) |
| User settings: default model, `permissions.defaultMode: "auto"`, deny rules (images, PDFs, merges where wanted), hooks, status line | `~/.claude/settings.json` (tracked) |
| Skills shared across projects (`herdr`, `web-ui-text`, `netskope-recover`, `dotfiles`, …) | `~/.claude/skills/` (tracked) |
| A project's allow rules and auto-mode sentences | `<project>/.claude/settings.local.json` (untracked) |
| A project's rules | `<project>/CLAUDE.md` (in the project's git), plus an untracked `CLAUDE.local.md` |

**Permission model**
- **Auto mode** (`--permission-mode auto`, or the default above): each tool call goes to a classifier.
- **`permissions.allow` rules** approve matching calls outright. Prefix rules look like `Bash(git status:*)`.
- **`permissions.deny` rules** always win.
- **`autoMode.allow`** in a project's settings holds plain-English sentences that tell the classifier what the owner has authorised there, for example pushing to an agent branch after its checks pass.

**What the classifier keeps refusing, rightly:**
- `--no-verify`;
- force pushes;
- an agent widening its own permissions or settings;
- disabling a security hook;
- sending keys to another agent's permission dialog;
- irreversible deletions such as `git worktree remove --force` on a dirty tree.

Those changes are the owner's to make by hand. In practice: an agent writes a script, and the owner reads and runs it.

**Models in use:**
- Opus for building, reviewing, orchestrating and acting as the owner's proxy.
- Sonnet for mechanical sub-agents.
- Fable only when its weekly allowance allows.

## Antigravity (`agy`)

| What | Where |
|---|---|
| CLI settings: `agentMode` (`auto`), `toolPermission`, `allowNonWorkspaceAccess`, default `model`, trusted workspaces | `~/.gemini/antigravity-cli/settings.json` |
| Permanent permission grants (`globalPermissionGrants.allow`) | `~/.gemini/config/config.json` |
| Global rules, loaded in every workspace | `~/.gemini/config/AGENTS.md` (it includes `~/.claude/CLAUDE.md` with `@[label](path)`) |
| Project rules | `AGENTS.md` or `GEMINI.md` at the project root. Use an untracked `AGENTS.md` that includes the project's `CLAUDE.md` and `CLAUDE.local.md`, so both harnesses follow one set of rules. Each rule file is capped at 24 KB after includes |
| Global skills | `~/.gemini/config/skills/<name>/SKILL.md`. Same format as Claude Code skills. Use **real copies**, not symlinks: a symlink that resolves outside the workspace raises a file-access dialog |
| Hooks | `~/.gemini/config/hooks.json`; Herdr installs its own session hook here |

**Permission model**
- **`agentMode: "auto"`** is auto mode for interactive sessions (the app and `agy` in a terminal).
- **`toolPermission`** is the "Tool Execution Policy" for terminal commands: `always-proceed` (no prompts), `request-review`, `strict` or `proceed-in-sandbox`.
- **`allowNonWorkspaceAccess`** governs reads and writes outside the workspace root. Even in auto mode, an outside read raises a dialog unless a grant covers it.
- **Grants** match prefixes: `command(git diff)` covers any `git diff …`, and `read_file(<dir>/)` covers a folder. Never use catch-all grants like `command(*)` or `read_file(/)`.
- **A stuck dialog stalls the session.** No other agent may answer it; only a person can.

**Print mode (`agy -p "<prompt>"`)** is non-interactive, good for one-shot reviews.
- `--mode auto` is refused there behind a server-side rollout flag ("not available for this account"; the log says `rollout flag off`), even when interactive auto mode works. It is not a laptop restriction.
- Without `toolPermission: always-proceed`, print mode refuses any tool needing permission, so it can read files but not run commands.
- `--mode plan` keeps it from changing anything.

**Hooks gotcha.** A `PreToolUse` hook that prints `{}` is read as *deny* for every tool. Print nothing when the hook has no objection, and print `{"decision": "deny", "reason": …}` to refuse. Test the allow path as well as the deny path.

**Models:**
- Gemini 4 Carbon (medium) builds UIs.
- The same model reviews Claude-built work in print mode, as a cross-vendor second opinion. It reads only, but it finds real defects that a same-vendor review misses.
- AGY also serves Claude models on Google's credits. Those sessions lack Claude Code's skills and permission rules.

## Herdr

- Herdr runs each agent in its own pane and reads its state (idle, working, blocked, done). For Claude Code it reads hooks. For AGY it reads the screen, so a block or a dialog can read as "idle".
- An orchestrating agent:
  - starts sessions with `herdr agent start`, always in a newly split pane, never a reused one;
  - names them with `herdr-name` (`herdr/.local/bin/`), because a plain rename does not survive a restart;
  - prompts them with `herdr agent prompt`;
  - polls `herdr agent get` and the files the sessions write, which is the wake signal for its loop.
- Herdr installs its integrations with `herdr integration install <tool>`, which writes hooks into the tools' own folders. Re-run the installer; don't track what it writes.

## Patterns that worked

- **One orchestrator, many short sessions.** Each unit of work gets a fresh builder session with a written brief. It writes a closing summary and stops. Reviews run in separate sessions.
- **Files as the mailbox:** briefs in, summaries and reviews out, and an inbox of open items per unit. They survive restarts and context compaction.
- **Two reviews from two vendors**, then at most one fix round and one light re-review, so review rounds can't spiral.
- **Merge only when** the build is green and the reviews are clean. Agents never merge into the main branch.
- **One heavy test run at a time on a shared laptop.** Wrap whole-suite runs in `lockf -k ~/.cache/<project>-heavy.lock …`.
