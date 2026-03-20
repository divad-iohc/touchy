#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
DIST_DIR="${PROJECT_DIR}/dist"
APP_NAME="Touchy"
APP_BUNDLE_PATH="${DIST_DIR}/${APP_NAME}.app"
ARCHIVE_BASENAME="${1:-Touchy-macOS}"
ARCHIVE_PATH="${DIST_DIR}/${ARCHIVE_BASENAME}.zip"
CHECKSUM_PATH="${ARCHIVE_PATH}.sha256"

"${SCRIPT_DIR}/make-app.sh"

if [[ ! -d "${APP_BUNDLE_PATH}" ]]; then
  echo "Expected app bundle not found at ${APP_BUNDLE_PATH}" >&2
  exit 1
fi

rm -f "${ARCHIVE_PATH}" "${CHECKSUM_PATH}"

echo "Creating release archive at ${ARCHIVE_PATH}..."
ditto -c -k --sequesterRsrc --keepParent "${APP_BUNDLE_PATH}" "${ARCHIVE_PATH}"

echo "Writing checksum at ${CHECKSUM_PATH}..."
shasum -a 256 "${ARCHIVE_PATH}" > "${CHECKSUM_PATH}"

echo "Created ${ARCHIVE_PATH}"
echo "Created ${CHECKSUM_PATH}"
