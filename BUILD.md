# AndroidAPS Build and Signing Guide

AndroidAPS doses insulin. **Build stable upstream release tags only** — never dev/nightly
without an explicit decision.

## Docker Build (recommended)

All dependencies (JDK 21, Android SDK) are handled by the Docker image. The build context is a
**clean clone of an upstream release tag**; the `Dockerfile` from this branch is passed with `-f`,
so nothing from this fork ends up in the APK.

```bash
# One step (clone tag, build image, sign):
./docker-build.sh 4.0.0 /opt/androidaps/keystore.jks /opt/androidaps/.keystore-password /opt/androidaps/output
```

Or by hand:

```bash
# 1. Clean source of the release tag
git clone --depth 1 --branch 4.0.0 https://github.com/nightscout/AndroidAPS.git /tmp/aaps-src

# 2. Build the image (SDK download + Gradle; ~8 min on aretea, cached SDK layers afterwards)
docker build -f Dockerfile -t aaps:4.0.0 /tmp/aaps-src

# 3. Sign the APK (keystore, password file and output dir are mounted at run time)
docker run --rm \
  -v /opt/androidaps/keystore.jks:/keystore.jks:ro \
  -v /opt/androidaps/.keystore-password:/keystore-password:ro \
  -v /opt/androidaps/output:/output \
  -e OUT_NAME=aaps-4.0.0-full-signed.apk \
  aaps:4.0.0
```

Output: `/opt/androidaps/output/aaps-4.0.0-full-signed.apk`

### Verify before installing (mandatory)

The sign step prints the certificate of the new APK and, if present in the output dir, of the
previous `app-full-release-signed.apk`. The **certificate SHA-256 digest must be identical**:

```
66e96293661de47fbe106a455962512406116b8a85c60689bf3267b7f41705e9
```

If it differs, do not install or upload the APK — Android would refuse the update, and it
means the wrong keystore was used.

### How it works

- `docker build` creates an image with JDK 21, the Android SDK (platform `android-37.0`, newest
  build-tools) and runs `./gradlew :app:assembleFullRelease` — the unsigned APK is baked into the image
- `docker run` mounts the keystore and the password file read-only, runs `zipalign` + `apksigner`
  (`--ks-pass file:`), and writes the signed APK to the mounted output dir
- The keystore and its password never enter the Docker image, argv or environment
- `.git` is part of the build context (needed for version info in the app UI)
- No NDK is needed

### Memory and disk

Gradle heap is 6GB (`GRADLE_OPTS` in the `Dockerfile`). The image is ~6GB and the build cache
grows by several GB; check free disk on the build host first (`df -h /var/lib/docker`).

## Manual Build (non-Docker)

### Prerequisites

- Java Development Kit (JDK) 21
- Android SDK with platform `android-37.0` and current build-tools
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
BT=$(ls -d $ANDROID_HOME/build-tools/*/ | sort -V | tail -1)
${BT}zipalign -p 4 \
  app/build/outputs/apk/full/release/app-full-release-unsigned.apk \
  app-full-release-unsigned-aligned.apk
```

#### 3. Sign the APK

```bash
${BT}apksigner sign \
  --ks keystore.jks \
  --ks-pass file:.keystore-password \
  --out app-full-release-signed.apk \
  app-full-release-unsigned-aligned.apk
```

#### 4. Verify

```bash
${BT}apksigner verify --print-certs app-full-release-signed.apk
```

## Installing on the phone (Xiaomi / HyperOS)

Download the APK from the private Garage bucket (presigned URL) and open it. On the Xiaomi 15
Ultra with HyperOS 3.0 the system installer shows the "update?" dialog and then fails with a bare
"App not installed" — the APK is fine, the HyperOS installer blocks the sideload. Install it with
adb instead (`pm install -r` keeps app data and settings):

```bash
# Phone: Developer options → Wireless debugging → "Pair device with pairing code" (first time only)
adb pair <ip>:<pair-port> <code>
# Then connect with the ip:port from the Wireless debugging main screen (the port changes every time)
adb connect <ip>:<port>
adb shell 'cp /sdcard/Download/aaps-4.0.0-full-signed.apk /data/local/tmp/aaps.apk && pm install -r --user 0 /data/local/tmp/aaps.apk; rm -f /data/local/tmp/aaps.apk'
adb shell 'dumpsys package info.nightscout.androidaps | grep -E "versionName|lastUpdateTime"'
```

Before installing: export settings in AAPS (Maintenance → Export settings; the file lands in
`/sdcard/AAPS/preferences/`) and check the file is fresh with
`adb shell ls -lat /sdcard/AAPS/preferences/ | head -3`. Afterwards open the app and check the
version, pump/CGM connection and the loop status. `pm install` prints the exact
`INSTALL_FAILED_*` reason if anything is wrong, which the HyperOS installer never does.

## Troubleshooting

### `Failed to find package 'platforms;android-37'`

Since API 36.1 the platform packages carry a minor version: the package for `compileSdk = 37` is
`platforms;android-37.0`. Check the exact names with `sdkmanager --list | grep platforms`.

### Missing SDK Components

```bash
sdkmanager --licenses
sdkmanager "platform-tools" "platforms;android-37.0" "build-tools;37.0.0"
```

### "uncommitted changes" error in Docker build

The Dockerfile runs `git checkout -- .` and `git clean -fd` after `COPY` to ensure a clean
working tree. If this fails, check that `.git` is part of the build context.

### "invalid source release: 21"

The project requires JDK 21. The Dockerfile uses `eclipse-temurin:21-jdk`. For non-Docker
builds, ensure `java -version` shows 21.
