#!/bin/bash
# Build and sign AndroidAPS from a clean upstream release tag using Docker.
# Run this on a machine with enough RAM (needs ~6-8GB for Gradle) and ~10GB free disk.
#
# Usage: ./docker-build.sh <tag> [keystore_path] [password_file] [output_dir]
#   e.g. ./docker-build.sh 4.0.0
#
# The password file holds the keystore password on its first line; it is mounted
# read-only into the container, so the password never appears in argv or env.
#
# Only build stable release tags - this app doses insulin. Never dev/nightly.

set -e

TAG="${1:?usage: $0 <tag> [keystore_path] [password_file] [output_dir]}"
KEYSTORE_PATH="${2:-./keystore.jks}"
PASSWORD_FILE="${3:-./.keystore-password}"
OUTPUT_DIR="${4:-./output}"
UPSTREAM="https://github.com/nightscout/AndroidAPS.git"
IMAGE_NAME="aaps:${TAG}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ ! -f "$KEYSTORE_PATH" ]; then
    echo "ERROR: Keystore not found at $KEYSTORE_PATH"
    exit 1
fi

if [ ! -f "$PASSWORD_FILE" ]; then
    echo "ERROR: Keystore password file not found at $PASSWORD_FILE"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

SRC="$(mktemp -d)"
trap 'rm -rf "$SRC"' EXIT

echo "=== Cloning upstream tag $TAG ==="
git clone --depth 1 --branch "$TAG" "$UPSTREAM" "$SRC"

echo "=== Building AndroidAPS Docker image ==="
docker build -f "$SCRIPT_DIR/Dockerfile" -t "$IMAGE_NAME" "$SRC"

echo "=== Signing APK ==="
docker run --rm \
    -v "$(realpath "$KEYSTORE_PATH")":/keystore.jks:ro \
    -v "$(realpath "$PASSWORD_FILE")":/keystore-password:ro \
    -v "$(realpath "$OUTPUT_DIR")":/output \
    -e OUT_NAME="aaps-${TAG}-full-signed.apk" \
    "$IMAGE_NAME"

echo ""
echo "=== APK available at: $OUTPUT_DIR/aaps-${TAG}-full-signed.apk ==="
echo "=== Compare the certificate SHA-256 above with the previous APK before installing ==="
