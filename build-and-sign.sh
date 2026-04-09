#!/bin/bash
# AndroidAPS Build and Sign Script
# This script automates the process of building, aligning, and signing the AndroidAPS APK
#
# Required environment variables:
#   KEYSTORE_PASSWORD - password for the keystore
#   KEYSTORE_PATH     - path to keystore.jks (default: ./keystore.jks)
#   BUILD_TOOLS_PATH  - path to Android SDK build-tools (default: auto-detect)

set -e

# Configuration
KEYSTORE_PATH="${KEYSTORE_PATH:-./keystore.jks}"
BUILD_TOOLS_PATH="${BUILD_TOOLS_PATH:-$(ls -d $ANDROID_HOME/build-tools/*/ 2>/dev/null | sort -V | tail -1)}"

if [ -z "$KEYSTORE_PASSWORD" ]; then
    echo "ERROR: KEYSTORE_PASSWORD environment variable is not set"
    echo "Usage: KEYSTORE_PASSWORD=your_password ./build-and-sign.sh"
    exit 1
fi

if [ -z "$BUILD_TOOLS_PATH" ]; then
    echo "ERROR: BUILD_TOOLS_PATH not set and could not auto-detect from ANDROID_HOME"
    exit 1
fi

if [ ! -f "$KEYSTORE_PATH" ]; then
    echo "ERROR: Keystore not found at $KEYSTORE_PATH"
    exit 1
fi

# Step 1: Build the APK
echo "Building APK..."
./gradlew :app:assembleFullRelease

# Step 2: Align the APK
echo "Aligning APK..."
INPUT_APK="app/build/outputs/apk/full/release/app-full-release-unsigned.apk"
ALIGNED_APK="app-full-release-unsigned-aligned.apk"
${BUILD_TOOLS_PATH}/zipalign -v -p 4 ${INPUT_APK} ${ALIGNED_APK}

# Step 3: Sign the APK
echo "Signing APK..."
SIGNED_APK="app-full-release-signed.apk"
${BUILD_TOOLS_PATH}/apksigner sign --ks ${KEYSTORE_PATH} --ks-pass pass:${KEYSTORE_PASSWORD} --out ${SIGNED_APK} ${ALIGNED_APK}

# Step 4: Verify the signature
echo "Verifying signature..."
${BUILD_TOOLS_PATH}/apksigner verify --verbose ${SIGNED_APK}

echo ""
echo "Build and sign process completed successfully!"
echo "Signed APK: ${SIGNED_APK}"
