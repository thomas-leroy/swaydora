#!/usr/bin/env bash
set -euo pipefail

echo "=== Diagnostic: NetworkManager Secret Agent on Sway ==="
echo ""

# Test 1: Check running processes
echo "[1] Processus en cours d'exécution..."
echo "GNOME Keyring:"
pgrep -a gnome-keyring-daemon || echo "  ❌ Pas actif"
echo ""
echo "KDE Wallet:"
pgrep -a kwalletd5 || echo "  ❌ Pas actif"
echo ""

# Test 2: Check environment variables
echo "[2] Variables d'environnement secret agent..."
echo "GNOME_KEYRING_CONTROL: ${GNOME_KEYRING_CONTROL:-❌ NON DÉFINIE}"
echo "GNOME_KEYRING_PID: ${GNOME_KEYRING_PID:-❌ NON DÉFINIE}"
echo "SSH_AUTH_SOCK: ${SSH_AUTH_SOCK:-❌ NON DÉFINIE}"
echo ""

# Test 3: Check DBus services available
echo "[3] Services DBus disponibles..."
echo "Agents secrets DBus:"
dbus-send --session --print-reply /org/freedesktop/DBus \
  /org/freedesktop/DBus org.freedesktop.DBus.ListNames 2>/dev/null | \
  grep -i -E 'wallet|keyring|secret' || echo "  ❌ Aucun agent secret trouvé"
echo ""

# Test 4: Check NetworkManager status
echo "[4] État de NetworkManager..."
systemctl is-active NetworkManager && echo "  ✅ NetworkManager actif" || echo "  ❌ NetworkManager INACTIF"
echo ""

# Test 5: Check if secret interface exists
echo "[5] Interface org.freedesktop.Secret disponible..."
busctl call org.freedesktop.DBus /org/freedesktop/DBus \
  org.freedesktop.DBus ListNames 2>/dev/null | \
  grep -q org.freedesktop.Secret && echo "  ✅ Oui" || echo "  ❌ Non"
echo ""

# Test 6: Check keyring_start.sh
echo "[6] Script keyring_start.sh..."
if [[ -f ~/.config/scripts/keyring_start.sh ]]; then
  echo "  ✅ Fichier existe"
  echo "  Contenu:"
  head -3 ~/.config/scripts/keyring_start.sh | sed 's/^/    /'
else
  echo "  ❌ Fichier manquant"
fi
echo ""

# Test 7: Try to manually start GNOME Keyring
echo "[7] Test démarrage manuel GNOME Keyring..."
if command -v gnome-keyring-daemon >/dev/null 2>&1; then
  daemon_test="$(gnome-keyring-daemon --start --components=secrets,ssh 2>&1 || true)"
  if [[ -n "$daemon_test" ]]; then
    echo "  ✅ Démarrage réussi"
    echo "$daemon_test" | sed 's/^/    /'
  else
    echo "  ❌ Démarrage échoué"
  fi
else
  echo "  ❌ gnome-keyring-daemon non trouvé"
fi
echo ""

# Test 8: Check packages installed
echo "[8] Packages clés installés..."
for pkg in gnome-keyring kwalletd5 nm-connection-editor networkmanager; do
  if rpm -q "$pkg" >/dev/null 2>&1; then
    echo "  ✅ $pkg"
  else
    echo "  ❌ $pkg"
  fi
done
echo ""

# Test 9: Sway config check
echo "[9] Vérification Sway config (keyring_start.sh)..."
if grep -q "keyring_start.sh" ~/.config/sway/config 2>/dev/null; then
  echo "  ✅ keyring_start.sh trouvé dans config"
  grep "keyring_start.sh" ~/.config/sway/config | sed 's/^/    /'
else
  echo "  ⚠️  keyring_start.sh pas trouvé dans config Sway"
fi
echo ""

# Test 10: Test actual nm-connection-editor availability
echo "[10] Test nm-connection-editor..."
if command -v nm-connection-editor >/dev/null 2>&1; then
  echo "  ✅ nm-connection-editor disponible"
else
  echo "  ❌ nm-connection-editor non trouvé"
fi
echo ""

# Test 11: Check if KDE Wallet can access secrets
echo "[11] Test accès KDE Wallet..."
if command -v kwallet-query >/dev/null 2>&1; then
  kwallet-query kdewallet 2>/dev/null && echo "  ✅ KDE Wallet accessible" || echo "  ❌ KDE Wallet non accessible"
else
  echo "  ⚠️  kwallet-query non disponible"
fi
echo ""

# Summary
echo "=== Résumé ==="
echo "Si vous voyez ❌ sur [3] ou [5]:"
echo "  → L'agent secret n'est pas exposé sur DBus"
echo "  → nm-connection-editor ne pourra pas sauvegarder"
echo ""
echo "Solution rapide: utiliser nmcli --ask"
echo "  nmcli --ask device wifi connect \"<SSID>\" ifname <INTERFACE>"
echo ""
