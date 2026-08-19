# WeatherApp

Open-Meteo를 이용해 현재 날씨와 시간별·주간 예보를 보여 주는 Flutter 앱입니다.
도시 이름을 검색할 수 있고 모바일, 데스크톱, 웹 레이아웃을 지원합니다.

## 주요 기능

- 한국어 도시 검색과 검색 결과 선택
- 현재 온도, 체감 온도, 습도, 풍속 및 강수량
- 앞으로 12시간의 시간별 예보와 7일 예보
- 날씨와 주야간 상태에 따라 달라지는 반응형 화면
- 마지막으로 선택한 도시를 기기에 저장하고 다음 실행 시 자동 복원

## 실행 방법

Ubuntu/Debian 개발 환경에서는 준비 스크립트로 최신 stable Flutter SDK와
Linux 빌드 도구를 한 번에 설치할 수 있습니다.

```sh
./tool/bootstrap_flutter.sh
```

스크립트는 기본적으로 SDK를 `~/development/flutter`에 설치합니다. 다른
경로를 사용하려면 `FLUTTER_HOME=/원하는/경로`를 지정하세요. 설치 후에는
안내에 따라 Flutter 경로를 셸 설정 파일의 `PATH`에 추가해야 합니다.

이미 Flutter SDK가 설치되어 있다면 다음 명령만 실행하세요.

```sh
flutter pub get
flutter run
```

웹 릴리스 빌드는 다음과 같이 만들 수 있습니다.

```sh
flutter build web --release
```

## 품질 검사

```sh
flutter analyze
flutter test
```

별도의 API 키는 필요하지 않습니다. 도시 검색은 Open-Meteo Geocoding API,
날씨 정보는 Open-Meteo Forecast API에서 가져옵니다.

## 앱 아이콘

PR 시스템에서 바이너리 패치를 처리할 수 있도록 저장소에는 PNG/ICO 대신
텍스트 기반 Android Vector Drawable과 SVG 웹 아이콘을 포함합니다. Windows는
운영체제 기본 아이콘을 사용하며, iOS와 macOS의 배포용 아이콘은 Xcode의
`AppIcon` 에셋 카탈로그에서 설정한 뒤 별도 에셋 PR로 관리하세요.
