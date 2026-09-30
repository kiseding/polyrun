#!/bin/bash
# Package an unsigned iOS .app as a self-signed IPA.
# Prefer a certificate created in this run. If the OS will not trust it
# without a GUI prompt, fall back to an ad-hoc signature. Neither is an
# Apple Developer certificate.
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: self_sign_ipa.sh Runner.app polyrun-ios.ipa" >&2
  exit 2
fi

APP=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
OUT=$2
if [[ "$OUT" != /* ]]; then
  OUT="$PWD/$OUT"
fi

if [[ ! -d "$APP" ]]; then
  echo "找不到应用包: $APP" >&2
  exit 1
fi

TMP=$(mktemp -d)
KEYCHAIN="$TMP/build.keychain"
PASS=$(openssl rand -base64 24)
CERT_NAME="PolyRun Self Signed"
PREVIOUS_KEYCHAINS=$(security list-keychains -d user | sed -e 's/^ *"//' -e 's/"$//')
cleanup() {
  # shellcheck disable=SC2086
  security list-keychains -d user -s $PREVIOUS_KEYCHAINS >/dev/null 2>&1 || true
  security delete-keychain "$KEYCHAIN" >/dev/null 2>&1 || true
  rm -rf "$TMP"
}
trap cleanup EXIT

if [[ -x /usr/bin/openssl ]]; then
  OPENSSL=/usr/bin/openssl
else
  OPENSSL=openssl
fi

cat > "$TMP/codesign.cnf" << EOF
[ req ]
distinguished_name = req_distinguished_name
x509_extensions = codesign_ext
prompt = no
[ req_distinguished_name ]
CN = ${CERT_NAME}
[ codesign_ext ]
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
basicConstraints = critical, CA:false
EOF

"$OPENSSL" req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
  -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -config "$TMP/codesign.cnf" >/dev/null 2>&1
"$OPENSSL" pkcs12 -export \
  -inkey "$TMP/key.pem" -in "$TMP/cert.pem" -out "$TMP/cert.p12" \
  -name "$CERT_NAME" -passout "pass:${PASS}"

security create-keychain -p "$PASS" "$KEYCHAIN"
security set-keychain-settings -lut 21600 "$KEYCHAIN"
security unlock-keychain -p "$PASS" "$KEYCHAIN"
security import "$TMP/cert.p12" -k "$KEYCHAIN" -P "$PASS" -A -T /usr/bin/codesign >/dev/null
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$PASS" "$KEYCHAIN" >/dev/null
# -d writes admin trust settings. GitHub macOS runners allow sudo without a prompt.
# Cap the wait so a GUI authorization dialog cannot stall the build.
python3 - "$KEYCHAIN" "$TMP/cert.pem" << 'PY'
import subprocess, sys
keychain, cert = sys.argv[1], sys.argv[2]
try:
    subprocess.run(
        ["sudo", "-n", "security", "add-trusted-cert", "-d", "-r", "trustRoot",
         "-p", "codeSign", "-k", keychain, cert],
        timeout=20, check=False,
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
except subprocess.TimeoutExpired:
    subprocess.run(["sudo", "-n", "killall", "security"], check=False)
PY
security list-keychains -d user -s "$KEYCHAIN" $PREVIOUS_KEYCHAINS >/dev/null

SIGN_ARGS=(-s -)
IDENTITY=$(security find-identity -v -p codesigning "$KEYCHAIN" | sed -n 's/.*"\(.*\)"/\1/p' | head -1 || true)
if [[ -n "${IDENTITY:-}" ]]; then
  SIGN_ARGS=(-s "$IDENTITY" --keychain "$KEYCHAIN")
  echo "使用自签名证书: $IDENTITY"
else
  echo "系统未信任自签名证书，改用 ad-hoc 自签名"
fi

cat > "$TMP/entitlements.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict/>
</plist>
EOF

sign_item() {
  codesign --force --timestamp=none --generate-entitlement-der "${SIGN_ARGS[@]}" "$1"
}

while IFS= read -r -d '' item; do
  sign_item "$item"
done < <(find "$APP" -depth \( -name '*.framework' -o -name '*.dylib' -o -name '*.appex' \) -print0)

codesign --force --timestamp=none --generate-entitlement-der \
  --entitlements "$TMP/entitlements.plist" "${SIGN_ARGS[@]}" "$APP"
codesign --verify --verbose=2 "$APP"

mkdir -p "$TMP/Payload"
cp -R "$APP" "$TMP/Payload/"
rm -f "$OUT"
(
  cd "$TMP"
  zip -qry -y "$OUT" Payload
)
echo "已打包: $OUT"
