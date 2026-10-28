#!/usr/bin/env zsh
# ==============================================================================
# ~/dotfiles/bootstrap.sh
# Interactive pacman-style bootstrapper for Homebrew tiers & GNU Stow dotfiles
# ==============================================================================

set -euo pipefail

DOTFILES_DIR="${0:A:h}"
BACKUP_DIR="$DOTFILES_DIR/.backups/$(date +%Y%m%d-%H%M%S)"

# ANSI Colors
BOLD=$'\033[1m'
DIM=$'\033[2m'
BLUE=$'\033[1;34m'
GREEN=$'\033[1;32m'
YELLOW=$'\033[1;33m'
CYAN=$'\033[1;36m'
RED=$'\033[1;31m'
RESET=$'\033[0m'

info()  { print -P "${BLUE}::${RESET} ${BOLD}$1${RESET}"; }
ok()    { print -P "${GREEN}✔${RESET} $1"; }
warn()  { print -P "${YELLOW}⚠${RESET} $1"; }
err()   { print -P "${RED}✘${RESET} $1" >&2; }

# Stow package definitions: "name|target_description"
STOW_PACKAGES=(
  "zsh|~/.zshrc, ~/.zprofile"
  "git|~/.gitconfig"
  "wezterm|~/.wezterm.lua"
  "starship|~/.config/starship.toml"
  "herdr|~/.config/herdr/config.toml, ~/.local/bin/herdr-name (no-folding)"
  "claude|~/.claude/CLAUDE.md, settings.json, hooks (no-folding)"
  "nvim|~/.config/nvim (LazyVim)"
  "tmux|~/.config/tmux/tmux.conf"
  "karabiner|~/.config/karabiner"
  "hammerspoon|~/.hammerspoon/init.lua"
  "scripts|~/.local/bin & ~/Library/LaunchAgents (llama-server)"
)

usage() {
  cat <<EOF
${BOLD}Usage:${RESET} ./bootstrap.sh [options]

${BOLD}Options:${RESET}
  (no flags)      Interactive pacman-style setup (choose tiers, packages, and configs)
  --core          Pre-select only Tier 1 (Brewfile.core) + core terminal configs
  --apps          Pre-select Tier 1 + Tier 2 (Brewfile.core + Brewfile.apps)
  --ai            Pre-select Tier 3 (Brewfile.ai)
  --all           Pre-select all 3 Brewfile tiers and all Stow configs
  -s, --stow-only Only select and link Stow dotfile configs (skip Homebrew)
  -b, --brew-only Only select and install Homebrew packages (skip Stow)
  -a, --audit     Find installed Homebrew packages not yet in any Brewfile tier
  -y, --yes       Non-interactive: accept all defaults in selected tiers without prompting
  -h, --help      Show this help message

${BOLD}Pacman Selection Syntax:${RESET}
  <Enter> or all  Select all items in the list
  1 3 5-8         Select only items 1, 3, and 5 through 8
  ^4 ^10-12       Select all items EXCEPT 4 and 10 through 12 (also supports !4 or -4)
  none or n       Skip all items in the current group
EOF
}

