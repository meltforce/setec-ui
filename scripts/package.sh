#!/usr/bin/env bash
# Build a signed DMG of Setec UI, and notarize it when asked to.
#
# `make dmg`, `make notarize` and .github/workflows/release.yml all call this
# one script, so the DMG a release tag produces is built by the same steps as
# one built by hand — a CI-only copy of these steps drifts from the local one
# and neither side reports it.
#
# Usage:
#   scripts/package.sh [--version X.Y.Z] [--notarize]
#
# Versions are dates: YYYY.MM.DD, plus an optional fourth component counting a
# second release on the same day (2026.09.21.2). Without --version the version
# stays what project.yml sets; the release workflow passes the tag.
#
# Notarization credentials, in the order they are looked for:
#   APPSTORE_CONNECT_KEY_ID / _ISSUER_ID / _PRIVATE_KEY — App Store Connect API
#       key. _PRIVATE_KEY carries the .p8 contents, which is how GitHub Actions
#       passes it; a readable file path is accepted as well.
#   NOTARY_PROFILE (default `notary`) — a notarytool keychain profile written by
#       `xcrun notarytool store-credentials`. The local path.
set -euo pipefail

APP_NAME="Setec UI"
SCHEME="SetecUI"
PROJECT="SetecUI.xcodeproj"
DERIVED="${DERIVED:-.build}"
TEAM_ID="R43S29F4G5"
IDENTITY="Developer ID Application"

VERSION=""
NOTARIZE=false

while [ $# -gt 0 ]; do
  case "$1" in
    --version) VERSION="${2:?--version needs a value}"; shift 2 ;;
    --notarize) NOTARIZE=true; shift ;;
    -h|--help) sed -n '2,26p' "$0"; exit 0 ;;
    *) echo "package.sh: unknown argument $1" >&2; exit 2 ;;
  esac
done

cd "$(dirname "$0")/.."

# A tag may carry the leading v; the bundle version must not.
VERSION="${VERSION#v}"
if [ -z "$VERSION" ]; then
  VERSION=$(sed -n 's/^ *MARKETING_VERSION: *"\(.*\)"/\1/p' project.yml | head -1)
  echo "package: no --version given, using project.yml's $VERSION"
fi

if ! [[ "$VERSION" =~ ^[0-9]{4}\.[0-9]{2}\.[0-9]{2}(\.[0-9]+)?$ ]]; then
  echo "package: '$VERSION' is not a version — the scheme is YYYY.MM.DD, and" >&2
  echo "         YYYY.MM.DD.N for a second release on the same day" >&2
  exit 2
fi

# CFBundleShortVersionString takes at most three period-separated integers, so
# the same-day counter cannot ride in it. It becomes the build number instead,
# which is what CFBundleVersion is for: two builds of one date differ there and
# agree on the version the app displays.
SHORT_VERSION=$(cut -d. -f1-3 <<<"$VERSION")
BUILD_NUMBER=$(cut -d. -f4 <<<"$VERSION")
BUILD_NUMBER="${BUILD_NUMBER:-1}"

DMG="$DERIVED/Setec-UI-$VERSION.dmg"
APP="$DERIVED/Build/Products/Release/$APP_NAME.app"

# The identity has to be in the keychain search list before the build, not after
# it: xcodebuild signs as part of the build and reports a missing identity as a
# build failure several hundred lines in.
if ! security find-identity -v -p codesigning | grep -q "$IDENTITY: .*($TEAM_ID)"; then
  echo "package: no '$IDENTITY' certificate for team $TEAM_ID in the keychain search list" >&2
  exit 1
fi

for tool in xcodegen create-dmg; do
  command -v "$tool" >/dev/null 2>&1 || { echo "package: $tool is not installed" >&2; exit 1; }
done

echo "package: building $APP_NAME $SHORT_VERSION (build $BUILD_NUMBER)"
xcodegen generate --quiet

# generic/platform=macOS with ONLY_ACTIVE_ARCH=NO builds both architectures, so
# the published DMG runs on Intel Macs as well as on Apple silicon. The Debug
# path in the Makefile pins arm64 instead, because nothing on a seat Mac needs
# the second slice and it doubles the build.
rm -rf "$APP"
set -o pipefail
BUILD_CMD=(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release
  -derivedDataPath "$DERIVED" -destination 'generic/platform=macOS'
  ONLY_ACTIVE_ARCH=NO
  MARKETING_VERSION="$SHORT_VERSION" CURRENT_PROJECT_VERSION="$BUILD_NUMBER"
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$IDENTITY"
  DEVELOPMENT_TEAM="$TEAM_ID" OTHER_CODE_SIGN_FLAGS="--timestamp"
  build)
if command -v xcbeautify >/dev/null 2>&1; then
  "${BUILD_CMD[@]}" | xcbeautify --quiet
else
  "${BUILD_CMD[@]}"
fi

