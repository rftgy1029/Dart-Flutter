#!/bin/bash
# Installs the Flutter SDK (bundles Dart) and fetches pub dependencies so
# `flutter analyze`, `flutter test`, and `dart test` work in Claude Code cloud sessions.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

# Pinned so pubspec.lock stays stable between sessions. Bump both together.
FLUTTER_VERSION="3.47.6"
FLUTTER_SHA256="f1631b9c2c8b3529323db412b0d1beacf4a748f8783b0d7cf599a8fd5f461675"
FLUTTER_HOME="${FLUTTER_HOME:-$HOME/development/flutter}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

installed_version() {
  python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["frameworkVersion"])' \
    "$FLUTTER_HOME/bin/cache/flutter.version.json" 2>/dev/null || true
}

if [ ! -x "$FLUTTER_HOME/bin/flutter" ] || [ "$(installed_version)" != "$FLUTTER_VERSION" ]; then
  echo "Installing Flutter $FLUTTER_VERSION into $FLUTTER_HOME" >&2
  archive="$(mktemp --suffix=.tar.xz)"
  trap 'rm -f "$archive"' EXIT
  curl --fail --silent --show-error --location --retry 3 \
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
    --output "$archive"
  echo "$FLUTTER_SHA256  $archive" | sha256sum --check --status
  rm -rf "$FLUTTER_HOME"
  mkdir -p "$(dirname "$FLUTTER_HOME")"
  tar --extract --xz --file "$archive" --directory "$(dirname "$FLUTTER_HOME")"
fi

export PATH="$FLUTTER_HOME/bin:$PATH"
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PATH=\"$FLUTTER_HOME/bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"
fi

# The SDK tarball is owned by a different uid; git refuses to read it otherwise.
git config --global --get-all safe.directory | grep -qxF "$FLUTTER_HOME" \
  || git config --global --add safe.directory "$FLUTTER_HOME"

flutter --disable-analytics >/dev/null 2>&1 || true
flutter --version >&2

(cd "$PROJECT_DIR/weatherapp" && flutter pub get)
(cd "$PROJECT_DIR/cli" && dart pub get)
(cd "$PROJECT_DIR/cli/command_runner" && dart pub get)
