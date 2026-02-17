#!/usr/bin/env bash
set -euo pipefail

# Print consistent log messages for this script.
log() {
  printf '[themes] %s\n' "$*"
}

# Write a minimal GTK settings.ini file to the target path.
write_gtk_settings() {
  local target="$1"
  mkdir -p "$(dirname "$target")"
  cat > "$target" <<'EOT'
[Settings]
gtk-application-prefer-dark-theme=1
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Adwaita
gtk-cursor-theme-name=Adwaita
gtk-font-name=JetBrainsMono Nerd Font 11
EOT
}

main() {
  # Apply same GTK settings for both GTK3 and GTK4 apps.
  write_gtk_settings "$HOME/.config/gtk-3.0/settings.ini"
  write_gtk_settings "$HOME/.config/gtk-4.0/settings.ini"

  # Export minimal theme environment variables for session apps.
  mkdir -p "$HOME/.config/environment.d"
  cat > "$HOME/.config/environment.d/90-theme.conf" <<'EOT'
GTK_THEME=Adwaita-dark
XCURSOR_THEME=Adwaita
EOT

  log 'applied minimal GTK/icon/cursor defaults'
}

# Entrypoint.
main "$@"
