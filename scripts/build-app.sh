#!/usr/bin/env bash
# Compila Acolytus y lo empaqueta como Acolytus.app (app de barra de menú, sin Dock).
#
#   ./scripts/build-app.sh            → build/Acolytus.app
#   ./scripts/build-app.sh --install  → además lo copia a ~/Applications y lo abre
set -euo pipefail

cd "$(dirname "$0")/.."
APP="build/Acolytus.app"
VERSION="${VERSION:-0.1.0}"

swift build -c release --product Acolytus
BIN="$(swift build -c release --show-bin-path)/Acolytus"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Acolytus"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>             <string>Acolytus</string>
    <key>CFBundleDisplayName</key>      <string>Acolytus</string>
    <key>CFBundleIdentifier</key>       <string>dev.limonada.acolytus</string>
    <key>CFBundleExecutable</key>       <string>Acolytus</string>
    <key>CFBundlePackageType</key>      <string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key>          <string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key>   <string>13.0</string>
    <key>LSUIElement</key>              <true/>
    <key>NSHighResolutionCapable</key>  <true/>
</dict>
</plist>
PLIST

# Firma ad-hoc: suficiente para uso personal.
codesign --force --deep --sign - "$APP"
echo "✓ $APP"

if [[ "${1:-}" == "--install" ]]; then
    mkdir -p "$HOME/Applications"
    pkill -x Acolytus 2>/dev/null || true
    rm -rf "$HOME/Applications/Acolytus.app"
    cp -R "$APP" "$HOME/Applications/"
    open "$HOME/Applications/Acolytus.app"
    echo "✓ Instalado en ~/Applications/Acolytus.app"
fi
