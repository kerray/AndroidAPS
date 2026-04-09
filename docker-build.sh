#!/bin/bash
# Build AndroidAPS APK using Docker
# Run this on a machine with enough RAM (needs ~4-6GB for Gradle)
#
# Usage: ./docker-build.sh [keystore_path] [output_dir]
#
# Environment variables:
#   KEYSTORE_PASSWORD - required

set -e

KEYSTORE_PATH="${1:-./keystore.jks}"
OUTPUT_DIR="${2:-./output}"
IMAGE_NAME="androidaps-builder"

if [ -z "$KEYSTORE_PASSWORD" ]; then
    echo "ERROR: KEYSTORE_PASSWORD environment variable is not set"
    exit 1
fi

if [ ! -f "$KEYSTORE_PATH" ]; then
    echo "ERROR: Keystore not found at $KEYSTORE_PATH"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

echo "=== Building AndroidAPS Docker image ==="
docker build -t "$IMAGE_NAME" .

echo "=== Signing APK ==="
docker run --rm \
    -v "$(realpath "$KEYSTORE_PATH")":/keystore.jks:ro \
    -v "$(realpath "$OUTPUT_DIR")":/output \
    -e KEYSTORE_PASSWORD="$KEYSTORE_PASSWORD" \
    "$IMAGE_NAME"

echo ""
echo "=== APK available at: $OUTPUT_DIR/app-full-release-signed.apk ==="
