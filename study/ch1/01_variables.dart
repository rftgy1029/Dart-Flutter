// 1장 - 1강: 변수, 타입, null safety
// 실행: dart run study/ch1/01_variables.dart

void main() {
  // ── 1. var / final / const ─────────────────────────
  var count = 1; // 타입 추론(int). 나중에 값 변경 가능
  count = 2;

  final city = 'Seoul'; // 한 번만 대입. 실행 중에 값이 정해져도 OK
  // city = 'Busan';    // ❌ 에러: final은 다시 대입 불가

  const pi = 3.14; // 컴파일 시점에 값이 확정돼야 함
  final now = DateTime.now(); // ✅ final은 OK
  // const now2 = DateTime.now(); // ❌ 에러: 실행해봐야 아는 값

  print('count=$count, city=$city, pi=$pi, now=$now');

  // ── 2. 기본 타입 ───────────────────────────────────
  int age = 25;
  double temp = 18.5;
  String name = '찬영';
  bool isRaining = false;
  List<String> cities = ['Seoul', 'Busan'];
  Map<String, int> population = {'Seoul': 940, 'Busan': 330};

  print('$name($age) / 기온 ${temp}도 / 비: $isRaining');
  print('도시 수: ${cities.length}, 서울 인구: ${population['Seoul']}만');

  // ── 3. null safety ────────────────────────────────
  String? nickname; // ?가 붙으면 null 가능 (기본값 null)
  print('닉네임: $nickname');

  // nickname.length;        // ❌ 에러: null일 수도 있어서 막힘
  print(nickname?.length);   // ?.  null이면 null 반환
  print(nickname ?? '없음'); // ??  null이면 오른쪽 값 사용

  nickname = 'chan';
  print(nickname.length); // ✅ 위에서 값을 넣었으니 Dart가 non-null로 인식

  // if로 null 체크하면 그 안에서는 non-null로 취급 (타입 승격)
  String? input = getInput();
  if (input != null) {
    print('입력 길이: ${input.length}');
  }

  // !  "절대 null 아님"을 개발자가 보장 → 틀리면 런타임 에러. 최대한 피하기
  // print(getInput()!.length);
}

String? getInput() => null;
