#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

CONFIGURATION="${CONFIGURATION:-debug}"
PRODUCT_NAME="SpacesRenamer"
APP_NAME="SpacesRenamer.app"
APP_DIR="${REPO_ROOT}/dist/${APP_NAME}"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
INFO_PLIST_SOURCE="${REPO_ROOT}/packaging/SpacesRenamer-Info.plist"
BUNDLE_IDENTIFIER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${INFO_PLIST_SOURCE}")"

cd "${REPO_ROOT}"

BIN_DIR="$(swift build -c "${CONFIGURATION}" --show-bin-path)"
swift build -c "${CONFIGURATION}"

install -d "${MACOS_DIR}" "${RESOURCES_DIR}"
install -m 755 "${BIN_DIR}/${PRODUCT_NAME}" "${MACOS_DIR}/${PRODUCT_NAME}"
install -m 644 "${INFO_PLIST_SOURCE}" "${CONTENTS_DIR}/Info.plist"

if [[ "${SKIP_CODESIGN:-0}" != "1" ]] && command -v codesign >/dev/null 2>&1; then
    codesign \
        --force \
        --deep \
        --sign - \
        --requirements "=designated => identifier \"${BUNDLE_IDENTIFIER}\"" \
        "${APP_DIR}" >/dev/null
fi

printf 'Packaged %s\n' "${APP_DIR}"
