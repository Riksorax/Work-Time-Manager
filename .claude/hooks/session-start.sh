#!/bin/bash
# SessionStart-Hook für Claude Code im Web (Cloud-Sessions).
#
# Installiert die drei Toolchains des Monorepos, damit Claude in Cloud-Sessions
# dieselben Checks wie die CI ausführen kann:
#   - Flutter (Version aus .github/workflows/ci.yml, damit beide synchron bleiben)
#   - .NET 10 SDK
#   - Node-Abhängigkeiten für web/
#
# Idempotent: bereits installierte Toolchains werden übersprungen. Läuft nur in
# Cloud-Sessions ($CLAUDE_CODE_REMOTE=true), lokal passiert nichts.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
ENV_FILE="${CLAUDE_ENV_FILE:-/dev/null}"

FLUTTER_HOME="/opt/flutter"
DOTNET_HOME="$HOME/.dotnet"

log() { echo "[session-start] $*" >&2; }

# ── Flutter ──────────────────────────────────────────────────────────────────
FLUTTER_VERSION=$(grep -oP "flutter-version:\s*'\K[^']+" "$PROJECT_DIR/.github/workflows/ci.yml" | head -n1)
if [ -z "$FLUTTER_VERSION" ]; then
  log "Flutter-Version nicht in ci.yml gefunden, Flutter wird übersprungen."
else
  INSTALLED=""
  VERSION_JSON="$FLUTTER_HOME/bin/cache/flutter.version.json"
  if [ -x "$FLUTTER_HOME/bin/flutter" ] && [ -f "$VERSION_JSON" ]; then
    INSTALLED=$(jq -r '.frameworkVersion // empty' "$VERSION_JSON")
  fi
  if [ "$INSTALLED" != "$FLUTTER_VERSION" ]; then
    log "Installiere Flutter $FLUTTER_VERSION ..."
    BASE_URL="https://storage.googleapis.com/flutter_infra_release/releases"
    ARCHIVE=$(curl -fsSL "$BASE_URL/releases_linux.json" \
      | jq -r --arg v "$FLUTTER_VERSION" \
          '.releases[] | select(.version == $v and .channel == "stable") | .archive' \
      | head -n1)
    if [ -z "$ARCHIVE" ]; then
      log "Flutter $FLUTTER_VERSION nicht in releases_linux.json gefunden."
      exit 1
    fi
    rm -rf "$FLUTTER_HOME"
    mkdir -p "$(dirname "$FLUTTER_HOME")"
    curl -fsSL "$BASE_URL/$ARCHIVE" | tar -xJ -C "$(dirname "$FLUTTER_HOME")"
  else
    log "Flutter $FLUTTER_VERSION bereits installiert."
  fi
  # Das Archiv enthält ein Git-Repo mit fremdem Owner.
  git config --global --get-all safe.directory | grep -qx "$FLUTTER_HOME" \
    || git config --global --add safe.directory "$FLUTTER_HOME"
  export PATH="$FLUTTER_HOME/bin:$HOME/.pub-cache/bin:$PATH"
  echo "export PATH=\"$FLUTTER_HOME/bin:\$HOME/.pub-cache/bin:\$PATH\"" >> "$ENV_FILE"

  flutter config --no-analytics >/dev/null 2>&1 || true
  dart --disable-analytics >/dev/null 2>&1 || true
  flutter --version >&2

  log "flutter pub get (mobile/) ..."
  (cd "$PROJECT_DIR/mobile" && flutter pub get >&2)
fi

# ── .NET ─────────────────────────────────────────────────────────────────────
if [ ! -x "$DOTNET_HOME/dotnet" ] || ! "$DOTNET_HOME/dotnet" --list-sdks | grep -q '^10\.'; then
  log "Installiere .NET 10 SDK ..."
  curl -fsSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh
  bash /tmp/dotnet-install.sh --channel 10.0 --install-dir "$DOTNET_HOME" >&2
  rm -f /tmp/dotnet-install.sh
else
  log ".NET 10 SDK bereits installiert."
fi
export DOTNET_ROOT="$DOTNET_HOME"
export DOTNET_CLI_TELEMETRY_OPTOUT=1
export DOTNET_NOLOGO=1
export PATH="$DOTNET_HOME:$DOTNET_HOME/tools:$PATH"
{
  echo "export DOTNET_ROOT=\"$DOTNET_HOME\""
  echo "export DOTNET_CLI_TELEMETRY_OPTOUT=1"
  echo "export DOTNET_NOLOGO=1"
  echo "export PATH=\"$DOTNET_HOME:$DOTNET_HOME/tools:\$PATH\""
} >> "$ENV_FILE"

log "dotnet restore (server/) ..."
(cd "$PROJECT_DIR/server" && dotnet restore WorkTimeManager.slnx >&2)

# ── Web (Angular) ────────────────────────────────────────────────────────────
if command -v npm >/dev/null 2>&1; then
  log "npm install (web/) ..."
  (cd "$PROJECT_DIR/web" && npm install --legacy-peer-deps --no-audit --no-fund >&2)
else
  log "npm nicht gefunden, web/ wird übersprungen."
fi

log "Fertig."