# ------------------------------------------------------------------------------
# Parse pacman-style selection string against total count N
# Sets global array SELECTED_INDICES=(1 2 ...)
# ------------------------------------------------------------------------------
parse_pacman_selection() {
  local input="$1"
  local max="$2"
  SELECTED_INDICES=()

  # Normalize commas to spaces and trim whitespace
  input="${input//,/ }"
  input="${input#"${input%%[![:space:]]*}"}"
  input="${input%"${input##*[![:space:]]*}"}"

  if [[ -z "$input" || "$input" == "all" || "$input" == "a" || "$input" == "*" ]]; then
    for (( i = 1; i <= max; i++ )); do
      SELECTED_INDICES+=($i)
    done
    return 0
  fi

  if [[ "$input" == "none" || "$input" == "n" || "$input" == "0" ]]; then
    return 0
  fi

  local tokens=(${=input})
  local has_positive=0
  local -A included=()
  local -A excluded=()

  for tok in "${tokens[@]}"; do
    local is_neg=0
    if [[ "$tok" == [\^\!\-]* ]]; then
      is_neg=1
      tok="${tok#[\^\!\-]}"
    else
      has_positive=1
    fi

    local start end
    if [[ "$tok" == <->-<-> ]]; then
      start="${tok%-*}"
      end="${tok#*-}"
    elif [[ "$tok" == <-> ]]; then
      start="$tok"
      end="$tok"
    else
      warn "Ignoring invalid selection token: '$tok'"
      continue
    fi

    (( start < 1 )) && start=1
    (( end > max )) && end=$max
    for (( i = start; i <= end; i++ )); do
      if (( is_neg )); then
        excluded[$i]=1
      else
        included[$i]=1
      fi
    done
  done

  for (( i = 1; i <= max; i++ )); do
    if (( has_positive )); then
      if [[ -n "${included[$i]:-}" && -z "${excluded[$i]:-}" ]]; then
        SELECTED_INDICES+=($i)
      fi
    else
      if [[ -z "${excluded[$i]:-}" ]]; then
        SELECTED_INDICES+=($i)
      fi
    fi
  done
}

# ------------------------------------------------------------------------------
# Ensure initial repo directories (nvim, karabiner, fonts) are seeded from $HOME
# if running for the first time on the primary machine
# ------------------------------------------------------------------------------
seed_from_home_if_needed() {
  # 1. Seed Neovim config if missing in repo but present in ~/.config/nvim
  if [[ ! -e "$DOTFILES_DIR/nvim/.config/nvim/init.lua" && -d "$HOME/.config/nvim" && ! -L "$HOME/.config/nvim" ]]; then
    info "Seeding nvim/.config/nvim from ~/.config/nvim..."
    mkdir -p "$DOTFILES_DIR/nvim/.config"
    cp -R "$HOME/.config/nvim" "$DOTFILES_DIR/nvim/.config/nvim"
    rm -rf "$DOTFILES_DIR/nvim/.config/nvim/.git"
  fi

  # 2. Seed Karabiner config if missing in repo
  if [[ ! -e "$DOTFILES_DIR/karabiner/.config/karabiner/karabiner.json" && -d "$HOME/.config/karabiner" && ! -L "$HOME/.config/karabiner" ]]; then
    info "Seeding karabiner/.config/karabiner from ~/.config/karabiner..."
    mkdir -p "$DOTFILES_DIR/karabiner/.config/karabiner"
    [[ -f "$HOME/.config/karabiner/karabiner.json" ]] && \
      cp "$HOME/.config/karabiner/karabiner.json" "$DOTFILES_DIR/karabiner/.config/karabiner/"
    [[ -d "$HOME/.config/karabiner/assets" ]] && \
      cp -R "$HOME/.config/karabiner/assets" "$DOTFILES_DIR/karabiner/.config/karabiner/"
  fi

  # 3. Seed custom ZxProto / 0xProto fonts if missing in repo
  if [[ ! -d "$DOTFILES_DIR/fonts" ]]; then
    mkdir -p "$DOTFILES_DIR/fonts"
    local font_files=("$HOME"/Library/Fonts/(ZxProto|0xProto)*(N))
    if (( ${#font_files[@]} > 0 )); then
      info "Seeding custom ZxProto / 0xProto fonts into ~/dotfiles/fonts/..."
      cp "${font_files[@]}" "$DOTFILES_DIR/fonts/"
    fi
  fi
}

# ------------------------------------------------------------------------------
# Audit mode: compare installed Homebrew packages against Brewfile.{core,apps,ai}
# ------------------------------------------------------------------------------
run_audit() {
  info "Auditing installed Homebrew formulae and casks against ~/dotfiles/brew/Brewfile.*..."
  local -A tracked=()
  for bf in "$DOTFILES_DIR"/brew/Brewfile.*; do
    while IFS= read -r line; do
      if [[ "$line" =~ '^(brew|cask)[[:space:]]+"([^"]+)"' ]]; then
        local full_name="${match[2]}"
        local short_name="${full_name:t}"
        tracked[$full_name]=1
        tracked[$short_name]=1
      fi
    done < "$bf"
  done

  local untracked_formulae=()
  local untracked_casks=()

  for f in $(brew leaves 2>/dev/null); do
    local short="${f:t}"
    if [[ -z "${tracked[$f]:-}" && -z "${tracked[$short]:-}" ]]; then
      untracked_formulae+=("$f")
    fi
  done

  for c in $(brew list --cask -1 2>/dev/null); do
    local short="${c:t}"
    if [[ -z "${tracked[$c]:-}" && -z "${tracked[$short]:-}" ]]; then
      untracked_casks+=("$c")
    fi
  done

  if (( ${#untracked_formulae[@]} == 0 && ${#untracked_casks[@]} == 0 )); then
    ok "All top-level Homebrew formulae and casks are tracked in your Brewfiles!"
    return 0
  fi

  echo
  info "Found untracked packages:"
  for f in "${untracked_formulae[@]}"; do
    echo "  ${CYAN}brew${RESET} \"$f\""
    read -r "choice?  Add '$f' to [1] core, [2] apps, [3] ai, or [s]kip? (default=s): "
    case "$choice" in
      1|core) echo "brew \"$f\"" >> "$DOTFILES_DIR/brew/Brewfile.core"; ok "Added to Brewfile.core" ;;
      2|apps) echo "brew \"$f\"" >> "$DOTFILES_DIR/brew/Brewfile.apps"; ok "Added to Brewfile.apps" ;;
      3|ai)   echo "brew \"$f\"" >> "$DOTFILES_DIR/brew/Brewfile.ai";   ok "Added to Brewfile.ai" ;;
      *)      echo "  Skipped." ;;
    esac
  done

  for c in "${untracked_casks[@]}"; do
    echo "  ${CYAN}cask${RESET} \"$c\""
    read -r "choice?  Add '$c' to [1] core, [2] apps, [3] ai, or [s]kip? (default=s): "
    case "$choice" in
      1|core) echo "cask \"$c\"" >> "$DOTFILES_DIR/brew/Brewfile.core"; ok "Added to Brewfile.core" ;;
      2|apps) echo "cask \"$c\"" >> "$DOTFILES_DIR/brew/Brewfile.apps"; ok "Added to Brewfile.apps" ;;
      3|ai)   echo "cask \"$c\"" >> "$DOTFILES_DIR/brew/Brewfile.ai";   ok "Added to Brewfile.ai" ;;
      *)      echo "  Skipped." ;;
    esac
  done
}

