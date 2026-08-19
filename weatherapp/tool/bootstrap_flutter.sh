#!/usr/bin/env bash
set -euo pipefail

# Installs the Linux/Web toolchain used by WeatherApp and prepares this project.
# Override FLUTTER_HOME when Flutter should live somewhere else.
FLUTTER_HOME="${FLUTTER_HOME:-$HOME/development/flutter}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ "${EUID}" -eq 0 ]]; then
  APT=(apt-get)
elif command -v sudo >/dev/null 2>&1; then
  APT=(sudo apt-get)
else
  echo "오류: 패키지 설치를 위해 root 권한 또는 sudo가 필요합니다." >&2
  exit 1
fi

echo "[1/5] Flutter와 Linux 데스크톱 빌드에 필요한 패키지를 설치합니다."
"${APT[@]}" update
"${APT[@]}" install -y \
  clang cmake curl git libgtk-3-dev liblzma-dev libstdc++-12-dev \
  ninja-build pkg-config unzip xz-utils zip

if [[ ! -x "$FLUTTER_HOME/bin/flutter" ]]; then
  echo "[2/5] 최신 stable Flutter SDK 정보를 확인합니다."
  release_json="$(mktemp)"
  archive="$(mktemp --suffix=.tar.xz)"
  trap 'rm -f "$release_json" "$archive"' EXIT
  curl --fail --location --retry 3 \
    https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json \
    --output "$release_json"

  readarray -t release < <(python3 - "$release_json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as file:
    releases = json.load(file)

stable_hash = releases["current_release"]["stable"]
stable = next(item for item in releases["releases"] if item["hash"] == stable_hash)
print(f'{releases["base_url"]}/{stable["archive"]}')
print(stable["sha256"])
PY
  )

  echo "[3/5] Flutter SDK를 내려받고 검증합니다."
  curl --fail --location --retry 3 "${release[0]}" --output "$archive"
  echo "${release[1]}  $archive" | sha256sum --check --status

  mkdir -p "$(dirname "$FLUTTER_HOME")"
  rm -rf "$FLUTTER_HOME"
  # Release archives may contain the publisher's numeric uid/gid. Keeping those
  # owners makes Git reject the SDK as an unsafe repository in root containers.
  tar --extract --xz --no-same-owner --file "$archive" \
    --directory "$(dirname "$FLUTTER_HOME")"
else
  echo "[2/5] 기존 Flutter SDK를 사용합니다: $FLUTTER_HOME"
  echo "[3/5] SDK 다운로드를 건너뜁니다."
fi

export PATH="$FLUTTER_HOME/bin:$PATH"

echo "[4/5] Flutter 플랫폼을 설정합니다."
flutter config --enable-web --enable-linux-desktop
flutter precache --web --linux

echo "[5/5] 프로젝트 의존성을 설치하고 개발 환경을 검사합니다."
cd "$PROJECT_ROOT"
flutter pub get
flutter doctor -v

cat <<EOF

설치가 완료되었습니다. 새 터미널에서도 Flutter를 사용하려면 다음 줄을
셸 설정 파일(~/.bashrc 또는 ~/.zshrc)에 추가하세요.

  export PATH="$FLUTTER_HOME/bin:\$PATH"

앱 실행: cd "$PROJECT_ROOT" && flutter run -d linux
웹 실행: cd "$PROJECT_ROOT" && flutter run -d web-server
EOF
