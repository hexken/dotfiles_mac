# macOS Dotfiles (`~/dotfiles`)

Modular macOS configuration and Homebrew setup managed with **GNU Stow** and an interactive **`pacman`-style `bootstrap.sh`** installer.

---

## Quick Start on a New MacBook

```zsh
git clone <your-repo-url> ~/dotfiles
cd ~/dotfiles
chmod +x bootstrap.sh
./bootstrap.sh
```

---

## Interactive `pacman`-Style Selection

When you run `./bootstrap.sh`, it displays numbered lists for each Homebrew tier (`core`, `apps`, `ai`) and your Stow config packages, showing which items are already `[installed]`:

```text
:: There are 24 members in group core (brew/Brewfile.core):
   1) brew ast-grep                  [installed]   # Code searching, linting, rewriting
   2) brew coreutils                 [installed]   # GNU File, Shell, and Text utilities
   ...
  24) cask wezterm                   [installed]   # GPU-accelerated cross-platform terminal...

Enter a selection for core (default=all, e.g. "^3 ^7-9" to exclude, "none" to skip):
```

### Supported Selection Syntax
| Input | Meaning |
| :--- | :--- |
| **`<Enter>`** or **`all`** | Select all items in the group |
| **`1 3 5-8`** | Select **only** items `1`, `3`, and `5` through `8` |
| **`^4 ^10-12`** *(or `!4`, `-4`)* | Select all items **except** `4` and `10` through `12` |
| **`none`** or **`n`** | Skip the entire group |

---

## Useful Flags

```zsh
# Interactive mode (prompts for tiers, packages, and dotfiles)
./bootstrap.sh

# Pre-select only Tier 1 (Brewfile.core) — great for locked-down client laptops
./bootstrap.sh --core

# Pre-select Tier 1 + Tier 2 (core + desktop apps)
./bootstrap.sh --apps

#Only link/re-link Stow dotfile configs (skip Homebrew)
./bootstrap.sh --stow-only

# Only run Homebrew package selector (skip Stow)
./bootstrap.sh --brew-only

# Check if you've installed any new Homebrew packages not yet in Brewfile.{core,apps,ai}
./bootstrap.sh --audit
```

---

## Configuring Homebrew Tiers (`~/dotfiles/brew/`)

Your packages live in three plain-text files:
1. [`brew/Brewfile.core`](brew/Brewfile.core) — Terminal, shell plugins, CLI tools, Neovim, WezTerm, Stow
2. [`brew/Brewfile.apps`](brew/Brewfile.apps) — macOS desktop utilities, browsers, Docker, VS Code
3. [`brew/Brewfile.ai`](brew/Brewfile.ai) — AI/LLM tools (Cursor, Antigravity, ChatGPT, Codex, `llama.cpp`, `omp`)

* **To move a package between tiers:** Cut and paste its line between `Brewfile.core`, `Brewfile.apps`, or `Brewfile.ai`.
* **When you `brew install` something new:** Run `./bootstrap.sh --audit` to interactively add newly installed packages to `core`, `apps`, or `ai`.

---

## Machine / Client-Specific Overrides (Untracked)

* **Zsh (`~/.zshrc.local`)**: Automatically sourced at the bottom of `.zshrc` if present. Put client-specific environment variables, tokens, or proxy settings here so they never get committed to Git.
* **Git (`~/.gitconfig.local` & `~/.gitconfig-work`)**: Automatically included by `.gitconfig`. Keep your work or client email address inside `~/.gitconfig.local` or `~/.gitconfig-work`.
