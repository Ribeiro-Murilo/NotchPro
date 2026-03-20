# Build Guide — NotchPro

Como gerar um `.app` e um `.dmg` funcional para distribuição.

---

## Pré-requisitos

| Requisito | Versão mínima |
|-----------|--------------|
| Xcode | 15+ |
| macOS | 14 Sonoma+ |
| Apple Developer Account | Opcional (necessário para distribuição pública) |

---

## 1. Build de Release via Xcode

No Xcode:

1. Selecione o scheme **NotchPro** e o destino **My Mac**
2. Mude o scheme para **Release**: `Product → Scheme → Edit Scheme → Run → Build Configuration → Release`
3. `Product → Archive`
4. No Organizer, clique em **Distribute App → Copy App** para exportar o `.app`

---

## 2. Build via linha de comando

```bash
# Build Release
xcodebuild \
  -scheme NotchPro \
  -configuration Release \
  -archivePath ./build/NotchPro.xcarchive \
  archive

# Exportar .app (sem assinatura — uso local)
xcodebuild \
  -exportArchive \
  -archivePath ./build/NotchPro.xcarchive \
  -exportPath ./build/export \
  -exportOptionsPlist ExportOptions.plist
```

Crie o arquivo `ExportOptions.plist` na raiz do projeto:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>mac-application</string>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
```

O `.app` exportado ficará em `./build/export/NotchPro.app`.

---

## 3. Criar o .dmg

### Opção A — Script manual com `hdiutil` (sem dependências)

```bash
#!/bin/bash
set -e

APP_PATH="./build/export/NotchPro.app"
DMG_NAME="NotchPro-1.0.dmg"
DMG_TMP="./build/tmp_dmg"
DMG_OUT="./build/$DMG_NAME"
VOLUME_NAME="NotchPro"

# Cria pasta temporária com o .app e atalho para /Applications
rm -rf "$DMG_TMP"
mkdir -p "$DMG_TMP"
cp -r "$APP_PATH" "$DMG_TMP/"
ln -s /Applications "$DMG_TMP/Applications"

# Cria o DMG
hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$DMG_TMP" \
  -ov \
  -format UDZO \
  "$DMG_OUT"

rm -rf "$DMG_TMP"
echo "✓ DMG criado: $DMG_OUT"
```

Salve como `scripts/make_dmg.sh` e execute:

```bash
chmod +x scripts/make_dmg.sh
./scripts/make_dmg.sh
```

### Opção B — `create-dmg` (DMG com visual customizado)

```bash
# Instalar
brew install create-dmg

# Gerar
create-dmg \
  --volname "NotchPro" \
  --volicon "NotchPro/Assets.xcassets/AppIcon.appiconset/icon_512x512.png" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "NotchPro.app" 175 190 \
  --hide-extension "NotchPro.app" \
  --app-drop-link 425 190 \
  "build/NotchPro-1.0.dmg" \
  "build/export/"
```

---

## 4. Assinatura e Notarização (distribuição pública)

Necessário para distribuir fora da Mac App Store sem o aviso de Gatekeeper.
Requer Apple Developer Program ($99/ano).

```bash
# 1. Assinar o .app com Developer ID
codesign \
  --deep \
  --force \
  --options runtime \
  --sign "Developer ID Application: Murilo Ribeiro (TEAM_ID)" \
  "./build/export/NotchPro.app"

# 2. Assinar o .dmg
codesign \
  --sign "Developer ID Application: Murilo Ribeiro (TEAM_ID)" \
  "./build/NotchPro-1.0.dmg"

# 3. Enviar para notarização
xcrun notarytool submit "./build/NotchPro-1.0.dmg" \
  --apple-id "seu@email.com" \
  --team-id "TEAM_ID" \
  --password "app-specific-password" \
  --wait

# 4. Grampear o ticket no DMG
xcrun stapler staple "./build/NotchPro-1.0.dmg"
```

> Para gerar uma **app-specific password**: [appleid.apple.com](https://appleid.apple.com) → Segurança → Senhas para apps.

---

## 5. Permissões necessárias (Entitlements)

O NotchPro usa AppleScript para controlar Music e Spotify. O usuário precisa conceder permissão na primeira execução:

**Configurações do Sistema → Privacidade e Segurança → Automação**

O app precisa de acesso a:
- **Music**
- **Spotify** (se instalado)

Isso acontece automaticamente quando o app tenta fazer a primeira chamada AppleScript — o macOS exibirá o diálogo de permissão.

---

## 6. Estrutura de saída esperada

```
build/
├── NotchPro.xcarchive/
├── export/
│   └── NotchPro.app
└── NotchPro-1.0.dmg
```

---

## Notas importantes

- O app usa **MediaRemote.framework** (framework privado da Apple). Isso impede publicação na **Mac App Store**.
- Para distribuição via Mac App Store seria necessário substituir MediaRemote por `MediaPlayer` framework público, o que limita funcionalidades.
- O DMG gerado funcionará normalmente em Macs com macOS 14+ sem assinatura, mas o Gatekeeper exibirá um aviso na primeira abertura. O usuário pode contornar com **clique direito → Abrir**.
