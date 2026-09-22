#!/usr/bin/env bash
# Eduly — TestFlight IPA üretimi
# Önkoşul: Apple Developer'da en az 1 cihaz kayıtlı + Xcode Accounts'ta Fahrettin team
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

export PATH="/opt/homebrew/bin:$PATH"

echo "==> Flutter pub get"
flutter pub get

echo "==> IPA (App Store Connect / TestFlight)"
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist

echo ""
echo "IPA yolu:"
ls -la build/ios/ipa/*.ipa 2>/dev/null || ls -la build/ios/ipa/
echo ""
echo "Sonraki: Transporter ile yükle → App Store Connect → TestFlight"
echo "Arkadaşlar TestFlight'tan kurar; her telefonun UDID'sini eklemen GEREKMEZ."
