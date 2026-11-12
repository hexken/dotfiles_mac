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

1. **`git scrub` does the scrubbing.** A git clean/smudge filter (`scripts/.local/bin/git-scrub`, set up by `git scrub install`, which `bootstrap.sh` runs) swaps each private term for a public stand-in when a file is staged, and back when it is checked out. Files on disk keep the specific wording; commits only ever hold the stand-ins, so commit, push and pull as usual. The map is `~/.config/git-scrub/map.tsv`, untracked and outside the repo: `private<TAB>public` per line, or a private term alone, which the guards refuse in any case. Never commit the map or copy its terms into a tracked file's message, comment or docs.
2. **Add a term when you meet a new detail.** Pick a stand-in that appears nowhere else in the repo, then run `git scrub check`: every tracked file must round-trip unchanged, and the staged copies must hold no private term. Reports name map lines, never the terms.
3. **The guards.** The pre-commit hook refuses a staged file or path that holds a private term, the commit-msg hook a message that does, and the pre-push hook any commit whose message, paths or added lines do (the filter bypassed, say). `git scrub audit` lists past commits that added one. The filter can't scrub file names or the commit author: keep private terms out of both.
4. **Still prefer an untracked override** when the tool can read a second file (`~/.zshrc.local`, `~/.gitconfig.local`, a skill's `LOCAL.md` such as `~/.claude/netskope-recover/LOCAL.md`): details that are long or sensitive belong there, not in the map.

## Known caveat

Claude Code may replace `~/.claude/settings.json` instead of writing through the symlink when it saves settings. If `readlink ~/.claude/settings.json` prints nothing, move the file back into `claude/.claude/` and restow.
