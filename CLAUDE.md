# Dotfiles conventions

This repo tracks macOS configs with GNU Stow (target `$HOME`) and installs them with `bootstrap.sh`. See `README.md` for the user-facing overview.

## Adding a config to the repo

1. **Pick a package.** One top-level directory per tool (`zsh/`, `herdr/`, `claude/`, …). Inside it, mirror the path relative to `$HOME`: `~/.config/foo/bar.toml` lives at `foo/.config/foo/bar.toml`. A helper script that only makes sense with one tool goes in that tool's package (e.g. `herdr/.local/bin/herdr-name`); general scripts go in `scripts/.local/bin/`.
2. **Move, then stow.** `mv` the real file into the package, then `stow -d ~/dotfiles -t ~ [--no-folding] --restow <pkg>`. Confirm with `ls -la` that the original path is now a symlink into the repo.
3. **Decide on `--no-folding`.** Use it whenever the target directory also holds files the repo must not own (runtime state, sockets, logs, caches, files managed by another tool). Without it, Stow may symlink the whole directory and that state lands in the repo. `herdr`, `claude`, `hammerspoon` and `scripts` use it; `nvim` and `karabiner` fold the whole directory.
4. **Update `bootstrap.sh` in two places:**
   - `STOW_PACKAGES`: a `"name|target description"` entry (mention `(no-folding)` if used).
   - The `case "$pkg"` block: `mkdir -p` the parent dirs, `backup_if_real_file` for every tracked target, `chmod +x` for scripts, then the `stow` call with the same flags as step 2. Put any post-install step (e.g. `herdr integration install claude`) here too.
5. **Update `.gitignore`** for runtime files that could appear inside the package directory, following the existing Herdr entries.
6. **Verify.** `zsh -n bootstrap.sh`, check the tool still works through the symlink, then `git status --short`.

## Rules

- **Never track files another tool manages or regenerates** (e.g. `~/.claude/hooks/herdr-agent-state.sh`, written by `herdr integration install`). Have `bootstrap.sh` run the tool's installer instead.
- **Never track machine-local state** (session IDs, caches, `~/.config/herdr/agent-names.tsv`).
- **Never commit secrets or workplace details.** See "The repo is public" below.
- **New Homebrew packages** go in the right `brew/Brewfile.{core,apps,ai}` tier (`./bootstrap.sh --audit` helps).
- **Don't commit.** Leave changes staged or unstaged and show the user the `git status` and a suggested commit message.

## The repo is public: scrub what's published, keep what works locally

`origin` is a public GitHub repo, so every commit is published. Workplace details never go in a commit: employer, client and project names, internal system or policy names, work repo and org names, work email addresses, and secrets. Scrubbing is only for the published copy, though. On this machine, keep whichever version works best, which is usually the specific one.

1. **Check before every commit.** Search the staged diff (`git diff --cached`) for workplace details. If any are there, scrub them first by replacing each with a generic term, e.g. "the corporate proxy".
2. **Prefer an untracked override.** If the tool can read a second file, commit the generic version and put the specifics in an untracked one it reads: `~/.zshrc.local`, `~/.gitconfig.local`, `~/.gitconfig-work`, or for a Claude skill a `LOCAL.md` beside its runtime state that the skill tells Claude to read (e.g. `~/.claude/netskope-recover/LOCAL.md`). Then nothing has to be hidden from git.
3. **Otherwise, commit the scrubbed version and keep the specific one on disk.** Use this when the specifics have to live in the tracked file itself, such as a skill's description or a hook's message:
   - Stage a scrubbed copy without touching the file on disk: write it to a temp file, then `git update-index --cacheinfo 100644,$(git hash-object -w <tmp>),<path>` (use `100755` for executables). Commit.
   - Mark the file `git update-index --skip-worktree <path>`, so git ignores the specific version on disk and it can't be staged by accident.
   - Record the original wording, the scrubbed wording and the file list in the untracked `LOCAL.md`.
   - `git ls-files -v | grep '^S'` lists the hidden files. While a file is hidden, edits to it are never committed. To publish a change, run `--no-skip-worktree`, make the change, stage a scrubbed copy as above, commit, and hide the file again. A `git pull` that changes a hidden file fails until you do the same.

## Known caveat

Claude Code may replace `~/.claude/settings.json` instead of writing through the symlink when it saves settings. If `readlink ~/.claude/settings.json` prints nothing, move the file back into `claude/.claude/` and restow.
