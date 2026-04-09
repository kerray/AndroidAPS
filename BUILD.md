# AndroidAPS Build and Signing Guide

## Docker Build (recommended)

The easiest way to build. All dependencies (JDK, SDK, NDK) are handled by the Docker image.

```bash
# 1. Build the Docker image (first run downloads ~3GB of SDK/NDK, subsequent builds use cache)
docker build --build-arg GRADLE_OPTS="-Xmx6g" -t androidaps-builder .

# 2. Sign the APK (mount keystore + output dir)
mkdir -p ./output
KEYSTORE_PASSWORD=<password> docker run --rm \
  -v "$(pwd)/keystore.jks":/keystore.jks:ro \
  -v "$(pwd)/output":/output \
  -e KEYSTORE_PASSWORD \
  androidaps-builder

# 3. Verify
ls -lh ./output/app-full-release-signed.apk
```

Or use the wrapper script: `KEYSTORE_PASSWORD=<password> ./docker-build.sh`

### How it works

- `docker build` creates an image with JDK 21, Android SDK 34, NDK r25b, and runs `./gradlew :app:assembleFullRelease` — the unsigned APK is baked into the image
- `docker run` mounts the keystore read-only, runs `zipalign` + `apksigner`, outputs the signed APK to `./output/`
- The keystore never enters the Docker image
- `.git` is included in the Docker context (needed for version info in the app UI)

### Memory tuning

Default Gradle heap is 4GB. Adjust with `--build-arg`:

```bash
docker build --build-arg GRADLE_OPTS="-Xmx3g" -t androidaps-builder .  # less RAM
docker build --build-arg GRADLE_OPTS="-Xmx6g" -t androidaps-builder .  # more RAM (faster)
```

## Manual Build (non-Docker)

### Prerequisites

- Java Development Kit (JDK) 21+
- Android SDK with Build Tools 34
- Android NDK r25b+
- `ANDROID_HOME` environment variable pointing to your SDK

### Quick Build

```bash
export KEYSTORE_PASSWORD=<your_password>
./build-and-sign.sh
```

### Manual Build Steps

#### 1. Build the APK

```bash
./gradlew :app:assembleFullRelease
```

Output: `app/build/outputs/apk/full/release/app-full-release-unsigned.apk`

#### 2. Align the APK

```bash
$ANDROID_HOME/build-tools/34.0.0/zipalign -v -p 4 \
  app/build/outputs/apk/full/release/app-full-release-unsigned.apk \
  app-full-release-unsigned-aligned.apk
```

#### 3. Sign the APK

```bash
$ANDROID_HOME/build-tools/34.0.0/apksigner sign \
  --ks keystore.jks \
  --ks-pass pass:$KEYSTORE_PASSWORD \
  --out app-full-release-signed.apk \
  app-full-release-unsigned-aligned.apk
```

#### 4. Verify (optional)

```bash
$ANDROID_HOME/build-tools/34.0.0/apksigner verify --verbose app-full-release-signed.apk
```

## Troubleshooting

### Missing SDK Components

```bash
sdkmanager "build-tools;34.0.0" "platform-tools" "platforms;android-34"
sdkmanager --licenses
```

### Memory Issues (non-Docker)

Edit `gradle.properties` to reduce memory usage:

```properties
org.gradle.parallel=false
org.gradle.workers.max=1
org.gradle.jvmargs=-Xmx1536m -XX:+UseSerialGC
org.gradle.daemon=false
kotlin.incremental=false
```

### "uncommitted changes" error in Docker build

The Dockerfile includes `git checkout -- . && git clean -fd` after `COPY` to ensure a clean
working tree. If this fails, check that `.dockerignore` is not excluding `.git`.

### "invalid source release: 21"

The project requires JDK 21. The Dockerfile uses `eclipse-temurin:21-jdk`. For non-Docker
builds, ensure `java -version` shows 21+.
