# CLAUDE.md - AndroidAPS (kerray fork)

Personal fork of [nightscout/AndroidAPS](https://github.com/nightscout/AndroidAPS) for building custom APKs.

## What this fork adds

- `Dockerfile` — complete Android build environment (JDK 21, SDK 34, NDK r25b), builds unsigned APK during `docker build`, signs at `docker run`
- `docker-build.sh` — convenience wrapper for the Docker workflow
- `build-and-sign.sh` — non-Docker build alternative (requires local JDK/SDK/NDK)
- `.dockerignore` — keeps secrets and build artifacts out of Docker context (but includes .git for version info)
- `CLAUDE.md` — this file
- `BUILD.md` — detailed build instructions

## Building (Docker — recommended)

The Docker workflow is the primary build method. It handles all dependencies automatically.

### Prerequisites
- Docker
- `keystore.jks` — APK signing keystore (NOT in git)
- `KEYSTORE_PASSWORD` — keystore password

### Quick build + sign

```bash
# Build the image (downloads SDK/NDK on first run, ~10-20 min)
docker build --build-arg GRADLE_OPTS="-Xmx6g" -t androidaps-builder .

# Sign the APK
mkdir -p ./output
KEYSTORE_PASSWORD=<password> docker run --rm \
  -v "$(pwd)/keystore.jks":/keystore.jks:ro \
  -v "$(pwd)/output":/output \
  -e KEYSTORE_PASSWORD \
  androidaps-builder
```

Output: `./output/app-full-release-signed.apk`

Or use the wrapper: `KEYSTORE_PASSWORD=<password> ./docker-build.sh`

### Memory
- Default Gradle heap: 4GB (`-Xmx4g`). Override with `--build-arg GRADLE_OPTS="-Xmx6g"`
- Build needs ~4-6GB RAM total

### Docker layer caching
SDK/NDK layers (~3GB) are cached. Only the Gradle step re-runs on source changes.

## Building (non-Docker)

See `BUILD.md` for manual build steps. Requires:
- JDK 21+
- Android SDK with build-tools 34
- Android NDK r25b+

## Current build host

The project is currently built on **aretea** (47GB RAM):
- Repo: `/opt/androidaps`
- Keystore: `/opt/androidaps/keystore.jks` (copied from VPS)
- Keystore password: `/opt/androidaps/.keystore-password` (chmod 600)
- Signed APK deployed to: `https://kerray.cz/files/aaps.apk`

## Upstream sync

```bash
git remote add upstream https://github.com/nightscout/AndroidAPS.git
git fetch upstream master
git merge upstream/master
git push origin krr-build
# Then rebuild Docker image + sign
```

## Keystore

The signing keystore (`keystore.jks`, 2084 bytes) is backed up at:
- Unraid: `/mnt/user/backups/AndroidAPS-keystore.jks`
- VPS: `krr@100.64.0.6:/home/krr/AndroidAPS/keystore.jks`

**Never commit the keystore or password to git.**

## Future: CI/CD via GitHub Actions

Plan: Add a GitHub Actions workflow triggered on push to `krr-build` that:
1. Connects to aretea via Tailscale (same pattern as bashkirtseff deploy)
2. SSHes in and runs `docker build` + `docker run` (sign)
3. Deploys the signed APK to kerray.cz

Blocked on: need a mechanism to copy the signed APK from aretea to kerray.cz
(aretea can SSH to the VPS as krr, but krr doesn't have write access to
`/var/www/kerray.cz/web/files/` — owned by web1:client1). Options:
- Grant krr write permission to the files dir (or a subdirectory)
- Use a deploy key/user with appropriate permissions
- SCP via a different user that has write access

Required GitHub secrets (same pattern as bashkirtseff):
- `TAILSCALE_AUTHKEY` — Tailscale auth key for network access
- `HEADSCALE_URL` — Headscale login server URL
- `SSH_PRIVATE_KEY` — SSH key for aretea
- `KEYSTORE_PASSWORD` — APK signing password