# Three properties the notary service rejects a submission for, each checked
# where it is cheap rather than after a round trip that takes minutes.
echo "package: checking the signature"
SIGN_INFO=$(codesign -dvvv "$APP" 2>&1)
grep -q "Authority=$IDENTITY: .*($TEAM_ID)" <<<"$SIGN_INFO" || {
  echo "package: the app is not signed with $IDENTITY ($TEAM_ID)" >&2
  grep '^Authority' <<<"$SIGN_INFO" >&2 || true
  exit 1
}
grep -qE 'flags=0x[0-9a-f]*\(.*runtime' <<<"$SIGN_INFO" || {
  echo "package: hardened runtime is not enabled — project.yml sets ENABLE_HARDENED_RUNTIME" >&2
  exit 1
}
grep -q 'Timestamp=' <<<"$SIGN_INFO" || {
  echo "package: the signature carries no secure timestamp" >&2
  exit 1
}
codesign --verify --strict --verbose=2 "$APP"
echo "package: architectures $(lipo -archs "$APP/Contents/MacOS/$APP_NAME")"

echo "package: building $DMG"
STAGE="$DERIVED/dmg"
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/$APP_NAME.app"
create-dmg \
  --volname "$APP_NAME" \
  --window-pos 200 120 --window-size 600 400 --icon-size 100 \
  --icon "$APP_NAME.app" 150 200 \
  --app-drop-link 450 200 \
  --hide-extension "$APP_NAME.app" \
  --no-internet-enable \
  "$DMG" "$STAGE"
rm -rf "$STAGE"
[ -f "$DMG" ] || { echo "package: create-dmg reported success and wrote no file" >&2; exit 1; }

if [ "$NOTARIZE" = false ]; then
  echo "package: $DMG (signed, not notarized)"
  exit 0
fi

# notarytool takes either a keychain profile or the three API-key values. The
# key is written to a file because notarytool reads it from one; it is written
# under a private umask and removed on exit, including on a failed submission.
NOTARY_ARGS=()
KEY_FILE=""
if [ -n "${APPSTORE_CONNECT_KEY_ID:-}" ]; then
  : "${APPSTORE_CONNECT_ISSUER_ID:?APPSTORE_CONNECT_KEY_ID is set, so APPSTORE_CONNECT_ISSUER_ID is needed too}"
  : "${APPSTORE_CONNECT_PRIVATE_KEY:?APPSTORE_CONNECT_KEY_ID is set, so APPSTORE_CONNECT_PRIVATE_KEY is needed too}"
  if [ -f "$APPSTORE_CONNECT_PRIVATE_KEY" ]; then
    KEY_PATH="$APPSTORE_CONNECT_PRIVATE_KEY"
  else
    # mktemp creates the file with mode 0600, which is the mode the key needs.
    KEY_FILE=$(mktemp "${TMPDIR:-/tmp}/AuthKey_XXXXXX.p8")
    KEY_PATH="$KEY_FILE"
    # A secret passed through CI arrives with its newlines escaped often enough
    # that notarytool's PEM parser rejects it; the base64 body is rewrapped at
    # 64 columns rather than trusted as it arrives.
    APPSTORE_CONNECT_PRIVATE_KEY="$APPSTORE_CONNECT_PRIVATE_KEY" KEY_PATH="$KEY_PATH" python3 - <<'PY'
import os, textwrap

key = os.environ["APPSTORE_CONNECT_PRIVATE_KEY"].replace("\\n", "\n").strip()
body = "".join(l.strip() for l in key.splitlines() if l and not l.startswith("-----"))
pem = "-----BEGIN PRIVATE KEY-----\n%s\n-----END PRIVATE KEY-----\n" % "\n".join(
    textwrap.wrap(body, 64)
)
with open(os.environ["KEY_PATH"], "w") as fh:
    fh.write(pem)
PY
  fi
  trap '[ -n "$KEY_FILE" ] && rm -f "$KEY_FILE"' EXIT
  NOTARY_ARGS=(--key "$KEY_PATH" --key-id "$APPSTORE_CONNECT_KEY_ID" --issuer "$APPSTORE_CONNECT_ISSUER_ID")
else
  NOTARY_ARGS=(--keychain-profile "${NOTARY_PROFILE:-notary}")
fi

echo "package: submitting $(basename "$DMG") to the notary service"
SUBMISSION=$(xcrun notarytool submit "$DMG" "${NOTARY_ARGS[@]}" --output-format json --wait)
echo "$SUBMISSION"
STATUS=$(python3 -c 'import sys,json; print(json.load(sys.stdin).get("status",""))' <<<"$SUBMISSION")
if [ "$STATUS" != "Accepted" ]; then
  ID=$(python3 -c 'import sys,json; print(json.load(sys.stdin).get("id",""))' <<<"$SUBMISSION")
  [ -n "$ID" ] && xcrun notarytool log "$ID" "${NOTARY_ARGS[@]}" || true
  echo "package: notarization ended as $STATUS" >&2
  exit 1
fi

xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
# What Gatekeeper answers for a downloaded disk image, which is the question the
# operator opening the DMG is actually asking.
spctl --assess --type open --context context:primary-signature -vv "$DMG"
echo "package: $DMG (notarized and stapled)"
