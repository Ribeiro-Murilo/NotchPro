#!/bin/bash
# make_dmg.sh — Gera NotchPro.dmg
# Uso: ./scripts/make_dmg.sh [versao]
# Exemplo: ./scripts/make_dmg.sh 1.0
set -e

VERSION=${1:-"1.0"}
APP_NAME="NotchPro"
APP_PATH="./build/export/${APP_NAME}.app"
DMG_TMP="./build/tmp_dmg"
DMG_OUT="./build/${APP_NAME}-${VERSION}.dmg"

# --- Verifica se o .app existe ---
if [ ! -d "$APP_PATH" ]; then
  echo "Erro: $APP_PATH não encontrado."
  echo "Execute primeiro: xcodebuild -scheme NotchPro -configuration Release archive ..."
  exit 1
fi

echo "→ Criando DMG para ${APP_NAME} v${VERSION}..."

# --- Monta pasta temporária ---
rm -rf "$DMG_TMP"
mkdir -p "$DMG_TMP"
cp -r "$APP_PATH" "$DMG_TMP/"
ln -s /Applications "$DMG_TMP/Applications"

# --- Gera DMG comprimido ---
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_TMP" \
  -ov \
  -format UDZO \
  "$DMG_OUT"

rm -rf "$DMG_TMP"

echo ""
echo "✓ DMG criado com sucesso: $DMG_OUT"
echo "  Tamanho: $(du -sh "$DMG_OUT" | cut -f1)"
