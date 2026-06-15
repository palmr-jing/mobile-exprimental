#!/usr/bin/env bash
# Archive, export, and upload MobileCommander to TestFlight via the App Store
# Connect API key. Requires the issuer ID (account-level; not stored in the .p8):
#
#   export ASC_ISSUER_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
#   scripts/upload-testflight.sh
#
# Optional overrides:
#   ASC_KEY_ID   (default 99L2CGPPWK)
#   ASC_KEY_PATH (default ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8)
#   TEAM_ID      (default 9SCSBH976W)
set -euo pipefail
cd "$(dirname "$0")/.."

ASC_KEY_ID="${ASC_KEY_ID:-99L2CGPPWK}"
ASC_KEY_PATH="${ASC_KEY_PATH:-$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8}"
TEAM_ID="${TEAM_ID:-9SCSBH976W}"
: "${ASC_ISSUER_ID:?Set ASC_ISSUER_ID (App Store Connect > Users and Access > Integrations > Keys > Issuer ID)}"

ARCHIVE="build/MobileCommander.xcarchive"
EXPORT_DIR="build/export"

echo "▸ Generating project…"
xcodegen generate >/dev/null

echo "▸ Archiving (Release, automatic signing)…"
xcodebuild archive \
  -scheme MobileCommander \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$ASC_KEY_PATH" \
  -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
  CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM="$TEAM_ID"

echo "▸ Exporting .ipa (app-store)…"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath "$EXPORT_DIR" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$ASC_KEY_PATH" \
  -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID"

IPA=$(ls "$EXPORT_DIR"/*.ipa | head -1)
echo "▸ Validating $IPA …"
xcrun altool --validate-app -f "$IPA" -t ios \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"

echo "▸ Uploading to TestFlight…"
xcrun altool --upload-app -f "$IPA" -t ios \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"

echo "✓ Uploaded. Build will appear in App Store Connect > TestFlight after processing."
