# AndroidAPS Build and Signing Guide

## Prerequisites

- Java Development Kit (JDK) 21+
- Android SDK with Build Tools
- Android NDK r25b+
- `ANDROID_HOME` environment variable pointing to your SDK

## Quick Build

```bash
# Set your keystore password
export KEYSTORE_PASSWORD=<your_password>

# Run the build script
./build-and-sign.sh
```

## Manual Build Steps

### 1. Build the APK

```bash
./gradlew :app:assembleFullRelease
```

Output: `app/build/outputs/apk/full/release/app-full-release-unsigned.apk`

### 2. Align the APK

```bash
$ANDROID_HOME/build-tools/<version>/zipalign -v -p 4 \
  app/build/outputs/apk/full/release/app-full-release-unsigned.apk \
  app-full-release-unsigned-aligned.apk
```

### 3. Sign the APK

```bash
$ANDROID_HOME/build-tools/<version>/apksigner sign \
  --ks keystore.jks \
  --ks-pass pass:$KEYSTORE_PASSWORD \
  --out app-full-release-signed.apk \
  app-full-release-unsigned-aligned.apk
```

### 4. Verify (optional)

```bash
$ANDROID_HOME/build-tools/<version>/apksigner verify --verbose app-full-release-signed.apk
```

## Troubleshooting

### Missing SDK Components

```bash
sdkmanager "build-tools;34.0.0" "platform-tools" "platforms;android-34"
sdkmanager --licenses
```

### Memory Issues

Edit `gradle.properties` to reduce memory usage:

```properties
org.gradle.parallel=false
org.gradle.workers.max=1
org.gradle.jvmargs=-Xmx1536m -XX:+UseSerialGC
org.gradle.daemon=false
kotlin.incremental=false
```
