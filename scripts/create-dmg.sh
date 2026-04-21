#!/usr/bin/env bash
# Gera um DMG distribuível com layout "arraste pra Applications".
# Requer: create-dmg (brew install create-dmg) e um build Release prévio.
#
# Uso:
#   ./scripts/create-dmg.sh            # monta dist/iCloudPeek-<versão>.dmg
#   ./scripts/create-dmg.sh 0.2.0      # versiona como 0.2.0

set -euo pipefail

VERSION="${1:-0.1.0}"
OUT="dist/iCloudPeek-${VERSION}.dmg"

if ! command -v create-dmg >/dev/null 2>&1; then
    echo "❌ create-dmg não instalado. Rode: brew install create-dmg" >&2
    exit 1
fi

REL_APP=$(ls -d ~/Library/Developer/Xcode/DerivedData/iCloudPeek-*/Build/Products/Release/iCloudPeek.app 2>/dev/null | head -1)

if [ -z "$REL_APP" ] || [ ! -d "$REL_APP" ]; then
    echo "❌ iCloudPeek.app de Release não encontrado. Rode primeiro:" >&2
    echo "   xcodebuild -project iCloudPeek.xcodeproj -scheme iCloudPeek -configuration Release \\" >&2
    echo "     CODE_SIGN_IDENTITY=\"-\" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build" >&2
    exit 2
fi

mkdir -p dist
rm -f "$OUT"

STAGE=$(mktemp -d)
trap "rm -rf '$STAGE'" EXIT

cp -R "$REL_APP" "$STAGE/"

create-dmg \
    --volname "iCloudPeek" \
    --window-pos 200 120 \
    --window-size 540 380 \
    --icon-size 110 \
    --icon "iCloudPeek.app" 140 170 \
    --hide-extension "iCloudPeek.app" \
    --app-drop-link 400 170 \
    --no-internet-enable \
    "$OUT" \
    "$STAGE/"

echo "✅ DMG criado: $OUT ($(du -h "$OUT" | cut -f1))"
