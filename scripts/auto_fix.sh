#!/usr/bin/env bash
# Auto-fix script for Flutter/Dart build errors
set -uo pipefail

ROOT="$(pwd)"
MAIN_DART="$ROOT/lib/main.dart"
PUBSPEC="$ROOT/pubspec.yaml"

CYAN="\033[1;36m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
NC="\033[0m"

log()  { echo -e "${CYAN}[auto-fix]${NC} $1"; }
ok()   { echo -e "${GREEN}[auto-fix]${NC} $1"; }
warn() { echo -e "${YELLOW}[auto-fix]${NC} $1"; }

# ---- 1. Backup main.dart ----
if [ -f "$MAIN_DART" ]; then
  cp "$MAIN_DART" "$MAIN_DART.bak"
  ok "Backed up main.dart → main.dart.bak"
fi

# ---- 2. Fix const RichText ----
if [ -f "$MAIN_DART" ]; then
  if grep -q "const RichText(" "$MAIN_DART"; then
    # Replace `const RichText(` with `RichText(` and add const to first TextSpan
    sed -i 's/const RichText(/RichText(/g' "$MAIN_DART"
    sed -i 's/RichText(\s*$/RichText(/' "$MAIN_DART"
    # Add const to TextSpan after RichText
    perl -i -0pe 's/RichText\((\s*)text:\s*TextSpan\(/RichText($1text: const TextSpan(/g' "$MAIN_DART"
    ok "Fixed const RichText issue"
  fi
fi

# ---- 3. Fix raw-string regex escaping (broken patterns) ----
if [ -f "$MAIN_DART" ]; then
  # Replace the specific broken pattern with the correct one
  perl -i -pe 's/RegExp\(r"\x27\(\?:\[\x27\\\\\\\\\]\|\\\\\\\\.\)\*\x27\|/RegExp("\x27(?:[\x27\\\\\\\\\\\\\\\\]|\\\\\\\\\\\\.)*\x27|/g' "$MAIN_DART" || true
  ok "Attempted regex escaping fix"
fi

# ---- 4. Clean caches ----
for d in "$ROOT/android/.gradle" "$ROOT/build" "$ROOT/.dart_tool"; do
  if [ -d "$d" ]; then
    log "Removing $d"
    rm -rf "$d"
  fi
done

# ---- 5. flutter clean + pub get ----
if command -v flutter >/dev/null 2>&1; then
  log "Running flutter clean..."
  flutter clean || true
  log "Running flutter pub get..."
  flutter pub get || true
  ok "Dependencies refreshed"
else
  warn "flutter not found in PATH — skipping clean/pub get"
fi

ok "Auto-fix complete ✅"
