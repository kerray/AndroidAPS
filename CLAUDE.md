# CLAUDE.md - AndroidAPS (kerray fork)

Personal fork of [nightscout/AndroidAPS](https://github.com/nightscout/AndroidAPS) for building custom APKs.

**Safety:** AndroidAPS is a closed-loop app that doses insulin. Build stable upstream release
tags only — never dev/nightly without explicit consent. The APK is for personal use and must not
be distributed (no public download links).

## What this fork adds

The `krr-build` branch only carries build tooling and docs. Its source tree is **not** kept in
sync with upstream — the build context is always a clean clone of an upstream release tag
(fork `master` mirrors upstream).

- `Dockerfile` — Android build environment for AAPS 4.x (JDK 21, SDK platform `android-37.0`, newest build-tools), builds the unsigned APK during `docker build`, signs at `docker run`
- `docker-build.sh` — wrapper: clone upstream tag, build, sign
- `build-and-sign.sh` — non-Docker build alternative (requires local JDK/SDK)
- `.dockerignore` — keeps secrets and build artifacts out of the Docker context (but includes .git for version info)
- `CLAUDE.md` — this file
- `BUILD.md` — detailed build instructions

## Building (Docker — recommended)

### Prerequisites
- Docker
- `keystore.jks` — APK signing keystore (NOT in git)
- `.keystore-password` — file with the keystore password on its first line (NOT in git)

### Quick build + sign

```bash
./docker-build.sh 4.0.0 /opt/androidaps/keystore.jks /opt/androidaps/.keystore-password /opt/androidaps/output
```

Output: `/opt/androidaps/output/aaps-4.0.0-full-signed.apk`. See `BUILD.md` for the individual steps.

**Always compare the signing certificate** printed by the sign step with the previous APK
(SHA-256 `66e96293661de47fbe106a455962512406116b8a85c60689bf3267b7f41705e9`). If it differs,
do not upload or install.

### Memory / disk
- Gradle heap: 6GB (`GRADLE_OPTS` in the `Dockerfile`); the 4.0.0 build took ~8 minutes
- Image ~6GB plus build cache — check free disk on the build host first

## Current build host

The project is built on **aretea** (47GB RAM, 12 cores):
- Build tooling checkout: `/opt/androidaps` (this branch)
- Keystore: `/opt/androidaps/keystore.jks`
- Keystore password: `/opt/androidaps/.keystore-password` (root, chmod 600)
- Signed APKs: `/opt/androidaps/output/`

The Coder workspace **`tady`** runs on the same machine and reaches the host Docker daemon via
`sudo docker` (host socket). Builds can be driven from there; bind-mount paths (`-v /opt/androidaps/...`)
are **host** paths, and host files are read with
`sudo docker run --rm -v /opt/androidaps:/x:ro alpine ...`.

## Distribution

Signed APKs go to the **private Garage bucket `aaps`**:
`apk/aaps-<version>-full-signed.apk`. Download via a short-lived presigned URL or the Garage
browser — never a public link.

## Keystore

Signing keystore: `keystore.jks` (JKS, 2084 bytes), one key, alias `key0`, key password = keystore password.

Backups:
- aretea: `/opt/androidaps/keystore.jks` + `.keystore-password`
- Unraid: `/mnt/user/backups/AndroidAPS-keystore.jks`
- VPS: `krr@100.64.0.6:/home/krr/AndroidAPS/keystore.jks`
- Garage (encrypted): bucket `aaps`, `keystore/aaps-keystore-backup-YYYYMMDD.tar.age` — keystore +
  password, encrypted with `age` to the SOPS age recipient (identity: rbw `kerray-infra/sops-age-key`);
  restore instructions in `keystore/README.txt` next to it
- GitHub Actions secrets on `kerray/AndroidAPS` (write-only, for CI): `KEYSTORE_BASE64`,
  `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`

**Never commit the keystore or password to git.**

## CI: upstream browser build (GitHub Actions)

Upstream ships `.github/workflows/aaps-ci.yml` (manual `workflow_dispatch`, pick a release tag).
The four keystore secrets it expects are set on the fork. It additionally requires `GDRIVE_OAUTH2`
(it uploads the APK to Google Drive) — not set yet, so the workflow stops at "Check Secrets"
until that is added. All keystore-using workflows are `workflow_dispatch` only.

## Upstream sync

Fork `master` is fast-forwarded to upstream; `krr-build` does not need merging:

```bash
gh repo sync kerray/AndroidAPS --branch master
```
