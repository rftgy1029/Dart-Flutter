// 1장 - 2강: 함수
// 실행: dart run study/ch1/02_functions.dart

void main() {
  // 1. 기본 함수
  print(add(3, 4));

  // 2. 화살표 함수
  print(multiply(6, 7));

  // 3. 이름 있는 매개변수 (named parameter)
  greet(name: '찬영', age: 25);
  greet(age: 25, name: '찬영'); // 순서 바꿔도 OK
  greet(name: '손님'); // age는 선택 → 생략 가능

  // 4. 선택적 위치 매개변수 + 기본값
  print(formatTemp(18.5));
  print(formatTemp(18.5, '°F'));

  // 5. 함수를 값처럼 넘기기 (콜백)
  runTwice(() => print('안녕!'));
  repeat(3, (i) => print('$i번째 실행'));
}

// 1. 기본 형태: 반환타입 이름(매개변수) { ... }
int add(int a, int b) {
  return a + b;
}

// 2. 한 줄짜리면 => 로 줄이기 ( { return ...; } 와 같음 )
int multiply(int a, int b) => a * b;

// 3. { } 로 감싸면 이름 있는 매개변수
//    required → 필수 / ? → 선택(null 가능)
void greet({required String name, int? age}) {
  final ageText = age == null ? '' : ' ($age살)';
  print('안녕하세요, $name님$ageText');
}

// 4. [ ] 로 감싸면 선택적 위치 매개변수, = 로 기본값
String formatTemp(double temp, [String unit = '°C']) => '$temp$unit';

// 5. 매개변수로 함수를 받기
//    void Function() = "아무것도 안 받고 아무것도 안 돌려주는 함수"
void runTwice(void Function() action) {
  action();
  action();
}

void repeat(int times, void Function(int) action) {
  for (var i = 1; i <= times; i++) {
    action(i);
  }
}
