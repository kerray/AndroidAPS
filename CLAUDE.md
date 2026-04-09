# CLAUDE.md - AndroidAPS (kerray fork)

Personal fork of [nightscout/AndroidAPS](https://github.com/nightscout/AndroidAPS) for building custom APKs.

## What this fork adds

- `build-and-sign.sh` — automated build, align, sign pipeline
- `CLAUDE.md` — this file
- Memory-tuned `gradle.properties` for resource-constrained builds

## Building

### Prerequisites
- JDK 21+ (project has moved to newer Kotlin/AGP)
- Android SDK with build-tools
- Android NDK r25b+ (for native components)
- `ANDROID_HOME` environment variable set

### Environment variables (secrets)
```
KEYSTORE_PASSWORD  — keystore password for APK signing
KEYSTORE_PATH      — path to keystore.jks (default: ./keystore.jks)
BUILD_TOOLS_PATH   — path to build-tools dir (auto-detected from ANDROID_HOME)
```

### Build command
```bash
KEYSTORE_PASSWORD=<password> ./build-and-sign.sh
```

Or manually:
```bash
./gradlew :app:assembleFullRelease
```

### Memory considerations
- Full build needs ~4-6GB heap. Default `gradle.properties` uses `-Xmx2g`.
- For machines with limited RAM, reduce parallel workers:
  ```properties
  org.gradle.parallel=false
  org.gradle.workers.max=1
  org.gradle.jvmargs=-Xmx1536m -XX:+UseSerialGC
  org.gradle.daemon=false
  kotlin.incremental=false
  ```

## Upstream sync
```bash
git remote add upstream https://github.com/nightscout/AndroidAPS.git
git fetch upstream master
git merge upstream/master
```

## Secrets — DO NOT COMMIT
- `keystore.jks` — APK signing keystore
- Keystore password — pass via `KEYSTORE_PASSWORD` env var
- These should be stored in Coder workspace secrets, CI secrets, or locally
