# AAPS 4.x build image: JDK 21, compileSdk 37. Build context = AndroidAPS checkout (stable tag only).
FROM eclipse-temurin:21-jdk
RUN apt-get update && apt-get install -y --no-install-recommends unzip wget git && rm -rf /var/lib/apt/lists/*
ENV ANDROID_HOME=/opt/android-sdk
ENV PATH="${ANDROID_HOME}/cmdline-tools/latest/bin:${PATH}"
RUN mkdir -p ${ANDROID_HOME}/cmdline-tools && \
    wget -q https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O /tmp/c.zip && \
    unzip -q /tmp/c.zip -d ${ANDROID_HOME}/cmdline-tools && mv ${ANDROID_HOME}/cmdline-tools/cmdline-tools ${ANDROID_HOME}/cmdline-tools/latest && rm /tmp/c.zip
# The API 37 platform package is "platforms;android-37.0" (minor-versioned names since 36.1);
# "platforms;android-37" does not exist. Newest build-tools are symlinked to $ANDROID_HOME/bt
# so zipalign/apksigner are on PATH regardless of version.
RUN yes | sdkmanager --licenses >/dev/null 2>&1; set -e; \
    BT=$(sdkmanager --list 2>/dev/null | grep -oE 'build-tools;[0-9]+\.[0-9]+\.[0-9]+ ' | sort -V | tail -1 | tr -d ' '); echo "BT=$BT"; \
    sdkmanager "$BT" "platform-tools" "platforms;android-37.0" >/dev/null; \
    ln -s ${ANDROID_HOME}/build-tools/$(ls ${ANDROID_HOME}/build-tools | sort -V | tail -1) ${ANDROID_HOME}/bt
ENV PATH="${ANDROID_HOME}/bt:${PATH}"
WORKDIR /build
COPY . .
RUN git checkout -- . 2>/dev/null; git clean -fd 2>/dev/null; git status --short | head
ENV GRADLE_OPTS="-Xmx6g -Dorg.gradle.daemon=false"
RUN ./gradlew :app:assembleFullRelease --no-daemon --stacktrace
# Signing happens at run time so the keystore never enters an image layer.
# Mounts: /keystore.jks (ro), /keystore-password (ro, first line = password), /output.
# OUT_NAME sets the output file name; the old APK is printed for certificate comparison.
ENV OUT_NAME=aaps-full-release-signed.apk
ENTRYPOINT ["/bin/bash","-c","set -e; APK=$(ls /build/app/build/outputs/apk/full/release/*.apk | head -1); zipalign -f -p 4 $APK /tmp/aligned.apk; apksigner sign --ks /keystore.jks --ks-pass file:/keystore-password --out /output/$OUT_NAME /tmp/aligned.apk; echo \"== $OUT_NAME\"; apksigner verify --print-certs /output/$OUT_NAME; if [ -f /output/app-full-release-signed.apk ]; then echo '== app-full-release-signed.apk (previous)'; apksigner verify --print-certs /output/app-full-release-signed.apk; fi"]