# ------------------------------------------------------------------------------
# Main execution
# ------------------------------------------------------------------------------
DO_BREW=1
DO_STOW=1
AUTO_YES=0
TIERS_ARG=()

while (( $# > 0 )); do
  case "$1" in
    --core)           TIERS_ARG+=("core") ;;
    --apps)           TIERS_ARG+=("core" "apps") ;;
    --ai)             TIERS_ARG+=("ai") ;;
    --all)            TIERS_ARG+=("core" "apps" "ai") ;;
    -s|--stow-only)   DO_BREW=0 ;;
    -b|--brew-only)   DO_STOW=0 ;;
    -a|--audit)       run_audit; exit 0 ;;
    -y|--yes)         AUTO_YES=1 ;;
    -h|--help)        usage; exit 0 ;;
    *)                err "Unknown argument: $1"; usage; exit 1 ;;
  esac
  shift
done

seed_from_home_if_needed

# Ensure Homebrew exists if DO_BREW=1
if (( DO_BREW )); then
  if ! command -v brew >/dev/null 2>&1; then
    info "Homebrew not found. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    [[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv zsh)"
  fi
fi

FINAL_BREW_LINES=()
FINAL_BREW_LABELS=()
FINAL_TAPS=()

if (( DO_BREW )); then
  info "Querying currently installed Homebrew packages..."
  INSTALLED_FORMULAE=($(brew list --formula -1 2>/dev/null || true))
  INSTALLED_CASKS=($(brew list --cask -1 2>/dev/null || true))

  ALL_TIERS=("core" "apps" "ai")
  TIER_DESCRIPTIONS=(
    "Brewfile.core — CLI essentials, shell plugins, Neovim, WezTerm, Stow"
    "Brewfile.apps — macOS desktop utilities, browsers, VS Code, Docker"
    "Brewfile.ai   — AI/LLM coding agents & local inference tools"
  )

  SELECTED_TIERS=()
  if (( ${#TIERS_ARG[@]} > 0 )); then
    typeset -U TIERS_ARG
    SELECTED_TIERS=("${TIERS_ARG[@]}")
  elif (( AUTO_YES )); then
    SELECTED_TIERS=("core" "apps" "ai")
  else
    echo
    info "There are 3 Homebrew package tiers available:"
    for (( i = 1; i <= ${#ALL_TIERS[@]}; i++ )); do
      printf "   ${BOLD}%d)${RESET} %-6s  ${DIM}%s${RESET}\n" "$i" "${ALL_TIERS[$i]}" "${TIER_DESCRIPTIONS[$i]}"
    done
    echo
    read -r "tier_input?Enter tiers to configure (default=all, e.g. \"1\" for core only, \"1 2\" for core+apps): "
    parse_pacman_selection "$tier_input" "${#ALL_TIERS[@]}"
    for idx in "${SELECTED_INDICES[@]}"; do
      SELECTED_TIERS+=("${ALL_TIERS[$idx]}")
    done
  fi

  # For each selected tier, parse Brewfile.<tier> and show pacman-style member prompt
  for tier in "${SELECTED_TIERS[@]}"; do
    bf="$DOTFILES_DIR/brew/Brewfile.$tier"
    [[ ! -f "$bf" ]] && continue

    pkg_lines=()
    pkg_types=()
    pkg_names=()
    pkg_descs=()
    pkg_status=()
    tier_taps=()
    last_comment=""

    while IFS= read -r raw_line; do
      line="${raw_line#"${raw_line%%[![:space:]]*}"}"
      [[ -z "$line" ]] && { last_comment=""; continue; }

      if [[ "$line" == \#* ]]; then
        last_comment="${line#\#}"
        last_comment="${last_comment#"${last_comment%%[![:space:]]*}"}"
        continue
      fi

      if [[ "$line" =~ '^tap[[:space:]]+"([^"]+)"' ]]; then
        tier_taps+=("$line")
        last_comment=""
        continue
      fi

      if [[ "$line" =~ '^(brew|cask|uv)[[:space:]]+"([^"]+)"' ]]; then
        p_type="${match[1]}"
        p_name="${match[2]}"
        short_name="${p_name:t}"

        is_inst=0
        if [[ "$p_type" == "brew" ]]; then
          (( ${INSTALLED_FORMULAE[(Ie)$short_name]} )) && is_inst=1
        elif [[ "$p_type" == "cask" ]]; then
          (( ${INSTALLED_CASKS[(Ie)$short_name]} )) && is_inst=1
        fi

        pkg_lines+=("$line")
        pkg_types+=("$p_type")
        pkg_names+=("$p_name")
        pkg_descs+=("$last_comment")
        pkg_status+=("$is_inst")
        last_comment=""
      fi
    done < "$bf"

    count=${#pkg_lines[@]}
    (( count == 0 )) && continue

    echo
    info "There are ${count} members in group ${CYAN}${tier}${RESET} (brew/Brewfile.${tier}):"
    for (( i = 1; i <= count; i++ )); do
      badge=""
      if (( pkg_status[$i] )); then
        badge=" ${GREEN}[installed]${RESET}"
      fi
      desc_str=""
      [[ -n "${pkg_descs[$i]}" ]] && desc_str="${DIM}# ${pkg_descs[$i]}${RESET}"
      printf "  ${BOLD}%2d)${RESET} %-4s %-26s%-22s %s\n" \
        "$i" "${pkg_types[$i]}" "${pkg_names[$i]}" "$badge" "$desc_str"
    done

    if (( AUTO_YES )); then
      parse_pacman_selection "all" "$count"
    else
      echo
      read -r "sel_input?Enter a selection for ${tier} (default=all, e.g. \"^3 ^7-9\" to exclude, \"none\" to skip): "
      parse_pacman_selection "$sel_input" "$count"
    fi

    if (( ${#SELECTED_INDICES[@]} > 0 )); then
      for tap_line in "${tier_taps[@]}"; do
        FINAL_TAPS+=("$tap_line")
      done
      for idx in "${SELECTED_INDICES[@]}"; do
        FINAL_BREW_LINES+=("${pkg_lines[$idx]}")
        FINAL_BREW_LABELS+=("${pkg_types[$idx]}/${pkg_names[$idx]}")
      done
    fi
  done
fi

# ------------------------------------------------------------------------------
# Select GNU Stow dotfile packages (pacman-style)
# ------------------------------------------------------------------------------
FINAL_STOW_PKGS=()
if (( DO_STOW )); then
  stow_count=${#STOW_PACKAGES[@]}
  echo
  info "There are ${stow_count} members in group ${CYAN}dotfiles${RESET} (GNU Stow packages):"
  for (( i = 1; i <= stow_count; i++ )); do
    entry="${STOW_PACKAGES[$i]}"
    s_name="${entry%%|*}"
    s_desc="${entry#*|}"
    printf "  ${BOLD}%2d)${RESET} %-14s ${DIM}%s${RESET}\n" "$i" "$s_name" "$s_desc"
  done

  if (( AUTO_YES )); then
    parse_pacman_selection "all" "$stow_count"
  else
    echo
    read -r "stow_input?Enter a selection for dotfiles (default=all, e.g. \"^8 ^9\" to exclude, \"none\" to skip): "
    parse_pacman_selection "$stow_input" "$stow_count"
  fi

  for idx in "${SELECTED_INDICES[@]}"; do
    entry="${STOW_PACKAGES[$idx]}"
    FINAL_STOW_PKGS+=("${entry%%|*}")
  done
fi

# ------------------------------------------------------------------------------
# Transaction Summary & Confirmation
# ------------------------------------------------------------------------------
if (( ${#FINAL_BREW_LINES[@]} == 0 && ${#FINAL_STOW_PKGS[@]} == 0 )); then
  warn "Nothing selected to install or stow. Exiting."
  exit 0
fi

echo
info "Transaction Summary"
if (( ${#FINAL_BREW_LABELS[@]} > 0 )); then
  print -P "\n${BOLD}Homebrew Packages (${#FINAL_BREW_LABELS[@]}):${RESET}"
  print -r -- "  ${FINAL_BREW_LABELS[*]}" | fold -s -w 88 | sed '2,$s/^/  /'
fi

if (( ${#FINAL_STOW_PKGS[@]} > 0 )); then
  print -P "\n${BOLD}Dotfile Configs to Stow (${#FINAL_STOW_PKGS[@]}):${RESET}"
  print -r -- "  ${FINAL_STOW_PKGS[*]}"
fi
echo

if (( ! AUTO_YES )); then
  read -r "confirm?:: Proceed with installation? [Y/n] "
  if [[ "$confirm" =~ ^[Nn] ]]; then
    warn "Aborted by user."
    exit 0
  fi
fi

# ------------------------------------------------------------------------------
# Execute Homebrew Bundle installation
# ------------------------------------------------------------------------------
if (( ${#FINAL_BREW_LINES[@]} > 0 )); then
  tmp_brewfile="$(mktemp -t Brewfile.selected.XXXXXX)"
  trap 'rm -f "$tmp_brewfile"' EXIT

  typeset -U FINAL_TAPS
  for t in "${FINAL_TAPS[@]}"; do
    print -r -- "$t" >> "$tmp_brewfile"
  done
  for l in "${FINAL_BREW_LINES[@]}"; do
    print -r -- "$l" >> "$tmp_brewfile"
  done

  info "Running brew bundle for ${#FINAL_BREW_LINES[@]} selected package(s)..."
  brew bundle --file="$tmp_brewfile"
  ok "Homebrew packages complete."
fi

# ------------------------------------------------------------------------------
# Install Custom Fonts (ZxProto / 0xProto) if present in ~/dotfiles/fonts
# ------------------------------------------------------------------------------
if (( DO_STOW )) && [[ -d "$DOTFILES_DIR/fonts" ]]; then
  font_list=("$DOTFILES_DIR"/fonts/*.(ttf|otf)(N))
  if (( ${#font_list[@]} > 0 )); then
    mkdir -p "$HOME/Library/Fonts"
    copied_fonts=0
    for ff in "${font_list[@]}"; do
      fname="${ff:t}"
      if [[ ! -f "$HOME/Library/Fonts/$fname" ]]; then
        cp "$ff" "$HOME/Library/Fonts/$fname"
        (( copied_fonts++ )) || true
      fi
    done
    (( copied_fonts > 0 )) && ok "Installed $copied_fonts font file(s) to ~/Library/Fonts"
  fi
fi

# ------------------------------------------------------------------------------
# Safely Backup Existing Files & Run GNU Stow
# ------------------------------------------------------------------------------
backup_if_real_file() {
  local target="$1"
  if [[ -e "$target" && ! -L "$target" ]]; then
    mkdir -p "$BACKUP_DIR"
    local rel="${target#$HOME/}"
    local dest="$BACKUP_DIR/$rel"
    mkdir -p "${dest:h}"
    mv "$target" "$dest"
    info "Backed up existing ~/$rel -> ${BACKUP_DIR#$DOTFILES_DIR/}/$rel"
  fi
}

if (( ${#FINAL_STOW_PKGS[@]} > 0 )); then
  if ! command -v stow >/dev/null 2>&1; then
    info "Installing GNU Stow via Homebrew..."
    brew install stow
  fi

  for pkg in "${FINAL_STOW_PKGS[@]}"; do
    case "$pkg" in
      zsh)
        backup_if_real_file "$HOME/.zshrc"
        backup_if_real_file "$HOME/.zprofile"
        stow -d "$DOTFILES_DIR" -t "$HOME" --restow zsh
        ;;
      git)
        backup_if_real_file "$HOME/.gitconfig"
        stow -d "$DOTFILES_DIR" -t "$HOME" --restow git
        ;;
      wezterm)
        backup_if_real_file "$HOME/.wezterm.lua"
        stow -d "$DOTFILES_DIR" -t "$HOME" --restow wezterm
        ;;
      starship)
        mkdir -p "$HOME/.config"
        backup_if_real_file "$HOME/.config/starship.toml"
        stow -d "$DOTFILES_DIR" -t "$HOME" --restow starship
        ;;
      herdr)
        mkdir -p "$HOME/.config/herdr"
        mkdir -p "$HOME/.local/bin"
        backup_if_real_file "$HOME/.config/herdr/config.toml"
        backup_if_real_file "$HOME/.local/bin/herdr-name"
        chmod +x "$DOTFILES_DIR/herdr/.local/bin/"* 2>/dev/null || true
        stow -d "$DOTFILES_DIR" -t "$HOME" --no-folding --restow herdr
        ;;
      claude)
        mkdir -p "$HOME/.claude/hooks"
        backup_if_real_file "$HOME/.claude/CLAUDE.md"
        backup_if_real_file "$HOME/.claude/settings.json"
        backup_if_real_file "$HOME/.claude/hooks/herdr-restore-name.sh"
        chmod +x "$DOTFILES_DIR/claude/.claude/hooks/"* 2>/dev/null || true
        stow -d "$DOTFILES_DIR" -t "$HOME" --no-folding --restow claude
        # herdr-agent-state.sh is owned by Herdr's integration, not tracked here
        if command -v herdr >/dev/null 2>&1; then
          herdr integration install claude >/dev/null 2>&1 || warn "herdr integration install claude failed"
        fi
        ;;
      nvim)
        mkdir -p "$HOME/.config"
        backup_if_real_file "$HOME/.config/nvim"
        stow -d "$DOTFILES_DIR" -t "$HOME" --restow nvim
        ;;
      tmux)
        mkdir -p "$HOME/.config/tmux"
        backup_if_real_file "$HOME/.config/tmux/tmux.conf"
        stow -d "$DOTFILES_DIR" -t "$HOME" --restow tmux
        ;;
      karabiner)
        mkdir -p "$HOME/.config"
        backup_if_real_file "$HOME/.config/karabiner"
        stow -d "$DOTFILES_DIR" -t "$HOME" --restow karabiner
        ;;
      hammerspoon)
        mkdir -p "$HOME/.hammerspoon"
        backup_if_real_file "$HOME/.hammerspoon/init.lua"
        stow -d "$DOTFILES_DIR" -t "$HOME" --no-folding --restow hammerspoon
        ;;
      scripts)
        mkdir -p "$HOME/.local/bin" "$HOME/Library/LaunchAgents"
        backup_if_real_file "$HOME/.local/bin/start-llama-qwen"
        backup_if_real_file "$HOME/.local/bin/stop-llama-qwen"
        backup_if_real_file "$HOME/Library/LaunchAgents/com.ktjhia.llama-qwen.plist"
        chmod +x "$DOTFILES_DIR/scripts/.local/bin/"* 2>/dev/null || true
        stow -d "$DOTFILES_DIR" -t "$HOME" --no-folding --restow scripts
        if [[ -f "$HOME/Library/LaunchAgents/com.ktjhia.llama-qwen.plist" ]]; then
          launchctl bootout "gui/$(id -u)/com.ktjhia.llama-qwen" 2>/dev/null || true
          launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.ktjhia.llama-qwen.plist" 2>/dev/null || true
        fi
        ;;
    esac
    ok "Stowed $pkg"
  done
fi

echo
ok "All done! Your dotfiles and packages are synced."
