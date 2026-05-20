# WeatherApp Flutter

Flutter로 만든 간단한 날씨 앱입니다. API 키 없이 사용할 수 있는 Open-Meteo 데이터를 사용해서 도시별 현재 날씨, 시간별 예보, 7일 예보를 보여줍니다.

## 지금까지 만든 것

- Flutter 프로젝트 생성: `weatherapp/`
- Open-Meteo 날씨 API 연결
- Open-Meteo 도시 검색 API 연결
- 기본 도시를 서울로 설정
- 도시 검색 후 선택한 지역의 날씨로 화면 변경
- 지역 변경 중 로딩창 표시
- 현재 날씨 카드 구현
- 습도, 바람, 강수량 정보 표시
- 12시간 시간별 예보 표시
- 7일 예보 표시
- Flutter 웹 빌드 확인
- Flutter 정적 분석 통과

## 코딩을 모르는 사람을 위한 설명

이 앱은 사용자가 도시 이름을 검색하면 그 지역의 날씨를 보여주는 앱입니다.

처음 앱을 열면 서울 날씨가 먼저 나옵니다. 검색창에 `Busan`, `Tokyo`, `New York` 같은 도시 이름을 입력하고 검색한 뒤 원하는 지역을 누르면 화면이 해당 지역 날씨로 바뀝니다.

화면에는 이런 정보가 나옵니다.

- 지금 기온
- 체감 온도
- 날씨 상태
- 습도
- 바람 속도
- 강수량
- 앞으로 12시간 예보
- 앞으로 7일 예보

도시를 바꾸는 동안에는 앱이 데이터를 불러오고 있다는 것을 알 수 있도록 로딩창이 표시됩니다.

## 앱 실행 방법

프로젝트 폴더로 이동합니다.

```bash
cd /workspaces/weatherApp-flutter/weatherapp
```

개발용 웹 서버로 실행합니다.

```bash
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080
```

브라우저에서 아래 주소를 엽니다.

```text
http://localhost:8080
```

Codespaces를 사용한다면 VS Code의 `Ports` 탭에서 `8080` 포트를 열면 됩니다.

## flutter 명령어가 안 될 때

터미널에서 `flutter` 명령을 못 찾는다면 아래 명령어를 먼저 실행합니다.

```bash
source ~/.bashrc
flutter --version
```

이 프로젝트에서는 Flutter SDK 경로를 VS Code 설정에도 지정해 두었습니다.

```text
.vscode/settings.json
```

## 개발자를 위한 구조

주요 코드는 `weatherapp/lib/` 아래에 있습니다.

```text
weatherapp/lib/
  main.dart
  models/
    weather_models.dart
  services/
    weather_service.dart
  screens/
    weather_home_page.dart
```

각 파일의 역할은 다음과 같습니다.

- `main.dart`: 앱 시작점, 테마 설정, 첫 화면 연결
- `weather_models.dart`: 도시, 현재 날씨, 시간별 예보, 일별 예보 데이터 모델
- `weather_service.dart`: Open-Meteo API 호출과 응답 파싱
- `weather_home_page.dart`: 검색창, 날씨 화면, 로딩창, 예보 UI

## 사용한 기술

- Flutter
- Dart
- Material 3 UI
- `http` 패키지
- Open-Meteo Forecast API
- Open-Meteo Geocoding API

## 확인한 명령어

정적 분석:

```bash
flutter analyze
```

결과:

```text
No issues found
```

웹 빌드:

```bash
flutter build web
```

결과:

```text
Built build/web
```

## 앞으로 추가하면 좋은 기능

- 현재 위치 기반 날씨
- 즐겨찾기 도시 저장
- 최근 검색 도시 표시
- 날씨 상태별 배경 이미지 또는 애니메이션
- 섭씨/화씨 전환
- 다국어 지원
- 모바일 앱 빌드 설정 정리
