#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
APP_NAME="Touchy"
APP_DISPLAY_NAME="Touchy"
BUILD_DIR="${PROJECT_DIR}/.build"
MODULE_CACHE_DIR="${BUILD_DIR}/module-cache"
DIST_DIR="${PROJECT_DIR}/dist"
APP_DIR="${DIST_DIR}/${APP_DISPLAY_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
INFO_PLIST_SOURCE="${PROJECT_DIR}/AppBundle/Info.plist"
RESOURCES_SOURCE="${PROJECT_DIR}/AppBundle/Resources"
EXECUTABLE_PATH="${BUILD_DIR}/release/${APP_NAME}"
ICON_SCRIPT="${SCRIPT_DIR}/generate-icon.swift"

cd "${PROJECT_DIR}"

echo "Building ${APP_NAME} in release mode..."
mkdir -p "${MODULE_CACHE_DIR}/clang" "${MODULE_CACHE_DIR}/swift"
env CLANG_MODULE_CACHE_PATH="${MODULE_CACHE_DIR}/clang" \
    SWIFT_MODULECACHE_PATH="${MODULE_CACHE_DIR}/swift" \
    swift build -c release

if [[ ! -x "${EXECUTABLE_PATH}" ]]; then
  echo "Expected executable not found at ${EXECUTABLE_PATH}" >&2
  exit 1
fi

echo "Generating app icon..."
mkdir -p "${RESOURCES_SOURCE}"
env CLANG_MODULE_CACHE_PATH="${MODULE_CACHE_DIR}/clang" \
    SWIFT_MODULECACHE_PATH="${MODULE_CACHE_DIR}/swift" \
    swift "${ICON_SCRIPT}" "${RESOURCES_SOURCE}/Touchy.icns"

echo "Creating app bundle at ${APP_DIR}..."
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

cp "${INFO_PLIST_SOURCE}" "${CONTENTS_DIR}/Info.plist"
cp "${EXECUTABLE_PATH}" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"

if [[ -n "${TOUCHY_VERSION:-}" ]]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${TOUCHY_VERSION}" "${CONTENTS_DIR}/Info.plist"
fi

if [[ -n "${TOUCHY_BUILD_NUMBER:-}" ]]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${TOUCHY_BUILD_NUMBER}" "${CONTENTS_DIR}/Info.plist"
fi

if [[ -d "${RESOURCES_SOURCE}" ]]; then
  cp -R "${RESOURCES_SOURCE}/." "${RESOURCES_DIR}/"
fi

echo "Signing app bundle with a stable bundle identifier..."
codesign --force --deep --sign - --identifier io.github.touchy-app.touchy "${APP_DIR}"

echo "Created ${APP_DIR}"
