#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

command -v flutter >/dev/null 2>&1 || {
  echo 'Flutter SDK را نصب کنید.' >&2
  exit 1
}

echo "Generating temporary Flutter project to obtain Gradle wrapper..."
flutter create --platforms=android --project-name wrapper_seed --org com.example "$TMP/wrapper_seed" >/dev/null

mkdir -p "$ROOT/android/gradle/wrapper"

cp "$TMP/wrapper_seed/android/gradle/wrapper/gradle-wrapper.jar" "$ROOT/android/gradle/wrapper/"
cp "$TMP/wrapper_seed/android/gradlew" "$ROOT/android/gradlew"
cp "$TMP/wrapper_seed/android/gradlew.bat" "$ROOT/android/gradlew.bat"

# Keep existing properties (Gradle 8.7) if present, otherwise copy.
if [ ! -f "$ROOT/android/gradle/wrapper/gradle-wrapper.properties" ]; then
  cp "$TMP/wrapper_seed/android/gradle/wrapper/gradle-wrapper.properties" "$ROOT/android/gradle/wrapper/"
fi

chmod +x "$ROOT/android/gradlew"

echo 'Gradle wrapper آماده شد.'
