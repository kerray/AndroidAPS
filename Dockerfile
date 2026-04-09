FROM eclipse-temurin:17-jdk

# Install required tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    unzip wget git \
    && rm -rf /var/lib/apt/lists/*

# Android SDK setup
ENV ANDROID_HOME=/opt/android-sdk
ENV PATH="${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/build-tools/34.0.0:${PATH}"

RUN mkdir -p ${ANDROID_HOME}/cmdline-tools && \
    wget -q https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O /tmp/cmdline-tools.zip && \
    unzip -q /tmp/cmdline-tools.zip -d ${ANDROID_HOME}/cmdline-tools && \
    mv ${ANDROID_HOME}/cmdline-tools/cmdline-tools ${ANDROID_HOME}/cmdline-tools/latest && \
    rm /tmp/cmdline-tools.zip

RUN yes | sdkmanager --licenses > /dev/null 2>&1 && \
    sdkmanager "build-tools;34.0.0" "platform-tools" "platforms;android-34"

# Android NDK
RUN wget -q https://dl.google.com/android/repository/android-ndk-r25b-linux.zip -O /tmp/ndk.zip && \
    unzip -q /tmp/ndk.zip -d ${ANDROID_HOME} && \
    rm /tmp/ndk.zip
ENV ANDROID_NDK_HOME=${ANDROID_HOME}/android-ndk-r25b

WORKDIR /build

# Copy source and build
COPY . .
ARG GRADLE_OPTS="-Xmx4g"
RUN ./gradlew :app:assembleFullRelease --no-daemon

# At runtime: align, sign, and copy to /output
# Mount keystore and output dir when running
ENTRYPOINT ["/bin/bash", "-c", "\
    set -e && \
    APK=/build/app/build/outputs/apk/full/release/app-full-release-unsigned.apk && \
    zipalign -v -p 4 $APK /tmp/aligned.apk && \
    apksigner sign --ks /keystore.jks --ks-pass pass:${KEYSTORE_PASSWORD} --out /output/app-full-release-signed.apk /tmp/aligned.apk && \
    apksigner verify --verbose /output/app-full-release-signed.apk && \
    echo 'Done! Signed APK at /output/app-full-release-signed.apk' \
"]
