typeset -U path PATH fpath FPATH

ZVM_INIT_MODE=sourcing
[[ -f /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && \
  source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
[[ -f /opt/homebrew/opt/zsh-vi-mode/share/zsh-vi-mode/zsh-vi-mode.plugin.zsh ]] && \
  source /opt/homebrew/opt/zsh-vi-mode/share/zsh-vi-mode/zsh-vi-mode.plugin.zsh
# export HOMEBREW_CASK_OPTS="--appdir=~/Applications"

HISTFILE="$HOME/.zsh_history"
HISTSIZE=100000
SAVEHIST=100000
setopt SHARE_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_REDUCE_BLANKS
setopt HIST_IGNORE_SPACE

export EDITOR=nvim
export VISUAL=nvim
alias v=nvim
alias zs='zsh -n ~/.zshrc && exec zsh'
ze() {
  nvim ~/.zshrc && zsh -n ~/.zshrc && exec zsh
}

export PATH="$HOME/.local/bin:$PATH"
export UV_SYSTEM_CERTS=true
export PYTORCH_ENABLE_MPS_FALLBACK=1
[[ -d "$HOME/.antigravity-ide/antigravity-ide/bin" ]] && \
  export PATH="$HOME/.antigravity-ide/antigravity-ide/bin:$PATH"

alias gad="git add"
alias gcmm="git commit -m"
alias gco="git checkout"
alias gcm="git commit"
alias gcp="git cherry-pick"
alias gst="git status"
alias gpl="git pull"
alias gps="git push"
alias gbr="git branch"
alias gdf="git diff"
alias glog="git log"
alias gcl="git clone" 
alias gft="git fetch"

alias lg="lazygit"

# Managed Mac Privileges.app integration (only active if PrivilegesCLI exists)
if [[ -x "/Applications/Privileges.app/Contents/MacOS/PrivilegesCLI" ]]; then
  alias priv='/Applications/Privileges.app/Contents/MacOS/PrivilegesCLI --add --reason "Client Engagement Related"'
  alias unpriv='/Applications/Privileges.app/Contents/MacOS/PrivilegesCLI --remove'

  sudo() {
    # Check if we currently have admin rights
    if ! /Applications/Privileges.app/Contents/MacOS/PrivilegesCLI -s 2>/dev/null | grep -q "administrator privileges"; then
      echo "🔑 Requesting admin privileges..."
      /Applications/Privileges.app/Contents/MacOS/PrivilegesCLI --add --reason "Client Engagement Related" || return 1
    fi
    command sudo "$@"
  }
fi

ccp() {
  print -n -- "${1:A}" | pbcopy
}

# Completion initialization (including Docker CLI completions)
[[ -d "$HOME/.docker/completions" ]] && fpath=("$HOME/.docker/completions" $fpath)
autoload -Uz compinit && compinit

if [[ -f "$HOME/config-personal/starship.toml" ]]; then
  export STARSHIP_CONFIG="$HOME/config-personal/starship.toml"
fi
command -v starship >/dev/null 2>&1 && eval "$(starship init zsh)"
command -v fzf >/dev/null 2>&1 && source <(fzf --zsh)

# Corporate SSL Certificate Trust (only active when ca-bundle.pem is present)
if [[ -f "$HOME/.config/ssl/ca-bundle.pem" ]]; then
  export NODE_EXTRA_CA_CERTS="$HOME/.config/ssl/ca-bundle.pem"
  export SSL_CERT_FILE="$HOME/.config/ssl/ca-bundle.pem"
  export REQUESTS_CA_BUNDLE="$HOME/.config/ssl/ca-bundle.pem"
  export CURL_CA_BUNDLE="$HOME/.config/ssl/ca-bundle.pem"
fi

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init --cmd cd zsh)"
  alias z='cd'
  alias zi='cdi'
fi

[[ -f /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && \
  source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Machine/client-specific local overrides (untracked in git)
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
