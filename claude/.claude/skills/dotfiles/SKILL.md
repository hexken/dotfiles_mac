---
name: dotfiles
description: Track configs or scripts from this session in the user's ~/dotfiles repo (GNU Stow + bootstrap.sh). Invoked manually with /dotfiles.
disable-model-invocation: true
---

# Track configs in ~/dotfiles

The user keeps system configs in `~/dotfiles`, managed with GNU Stow and installed by `~/dotfiles/bootstrap.sh`.

1. Read `~/dotfiles/CLAUDE.md` (the conventions; follow them exactly) and skim `~/dotfiles/README.md` and the `STOW_PACKAGES` list and `case "$pkg"` block in `~/dotfiles/bootstrap.sh`.
2. Work out which files from this session should be tracked. If the user named them, use those; otherwise list the configs and scripts created or changed in this session and confirm with the user. Point out anything that should *not* be tracked (machine-local state, tool-managed files, secrets) and why.
3. For each file, propose the package and repo path, and whether it needs `--no-folding`, before moving anything.
4. Move the files, restow, and update `bootstrap.sh` and `.gitignore` as `CLAUDE.md` describes.
5. Verify as `CLAUDE.md` describes, then report what moved where and show `git status --short` with a suggested commit message. Do not commit.

If `$ARGUMENTS` is given, treat it as the files or tool to track.
