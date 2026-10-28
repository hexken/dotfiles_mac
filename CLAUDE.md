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
- **Never commit secrets.** Machine- or client-specific values belong in the untracked `~/.zshrc.local`, `~/.gitconfig.local`, or `~/.gitconfig-work`.
- **New Homebrew packages** go in the right `brew/Brewfile.{core,apps,ai}` tier (`./bootstrap.sh --audit` helps).
- **Don't commit.** Leave changes staged or unstaged and show the user the `git status` and a suggested commit message.

## Known caveat

Claude Code may replace `~/.claude/settings.json` instead of writing through the symlink when it saves settings. If `readlink ~/.claude/settings.json` prints nothing, move the file back into `claude/.claude/` and restow.
