#!/usr/bin/env bash
set -e

APP_NAME="Flow"
BUNDLE_NAME="${APP_NAME}.app"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
APP_DIR="${BUILD_DIR}/${BUNDLE_NAME}"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "=== Building ${APP_NAME} for macOS (Release) ==="
cd "${PROJECT_DIR}"
swift build -c release --disable-sandbox

echo "=== Packaging ${BUNDLE_NAME} ==="
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Copy binary
cp ".build/release/FlowApp" "${MACOS_DIR}/FlowApp"
chmod +x "${MACOS_DIR}/FlowApp"

# Copy Info.plist
cp "Resources/Info.plist" "${CONTENTS_DIR}/Info.plist"

# Generate Icon
echo "=== Generating Application Icon ==="
swift "Resources/generate_icon.swift"
python3 "Resources/make_icns.py" "/tmp/Flow.iconset" "${RESOURCES_DIR}/AppIcon.icns"
cp "${RESOURCES_DIR}/AppIcon.icns" "Resources/AppIcon.icns"
rm -rf "/tmp/Flow.iconset"

# Code-sign ad-hoc
echo "=== Code-signing Application ==="
codesign --force --deep --sign - "${APP_DIR}"

echo "=========================================================="
echo "✨ Success! ${BUNDLE_NAME} built at: ${APP_DIR}"
echo "To run Flow, execute: open \"${APP_DIR}\""
echo "=========================================================="
