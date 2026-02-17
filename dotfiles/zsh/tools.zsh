# zoxide init
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

# atuin init
if command -v atuin >/dev/null 2>&1; then
  eval "$(atuin init zsh --disable-up-arrow)"
fi
